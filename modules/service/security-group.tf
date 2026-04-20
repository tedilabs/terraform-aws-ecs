data "aws_subnet" "this" {
  count = local.default_security_group_enabled ? 1 : 0

  id = tolist(var.network_configuration.subnets)[0]
}

locals {
  default_security_group_enabled = var.default_security_group.enabled && var.network_configuration != null

  security_groups = (local.default_security_group_enabled
    ? setunion(
      module.security_group[*].id,
      var.network_configuration.security_groups
    )
    : (var.network_configuration != null
      ? var.network_configuration.security_groups
      : []
    )
  )
}


###################################################
# Security Group
###################################################

module "security_group" {
  source  = "tedilabs/network/aws//modules/security-group"
  version = "~> 1.0.0"

  count = local.default_security_group_enabled ? 1 : 0

  region = var.region

  name        = coalesce(var.default_security_group.name, local.metadata.name)
  description = var.default_security_group.description
  vpc_id      = data.aws_subnet.this[0].vpc_id

  ingress_rules = [
    for i, rule in var.default_security_group.ingress_rules :
    merge(rule, {
      id = coalesce(rule.id, "ec2-instance-${i}")
    })
  ]
  egress_rules = [
    for i, rule in var.default_security_group.egress_rules :
    merge(rule, {
      id = coalesce(rule.id, "ec2-instance-${i}")
    })
  ]

  revoke_rules_on_delete = true
  resource_group = {
    enabled = false
  }
  module_tags_enabled = false

  tags = merge(
    local.module_tags,
    var.tags,
  )
}
