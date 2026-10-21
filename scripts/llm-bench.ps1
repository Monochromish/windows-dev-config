param([string]$Model = 'qwen3.8:27b')

$api = 'http://127.0.0.1:11434'

function Invoke-Generate($Prompt, $MaxTokens) {
    $body = @{
        model   = $Model
        prompt  = $Prompt
        stream  = $false
        think   = $false
        options = @{ num_predict = $MaxTokens; temperature = 0 }
    } | ConvertTo-Json -Depth 4
    Invoke-RestMethod "$api/api/generate" -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 600
}

try { $null = Invoke-RestMethod "$api/api/version" -TimeoutSec 3 }
catch { Write-Host 'Ollama is not running.' -ForegroundColor Red; exit 1 }

$cs = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$ramInstalled = [math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1GB)
$ramVisible = [math]::Round($cs.TotalPhysicalMemory / 1GB)
$gpu = & nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>$null | Select-Object -First 1

Write-Host "`nHardware" -ForegroundColor Cyan
Write-Host "  Device : $($cs.Manufacturer) $($cs.Model)"
Write-Host "  CPU    : $($cpu.Name) ($($cpu.NumberOfCores) cores, $env:PROCESSOR_ARCHITECTURE)"
Write-Host "  Memory : $ramInstalled GB installed, $ramVisible GB visible to Windows"
if ($gpu) { Write-Host "  GPU    : $gpu" }

Write-Host "`n$Model" -ForegroundColor Cyan

# Unload first so the first request measures a cold start.
$null = Invoke-RestMethod "$api/api/generate" -Method Post -Body (@{ model = $Model; keep_alive = 0 } | ConvertTo-Json) -ContentType 'application/json'
$cold = Invoke-Generate 'Say hello in one short sentence.' 20
$loadSeconds = $cold.load_duration / 1e9
Write-Host ("  Cold start   : {0:N1} s" -f $loadSeconds)

$rates = foreach ($i in 1..3) {
    $r = Invoke-Generate 'Explain how a car engine works, in about 300 words.' 400
    $tps = $r.eval_count / ($r.eval_duration / 1e9)
    Write-Host ("  Generation {0} : {1:N1} tokens/s" -f $i, $tps)
    $tps
}

$filler = 'The quick brown fox jumps over the lazy dog while the engineer reviews firmware logs. ' * 450
$long = Invoke-Generate "$filler`n`nSummarize the text above in one sentence." 60
$promptTps = $long.prompt_eval_count / ($long.prompt_eval_duration / 1e9)
Write-Host ("  Prompt       : {0:N0} tokens/s ({1} tokens)" -f $promptTps, $long.prompt_eval_count)

$loaded = (Invoke-RestMethod "$api/api/ps").models | Where-Object { $_.name -eq $Model } | Select-Object -First 1
$gpuPercent = if ($loaded) { [math]::Round(100 * $loaded.size_vram / $loaded.size) } else { '?' }
$sizeGb = if ($loaded) { [math]::Round($loaded.size / 1GB, 1) } else { '?' }
$avg = ($rates | Measure-Object -Average).Average

Write-Host "`nSummary" -ForegroundColor Green
Write-Host ("  {0} ({1}) on {2}" -f $Model, $loaded.details.quantization_level, $cs.Model)
Write-Host ("  Generation : {0:N1} tokens/s" -f $avg)
Write-Host ("  Prompt     : {0:N0} tokens/s" -f $promptTps)
Write-Host ("  Memory     : {0} GB, {1}% on GPU, {2} context" -f $sizeGb, $gpuPercent, $loaded.context_length)
Write-Host ("  Cold start : {0:N1} s`n" -f $loadSeconds)
