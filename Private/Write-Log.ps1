function Write-Log {
  param (
    [string]$Message,
    [ValidateSet('INFO', 'WARN', 'ERROR')]
    [string]$Level = 'INFO'
  )

  $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $entry = "[$timestamp] [$Level] $Message"
  $logFile = Join-Path $script:config.LogPath "M365Automation_$(Get-Date -Format 'yyyy-MM-dd').log"

  if (-not (Test-Path $script:config.LogPath)) {
    New-Item -ItemType Directory -Path $script:config.LogPath -Force | Out-Null
  }

  Add-Content -Path $logFile -Value $entry

  switch ($Level) {
    'INFO'  { Write-Host $entry -ForegroundColor Cyan }
    'WARN'  { Write-Host $entry -ForegroundColor Yellow }
    'ERROR' { Write-Host $entry -ForegroundColor Red }
  }
}
