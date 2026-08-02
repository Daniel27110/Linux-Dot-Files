#!/bin/bash

# ==============================================================================
# Script Information
# ==============================================================================
# Target Environment: Arch Linux / KDE Plasma 6 / systemd-boot
# Installation Steps:
#   git clone https://github.com/Daniel27110/Linux-Dot-Files
#   cd Linux-Dot-Files
#   chmod +x Install.sh
#   ./Install.sh
# ==============================================================================

# ==============================================================================
# Initialization & Global Configuration
# ==============================================================================

LOG_FILE="$HOME/install_steps.log"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Enforce non-interactive sudo after initial authentication
SUDO_CMD=(sudo -n)
YAY_BASE_ARGS=(--sudoloop --sudoflags "-n")

# Initialize log file
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_step() {
    echo "$1" >> "$LOG_FILE"
}

is_step_completed() {
    grep -Fqw "$1" "$LOG_FILE"
}

# Authenticate sudo early
if sudo -n true 2>/dev/null; then
    echo "Sudo access is already available. Continuing with installation."
else
    echo "Please enter your sudo password:"
    sudo -v || { echo "Failed to acquire sudo access. Exiting."; exit 1; }
fi

# Keep sudo session alive in background
keep_sudo_alive() {
    while true; do
        sudo -n -v > /dev/null 2>&1 || exit 1
        sleep 30
    done &
    SUDO_KEEP_ALIVE_PID=$!
}
keep_sudo_alive

run_sudo() {
    "${SUDO_CMD[@]}" "$@"
}

run_yay() {
    yay "${YAY_BASE_ARGS[@]}" "$@"
}

# ==============================================================================
# Helper Functions
# ==============================================================================

