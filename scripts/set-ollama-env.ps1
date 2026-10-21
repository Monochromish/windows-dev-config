$settings = [ordered]@{
    OLLAMA_FLASH_ATTENTION   = '1'
    # q8_0 crashes model loading on RTX Spark (N1X) with Ollama 0.40.x.
    OLLAMA_KV_CACHE_TYPE     = 'f16'
    OLLAMA_CONTEXT_LENGTH    = '32768'
    OLLAMA_MAX_LOADED_MODELS = '1'
}

foreach ($name in $settings.Keys) {
    [Environment]::SetEnvironmentVariable($name, $settings[$name], 'User')
    Write-Host "$name=$($settings[$name])"
}
Write-Host 'Restart Ollama to apply.'
