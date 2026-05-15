#!/usr/bin/env python3
import os
import time
import logging
from prometheus_client import start_http_server, Gauge
import b2sdk.v2 as b2

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

BUCKET_BYTES = Gauge("b2_bucket_bytes_total", "Total bytes stored in B2 bucket", ["bucket"])
BUCKET_FILES = Gauge("b2_bucket_file_count_total", "Total file versions in B2 bucket", ["bucket"])

INTERVAL = int(os.environ.get("B2_REFRESH_INTERVAL", "1800"))


def get_bucket_stats(bucket) -> tuple[int, int]:
    total_bytes = 0
    total_files = 0
    for file_version, _ in bucket.ls(recursive=True, latest_only=False):
        total_bytes += file_version.size or 0
        total_files += 1
    return total_bytes, total_files


def run_loop():
    key_id = os.environ["B2_APPLICATION_KEY_ID"]
    app_key = os.environ["B2_APPLICATION_KEY"]
    bucket_name = os.environ["B2_BUCKET_NAME"]
    while True:
        try:
            info = b2.InMemoryAccountInfo()
            api = b2.B2Api(info)
            api.authorize_account("production", key_id, app_key)
            bucket = api.get_bucket_by_name(bucket_name)
            total_bytes, total_files = get_bucket_stats(bucket)
            BUCKET_BYTES.labels(bucket=bucket_name).set(total_bytes)
            BUCKET_FILES.labels(bucket=bucket_name).set(total_files)
            log.info("updated: %d bytes, %d files in %s", total_bytes, total_files, bucket_name)
        except Exception as e:
            log.error("failed to update metrics: %s", e)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    start_http_server(8080)
    log.info("metrics server listening on :8080")
    run_loop()
