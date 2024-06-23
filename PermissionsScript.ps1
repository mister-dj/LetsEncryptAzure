<#
Script to add an owner to an application via Graph
Reference: https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/assign-app-owners?pivots=ms-powershell
#>

#####################################################
#  Configure these variables for your environment   #
#####################################################
#This is the Object ID as shown in Entra under Applications > Enterprise Apps > Overview
$AppObjectID = "<your app's Object ID here>"
#This is the Object ID as shown in Entra under Applications > Enterprise Apps > Filter to Managed Identities > Overview
$ManagedIdentityObjectId = "<your Managed Identity's Object ID here>"


#####################################################
#            Do Not Edit Anything Below             #
##################################################### 
Import-Module Microsoft.Graph.Authentication, Microsoft.Graph.Applications
Connect-MgGraph -Scopes 'Application.ReadWrite.All'

$params = @{
    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$ManagedIdentityObjectId"
}

New-MgServicePrincipalOwnerByRef -ServicePrincipalId $AppObjectID -BodyParameter $params
