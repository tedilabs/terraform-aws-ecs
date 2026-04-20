variable "region" {
  description = "(Optional) The region in which to create the module resources. If not provided, the module resources will be created in the provider's configured region."
  type        = string
  default     = null
  nullable    = true
}

variable "name" {
  description = "(Required) Desired name for the ECS service."
  type        = string
  nullable    = false
}

variable "cluster" {
  description = "(Required) A name of the ECS cluster to create the service in."
  type        = string
  nullable    = false

  validation {
    condition     = !startswith(var.cluster, "arn:aws:ecs:")
    error_message = "`cluster` should be a name of the ECS cluster, not ARN. Please provide the cluster name only."
  }
}

variable "task_definition" {
  description = "(Required) The family and revision (`family:revision`) or full ARN of the task definition to run in the service."
  type        = string
  nullable    = false
}

variable "task_tags_propagation" {
  description = <<EOF
  (Optional) A configuration of the tags propagation for the tasks within the service. `task_tags_propagation` as defined below.
    (Optional) `source` - The source of the tags to propagate. Valid values are `NONE`, `SERVICE`, `TASK_DEFINITION`. Defaults to `NONE`.
      `NONE` - Do not propagate any tags.
      `SERVICE` - Propagate the tags from the service.
      `TASK_DEFINITION` - Propagate the tags from the task definition.
    (Optional) `ecs_managed_tags_enabled` - Whether to enable Amazon ECS managed tags for the tasks within the service. Defaults to `true`.
  EOF
  type = object({
    source                   = optional(string, "NONE")
    ecs_managed_tags_enabled = optional(bool, true)
  })

  validation {
    condition     = contains(["NONE", "SERVICE", "TASK_DEFINITION"], var.task_tags_propagation.source)
    error_message = "Valid values for `task_tags_propagation.source` are `NONE`, `SERVICE`, `TASK_DEFINITION`."
  }
}

variable "scheduling_strategy" {
  description = "(Optional) The scheduling strategy to use for the service. Valid values are `REPLICA`, `DAEMON`. Note that Tasks using the `FARGATE` launch type or the `CODE_DEPLOY` or `EXTERNAL` deployment controller types don't support the `DAEMON` scheduling strategy. Defaults to `REPLICA`."
  type        = string
  default     = "REPLICA"
  nullable    = false

  validation {
    condition     = contains(["REPLICA", "DAEMON"], var.scheduling_strategy)
    error_message = "Valid values for `scheduling_strategy` are `REPLICA`, `DAEMON`."
  }
}

variable "desired_count" {
  description = "(Optional) The number of instances of the task definition to place and keep running. Defaults to `1`. Only valid for services using the `REPLICA` scheduling strategy. Ignored after the service is created."
  type        = number
  default     = 1
  nullable    = false
}

