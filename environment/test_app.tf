resource "aws_ecs_service" "test" {
  count                   = local.test_enabled ? 1 : 0
  name                    = "test-${terraform.workspace}"
  cluster                 = aws_ecs_cluster.main.id
  task_definition         = aws_ecs_task_definition.reset_database[0].arn
  desired_count           = 0
  launch_type             = "FARGATE"
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"
  tags                    = local.default_tags

  network_configuration {
    security_groups = [
      aws_security_group.front.id,
      aws_security_group.api_task.id,
    ]

    subnets          = data.aws_subnet.private.*.id
    assign_public_ip = false
  }
}

resource "aws_ecs_task_definition" "test_front" {
  count                    = local.test_enabled ? 1 : 0
  family                   = "test-front-${terraform.workspace}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  container_definitions    = "[${local.test_front_container}]"
  task_role_arn            = aws_iam_role.test.arn
  execution_role_arn       = aws_iam_role.execution_role.arn
  tags                     = local.default_tags
}

resource "aws_ecs_task_definition" "test_api" {
  count                    = local.test_enabled ? 1 : 0
  family                   = "test-api-${terraform.workspace}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  container_definitions    = "[${local.test_api_container}]"
  task_role_arn            = aws_iam_role.test.arn
  execution_role_arn       = aws_iam_role.execution_role.arn
  tags                     = local.default_tags
}

resource "aws_ecs_task_definition" "reset_database" {
  count                    = local.test_enabled ? 1 : 0
  family                   = "reset-database-${terraform.workspace}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  container_definitions    = "[${local.reset_database_container}]"
  task_role_arn            = aws_iam_role.test.arn
  execution_role_arn       = aws_iam_role.execution_role.arn
  tags                     = local.default_tags
}

locals {
  reset_database_container = <<EOF
  {
    "name": "reset_database",
    "image": "registry.service.opg.digital/opguk/digi-deps-api:${var.OPG_DOCKER_TAG}",
    "repositoryCredentials": {
      "credentialsParameter": "${data.aws_secretsmanager_secret.registry.name}"
    },
    "command": [ "sh", "scripts/resetdb.sh" ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.opg_digi_deps.name}",
        "awslogs-region": "eu-west-1",
        "awslogs-stream-prefix": "${aws_iam_role.test.name}"
      }
    },
    "secrets": [
      { "name": "API_DATABASE_PASSWORD", "valueFrom": "${data.aws_secretsmanager_secret.database_password.arn}" },
      { "name": "API_SECRET", "valueFrom": "${data.aws_secretsmanager_secret.api_secret.arn}" }
    ],
    "environment": [
      { "name": "API_BEHAT_CONTROLLER_ENABLED", "value": "true" },
      { "name": "API_DATABASE_HOSTNAME", "value": "${aws_db_instance.api.address}" },
      { "name": "API_DATABASE_NAME", "value": "${aws_db_instance.api.name}" },
      { "name": "API_DATABASE_PORT", "value": "${aws_db_instance.api.port}" },
      { "name": "API_DATABASE_USERNAME", "value": "digidepsmaster" },
      { "name": "API_FIXTURES_ACCOUNTPASSWORD", "value": "Abcd1234" },
      { "name": "API_FIXTURES_ENABLE_PLEASE", "value": "True" },
      { "name": "API_REDIS_DSN", "value": "redis://${aws_route53_record.api_redis.fqdn}" },
      { "name": "API_SECURITY_ANONYMOUS", "value": "true" }
    ]
  }
  
