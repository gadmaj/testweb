#Requires -Modules SqlServer
<#
.SYNOPSIS
    Native SQL Server backup (Full or transaction Log) using the Microsoft 'SqlServer'
    module, with media verification, retention cleanup, and logging.
    Works on every edition INCLUDING SQL Express (no SQL Agent needed - schedule with
    Windows Task Scheduler via Register-SqlBackupTasks.ps1).
.PARAMETER ServerInstance
    e.g. "PRODSVR"  or  "SANDBOXSVR\SQLEXPRESS"
.PARAMETER Database
    One or more database names.
.PARAMETER BackupRoot
    Destination folder or UNC share, e.g. \\fileserver\sqlbackup\prod
.PARAMETER BackupType
    Full (default) or Log.  Log requires the DB to be in FULL recovery model.
.PARAMETER CopyOnly
    Take a COPY_ONLY full backup (does not disturb an existing differential/log chain).
    Recommended on PRODUCTION so this job never interferes with its primary backups.
.PARAMETER Compress
    Enable backup compression. SUPPORTED on Standard/Enterprise. DO NOT use on Express
    (Express cannot compress backups - leaving this off keeps it Default/Off).
.EXAMPLE
    .\Invoke-SqlBackup.ps1 -ServerInstance PRODSVR -Database AppDB `
        -BackupRoot \\fileserver\sqlbackup\prod -CopyOnly -Compress
.EXAMPLE
    .\Invoke-SqlBackup.ps1 -ServerInstance SANDBOXSVR\SQLEXPRESS -Database AppDB `
        -BackupRoot D:\SqlBackup\sandbox
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]   $ServerInstance,
    [Parameter(Mandatory)] [string[]] $Database,
    [Parameter(Mandatory)] [string]   $BackupRoot,
    [ValidateSet('Full','Log')] [string] $BackupType = 'Full',
    [int]    $RetentionDays = 14,
    [switch] $CopyOnly,
    [switch] $Compress,
    [string] $LogDir = 'C:\SqlBackup\logs'
)

$ErrorActionPreference = 'Stop'
Import-Module SqlServer -ErrorAction Stop

# --- logging helper ---
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$logFile = Join-Path $LogDir ("backup_{0}_{1}.log" -f $BackupType, (Get-Date -Format 'yyyyMMdd'))
function Write-Log($msg) {
    ("{0}  {1}" -f (Get-Date -Format 's'), $msg) | Tee-Object -FilePath $logFile -Append
}

$ext    = if ($BackupType -eq 'Log') { 'trn' }      else { 'bak' }
$action = if ($BackupType -eq 'Log') { 'Log' }      else { 'Database' }
$comp   = if ($Compress)             { 'On' }        else { 'Default' }
$exit   = 0

if (-not (Test-Path $BackupRoot)) { New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null }

foreach ($db in $Database) {
    try {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $file  = Join-Path $BackupRoot ("{0}_{1}_{2}.{3}" -f $db, $BackupType.ToUpper(), $stamp, $ext)
        Write-Log "START $BackupType backup of [$db] on [$ServerInstance] -> $file"

        $params = @{
            ServerInstance    = $ServerInstance
            Database          = $db
            BackupFile        = $file
            BackupAction      = $action
            Checksum          = $true
            CompressionOption = $comp
        }
        if ($CopyOnly -and $BackupType -eq 'Full') { $params['CopyOnly'] = $true }

        Backup-SqlDatabase @params
        Write-Log "  written, verifying media..."

        # Confirm the backup is restorable before we trust it
        Invoke-Sqlcmd -ServerInstance $ServerInstance `
            -Query "RESTORE VERIFYONLY FROM DISK = N'$file' WITH CHECKSUM" -ErrorAction Stop | Out-Null
        Write-Log "  VERIFY OK for [$db]"

        # Retention: delete this DB's own backups of the same TYPE older than N days
        $cutoff  = (Get-Date).AddDays(-$RetentionDays)
        $pattern = "{0}_{1}_*.{2}" -f $db, $BackupType.ToUpper(), $ext
        Get-ChildItem -Path $BackupRoot -Filter $pattern -File |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            ForEach-Object {
                Write-Log "  removing expired $($_.Name)"
                Remove-Item $_.FullName -Force
            }
    }
    catch {
        $exit = 1
        Write-Log "  ERROR on [$db]: $($_.Exception.Message)"
    }
}

Write-Log "DONE (exit $exit)"
exit $exit      # non-zero so Task Scheduler / monitoring flags a failed run