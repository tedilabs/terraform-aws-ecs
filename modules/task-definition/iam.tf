data "aws_caller_identity" "this" {}

locals {
  account_id = data.aws_caller_identity.this.account_id
}


###################################################
# IAM Role for ECS Task Execution
###################################################

module "role__task_execution" {
  source  = "tedilabs/account/aws//modules/iam-role"
  version = "~> 0.33.0"

  count = var.default_task_execution_role.enabled ? 1 : 0

  name = coalesce(
    var.default_task_execution_role.name,
    "ecs-task-execution-${local.metadata.name}",
  )
  path        = var.default_task_execution_role.path
  description = var.default_task_execution_role.description

  trusted_service_policies = [
    {
      services = ["ecs-tasks.amazonaws.com"]
      conditions = [
        {
          key       = "aws:SourceAccount"
          condition = "StringEquals"
          values    = [local.account_id]
        }
      ]
    }
  ]

  policies = concat(
    ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"],
    var.default_task_execution_role.policies,
  )
  inline_policies      = var.default_task_execution_role.inline_policies
  permissions_boundary = var.default_task_execution_role.permissions_boundary

  force_detach_policies = true
  resource_group = {
    enabled = false
  }
  module_tags_enabled = false

  tags = merge(
    local.module_tags,
    var.tags,
  )
}


###################################################
# IAM Role for ECS Task
###################################################

module "role__task" {
  source  = "tedilabs/account/aws//modules/iam-role"
  version = "~> 0.33.0"

  count = var.default_task_role.enabled ? 1 : 0

  name = coalesce(
    var.default_task_role.name,
    "ecs-task-${local.metadata.name}",
  )
  path        = var.default_task_role.path
  description = var.default_task_role.description

  trusted_service_policies = [
    {
      services = ["ecs-tasks.amazonaws.com"]
      conditions = [
        {
          key       = "aws:SourceAccount"
          condition = "StringEquals"
          values    = [local.account_id]
        }
      ]
    }
  ]

  policies             = var.default_task_role.policies
  inline_policies      = var.default_task_role.inline_policies
  permissions_boundary = var.default_task_role.permissions_boundary

  force_detach_policies = true
  resource_group = {
    enabled = false
  }
  module_tags_enabled = false

  tags = merge(
    local.module_tags,
    var.tags,
  )
}
