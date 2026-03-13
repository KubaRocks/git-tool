#!/usr/bin/env bash
set -uo pipefail

# gt installer
# Usage: curl -fsSL https://raw.githubusercontent.com/KubaRocks/git-tool/main/install.sh | bash

# When piped via curl|bash, stdin is the script. Reclaim the terminal.
if [[ ! -t 0 ]]; then
  exec < /dev/tty
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

info() { echo -e "${BLUE}▸${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠${RESET} $*"; }
error() { echo -e "${RED}error:${RESET} $*" >&2; }

REPO_URL="https://raw.githubusercontent.com/KubaRocks/git-tool/main"

echo ""
echo -e "${BOLD}gt${RESET} — Git Tool Installer"
echo -e "${DIM}─────────────────────────────────────────${RESET}"
echo ""

# ── Check dependencies ───────────────────────────────────────────────────────
info "Checking dependencies..."

missing_deps=()

if ! command -v git &>/dev/null; then
  error "git is required but not installed."
  exit 1
fi

if ! command -v gum &>/dev/null; then
  missing_deps+=("gum")
fi

if ! command -v claude &>/dev/null; then
  missing_deps+=("claude")
fi

if [[ ${#missing_deps[@]} -gt 0 ]]; then
  warn "Missing dependencies: ${missing_deps[*]}"
  echo ""

  for dep in "${missing_deps[@]}"; do
    case "$dep" in
      gum)
        echo -e "  ${BOLD}gum${RESET} — interactive terminal UI"
        if command -v brew &>/dev/null; then
          echo -e "    Install with: ${DIM}brew install gum${RESET}"
          read -rp "    Install now? [Y/n] " answer
          if [[ "${answer:-Y}" =~ ^[Yy]$ ]]; then
            brew install gum
            if command -v gum &>/dev/null; then
              success "gum installed."
            else
              error "Failed to install gum."
              exit 1
            fi
          fi
        else
          echo -e "    See: ${DIM}https://github.com/charmbracelet/gum#installation${RESET}"
        fi
        ;;
      claude)
        echo -e "  ${BOLD}claude${RESET} — Claude CLI for AI commit messages"
        if command -v npm &>/dev/null; then
          echo -e "    Install with: ${DIM}npm install -g @anthropic-ai/claude-code${RESET}"
          read -rp "    Install now? [Y/n] " answer
          if [[ "${answer:-Y}" =~ ^[Yy]$ ]]; then
            npm install -g @anthropic-ai/claude-code
            if command -v claude &>/dev/null; then
              success "claude installed."
            else
              error "Failed to install claude."
              exit 1
            fi
          fi
        else
          echo -e "    See: ${DIM}https://docs.anthropic.com/en/docs/claude-cli${RESET}"
        fi
        ;;
    esac
    echo ""
  done

  # Re-check after install attempts
  if ! command -v gum &>/dev/null || ! command -v claude &>/dev/null; then
    warn "Some dependencies are still missing. gt will prompt you when they're needed."
    echo ""
  fi
else
  success "All dependencies found."
fi

# ── Choose install location ──────────────────────────────────────────────────
echo ""
info "Choosing install location..."
echo ""

# Build list of candidate directories
candidates=()
candidate_labels=()

# Check common bin directories
for dir in "$HOME/bin" "$HOME/.local/bin" "/usr/local/bin"; do
  if [[ -d "$dir" && -w "$dir" ]]; then
    # Check if it's in PATH
    if echo "$PATH" | tr ':' '\n' | grep -qx "$dir"; then
      candidates+=("$dir")
      candidate_labels+=("${dir} (in PATH, writable)")
    else
      candidates+=("$dir")
      candidate_labels+=("${dir} (writable, not in PATH)")
    fi
  elif [[ -d "$dir" && ! -w "$dir" ]]; then
    candidates+=("$dir")
    candidate_labels+=("${dir} (requires sudo)")
  elif [[ ! -d "$dir" ]]; then
    # Directory doesn't exist — check if parent is writable
    parent_dir=$(dirname "$dir")
    if [[ -w "$parent_dir" ]]; then
      candidates+=("$dir")
      candidate_labels+=("${dir} (will be created)")
    fi
  fi
done

candidates+=("custom")
candidate_labels+=("Custom path...")

if [[ ${#candidates[@]} -eq 1 ]]; then
  # Only "custom" available
  echo -e "  No standard bin directories found."
fi

echo -e "  Where would you like to install ${BOLD}gt${RESET}?"
echo ""

# Simple menu (works without gum)
for i in "${!candidate_labels[@]}"; do
  echo -e "  ${GREEN}$((i + 1)))${RESET} ${candidate_labels[$i]}"
done
echo ""
read -rp "  Choose [1]: " choice_num
choice_num="${choice_num:-1}"

# Validate
if [[ ! "$choice_num" =~ ^[0-9]+$ ]] || [[ "$choice_num" -lt 1 ]] || [[ "$choice_num" -gt ${#candidates[@]} ]]; then
  error "Invalid choice."
  exit 1
fi

selected="${candidates[$((choice_num - 1))]}"

if [[ "$selected" == "custom" ]]; then
  read -rp "  Enter path: " selected
  selected="${selected/#\~/$HOME}"
fi

# Expand and validate
INSTALL_DIR="$selected"

# Create directory if needed
if [[ ! -d "$INSTALL_DIR" ]]; then
  info "Creating ${INSTALL_DIR}..."
  mkdir -p "$INSTALL_DIR" || { error "Could not create ${INSTALL_DIR}"; exit 1; }
fi

# ── Download and install ─────────────────────────────────────────────────────
echo ""
info "Installing gt to ${BOLD}${INSTALL_DIR}/gt${RESET}..."

USE_SUDO=""
if [[ ! -w "$INSTALL_DIR" ]]; then
  USE_SUDO="sudo"
  warn "Requires sudo to write to ${INSTALL_DIR}"
fi

if command -v curl &>/dev/null; then
  $USE_SUDO curl -fsSL "${REPO_URL}/gt" -o "${INSTALL_DIR}/gt"
elif command -v wget &>/dev/null; then
  $USE_SUDO wget -qO "${INSTALL_DIR}/gt" "${REPO_URL}/gt"
else
  error "Neither curl nor wget found. Cannot download."
  exit 1
fi

$USE_SUDO chmod +x "${INSTALL_DIR}/gt"

# ── Install zsh completions ─────────────────────────────────────────────────
COMPLETIONS_INSTALLED=false
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *zsh* ]]; then
  # Try common completion directories
  for comp_dir in "$HOME/.zsh/completions" "$HOME/.local/share/zsh/completions"; do
    if [[ -d "$comp_dir" ]]; then
      info "Installing zsh completions to ${comp_dir}..."
      curl -fsSL "${REPO_URL}/completions/_gt" -o "${comp_dir}/_gt" 2>/dev/null && COMPLETIONS_INSTALLED=true
      break
    fi
  done

  if [[ "$COMPLETIONS_INSTALLED" == false ]]; then
    # Create completions dir
    comp_dir="$HOME/.zsh/completions"
    mkdir -p "$comp_dir"
    info "Installing zsh completions to ${comp_dir}..."
    curl -fsSL "${REPO_URL}/completions/_gt" -o "${comp_dir}/_gt" 2>/dev/null && COMPLETIONS_INSTALLED=true

    if [[ "$COMPLETIONS_INSTALLED" == true ]]; then
      # Check if fpath includes this dir
      if ! grep -q '.zsh/completions' "$HOME/.zshrc" 2>/dev/null; then
        warn "Add this to your .zshrc to enable completions:"
        echo -e "    ${DIM}fpath=(~/.zsh/completions \$fpath)${RESET}"
      fi
    fi
  fi
fi

# ── Check PATH ───────────────────────────────────────────────────────────────
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo ""
  warn "${INSTALL_DIR} is not in your PATH."
  echo -e "  Add this to your shell profile:"

  if [[ "$SHELL" == *zsh* ]]; then
    echo -e "    ${DIM}echo 'export PATH=\"${INSTALL_DIR}:\$PATH\"' >> ~/.zshrc${RESET}"
  elif [[ "$SHELL" == *bash* ]]; then
    echo -e "    ${DIM}echo 'export PATH=\"${INSTALL_DIR}:\$PATH\"' >> ~/.bashrc${RESET}"
  else
    echo -e "    ${DIM}export PATH=\"${INSTALL_DIR}:\$PATH\"${RESET}"
  fi
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${DIM}─────────────────────────────────────────${RESET}"
success "gt installed successfully!"
echo ""
echo -e "  Run ${BOLD}gt${RESET} to get started."
echo ""
