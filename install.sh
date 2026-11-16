#!/bin/sh
# Installs github-diff into the Herdr app and binds a key to open it:
# ctrl-shift-d on Linux and Windows (WSL), cmd-shift-d on macOS.
#
# Run it again to update: it replaces the mod's own files and keeps the ones Herdr writes
# into the folder. It never replaces a key you already use; it tells you instead.
#
# Usage: sh install.sh            (HERDR_APP_HOME picks another Herdr home)
set -eu

here=$(cd "$(dirname "$0")" && pwd)
home=${HERDR_APP_HOME:-$HOME/.config/herdr-app}
dest=$home/mods/github-diff

command -v herdr-app >/dev/null 2>&1 || { echo "herdr-app is not on PATH. Install the Herdr app first: https://herdr.dev" >&2; exit 1; }
[ -d "$home" ] || { echo "No Herdr app home at $home. Open the Herdr app once, then run this again." >&2; exit 1; }
[ -f "$here/mods/github-diff/mod.json" ] || { echo "Run this from a checkout of the repository." >&2; exit 1; }
if [ -L "$dest" ]; then echo "$dest is a symlink; remove it first (Herdr never reloads a linked mod)." >&2; exit 1; fi

mkdir -p "$dest"
# Drop the mod's old files, keep what Herdr writes there itself, then copy the new ones.
find "$dest" -mindepth 1 -maxdepth 1 ! -name jsconfig.json ! -name gpui-kit.d.ts ! -name herdr.d.ts -exec rm -rf {} +
cp -R "$here/mods/github-diff/." "$dest/"
herdr-app check "$dest" || { echo "The installed copy fails to load; see the error above." >&2; exit 1; }
echo "github-diff installed in $dest"

case "$(uname -s)" in Darwin) key=cmd-shift-d ;; *) key=ctrl-shift-d ;; esac
keys=$home/keys.json
if [ ! -f "$keys" ]; then
  echo "No $keys yet. Add this to it, in the \"global\" section: \"$key\": \"mod.open:github-diff\""
  exit 0
fi
command -v python3 >/dev/null 2>&1 || { echo "python3 isn't on PATH. Add to $keys, in \"global\": \"$key\": \"mod.open:github-diff\""; exit 0; }
python3 - "$keys" "$key" <<'PY'
import json, os, sys
path, key = sys.argv[1], sys.argv[2]
action = "mod.open:github-diff"
with open(path) as f:
    keys = json.load(f)
section = keys.setdefault("global", {})
current = section.get(key)
if current == action:
    print(f"{key} already opens github-diff")
elif current is not None:
    print(f"{key} is already used for {current!r}; left as it is. Bind another key to {action!r} in {path}.")
else:
    section[key] = action
    tmp = path + ".github-diff-tmp"
    with open(tmp, "w") as f:
        json.dump(keys, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, path)
    print(f"{key} now opens github-diff")
PY
