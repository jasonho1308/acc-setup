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

RUN_ALL=false
confirm_action() {
    local prompt=$1 reply=''

    [[ "$RUN_ALL" == true ]] && return 0
    read -rp "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

update_managed_shell_block() {
    local config_file=$1
    local shell_name=$2
    local start_marker="# >>> Jason's terminal setup (${shell_name}) >>>"
    local end_marker="# <<< Jason's terminal setup (${shell_name}) <<<"
    local block_file output_file backup_file input_file=/dev/null
    local start_count=0 end_count=0 start_line=0 end_line=0

    block_file=$(mktemp)
    output_file=$(mktemp)
    {
        printf '%s\n' "$start_marker"
        cat
        printf '%s\n' "$end_marker"
    } > "$block_file"

    if [[ -f "$config_file" ]]; then
        input_file=$config_file
        start_count=$(grep -Fxc "$start_marker" "$config_file" || true)
        end_count=$(grep -Fxc "$end_marker" "$config_file" || true)
        if [[ "$start_count" -eq 1 && "$end_count" -eq 1 ]]; then
            start_line=$(grep -Fn "$start_marker" "$config_file" | cut -d: -f1)
            end_line=$(grep -Fn "$end_marker" "$config_file" | cut -d: -f1)
        fi
    fi

    if [[ "$start_count" -ne "$end_count" || "$start_count" -gt 1 ||
          ( "$start_count" -eq 1 && "$start_line" -ge "$end_line" ) ]]; then
        rm -f -- "$block_file" "$output_file"
        err "Malformed Jason setup markers in $config_file; leaving it unchanged."
    fi

    awk -v start="$start_marker" -v end="$end_marker" -v block="$block_file" '
        function print_block(  line) {
            while ((getline line < block) > 0) print line
            close(block)
        }
        $0 == start {
            if (!inserted) {
                print_block()
                inserted = 1
            }
            managed = 1
            next
        }
        managed && $0 == end {
            managed = 0
            next
        }
        !managed { print }
        END {
            if (!inserted) {
                if (NR > 0) print ""
                print_block()
            }
        }
    ' "$input_file" > "$output_file"

    if [[ -f "$config_file" ]] && cmp -s "$config_file" "$output_file"; then
        rm -f -- "$block_file" "$output_file"
        ok "$config_file already contains the current setup block."
        return
    fi

    if [[ -f "$config_file" ]]; then
        backup_file=$(mktemp "${config_file}.backup.$(date +%s).XXXXXX")
        cp -p -- "$config_file" "$backup_file"
        info "Existing $config_file backed up to $backup_file."
    else
        mkdir -p -- "$(dirname "$config_file")"
    fi

    cat "$output_file" > "$config_file"
    rm -f -- "$block_file" "$output_file"
    ok "$config_file updated without changing content outside the managed block."
}

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
    info "zsh not found, running bash — will set up oh-my-bash + agnoster-timestamp-newline theme"
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
    echo "   • Install agnoster-timestamp-newline theme"
fi
echo "   • Install pixi"
echo "   • Install lsd and use it for colourised ls/ll output"
echo "   • Prevent Pixi and Conda from adding duplicate prompt prefixes"
echo "   • Offer to install the latest Hack Nerd Font (Linux)"
echo "   • Merge managed settings into ~/.${SHELL_TYPE}rc (existing content is preserved)"
echo "   • NO sudo, NO packages, NO chsh"
echo "============================================"
echo
echo " Choose how to proceed:"
echo "   A • Run all actions without further yes/no prompts"
echo "   Y • Ask for confirmation before each action"
echo "   N • Abort"
read -rp "Choice [A/y/N] " REPLY
case "$REPLY" in
    [Aa]) RUN_ALL=true ;;
    [Yy]) ;;
    *) info "Aborted."; exit 0 ;;
esac

# ── 1. pixi (shell-agnostic, works on any Linux) ──
PIXI_AVAILABLE=false
if command -v pixi &>/dev/null; then
    PIXI_AVAILABLE=true
    ok "pixi already installed ($(pixi --version 2>/dev/null || echo '?'))"
