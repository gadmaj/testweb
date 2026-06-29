#Requires -RunAsAdministrator
<#
.SYNOPSIS
    install sql server
.DESCRIPTION
    Run this ONCE on BOTH servers, in an elevated PowerShell session:
        - Server 2  (PRODUCTION) : Windows Server 2022 + SQL Server 2019 Standard
        - Server 1  (SANDBOX)    : Windows Server 2025 + SQL Server Express
    'SqlServer' is the supported successor to the legacy 'SQLPS' module.
.NOTES
    For an OFFLINE/air-gapped server, on an internet-connected box run:
        Save-Module -Name SqlServer -Path C:\Temp\SqlServer
    then copy that folder to:
        %ProgramFiles%\WindowsPowerShell\Modules\SqlServer
    on the offline server.
#>
[CmdletBinding()]
param(
    [ValidateSet('AllUsers','CurrentUser')]
    [string] $Scope = 'AllUsers'
)

Write-Host "installing sqlserver" -ForegroundColor Cyan

[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host "installing nuget package provider" -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}
if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

Write-Host "installing sqlserver module (scope: $Scope)..." -ForegroundColor Yellow
Install-Module -Name SqlServer -Scope $Scope -AllowClobber -Force

Import-Module SqlServer -Force
$m = Get-Module SqlServer
Write-Host ("sqlserver ver. {0} installed" -f $m.Version) -ForegroundColor Green
Get-Command -Module SqlServer -Name Backup-SqlDatabase, Restore-SqlDatabase, Invoke-Sqlcmd |
    Format-Table Name, Version -AutoSize