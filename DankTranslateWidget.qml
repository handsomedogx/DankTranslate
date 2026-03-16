import QtQuick
import Quickshell
import Quickshell.Io
import "DependencyUtils.js" as DependencyUtils
import "I18n.js" as I18n
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "dank-translate"

    property string targetLang: "auto"
    property string screenshotMode: "region"
    property string ocrLanguages: "eng+chi_sim"
    property bool autoCopyResult: false
    property bool rememberLastInput: true
    property string translationBackend: "google"
    property string openaiBaseUrl: ""
    property string openaiModel: ""
    property string openaiApiKey: ""
    property string openaiSystemPrompt: I18n.defaultOpenaiSystemPrompt()
    property string openaiUserPrompt: I18n.defaultOpenaiUserPromptTemplate()
    property string currentView: "translate"
    property string inputText: ""
    property string translatedText: ""
    property string lastDetectedSource: ""
    property string statusText: ""
    property string lastError: ""
    property string busyLabel: ""
    property bool busy: false
    property var dependencyStatus: DependencyUtils.defaultStatus()
    property var livePopout: null

    readonly property string helperScriptPath: resolveFilePath("./scripts/translate_helper.py")
    readonly property string dependencyScriptPath: resolveFilePath("./scripts/check_dependencies.sh")
    readonly property string uiLanguage: I18n.detectUiLanguage(Qt.locale().name)
    readonly property string targetName: I18n.languageName(uiLanguage, targetLang)
    readonly property real availableScreenHeight: root.parentScreen?.height ?? Screen.height
    readonly property real maxTranslateViewHeight: Math.max(260, Math.min(680, availableScreenHeight - 180))
    readonly property real maxInputViewportHeight: 220
    readonly property real maxResultViewportHeight: 200
    readonly property string backendConfigurationMessage: {
        if (translationBackend !== "openai") {
            return "";
        }

        const missing = [];
        if (normalizeSettingText(openaiBaseUrl).length === 0) {
            missing.push(I18n.t(uiLanguage, "backendBaseUrlShort"));
        }
        if (normalizeSettingText(openaiModel).length === 0) {
            missing.push(I18n.t(uiLanguage, "backendModelShort"));
        }
        if (missing.length === 0) {
            return "";
        }
        return I18n.t(uiLanguage, "openaiConfigMissing", {
            "items": I18n.joinList(uiLanguage, missing)
        });
    }
    readonly property bool canTranslateText: dependencyStatus.checked && !dependencyStatus.loading
        && dependencyStatus.dms && dependencyStatus.python3 && dependencyStatus.helper
        && dependencyStatus.probeError.length === 0 && backendConfigurationMessage.length === 0
    readonly property bool canScreenshotTranslate: canTranslateText && dependencyStatus.tesseract
        && dependencyStatus.missingOcrLanguages.length === 0
    readonly property string translateDependencyMessage: DependencyUtils.getTranslateMessage(dependencyStatus, uiLanguage)
    readonly property string screenshotDependencyMessage: DependencyUtils.getScreenshotMessage(dependencyStatus, uiLanguage)
    readonly property string dependencyBannerText: {
        if (translateDependencyMessage.length > 0) {
            return translateDependencyMessage;
        }
        if (backendConfigurationMessage.length > 0) {
            return backendConfigurationMessage;
        }
        if (screenshotDependencyMessage.length > 0) {
            return screenshotDependencyMessage;
        }
        return "";
    }

    function resolveFilePath(relativePath) {
        const resolved = Qt.resolvedUrl(relativePath).toString();
        if (resolved.indexOf("file://") === 0) {
            return decodeURIComponent(resolved.slice(7));
        }
        return resolved;
    }

    function normalizeSettingText(value) {
        if (value === undefined || value === null) {
            return "";
        }
        return String(value).trim();
    }

    function syncSettings() {
        targetLang = pluginData.targetLang || "auto";
        screenshotMode = pluginData.screenshotMode || "region";
        ocrLanguages = pluginData.ocrLanguages || "eng+chi_sim";
        autoCopyResult = pluginData.autoCopyResult ?? false;
        rememberLastInput = pluginData.rememberLastInput ?? true;
        translationBackend = pluginData.translationBackend || "google";
        openaiBaseUrl = normalizeSettingText(pluginData.openaiBaseUrl || "");
        openaiModel = normalizeSettingText(pluginData.openaiModel || "");
        openaiApiKey = normalizeSettingText(pluginData.openaiApiKey || "");
        openaiSystemPrompt = pluginData.openaiSystemPrompt || I18n.defaultOpenaiSystemPrompt();
        openaiUserPrompt = pluginData.openaiUserPrompt || I18n.defaultOpenaiUserPromptTemplate();
        refreshDependencyStatus();
    }

    function restoreState() {
        if (!pluginService || !pluginId) {
            return;
        }

        inputText = rememberLastInput ? (pluginService.loadPluginState(pluginId, "lastInput", "") || "") : "";
        translatedText = pluginService.loadPluginState(pluginId, "lastTranslation", "") || "";
        lastDetectedSource = pluginService.loadPluginState(pluginId, "lastDetectedSource", "") || "";
        lastError = pluginService.loadPluginState(pluginId, "lastError", "") || "";
        statusText = pluginService.loadPluginState(pluginId, "statusText", "") || "";
    }

    function saveState(key, value) {
        if (pluginService && pluginId) {
            pluginService.savePluginState(pluginId, key, value);
        }
    }

    function saveSetting(key, value) {
        if (pluginService && pluginId) {
            pluginService.savePluginData(pluginId, key, value);
        }
    }

    function updateTargetLang(languageCode) {
        targetLang = languageCode;
        saveSetting("targetLang", languageCode);
    }

    function targetButtonText() {
        return I18n.targetButtonText(uiLanguage, targetLang);
    }

    function toggleTargetLang() {
        if (targetLang === "auto") {
            updateTargetLang("zh-CN");
            return;
        }
        if (targetLang === "zh-CN") {
            updateTargetLang("en");
            return;
        }
        updateTargetLang("auto");
    }

    function persistLiveInput() {
        if (rememberLastInput) {
            saveState("lastInput", inputText);
        }
    }

    function buildTranslationBackendArgs() {
        const args = ["--backend", translationBackend];
        if (translationBackend !== "openai") {
            return args;
        }

        const baseUrl = normalizeSettingText(openaiBaseUrl);
        const model = normalizeSettingText(openaiModel);
        const apiKey = normalizeSettingText(openaiApiKey);

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

    function findPluginPopout() {
        if (livePopout && livePopout.shouldBeVisible !== undefined) {
            return livePopout;
        }
        return null;
    }

    function withDefaultPopout(callback) {
        const originalClickAction = root.pillClickAction;
        root.pillClickAction = null;
        try {
            callback();
        } finally {
            root.pillClickAction = originalClickAction;
        }
    }

    function deferVisibleViewChange(viewName) {
        Qt.callLater(() => {
            const livePopout = findPluginPopout();
            if (livePopout && livePopout.shouldBeVisible) {
                currentView = viewName;
            }
        });
    }

    function openView(viewName) {
        const popout = findPluginPopout();
        if (popout && popout.shouldBeVisible) {
            if (currentView !== viewName) {
                deferVisibleViewChange(viewName);
            }
            return;
        }
        currentView = viewName;
        withDefaultPopout(() => root.triggerPopout());
    }

    function toggleView(viewName) {
        const popout = findPluginPopout();
        if (popout && popout.shouldBeVisible && currentView === viewName) {
            popout.close();
            return;
        }
        if (popout && popout.shouldBeVisible) {
            deferVisibleViewChange(viewName);
            return;
        }
        currentView = viewName;
        withDefaultPopout(() => root.triggerPopout());
    }

    function openWithMode(mode) {
        const selectedMode = mode || "translate";
        if (selectedMode === "screenshot") {
            screenshotTranslate();
            return;
        }
        if (selectedMode === "actions") {
            openView("actions");
            return;
        }
        if (selectedMode === "toggle-target") {
            toggleTargetLang();
            return;
        }
        openView("translate");
    }

    function toggleWithMode(mode) {
        const selectedMode = mode || "translate";
        if (selectedMode === "screenshot") {
            screenshotTranslate();
            return;
        }
        if (selectedMode === "actions") {
            toggleView("actions");
            return;
        }
        if (selectedMode === "toggle-target") {
            toggleTargetLang();
            return;
        }
        toggleView("translate");
    }

    function clearResults() {
        translatedText = "";
        lastDetectedSource = "";
        statusText = "";
        lastError = "";
        saveState("lastTranslation", translatedText);
        saveState("lastDetectedSource", lastDetectedSource);
        saveState("statusText", statusText);
        saveState("lastError", lastError);
    }

    function resetAll() {
        inputText = "";
        clearResults();
        saveState("lastInput", "");
    }

    function copyText(text, successMessage) {
        const normalized = (text || "").trim();
        if (!normalized) {
            return;
        }
        Quickshell.execDetached(["dms", "cl", "copy", normalized]);
        ToastService.showInfo(successMessage, "", "", "dank-translate");
    }

    function startJob(label) {
        busy = true;
        busyLabel = label;
        lastError = "";
        statusText = label;
        saveState("lastError", "");
        saveState("statusText", statusText);
    }

    function finishJob() {
        busy = false;
        busyLabel = "";
    }

    function refreshDependencyStatus() {
        const loadingState = DependencyUtils.defaultStatus();
        loadingState.loading = true;
        dependencyStatus = loadingState;

        Proc.runCommand(
            "dankTranslate.dependencies",
            ["sh", dependencyScriptPath, ocrLanguages],
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

    function showDependencyProblem(message) {
        if (!message || message.length === 0) {
            return;
        }
        lastError = message;
        saveState("lastError", lastError);
        ToastService.showError(I18n.t(uiLanguage, "pluginUnavailableTitle"), message, "", "dank-translate");
    }

    function applyResponse(stdout, exitCode) {
        let payload = null;
        const raw = (stdout || "").trim();

        if (raw.length > 0) {
            try {
                payload = JSON.parse(raw);
            } catch (error) {
                payload = null;
            }
        }

        if (payload?.cancelled) {
            lastError = "";
            statusText = "";
            saveState("lastError", "");
            saveState("statusText", "");
            finishJob();
            return;
        }

        if (!payload || !payload.ok) {
            lastError = payload?.error || (raw.length > 0 ? raw : I18n.t(uiLanguage, "genericRequestFailed"));
            statusText = "";
            saveState("lastError", lastError);
            saveState("statusText", statusText);
            ToastService.showError(I18n.t(uiLanguage, "pluginFailedTitle"), lastError, "", "dank-translate");
            finishJob();
            return;
        }

        inputText = payload.input_text || inputText;
        translatedText = payload.translated_text || "";
        lastDetectedSource = payload.detected_source || "";
        lastError = "";

        if (payload.mode === "screenshot") {
            currentView = "translate";
            openView("translate");
        }

        const resolvedTargetName = I18n.languageName(uiLanguage, payload.target_language || targetLang);
        statusText = payload.mode === "screenshot"
            ? I18n.t(uiLanguage, "screenshotTranslatedTo", {"language": resolvedTargetName})
            : I18n.t(uiLanguage, "translatedTo", {"language": resolvedTargetName});

        saveState("lastInput", inputText);
        saveState("lastTranslation", translatedText);
        saveState("lastDetectedSource", lastDetectedSource);
        saveState("lastError", "");
        saveState("statusText", statusText);

        if (autoCopyResult && translatedText.length > 0) {
            copyText(translatedText, I18n.t(uiLanguage, "translatedTextCopied"));
        }

        if (payload.mode === "screenshot") {
            ToastService.showInfo(I18n.t(uiLanguage, "screenshotTranslatedTitle"), statusText, "", "dank-translate");
        }

        finishJob();
    }

    function translateInput() {
        if (!canTranslateText) {
            showDependencyProblem(translateDependencyMessage.length > 0 ? translateDependencyMessage : backendConfigurationMessage);
            return;
        }

        const trimmed = (inputText || "").trim();
        if (trimmed.length === 0) {
            lastError = I18n.t(uiLanguage, "enterTextBeforeTranslating");
            saveState("lastError", lastError);
            return;
        }

        persistLiveInput();
        startJob(I18n.t(uiLanguage, "translatingText"));

        let command = [
            "python3",
            helperScriptPath,
            "translate",
            "--text",
            trimmed,
            "--source",
            "auto",
            "--target",
            targetLang
        ];
        command = command.concat(buildTranslationBackendArgs());

        Proc.runCommand(
            "dankTranslate.translate",
            command,
            (stdout, exitCode) => applyResponse(stdout, exitCode),
            0
        );
    }

    function screenshotTranslate() {
        if (!canScreenshotTranslate) {
            showDependencyProblem(
                screenshotDependencyMessage.length > 0
                    ? screenshotDependencyMessage
                    : (translateDependencyMessage.length > 0 ? translateDependencyMessage : backendConfigurationMessage)
            );
            return;
        }

        startJob(I18n.t(uiLanguage, "selectScreenshotArea"));
        closePopout();

        let command = [
            "python3",
            helperScriptPath,
            "screenshot",
            "--source",
            "auto",
            "--target",
            targetLang,
            "--mode",
            screenshotMode,
            "--ocr-languages",
            ocrLanguages
        ];
        command = command.concat(buildTranslationBackendArgs());

        Proc.runCommand(
            "dankTranslate.screenshot",
            command,
            (stdout, exitCode) => applyResponse(stdout, exitCode),
            0
        );
    }

    function headerText() {
        return currentView === "actions" ? I18n.t(uiLanguage, "actionsHeader") : "Dank Translate";
    }

    function detailsText() {
        if (busy && busyLabel.length > 0) {
            return busyLabel;
        }
        if (lastError.length > 0) {
            return lastError;
        }
        if (statusText.length > 0) {
            return statusText;
        }
        if (currentView === "actions") {
            return I18n.t(uiLanguage, "actionsDetails");
        }
        if (targetLang === "auto") {
            return I18n.t(uiLanguage, "autoDetails");
        }
        return I18n.t(uiLanguage, "fixedDetails", {
            "language": targetName
        });
    }

    Component.onCompleted: {
        syncSettings();
        restoreState();
    }

    onPluginServiceChanged: restoreState()
    onPluginIdChanged: restoreState()
    onPluginDataChanged: syncSettings()

    IpcHandler {
        target: "dankTranslate"

        function toggle(): string {
            root.toggleView("translate");
            return "DANK_TRANSLATE_TOGGLED";
        }

        function quickActions(): string {
            root.openView("actions");
            return "DANK_TRANSLATE_ACTIONS_OPENED";
        }

        function screenshot(): string {
            root.screenshotTranslate();
            return "DANK_TRANSLATE_SCREENSHOT_STARTED";
        }

        function close(): string {
            root.closePopout();
            return "DANK_TRANSLATE_CLOSED";
        }

        function toggleTarget(): string {
            root.toggleTargetLang();
            return "DANK_TRANSLATE_TARGET_" + root.targetLang;
        }
    }

    pillClickAction: () => root.toggleView("translate")
    pillRightClickAction: () => root.openView("actions")

    horizontalBarPill: Component {
        Row {
            DankIcon {
                name: root.busy ? "hourglass_top" : "translate"
                size: root.iconSize - 2
                color: root.busy ? Theme.warning : Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            DankIcon {
                name: root.busy ? "hourglass_top" : "translate"
                size: root.iconSize - 2
                color: root.busy ? Theme.warning : Theme.primary
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutWidth: 460
    popoutHeight: 0

    popoutContent: Component {
        PopoutComponent {
            id: popoutColumn

            headerText: root.headerText()
            detailsText: root.detailsText()
            showCloseButton: true
            readonly property real maxBodyHeight: root.maxTranslateViewHeight

            onParentPopoutChanged: {
                if (parentPopout) {
                    root.livePopout = parentPopout;
                }
            }

            Item {
                width: parent.width
                implicitHeight: Math.min(popoutColumn.maxBodyHeight, popoutBodyFlick.contentHeight)
                height: implicitHeight

                DankFlickable {
                    id: popoutBodyFlick

                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: popoutBodyLoader.item ? popoutBodyLoader.item.implicitHeight : 0
                    clip: true

                    Loader {
                        id: popoutBodyLoader

                        width: popoutBodyFlick.width
                        sourceComponent: root.currentView === "actions" ? actionsView : translateView
                    }
                }
            }

            Component {
                id: actionsView

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledRect {
                        width: parent.width
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        implicitHeight: actionsColumn.implicitHeight + Theme.spacingM * 2
                        height: implicitHeight

                        Column {
                            id: actionsColumn
                            width: parent.width - Theme.spacingM * 2
                            x: Theme.spacingM
                            y: Theme.spacingM
                            spacing: Theme.spacingM

                            StyledText {
                                width: parent.width
                                text: I18n.t(root.uiLanguage, "quickActionsIntro")
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeMedium
                                wrapMode: Text.WordWrap
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankButton {
                                    width: (parent.width - Theme.spacingS) / 2
                                    text: I18n.t(root.uiLanguage, "openTranslator")
                                    iconName: "translate"
                                    onClicked: root.openView("translate")
                                }

                                DankButton {
                                    width: (parent.width - Theme.spacingS) / 2
                                    text: I18n.t(root.uiLanguage, "screenshotOcr")
                                    iconName: "image_search"
                                    enabled: !root.busy && root.canScreenshotTranslate
                                    onClicked: root.screenshotTranslate()
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankButton {
                                    width: (parent.width - Theme.spacingS) / 2
                                    text: root.targetButtonText()
                                    iconName: "swap_horiz"
                                    onClicked: root.toggleTargetLang()
                                }

                                DankButton {
                                    width: (parent.width - Theme.spacingS) / 2
                                    text: I18n.t(root.uiLanguage, "clearResults")
                                    iconName: "delete"
                                    onClicked: root.clearResults()
                                }
                            }

                            DankButton {
                                width: parent.width
                                text: root.dependencyStatus.loading
                                    ? I18n.t(root.uiLanguage, "checkingDependencies")
                                    : I18n.t(root.uiLanguage, "refreshDependencyCheck")
                                iconName: root.dependencyStatus.loading ? "hourglass_top" : "refresh"
                                enabled: !root.dependencyStatus.loading
                                onClicked: root.refreshDependencyStatus()
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        implicitHeight: keybindColumn.implicitHeight + Theme.spacingM * 2
                        height: implicitHeight

                        Column {
                            id: keybindColumn
                            width: parent.width - Theme.spacingM * 2
                            x: Theme.spacingM
                            y: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                width: parent.width
                                text: I18n.t(root.uiLanguage, "suggestedKeybindTargets")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                width: parent.width
                                text: DependencyUtils.formatStatusLine(
                                    I18n.t(root.uiLanguage, "textTranslation"),
                                    root.canTranslateText,
                                    root.translateDependencyMessage,
                                    root.uiLanguage
                                )
                                wrapMode: Text.WordWrap
                                font.pixelSize: Theme.fontSizeSmall
                                color: root.canTranslateText ? Theme.surfaceVariantText : Theme.warning
                            }

                            StyledText {
                                width: parent.width
                                text: DependencyUtils.formatStatusLine(
                                    I18n.t(root.uiLanguage, "screenshotOcr"),
                                    root.canScreenshotTranslate,
                                    root.screenshotDependencyMessage,
                                    root.uiLanguage
                                )
                                wrapMode: Text.WordWrap
                                font.pixelSize: Theme.fontSizeSmall
                                color: root.canScreenshotTranslate ? Theme.surfaceVariantText : Theme.warning
                            }

                            StyledText {
                                width: parent.width
                                text: "dms ipc call widget toggle dankTranslate"
                                wrapMode: Text.WordWrap
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                width: parent.width
                                text: "dms ipc call widget openWith dankTranslate screenshot"
                                wrapMode: Text.WordWrap
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                width: parent.width
                                text: "dms ipc call widget openWith dankTranslate actions"
                                wrapMode: Text.WordWrap
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }
            }

            Component {
                id: translateView

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    function requestInputFocus() {
                        Qt.callLater(() => {
                            inputEditor.forceActiveFocus();
                            inputEditor.ensureCursorVisible();
                        });
                    }

                    Component.onCompleted: requestInputFocus()

                    Connections {
                        target: root

                        function onInputTextChanged() {
                            if (inputEditor.text !== root.inputText) {
                                inputEditor.text = root.inputText;
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        visible: root.dependencyStatus.loading || root.dependencyBannerText.length > 0
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        border.color: root.dependencyBannerText.length > 0 ? Theme.warning : Theme.outlineMedium
                        border.width: root.dependencyBannerText.length > 0 ? 2 : 1
                        implicitHeight: dependencyBannerColumn.implicitHeight + Theme.spacingM * 2
                        height: implicitHeight

                        Column {
                            id: dependencyBannerColumn
                            width: parent.width - Theme.spacingM * 2
                            x: Theme.spacingM
                            y: Theme.spacingM
                            spacing: Theme.spacingXS

                                    StyledText {
                                        width: parent.width
                                        text: root.dependencyStatus.loading
                                            ? I18n.t(root.uiLanguage, "checkingDependencies")
                                            : I18n.t(root.uiLanguage, "runtimeChecks")
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.DemiBold
                                        color: Theme.surfaceText
                            }

                                    StyledText {
                                        width: parent.width
                                        text: root.dependencyStatus.loading
                                            ? I18n.t(root.uiLanguage, "validatingDependencies")
                                            : root.dependencyBannerText
                                        wrapMode: Text.WordWrap
                                        color: root.dependencyBannerText.length > 0 ? Theme.warning : Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankButton {
                            width: (parent.width - Theme.spacingS * 2) / 3
                            text: root.targetButtonText()
                            iconName: "swap_horiz"
                            onClicked: root.toggleTargetLang()
                        }

                        DankButton {
                            width: (parent.width - Theme.spacingS * 2) / 3
                            text: I18n.t(root.uiLanguage, "screenshot")
                            iconName: "image_search"
                            enabled: !root.busy && root.canScreenshotTranslate
                            onClicked: root.screenshotTranslate()
                        }

                        DankButton {
                            width: (parent.width - Theme.spacingS * 2) / 3
                            text: I18n.t(root.uiLanguage, "actions")
                            iconName: "more_horiz"
                            onClicked: root.openView("actions")
                        }
                    }

                    StyledRect {
                        width: parent.width
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        border.color: inputEditor.activeFocus ? Theme.primary : Theme.outlineMedium
                        border.width: inputEditor.activeFocus ? 2 : 1
                        implicitHeight: Math.max(140, Math.min(root.maxInputViewportHeight, Math.max(100, inputEditor.contentHeight)) + Theme.spacingM * 2)
                        height: implicitHeight
                        clip: true

                        DankFlickable {
                            id: inputFlickable

                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            contentWidth: width
                            contentHeight: Math.max(height, inputEditor.contentHeight)
                            clip: true

                            TextEdit {
                                id: inputEditor

                                width: inputFlickable.width
                                height: Math.max(inputFlickable.height, contentHeight)
                                text: root.inputText
                                wrapMode: TextEdit.Wrap
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                selectByMouse: true
                                persistentSelection: true

                                function ensureCursorVisible() {
                                    const top = cursorRectangle.y;
                                    const bottom = cursorRectangle.y + cursorRectangle.height;
                                    if (top < inputFlickable.contentY) {
                                        inputFlickable.contentY = Math.max(0, top - Theme.spacingS);
                                    } else if (bottom > inputFlickable.contentY + inputFlickable.height) {
                                        inputFlickable.contentY = Math.min(
                                            inputFlickable.contentHeight - inputFlickable.height,
                                            bottom - inputFlickable.height + Theme.spacingS
                                        );
                                    }
                                }

                                onTextChanged: {
                                    root.inputText = text;
                                    root.persistLiveInput();
                                    ensureCursorVisible();
                                }

                                onCursorRectangleChanged: ensureCursorVisible()

                                Keys.onPressed: event => {
                                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                                        root.translateInput();
                                        event.accepted = true;
                                    }
                                }
                            }

                            StyledText {
                                width: inputFlickable.width
                                text: I18n.t(root.uiLanguage, "inputPlaceholder")
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeMedium
                                wrapMode: Text.WordWrap
                                visible: inputEditor.text.length === 0 && !inputEditor.activeFocus
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankButton {
                            width: (parent.width - Theme.spacingS * 2) / 3
                            text: root.dependencyStatus.loading
                                ? I18n.t(root.uiLanguage, "checkingShort")
                                : (root.busy ? I18n.t(root.uiLanguage, "working") : I18n.t(root.uiLanguage, "translate"))
                            iconName: root.busy ? "hourglass_top" : "send"
                            enabled: !root.busy && root.canTranslateText
                            onClicked: root.translateInput()
                        }

                        DankButton {
                            width: (parent.width - Theme.spacingS * 2) / 3
                            text: I18n.t(root.uiLanguage, "copyResult")
                            iconName: "content_copy"
                            enabled: root.translatedText.length > 0
                            onClicked: root.copyText(root.translatedText, I18n.t(root.uiLanguage, "translatedTextCopied"))
                        }

                        DankButton {
                            width: (parent.width - Theme.spacingS * 2) / 3
                            text: I18n.t(root.uiLanguage, "clear")
                            iconName: "delete"
                            enabled: root.inputText.length > 0 || root.translatedText.length > 0
                            onClicked: root.resetAll()
                        }
                    }

                    StyledRect {
                        width: parent.width
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        implicitHeight: translationColumn.implicitHeight + Theme.spacingM * 2
                        height: implicitHeight

                        Column {
                            id: translationColumn
                            width: parent.width - Theme.spacingM * 2
                            x: Theme.spacingM
                            y: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                width: parent.width
                                text: I18n.t(root.uiLanguage, "translation")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }

                            DankFlickable {
                                id: translationFlickable

                                width: parent.width
                                height: Math.min(root.maxResultViewportHeight, Math.max(72, translationText.implicitHeight))
                                contentWidth: width
                                contentHeight: Math.max(height, translationText.implicitHeight)
                                clip: true

                                StyledText {
                                    id: translationText

                                    width: translationFlickable.width
                                    text: root.translatedText.length > 0 ? root.translatedText : I18n.t(root.uiLanguage, "translationPlaceholder")
                                    wrapMode: Text.WordWrap
                                    color: root.translatedText.length > 0 ? Theme.surfaceText : Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                            }

                            StyledText {
                                width: parent.width
                                visible: root.lastDetectedSource.length > 0
                                text: I18n.t(root.uiLanguage, "detectedSource", {"value": root.lastDetectedSource})
                                wrapMode: Text.WordWrap
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }

                }
            }
        }
    }
}
