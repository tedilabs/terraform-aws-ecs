variable "region" {
  description = "(Optional) The region in which to create the module resources. If not provided, the module resources will be created in the provider's configured region."
  type        = string
  default     = null
  nullable    = true
}

variable "name" {
  description = "(Required) A unique name for your task definition. It can used to track multiple versions of the same task definition."
  type        = string
  nullable    = false
}

variable "skip_destroy" {
  description = "(Optional) Whether to skip destroying the task definition. Defaults to `false`. If `true`, the task definition will be deregistered but not deleted, and can be re-registered later. If `false`, the task definition will be deleted and cannot be re-registered."
  type        = bool
  default     = true
  nullable    = false
}

variable "runtime" {
  description = <<EOF
  (Optional) A configuration for the runtime platform of the task definition. `runtime` as defined below.
    (Optional) `launch_types` - A set of launch types that Amazon ECS validates the task definition against. A client exception is returned if the task definition doesn't validate against the compatibilities specified. Valid values are `EC2`, `FARGATE`, `EXTERNAL` and `MANAGED_INSTANCES`. Defaults to `["EC2"]`.
      `EC2` — Run tasks on self-managed EC2 instances registered to the cluster.
      `FARGATE` — Run tasks on AWS-managed serverless compute with no infrastructure to provision or manage.
      `EXTERNAL` — Run tasks on on-premises or non-AWS infrastructure registered via ECS Anywhere.
      `MANAGED_INSTANCES` — Run tasks on AWS-managed EC2 instances that combine Fargate's operational simplicity with EC2's flexibility (e.g., GPU, specific instance types).
    (Optional) `os_family` - The operating system family. Valid values are `LINUX`, `WINDOWS_SERVER_2004_CORE`, `WINDOWS_SERVER_2016_FULL`, `WINDOWS_SERVER_2019_FULL`, `WINDOWS_SERVER_2019_CORE`, `WINDOWS_SERVER_2022_FULL`, `WINDOWS_SERVER_2022_CORE`, `WINDOWS_SERVER_2025_FULL`, `WINDOWS_SERVER_2025_CORE`, `WINDOWS_SERVER_20H2_CORE`. Defaults to `LINUX`.
    (Optional) `cpu_arch` - The CPU architecture. Valid values are `X86_64`, `ARM64`. Defaults to `X86_64`.
  EOF
  type = object({
    launch_types = optional(set(string), ["EC2"])
    os_family    = optional(string, "LINUX")
    cpu_arch     = optional(string, "X86_64")
  })
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for launch_type in var.runtime.launch_types :
      contains(["EC2", "FARGATE", "EXTERNAL", "MANAGED_INSTANCES"], launch_type)
    ])
    error_message = "Valid values for `runtime.launch_types` are `EC2`, `FARGATE`, `EXTERNAL`, `MANAGED_INSTANCES`."
  }
  validation {
    condition     = contains(["LINUX", "WINDOWS_SERVER_2004_CORE", "WINDOWS_SERVER_2016_FULL", "WINDOWS_SERVER_2019_FULL", "WINDOWS_SERVER_2019_CORE", "WINDOWS_SERVER_2022_FULL", "WINDOWS_SERVER_2022_CORE", "WINDOWS_SERVER_2025_FULL", "WINDOWS_SERVER_2025_CORE", "WINDOWS_SERVER_20H2_CORE"], var.runtime.os_family)
    error_message = "Valid values for `runtime.os_family` are `LINUX`, `WINDOWS_SERVER_2004_CORE`, `WINDOWS_SERVER_2016_FULL`, `WINDOWS_SERVER_2019_FULL`, `WINDOWS_SERVER_2019_CORE`, `WINDOWS_SERVER_2022_FULL`, `WINDOWS_SERVER_2022_CORE`, `WINDOWS_SERVER_2025_FULL`, `WINDOWS_SERVER_2025_CORE`, `WINDOWS_SERVER_20H2_CORE`."
  }
  validation {
    condition     = contains(["X86_64", "ARM64"], var.runtime.cpu_arch)
    error_message = "Valid values for `runtime.cpu_arch` are `X86_64`, `ARM64`."
  }
}