EOF


  test_api_container = <<EOF
  {
    "name": "test_api",
    "image": "registry.service.opg.digital/opguk/digi-deps-api:${var.OPG_DOCKER_TAG}",
    "repositoryCredentials": {
      "credentialsParameter": "${data.aws_secretsmanager_secret.registry.name}"
    },
    "command": [ "sh", "scripts/apiunittest.sh" ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.opg_digi_deps.name}",
        "awslogs-region": "eu-west-1",
        "awslogs-stream-prefix": "${aws_iam_role.test.name}"
      }
    },
    "secrets": [
      { "name": "API_DATABASE_PASSWORD", "valueFrom": "${data.aws_secretsmanager_secret.database_password.arn}" },
      { "name": "API_SECRET", "valueFrom": "${data.aws_secretsmanager_secret.api_secret.arn}" },
      { "name": "API_SECRETS_ADMIN_KEY", "valueFrom": "${data.aws_secretsmanager_secret.admin_api_client_secret.arn}" },
      { "name": "API_SECRETS_FRONT_KEY", "valueFrom": "${data.aws_secretsmanager_secret.front_api_client_secret.arn}" }
    ],
    "environment": [
      { "name": "API_BEHAT_CONTROLLER_ENABLED", "value": "true" },
      { "name": "API_DATABASE_HOSTNAME", "value": "${aws_db_instance.api.address}" },
      { "name": "API_DATABASE_NAME", "value": "${aws_db_instance.api.name}" },
      { "name": "API_DATABASE_PORT", "value": "${aws_db_instance.api.port}" },
      { "name": "API_DATABASE_USERNAME", "value": "digidepsmaster" },
      { "name": "API_FIXTURES_ACCOUNTPASSWORD", "value": "Abcd1234" },
      { "name": "API_FIXTURES_ENABLE_PLEASE", "value": "True" },
      { "name": "API_REDIS_DSN", "value": "redis://${aws_route53_record.api_redis.fqdn}" },
      { "name": "API_SECURITY_ANONYMOUS", "value": "true" },
      { "name": "API_SECRETS_ADMIN_PERMISSIONS", "value": "[ROLE_ADMIN, ROLE_AD, ROLE_CASE_MANAGER]" },
      { "name": "API_SECRETS_FRONT_PERMISSIONS", "value": "[ROLE_LAY_DEPUTY, ROLE_PA, ROLE_PROF, ROLE_PA_ADMIN, ROLE_PA_TEAM_MEMBER]" }
    ]
  }
  
EOF


