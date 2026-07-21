#!/bin/zsh
set -euo pipefail

# Fully installs the customized CoveType stack on a supported Mac:
#   - CoveType.app
#   - isolated CPython 3.12 + pinned MLX runtime
#   - Qwen3-ASR 0.6B 8-bit and Qwen3.5 0.8B 4-bit models
#   - current user defaults and post-install self-tests
#
# macOS privacy permissions and Apple Translation language-pack consent are
# intentionally left to the signed-in user because macOS does not permit an
# installer to grant them silently.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_SUPPORT_DIR="$HOME/Library/Application Support/CoveType"
RUNTIME_DIR="$APP_SUPPORT_DIR/mlx-runtime"
MODELS_DIR="$APP_SUPPORT_DIR/models"
TOOLS_DIR="$APP_SUPPORT_DIR/tools"
UV_PYTHON_DIR="$APP_SUPPORT_DIR/python-builds"
UV_CACHE_DIR="$APP_SUPPORT_DIR/uv-cache"
BACKUP_DIR="$APP_SUPPORT_DIR/backups"
SYSTEM_APPLICATIONS_DIR="/Applications"
USER_APPLICATIONS_DIR="$HOME/Applications"
INSTALL_DIR=""
INSTALL_APP=""
ASR_MODEL_DIR="$MODELS_DIR/Qwen3-ASR-0.6B-8bit"
POLISH_MODEL_DIR="$MODELS_DIR/Qwen3.5-0.8B-4bit"
ASR_REPO="mlx-community/Qwen3-ASR-0.6B-8bit"
POLISH_REPO="mlx-community/Qwen3.5-0.8B-4bit"
UV_VERSION="0.11.30"
SKIP_LAUNCH=0
SKIP_MODEL_TEST=0
PERMISSIONS_ONLY=0
PERMISSIONS_READY=0
LOGIN_ITEM_READY=0
PRODUCT_APP_NAME="CoveType.app"
APP_EXECUTABLE="CoveType"
LOGIN_AGENT_LABEL="ai.covetype.app.login"
LOGIN_AGENT_DIR="$HOME/Library/LaunchAgents"
LOGIN_AGENT_PLIST="$LOGIN_AGENT_DIR/$LOGIN_AGENT_LABEL.plist"

APPLE_LANGUAGE="$(defaults read -g AppleLanguages 2>/dev/null | sed -n '2{s/[\", ]//g;p;}' || true)"
if [[ -z "$APPLE_LANGUAGE" ]]; then
    APPLE_LANGUAGE="$(defaults read -g AppleLocale 2>/dev/null || printf 'en')"
fi
case "$APPLE_LANGUAGE" in
    zh-Hant*|zh_Hant*|zh-TW*|zh_TW*|zh-HK*|zh_HK*|zh-MO*|zh_MO*) UI_LANGUAGE="zh-Hant" ;;
    zh*) UI_LANGUAGE="zh-Hans" ;;
    ja*) UI_LANGUAGE="ja" ;;
    ko*) UI_LANGUAGE="ko" ;;
    fr*) UI_LANGUAGE="fr" ;;
    de*) UI_LANGUAGE="de" ;;
    es*) UI_LANGUAGE="es" ;;
    *) UI_LANGUAGE="en" ;;
esac

log() {
    printf '\n==> %s\n' "$1"
}

fail() {
    printf '\nERROR: %s\n' "$1" >&2
    exit 1
}

