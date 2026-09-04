# acc-setup

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jasonho1308/acc-setup/main/setup.sh)
```

The script installs [`lsd`](https://github.com/lsd-rs/lsd) through pixi and
configures `ls` and `ll` (plus `la`) to use its automatic colour output.

The generated Zsh and Bash configurations both use the custom
`agnoster-timestamp-newline` theme. They share the same colored environment,
`user@machine`, timestamp, directory, and Git segments, plus Powerline
separators and a two-line layout. The user and machine segment is always shown
for both local and remote sessions. Active Python venv, Conda, and pixi
environments appear in a dedicated magenta segment. The white timing segment
shows the current time and adds a compact `took 7s` duration after commands
lasting at least one second.

Existing `~/.bashrc` and `~/.zshrc` files are preserved. The setup adds or
updates only its clearly marked managed block, leaves all other content
untouched, and creates a timestamped backup whenever that block changes.
Re-running an up-to-date setup does not rewrite the file or create another
backup.

On Linux, the setup asks whether to download the latest `Hack.zip` from the
official Nerd Fonts release and install its TTF files under
`~/.local/share/fonts/Hack`. Declining skips the font cleanly; installation
problems produce a warning but do not stop the rest of the setup.

The setup script can optionally configure the WakaTime client to submit
activity to a self-hosted Wakapi instance only. It prompts for the Wakapi API
URL and API key without displaying the key, then writes them only to
`~/.wakatime.cfg` with mode `600`; no URLs or keys are stored in this repository.
