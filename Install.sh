#!/bin/bash

# ==============================================================================
# Script Information
# ==============================================================================

# This script is intended to work in the following environment:
# - Arch Linux (or Arch based distros)
# - KDE Plasma 6
# - An active internet connection
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
# - Zathura PDF Poppler (Zathura Plugin)

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
    grep -q "$1" $LOG_FILE
}

# Initialize log file
if [ ! -f $LOG_FILE ]; then
    touch $LOG_FILE
fi

# Prompt for sudo password upfront to prevent interruptions
echo "Please enter your sudo password:"
sudo -v

# Function to keep sudo session alive
keep_sudo_alive() {
    while true; do sudo -v; sleep 60; done &
}

# Function to show a loading spinner
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to run a command with spinner
run_with_spinner() {
    local step="$1"
    shift
    if is_step_completed "$step"; then
        printf "\e[33mSKIPPED\e[0m\n"
        return 0
    fi
    local command="$*"
    "$@" > /dev/null 2>&1 &
    spinner
    wait $!
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        printf "\e[31mFAILED\e[0m\n"
    else
        printf "\e[32mSUCCESS\e[0m\n"
        log_step "$step"
    fi
    return $exit_code
}

# Keep sudo session alive
keep_sudo_alive

# ==============================================================================
# System Update
# ==============================================================================

echo -n "Updating system..."
run_with_spinner "update_system" sudo pacman -Syu --noconfirm

# ==============================================================================
# Install Yay (AUR Helper)
# ==============================================================================

echo "Installing Yay..."
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

# Install Firefox
echo -n "Installing Firefox..."
run_with_spinner "install_firefox" yay -S firefox --noconfirm

# Install Firewalld
echo "Installing Firewalld..."
echo -n "    Installing firewalld..."
run_with_spinner "install_firewalld" yay -S firewalld --noconfirm
echo -n "    Enabling firewalld..."
run_with_spinner "enable_firewalld" sudo systemctl enable firewalld.service
echo -n "    Starting firewalld..."
run_with_spinner "start_firewalld" sudo systemctl start firewalld.service

# Install Visual Studio Code
echo "Installing Visual Studio Code..."
echo -n "    Installing required packages..."
run_with_spinner "clone_vscode_repo" git clone https://aur.archlinux.org/visual-studio-code-bin.git
cd visual-studio-code-bin
echo -n "    Building and installing Visual Studio Code..."
run_with_spinner "makepkg_vscode" makepkg -si --noconfirm
cd ~

# Install Gwenview
echo -n "Installing Gwenview..."
run_with_spinner "install_gwenview" yay -S gwenview --noconfirm

# Install Kio-admin
echo -n "Installing Kio-admin..."
run_with_spinner "install_kio_admin" yay -S kio-admin --noconfirm

# ==============================================================================
# Install Themes and Fonts
# ==============================================================================

# Install Papirus Icon Theme
echo "Installing Papirus Icon Theme..."
echo -n "    Installing Papirus Icon Theme..."
run_with_spinner "install_papirus_icon_theme" yay -S papirus-icon-theme --noconfirm
echo -n "    Installing Papirus Folders..."
run_with_spinner "install_papirus_folders" yay -S papirus-folders-git --noconfirm
echo -n "    Configuring Papirus Folders..."
run_with_spinner "configure_papirus_folders" papirus-folders -C bluegrey --theme Papirus-Dark

# Install Fira Code Font
echo -n "Installing Fira Code Font..."
run_with_spinner "install_fira_code_font" yay -S ttf-fira-code --noconfirm

# Install Noto Fonts CJK
echo -n "Installing Noto Fonts CJK..."
run_with_spinner "install_noto_fonts_cjk" yay -S noto-fonts-cjk --noconfirm

# ==============================================================================
# Configure Fcitx5 (Input Method Framework)
# ==============================================================================

echo "Installing Fcitx5..."
echo -n "    Installing Fcitx5..."
run_with_spinner "install_fcitx5_im" yay -S fcitx5-im --noconfirm
echo -n "    Installing Fcitx5 Mozc..."
run_with_spinner "install_fcitx5_mozc" yay -S fcitx5-mozc --noconfirm

echo -n "Configuring Fcitx5..."
if is_step_completed "configure_fcitx5"; then
    printf "\e[33mSKIPPED\e[0m\n"
else
    sudo tee -a /etc/environment <<< "GTK_IM_MODULE=fcitx" && sudo tee -a /etc/environment <<< "QT_IM_MODULE=fcitx" && sudo tee -a /etc/environment <<< "XMODIFIERS=@im=fcitx" && printf "\e[32mSUCCESS\e[0m\n" && log_step "configure_fcitx5" || printf "\e[31mFAILED\e[0m\n"
fi

# ==============================================================================
# Install Konsave (Theme Manager)
# ==============================================================================

echo "Installing Konsave..."
echo -n "    Installing Konsave..."
run_with_spinner "install_konsave" yay -S konsave --noconfirm
cd ~/Linux-Dot-Files/Themes
echo -n "    Importing Konsave theme..."
run_with_spinner "import_konsave_theme" konsave -i Rouge-03-08-24.knsv
echo -n "    Applying Konsave theme..."
run_with_spinner "apply_konsave_theme" konsave -a Rouge-03-08-24
cd ~

