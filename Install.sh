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
# - Papirus Icon Theme
# - Fira Code Font
# - Noto Fonts CJK (Chinese, Japanese, Korean)
# - Fcitx5 (Input Method Framework)
# - Konsave (Theme Manager)
# - Zathura (PDF Reader)
# - Zathura PDF Poppler (Zathura Plugin)

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
    "$@" > /dev/null 2>&1 &
    spinner
    wait $!
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Error occurred during: $*"
        "$@"
    fi
    return $exit_code
}

# Updates the system
echo "Updating system..."
run_with_spinner sudo pacman -Syu --noconfirm

# Moves to the home directory
cd ~

# Installs Yay (AUR Helper)
echo "Installing Yay..."
run_with_spinner sudo pacman -S --needed git base-devel --noconfirm
run_with_spinner git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
run_with_spinner makepkg -si --noconfirm
cd ~

# Installs Firefox
echo "Installing Firefox..."
run_with_spinner yay -S firefox --noconfirm

# Installs Firewalld
echo "Installing Firewalld..."
run_with_spinner yay -S firewalld --noconfirm
run_with_spinner sudo systemctl enable firewalld.service
run_with_spinner sudo systemctl start firewalld.service

# Installs Visual Studio Code (Proprietary)
echo "Installing Visual Studio Code..."
run_with_spinner git clone https://aur.archlinux.org/visual-studio-code-bin.git
cd visual-studio-code-bin
run_with_spinner makepkg -si --noconfirm
cd ~

# Installs Papirus Icon Theme
echo "Installing Papirus Icon Theme..."
run_with_spinner yay -S papirus-icon-theme --noconfirm
run_with_spinner yay -S papirus-folders-git --noconfirm
run_with_spinner papirus-folders -C bluegrey --theme Papirus-Dark

# Installs Fira Code Font
echo "Installing Fira Code Font..."
run_with_spinner yay -S ttf-fira-code --noconfirm

# Installs Noto Fonts CJK (Chinese, Japanese, Korean)
echo "Installing Noto Fonts CJK..."
run_with_spinner yay -S noto-fonts-cjk --noconfirm

# Installs Fcitx5 (Input Method Framework)
echo "Installing Fcitx5..."
run_with_spinner yay -S fcitx5-im --noconfirm
run_with_spinner yay -S fcitx5-mozc --noconfirm

# Set environment variable for fcitx5 inside the etc/environment file
echo "Configuring Fcitx5..."
run_with_spinner sudo tee -a /etc/environment <<< "GTK_IM_MODULE=fcitx"
run_with_spinner sudo tee -a /etc/environment <<< "QT_IM_MODULE=fcitx"
run_with_spinner sudo tee -a /etc/environment <<< "XMODIFIERS=@im=fcitx"

# Installs Konsave (Theme Manager)
echo "Installing Konsave..."
run_with_spinner yay -S konsave --noconfirm
cd ~/Linux-Dot-Files/Themes
run_with_spinner konsave -i Rouge-03-08-24.knsv
run_with_spinner konsave -a Rouge-03-08-24
cd ~

# Installs Zathura (PDF Reader)
echo "Installing Zathura..."
run_with_spinner yay -S zathura --noconfirm
run_with_spinner yay -S zathura-pdf-poppler --noconfirm
cd ~/Linux-Dot-Files/Home/user/.config
run_with_spinner mv zathura ~/.config
cd ~

# Moves wallpaper to the Pictures directory
echo "Moving wallpaper to Pictures directory..."
cd ~/Linux-Dot-Files/Pictures
run_with_spinner mv Rouge.jpg ~/Pictures
cd ~

# Applies the wallpaper to all screens
echo "Applying wallpaper..."
run_with_spinner qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'var allDesktops = desktops();print (allDesktops);for (i=0;i<allDesktops.length;i++) {d = allDesktops[i];d.wallpaperPlugin = "org.kde.image";d.currentConfigGroup = Array("Wallpaper","org.kde.image","General");d.writeConfig("Image", "file:///home/daniel/Pictures/Rouge.jpg")}'

# Moves the splash screen to the KDE splash screen directory
echo "Moving splash screen..."
cd ~/Linux-Dot-Files/Themes
run_with_spinner sudo mv Rouge-Splash/ ~/.local/share/plasma/look-and-feel/
cd ~

# Applies the splash screen by changing the ksplashrc file
echo "Applying splash screen..."
cd ~/Linux-Dot-Files/Home/user/.config
run_with_spinner mv ksplashrc ~/.config
cd ~

# Appends the content of the .bashrc_append file to the user's .bashrc file
echo "Configuring .bashrc..."
run_with_spinner cat ~/Linux-Dot-Files/Home/user/.bashrc_append >> ~/.bashrc

# adds "quiet" to the grub configuration file in /boot/loader/entries/yyyy-mm-dd_linux.conf
echo "Configuring bootloader..."
cd /boot/loader/entries
run_with_spinner sudo sed -i '/options/ s/$/ quiet/' /boot/loader/entries/$(ls /boot/loader/entries | grep -oP '.*(?=_linux)')_linux.conf
cd ~

# Removes the Linux-Dot-Files directory
echo "Cleaning up..."
run_with_spinner rm -rf ~/Linux-Dot-Files

# Prints a message to the user
echo "Installation complete!"

# ask the user if they want to add utility applications (zoom, whatsapp, etc.)
echo "Do you want to install utility applications? (Zoom, WhatsApp, etc.) [Y/n]"
read response

# If the user types 'Y' or 'y', the script will install the utility applications
if [ "$response" = "Y" ] || [ "$response" = "y" ]; then
    # Installs utility applications
    echo "Installing utility applications..."

    # Installs Zoom
    echo "Installing Zoom..."
    run_with_spinner yay -S zoom --noconfirm

    # Installs WhatsApp
    echo "Installing WhatsApp..."
    run_with_spinner yay -S whatsdesk-bin --noconfirm
else
    echo "Skipping utility applications installation."
fi

# Reboots the system in 10 seconds
echo "Rebooting in 10 seconds..."
sleep 10
reboot

# End of script
