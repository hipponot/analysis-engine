
resource "aws_s3_bucket" "raw_data" {
  bucket = "${var.cluster_name}-${data.aws_caller_identity.current.account_id}-raw-data"

  tags = {
    Name = "${var.cluster_name}-raw-data"
  }
}

resource "aws_s3_bucket" "processed_data" {
  bucket = "${var.cluster_name}-${data.aws_caller_identity.current.account_id}-processed-data"

  tags = {
    Name = "${var.cluster_name}-processed-data"
  }
}
