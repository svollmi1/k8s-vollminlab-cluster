# Buckets
import {
  to = minio_s3_bucket.cnpg_backups
  id = "cnpg-backups"
}

import {
  to = minio_s3_bucket.loki
  id = "loki"
}

import {
  to = minio_s3_bucket.terraform_state
  id = "terraform-state"
}

import {
  to = minio_s3_bucket.velero
  id = "velero"
}

# IAM Policies
import {
  to = minio_iam_policy.cnpg
  id = "cnpg-policy"
}

import {
  to = minio_iam_policy.velero
  id = "velero-policy"
}

import {
  to = minio_iam_policy.tofu_state
  id = "tofu-state-policy"
}

# IAM Users
import {
  to = minio_iam_user.cnpg_svc
  id = "cnpg-svc"
}

import {
  to = minio_iam_user.homepage_monitor
  id = "homepage-monitor"
}

import {
  to = minio_iam_user.tofu_svc
  id = "tofu-svc"
}

import {
  to = minio_iam_user.velero_svc
  id = "velero-svc"
}

# Policy attachments
import {
  to = minio_iam_user_policy_attachment.cnpg_svc
  id = "cnpg-svc/cnpg-policy"
}

import {
  to = minio_iam_user_policy_attachment.tofu_svc
  id = "tofu-svc/tofu-state-policy"
}

import {
  to = minio_iam_user_policy_attachment.velero_svc
  id = "velero-svc/velero-policy"
}
