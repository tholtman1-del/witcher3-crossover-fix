#!/bin/zsh
# Removes the Witcher 3 5.00b CrossOver fix and restores the original files.
# Usage: double-click, or run: ./uninstall.command ["/path/to/The Witcher 3"]
set -e
bottles="$HOME/Library/Application Support/CrossOver/Bottles"
dirs=()
if [ -n "$1" ]; then
  p="${1%/}"; [ -f "$p" ] && p="${p:h}"
  for c in "$p" "$p/x64_dx12" "$p/bin/x64_dx12"; do
    [ -f "$c/amd_fidelityfx_loader_dx12_orig.dll" ] && dirs+=("${c:A}")
  done
else
  # Bottles: don't follow links (dosdevices/z: points at the whole disk). External drives: limited depth.
  for f in "${(@f)$(find "$bottles" -path "*/bin/x64_dx12/amd_fidelityfx_loader_dx12_orig.dll" 2>/dev/null)}"; do
    [ -n "$f" ] && dirs+=("${f:h:A}")
  done
  for vol in /Volumes/*(N/); do
    [ "${vol:A}" = "/" ] && continue
    for f in "${(@f)$(find "$vol" -maxdepth 9 -path "*/bin/x64_dx12/amd_fidelityfx_loader_dx12_orig.dll" 2>/dev/null)}"; do
      [ -n "$f" ] && dirs+=("${f:h:A}")
    done
  done
fi
dirs=(${(u)dirs:#})
if [ ${#dirs} -eq 0 ]; then
  echo "No patched Witcher 3 install found automatically."
  echo "Drag your Witcher 3 folder into this window and press Enter (or just Enter to quit):"
  read -r answer
  [ -z "$answer" ] && exit 0
  exec "$0" "${${answer//\\ / }//\"/}"
fi

for d in "${dirs[@]}"; do
  echo "Restoring: $d"
  mv -f "$d/amd_fidelityfx_loader_dx12_orig.dll" "$d/amd_fidelityfx_loader_dx12.dll"
  if [ -f "$d/witcher3.exe.backup" ]; then
    mv -f "$d/witcher3.exe.backup" "$d/witcher3.exe"
    echo "  restored original witcher3.exe"
  fi
  bin="${d:h}"
  if [ -L "$bin/x64" ]; then rm "$bin/x64"
  elif [ -f "$bin/x64/.ffxproxy-copy" ]; then rm -rf "$bin/x64"
  fi
  echo "  done"
done
