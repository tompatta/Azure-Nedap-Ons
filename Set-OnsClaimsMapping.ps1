<#
.DESCRIPTION
    This script will add the "employee_number" claim from the AzureAD attribute "employeeid" to an existing Application Registration in Azure.
    The claim uses the "employeeid" attribute in Azure Active Directory for the claim value.
    Please make sure you are connected to the correct AzureAD tenant before proceeding.

    This script comes as-is without any warranties. Please proceed at your own risk!
.NOTES
    Version:        1.0
    Author:         Tom Schoen
    Creation Date:  30-05-2022
    Purpose/Change: Initial upload
#>

Write-Host -ForegroundColor Cyan @"
This script will add the `"employee_number`" claim from the AzureAD attribute `"employeeid`" to an existing Application Registration in Azure.
The claim uses the "employeeid" attribute in Azure Active Directory for the claim value.
Please make sure you are connected to the correct AzureAD tenant before proceeding.

This script comes as-is without any warranties. Please proceed at your own risk!

"@

try { 
    $AzureADTenant = Get-AzureADTenantDetail
}
catch { 
    Write-Host -ForegroundColor Red "    [X] Cannot continue because you are not connected to AzureAD. Please connect to your tenant using `"Connect-AzureAD`" and try again.`n"
    Exit
}

Write-Host -ForegroundColor White "`n    [!] Connected to $($AzureADTenant.DisplayName) (at $($AzureADTenant.VerifiedDomains[0].Name)).`n"

Write-Host -ForegroundColor White "    [?] Select Nedap ONS Application Registration`n"

$ApplicationPrincipal = Get-AzureADServicePrincipal -All:$true |
Select-Object DisplayName, ObjectId, AppId |
Sort-Object DisplayName |
Out-Gridview -Title "Select Nedap ONS Application Registration" -OutputMode Single

If (-not $ApplicationPrincipal) {
    Write-Host -ForegroundColor Red "    [X] Cannot continue because no application was selected. Please try again.`n"
    Exit
}

Write-Host -ForegroundColor White "    [!] Checking for existing policies on application"
$CurrentPolicies = Get-AzureADServicePrincipalPolicy -Id $ApplicationPrincipal.ObjectId |
Where-Object { $_.Type -eq "ClaimsMappingPolicy" }

If ($CurrentPolicies) {
    Write-Host -ForegroundColor Yellow "`n    [!] A claims-mapping policy ($($CurrentPolicies.DisplayName)) is currently already set for this application."
    Write-Host -ForegroundColor Yellow "        Would you like this script to remove it from the application for you?" -NoNewline
    Write-Host -ForegroundColor White " [Y/N]: " -NoNewline
    If ((Read-Host) -match "[yY]") { 
        $CurrentPolicies | ForEach-Object { Remove-AzureADServicePrincipalPolicy -Id $ApplicationPrincipal.ObjectId -PolicyId $_.Id }
        Write-Host -ForegroundColor White "`n    [!] Removing current claims-mapping policy"
    }
    else {
        Write-Host -ForegroundColor Red "`n    [X] Cannot continue because a claims-mapping policy is currently already set for this application. Please remove the policy manually and try again.`n"
        Exit
    }
}

Write-Host -ForegroundColor White "`n    [!] Creating new claims-mapping policy`n"
$NewPolicy = New-AzureADPolicy -Definition @('
{
   "ClaimsMappingPolicy":{
      "Version":1,
      "IncludeBasicClaimSet":"true",
      "ClaimsSchema":[
         {
            "Source":"user",
            "ID":"employeeid",
            "SamlClaimType":"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/employee_number",
            "JwtClaimType":"employee_number"
         }
      ]
   }
}
') -DisplayName "NedapONSEmployeeNumber" -Type "ClaimsMappingPolicy"

Write-Host -ForegroundColor White "    [!] Adding new claims-mapping policy to application`n"
Add-AzureADServicePrincipalPolicy -Id $ApplicationPrincipal.ObjectId -RefObjectId $NewPolicy.Id

Write-Host -ForegroundColor Green "    [!] Script execution complete."
Write-Host -ForegroundColor Green "        Added policy `"$($NewPolicy.DisplayName)`" ($($NewPolicy.Id))"
Write-Host -ForegroundColor Green "        to application `"$($ApplicationPrincipal.DisplayName)`" ($($ApplicationPrincipal.ObjectId)).`n"
