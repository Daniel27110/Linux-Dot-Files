#!/bin/bash

# ==============================================================================
# Script Information
# ==============================================================================

# This script is intended to work in the following environment:
# - Arch Linux (should also work in any Arch based distribution)
# - KDE Plasma 6 with an active internet connection
# - Systemd-boot as the bootloader

# How to use:
# - Clone this repository: git clone https://github.com/Daniel27110/Linux-Dot-Files
# - Enter the directory: cd Linux-Dot-Files
# - Make the script executable: chmod +x Install.sh
# - Run the script: ./Install.sh

# This script will install the following packages:
# - Yay (AUR Helper)
# - Firefox
# - Firewalld
# - Visual Studio Code (Proprietary)
# - Gwenview (Image Viewer)
# - Kio-admin (Root File Manager)
# - Papirus Icon Theme
# - Fira Code Font
# - Noto Fonts CJK (Chinese, Japanese, Korean)
# - Fcitx5 (Input Method Framework)
# - Konsave (Theme Manager)
# - Zathura (PDF Reader)
# - Anki (Flashcard Application)
# - Lutris (Game Manager)
# - Proton GE (Proton for running Windows games)
# - Feral GameMode (Game Performance Optimizations)
# - MPV (Media Player)

# ==============================================================================
# Initialization
# ==============================================================================

LOG_FILE=~/install_steps.log
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Enforce non-interactive sudo after initial authentication.
SUDO_CMD=(sudo -n)

# Always run yay with a sudo loop and non-interactive sudo flags.
YAY_BASE_ARGS=(--sudoloop --sudoflags "-n")

# Function to log a completed step
log_step() {
    echo "$1" >> "$LOG_FILE"
}

# Function to check if a step is already completed
is_step_completed() {
    grep -Fqw "$1" "$LOG_FILE"
}

# Initialize log file
if [ ! -f $LOG_FILE ]; then
    touch $LOG_FILE
fi

# Check if the user already has an active sudo session
if sudo -n true 2>/dev/null; then
    echo "Sudo access is already available. Continuing with the installation."
else
    echo "Please enter your sudo password:"
    sudo -v || { echo "Failed to get sudo access. Exiting."; exit 1; }
fi

# Keep sudo session alive for the duration of the script
keep_sudo_alive() {
    while true; do
        sudo -n -v > /dev/null 2>&1 || exit 1
        sleep 30
    done &
    SUDO_KEEP_ALIVE_PID=$!
}

run_sudo() {
    "${SUDO_CMD[@]}" "$@"
}

run_yay() {
    yay "${YAY_BASE_ARGS[@]}" "$@"
}

