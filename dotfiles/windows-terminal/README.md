# Windows Terminal

In Settings → Open JSON file, set the font for all profiles:

```json
"profiles": {
    "defaults": { "font": { "face": "Hack Nerd Font" } }
}
```

Set PowerShell 7 as the default profile (Settings → Startup → Default profile). Windows PowerShell 5.1 does not load the profile in `dotfiles/`.
