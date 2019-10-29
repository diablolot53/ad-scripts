<#
Check-TelephoneNumber.ps1

PURPOSE
   Searches user accounts in Active Directory and checks their phone number to see if it was entered
   with the correct formatting. Any accounts with incorrect formatting are flagged and returned.

PARAMETERS
   Domain          - Required - Name of the Active Directory domain to search
   OU              - Optional - Organizational Unit to search. If this isn't specified the root of the domain is used. Must use the Disiguished Name for the OU
   All             - Optional - Searches all accounts for incorrect telephone number formats. By default only active accounts are checked
   DebugResults    - Optional - Returns the check all results. By default only accounts with failing the checks are returned

RETURN
  Name             - String - Full name for the user account
  samAccountName   - String - samAccountName for the user account
  telephoneNumber  - String - Telephone number for the account
  mobileNumber     - String - Mobile number for the account
  faxNumber        - String - Fax number for the account
  checkFailed      - Boolean - True/False value if the telephone number matches the provided format
  accountEnabled   - Boolean - True/False value if the account is enabled

EXAMPLE
  Check-TelephoneNumber.ps1 | ft
    Searches from the root of the domain returning all active accounts w/ incorrectly formatted telephone numbers. The output is displayed in an easy to read table.

  Check-TelephoneNumber.ps1 -OU "OU=Company Users,DC=Test,DC=local" | ft
    Searches the Company Users OU for any accounts with incorrectly formatted phone numbers

  Check-TelephoneNumber.ps1 | Export-CSV .\FormatCheckFailures.csv -NoTypeInformation
    Runs the search from the root of the domain and then exports the results into a CSV file
#>
param(
    #[Parameter(Mandatory=$true)][string]$Domain,
    [string]$OU,
    [switch]$All = $False,
    [switch]$DebugResults = $False
)



#Variables
$global:Out = @() #Contains the formatted results of the Add-Output function

$Regex = '^[2-9]\d{2}-\d{3}-\d{4}$'  <#
    Regex string to used check the telephone number formatting. Source - http://regexlib.com/REDetails.aspx?regexp_id=22
    Default format - 800-555-5555
    More information and additional regex search strings can be at http://regexlib.com/Search.aspx?k=phone&AspxAutoDetectCookieSupport=1
#>



#Functions
Function Test-TelNumFormat{
<# 
PURPOSE
   Tests the provided telephone number to see if it matches the correct formatting

PARAMETER
   telNubmer - Phone number to be tested

RETURN
   True - Telephone number matches the following format in the $Regex variable
   False - Telephone number does not match
#>
    param([string]$telNumber)

    If ($telNumber -eq ''){Return $True}
    If ($telNumber -match $Regex){Return $True}
    Else {Return $False}
}

Function Add-Output{
<#
PURPOSE
  Adds the provided user data to the output array

PARAMETERS
  Name             - Full name for the user account
  samAccountName   - samAccountName for the user account
  telephoneNumber  - Telephone number for the account
  accountEnabled   - True/False value if the account is enabled 
#>
    param(
    [string]$Name,
    [string]$samAccountName,
    [string]$telephoneNumber,
    [string]$mobileNumber,
    [string]$faxNumber,
    [string]$ipPhone,
    [boolean]$checkFailed,
    [boolean]$accountEnabled
    )
    
#Create custom object for proper formatting
    $obj = New-Object PSObject
    $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $Name
    $obj | Add-Member -MemberType NoteProperty -Name "samAccountName" -Value $samAccountName
    $obj | Add-Member -MemberType NoteProperty -Name "telephoneNumber" -Value $telephoneNumber
    $obj | Add-Member -MemberType NoteProperty -Name "mobileNumber" -Value $mobileeNumber
    $obj | Add-Member -MemberType NoteProperty -Name "faxNumber" -Value $faxNumber
    $obj | Add-Member -MemberType NoteProperty -Name "ipPhone" -Value $ipPhone
    $obj | Add-Member -MemberType NoteProperty -Name "accountEnabled" -Value $accountEnabled
    $obj | Add-Member -MemberType NoteProperty -Name "checkFailed" -Value $checkFailed

#Add the custom object to the outputvariable
$global:Out += $obj | Select Name,samAccountName,telephoneNumber,mobileNumber,faxNumber,ipPhone,checkFailed,accountEnabled
}

Function Search-AD{
<#
PURPOSE
  Search Active Directory and return user accounts

RETURN
  Returns user accounts that match the search parameters with the following attributes
    Name
    samAccountName
    telephoneNumber
    accountEnabled
#>

#Validate OU format
#<Enter code here>

#Generate AD filter query
    switch ($All) {
        $False {$ADFilter = "Enabled -eq 'True'";break}
        $True  {$ADFilter = "*";break}
    }

#Search AD
    If ($OU -eq ''){$Results = Get-ADUser -Filter $ADFilter -Properties telephoneNumber,mobile,facsimileTelephoneNumber,ipPhone}
    Else {$Results = Get-ADUser -Filter $ADFilter -SearchBase $OU -Properties telephoneNumber,mobile,facsimileTelephoneNumber,ipPhone}

#Return the results
    Return $Results
}



<#
 Test phone number format for the provided accounts

 Return any accounts found with the incorrect format
#>
#Gather AD Account information
$ADUsers = Search-AD

#Run the search on the returned results
ForEach ($u in $ADUsers){
    #Check the returned phone numbers
    $CheckTelephoneNumber = Test-TelNumFormat -telNumber $u.telephoneNumber
    $CheckMobileNumber = Test-TelNumFormat -telNumber $u.mobile
    $CheckFaxNumber = Test-TelNumFormat -telNumber $u.facsimileTelephoneNumber
    $CheckipPhone = Test-TelNumFormat -telNumber $u.ipPhone
    #Aggregate the check results into a single value
      #If any of the checks fail the value is True so they are added to the script output
    $CheckFailed = ($CheckTelephoneNumber -xor $CheckMobileNumber) -or ($CheckMobileNumber -xor $CheckFaxNumber) -or ($CheckFaxNumber -xor $CheckipPhone)
    
    #Add to output if the following are true:
      #Any of the 3 phone numbers fail the format check
      #-DebugResults parameter is specified
    If ($CheckFailed -xor $DebugResults){
        Add-Output -Name $u.Name -samAccountName $u.SamAccountName -telephoneNumber $u.telephoneNumber -mobileNumber $u.mobile -faxNumber $u.facsimileTelephoneNumber -ipPhone $u.ipPhone -accountEnabled $u.Enabled -checkFailed $CheckFailed
    }
}

#Returns the data as a PSCustomObject
Return $global:Out