. .\Build\init.ps1

Invoke-psake -buildFile $ProjectRoot\Build\psake.ps1 -taskList default -parameters $parameters

Write-Host "Build exit code:" $LastExitCode

# Propagating the exit code so that builds actually fail when there is a problem
exit $LastExitCode