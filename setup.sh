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
    info "zsh detected — will set up oh-my-zsh + zsh2000 theme"
elif [[ "${BASH_VERSION:-}" ]]; then
    SHELL_TYPE="bash"
    CURRENT_SHELL="bash"
    info "zsh not found, running bash — will set up oh-my-bash + powerline theme"
else
    err "Neither zsh nor bash found. Something is wrong."
fi

# ── 0.5 Confirm ────────────────────────────────────
echo
echo " This will:"
if [[ "$SHELL_TYPE" == "zsh" ]]; then
    echo "   • Install oh-my-zsh"
    echo "   • Install zsh2000 theme"
else
    echo "   • Install oh-my-bash"
    echo "   • Set a powerline/bash2000 theme"
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

    # ── 2b. zsh2000 theme ──────────────────────────
    THEME_DIR="$HOME/.oh-my-zsh/custom/themes"
    mkdir -p "$THEME_DIR"
    cat > "$THEME_DIR/zsh2000.zsh-theme" << 'THEME_EOF'
CURRENT_BG='NONE'
SEGMENT_SEPARATOR_RIGHT='\ue0b2'
SEGMENT_SEPARATOR_LEFT='\ue0b0'

ZSH_THEME_GIT_PROMPT_UNTRACKED=" ✭"
ZSH_THEME_GIT_PROMPT_STASHED=' ⚑'
ZSH_THEME_GIT_PROMPT_DIVERGED=' ⚡'
ZSH_THEME_GIT_PROMPT_ADDED=" ✚"
ZSH_THEME_GIT_PROMPT_MODIFIED=" ✹"
ZSH_THEME_GIT_PROMPT_DELETED=" ✖"
ZSH_THEME_GIT_PROMPT_RENAMED=" ➜"
ZSH_THEME_GIT_PROMPT_UNMERGED=" ═"
ZSH_THEME_GIT_PROMPT_AHEAD=' ⬆'
ZSH_THEME_GIT_PROMPT_BEHIND=' ⬇'
ZSH_THEME_GIT_PROMPT_DIRTY=' ±'

prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR_LEFT%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

prompt_segment_right() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  echo -n "%K{$CURRENT_BG}%F{$1}$SEGMENT_SEPARATOR_RIGHT%{$bg%}%{$fg%} "
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR_LEFT"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

prompt_user_hostname() {
  local user=`whoami`
  if [ -n "$SSH_CLIENT" ]; then
    prompt_segment black default "%(!.%{%F{yellow}%}.)$user@%m"
  fi
}

prompt_git() {
  local ref dirty
  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null)
    if [[ -n $dirty ]]; then
      prompt_segment magenta black
    else
      prompt_segment green black
    fi
    if [ "$ZSH_2000_DISABLE_GIT_STATUS" != "true" ];then
      echo -n "\ue0a0 ${ref/refs\/heads\//}$dirty"$(git_prompt_status)
    else
      echo -n "\ue0a0 ${ref/refs\/heads\//}$dirty"
    fi
  fi
}

prompt_dir() {
  prompt_segment blue white '%~'
}

prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{yellow}%}✖"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"
  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

prompt_time() {
  prompt_segment_right white black '%D{%H:%M:%S} '
}

build_prompt() {
  if [ "$ZSH_2000_DISABLE_STATUS" != 'true' ];then
    RETVAL=$?
    prompt_status
  fi
  prompt_user_hostname
  prompt_dir
  prompt_git
  prompt_end
}

ZSH_THEME_GIT_TIME_SINCE_COMMIT_SHORT="%{$fg[green]%}"
ZSH_THEME_GIT_TIME_SHORT_COMMIT_MEDIUM="%{$fg[yellow]%}"
ZSH_THEME_GIT_TIME_SINCE_COMMIT_LONG="%{$fg[red]%}"
ZSH_THEME_GIT_TIME_SINCE_COMMIT_NEUTRAL="%{$fg[cyan]%}"

function git_time_since_commit() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        if [[ $(git log 2>&1 > /dev/null | grep -c "^fatal: bad default revision") == 0 ]]; then
            last_commit=`git log --pretty=format:'%at' -1 2> /dev/null`
            now=`date +%s`
            seconds_since_last_commit=$((now-last_commit))
            MINUTES=$((seconds_since_last_commit / 60))
            HOURS=$((seconds_since_last_commit/3600))
            DAYS=$((seconds_since_last_commit / 86400))
            SUB_HOURS=$((HOURS % 24))
            SUB_MINUTES=$((MINUTES % 60))
            if [[ -n $(git status -s 2> /dev/null) ]]; then
                if [ "$MINUTES" -gt 30 ]; then
                    COLOR="$ZSH_THEME_GIT_TIME_SINCE_COMMIT_LONG"
                elif [ "$MINUTES" -gt 10 ]; then
                    COLOR="$ZSH_THEME_GIT_TIME_SHORT_COMMIT_MEDIUM"
                else
                    COLOR="$ZSH_THEME_GIT_TIME_SINCE_COMMIT_SHORT"
                fi
            else
                COLOR="$ZSH_THEME_GIT_TIME_SINCE_COMMIT_NEUTRAL"
            fi
            if [ "$HOURS" -gt 24 ]; then
                echo "($COLOR${DAYS}d${SUB_HOURS}h${SUB_MINUTES}m%{$reset_color%})"
            elif [ "$MINUTES" -gt 60 ]; then
                echo "($COLOR${HOURS}h${SUB_MINUTES}m%{$reset_color%})"
            else
                echo "($COLOR${MINUTES}m%{$reset_color%})"
            fi
        fi
    fi
}

build_rprompt() {
  prompt_time
}

PROMPT='%{%f%b%k%}$(build_prompt) '
RPROMPT='%{%f%b%k%}$(git_time_since_commit)$(build_rprompt)'
THEME_EOF
    ok "zsh2000 theme installed."

    # ── 2c. .zshrc ─────────────────────────────────
    # Back up if not ours
    if [[ -f "$HOME/.zshrc" ]] && ! grep -q "# Jason's" "$HOME/.zshrc" 2>/dev/null; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%s)"
        info "Existing .zshrc backed up."
    fi

    cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
# ── Jason's zshrc ────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="zsh2000"
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

    # ── 2b. bash2000 theme ────────────────────────
    # oh-my-bash uses a different theme engine, but
    # "powerline" theme is the closest built-in.
    # We configure it in .bashrc.
    ok "oh-my-bash 'powerline' theme will be used (closest to zsh2000)."

    # ── 2c. .bashrc ───────────────────────────────
    if [[ -f "$HOME/.bashrc" ]] && ! grep -q "# Jason's" "$HOME/.bashrc" 2>/dev/null; then
        cp "$HOME/.bashrc" "$HOME/.bashrc.backup.$(date +%s)"
        info "Existing .bashrc backed up."
    fi

    cat > "$HOME/.bashrc" << 'BASHRC_EOF'
# ── Jason's bashrc ───────────────────────────────
export OSH="$HOME/.oh-my-bash"
OSH_THEME="powerline"
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

# ── 3. Done ───────────────────────────────────────
echo
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo
echo "  Shell:      ${SHELL_TYPE}"
echo "  Config:     ~/.${SHELL_TYPE}rc"
echo "  pixi:       $HOME/.pixi/bin/pixi"
echo
echo "  To see changes now:"
if [[ "$SHELL_TYPE" == "zsh" ]]; then
    echo "    source ~/.zshrc   # or just run: zsh"
else
    echo "    source ~/.bashrc  # or: exec bash"
fi
echo
