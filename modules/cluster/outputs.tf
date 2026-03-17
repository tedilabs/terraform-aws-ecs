output "region" {
  description = "The AWS region this module resources resides in."
  value       = aws_ecs_cluster.this.region
}

output "id" {
  description = "The ID of the ECS cluster."
  value       = aws_ecs_cluster.this.id
}

output "arn" {
  description = "The ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "name" {
  description = "The name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "service_connect_defaults" {
  description = "The configuration of Service Connect defaults for the cluster."
  value = {
    namespace = var.service_connect_defaults.namespace
  }
}

output "encryption_at_rest" {
  description = "The encryption at rest configuration for managed storage."
  value = {
    ebs = {
      kms_key = one(aws_ecs_cluster.this.configuration[*].managed_storage_configuration[0].kms_key_id)
    }
    fargate_ephemeral_storage = {
      kms_key = one(aws_ecs_cluster.this.configuration[*].managed_storage_configuration[0].fargate_ephemeral_storage_kms_key_id)
    }
  }
}

output "execute_command" {
  description = "The execute command configuration."
  value = {
    data_channel_encryption = {
      kms_key = one(aws_ecs_cluster.this.configuration[*].execute_command_configuration[0].kms_key_id)
    }
    logging = {
      mode = one(aws_ecs_cluster.this.configuration[*].execute_command_configuration[0].logging)
      cloudwatch_log_group = (one(aws_ecs_cluster.this.configuration[*].execute_command_configuration[0].logging) == "OVERRIDE"
        ? {
          name               = aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].log_configuration[0].cloud_watch_log_group_name
          encryption_enabled = aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].log_configuration[0].cloud_watch_encryption_enabled
        }
        : null
      )
      s3_bucket = (one(aws_ecs_cluster.this.configuration[*].execute_command_configuration[0].logging) == "OVERRIDE"
        ? {
          name               = aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].log_configuration[0].s3_bucket_name
          key_prefix         = aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].log_configuration[0].s3_key_prefix
          encryption_enabled = aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].log_configuration[0].s3_bucket_encryption_enabled
        }
        : null
      )
    }
  }
}

output "container_insights" {
  description = "The Container Insights configuration."
  value = {
    mode = var.container_insights.mode
  }
}

output "capacity_providers" {
  description = "The capacity providers associated with the cluster."
  value       = aws_ecs_cluster_capacity_providers.this.capacity_providers
}

output "default_capacity_provider_strategy" {
  description = "The default capacity provider strategy for the cluster."
  value = {
    for item in aws_ecs_cluster_capacity_providers.this.default_capacity_provider_strategy :
    item.capacity_provider => {
      weight = item.weight
      base   = item.base
    }
  }
}

output "resource_group" {
  description = "The resource group created to manage resources in this module."
  value = merge(
    {
      enabled = var.resource_group.enabled && var.module_tags_enabled
    },
    (var.resource_group.enabled && var.module_tags_enabled
      ? {
        arn  = module.resource_group[0].arn
        name = module.resource_group[0].name
      }
      : {}
    )
  )
}

# output "debug" {
#   description = "Debug output containing all cluster attributes except common ones."
#   value = {
#     for k, v in aws_ecs_cluster.this :
#     k => v
#     if !contains(["arn", "id", "name", "region", "tags", "tags_all", "setting", "service_connect_defaults", "configuration"], k)
#   }
# }
