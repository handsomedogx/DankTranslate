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
    readonly property string uiLanguage: I18n.detectUiLanguage(Qt.locale().name)
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
        text: I18n.t(root.uiLanguage, "pluginDescription")
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
