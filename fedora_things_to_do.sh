#!/usr/bin/env bash
# "Things To Do!" script for a fresh Fedora Workstation installation
# Version: 25.10 - Enhanced Edition with Custom Configs

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Check if the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo"
  exit 1
fi

# Function to echo colored text
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
ACTUAL_USER=${SUDO_USER:-$(whoami)}
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
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
  local message="$1"
  local exit_code=${2:-$?}
  if [ $exit_code -ne 0 ]; then
    color_echo "red" "ERROR: $message (Exit code: $exit_code)"
    log_message "ERROR: $message (Exit code: $exit_code)"
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
    color_echo "red" "Reboot canceled. Please reboot manually for all changes to take effect."
  fi
}

# Function to backup configuration files
backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    cp "$file" "$file.bak.$(date +%Y%m%d_%H%M%S)"
    handle_error "Failed to backup $file"
    color_echo "green" "Backed up $file"
  fi
}

# Function to run commands as actual user
run_as_user() {
  sudo -u $ACTUAL_USER bash -c "$@"
}

# Function to check if command exists
command_exists() {
  command -v "$1" &>/dev/null
}

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                           ║"
echo "║   ░█▀▀░█▀▀░█▀▄░█▀█░█▀▄░█▀█░░░█░█░█▀█░█▀▄░█░█░█▀▀░▀█▀░█▀█░▀█▀░▀█▀░█▀█░█▀█   ║"
echo "║   ░█▀▀░█▀▀░█░█░█░█░█▀▄░█▀█░░░█▄█░█░█░█▀▄░█▀▄░▀▀█░░█░░█▀█░░█░░░█░░█░█░█░█   ║"
echo "║   ░▀░░░▀▀▀░▀▀░░▀▀▀░▀░▀░▀░▀░░░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░░▀░░▀░▀░░▀░░▀▀▀░▀▀▀░▀░▀   ║"
echo "║   ░░░░░░░░░░░░▀█▀░█░█░▀█▀░█▀█░█▀▀░█▀▀░░░▀█▀░█▀█░░░█▀▄░█▀█░█░░░░░░░░░░░░   ║"
echo "║   ░░░░░░░░░░░░░█░░█▀█░░█░░█░█░█░█░▀▀█░░░░█░░█░█░░░█░█░█░█░▀░░░░░░░░░░░   ║"
echo "║   ░░░░░░░░░░░░░▀░░▀░▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░░░░▀░░▀▀▀░░░▀▀░░▀▀▀░▀░░░░░░░░░░░   ║"
echo "║                                                                           ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "This script automates \"Things To Do!\" steps after a fresh Fedora Workstation installation"
echo "ver. 25.10 / Enhanced Edition with Custom Configs"
echo ""
echo "Don't run this script if you didn't build it yourself or don't know what it does."
echo ""
read -p "Press Enter to continue or CTRL+C to cancel..."

log_message "Script started by user: $ACTUAL_USER"

# System Upgrade
color_echo "blue" "Performing system upgrade (excluding kernel updates)... This may take a while..."
dnf upgrade --exclude=kernel* --exclude=kernel-core* --exclude=kernel-modules* --exclude=kernel-devel* -y
handle_error "System upgrade failed"

# System Configuration
# Set the system hostname to uniquely identify the machine on the network
color_echo "yellow" "Setting hostname..."
read -p "Enter desired hostname (default: fedora): " new_hostname
new_hostname=${new_hostname:-fedora}
hostnamectl set-hostname "$new_hostname"
color_echo "green" "Hostname set to: $new_hostname"

# Optimize DNF package manager for faster downloads and efficient updates
color_echo "yellow" "Configuring DNF Package Manager..."
backup_file "/etc/dnf/dnf.conf"
cat >> /etc/dnf/dnf.conf <<EOF
max_parallel_downloads=10
fastestmirror=True
defaultyes=True
EOF
dnf install -y dnf-plugins-core
color_echo "green" "DNF configured successfully."

# Replace Fedora Flatpak Repo with Flathub for better package management and apps stability
color_echo "yellow" "Replacing Fedora Flatpak Repo with Flathub..."
dnf install -y flatpak
flatpak remote-delete fedora --force 2>/dev/null || true
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak repair
flatpak update -y
color_echo "green" "Flathub configured successfully."

# Install and enable SSH server for secure remote access and file transfers
color_echo "yellow" "Installing and enabling SSH..."
dnf install -y openssh-server
systemctl enable --now sshd
color_echo "green" "SSH installed and enabled."