ensure_repo_clone() {
    local url="$1"
    local dir="$2"

    if [ -d "$dir/.git" ]; then
        git -C "$dir" fetch --depth 1 origin > /dev/null 2>&1 || return 1
        local default_branch
        default_branch=$(git -C "$dir" remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
        default_branch="${default_branch:-master}"
        git -C "$dir" reset --hard "origin/$default_branch" > /dev/null 2>&1 || return 1
    elif [ -d "$dir" ]; then
        rm -rf "$dir" || return 1
        git clone "$url" "$dir" > /dev/null 2>&1 || return 1
    else
        git clone "$url" "$dir" > /dev/null 2>&1 || return 1
    fi
}

append_unique_line_sudo() {
    local file="$1"
    local line="$2"
    if ! run_sudo grep -Fxq "$line" "$file"; then
        printf '%s\n' "$line" | run_sudo tee -a "$file" > /dev/null
    fi
}

configure_fcitx5_env() {
    append_unique_line_sudo /etc/environment "GTK_IM_MODULE=fcitx" || return 1
    append_unique_line_sudo /etc/environment "QT_IM_MODULE=fcitx" || return 1
    append_unique_line_sudo /etc/environment "XMODIFIERS=@im=fcitx" || return 1
}

sync_splash_screen() {
    mkdir -p "$HOME/.local/share/plasma/look-and-feel" || return 1
    rm -rf "$HOME/.local/share/plasma/look-and-feel/Rouge-Splash" || return 1
    cp -a "$REPO_DIR/Themes/Splash/Rouge-Splash" "$HOME/.local/share/plasma/look-and-feel/" || return 1
}

sync_login_screen() {
    run_sudo rm -rf /usr/share/sddm/themes/Rouge || return 1
    run_sudo cp -a "$REPO_DIR/Themes/Login/Rouge" /usr/share/sddm/themes/ || return 1
}

sync_sddm_config() {
    run_sudo mkdir -p /etc/sddm.conf.d/ || return 1
    run_sudo install -m 0644 "$REPO_DIR/Home/user/.config/kde_settings.conf" /etc/sddm.conf.d/kde_settings.conf || return 1
}

set_systemd_boot_timeout_zero() {
    local loader_conf="/boot/loader/loader.conf"

    if run_sudo grep -Eq '^[[:space:]]*timeout[[:space:]]+0([[:space:]]|$)' "$loader_conf"; then
        return 0
    fi

    if run_sudo grep -Eq '^[[:space:]]*timeout[[:space:]]+' "$loader_conf"; then
        run_sudo sed -Ei 's/^[[:space:]]*timeout[[:space:]]+.*/timeout 0/' "$loader_conf"
    else
        printf '\ntimeout 0\n' | run_sudo tee -a "$loader_conf" > /dev/null
    fi
}

# Prompt helper for yes/no questions
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

# Improved spinner function with consistent tab alignment
run_with_spinner() {
    local step="$1"
    shift
    echo ""
    if is_step_completed "$step"; then
        printf "\t\e[33mSKIPPED\e[0m\n"
        return 0
    fi
    # Start the command in the foreground, but capture its PID for the spinner
    (
        "$@" > /dev/null 2>&1
    ) &
    local cmd_pid=$!
    spinner $cmd_pid
    wait $cmd_pid
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        printf "\t\e[31mFAILED\e[0m\n"
    else
        printf "\t\e[32mSUCCESS\e[0m\n"
        log_step "$step"
    fi
    return $exit_code
}

# Spinner function to show progress while a command is running
spinner() {
    local pid=$1
    local delay=0.1
    local spinster='|/-\'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i + 1) % 4 ))
        printf "\r\t[%c]  " "${spinster:$i:1}"
        sleep $delay
    done
    printf "\r\t    \r"
}

# ==============================================================================
# Installation Options
# ==============================================================================

echo -e "\n\e[1mWelcome to the Rouge Linux setup installer.\e[0m"
echo "This script installs applications, themes, and configurations for customizing KDE Plasma 6 on Arch Linux."
echo "Choose optional software below before installation starts."

INSTALL_ANKI=false
INSTALL_GAMING_SUITE=false
INSTALL_QBITTORRENT=false
CONFIGURE_GIT_PROFILE=false
HIDE_SYSTEMD_BOOT_MENU=false

echo -e "\n\e[1mOptional software\e[0m"
if prompt_yes_no "Install Anki (flashcards)" "y"; then
    INSTALL_ANKI=true
fi

if prompt_yes_no "Install Gaming Support Suite (Lutris, Proton GE, GameMode, Xow)" "y"; then
    INSTALL_GAMING_SUITE=true
fi

if prompt_yes_no "Install qBittorrent" "n"; then
    INSTALL_QBITTORRENT=true
fi

if prompt_yes_no "Configure Git global profile (name + email)" "n"; then
    CONFIGURE_GIT_PROFILE=true
fi

if prompt_yes_no "Hide systemd-boot menu (set timeout to 0)" "n"; then
    HIDE_SYSTEMD_BOOT_MENU=true
fi

echo -e "\n\e[1mSelections\e[0m"
echo "    Anki: $INSTALL_ANKI"
echo "    Gaming Support Suite: $INSTALL_GAMING_SUITE"
echo "    qBittorrent: $INSTALL_QBITTORRENT"
echo "    Configure Git profile: $CONFIGURE_GIT_PROFILE"
echo "    Hide systemd-boot menu: $HIDE_SYSTEMD_BOOT_MENU"

# Keep sudo session alive
keep_sudo_alive

# ==============================================================================
# System Update
# ==============================================================================

echo -e "\n\e[1mUpdating system.\e[0m"
echo -n "    Running system update..."
cd ~
run_with_spinner "update_system" run_sudo pacman -Syu --noconfirm

# ==============================================================================
# Install Yay (AUR Helper)
# ==============================================================================

echo -e "\n\e[1mInstalling Yay.\e[0m"
echo -n "    Installing required packages..."
run_with_spinner "install_yay" run_sudo pacman -S --needed git base-devel --noconfirm

echo -n "    Cloning yay repository..."
run_with_spinner "clone_yay_repo" ensure_repo_clone https://aur.archlinux.org/yay-bin.git "$HOME/yay-bin"

cd yay-bin
echo -n "    Building and installing yay..."
run_with_spinner "makepkg_yay" env PACMAN_AUTH="sudo -n" makepkg -si --noconfirm
cd ~

# ==============================================================================
# Install Applications
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

echo -n "    Installing Visual Studio Code..."
run_with_spinner "clone_vscode_repo" ensure_repo_clone https://aur.archlinux.org/visual-studio-code-bin.git "$HOME/visual-studio-code-bin"
cd visual-studio-code-bin

echo -n "    Building and installing Visual Studio Code..."
run_with_spinner "makepkg_vscode" env PACMAN_AUTH="sudo -n" makepkg -si --noconfirm
cd ~

echo -n "    Installing Gwenview..."
run_with_spinner "install_gwenview" run_yay -S --needed --noconfirm gwenview

echo -n "    Installing Kio-admin..."
run_with_spinner "install_kio_admin" run_yay -S --needed --noconfirm kio-admin

if [ "$INSTALL_QBITTORRENT" = true ]; then
    echo -n "    Installing qBittorrent..."
    run_with_spinner "install_qbittorrent" run_yay -S --needed --noconfirm qbittorrent
else
    echo -e "    Skipping qBittorrent."
fi

# ==============================================================================
# Install Themes and Fonts
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
# Install Zenity GTK Dialogs
# ==============================================================================

echo -e "\n\e[1mInstalling Zenity GTK Dialogs.\e[0m"

echo -n "    Installing Zenity GTK Dialogs dependencies..."
run_with_spinner "install_zenity_dependencies" run_yay -S --needed --noconfirm breeze-gtk kde-gtk-config gsettings-desktop-schemas dconf

echo -n "    Installing Zenity GTK Dialogs..."
run_with_spinner "install_zenity" run_yay -S --needed --noconfirm zenity-gtk3

# ==============================================================================
# Configure Fcitx5 (Input Method Framework)
# ==============================================================================

echo -e "\n\e[1mConfiguring Fcitx5.\e[0m"

echo -n "    Installing Fcitx5..."
run_with_spinner "install_fcitx5_im" run_yay -S --needed --noconfirm fcitx5-im
echo -n "    Installing Fcitx5 Mozc..."
run_with_spinner "install_fcitx5_mozc" run_yay -S --needed --noconfirm fcitx5-mozc

echo -n "    Configuring Fcitx5 environment variables..."
run_with_spinner "configure_fcitx5" configure_fcitx5_env

echo -n "    Applying Fcitx5 configuration files..."
mkdir -p "$HOME/.config"
run_with_spinner "apply_fcitx5_config" cp -a "$REPO_DIR/Home/user/.config/fcitx5" "$HOME/.config/"

# ==============================================================================
# Install Konsave (Theme Manager)
# ==============================================================================

echo -e "\n\e[1mInstalling Konsave.\e[0m"
echo -n "    Installing Konsave..."
run_with_spinner "install_konsave" run_yay -S --needed --noconfirm konsave

cd "$REPO_DIR/Themes"
echo -n "    Importing Konsave theme..."
run_with_spinner "import_konsave_theme" konsave -i rouge-12-02-26.knsv

echo -n "    Applying Konsave theme..."
run_with_spinner "apply_konsave_theme" konsave -a rouge-12-02-26
cd ~

# ==============================================================================
# Install Zathura (PDF Reader)
# ==============================================================================

echo -e "\n\e[1mInstalling Zathura.\e[0m"

echo -n "    Installing Zathura..."
run_with_spinner "install_zathura" run_yay -S --needed --noconfirm zathura

echo -n "    Installing Zathura Plugins..."
run_with_spinner "install_zathura_pdf_poppler" run_yay -S --needed --noconfirm zathura-pdf-poppler

cd "$REPO_DIR/Home/user/.config"
echo -n "    Configuring Zathura..."
mkdir -p "$HOME/.config"
run_with_spinner "move_zathura_config" cp -a "$REPO_DIR/Home/user/.config/zathura" "$HOME/.config/"
cd ~

# ==============================================================================
# Configure Wallpaper
# ==============================================================================

echo -e "\n\e[1mConfiguring Wallpaper.\e[0m"

echo -n "    Moving wallpaper to Pictures directory..."
mkdir -p "$HOME/Pictures"
run_with_spinner "move_wallpaper" install -m 0644 "$REPO_DIR/Pictures/Rouge.jpg" "$HOME/Pictures/Rouge.jpg"

echo -n "    Applying wallpaper..."
run_with_spinner "apply_wallpaper" qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'var allDesktops = desktops();print (allDesktops);for (i=0;i<allDesktops.length;i++) {d = allDesktops[i];d.wallpaperPlugin = "org.kde.image";d.currentConfigGroup = Array("Wallpaper","org.kde.image","General");d.writeConfig("Image", "file://'"$HOME"'/Pictures/Rouge.jpg");}'


# ==============================================================================
# Configure Splash Screen
# ==============================================================================

echo -e "\n\e[1mConfiguring Splash Screen.\e[0m"

echo -n "    Moving splash screen..."
run_with_spinner "move_splash_screen" sync_splash_screen

echo -n "    Applying splash screen..."
run_with_spinner "apply_splash_screen" install -Dm644 "$REPO_DIR/Home/user/.config/ksplashrc" "$HOME/.config/ksplashrc"

# ==============================================================================
# Configure Login Screen
# ==============================================================================

echo -e "\n\e[1mConfiguring Login Screen.\e[0m"

echo -n "    Installing qt5-graphicaleffects..."
run_with_spinner "install_qt5_graphicaleffects" run_yay -S --needed --noconfirm qt5-graphicaleffects

echo -n "    Installing qt5-quickcontrols..."
run_with_spinner "install_qt5_quickcontrols" run_yay -S --needed --noconfirm qt5-quickcontrols

echo -n "    Installing qt5-quickcontrols2..."
run_with_spinner "install_qt5_quickcontrols2" run_yay -S --needed --noconfirm qt5-quickcontrols2

echo -n "    Moving login screen..."
run_with_spinner "move_login_screen" sync_login_screen

echo -n "    Applying login screen..."
run_with_spinner "move_sddm_config" sync_sddm_config

# ==============================================================================
# Configure .bashrc
# ==============================================================================

echo -e "\n\e[1mConfiguring .bashrc.\e[0m"

echo -n "    Configuring .bashrc..."
if is_step_completed "configure_bashrc"; then
    echo -e "\n\t\e[33mSKIPPED\e[0m"  # Added line break before "SKIPPED"
else
    if grep -Fqx "trap 'preexec_invoke_exec' DEBUG" ~/.bashrc; then
        echo -e "\n\t\e[33mSKIPPED\e[0m"
        log_step "configure_bashrc"
    else
        cat "$REPO_DIR/Home/user/.bashrc_append" >> ~/.bashrc && echo -e "\n\t\e[32mSUCCESS\e[0m" && log_step "configure_bashrc" || echo -e "\n\t\e[31mFAILED\e[0m"
    fi
fi

# ==============================================================================
# Configure Git Profile
# ==============================================================================

if [ "$CONFIGURE_GIT_PROFILE" = true ]; then
    echo -e "\n\e[1mConfiguring Git profile.\e[0m"

    echo -n "    Setting Git user.name..."
    run_with_spinner "configure_git_user_name" git config --global user.name "Daniel Vargas"

    echo -n "    Setting Git user.email..."
    run_with_spinner "configure_git_user_email" git config --global user.email d.vargasu@uniandes.edu.co
else
    echo -e "\n\e[1mSkipping Git profile configuration (not selected).\e[0m"
fi

# ==============================================================================
# Configure Bootloader
# ==============================================================================

echo -e "\n\e[1mConfiguring Bootloader.\e[0m"

echo -n "    Configuring bootloader..."
cd /boot/loader/entries
if is_step_completed "configure_bootloader"; then
    echo -e "\n\t\e[33mSKIPPED\e[0m"  # Added line break before "SKIPPED"
else
    for file in *_linux.conf; do
        if run_sudo grep -Eq '^options.*\bquiet\b' "$file"; then
            continue
        fi
        run_sudo sed -i '/^options/ s/$/ quiet/' "$file" && echo -e "\n\t\e[32mSUCCESS\e[0m" && log_step "configure_bootloader" || echo -e "\n\t\e[31mFAILED\e[0m"
    done
fi
cd ~

if [ "$HIDE_SYSTEMD_BOOT_MENU" = true ]; then
    echo -n "    Setting systemd-boot timeout to 0..."
    run_with_spinner "set_bootloader_timeout_zero" set_systemd_boot_timeout_zero
else
    echo -e "    Skipping systemd-boot timeout change (not selected)."
fi

# ==============================================================================
# Install Anki
# ==============================================================================

if [ "$INSTALL_ANKI" = true ]; then
    echo -e "\n\e[1mInstalling Anki.\e[0m"

    echo -n "    Installing Anki..."
    run_with_spinner "install_anki" run_yay -S --needed --noconfirm anki-bin

    echo -n "    Applying Anki addons..."
    mkdir -p ~/.local/share/Anki2/addons21/

    run_with_spinner "apply_anki_addons" cp -a "$REPO_DIR/Home/user/.local/share/Anki2/addons21/." "$HOME/.local/share/Anki2/addons21/"
else
    echo -e "\n\e[1mSkipping Anki (not selected).\e[0m"
fi

# ==============================================================================
# Install Gaming Support Suite
# ==============================================================================

if [ "$INSTALL_GAMING_SUITE" = true ]; then
    echo -e "\n\e[1mInstalling Gaming Support Suite.\e[0m"

    # Enable the multilib repository if not already enabled
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo -n "    Enabling multilib repository..."
        run_with_spinner "enable_multilib" run_sudo sed -i '/^#\[multilib\]$/,/^#Include/s/^#//' /etc/pacman.conf
    elif grep -q "^#Include = /etc/pacman.d/mirrorlist" /etc/pacman.conf; then
        echo -n "    Enabling multilib repository..."
        run_with_spinner "enable_multilib" run_sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
    fi

    # Update the multilib repository
    echo -n "    Updating system with multilib..."
    run_with_spinner "update_multilib" run_sudo pacman -Syu --noconfirm

    echo -n "    Installing Lutris..."
    run_with_spinner "install_lutris" run_yay -S --needed --noconfirm lutris

    echo -n "    Installing Proton GE..."
    run_with_spinner "install_proton_ge" run_yay -S --needed --noconfirm proton-ge-custom-bin

    # Install Feral GameMode
    echo -n "    Installing Feral GameMode..."
    run_with_spinner "install_feral_gamemode" run_yay -S --needed --noconfirm gamemode lib32-gamemode

    # Add the user to the 'games' group. "Without it, the GameMode user daemon will not have rights to change CPU governor or the niceness of processes.".
    echo -n "    Adding user to 'games' group..."

    # Check if the 'games' group exists
    if getent group games > /dev/null; then
        run_with_spinner "add_user_to_games_group" run_sudo usermod -aG games $USER
    else
        echo -n "    Creating 'games' group..."
        run_with_spinner "create_games_group" run_sudo groupadd games
        run_with_spinner "add_user_to_games_group" run_sudo usermod -aG games $USER
    fi
else
    echo -e "\n\e[1mSkipping Gaming Support Suite (not selected).\e[0m"
fi



# ==============================================================================
# Install XOW (Xbox One Controller Driver)
# ==============================================================================

if [ "$INSTALL_GAMING_SUITE" = true ]; then
    echo -e "\n\e[1mInstalling Xow (Xbox Wireless Dongle support).\e[0m"

    echo -n "    Cloning xow repository..."
    run_with_spinner "clone_xow_repo" ensure_repo_clone https://github.com/medusalix/xow "$HOME/xow"

    cd xow
    echo -n "    Building xow..."
    run_with_spinner "build_xow" make BUILD=RELEASE

    echo -n "    Installing xow..."
    run_with_spinner "install_xow" run_sudo make install

    echo -n "    Downloading xow firmware..."
    run_with_spinner "download_xow_firmware" run_sudo xow-get-firmware.sh --skip-disclaimer

    echo -n "    Enabling xow service..."
    run_with_spinner "enable_xow_service" run_sudo systemctl enable xow

    echo -n "    Starting xow service..."
    run_with_spinner "start_xow_service" run_sudo systemctl start xow
else
    echo -e "\n\e[1mSkipping Xow (Gaming Support Suite not selected).\e[0m"
fi



# ==============================================================================
# MPV (Media Player)
# ==============================================================================

echo -e "\n\e[1mInstalling MPV.\e[0m"

echo -n "    Installing MPV..."
run_with_spinner "install_mpv" run_sudo pacman -S --needed mpv --noconfirm

echo -n "    Applying MPV configuration files..."
mkdir -p "$HOME/.config"
run_with_spinner "apply_mpv_config" cp -a "$REPO_DIR/Home/user/.config/mpv" "$HOME/.config/"



# ==============================================================================
# Replace Arch's Captive Portal Detection with Kde
# ==============================================================================

echo -e "\n\e[1mReplacing Arch's Captive Portal Detection with Kde.\e[0m"

# Create the following script at /etc/NetworkManager/conf.d/20-connectivity.conf
# And the same at /usr/lib/NetworkManager/conf.d/20-connectivity.conf with the following content:
# [connectivity]
# uri=https://networkcheck.kde.org/
# interval=300

echo -n "    Configuring NetworkManager captive portal detection..."
run_with_spinner "configure_captive_portal" run_sudo bash -c 'cat << EOF > /etc/NetworkManager/conf.d/20-connectivity.conf
[connectivity]
uri=https://networkcheck.kde.org/
interval=300
EOF'

run_with_spinner "configure_captive_portal_lib" run_sudo bash -c 'cat << EOF > /usr/lib/NetworkManager/conf.d/20-connectivity.conf
[connectivity]
uri=https://networkcheck.kde.org/
interval=300
EOF'

echo -n "    Restarting NetworkManager service..."
run_with_spinner "restart_networkmanager" run_sudo systemctl restart NetworkManager

# ==============================================================================
# Final Steps
# ==============================================================================

# Kill the keep_sudo_alive process
kill $SUDO_KEEP_ALIVE_PID
wait $SUDO_KEEP_ALIVE_PID 2>/dev/null

# End the script with a message
echo -e "\n\e[1mInstallation complete.\e[0m"
read -p "Do you want to reboot the system now? (y/n): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Rebooting system in 10 seconds."
    sleep 10
    reboot
else
    echo "Reboot canceled. Please reboot manually when ready."
fi
