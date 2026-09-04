# acc-setup

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jasonho1308/acc-setup/main/setup.sh)
```

The script installs [`lsd`](https://github.com/lsd-rs/lsd) through pixi and
configures `ls` and `ll` (plus `la`) to use its automatic colour output.

The generated Zsh and Bash configurations both use the custom
`agnoster-timestamp-newline` theme. They share the Mac Agnoster segment order,
colors, Powerline separators, and two-line layout. The white timing segment
shows the current time and adds a compact `took 7s` duration after commands
lasting at least one second.

On Linux, the setup asks whether to download the latest `Hack.zip` from the
official Nerd Fonts release and install its TTF files under
`~/.local/share/fonts/Hack`. Declining skips the font cleanly; installation
problems produce a warning but do not stop the rest of the setup.

The setup script can optionally configure the WakaTime client to submit
activity to a self-hosted Wakapi instance only. It prompts for the Wakapi API
URL and API key without displaying the key, then writes them only to
`~/.wakatime.cfg` with mode `600`; no URLs or keys are stored in this repository.