# Check and apply firmware updates to improve hardware compatibility and performance
color_echo "yellow" "Checking for firmware updates..."
if command_exists fwupdmgr; then
  fwupdmgr get-devices 2>/dev/null || true
  fwupdmgr refresh --force 2>/dev/null || true
  fwupdmgr get-updates 2>/dev/null || true
  fwupdmgr update -y 2>/dev/null || true
  color_echo "green" "Firmware check completed."
else
  color_echo "yellow" "fwupdmgr not available, skipping firmware updates."
fi

# Enable RPM Fusion repositories to access additional software packages and codecs
color_echo "yellow" "Enabling RPM Fusion repositories..."
dnf install -y \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf update @core -y
color_echo "green" "RPM Fusion repositories enabled."

# Install multimedia codecs to enhance multimedia capabilities
color_echo "yellow" "Installing multimedia codecs..."
dnf swap ffmpeg-free ffmpeg --allowerasing -y
dnf install -y gstreamer1-plugins-{bad-\*,good-\*,base} gstreamer1-plugin-openh264 gstreamer1-libav lame\* --exclude=gstreamer1-plugins-bad-free-devel
dnf group install -y multimedia 2>/dev/null || dnf groupinstall -y Multimedia 2>/dev/null || color_echo "yellow" "Multimedia group not found, but individual packages were installed"
dnf install -y ffmpeg-libs libva libva-utils
dnf group install -y sound-and-video 2>/dev/null || dnf groupinstall -y "Sound and Video" 2>/dev/null || color_echo "yellow" "Sound and Video group not found, continuing..."
dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y 2>/dev/null || true
dnf update @sound-and-video -y 2>/dev/null || true
color_echo "green" "Multimedia codecs installed successfully."

# Install Hardware Accelerated Codecs for AMD GPUs
color_echo "yellow" "Installing AMD Hardware Accelerated Codecs..."
dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
dnf swap mesa-va-drivers mesa-va-drivers-freeworld -y 2>/dev/null || true
dnf swap mesa-vdpau-drivers mesa-vdpau-drivers-freeworld -y 2>/dev/null || true
color_echo "green" "AMD codecs installed successfully."

# Install virtualization tools to enable virtual machines and containerization
color_echo "yellow" "Installing virtualization tools..."
dnf install -y @virtualization 2>/dev/null || dnf group install -y virtualization 2>/dev/null || {
  color_echo "yellow" "Virtualization group not found, installing individual packages..."
  dnf install -y qemu-kvm libvirt virt-install virt-manager virt-viewer
}
systemctl enable --now libvirtd 2>/dev/null || color_echo "yellow" "Could not enable libvirtd (may not be installed)"
usermod -aG libvirt $ACTUAL_USER 2>/dev/null || true
color_echo "green" "Virtualization tools installation completed."

# App Installation
# Install essential applications
color_echo "yellow" "Installing essential applications..."
dnf install -y p7zip p7zip-plugins fastfetch unzip unrar git wget curl gnome-tweaks htop btop
color_echo "green" "Essential applications installed successfully."

# Install Internet & Communication applications
color_echo "yellow" "Installing Zen Browser..."
flatpak install -y flathub io.github.zen_browser.zen 2>/dev/null || \
flatpak install -y flathub app.zen_browser.zen 2>/dev/null || \
color_echo "yellow" "Zen Browser not found in Flathub, skipping..."
color_echo "green" "Zen Browser installation attempted."

# Configure Zen Browser with custom CSS
color_echo "yellow" "Configuring Zen Browser with custom theme..."

# Create .zen directory if it doesn't exist
mkdir -p "$ACTUAL_HOME/.zen"
chown $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.zen"

# Find Zen Browser profile directory
ZEN_PROFILE_DIR=$(find "$ACTUAL_HOME/.zen" -maxdepth 1 -type d \( -name "*.default*" -o -name "*.Default*" \) 2>/dev/null | head -n 1)

if [ -z "$ZEN_PROFILE_DIR" ]; then
  # If profile doesn't exist, create a default one
  color_echo "yellow" "Zen Browser profile not found. Creating configuration for first launch..."
  ZEN_PROFILE_DIR="$ACTUAL_HOME/.zen/default.default-release"
  mkdir -p "$ZEN_PROFILE_DIR/chrome"
else
  # Create chrome directory if it doesn't exist
  mkdir -p "$ZEN_PROFILE_DIR/chrome"
  color_echo "green" "Found Zen Browser profile at: $ZEN_PROFILE_DIR"
fi