variable "placement_constraints" {
  description = <<EOF
  (Optional) A list of placement constraints for the task definition. You can use constraints to place tasks based on member attributes. Maximum number of `placement_constraints` is `10`. Each item of `placement_constraints` as defined below.
    (Optional) `type` - The type of constraint. Use `memberOf` to restrict the selection to a group of valid candidates. Deefaults to `memberOf`. Note that `distinctInstance` is not supported in task definitions.
    (Reuiqred) `expression` - The Cluster Query Language expression to apply to the constraint.
  EOF
  type = list(object({
    type       = optional(string, "memberOf")
    expression = string
  }))
  default  = []
  nullable = false

  validation {
    condition     = length(var.placement_constraints) <= 10
    error_message = "Maximum number of `placement_constraints` is `10`."
  }
  validation {
    condition = alltrue([
      for constraint in var.placement_constraints :
      contains(["memberOf"], constraint.type)
    ])
    error_message = "Valid values for `type` in `placement_constraints` are `memberOf`."
  }
}

variable "resources" {
  description = <<EOF
  (Optional) A configuration for the resource requirements of the task. NOTE: Task-level CPU and memory parameters are ignored for Windows containers. We recommend specifying container-level resources for Windows containers. `resources` as defined below.
    (Optional) `cpu` - The number of cpu units used by the task.  It can be expressed as an integer using CPU units (for example, `1024`) or as a string using vCPUs (for example, `1 vCPU` or `1 vcpu`) in a task definition. If you're using the EC2 launch type or external launch type, this field is optional. Supported values are between 128 CPU units (0.125 vCPUs) and 196608 CPU units (192 vCPUs). If you do not specify a value, the parameter is ignored. This field is required for Fargate.
    - The CPU units cannot be less than 1 vCPU when you use Windows containers on Fargate.
    (Optional) `memory` - The amount of memory (in MiB) used by the task. It can be expressed as an integer using MiB (for example ,`1024`) or as a string using GB (for example, `1GB` or `1 GB`) in a task definition. If using the EC2 launch type, this field is optional.
  EOF
  type = object({
    cpu    = optional(string)
    memory = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition = anytrue([
      !contains(var.runtime.launch_types, "FARGATE"),
      contains(var.runtime.launch_types, "FARGATE") && var.resources.cpu != null && var.resources.memory != null,
    ])
    error_message = "When `runtime.launch_types` includes `FARGATE`, both `resources.cpu` and `resources.memory` are required."
  }
}

variable "network_mode" {
  description = <<EOF
  (Optional) The Docker networking type of the containers in the task use. Valid values are `awsvpc`, `bridge`, `host`, `none`. Defaults to `awsvpc`.

    `awsvpc` - The task with an elastic network interface (ENI). When creating a service or running a task with this network mode you must specify a network configuration consisting of one or more subnets, security groups, and whether to assign the task a public IP address.

    `bridge` - Use Docker's built-in virtual network, which runs inside each Amazon EC2 instance hosting the task. The bridge is an internal network namespace that allows each container connected to the same bridge network to communicate with each other. It provides an isolation boundary from containers that aren't connected to the same bridge network. You use static or dynamic port mappings to map ports in the container with ports on the Amazon EC2 host. If you choose bridge for the network mode, under Port mappings, for Host port, specify the port number on the container instance to reserve for your container.

    `host` - The task bypass Docker's built-in virtual network and maps container ports directly to the ENI of the Amazon EC2 instance hosting the task. As a result, you can't run multiple instantiations of the same task on a single Amazon EC2 instance when port mappings are used.

    `none` - The task with no external network connectivity.
  EOF
  type        = string
  default     = "awsvpc"
  nullable    = false

  validation {
    condition     = contains(["awsvpc", "bridge", "host", "none"], var.network_mode)
    error_message = "Valid values for `network_mode` are `awsvpc`, `bridge`, `host`, `none`."
  }
}

variable "ephemeral_storage_size" {
  description = "(Optional) The total amount (in GiB) of ephemeral storage to set for the task. The minimum supported value is `21` GiB and the maximum supported value is `200` GiB. Only supported when `runtime.launch_types` includes `FARGATE`. Defaults to `21`."
  type        = number
  default     = 21
  nullable    = false

  validation {
    condition     = var.ephemeral_storage_size >= 21 && var.ephemeral_storage_size <= 200
    error_message = "Valid value for `ephemeral_storage_size` is between 21 and 200."
  }
}

variable "volumes" {
  description = <<EOF
  (Optional) A list of volume configurations for tasks launched using this task definition. Only one volume configured at launch si supported. Each item of `volumes` as defined below.
    (Required) `name` - The name of the volume. Up to 255 letters (uppercase and lowercase), numbers, underscores, and hyphens are allowed.
    (Optional) `type` - A source type for the volume. Valid values are `CONFIGURE_AT_LAUNCH`, `HOST`, `DOCKER`, `EFS`, `FSX_WINDOWS_FILE_SERVER` and `S3_FILES`. Defaults to `HOST`.
    (Optional) `host` - The host volume configuration. `host` as defined below.
      (Optional) `path` - The path on the host container instance that is presented to the container. If not set, ECS will create a nonpersistent data volume that starts empty and is deleted after the task has finished.
    (Optional) `docker` - The Docker volume configuration. `docker` as defined below.
      (Optional) `labels` - A map of custom metadata to add to the Docker volume. Defaults to `{}`.
      (Optional) `scope` - The scope for the Docker volume that determines its lifecycle. Valid values are `task` and `shared`. Defaults to `task`.
        `task` - The Docker volume is automatically provisioned when the task starts and destroyed when the task stops.
        `shared` - The Docker volume persists after the task stops.
      (Optional) `autoprovision` - Whether to automatically provision the Docker volume. If `true`, the Docker volume is automatically provisioned when the task starts. If `false`, the Docker volume must already exist when the task starts. Only used when `scope` is `shared`. Defaults to `true`.
      (Optional) `driver` - The Docker volume driver to use. The driver value must match the driver name provided by Docker because it is used for task placement.
      (Optional) `driver_opts` - A map of Docker driver-specific options. This is used to specify parameters for the driver.
    (Optional) `efs` - The EFS volume configuration. `efs` as defined below.
      (Required) `file_system` - The ID of the EFS file system.
      (Optional) `root_directory` - The directory within the EFS file system to mount as the root directory. Defaults to `/`.
      (Optional) `transit_encryption_enabled` - Whether to use encryption in transit between the ECS host and the EFS file system. Transit encryption must be truned on if EFS IAM Authorization is used. Defaults to `false`.
      (Optional) `transit_encryption_port` - The port to use when sending encrypted data between the Amazon ECS host and the Amazon EFS server. If you do not specify a transit encryption port, it will use the port selection strategy that the Amazon EFS mount helper uses.
      (Optional) `authorization` - The authorization configuration for the EFS volume. `authorization` as defined below.
        (Optional) `iam_enabled` - Whether to use the Amazon ECS task role defined in a task definition when mounting the Amazon EFS file system. If it is turned on, transit encryption must be turned on in the EFSVolumeConfiguration. Defaults to `false`.
        (Optional) `access_point` - The Amazon EFS access point ID to use.
    (Optional) `fsx_windows_file_server` - The FSx for Windows File Server volume configuration. `fsx_windows_file_server` as defined below.
      (Required) `file_system` - The ID of the FSx for Windows File Server file system to use.
      (Required) `root_directory` - The directory within the Amazon FSx for Windows File Server file system to mount as the root directory inside the host.
      (Required) `authorization` - The authorization configuration for the FSx for Windows File Server volume. `authorization` as defined below.
        (Required) `domain` - A fully qualified domain name hosted by an AWS Directory Service Managed Microsoft AD (Active Directory) or self-hosted AD on Amazon EC2.
        (Required) `credentials_parameter` - The authorization credential option to use. The authorization credential options can be provided using either the Amazon Resource Name (ARN) of an AWS Secrets Manager secret or AWS Systems Manager Parameter Store parameter. The ARNs refer to the stored credentials.
    (Optional) `s3_files` - The S3 Files volume configuration. `s3_files` as defined below.
      (Required) `file_system` - The ARN of the S3 Files file system to mount.
      (Optional) `access_point` - The ARN of the S3 Files access point to use.
      (Optional) `root_directory` - The directory within the Amazon S3 Files file system to mount as the root directory. Defaults to `/`.
      (Optional) `transit_encryption_port` - The port to use for sending encrypted data between the ECS host and the S3 Files file system. If you do not specify a transit encryption port, it will use the port selection strategy that the Amazon S3 Files mount helper uses.
  EOF
  type = list(object({
    name = string
    type = optional(string, "HOST")
    host = optional(object({
      path = optional(string)
    }), {})
    docker = optional(object({
      labels        = optional(map(string), {})
      scope         = optional(string, "task")
      autoprovision = optional(bool, true)
      driver        = optional(string)
      driver_opts   = optional(map(string), {})
    }), {})
    efs = optional(object({
      file_system                = string
      root_directory             = optional(string, "/")
      transit_encryption_enabled = optional(bool, false)
      transit_encryption_port    = optional(number)
      authorization = optional(object({
        iam_enabled  = optional(bool, false)
        access_point = optional(string)
      }), {})
    }))
    fsx_windows_file_server = optional(object({
      file_system    = string
      root_directory = string
      authorizeion = object({
        domain                = string
        credentials_parameter = string
      })
    }))
    s3_files = optional(object({
      file_system             = string
      access_point            = optional(string)
      root_directory          = optional(string, "/")
      transit_encryption_port = optional(number)
    }))
  }))
  default  = []
  nullable = false

  validation {
    condition = alltrue([
      for volume in var.volumes :
      contains(["CONFIGURE_AT_LAUNCH", "HOST", "DOCKER", "EFS", "FSX_WINDOWS_FILE_SERVER", "S3_FILES"], volume.type)
    ])
    error_message = "Valid values for `type` in `volumes` are `CONFIGURE_AT_LAUNCH`, `HOST`, `DOCKER`, `EFS`, `FSX_WINDOWS_FILE_SERVER`, `S3_FILES`."
  }
  validation {
    condition = alltrue([
      for volume in var.volumes :
      contains(["task", "shared"], volume.docker.scope)
      if volume.type == "DOCKER"
    ])
    error_message = "Valid values for `docker.scope` in `volumes` are `task`, `shared`."
  }
}

variable "namespace_sharing" {
  description = <<EOF
  (Optional) A configuration for namespace sharing. `namespace_sharing` as defined below.
    (Optional) `pid_mode` - The process namespace to use for the containers in the task. Valid values are `HOST`, `TASK`, `CONTAINER`.
    - On Fargate for Linux containers, the only valid value is `TASK`. For example, monitoring sidecars might need pidMode to access information about other containers running in the same task.
    - If `HOST` is specified, all containers within the tasks that specified the host PID mode on the same container instance share the same process namespace with the host Amazon EC2 instance.
    - If `TASK` is specified, all containers within the specified task share the same process namespace.
    - If `CONTAINER` is specified, the the default is a private namespace for each container.
    - If the `HOST` PID mode is used, there's a heightened risk of undesired process namespace exposure.
    - This parameter is not supported for Windows containers.
    (Optional) `ipc_mode` - The IPC resource namespace to use for the containers in the task. Valid values are `HOST`, `TASK`, `CONTAINER`, `INHERIT`.
    - If `HOST` is specified, then all containers within the tasks that specified the host IPC mode on the same container instance share the same IPC resources with the host Amazon EC2 instance.
    - If `TASK` is specified, all containers within the specified task share the same IPC resources.
    - If `CONTAINER` is specified, then IPC resources within the containers of a task are private and not shared with other containers in a task or on the container instance.
    - If `INHERIT` value is specified, then the IPC resource namespace sharing depends on the Docker daemon setting on the container instance.
    - If the `HOST` IPC mode is used, be aware that there is a heightened of undesired IPC namespace expose.
    - If you are setting namespaced kernel parameters using systemControls for the containers in the task, the following will apply to your IPC resource namespace.
      - For tasks that use the `HOST` IPC mode, IPC namespace related systemControls are not supported.
      - For tasks that use the `TASK` IPC mode, IPC namespace related systemControls will apply to all containers within a task.
    - This parameter is not supported for Windows containers or tasks run on Fargate.
  EOF
  type = object({
    pid_mode = optional(string, "CONTAINER")
    ipc_mode = optional(string, "INHERIT")
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["HOST", "TASK", "CONTAINER"], var.namespace_sharing.pid_mode)
    error_message = "Valid values for `namespace_sharing.pid_mode` are `HOST`, `TASK`, `CONTAINER`."
  }
  validation {
    condition     = contains(["HOST", "TASK", "CONTAINER", "INHERIT"], var.namespace_sharing.ipc_mode)
    error_message = "Valid values for `namespace_sharing.ipc_mode` are `HOST`, `TASK`, `CONTAINER`, `INHERIT`."
  }
}

variable "default_task_execution_role" {
  description = <<EOF
  (Optional) A configuration for the default task execution role. Use `task_execution_role` if `default_task_execution_role.enabled` is `false`. `default_task_execution_role` as defined below.
    (Optional) `enabled` - Whether to create the default task execution role. Defaults to `true`.
    (Optional) `name` - The name of the default task execution role. Defaults to `ecs-task-execution-$${var.name}`.
    (Optional) `path` - The path of the default task execution role. Defaults to `/`.
    (Optional) `description` - The description of the default task execution role. Defaults to `Managed by Terraform.`.
    (Optional) `policies` - A list of IAM policy ARNs to attach to the role. `AmazonECSTaskExecutionRolePolicy` is always attached. Defaults to `[]`.
    (Optional) `inline_policies` - A map of inline IAM policies to attach to the default service role. (`name` => `policy`). Defaults to `{}`.
    (Optional) `permissions_boundary` - The ARN of the IAM policy to use as permissions boundary.
  EOF
  type = object({
    enabled     = optional(bool, true)
    name        = optional(string)
    path        = optional(string, "/")
    description = optional(string, "Managed by Terraform.")

    policies             = optional(list(string), [])
    inline_policies      = optional(map(string), {})
    permissions_boundary = optional(string)
  })
  default  = {}
  nullable = false
}

variable "task_execution_role" {
  description = "(Optional) The ARN of the task execution role that grants the ECS agent permission to make AWS API calls. Only required if `default_task_execution_role.enabled` is `false`."
  type        = string
  default     = null
  nullable    = true
}

variable "default_task_role" {
  description = <<EOF
  (Optional) A configuration for the default task role. Use `task_role` if `default_task_role.enabled` is `false`. `default_task_role` as defined below.
    (Optional) `enabled` - Whether to create the default task role. Defaults to `false`.
    (Optional) `name` - The name of the default task role. Defaults to `{task-definition-name}-task`.
    (Optional) `path` - The path of the default task role. Defaults to `/`.
    (Optional) `description` - The description of the default task role. Defaults to `Managed by Terraform.`.
    (Optional) `policies` - A list of IAM policy ARNs to attach to the role. Defaults to `[]`.
    (Optional) `inline_policies` - A map of inline IAM policies to attach to the default service role. (`name` => `policy`). Defaults to `{}`.
    (Optional) `permissions_boundary` - The ARN of the IAM policy to use as permissions boundary.
  EOF
  type = object({
    enabled     = optional(bool, false)
    name        = optional(string)
    path        = optional(string, "/")
    description = optional(string, "Managed by Terraform.")

    policies             = optional(list(string), [])
    inline_policies      = optional(map(string), {})
    permissions_boundary = optional(string)
  })
  default  = {}
  nullable = false
}

variable "task_role" {
  description = "(Optional) The ARN of the task role that allows your ECS task to make calls to other AWS services. Only required if `default_task_role.enabled` is `true` and you want to use a custom role."
  type        = string
  default     = null
  nullable    = true
}

variable "fault_injection" {
  description = <<EOF
  (Optional) A configuration for the fault injection for the task definition. `fault_injection` as defined below.
    (Optional) `enabled` - Whether to enable fault injection and allow for fault injection requests for the task definition. When enabled, allows for fault injection requests to be accepted from the task's containers. Defaults to `false`.
  EOF
  type = object({
    enabled = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "container_definitions" {
  description = "(Required) A valid JSON document that describes the containers to run as part of the task."
  type        = string
  nullable    = false
}

variable "tags" {
  description = "(Optional) A map of tags to add to all resources."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "module_tags_enabled" {
  description = "(Optional) Whether to create AWS Resource Tags for the module informations."
  type        = bool
  default     = true
  nullable    = false
}


###################################################
# Resource Group
###################################################

variable "resource_group" {
  description = <<EOF
  (Optional) Configurations of Resource Group. `resource_group` as defined below.
    (Optional) `enabled` - Whether to create the resource group. Defaults to `true`.
    (Optional) `name` - The name of the resource group. Defaults to `""`.
    (Optional) `description` - The description of the resource group. Defaults to `"Managed by Terraform."`.
  EOF
  type = object({
    enabled     = optional(bool, true)
    name        = optional(string, "")
    description = optional(string, "Managed by Terraform.")
  })
  default  = {}
  nullable = false
}
