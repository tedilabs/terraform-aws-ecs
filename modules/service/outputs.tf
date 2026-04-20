output "region" {
  description = "The AWS region this module resources resides in."
  value       = aws_ecs_service.this.region
}

output "id" {
  description = "The ID of the ECS service."
  value       = aws_ecs_service.this.id
}

output "arn" {
  description = "The ARN of the ECS service."
  value       = aws_ecs_service.this.arn
}

output "name" {
  description = "The name of the ECS service."
  value       = aws_ecs_service.this.name
}

output "cluster" {
  description = "The ARN of the ECS cluster that hosts the service."
  value       = aws_ecs_service.this.cluster
}

output "task_definition" {
  description = "The task definition of the service."
  value       = aws_ecs_service.this.task_definition
}

output "task_tags_propagation" {
  description = <<EOF
  The configuration for task tags propagation of the service.
    `source` - The source of the tags to propagate.
    `ecs_managed_tags_enabled` - Whether ECS managed tags are enabled for the service.
  EOF
  value = {
    source                   = aws_ecs_service.this.propagate_tags
    ecs_managed_tags_enabled = aws_ecs_service.this.enable_ecs_managed_tags
  }
}

output "scheduling_strategy" {
  description = "The scheduling strategy to use for the service."
  value       = aws_ecs_service.this.scheduling_strategy
}

output "desired_count" {
  description = "The number of instances of the task definition."
  value       = aws_ecs_service.this.desired_count
}

output "runtime" {
  description = <<EOF
  The configuration for the runtime platform of the service.
  EOF
  value = {
    launch_type = aws_ecs_service.this.launch_type
    fargate = (aws_ecs_service.this.launch_type == "FARGATE"
      ? {
        platform_version = aws_ecs_service.this.platform_version
      }
      : null
    )
    capacity_provider_strategy = (var.runtime.launch_type == "CAPACITY_PROVIDER_STRATEGY"
      ? {
        for strategy in aws_ecs_service.this.capacity_provider_strategy :
        strategy.capacity_provider => {
          weight = strategy.weight
          base   = strategy.base
        }
      }
      : null
    )
  }
}

output "placement_constraints" {
  description = "A list of placement constraints for the service."
  value = [
    for constraint in aws_ecs_service.this.placement_constraints :
    {
      type       = constraint.type
      expression = constraint.expression
    }
  ]
}

output "execute_command" {
  description = <<EOF
  The configuration for the execute command functionality (ECS Exec) of the service.
    `enabled` - Whether ECS Exec is enabled for the service.
  EOF
  value = {
    enabled = aws_ecs_service.this.enable_execute_command
  }
}

output "deployment" {
  description = "The deployment configuration of the ECS service."
  value = {
    controller_type                       = aws_ecs_service.this.deployment_controller[0].type
    availability_zone_rebalancing_enabled = aws_ecs_service.this.availability_zone_rebalancing == "ENABLED"
    min_healthy_percent                   = var.deployment.min_healthy_percent
    max_percent                           = var.deployment.max_percent
    failure_detection = {
      circuit_breaker = {
        enabled             = aws_ecs_service.this.deployment_circuit_breaker[0].enable
        rollback_on_failure = aws_ecs_service.this.deployment_circuit_breaker[0].rollback
      }
      cloudwatch_alarms = {
        enabled = var.deployment.failure_detection.cloudwatch_alarms.enabled
        alarm_names = (var.deployment.failure_detection.cloudwatch_alarms.enabled
          ? aws_ecs_service.this.alarms[0].alarm_names
          : []
        )
        rollback_on_failure = (var.deployment.failure_detection.cloudwatch_alarms.enabled
          ? aws_ecs_service.this.alarms[0].rollback
          : null
        )
      }
    }
  }
}

output "network_configuration" {
  description = "The network configuration of the service."
  value = (one(aws_ecs_service.this.network_configuration) != null
    ? {
      subnets                              = aws_ecs_service.this.network_configuration[0].subnets
      security_groups                      = aws_ecs_service.this.network_configuration[0].security_groups
      public_ip_address_assignment_enabled = aws_ecs_service.this.network_configuration[0].assign_public_ip
    }
    : null
  )
}

output "load_balancers" {
  description = "The load balancer configurations of the service."
  value       = var.load_balancers
}

output "auto_scaling" {
  description = "The auto scaling configuration of the service."
  value = {
    enabled   = var.auto_scaling.enabled
    min_count = var.auto_scaling.min_count
    max_count = var.auto_scaling.max_count
    target_tracking_policies = [
      for policy in var.auto_scaling.target_tracking_policies : {
        name         = policy.name
        metric       = policy.metric
        target_value = policy.target_value
      }
    ]
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
#   value = {
#     for k, v in aws_ecs_service.this :
#     k => v
#     if !contains(["arn", "id", "tags", "name", "region", "tags_all", "timeouts", "force_delete", "force_new_deployment", "launch_type", "platform_version", "enable_execute_command", "enable_ecs_managed_tags", "propagate_tags", "cluster", "scheduling_strategy", "desired_count", "wait_for_steady_state", "capacity_provider_strategy", "network_configuration", "deployment_circuit_breaker", "alarms", "placement_constraints", "deployment_controller"], k)
#   }
# }