# Create userChrome.css
cat > "$ZEN_PROFILE_DIR/chrome/userChrome.css" <<'USERCHROME_EOF'
@import "ZenZero/modules/zz-tab-groups.css";
@import "ZenZero/modules/zz-tab-switcher.css";
@import "ZenZero/modules/zz-player.css";
@import "ZenZero/modules/zz-containers.css";
@import "ZenZero/modules/zz-custom-addon-icons.css";
@import "ZenZero/modules/zz-glance.css";
@import "ZenZero/modules/zz-general.css";
/*   @import "ZenZero/modules/zz-compact-sidebar.css"; */

/* other mods */

/* auto hide toolbar buttons */
#zen-sidebar-top-buttons {
  transition: all 0.3s ease-in-out !important;
  margin-top: 0 !important;
  padding-top: 5px !important;
}

#navigator-toolbox:not(:has(#nav-bar:hover)):not(:has(#urlbar[open=""])) {
  #zen-sidebar-top-buttons:not(:hover):not(:has([open="true"])):has(
      toolbarbutton:not([hidden="true"]):not(#unified-extensions-button)
    ) {
    margin-top: -20px !important;
    margin-bottom: 0 !important;
    opacity: 0 !important;
  }
}

.tab-group-label {
  #tabbrowser-tabs[orient="vertical"] & {
    height: 100% !important;
    align-content: center !important;
  }
}

.browserContainer.responsive-mode{
  background-color: transparent !important;
  browser{
    border-radius: 2em !important;
  }
}

/* Floating URL Bar - Show results only when typing */
#urlbar[open] {
  background-image: var(--zen-main-browser-background-toolbar) !important;
  border-radius: 20px !important;
  left: 50%;
  position: absolute !important;
}
 
#urlbar[open] #urlbar-background {
  margin: 4px !important;
}
 
#urlbar .urlbarView-body-inner {
  display: none !important;
}
 
#urlbar[usertyping] .urlbarView-body-inner {
  display: block !important;
}

/* ============= transparent sidebar - use either mask or push ================== */
#zen-main-app-wrapper {
  --zen-sidebar-custom-width: 165px !important;
}

[zen-compact-mode="true"] #navigator-toolbox{
  --zen-sidebar-width: var(--zen-sidebar-custom-width) !important;
  --actual-zen-sidebar-width: var(--zen-sidebar-custom-width) !important;
  width: var(--zen-sidebar-custom-width) !important;
}

.urlbar-background{
  background-color: color-mix(in srgb, var(--zen-urlbar-background-base) 60%, transparent) !important;
  border-radius: 1em !important;
}

/* mask */
#titlebar::before{
  box-shadow:  light-dark(#fff3, #0003) 0px -36px 30px 0px inset, rgba(0, 0, 0, 0.06) 0px 2px 1px, rgba(0, 0, 0, 0.09) 0px 4px 2px, rgba(0, 0, 0, 0.09) 0px 8px 4px, rgba(0, 0, 0, 0.09) 0px 16px 8px, rgba(0, 0, 0, 0.09) 0px 32px 16px !important;
  background-color: light-dark(#fff8, #0005)  !important;
}

#main-window:not([zen-right-side="true"]) #zen-main-app-wrapper[zen-compact-mode="true"]:has([zen-user-show=""],#navigator-toolbox[zen-has-hover="true"],[has-popup-menu=""]){
  #tabbrowser-tabpanels {
    mask-image: linear-gradient(to right, transparent 0, transparent calc(var(--zen-sidebar-custom-width) + 10px), black 0, black 100%) !important;
    mask-repeat: no-repeat !important;
    mask-size: 100% 100% !important;
  }
}

#main-window[zen-right-side="true"] #zen-main-app-wrapper[zen-compact-mode="true"]:has([zen-user-show=""],#navigator-toolbox[zen-has-hover="true"],[has-popup-menu=""]){
  #tabbrowser-tabpanels {
    mask-image: linear-gradient(to left, transparent 0, transparent calc(var(--zen-sidebar-custom-width) + 10px), black 0, black 100%) !important;
    mask-repeat: no-repeat !important;
    mask-size: 100% 100% !important;
  }
}
USERCHROME_EOF

# Create userContent.css
cat > "$ZEN_PROFILE_DIR/chrome/userContent.css" <<'USERCONTENT_EOF'
:root{
  --zen-colors-tertiary: transparent !important;
  --zen-settings-secondary-background: transparent !important;
}

#preferences-root{
  background-color: transparent !important;
}

html:has([data-l10n-id]){
  background-color: transparent !important;
}

