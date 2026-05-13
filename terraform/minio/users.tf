resource "minio_iam_user" "cnpg_svc" {
  name = "cnpg-svc"
  lifecycle { ignore_changes = [secret] }
}

# TODO: consoleAdmin is over-privileged for a read-only homepage widget.
# Pre-existing state imported as-is — scope down to readonly in a follow-up PR.
resource "minio_iam_user" "homepage_monitor" {
  name = "homepage-monitor"
  lifecycle { ignore_changes = [secret] }
}

resource "minio_iam_user" "tofu_svc" {
  name = "tofu-svc"
  lifecycle { ignore_changes = [secret] }
}

resource "minio_iam_user" "velero_svc" {
  name = "velero-svc"
  lifecycle { ignore_changes = [secret] }
}

resource "minio_iam_user_policy_attachment" "cnpg_svc" {
  user_name   = minio_iam_user.cnpg_svc.name
  policy_name = minio_iam_policy.cnpg.name
}

# TODO: Replace consoleAdmin with a scoped read-only policy (follow-up PR).
resource "minio_iam_user_policy_attachment" "homepage_monitor" {
  user_name   = minio_iam_user.homepage_monitor.name
  policy_name = "consoleAdmin"
}

resource "minio_iam_user_policy_attachment" "tofu_svc" {
  user_name   = minio_iam_user.tofu_svc.name
  policy_name = minio_iam_policy.tofu_state.name
}

resource "minio_iam_user_policy_attachment" "velero_svc" {
  user_name   = minio_iam_user.velero_svc.name
  policy_name = minio_iam_policy.velero.name
}
