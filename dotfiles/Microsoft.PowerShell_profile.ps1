mise activate pwsh | Out-String | Invoke-Expression
Invoke-Expression (&starship init powershell)

# Smart App Control blocks uv's unsigned hf.exe launcher, so run the CLI through its own Python.
function hf { & "$env:APPDATA\uv\tools\huggingface-hub\Scripts\python.exe" -m huggingface_hub.cli.hf @args }