.KEYJUMP_hint{
  border-radius: 100px !important;
  background-color: #49FCBB !important;
  color: #000 !important;
  font-family: 'Product Sans', Sans !important;
  font-weight: bold !important;
  box-shadow: #0008 0 0 10px !important;
  border: #0008 1px solid !important;
  transition: all 0.3s ease-in-out !important;
}

@-moz-document url(about:config), url(about:support){
  html, #toolbar{
    background-color: transparent !important;
  }
  tr, table{
    background-color: transparent !important;
    border: none !important;
  }
  tr{
    outline: solid 1px #88888822 !important;
  }
}

groupbox{
  background: var(--zen-colors-border-contrast) !important;
  border: none;
}

@-moz-document url(about:home), url(about:newtab), url(about:privatebrowsing) {
  body, .App{
    background-color: #00000000 !important;
  }

  .top-sites-list, .personalizeButtonWrapper{
    opacity: 0 !important;
    transition: opacity 0.3s ease-in-out;

    &:hover{
      opacity: 1 !important;
    }
  }
  
  .App > div:nth-child(2), .wallpaper{
    display: none !important;
  }
  
  .info-border > .info{
    display: none !important;
  }
  
  #search-handoff-button{
    border-radius: 2em !important;
  }
  
  .wordmark{
    display: none !important;
  }
}

@-moz-document url(addons.mozilla.org) {
  html, body, nav, header{
    background-color: transparent !important;
    background: none !important;
    border: none !important;
    box-shadow: none !important;
  }

  :root{
    --darkreader-background-ffffff: transparent !important;
  }

  footer{
    display: none !important;
  }
}
USERCONTENT_EOF

# Create zen-themes.css
cat > "$ZEN_PROFILE_DIR/chrome/zen-themes.css" <<'ZENTHEMES_EOF'
/* Zen Mods - Generated by ZenMods.
* FILE GENERATED AT: Saturday, October 4, 2025 at 10:38:38 PM Indochina Time
* DO NOT EDIT THIS FILE DIRECTLY!
* Your changes will be overwritten.
* Instead, go to the preferences and edit the mods there.
*/

/* End of Zen Mods */
ZENTHEMES_EOF

# Set proper permissions
chown -R $ACTUAL_USER:$ACTUAL_USER "$ZEN_PROFILE_DIR"
color_echo "green" "Zen Browser custom theme configured successfully."

# Remove Firefox
color_echo "yellow" "Removing Firefox browser..."
dnf remove -y firefox 2>/dev/null || true
color_echo "green" "Firefox removed successfully."

color_echo "yellow" "Installing Discord..."
dnf install -y discord 2>/dev/null || flatpak install -y flathub com.discordapp.Discord
color_echo "green" "Discord installed successfully."

color_echo "yellow" "Installing Telegram Desktop..."
dnf install -y telegram-desktop 2>/dev/null || flatpak install -y flathub org.telegram.desktop
color_echo "green" "Telegram Desktop installed successfully."

# Install Alacritty terminal emulator
color_echo "yellow" "Installing Alacritty terminal emulator..."
dnf install -y alacritty
handle_error "Failed to install Alacritty"

# Configure Alacritty with custom config
color_echo "yellow" "Configuring Alacritty with custom theme..."
mkdir -p "$ACTUAL_HOME/.config/alacritty/theme"

# Create main Alacritty config
cat > "$ACTUAL_HOME/.config/alacritty/alacritty.toml" <<'ALACRITTY_EOF'
general.import = [ "~/.config/alacritty/theme/alacritty.toml" ]

[env]
TERM = "xterm-256color"

[font]
normal = { family = "MesloLGS Nerd Font Mono" }
bold = { family = "MesloLGS Nerd Font Mono" }
italic = { family = "MesloLGS Nerd Font Mono" }
size = 12

[window]
padding.x = 14
padding.y = 14
decorations = "None"
opacity = 0.9

[keyboard]
bindings = [
{ key = "F11", action = "ToggleFullscreen" }
]
ALACRITTY_EOF

# Create Alacritty theme file
cat > "$ACTUAL_HOME/.config/alacritty/theme/alacritty.toml" <<'ALACRITTY_THEME_EOF'
[colors]
draw_bold_text_with_bright_colors = true

[colors.primary]
background = '#282A36'
foreground = '#F8F8F2'

[colors.cursor]
text = 'CellBackground'
cursor = 'CellForeground'

[colors.normal]
black = '#282A36'
red = '#FFAFCC'
green = '#8BE9FD'
blue = '#8BE9FD'
magenta = '#FFC8DD'
cyan = '#8BE9FD'
white = '#F8F8F2'
yellow = '#CBC3E3'

