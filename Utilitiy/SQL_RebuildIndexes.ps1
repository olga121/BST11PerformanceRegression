[CmdletBinding()]
param 
(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $WorkspaceDirectory,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $TemplateFile
)
#LOAD CONFIG FILE
$configFilePath=([System.IO.Path]::Combine($WorkspaceDirectory, "self", "configs", $TemplateFile))
$config=Get-Content $configFilePath | Out-String | ConvertFrom-Json

#REBUILD INDEXES SCRIPT
$rebuildIndexesScript=([System.IO.Path]::Combine($PSScriptRoot, "SQL", "REBUILD_INDEXES.sql"))

#GET TARGET SERVER AND DATABASE
$server=$config.servers.dbServer.name
$dbName=$config.servers.dbServer.databaseName

#REBUILD TABLE INDEXES
Write-Host "Rebuilding table indexes on server: $($server) and database: $($dbName)"
$Variables="DBNAME='$($dbName)'"
Invoke-Sqlcmd -ServerInstance $server `
                -Database $dbName `
                -InputFile $rebuildIndexesScript `
                -Variable $Variables
Write-Host "Rebuilding indexes complete"