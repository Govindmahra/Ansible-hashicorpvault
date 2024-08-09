#!/bin/bash

# AWS credentials and configuration
AWS_ACCESS_KEY=""
AWS_SECRET_KEY=""
REGION="us-east-1"
OUTPUT_FORMAT="json"

# Update and install necessary packages
echo "Updating package list and installing necessary packages..."
sudo apt update && sudo apt install -y unzip curl

# Download and install AWS CLI
echo "Downloading and installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update

# Check if AWS CLI was installed successfully
if ! command -v aws &> /dev/null; then
  echo "AWS CLI could not be installed"
  exit 1
fi

# Configure AWS CLI with provided credentials and settings
echo "Configuring AWS CLI with provided credentials and settings..."
aws configure set aws_access_key_id "$AWS_ACCESS_KEY"
aws configure set aws_secret_access_key "$AWS_SECRET_KEY"
aws configure set region "$REGION"
aws configure set output "$OUTPUT_FORMAT"

# Clean up
rm -rf awscliv2.zip aws

echo "AWS CLI installed and configured successfully!"
