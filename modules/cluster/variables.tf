variable "region" {
  description = "(Optional) The region in which to create the module resources. If not provided, the module resources will be created in the provider's configured region."
  type        = string
  default     = null
  nullable    = true
}

variable "name" {
  description = "(Required) Desired name for the ECS cluster."
  type        = string
  nullable    = false
}

variable "service_connect_defaults" {
  description = <<EOF
  (Optional) A configuration of the Service Connect defaults for the ECS cluster. `service_connect_defaults` as defined below.
    (Optional) `namespace` - The ARN of the AWS Cloud Map namespace to use as default for Service Connect.
  EOF
  type = object({
    namespace = optional(string)
  })
  default  = {}
  nullable = false
}

variable "container_insights" {
  description = <<EOF
  (Optional) A configuration of Container Insights for the ECS cluster. `container_insights` as defined below.
    (Optional) `mode` - The level of observability to achieve with Container Insights. Valid values are `DISABLED`, `ENABLED`, and `ENHANCED`. Defaults to `DISABLED`.
      `DISABLED` - Provides default CloudWatch metrics only.
      `ENABLED` - Provides aggregated metrics at cluster and service level. You can run deep dive analysis with Logs Insights analytics.
      `ENHANCED` - Provides detailed health and performance metrics at task and container level in addition to aggregated metrics at cluster and service level. Enables easier drill downs for faster problem isolation and troubleshooting.
  EOF
  type = object({
    mode = optional(string, "DISABLED")
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["DISABLED", "ENABLED", "ENHANCED"], var.container_insights.mode)
    error_message = "Valid values for `container_insights.mode` are `DISABLED`, `ENABLED`, and `ENHANCED`."
  }
}

variable "execute_command" {
  description = <<EOF
  (Optional) A configuration of the execute command for the ECS cluster. `execute_command` as defined below.
    (Optional) `logging` - The log setting to use for redirecting logs for execute command results. Valid values are `NONE`, `DEFAULT`, `OVERRIDE`. Defaults to `DEFAULT`.
    (Optional) `encryption_kms_key` - The ARN of the KMS key to use for encryption of data between the local client and the container.
    (Optional) `cloudwatch_log_group` - The name of the CloudWatch log group to send execute command logs to.
    (Optional) `cloudwatch_encryption_enabled` - Whether to enable encryption on the CloudWatch log group. Defaults to `true`.
    (Optional) `s3_bucket` - The name of the S3 bucket to send execute command logs to.
    (Optional) `s3_key_prefix` - An optional prefix for the S3 bucket logs.
    (Optional) `s3_encryption_enabled` - Whether to enable encryption on the S3 bucket logs. Defaults to `true`.
  EOF
  type = object({
    logging                       = optional(string, "DEFAULT")
    encryption_kms_key            = optional(string)
    cloudwatch_log_group          = optional(string)
    cloudwatch_encryption_enabled = optional(bool, true)
    s3_bucket                     = optional(string)
    s3_key_prefix                 = optional(string)
    s3_encryption_enabled         = optional(bool, true)
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["NONE", "DEFAULT", "OVERRIDE"], var.execute_command.logging)
    error_message = "Valid values for `execute_command.logging` are `NONE`, `DEFAULT`, `OVERRIDE`."
  }
}

variable "managed_storage_encryption" {
  description = <<EOF
  (Optional) A configuration of managed storage encryption for Fargate ephemeral storage. `managed_storage_encryption` as defined below.
    (Optional) `enabled` - Whether to enable encryption of ephemeral storage with a customer-managed KMS key. Defaults to `false`.
    (Optional) `kms_key` - The ARN of the KMS key to use for encryption. Required when `enabled` is `true`.
  EOF
  type = object({
    enabled = optional(bool, false)
    kms_key = optional(string)
  })
  default  = {}
  nullable = false
}

variable "default_capacity_provider_strategy" {
  description = <<EOF
  (Optional) A list of default capacity provider strategies for the ECS cluster. Each item of `default_capacity_provider_strategy` as defined below.
    (Required) `capacity_provider` - The name of the capacity provider.
    (Optional) `weight` - The relative percentage of the total number of tasks launched that should use the capacity provider. Defaults to `0`.
    (Optional) `base` - The number of tasks, at a minimum, to run on the specified capacity provider. Only one capacity provider in a strategy can have a base defined. Defaults to `0`.
  EOF
  type = list(object({
    capacity_provider = string
    weight            = optional(number, 0)
    base              = optional(number, 0)
  }))
  default  = []
  nullable = false
}

variable "fargate_capacity_providers" {
  description = <<EOF
  (Optional) A configuration of Fargate capacity providers for the ECS cluster. `fargate_capacity_providers` as defined below.
    (Optional) `fargate_enabled` - Whether to enable the FARGATE capacity provider. Defaults to `true`.
    (Optional) `fargate_spot_enabled` - Whether to enable the FARGATE_SPOT capacity provider. Defaults to `false`.
  EOF
  type = object({
    fargate_enabled      = optional(bool, true)
    fargate_spot_enabled = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "managed_capacity_providers" {
  description = "(Optional) A list of names of custom (managed) capacity providers to associate with the cluster. Defaults to `[]`."
  type        = list(string)
  default     = []
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
  (Optional) A configurations of Resource Group for this module. `resource_group` as defined below.
    (Optional) `enabled` - Whether to create Resource Group to find and group AWS resources which are created by this module. Defaults to `true`.
    (Optional) `name` - The name of Resource Group. A Resource Group name can have a maximum of 127 characters, including letters, numbers, hyphens, dots, and underscores. The name cannot start with `AWS` or `aws`. If not provided, a name will be generated using the module name and instance name.
    (Optional) `description` - The description of Resource Group. Defaults to `Managed by Terraform.`.
  EOF
  type = object({
    enabled     = optional(bool, true)
    name        = optional(string, "")
    description = optional(string, "Managed by Terraform.")
  })
  default  = {}
  nullable = false
}
