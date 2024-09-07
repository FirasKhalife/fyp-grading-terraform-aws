# Terraform AWS Instance

This project is a Terraform configuration for provisioning an AWS resources using the AWS provider. It sets up an instance with specific configurations such as key pairs and security groups.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Terraform](https://www.terraform.io/downloads.html) (version X.X.X)
- [AWS CLI](https://aws.amazon.com/cli/)
- An AWS account with proper permissions

## Setup

1. Clone the repository:

    ```bash
    git clone https://github.com/your-username/terraform-aws-instance.git
    cd terraform-aws-instance
    ```

2. Configure AWS credentials if you haven't already:

    ```bash
    aws configure
    ```

3. Initialize the Terraform configuration:

    ```bash
    terraform init
    ```

    This will download the necessary provider plugins, as defined in the `.terraform.lock.hcl` file.

4. (Optional) Modify the `main.tf` file to add the public key to the resource "aws_key_pair" "ssh_key_pair", and adjust settings like instance type, region, etc.

