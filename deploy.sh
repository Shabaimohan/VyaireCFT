#!/bin/bash

# Parameters
ENV="$1"
STACK_NAME="vywus-$ENV-messenger-stack"
TEMPLATE_FILE="./lambda.yaml"
PARAMETER_FILE="./parameters.json"
REGION="us-east-1"

# Validate input
if [ -z "$ENV" ]; then
    echo "Usage: $0 <environment>"
    exit 1
fi

# Set AWS Profile (if needed)
# export AWS_PROFILE=my-aws-profile

# Check if the stack exists
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].StackStatus' --output text 2>/dev/null)

if [ "$STACK_STATUS" == "None" ]; then
    echo "Creating new CloudFormation stack: $STACK_NAME"
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --parameters "file://$PARAMETER_FILE" \
        --region "$REGION" \
        --capabilities CAPABILITY_NAMED_IAM
else
    echo "Updating existing CloudFormation stack: $STACK_NAME"
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --parameters "file://$PARAMETER_FILE" \
        --region "$REGION" \
        --capabilities CAPABILITY_NAMED_IAM
fi

# Wait for the deployment to complete
echo "Waiting for stack operation to complete..."
aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION" 2>/dev/null || \
aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$REGION" 2>/dev/null

echo "CloudFormation deployment completed successfully."
