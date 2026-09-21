provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Configures the OpenSearch provider against the collection endpoint created
# by the opensearch_vectorstore module, authenticating with the same AWS
# credentials Terraform is using (SigV4). NOTE: because this value is only
# known after the collection is created, the very first `terraform apply`
# on a brand-new account may need to be re-run once if it errors out while
# creating the vector index -- this is a well-known one-time ordering quirk
# with OpenSearch Serverless + Terraform, not a bug in this configuration.
provider "opensearch" {
  # aws_opensearchserverless_collection.collection_endpoint already includes
  # the https:// scheme.
  url               = module.opensearch_vectorstore.collection_endpoint
  healthcheck       = false
  sign_aws_requests = true
  aws_region        = var.aws_region
}
