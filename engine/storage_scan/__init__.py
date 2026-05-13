"""SentraCore — Disk cleanup scanning + large file browser."""

from engine.storage_scan.cleaner import CleanResult, apply_cleanup
from engine.storage_scan.cleanup_categories import (
    CleanupCategory,
    available_categories,
    get_category,
)
from engine.storage_scan.finder import LargeFile, find_large_files
from engine.storage_scan.scanner import CategoryScanResult, ScanResult, run_scan

__all__ = [
    "CategoryScanResult",
    "CleanupCategory",
    "CleanResult",
    "LargeFile",
    "ScanResult",
    "apply_cleanup",
    "available_categories",
    "find_large_files",
    "get_category",
    "run_scan",
]
