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
      fargate_ephemeral_storage_kms_key_id = (var.managed_storage_encryption.enabled
        ? var.managed_storage_encryption.kms_key
        : null
      )
    }

    execute_command_configuration {
      kms_key_id = var.execute_command.encryption_kms_key
      logging    = var.execute_command.logging

      dynamic "log_configuration" {
        for_each = var.execute_command.logging == "OVERRIDE" ? ["go"] : []

        content {
          cloud_watch_log_group_name     = var.execute_command.cloudwatch_log_group
          cloud_watch_encryption_enabled = var.execute_command.cloudwatch_encryption_enabled
          s3_bucket_name                 = var.execute_command.s3_bucket
          s3_key_prefix                  = var.execute_command.s3_key_prefix
          s3_bucket_encryption_enabled   = var.execute_command.s3_encryption_enabled
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
