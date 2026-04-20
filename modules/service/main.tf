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

data "aws_ecs_cluster" "this" {
  region = var.region

  cluster_name = var.cluster
}

locals {
  auto_scaling_metric = {
    "CPU"               = "ECSServiceAverageCPUUtilization"
    "MEMORY"            = "ECSServiceAverageMemoryUtilization"
    "ALB_REQUEST_COUNT" = "ALBRequestCountPerTarget"
  }
}


###################################################
# ECS Service
###################################################

# TODO:
# task_definition - (Optional) Family and revision (family:revision) or full ARN of the task definition that you want to run in your service. Required unless using the EXTERNAL deployment controller. If a revision is not specified, the latest ACTIVE revision is used.
# deployment_configuration - (Optional) Configuration block for deployment settings. See below.
# `load_balancer.advanced_configuration`
# service_connect_configuration - (Optional) ECS Service Connect configuration for this service to discover and connect to services, and be discovered by, and connected from, other services within a namespace. See below.
# service_registries - (Optional) Service discovery registries for the service. The maximum number of service_registries blocks is 1. See below.
# sigint_rollback - (Optional) Whether to enable graceful termination of deployments using SIGINT signals. When enabled, allows customers to safely cancel an in-progress deployment and automatically trigger a rollback to the previous stable state. Defaults to false. Only applicable when using ECS deployment controller and requires wait_for_steady_state = true.
# volume_configuration - (Optional) Configuration for a volume specified in the task definition as a volume that is configured at launch time. Currently, the only supported volume type is an Amazon EBS volume. See below.
# vpc_lattice_configurations - (Optional) The VPC Lattice configuration for your service that allows Lattice to connect, secure, and monitor your service across multiple accounts and VPCs. See below.
#
# INFO: Not supported attributes
# - `deployment_configuration` (BLUE_GREEN/LINEAR/CANARY strategies)
# - `iam_role` (If your account has already created the Amazon ECS service-linked role, that role is used by default for your service unless you specify a role here.)
# - `load_balancer.elb_name`
# - `sigint_rollback` (requires BLUE_GREEN deployment strategy)
# - `volume_configuration` (EBS volume management)
# - `vpc_lattice_configurations`
resource "aws_ecs_service" "this" {
  region = var.region

  name    = var.name
  cluster = data.aws_ecs_cluster.this.arn


  ## Task Definition
  task_definition         = var.task_definition
  enable_ecs_managed_tags = var.task_tags_propagation.ecs_managed_tags_enabled
  propagate_tags          = var.task_tags_propagation.source


  ## Runtime
  launch_type = (var.runtime.launch_type != "CAPACITY_PROVIDER_STRATEGY"
    ? var.runtime.launch_type
    : null
  )

  platform_version = (var.runtime.launch_type == "FARGATE"
    ? var.runtime.fargate.platform_version
    : null
  )

  dynamic "capacity_provider_strategy" {
    for_each = var.runtime.launch_type == "CAPACITY_PROVIDER_STRATEGY" ? var.runtime.capacity_provider_strategy : {}
    iterator = strategy

    content {
      capacity_provider = strategy.key
      weight            = strategy.value.weight
      base              = strategy.value.base
    }
  }

  dynamic "placement_constraints" {
    for_each = var.placement_constraints

    content {
      type = placement_constraints.value.type
      expression = (placement_constraints.value.type == "memberOf"
        ? placement_constraints.value.expression
        : null
      )
    }
  }

  dynamic "ordered_placement_strategy" {
    for_each = var.runtime.launch_type != "FARGATE" && var.deployment.scheduling_strategy == "REPLICA" ? var.placement_strategy : []
    iterator = strategy

    content {
      type  = strategy.value.type
      field = strategy.value.field
    }
  }


  ## ECS Exec
  enable_execute_command = var.execute_command.enabled


  ## Deployment
  scheduling_strategy = var.deployment.scheduling_strategy
  desired_count = (var.deployment.scheduling_strategy == "REPLICA"
    ? var.deployment.desired_count
    : null
  )

  deployment_controller {
    type = var.deployment.controller_type
  }

  availability_zone_rebalancing = var.deployment.availability_zone_rebalancing_enabled ? "ENABLED" : "DISABLED"

  health_check_grace_period_seconds = var.deployment.health_check_grace_period

  deployment_minimum_healthy_percent = (var.deployment.controller_type == "ECS"
    ? var.deployment.min_running_tasks_percent
    : null
  )
  deployment_maximum_percent = (var.deployment.controller_type == "ECS"
    ? (var.deployment.scheduling_strategy == "DAEMON"
      ? 100
      : var.deployment.max_running_tasks_percent
    )
    : null
  )

  deployment_circuit_breaker {
    enable   = var.deployment.failure_detection.circuit_breaker.enabled
    rollback = var.deployment.failure_detection.circuit_breaker.rollback_on_failure
  }

  dynamic "alarms" {
    for_each = var.deployment.failure_detection.cloudwatch_alarms.enabled ? [var.deployment.failure_detection.cloudwatch_alarms] : []
    iterator = cloudwatch_alarms

    content {
      enable      = cloudwatch_alarms.value.enabled
      alarm_names = cloudwatch_alarms.value.alarm_names
      rollback    = cloudwatch_alarms.value.rollback_on_failure
    }
  }


  ## Network
  dynamic "network_configuration" {
    for_each = var.network_configuration != null ? [var.network_configuration] : []

    content {
      subnets          = network_configuration.value.subnets
      security_groups  = local.security_groups
      assign_public_ip = network_configuration.value.public_ip_address_assignment_enabled
    }
  }


  ## Load Balancer
  dynamic "load_balancer" {
    for_each = var.load_balancers

    content {
      target_group_arn = load_balancer.value.target_group
      container_name   = load_balancer.value.container.name
      container_port   = load_balancer.value.container.port
    }
  }


  ## Service Connect
  dynamic "service_connect_configuration" {
    for_each = var.service_connect.enabled ? ["go"] : []

    content {
      enabled   = true
      namespace = var.service_connect.namespace

      dynamic "log_configuration" {
        for_each = var.service_connect.log_configuration != null ? [var.service_connect.log_configuration] : []

        content {
          log_driver = log_configuration.value.log_driver
          options    = log_configuration.value.options

          dynamic "secret_option" {
            for_each = log_configuration.value.secret_options

            content {
              name       = secret_option.value.name
              value_from = secret_option.value.value_from
            }
          }
        }
      }

      dynamic "service" {
        for_each = var.service_connect.services

        content {
          port_name             = service.value.port_name
          discovery_name        = service.value.discovery_name
          ingress_port_override = service.value.ingress_port_override

          dynamic "client_alias" {
            for_each = service.value.client_alias != null ? [service.value.client_alias] : []

            content {
              port     = client_alias.value.port
              dns_name = client_alias.value.dns_name
            }
          }
        }
      }
    }
  }


  ## Service Discovery
  dynamic "service_registries" {
    for_each = var.service_registries != null ? [var.service_registries] : []

    content {
      registry_arn   = service_registries.value.registry_arn
      port           = service_registries.value.port
      container_name = service_registries.value.container_name
      container_port = service_registries.value.container_port
    }
  }


  force_delete          = var.force_delete
  force_new_deployment  = var.force_new_deployment
  wait_for_steady_state = var.wait_for_steady_state
  triggers              = var.triggers_to_redeployment


  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  tags = merge(
    {
      "Name" = local.metadata.name
    },
    local.module_tags,
    var.tags,
  )

  lifecycle {
    ignore_changes = [
      desired_count,
    ]
  }
}


###################################################
# Auto Scaling
###################################################

resource "aws_appautoscaling_target" "this" {
  count = var.auto_scaling.enabled ? 1 : 0

  region = var.region

  service_namespace  = "ecs"
  resource_id        = "service/${split("/", var.cluster)[1]}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  min_capacity = var.auto_scaling.min_count
  max_capacity = var.auto_scaling.max_count
}

resource "aws_appautoscaling_policy" "this" {
  for_each = {
    for policy in var.auto_scaling.target_tracking_policies :
    policy.name => policy
    if var.auto_scaling.enabled
  }

  region = var.region

  name               = each.key
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value       = each.value.target_value
    scale_in_cooldown  = each.value.scale_in_cooldown
    scale_out_cooldown = each.value.scale_out_cooldown
    disable_scale_in   = each.value.disable_scale_in

    predefined_metric_specification {
      predefined_metric_type = local.auto_scaling_metric[each.value.metric]
      resource_label         = each.value.metric == "ALB_REQUEST_COUNT" ? each.value.alb_resource_label : null
    }
  }
}
