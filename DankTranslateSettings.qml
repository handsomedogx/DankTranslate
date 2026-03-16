import QtQuick
import "DependencyUtils.js" as DependencyUtils
import "I18n.js" as I18n
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankTranslate"

    property var dependencyStatus: DependencyUtils.defaultStatus()
    property string translationBackend: "google"
    property string openaiBaseUrl: ""
    property string openaiModel: ""
    property string openaiApiKey: ""
    property string openaiSystemPrompt: I18n.defaultOpenaiSystemPrompt()
    property string openaiUserPrompt: I18n.defaultOpenaiUserPromptTemplate()
    property bool backendTestRunning: false
    property bool backendTestOk: false
    property string backendTestStatus: ""
    property string backendTestResult: ""
    property string backendTestInput: I18n.defaultBackendTestText(uiLanguage)
    property bool settingsSyncScheduled: false
    readonly property string uiLanguage: I18n.detectUiLanguage(Qt.locale().name)
    readonly property string dependencyScriptPath: resolveFilePath("./scripts/check_dependencies.sh")
    readonly property string helperScriptPath: resolveFilePath("./scripts/translate_helper.py")
    readonly property string backendConfigurationMessage: {
        if (translationBackend !== "openai") {
            return "";
        }

        const missing = [];
        if (normalizeText(openaiBaseUrl).length === 0) {
            missing.push(I18n.t(uiLanguage, "backendBaseUrlShort"));
        }
        if (normalizeText(openaiModel).length === 0) {
            missing.push(I18n.t(uiLanguage, "backendModelShort"));
        }
        if (missing.length === 0) {
            return "";
        }
        return I18n.t(uiLanguage, "openaiConfigMissing", {
            "items": I18n.joinList(uiLanguage, missing)
        });
    }

    function resolveFilePath(relativePath) {
        const resolved = Qt.resolvedUrl(relativePath).toString();
        if (resolved.indexOf("file://") === 0) {
            return decodeURIComponent(resolved.slice(7));
        }
        return resolved;
    }

    function normalizeText(value) {
        if (value === undefined || value === null) {
            return "";
        }
        return String(value).trim();
    }

    function syncStoredSettings() {
        translationBackend = root.loadValue("translationBackend", "google") || "google";
        openaiBaseUrl = normalizeText(root.loadValue("openaiBaseUrl", ""));
        openaiModel = normalizeText(root.loadValue("openaiModel", ""));
        openaiApiKey = normalizeText(root.loadValue("openaiApiKey", ""));
        openaiSystemPrompt = root.loadValue("openaiSystemPrompt", I18n.defaultOpenaiSystemPrompt());
        openaiUserPrompt = root.loadValue("openaiUserPrompt", I18n.defaultOpenaiUserPromptTemplate());
        syncBackendDropdown();
    }

    function syncBackendDropdown() {
        if (!backendDropdown) {
            return;
        }
        backendDropdown.currentValue = I18n.backendLabel(uiLanguage, translationBackend);
    }

    function runScheduledSettingsSync() {
        settingsSyncScheduled = false;
        syncStoredSettings();
        refreshDependencyStatus();
    }

    function scheduleSettingsSync() {
        if (settingsSyncScheduled) {
            return;
        }
        settingsSyncScheduled = true;
        Qt.callLater(runScheduledSettingsSync);
    }

    function buildBackendArgs() {
        const args = ["--backend", translationBackend];
        if (translationBackend !== "openai") {
            return args;
        }

        const baseUrl = normalizeText(openaiBaseUrl);
        const model = normalizeText(openaiModel);
        const apiKey = normalizeText(openaiApiKey);

        if (baseUrl.length > 0) {
            args.push("--openai-base-url", baseUrl);
        }
        if (model.length > 0) {
            args.push("--openai-model", model);
        }
        if (apiKey.length > 0) {
            args.push("--openai-api-key", apiKey);
        }
        if (openaiSystemPrompt.length > 0) {
            args.push("--openai-system-prompt", openaiSystemPrompt);
        }
        if (openaiUserPrompt.length > 0) {
            args.push("--openai-user-prompt", openaiUserPrompt);
        }

        return args;
    }

    function resetOpenaiPrompts() {
        openaiSystemPrompt = I18n.defaultOpenaiSystemPrompt();
        openaiUserPrompt = I18n.defaultOpenaiUserPromptTemplate();
        root.saveValue("openaiSystemPrompt", openaiSystemPrompt);
        root.saveValue("openaiUserPrompt", openaiUserPrompt);
    }

    function runBackendTest() {
        const sampleText = normalizeText(backendTestInput);
        if (sampleText.length === 0) {
            backendTestOk = false;
            backendTestStatus = I18n.t(uiLanguage, "backendTestFailed", {
                "error": I18n.t(uiLanguage, "enterTextBeforeTranslating")
            });
            backendTestResult = "";
            return;
        }
        if (backendConfigurationMessage.length > 0) {
            backendTestOk = false;
            backendTestStatus = I18n.t(uiLanguage, "backendTestFailed", {
                "error": backendConfigurationMessage
            });
            backendTestResult = "";
            return;
        }

        backendTestRunning = true;
        backendTestOk = false;
        backendTestStatus = I18n.t(uiLanguage, "testingBackend");
        backendTestResult = "";

        let command = [
            "python3",
            helperScriptPath,
            "test-backend",
            "--text",
            sampleText,
            "--source",
            "auto",
            "--target",
            root.loadValue("targetLang", "auto")
        ];
        command = command.concat(buildBackendArgs());

        Proc.runCommand(
            "dankTranslate.settings.testBackend",
            command,
            (stdout, exitCode) => {
                const raw = (stdout || "").trim();
                let payload = null;

                if (raw.length > 0) {
                    try {
                        payload = JSON.parse(raw);
                    } catch (error) {
                        payload = null;
                    }
                }

                backendTestRunning = false;

                if (payload && payload.ok) {
                    backendTestOk = true;
                    backendTestStatus = I18n.t(uiLanguage, "backendTestSucceeded");
                    backendTestResult = payload.translated_text || "";
                    return;
                }

                backendTestOk = false;
                backendTestStatus = I18n.t(uiLanguage, "backendTestFailed", {
                    "error": payload?.error || (raw.length > 0 ? raw : I18n.t(uiLanguage, "genericRequestFailed"))
                });
                backendTestResult = "";
            },
            0
        );
    }

    function refreshDependencyStatus() {
        const loadingState = DependencyUtils.defaultStatus();
        loadingState.loading = true;
        dependencyStatus = loadingState;

        Proc.runCommand(
            "dankTranslate.settings.dependencies",
            ["sh", dependencyScriptPath, root.loadValue("ocrLanguages", "eng+chi_sim")],
            (stdout, exitCode) => {
                let parsed = DependencyUtils.parseProbeOutput(stdout, uiLanguage);
                parsed.loading = false;
                if (exitCode !== 0 && !parsed.probeError) {
                    parsed.probeError = I18n.t(uiLanguage, "dependencyProbeExitCode", {
                        "code": exitCode
                    });
                }
                dependencyStatus = parsed;
            },
            0
        );
    }

    Component.onCompleted: root.scheduleSettingsSync()

    onPluginServiceChanged: root.scheduleSettingsSync()

    onPluginIdChanged: root.scheduleSettingsSync()

    onUiLanguageChanged: syncBackendDropdown()

    Connections {
        target: root

        function onSettingChanged() {
            root.scheduleSettingsSync();
        }
    }

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId) {
                root.scheduleSettingsSync();
            }
        }
    }

    StyledText {
        width: parent.width
        text: "Dank Translate"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.t(root.uiLanguage, "pluginDescription")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        implicitHeight: backendColumn.implicitHeight + Theme.spacingM * 2

        Column {
            id: backendColumn
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            y: Theme.spacingM
            spacing: Theme.spacingM

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "translationBackend")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "translationBackendDescription")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            DankDropdown {
                id: backendDropdown

                width: parent.width
                text: I18n.t(root.uiLanguage, "translationBackend")
                description: I18n.t(root.uiLanguage, "translationBackendDescription")
                options: I18n.backendOptions(root.uiLanguage)
                currentValue: I18n.backendLabel(root.uiLanguage, root.translationBackend)
                onValueChanged: {
                    const backend = I18n.backendValue(root.uiLanguage, value);
                    root.translationBackend = backend;
                    root.saveValue("translationBackend", backend);
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingS
                visible: root.translationBackend === "openai"

                StyledText {
                    width: parent.width
                    text: I18n.t(root.uiLanguage, "openaiSettings")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                DankTextField {
                    width: parent.width
                    text: root.openaiBaseUrl
                    placeholderText: "http://127.0.0.1:8031/v1"
                    leftIconName: "link"
                    showClearButton: true
                    onTextChanged: root.openaiBaseUrl = text
                    onEditingFinished: {
                        text = root.normalizeText(text);
                        root.openaiBaseUrl = text;
                        root.saveValue("openaiBaseUrl", text);
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.t(root.uiLanguage, "openaiBaseUrlDescription")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                DankTextField {
                    width: parent.width
                    text: root.openaiModel
                    placeholderText: "gpt-4o-mini"
                    leftIconName: "memory"
                    showClearButton: true
                    onTextChanged: root.openaiModel = text
                    onEditingFinished: {
                        text = root.normalizeText(text);
                        root.openaiModel = text;
                        root.saveValue("openaiModel", text);
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.t(root.uiLanguage, "openaiModelDescription")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                DankTextField {
                    width: parent.width
                    text: root.openaiApiKey
                    placeholderText: "optional"
                    leftIconName: "key"
                    showClearButton: true
                    onTextChanged: root.openaiApiKey = text
                    onEditingFinished: {
                        text = root.normalizeText(text);
                        root.openaiApiKey = text;
                        root.saveValue("openaiApiKey", text);
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.t(root.uiLanguage, "openaiApiKeyDescription")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    width: parent.width
                    text: I18n.t(root.uiLanguage, "openaiPromptSettings")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    width: parent.width
                    text: I18n.t(root.uiLanguage, "openaiPromptDescription")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                StyledRect {
                    width: parent.width
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.color: openaiSystemPromptEditor.activeFocus ? Theme.primary : Theme.outlineMedium
                    border.width: openaiSystemPromptEditor.activeFocus ? 2 : 1
                    implicitHeight: Math.max(120, openaiSystemPromptEditor.contentHeight + Theme.spacingM * 2)
                    clip: true

                    TextEdit {
                        id: openaiSystemPromptEditor

                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        text: root.openaiSystemPrompt
                        wrapMode: TextEdit.Wrap
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        selectByMouse: true
                        persistentSelection: true

                        onTextChanged: root.openaiSystemPrompt = text
                        onActiveFocusChanged: {
                            if (!activeFocus) {
                                root.saveValue("openaiSystemPrompt", text);
                            }
                        }
                    }

                    Connections {
                        target: root

                        function onOpenaiSystemPromptChanged() {
                            if (openaiSystemPromptEditor.text !== root.openaiSystemPrompt) {
                                openaiSystemPromptEditor.text = root.openaiSystemPrompt;
                            }
                        }
                    }

                    StyledText {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        text: I18n.t(root.uiLanguage, "openaiSystemPrompt")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                        visible: openaiSystemPromptEditor.text.length === 0 && !openaiSystemPromptEditor.activeFocus
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.t(root.uiLanguage, "openaiSystemPromptDescription")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                StyledRect {
                    width: parent.width
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.color: openaiUserPromptEditor.activeFocus ? Theme.primary : Theme.outlineMedium
                    border.width: openaiUserPromptEditor.activeFocus ? 2 : 1
                    implicitHeight: Math.max(140, openaiUserPromptEditor.contentHeight + Theme.spacingM * 2)
                    clip: true

                    TextEdit {
                        id: openaiUserPromptEditor

                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        text: root.openaiUserPrompt
                        wrapMode: TextEdit.Wrap
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        selectByMouse: true
                        persistentSelection: true

                        onTextChanged: root.openaiUserPrompt = text
                        onActiveFocusChanged: {
                            if (!activeFocus) {
                                root.saveValue("openaiUserPrompt", text);
                            }
                        }
                    }

                    Connections {
                        target: root

                        function onOpenaiUserPromptChanged() {
                            if (openaiUserPromptEditor.text !== root.openaiUserPrompt) {
                                openaiUserPromptEditor.text = root.openaiUserPrompt;
                            }
                        }
                    }

                    StyledText {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        text: I18n.t(root.uiLanguage, "openaiUserPrompt")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                        visible: openaiUserPromptEditor.text.length === 0 && !openaiUserPromptEditor.activeFocus
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.t(root.uiLanguage, "openaiUserPromptDescription")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                DankButton {
                    width: parent.width
                    text: I18n.t(root.uiLanguage, "resetPromptDefaults")
                    iconName: "refresh"
                    onClicked: root.resetOpenaiPrompts()
                }

                StyledText {
                    width: parent.width
                    visible: root.backendConfigurationMessage.length > 0
                    text: root.backendConfigurationMessage
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.warning
                    wrapMode: Text.WordWrap
                }
            }

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "backendTest")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "backendTestDescription")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            DankTextField {
                width: parent.width
                text: root.backendTestInput
                placeholderText: I18n.defaultBackendTestText(root.uiLanguage)
                leftIconName: "edit"
                showClearButton: true
                onTextChanged: root.backendTestInput = text
            }

            DankButton {
                width: parent.width
                text: root.backendTestRunning ? I18n.t(root.uiLanguage, "testingBackend") : I18n.t(root.uiLanguage, "backendTestButton")
                iconName: root.backendTestRunning ? "hourglass_top" : "play_arrow"
                enabled: !root.backendTestRunning && !root.dependencyStatus.loading
                    && root.dependencyStatus.python3 && root.dependencyStatus.helper
                    && root.normalizeText(root.backendTestInput).length > 0
                    && root.backendConfigurationMessage.length === 0
                onClicked: root.runBackendTest()
            }

            StyledText {
                width: parent.width
                visible: root.backendTestStatus.length > 0
                text: root.backendTestStatus
                font.pixelSize: Theme.fontSizeSmall
                color: root.backendTestOk ? Theme.primary : Theme.warning
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: parent.width
                visible: root.backendTestResult.length > 0
                text: I18n.t(root.uiLanguage, "backendTestResult") + ": " + root.backendTestResult
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                wrapMode: Text.WordWrap
            }
        }
    }

    StyledRect {
        width: parent.width
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        implicitHeight: settingsColumn.implicitHeight + Theme.spacingM * 2

        Column {
            id: settingsColumn
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            y: Theme.spacingM
            spacing: Theme.spacingM

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "dependencies")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "dependencyIntro")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            DankDropdown {
                width: parent.width
                text: I18n.t(root.uiLanguage, "translationDirection")
                description: I18n.t(root.uiLanguage, "translationDirectionDescription")
                options: I18n.directionOptions(root.uiLanguage)
                currentValue: I18n.directionLabel(root.uiLanguage, root.loadValue("targetLang", "auto"))
                onValueChanged: root.saveValue("targetLang", I18n.directionValue(root.uiLanguage, value))
            }

            DankDropdown {
                width: parent.width
                text: I18n.t(root.uiLanguage, "screenshotMode")
                description: I18n.t(root.uiLanguage, "screenshotModeDescription")
                options: I18n.screenshotModeOptions(root.uiLanguage)
                currentValue: I18n.screenshotModeLabel(root.uiLanguage, root.loadValue("screenshotMode", "region"))
                onValueChanged: root.saveValue("screenshotMode", I18n.screenshotModeValue(root.uiLanguage, value))
            }

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "ocrLanguages")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DankTextField {
                width: parent.width
                text: root.loadValue("ocrLanguages", "eng+chi_sim")
                placeholderText: "eng+chi_sim"
                leftIconName: "language"
                showClearButton: true
                onEditingFinished: root.saveValue("ocrLanguages", text.trim().length > 0 ? text.trim() : "eng+chi_sim")
            }

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "ocrLanguagesDescription")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }
    }

    StyledRect {
        width: parent.width
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        implicitHeight: diagnosticsColumn.implicitHeight + Theme.spacingM * 2

        Column {
            id: diagnosticsColumn
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            y: Theme.spacingM
            spacing: Theme.spacingS

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "diagnostics")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: dependencyStatus.loading
                    ? I18n.t(root.uiLanguage, "checkingDependencies")
                    : DependencyUtils.formatStatusLine("DMS CLI", dependencyStatus.dms, "", root.uiLanguage)
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: dependencyStatus.loading || dependencyStatus.dms ? Theme.surfaceVariantText : Theme.warning
            }

            StyledText {
                width: parent.width
                text: DependencyUtils.formatStatusLine("python3", dependencyStatus.python3, "", root.uiLanguage)
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: dependencyStatus.python3 ? Theme.surfaceVariantText : Theme.warning
            }

            StyledText {
                width: parent.width
                text: DependencyUtils.formatStatusLine(I18n.t(root.uiLanguage, "translateHelperScript"), dependencyStatus.helper, "", root.uiLanguage)
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: dependencyStatus.helper ? Theme.surfaceVariantText : Theme.warning
            }

            StyledText {
                width: parent.width
                text: DependencyUtils.formatStatusLine("tesseract", dependencyStatus.tesseract, "", root.uiLanguage)
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: dependencyStatus.tesseract ? Theme.surfaceVariantText : Theme.warning
            }

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "requestedOcrLanguages", {
                    "value": dependencyStatus.requiredOcrLanguages.length > 0
                        ? I18n.joinList(root.uiLanguage, dependencyStatus.requiredOcrLanguages)
                        : I18n.t(root.uiLanguage, "none")
                })
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "missingOcrLanguages", {
                    "value": dependencyStatus.missingOcrLanguages.length > 0
                        ? I18n.joinList(root.uiLanguage, dependencyStatus.missingOcrLanguages)
                        : I18n.t(root.uiLanguage, "none")
                })
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: dependencyStatus.missingOcrLanguages.length > 0 ? Theme.warning : Theme.surfaceVariantText
            }

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "installedOcrLanguages", {
                    "value": dependencyStatus.availableOcrLanguages.length > 0
                        ? I18n.joinList(root.uiLanguage, dependencyStatus.availableOcrLanguages)
                        : I18n.t(root.uiLanguage, "unavailable")
                })
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            StyledText {
                width: parent.width
                visible: dependencyStatus.probeError.length > 0
                text: I18n.t(root.uiLanguage, "checkError", {"error": dependencyStatus.probeError})
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.warning
            }

            StyledText {
                width: parent.width
                text: DependencyUtils.getTranslateMessage(dependencyStatus, root.uiLanguage)
                visible: DependencyUtils.getTranslateMessage(dependencyStatus, root.uiLanguage).length > 0
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.warning
            }

            StyledText {
                width: parent.width
                text: DependencyUtils.getScreenshotMessage(dependencyStatus, root.uiLanguage)
                visible: DependencyUtils.getScreenshotMessage(dependencyStatus, root.uiLanguage).length > 0
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.warning
            }

            DankButton {
                width: parent.width
                text: dependencyStatus.loading ? I18n.t(root.uiLanguage, "checkingShort") : I18n.t(root.uiLanguage, "refreshDiagnostics")
                iconName: dependencyStatus.loading ? "hourglass_top" : "refresh"
                enabled: !dependencyStatus.loading
                onClicked: root.refreshDependencyStatus()
            }
        }
    }

    StyledRect {
        width: parent.width
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        implicitHeight: behaviorColumn.implicitHeight + Theme.spacingM * 2

        Column {
            id: behaviorColumn
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            y: Theme.spacingM
            spacing: Theme.spacingM

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "behavior")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            DankDropdown {
                width: parent.width
                text: I18n.t(root.uiLanguage, "autoCopyTranslatedText")
                description: I18n.t(root.uiLanguage, "autoCopyTranslatedTextDescription")
                options: I18n.toggleOptions(root.uiLanguage, false)
                currentValue: I18n.toggleLabel(root.uiLanguage, root.loadValue("autoCopyResult", false))
                onValueChanged: root.saveValue("autoCopyResult", I18n.isEnabledLabel(root.uiLanguage, value))
            }

            DankDropdown {
                width: parent.width
                text: I18n.t(root.uiLanguage, "rememberLastInput")
                description: I18n.t(root.uiLanguage, "rememberLastInputDescription")
                options: I18n.toggleOptions(root.uiLanguage, true)
                currentValue: I18n.toggleLabel(root.uiLanguage, root.loadValue("rememberLastInput", true))
                onValueChanged: root.saveValue("rememberLastInput", I18n.isEnabledLabel(root.uiLanguage, value))
            }
        }
    }

    StyledRect {
        width: parent.width
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        implicitHeight: keybindColumn.implicitHeight + Theme.spacingM * 2

        Column {
            id: keybindColumn
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            y: Theme.spacingM
            spacing: Theme.spacingS

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "suggestedIpcCommands")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "openOrCloseTranslator", {
                    "command": "dms ipc call widget toggle dankTranslate"
                })
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "startScreenshotTranslation", {
                    "command": "dms ipc call widget openWith dankTranslate screenshot"
                })
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            StyledText {
                width: parent.width
                text: I18n.t(root.uiLanguage, "openQuickActionsPanel", {
                    "command": "dms ipc call widget openWith dankTranslate actions"
                })
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
