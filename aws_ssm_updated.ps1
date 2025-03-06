Param (
    [Parameter(Mandatory=$true)]
    [string] $Env,

    [string] $Region = "us-east-2"
)

$ErrorActionPreference = "Stop"

$ParamPrefix = "/vywus/msgr/master/$Env"

# Use a multidimensional array to maintain order
$Parameters = @(
    @("db-password", "db-password - Messenger database password"),
    @("jwt-secret", "jwt-secret - Web App JWT Secret"),
    @("dataFeederApiKey", "dataFeederApiKey - API Key for Data Feeder to connect to web app"),
    @("firebase-push-token", "firebase-push-token - Firebase Push Token (Firebase > Settings > Cloud Messaging)"),
    @("apns-certificate", "apns-certificate - Path to Apple Push Notification certificate (p12)"),
    @("apns-certificate-password", "apns-certificate-password - Password for Apple Push Notification certificate"),
    @("apnsBundleId", "apnsBundleId - APNS Bundle ID"),
    @("apnsKeyId", "apnsKeyId - APNS Key ID"),
    @("apnsTeamId", "apnsTeamId - APNS Team ID"),
    @("apnsToken", "apnsToken - APNS Token"),
    @("rkp-auth-jwt-secret", "rkp-auth-jwt-secret - Secret used to generate JWTs for RKP's Auth Service"),
    @("dataFeederDbConnectionSharedMaster", "dataFeederDbConnectionSharedMaster - Connection string for Data Feeder Shared Master"),
    @("dataFeederDbConnectionRespRepository", "dataFeederDbConnectionRespRepository - Connection string for Data Feeder Resp Repository"),
    @("dataFeederDbConnectionPyxis", "dataFeederDbConnectionPyxis - Connection string for Data Feeder Pyxis"),
    @("dbUser", "dbUser - Database Username"),
    @("dbName", "dbName - Database Name")
)

# Get the list of existing AWS SSM Parameters
$ExistingParamsJson = aws ssm describe-parameters --region $Region | ConvertFrom-Json
$ExistingParams = $ExistingParamsJson.Parameters.Name

ForEach ($Param in $Parameters) {
    $ParamName = "$ParamPrefix/$($Param[0])"
    $Prompt = $Param[1]

    $ExistingParam = $ExistingParams -contains $ParamName

    If ($ExistingParam) {
        $Prompt = "$Prompt`n`n(Press enter to keep the current value)"
    }

    $First = $true
    While ($First -or (!$ExistingParam -and $Value.Length -eq 0)) {
        $First = $false
        
        # Special handling for APNS certificate
        If ($Param[0] -eq "apns-certificate") {
            $Path = Read-Host -Prompt "Enter full path to Apple Push Notification certificate (p12)"

            If (Test-Path $Path -PathType Leaf) {
                $Bytes = Get-Content $Path -Encoding Byte
                $Base64 = [Convert]::ToBase64String($Bytes)
                $Value = ConvertTo-SecureString $Base64 -AsPlainText -Force
            } Else {
                Write-Host " - ${ParamName}: Could not find file at: $Path" -ForegroundColor Yellow
                $First = $true
                Continue
            }
        } Else {
            $Value = Read-Host -Prompt $Prompt -AsSecureString
        }
    }

    If ($Value.Length -gt 0) {
        # Convert SecureString to PlainText
        $BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
        $PlainTextValue = [Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        # Check if parameter exists
        If ($ExistingParam) {
            aws ssm put-parameter --name $ParamName --value $PlainTextValue --type "SecureString" --tier "Advanced" --overwrite --region $Region | Out-Null
            Write-Host "  - Updated parameter: $ParamName (Advanced Tier)" -ForegroundColor Green
        } Else {
            aws ssm put-parameter --name $ParamName --description $Prompt --value $PlainTextValue --type "SecureString" --tier "Advanced" --region $Region | Out-Null
            Write-Host "  - Created new parameter: $ParamName (Advanced Tier)" -ForegroundColor Green
        }
    }
}

Write-Host "Finished adding parameters to AWS SSM Parameter Store" -ForegroundColor Green

Write-Host
Write-Host "-------------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "WARNING: Any changed parameters may require service restart to take effect" -ForegroundColor Yellow
Write-Host "-------------------------------------------------------------------------------------" -ForegroundColor Yellow
