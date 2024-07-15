#!/bin/bash

# This script is intended to work in the following environment:
# - Arch Linux (or Arch based distros)
# - Kde Plasma 6 
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

# Updates the system
echo -n "Updating system..."
run_with_spinner "update_system" sudo pacman -Syu --noconfirm

# Moves to the home directory
cd ~

# Installs Yay (AUR Helper)
echo "Installing Yay..."
echo -n "    Installing required packages..."
run_with_spinner "install_yay" sudo pacman -S --needed git base-devel --noconfirm
echo -n "    Cloning yay repository..."
run_with_spinner "clone_yay_repo" git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
echo -n "    Building and installing yay..."
run_with_spinner "makepkg_yay" makepkg -si --noconfirm
cd ~

# Installs Firefox
echo -n "Installing Firefox..."
run_with_spinner "install_firefox" yay -S firefox --noconfirm

# Installs Firewalld
echo "Installing Firewalld..."
echo -n "    Installing firewalld..."
run_with_spinner "install_firewalld" yay -S firewalld --noconfirm
echo -n "    Enabling firewalld..."
run_with_spinner "enable_firewalld" sudo systemctl enable firewalld.service
echo -n "    Starting firewalld..."
run_with_spinner "start_firewalld" sudo systemctl start firewalld.service

# Installs Visual Studio Code (Proprietary)
echo "Installing Visual Studio Code..."
echo -n "    Installing required packages..."
run_with_spinner "clone_vscode_repo" git clone https://aur.archlinux.org/visual-studio-code-bin.git
cd visual-studio-code-bin
echo -n "    Building and installing Visual Studio Code..."
run_with_spinner "makepkg_vscode" makepkg -si --noconfirm
cd ~

# Installs Gwenview (Image Viewer)
echo -n "Installing Gwenview..."
run_with_spinner "install_gwenview" yay -S gwenview --noconfirm

# Installs Kio-admin (Root File Manager)
echo -n "Installing Kio-admin..."
run_with_spinner "install_kio_admin" yay -S kio-admin --noconfirm

# Installs Papirus Icon Theme
echo "Installing Papirus Icon Theme..."
echo -n "    Installing Papirus Icon Theme..."
run_with_spinner "install_papirus_icon_theme" yay -S papirus-icon-theme --noconfirm
echo -n "    Installing Papirus Folders..."
run_with_spinner "install_papirus_folders" yay -S papirus-folders-git --noconfirm
echo -n "    Configuring Papirus Folders..."
run_with_spinner "configure_papirus_folders" papirus-folders -C bluegrey --theme Papirus-Dark

# Installs Fira Code Font
echo -n "Installing Fira Code Font..."
run_with_spinner "install_fira_code_font" yay -S ttf-fira-code --noconfirm

# Installs Noto Fonts CJK (Chinese, Japanese, Korean)
echo -n "Installing Noto Fonts CJK..."
run_with_spinner "install_noto_fonts_cjk" yay -S noto-fonts-cjk --noconfirm

# Installs Fcitx5 (Input Method Framework)
echo "Installing Fcitx5..."
echo -n "    Installing Fcitx5..."
run_with_spinner "install_fcitx5_im" yay -S fcitx5-im --noconfirm
echo -n "    Installing Fcitx5 Mozc..."
run_with_spinner "install_fcitx5_mozc" yay -S fcitx5-mozc --noconfirm

# Set environment variable for fcitx5 inside the etc/environment file
echo -n "Configuring Fcitx5..."
# sudo tee -a /etc/environment <<< "GTK_IM_MODULE=fcitx"
# sudo tee -a /etc/environment <<< "QT_IM_MODULE=fcitx"
# sudo tee -a /etc/environment <<< "XMODIFIERS=@im=fcitx"
if is_step_completed "configure_fcitx5"; then
    printf "\e[33mSKIPPED\e[0m\n"
else
    sudo tee -a /etc/environment <<< "GTK_IM_MODULE=fcitx" && sudo tee -a /etc/environment <<< "QT_IM_MODULE=fcitx" && sudo tee -a /etc/environment <<< "XMODIFIERS=@im=fcitx" && printf "\e[32mSUCCESS\e[0m\n" && log_step "configure_fcitx5" || printf "\e[31mFAILED\e[0m\n"
fi

# Installs Konsave (Theme Manager)
echo "Installing Konsave..."
echo -n "    Installing Konsave..."
run_with_spinner "install_konsave" yay -S konsave --noconfirm
cd ~/Linux-Dot-Files/Themes
echo -n "    Importing Konsave theme..."
run_with_spinner "import_konsave_theme" konsave -i Rouge-03-08-24.knsv
echo -n "    Applying Konsave theme..."
run_with_spinner "apply_konsave_theme" konsave -a Rouge-03-08-24
cd ~

# Installs Zathura (PDF Reader)
echo "Installing Zathura..."
echo -n "    Installing Zathura..."
run_with_spinner "install_zathura" yay -S zathura --noconfirm
echo -n "    Installing Zathura Plugins..."
run_with_spinner "install_zathura_pdf_poppler" yay -S zathura-pdf-poppler --noconfirm
cd ~/Linux-Dot-Files/Home/user/.config
echo -n "    Configuring Zathura..."
run_with_spinner "move_zathura_config" mv zathura ~/.config
cd ~

# Moves wallpaper to the Pictures directory
echo -n "Moving wallpaper to Pictures directory..."
cd ~/Linux-Dot-Files/Pictures
run_with_spinner "move_wallpaper" mv Rouge.jpg ~/Pictures
cd ~