variable "runtime" {
  description = <<EOF
  (Required) A configuration for the runtime platform of the service. `runtime` as defined below.
    (Required) `launch_type` - A launch type on which to run the service. Valid values are `EC2`, `FARGATE`, `EXTERNAL`, `MANAGED_INSTANCES`, `CAPACITY_PROVIDER_STRATEGY`.
      `EC2` — Run tasks on self-managed EC2 instances registered to the cluster.
      `FARGATE` — Run tasks on Fargate On-Demand infrastructure. Fargate Spot infrastructure is available for use but a capacity
             provider strategy must be used.
      `EXTERNAL` — Run tasks on on-premises or non-AWS infrastructure registered via ECS Anywhere.
      `MANAGED_INSTANCES` — Run tasks on AWS-managed EC2 instances that combine Fargate's operational simplicity with EC2's flexibility (e.g., GPU, specific instance types).
      `CAPACITY_PROVIDER_STRATEGY` - Run tasks using a capacity provider strategy.
    (Optional) `fargate` - A configuration for Fargate-specific runtime options. `fargate` as defined below. Only applicable if `launch_type` is `FARGATE`.
      (Optional) `platform_version` - The platform version on which to run the service. Valid values are `LATEST`, `x.y.z` like `1.4.0`. Defaults to `LATEST`.
    (Optional) `capacity_provider_strategy` - A map of capacity provider strategies for the service. Each key of the map is the name of a capacity provider, and the value is an object that defines the strategy to use for that capacity provider. Each value of `capacity_provider_strategy` as defined below. Only applicable if `launch_type` is `CAPACITY_PROVIDER_STRATEGY`.
      (Optional) `weight` - The relative percentage of the total number of tasks launched that should use the capacity provider. The weight value is taken into consideration after the base value, if defined, is satisfied.  If no weight value is specified, the default value of 0 is used. When multiple capacity providers are specified within a capacity provider strategy, at least one of the capacity providers must have a weight value greater than zero and any capacity providers with a weight of 0 can't be used to place tasks. If you specify multiple capacity providers in a strategy that all have a weight of 0 , any RunTask or CreateService actions using the capacity provider strategy will fail. Defaults to `0`.
      (Optional) `base` - The number of tasks, at a minimum, to run on the specified capacity provider. Only one capacity provider in a strategy can have a base defined. Defaults to `0`.
  EOF
  type = object({
    launch_type = string
    fargate = optional(object({
      platform_version = optional(string, "LATEST")
    }), {})
    capacity_provider_strategy = optional(map(object({
      weight = optional(number, 0)
      base   = optional(number, 0)
    })), {})
  })
  nullable = false

  validation {
    condition     = contains(["EC2", "FARGATE", "EXTERNAL", "MANAGED_INSTANCES", "CAPACITY_PROVIDER_STRATEGY"], var.runtime.launch_type)
    error_message = "Valid values for `runtime.launch_type` are `EC2`, `FARGATE`, `EXTERNAL`, `MANAGED_INSTANCES`, `CAPACITY_PROVIDER_STRATEGY`."
  }
  validation {
    condition = (
      var.runtime.fargate.platform_version == "LATEST" ||
      regex("^\\d+\\.\\d+\\.\\d+$", var.runtime.fargate.platform_version) != null
    )
    error_message = "`runtime.fargate.platform_version` must be `LATEST` or in `x.y.z` format like `1.4.0`."
  }
  validation {
    condition = anytrue([
      var.runtime.launch_type != "CAPACITY_PROVIDER_STRATEGY",
      (var.runtime.launch_type == "CAPACITY_PROVIDER_STRATEGY" && length(var.runtime.capacity_provider_strategy) > 0),
    ])
    error_message = "When `runtime.launch_type` is `CAPACITY_PROVIDER_STRATEGY`, `runtime.capacity_provider_strategy` must be provided with at least one capacity provider."
  }
}

variable "placement_constraints" {
  description = <<EOF
  (Optional) A list of placement constraints for the service. You can use constraints to place tasks based on member attributes. Maximum number of `placement_constraints` is `10`. Each item of `placement_constraints` as defined below.
    (Required) `type` - The type of constraint. Valid values are `distinctInstance`, `memberOf`.
    (Optional) `expression` - The cluster query language expression to apply to the constraint. Only required when `type` is `memberOf`.
  EOF
  type = list(object({
    type       = string
    expression = optional(string)
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
      contains(["distinctInstance", "memberOf"], constraint.type)
    ])
    error_message = "Valid values for `placement_constraints.type` are `distinctInstance`, `memberOf`."
  }
}

variable "ordered_placement_strategy" {
  description = <<EOF
  (Optional) A list of placement strategies for the service. Only for EC2 launch type. Each item of `ordered_placement_strategy` as defined below.
    (Required) `type` - The type of placement strategy. Valid values are `binpack`, `random`, `spread`.
    (Optional) `field` - The field to apply the placement strategy against.
  EOF
  type = list(object({
    type  = string
    field = optional(string)
  }))
  default  = []
  nullable = false

  validation {
    condition = alltrue([
      for strategy in var.ordered_placement_strategy :
      contains(["binpack", "random", "spread"], strategy.type)
    ])
    error_message = "Valid values for `ordered_placement_strategy.type` are `binpack`, `random`, `spread`."
  }
}

