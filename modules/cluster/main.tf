locals {
  metadata = {
    package = "terraform-aws-ecs"
    version = trimspace(file("${path.module}/../../VERSION"))
    module  = basename(path.module)
    name    = var.name
  }
  module_tags = var.module_tags_enabled ? {
    "module.terraform.io/package"   = local.metadata.package
    "module.terraform.io/version"   = local.metadata.version
    "module.terraform.io/name"      = local.metadata.module
    "module.terraform.io/full-name" = "${local.metadata.package}/${local.metadata.module}"
    "module.terraform.io/instance"  = local.metadata.name
  } : {}
}

locals {
  container_insights_mode = {
    "ENABLED"  = "enabled"
    "ENHANCED" = "enhanced"
    "DISABLED" = "disabled"
  }

  capacity_providers = concat(
    var.fargate_capacity_providers.fargate_enabled ? ["FARGATE"] : [],
    var.fargate_capacity_providers.fargate_spot_enabled ? ["FARGATE_SPOT"] : [],
    var.managed_capacity_providers,
  )
}


###################################################
# ECS Cluster
###################################################

resource "aws_ecs_cluster" "this" {
  region = var.region

  name = var.name


  ## Service Connect
  dynamic "service_connect_defaults" {
    for_each = var.service_connect_defaults.namespace != null ? [var.service_connect_defaults] : []

    content {
      namespace = service_connect_defaults.value.namespace
    }
  }

  configuration {
    managed_storage_configuration {
      kms_key_id                           = var.encryption_at_rest.ebs.kms_key
      fargate_ephemeral_storage_kms_key_id = var.encryption_at_rest.fargate_ephemeral_storage.kms_key
    }

    dynamic "execute_command_configuration" {
      for_each = [var.execute_command]
      iterator = exec

      content {
        kms_key_id = exec.value.data_channel_encryption.kms_key
        logging    = exec.value.logging.mode

        dynamic "log_configuration" {
          for_each = exec.value.logging.mode == "OVERRIDE" ? [exec.value.logging] : []
          iterator = logging

          content {
            cloud_watch_log_group_name     = logging.value.cloudwatch_log_group.name
            cloud_watch_encryption_enabled = logging.value.cloudwatch_log_group.encryption_enabled

            s3_bucket_name               = logging.value.s3_bucket.name
            s3_key_prefix                = logging.value.s3_bucket.key_prefix
            s3_bucket_encryption_enabled = logging.value.s3_bucket.encryption_enabled
          }
        }
      }
    }
  }


  ## Container Insights
  setting {
    name  = "containerInsights"
    value = local.container_insights_mode[var.container_insights.mode]
  }


  tags = merge(
    {
      "Name" = local.metadata.name
    },
    local.module_tags,
    var.tags,
  )
}


###################################################
# Capacity Providers
###################################################

resource "aws_ecs_cluster_capacity_providers" "this" {
  region = var.region

  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = local.capacity_providers

  dynamic "default_capacity_provider_strategy" {
    for_each = var.default_capacity_provider_strategy

    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      weight            = default_capacity_provider_strategy.value.weight
      base              = default_capacity_provider_strategy.value.base
    }
  }
}
