<#
	Offline Event Viewer Search Script
	Last Update - 03/30/2018

PURPOSE
	This script can be used to load XML exports from the Security log in the Event Viewer and search through them.

PARAMETERS
	XMLFiles  - Required - The source XML file to load. Multiple files can be specified by separating them with a comma.
	Username  - Optional - The username to search for in the log extracts
	LogonType - Optional - The logon type (as a number) to search for in the log extracts. The Logon types are defined below:
								2: Interactive - Interactive (logon at keyboard and screen of system)
								3: Network - (Connection to shared folder from elsewhere on network)
								4: Batch (Scheduled Task)
								7: Unlock (Unlocked an unattended workstation with password protected screen saver)
								8: NetworkCleartext (Logon with credentials sent in the clear text. Most often indicates a logon to IIS with "basic authentication")
								10: RemoteInteractive (Terminal Services, Remote Desktop or Remote Assistance)
								11: CachedInteractive (Logon with cached domain credentials such as when logging on to a laptop when away from the network)
								More information can be found at https://www.ultimatewindowssecurity.com/securitylog/encyclopedia/event.aspx?eventID=4624
OUTPUT
	Displays the search results as a table in the command line window
#>

#PARAMETERS
param (
	[Parameter(Mandatory=$True)][string]$XMLFiles,
	[String]$Username,
	[Int]$LogonType
)

#FUNCTIONS
<#
NAME
	ReadXML
PURPOSE
	Validates the files provided are XML files and loads them into memory. If the XML files can be found and read, the function will return the data contained in the files.
	If the files could not be read or do not contain XML data, then return an error.
OUTPUT
	Success - Return System.Diagnostics.EventLogEntry
	Failure - Return failure

TO DO
	-Add a check to verify the imported XML file contains Event Log data instead of something else
#>
Function ReadXML{
	param ([string]$File)

	If ((Test-Path $File) -eq $True){
		Try{
			$Temp = Import-Clixml $File
			Return $Temp
		}
		Catch{Return "XML Load Error"}
	}
	Else{Return "XML File Not Found"}
}

#SCRIPT
#Cleanup the XMLFiles input
$XMLFiles = $XMLFiles.Trim("`"")
$XMLFilesArray = $XMLFiles.Split(",")

#Load the provided XML files
$i = 1
ForEach ($file in $XMLFilesArray){
	#Display a progress bar to inform the user whats going on
	Write-Progress -Activity "Loading XML File $file" -Status "File $i of $($XMLFilesArray.Count)" -PercentComplete (($i/$XMLFilesArray.Count)*100)

	$ReturnData = ReadXML -File $file

	#If an error is found while reading the XML file, exit the script and display the error message
	If ($ReturnData.Contains("XML Load Error") -or $ReturnData.Contains("XML File Not Found")){
		Write-Host -ForegroundColor Red $ReturnData
		Write-Host -ForegroundColor Red "Error loading - $file"
		Exit
	}

	$EventData += $ReturnData
	$i++
}