#!/usr/bin/env bash
# install.sh — copy the tools to ~/.local/bin and the lnav format to ~/.config/lnav.
# Re-run after `git pull` to update. Your project configs in ~/.config/smb-logs/ are never touched.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

bin="$HOME/.local/bin"
fmt="$HOME/.config/lnav/formats/installed"
conf="$HOME/.config/smb-logs"
mkdir -p "$bin" "$fmt" "$conf"
chmod 700 "$conf"

install -m 755 "$here/bin/smb-logs" "$here/bin/logview" "$here/bin/logview-filter" "$bin/"
install -m 644 "$here/lnav/pino_json.json" "$fmt/"
echo "Installed: $bin/{smb-logs,logview,logview-filter}, $fmt/pino_json.json"

missing=()
for cmd in smbclient lnav python3 timeout; do command -v "$cmd" >/dev/null || missing+=("$cmd"); done
if ((${#missing[@]})); then
  echo "Missing: ${missing[*]}  (Ubuntu/Debian: sudo apt install smbclient lnav python3)"
fi
case ":$PATH:" in *":$bin:"*) ;; *) echo "Note: $bin is not on your PATH." ;; esac
ls "$conf"/*.conf >/dev/null 2>&1 || echo "Next: cp $here/config/example.conf $conf/<project>.conf and fill it in."