[colors.bright]
black = '#F8F8F2'
red = '#FFAFCC'
green = '#BDE0FE'
yellow = '#CBC3E3'
blue = '#BDE0FE'
magenta = '#FFC8DD'
cyan = '#BDE0FE'
white = '#F8F8F2'
ALACRITTY_THEME_EOF

chown -R $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.config/alacritty"
color_echo "green" "Alacritty installed and configured successfully."

# Install Zsh and Oh My Posh
color_echo "yellow" "Installing Zsh with Zinit and Oh My Posh..."
dnf install -y zsh fzf git

# Verify zsh is installed
if ! command_exists zsh; then
  color_echo "red" "Failed to install Zsh"
  handle_error "Zsh installation failed" 1
fi

# Change shell for actual user (only if zsh exists)
ZSH_PATH=$(which zsh)
chsh -s "$ZSH_PATH" "$ACTUAL_USER" 2>/dev/null || {
  color_echo "yellow" "Could not change shell automatically. You can change it manually with: chsh -s $(which zsh)"
}

# Install Oh My Posh as actual user
color_echo "yellow" "Installing Oh My Posh..."
run_as_user "curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin" 2>/dev/null || {
  color_echo "yellow" "Oh My Posh installation had issues, but continuing..."
}

# Create theme directory
mkdir -p "$ACTUAL_HOME/.local/bin/theme"
chown -R $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.local/bin"

# Download theme
color_echo "yellow" "Downloading Oh My Posh theme..."
run_as_user "wget -q -O $ACTUAL_HOME/.local/bin/theme/emodipt-extend.omp.json https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/emodipt-extend.omp.json" 2>/dev/null || {
  color_echo "yellow" "Failed to download theme, creating a basic one..."
  echo '{}' > "$ACTUAL_HOME/.local/bin/theme/emodipt-extend.omp.json"
  chown $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.local/bin/theme/emodipt-extend.omp.json"
}

# Install zoxide as actual user
color_echo "yellow" "Installing zoxide..."
run_as_user "curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash" 2>/dev/null || {
  color_echo "yellow" "Zoxide installation had issues, but continuing..."
}

# Create comprehensive .zshrc with Zinit
cat > "$ACTUAL_HOME/.zshrc" <<'ZSHRC_EOF'
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.

# Set the directory to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
	mkdir -p "$(dirname $ZINIT_HOME)"
	git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load Zinit
source "${ZINIT_HOME}/zinit.zsh"

# ohmyposh - check if oh-my-posh exists before initializing
if [ -f "$HOME/.local/bin/oh-my-posh" ]; then
  if [ -f "$HOME/.local/bin/theme/emodipt-extend.omp.json" ]; then
    eval "$(oh-my-posh init zsh --config ~/.local/bin/theme/emodipt-extend.omp.json)"
  else
    eval "$(oh-my-posh init zsh)"
  fi
fi

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add in snippets
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

# load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Aliases
alias ls='ls --color'
alias c='clear'
alias q='exit'

# Shell integrations
if command -v fzf &> /dev/null; then
  eval "$(fzf --zsh)"
fi

if command -v zoxide &> /dev/null; then
  eval "$(zoxide init --cmd cd zsh)"
fi

# Automatically start ssh-agent and add key if not already done
if [ -z "$SSH_AUTH_SOCK" ]; then
  if [ -f ~/.ssh/id_rsa ]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    ssh-add ~/.ssh/id_rsa 2>/dev/null < /dev/null
  fi
fi
ZSHRC_EOF

chown $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.zshrc"
color_echo "green" "Zsh with Zinit and Oh My Posh installed and configured successfully."

# Install Office Productivity applications
color_echo "yellow" "Installing LibreOffice..."
dnf remove -y libreoffice* 2>/dev/null || true
flatpak install -y flathub org.libreoffice.LibreOffice
flatpak install -y --reinstall org.freedesktop.Platform.Locale/x86_64/24.08 2>/dev/null || true
flatpak install -y --reinstall org.libreoffice.LibreOffice.Locale 2>/dev/null || true
color_echo "green" "LibreOffice installed successfully."

color_echo "yellow" "Installing Obsidian..."
flatpak install -y flathub md.obsidian.Obsidian
color_echo "green" "Obsidian installed successfully."

# Install Coding and DevOps applications
color_echo "yellow" "Installing Visual Studio Code..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc

# Remove old repo if exists
if [ -f /etc/yum.repos.d/vscode.repo ]; then
  color_echo "yellow" "VS Code repository already exists, updating..."
  rm -f /etc/yum.repos.d/vscode.repo
fi