ui_text() {
    local key="$1"
    case "$UI_LANGUAGE:$key" in
        zh-Hans:title) printf 'CoveType 权限设置' ;;
        zh-Hans:intro) printf 'CoveType 已安装。接下来 macOS 会要求麦克风和辅助功能权限。请按照提示点击“允许”，并在系统设置中打开 CoveType 开关。安装程序会自动检测结果。' ;;
        zh-Hans:microphone) printf '麦克风' ;;
        zh-Hans:accessibility) printf '辅助功能' ;;
        zh-Hans:microphone_body) printf '请在“系统设置 → 隐私与安全性 → 麦克风”中打开 CoveType。如果看到系统弹窗，请点击“允许”。完成后回到此窗口并点击“重新检测”。' ;;
        zh-Hans:accessibility_body) printf '请在“系统设置 → 隐私与安全性 → 辅助功能”中找到 CoveType 并打开开关。如果列表中没有 CoveType，请点击“+”并选择：%s' "$INSTALL_APP" ;;
        zh-Hans:open) printf '打开系统设置' ;;
        zh-Hans:continue) printf '继续' ;;
        zh-Hans:check) printf '重新检测' ;;
        zh-Hans:skip) printf '稍后处理' ;;
        zh-Hans:ready) printf '麦克风和辅助功能权限均已开启。' ;;
        zh-Hans:incomplete) printf '权限尚未全部开启；以后可重新运行安装程序自动检测。' ;;
        zh-Hans:login_ready) printf 'CoveType 已开启登录时自动启动。' ;;

        zh-Hant:title) printf 'CoveType 權限設定' ;;
        zh-Hant:intro) printf 'CoveType 已安裝。接下來 macOS 會要求麥克風和輔助使用權限。請依提示按一下「允許」，並在系統設定中開啟 CoveType。安裝程式會自動偵測結果。' ;;
        zh-Hant:microphone) printf '麥克風' ;;
        zh-Hant:accessibility) printf '輔助使用' ;;
        zh-Hant:microphone_body) printf '請在「系統設定 → 隱私權與安全性 → 麥克風」中開啟 CoveType。如果看到系統提示，請按一下「允許」。完成後返回此視窗並按一下「重新偵測」。' ;;
        zh-Hant:accessibility_body) printf '請在「系統設定 → 隱私權與安全性 → 輔助使用」中找到 CoveType 並開啟。如果清單中沒有 CoveType，請按一下「+」並選擇：%s' "$INSTALL_APP" ;;
        zh-Hant:open) printf '開啟系統設定' ;;
        zh-Hant:continue) printf '繼續' ;;
        zh-Hant:check) printf '重新偵測' ;;
        zh-Hant:skip) printf '稍後處理' ;;
        zh-Hant:ready) printf '麥克風和輔助使用權限均已開啟。' ;;
        zh-Hant:incomplete) printf '權限尚未全部開啟；稍後可重新執行安裝程式自動偵測。' ;;
        zh-Hant:login_ready) printf 'CoveType 已開啟登入時自動啟動。' ;;

        ja:title) printf 'CoveType 権限設定' ;;
        ja:intro) printf 'CoveType をインストールしました。続いて macOS がマイクとアクセシビリティの許可を求めます。「許可」を選び、システム設定で CoveType をオンにしてください。インストーラが結果を自動確認します。' ;;
        ja:microphone) printf 'マイク' ;;
        ja:accessibility) printf 'アクセシビリティ' ;;
        ja:microphone_body) printf '「システム設定 → プライバシーとセキュリティ → マイク」で CoveType をオンにしてください。確認画面が表示された場合は「許可」を選び、完了後に「再確認」をクリックしてください。' ;;
        ja:accessibility_body) printf '「システム設定 → プライバシーとセキュリティ → アクセシビリティ」で CoveType をオンにしてください。CoveType がない場合は「+」をクリックして次を選択してください：%s' "$INSTALL_APP" ;;
        ja:open) printf 'システム設定を開く' ;;
        ja:continue) printf '続ける' ;;
        ja:check) printf '再確認' ;;
        ja:skip) printf '後で行う' ;;
        ja:ready) printf 'マイクとアクセシビリティの両方が有効です。' ;;
        ja:incomplete) printf '必要な権限がまだ揃っていません。後でインストーラを再実行して確認できます。' ;;
        ja:login_ready) printf 'CoveType はログイン時に自動起動するよう設定されました。' ;;

        ko:title) printf 'CoveType 권한 설정' ;;
        ko:intro) printf 'CoveType가 설치되었습니다. 이제 macOS에서 마이크와 손쉬운 사용 권한을 요청합니다. “허용”을 선택하고 시스템 설정에서 CoveType를 켜십시오. 설치 프로그램이 결과를 자동으로 확인합니다.' ;;
        ko:microphone) printf '마이크' ;;
        ko:accessibility) printf '손쉬운 사용' ;;
        ko:microphone_body) printf '“시스템 설정 → 개인정보 보호 및 보안 → 마이크”에서 CoveType를 켜십시오. 시스템 메시지가 표시되면 “허용”을 누르고 완료 후 “다시 확인”을 클릭하십시오.' ;;
        ko:accessibility_body) printf '“시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용”에서 CoveType를 찾아 켜십시오. 목록에 없다면 “+”를 누르고 다음 앱을 선택하십시오: %s' "$INSTALL_APP" ;;
        ko:open) printf '시스템 설정 열기' ;;
        ko:continue) printf '계속' ;;
        ko:check) printf '다시 확인' ;;
        ko:skip) printf '나중에' ;;
        ko:ready) printf '마이크와 손쉬운 사용 권한이 모두 활성화되었습니다.' ;;
        ko:incomplete) printf '일부 권한이 아직 비활성화되어 있습니다. 나중에 설치 프로그램을 다시 실행하여 확인할 수 있습니다.' ;;
        ko:login_ready) printf 'CoveType가 로그인 시 자동으로 시작되도록 설정되었습니다.' ;;

        fr:title) printf 'Autorisations CoveType' ;;
        fr:intro) printf 'CoveType est installé. macOS va maintenant demander l’accès au microphone et à l’accessibilité. Choisissez « Autoriser », puis activez CoveType dans Réglages Système. Le programme vérifiera automatiquement le résultat.' ;;
        fr:microphone) printf 'Microphone' ;;
        fr:accessibility) printf 'Accessibilité' ;;
        fr:microphone_body) printf 'Activez CoveType dans « Réglages Système → Confidentialité et sécurité → Microphone ». Si macOS affiche une demande, choisissez « Autoriser », puis cliquez sur « Vérifier à nouveau ».' ;;
        fr:accessibility_body) printf 'Activez CoveType dans « Réglages Système → Confidentialité et sécurité → Accessibilité ». Si CoveType est absent, cliquez sur « + » et sélectionnez : %s' "$INSTALL_APP" ;;
        fr:open) printf 'Ouvrir les réglages' ;;
        fr:continue) printf 'Continuer' ;;
        fr:check) printf 'Vérifier à nouveau' ;;
        fr:skip) printf 'Plus tard' ;;
        fr:ready) printf 'Le microphone et l’accessibilité sont activés.' ;;
        fr:incomplete) printf 'Certaines autorisations manquent encore. Relancez l’installateur plus tard pour les vérifier.' ;;
        fr:login_ready) printf 'CoveType démarrera automatiquement à l’ouverture de session.' ;;

        de:title) printf 'CoveType-Berechtigungen' ;;
        de:intro) printf 'CoveType wurde installiert. macOS fragt nun nach Mikrofon- und Bedienungshilfen-Zugriff. Wählen Sie „Erlauben“ und aktivieren Sie CoveType in den Systemeinstellungen. Das Installationsprogramm prüft das Ergebnis automatisch.' ;;
        de:microphone) printf 'Mikrofon' ;;
        de:accessibility) printf 'Bedienungshilfen' ;;
        de:microphone_body) printf 'Aktivieren Sie CoveType unter „Systemeinstellungen → Datenschutz & Sicherheit → Mikrofon“. Falls eine Abfrage erscheint, wählen Sie „Erlauben“ und klicken danach auf „Erneut prüfen“.' ;;
        de:accessibility_body) printf 'Aktivieren Sie CoveType unter „Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen“. Fehlt CoveType, klicken Sie auf „+“ und wählen Sie: %s' "$INSTALL_APP" ;;
        de:open) printf 'Systemeinstellungen öffnen' ;;
        de:continue) printf 'Fortfahren' ;;
        de:check) printf 'Erneut prüfen' ;;
        de:skip) printf 'Später' ;;
        de:ready) printf 'Mikrofon und Bedienungshilfen sind aktiviert.' ;;
        de:incomplete) printf 'Einige Berechtigungen fehlen noch. Starten Sie das Installationsprogramm später erneut.' ;;
        de:login_ready) printf 'CoveType startet jetzt automatisch bei der Anmeldung.' ;;

        es:title) printf 'Permisos de CoveType' ;;
        es:intro) printf 'CoveType está instalado. macOS solicitará acceso al micrófono y a Accesibilidad. Elija «Permitir» y active CoveType en Ajustes del Sistema. El instalador comprobará automáticamente el resultado.' ;;
        es:microphone) printf 'Micrófono' ;;
        es:accessibility) printf 'Accesibilidad' ;;
        es:microphone_body) printf 'Active CoveType en «Ajustes del Sistema → Privacidad y seguridad → Micrófono». Si aparece un aviso, elija «Permitir» y después pulse «Comprobar de nuevo».' ;;
        es:accessibility_body) printf 'Active CoveType en «Ajustes del Sistema → Privacidad y seguridad → Accesibilidad». Si CoveType no aparece, pulse «+» y seleccione: %s' "$INSTALL_APP" ;;
        es:open) printf 'Abrir ajustes' ;;
        es:continue) printf 'Continuar' ;;
        es:check) printf 'Comprobar de nuevo' ;;
        es:skip) printf 'Más tarde' ;;
        es:ready) printf 'El micrófono y Accesibilidad están activados.' ;;
        es:incomplete) printf 'Aún faltan permisos. Puede volver a ejecutar el instalador para comprobarlos.' ;;
        es:login_ready) printf 'CoveType se iniciará automáticamente al iniciar sesión.' ;;

        *:title) printf 'CoveType Permissions' ;;
        *:intro) printf 'CoveType is installed. macOS will now ask for Microphone and Accessibility access. Choose Allow, then turn on CoveType in System Settings. The installer will verify the result automatically.' ;;
        *:microphone) printf 'Microphone' ;;
        *:accessibility) printf 'Accessibility' ;;
        *:microphone_body) printf 'Turn on CoveType in System Settings → Privacy & Security → Microphone. If macOS shows a permission alert, choose Allow, then click Check Again.' ;;
        *:accessibility_body) printf 'Find CoveType in System Settings → Privacy & Security → Accessibility and turn it on. If CoveType is missing, click + and select: %s' "$INSTALL_APP" ;;
        *:open) printf 'Open System Settings' ;;
        *:continue) printf 'Continue' ;;
        *:check) printf 'Check Again' ;;
        *:skip) printf 'Do It Later' ;;
        *:ready) printf 'Microphone and Accessibility are both enabled.' ;;
        *:incomplete) printf 'Some permissions are still disabled. Run the installer again later to verify them.' ;;
        *:login_ready) printf 'CoveType will now start automatically at login.' ;;
    esac
}

