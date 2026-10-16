# Terraform script for deploying n8n on Google Cloud Run (Durable Mode)

This Terraform script provisions the necessary resources to deploy a durable instance of n8n on Google Cloud Run. The script is based on the "Durable mode" instructions in the [official n8n documentation](https://docs.n8n.io/hosting/installation/server-setups/google-cloud-run.html#durable-mode).

## Resources Created

This script will create the following resources in your Google Cloud project:

*   **APIs:**
    *   Cloud Run API
    *   Cloud SQL Admin API
    *   Secret Manager API
*   **Cloud SQL for PostgreSQL:**
    *   A PostgreSQL instance (`db-f1-micro`)
    *   A database named `n8n`
    *   A user named `n8n-user` with a randomly generated password
*   **Secret Manager:**
    *   A secret to store the database password
    *   A secret to store the n8n encryption key (randomly generated)
*   **Service Account:**
    *   A service account for the Cloud Run service
    *   IAM bindings to allow the service account to access the secrets and the Cloud SQL instance
*   **Cloud Run:**
    *   A Cloud Run service that deplodes the latest `n8nio/n8n` container image

## Prerequisites

*   [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) installed on your local machine.
*   A Google Cloud project with billing enabled.
*   The `gcloud` CLI installed and authenticated with your Google Cloud account.

## How to Use

1.  **Clone this repository or download the files.**

2.  **Update `terraform.tfvars`:**
    Open the `terraform.tfvars` file and replace the placeholder values with your actual Google Cloud project ID and your desired region.

    ```hcl
    project_id = "your-gcp-project-id"
    region     = "us-central1"
    ```

3.  **Initialize Terraform:**
    Open a terminal in the directory containing the Terraform files and run:

    ```bash
    terraform init
    ```

4.  **Apply the Terraform configuration:**
    Run the following command to create the resources. You will be prompted to confirm the changes before they are applied.

    ```bash
    terraform apply
    ```

5.  **Access n8n:**
    Once the `apply` command is complete, Terraform will output the URL of your n8n instance. You can use this URL to access your n8n deployment.

## Cleanup

To destroy all the resources created by this Terraform script, run the following command:

```bash
terraform destroy
```