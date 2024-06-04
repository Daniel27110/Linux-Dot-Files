 
#!/bin/bash

# This script is intended to work in the following environment:

# - Arch Linux (or Arch based distros)
# - Kde Plasma 5 or higher
# - An active internet connection

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

# Applies the wallpaper to all screens using dbus

dbus-send --session --dest=org.kde.plasmashell --type=method_call /PlasmaShell org.kde.PlasmaShell.evaluateScript 'string:
var Desktops = desktops();
for (i=0;i<Desktops.length;i++) {
        d = Desktops[i];
        d.wallpaperPlugin = "org.kde.image";
        d.currentConfigGroup = Array("Wallpaper",
                                    "org.kde.image",
                                    "General");
        d.writeConfig("Image", "file:/home/'$(whoami)'/Pictures/Rouge.jpg")
}'

# Moves the splash screen to the KDE splash screen directory

cd ~/Linux-Dot-Files/Themes
sudo mv RougeSplash/ ~/.local/share/plasma/look-and-feel/
cd ~

# Applies the splash screen by changing the ksplashrc file

cd ~/Linux-Dot-Files/Home/user/.config
mv ksplashrc ~/.config
cd ~

# Appends the content of the .bashrc_append file to the user's .bashrc file

cat ~/Linux-Dot-Files/Home/user/.bashrc_append >> ~/.bashrc

# Removes the Linux-Dot-Files directory

rm -rf ~/Linux-Dot-Files

# Prints a message to the user

echo "Installation complete!"

# Reboots the system in 10 seconds

echo "Rebooting in 10 seconds..."
sleep 10
reboot

# End of script