# Install qdbus6
echo -n "Installing qdbus..."
run_with_spinner "install_qdbus6" yay -S qt6-tools-desktop --noconfirm

# Applies the wallpaper to all screens
echo -n "Applying wallpaper..."
run_with_spinner "apply_wallpaper" qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'var allDesktops = desktops();print (allDesktops);for (i=0;i<allDesktops.length;i++) {d = allDesktops[i];d.wallpaperPlugin = "org.kde.image";d.currentConfigGroup = Array("Wallpaper","org.kde.image","General");d.writeConfig("Image", "file:///home/daniel/Pictures/Rouge.jpg")}'

# Moves the splash screen to the KDE splash screen directory
echo -n "Moving splash screen..."
cd ~/Linux-Dot-Files/Themes/Splash/
# if the directory in ~/.local/share/plasma/look-and-feel/ is not empty, remove it
sudo rm -rf ~/.local/share/plasma/look-and-feel/Rouge-Splash
run_with_spinner "move_splash_screen" sudo mv Rouge-Splash/ ~/.local/share/plasma/look-and-feel/
cd ~

# Applies the splash screen by changing the ksplashrc file
echo -n "Applying splash screen..."
cd ~/Linux-Dot-Files/Home/user/.config
run_with_spinner "apply_splash_screen" mv ksplashrc ~/.config
cd ~

# Install required packages for the login screen
echo "Installing required packages for the login screen..."
echo -n "    Installing qt5-graphicaleffects..."
run_with_spinner "install_qt5_graphicaleffects" yay -S qt5-graphicaleffects --noconfirm
echo -n "    Installing qt5-quickcontrols..."
run_with_spinner "install_qt5_quickcontrols" yay -S qt5-quickcontrols --noconfirm
echo -n "    Installing qt5-quickcontrols2..."
run_with_spinner "install_qt5_quickcontrols2" yay -S qt5-quickcontrols2 --noconfirm

# Move the login screen to the SDDM theme directory
echo -n "Moving login screen..."
cd ~/Linux-Dot-Files/Themes/Login/
# if the directory in /usr/share/sddm/themes/ is not empty, remove it
sudo rm -rf /usr/share/sddm/themes/Rouge
run_with_spinner "move_login_screen" sudo mv Rouge/ /usr/share/sddm/themes/
cd ~

# Applies the login screen by changing the sddm.conf file (if the folder /etc/sddm.conf.d/ does not exist, create it)
echo -n "Applying login screen..."
cd ~/Linux-Dot-Files/Home/user/.config
if [ ! -d "/etc/sddm.conf.d/" ]; then
    sudo mkdir /etc/sddm.conf.d/
fi
run_with_spinner "move_sddm_config" sudo mv kde_settings.conf /etc/sddm.conf.d/
cd ~

# Appends the content of the .bashrc_append file to the user's .bashrc file
echo -n "Configuring .bashrc..."
if is_step_completed "configure_bashrc"; then
    printf "\e[33mSKIPPED\e[0m\n"
else
    cat ~/Linux-Dot-Files/Home/user/.bashrc_append >> ~/.bashrc && printf "\e[32mSUCCESS\e[0m\n" && log_step "configure_bashrc" || printf "\e[31mFAILED\e[0m\n"
fi

# adds "quiet" to the grub configuration file in /boot/loader/entries/yyyy-mm-dd_linux.conf
echo -n "Configuring bootloader..."
cd /boot/loader/entries
# sudo sed -i '/options/ s/$/ quiet/' /boot/loader/entries/$(ls /boot/loader/entries | grep -oP '.*(?=_linux)')_linux.conf
if is_step_completed "configure_bootloader"; then
    printf "\e[33mSKIPPED\e[0m\n"
else
    for file in *_linux.conf; do sudo sed -i '/options/ s/$/ quiet/' "$file" && printf "\e[32mSUCCESS\e[0m\n" && log_step "configure_bootloader" || printf "\e[31mFAILED\e[0m\n"; done
fi
cd ~

# ask the user if they want to add utility applications (zoom, whatsapp, etc.)
echo "Do you want to install utility applications? (Zoom, WhatsApp, etc.) [Y/n]"
read response

# If the user types 'Y' or 'y', the script will install the utility applications
if [ "$response" = "Y" ] || [ "$response" = "y" ]; then
    # Installs utility applications
    printf "\nInstalling utility applications...\n"

    # Installs Zoom
    echo -n "Installing Zoom..."
    run_with_spinner "install_zoom" yay -S zoom --noconfirm

    # Installs WhatsApp
    echo -n "Installing WhatsApp..."
    run_with_spinner "install_whatsapp" yay -S whatsdesk-bin --noconfirm

    # Installs anki
    echo -n "Installing Anki..."
    run_with_spinner "install_anki" yay -S anki-bin --noconfirm

    # apply anki addons from the Home/user/.local/share/Anki2/addons21/ directory, moving all folders inside the addons21 directory
    echo -n "Applying Anki addons..."
    cd ~/Linux-Dot-Files/Home/user/.local/share/Anki2/addons21/
    run_with_spinner "apply_anki_addons" mv * ~/.local/share/Anki2/addons21/
    cd ~
else
    echo "Skipping utility applications installation."
fi

# Removes the Linux-Dot-Files directory
echo -n "Cleaning up..."
run_with_spinner "cleanup" rm -rf ~/Linux-Dot-Files

# Prints a message to the user
printf "\nInstallation complete!\n"

# Reboots the system in 10 seconds
printf "\nRebooting system in 10 seconds...\n"
sleep 10
reboot

# End of script