cat > /etc/yum.repos.d/vscode.repo <<EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
dnf check-update || true
dnf install -y code
color_echo "green" "Visual Studio Code installed successfully."

color_echo "yellow" "Installing Docker..."
dnf remove -y docker docker-client docker-client-latest docker-common docker-latest \
  docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine 2>/dev/null || true

dnf -y install dnf-plugins-core

# Add Docker repository (remove old one first if it exists)
if [ -f /etc/yum.repos.d/docker-ce.repo ]; then
  color_echo "yellow" "Docker repository already exists, removing old configuration..."
  rm -f /etc/yum.repos.d/docker-ce.repo
fi

dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo || {
  color_echo "yellow" "Failed to add Docker repo with dnf config-manager, trying manual method..."
  dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
}

dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
systemctl enable --now containerd

groupadd docker 2>/dev/null || true
usermod -aG docker $ACTUAL_USER

# Clean up any existing docker directory
rm -rf "$ACTUAL_HOME/.docker"
mkdir -p "$ACTUAL_HOME/.docker"
chown -R $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.docker"

color_echo "green" "Docker installed successfully. Please log out and back in for group changes to take effect."

color_echo "yellow" "Installing essential development tools and languages..."
dnf groupinstall -y "Development Tools" 2>/dev/null || dnf group install -y development-tools 2>/dev/null || {
  color_echo "yellow" "Could not install Development Tools group, installing individual packages..."
  dnf install -y gcc gcc-c++ make automake autoconf libtool git
}
dnf install -y gcc clang cmake python3 python3-pip nodejs npm

# Install Java (check available version)
dnf install -y java-latest-openjdk-devel || dnf install -y java-21-openjdk-devel || dnf install -y java-17-openjdk-devel

color_echo "green" "Essential development tools and languages installed successfully."

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
rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm 2>/dev/null || true
color_echo "green" "Microsoft Fonts (core) installation attempted."

# Install Google fonts collection
color_echo "yellow" "Installing Google Fonts..."
GOOGLE_FONTS_DIR="$ACTUAL_HOME/.local/share/fonts/google"
mkdir -p "$GOOGLE_FONTS_DIR"

TEMP_FONTS_DIR=$(mktemp -d)
cd "$TEMP_FONTS_DIR"

wget -q -O google-fonts.zip https://github.com/google/fonts/archive/main.zip 2>/dev/null || {
  color_echo "yellow" "Failed to download Google Fonts, skipping..."
}

if [ -f google-fonts.zip ]; then
  unzip -q google-fonts.zip -d "$GOOGLE_FONTS_DIR" 2>/dev/null || {
    color_echo "yellow" "Failed to extract Google Fonts, but continuing..."
  }
  rm -f google-fonts.zip
  chown -R $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.local/share/fonts"
  fc-cache -fv 2>/dev/null || fc-cache -f
  color_echo "green" "Google Fonts installed successfully."
else
  color_echo "yellow" "Failed to download Google Fonts, skipping..."
fi

# Clean up
cd /tmp
rm -rf "$TEMP_FONTS_DIR"

# Download and install Meslo Nerd Font
color_echo "yellow" "Installing Meslo Nerd Font..."
MESLO_DIR="$ACTUAL_HOME/.local/share/fonts/MesloNerdFont"
mkdir -p "$MESLO_DIR"

# Change to temp directory for download
TEMP_FONT_DIR=$(mktemp -d)
cd "$TEMP_FONT_DIR"

wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip -O Meslo.zip 2>/dev/null || {
  color_echo "yellow" "Failed to download Meslo Nerd Font from latest release, trying alternate method..."
  wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Meslo.zip -O Meslo.zip 2>/dev/null || true
}

if [ -f Meslo.zip ]; then
  unzip -q -o Meslo.zip -d "$MESLO_DIR" 2>/dev/null || {
    color_echo "yellow" "Unzip failed, trying with error suppression..."
    unzip -o Meslo.zip -d "$MESLO_DIR" 2>&1 | grep -v "warning" || true
  }
  rm -f Meslo.zip
  chown -R $ACTUAL_USER:$ACTUAL_USER "$MESLO_DIR"
  fc-cache -fv 2>/dev/null || fc-cache -f
  color_echo "green" "Meslo Nerd Font installed successfully."
else
  color_echo "yellow" "Failed to download Meslo Nerd Font, skipping..."
fi

# Clean up and return to safe directory
cd /tmp
rm -rf "$TEMP_FONT_DIR"

# Install Tela icon theme
color_echo "yellow" "Installing Tela Icon Theme..."
TEMP_TELA_DIR=$(mktemp -d)
git clone https://github.com/vinceliuice/Tela-icon-theme.git "$TEMP_TELA_DIR" 2>/dev/null || {
  color_echo "yellow" "Failed to clone Tela icon theme repository, skipping..."
}

