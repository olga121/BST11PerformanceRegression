[CmdletBinding()]
param 
(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $WorkspaceDirectory,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $TemplateFile
)

#LOAD CONFIG FILE
$configFilePath=([System.IO.Path]::Combine($WorkspaceDirectory, "self", "configs", $TemplateFile))
$config=Get-Content $configFilePath | Out-String | ConvertFrom-Json

#UPDATE STATS SCRIPT
$updateStatsScript=([System.IO.Path]::Combine($PSScriptRoot, "SQL", "UPDATE_STATS.sql"))

#GET TARGET SERVER AND DATABASE
$server=$config.servers.dbServer.name
$dbName=$config.servers.dbServer.databaseName

#UPDATE STATISTICS
Write-Host "Updating statistics on server: $($server) and database: $($dbName)"
Invoke-Sqlcmd -ServerInstance $server `
                -Database $dbName `
                -InputFile $updateStatsScript
Write-Host "Updating statistics complete"