elif confirm_action "Install pixi?"; then
    info "Installing pixi..."
    if $DOWNLOAD https://pixi.sh/install.sh | bash; then
        ok "Pixi installer completed."
    else
        warn "Could not install pixi — continuing without it."
    fi
else
    info "Skipping pixi installation."
fi

# Ensure a newly installed pixi is available right now.
export PATH="$HOME/.pixi/bin:$PATH"
command -v pixi &>/dev/null && PIXI_AVAILABLE=true

# ── 1.25. lsd ─────────────────────────────────────
LSD_AVAILABLE=false
if command -v lsd &>/dev/null; then
    LSD_AVAILABLE=true
    ok "lsd already installed ($(lsd --version 2>/dev/null || echo '?'))"
elif [[ "$PIXI_AVAILABLE" != true ]]; then
    info "Skipping lsd because pixi is unavailable."
elif confirm_action "Install lsd with pixi?"; then
    info "Installing lsd with pixi..."
    if pixi global install lsd-rust && command -v lsd &>/dev/null; then
        LSD_AVAILABLE=true
        ok "lsd installed."
    else
        warn "Could not install lsd — continuing with the system ls command."
    fi
else
    info "Skipping lsd installation; system ls will be used."
fi

# ── 1.5. Environment-manager prompt prefixes ──────
# The custom theme renders environments in its own colored segment, so prevent
# Pixi and Conda from also prepending plain-text environment names to PS1.
if [[ "$PIXI_AVAILABLE" != true ]]; then
    info "Pixi not found — skipping its prompt-prefix setting."
elif confirm_action "Disable Pixi's duplicate prompt prefix?"; then
    if pixi config list 2>/dev/null | grep -A1 '^\[shell\]$' | grep -qx 'change-ps1 = false'; then
        ok "Pixi's duplicate prompt prefix is already disabled."
    elif pixi config set --global shell.change-ps1 false >/dev/null; then
        ok "Pixi's duplicate prompt prefix disabled."
    else
        warn "Could not disable Pixi's built-in prompt prefix."
    fi
else
    info "Leaving Pixi's prompt-prefix setting unchanged."
fi

if ! command -v conda &>/dev/null; then
    info "Conda not found — skipping its prompt-prefix setting."
elif confirm_action "Disable Conda's duplicate prompt prefix?"; then
    if [[ "$(conda config --show changeps1 2>/dev/null || true)" == "changeps1: False" ]]; then
        ok "Conda's duplicate prompt prefix is already disabled."
    elif conda config --set changeps1 false >/dev/null; then
        ok "Conda's duplicate prompt prefix disabled."
    else
        warn "Could not disable Conda's built-in prompt prefix."
    fi
else
    info "Leaving Conda's prompt-prefix setting unchanged."
fi

