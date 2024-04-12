[CmdletBinding()]
param 
(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $WorkspaceDirectory,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $TemplateFile,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $backupDirectory,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $backUpFileName,
    [switch]$Elevated
)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
  }
  
  if ((Test-Admin) -eq $false)  {
      if ($elevated) 
      {
          Write-Output "Tried to elevate, did not work, aborting"
      } 
      else {
          Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
  }
  
  exit
  }
  
  Write-Output 'running with full privileges'

#LOAD CONFIG FILE
$configFilePath=([System.IO.Path]::Combine($WorkspaceDirectory, "self", "configs", $TemplateFile))
$config=Get-Content $configFilePath | Out-String | ConvertFrom-Json

#GET TARGET SERVER AND DATABASE
$server=$config.servers.dbServer.name
$dbName=$config.servers.dbServer.databaseName

#Drop existing database
# try {
#     Invoke-SqlCmd -serverinstance "$server" 
#      -Query "if exists (select name from master.dbo.sysdatabases where name ='$dbname') `
#                  begin `
#                      alter database ['$dbname'] set single_user with rollback immediate; `
#                      drop database ['$dbname']; `
#                  end;" `
#      -verbose
#      $message = "Dropped  " + $dbName
#      Write-Output $message
#      }catch{
#          write-output 'failed to delete database'
#    }
    
# Restore database from backup
$dataFilePath = "E:\ProgramFiles\MSSQL\Data\${dbName}.mdf"
$logFilePath = "E:\ProgramFiles\MSSQL\Data\${dbName}.ldf"

# Specify the backup file to restore from
$backupFilePath = "$backupDirectory\$backUpFileName"

# Specify the file and log paths for the new database
$RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile("$dbName", "$dataFilePath")
$RelocateLog = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile("${dbName}_log", "$logFilePath")

$message = "Performing database restore...From " + $backupFilePath
Write-Output $message
Try {

Restore-SqlDatabase -ServerInstance "$server" -Database "$dbName" -BackupFile "$backupFilePath" -RelocateFile @($RelocateData,$RelocateLog) -ReplaceDatabase

$message ="Completed restoring database " + $dbName
Write-Output $message
    } 
    Catch {
       Write-Output 'Failed to restore database'}
