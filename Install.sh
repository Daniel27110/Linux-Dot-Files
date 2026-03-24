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

# Function to log a completed step
log_step() {
    echo "$1" >> $LOG_FILE
}

# Function to check if a step is already completed
is_step_completed() {
    grep -qw "$1" $LOG_FILE
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
    while true; do sudo -n -v; sleep 10; done &
    SUDO_KEEP_ALIVE_PID=$!
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

echo -e "\n\e[1mSelections\e[0m"
echo "    Anki: $INSTALL_ANKI"
echo "    Gaming Support Suite: $INSTALL_GAMING_SUITE"
echo "    qBittorrent: $INSTALL_QBITTORRENT"

# Keep sudo session alive
keep_sudo_alive

# ==============================================================================
# System Update
# ==============================================================================

echo -e "\n\e[1mUpdating system.\e[0m"
echo -n "    Running system update..."
cd ~
run_with_spinner "update_system" sudo pacman -Syu --noconfirm

# ==============================================================================
# Install Yay (AUR Helper)
# ==============================================================================

echo -e "\n\e[1mInstalling Yay.\e[0m"
echo -n "    Installing required packages..."
run_with_spinner "install_yay" sudo pacman -S --needed git base-devel --noconfirm

echo -n "    Cloning yay repository..."
run_with_spinner "clone_yay_repo" git clone https://aur.archlinux.org/yay-bin.git

cd yay-bin
echo -n "    Building and installing yay..."
run_with_spinner "makepkg_yay" makepkg -si --noconfirm
cd ~

# ==============================================================================
# Install Applications
# ==============================================================================

echo -e "\n\e[1mInstalling applications.\e[0m"

echo -n "    Installing Firefox..."
run_with_spinner "install_firefox" yay -S firefox --noconfirm

echo -n "    Installing Dolphin Plugins..."
run_with_spinner "install_dolphin_plugins" yay -S dolphin-plugins --noconfirm

echo -n "    Installing Firewalld..."
run_with_spinner "install_firewalld" yay -S firewalld --noconfirm

echo -n "    Enabling Firewalld..."
run_with_spinner "enable_firewalld" sudo systemctl enable firewalld.service

echo -n "    Starting Firewalld..."
run_with_spinner "start_firewalld" sudo systemctl start firewalld.service

echo -n "    Installing Visual Studio Code..."
run_with_spinner "clone_vscode_repo" git clone https://aur.archlinux.org/visual-studio-code-bin.git
cd visual-studio-code-bin

echo -n "    Building and installing Visual Studio Code..."
run_with_spinner "makepkg_vscode" makepkg -si --noconfirm
cd ~

echo -n "    Installing Gwenview..."
run_with_spinner "install_gwenview" yay -S gwenview --noconfirm

echo -n "    Installing Kio-admin..."
run_with_spinner "install_kio_admin" yay -S kio-admin --noconfirm

if [ "$INSTALL_QBITTORRENT" = true ]; then
    echo -n "    Installing qBittorrent..."
    run_with_spinner "install_qbittorrent" yay -S qbittorrent --noconfirm
else
    echo -e "    Skipping qBittorrent."
fi

# ==============================================================================
# Install Themes and Fonts
# ==============================================================================

echo -e "\n\e[1mInstalling themes and fonts.\e[0m"

echo -n "    Installing Papirus Icon Theme..."
run_with_spinner "install_papirus_icon_theme" yay -S papirus-icon-theme --noconfirm

echo -n "    Installing Papirus Folders..."
run_with_spinner "install_papirus_folders" yay -S papirus-folders-git --noconfirm

echo -n "    Configuring Papirus Folders..."
run_with_spinner "configure_papirus_folders" papirus-folders -C bluegrey --theme Papirus-Dark

echo -n "    Installing Fira Code Font..."
run_with_spinner "install_fira_code_font" yay -S ttf-fira-code --noconfirm

echo -n "    Installing Noto Fonts CJK..."
run_with_spinner "install_noto_fonts_cjk" yay -S noto-fonts-cjk --noconfirm

# ==============================================================================
# Install Zenity GTK Dialogs
# ==============================================================================

echo -e "\n\e[1mInstalling Zenity GTK Dialogs.\e[0m"

echo -n "    Installing Zenity GTK Dialogs dependencies..."
run_with_spinner "install_zenity_dependencies" yay -S --noconfirm breeze-gtk kde-gtk-config gsettings-desktop-schemas dconf

echo -n "    Installing Zenity GTK Dialogs..."
run_with_spinner "install_zenity" yay -S zenity-gtk3 --noconfirm

# ==============================================================================
# Configure Fcitx5 (Input Method Framework)
# ==============================================================================

echo -e "\n\e[1mConfiguring Fcitx5.\e[0m"

echo -n "    Installing Fcitx5..."
run_with_spinner "install_fcitx5_im" yay -S fcitx5-im --noconfirm
echo -n "    Installing Fcitx5 Mozc..."
run_with_spinner "install_fcitx5_mozc" yay -S fcitx5-mozc --noconfirm

echo -n "    Configuring Fcitx5 environment variables..."
run_with_spinner "configure_fcitx5" bash -c 'echo "GTK_IM_MODULE=fcitx" | sudo tee -a /etc/environment > /dev/null && \
echo "QT_IM_MODULE=fcitx" | sudo tee -a /etc/environment > /dev/null && \
echo "XMODIFIERS=@im=fcitx" | sudo tee -a /etc/environment > /dev/null'

echo -n "    Applying Fcitx5 configuration files..."
cd ~/Linux-Dot-Files/Home/user/.config
run_with_spinner "apply_fcitx5_config" mv fcitx5 ~/.config/
cd ~

# ==============================================================================
# Install Konsave (Theme Manager)
# ==============================================================================

echo -e "\n\e[1mInstalling Konsave.\e[0m"
echo -n "    Installing Konsave..."
run_with_spinner "install_konsave" yay -S konsave --noconfirm

cd ~/Linux-Dot-Files/Themes
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
run_with_spinner "install_zathura" yay -S zathura --noconfirm

echo -n "    Installing Zathura Plugins..."
run_with_spinner "install_zathura_pdf_poppler" yay -S zathura-pdf-poppler --noconfirm

cd ~/Linux-Dot-Files/Home/user/.config
echo -n "    Configuring Zathura..."
run_with_spinner "move_zathura_config" mv zathura ~/.config
cd ~

# ==============================================================================
# Configure Wallpaper
# ==============================================================================

echo -e "\n\e[1mConfiguring Wallpaper.\e[0m"

echo -n "    Moving wallpaper to Pictures directory..."
cd ~/Linux-Dot-Files/Pictures
run_with_spinner "move_wallpaper" mv Rouge.jpg ~/Pictures
cd ~

echo -n "    Applying wallpaper..."
run_with_spinner "apply_wallpaper" qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'var allDesktops = desktops();print (allDesktops);for (i=0;i<allDesktops.length;i++) {d = allDesktops[i];d.wallpaperPlugin = "org.kde.image";d.currentConfigGroup = Array("Wallpaper","org.kde.image","General");d.writeConfig("Image", "file://'"$HOME"'/Pictures/Rouge.jpg");}'


# ==============================================================================
# Configure Splash Screen
# ==============================================================================

echo -e "\n\e[1mConfiguring Splash Screen.\e[0m"

echo -n "    Moving splash screen..."
cd ~/Linux-Dot-Files/Themes/Splash/
sudo rm -rf ~/.local/share/plasma/look-and-feel/Rouge-Splash
run_with_spinner "move_splash_screen" sudo mv Rouge-Splash/ ~/.local/share/plasma/look-and-feel/
cd ~

echo -n "    Applying splash screen..."
cd ~/Linux-Dot-Files/Home/user/.config
run_with_spinner "apply_splash_screen" mv ksplashrc ~/.config
cd ~

# ==============================================================================
# Configure Login Screen
# ==============================================================================

echo -e "\n\e[1mConfiguring Login Screen.\e[0m"

echo -n "    Installing qt5-graphicaleffects..."
run_with_spinner "install_qt5_graphicaleffects" yay -S qt5-graphicaleffects --noconfirm

echo -n "    Installing qt5-quickcontrols..."
run_with_spinner "install_qt5_quickcontrols" yay -S qt5-quickcontrols --noconfirm

echo -n "    Installing qt5-quickcontrols2..."
run_with_spinner "install_qt5_quickcontrols2" yay -S qt5-quickcontrols2 --noconfirm

echo -n "    Moving login screen..."
cd ~/Linux-Dot-Files/Themes/Login/
sudo rm -rf /usr/share/sddm/themes/Rouge
run_with_spinner "move_login_screen" sudo mv Rouge/ /usr/share/sddm/themes/
cd ~

echo -n "    Applying login screen..."
cd ~/Linux-Dot-Files/Home/user/.config
if [ ! -d "/etc/sddm.conf.d/" ]; then
    sudo mkdir /etc/sddm.conf.d/
fi
run_with_spinner "move_sddm_config" sudo mv kde_settings.conf /etc/sddm.conf.d/
cd ~

# ==============================================================================
# Configure .bashrc
# ==============================================================================

echo -e "\n\e[1mConfiguring .bashrc.\e[0m"

echo -n "    Configuring .bashrc..."
if is_step_completed "configure_bashrc"; then
    echo -e "\n\t\e[33mSKIPPED\e[0m"  # Added line break before "SKIPPED"
else
    cat ~/Linux-Dot-Files/Home/user/.bashrc_append >> ~/.bashrc && echo -e "\n\t\e[32mSUCCESS\e[0m" && log_step "configure_bashrc" || echo -e "\n\t\e[31mFAILED\e[0m"
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
        sudo sed -i '/options/ s/$/ quiet/' "$file" && echo -e "\n\t\e[32mSUCCESS\e[0m" && log_step "configure_bootloader" || echo -e "\n\t\e[31mFAILED\e[0m"
    done
fi
cd ~

# ==============================================================================
# Install Anki
# ==============================================================================

if [ "$INSTALL_ANKI" = true ]; then
    echo -e "\n\e[1mInstalling Anki.\e[0m"

    echo -n "    Installing Anki..."
    run_with_spinner "install_anki" yay -S anki-bin --noconfirm

    echo -n "    Applying Anki addons..."
    mkdir -p ~/.local/share/Anki2/addons21/

    cd ~/Linux-Dot-Files/Home/user/.local/share/Anki2/addons21/
    run_with_spinner "apply_anki_addons" mv * ~/.local/share/Anki2/addons21/
    cd ~
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
        run_with_spinner "enable_multilib" sudo sed -i '/^#\[multilib\]$/,/^#Include/s/^#//' /etc/pacman.conf
    elif grep -q "^#Include = /etc/pacman.d/mirrorlist" /etc/pacman.conf; then
        echo -n "    Enabling multilib repository..."
        run_with_spinner "enable_multilib" sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
    fi

    # Update the multilib repository
    echo -n "    Updating system with multilib..."
    run_with_spinner "update_multilib" sudo pacman -Syu --noconfirm

    echo -n "    Installing Lutris..."
    run_with_spinner "install_lutris" yay -S lutris --noconfirm

    echo -n "    Installing Proton GE..."
    run_with_spinner "install_proton_ge" yay -S proton-ge-custom-bin --noconfirm

    # Install Feral GameMode
    echo -n "    Installing Feral GameMode..."
    run_with_spinner "install_feral_gamemode" yay -S gamemode lib32-gamemode --noconfirm

    # Add the user to the 'games' group. "Without it, the GameMode user daemon will not have rights to change CPU governor or the niceness of processes.".
    echo -n "    Adding user to 'games' group..."

    # Check if the 'games' group exists
    if getent group games > /dev/null; then
        run_with_spinner "add_user_to_games_group" sudo usermod -aG games $USER
    else
        echo -n "    Creating 'games' group..."
        run_with_spinner "create_games_group" sudo groupadd games
        run_with_spinner "add_user_to_games_group" sudo usermod -aG games $USER
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
    run_with_spinner "clone_xow_repo" git clone https://github.com/medusalix/xow

    cd xow
    echo -n "    Building xow..."
    run_with_spinner "build_xow" make BUILD=RELEASE

    echo -n "    Installing xow..."
    run_with_spinner "install_xow" sudo make install

    echo -n "    Downloading xow firmware..."
    run_with_spinner "download_xow_firmware" sudo xow-get-firmware.sh --skip-disclaimer

    echo -n "    Enabling xow service..."
    run_with_spinner "enable_xow_service" sudo systemctl enable xow

    echo -n "    Starting xow service..."
    run_with_spinner "start_xow_service" sudo systemctl start xow
else
    echo -e "\n\e[1mSkipping Xow (Gaming Support Suite not selected).\e[0m"
fi



# ==============================================================================
# MPV (Media Player)
# ==============================================================================

echo -e "\n\e[1mInstalling MPV.\e[0m"

echo -n "    Installing MPV..."
run_with_spinner "install_mpv" sudo pacman -S mpv --noconfirm

echo -n "    Applying MPV configuration files..."
cd ~/Linux-Dot-Files/Home/user/.config
run_with_spinner "apply_mpv_config" mv mpv ~/.config/



# ==============================================================================
# Replace Arch's Captive Portal Detection with Firefox
# ==============================================================================

echo -e "\n\e[1mReplacing Arch's Captive Portal Detection with Firefox.\e[0m"

# Create the following script at /etc/NetworkManager/conf.d/20-connectivity.conf
# [connectivity]
# uri=http://detectportal.firefox.com/success.txt
# interval=300

echo -n "    Configuring NetworkManager captive portal detection..."
run_with_spinner "configure_captive_portal" sudo bash -c 'cat << EOF > /etc/NetworkManager/conf.d/20-connectivity.conf
[connectivity]
uri=http://detectportal.firefox.com/success.txt
interval=300
EOF'

echo -n "    Restarting NetworkManager service..."
run_with_spinner "restart_networkmanager" sudo systemctl restart NetworkManager

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
