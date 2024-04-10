[CmdletBinding()]
param 
(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $WorkspaceDirectory,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $TemplateFile
)
#LOAD CONFIG FILE
$configFilePath=([System.IO.Path]::Combine($WorkspaceDirectory, "self", "configs", $TemplateFile))
$config=Get-Content $configFilePath | Out-String | ConvertFrom-Json

#GET TARGET SERVER AND DATABASE
$server=$config.servers.dbServer.name
$dbName=$config.servers.dbServer.databaseName

#Cleaning
Write-Host "Clean Prebills Final Bills on server: $($server) and database: $($dbName)"
$Variables="DBNAME='$($dbName)'", "DocFrom='$(0)'", "DocTo='$(0)'"

#Cleaning SCRIPT
$CleaningFile=([System.IO.Path]::Combine($PSScriptRoot, "SQL", "CleanPrebillsFinalBills.sql"))

foreach($item in Get-Content "$CleaningFile"){

Invoke-Sqlcmd -ServerInstance $server `
                -Database $dbName `
                -InputFile $item `
                -Variable $Variables
}

Write-Host "Clean Prebills Final Bills complete"

