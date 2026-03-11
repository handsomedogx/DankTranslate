# Dank Translate

`Dank Translate` is a DankMaterialShell widget plugin for:

- opening a translator popout from the bar or a keyboard shortcut
- translating English and Chinese text with automatic direction or a manual target override
- starting screenshot OCR translation from the bar icon or IPC
- using right click on the bar icon as a quick action panel

## Features

- Left click the bar icon: toggle the translator popout
- Right click the bar icon: open a quick action panel
- Translation direction can be `Auto`, `中文`, or `English`
- Keyboard-accessible IPC targets:
  - `widget toggle dankTranslate`
  - `widget openWith dankTranslate screenshot`
  - `widget openWith dankTranslate actions`
- Screenshot OCR flow:
  1. run `dms screenshot`
  2. OCR with `tesseract`
  3. translate OCR output to Chinese or English
- Built-in dependency diagnostics in both the widget and the settings page

## Dependencies

Install:

- `python3`
- `tesseract`
- Tesseract language data for `eng`
- Tesseract language data for `chi_sim` if you want Chinese OCR

The helper script uses the Google Translate web endpoint through Python's standard library. If you want a different translation backend, replace the logic in [`scripts/translate_helper.py`](./scripts/translate_helper.py).

## Install

Copy or symlink the plugin directory into your DMS plugins folder:

```bash
ln -sf /path/to/DankTranslate ~/.config/DankMaterialShell/plugins/DankTranslate
dms ipc call plugins reload dankTranslate
```

Then:

1. Open `Settings -> Plugins`
2. Scan for plugins if needed
3. Enable `Dank Translate`
4. Add `dankTranslate` to the bar widget list

## Suggested Keybinds

### Hyprland

```conf
bind = SUPER, T, exec, dms ipc call widget toggle dankTranslate
bind = SUPER SHIFT, T, exec, dms ipc call widget openWith dankTranslate screenshot
bind = SUPER CTRL, T, exec, dms ipc call widget openWith dankTranslate actions
```

### niri

```kdl
binds {
    Mod+T { spawn "dms" "ipc" "call" "widget" "toggle" "dankTranslate"; }
    Mod+Shift+T { spawn "dms" "ipc" "call" "widget" "openWith" "dankTranslate" "screenshot"; }
    Mod+Ctrl+T { spawn "dms" "ipc" "call" "widget" "openWith" "dankTranslate" "actions"; }
}
```

## Files

- `plugin.json`: plugin manifest
- `DankTranslateWidget.qml`: bar widget, popout, and IPC entry points
- `DankTranslateSettings.qml`: plugin settings page
- `scripts/translate_helper.py`: screenshot OCR and translation helper

## License

MIT. See [`LICENSE`](./LICENSE).