# ==============================================================================
# Install Zathura (PDF Reader)
# ==============================================================================

echo "Installing Zathura..."
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

echo -n "Moving wallpaper to Pictures directory..."
cd ~/Linux-Dot-Files/Pictures
run_with_spinner "move_wallpaper" mv Rouge.jpg ~/Pictures
cd ~

echo -n "Applying wallpaper..."
run_with_spinner "apply_wallpaper" qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'var allDesktops = desktops();print (allDesktops);for (i=0;i<allDesktops.length;i++) {d = allDesktops[i];d.wallpaperPlugin = "org.kde.image";d.currentConfigGroup = Array("Wallpaper","org.kde.image","General");d.writeConfig("Image", "file:///home/daniel/Pictures/Rouge.jpg")}'

# ==============================================================================
# Configure Splash Screen
# ==============================================================================

echo -n "Moving splash screen..."
cd ~/Linux-Dot-Files/Themes/Splash/
sudo rm -rf ~/.local/share/plasma/look-and-feel/Rouge-Splash
run_with_spinner "move_splash_screen" sudo mv Rouge-Splash/ ~/.local/share/plasma/look-and-feel/
cd ~

echo -n "Applying splash screen..."
cd ~/Linux-Dot-Files/Home/user/.config
run_with_spinner "apply_splash_screen" mv ksplashrc ~/.config
cd ~

# ==============================================================================
# Configure Login Screen
# ==============================================================================

echo "Installing required packages for the login screen..."
echo -n "    Installing qt5-graphicaleffects..."
run_with_spinner "install_qt5_graphicaleffects" yay -S qt5-graphicaleffects --noconfirm
echo -n "    Installing qt5-quickcontrols..."
run_with_spinner "install_qt5_quickcontrols" yay -S qt5-quickcontrols --noconfirm
echo -n "    Installing qt5-quickcontrols2..."
run_with_spinner "install_qt5_quickcontrols2" yay -S qt5-quickcontrols2 --noconfirm

echo -n "Moving login screen..."
cd ~/Linux-Dot-Files/Themes/Login/
sudo rm -rf /usr/share/sddm/themes/Rouge
run_with_spinner "move_login_screen" sudo mv Rouge/ /usr/share/sddm/themes/
cd ~

echo -n "Applying login screen..."
cd ~/Linux-Dot-Files/Home/user/.config
if [ ! -d "/etc/sddm.conf.d/" ]; then
    sudo mkdir /etc/sddm.conf.d/
fi
run_with_spinner "move_sddm_config" sudo mv kde_settings.conf /etc/sddm.conf.d/
cd ~

# ==============================================================================
# Configure .bashrc
# ==============================================================================

echo -n "Configuring .bashrc..."
if is_step_completed "configure_bashrc"; then
    printf "\e[33mSKIPPED\e[0m\n"
else
    cat ~/Linux-Dot-Files/Home/user/.bashrc_append >> ~/.bashrc && printf "\e[32mSUCCESS\e[0m\n" && log_step "configure_bashrc" || printf "\e[31mFAILED\e[0m\n"
fi

# ==============================================================================
# Configure Bootloader
# ==============================================================================

echo -n "Configuring bootloader..."
cd /boot/loader/entries
if is_step_completed "configure_bootloader"; then
    printf "\e[33mSKIPPED\e[0m\n"
else
    for file in *_linux.conf; do sudo sed -i '/options/ s/$/ quiet/' "$file" && printf "\e[32mSUCCESS\e[0m\n" && log_step "configure_bootloader" || printf "\e[31mFAILED\e[0m\n"; done
fi
cd ~

# ==============================================================================
# Install Utility Applications (Optional)
# ==============================================================================

echo "Do you want to install utility applications? (Zoom, WhatsApp, etc.) [Y/n]"
read response

if [ "$response" = "Y" ] || [ "$response" = "y" ]; then
    printf "\nInstalling utility applications...\n"

    # Install Zoom
    echo -n "Installing Zoom..."
    run_with_spinner "install_zoom" yay -S zoom --noconfirm

    # Install WhatsApp
    echo -n "Installing WhatsApp..."
    run_with_spinner "install_whatsapp" yay -S whatsdesk-bin --noconfirm

    # Install Anki
    echo -n "Installing Anki..."
    run_with_spinner "install_anki" yay -S anki-bin --noconfirm

    # Apply Anki Addons
    echo -n "Applying Anki addons..."
    cd ~/Linux-Dot-Files/Home/user/.local/share/Anki2/addons21/
    run_with_spinner "apply_anki_addons" mv * ~/.local/share/Anki2/addons21/
    cd ~
else
    echo "Skipping utility applications installation."
fi

# ==============================================================================
# Cleanup
# ==============================================================================

echo -n "Cleaning up..."
run_with_spinner "cleanup" rm -rf ~/Linux-Dot-Files

# ==============================================================================
# Final Steps
# ==============================================================================

printf "\nInstallation complete!\n"
printf "\nRebooting system in 10 seconds...\n"
sleep 10
reboot

# End of script