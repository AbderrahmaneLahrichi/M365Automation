# Load config
$configPath = Join-Path $PSScriptRoot 'Config\config.json'
$script:config = Get-Content $configPath | ConvertFrom-Json

# Default LogPath to user profile if not set in config
if (-not $script:config.LogPath) {
  $script:config | Add-Member -NotePropertyName 'LogPath' -NotePropertyValue "$env:USERPROFILE\Logs\M365Automation" -Force
}

# Load private functions
Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" | ForEach-Object { . $_.FullName }

# Load public functions
Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" | ForEach-Object { . $_.FullName }
