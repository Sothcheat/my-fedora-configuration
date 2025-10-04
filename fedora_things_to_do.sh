#!/bin/bash
# "Things To Do!" script for a fresh Fedora Workstation installation

# Check if the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo"
  exit 1
fi

# Funtion to echo colored text
color_echo() {
  local color="$1"
  local text="$2"
  case "$color" in
  "red") echo -e "\033[0;31m$text\033[0m" ;;
  "green") echo -e "\033[0;32m$text\033[0m" ;;
  "yellow") echo -e "\033[1;33m$text\033[0m" ;;
  "blue") echo -e "\033[0;34m$text\033[0m" ;;
  *) echo "$text" ;;
  esac
}

# Set variables
ACTUAL_USER=$SUDO_USER
ACTUAL_HOME=$(eval echo ~$SUDO_USER)
LOG_FILE="/var/log/fedora_things_to_do.log"
INITIAL_DIR=$(pwd)

# Function to generate timestamps
get_timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

# Function to log messages
log_message() {
  local message="$1"
  echo "$(get_timestamp) - $message" | tee -a "$LOG_FILE"
}

# Function to handle errors
handle_error() {
  local exit_code=$?
  local message="$1"
  if [ $exit_code -ne 0 ]; then
    color_echo "red" "ERROR: $message"
    exit $exit_code
  fi
}

# Function to prompt for reboot
prompt_reboot() {
  sudo -u $ACTUAL_USER bash -c 'read -p "It is time to reboot the machine. Would you like to do it now? (y/n): " choice; [[ $choice == [yY] ]]'
  if [ $? -eq 0 ]; then
    color_echo "green" "Rebooting..."
    reboot
  else
    color_echo "red" "Reboot canceled."
  fi
}

# Function to backup configuration files
backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    cp "$file" "$file.bak"
    handle_error "Failed to backup $file"
    color_echo "green" "Backed up $file"
  fi
}

echo ""
echo "╔═════════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                             ║"
echo "║   ░█▀▀░█▀▀░█▀▄░█▀█░█▀▄░█▀█░░░█░█░█▀█░█▀▄░█░█░█▀▀░▀█▀░█▀█░▀█▀░▀█▀░█▀█░█▀█░   ║"
echo "║   ░█▀▀░█▀▀░█░█░█░█░█▀▄░█▀█░░░█▄█░█░█░█▀▄░█▀▄░▀▀█░░█░░█▀█░░█░░░█░░█░█░█░█░   ║"
echo "║   ░▀░░░▀▀▀░▀▀░░▀▀▀░▀░▀░▀░▀░░░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░░▀░░▀░▀░░▀░░▀▀▀░▀▀▀░▀░▀░   ║"
echo "║   ░░░░░░░░░░░░▀█▀░█░█░▀█▀░█▀█░█▀▀░█▀▀░░░▀█▀░█▀█░░░█▀▄░█▀█░█░░░░░░░░░░░░░░   ║"
echo "║   ░░░░░░░░░░░░░█░░█▀█░░█░░█░█░█░█░▀▀█░░░░█░░█░█░░░█░█░█░█░▀░░░░░░░░░░░░░░   ║"
echo "║   ░░░░░░░░░░░░░▀░░▀░▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░░░░▀░░▀▀▀░░░▀▀░░▀▀▀░▀░░░░░░░░░░░░░░   ║"
echo "║                                                                             ║"
echo "╚═════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "This script automates \"Things To Do!\" steps after a fresh Fedora Workstation installation"
echo "ver. 25.08 / 100 Stars Edition"
echo ""
echo "Don't run this script if you didn't build it yourself or don't know what it does."
echo ""
read -p "Press Enter to continue or CTRL+C to cancel..."

# System Upgrade
colorecho blue "Performing system upgrade (excluding kernel updates)... This may take a while..."
dnf upgrade --exclude=kernel\* --exclude=kernel-core\* --exclude=kernel-modules\* --exclude=kernel-devel\* -y
handleerror $? "System upgrade failed"

