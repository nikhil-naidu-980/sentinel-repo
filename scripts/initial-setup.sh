#!/bin/bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-west-2}"
PROJECT_NAME="${PROJECT_NAME:-sentinel}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

echo "Checking AWS credentials"
if ! aws sts get-caller-identity &>/dev/null; then
    echo "ERROR: AWS credentials not configured"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Using AWS Account: $ACCOUNT_ID"

S3_BUCKET_NAME="${PROJECT_NAME}-nikhil-tfstate-${ENVIRONMENT}-${ACCOUNT_ID}"

echo "Creating S3 bucket: $S3_BUCKET_NAME"
if aws s3api head-bucket --bucket "$S3_BUCKET_NAME" 2>/dev/null; then
    echo "S3 bucket already exists"
else
    aws s3api create-bucket --bucket "$S3_BUCKET_NAME" --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi

aws s3api put-bucket-versioning --bucket "$S3_BUCKET_NAME" \
    --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "$S3_BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "aws:kms"}, "BucketKeyEnabled": true}]
    }'

aws s3api put-public-access-block --bucket "$S3_BUCKET_NAME" \
    --public-access-block-configuration '{
        "BlockPublicAcls": true, "IgnorePublicAcls": true,
        "BlockPublicPolicy": true, "RestrictPublicBuckets": true
    }'

echo "Setup Complete!"
echo "S3 Bucket: $S3_BUCKET_NAME"

