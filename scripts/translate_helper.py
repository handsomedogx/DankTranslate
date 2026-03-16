#!/usr/bin/env python3

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request


GOOGLE_TRANSLATE_URL = "https://translate.googleapis.com/translate_a/single"
DEFAULT_OPENAI_SYSTEM_PROMPT = (
    "You are a translation engine. Translate the user's text accurately into the requested "
    "target language. Preserve line breaks, punctuation, and formatting. Return only the "
    "translated text without explanations or quotes."
)
DEFAULT_OPENAI_USER_PROMPT_TEMPLATE = (
    "Translate the following text from {sourceLanguage} to {targetLanguage}. Preserve line "
    "breaks, punctuation, and formatting. Return only the translation.\n\n{text}"
)
HAN_PATTERN = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")
LATIN_PATTERN = re.compile(r"[A-Za-z]")
CANCELLED_PATTERN = re.compile(r"\b(cancelled|canceled|cancel|aborted)\b", re.IGNORECASE)


def emit(payload):
    print(json.dumps(payload, ensure_ascii=False))


def normalize_text_input(text):
    return (text or "").replace("\r\n", "\n").replace("\r", "\n")


def clean_ocr_text(text):
    lines = [line.strip() for line in text.splitlines()]
    compact = "\n".join(line for line in lines if line)
    compact = re.sub(r"\n{3,}", "\n\n", compact)
    return compact.strip()


def infer_source_language(text, configured_source):
    if configured_source != "auto":
        return configured_source

    han_count = len(HAN_PATTERN.findall(text))
    latin_count = len(LATIN_PATTERN.findall(text))

    if han_count == 0 and latin_count == 0:
        return ""

    if han_count >= latin_count:
        return "zh-CN"

    return "en"


def infer_target_language(text, configured_target):
    if configured_target != "auto":
        return configured_target

    han_count = len(HAN_PATTERN.findall(text))
    latin_count = len(LATIN_PATTERN.findall(text))

    if han_count == 0 and latin_count == 0:
        return "zh-CN"

    if han_count >= latin_count:
        return "en"

    return "zh-CN"


def language_name(language_code):
    if language_code in ("zh", "zh-CN"):
        return "Simplified Chinese"
    if language_code == "en":
        return "English"
    if language_code == "auto":
        return "the detected source language"
    return language_code


def is_cancelled_capture(returncode, stderr_text, stdout_bytes):
    if stdout_bytes:
        return False

    message = (stderr_text or "").strip()
    if returncode == 0 and not message:
        return True

    return bool(message and CANCELLED_PATTERN.search(message))


def read_json_response(request, timeout):
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        response_text = exc.read().decode("utf-8", errors="replace").strip()
        raise RuntimeError(response_text or f"Translation backend returned HTTP {exc.code}.") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(str(exc.reason or exc)) from exc


def translate_text_with_google(text, source, target, timeout):
    query = urllib.parse.urlencode({
        "client": "gtx",
        "sl": source,
        "tl": target,
        "dt": "t",
        "q": text,
    })
    request = urllib.request.Request(
        GOOGLE_TRANSLATE_URL + "?" + query,
        headers={"User-Agent": "DankTranslate/0.3"},
    )
    payload = read_json_response(request, timeout)

    translated_chunks = []
    for chunk in payload[0] or []:
        if chunk and len(chunk) > 0 and chunk[0]:
            translated_chunks.append(chunk[0])

    translated = "".join(translated_chunks).strip()
    if not translated:
        raise RuntimeError("Google Translate returned an empty result.")

    detected_source = payload[2] if len(payload) > 2 and isinstance(payload[2], str) else infer_source_language(text, source)
    return {
        "translated_text": translated,
        "detected_source": detected_source,
    }


def normalize_openai_chat_url(base_url):
    normalized = (base_url or "").strip().rstrip("/")
    if not normalized:
        raise RuntimeError("OpenAI-compatible backend requires a base URL.")

    if normalized.endswith("/chat/completions"):
        return normalized
    if normalized.endswith("/v1"):
        return normalized + "/chat/completions"
    return normalized + "/v1/chat/completions"


def build_openai_prompt(text, source, target):
    template = DEFAULT_OPENAI_USER_PROMPT_TEMPLATE
    return apply_prompt_template(template, text, source, target)


def apply_prompt_template(template, text, source, target):
    source_name = language_name(infer_source_language(text, source) or source or "auto")
    target_name = language_name(target)
    values = {
        "{sourceLanguage}": source_name,
        "{source_language}": source_name,
        "{source}": source_name,
        "{targetLanguage}": target_name,
        "{target_language}": target_name,
        "{target}": target_name,
        "{text}": text,
    }

    rendered = template
    for placeholder, value in values.items():
        rendered = rendered.replace(placeholder, value)
    return rendered


