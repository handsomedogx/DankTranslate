.pragma library

function normalizeText(value) {
    if (value === undefined || value === null) {
        return "";
    }
    return String(value).trim();
}

function defaultSettings(i18n) {
    return {
        "translationBackend": "google",
        "openaiBaseUrl": "",
        "openaiModel": "",
        "openaiApiKey": "",
        "openaiSystemPrompt": i18n.defaultOpenaiSystemPrompt(),
        "openaiUserPrompt": i18n.defaultOpenaiUserPromptTemplate()
    };
}

function loadSettings(loadValue, i18n) {
    const defaults = defaultSettings(i18n);
    return {
        "translationBackend": normalizeText(loadValue("translationBackend", defaults.translationBackend)) || defaults.translationBackend,
        "openaiBaseUrl": normalizeText(loadValue("openaiBaseUrl", defaults.openaiBaseUrl)),
        "openaiModel": normalizeText(loadValue("openaiModel", defaults.openaiModel)),
        "openaiApiKey": normalizeText(loadValue("openaiApiKey", defaults.openaiApiKey)),
        "openaiSystemPrompt": loadValue("openaiSystemPrompt", defaults.openaiSystemPrompt),
        "openaiUserPrompt": loadValue("openaiUserPrompt", defaults.openaiUserPrompt)
    };
}

function fromObject(data, i18n) {
    const defaults = defaultSettings(i18n);
    return {
        "translationBackend": normalizeText(data?.translationBackend || defaults.translationBackend) || defaults.translationBackend,
        "openaiBaseUrl": normalizeText(data?.openaiBaseUrl || defaults.openaiBaseUrl),
        "openaiModel": normalizeText(data?.openaiModel || defaults.openaiModel),
        "openaiApiKey": normalizeText(data?.openaiApiKey || defaults.openaiApiKey),
        "openaiSystemPrompt": data?.openaiSystemPrompt || defaults.openaiSystemPrompt,
        "openaiUserPrompt": data?.openaiUserPrompt || defaults.openaiUserPrompt
    };
}

function configurationMessage(uiLanguage, settings, i18n) {
    const normalized = fromObject(settings, i18n);
    if (normalized.translationBackend !== "openai") {
        return "";
    }

    const missing = [];
    if (normalized.openaiBaseUrl.length === 0) {
        missing.push(i18n.t(uiLanguage, "backendBaseUrlShort"));
    }
    if (normalized.openaiModel.length === 0) {
        missing.push(i18n.t(uiLanguage, "backendModelShort"));
    }
    if (missing.length === 0) {
        return "";
    }

    return i18n.t(uiLanguage, "openaiConfigMissing", {
        "items": i18n.joinList(uiLanguage, missing)
    });
}

function buildArgs(settings, i18n) {
    const normalized = fromObject(settings, i18n);
    const args = ["--backend", normalized.translationBackend];
    if (normalized.translationBackend !== "openai") {
        return args;
    }

    if (normalized.openaiBaseUrl.length > 0) {
        args.push("--openai-base-url", normalized.openaiBaseUrl);
    }
    if (normalized.openaiModel.length > 0) {
        args.push("--openai-model", normalized.openaiModel);
    }
    if (normalized.openaiApiKey.length > 0) {
        args.push("--openai-api-key", normalized.openaiApiKey);
    }
    if (normalized.openaiSystemPrompt.length > 0) {
        args.push("--openai-system-prompt", normalized.openaiSystemPrompt);
    }
    if (normalized.openaiUserPrompt.length > 0) {
        args.push("--openai-user-prompt", normalized.openaiUserPrompt);
    }

    return args;
}