permission_status() {
    "$INSTALL_APP/Contents/MacOS/$APP_EXECUTABLE" --permission-status 2>/dev/null || true
}

permission_is_granted() {
    local permission="$1"
    local permission_output
    permission_output="$(permission_status)"
    if [[ "$permission" == "microphone" ]]; then
        printf '%s\n' "$permission_output" | grep -q '"microphone_authorized":true'
    else
        printf '%s\n' "$permission_output" | grep -q '"accessibility":true'
    fi
}

install_launch_agent() {
    local staged_plist="$TEMP_DIR/$LOGIN_AGENT_LABEL.plist"
    local covetype_user_id=""
    local launch_domain=""
    local launch_service=""

    mkdir -p "$LOGIN_AGENT_DIR"
    plutil -create xml1 "$staged_plist"
    /usr/libexec/PlistBuddy -c "Add :Label string $LOGIN_AGENT_LABEL" "$staged_plist"
    /usr/libexec/PlistBuddy -c 'Add :ProgramArguments array' "$staged_plist"
    /usr/libexec/PlistBuddy -c 'Add :ProgramArguments:0 string /usr/bin/open' "$staged_plist"
    /usr/libexec/PlistBuddy -c 'Add :ProgramArguments:1 string -gj' "$staged_plist"
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments:2 string $INSTALL_APP" "$staged_plist"
    /usr/libexec/PlistBuddy -c 'Add :RunAtLoad bool true' "$staged_plist"
    /usr/libexec/PlistBuddy -c 'Add :ProcessType string Interactive' "$staged_plist"
    plutil -lint "$staged_plist" >/dev/null
    ditto "$staged_plist" "$LOGIN_AGENT_PLIST"
    chmod 644 "$LOGIN_AGENT_PLIST"

    covetype_user_id="$(id -u)"
    launch_domain="gui/$covetype_user_id"
    launch_service="$launch_domain/$LOGIN_AGENT_LABEL"
    launchctl bootout "$launch_service" >/dev/null 2>&1 || true
    launchctl enable "$launch_service" >/dev/null 2>&1 || true

    if [[ "$SKIP_LAUNCH" -eq 0 ]]; then
        launchctl bootstrap "$launch_domain" "$LOGIN_AGENT_PLIST" || fail "Could not load the CoveType login agent."
        launchctl print "$launch_service" >/dev/null 2>&1 || fail "The CoveType login agent was not registered."
    fi

    LOGIN_ITEM_READY=1
    printf '%s\n' "$(ui_text login_ready)"
}

