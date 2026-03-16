.pragma library

const STRINGS = {
    "en": {
        "auto": "Auto",
        "english": "English",
        "chinese": "Chinese",
        "unknown": "Unknown",
        "on": "On",
        "off": "Off",
        "none": "none",
        "unavailable": "unavailable",
        "ok": "OK",
        "missing": "Missing",
        "autoTargetButton": "Auto EN/ZH",
        "toLanguage": "To {language}",
        "pluginDescription": "A bar translation plugin with popup translation, keyboard-triggered IPC entry points, and screenshot OCR translation.",
        "dependencies": "Dependencies",
        "dependencyIntro": "Required tools: python3, tesseract, and the DMS CLI. For Chinese OCR install the Tesseract language data for chi_sim in addition to eng.",
        "translationBackend": "Translation backend",
        "translationBackendDescription": "Choose between the built-in Google Translate web endpoint and an OpenAI-compatible model API.",
        "backendGoogle": "Google Translate",
        "backendOpenai": "OpenAI-Compatible Model",
        "openaiSettings": "OpenAI-compatible backend",
        "openaiBaseUrl": "Base URL",
        "openaiBaseUrlDescription": "Host or /v1 endpoint for the model server, for example http://127.0.0.1:8031/v1.",
        "openaiModel": "Model",
        "openaiModelDescription": "The model name sent to the OpenAI-compatible API.",
        "openaiApiKey": "API key",
        "openaiApiKeyDescription": "Optional for local servers that do not require authentication.",
        "openaiPromptSettings": "Prompt settings",
        "openaiPromptDescription": "Customize the OpenAI-compatible prompts used for translation requests.",
        "openaiSystemPrompt": "System prompt",
        "openaiSystemPromptDescription": "Sets the assistant role for the model. Use the recommended default unless you need stricter behavior.",
        "openaiUserPrompt": "User prompt template",
        "openaiUserPromptDescription": "Template for each translation request. Available placeholders: {sourceLanguage}, {targetLanguage}, {text}.",
        "resetPromptDefaults": "Reset Prompt Defaults",
        "backendBaseUrlShort": "base URL",
        "backendModelShort": "model",
        "openaiConfigMissing": "OpenAI-compatible backend requires: {items}.",
        "translationDirection": "Translation direction",
        "translationDirectionDescription": "Auto translates Chinese to English and English to Chinese. You can still force a fixed target.",
        "screenshotMode": "Screenshot mode",
        "screenshotModeDescription": "The mode used when starting screenshot translation from the icon or IPC shortcut.",
        "ocrLanguages": "OCR languages",
        "ocrLanguagesDescription": "Use Tesseract language codes joined by +, for example eng+chi_sim.",
        "backendTest": "Backend test",
        "backendTestDescription": "Run a sample translation with the currently selected backend configuration.",
        "backendTestInput": "Test text",
        "backendTestButton": "Test Current Backend",
        "testingBackend": "Testing backend...",
        "backendTestSucceeded": "Backend test succeeded.",
        "backendTestFailed": "Backend test failed: {error}",
        "backendTestResult": "Test result",
        "backendTestDefaultText": "Hello from Dank Translate.",
        "diagnostics": "Diagnostics",
        "requestedOcrLanguages": "Requested OCR languages: {value}",
        "missingOcrLanguages": "Missing OCR languages: {value}",
        "installedOcrLanguages": "Installed OCR languages: {value}",
        "checkError": "Check error: {error}",
        "refreshDiagnostics": "Refresh Diagnostics",
        "behavior": "Behavior",
        "autoCopyTranslatedText": "Auto-copy translated text",
        "autoCopyTranslatedTextDescription": "Choose whether successful translations are copied to the clipboard automatically.",
        "rememberLastInput": "Remember last input",
        "rememberLastInputDescription": "Persist the last typed text between shell restarts.",
        "suggestedIpcCommands": "Suggested IPC keybind commands",
        "openOrCloseTranslator": "Open or close the translator popout:\n{command}",
        "startScreenshotTranslation": "Start screenshot OCR translation:\n{command}",
        "openQuickActionsPanel": "Open the quick actions panel:\n{command}",
        "pluginUnavailableTitle": "Dank Translate unavailable",
        "pluginFailedTitle": "Dank Translate failed",
        "translatedTextCopied": "Translated text copied",
        "screenshotTranslatedTitle": "Screenshot translated",
        "genericRequestFailed": "Translation request failed.",
        "screenshotTranslatedTo": "Screenshot OCR translated to {language}",
        "translatedTo": "Translated to {language}",
        "enterTextBeforeTranslating": "Enter some text before translating.",
        "translatingText": "Translating text...",
        "selectScreenshotArea": "Select an area for screenshot translation...",
        "actionsHeader": "Dank Translate Actions",
        "actionsDetails": "Right click the bar icon for quick actions, or bind the IPC targets for keyboard access.",
        "autoDetails": "Auto-detect Chinese vs English input and translate to the opposite language. Use Ctrl+Enter to translate from the editor.",
        "fixedDetails": "Auto-detect input text and translate it to {language}. Use Ctrl+Enter to translate from the editor.",
        "quickActionsIntro": "Quick actions for keyboard-first use.",
        "openTranslator": "Open Translator",
        "screenshotOcr": "Screenshot OCR",
        "clearResults": "Clear Results",
        "refreshDependencyCheck": "Refresh Dependency Check",
        "suggestedKeybindTargets": "Suggested keybind IPC targets",
        "textTranslation": "Text translation",
        "runtimeChecks": "Runtime checks",
        "validatingDependencies": "Validating python3, tesseract, helper scripts, and OCR language packs.",
        "screenshot": "Screenshot",
        "actions": "Actions",
        "inputPlaceholder": "Type or paste a word or sentence here. Press Ctrl+Enter to translate.",
        "checkingShort": "Checking...",
        "working": "Working...",
        "translate": "Translate",
        "copyResult": "Copy Result",
        "clear": "Clear",
        "translation": "Translation",
        "backendInUse": "Current backend: {value}",
        "backendInUseWithModel": "Current backend: {value} ({model})",
        "translationPlaceholder": "Translated text will appear here.",
        "detectedSource": "Detected source: {value}",
        "dependencyProbeExitCode": "Dependency probe exited with code {code}",
        "dependencyCheckNoOutput": "Dependency check returned no output.",
        "checkingTranslationDependencies": "Checking translation dependencies...",
        "checkingScreenshotDependencies": "Checking screenshot OCR dependencies...",
        "dependencyCheckFailed": "Dependency check failed: {error}",
        "textTranslationUnavailable": "Text translation unavailable: missing {items}.",
        "translateHelperScript": "translate helper script",
        "screenshotUnavailable": "Screenshot OCR unavailable: {items}.",
        "ocrLanguagesLabel": "OCR languages: {items}",
        "checkingDependencies": "Checking dependencies...",
        "modeRegion": "Region",
        "modeFull": "Full Screen",
        "modeWindow": "Window",
        "modeAll": "All Displays"
    },
    "zh": {
        "auto": "自动",
        "english": "英语",
        "chinese": "中文",
        "unknown": "未知",
        "on": "开启",
        "off": "关闭",
        "none": "无",
        "unavailable": "不可用",
        "ok": "正常",
        "missing": "缺失",
        "autoTargetButton": "自动 中英",
        "toLanguage": "翻译为{language}",
        "pluginDescription": "一个支持弹窗翻译、IPC 快捷键和截图 OCR 翻译的状态栏插件。",
        "dependencies": "依赖",
        "dependencyIntro": "需要 python3、tesseract 和 DMS CLI。若要识别中文，请额外安装 chi_sim 的 Tesseract 语言包。",
        "translationBackend": "翻译后端",
        "translationBackendDescription": "在内置的 Google Translate 网页接口和 OpenAI 协议模型接口之间切换。",
        "backendGoogle": "谷歌翻译",
        "backendOpenai": "OpenAI 协议模型",
        "openaiSettings": "OpenAI 协议后端",
        "openaiBaseUrl": "基础地址",
        "openaiBaseUrlDescription": "填写模型服务的主机地址或 /v1 端点，例如 http://127.0.0.1:8031/v1。",
        "openaiModel": "模型",
        "openaiModelDescription": "发送给 OpenAI 协议接口的模型名称。",
        "openaiApiKey": "API Key",
        "openaiApiKeyDescription": "对于不需要鉴权的本地服务，这一项可以留空。",
        "openaiPromptSettings": "提示词设置",
        "openaiPromptDescription": "自定义发送给 OpenAI 协议模型的提示词。",
        "openaiSystemPrompt": "系统提示词",
        "openaiSystemPromptDescription": "用于设置模型的角色约束。除非你明确知道要改什么，否则建议保留默认值。",
        "openaiUserPrompt": "用户提示词模板",
        "openaiUserPromptDescription": "每次翻译请求使用的模板。可用占位符：{sourceLanguage}、{targetLanguage}、{text}。",
        "resetPromptDefaults": "恢复默认提示词",
        "backendBaseUrlShort": "基础地址",
        "backendModelShort": "模型",
        "openaiConfigMissing": "OpenAI 协议后端需要填写：{items}。",
        "translationDirection": "翻译方向",
        "translationDirectionDescription": "自动模式会将中文翻译成英文，将英文翻译成中文。你也可以固定目标语言。",
        "screenshotMode": "截图模式",
        "screenshotModeDescription": "从图标或 IPC 快捷键启动截图翻译时使用的模式。",
        "ocrLanguages": "OCR 语言",
        "ocrLanguagesDescription": "使用以 + 连接的 Tesseract 语言代码，例如 eng+chi_sim。",
        "backendTest": "后端测试",
        "backendTestDescription": "使用当前选择的后端配置发起一次示例翻译。",
        "backendTestInput": "测试文本",
        "backendTestButton": "测试当前后端",
        "testingBackend": "正在测试后端...",
        "backendTestSucceeded": "后端测试成功。",
        "backendTestFailed": "后端测试失败：{error}",
        "backendTestResult": "测试结果",
        "backendTestDefaultText": "Hello from Dank Translate.",
        "diagnostics": "诊断",
        "requestedOcrLanguages": "请求的 OCR 语言：{value}",
        "missingOcrLanguages": "缺少的 OCR 语言：{value}",
        "installedOcrLanguages": "已安装的 OCR 语言：{value}",
        "checkError": "检查错误：{error}",
        "refreshDiagnostics": "刷新诊断",
        "behavior": "行为",
        "autoCopyTranslatedText": "自动复制译文",
        "autoCopyTranslatedTextDescription": "选择成功翻译后是否自动复制到剪贴板。",
        "rememberLastInput": "记住上次输入",
        "rememberLastInputDescription": "在 shell 重启之间保留上次输入内容。",
        "suggestedIpcCommands": "建议的 IPC 快捷键命令",
        "openOrCloseTranslator": "打开或关闭翻译弹窗：\n{command}",
        "startScreenshotTranslation": "开始截图 OCR 翻译：\n{command}",
        "openQuickActionsPanel": "打开快捷操作面板：\n{command}",
        "pluginUnavailableTitle": "Dank Translate 不可用",
        "pluginFailedTitle": "Dank Translate 失败",
        "translatedTextCopied": "已复制译文",
        "screenshotTranslatedTitle": "截图翻译完成",
        "genericRequestFailed": "翻译请求失败。",
        "screenshotTranslatedTo": "截图 OCR 已翻译为{language}",
        "translatedTo": "已翻译为{language}",
        "enterTextBeforeTranslating": "请先输入一些内容。",
        "translatingText": "正在翻译...",
        "selectScreenshotArea": "请选择截图区域进行翻译...",
        "actionsHeader": "Dank Translate 操作",
        "actionsDetails": "右键栏图标可打开快捷操作，也可以绑定 IPC 命令进行键盘调用。",
        "autoDetails": "自动识别中文或英文输入，并翻译为另一种语言。按 Ctrl+Enter 开始翻译。",
        "fixedDetails": "自动检测输入语言，并翻译为{language}。按 Ctrl+Enter 开始翻译。",
        "quickActionsIntro": "适合键盘优先场景的快捷操作。",
        "openTranslator": "打开翻译器",
        "screenshotOcr": "截图 OCR",
        "clearResults": "清空结果",
        "refreshDependencyCheck": "刷新依赖检查",
        "suggestedKeybindTargets": "建议的快捷键 IPC 目标",
        "textTranslation": "文本翻译",
        "runtimeChecks": "运行时检查",
        "validatingDependencies": "正在验证 python3、tesseract、辅助脚本和 OCR 语言包。",
        "screenshot": "截图",
        "actions": "操作",
        "inputPlaceholder": "在这里输入或粘贴单词、短语或句子。按 Ctrl+Enter 开始翻译。",
        "checkingShort": "检查中...",
        "working": "处理中...",
        "translate": "翻译",
        "copyResult": "复制结果",
        "clear": "清空",
        "translation": "译文",
        "backendInUse": "当前后端：{value}",
        "backendInUseWithModel": "当前后端：{value}（{model}）",
        "translationPlaceholder": "译文会显示在这里。",
        "detectedSource": "检测到的源语言：{value}",
        "dependencyProbeExitCode": "依赖检查退出码：{code}",
        "dependencyCheckNoOutput": "依赖检查没有返回任何输出。",
        "checkingTranslationDependencies": "正在检查文本翻译依赖...",
        "checkingScreenshotDependencies": "正在检查截图 OCR 依赖...",
        "dependencyCheckFailed": "依赖检查失败：{error}",
        "textTranslationUnavailable": "文本翻译不可用：缺少{items}。",
        "translateHelperScript": "翻译辅助脚本",
        "screenshotUnavailable": "截图 OCR 不可用：{items}。",
        "ocrLanguagesLabel": "OCR 语言：{items}",
        "checkingDependencies": "正在检查依赖...",
        "modeRegion": "选区",
        "modeFull": "全屏",
        "modeWindow": "窗口",
        "modeAll": "全部显示器"
    }
};

