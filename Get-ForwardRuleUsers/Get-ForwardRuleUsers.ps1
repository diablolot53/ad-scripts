$UserCredential = Get-Credential
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
Import-PSSession $Session
Connect-MsolService -Credential $UserCredential

#$Mailboxes = Get-Mailbox -Filter {RecipientType -eq "UserMailbox"} -ResultSize Unlimited | select PrimarySMTPAddress
$Mailboxes = Get-MsolUser -EnabledFilter EnabledOnly -All | where {($_.Licenses).Count -gt 0} | select SignInName
$i = 1
$UsersToInvestigate = @()

ForEach ($m in $Mailboxes){
    Write-Progress -Activity "Checking mailbox $($m.SignInName)" -Status "Mailbox $i of $($Mailboxes.Count)" -PercentComplete (($i/$Mailboxes.Count)*100)
    $MailboxRules = (Get-InboxRule -Mailbox $m.SignInName | where {$_.Name -like "Forward all messages"})
    If ($MailboxRules -ne $null){
        $line = New-Object PSObject
        $line | Add-Member -Type NoteProperty -Name "User" -Value $m.SignInName
        $line | Add-Member -Type NoteProperty -Name "ForwardAddress" -Value $MailboxRules.ForwardTo
        $UsersToInvestigate += $line
        Clear-Variable line
    }
    $i += 1
   Clear-Variable MailboxRules
}

Write-Host $UsersToInvestigate