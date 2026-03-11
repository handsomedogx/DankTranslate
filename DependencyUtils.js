.pragma library

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

function parseCsv(value) {
    if (!value || value.length === 0) {
        return [];
    }
    return value.split(",").map(entry => entry.trim()).filter(entry => entry.length > 0);
}

function parseProbeOutput(raw) {
    const status = defaultStatus();
    const text = (raw || "").trim();

    if (text.length === 0) {
        status.checked = true;
        status.probeError = "Dependency check returned no output.";
        return status;
    }

    const fields = {};
    const lines = text.split("\n");
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

function formatMissingList(values) {
    return values.join(", ");
}

function getTranslateMessage(status) {
    if (!status.checked) {
        return "Checking translation dependencies...";
    }

    if (status.probeError) {
        return "Dependency check failed: " + status.probeError;
    }

    const missing = [];
    if (!status.dms) {
        missing.push("dms");
    }
    if (!status.python3) {
        missing.push("python3");
    }
    if (!status.helper) {
        missing.push("translate helper script");
    }

    if (missing.length === 0) {
        return "";
    }

    return "Text translation unavailable: missing " + formatMissingList(missing) + ".";
}

function getScreenshotMessage(status) {
    if (!status.checked) {
        return "Checking screenshot OCR dependencies...";
    }

    if (status.probeError) {
        return "Dependency check failed: " + status.probeError;
    }

    const problems = [];
    if (!status.tesseract) {
        problems.push("tesseract");
    }
    if (status.missingOcrLanguages.length > 0) {
        problems.push("OCR languages: " + formatMissingList(status.missingOcrLanguages));
    }

    if (problems.length === 0) {
        return "";
    }

    return "Screenshot OCR unavailable: " + problems.join("; ") + ".";
}

function formatStatusLine(label, ok, details) {
    let line = label + ": " + (ok ? "OK" : "Missing");
    if (details && details.length > 0) {
        line += " (" + details + ")";
    }
    return line;
}