ensure_repo_clone() {
    local url="$1"
    local dir="$2"

    if [ -d "$dir/.git" ]; then
        git -C "$dir" fetch --depth 1 origin > /dev/null 2>&1 || return 1
        local default_branch
        default_branch=$(git -C "$dir" remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
        default_branch="${default_branch:-master}"
        git -C "$dir" reset --hard "origin/$default_branch" > /dev/null 2>&1 || return 1
    else
        rm -rf "$dir" 2>/dev/null
        git clone --depth 1 "$url" "$dir" > /dev/null 2>&1 || return 1
    fi
}

append_unique_line_sudo() {
    local file="$1"
    local line="$2"
    run_sudo mkdir -p "$(dirname "$file")" || return 1
    if ! run_sudo grep -Fxq "$line" "$file" 2>/dev/null; then
        printf '%s\n' "$line" | run_sudo tee -a "$file" > /dev/null || return 1
    fi
}

safe_cp() {
    local src="$1"
    local dest="$2"
    local use_sudo="$3"

    if [ ! -e "$src" ]; then
        return 0  # Do not fail if optional repo file doesn't exist yet
    fi

    if [ "$use_sudo" = "sudo" ]; then
        run_sudo mkdir -p "$(dirname "$dest")" || return 1
        run_sudo cp -a "$src" "$dest" || return 1
    else
        mkdir -p "$(dirname "$dest")" || return 1
        cp -a "$src" "$dest" || return 1
    fi
}

configure_fcitx5_env() {
    append_unique_line_sudo /etc/environment "GTK_IM_MODULE=fcitx" || return 1
    append_unique_line_sudo /etc/environment "QT_IM_MODULE=fcitx" || return 1
    append_unique_line_sudo /etc/environment "XMODIFIERS=@im=fcitx" || return 1
}

sync_splash_screen() {
    mkdir -p "$HOME/.local/share/plasma/look-and-feel" || return 1
    rm -rf "$HOME/.local/share/plasma/look-and-feel/Rouge-Splash"
    safe_cp "$REPO_DIR/Themes/Splash/Rouge-Splash" "$HOME/.local/share/plasma/look-and-feel/" || return 1
}

sync_login_screen() {
    run_sudo mkdir -p /usr/share/sddm/themes/ || return 1
    run_sudo rm -rf /usr/share/sddm/themes/Rouge
    safe_cp "$REPO_DIR/Themes/Login/Rouge" /usr/share/sddm/themes/ sudo || return 1
}

sync_sddm_config() {
    run_sudo mkdir -p /etc/sddm.conf.d/ || return 1
    if [ -f "$REPO_DIR/Home/user/.config/kde_settings.conf" ]; then
        run_sudo install -m 0644 "$REPO_DIR/Home/user/.config/kde_settings.conf" /etc/sddm.conf.d/kde_settings.conf || return 1
    fi
}

set_systemd_boot_timeout_zero() {
    local loader_conf=""
    for path in "/boot/loader/loader.conf" "/efi/loader/loader.conf" "/boot/efi/loader/loader.conf"; do
        if run_sudo test -f "$path"; then
            loader_conf="$path"
            break
        fi
    done

    if [ -z "$loader_conf" ]; then
        return 0  # Skip silently if systemd-boot loader.conf is not found
    fi

    if run_sudo grep -Eq '^[[:space:]]*timeout[[:space:]]+0([[:space:]]|$)' "$loader_conf"; then
        return 0
    fi

    if run_sudo grep -Eq '^[[:space:]]*timeout[[:space:]]+' "$loader_conf"; then
        run_sudo sed -Ei 's/^[[:space:]]*timeout[[:space:]]+.*/timeout 0/' "$loader_conf" || return 1
    else
        printf '\ntimeout 0\n' | run_sudo tee -a "$loader_conf" > /dev/null || return 1
    fi
}

configure_kernel_cmdline() {
    local entries_dir=""
    for dir in "/boot/loader/entries" "/efi/loader/entries" "/boot/efi/loader/entries"; do
        if run_sudo test -d "$dir"; then
            entries_dir="$dir"
            break
        fi
    done

    if [ -z "$entries_dir" ]; then
        return 0
    fi

    run_sudo find "$entries_dir" -maxdepth 1 -name "*.conf" | while read -r file; do
        if ! run_sudo grep -Eq '^options.*\bquiet\b' "$file"; then
            run_sudo sed -i '/^options/ s/$/ quiet/' "$file" || return 1
        fi
    done
}

configure_bashrc_append() {
    if grep -Fqx "trap 'preexec_invoke_exec' DEBUG" "$HOME/.bashrc" 2>/dev/null; then
        return 0
    fi
    if [ -f "$REPO_DIR/Home/user/.bashrc_append" ]; then
        cat "$REPO_DIR/Home/user/.bashrc_append" >> "$HOME/.bashrc" || return 1
    fi
}

enable_multilib_repo() {
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        run_sudo sed -i '/^#\[multilib\]/s/^#//;/^\[multilib\]/,/^#Include/s/^#Include/Include/' /etc/pacman.conf || return 1
    fi
}

configure_captive_portal() {
    run_sudo mkdir -p /etc/NetworkManager/conf.d || return 1
    run_sudo bash -c 'cat << EOF > /etc/NetworkManager/conf.d/20-connectivity.conf
[connectivity]
uri=https://networkcheck.kde.org/
interval=300
EOF' || return 1
}

apply_wallpaper_plasma() {
    local wp_file="$HOME/Pictures/Rouge.jpg"
    mkdir -p "$HOME/Pictures"
    if [ -f "$REPO_DIR/Pictures/Rouge.jpg" ]; then
        install -m 0644 "$REPO_DIR/Pictures/Rouge.jpg" "$wp_file" || return 1
    fi
    if command -v qdbus6 >/dev/null 2>&1 && pgrep -x plasmashell >/dev/null 2>&1; then
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
            var allDesktops = desktops();
            for (i=0; i<allDesktops.length; i++) {
                d = allDesktops[i];
                d.wallpaperPlugin = "org.kde.image";
                d.currentConfigGroup = Array("Wallpaper","org.kde.image","General");
                d.writeConfig("Image", "file://'"$wp_file"'");
            }' >/dev/null 2>&1
    fi
    return 0
}

# ==============================================================================
# Interactive Prompt & Spinner
# ==============================================================================

prompt_yes_no() {
    local question="$1"
    local default="$2"
    local answer=""
    local prompt_suffix="[y/N]"

    if [[ "$default" =~ ^[Yy]$ ]]; then
        prompt_suffix="[Y/n]"
    fi

    while true; do
        read -rp "    ${question} ${prompt_suffix}: " answer
        answer="${answer:-$default}"
        case "$answer" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) echo "    Please answer with y or n." ;;
        esac
    done
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinster='|/-\'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % 4 ))
        printf "\r\t[%c]  " "${spinster:$i:1}"
        sleep $delay
    done
    printf "\r\t    \r"
}

