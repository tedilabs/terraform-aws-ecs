mock_provider "aws" {}

variables {
  name                  = "example"
  cluster               = "example"
  task_definition       = "example:1"
  task_tags_propagation = {}
  runtime = {
    launch_type = "EC2"
  }
  default_security_group = {
    enabled = false
  }
  resource_group = {
    enabled = false
  }
}

run "rolling_defaults_do_not_configure_blue_green" {
  command = plan

  variables {
    load_balancers = [{
      target_group = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/primary/1234567890abcdef"
      container = {
        name = "api"
        port = 8080
      }
    }]
  }

  assert {
    condition     = length(aws_ecs_service.this.deployment_configuration) == 0
    error_message = "The default rolling configuration must not add a deployment_configuration block."
  }

  assert {
    condition     = length(one(aws_ecs_service.this.load_balancer).advanced_configuration) == 0
    error_message = "The default load balancer configuration must not add an advanced_configuration block."
  }

  assert {
    condition     = output.deployment.strategy == null && output.deployment.bake_time_in_minutes == null
    error_message = "The default deployment output must keep the native strategy configuration nullable."
  }

  assert {
    condition     = one(output.load_balancers).advanced_configuration == null
    error_message = "The default load balancer output must keep advanced_configuration nullable."
  }
}

run "blue_green_maps_native_ecs_configuration" {
  command = plan

  variables {
    deployment = {
      strategy             = "BLUE_GREEN"
      bake_time_in_minutes = 30
    }
    load_balancers = [{
      target_group = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/blue/1234567890abcdef"
      container = {
        name = "api"
        port = 8080
      }
      advanced_configuration = {
        alternate_target_group   = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/green/1234567890abcdef"
        production_listener_rule = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:listener-rule/app/example/123/456/789"
        infrastructure_role      = "arn:aws:iam::123456789012:role/ecs-load-balancer"
      }
    }]
  }

  assert {
    condition     = aws_ecs_service.this.deployment_configuration[0].strategy == "BLUE_GREEN"
    error_message = "The ECS service must use the native BLUE_GREEN strategy."
  }

  assert {
    condition     = aws_ecs_service.this.deployment_configuration[0].bake_time_in_minutes == "30"
    error_message = "The ECS service must map the deployment bake time."
  }

  assert {
    condition     = one(aws_ecs_service.this.load_balancer).advanced_configuration[0].alternate_target_group_arn == "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/green/1234567890abcdef"
    error_message = "The ECS service must map the alternate target group."
  }

  assert {
    condition     = one(aws_ecs_service.this.load_balancer).advanced_configuration[0].production_listener_rule == "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:listener-rule/app/example/123/456/789"
    error_message = "The ECS service must map the production listener rule."
  }

  assert {
    condition     = one(aws_ecs_service.this.load_balancer).advanced_configuration[0].test_listener_rule == null
    error_message = "The test listener rule must remain optional."
  }

  assert {
    condition     = one(aws_ecs_service.this.load_balancer).advanced_configuration[0].role_arn == "arn:aws:iam::123456789012:role/ecs-load-balancer"
    error_message = "The ECS service must map the ECS infrastructure role."
  }

  assert {
    condition     = output.deployment.strategy == "BLUE_GREEN" && output.deployment.bake_time_in_minutes == 30
    error_message = "The deployment output must expose the native strategy and numeric bake time."
  }

  assert {
    condition = (
      one(output.load_balancers).advanced_configuration.alternate_target_group == "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/green/1234567890abcdef" &&
      one(output.load_balancers).advanced_configuration.production_listener_rule == "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:listener-rule/app/example/123/456/789" &&
      one(output.load_balancers).advanced_configuration.test_listener_rule == null &&
      one(output.load_balancers).advanced_configuration.infrastructure_role == "arn:aws:iam::123456789012:role/ecs-load-balancer"
    )
    error_message = "The load balancer output must expose the native blue/green advanced configuration."
  }
}

run "blue_green_requires_advanced_load_balancer_configuration" {
  command = plan

  variables {
    deployment = {
      strategy = "BLUE_GREEN"
    }
    load_balancers = [{
      target_group = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/blue/1234567890abcdef"
      container = {
        name = "api"
        port = 8080
      }
    }]
  }

  expect_failures = [var.load_balancers]
}
