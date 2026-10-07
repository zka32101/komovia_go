#!/usr/bin/env python3
"""Upsert seed documents into Firestore via the REST API.

Client writes to these collections are blocked by firestore.rules, so seed
data is written with an admin OAuth token (gcloud) instead.

Usage:
  python scripts/seed_firestore.py <collection> <seed.json> [--project ID] [--dry-run]

<seed.json> maps document IDs to plain JSON objects (str / int / float /
bool / list / object / null). Existing documents with the same ID are
overwritten, so the script is idempotent.
"""
import argparse
import json
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_PROJECT = "goen-29686"


def to_value(v):
    if v is None:
        return {"nullValue": None}
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if isinstance(v, str):
        return {"stringValue": v}
    if isinstance(v, list):
        return {"arrayValue": {"values": [to_value(x) for x in v]}}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: to_value(x) for k, x in v.items()}}}
    raise TypeError(f"unsupported value: {v!r}")


def token():
    return subprocess.check_output(
        "gcloud auth print-access-token", shell=True, text=True
    ).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("collection")
    ap.add_argument("seed")
    ap.add_argument("--project", default=DEFAULT_PROJECT)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    with open(args.seed, encoding="utf-8") as f:
        docs = json.load(f)

    if args.dry_run:
        for doc_id, data in docs.items():
            print(f"[dry-run] {args.collection}/{doc_id}: {sorted(data)}")
        return 0

    tok = token()
    base = (
        f"https://firestore.googleapis.com/v1/projects/{args.project}"
        f"/databases/(default)/documents/{args.collection}"
    )
    failures = 0
    for doc_id, data in docs.items():
        body = json.dumps(
            {"fields": {k: to_value(v) for k, v in data.items()}}
        ).encode("utf-8")
        req = urllib.request.Request(
            f"{base}/{urllib.parse.quote(doc_id)}",
            data=body,
            method="PATCH",
            headers={
                "Authorization": f"Bearer {tok}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(req) as r:
                print(f"OK   {args.collection}/{doc_id} ({r.status})")
        except urllib.error.HTTPError as e:
            failures += 1
            print(f"FAIL {args.collection}/{doc_id}: {e.code} {e.read().decode()[:300]}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
