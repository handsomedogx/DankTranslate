#!/usr/bin/env python3

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request


GOOGLE_TRANSLATE_URL = "https://translate.googleapis.com/translate_a/single"
HAN_PATTERN = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")
LATIN_PATTERN = re.compile(r"[A-Za-z]")
CANCELLED_PATTERN = re.compile(r"\b(cancelled|canceled|cancel|aborted)\b", re.IGNORECASE)


def emit(payload):
    print(json.dumps(payload, ensure_ascii=False))


def clean_text(text):
    lines = [line.strip() for line in text.splitlines()]
    compact = "\n".join(line for line in lines if line)
    compact = re.sub(r"\n{3,}", "\n\n", compact)
    return compact.strip()


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


def is_cancelled_capture(returncode, stderr_text, stdout_bytes):
    if stdout_bytes:
        return False

    message = (stderr_text or "").strip()
    if returncode == 0 and not message:
        return True

    return bool(message and CANCELLED_PATTERN.search(message))


def translate_text(text, source, target, timeout):
    query = urllib.parse.urlencode({
        "client": "gtx",
        "sl": source,
        "tl": target,
        "dt": "t",
        "q": text,
    })
    request = urllib.request.Request(
        GOOGLE_TRANSLATE_URL + "?" + query,
        headers={"User-Agent": "DankTranslate/0.1"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = json.loads(response.read().decode("utf-8"))

    translated_chunks = []
    for chunk in payload[0] or []:
        if chunk and len(chunk) > 0 and chunk[0]:
            translated_chunks.append(chunk[0])

    translated = "".join(translated_chunks).strip()
    if not translated:
        raise RuntimeError("Translation backend returned an empty result.")

    detected_source = payload[2] if len(payload) > 2 and isinstance(payload[2], str) else source
    return {
        "translated_text": translated,
        "detected_source": detected_source,
    }


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


def handle_translate(args):
    text = clean_text(args.text)
    if not text:
        return {"ok": False, "error": "No text was provided for translation."}

    target = infer_target_language(text, args.target)
    translated = translate_text(text, args.source, target, args.timeout)
    return {
        "ok": True,
        "mode": "translate",
        "input_text": text,
        "ocr_text": "",
        "target_language": target,
        "translated_text": translated["translated_text"],
        "detected_source": translated["detected_source"],
    }


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
        ocr_text = run_tesseract(image_path, args.ocr_languages)
        target = infer_target_language(ocr_text, args.target)
        translated = translate_text(ocr_text, args.source, target, args.timeout)
        return {
            "ok": True,
            "mode": "screenshot",
            "capture_mode": args.mode,
            "input_text": ocr_text,
            "ocr_text": ocr_text,
            "target_language": target,
            "translated_text": translated["translated_text"],
            "detected_source": translated["detected_source"],
        }
    finally:
        try:
            os.unlink(image_path)
        except OSError:
            pass


def build_parser():
    parser = argparse.ArgumentParser(description="Helper for DankTranslate DMS plugin.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    translate_parser = subparsers.add_parser("translate", help="Translate plain text.")
    translate_parser.add_argument("--text", required=True, help="Input text to translate.")
    translate_parser.add_argument("--source", default="auto", help="Source language code.")
    translate_parser.add_argument("--target", required=True, help="Target language code or auto.")
    translate_parser.add_argument("--timeout", type=float, default=10.0, help="Network timeout in seconds.")

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

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()

    try:
        if args.command == "translate":
            payload = handle_translate(args)
        else:
            payload = handle_screenshot(args)
    except Exception as exc:
        payload = {"ok": False, "error": str(exc)}

    emit(payload)
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
