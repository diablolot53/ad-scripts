<#
	Offline Event Viewer Export Script
	Last Update - 04/03/2018

PURPOSE
	This is the companion to the Search-OfflineEvents search script. It will filter and export logon events for easy searching and archival purposes.

PARAMETERS
	-File[String]		- Required - The name of the file to use for the export.
	-Compress[Switch]	- Optional - Compresses the XML export into a zip file
	-Success[Switch]	- Default/Optional - Exports successful logon attempts, EventID 4624. If no other option is selected this will be used as the default
	-Failure[Switch]	- Optional - Exports failed logon attempts, EventID 4625
	-Custom[Int]		- Optional - Specify the EventID of the events to export from the Security log

OUTPUT
	XML file containing the matching Security log entries.
#>

#PARAMETERS
param (
	[Parameter(Mandatory=$True)][string]$File,
	[switch]$Compress,
	[switch]$Success,
	[switch]$Failure,
	[int]$Custom
)

#FUNCTIONS


#SCRIPT
#Variables
$EventID = @()

#Check and see if the file specified already exists
If(((Test-Path $File) -eq $True) -or ((Test-Path "$($File).zip") -eq $True)){
	Write-Host "$($File) already exists"
	$Response = Read-Host -Prompt "Do you wish to continue and overwrite the file?(y/N)"
	switch ($Response){
		Y {Continue}
		N {Exit}
		default{Exit}
	}
}

#EventIDs to search
If ($Failure.IsPresent -eq $True){$EventID += 4625}
If ($Custom -gt 0){$EventID += $Custom}
If (($Success.IsPresent -eq $True) -or ($EventID.Count -eq 0)){$EventID += 4624}
Write-Progress -Activity "Exporting Events from log" -Id 0
$Results = Get-EventLog -LogName Security -InstanceId $EventID -ErrorAction Continue

#Export Results to an XML file
Export-Clixml -InputObject $Results -Depth 100 -Path $File

#Compress the results if the parameter is specified
If ($Compress.IsPresent -eq $True){
	Compress-Archive -Path $File -DestinationPath "$($File).zip" -Force
	sleep 2
	Remove-Item $File
}