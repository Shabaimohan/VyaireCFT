# PowerShell script to deploy AWS CloudFormation stack using AWS CLI

Param(
    [Parameter(Mandatory=$true)]
    [string]$Env
)

# Get the script directory
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Define correct file names
$TemplateFile = "$ScriptPath\aws-deploy.yaml"
$ParameterFile = "$ScriptPath\master_${Env}_parameters.json"
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

# Check if the stack exists
$StackStatus = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query 'Stacks[0].StackStatus' --output text 2>$null

if ($null -eq $StackStatus) {
    Write-Host "Creating new CloudFormation stack: $StackName" -ForegroundColor Cyan
    aws cloudformation create-stack `
        --stack-name $StackName `
        --template-body "file://$TemplateFile" `
        --parameters "file://$ParameterFile" `
        --region $Region `
        --capabilities CAPABILITY_NAMED_IAM
} else {
    Write-Host "Updating existing CloudFormation stack: $StackName" -ForegroundColor Cyan
    aws cloudformation update-stack `
        --stack-name $StackName `
        --template-body "file://$TemplateFile" `
        --parameters "file://$ParameterFile" `
        --region $Region `
        --capabilities CAPABILITY_NAMED_IAM
}

# Wait for stack completion
Write-Host "Waiting for stack operation to complete..." -ForegroundColor Yellow
aws cloudformation wait stack-create-complete --stack-name $StackName --region $Region 2>$null
aws cloudformation wait stack-update-complete --stack-name $StackName --region $Region 2>$null

Write-Host "CloudFormation deployment completed successfully." -ForegroundColor Green
