[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/F2J527ZLUN)

# Witcher 3 Remastered (5.00b) black screen fix for CrossOver on Mac

The Witcher 3 Remastered patch 5.00b (released 28 Sep 2026) hangs on a black screen under CrossOver 26.3 / D3DMetal 3.0. This fix gets it to the main menu at 60 fps on an M1 Pro.

## What goes wrong

1. **CrossOver redirects the game to a folder that doesn't exist.** CrossOver has a built-in tweak that swaps `bin\x64_dx12\witcher3.exe` for `bin\x64\witcher3.exe`, the old DX11 build. Patch 5.00b is DX12-only and no longer ships `bin\x64`, so the game fails to launch ("Path not found").
2. **D3DMetal crashes on one pipeline.** During startup the game creates a single *stream-output* graphics pipeline (geometry shader, no pixel shader). Compiling it crashes Apple's shader converter (`libmetalirconverter.dylib`). The game's crash handler then deadlocks, which leaves you with a black window at 100% CPU.

## What the fix does

- Adds a symlink `bin/x64 → x64_dx12` so CrossOver's redirect lands on the real DX12 build.
- Replaces `amd_fidelityfx_loader_dx12.dll` with a small proxy. The original is kept as `amd_fidelityfx_loader_dx12_orig.dll` and every FidelityFX call is forwarded to it unchanged. The proxy also hooks the game's D3D12 device and refuses stream-output pipelines before they reach D3DMetal. The game continues without that pipeline.
- Marks the game as DPI-aware at startup. Otherwise, with CrossOver's **High Resolution Mode** on, the game only sees a half-size virtual screen and tops out at 1512×982 on a 14" MacBook Pro. With this, resolutions like 1920×1200 or the full native size show up. Mac screens are 16:10, so choose 1920×1200 rather than 1920×1080.
- Patches `witcher3.exe` for DLSS: the game detects Wine by looking for the string `wine_get_version`, so the installer renames it to `frog_get_version` (same length, binary-safe, via `perl`). The original is saved as `witcher3.exe.backup`, and `uninstall.command` restores it. DLSS under CrossOver is community-reported and unverified here.

Nothing else in the game is modified, and the proxy makes no network access.

## Install

1. Download this repo (Code → Download ZIP) and unzip it.
2. Double-click `install.command`. If macOS blocks it, right-click → Open. It looks for the game in:
   - every CrossOver bottle (GOG, Steam, EA...), including extra drive letters the bottle maps,
   - Steam library folders listed in Steam's own config, even on other drives,
   - external drives under `/Volumes`.

   If it still can't find the game, it asks you to **drag the game folder into the window**. The game folder, its `bin` folder, or `witcher3.exe` all work. You can also pass the path in Terminal: `./install.command "/Volumes/MyDrive/SteamLibrary/steamapps/common/The Witcher 3"`
3. Launch the game as usual.

External drives work, including exFAT. If a drive can't store the `bin/x64` link, the installer copies the folder instead (about 650 MB) and refreshes that copy each time you run it.

**Recommended in-game settings:** turn off HDR and NVIDIA DLSS/Reflex, and use FXAA or TAA for anti-aliasing. FSR is untested.

**After a game update or "Verify files", run `install.command` again.** The launcher restores the original DLL.

## Uninstall

Double-click `uninstall.command`. It restores the original DLL and removes the `bin/x64` link, or the copy. It searches the same places as the installer and also accepts a dragged folder.

## Known limits

- Tested on: M1 Pro, macOS 26, CrossOver 26.3, GOG version 5.00b. Steam should work the same way but hasn't been tested.
- The refused pipeline may mean a visual effect is missing in-game.
- A log is written to `drive_c/users/crossover/ffxproxy.log` inside the bottle.

## Build it yourself

The DLL is built from `ffxproxy.c` (single file, no dependencies) with Zig as the cross-compiler:

```sh
python3 -m venv venv && venv/bin/pip install ziglang
venv/bin/python -m ziglang cc -target x86_64-windows-gnu -shared -O2 -o amd_fidelityfx_loader_dx12.dll ffxproxy.c
```

SHA-256 of the released DLL:
`46862167d7471bd41deee3edb11665b3dcecc86f20fe4ddcd666764cefe1827a`

Optional environment variables: `FFXPROXY_DUMP=1` dumps shaders to `%USERPROFILE%\ffxdump`, `FFXPROXY_STUB_FSR=1` gives FSR a dummy context, and `FFXPROXY_NO_DPI=1` turns off the DPI-awareness change.

## License

MIT. Not affiliated with CD PROJEKT RED, CodeWeavers, Apple or AMD.
