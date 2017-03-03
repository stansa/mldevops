param (
    [string]$environment = "dev"
)

cls


Write-Host "Checking/Installing AzureRM module..."
if (!(Get-Module -Name AzureRM -ListAvailable)) { Install-Module -Name AzureRM -Scope CurrentUser -AllowClobber -Force}

Write-Host "Checking/Installing Psake module..."
if (!(Get-Module -Name psake -ListAvailable)) { Install-Module -Name psake -Scope CurrentUser -AllowClobber -Force}

Write-Host "Installing Azure ML module..."
$dll = '.\Build\AzureMLPS.dll'
Unblock-File $dll
Import-Module $dll


$ProjectRoot = Resolve-Path "."
Write-Host "ProjectRoot is $ProjectRoot"


$config_common =  .\Build\config_common.ps1
$parameters += $config_common

if ($environment -eq "dev") {
$config_user = .\Build\.config_user.ps1
$parameters += $config_user		
}


$config_env =  invoke-expression .\Build\config_$environment.ps1
$parameters += $config_env