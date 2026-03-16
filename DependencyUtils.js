.pragma library

function isZh(uiLanguage) {
    return uiLanguage === "zh";
}

function localizedText(uiLanguage, enText, zhText) {
    return isZh(uiLanguage) ? zhText : enText;
}

function defaultStatus() {
    return {
        "checked": false,
        "loading": false,
        "probeError": "",
        "dms": false,
        "python3": false,
        "helper": false,
        "tesseract": false,
        "requiredOcrLanguages": [],
        "availableOcrLanguages": [],
        "missingOcrLanguages": []
    };
}

function loadingStatus() {
    const status = defaultStatus();
    status.loading = true;
    return status;
}

function parseCsv(value) {
    if (!value || value.length === 0) {
        return [];
    }
    return value.split(",").map(entry => entry.trim()).filter(entry => entry.length > 0);
}

function parseProbeOutput(raw, uiLanguage) {
    const status = defaultStatus();
    const rawText = (raw || "").trim();

    if (rawText.length === 0) {
        status.checked = true;
        status.probeError = localizedText(uiLanguage, "Dependency check returned no output.", "依赖检查没有返回任何输出。");
        return status;
    }

    const fields = {};
    const lines = rawText.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const separatorIndex = line.indexOf("=");
        if (separatorIndex <= 0) {
            continue;
        }
        fields[line.slice(0, separatorIndex)] = line.slice(separatorIndex + 1);
    }

    status.checked = true;
    status.dms = fields.DMS === "1";
    status.python3 = fields.PYTHON3 === "1";
    status.helper = fields.HELPER === "1";
    status.tesseract = fields.TESSERACT === "1";
    status.requiredOcrLanguages = parseCsv(fields.REQUIRED_LANGS || "");
    status.availableOcrLanguages = parseCsv(fields.LANGS || "");
    status.missingOcrLanguages = parseCsv(fields.MISSING_LANGS || "");
    status.probeError = fields.ERROR || "";

    return status;
}

function probeCommand(scriptPath, ocrLanguages) {
    return ["sh", scriptPath, ocrLanguages];
}

function finalizeProbeStatus(raw, exitCode, uiLanguage, i18n) {
    const parsed = parseProbeOutput(raw, uiLanguage);
    parsed.loading = false;
    if (exitCode !== 0 && !parsed.probeError) {
        parsed.probeError = i18n.t(uiLanguage, "dependencyProbeExitCode", {
            "code": exitCode
        });
    }
    return parsed;
}

function formatMissingList(values) {
    return values.join(", ");
}

function formatMissingListForUi(values, uiLanguage) {
    return values.join(isZh(uiLanguage) ? "、" : ", ");
}

function getTranslateMessage(status, uiLanguage) {
    if (!status.checked) {
        return localizedText(uiLanguage, "Checking translation dependencies...", "正在检查文本翻译依赖...");
    }

    if (status.probeError) {
        return localizedText(uiLanguage, "Dependency check failed: ", "依赖检查失败：") + status.probeError;
    }

    const missing = [];
    if (!status.dms) {
        missing.push("dms");
    }
    if (!status.python3) {
        missing.push("python3");
    }
    if (!status.helper) {
        missing.push(localizedText(uiLanguage, "translate helper script", "翻译辅助脚本"));
    }

    if (missing.length === 0) {
        return "";
    }

    return localizedText(uiLanguage, "Text translation unavailable: missing ", "文本翻译不可用：缺少")
        + formatMissingListForUi(missing, uiLanguage) + ".";
}

function getScreenshotMessage(status, uiLanguage) {
    if (!status.checked) {
        return localizedText(uiLanguage, "Checking screenshot OCR dependencies...", "正在检查截图 OCR 依赖...");
    }

    if (status.probeError) {
        return localizedText(uiLanguage, "Dependency check failed: ", "依赖检查失败：") + status.probeError;
    }

    const problems = [];
    if (!status.tesseract) {
        problems.push("tesseract");
    }
    if (status.missingOcrLanguages.length > 0) {
        problems.push(localizedText(uiLanguage, "OCR languages: ", "OCR 语言：") + formatMissingListForUi(status.missingOcrLanguages, uiLanguage));
    }

    if (problems.length === 0) {
        return "";
    }

    return localizedText(uiLanguage, "Screenshot OCR unavailable: ", "截图 OCR 不可用：")
        + problems.join(isZh(uiLanguage) ? "；" : "; ") + ".";
}

function formatStatusLine(label, ok, details, uiLanguage) {
    let line = label + ": " + (ok ? localizedText(uiLanguage, "OK", "正常") : localizedText(uiLanguage, "Missing", "缺失"));
    if (details && details.length > 0) {
        line += " (" + details + ")";
    }
    return line;
}