variable "execute_command" {
  description = <<EOF
  (Optional) A configuration of the execute command (ECS Exec) for the ECS service. `execute_command` as defined below.
    (Optional) `enabled` - Whether to enable ECS Exec functionality for the tasks within the service. If true, this enables execute command functionality on all containers in the service tasks. Defaults to `false`.
  EOF
  type = object({
    enabled = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "deployment" {
  description = <<EOF
  (Optional) A configuration of the deployment for the ECS service. `deployment` as defined below.
    (Optional) `controller_type` - The deployment controller type to use. Valid values are `ECS`, `CODE_DEPLOY`, `EXTERNAL`. Defaults to `ECS`.
    (Optional) `min_healthy_percent` - The lower limit (as a percentage of `desired_count`) of the number of running tasks that must remain running and healthy in a service during a deployment. Defaults to `100`.
    (Optional) `max_percent` - The upper limit (as a percentage of `desired_count`) of the number of running tasks that can be running in a service during a deployment. Defaults to `200`.
    (Optional) `failure_detection` - A configuration of the deployment failure detection. `failure_detection` as defined below.
      (Optional) `circuit_breaker` - A configuration of the deployment circuit breaker. `circuit_breaker` as defined below.
        (Optional) `enabled` - Whether to enable the deployment circuit breaker logic. If the service can't reach a steady state because a task failed to launch, the deployment fails. Defaults to `true`.
        (Optional) `rollback_on_failure` - Whether to enable Amazon ECS to roll back the service if a service deployment failure is detected. If rollback is enabled, when a service deployment fails, the service is rolled back to the last deployment that completed successfully. Defaults to `true`.
      (Optional) `alarms` - A configuration of CloudWatch alarms-based deployment monitoring. `alarms` as defined below.
        (Optional) `enabled` - Whether to use CloudWatch alarm option in the service deployment process. If the CloudWatch alarm or alarms that you specify transition to the ALARM state, the deployment fails. Defaults to `false`.
        (Optional) `alarm_names` - A set of CloudWatch alarm names to monitor during deployment. Defaults to `[]`.
        (Optional) `rollback_on_failure` - Whether to configure Amazon ECS to roll back the service if a service deployment fails. Defaults to `true`.
  EOF
  type = object({
    controller_type                       = optional(string, "ECS")
    availability_zone_rebalancing_enabled = optional(bool, false)
    min_healthy_percent                   = optional(number, 100)
    max_percent                           = optional(number, 200)
    failure_detection = optional(object({
      circuit_breaker = optional(object({
        enabled             = optional(bool, true)
        rollback_on_failure = optional(bool, true)
      }), {})
      cloudwatch_alarms = optional(object({
        enabled             = optional(bool, false)
        alarm_names         = optional(set(string), [])
        rollback_on_failure = optional(bool, true)
      }), {})
    }), {})
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["ECS", "CODE_DEPLOY", "EXTERNAL"], var.deployment.controller_type)
    error_message = "Valid values for `deployment.controller_type` are `ECS`, `CODE_DEPLOY`, `EXTERNAL`."
  }
}

variable "network_configuration" {
  description = <<EOF
  (Optional) A network configuration for the service. Only applicable for tasks using the `awsvpc` network mode. `network_configuration` as defined below.
    (Required) `subnets` - A set of subnet IDs to associate with the task or service. Maximum of 16 subnets are allowed. All subnets must be from the same VPC.
    (Optional) `security_groups` - A set of security group IDs to associate with the task or service. Defaults to `[]`.
    (Optional) `public_ip_address_assignment_enabled` - Whether to assign a public IP address to the ENI. Defaults to `false`.
  EOF
  type = object({
    subnets                              = set(string)
    security_groups                      = optional(set(string), [])
    public_ip_address_assignment_enabled = optional(bool, false)
  })
  default  = null
  nullable = true
}

variable "load_balancers" {
  description = <<EOF
  (Optional) A list of load balancer configurations for the service. Each item of `load_balancers` as defined below.
    (Required) `target_group_arn` - The ARN of the target group.
    (Required) `container_name` - The name of the container to associate with the load balancer.
    (Required) `container_port` - The port on the container to associate with the load balancer.
  EOF
  type = list(object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  }))
  default  = []
  nullable = false
}

variable "service_connect" {
  description = <<EOF
  (Optional) A configuration of Service Connect for the ECS service. `service_connect` as defined below.
    (Optional) `enabled` - Whether to enable Service Connect. Defaults to `false`.
    (Optional) `namespace` - The ARN of the AWS Cloud Map namespace to use for Service Connect. If not provided, the cluster default namespace is used.
    (Optional) `log_configuration` - A log configuration for the Service Connect proxy. `log_configuration` as defined below.
      (Required) `log_driver` - The log driver to use for the Service Connect proxy.
      (Optional) `options` - The configuration options to send to the log driver. Defaults to `{}`.
      (Optional) `secret_options` - A list of secrets to pass to the log configuration. Each item of `secret_options` as defined below.
        (Required) `name` - The name of the secret.
        (Required) `value_from` - The ARN of the Secrets Manager secret or SSM Parameter Store parameter.
    (Optional) `services` - A list of Service Connect service configurations. Each item of `services` as defined below.
      (Required) `port_name` - The name of one of the `portMappings` from all the containers in the task definition.
      (Optional) `discovery_name` - The name of the new AWS Cloud Map service that ECS creates for this service.
      (Optional) `ingress_port_override` - The port number for the Service Connect proxy to listen on.
      (Optional) `client_alias` - A configuration of the client alias for the service. `client_alias` as defined below.
        (Required) `port` - The listening port number for the Service Connect proxy.
        (Optional) `dns_name` - The DNS name of the service.
  EOF
  type = object({
    enabled   = optional(bool, false)
    namespace = optional(string)
    log_configuration = optional(object({
      log_driver = string
      options    = optional(map(string), {})
      secret_options = optional(list(object({
        name       = string
        value_from = string
      })), [])
    }))
    services = optional(list(object({
      port_name             = string
      discovery_name        = optional(string)
      ingress_port_override = optional(number)
      client_alias = optional(object({
        port     = number
        dns_name = optional(string)
      }))
    })), [])
  })
  default  = {}
  nullable = false
}

variable "service_registries" {
  description = <<EOF
  (Optional) A configuration of the service discovery registries for the service. `service_registries` as defined below.
    (Required) `registry_arn` - The ARN of the Service Registry.
    (Optional) `port` - The port value used if your Service Discovery service specified an SRV record.
    (Optional) `container_name` - The container name value already specified in the task definition.
    (Optional) `container_port` - The container port value already specified in the task definition.
  EOF
  type = object({
    registry_arn   = string
    port           = optional(number)
    container_name = optional(string)
    container_port = optional(number)
  })
  default  = null
  nullable = true
}

variable "health_check_grace_period" {
  description = "(Optional) Seconds to ignore failing load balancer health checks on newly instantiated tasks. Only valid for services configured to use load balancers. Defaults to `0`."
  type        = number
  default     = 0
  nullable    = false
}

variable "availability_zone_rebalancing" {
  description = "(Optional) ECS automatically redistributes tasks within a service across Availability Zones (AZs) to mitigate the risk of impaired application availability due to underlying infrastructure failures and task lifecycle activities. Valid values are `ENABLED`, `DISABLED`. Defaults to `ENABLED`."
  type        = string
  default     = "ENABLED"
  nullable    = false

  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.availability_zone_rebalancing)
    error_message = "Valid values for `availability_zone_rebalancing` are `ENABLED`, `DISABLED`."
  }
}