localized_dialog() {
    local body="$1"
    local primary_button="$2"
    local secondary_button="$3"
    osascript - "$(ui_text title)" "$body" "$primary_button" "$secondary_button" <<'APPLESCRIPT'
on run arguments
    set dialogResult to display dialog (item 2 of arguments) with title (item 1 of arguments) buttons {(item 4 of arguments), (item 3 of arguments)} default button (item 3 of arguments) with icon caution
    return button returned of dialogResult
end run
APPLESCRIPT
}

open_permission_settings() {
    local permission="$1"
    if [[ "$permission" == "microphone" ]]; then
        open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone'
    else
        open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'
    fi
}

guide_permission() {
    local permission="$1"
    local body_key="${permission}_body"
    local response=""

    permission_is_granted "$permission" && return 0

    response="$(localized_dialog "$(ui_text "$body_key")" "$(ui_text open)" "$(ui_text skip)" 2>/dev/null || true)"
    if [[ "$response" == "$(ui_text skip)" || -z "$response" ]]; then
        return 1
    fi

    open_permission_settings "$permission"
    while ! permission_is_granted "$permission"; do
        response="$(localized_dialog "$(ui_text "$body_key")" "$(ui_text check)" "$(ui_text skip)" 2>/dev/null || true)"
        if [[ "$response" == "$(ui_text skip)" || -z "$response" ]]; then
            return 1
        fi
        sleep 0.5
    done
    return 0
}

