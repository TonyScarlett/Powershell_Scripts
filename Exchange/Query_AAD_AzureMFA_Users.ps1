#About the Azure MFA Inventory script
#The script below performs two functions:

#It provides a total of the amount of user objects in an Azure Active Directory tenant that have Azure Multi-Factor Authentication configured, compared to the total amount of user objects in the Azure Active Directory tenant. The script saves this information in a .txt file.
#It provides a table of the user objects in an Azure Active Directory tenant that have Azure Multi-Factor Authentication configured, with their preferred method, their configured phone numbers, and all the other Azure Multi-Factor Authentication information available as part of the strongauthenticationdetails array for the object. The script saves this information in a .csv file.
#Note:
#The script fetches information on people from Azure Active Directory. This information is sensitive. The script should be run by an administrator with proper clearance within your information and only shared with the right people within the organization. Information you don’t want to see, can be omitted from the output by commenting the lines for the property in the script, twice.

#REQUIREMENTS
#Running the script requires the Global Admin role in the Azure Active Directory tenant.
#The script requires the Azure AD PowerShell Module to be installed.

#Connect to Azure AD environment
Import-module MSOnline
$Credential = Get-Credential
Connect-MsolService -Credential $Credential

#Create new object with requested information of the users.
$Data = New-Object PSObject
$Data | Add-Member -MemberType NoteProperty –name UserPrincipalName –value NotSet
$Data | Add-Member -MemberType NoteProperty –name Enforced –value NotSet
$Data | Add-Member -MemberType NoteProperty –name Default –value NotSet
$Data | Add-Member -MemberType NoteProperty –name AlternativePhoneNumber –value NotSet
$Data | Add-Member -MemberType NoteProperty –name Email –value NotSet
$Data | Add-Member -MemberType NoteProperty –name PhoneNumber –value NotSet
$Data | Add-Member -MemberType NoteProperty –name ProofupTime –value NotSet

# Get user totals
$AllUsers = Get-MSOLuser -all| Measure
$AllUsers = $AllUsers.Count

#Retrieve all enabled MFA user
$RawData = Get-MsolUser -all| Where{$_.StrongAuthenticationMethods -ne $null} | select UserPrincipalName,StrongAuthenticationMethods,StrongAuthenticationPhoneAppDetails,StrongAuthenticationRequirements,StrongAuthenticationUserDetails, StrongAuthenticationProofupTime

#Get MFA user total
$AllAzureMFAUsers = $RawData | measure
$AllAzureMFAUsers = $AllAzureMFAUsers.Count

#Fill resuslt object $Data with requested information
$Data = ForEach($User in $RawData){
    
    #Create new object for passing back the required information after converting from the user source
    $Result = New-Object PSObject
    $Result | Add-Member -MemberType NoteProperty –name UserPrincipalName –value NotSet
    $Result | Add-Member -MemberType NoteProperty –name Enforced –value NotSet
    $Result | Add-Member -MemberType NoteProperty –name Default –value NotSet
    $Result | Add-Member -MemberType NoteProperty –name AlternativePhoneNumber –value NotSet
    $Result | Add-Member -MemberType NoteProperty –name Email –value NotSet
    $Result | Add-Member -MemberType NoteProperty –name PhoneNumber –value NotSet
    $Result | Add-Member -MemberType NoteProperty –name ProofupTime –value NotSet

    #Fill the UserPrincipalName
	$Result.UserPrincipalName = $User.UserPrincipalName

    #Move object information one level up.
	$Temp = $User.StrongAuthenticationRequirements
	
    #Fill the value if the MFA is enforcerd.
	$Result.Enforced = $Temp.State
	
    #Move object information one level up.
	$Temp = $User.StrongAuthenticationMethods

    #Get preferred method and place it in $Temp.
	$Temp = $Temp | Where{$_.IsDefault -eq "True"} | Select MethodType
	
    #Fill the Preferred method to value Default
	$Result.Default = $Temp.MethodType
	
    #Move object information one level up.
	$Temp = $User.StrongAuthenticationUserDetails
	
    #Fill the values with retrieved information.
	$Result.AlternativePhoneNumber = $Temp.AlternativePhoneNumber
	$Result.Email = $Temp.Email
	$Result.PhoneNumber = $Temp.PhoneNumber
	
    #Convert last succesvol MFA login
    $Result.ProofupTime = [datetime]($User.StrongAuthenticationProofupTime)

    #Passback the object to data
	$Result 
}

#Create output string with user totals
$OutputUsers = "Total users in AzureAD: $AllUsers
Total users enabled for Azure MFA: $AllAzureMFAUsers "

#Output information to file
$OutputUsers | Out-File -FilePath ".\Result_Enabled_AzureMFA_Users_AzureAD_Total.log"
$Data | export-csv -Path ".\Result_Enabled_AzureMFA_Users_AzureAD.csv" -delimiter ";" -NoTypeInformation
