#!/bin/sh

required_ocr_languages="$1"
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
helper_script="$script_dir/translate_helper.py"

has_command() {
    if command -v "$1" >/dev/null 2>&1; then
        printf '1'
    else
        printf '0'
    fi
}

dms_ok=$(has_command dms)
python_ok=$(has_command python3)
tesseract_ok=$(has_command tesseract)

if [ -f "$helper_script" ]; then
    helper_ok=1
else
    helper_ok=0
fi

langs_csv=""
if [ "$tesseract_ok" = "1" ]; then
    langs_csv=$(tesseract --list-langs 2>/dev/null | tail -n +2 | tr '\n' ',' | sed 's/,$//')
fi

missing_langs=""
if [ -n "$required_ocr_languages" ] && [ "$tesseract_ok" = "1" ]; then
    old_ifs=$IFS
    IFS='+'
    for lang in $required_ocr_languages; do
        [ -z "$lang" ] && continue
        case ",$langs_csv," in
            *,"$lang",*)
                ;;
            *)
                if [ -n "$missing_langs" ]; then
                    missing_langs="$missing_langs,$lang"
                else
                    missing_langs="$lang"
                fi
                ;;
        esac
    done
    IFS=$old_ifs
fi

printf 'DMS=%s\n' "$dms_ok"
printf 'PYTHON3=%s\n' "$python_ok"
printf 'HELPER=%s\n' "$helper_ok"
printf 'TESSERACT=%s\n' "$tesseract_ok"
printf 'REQUIRED_LANGS=%s\n' "$(printf '%s' "$required_ocr_languages" | tr '+' ',')"
printf 'LANGS=%s\n' "$langs_csv"
printf 'MISSING_LANGS=%s\n' "$missing_langs"