# ── 1.75. Hack Nerd Font (optional on Linux) ──────
NERD_FONT_INSTALLED=false
if [[ "$(uname -s)" == "Linux" ]]; then
    echo
    if confirm_action "Install the latest Hack Nerd Font?"; then
        NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip"
        NERD_FONT_DIR="$HOME/.local/share/fonts/Hack"
        NERD_FONT_TMP_DIR="$(mktemp -d 2>/dev/null || true)"

        if [[ -z "$NERD_FONT_TMP_DIR" ]]; then
            warn "Could not create a temporary directory — skipping Hack Nerd Font installation."
        elif ! command -v unzip &>/dev/null && ! command -v bsdtar &>/dev/null; then
            warn "Need unzip or bsdtar to install Hack Nerd Font — skipping it."
            rm -rf -- "$NERD_FONT_TMP_DIR"
        else
            NERD_FONT_ARCHIVE="$NERD_FONT_TMP_DIR/Hack.zip"
            info "Installing the latest Hack Nerd Font..."

            if ! $DOWNLOAD "$NERD_FONT_URL" > "$NERD_FONT_ARCHIVE"; then
                warn "Hack Nerd Font download failed — continuing without changing installed fonts."
            elif ! mkdir -p "$NERD_FONT_DIR"; then
                warn "Could not create $NERD_FONT_DIR — continuing without changing installed fonts."
            elif command -v unzip &>/dev/null; then
                if unzip -q -o "$NERD_FONT_ARCHIVE" '*.ttf' -d "$NERD_FONT_DIR"; then
                    NERD_FONT_INSTALLED=true
                    ok "Latest Hack Nerd Font installed in $NERD_FONT_DIR."
                else
                    warn "Hack Nerd Font extraction failed — continuing setup."
                fi
            elif bsdtar -xf "$NERD_FONT_ARCHIVE" -C "$NERD_FONT_DIR"; then
                NERD_FONT_INSTALLED=true
                ok "Latest Hack Nerd Font installed in $NERD_FONT_DIR."
            else
                warn "Hack Nerd Font extraction failed — continuing setup."
            fi

            if [[ "$NERD_FONT_INSTALLED" == true ]]; then
                if command -v fc-cache &>/dev/null; then
                    fc-cache -f "$NERD_FONT_DIR" >/dev/null 2>&1 ||
                        warn "Could not refresh the font cache — continuing setup."
                else
                    warn "fc-cache not found; the font is installed but its cache was not refreshed."
                fi
            fi

            rm -rf -- "$NERD_FONT_TMP_DIR"
        fi

        unset NERD_FONT_URL NERD_FONT_DIR NERD_FONT_TMP_DIR NERD_FONT_ARCHIVE
    else
        info "Skipping Hack Nerd Font installation."
    fi
fi

# ══════════════════════════════════════════════════
#  SHELL CONFIGURATION
# ══════════════════════════════════════════════════
SHELL_CONFIGURED=false
if confirm_action "Configure ${SHELL_TYPE}, its framework, theme, and rc file?"; then

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
typeset -g _JASON_AGNOSTER_START_TIME=''
typeset -g _JASON_AGNOSTER_DURATION=''
typeset -gi _JASON_AGNOSTER_RETVAL=0

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
  local user_name=${USER:-$(id -un)}
  local machine_name=${HOST:-$(hostname)}
  machine_name=${machine_name%%.*}
  prompt_segment black default "%(!.%{%F{yellow}%}.)${user_name}@${machine_name}"
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

