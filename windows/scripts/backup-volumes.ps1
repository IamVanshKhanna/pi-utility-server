# backup-volumes.ps1 - Export Windows Docker named volumes to tar archives
# Run manually or via Task Scheduler (Weekly Sunday 4am)
#   Task Scheduler > Create Basic Task > Action: Start a program
#   Program: powershell.exe
#   Arguments: -ExecutionPolicy Bypass -File "C:\Users\vansh\homelab-ops-mesh\windows\scripts\backup-volumes.ps1"

$ErrorActionPreference = "Continue"
$ScriptDir = $PSScriptRoot
$RepoDir = (Resolve-Path (Join-Path $ScriptDir "..\..")).Path
$BackupDir = Join-Path $RepoDir "windows\backups"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = Join-Path $BackupDir "backup-$Timestamp.log"

if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }

$VolumeList = @(
    "monitoring_grafana_data",
    "monitoring_prometheus_data",
    "monitoring_loki_data",
    "monitoring_alertmanager_data",
    "tracing_tempo_data",
    "auth_authelia_data",
    "secrets_infisical_db_data"
)

"=== Windows volume backup started: $(Get-Date -Format o) ===" | Out-File $LogFile

foreach ($Vol in $VolumeList) {
    "Backing up volume: $Vol" | Out-File $LogFile -Append
    $OutFile = Join-Path $BackupDir "$Vol-$Timestamp.tar.gz"
    $BackupMount = $BackupDir -replace '\\', '/'
    docker run --rm -v "${Vol}:/source" -v "${BackupMount}:/backup" alpine tar czf "/backup/$Vol-$Timestamp.tar.gz" -C /source . 2>> $LogFile
    if ($LASTEXITCODE -eq 0) {
        "  $Vol : OK" | Out-File $LogFile -Append
    } else {
        "  $Vol : FAILED (exit $LASTEXITCODE)" | Out-File $LogFile -Append
    }
}

"Cleaning old backups (keep 7)" | Out-File $LogFile -Append
Get-ChildItem -Path $BackupDir -Filter "*.tar.gz" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 7 | Remove-Item -Force 2>> $LogFile

"=== Windows volume backup finished: $(Get-Date -Format o) ===" | Out-File $LogFile -Append
Get-Content $LogFile