function normalizeUiLanguage(uiLanguage) {
    return uiLanguage === "zh" ? "zh" : "en";
}

function detectUiLanguage(localeName) {
    const normalized = String(localeName || "").toLowerCase().replace("-", "_");
    return normalized.indexOf("zh") === 0 ? "zh" : "en";
}

function t(uiLanguage, key, params) {
    const resolvedLanguage = normalizeUiLanguage(uiLanguage);
    let text = STRINGS[resolvedLanguage][key] || STRINGS.en[key] || key;
    if (!params) {
        return text;
    }
    for (const name in params) {
        text = text.split("{" + name + "}").join(params[name]);
    }
    return text;
}

function joinList(uiLanguage, values) {
    const entries = values || [];
    return entries.join(normalizeUiLanguage(uiLanguage) === "zh" ? "、" : ", ");
}

function languageName(uiLanguage, languageCode) {
    if (languageCode === "auto") {
        return t(uiLanguage, "auto");
    }
    if (languageCode === "en") {
        return t(uiLanguage, "english");
    }
    if (languageCode === "zh-CN" || languageCode === "zh") {
        return t(uiLanguage, "chinese");
    }
    return languageCode || t(uiLanguage, "unknown");
}

function targetButtonText(uiLanguage, targetLang) {
    if (targetLang === "auto") {
        return t(uiLanguage, "autoTargetButton");
    }
    return t(uiLanguage, "toLanguage", {
        "language": languageName(uiLanguage, targetLang)
    });
}

