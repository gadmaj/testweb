#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Registers nightly (and optional periodic transaction-log) SQL backups as Windows
    Scheduled Tasks that run Invoke-SqlBackup.ps1 under a dedicated service account.
    Use on SQL Express (which has no SQL Agent) and, for a consistent toolset, on
    Standard too.
.PARAMETER ServiceAccount
    The account the task runs as,xx e.g. CONTOSO\svc_sqlbak  (or a gMSA: CONTOSO\svc_sqlbak$).
    It needs:  SQL  -> db_backupoperator on each database (BACKUP rights);
               NTFS -> Modify on the BackupRoot folder / share.
.PARAMETER IsGmsa
    Set if ServiceAccount is a group Managed Service Account (no password is stored).
.PARAMETER WithLogBackups
    Also create a repeating TLOG-backup task for point-in-time restore.
    Requires the database to be in FULL recovery model.
.EXAMPLE  (PRODUCTION - Server 2)
    .\Register-SqlBackupTasks.ps1 -ScriptPath C:\SqlBackup\Invoke-SqlBackup.ps1 `
        -ServerInstance PRODSVR -Database AppDB `
        -BackupRoot \\fileserver\sqlbackup\prod `
        -ServiceAccount CONTOSO\svc_sqlbak `
        -TaskName "SQL Nightly Full Backup (PROD)" -FullTime 01:00 -CopyOnly -Compress
.EXAMPLE  (SANDBOX - Server 1, SQL Express)
    .\Register-SqlBackupTasks.ps1 -ScriptPath C:\SqlBackup\Invoke-SqlBackup.ps1 `
        -ServerInstance SANDBOXSVR\SQLEXPRESS -Database AppDB `
        -BackupRoot D:\SqlBackup\sandbox `
        -ServiceAccount CONTOSO\svc_sqlbak `
        -TaskName "SQL Nightly Full Backup (SANDBOX)" -FullTime 23:00
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ScriptPath,
    [Parameter(Mandatory)] [string] $ServerInstance,
    [Parameter(Mandatory)] [string] $Database,
    [Parameter(Mandatory)] [string] $BackupRoot,
    [Parameter(Mandatory)] [string] $ServiceAccount,
    [switch] $IsGmsa,
    [string] $TaskName        = 'SQL Nightly Full Backup',
    [string] $FullTime        = '01:00',
    [int]    $RetentionDays   = 14,
    [switch] $CopyOnly,
    [switch] $Compress,
    [switch] $WithLogBackups,
    [int]    $LogIntervalHours = 2
)

$psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

# Prompt once for the service-account password (skipped for gMSA)
$cred = if ($IsGmsa) { $null } else {
    Get-Credential -UserName $ServiceAccount -Message "Password for the SQL backup service account"
}

function New-BackupTask {
    param([string]$Name, [string]$Arguments, $Trigger)

    $action = New-ScheduledTaskAction -Execute $psExe `
        -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$ScriptPath`" $Arguments"

    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
        -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 4)

    if ($IsGmsa) {
        $principal = New-ScheduledTaskPrincipal -UserId $ServiceAccount `
            -LogonType Password -RunLevel Highest
        Register-ScheduledTask -TaskName $Name -Action $action -Trigger $Trigger `
            -Principal $principal -Settings $settings -Force
    }
    else {
        Register-ScheduledTask -TaskName $Name -Action $action -Trigger $Trigger `
            -Settings $settings -RunLevel Highest `
            -User $cred.UserName -Password $cred.GetNetworkCredential().Password -Force
    }
}

# ---------- nightly FULL backup ----------
$fullArgs = "-ServerInstance `"$ServerInstance`" -Database $Database " +
            "-BackupRoot `"$BackupRoot`" -BackupType Full -RetentionDays $RetentionDays"
if ($CopyOnly) { $fullArgs += ' -CopyOnly' }
if ($Compress) { $fullArgs += ' -Compress' }

$fullTrigger = New-ScheduledTaskTrigger -Daily -At $FullTime
New-BackupTask -Name $TaskName -Arguments $fullArgs -Trigger $fullTrigger | Out-Null
Write-Host "Registered '$TaskName' - daily at $FullTime." -ForegroundColor Green

# ---------- optional repeating LOG backup (point-in-time restore) ----------
if ($WithLogBackups) {
    $logArgs = "-ServerInstance `"$ServerInstance`" -Database $Database " +
               "-BackupRoot `"$BackupRoot`" -BackupType Log -RetentionDays $RetentionDays"
    $start = (Get-Date $FullTime).AddMinutes(30)
    $logTrigger = New-ScheduledTaskTrigger -Once -At $start `
        -RepetitionInterval (New-TimeSpan -Hours $LogIntervalHours) `
        -RepetitionDuration  (New-TimeSpan -Days 1)
    New-BackupTask -Name "$TaskName (TLOG)" -Arguments $logArgs -Trigger $logTrigger | Out-Null
    Write-Host "Registered '$TaskName (TLOG)' - every $LogIntervalHours h (needs FULL recovery model)." -ForegroundColor Green
}
