#!/usr/bin/env python3
import os
import json
from pathlib import Path

# 설정
roots = [
    Path("/mnt/ssd4tb1"),
    Path("/mnt/ssd4tb2"),
    Path("/mnt/ssd4tb3"),
    Path("/mnt/ssd4tb4"),
]
sequences = range(1, 59)  # 1~58
folder_keys = ["cam-front", "info_calib", "info_label", "os2-64", "sparse_cube"]

def get_dir_size(path: Path) -> int:
    """디렉토리 내 모든 파일 크기의 합을 바이트 단위로 반환."""
    total = 0
    for f in path.rglob('*'):
        if f.is_file():
            total += f.stat().st_size
    return total

results = {}

for root in roots:
    for seq in sequences:
        seq_dir = root / str(seq)
        if not seq_dir.is_dir():
            continue
        print(f"Checking {seq_dir}")
        stats = {}
        total = 0
        for key in folder_keys:
            sub = seq_dir / key
            size = get_dir_size(sub) if sub.is_dir() else 0
            stats[key] = size
            total += size
        stats["total"] = total

        # 결과 저장 (키는 "ssd4tbX/숫자" 형태)
        results[f"{root.name}/{seq}"] = stats

# JSON으로 보기 좋게 출력
print(json.dumps(results, indent=2, ensure_ascii=False))