run_permission_guide() {
    local response=""

    if permission_status | grep -q '"ready":true'; then
        PERMISSIONS_READY=1
        printf '\n%s\n' "$(ui_text ready)"
        return
    fi

    response="$(localized_dialog "$(ui_text intro)" "$(ui_text continue)" "$(ui_text skip)" 2>/dev/null || true)"
    if [[ "$response" == "$(ui_text skip)" || -z "$response" ]]; then
        printf '\n%s\n' "$(ui_text incomplete)"
        return
    fi

    open "$INSTALL_APP"
    sleep 2
    guide_permission microphone || true
    guide_permission accessibility || true

    if permission_status | grep -q '"ready":true'; then
        PERMISSIONS_READY=1
        printf '\n%s\n' "$(ui_text ready)"
    else
        printf '\n%s\n' "$(ui_text incomplete)"
    fi
}

while [[ "$#" -gt 0 ]]; do
    argument="$1"
    case "$argument" in
        --skip-launch) SKIP_LAUNCH=1 ;;
        --skip-model-test) SKIP_MODEL_TEST=1 ;;
        --permissions-only) PERMISSIONS_ONLY=1 ;;
        --install-dir)
            shift
            [[ "$#" -gt 0 ]] || fail "--install-dir requires a directory."
            INSTALL_DIR="$1"
            ;;
        --help)
            printf 'Usage: %s [--skip-launch] [--skip-model-test] [--permissions-only] [--install-dir DIRECTORY]\n' "$0"
            exit 0
            ;;
        *) fail "Unknown option: $argument" ;;
    esac
    shift
done

[[ "$(uname -s)" == "Darwin" ]] || fail "This installer must run on macOS."
[[ "$(uname -m)" == "arm64" ]] || fail "This MLX build requires an Apple Silicon Mac (M1 or newer)."

OS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[[ "$OS_MAJOR" -ge 15 ]] || fail "CoveType instant translation requires macOS 15 or later."

mkdir -p "$APP_SUPPORT_DIR" "$MODELS_DIR" "$TOOLS_DIR" "$UV_PYTHON_DIR" "$UV_CACHE_DIR" "$BACKUP_DIR"

if [[ -z "$INSTALL_DIR" ]]; then
    if [[ -w "$SYSTEM_APPLICATIONS_DIR" || -w "$SYSTEM_APPLICATIONS_DIR/$PRODUCT_APP_NAME" ]]; then
        INSTALL_DIR="$SYSTEM_APPLICATIONS_DIR"
    else
        INSTALL_DIR="$USER_APPLICATIONS_DIR"
    fi
fi
mkdir -p "$INSTALL_DIR"
[[ -w "$INSTALL_DIR" ]] || fail "The application directory is not writable: $INSTALL_DIR"
if [[ -d "$INSTALL_DIR/$PRODUCT_APP_NAME" ]]; then
    INSTALL_APP="$INSTALL_DIR/$PRODUCT_APP_NAME"
else
    INSTALL_APP="$INSTALL_DIR/$PRODUCT_APP_NAME"
fi

if [[ "$PERMISSIONS_ONLY" -eq 1 ]]; then
    [[ -x "$INSTALL_APP/Contents/MacOS/$APP_EXECUTABLE" ]] || fail "CoveType is not installed at $INSTALL_APP"
    run_permission_guide
    open "$INSTALL_APP"
    [[ "$PERMISSIONS_READY" -eq 1 ]] && exit 0
    exit 2
