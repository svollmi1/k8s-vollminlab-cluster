resource "minio_iam_policy" "cnpg" {
  name = "cnpg-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:PutObject", "s3:DeleteObject", "s3:GetBucketLocation", "s3:GetObject"]
        Resource = ["arn:aws:s3:::cnpg-backups", "arn:aws:s3:::cnpg-backups/*"]
      },
    ]
  })
}

resource "minio_iam_policy" "velero" {
  name = "velero-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"]
        Resource = ["arn:aws:s3:::velero"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:AbortMultipartUpload", "s3:DeleteObject", "s3:GetObject", "s3:ListMultipartUploadParts", "s3:PutObject"]
        Resource = ["arn:aws:s3:::velero/*"]
      },
    ]
  })
}

resource "minio_iam_policy" "homepage_monitor" {
  name = "homepage-monitor-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:GetBucketPolicy", "s3:ListAllMyBuckets", "s3:ListBucket"]
        Resource = ["arn:aws:s3:::*"]
      },
    ]
  })
}

resource "minio_iam_policy" "tofu_state" {
  name = "tofu-state-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket", "s3:PutObject", "s3:DeleteObject", "s3:GetBucketLocation"]
        Resource = ["arn:aws:s3:::terraform-state/*", "arn:aws:s3:::terraform-state"]
      },
    ]
  })
}