function directionOptions(uiLanguage) {
    return [
        t(uiLanguage, "auto"),
        t(uiLanguage, "chinese"),
        t(uiLanguage, "english")
    ];
}

function backendOptions(uiLanguage) {
    return [
        t(uiLanguage, "backendGoogle"),
        t(uiLanguage, "backendOpenai")
    ];
}

function backendLabel(uiLanguage, value) {
    if (value === "openai") {
        return t(uiLanguage, "backendOpenai");
    }
    return t(uiLanguage, "backendGoogle");
}

function backendValue(uiLanguage, label) {
    if (label === t(uiLanguage, "backendOpenai")) {
        return "openai";
    }
    return "google";
}

function backendDisplayText(uiLanguage, backend, model) {
    const backendName = backendLabel(uiLanguage, backend);
    const normalizedModel = String(model || "").trim();
    if (backend === "openai" && normalizedModel.length > 0) {
        return t(uiLanguage, "backendInUseWithModel", {
            "value": backendName,
            "model": normalizedModel
        });
    }
    return t(uiLanguage, "backendInUse", {
        "value": backendName
    });
}

function defaultBackendTestText(uiLanguage) {
    return t(uiLanguage, "backendTestDefaultText");
}

function defaultOpenaiSystemPrompt() {
    return "You are a translation engine. Translate the user's text accurately into the requested target language. Preserve line breaks, punctuation, and formatting. Return only the translated text without explanations or quotes.";
}

