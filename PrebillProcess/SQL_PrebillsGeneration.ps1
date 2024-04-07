[CmdletBinding()]
param 
(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $WorkspaceDirectory,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $TemplateFile,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $TestScenario,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $DocumentNbr_From
)

#LOAD CONFIG FILE
$configFilePath=([System.IO.Path]::Combine($WorkspaceDirectory, "perf", "configs", $TemplateFile))
$config=Get-Content $configFilePath | Out-String | ConvertFrom-Json

#Procedure TO RUN
if ($TestScenario -contains "Prebill"){
    $Procedure = "PrebillsGeneration.sql"
}
else{
    $Procedure = "FinalBillsGeneration.sql"
}

$ProcedureToRun=([System.IO.Path]::Combine($WorkspaceDirectory, "perf", "PrebillProcess", $Procedure))

#GET TARGET SERVER AND DATABASE
$server=$config.servers.dbServer.name
$dbName=$config.servers.dbServer.databaseName

#GET START DATE
$start=Get-Date -Format 'yyyy:MM:dd HH:mm:ss:fff'
#$start=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ss:fff")
$timeout=10

#RUN PREBILLS GENERATION
$Variables = "ClinedDB='$($dbName)'", "DocumentNbr_From='$($DocumentNbr_From)'"

Write-Host "$Test_scenario on server: $($server) and database: $($dbName) started"
Invoke-Sqlcmd -ServerInstance $server `
                -Database $dbName `
                -InputFile $ProcedureToRun `
                -Variable $Variables

Write-Host "$Test_scenario executed"


#CHECK IF PREBILLS GENERATION COMPLETED
$query="SELECT TOP 1 FinishTime 
        FROM dbo.processrun WITH (NOLOCK)
        ORDER BY StartTime DESC'"
$result=Invoke-Sqlcmd -ServerInstance $server `
              -Database $dbName `
              -Query $query
$TimeNow = Get-Date -Format 'yyyy:MM:dd HH:mm:ss:fff'
#$TimeNow=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ss:fff")
$isGenerationComplete=if(($TimeNow -$result).TotalMinutes -gt'1') {$true} else {$false}

while(!$isGenerationComplete) {
    Start-Sleep -Seconds 60
    $result=Invoke-Sqlcmd -ServerInstance $server `
                -Database $dbName `
                -Query $query
    $isGenerationComplete=if(($TimeNow -$result).TotalMinutes -gt'1') {$true} else {$false}
    if (($TimeNow - $start).TotalMinutes -gt $timeout) {
        throw "Execution time exceeded timeout value of $($timeout) minutes"
    }
}