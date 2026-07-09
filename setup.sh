#!/usr/bin/env bash
# ──────────────────────────────────────────────────
# Jason's terminal setup (Linux servers)
# No sudo. Detects zsh vs bash, installs the right
# oh-my-* framework + Jason's preferences.
#
# Run:  bash setup.sh
# ──────────────────────────────────────────────────
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${CYAN}→${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
err()   { echo -e "${RED}✗${NC} $*"; exit 1; }

# ── 0. Detect what we're working with ──────────────
echo "============================================"
echo " Jason's Terminal Setup"
echo "============================================"

# Find a downloader: curl > wget > error
if command -v curl &>/dev/null; then
    DOWNLOAD="curl -fsSL"
elif command -v wget &>/dev/null; then
    DOWNLOAD="wget -qO-"
else
    err "Need curl or wget. Install one and retry."
fi

# Detect target shell
if command -v zsh &>/dev/null; then
    SHELL_TYPE="zsh"
    CURRENT_SHELL="$(basename "${SHELL:-$0}")"
    info "zsh detected — will set up oh-my-zsh + agnoster-timestamp-newline theme"
elif [[ "${BASH_VERSION:-}" ]]; then
    SHELL_TYPE="bash"
    CURRENT_SHELL="bash"
    info "zsh not found, running bash — will set up oh-my-bash + agnoster theme"
else
    err "Neither zsh nor bash found. Something is wrong."
fi

# ── 0.5 Confirm ────────────────────────────────────
echo
echo " This will:"
if [[ "$SHELL_TYPE" == "zsh" ]]; then
    echo "   • Install oh-my-zsh"
    echo "   • Install agnoster-timestamp-newline theme"
else
    echo "   • Install oh-my-bash"
    echo "   • Set agnoster theme"
fi
echo "   • Install pixi"
echo "   • Write shell config (~/.${SHELL_TYPE}rc)"
echo "   • NO sudo, NO packages, NO chsh"
echo "============================================"
echo
read -rp "Continue? [y/N] " REPLY
[[ "$REPLY" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }

# ── 1. pixi (shell-agnostic, works on any Linux) ──
if command -v pixi &>/dev/null; then
    ok "pixi already installed ($(pixi --version 2>/dev/null || echo '?'))"
else
    info "Installing pixi..."
    $DOWNLOAD https://pixi.sh/install.sh | bash
    ok "pixi installed."
fi
# Ensure pixi is available right now
export PATH="$HOME/.pixi/bin:$PATH"

# ══════════════════════════════════════════════════
#  ZSH PATH
# ══════════════════════════════════════════════════
if [[ "$SHELL_TYPE" == "zsh" ]]; then

    # ── 2a. oh-my-zsh ──────────────────────────────
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        ok "oh-my-zsh already installed."
    else
        info "Installing oh-my-zsh..."
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
            sh -c "$($DOWNLOAD https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        ok "oh-my-zsh installed."
    fi

    # ── 2b. agnoster-timestamp-newline theme ───────
    THEME_DIR="$HOME/.oh-my-zsh/custom/themes"
    mkdir -p "$THEME_DIR"
    cat > "$THEME_DIR/agnoster-timestamp-newline.zsh-theme" << 'THEME_EOF'
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# Timestamp + newline variant by DylanDelobel
# https://github.com/DylanDelobel/agnoster-timestamp-newline-zsh-theme
#
# Requires a Powerline-patched font:
# https://github.com/powerline/fonts

CURRENT_BG='NONE'

() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  SEGMENT_SEPARATOR=$'\ue0b0'
}

prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

prompt_context() {
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment black default "%(!.%{%F{yellow}%}.)$USER@%m"
  fi
}

prompt_git() {
  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$'\ue0a0'
  }
  local ref dirty mode repo_path
  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    if [[ -n $dirty ]]; then
      prompt_segment yellow black
    else
      prompt_segment green black
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info
    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr '✚'
    zstyle ':vcs_info:*' unstagedstr '●'
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info
    echo -n "${ref/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
  fi
}

prompt_hg() {
  local rev status
  if $(hg id >/dev/null 2>&1); then
    if $(hg prompt >/dev/null 2>&1); then
      if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
        prompt_segment red white; st='±'
      elif [[ -n $(hg prompt "{status|modified}") ]]; then
        prompt_segment yellow black; st='±'
      else
        prompt_segment green black
      fi
      echo -n $(hg prompt "☿ {rev}@{branch}") $st
    else
      st=""
      rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(hg id -b 2>/dev/null)
      if $(hg st | grep -q "^\?"); then
        prompt_segment red black; st='±'
      elif $(hg st | grep -q "^[MA]"); then
        prompt_segment yellow black; st='±'
      else
        prompt_segment green black
      fi
      echo -n "☿ $rev@$branch" $st
    fi
  fi
}

