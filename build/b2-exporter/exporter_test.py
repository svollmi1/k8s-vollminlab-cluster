from unittest.mock import MagicMock
import pytest
import exporter


def _make_file(size: int):
    f = MagicMock()
    f.size = size
    return f


def test_get_bucket_stats_sums_all_file_sizes():
    mock_bucket = MagicMock()
    mock_bucket.ls.return_value = [
        (_make_file(1000), None),
        (_make_file(2500), None),
        (_make_file(500), None),
    ]
    total_bytes, total_files = exporter.get_bucket_stats(mock_bucket)
    assert total_bytes == 4000
    assert total_files == 3
    mock_bucket.ls.assert_called_once_with(recursive=True, latest_only=False)


def test_get_bucket_stats_empty_bucket():
    mock_bucket = MagicMock()
    mock_bucket.ls.return_value = []
    total_bytes, total_files = exporter.get_bucket_stats(mock_bucket)
    assert total_bytes == 0
    assert total_files == 0


def test_get_bucket_stats_single_file():
    mock_bucket = MagicMock()
    mock_bucket.ls.return_value = [(_make_file(999999999), None)]
    total_bytes, total_files = exporter.get_bucket_stats(mock_bucket)
    assert total_bytes == 999999999
    assert total_files == 1
