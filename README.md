# Sysadmin Aliases
These are a collection of aliases used frequently by TJ CSL Sysadmins.

## Installation
You must have the following installed:

- `gpg`
- `sshpass`
- [`fzf`](https://github.com/junegunn/fzf)
- [`fd`](https://github.com/sharkdp/fd)

Additionally, the following environment variables must be set:
- `KEYBASE_PASSCARD_DIR` must be set to the location of the git clone of `keybase-passcard`.
- `CSL_ANSIBLE_DIR` must be set to the location of the git clone of `ansible`

To use some aliases, you may also need to have a bash function called `copy`
to copy something to clipboard from stdin for your system (e.g. `wl-copy`
for Wayland, `xclip -sel clip` for xorg, etc).

After that, simply clone this repository and source `main.sh`