prompt_dir() {
  prompt_segment blue black '%~'
}

prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment blue black "(`basename $virtualenv_path`)"
  fi
}

prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"
  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

prompt_newline() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR
%{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n " %{%k%}"
  fi
  echo -n " %{%f%}"
  CURRENT_BG=''
}

prompt_timestamp() {
  prompt_segment white black '%*'
}

build_prompt() {
  RETVAL=$?
  prompt_status
  prompt_virtualenv
  prompt_context
  prompt_timestamp
  prompt_dir
  prompt_git
  prompt_hg
  prompt_newline
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt)'
THEME_EOF
    ok "agnoster-timestamp-newline theme installed."

    # ── 2c. .zshrc ─────────────────────────────────
    # Back up if not ours
    if [[ -f "$HOME/.zshrc" ]] && ! grep -q "# Jason's" "$HOME/.zshrc" 2>/dev/null; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%s)"
        info "Existing .zshrc backed up."
    fi

    cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
# ── Jason's zshrc ────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster-timestamp-newline"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"

# pixi
export PATH="$HOME/.pixi/bin:$PATH"

# aliases
alias ll="ls -lahF"
alias la="ls -A"
alias ..="cd .."
alias ...="cd ../.."

# editor
export EDITOR="${EDITOR:-nano}"

# history
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"
setopt HIST_IGNORE_DUPS SHARE_HISTORY

export PATH="$HOME/.local/bin:$PATH"
ZSHRC_EOF
    ok "~/.zshrc written."

# ══════════════════════════════════════════════════
#  BASH PATH
# ══════════════════════════════════════════════════
else

    # ── 2a. oh-my-bash ────────────────────────────
    if [[ -d "$HOME/.oh-my-bash" ]]; then
        ok "oh-my-bash already installed."
    else
        info "Installing oh-my-bash..."
        bash -c "$($DOWNLOAD https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended
        ok "oh-my-bash installed."
    fi

    # ── 2b. agnoster theme ────────────────────────
    # oh-my-bash has a built-in agnoster theme,
    # same look as the zsh version. Requires powerline font.
    ok "oh-my-bash 'agnoster' theme will be used."

    # ── 2c. .bashrc ───────────────────────────────
    if [[ -f "$HOME/.bashrc" ]] && ! grep -q "# Jason's" "$HOME/.bashrc" 2>/dev/null; then
        cp "$HOME/.bashrc" "$HOME/.bashrc.backup.$(date +%s)"
        info "Existing .bashrc backed up."
    fi

    cat > "$HOME/.bashrc" << 'BASHRC_EOF'
# ── Jason's bashrc ───────────────────────────────
export OSH="$HOME/.oh-my-bash"
OSH_THEME="agnoster"
source "$OSH/oh-my-bash.sh"

# pixi
export PATH="$HOME/.pixi/bin:$PATH"

# aliases
alias ll="ls -lahF"
alias la="ls -A"
alias ..="cd .."
alias ...="cd ../.."

# editor
export EDITOR="${EDITOR:-nano}"

# history
HISTSIZE=10000
HISTFILESIZE=10000
HISTCONTROL=ignoredups

export PATH="$HOME/.local/bin:$PATH"
BASHRC_EOF
    ok "~/.bashrc written."
fi

# ── 3. Git config ─────────────────────────────────
GIT_NAME="Ho Cheuk Hai Jason"
GIT_EMAIL="50993239+jasonho1308@users.noreply.github.com"

if ! command -v git &>/dev/null; then
    warn "git not found — install Xcode CLT (xcode-select --install) or 'sudo apt install git', then re-run for git config."
elif [[ -f "$HOME/.gitconfig" ]]; then
    ok "~/.gitconfig already exists, skipping."
else
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    ok "Git user configured: $GIT_NAME <$GIT_EMAIL>"
fi

# ── 4. Done ───────────────────────────────────────
echo
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo
echo "  Shell:      ${SHELL_TYPE}"
echo "  Config:     ~/.${SHELL_TYPE}rc"
echo "  pixi:       $HOME/.pixi/bin/pixi"
if [[ "$SHELL_TYPE" == "zsh" ]]; then
    echo "  Theme:      agnoster-timestamp-newline"
else
    echo "  Theme:      agnoster"
fi
echo
echo "  ⚠ Agnoster needs a Powerline-patched font:"
echo "     https://github.com/powerline/fonts"
echo
echo "  To see changes now:"
if [[ "$SHELL_TYPE" == "zsh" ]]; then
    echo "    source ~/.zshrc   # or just run: zsh"
else
    echo "    source ~/.bashrc  # or: exec bash"
fi
echo