if [ -d "$TEMP_TELA_DIR/.git" ]; then
  cd "$TEMP_TELA_DIR"
  chmod +x ./install.sh
  ./install.sh -a 2>/dev/null || {
    color_echo "yellow" "Tela icon theme installation had issues, but continuing..."
  }
  cd /tmp
  rm -rf "$TEMP_TELA_DIR"
  
  # Set icon theme for user
  run_as_user "gsettings set org.gnome.desktop.interface icon-theme 'Tela-orange'" 2>/dev/null || {
    color_echo "yellow" "Could not set Tela icon theme as default, you can set it manually"
  }
  color_echo "green" "Tela Icon Theme installed successfully."
else
  color_echo "yellow" "Tela icon theme installation skipped."
  rm -rf "$TEMP_TELA_DIR"
fi

# Disable NetworkManager-wait-online.service
color_echo "yellow" "Disabling NetworkManager-wait-online.service..."
systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
color_echo "green" "NetworkManager-wait-online.service disabled."

# Configure Better Battery-life
color_echo "yellow" "Installing TLP for better battery life..."
dnf install -y https://repo.linrunner.de/fedora/tlp/repos/releases/tlp-release.fc$(rpm -E %fedora).noarch.rpm

# Remove conflicting power profile daemon
dnf remove -y tuned tuned-ppd 2>/dev/null || true

# Install TLP
dnf install -y tlp tlp-rdw

# Enable TLP service
systemctl enable tlp.service

# Mask the following services to avoid conflicts with TLP's Radio Device Switching options
systemctl mask systemd-rfkill.service systemd-rfkill.socket 2>/dev/null || true

color_echo "green" "TLP configured successfully."

# Configure Dual Boot time fix
color_echo "yellow" "Configuring hardware clock to use UTC (fixes dual-boot time issues)..."
timedatectl set-local-rtc 0 --adjust-system-clock
color_echo "green" "Hardware clock configured successfully."

# Encrypted DNS
color_echo "yellow" "Configuring Encrypted DNS (DNS-over-HTTPS via Cloudflare)..."

# Add Cloudflared repository (remove old one first if it exists)
if [ -f /etc/yum.repos.d/cloudflared.repo ]; then
  color_echo "yellow" "Cloudflared repository already exists, removing old configuration..."
  rm -f /etc/yum.repos.d/cloudflared.repo
fi

dnf config-manager addrepo --from-repofile=https://pkg.cloudflare.com/cloudflared.repo 2>/dev/null || {
  color_echo "yellow" "Could not add Cloudflared repo, trying alternate method..."
  dnf config-manager --add-repo https://pkg.cloudflare.com/cloudflared.repo 2>/dev/null || true
}

# Install cloudflared
dnf install -y cloudflared

# Create a systemd service for cloudflared
cat > /etc/systemd/system/cloudflared.service <<'EOF'
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
systemctl daemon-reload
systemctl enable --now cloudflared

# Configure systemd-resolved to use 127.0.0.1 (cloudflared)
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/dns-over-https.conf <<'EOF'
[Resolve]
DNS=127.0.0.1
FallbackDNS=1.1.1.1
DNSSEC=yes
Cache=yes
EOF

# Tell NetworkManager to use systemd-resolved
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/dns.conf <<'EOF'
[main]
dns=systemd-resolved
EOF

# Restart services
systemctl restart cloudflared
systemctl restart systemd-resolved
systemctl restart NetworkManager

# Test DNS resolution
color_echo "blue" "Testing DNS resolution..."
dig +short example.com || nslookup example.com || true

# Check current DNS status
resolvectl status | head -n 20

color_echo "green" "Encrypted DNS configured successfully."

# Disable GNOME Software autostart
color_echo "yellow" "Disabling GNOME Software autostart..."
rm -f /etc/xdg/autostart/org.gnome.Software.desktop 2>/dev/null || true
color_echo "green" "GNOME Software autostart disabled."

# System Cleanup
color_echo "yellow" "Cleaning up the system..."

# Clean package cache
dnf clean all

# Remove orphaned packages
dnf autoremove -y

# Remove old kernels (keeping last 2)
color_echo "yellow" "Removing old kernels (keeping last 2)..."
dnf remove $(dnf repoquery --installonly --latest-limit=-2 -q) -y 2>/dev/null || true

color_echo "green" "System cleaned successfully."

