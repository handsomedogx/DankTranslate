.pragma library

function isZh(uiLanguage) {
    return uiLanguage === "zh";
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

function parseProbeOutput(raw, uiLanguage, i18n) {
    const status = defaultStatus();
    const rawText = (raw || "").trim();

    if (rawText.length === 0) {
        status.checked = true;
        status.probeError = i18n.t(uiLanguage, "dependencyCheckNoOutput");
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
    const parsed = parseProbeOutput(raw, uiLanguage, i18n);
    parsed.loading = false;
    if (exitCode !== 0 && !parsed.probeError) {
        parsed.probeError = i18n.t(uiLanguage, "dependencyProbeExitCode", {
            "code": exitCode
        });
    }
    return parsed;
}

function formatMissingListForUi(values, uiLanguage) {
    return values.join(isZh(uiLanguage) ? "、" : ", ");
}

function getTranslateMessage(status, uiLanguage, i18n) {
    if (!status.checked) {
        return i18n.t(uiLanguage, "checkingTranslationDependencies");
    }

    if (status.probeError) {
        return i18n.t(uiLanguage, "dependencyCheckFailed", {
            "error": status.probeError
        });
    }

    const missing = [];
    if (!status.dms) {
        missing.push("dms");
    }
    if (!status.python3) {
        missing.push("python3");
    }
    if (!status.helper) {
        missing.push(i18n.t(uiLanguage, "translateHelperScript"));
    }

    if (missing.length === 0) {
        return "";
    }

    return i18n.t(uiLanguage, "textTranslationUnavailable", {
        "items": formatMissingListForUi(missing, uiLanguage)
    });
}

function getScreenshotMessage(status, uiLanguage, i18n) {
    if (!status.checked) {
        return i18n.t(uiLanguage, "checkingScreenshotDependencies");
    }

    if (status.probeError) {
        return i18n.t(uiLanguage, "dependencyCheckFailed", {
            "error": status.probeError
        });
    }

    const problems = [];
    if (!status.tesseract) {
        problems.push("tesseract");
    }
    if (status.missingOcrLanguages.length > 0) {
        problems.push(i18n.t(uiLanguage, "ocrLanguagesLabel", {
            "items": formatMissingListForUi(status.missingOcrLanguages, uiLanguage)
        }));
    }

    if (problems.length === 0) {
        return "";
    }

    return i18n.t(uiLanguage, "screenshotUnavailable", {
        "items": problems.join(isZh(uiLanguage) ? "；" : "; ")
    });
}

function formatStatusLine(label, ok, details, uiLanguage, i18n) {
    let line = label + ": " + (ok ? i18n.t(uiLanguage, "ok") : i18n.t(uiLanguage, "missing"));
    if (details && details.length > 0) {
        line += " (" + details + ")";
    }
    return line;
}