def extract_content_text(content):
    if isinstance(content, str):
        return content.strip()

    if isinstance(content, list):
        parts = []
        for part in content:
            if isinstance(part, str):
                parts.append(part)
                continue
            if isinstance(part, dict):
                text = part.get("text")
                if isinstance(text, str) and text.strip():
                    parts.append(text)
        return "".join(parts).strip()

    return ""


def translate_text_with_openai(
    text,
    source,
    target,
    timeout,
    base_url,
    api_key,
    model,
    system_prompt,
    user_prompt_template,
):
    normalized_model = (model or "").strip()
    if not normalized_model:
        raise RuntimeError("OpenAI-compatible backend requires a model name.")

    normalized_system_prompt = (system_prompt or "").strip() or DEFAULT_OPENAI_SYSTEM_PROMPT
    normalized_user_prompt_template = (user_prompt_template or "").strip() or DEFAULT_OPENAI_USER_PROMPT_TEMPLATE

    request_body = {
        "model": normalized_model,
        "messages": [
            {"role": "system", "content": normalized_system_prompt},
            {"role": "user", "content": apply_prompt_template(normalized_user_prompt_template, text, source, target)},
        ],
        "temperature": 0.2,
        "stream": False,
    }
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "DankTranslate/0.3",
    }
    normalized_api_key = (api_key or "").strip()
    if normalized_api_key:
        headers["Authorization"] = f"Bearer {normalized_api_key}"

    request = urllib.request.Request(
        normalize_openai_chat_url(base_url),
        data=json.dumps(request_body, ensure_ascii=False).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    payload = read_json_response(request, timeout)

    translated = ""
    choices = payload.get("choices")
    if isinstance(choices, list) and choices:
        first_choice = choices[0] if isinstance(choices[0], dict) else {}
        if isinstance(first_choice, dict):
            message = first_choice.get("message")
            if isinstance(message, dict):
                translated = extract_content_text(message.get("content"))
            if not translated:
                translated = extract_content_text(first_choice.get("text"))

    translated = translated.strip()
    if not translated:
        raise RuntimeError("OpenAI-compatible backend returned an empty result.")

    return {
        "translated_text": translated,
        "detected_source": infer_source_language(text, source),
    }


def translate_text(
    text,
    source,
    target,
    timeout,
    backend,
    openai_base_url,
    openai_api_key,
    openai_model,
    openai_system_prompt,
    openai_user_prompt,
):
    if backend == "google":
        return translate_text_with_google(text, source, target, timeout)
    if backend == "openai":
        return translate_text_with_openai(
            text,
            source,
            target,
            timeout,
            openai_base_url,
            openai_api_key,
            openai_model,
            openai_system_prompt,
            openai_user_prompt,
        )
    raise RuntimeError(f"Unsupported translation backend: {backend}")


def capture_screenshot(mode):
    command = [
        "dms",
        "screenshot",
        mode,
        "--stdout",
        "--no-file",
        "--no-clipboard",
        "--no-notify",
    ]
    process = subprocess.run(command, capture_output=True, check=False)
    error = process.stderr.decode("utf-8", errors="replace").strip()

    if is_cancelled_capture(process.returncode, error, process.stdout):
        return None

    if process.returncode != 0:
        raise RuntimeError(error or "dms screenshot failed.")
    if not process.stdout:
        raise RuntimeError("dms screenshot did not return image data.")
    return process.stdout


def run_tesseract(image_path, languages):
    command = [
        "tesseract",
        image_path,
        "stdout",
        "-l",
        languages,
        "--psm",
        "6",
    ]
    process = subprocess.run(command, capture_output=True, text=True, check=False)
    if process.returncode != 0:
        error = process.stderr.strip()
        raise RuntimeError(error or "tesseract OCR failed.")

    text = clean_text(process.stdout)
    if not text:
        raise RuntimeError("OCR did not detect any text in the screenshot.")
    return text


def build_translation_payload(mode, text, target, translated):
    return {
        "ok": True,
        "mode": mode,
        "input_text": text,
        "ocr_text": text if mode == "screenshot" else "",
        "target_language": target,
        "translated_text": translated["translated_text"],
        "detected_source": translated["detected_source"],
    }


def handle_translate(args):
    raw_text = normalize_text_input(args.text)
    if not raw_text.strip():
        return {"ok": False, "error": "No text was provided for translation."}
    text = raw_text

    target = infer_target_language(text, args.target)
    translated = translate_text(
        text,
        args.source,
        target,
        args.timeout,
        args.backend,
        args.openai_base_url,
        args.openai_api_key,
        args.openai_model,
        args.openai_system_prompt,
        args.openai_user_prompt,
    )
    return build_translation_payload("translate", text, target, translated)


def handle_test_backend(args):
    raw_text = normalize_text_input(args.text)
    if not raw_text.strip():
        return {"ok": False, "error": "No text was provided for backend testing."}
    text = raw_text

    target = infer_target_language(text, args.target)
    translated = translate_text(
        text,
        args.source,
        target,
        args.timeout,
        args.backend,
        args.openai_base_url,
        args.openai_api_key,
        args.openai_model,
        args.openai_system_prompt,
        args.openai_user_prompt,
    )
    payload = build_translation_payload("test-backend", text, target, translated)
    payload["backend"] = args.backend
    return payload


def handle_screenshot(args):
    image_bytes = capture_screenshot(args.mode)
    if image_bytes is None:
        return {
            "ok": False,
            "mode": "screenshot",
            "cancelled": True,
            "error": "",
        }

    with tempfile.NamedTemporaryFile(prefix="dank-translate-", suffix=".png", delete=False) as handle:
        handle.write(image_bytes)
        image_path = handle.name

    try:
        ocr_text = clean_ocr_text(run_tesseract(image_path, args.ocr_languages))
        target = infer_target_language(ocr_text, args.target)
        translated = translate_text(
            ocr_text,
            args.source,
            target,
            args.timeout,
            args.backend,
            args.openai_base_url,
            args.openai_api_key,
            args.openai_model,
            args.openai_system_prompt,
            args.openai_user_prompt,
        )
        payload = build_translation_payload("screenshot", ocr_text, target, translated)
        payload["capture_mode"] = args.mode
        return payload
    finally:
        try:
            os.unlink(image_path)
        except OSError:
            pass


def add_backend_arguments(parser):
    parser.add_argument(
        "--backend",
        choices=["google", "openai"],
        default="google",
        help="Translation backend to use.",
    )
    parser.add_argument(
        "--openai-base-url",
        default="",
        help="Base URL for an OpenAI-compatible API, e.g. http://127.0.0.1:8031/v1.",
    )
    parser.add_argument(
        "--openai-api-key",
        default="",
        help="Optional API key for the OpenAI-compatible API.",
    )
    parser.add_argument(
        "--openai-model",
        default="",
        help="Model name used for the OpenAI-compatible API.",
    )
    parser.add_argument(
        "--openai-system-prompt",
        default="",
        help="Optional custom system prompt for the OpenAI-compatible API.",
    )
    parser.add_argument(
        "--openai-user-prompt",
        default="",
        help="Optional custom user prompt template for the OpenAI-compatible API.",
    )


def build_parser():
    parser = argparse.ArgumentParser(description="Helper for DankTranslate DMS plugin.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    translate_parser = subparsers.add_parser("translate", help="Translate plain text.")
    translate_parser.add_argument("--text", required=True, help="Input text to translate.")
    translate_parser.add_argument("--source", default="auto", help="Source language code.")
    translate_parser.add_argument("--target", required=True, help="Target language code or auto.")
    translate_parser.add_argument("--timeout", type=float, default=10.0, help="Network timeout in seconds.")
    add_backend_arguments(translate_parser)

    test_parser = subparsers.add_parser("test-backend", help="Run a sample translation against the configured backend.")
    test_parser.add_argument("--text", required=True, help="Input text used for backend testing.")
    test_parser.add_argument("--source", default="auto", help="Source language code.")
    test_parser.add_argument("--target", required=True, help="Target language code or auto.")
    test_parser.add_argument("--timeout", type=float, default=10.0, help="Network timeout in seconds.")
    add_backend_arguments(test_parser)

    screenshot_parser = subparsers.add_parser("screenshot", help="Capture a screenshot, OCR it, then translate it.")
    screenshot_parser.add_argument("--source", default="auto", help="Source language code.")
    screenshot_parser.add_argument("--target", required=True, help="Target language code or auto.")
    screenshot_parser.add_argument(
        "--mode",
        choices=["region", "full", "window", "all"],
        default="region",
        help="DMS screenshot mode to use.",
    )
    screenshot_parser.add_argument(
        "--ocr-languages",
        default="eng+chi_sim",
        help="Tesseract language list, e.g. eng+chi_sim.",
    )
    screenshot_parser.add_argument("--timeout", type=float, default=10.0, help="Network timeout in seconds.")
    add_backend_arguments(screenshot_parser)

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()

    try:
        if args.command == "translate":
            payload = handle_translate(args)
        elif args.command == "test-backend":
            payload = handle_test_backend(args)
        else:
            payload = handle_screenshot(args)
    except Exception as exc:
        payload = {"ok": False, "error": str(exc)}

    emit(payload)
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
