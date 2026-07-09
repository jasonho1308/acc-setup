# linux-setup

One-command terminal setup for fresh Linux servers and macOS machines. No sudo, no packages — just shell config, prompt theme, pixi, and git identity.

## Quick start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jasonho1308/linux-setup/main/setup.sh)
```

## What it does

| | zsh available | bash only |
|---|---|---|
| Framework | oh-my-zsh | oh-my-bash |
| Theme | agnoster-timestamp-newline | agnoster |
| Package manager | pixi | pixi |
| Git identity | `Ho Cheuk Hai Jason` | same |
| Config file | `~/.zshrc` | `~/.bashrc` |

- Detects whether zsh is available, falls back to bash + oh-my-bash
- Backs up any existing rc file before overwriting
- Skips git config if git isn't installed yet (e.g. fresh macOS before Xcode CLT)
- No `sudo`, no `apt`/`brew`, no `chsh`

## Requirements

- curl or wget
- A [Powerline-patched font](https://github.com/powerline/fonts) for the agnoster prompt to render correctly