# System Configuration
# Set the system hostname to uniquely identify the machine on the network
color_echo "yellow" "Setting hostname..."
hostnamectl set-hostname fedora

# Optimize DNF package manager for faster downloads and efficient updates
color_echo "yellow" "Configuring DNF Package Manager..."
backup_file "/etc/dnf/dnf.conf"
echo "max_parallel_downloads=10" | tee -a /etc/dnf/dnf.conf >/dev/null
echo "fastestmirror=True" | tee -a /etc/dnf/dnf.conf >/dev/null
dnf -y install dnf-plugins-core

# Replace Fedora Flatpak Repo with Flathub for better package management and apps stability
color_echo "yellow" "Replacing Fedora Flatpak Repo with Flathub..."
dnf install -y flatpak
flatpak remote-delete fedora --force || true
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak repair
flatpak update

# Install and enable SSH server for secure remote access and file transfers
color_echo "yellow" "Installing and enabling SSH..."
dnf install -y openssh-server
systemctl enable --now sshd

# Check and apply firmware updates to improve hardware compatibility and performance
color_echo "yellow" "Checking for firmware updates..."
fwupdmgr get-devices
fwupdmgr refresh --force
fwupdmgr get-updates
fwupdmgr update -y

# Enable RPM Fusion repositories to access additional software packages and codecs
color_echo "yellow" "Enabling RPM Fusion repositories..."
dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf update @core -y

# Install multimedia codecs to enhance multimedia capabilities
color_echo "yellow" "Installing multimedia codecs..."
dnf swap ffmpeg-free ffmpeg --allowerasing -y
dnf install -y gstreamer1-plugins-{bad-\*,good-\*,base} gstreamer1-plugin-openh264 gstreamer1-libav lame\* --exclude=gstreamer1-plugins-bad-free-devel
dnf4 group install multimedia
dnf install -y ffmpeg-libs libva libva-utils
dnf group install -y sound-and-video
dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y
dnf update @sound-and-video -y

# Install Hardware Accelerated Codecs for AMD GPUs. This improves video playback and encoding performance on systems with AMD graphics.
color_echo "yellow" "Installing AMD Hardware Accelerated Codecs..."
dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
dnf swap mesa-va-drivers mesa-va-drivers-freeworld -y
dnf swap mesa-vdpau-drivers mesa-vdpau-drivers-freeworld -y

# Install virtualization tools to enable virtual machines and containerization
color_echo "yellow" "Installing virtualization tools..."
dnf install -y @virtualization

# App Installation
# Install essential applications
color_echo "yellow" "Installing essential applications..."
dnf install -y p7zip p7zip-plugins fastfetch unzip unrar git wget curl gnome-tweaks
color_echo "green" "Essential applications installed successfully."

# Install Internet & Communication applications
color_echo "yellow" "Installing Zen Browser..."
flatpak install -y flathub app.zen_browser.zen
color_echo "green" "Zen Browser installed successfully."
# Remove Firefox
color_echo "yellow" "Removing Firefox browser..."
dnf remove -y firefox
handleerror $? "Failed to remove Firefox"
color_echo "green" "Firefox removed successfully."
color_echo "yellow" "Installing Discord..."
dnf install -y discord
color_echo "green" "Discord installed successfully."
color_echo "yellow" "Installing Telegram Desktop..."
dnf install -y telegram-desktop
color_echo "green" "Telegram Desktop installed successfully."
# Install Alacritty terminal emulator
color_echo "yellow" "Installing Alacritty terminal emulator..."
dnf install -y alacritty
handleerror $? "Failed to install Alacritty"
colorecho "green" "Alacritty installed successfully."
# Install Zsh
color_echo "yellow" "Installing Zsh and OhMyPosh..."
dnf install zsh
chsh -s $(which zsh)
curl -s https://ohmyposh.dev/install.sh | bash -s
wget -O ~/.local/bin/theme/emodipt-extend.omp.json \
  https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/emodipt-extend.omp.json
# Install fzf (fuzzy finder)
dnf install fzf
# Install zoxid
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
color_echo "green" "Zsh and OhMyPosh installed successfully."

