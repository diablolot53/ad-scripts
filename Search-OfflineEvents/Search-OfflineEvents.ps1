<#
	Offline Event Viewer Search Script
	Last Update - 04/02/2018

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
Function ReadXML{
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

Function FormatResults{
<#
NAME
	FormatResults
PURPOSE
	Takes the search results and formats it correctly for output to the console. It will display the following attributes discovered during the search:
		Username
		SourceDC
		SourceWorkstation
		LogonType
		TimeGenerated
INPUT
	System.Diagnostics.EventLogEntry
OUTPUT
	[String]Username
	[String]SourceDC
	[String]SourceWorkstation
	[String]LogonType
	[DateTime]TimeGenerated
#>
	param ($EventIn)

	#Edit the LogonType to make it easier to understand
	Switch ($EventIn.ReplacementStrings[8]){
		2 {$EventLogonType = "2-Interactive"}
		3 {$EventLogonType = "3-Network"}
		4 {$EventLogonType = "4-Batch"}
		7 {$EventLogonType = "7-Unlock"}
		8 {$EventLogonType = "8-NetworkCleartext"}
		10 {$EventLogonType = "10-RemoteInteractive"}
		11 {$EventLogonType = "11-CachedInteractive"}
		default {$EventLogonType = $EventIn.ReplacementStrings[8]}
	}

	#Format the data and return it
	$out = New-Object PSObject
	$out | Add-Member -MemberType NoteProperty -Name "Username" -Value $EventIn.ReplacementStrings[5]
	$out | Add-Member -MemberType NoteProperty -Name "SourceDC" -Value $EventIn.MachineName
	$out | Add-Member -MemberType NoteProperty -Name "SourceWorkstation" -Value $EventIn.ReplacementStrings[18]
	$out | Add-Member -MemberType NoteProperty -Name "LogonType" -Value $EventLogonType
	$out | Add-Member -MemberType NoteProperty -Name "TimeGenerated" -Value $EventIn.TimeGenerated
	Return $out
}

#SCRIPT
#Cleanup the XMLFiles input
$XMLFiles = $XMLFiles.Trim("`"")
$XMLFilesArray = $XMLFiles.Split(",")

#Variables
$i = 1
$EventData = @()
$Out = @()

#Import the XML files
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
Write-Progress -Activity "Loading XML" -Completed

#Search through the EventLog data
Write-Progress -Activity "Searching Logon Records" -Status "Please Wait"
#1. Lookup via Username & LogonType
If (($Username -ne "") -and ($LogonType -ne 0)){
	$Results = $EventData | where {($_.ReplacementStrings[5] -like $Username) -and ($_.ReplacementStrings[8] -eq $LogonType) -and ($_.ReplacementStrings[18] -ne "-")}
	ForEach ($r in $Results){
		$Out += FormatResults $r
	}
	Format-Table -InputObject $Out | Out-String | Write-Host
	Exit
}

#2. Lookup via Username
If ($Username -ne ""){
	$Results = $EventData | where {($_.ReplacementStrings[5] -like $Username) -and ($_.ReplacementStrings[18] -ne "-")}
	ForEach ($r in $Results){
		$Out += FormatResults $r
	}
	Format-Table -InputObject $Out | Out-String | Write-Host
	Exit
}

#3. Lookup via LogonType
If ($LogonType -ne 0){
	$Results = $EventData | where {($_.ReplacementStrings[8] -eq $LogonType)}
	ForEach ($r in $Results){
		$Out += FormatResults $r
	}
	Format-Table -InputObject $Out | Out-String | Write-Host
	Exit
}