"""
이 파일 실행 전에 destination 폴더의 권한을 변경하기
sudo chmod -R 777 /mnt/hj_black/kradar
"""

#!/usr/bin/env python3
import subprocess
from pathlib import Path

# ==== 설정 섹션 ====
# SSH config 에 정의된 host alias
SSH_ALIAS      = "희준_서버"

# 원격지 기본 경로 (시퀀스별로 /1, /2, … /58 생성됨)
DEST_BASE_PATH = "/mnt/hj_black/kradar"

# 로컬 루트 디렉토리 목록
SOURCE_ROOTS = [
    "/mnt/ssd4tb1",
    "/mnt/ssd4tb2",
    "/mnt/ssd4tb3",
    "/mnt/ssd4tb4",
]

# 복사할 시퀀스 번호 범위
SEQUENCES = range(1, 59)   # 1~58

# 각 시퀀스 폴더 아래 복사할 폴더/파일 이름
KEYS = [
    "cam-front",
    "info_calib",
    "info_label",
    "os2-64",
    "sparse_cube",
    "description.txt",
]
# ====================

def run(cmd):
    print("> " + " ".join(cmd))
    subprocess.run(cmd, check=True)

for root in SOURCE_ROOTS:
    for seq in SEQUENCES:
        local_seq_dir = Path(root) / str(seq)
        if not local_seq_dir.is_dir():
            continue

        # 원격에 생성될 시퀀스별 경로
        remote_seq_dir = f"{DEST_BASE_PATH}/{seq}"

        # 1) 원격에 디렉토리 만들고, 소유권을 접속 계정으로 변경
        # run([
        #     "ssh", "-q", SSH_ALIAS,
        #     f"mkdir -p {remote_seq_dir}"    
        # ])

        # 2) KEY 목록을 순회하며 scp 로 복사
        for key in KEYS:
            src = local_seq_dir / key
            if not src.exists():
                print(f"· 건너뜀: {src} (존재하지 않음)")
                continue

            print(f"복사: {src} → {remote_seq_dir}/")
            run([
                "scp", "-q", "-r",     # -q: quiet mode
                str(src),
                f"{SSH_ALIAS}:{remote_seq_dir}/"
            ])
