param (
   
	[ValidateSet( "Default","ExportTMFromExp","ExportWSDef","CreateILearnerBlob","CreateOrUpdateWS","DeleteWS","UpdateWSLocalILearner","UpdateWSRemoteILearner")][string]$action="Default"

)

cls

$ProjectRoot = Resolve-Path "$PSScriptRoot\."
Write-Host "ProjectRoot is $ProjectRoot"

###########################################SETUP Powershell Modules
Write-Host "Checking/Installing AzureRM module..."
if (!(Get-Module -Name AzureRM -ListAvailable)) { Install-Module -Name AzureRM -Scope CurrentUser -AllowClobber -Force}

Write-Host "Checking/Installing Psake module..."
if (!(Get-Module -Name psake -ListAvailable)) { Install-Module -Name psake -Scope CurrentUser -AllowClobber -Force}

Write-Host "Checking/Installing Powershell module..."
if (!(Get-Module -Name powershell-yaml -ListAvailable)) { Install-Module -Name powershell-yaml -Scope CurrentUser -AllowClobber -Force}


Write-Host "Installing Azure ML module..."
$dll = "$ProjectRoot\.\Build\AzureMLPS.dll"
Unblock-File $dll
Import-Module $dll


###########################################SETUP CONFIGURATION
$parameters = @{}

$config_common_yaml = (Get-Content -Path  $ProjectRoot\.\Build\config\config_common.yml -Raw).Replace('$ProjectRoot', $ProjectRoot) | ConvertFrom-Yaml 
$config_common = $config_common_yaml.Common
$parameters += $config_common

$config_env_yaml = (Get-Content -Path  $ProjectRoot\.\Build\config\config_local.yml -Raw).Replace('$ProjectRoot', $ProjectRoot) | ConvertFrom-Yaml 
$config_env = $config_env_yaml.local
$parameters += $config_env


$mlcommands_yaml = Get-Content -Path  $ProjectRoot\.\Build\ml\mlcommands.yml -Raw | ConvertFrom-Yaml 
$mlprops = $mlcommands_yaml.$action
$parameters += $mlprops

#$config_user = $mlcommands_yaml.AML_Studio_Credentials
#$parameters += $config_user		

#$parameters



###########################################Call Psake scripts
Invoke-psake -BuildFile $ProjectRoot\Build\psake.ps1 -taskList $action -properties $properties -parameters $parameters

Write-Host "Build exit code:" $LastExitCode

# Propagating the exit code so that Builds actually fail when there is a problem
exit $LastExitCode

