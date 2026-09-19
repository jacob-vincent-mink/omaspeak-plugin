# Omaspeak

A compact Omarchy bar widget for the [Omaspeak](https://github.com/jacob-vincent-mink/omaspeak)
local text-to-speech daemon: see whether speech is ready, speak a phrase, and
choose the model voice without leaving the bar.

The icon reports the daemon state from `omaspeak status --json` together with
the load state of the `omaspeak` user service, and both are re-checked on a
background timer. Stopping the service or removing `omaspeak-bin` therefore
changes the bar icon on its own, without the panel being opened. The voice list
comes from the installed model and marks the voice the daemon reports as
active, while a configuration without a pinned voice reads `Default`.

## Requirements

- Omarchy Quattro with shell plugin support
- The `omaspeak-bin` package on `PATH`, because the widget drives the `omaspeak` command line
- A systemd user session, because the daemon runs as the `omaspeak` user service

## Install

```bash
sudo pacman -S omaspeak-bin   # the app the widget drives
omaspeak setup                # choose a model and runtime, once
omarchy plugin add https://github.com/jacob-vincent-mink/omaspeak-plugin.git --enable
omarchy bar move jacob.omaspeak --section right --index 0
```

Click the icon to open the panel. Press **Set up the service** once, so the
**Start** and **Stop** buttons have a service to control: it opens a terminal
running `omaspeak setup systemd`, which installs and enables the user service.
When the binary is missing the panel reports **Not installed** and prints the
install command instead of failing.

## Remove

```bash
omarchy plugin disable jacob.omaspeak
omarchy plugin remove jacob.omaspeak
```

Removing the widget changes nothing else. It keeps no files of its own, and the
only setting it changes is `model.voice` in your Omaspeak configuration, which it
does through `omaspeak config`; **Clear** returns the model to its default voice.

To drop the app as well, run `sudo pacman -R omaspeak-bin`. Its package removal
hook stops and cleans up the `omaspeak` user service, and it always keeps
`~/.config/omaspeak/config.toml` and the models under `~/.local/share/omaspeak`,
which you can delete yourself when you want the space back.

## What the widget runs

Every command runs as your own user and none of them needs root. The panel only
prints the package install command; it never runs it.

| Command | Used for |
| --- | --- |
| `sh -c "command -v omaspeak"` | installed or not |
| `omaspeak status --json` | daemon, model, and backend state |
| `omaspeak voices --json` | voices the installed model offers |
| `omaspeak say <text>` | speaking the typed phrase |
| `omaspeak config get/set/unset model.voice` | the voice choice |
| `systemctl --user show omaspeak --property=LoadState --value` | whether the service is present |
| `systemctl --user start omaspeak`, `systemctl --user stop omaspeak` | the **Start** and **Stop** buttons |
| `omarchy launch terminal omaspeak setup` | the first-time setup button |
| `omarchy launch terminal omaspeak setup systemd` | the service setup button |

## External dependencies

Quickshell and QML from the Omarchy shell, the `omaspeak` command line from
`omaspeak-bin`, and `systemctl` for the user service. The widget downloads
nothing and opens no network connection. `omaspeak-bin` is the packaged release
of Omaspeak, whose own `licenses/` directory and `THIRD_PARTY_NOTICES.md`
describe the components it bundles; model downloads belong to Omaspeak itself
and are not fetched by this widget.

## Checks

```bash
node --test tests/*.test.cjs
```

The runner is given a file glob rather than the directory, because current Node
reports the directory itself as a single failing test.

Covers the status and voice parsing, the running and service-present states,
the active voice, and the backend display. Node is needed only for these
development checks, not for the widget.

## License

MIT, see [LICENSE](LICENSE).
