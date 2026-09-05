#!/usr/bin/env python3
"""Hash review inputs and supplied evidence; never execute tests or access keys."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def fingerprint(path):
    if path.is_symlink() or not path.is_file():
        raise ValueError("audit input must be a regular non-symlink file")
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, action="append", default=[])
    args = parser.parse_args()
    selected = set()
    for folder, pattern in [("contracts", "*.sol"), ("test", "*.js"), ("scripts", "*.js")]:
        selected.update(ROOT.joinpath(folder).rglob(pattern))
    selected.update(ROOT / name for name in ["package.json", "package-lock.json", "hardhat.config.js"])
    selected.add(Path(__file__).resolve())
    inputs = {str(p.relative_to(ROOT)): fingerprint(p) for p in sorted(selected)}
    evidence = [{"name": p.name, **fingerprint(p)} for p in args.evidence]
    manifest = {
        "schemaVersion": 1,
        "platform": "INO Security Audit Platform",
        "repository": "xitcoin-org/contracts",
        "revision": git("rev-parse", "HEAD"),
        "workingTreeDirty": bool(git("status", "--porcelain")),
        "inputs": inputs,
        "evidence": evidence,
        "limitations": ["Hashes establish identity, not correctness or execution.",
                        "Record tool versions, commands, exit codes and review conclusions alongside this manifest.",
                        "No tests, prover, deployment, network queries or transactions are run by this script."],
    }
    # Refuse to overwrite earlier evidence, including an existing symlink.
    with args.output.open("x", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
