import QtQuick
import "DependencyUtils.js" as DependencyUtils
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankTranslate"

    property var dependencyStatus: DependencyUtils.defaultStatus()
    readonly property string dependencyScriptPath: resolveFilePath("./scripts/check_dependencies.sh")

    function resolveFilePath(relativePath) {
        const resolved = Qt.resolvedUrl(relativePath).toString();
        if (resolved.indexOf("file://") === 0) {
            return decodeURIComponent(resolved.slice(7));
        }
        return resolved;
    }

    function refreshDependencyStatus() {
        const loadingState = DependencyUtils.defaultStatus();
        loadingState.loading = true;
        dependencyStatus = loadingState;

        Proc.runCommand(
            "dankTranslate.settings.dependencies",
            ["sh", dependencyScriptPath, root.loadValue("ocrLanguages", "eng+chi_sim")],
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

    Component.onCompleted: refreshDependencyStatus()

    Connections {
        target: root

        function onSettingChanged() {
            root.refreshDependencyStatus();
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
        text: "A bar translation plugin with popup translation, keyboard-triggered IPC entry points, and screenshot OCR translation."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
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
                text: "Dependencies"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: "Required tools: python3, tesseract, and the DMS CLI. For Chinese OCR install the Tesseract language data for chi_sim in addition to eng."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            DankDropdown {
                width: parent.width
                text: "Translation direction"
                description: "Auto translates Chinese to English and English to Chinese. You can still force a fixed target."
                options: ["Auto", "中文", "English"]
                currentValue: {
                    const value = root.loadValue("targetLang", "auto");
                    if (value === "en") {
                        return "English";
                    }
                    if (value === "zh-CN") {
                        return "中文";
                    }
                    return "Auto";
                }
                onValueChanged: {
                    if (value === "English") {
                        root.saveValue("targetLang", "en");
                    } else if (value === "中文") {
                        root.saveValue("targetLang", "zh-CN");
                    } else {
                        root.saveValue("targetLang", "auto");
                    }
                }
            }

            DankDropdown {
                width: parent.width
                text: "Screenshot mode"
                description: "The mode used when starting screenshot translation from the icon or IPC shortcut."
                options: ["region", "full", "window", "all"]
                currentValue: root.loadValue("screenshotMode", "region")
                onValueChanged: root.saveValue("screenshotMode", value)
            }

            StyledText {
                width: parent.width
                text: "OCR languages"
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
                text: "Use Tesseract language codes joined by +, for example eng+chi_sim."
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
                text: "Diagnostics"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: dependencyStatus.loading
                    ? "Checking dependencies..."
                    : DependencyUtils.formatStatusLine("DMS CLI", dependencyStatus.dms, "")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: dependencyStatus.loading || dependencyStatus.dms ? Theme.surfaceVariantText : Theme.warning
            }

            StyledText {
                width: parent.width
                text: DependencyUtils.formatStatusLine("python3", dependencyStatus.python3, "")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: dependencyStatus.python3 ? Theme.surfaceVariantText : Theme.warning
            }

            StyledText {
                width: parent.width
                text: DependencyUtils.formatStatusLine("Translate helper", dependencyStatus.helper, "")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: dependencyStatus.helper ? Theme.surfaceVariantText : Theme.warning
            }

            StyledText {
                width: parent.width
                text: DependencyUtils.formatStatusLine("tesseract", dependencyStatus.tesseract, "")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: dependencyStatus.tesseract ? Theme.surfaceVariantText : Theme.warning
            }

            StyledText {
                width: parent.width
                text: "Requested OCR languages: " + (dependencyStatus.requiredOcrLanguages.length > 0 ? dependencyStatus.requiredOcrLanguages.join(", ") : "none")
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            StyledText {
                width: parent.width
                text: dependencyStatus.missingOcrLanguages.length > 0
                    ? "Missing OCR languages: " + dependencyStatus.missingOcrLanguages.join(", ")
                    : "Missing OCR languages: none"
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: dependencyStatus.missingOcrLanguages.length > 0 ? Theme.warning : Theme.surfaceVariantText
            }

            StyledText {
                width: parent.width
                text: dependencyStatus.availableOcrLanguages.length > 0
                    ? "Installed OCR languages: " + dependencyStatus.availableOcrLanguages.join(", ")
                    : "Installed OCR languages: unavailable"
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            StyledText {
                width: parent.width
                visible: dependencyStatus.probeError.length > 0
                text: "Check error: " + dependencyStatus.probeError
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.warning
            }

            StyledText {
                width: parent.width
                text: DependencyUtils.getTranslateMessage(dependencyStatus)
                visible: DependencyUtils.getTranslateMessage(dependencyStatus).length > 0
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.warning
            }

            StyledText {
                width: parent.width
                text: DependencyUtils.getScreenshotMessage(dependencyStatus)
                visible: DependencyUtils.getScreenshotMessage(dependencyStatus).length > 0
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.warning
            }

            DankButton {
                width: parent.width
                text: dependencyStatus.loading ? "Checking..." : "Refresh Diagnostics"
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
                text: "Behavior"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            DankDropdown {
                width: parent.width
                text: "Auto-copy translated text"
                description: "Choose whether successful translations are copied to the clipboard automatically."
                options: ["Off", "On"]
                currentValue: root.loadValue("autoCopyResult", false) ? "On" : "Off"
                onValueChanged: root.saveValue("autoCopyResult", value === "On")
            }

            DankDropdown {
                width: parent.width
                text: "Remember last input"
                description: "Persist the last typed text between shell restarts."
                options: ["On", "Off"]
                currentValue: root.loadValue("rememberLastInput", true) ? "On" : "Off"
                onValueChanged: root.saveValue("rememberLastInput", value === "On")
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
                text: "Suggested IPC keybind commands"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: "Open or close the translator popout:\ndms ipc call widget toggle dankTranslate"
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            StyledText {
                width: parent.width
                text: "Start screenshot OCR translation:\ndms ipc call widget openWith dankTranslate screenshot"
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            StyledText {
                width: parent.width
                text: "Open the quick actions panel:\ndms ipc call widget openWith dankTranslate actions"
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