variable "triggers" {
  description = "(Optional) A map of arbitrary keys and values that, when changed, will trigger an in-place update (redeployment). Useful with `plantimestamp()`. Defaults to `{}`."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "force_delete" {
  description = "(Optional) Whether to delete the service even if it wasn't scaled down to zero tasks. Only valid for services using the `REPLICA` scheduling strategy. Defaults to `false`."
  type        = bool
  default     = false
  nullable    = false
}

variable "force_new_deployment" {
  description = "(Optional) Whether to enable to force a new task deployment of the service. This can be used to update tasks to use a newer Docker image with same image/tag combination (e.g., `myimage:latest`), roll Fargate tasks onto a newer platform version, or immediately deploy `ordered_placement_strategy` and `placement_constraints` updates. Defaults to `false`."
  type        = bool
  default     = false
  nullable    = false
}

variable "wait_for_steady_state" {
  description = "(Optional) Whether Terraform should wait for the service to reach a steady state before continuing. Defaults to `true`."
  type        = bool
  default     = true
  nullable    = false
}

variable "auto_scaling" {
  description = <<EOF
  (Optional) A configuration of the auto scaling for the service. `auto_scaling` as defined below.
    (Optional) `enabled` - Whether to enable auto scaling. Defaults to `false`.
    (Optional) `min_count` - The minimum number of tasks. Defaults to `1`.
    (Optional) `max_count` - The maximum number of tasks. Defaults to `1`.
    (Optional) `target_tracking_policies` - A list of target tracking scaling policies. Each item of `target_tracking_policies` as defined below.
      (Required) `name` - The name of the scaling policy.
      (Required) `metric` - The metric type. Valid values are `CPU`, `MEMORY`, `ALB_REQUEST_COUNT`.
      (Required) `target_value` - The target value for the metric.
      (Optional) `scale_in_cooldown` - The amount of time (in seconds) after a scale-in activity completes before another can start. Defaults to `300`.
      (Optional) `scale_out_cooldown` - The amount of time (in seconds) after a scale-out activity completes before another can start. Defaults to `300`.
      (Optional) `alb_resource_label` - Required when `metric` is `ALB_REQUEST_COUNT`. The resource label for the ALB target group.
      (Optional) `disable_scale_in` - Whether scale in by the target tracking policy is disabled. Defaults to `false`.
  EOF
  type = object({
    enabled   = optional(bool, false)
    min_count = optional(number, 1)
    max_count = optional(number, 1)
    target_tracking_policies = optional(list(object({
      name               = string
      metric             = string
      target_value       = number
      scale_in_cooldown  = optional(number, 300)
      scale_out_cooldown = optional(number, 300)
      alb_resource_label = optional(string)
      disable_scale_in   = optional(bool, false)
    })), [])
  })
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for policy in var.auto_scaling.target_tracking_policies :
      contains(["CPU", "MEMORY", "ALB_REQUEST_COUNT"], policy.metric)
    ])
    error_message = "Valid values for `auto_scaling.target_tracking_policies.metric` are `CPU`, `MEMORY`, `ALB_REQUEST_COUNT`."
  }

  validation {
    condition = alltrue([
      for policy in var.auto_scaling.target_tracking_policies :
      policy.metric != "ALB_REQUEST_COUNT" || policy.alb_resource_label != null
    ])
    error_message = "`auto_scaling.target_tracking_policies.alb_resource_label` is required when `metric` is `ALB_REQUEST_COUNT`."
  }
}

variable "timeouts" {
  description = "(Optional) How long to wait for the ECS Service to be created/updated/deleted."
  type = object({
    create = optional(string, "20m")
    update = optional(string, "20m")
    delete = optional(string, "20m")
  })
  default  = {}
  nullable = false
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
