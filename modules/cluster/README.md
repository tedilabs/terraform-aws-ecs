# cluster

This module creates following resources.

- `aws_ecs_cluster`
- `aws_ecs_cluster_capacity_providers`

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.12 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.35.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_resource_group"></a> [resource\_group](#module\_resource\_group) | tedilabs/misc/aws//modules/resource-group | ~> 0.12.0 |

## Resources

| Name | Type |
|------|------|
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | (Required) Desired name for the ECS cluster. | `string` | n/a | yes |
| <a name="input_capacity_providers"></a> [capacity\_providers](#input\_capacity\_providers) | (Optional) A set of names of custom (managed) capacity providers to associate with the cluster. To use a Fargate capacity provider, specify either the `FARGATE` or `FARGATE_SPOT` capacity providers. The Fargate capacity providers are available to all accounts and only need to be associated with a cluster to be used. Defaults to `[]`. | `set(string)` | `[]` | no |
| <a name="input_container_insights"></a> [container\_insights](#input\_container\_insights) | (Optional) A configuration of Container Insights for the ECS cluster. `container_insights` as defined below.<br/>    (Optional) `mode` - The level of observability to achieve with Container Insights. Valid values are `DISABLED`, `ENABLED`, and `ENHANCED`. Defaults to `DISABLED`.<br/>      `DISABLED` - Provides default CloudWatch metrics only.<br/>      `ENABLED` - Provides aggregated metrics at cluster and service level. You can run deep dive analysis with Logs Insights analytics.<br/>      `ENHANCED` - Provides detailed health and performance metrics at task and container level in addition to aggregated metrics at cluster and service level. Enables easier drill downs for faster problem isolation and troubleshooting. | <pre>object({<br/>    mode = optional(string, "DISABLED")<br/>  })</pre> | `{}` | no |
| <a name="input_default_capacity_provider_strategy"></a> [default\_capacity\_provider\_strategy](#input\_default\_capacity\_provider\_strategy) | (Optional) A map of default capacity provider strategies for the ECS cluster. Each kye of the map is the name of a capacity provider, and the value is an object that defines the default strategy to use for that capacity provider. Each value of `default_capacity_provider_strategy` as defined below.<br/>    (Optional) `weight` - The relative percentage of the total number of tasks launched that should use the capacity provider. The weight value is taken into consideration after the base value, if defined, is satisfied.  If no weight value is specified, the default value of 0 is used. When multiple capacity providers are specified within a capacity provider strategy, at least one of the capacity providers must have a weight value greater than zero and any capacity providers with a weight of 0 can't be used to place tasks. If you specify multiple capacity providers in a strategy that all have a weight of 0 , any RunTask or CreateService actions using the capacity provider strategy will fail. Defaults to `0`.<br/>    (Optional) `base` - The number of tasks, at a minimum, to run on the specified capacity provider. Only one capacity provider in a strategy can have a base defined. Defaults to `0`. | <pre>map(object({<br/>    weight = optional(number, 0)<br/>    base   = optional(number, 0)<br/>  }))</pre> | `{}` | no |
| <a name="input_encryption_at_rest"></a> [encryption\_at\_rest](#input\_encryption\_at\_rest) | (Optional) A configuration of encryption at rest for managed storage. `encryption_at_rest` as defined below.<br/>    (Optional) `ebs` - A configuration of EBS volume encryption for EC2-based tasks. `ebs` as defined below.<br/>      (Optional) `kms_key` - The ARN of the KMS key to use for EBS volume encryption.<br/>    (Optional) `fargate_ephemeral_storage` - A configuration of ephemeral storage encryption for Fargate tasks. `fargate_ephemeral_storage` as defined below.<br/>      (Optional) `kms_key` - The ARN of the KMS key to use for Fargate ephemeral storage encryption. | <pre>object({<br/>    ebs = optional(object({<br/>      kms_key = optional(string)<br/>    }), {})<br/>    fargate_ephemeral_storage = optional(object({<br/>      kms_key = optional(string)<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_execute_command"></a> [execute\_command](#input\_execute\_command) | (Optional) A configuration of the execute command (ECS Exec) for the ECS cluster. `execute_command` as defined below.<br/>    (Optional) `data_channel_encryption` - A configuration of data channel encryption for execute command. `data_channel_encryption` as defined below.<br/>      (Optional) `kms_key` - The ARN of the KMS key to use for encryption of data between the local client and the container.<br/>    (Optional) `logging` - A configuration for logging commands run using ECS Exec. `logging` as defined below.<br/>      (Optional) `mode` - The mode of logging for commands run using ECS Exec. Valid values are `NONE`, `DEFAULT`, `OVERRIDE`. Defaults to `DEFAULT`.<br/>        `NONE` - The ECS Exec command session is not logged.<br/>        `DEFAULT` - Send logs to CloudWatch Logs using the awslogs log driver that's configured in your task definition. If no awslogs log driver is configured in the task definition, the output won't be logged.<br/>        `OVERRIDE` - Log to the provided CloudWatch log group, Amazon S3 bucket, or both. Your ECS task role needs to include IAM permissions to log the output to CloudWatch and/or S3. Standard AWS data transfer charges and logging costs will apply.<br/>      (Optional) `cloudwatch_log_group` - A configuration for logging to a CloudWatch log group for commands run using ECS Exec. Must set `mode` to `OVERRIDE` to use this logging option. `cloudwatch_log_group` as defined below.<br/>        (Required) `name` - The name of the CloudWatch log group to send execute command logs to.<br/>        (Optional) `encryption_enabled` - Whether to enable encryption on the CloudWatch log group. Defaults to `true`.<br/>      (Optional) `s3_bucket` - A configuration for logging to an S3 bucket for commands run using ECS Exec. Must set `mode` to `OVERRIDE` to use this logging option. `s3_bucket` as defined below.<br/>        (Required) `name` - The name of the S3 bucket to send execute command logs to.<br/>        (Optional) `key_prefix` - An optional key prefix for the specified S3 bucket.<br/>        (Optional) `encryption_enabled` - Whether to enable encryption on the S3 bucket logs. Defaults to `true`. | <pre>object({<br/>    data_channel_encryption = optional(object({<br/>      kms_key = optional(string)<br/>    }), {})<br/>    logging = optional(object({<br/>      mode = optional(string, "DEFAULT")<br/><br/>      cloudwatch_log_group = optional(object({<br/>        name               = string<br/>        encryption_enabled = optional(bool, true)<br/>      }))<br/><br/>      s3_bucket = optional(object({<br/>        name               = string<br/>        key_prefix         = optional(string, "")<br/>        encryption_enabled = optional(bool, true)<br/>      }))<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_module_tags_enabled"></a> [module\_tags\_enabled](#input\_module\_tags\_enabled) | (Optional) Whether to create AWS Resource Tags for the module informations. | `bool` | `true` | no |
| <a name="input_region"></a> [region](#input\_region) | (Optional) The region in which to create the module resources. If not provided, the module resources will be created in the provider's configured region. | `string` | `null` | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | (Optional) A configurations of Resource Group for this module. `resource_group` as defined below.<br/>    (Optional) `enabled` - Whether to create Resource Group to find and group AWS resources which are created by this module. Defaults to `true`.<br/>    (Optional) `name` - The name of Resource Group. A Resource Group name can have a maximum of 127 characters, including letters, numbers, hyphens, dots, and underscores. The name cannot start with `AWS` or `aws`. If not provided, a name will be generated using the module name and instance name.<br/>    (Optional) `description` - The description of Resource Group. Defaults to `Managed by Terraform.`. | <pre>object({<br/>    enabled     = optional(bool, true)<br/>    name        = optional(string, "")<br/>    description = optional(string, "Managed by Terraform.")<br/>  })</pre> | `{}` | no |
| <a name="input_service_connect_defaults"></a> [service\_connect\_defaults](#input\_service\_connect\_defaults) | (Optional) A configuration of the Service Connect defaults for the ECS cluster. `service_connect_defaults` as defined below.<br/>    (Optional) `namespace` - The ARN of the AWS Cloud Map namespace to use as default for Service Connect. | <pre>object({<br/>    namespace = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | (Optional) A map of tags to add to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | The ARN of the ECS cluster. |
| <a name="output_capacity_providers"></a> [capacity\_providers](#output\_capacity\_providers) | The capacity providers associated with the cluster. |
| <a name="output_container_insights"></a> [container\_insights](#output\_container\_insights) | The Container Insights configuration. |
| <a name="output_default_capacity_provider_strategy"></a> [default\_capacity\_provider\_strategy](#output\_default\_capacity\_provider\_strategy) | The default capacity provider strategy for the cluster. |
| <a name="output_encryption_at_rest"></a> [encryption\_at\_rest](#output\_encryption\_at\_rest) | The encryption at rest configuration for managed storage. |
| <a name="output_execute_command"></a> [execute\_command](#output\_execute\_command) | The execute command configuration. |
| <a name="output_id"></a> [id](#output\_id) | The ID of the ECS cluster. |
| <a name="output_name"></a> [name](#output\_name) | The name of the ECS cluster. |
| <a name="output_region"></a> [region](#output\_region) | The AWS region this module resources resides in. |
| <a name="output_resource_group"></a> [resource\_group](#output\_resource\_group) | The resource group created to manage resources in this module. |
| <a name="output_service_connect_defaults"></a> [service\_connect\_defaults](#output\_service\_connect\_defaults) | The configuration of Service Connect defaults for the cluster. |
<!-- END_TF_DOCS -->
