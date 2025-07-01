
resource "aws_batch_compute_environment" "gpu_compute_env" {
  compute_environment_name = "${var.cluster_name}-gpu-compute-env"
  type                     = "MANAGED"

  compute_resources {
    type        = "SPOT"
    max_vcpus   = 256
    min_vcpus   = 0
    instance_role = aws_iam_instance_profile.batch_instance_profile.arn
    spot_iam_fleet_role = aws_iam_role.batch_spot_fleet_role.arn
    instance_type = [
      "g4dn.xlarge",
      "g4dn.2xlarge",
    ]
    security_group_ids = [module.eks.node_security_group_id]
    subnets = module.vpc.private_subnets
  }

  service_role = aws_iam_role.batch_service_role.arn

  depends_on = [
    aws_iam_instance_profile.batch_instance_profile,
    aws_iam_role.batch_service_role,
  ]
}

resource "aws_batch_job_queue" "gpu_job_queue" {
  name     = "${var.cluster_name}-gpu-job-queue"
  priority = 1
  state    = "ENABLED"
  compute_environment_order {
    order = 1
    compute_environment = aws_batch_compute_environment.gpu_compute_env.arn
  }
}

resource "aws_batch_job_definition" "video_processing" {
  name = "${var.cluster_name}-video-processing"
  type = "container"

  container_properties = jsonencode({
    "image": "public.ecr.aws/amazonlinux/amazonlinux:latest",
    "vcpus": 2,
    "memory": 2048,
    "command": ["echo", "Hello World"],
    "jobRoleArn": aws_iam_role.batch_job_role.arn
  })

  depends_on = [
    aws_iam_role.batch_job_role,
  ]
}
