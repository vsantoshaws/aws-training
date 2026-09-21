data "aws_caller_identity" "current" {}

# Resolves an assumed-role session ARN back to the underlying IAM role ARN,
# since OpenSearch Serverless access policies must reference the role/user
# ARN, not the transient STS session ARN.
data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

locals {
  data_access_principals = distinct(concat(
    [data.aws_iam_session_context.current.issuer_arn],
    var.additional_data_access_principal_arns
  ))
}

resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "${var.collection_name}-enc"
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.collection_name}"]
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name = "${var.collection_name}-net"
  type = "network"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.collection_name}"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${var.collection_name}"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_access_policy" "data" {
  name = "${var.collection_name}-data"
  type = "data"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.collection_name}"]
          Permission   = ["aoss:*"]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${var.collection_name}/*"]
          Permission   = ["aoss:*"]
        }
      ]
      Principal = local.data_access_principals
    }
  ])
}

resource "aws_opensearchserverless_collection" "kb" {
  name = var.collection_name
  type = "VECTORSEARCH"

  tags = merge(var.tags, {
    Name = var.collection_name
  })

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.data,
  ]
}

# OpenSearch Serverless data-access-policy propagation and collection
# activation both take a little time; give both a head start before the
# opensearch provider tries to authenticate and create the vector index.
resource "time_sleep" "wait_for_collection" {
  depends_on      = [aws_opensearchserverless_collection.kb]
  create_duration = "60s"
}

resource "opensearch_index" "vector_index" {
  name                           = var.vector_index_name
  number_of_shards               = "2"
  number_of_replicas             = "0"
  index_knn                      = true
  index_knn_algo_param_ef_search = "512"

  mappings = jsonencode({
    properties = {
      (var.vector_field_name) = {
        type      = "knn_vector"
        dimension = var.vector_dimension
        method = {
          name       = "hnsw"
          engine     = "faiss"
          space_type = "l2"
        }
      }
      (var.text_field_name) = {
        type = "text"
      }
      (var.metadata_field_name) = {
        type  = "text"
        index = false
      }
    }
  })

  force_destroy = true

  depends_on = [time_sleep.wait_for_collection]
}
