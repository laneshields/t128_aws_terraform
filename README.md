### Sample 128T AWS Terraform Repository ###
This repository contains terraform scripts used to build:
* A VPC with  4 subnets across two availability zones (1 each internal and external)
* An Internet Gateway for the VPC
* A 128T Router instance in each AZ connected to both the external and internal subnet.  Note that this uses the 128T Router 100M AMI available in the Marketplace by default (not a BYOL instance)
* A Server in each AZ connected to the internal subnet
* An Elastic IP for each 128T external IP
* A route tables and routing setup to allow internal subnets a default route to their respective 128T and the 128Ts a route to the Internet through the Internet gateway

## What is needed to run this demo ##
1) An AWS account setup with access keys.  To enable this, log in to the Amazon web console, go to the IAM service, select users, and click on your username.  In the next window, click the security credentials tab, click on create access key.  In the popup either download the CSV or show your access key and save the values somewhere.
2) An existing 128T conductor to orchestrate configuration.  At the moment, this setup does not push configuration for the rotuers, but it will redirect the salt minions to the conductor to appear as available assets

## Configuration ##
There are several configurable options.  Some require an option and some have defaults set.  The values for these options should be placed in a file named terraform.tfvars in this directory.  

This example shows the bare minimum required contents of this file:
```
aws_access_key = "****************"
aws_secret_key = "****************"
key_name = "my_aws_keypair"
conductor_address = "X.X.X.X"
```

### Variable Options ###
# Use the values provided from the AWS console
* aws_access_key - The access key provided by the AWS console
* aws_secret_key - The secret key provided by the AWS console
* key_name - The name of the SSH keypair to use to login to the instances

* aws_region - The AWS Region to deploy in.  Defaults to "us-east-1"
* aws_az1 - The ID for the primary Availability Zone to use.  This is in the format as reported for ZoneId in the output of the awsc CLI command describe-availability-zones.  Defaults to "use1-az1"
* aws_az2 - The ID for the secondary Availability Zone to use.  This is in the format as reported for ZoneId in the output of the awsc CLI command describe-availability-zones.  Defaults to "use1-az2"
* vpc_cidr_range - The CIDR Range to configure as allowable for the VPC.  Defaults to "10.0.0.0/16"
* az1_external_subnet - The CIDR Range to use for the AZ1 external subnet.  Defaults to "10.0.0.0/24"
* az2_external_subnet - The CIDR Range to use for the AZ2 external subnet.  Defaults to "10.0.1.0/24"
* az1_internal_subnet - The CIDR Range to use for the AZ1 internal subnet.  Defaults to "10.0.2.0/24"
* az2_internal_subnet - The CIDR Range to use for the AZ2 internal subnet.  Defaults to "10.0.3.0/24"
* t128_flavor - The flavor to use for the 128T AMI.  Must be valid for the AMI.  Defaults to "c5.xlarge"
* server_flavor - The flavor to use for the server AMI.  Defaults to "t3.micro"

## Initialization ##
Before the script is run for the first time, you need to install all relevant Terraform modules.  Do this by running `terraform init`

## Build ##
To build the environment in AWS and apply the relevant config on the Conductor, run `terraform apply`

## Destroy ##
To destroy the environment in AWS and delete the configuration from Conductor, run `terraform destroy`
