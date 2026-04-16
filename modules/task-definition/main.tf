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
  pid_mode = {
    "HOST"      = "host"
    "TASK"      = "task"
    "CONTAINER" = null
  }
  ipc_mode = {
    "HOST"      = "host"
    "TASK"      = "task"
    "CONTAINER" = "none"
    "INHERIT"   = null
  }
}


###################################################
# ECS Task Definition
###################################################

# TODO: `container_definitions`
# TODO: `ephemeral_storage`
# TODO: `volume`
# INFO: Deprecated attributes
# - `proxy_configuration`
resource "aws_ecs_task_definition" "this" {
  region = var.region

  family       = var.name
  skip_destroy = var.skip_destroy
  track_latest = true

  container_definitions = var.container_definitions


  ## Runtime
  requires_compatibilities = var.runtime.launch_types

  dynamic "runtime_platform" {
    for_each = [var.runtime]
    iterator = runtime

    content {
      operating_system_family = runtime.value.os_family
      cpu_architecture        = runtime.value.cpu_arch
    }
  }

  dynamic "placement_constraints" {
    for_each = var.placement_constraints
    iterator = constraint

    content {
      type       = constraint.value.type
      expression = constraint.value.expression
    }
  }


  ## Resources
  cpu    = var.resources.cpu
  memory = var.resources.memory

  network_mode = var.network_mode

  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_size > 21 ? ["go"] : []

    content {
      size_in_gib = var.ephemeral_storage_size
    }
  }

  dynamic "volume" {
    for_each = var.volumes

    content {
      name      = volume.value.name
      host_path = volume.value.host_path

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs_volume != null ? [volume.value.efs_volume] : []

        content {
          file_system_id          = efs_volume_configuration.value.file_system
          root_directory          = efs_volume_configuration.value.root_directory
          transit_encryption      = efs_volume_configuration.value.transit_encryption_enabled ? "ENABLED" : "DISABLED"
          transit_encryption_port = efs_volume_configuration.value.transit_encryption_port

          dynamic "authorization_config" {
            for_each = efs_volume_configuration.value.iam_authorization_enabled ? ["go"] : []

            content {
              iam             = "ENABLED"
              access_point_id = efs_volume_configuration.value.access_point
            }
          }
        }
      }
    }
  }


  ## Namespace Sharing
  pid_mode = local.pid_mode[var.namespace_sharing.pid_mode]
  ipc_mode = local.ipc_mode[var.namespace_sharing.ipc_mode]


  ## Permissions
  execution_role_arn = (var.default_task_execution_role.enabled
    ? module.role__task_execution[0].arn
    : var.task_execution_role
  )
  task_role_arn = (var.default_task_role.enabled
    ? module.role__task[0].arn
    : var.task_role
  )


  ## Misc
  enable_fault_injection = var.fault_injection.enabled


  tags = merge(
    {
      "Name" = local.metadata.name
    },
    local.module_tags,
    var.tags,
  )
}
