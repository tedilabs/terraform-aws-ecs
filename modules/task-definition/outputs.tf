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

locals {
  volumes = [
    for volume in aws_ecs_task_definition.this.volume :
    merge(volume, {
      type = (volume.configure_at_launch
        ? "CONFIGURE_AT_LAUNCH"
        : (length(volume.docker_volume_configuration) > 0
          ? "DOCKER"
          : (length(volume.efs_volume_configuration) > 0
            ? "EFS"
            : (length(volume.fsx_windows_file_server_volume_configuration) > 0
              ? "FSX_WINDOWS_FILE_SERVER"
              : (length(volume.s3files_volume_configuration) > 0
                ? "S3_FILES"
                : "HOST"
              )
            )
          )
        )
      )
    })
  ]
}
output "volumes" {
  description = "The list of data volumes that can be used by containers in the task definition."
  value = {
    for volume in local.volumes :
    volume.name => merge(
      {
        name = volume.name
        type = volume.type
      },
      (volume.type == "HOST"
        ? {
          host = {
            path = volume.host_path
          }
        }
        : {}
      ),
      (volume.type == "DOCKER"
        ? {
          docker = {
            labels        = volume.docker_volume_configuration[0].labels
            scope         = volume.docker_volume_configuration[0].scope
            autoprovision = volume.docker_volume_configuration[0].autoprovision
            driver        = volume.docker_volume_configuration[0].driver
            driver_opts   = volume.docker_volume_configuration[0].driver_opts
          }
        }
        : {}
      ),
      (volume.type == "EFS"
        ? {
          efs = {
            file_system             = volume.efs_volume_configuration[0].file_system_id
            root_directory          = volume.efs_volume_configuration[0].root_directory
            transit_encryption      = volume.efs_volume_configuration[0].transit_encryption ? "ENABLED" : "DISABLED"
            transit_encryption_port = volume.efs_volume_configuration[0].transit_encryption_port
            authorization = {
              iam_enabled  = volume.efs_volume_configuration[0].authorization_config[0].iam == "ENABLED"
              access_point = volume.efs_volume_configuration[0].authorization_config[0].access_point_id
            }
          }
        }
        : {}
      ),
      (volume.type == "FSX_WINDOWS_FILE_SERVER"
        ? {
          fsx_windows_file_server = {
            file_system    = volume.fsx_windows_file_server_volume_configuration[0].file_system_id
            root_directory = volume.fsx_windows_file_server_volume_configuration[0].root_directory
            authorization = {
              domain                = volume.fsx_windows_file_server_volume_configuration[0].authorization[0].domain
              credentials_parameter = volume.fsx_windows_file_server_volume_configuration[0].authorization[0].credentials_parameter
            }
          }
        }
        : {}
      ),
      (volume.type == "S3_FILES"
        ? {
          s3_files = {
            file_system             = volume.s3files_volume_configuration[0].file_system_arn
            access_point            = volume.s3files_volume_configuration[0].access_point_arn
            root_directory          = volume.s3files_volume_configuration[0].root_directory
            transit_encryption_port = volume.s3files_volume_configuration[0].transit_encryption_port
          }
        }
        : {}
      ),
    )
  }
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
