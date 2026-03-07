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

output "container_insights" {
  description = "The Container Insights configuration."
  value = {
    mode = var.container_insights.mode
  }
}

output "execute_command" {
  description = "The execute command configuration."
  value = {
    logging            = var.execute_command.logging
    encryption_kms_key = var.execute_command.encryption_kms_key
  }
}

output "managed_storage_encryption" {
  description = "The managed storage encryption configuration."
  value = {
    enabled = var.managed_storage_encryption.enabled
    kms_key = var.managed_storage_encryption.kms_key
  }
}

output "capacity_providers" {
  description = "The list of capacity providers associated with the cluster."
  value       = local.capacity_providers
}

output "default_capacity_provider_strategy" {
  description = "The default capacity provider strategy for the cluster."
  value       = var.default_capacity_provider_strategy
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

output "debug" {
  value = {
    for k, v in aws_ecs_cluster.this :
    k => v
    if !contains(["arn", "id", "name", "region", "tags", "tags_all", "setting", "service_connect_defaults"], k)
  }
}