fi

AVAILABLE_KB="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
[[ "$AVAILABLE_KB" -ge 5242880 ]] || fail "At least 5 GB of free disk space is required."

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/covetype-installer.XXXXXX")"
cleanup() {
    if [[ -n "${TEMP_DIR:-}" && "$TEMP_DIR" == *covetype-installer.* && -d "$TEMP_DIR" ]]; then
        find "$TEMP_DIR" -depth -delete
    fi
}
trap cleanup EXIT INT TERM

REQUIREMENTS_FILE=""
if [[ -f "$SCRIPT_DIR/requirements-macos.txt" ]]; then
    REQUIREMENTS_FILE="$SCRIPT_DIR/requirements-macos.txt"
elif [[ -f "$PROJECT_ROOT/scripts/requirements-macos.txt" ]]; then
    REQUIREMENTS_FILE="$PROJECT_ROOT/scripts/requirements-macos.txt"
else
    fail "requirements-macos.txt is missing from the installer."
fi

SOURCE_APP=""
if [[ -d "$SCRIPT_DIR/$PRODUCT_APP_NAME" ]]; then
    SOURCE_APP="$SCRIPT_DIR/$PRODUCT_APP_NAME"
elif [[ -d "$PROJECT_ROOT/dist/$PRODUCT_APP_NAME" ]]; then
    SOURCE_APP="$PROJECT_ROOT/dist/$PRODUCT_APP_NAME"
fi

if [[ -z "$SOURCE_APP" ]]; then
    [[ -f "$PROJECT_ROOT/Package.swift" ]] || fail "CoveType.app is missing and no source package is available."
    command -v xcrun >/dev/null 2>&1 || fail "Xcode Command Line Tools are required to build from source."
    xcrun --find swift >/dev/null 2>&1 || fail "Run 'xcode-select --install', then retry."

    log "Building CoveType from source"
    swift build -c release --arch arm64 --package-path "$PROJECT_ROOT"
    BUILD_BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path --package-path "$PROJECT_ROOT")"
    SOURCE_APP="$TEMP_DIR/$PRODUCT_APP_NAME"
    mkdir -p "$SOURCE_APP/Contents/MacOS" "$SOURCE_APP/Contents/Resources"
    cp "$BUILD_BIN_DIR/CoveType" "$SOURCE_APP/Contents/MacOS/$APP_EXECUTABLE"
    cp "$PROJECT_ROOT/App/Info.plist" "$SOURCE_APP/Contents/Info.plist"
    cp "$PROJECT_ROOT/App/CoveType.icns" "$SOURCE_APP/Contents/Resources/CoveType.icns"
    cp "$PROJECT_ROOT/Resources/covetype_local_ai_worker.py" "$SOURCE_APP/Contents/Resources/covetype_local_ai_worker.py"
    chmod +x "$SOURCE_APP/Contents/MacOS/$APP_EXECUTABLE"
    codesign --force --sign - --entitlements "$PROJECT_ROOT/App/CoveType.entitlements" --timestamp=none "$SOURCE_APP"
fi

[[ -x "$SOURCE_APP/Contents/MacOS/$APP_EXECUTABLE" ]] || fail "The CoveType app bundle is invalid."
[[ -f "$SOURCE_APP/Contents/Resources/covetype_local_ai_worker.py" ]] || fail "The local AI worker is missing."
codesign --verify --deep --strict "$SOURCE_APP" || fail "The CoveType app signature is invalid."

UV_BIN="$TOOLS_DIR/uv"
if [[ ! -x "$UV_BIN" ]]; then
    log "Installing uv $UV_VERSION into the private CoveType tools directory"
    UV_INSTALLER="$TEMP_DIR/uv-install.sh"
    curl --fail --location --silent --show-error \
        "https://astral.sh/uv/$UV_VERSION/install.sh" \
        --output "$UV_INSTALLER"
    UV_UNMANAGED_INSTALL="$TOOLS_DIR" sh "$UV_INSTALLER"
fi
[[ -x "$UV_BIN" ]] || fail "uv installation failed."

export UV_PYTHON_INSTALL_DIR="$UV_PYTHON_DIR"
export UV_CACHE_DIR

