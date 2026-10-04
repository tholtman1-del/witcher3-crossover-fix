#!/bin/zsh
# Witcher 3 Remastered 5.00b black-screen fix for CrossOver (D3DMetal).
# Usage: double-click, or run: ./install.command ["/path/to/The Witcher 3"]
# The path may be the game folder, its bin or bin/x64_dx12 folder, or witcher3.exe.
set -e
here=${0:A:h}
dll="$here/amd_fidelityfx_loader_dx12.dll"
[ -f "$dll" ] || { echo "amd_fidelityfx_loader_dx12.dll must sit next to this script."; exit 1; }
bottles="$HOME/Library/Application Support/CrossOver/Bottles"

# Turn whatever the user gave us into the bin/x64_dx12 folder, or print nothing.
resolve_game_dir() {
  local p="$1"
  while [[ "$p" == *" " && "$p" != *"\\ " ]]; do p="${p% }"; done   # Terminal adds a trailing space on drag-and-drop
  p="${p%\"}"; p="${p#\"}"; p="${p%\'}"; p="${p#\'}"      # strip quotes
  p="${p//\\ / }"                                          # un-escape drag-and-drop spaces
  p="${p%/}"
  [ -f "$p" ] && p="${p:h}"
  for c in "$p" "$p/x64_dx12" "$p/bin/x64_dx12"; do
    [ -f "$c/witcher3.exe" ] && [ "${c:t}" = "x64_dx12" ] && { echo "${c:A}"; return; }
  done
  return 0
}

# Convert a Windows path from a bottle (e.g. D:\SteamLibrary) to a macOS path.
win_to_mac() {
  local bottle="$1" win="$2"
  local letter="${win[1]:l}" rest="${win[3,-1]//\\\\//}"
  rest="${rest//\\//}"
  local dev="$bottle/dosdevices/$letter:"
  [ -e "$dev" ] && echo "${dev:A}$rest"
  return 0
}

found=()
add() { local r; r=$(resolve_game_dir "$1"); [ -n "$r" ] && found+=("$r"); return 0; }

if [ -n "$1" ]; then
  add "$1"
  [ ${#found} -gt 0 ] || { echo "No bin/x64_dx12/witcher3.exe found under: $1"; exit 1; }
else
  echo "Searching for The Witcher 3..."
  for b in "$bottles"/*(N/); do
    # 1. Inside the bottle's C: drive
    for exe in "${(@f)$(find "$b/drive_c" -path "*/bin/x64_dx12/witcher3.exe" 2>/dev/null)}"; do add "$exe"; done
    # 2. Extra drive letters mapped by the bottle (skip y: = home and z: = whole disk)
    for dev in "$b"/dosdevices/[a-xA-X]:(N@); do
      [ "${dev:t}" = "c:" ] && continue
      case "${dev:A}" in /|"$HOME"|/Users|/System*) continue ;; esac
      for exe in "${(@f)$(find -L "$dev/" -maxdepth 9 -path "*/bin/x64_dx12/witcher3.exe" 2>/dev/null)}"; do add "$exe"; done
    done
    # 3. Steam library folders listed in Steam's config
    for vdf in "$b"/drive_c/Program\ Files*/Steam/{steamapps,config}/libraryfolders.vdf(N); do
      for lib in "${(@f)$(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"/\1/p' "$vdf")}"; do
        mac=$(win_to_mac "$b" "$lib")
        [ -n "$mac" ] && [ -d "$mac/steamapps/common" ] || continue
        for exe in "$mac"/steamapps/common/*/bin/x64_dx12/witcher3.exe(N); do add "$exe"; done
      done
    done
  done
  # 4. External drives
  for vol in /Volumes/*(N/); do
    [ "${vol:A}" = "/" ] && continue
    for exe in "${(@f)$(find "$vol" -maxdepth 9 -path "*/bin/x64_dx12/witcher3.exe" 2>/dev/null)}"; do add "$exe"; done
  done
fi

found=(${(u)found:#})
if [ ${#found} -eq 0 ]; then
  echo
  echo "Couldn't find the game automatically."
  echo "Drag your Witcher 3 folder (the one containing 'bin' and 'content') into this window and press Enter:"
  read -r answer
  add "$answer"
  [ ${#found} -gt 0 ] || { echo "No bin/x64_dx12/witcher3.exe found there."; exit 1; }
fi

for d in "${found[@]}"; do
  echo
  echo "Patching: $d"
  [ -f "$d/amd_fidelityfx_loader_dx12.dll" ] || { echo "  no amd_fidelityfx_loader_dx12.dll here, skipping (not 5.00b?)"; continue; }
  # Keep the real FidelityFX loader under a new name, unless the proxy is already installed.
  if ! grep -q "ffxproxy" "$d/amd_fidelityfx_loader_dx12.dll"; then
    mv -f "$d/amd_fidelityfx_loader_dx12.dll" "$d/amd_fidelityfx_loader_dx12_orig.dll"
  fi
  cp "$dll" "$d/amd_fidelityfx_loader_dx12.dll"
  # DLSS workaround: the game detects Wine by looking for the string "wine_get_version".
  # Rename it (same length, so the binary stays valid) to make that check fail.
  # Done before the bin/x64 copy below so a copied folder gets the patched exe too.
  exe="$d/witcher3.exe"
  if LC_ALL=C grep -aq "wine_get_version" "$exe"; then
    cp -f "$exe" "$exe.backup"
    LC_ALL=C perl -pi -e 's/wine_get_version/frog_get_version/g' "$exe"
    echo "  patched witcher3.exe for DLSS (backup: witcher3.exe.backup)"
  else
    echo "  witcher3.exe already patched for DLSS"
  fi
  # CrossOver silently redirects bin\x64_dx12\witcher3.exe to bin\x64\witcher3.exe (the DX11
  # build, which 5.00b no longer ships). Point that path at the DX12 build.
  bin="${d:h}"
  if [ -L "$bin/x64" ]; then
    echo "  bin/x64 link already in place"
  elif [ -f "$bin/x64/.ffxproxy-copy" ] || [ ! -e "$bin/x64" ]; then
    if [ ! -e "$bin/x64" ] && ln -s x64_dx12 "$bin/x64" 2>/dev/null; then
      echo "  created bin/x64 -> x64_dx12"
    else
      # exFAT/FAT drives can't store symlinks: keep a refreshed copy instead (~650 MB).
      echo "  this drive doesn't support links, copying x64_dx12 to x64 (about 650 MB)..."
      rm -rf "$bin/x64"
      cp -R "$d" "$bin/x64"
      touch "$bin/x64/.ffxproxy-copy"
      echo "  copied (run this installer again after every game update)"
    fi
  else
    echo "  bin/x64 exists and isn't ours, leaving it alone"
  fi
  echo "  done"
done
echo
echo "Fix installed. Launch the game as usual."
