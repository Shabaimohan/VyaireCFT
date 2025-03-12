Param(
    [Parameter(Mandatory=$true)]
    [string]$Env,

    [Parameter(Mandatory=$true)]
    [string]$Account
)

# Get the script directory
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Define file paths
$TemplateFile = "$ScriptPath\aws-${Account}-deploy.yaml"
$ParameterFile = "$ScriptPath\master_${Env}_parameters.json"
$StackName = "vywus-$Env-messenger-stack"
$Region = "us-east-2"
$ChangeSetName = "changeset-$StackName-$(Get-Date -Format 'yyyyMMddHHmmss')"

# Validate input
if (-not $Env) {
    Write-Host "Usage: .\deploy.ps1 -Env <environment> -Account <account>" -ForegroundColor Red
    exit 1
}

# Check if required files exist
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

    # Wait for stack creation to complete
    Write-Host "Waiting for stack creation to complete..." -ForegroundColor Yellow
    $CreateResult = aws cloudformation wait stack-create-complete --stack-name $StackName --region $Region 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nERROR: Stack creation failed!" -ForegroundColor Red
        Write-Host "AWS CLI Output: $CreateResult" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "CloudFormation stack created successfully." -ForegroundColor Green
} else {
    Write-Host "Creating Change Set: $ChangeSetName for stack: $StackName" -ForegroundColor Cyan

    # Create Change Set
    aws cloudformation create-change-set `
        --stack-name $StackName `
        --template-body "file://$TemplateFile" `
        --parameters "file://$ParameterFile" `
        --region $Region `
        --capabilities CAPABILITY_NAMED_IAM `
        --change-set-name $ChangeSetName

    # Wait for Change Set creation
    Write-Host "Waiting for Change Set to be created..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10

    # Describe Change Set to show modifications
    $ChangeSetStatus = aws cloudformation describe-change-set --change-set-name $ChangeSetName --stack-name $StackName --region $Region --query 'Status' --output text

    if ($ChangeSetStatus -eq "FAILED") {
        Write-Host "No changes detected. Skipping update." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "`nChange Set Details:" -ForegroundColor Cyan
    aws cloudformation describe-change-set --change-set-name $ChangeSetName --stack-name $StackName --region $Region --query 'Changes[*].{Action:ResourceChange.Action, LogicalID:ResourceChange.LogicalResourceId, Type:ResourceChange.ResourceType, Replacement:ResourceChange.Replacement}' --output table

    # Ask for confirmation before executing the change set
    $UserApproval = Read-Host "Do you want to execute the change set? (yes/no)"
    
    if ($UserApproval -eq "yes") {
        Write-Host "Executing Change Set: $ChangeSetName..." -ForegroundColor Cyan
        aws cloudformation execute-change-set --change-set-name $ChangeSetName --stack-name $StackName --region $Region
        
        # Wait for update to complete
        Write-Host "Waiting for stack update to complete..." -ForegroundColor Yellow
        $UpdateResult = aws cloudformation wait stack-update-complete --stack-name $StackName --region $Region 2>&1

        # Check if the update failed
        if ($LASTEXITCODE -ne 0) {
            Write-Host "`nERROR: Stack update failed!" -ForegroundColor Red
            Write-Host "AWS CLI Output: $UpdateResult" -ForegroundColor Yellow

            # Get the latest stack events for debugging
            Write-Host "`nFetching latest CloudFormation stack events..." -ForegroundColor Cyan
            aws cloudformation describe-stack-events --stack-name $StackName --region $Region --query 'StackEvents[0:5].[Timestamp, ResourceStatus, ResourceType, LogicalResourceId, ResourceStatusReason]' --output table
            
            exit 1
        }

        Write-Host "CloudFormation stack updated successfully." -ForegroundColor Green
    } else {
        Write-Host "Change Set execution canceled. No updates were applied." -ForegroundColor Yellow
    }
}
