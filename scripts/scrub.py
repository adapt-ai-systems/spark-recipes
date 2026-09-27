#!/usr/bin/env python3
"""Block private data in index, worktree, reachable history, and tag metadata."""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], stderr=subprocess.DEVNULL)


def load_private_terms() -> list[str]:
    configured = os.environ.get("SPARK_RECIPES_DENYLIST_FILE")
    path = Path(configured) if configured else Path.home() / ".config" / "spark-recipes" / "denylist.txt"
    if not path.is_file():
        raise RuntimeError("private scrub deny-list missing; push refused")
    terms = [x.strip() for x in path.read_text().splitlines() if x.strip() and not x.lstrip().startswith("#")]
    if not terms:
        raise RuntimeError("private scrub deny-list empty; push refused")
    return terms


GENERIC_RULES = {
    "private IPv4": re.compile(r"(?<![\d.])(?:10(?:\.\d{1,3}){3}|192\.168(?:\.\d{1,3}){2}|172\.(?:1[6-9]|2\d|3[01])(?:\.\d{1,3}){2}|100\.(?:6[4-9]|[7-9]\d|1[01]\d|12[0-7])(?:\.\d{1,3}){2})(?![\d.])"),
    "private domain": re.compile(r"(?i)\b[\w.-]+\.(?:ts\.net|local|lan|internal)\b|\bfd7a:115c:a1e0\b"),
    "private hostname": re.compile(r"(?i)\b(?:spark-(?!(?:playbooks|recipes)\b)[a-z0-9]{4,}|dgx[1-9](?:\.[\w.-]+)?)\b"),
    "home path": re.compile(r"(?i)(?:/home/[a-z0-9_-]+/|/" + "root" + r"/|/" + "Users" + r"/|[A-Z]:\\" + "Users" + r"\\|~" + r"/|\$HOME" + r"/)"),
    "email": re.compile(r"(?i)\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b"),
    "pulse id": re.compile(r"(?i)(?<![a-f0-9])[a-f0-9]{32}(?![a-f0-9])"),
    "token prefix": re.compile(r"(?i)\b(?:gh[pousr]_|github_pat_|hf_|xox[baprs]-|sk-[a-z0-9]{12,}|AKIA[0-9A-Z]{16})[A-Za-z0-9_\-]{8,}"),
    "private key": re.compile(r"-----BEGIN (?:OPENSSH|RSA|EC|DSA|PRIVATE) PRIVATE KEY-----"),
    "credential assignment": re.compile(r"(?i)\b[A-Z0-9_]*(?:_PASS|_PASSWORD|_TOKEN|_SECRET|_API_KEY|_ACCESS_KEY|PASSWORD|TOKEN|SECRET|PASS)\s*[:=]\s*['\"]?[A-Za-z0-9_./+!@#$%^&*()=:\-]{6,}"),
    "bearer credential": re.compile(r"(?i)\bAuthorization\s*:\s*Bearer\s+[^\s]{6,}"),
}


def scan_text(name: str, data: bytes, private_terms: list[str]) -> list[str]:
    if b"\x00" in data:
        return [f"{name}: binary file not allowed"]
    try:
        body = data.decode("utf-8")
    except UnicodeDecodeError:
        return [f"{name}: non-UTF-8 file not allowed"]
    if any(ord(c) < 32 and c not in "\n\r\t" for c in body):
        return [f"{name}: control bytes not allowed"]
    rules = dict(GENERIC_RULES)
    rules["private deny-list term"] = re.compile("|".join(map(re.escape, private_terms)), re.IGNORECASE)
    findings = []
    for label, rule in rules.items():
        for hit in rule.finditer(body):
            line = body.count("\n", 0, hit.start()) + 1
            findings.append(f"{name}:{line}: {label}: {hit.group(0)[:80]}")
    return findings


def staged_blobs() -> list[tuple[str, bytes]]:
    out = []
    for raw in git("ls-files", "--stage", "-z").split(b"\x00"):
        if not raw:
            continue
        header, name = raw.split(b"\t", 1)
        mode, oid, stage = header.decode().split()
        if stage != "0":
            raise RuntimeError("unmerged index; push refused")
        out.append(("index:" + name.decode("utf-8", "replace"), git("cat-file", "blob", oid)))
    return out


def worktree_files() -> list[tuple[str, bytes]]:
    out = []
    for raw in git("ls-files", "-z").split(b"\x00"):
        if not raw:
            continue
        name = raw.decode("utf-8", "replace")
        path = ROOT / name
        if path.is_file():
            out.append(("worktree:" + name, path.read_bytes()))
    return out


def history_objects() -> list[tuple[str, bytes]]:
    try:
        rows = git("rev-list", "--objects", "--all").decode().splitlines()
    except subprocess.CalledProcessError:
        rows = []
    out, seen = [], set()
    for row in rows:
        oid, _, name = row.partition(" ")
        if oid in seen or not name:
            continue
        seen.add(oid)
        if git("cat-file", "-t", oid).strip() == b"blob":
            out.append((f"history:{name}@{oid[:12]}", git("cat-file", "blob", oid)))
    return out


def metadata_objects() -> list[tuple[str, bytes]]:
    out = []
    try:
        out.append(("commit metadata", git("log", "--all", "--format=%an <%ae> %cn <%ce> %s%n%b")))
    except subprocess.CalledProcessError:
        pass
    for raw in git("for-each-ref", "refs/tags", "--format=%(objectname) %(objecttype)").decode().splitlines():
        oid, typ = raw.split()
        if typ == "tag":
            out.append((f"tag:{oid[:12]}", git("cat-file", "tag", oid)))
    return out


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--history", action="store_true")
    args = p.parse_args()
    try:
        terms = load_private_terms()
        files = staged_blobs() + worktree_files()
        if args.history:
            files += history_objects() + metadata_objects()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"SCRUB BLOCKED: {exc}")
        return 2
    findings = []
    for name, data in files:
        findings.extend(scan_text(name, data, terms))
        findings.extend(scan_text("path", name.encode(), terms))
    if findings:
        print("SCRUB BLOCKED")
        print("\n".join(findings))
        return 1
    print(f"SCRUB PASS: {len(files)} index/worktree/history objects, {len(GENERIC_RULES)} generic checks plus private deny-list")
    return 0


if __name__ == "__main__":
    sys.exit(main())