# Install Office Productivity applications
color_echo "yellow" "Installing LibreOffice..."
dnf remove -y libreoffice*
flatpak install -y flathub org.libreoffice.LibreOffice
flatpak install -y --reinstall org.freedesktop.Platform.Locale/x86_64/24.08
flatpak install -y --reinstall org.libreoffice.LibreOffice.Locale
color_echo "green" "LibreOffice installed successfully."
color_echo "yellow" "Installing Obsidian..."
flatpak install -y flathub md.obsidian.Obsidian
color_echo "green" "Obsidian installed successfully."

# Install Coding and DevOps applications
color_echo "yellow" "Installing Visual Studio Code..."
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
dnf check-update
dnf install -y code
color_echo "green" "Visual Studio Code installed successfully."
color_echo "yellow" "Installing Docker..."
dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine --noautoremove
dnf -y install dnf-plugins-core
if command -v dnf4 &>/dev/null; then
  dnf4 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
else
  dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
fi
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
systemctl enable --now containerd
groupadd docker
usermod -aG docker $ACTUAL_USER
rm -rf $ACTUAL_HOME/.docker
echo "Docker installed successfully. Please log out and back in for the group changes to take effect."
color_echo "green" "Docker installed successfully."
color_echo "yellow" "Installing essential development tools and language..."
dnf group install -y development-tools c-development
dnf install -y gcc clang cmake python3-pip java-25-openjdk-devel nodejs npm
color_echo "green" "Essential development tools and language installed successfully."
# Note: Docker group changes will take effect after logging out and back in

# Install Media & Graphics applications
color_echo "yellow" "Installing VLC..."
dnf install -y vlc
color_echo "green" "VLC installed successfully."
color_echo "yellow" "Installing OBS Studio..."
dnf install -y obs-studio
color_echo "green" "OBS Studio installed successfully."

# Install Remote Networking applications
color_echo "yellow" "Installing AnyDesk..."
flatpak install -y flathub com.anydesk.Anydesk
color_echo "green" "AnyDesk installed successfully."

# Install System Tools applications
color_echo "yellow" "Installing Extension Manager..."
flatpak install -y flathub com.mattjakeman.ExtensionManager
color_echo "green" "Extension Manager installed successfully."

# Customization
# Install Microsoft Windows fonts (core)
color_echo "yellow" "Installing Microsoft Fonts (core)..."
dnf install -y curl cabextract xorg-x11-font-utils fontconfig
rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
color_echo "green" "Microsoft Fonts (core) installed successfully."

# Install Google fonts collection
color_echo "yellow" "Installing Google Fonts..."
wget -O /tmp/google-fonts.zip https://github.com/google/fonts/archive/main.zip
mkdir -p $ACTUAL_HOME/.local/share/fonts/google
unzip /tmp/google-fonts.zip -d $ACTUAL_HOME/.local/share/fonts/google
rm -f /tmp/google-fonts.zip
fc-cache -fv
color_echo "green" "Google Fonts installed successfully."

# Download and install Meslo Nerd Font
color_echo "yellow" "Installing Meslo Nerd Font..."
MESLO_DIR="$ACTUALHOME/.local/share/fonts/MesloNerdFont"
mkdir -p "$MESLO_DIR"
cd "$MESLO_DIR"
wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip -O Meslo.zip
unzip -o Meslo.zip
rm -f Meslo.zip
fc-cache -fv
color_echo "green" "Meslo Nerd Font installed successfully."

# Install Tela icon theme
color_echo "yellow" "Installing Tela Icon Theme..."
git clone https://github.com/vinceliuice/Tela-icon-theme.git /tmp/Tela-icon-theme
cd /tmp/Tela-icon-theme && ./install.sh -a
rm -rf /tmp/Tela-icon-theme
sudo -u $ACTUAL_USER gsettings set org.gnome.desktop.interface icon-theme "Tela-orange"
color_echo "green" "Tela Icon Theme installed successfully."

