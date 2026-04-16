output "region" {
  description = "The AWS region this module resources resides in."
  value       = aws_ecs_task_definition.this.region
}

output "id" {
  description = "The ID of the task definition."
  value       = aws_ecs_task_definition.this.id
}

output "arn" {
  description = "The full ARN of the task definition (includes revision)."
  value       = aws_ecs_task_definition.this.arn
}

output "arn_without_revision" {
  description = "The ARN of the task definition without the revision."
  value       = aws_ecs_task_definition.this.arn_without_revision
}

output "name" {
  description = "The family name of the task definition."
  value       = aws_ecs_task_definition.this.family
}

output "revision" {
  description = "The revision number of the task definition."
  value       = aws_ecs_task_definition.this.revision
}

output "runtime" {
  description = <<EOF
  The configuration for the runtime platform for the task.
    `launch_types` - The set of launch types required by the task.
    `os_family` - The operating system family used by the task.
    `cpu_architecture` - The CPU architecture used by the task.
  EOF
  value = {
    launch_types = aws_ecs_task_definition.this.requires_compatibilities
    os_family    = aws_ecs_task_definition.this.runtime_platform[0].operating_system_family
    cpu_arch     = aws_ecs_task_definition.this.runtime_platform[0].cpu_architecture
  }
}

output "placement_constraints" {
  description = "A list of placement constraints for the task definition."
  value = [
    for constraint in aws_ecs_task_definition.this.placement_constraints :
    {
      type       = constraint.type
      expression = constraint.expression
    }
  ]
}

output "resources" {
  description = "The resource requirements for the task."
  value = {
    cpu    = aws_ecs_task_definition.this.cpu
    memory = aws_ecs_task_definition.this.memory
  }
}

output "network_mode" {
  description = "The Docker networking mode to use for the containers in the task."
  value       = aws_ecs_task_definition.this.network_mode
}

output "namespace_sharing" {
  description = "The namespace sharing configuration for the task definition."
  value = {
    pid_mode = var.namespace_sharing.pid_mode
    ipc_mode = var.namespace_sharing.ipc_mode
  }
}

output "task_execution_role" {
  description = <<EOF
  The ARN (Amazon Resource Name) of the task execution role.
  EOF
  value       = aws_ecs_task_definition.this.execution_role_arn
}

output "task_role" {
  description = <<EOF
  The ARN (Amazon Resource Name) of the task role.
  EOF
  value       = aws_ecs_task_definition.this.task_role_arn
}

output "fault_injection" {
  description = "The configuration for the fault injection for the task definition."
  value = {
    enabled = aws_ecs_task_definition.this.enable_fault_injection
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
#     for k, v in aws_ecs_task_definition.this :
#     k => v
#     if !contains(["arn", "tags", "tags_all", "region", "execution_role_arn", "task_role_arn", "id", "arn_without_revision", "family", "revision", "pid_mode", "ipc_mode", "skip_destroy", "runtime_platform", "requires_compatibilities", "cpu", "memory", "enable_fault_injection", "track_latest", "network_mode", "placement_constraints", "proxy_configuration"], k)
#   }
# }
