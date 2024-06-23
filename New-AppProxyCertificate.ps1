<#
PowerShell script for use in an Azure Automation Account Runbook.
Uses the Posh-Acme module for generating certificates via LetsEncrypt, then applies the cert to an App Proxy application via Graph.

For more information see below links
Module documentation: https://poshac.me/docs/v4/
Plugin reference: https://poshac.me/docs/v4/Plugins/Namecheap/

NOTE: 
The only "official" PowerShell module/cmdlet for setting an App Proxy application's custom domain 
cert as of 12/15/2023 is a cmdlet that is part of the AzureAD module, which is deprecated. Instead, Graph is used.

The Graph snippet used here is from https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/2076

#>
param(
    [Parameter (Mandatory=$true)]
    [string]$ApiKeySecretName,
    [Parameter (Mandatory=$true)]
    [string]$ApplicationId,
    [Parameter (Mandatory=$true)]
    [validatePattern('^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$')] #some FQDN validation via RegEx
    [ValidateNotNullOrEmpty()]
    [string]$CertDomain,
    [Parameter (Mandatory=$true)]
    [string]$KeyVault,
    [Parameter (Mandatory=$false)]
    [ValidateSet('production','staging')]
    [string]$LetsEncryptServer = "production",
    [Parameter (Mandatory=$true)]
    [string]$LeContactEmail
)

$ErrorActionPreference = 'Stop'

Connect-AzAccount -Identity

# Retrieve API creds from Key Vault
$ApiKey = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name $ApiKeySecretName).SecretValue

# Generate random cert password - note that the password will be automatically removed by Key Vault when the cert is uploaded
$RandomString = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 25 | ForEach-Object {[char]$_})

# Use LE Staging for testing
if($LetsEncryptServer -eq "staging"){
    Set-PAServer LE_STAGE
}
elseif ($LetsEncryptServer -eq "production") {
    Set-PAServer LE_PROD
}
else{
    Throw "Invalid LetsEncrypt server."
}

# Splat cmdlet plugin args
$pArgs = @{
    CFToken = $ApiKey
}

$Cert = New-PACertificate -Domain $CertDomain -Plugin Cloudflare -PluginArgs $pArgs -AcceptTOS -Contact $LeContactEmail -PfxPass $RandomString -Force

Connect-MgGraph -Identity

$params = @{
    onPremisesPublishing = @{
    verifiedCustomDomainKeyCredential = @{
    type="X509CertAndPassword";
    value = [convert]::ToBase64String((Get-Content -Path $Cert.PfxFile -AsByteStream));
    };
    
    verifiedCustomDomainPasswordCredential = @{ value = $RandomString };
    }
}
#Note: the "ApplicationId" parameter that Update-MgBetaApplication takes is NOT the same Application ID that is visible in Entra. The ID the command uses is separate from ObjectID and Application ID.
$App = Get-MgApplication | Where-Object{$_.AppID -eq $ApplicationId}
Update-MgBetaApplication -ApplicationId $App.Id -BodyParameter $params
