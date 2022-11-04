resource "aws_cloudwatch_log_group" "log" {
  name = "/ecs/${var.environment}-${var.name}"
  retention_in_days = var.retention_days
}
