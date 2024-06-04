 
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

# Updates the system

sudo pacman -Syu --noconfirm

# Moves to the home directory

cd ~

# Installs Yay (AUR Helper)

sudo pacman -S --needed git base-devel --noconfirm
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
cd ~

# Installs Firefox

yay -S firefox --noconfirm

# Installs Firewalld

yay -S firewalld --noconfirm
sudo systemctl enable firewalld.service
sudo systemctl start firewalld.service

# Installs Visual Studio Code (Proprietary)

git clone https://aur.archlinux.org/visual-studio-code-bin.git
cd visual-studio-code-bin
makepkg -si --noconfirm
cd ~

# Installs Papirus Icon Theme

yay -S papirus-icon-theme --noconfirm
yay -S papirus-folders-git --noconfirm
papirus-folders -C bluegrey --theme Papirus-Dark

# Installs Fira Code Font

yay -S ttf-fira-code --noconfirm


# Installs Noto Fonts CJK (Chinese, Japanese, Korean)

yay -S noto-fonts-cjk --noconfirm

# Installs Fcitx5 (Input Method Framework)

yay -S fcitx5-im --noconfirm
yay -S fcitx5-mozc --noconfirm

# Set environment variable for fcitx5 inside the etc/environment file

echo "GTK_IM_MODULE=fcitx" | sudo tee -a /etc/environment
echo "QT_IM_MODULE=fcitx" | sudo tee -a /etc/environment
echo "XMODIFIERS=@im=fcitx" | sudo tee -a /etc/environment

# Installs Konsave (Theme Manager)

yay -S konsave --noconfirm
cd ~/Linux-Dot-Files/Themes
konsave -i Rouge-03-08-24.knsv
konsave -a Rouge-03-08-24
cd ~

# Installs Zathura (PDF Reader)

yay -S zathura --noconfirm
yay -S zathura-pdf-poppler --noconfirm
cd ~/Linux-Dot-Files/Home/user/.config
mv zathura ~/.config
cd ~

# Moves wallpaper to the Pictures directory
cd ~/Linux-Dot-Files/Pictures
mv Rouge.jpg ~/Pictures
cd ~

# Applies the wallpaper to all screens

qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'var allDesktops = desktops();print (allDesktops);for (i=0;i<allDesktops.length;i++) {d = allDesktops[i];d.wallpaperPlugin = "org.kde.image";d.currentConfigGroup = Array("Wallpaper","org.kde.image","General");d.writeConfig("Image", "file:///home/daniel/Pictures/Rouge.jpg")}'

# Moves the splash screen to the KDE splash screen directory

cd ~/Linux-Dot-Files/Themes
sudo mv Rouge-Splash/ ~/.local/share/plasma/look-and-feel/
cd ~

# Applies the splash screen by changing the ksplashrc file

cd ~/Linux-Dot-Files/Home/user/.config
mv ksplashrc ~/.config
cd ~

# Appends the content of the .bashrc_append file to the user's .bashrc file

cat ~/Linux-Dot-Files/Home/user/.bashrc_append >> ~/.bashrc

# adds "quiet" to the grub configuration file in /boot/loader/entries/yyyy-mm-dd_linux.conf
# it must be added to the last non-empty line of the file that begins with "options"

cd /boot/loader/entries
sudo sed -i '/options/ s/$/ quiet/' /boot/loader/entries/$(ls /boot/loader/entries | grep -oP '.*(?=_linux)')_linux.conf
cd ~

# Removes the Linux-Dot-Files directory

rm -rf ~/Linux-Dot-Files

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

        yay -S zoom --noconfirm

        # Installs WhatsApp

        yay -S whatsdesk-bin --noconfirm

else
    echo "Skipping utility applications installation."
fi

# Reboots the system in 10 seconds

echo "Rebooting in 10 seconds..."
sleep 10
reboot

# End of script