run_with_spinner() {
    local step="$1"
    shift
    echo ""
    if is_step_completed "$step"; then
        printf "\t\e[33mSKIPPED\e[0m\n"
        return 0
    fi

    ( "$@" > /dev/null 2>&1 ) &
    local cmd_pid=$!
    spinner "$cmd_pid"
    wait "$cmd_pid"
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        printf "\t\e[31mFAILED\e[0m\n"
    else
        printf "\t\e[32mSUCCESS\e[0m\n"
        log_step "$step"
    fi
    return $exit_code
}

# ==============================================================================
# Installation Options
# ==============================================================================

echo -e "\n\e[1mWelcome to the Rouge Linux setup installer.\e[0m"
echo "This script installs applications, themes, and configurations for customizing KDE Plasma 6 on Arch Linux."

INSTALL_ANKI=false
INSTALL_GAMING_SUITE=false
INSTALL_QBITTORRENT=false
CONFIGURE_GIT_PROFILE=false
HIDE_SYSTEMD_BOOT_MENU=false

echo -e "\n\e[1mOptional software\e[0m"
if prompt_yes_no "Install Anki (flashcards)" "y"; then INSTALL_ANKI=true; fi
if prompt_yes_no "Install Gaming Support Suite (Lutris, Wine, GameMode, Xow)" "y"; then INSTALL_GAMING_SUITE=true; fi
if prompt_yes_no "Install qBittorrent" "n"; then INSTALL_QBITTORRENT=true; fi
if prompt_yes_no "Configure Git global profile (name + email)" "n"; then CONFIGURE_GIT_PROFILE=true; fi
if prompt_yes_no "Hide systemd-boot menu (set timeout to 0)" "n"; then HIDE_SYSTEMD_BOOT_MENU=true; fi

echo -e "\n\e[1mSelections\e[0m"
echo "    Anki: $INSTALL_ANKI"
echo "    Gaming Support Suite: $INSTALL_GAMING_SUITE"
echo "    qBittorrent: $INSTALL_QBITTORRENT"
echo "    Configure Git profile: $CONFIGURE_GIT_PROFILE"
echo "    Hide systemd-boot menu: $HIDE_SYSTEMD_BOOT_MENU"

# ==============================================================================
# System Update & Base Requirements
# ==============================================================================

echo -e "\n\e[1mUpdating system.\e[0m"
echo -n "    Running system update..."
run_with_spinner "update_system" run_sudo pacman -Syu --noconfirm

echo -e "\n\e[1mInstalling Yay.\e[0m"
echo -n "    Installing required build dependencies..."
run_with_spinner "install_base_devel" run_sudo pacman -S --needed --noconfirm git base-devel

if ! command -v yay >/dev/null 2>&1; then
    echo -n "    Cloning yay repository..."
    run_with_spinner "clone_yay_repo" ensure_repo_clone https://aur.archlinux.org/yay-bin.git "$HOME/yay-bin"

    echo -n "    Building and installing yay..."
    run_with_spinner "makepkg_yay" bash -c "cd '$HOME/yay-bin' && env PACMAN_AUTH='sudo -n' makepkg -si --noconfirm"