# UPDATED: Disable NetworkManager-wait-online.service
colorecho "yellow" "Disabling NetworkManager-wait-online.service..."
systemctl disable NetworkManager-wait-online.service
colorecho "green" "NetworkManager-wait-online.service disabled."

# Configure Better Battery-life
color_echo "yellow" "Installing TLP..."
dnf install https://repo.linrunner.de/fedora/tlp/repos/releases/tlp-release.fc$(rpm -E %fedora).noarch.rpm
#Remove conflicting power profile demone
dnf remove tuned tuned-ppd
# Install TLP
dnf install tlp tlp-rdw
# Enable TLP service
systemctl enable tlp.service
# Mask the following services to avoid conflicts with TLP’s Radio Device Switching options
systemctl mask systemd-rfkill.service systemd-rfkill.socket
color_echo "green" "TLP configured successfully."

# Configure Dual Boot time fix
color_echo "yellow" "Tell Fedora to use UTC for hardware clock..."
timedatectl set-local-rtc 0 --adjust-system-clock
color_echo "green" "Dual Boot fix configured successfully."

# Encrypted DNS
color_echo "yellow" "Configuring Encrypted DNS..."
#Add Cloudflared repository
dnf config-manager addrepo --from-repofile=https://pkg.cloudflare.com/cloudflared.repo
# Install cloudflared
dnf install -y cloudflared
# Create a systemd service for cloudflared
tee /etc/systemd/system/cloudflared.service >/dev/null <<'EOF'
[Unit]
Description=Cloudflared DNS-over-HTTPS proxy
After=network.target

[Service]
ExecStart=/usr/bin/cloudflared proxy-dns --upstream https://1.1.1.1/dns-query --upstream https://1.0.0.1/dns-query
Restart=on-failure
User=nobody
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable the service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now cloudflared

# Configure systemd-resolved to use 127.0.0.1 (cloudflared)
mkdir -p /etc/systemd/resolved.conf.d
tee /etc/systemd/resolved.conf.d/dns-over-https.conf >/dev/null <<'EOF'
[Resolve]
DNS=127.0.0.1
FallbackDNS=1.1.1.1
DNSSEC=yes
Cache=yes
EOF

# Tell NetworkManager to use systemd-resolved
tee /etc/NetworkManager/conf.d/dns.conf >/dev/null <<'EOF'
[main]
dns=systemd-resolved
EOF

# Restart services
systemctl restart cloudflared
systemctl restart systemd-resolved
systemctl restart NetworkManager

# Test DNS resolution
dig +short example.com

# Check current DNS status
resolvectl status
color_echo "green" "Encrypted DNS configured successfully."

rm /etc/xdg/autostart/org.gnome.Software.desktop

color_echo "yellow" "Cleainng up the system..."
# Clean package cache
dnf clean all

# Remove orphaned packages
dnf autoremove -y

# Remove old kernels (if you have too many)
# sudo dnf remove $(dnf repoquery --installonly --latest-limit=-3 -q)
color_echo "green" "The system cleaned successfully."

# Custom user-defined commands
# Custom user-defined commands
echo "Created with ❤️ for Open Source"

# Before finishing, ensure we're in a safe directory
cd /tmp || cd $ACTUAL_HOME || cd /

# Finish
echo ""
echo "╔═════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                         ║"
echo "║   ░█░█░█▀▀░█░░░█▀▀░█▀█░█▄█░█▀▀░░░▀█▀░█▀█░░░█▀▀░█▀▀░█▀▄░█▀█░█▀▄░█▀█░█░   ║"
echo "║   ░█▄█░█▀▀░█░░░█░░░█░█░█░█░█▀▀░░░░█░░█░█░░░█▀▀░█▀▀░█░█░█░█░█▀▄░█▀█░▀░   ║"
echo "║   ░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░░░░▀░░▀▀▀░░░▀░░░▀▀▀░▀▀░░▀▀▀░▀░▀░▀░▀░▀░   ║"
echo "║                                                                         ║"
echo "╚═════════════════════════════════════════════════════════════════════════╝"
echo ""
color_echo "green" "All steps completed. Enjoy!"

# Prompt for reboot
prompt_reboot