if [[ -x "$RUNTIME_DIR/bin/python" ]]; then
    RUNTIME_MINOR="$("$RUNTIME_DIR/bin/python" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
    if [[ "$RUNTIME_MINOR" != "3.12" ]]; then
        RUNTIME_BACKUP="$BACKUP_DIR/mlx-runtime-before-$(date +%Y%m%d-%H%M%S)"
        log "Preserving incompatible Python runtime at $RUNTIME_BACKUP"
        mv "$RUNTIME_DIR" "$RUNTIME_BACKUP"
    fi
fi

if [[ ! -x "$RUNTIME_DIR/bin/python" ]]; then
    log "Installing a private CPython 3.12 runtime"
    "$UV_BIN" venv --python 3.12 "$RUNTIME_DIR"
fi

runtime_matches_requirements() {
    "$RUNTIME_DIR/bin/python" - "$REQUIREMENTS_FILE" <<'PY'
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path
import sys

for raw_line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#"):
        continue
    if "==" not in line:
        raise SystemExit(1)
    package, expected = line.split("==", 1)
    try:
        installed = version(package)
    except PackageNotFoundError:
        raise SystemExit(1)
    if installed != expected:
        raise SystemExit(1)

import mlx, mlx_audio, mlx_lm  # noqa: F401
PY
}

if runtime_matches_requirements; then
    log "Pinned MLX runtime is already complete; skipping network synchronization"
else
    log "Synchronizing pinned MLX dependencies"
    "$UV_BIN" pip sync --python "$RUNTIME_DIR/bin/python" "$REQUIREMENTS_FILE"
    runtime_matches_requirements || fail "The MLX runtime does not match the pinned requirements."
fi

download_model() {
    local repo_id="$1"
    local destination="$2"
    local display_name="$3"

    if [[ -f "$destination/config.json" && -f "$destination/model.safetensors.index.json" ]]; then
        log "$display_name is already installed"
        return
    fi

    log "Downloading $display_name from Hugging Face (resumable)"
    mkdir -p "$destination"
    "$RUNTIME_DIR/bin/python" - "$repo_id" "$destination" <<'PY'
import sys
from huggingface_hub import snapshot_download

snapshot_download(
    repo_id=sys.argv[1],
    local_dir=sys.argv[2],
)
PY
    [[ -f "$destination/config.json" ]] || fail "$display_name download is incomplete."
    [[ -f "$destination/model.safetensors.index.json" ]] || fail "$display_name weights are incomplete."
}

download_model "$ASR_REPO" "$ASR_MODEL_DIR" "Qwen3-ASR 0.6B 8-bit"
download_model "$POLISH_REPO" "$POLISH_MODEL_DIR" "Qwen3.5 0.8B 4-bit"

log "Stopping the previous CoveType instance"
osascript -e 'tell application "CoveType" to quit' >/dev/null 2>&1 || true
for _ in {1..20}; do
    if ! pgrep -f '/CoveType\.app/Contents/MacOS/CoveType$' >/dev/null; then
        break
    fi
    sleep 0.25
done
if pgrep -f '/CoveType\.app/Contents/MacOS/CoveType$' >/dev/null; then
    pkill -TERM -f '/CoveType\.app/Contents/MacOS/CoveType$' || true
    sleep 1
fi

APP_BACKUP=""
if [[ -d "$INSTALL_APP" ]]; then
    APP_BACKUP="$BACKUP_DIR/CoveType-before-$(date +%Y%m%d-%H%M%S).app.zip"
    log "Preserving the previous app at $APP_BACKUP"
    ditto -c -k --keepParent "$INSTALL_APP" "$APP_BACKUP"

    # Keep the outer .app directory in place. Moving the whole bundle causes
    # macOS Accessibility approval to follow the backup instead of the newly
    # installed app, even when the bundle identifier and signature are stable.
    log "Updating CoveType in place to preserve privacy permissions"
    find "$INSTALL_APP/Contents" -depth -delete
    ditto "$SOURCE_APP/Contents" "$INSTALL_APP/Contents"
else
    log "Installing CoveType into $INSTALL_DIR"
    ditto "$SOURCE_APP" "$INSTALL_APP"
fi
xattr -cr "$INSTALL_APP"
if ! codesign --verify --deep --strict "$INSTALL_APP"; then
    if [[ -n "$APP_BACKUP" ]]; then
        ROLLBACK_DIR="$TEMP_DIR/rollback"
        mkdir -p "$ROLLBACK_DIR"
        ditto -x -k "$APP_BACKUP" "$ROLLBACK_DIR"
        ROLLBACK_BUNDLE="$ROLLBACK_DIR/$(basename "$INSTALL_APP")"
        if [[ -d "$ROLLBACK_BUNDLE/Contents" ]]; then
            find "$INSTALL_APP/Contents" -depth -delete
            ditto "$ROLLBACK_BUNDLE/Contents" "$INSTALL_APP/Contents"
        fi
    fi
    fail "Installed app signature verification failed; the previous app was restored."