fi

# ==============================================================================
# Applications
# ==============================================================================

echo -e "\n\e[1mInstalling applications.\e[0m"
echo -n "    Installing Firefox..."
run_with_spinner "install_firefox" run_yay -S --needed --noconfirm firefox

echo -n "    Installing Dolphin Plugins..."
run_with_spinner "install_dolphin_plugins" run_yay -S --needed --noconfirm dolphin-plugins

echo -n "    Installing Firewalld..."
run_with_spinner "install_firewalld" run_yay -S --needed --noconfirm firewalld

echo -n "    Enabling Firewalld..."
run_with_spinner "enable_firewalld" run_sudo systemctl enable firewalld.service

echo -n "    Starting Firewalld..."
run_with_spinner "start_firewalld" run_sudo systemctl start firewalld.service

echo -n "    Cloning Visual Studio Code repository..."
run_with_spinner "clone_vscode_repo" ensure_repo_clone https://aur.archlinux.org/visual-studio-code-bin.git "$HOME/visual-studio-code-bin"

echo -n "    Building and installing Visual Studio Code..."
run_with_spinner "makepkg_vscode" bash -c "cd '$HOME/visual-studio-code-bin' && env PACMAN_AUTH='sudo -n' makepkg -si --noconfirm"

echo -n "    Installing Gwenview..."
run_with_spinner "install_gwenview" run_yay -S --needed --noconfirm gwenview

echo -n "    Installing Kio-admin..."
run_with_spinner "install_kio_admin" run_yay -S --needed --noconfirm kio-admin

if [ "$INSTALL_QBITTORRENT" = true ]; then
    echo -n "    Installing qBittorrent..."
    run_with_spinner "install_qbittorrent" run_yay -S --needed --noconfirm qbittorrent
fi

# ==============================================================================
# Themes, Fonts & Icons
# ==============================================================================

echo -e "\n\e[1mInstalling themes and fonts.\e[0m"
echo -n "    Installing Papirus Icon Theme..."
run_with_spinner "install_papirus_icon_theme" run_yay -S --needed --noconfirm papirus-icon-theme

echo -n "    Installing Papirus Folders..."
run_with_spinner "install_papirus_folders" run_yay -S --needed --noconfirm papirus-folders-git

echo -n "    Configuring Papirus Folders..."
run_with_spinner "configure_papirus_folders" papirus-folders -C bluegrey --theme Papirus-Dark

echo -n "    Installing Fira Code Font..."
run_with_spinner "install_fira_code_font" run_yay -S --needed --noconfirm ttf-fira-code

echo -n "    Installing Noto Fonts CJK..."
run_with_spinner "install_noto_fonts_cjk" run_yay -S --needed --noconfirm noto-fonts-cjk

# ==============================================================================
# Zenity GTK Dialogs
# ==============================================================================

echo -e "\n\e[1mInstalling Zenity GTK Dialogs.\e[0m"
echo -n "    Installing Zenity dependencies..."
run_with_spinner "install_zenity_dependencies" run_yay -S --needed --noconfirm breeze-gtk kde-gtk-config gsettings-desktop-schemas dconf

echo -n "    Installing Zenity GTK3..."
run_with_spinner "install_zenity" run_yay -S --needed --noconfirm zenity-gtk3

# ==============================================================================
# Input Method Framework (Fcitx5)
# ==============================================================================

echo -e "\n\e[1mConfiguring Fcitx5.\e[0m"
echo -n "    Installing Fcitx5..."
run_with_spinner "install_fcitx5_im" run_yay -S --needed --noconfirm fcitx5-im

echo -n "    Installing Fcitx5 Mozc..."
run_with_spinner "install_fcitx5_mozc" run_yay -S --needed --noconfirm fcitx5-mozc

echo -n "    Configuring Fcitx5 environment variables..."
run_with_spinner "configure_fcitx5" configure_fcitx5_env