function defaultOpenaiUserPromptTemplate() {
    return "Translate the following text from {sourceLanguage} to {targetLanguage}. Preserve line breaks, punctuation, and formatting. Return only the translation.\n\n{text}";
}

function directionLabel(uiLanguage, value) {
    if (value === "en") {
        return t(uiLanguage, "english");
    }
    if (value === "zh-CN" || value === "zh") {
        return t(uiLanguage, "chinese");
    }
    return t(uiLanguage, "auto");
}

function directionValue(uiLanguage, label) {
    if (label === t(uiLanguage, "english")) {
        return "en";
    }
    if (label === t(uiLanguage, "chinese")) {
        return "zh-CN";
    }
    return "auto";
}

function toggleOptions(uiLanguage, onFirst) {
    return onFirst
        ? [t(uiLanguage, "on"), t(uiLanguage, "off")]
        : [t(uiLanguage, "off"), t(uiLanguage, "on")];
}

function toggleLabel(uiLanguage, enabled) {
    return enabled ? t(uiLanguage, "on") : t(uiLanguage, "off");
}

function isEnabledLabel(uiLanguage, label) {
    return label === t(uiLanguage, "on");
}

function screenshotModeOptions(uiLanguage) {
    return [
        t(uiLanguage, "modeRegion"),
        t(uiLanguage, "modeFull"),
        t(uiLanguage, "modeWindow"),
        t(uiLanguage, "modeAll")
    ];
}

function screenshotModeLabel(uiLanguage, mode) {
    if (mode === "full") {
        return t(uiLanguage, "modeFull");
    }
    if (mode === "window") {
        return t(uiLanguage, "modeWindow");
    }
    if (mode === "all") {
        return t(uiLanguage, "modeAll");
    }
    return t(uiLanguage, "modeRegion");
}

function screenshotModeValue(uiLanguage, label) {
    if (label === t(uiLanguage, "modeFull")) {
        return "full";
    }
    if (label === t(uiLanguage, "modeWindow")) {
        return "window";
    }
    if (label === t(uiLanguage, "modeAll")) {
        return "all";
    }
    return "region";
}
