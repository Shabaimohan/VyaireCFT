Param (
    [Parameter(Mandatory=$true)]
    [string] $Env,

    [string] $Region = "us-east-2"
)

$ErrorActionPreference = "Stop"

# Updated parameter prefix to avoid 'ssm' issue
$ParamPrefix = "/zoll/msgr/master/$Env/"

# Validate that the prefix does not contain 'ssm'
If ($ParamPrefix -match "(?i)/ssm") {
    Write-Host "Error: Parameter prefix contains 'ssm', which is not allowed by AWS SSM." -ForegroundColor Red
    Exit 1
}

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
    @("dbName", "dbName - Database Name"),
    @("DBPasswordPostgres", "Database Postgres Password"),
    @("DBUserPostgres", "Database Postgres Username")
)

# Get the list of existing AWS SSM Parameters
$ExistingParamsJson = aws ssm describe-parameters --region $Region | ConvertFrom-Json
$ExistingParams = $ExistingParamsJson.Parameters.Name

ForEach ($Param in $Parameters) {
    $ParamName = "$ParamPrefix$($Param[0])"
    $Prompt = $Param[1]

    $ExistingParam = $ExistingParams -contains $ParamName

    If ($ExistingParam) {
        $Prompt = "$Prompt`n`n(Press enter to keep the current value)"
    }

    $First = $true
    $SkipUpdate = $false

    While ($First -or (!$ExistingParam -and $Value.Length -eq 0)) {
        $First = $false

        # Special handling for APNS certificate
        If ($Param[0] -eq "apns-certificate") {
            $Path = Read-Host -Prompt "Enter full path to Apple Push Notification certificate (p12) or press Enter to keep existing value"

            If ($Path -eq "" -and $ExistingParam) {
                $SkipUpdate = $true
                break
            } ElseIf (Test-Path "$Path" -PathType Leaf) {
                # Read APNS certificate correctly
                $Bytes = [System.IO.File]::ReadAllBytes($Path)
                $Base64 = [Convert]::ToBase64String($Bytes)
                $Value = $Base64
            } Else {
                Write-Host " - ${ParamName}: Could not find file at: $Path" -ForegroundColor Yellow
                $First = $true
                Continue
            }
        } Else {
            $Value = Read-Host -Prompt $Prompt -AsSecureString

            # Convert SecureString to PlainText
            $BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
            $PlainTextValue = [Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

            If ($PlainTextValue -eq "" -and $ExistingParam) {
                $SkipUpdate = $true
                break
            }
        }
    }

    If (-not $SkipUpdate) {
        # Set tier based on parameter name
        $Tier = "Standard"
        If ($Param[0] -eq "apns-certificate") {
            $Tier = "Advanced"
        }

        # Check if parameter exists
        If ($ExistingParam) {
            aws ssm put-parameter --name $ParamName --value $Value --type "SecureString" --tier $Tier --overwrite --region $Region | Out-Null
            Write-Host "  - Updated parameter: $ParamName ($Tier Tier)" -ForegroundColor Green
        } Else {
            aws ssm put-parameter --name $ParamName --description $Prompt --value $Value --type "SecureString" --tier $Tier --region $Region | Out-Null
            Write-Host "  - Created new parameter: $ParamName ($Tier Tier)" -ForegroundColor Green
        }
    } Else {
        Write-Host "  - Kept existing value for: $ParamName" -ForegroundColor Cyan
    }
}

Write-Host "Finished adding parameters to AWS SSM Parameter Store" -ForegroundColor Blue

Write-Host
Write-Host "-------------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "WARNING: Any changed parameters may require service restart to take effect" -ForegroundColor Yellow
Write-Host "-------------------------------------------------------------------------------------" -ForegroundColor Yellow