echo -n "    Applying Fcitx5 configuration files..."
run_with_spinner "apply_fcitx5_config" safe_cp "$REPO_DIR/Home/user/.config/fcitx5" "$HOME/.config/fcitx5"

# ==============================================================================
# Theme Manager (Konsave)
# ==============================================================================

echo -e "\n\e[1mInstalling Konsave.\e[0m"
echo -n "    Installing Konsave..."
run_with_spinner "install_konsave" run_yay -S --needed --noconfirm konsave

if [ -f "$REPO_DIR/Themes/rouge-27-07-26.knsv" ]; then
    echo -n "    Importing Konsave theme..."
    run_with_spinner "import_konsave_theme" bash -c "cd '$REPO_DIR/Themes' && konsave -i rouge-27-07-26.knsv"

    echo -n "    Applying Konsave theme..."
    run_with_spinner "apply_konsave_theme" konsave -a rouge-27-07-26
fi

# ==============================================================================
# PDF Reader (Zathura)
# ==============================================================================

echo -e "\n\e[1mInstalling Zathura.\e[0m"
echo -n "    Installing Zathura..."
run_with_spinner "install_zathura" run_yay -S --needed --noconfirm zathura

echo -n "    Installing Zathura PDF Poppler plugin..."
run_with_spinner "install_zathura_pdf_poppler" run_yay -S --needed --noconfirm zathura-pdf-poppler

echo -n "    Configuring Zathura..."
run_with_spinner "apply_zathura_config" safe_cp "$REPO_DIR/Home/user/.config/zathura" "$HOME/.config/zathura"

# ==============================================================================
# Plasma Customizations (Wallpaper, Splash, Login Screen)
# ==============================================================================

echo -e "\n\e[1mConfiguring Plasma Customizations.\e[0m"
echo -n "    Applying wallpaper..."
run_with_spinner "apply_wallpaper" apply_wallpaper_plasma

echo -n "    Configuring splash screen..."
run_with_spinner "move_splash_screen" sync_splash_screen

echo -n "    Applying ksplashrc configuration..."
run_with_spinner "apply_splash_config" safe_cp "$REPO_DIR/Home/user/.config/ksplashrc" "$HOME/.config/ksplashrc"

echo -n "    Installing Qt5 graphical effects & controls..."
run_with_spinner "install_qt5_sddm_deps" run_yay -S --needed --noconfirm qt5-graphicaleffects qt5-quickcontrols qt5-quickcontrols2

echo -n "    Configuring SDDM login theme..."
run_with_spinner "move_login_screen" sync_login_screen

echo -n "    Applying SDDM configuration..."
run_with_spinner "move_sddm_config" sync_sddm_config

# ==============================================================================
# Shell & Git Configurations
# ==============================================================================

echo -e "\n\e[1mConfiguring Shell & Bootloader.\e[0m"
echo -n "    Configuring .bashrc..."
run_with_spinner "configure_bashrc" configure_bashrc_append

if [ "$CONFIGURE_GIT_PROFILE" = true ]; then
    echo -n "    Setting Git user.name..."
    run_with_spinner "configure_git_user_name" git config --global user.name "Daniel Vargas"

    echo -n "    Setting Git user.email..."
    run_with_spinner "configure_git_user_email" git config --global user.email d.vargasu@uniandes.edu.co
fi

echo -n "    Configuring kernel command line (quiet boot)..."
run_with_spinner "configure_bootloader" configure_kernel_cmdline

if [ "$HIDE_SYSTEMD_BOOT_MENU" = true ]; then
    echo -n "    Setting systemd-boot timeout to 0..."
    run_with_spinner "set_bootloader_timeout_zero" set_systemd_boot_timeout_zero
fi

# ==============================================================================
# Optional: Anki Flashcard Application
# ==============================================================================