fi

# Prevent source and backup copies with the same bundle identifier from
# appearing as ambiguous entries in System Settings.
LSREGISTER_BIN="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER_BIN" ]]; then
    [[ "$SOURCE_APP" == "$INSTALL_APP" ]] || "$LSREGISTER_BIN" -u "$SOURCE_APP" >/dev/null 2>&1 || true
    find "$BACKUP_DIR" -type d -name '*.app' -prune -print0 2>/dev/null | while IFS= read -r -d '' old_app_bundle; do
        "$LSREGISTER_BIN" -u "$old_app_bundle" >/dev/null 2>&1 || true
    done
    "$LSREGISTER_BIN" -f "$INSTALL_APP" >/dev/null 2>&1 || true
fi

log "Applying portable defaults"
defaults write ai.covetype.app ai.covetype.app.polishMode -string Light
defaults write ai.covetype.app ai.covetype.app.translationTarget -string English
defaults delete ai.covetype.app ai.covetype.app.hotkeyModifier >/dev/null 2>&1 || true
defaults delete ai.covetype.app ai.covetype.app.triggerMode >/dev/null 2>&1 || true
defaults delete ai.covetype.app ai.covetype.app.microphone >/dev/null 2>&1 || true

log "Running runtime and shortcut checks"
"$RUNTIME_DIR/bin/python" -c 'import mlx, mlx_audio, mlx_lm; print("MLX_RUNTIME=PASS")'
"$INSTALL_APP/Contents/MacOS/$APP_EXECUTABLE" --hotkey-self-test
"$INSTALL_APP/Contents/MacOS/$APP_EXECUTABLE" --update-channel-self-test
"$INSTALL_APP/Contents/MacOS/$APP_EXECUTABLE" --telemetry-self-test

HEALTH_OUTPUT="$(printf '%s\n' \
    '{"id":"health","action":"health"}' \
    '{"id":"shutdown","action":"shutdown"}' \
    | "$RUNTIME_DIR/bin/python" "$INSTALL_APP/Contents/Resources/covetype_local_ai_worker.py")"
printf '%s\n' "$HEALTH_OUTPUT"
printf '%s\n' "$HEALTH_OUTPUT" | grep -q '"asr_installed":true' || fail "ASR model health check failed."
printf '%s\n' "$HEALTH_OUTPUT" | grep -q '"polish_installed":true' || fail "Polishing model health check failed."

if [[ "$SKIP_MODEL_TEST" -eq 0 ]]; then
    log "Running an end-to-end local speech recognition test"
    say -v Samantha -o "$TEMP_DIR/covetype-self-test.aiff" 'CoveType local speech recognition is ready.'
    afconvert "$TEMP_DIR/covetype-self-test.aiff" "$TEMP_DIR/covetype-self-test.wav" -f WAVE -d LEI16@16000
    "$INSTALL_APP/Contents/MacOS/$APP_EXECUTABLE" --local-ai-self-test "$TEMP_DIR/covetype-self-test.wav"
fi

# The previous bundle is needed only for rollback while installation checks run.
# Remove it after a successful install so CoveType does not accumulate obsolete
# app copies or leave duplicate privacy-permission identities on disk.
if [[ -n "$APP_BACKUP" && -f "$APP_BACKUP" ]]; then
    log "Removing the temporary rollback copy"
    find "$APP_BACKUP" -delete
    rmdir "$BACKUP_DIR" >/dev/null 2>&1 || true
fi

log "Enabling CoveType at login"
install_launch_agent

if [[ "$SKIP_LAUNCH" -eq 0 ]]; then
    log "Launching CoveType and checking privacy permissions"
    run_permission_guide
    open "$INSTALL_APP"
fi

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALL_APP/Contents/Info.plist")"
printf '\nCoveType %s installation completed.\n' "$APP_VERSION"
printf 'Shortcuts: open the CoveType menu and choose Shortcut Settings to record a key or key combination and set its hold duration.\n'
if [[ "$SKIP_LAUNCH" -eq 0 && "$PERMISSIONS_READY" -eq 0 ]]; then
    printf '%s\n' "$(ui_text incomplete)"
fi
printf 'The first use of each Apple on-device translation language requires language-pack approval.\n'