# Create a summary file
SUMMARY_FILE="$ACTUAL_HOME/fedora_setup_summary.txt"
cat > "$SUMMARY_FILE" <<EOF
Fedora Workstation Setup Summary
================================
Date: $(date)
User: $ACTUAL_USER
Hostname: $(hostname)

Installed Applications:
- Zen Browser (Flatpak) with custom CSS theme
- Discord
- Telegram Desktop
- Alacritty Terminal with custom theme (pastel colors)
- Zsh with Zinit, Oh My Posh, and plugins
- LibreOffice (Flatpak)
- Obsidian (Flatpak)
- Visual Studio Code
- Docker
- VLC
- OBS Studio
- AnyDesk (Flatpak)
- Extension Manager (Flatpak)

Configured Features:
- DNF optimizations (10 parallel downloads, fastest mirror)
- Flathub repository
- SSH server
- RPM Fusion repositories
- Multimedia codecs
- AMD hardware acceleration
- Virtualization tools
- TLP for battery optimization
- Encrypted DNS (DNS-over-HTTPS via Cloudflare)
- UTC hardware clock for dual-boot

Custom Configurations Applied:
- Alacritty: Pastel color scheme with transparency
  Config: ~/.config/alacritty/alacritty.toml
- Zsh: Zinit plugin manager, Oh My Posh theme, fzf, zoxide
  Config: ~/.zshrc
- Zen Browser: Custom transparent sidebar, floating URL bar, custom styling
  Config: ~/.zen/*/chrome/userChrome.css & userContent.css

Zsh Plugins Installed:
- zsh-syntax-highlighting
- zsh-completions
- zsh-autosuggestions
- fzf-tab
- Oh My Zsh snippets (git, sudo, kubectl, etc.)

Post-Installation Steps:
1. Log out and back in for Docker group changes
2. Launch Zen Browser to activate custom CSS (may need to enable in about:config)
3. Launch Alacritty to see the custom theme
4. Open a new terminal to start using Zsh
5. Customize GNOME with Extension Manager
6. Reboot to apply all changes

Useful Commands:
- 'cd <directory>' - Navigate (powered by zoxide)
- 'Ctrl+R' - Fuzzy search history with fzf
- 'ls' - Colorized file listing
- 'btop' or 'htop' - System monitoring

Configuration Files:
- Alacritty: ~/.config/alacritty/
- Zsh: ~/.zshrc
- Zen Browser: ~/.zen/*/chrome/
- Oh My Posh: ~/.local/bin/theme/

Log file: $LOG_FILE
EOF

chown $ACTUAL_USER:$ACTUAL_USER "$SUMMARY_FILE"
color_echo "green" "Setup summary saved to: $SUMMARY_FILE"

# Custom user-defined commands
echo ""
echo "Created with ❤️ for Open Source"

# Before finishing, ensure we're in a safe directory
cd /tmp || cd "$ACTUAL_HOME" || cd /

log_message "Script completed successfully"

# Finish
echo ""
echo "╔═════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                         ║"
echo "║   ░█░█░█▀▀░█░░░█▀▀░█▀█░█▄█░█▀▀░░░▀█▀░█▀█░░░█▀▀░█▀▀░█▀▄░█▀█░█▀▄░█▀█░█   ║"
echo "║   ░█▄█░█▀▀░█░░░█░░░█░█░█░█░█▀▀░░░░█░░█░█░░░█▀▀░█▀▀░█░█░█░█░█▀▄░█▀█░▀   ║"
echo "║   ░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░░░░▀░░▀▀▀░░░▀░░░▀▀▀░▀▀░░▀▀▀░▀░▀░▀░   ║"
echo "║                                                                         ║"
echo "╚═════════════════════════════════════════════════════════════════════════╝"
echo ""
color_echo "green" "All steps completed successfully!"
color_echo "blue" "Check $SUMMARY_FILE for a complete summary."
echo ""
color_echo "yellow" "IMPORTANT NOTES:"
echo "  1. Your custom configurations have been applied:"
echo "     • Alacritty: Pastel theme with transparency"
echo "     • Zsh: Full Zinit setup with Oh My Posh"
echo "     • Zen Browser: Custom CSS theme"
echo ""
echo "  2. To enable Zen Browser custom CSS:"
echo "     • Open Zen Browser"
echo "     • Type 'about:config' in the address bar"
echo "     • Search for 'toolkit.legacyUserProfileCustomizations.stylesheets'"
echo "     • Set it to 'true'"
echo "     • Restart Zen Browser"
echo ""
echo "  3. Log out and back in for all group changes to take effect"
echo ""

# Prompt for reboot
prompt_reboot
