Param(
    [Parameter(Mandatory=$true)]
    [string]$Env
)

# Get the script directory
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Define file paths
$TemplateFile = "$ScriptPath\SNS.yaml"
$ParameterFile = "$ScriptPath\parameters.json"
$StackName = "vywus-$Env-messenger-stack"
$Region = "us-east-2"

# Validate input
if (-not $Env) {
    Write-Host "Usage: .\deploy.ps1 -Env <environment>" -ForegroundColor Red
    exit 1
}

# Check if the required files exist
if (-Not (Test-Path $TemplateFile)) {
    Write-Host "ERROR: CloudFormation template file not found at: $TemplateFile" -ForegroundColor Red
    exit 1
}

if (-Not (Test-Path $ParameterFile)) {
    Write-Host "ERROR: Parameter file not found at: $ParameterFile" -ForegroundColor Red
    exit 1
}

# Convert JSON parameters to AWS CLI format
$ParameterObjects = Get-Content -Raw $ParameterFile | ConvertFrom-Json

# Construct AWS CLI parameters as a single string for --parameter-overrides
$ParameterOverrides = ($ParameterObjects | ForEach-Object { "ParameterKey=$($_.ParameterKey),ParameterValue=$($_.ParameterValue)" }) -join " "

Write-Host "Deploying CloudFormation stack: $StackName" -ForegroundColor Cyan

# Deploy the CloudFormation stack using AWS CLI
$DeployArgs = @(
    "cloudformation", "deploy",
    "--stack-name", $StackName,
    "--template-file", $TemplateFile,
    "--region", $Region,
    "--capabilities", "CAPABILITY_NAMED_IAM",
    "--parameter-overrides", $ParameterOverrides
)

# Execute AWS CLI command
aws @DeployArgs

# Check deployment status
if ($LASTEXITCODE -eq 0) {
    Write-Host "CloudFormation deployment initiated successfully." -ForegroundColor Green
} else {
    Write-Host "CloudFormation deployment failed. Please check the AWS CLI logs." -ForegroundColor Red
    exit 1
}

# Wait for stack operation to complete
Write-Host "Waiting for stack operation to complete..." -ForegroundColor Yellow
aws cloudformation wait stack-create-complete --stack-name $StackName --region $Region 2>$null
aws cloudformation wait stack-update-complete --stack-name $StackName --region $Region 2>$null

Write-Host "CloudFormation deployment completed successfully." -ForegroundColor Green