test_front_container = <<EOF
  {
    "name": "test_front",
    "image": "registry.service.opg.digital/opguk/digi-deps-frontend:${var.OPG_DOCKER_TAG}",
    "repositoryCredentials": {
      "credentialsParameter": "${data.aws_secretsmanager_secret.registry.name}"
    },
    "command": [ "sh", "scripts/clienttest.sh" ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.opg_digi_deps.name}",
        "awslogs-region": "eu-west-1",
        "awslogs-stream-prefix": "${aws_iam_role.test.name}"
      }
    },
    "secrets": [
      { "name": "API_DATABASE_PASSWORD", "valueFrom": "${data.aws_secretsmanager_secret.database_password.arn}" },
      { "name": "FRONTEND_API_CLIENT_SECRET", "valueFrom": "${data.aws_secretsmanager_secret.front_api_client_secret.arn}" },
      { "name": "FRONTEND_GA", "valueFrom": "${data.aws_secretsmanager_secret.google_analytics.arn}" },
      { "name": "FRONTEND_OAUTH2_CLIENT_SECRET", "valueFrom": "${data.aws_secretsmanager_secret.oauth2_client_secret.arn}" },
      { "name": "FRONTEND_SECRET", "valueFrom": "${data.aws_secretsmanager_secret.front_frontend_secret.arn}" },
      { "name": "FRONTEND_SMTP_DEFAULT_PASSWORD", "valueFrom": "${data.aws_secretsmanager_secret.smtp_password.arn}" },
      { "name": "FRONTEND_SMTP_DEFAULT_USER", "valueFrom": "${data.aws_secretsmanager_secret.smtp_user.arn}" }
    ],
    "environment": [
      { "name": "API_DATABASE_HOSTNAME", "value": "${aws_db_instance.api.address}" },
      { "name": "API_DATABASE_NAME", "value": "${aws_db_instance.api.name}" },
      { "name": "API_DATABASE_PORT", "value": "${aws_db_instance.api.port}" },
      { "name": "API_DATABASE_USERNAME", "value": "digidepsmaster" },
      { "name": "FRONTEND_ADMIN_HOST", "value": "https://${aws_route53_record.admin.fqdn}" },
      { "name": "FRONTEND_API_URL", "value": "https://${local.api_service_fqdn}" },
      { "name": "FRONTEND_BEHAT_CONTROLLER_ENABLED", "value": "true" },
      { "name": "FRONTEND_EMAIL_DOMAIN", "value": "${local.email_domain}" },
      { "name": "FRONTEND_EMAIL_FEEDBACK_TO", "value": "${local.email_feedback_address}" },
      { "name": "FRONTEND_EMAIL_REPORT_TO", "value": "${local.email_report_address}" },
      { "name": "FRONTEND_EMAIL_UPDATE_TO", "value": "${local.email_update_address}" },
      { "name": "FRONTEND_FILESCANNER_SSLVERIFY", "value": "False" },
      { "name": "FRONTEND_FILESCANNER_URL", "value": "https://${local.scan_service_fqdn}:8443" },
      { "name": "FRONTEND_NONADMIN_HOST", "value": "https://${aws_route53_record.front.fqdn}" },
      { "name": "FRONTEND_OAUTH2_CLIENT_ID", "value": "0" },
      { "name": "FRONTEND_OAUTH2_ENABLED", "value": "false" },
      { "name": "FRONTEND_ROLE", "value": "front" },
      { "name": "FRONTEND_S3_BUCKETNAME", "value": "pa-uploads-${terraform.workspace}" },
      { "name": "FRONTEND_SESSION_COOKIE_SECURE", "value": "true" },
      { "name": "FRONTEND_SESSION_MEMCACHE", "value": "memcachefront" },
      { "name": "FRONTEND_SESSION_REDIS_DSN", "value": "redis://${aws_route53_record.front_redis.fqdn}" },
      { "name": "FRONTEND_SMTP_DEFAULT_HOSTNAME", "value": "email-smtp.eu-west-1.amazonaws.com" },
      { "name": "FRONTEND_SMTP_DEFAULT_PORT", "value": "587" },
      { "name": "FRONTEND_SMTP_SECURE_HOSTNAME", "value": "email-smtp.eu-west-1.amazonaws.com" },
      { "name": "FRONTEND_SMTP_SECURE_PORT", "value": "25" },
      { "name": "FRONTEND_URL_ADMIN", "value": "https://${aws_route53_record.admin.fqdn}" },
      { "name": "FRONTEND_URL_FRONTEND", "value": "https://${aws_route53_record.front.fqdn}" },
      { "name": "NGINX_INDEX", "value": "app.php" },
      { "name": "OPG_DOCKER_TAG", "value": "${var.OPG_DOCKER_TAG}" },
      { "name": "OPG_NGINX_CLIENTBODYTIMEOUT", "value": "240s" },
      { "name": "OPG_NGINX_CLIENTMAXBODYSIZE", "value": "10M" },
      { "name": "OPG_NGINX_INDEX", "value": "app.php" },
      { "name": "OPG_NGINX_ROOT", "value": "/app/web" },
      { "name": "OPG_NGINX_SERVER_NAMES", "value": "*.${local.domain_name} *.${terraform.workspace}.internal ~.*" },
      { "name": "OPG_NGINX_SSL_FORCE_REDIRECT", "value": "1" },
      { "name": "OPG_PHP_POOL_CHILDREN_MAX", "value": "12" },
      { "name": "OPG_SERVICE", "value": "front" },
      { "name": "OPG_STACKNAME", "value": "${terraform.workspace}" },
      { "name": "WKHTMLTOPDF_ADDRESS", "value": "http://${local.wkhtmltopdf_service_fqdn}" }
    ]
  }
  
EOF

}

