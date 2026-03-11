import QtQuick
import Quickshell
import Quickshell.Io
import "DependencyUtils.js" as DependencyUtils
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
    property string currentView: "translate"
    property string inputText: ""
    property string translatedText: ""
    property string lastDetectedSource: ""
    property string statusText: ""
    property string lastError: ""
    property string busyLabel: ""
    property bool busy: false
    property var dependencyStatus: DependencyUtils.defaultStatus()

    readonly property string helperScriptPath: resolveFilePath("./scripts/translate_helper.py")
    readonly property string dependencyScriptPath: resolveFilePath("./scripts/check_dependencies.sh")
    readonly property string targetName: languageNameForCode(targetLang)
    readonly property real availableScreenHeight: root.parentScreen?.height ?? Screen.height
    readonly property real maxTranslateViewHeight: Math.max(260, Math.min(680, availableScreenHeight - 180))
    readonly property real maxInputViewportHeight: 220
    readonly property real maxResultViewportHeight: 200
    readonly property bool canTranslateText: dependencyStatus.checked && !dependencyStatus.loading
        && dependencyStatus.dms && dependencyStatus.python3 && dependencyStatus.helper && dependencyStatus.probeError.length === 0
    readonly property bool canScreenshotTranslate: canTranslateText && dependencyStatus.tesseract
        && dependencyStatus.missingOcrLanguages.length === 0
    readonly property string translateDependencyMessage: DependencyUtils.getTranslateMessage(dependencyStatus)
    readonly property string screenshotDependencyMessage: DependencyUtils.getScreenshotMessage(dependencyStatus)
    readonly property string dependencyBannerText: {
        if (translateDependencyMessage.length > 0) {
            return translateDependencyMessage;
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

    function syncSettings() {
        targetLang = pluginData.targetLang || "auto";
        screenshotMode = pluginData.screenshotMode || "region";
        ocrLanguages = pluginData.ocrLanguages || "eng+chi_sim";
        autoCopyResult = pluginData.autoCopyResult ?? false;
        rememberLastInput = pluginData.rememberLastInput ?? true;
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

    function languageNameForCode(languageCode) {
        if (languageCode === "auto") {
            return "Auto";
        }
        if (languageCode === "en") {
            return "English";
        }
        if (languageCode === "zh-CN" || languageCode === "zh") {
            return "中文";
        }
        return languageCode || "Unknown";
    }

    function targetButtonText() {
        if (targetLang === "auto") {
            return "Auto EN/ZH";
        }
        return "To " + targetName;
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

    function findPluginPopout() {
        const items = root.childItems || [];
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (item && typeof item.toggle === "function" && typeof item.close === "function" && item.shouldBeVisible !== undefined) {
                return item;
            }
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

    function openView(viewName) {
        currentView = viewName;
        const popout = findPluginPopout();
        if (popout && popout.shouldBeVisible) {
            return;
        }
        withDefaultPopout(() => root.triggerPopout());
    }

    function toggleView(viewName) {
        const popout = findPluginPopout();
        if (popout && popout.shouldBeVisible && currentView === viewName) {
            popout.close();
            return;
        }
        currentView = viewName;
        if (popout && popout.shouldBeVisible) {
            return;
        }
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
                let parsed = DependencyUtils.parseProbeOutput(stdout);
                parsed.loading = false;
                if (exitCode !== 0 && !parsed.probeError) {
                    parsed.probeError = "Dependency probe exited with code " + exitCode;
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
        ToastService.showError("Dank Translate unavailable", message, "", "dank-translate");
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
            lastError = payload?.error || (raw.length > 0 ? raw : "Translation request failed.");
            statusText = "";
            saveState("lastError", lastError);
            saveState("statusText", statusText);
            ToastService.showError("Dank Translate failed", lastError, "", "dank-translate");
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

        const resolvedTargetName = languageNameForCode(payload.target_language || targetLang);
        statusText = payload.mode === "screenshot"
            ? "Screenshot OCR translated to " + resolvedTargetName
            : "Translated to " + resolvedTargetName;

        saveState("lastInput", inputText);
        saveState("lastTranslation", translatedText);
        saveState("lastDetectedSource", lastDetectedSource);
        saveState("lastError", "");
        saveState("statusText", statusText);

        if (autoCopyResult && translatedText.length > 0) {
            copyText(translatedText, "Translated text copied");
        }

        if (payload.mode === "screenshot") {
            ToastService.showInfo("Screenshot translated", statusText, "", "dank-translate");
        }

        finishJob();
    }

    function translateInput() {
        if (!canTranslateText) {
            showDependencyProblem(translateDependencyMessage);
            return;
        }

        const trimmed = (inputText || "").trim();
        if (trimmed.length === 0) {
            lastError = "Enter some text before translating.";
            saveState("lastError", lastError);
            return;
        }

        persistLiveInput();
        startJob("Translating text...");

        Proc.runCommand(
            "dankTranslate.translate",
            ["python3", helperScriptPath, "translate", "--text", trimmed, "--source", "auto", "--target", targetLang],
            (stdout, exitCode) => applyResponse(stdout, exitCode),
            0
        );
    }

    function screenshotTranslate() {
        if (!canScreenshotTranslate) {
            showDependencyProblem(screenshotDependencyMessage.length > 0 ? screenshotDependencyMessage : translateDependencyMessage);
            return;
        }

        startJob("Select an area for screenshot translation...");
        closePopout();

        Proc.runCommand(
            "dankTranslate.screenshot",
            [
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
            ],
            (stdout, exitCode) => applyResponse(stdout, exitCode),
            0
        );
    }

    function headerText() {
        return currentView === "actions" ? "Dank Translate Actions" : "Dank Translate";
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
            return "Right click the bar icon for quick actions, or bind the IPC targets for keyboard access.";
        }
        if (targetLang === "auto") {
            return "Auto-detect Chinese vs English input and translate to the opposite language. Use Ctrl+Enter to translate from the editor.";
        }
        return "Auto-detect input text and translate it to " + targetName + ". Use Ctrl+Enter to translate from the editor.";
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

            Item {
                width: parent.width
                implicitHeight: Math.min(popoutColumn.maxBodyHeight, popoutBodyFlick.contentHeight)
                height: implicitHeight

                DankFlickable {
                    id: popoutBodyFlick

                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: popoutBodyColumn.implicitHeight
                    clip: true

                    Column {
                        id: popoutBodyColumn
                        width: popoutBodyFlick.width
                        spacing: Theme.spacingM

                        Loader {
                            width: parent.width
                            active: root.currentView === "actions"
                            sourceComponent: actionsView
                        }

                        Loader {
                            width: parent.width
                            active: root.currentView === "translate"
                            sourceComponent: translateView
                        }
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
                                text: "Quick actions for keyboard-first use."
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeMedium
                                wrapMode: Text.WordWrap
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankButton {
                                    width: (parent.width - Theme.spacingS) / 2
                                    text: "Open Translator"
                                    iconName: "translate"
                                    onClicked: root.openView("translate")
                                }

                                DankButton {
                                    width: (parent.width - Theme.spacingS) / 2
                                    text: "Screenshot OCR"
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
                                    text: "Clear Results"
                                    iconName: "delete"
                                    onClicked: root.clearResults()
                                }
                            }

                            DankButton {
                                width: parent.width
                                text: root.dependencyStatus.loading ? "Checking dependencies..." : "Refresh Dependency Check"
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
                                text: "Suggested keybind IPC targets"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                width: parent.width
                                text: DependencyUtils.formatStatusLine("Text translation", root.canTranslateText, root.translateDependencyMessage)
                                wrapMode: Text.WordWrap
                                font.pixelSize: Theme.fontSizeSmall
                                color: root.canTranslateText ? Theme.surfaceVariantText : Theme.warning
                            }

                            StyledText {
                                width: parent.width
                                text: DependencyUtils.formatStatusLine("Screenshot OCR", root.canScreenshotTranslate, root.screenshotDependencyMessage)
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
                                text: root.dependencyStatus.loading ? "Checking dependencies..." : "Runtime checks"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                width: parent.width
                                text: root.dependencyStatus.loading
                                    ? "Validating python3, tesseract, helper scripts, and OCR language packs."
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
                            text: "Screenshot"
                            iconName: "image_search"
                            enabled: !root.busy && root.canScreenshotTranslate
                            onClicked: root.screenshotTranslate()
                        }

                        DankButton {
                            width: (parent.width - Theme.spacingS * 2) / 3
                            text: "Actions"
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
                                text: "Type or paste a word or sentence here. Press Ctrl+Enter to translate."
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
                            text: root.dependencyStatus.loading ? "Checking..." : (root.busy ? "Working..." : "Translate")
                            iconName: root.busy ? "hourglass_top" : "send"
                            enabled: !root.busy && root.canTranslateText
                            onClicked: root.translateInput()
                        }

                        DankButton {
                            width: (parent.width - Theme.spacingS * 2) / 3
                            text: "Copy Result"
                            iconName: "content_copy"
                            enabled: root.translatedText.length > 0
                            onClicked: root.copyText(root.translatedText, "Translated text copied")
                        }

                        DankButton {
                            width: (parent.width - Theme.spacingS * 2) / 3
                            text: "Clear"
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
                                text: "Translation"
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
                                    text: root.translatedText.length > 0 ? root.translatedText : "Translated text will appear here."
                                    wrapMode: Text.WordWrap
                                    color: root.translatedText.length > 0 ? Theme.surfaceText : Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                            }

                            StyledText {
                                width: parent.width
                                visible: root.lastDetectedSource.length > 0
                                text: "Detected source: " + root.lastDetectedSource
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
