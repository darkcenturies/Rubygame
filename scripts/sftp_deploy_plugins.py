#!/usr/bin/env python3
"""Upload local plugins/ to Shockbyte Rubygame/plugins via SFTP."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import paramiko

REMOTE_PREFIX = "Rubygame/plugins"


def mkdir_p(sftp: paramiko.SFTPClient, remote_dir: str) -> None:
    if not remote_dir or remote_dir in (".", "/"):
        return
    parts = remote_dir.replace("\\", "/").strip("/").split("/")
    built: list[str] = []
    for part in parts:
        built.append(part)
        path = "/".join(built)
        try:
            sftp.stat(path)
        except OSError:
            sftp.mkdir(path)


def main() -> int:
    host = os.environ["SHOCKBYTE_SFTP_HOST"]
    port = int(os.environ.get("SHOCKBYTE_SFTP_PORT", "2222"))
    user = os.environ["SHOCKBYTE_SFTP_USER"]
    password = os.environ["SHOCKBYTE_SFTP_PASSWORD"]
    local_root = Path(os.environ.get("LOCAL_PLUGINS", "plugins")).resolve()

    if not local_root.is_dir():
        print(f"Missing local plugins dir: {local_root}", file=sys.stderr)
        return 1

    transport = paramiko.Transport((host, port))
    transport.connect(username=user, password=password)
    sftp = paramiko.SFTPClient.from_transport(transport)
    if sftp is None:
        print("SFTP client setup failed", file=sys.stderr)
        return 1

    try:
        print(f"Remote cwd: {sftp.getcwd() or '/'}")
        files = sorted(p for p in local_root.rglob("*") if p.is_file())
        print(f"Uploading {len(files)} files to {REMOTE_PREFIX}/")

        for local_file in files:
            rel = local_file.relative_to(local_root).as_posix()
            remote_path = f"{REMOTE_PREFIX}/{rel}"
            remote_dir = os.path.dirname(remote_path)
            if remote_dir:
                mkdir_p(sftp, remote_dir)
            sftp.put(str(local_file), remote_path)
            print(f"put {rel}")

        print("Deploy succeeded.")
        return 0
    finally:
        sftp.close()
        transport.close()


if __name__ == "__main__":
    raise SystemExit(main())