if [ "$INSTALL_ANKI" = true ]; then
    echo -e "\n\e[1mInstalling Anki.\e[0m"
    echo -n "    Installing Anki..."
    run_with_spinner "install_anki" run_yay -S --needed --noconfirm anki-bin

    echo -n "    Applying Anki addons..."
    run_with_spinner "apply_anki_addons" safe_cp "$REPO_DIR/Home/user/.local/share/Anki2/addons21" "$HOME/.local/share/Anki2/addons21"
fi

# ==============================================================================
# Optional: Gaming Support Suite & Xow
# ==============================================================================

if [ "$INSTALL_GAMING_SUITE" = true ]; then
    echo -e "\n\e[1mInstalling Gaming Support Suite.\e[0m"
    echo -n "    Enabling multilib repository..."
    run_with_spinner "enable_multilib" enable_multilib_repo

    echo -n "    Updating system databases with multilib..."
    run_with_spinner "update_multilib" run_sudo pacman -Syu --noconfirm

    echo -n "    Installing Lutris..."
    run_with_spinner "install_lutris" run_yay -S --needed --noconfirm lutris

        echo -n "    Installing Wine..."
        run_with_spinner "install_wine" run_yay -S --needed --noconfirm wine

    echo -n "    Installing Feral GameMode..."
    run_with_spinner "install_feral_gamemode" run_yay -S --needed --noconfirm gamemode lib32-gamemode

    echo -n "    Configuring user 'games' group permissions..."
    run_with_spinner "add_user_to_games_group" run_sudo usermod -aG games "$USER"

    echo -e "\n\e[1mInstalling Xow (Xbox Wireless Dongle Support).\e[0m"
    echo -n "    Installing cabextract and libusb build dependencies..."
    run_with_spinner "install_xow_deps" run_sudo pacman -S --needed --noconfirm cabextract libusb

    echo -n "    Cloning xow repository..."
    run_with_spinner "clone_xow_repo" ensure_repo_clone https://github.com/medusalix/xow "$HOME/xow"

    echo -n "    Building xow..."
    run_with_spinner "build_xow" bash -c "cd '$HOME/xow' && make BUILD=RELEASE"

    echo -n "    Installing xow binary..."
    run_with_spinner "install_xow" bash -c "cd '$HOME/xow' && run_sudo make install"

    echo -n "    Downloading xow firmware..."
    run_with_spinner "download_xow_firmware" run_sudo xow-get-firmware.sh --skip-disclaimer

    echo -n "    Enabling xow service..."
    run_with_spinner "enable_xow_service" run_sudo systemctl enable xow

    echo -n "    Starting xow service..."
    run_with_spinner "start_xow_service" run_sudo systemctl start xow
fi

# ==============================================================================
# MPV Media Player & NetworkManager Portal Check
# ==============================================================================

echo -e "\n\e[1mInstalling MPV.\e[0m"
echo -n "    Installing MPV..."
run_with_spinner "install_mpv" run_sudo pacman -S --needed --noconfirm mpv

echo -n "    Applying MPV configuration files..."
run_with_spinner "apply_mpv_config" safe_cp "$REPO_DIR/Home/user/.config/mpv" "$HOME/.config/mpv"

echo -e "\n\e[1mReplacing Arch Captive Portal Detection with KDE.\e[0m"
echo -n "    Configuring NetworkManager captive portal detection..."
run_with_spinner "configure_captive_portal" configure_captive_portal

echo -n "    Restarting NetworkManager service..."
run_with_spinner "restart_networkmanager" run_sudo systemctl restart NetworkManager

# ==============================================================================
# Cleanup & Completion
# ==============================================================================

kill "$SUDO_KEEP_ALIVE_PID" 2>/dev/null
wait "$SUDO_KEEP_ALIVE_PID" 2>/dev/null

echo -e "\n\e[1mInstallation complete.\e[0m"
read -rp "Do you want to reboot the system now? (y/n): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Rebooting system in 5 seconds..."
    sleep 5
    run_sudo reboot
else
    echo "Reboot canceled. Please reboot manually when ready."
fi