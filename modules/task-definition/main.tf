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
# TODO: `volume[type=EFS].runtime_platform`
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
      name = volume.value.name

      configure_at_launch = (volume.value.type == "CONFIGURE_AT_LAUNCH"
        ? true
        : false
      )
      host_path = (volume.value.type == "HOST"
        ? volume.value.host.path
        : null
      )

      dynamic "docker_volume_configuration" {
        for_each = (volume.value.type == "DOCKER"
          ? [volume.value.docker]
          : []
        )
        iterator = docker

        content {
          labels = docker.value.labels
          scope  = docker.value.scope
          autoprovision = (docker.value.scope == "shared"
            ? docker.value.autoprovision
            : null
          )
          driver      = docker.value.driver
          driver_opts = docker.value.driver_opts
        }
      }

      dynamic "efs_volume_configuration" {
        for_each = (volume.value.type == "EFS"
          ? [volume.value.efs]
          : []
        )
        iterator = efs

        content {
          file_system_id          = efs.value.file_system
          root_directory          = efs.value.root_directory
          transit_encryption      = efs.value.transit_encryption_enabled ? "ENABLED" : "DISABLED"
          transit_encryption_port = efs.value.transit_encryption_port

          authorization_config {
            iam             = efs.value.authorization.iam_enabled ? "ENABLED" : "DISABLED"
            access_point_id = efs.value.authorization.access_point
          }
        }
      }

      dynamic "fsx_windows_file_server_volume_configuration" {
        for_each = (volume.value.type == "FSX_WINDOWS_FILE_SERVER"
          ? [volume.value.fsx_windows_file_server]
          : []
        )
        iterator = fsx_windows_file_server

        content {
          file_system_id = fsx_windows_file_server.value.file_system
          root_directory = fsx_windows_file_server.value.root_directory

          authorization_config {
            domain                = fsx_windows_file_server.value.authorization.domain
            credentials_parameter = fsx_windows_file_server.value.authorization.credentials_parameter
          }
        }
      }

      dynamic "s3files_volume_configuration" {
        for_each = (volume.value.type == "S3_FILES"
          ? [volume.value.s3_files]
          : []
        )
        iterator = s3files

        content {
          file_system_arn         = s3files.value.file_system
          access_point_arn        = s3files.value.access_point
          root_directory          = s3files.value.root_directory
          transit_encryption_port = s3files.value.transit_encryption_port
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

  lifecycle {
    ignore_changes = [
      container_definitions,
    ]
  }
}