prompt_environment() {
  local environment_name=''

  if [[ -n ${PIXI_ENVIRONMENT_NAME:-} ]]; then
    environment_name="pixi:${PIXI_ENVIRONMENT_NAME}"
  elif [[ -n ${CONDA_DEFAULT_ENV:-} ]]; then
    environment_name="conda:${CONDA_DEFAULT_ENV}"
  elif [[ -n ${VIRTUAL_ENV:-} ]]; then
    environment_name="venv:$(basename "$VIRTUAL_ENV")"
  fi

  [[ -n $environment_name ]] && prompt_segment magenta black "$environment_name"
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

_jason_agnoster_format_duration() {
  local -i total_seconds=$1
  local -i hours=$(( total_seconds / 3600 ))
  local -i minutes=$(( (total_seconds % 3600) / 60 ))
  local -i seconds=$(( total_seconds % 60 ))

  REPLY=''
  (( hours > 0 )) && REPLY+="${hours}h"
  (( minutes > 0 )) && REPLY+="${REPLY:+ }${minutes}m"
  (( seconds > 0 || total_seconds < 60 )) && REPLY+="${REPLY:+ }${seconds}s"
}

_jason_agnoster_preexec() {
  _JASON_AGNOSTER_START_TIME=$EPOCHREALTIME
}

_jason_agnoster_precmd() {
  local retval=$?
  local -F elapsed
  local -i elapsed_seconds

  _JASON_AGNOSTER_RETVAL=$retval
  _JASON_AGNOSTER_DURATION=''
  if [[ -n $_JASON_AGNOSTER_START_TIME ]]; then
    elapsed=$(( EPOCHREALTIME - _JASON_AGNOSTER_START_TIME ))
    if (( elapsed >= 1.0 )); then
      elapsed_seconds=${elapsed%.*}
      _jason_agnoster_format_duration $elapsed_seconds
      _JASON_AGNOSTER_DURATION=$REPLY
    fi
  fi
  _JASON_AGNOSTER_START_TIME=''
}

prompt_timestamp() {
  local timestamp
  timestamp=$(date +%H:%M:%S)
  [[ -n $_JASON_AGNOSTER_DURATION ]] && timestamp+=" · $_JASON_AGNOSTER_DURATION"
  prompt_segment white black "$timestamp"
}

build_prompt() {
  RETVAL=$_JASON_AGNOSTER_RETVAL
  prompt_status
  prompt_environment
  prompt_context
  prompt_timestamp
  prompt_dir
  prompt_git
  prompt_hg
  prompt_newline
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt)'

zmodload zsh/datetime
autoload -Uz add-zsh-hook
add-zsh-hook -d preexec _jason_agnoster_preexec 2>/dev/null
add-zsh-hook -d precmd _jason_agnoster_precmd 2>/dev/null
add-zsh-hook preexec _jason_agnoster_preexec
add-zsh-hook precmd _jason_agnoster_precmd
THEME_EOF
    ok "agnoster-timestamp-newline theme installed."

    # ── 2c. .zshrc ─────────────────────────────────
    update_managed_shell_block "$HOME/.zshrc" zsh << 'ZSHRC_EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster-timestamp-newline"
typeset -ga plugins
(( ${plugins[(Ie)git]} )) || plugins+=(git)

if (( $+functions[_omz_source] )); then
    (( $+functions[parse_git_dirty] )) || _omz_source "plugins/git/git.plugin.zsh"
    source "$ZSH/custom/themes/agnoster-timestamp-newline.zsh-theme"
else
    source "$ZSH/oh-my-zsh.sh"
fi

# pixi and environment prompt handling
export PATH="$HOME/.pixi/bin:$PATH"
export VIRTUAL_ENV_DISABLE_PROMPT=1
export CONDA_CHANGEPS1=false

# aliases
if command -v lsd >/dev/null 2>&1; then
    alias ls="lsd --color=auto"
    alias ll="lsd -lahF --color=auto"
    alias la="lsd -A --color=auto"
else
    alias ll="ls -lahF --color=auto"
    alias la="ls -A --color=auto"
fi
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

    # ── 2b. agnoster-timestamp-newline theme ──────
    BASH_THEME_DIR="$HOME/.oh-my-bash/custom/themes/agnoster-timestamp-newline"
    mkdir -p "$BASH_THEME_DIR"
    cat > "$BASH_THEME_DIR/agnoster-timestamp-newline.theme.sh" << 'BASH_THEME_EOF'
#! bash oh-my-bash.module

# Start with Oh My Bash's Agnoster drawing and VCS implementation, then
# override only the components needed to match the Mac Zsh prompt.
source "$OSH/themes/agnoster/agnoster.theme.sh"

if [[ ! ${bash_preexec_imported:-${__bp_imported:-}} ]]; then
  source "$OSH/tools/bash-preexec.sh"
fi

_JASON_AGNOSTER_START_NS=''
_JASON_AGNOSTER_DURATION=''
_JASON_AGNOSTER_RETVAL=0

function _jason_agnoster_now_ns {
  local now seconds
  now=$(date +%s%N 2>/dev/null)
  if [[ $now =~ ^[0-9]+$ && ${#now} -gt 10 ]]; then
    _JASON_AGNOSTER_NOW_NS=$now
  else
    seconds=$(date +%s)
    _JASON_AGNOSTER_NOW_NS=$((seconds * 1000000000))
  fi
}

function _jason_agnoster_format_duration {
  local total_seconds=$1
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))

  _JASON_AGNOSTER_DURATION=''
  ((hours > 0)) && _JASON_AGNOSTER_DURATION="${hours}h"
  ((minutes > 0)) && _JASON_AGNOSTER_DURATION+="${_JASON_AGNOSTER_DURATION:+ }${minutes}m"
  ((seconds > 0 || total_seconds < 60)) && _JASON_AGNOSTER_DURATION+="${_JASON_AGNOSTER_DURATION:+ }${seconds}s"
}

function _jason_agnoster_preexec {
  _jason_agnoster_now_ns
  _JASON_AGNOSTER_START_NS=$_JASON_AGNOSTER_NOW_NS
}

function _jason_agnoster_precmd {
  local retval=$?
  local elapsed_ns elapsed_seconds

  _JASON_AGNOSTER_RETVAL=$retval
  _JASON_AGNOSTER_DURATION=''
  if [[ -n $_JASON_AGNOSTER_START_NS ]]; then
    _jason_agnoster_now_ns
    elapsed_ns=$((_JASON_AGNOSTER_NOW_NS - _JASON_AGNOSTER_START_NS))
    if ((elapsed_ns >= 1000000000)); then
      elapsed_seconds=$((elapsed_ns / 1000000000))
      _jason_agnoster_format_duration "$elapsed_seconds"
    fi
  fi
  _JASON_AGNOSTER_START_NS=''
  return 0
}

function _jason_agnoster_has_hook {
  local needle=$1 hook
  shift
  for hook in "$@"; do
    [[ $hook == "$needle" ]] && return 0
  done
  return 1
}

_jason_agnoster_has_hook _jason_agnoster_preexec "${preexec_functions[@]}" ||
  preexec_functions+=(_jason_agnoster_preexec)
_jason_agnoster_has_hook _jason_agnoster_precmd "${precmd_functions[@]}" ||
  precmd_functions+=(_jason_agnoster_precmd)

function prompt_environment {
  local environment_name=''

  if [[ -n ${PIXI_ENVIRONMENT_NAME:-} ]]; then
    environment_name="pixi:${PIXI_ENVIRONMENT_NAME}"
  elif [[ -n ${CONDA_DEFAULT_ENV:-} ]]; then
    environment_name="conda:${CONDA_DEFAULT_ENV}"
  elif [[ -n ${VIRTUAL_ENV:-} ]]; then
    environment_name="venv:$(basename "$VIRTUAL_ENV")"
  fi

  [[ -n $environment_name ]] && prompt_segment magenta black "$environment_name"
}

function prompt_context {
  local user_name=${USER:-$(id -un)}
  local machine_name=${HOSTNAME:-$(hostname)}
  machine_name=${machine_name%%.*}
  prompt_segment black default "${user_name}@${machine_name}"
}

function prompt_timestamp {
  local timestamp
  timestamp=$(date +%H:%M:%S)
  [[ -n $_JASON_AGNOSTER_DURATION ]] && timestamp+=" · $_JASON_AGNOSTER_DURATION"
  prompt_segment white black "$timestamp"
}

function prompt_newline {
  local REPLY
  if [[ -n $CURRENT_BG ]]; then
    local -a codes=(0)
    _omb_theme_agnoster_fg_color "$CURRENT_BG"
    [[ $REPLY ]] && codes+=("$REPLY")
    _omb_theme_agnoster_ansi 'codes[@]'
    PR="$PR $REPLY$SEGMENT_SEPARATOR"$'\n'"$REPLY$SEGMENT_SEPARATOR"
  else
    _omb_theme_agnoster_ansi_single 0
    PR="$PR $REPLY"
  fi

  _omb_theme_agnoster_ansi_single 0
  PR="$PR $REPLY "
  CURRENT_BG=''
}

function build_prompt {
  prompt_status
  prompt_environment
  prompt_context
  prompt_timestamp
  prompt_dir
  prompt_git
  prompt_hg
  prompt_newline
  prompt_end
}

function _omb_theme_PROMPT_COMMAND {
  local RETVAL=${_JASON_AGNOSTER_RETVAL:-$?}
  local PRIGHT=''
  local CURRENT_BG=NONE
  local REPLY
  _omb_theme_agnoster_text_effect reset
  _omb_theme_agnoster_ansi_single "$REPLY"
  local PR=$REPLY
  build_prompt
  PS1=$PR
}
BASH_THEME_EOF
    ok "agnoster-timestamp-newline theme installed."

    # ── 2c. .bashrc ───────────────────────────────
    update_managed_shell_block "$HOME/.bashrc" bash << 'BASHRC_EOF'
export OSH="$HOME/.oh-my-bash"
OSH_THEME="agnoster-timestamp-newline"

if [[ $(declare -p plugins 2>/dev/null) != "declare -a"* ]]; then
    plugins=(${plugins:-})
fi
[[ " ${plugins[*]} " == *" git "* ]] || plugins+=(git)
[[ " ${plugins[*]} " == *" bash-preexec "* ]] || plugins+=(bash-preexec)

if declare -F _omb_module_require_theme >/dev/null; then
    _omb_module_require_plugin git bash-preexec
    _omb_module_require_theme agnoster-timestamp-newline
else
    source "$OSH/oh-my-bash.sh"
fi

# pixi and environment prompt handling
export PATH="$HOME/.pixi/bin:$PATH"
export VIRTUAL_ENV_DISABLE_PROMPT=1
export CONDA_CHANGEPS1=false

# aliases
if command -v lsd >/dev/null 2>&1; then
    alias ls="lsd --color=auto"
    alias ll="lsd -lahF --color=auto"
    alias la="lsd -A --color=auto"
else
    alias ll="ls -lahF --color=auto"
    alias la="ls -A --color=auto"
fi
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
fi
    SHELL_CONFIGURED=true
else
    info "Skipping shell framework, theme, and rc configuration."
fi

# ── 3. Wakapi ─────────────────────────────────────
echo
if confirm_action "Configure Wakapi tracking?"; then
    read -rp "Wakapi API URL (e.g. https://wakapi.example.com/api): " WAKAPI_URL
    read -rsp "Wakapi API key (hidden): " WAKAPI_API_KEY
    echo

    if [[ -z "$WAKAPI_URL" || -z "$WAKAPI_API_KEY" ]]; then
        warn "The Wakapi URL and API key are required — leaving ~/.wakatime.cfg unchanged."
    else
        cat > "$HOME/.wakatime.cfg" << WAKATIME_EOF
[settings]
api_url = $WAKAPI_URL
api_key = $WAKAPI_API_KEY
WAKATIME_EOF
        chmod 600 "$HOME/.wakatime.cfg"
        ok "WakaTime client configured to submit to Wakapi only."
    fi

    unset WAKAPI_URL WAKAPI_API_KEY
else
    info "Skipping Wakapi configuration."
fi

# ── 4. Git config ─────────────────────────────────
GIT_NAME="Ho Cheuk Hai Jason"
GIT_EMAIL="50993239+jasonho1308@users.noreply.github.com"

if ! command -v git &>/dev/null; then
    warn "git not found — install Xcode CLT (xcode-select --install) or 'sudo apt install git', then re-run for git config."
elif [[ -f "$HOME/.gitconfig" ]]; then
    ok "~/.gitconfig already exists, skipping."
elif confirm_action "Configure the global Git name and email?"; then
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    ok "Git user configured: $GIT_NAME <$GIT_EMAIL>"
else
    info "Skipping global Git configuration."
fi

# ── 5. Done ───────────────────────────────────────
echo
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo
echo "  Shell:      ${SHELL_TYPE}"
if [[ "$SHELL_CONFIGURED" == true ]]; then
    echo "  Config:     ~/.${SHELL_TYPE}rc"
    echo "  Theme:      agnoster-timestamp-newline"
else
    echo "  Config:     skipped"
fi
if [[ "$PIXI_AVAILABLE" == true ]]; then
    echo "  pixi:       $(command -v pixi)"
else
    echo "  pixi:       unavailable or skipped"
fi
if [[ "$LSD_AVAILABLE" == true ]]; then
    echo "  ls/ll:      lsd with automatic colour output"
else
    echo "  ls/ll:      system ls"
fi
if [[ "$NERD_FONT_INSTALLED" == true ]]; then
    echo "  Font:       Hack Nerd Font (latest release)"
fi
echo
echo "  ⚠ Agnoster needs a Powerline-patched font:"
echo "     https://github.com/powerline/fonts"
if [[ "$SHELL_CONFIGURED" == true ]]; then
    echo
    echo "  To see changes now:"
    if [[ "$SHELL_TYPE" == "zsh" ]]; then
        echo "    source ~/.zshrc   # or just run: zsh"
    else
        echo "    source ~/.bashrc  # or: exec bash"
    fi
fi
echo
