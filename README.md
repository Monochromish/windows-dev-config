# windows-dev-config

Reproducible Windows 11 developer setup using [WinGet Configuration](https://learn.microsoft.com/windows/package-manager/configuration/) and a small set of dotfiles. Tested on Windows on Arm (Surface Laptop Ultra, NVIDIA RTX Spark N1X); winget selects the matching installer on x64 as well.

## Usage

```powershell
git clone https://github.com/Monochromish/windows-dev-config
cd windows-dev-config
winget configure -f configurations/core.winget
```

Apply additional configurations as needed:

| Configuration | Contents |
|---|---|
| `core.winget` | Developer Mode, long paths, PowerShell 7, Windows Terminal, Starship, Git, GitHub CLI, VS Code, mise, Python 3.14, uv, pnpm, ripgrep, jq, CMake, 7-Zip, PowerToys |
| `web-and-apps.winget` | Bun, Docker Desktop, Bruno, GitHub Desktop, StyLua, Lua Language Server |
| `local-ai.winget` | Ollama, LM Studio |
| `embedded-stm32.winget` | Arm GNU Toolchain 13.2.rel1, GNU Make, xPack OpenOCD |

`winget configure` lists every change and asks for confirmation. Some resources require elevation.

## Post-install

| Step | Command or file |
|---|---|
| Font | `scripts/install-nerd-font.ps1` |
| PowerShell profile | Copy `dotfiles/Microsoft.PowerShell_profile.ps1` to `$PROFILE` |
| Windows Terminal | `dotfiles/windows-terminal/README.md` |
| VS Code | Merge `dotfiles/vscode/settings.json`; install extensions with `Get-Content dotfiles/vscode/extensions.txt \| % { code --install-extension $_ }` |
| Visual Studio | Tools → Options → Environment → Fonts and Colors: set Hack Nerd Font Mono for Text Editor and Terminal, or import `dotfiles/visual-studio/hack-nerd-font.vssettings` |
| Node | `mise use -g node@lts` |
| WSL | Copy `dotfiles/.wslconfig` to `%USERPROFILE%`, then `wsl --shutdown` |
| GitHub | `gh auth login` |

## Windows settings

- **System → Advanced:** enable sudo and create a Dev Drive for repositories and package caches. With the Dev Drive mounted as `D:`:
  - `npm config set cache D:\packages\npm-cache`
  - `pnpm config set store-dir D:\packages\pnpm-store --global`
  - Set `UV_CACHE_DIR` and `PIP_CACHE_DIR` to folders under `D:\packages`
- **Windows Update:** enable "Get the latest updates as soon as they're available" and install optional updates for drivers and firmware.

## Local AI

- `scripts/set-ollama-env.ps1` enables flash attention, a 32K context and a single loaded model.
- Keep the KV cache at `f16`. On RTX Spark (N1X) with Ollama 0.40.x, `q8_0` fails with `CUDA error: shared object initialization failed`. The same applies to LM Studio.
- LM Studio on Windows on Arm installs a CPU-only runtime. Install the CUDA runtime with `lms runtime get llama.cpp-win-arm64-nvidia-cuda13 --allow-incompatible -y`, then select it with `lms runtime select`.
- `scripts/llm-bench.ps1 [model]` reports hardware and Ollama throughput for a model (default `qwen3.8:27b`).

## CPU watchdog

`scripts/cpu-watchdog/install.ps1` installs a scheduled task that checks every 5 minutes and shows a notification when a Windows background component (anything under `C:\Windows` or a built-in Microsoft app) uses more than 60% of a core for two consecutive checks. User-launched apps, games, compilers and the foreground window are never flagged; shells, WSL, Defender, Windows Update and search indexing are excluded.

Thresholds and the ignore list are in `config.json` in the install folder (`%USERPROFILE%\Scripts\cpu-watchdog` by default); alerts are logged to `watchdog.log` next to it. Test notifications with `cpu-watchdog.ps1 -TestNotification`. Remove it by deleting the "CPU Watchdog" task in Task Scheduler.

## Windows on Arm

- The Arm GNU Toolchain, GNU Make and OpenOCD have no native Arm64 builds and run under emulation.
- USB drivers cannot be emulated; verify debug probes such as ST-Link early.
- Docker Desktop requires WSL 2 (`wsl --install`).
- Some installers rewrite the user `PATH`. If commands disappear after an install, check it under Environment Variables.
