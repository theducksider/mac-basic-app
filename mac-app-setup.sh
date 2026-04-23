#!/bin/bash

set -euo pipefail

########################################
# LOGGING HELPERS
########################################
log_info()    { echo "[$(date '+%H:%M:%S')] ℹ  $*"; }
log_success() { echo "[$(date '+%H:%M:%S')] ✅ $*"; }
log_warn()    { echo "[$(date '+%H:%M:%S')] ⚠  $*" >&2; }
log_error()   { echo "[$(date '+%H:%M:%S')] ❌ $*" >&2; }
log_step()    { echo ""; echo "[$(date '+%H:%M:%S')] ──────── STEP: $* ────────"; }

########################################
# SUDO KEEP-ALIVE (ONE PROMPT, STAYS ALIVE)
########################################
ensure_sudo() {
  local real_user="${SUDO_USER:-$USER}"
  local sudoers_file="/etc/sudoers.d/99-install-nopasswd"

  log_info "Enter your password once — required for the full installation:"
  sudo -v

  # Write a temporary NOPASSWD rule so no child process prompts again
  echo "$real_user ALL=(ALL) NOPASSWD: ALL" | sudo tee "$sudoers_file" > /dev/null
  sudo chmod 0440 "$sudoers_file"

  # Always remove the rule on exit, success or failure
  trap 'sudo rm -f "$sudoers_file"; log_info "Sudo rule removed."' EXIT INT TERM

  log_success "sudo granted for full session (rule cleaned up on exit)."
}

########################################
# HOMEBREW SETUP
########################################
setup_homebrew() {
  log_step "Setting up Homebrew"
  export NONINTERACTIVE=1
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_AUTO_UPDATE=1

  if ! command -v brew &>/dev/null; then
    log_info "Homebrew not found. Downloading and installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    log_success "Homebrew installer finished."
  else
    log_info "Homebrew already present."
  fi

  log_info "Configuring brew PATH..."
  # Ensure brew is on PATH for both Apple Silicon and Intel Macs
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    log_error "Homebrew binary not found after install. Please check installation."
    exit 1
  fi

  log_success "Homebrew ready: $(brew --version | head -1)"
}

########################################
# INSTALL CASK APPS (RESILIENT)
########################################
install_apps() {
  local apps=(
    google-chrome
    slack
    viber
    nordpass
    zoom
    adobe-acrobat-reader
    google-drive
    whatsapp
    openvpn-connect
  )

  local failed=()

  local total=${#apps[@]}
  local idx=0
  log_info "Installing $total applications..."

  for app in "${apps[@]}"; do
    idx=$((idx + 1))
    log_step "App $idx/$total: $app"
    if brew list --cask "$app" &>/dev/null; then
      log_info "$app already installed, skipping."
    else
      log_info "Downloading and installing $app..."
      if brew install --cask "$app"; then
        log_success "$app installed."
      else
        log_warn "$app failed to install. Continuing with remaining apps..."
        failed+=("$app")
      fi
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    log_warn "The following apps failed to install and require manual attention:"
    for f in "${failed[@]}"; do
      echo "  - $f"
    done
    return 1
  fi
}

########################################
# MAIN
########################################
main() {
  log_step "Starting secure headless Mac app installation"

  ensure_sudo "$@"
  setup_homebrew

  log_step "Updating Homebrew"
  brew update
  log_success "Homebrew updated."

  install_apps

  log_step "Cleanup"
  brew cleanup
  log_success "Cleanup done."

  log_success "All applications installed successfully."
  echo ""
  echo "Installed:"
  echo "  • Google Chrome"
  echo "  • Slack"
  echo "  • Viber"
  echo "  • NordPass"
  echo "  • Zoom"
  echo "  • Adobe Acrobat Reader"
  echo "  • Google Drive"
  echo "  • WhatsApp"
  echo "  • OpenVPN Connect"
}

main "$@"

