#!/usr/bin/env bash
# lib/gyte-manifest.sh
# Manifest writer helpers for GYTE
# Dependencies: bash + python3 (stdlib only)

set -euo pipefail

: "${GYTE_MANIFEST_VERBOSE:=0}"

gyte__m_log() {
  if [[ "${GYTE_MANIFEST_VERBOSE}" == "1" ]]; then
    printf '[manifest] %s\n' "$*" >&2
  fi
}

gyte__m_now_iso() {
  python3 - <<'PY'
from datetime import datetime
print(datetime.now().astimezone().isoformat(timespec="seconds"))
PY
}

gyte__m_atomic_write_json() {
  local target="$1"
  local tmp="${target}.tmp.$$"
  umask 022
  cat > "${tmp}"
  mv -f "${tmp}" "${target}"
}

gyte__m_item_manifest_init() {
  local item_dir="${GYTE_ITEM_DIR:?missing GYTE_ITEM_DIR}"
  local id="${GYTE_ITEM_ID:?missing GYTE_ITEM_ID}"
  local ai_mode="${GYTE_AI_MODE:?missing GYTE_AI_MODE}"
  local langs_csv="${GYTE_LANGS_CSV:-}"
  local title="${GYTE_TITLE:-}"
  local url="${GYTE_URL:-}"
  local created
  created="$(gyte__m_now_iso)"

  mkdir -p "${item_dir}"

  python3 - <<'PY' \
    "${item_dir}" "${id}" "${title}" "${url}" "${langs_csv}" "${ai_mode}" "${created}" \
  | gyte__m_atomic_write_json "${item_dir}/manifest.json"
import json, os, sys

item_dir, vid, title, url, langs_csv, ai_mode, created = sys.argv[1:]

langs = [x.strip() for x in (langs_csv or "").split(",") if x.strip()]

paths = {
  "title": "title.txt",
  "url": "url.txt",
  "langs": "langs.txt",
  "row_tsv": "row.tsv",
  "transcript": "transcript.txt",
  "summary": "summary.txt",
  "transcript_error": "transcript_error.txt",
}

exists = {k: os.path.exists(os.path.join(item_dir, rel)) for k, rel in paths.items()}

doc = {
  "schema": "gyte.manifest.item.v1",
  "id": vid,
  "title": title,
  "url": url,
  "langs": langs,
  "ai_mode": ai_mode,
  "transcript_source": "none",
  "summary_source": "none",
  "status": "error",
  "error_message": None,
  "paths": paths,
  "timestamps": {"created": created, "updated": created},
  "meta": {
    "exists": exists,
    "reflowed_transcript": False,
    "stdout_summary_emitted": False,
    "inputs": {"tsv_row_present": True},
  },
}

print(json.dumps(doc, ensure_ascii=False, indent=2, sort_keys=True))
PY
}

gyte__m_item_manifest_update() {
  local item_dir="${GYTE_ITEM_DIR:?missing GYTE_ITEM_DIR}"
  local path="${item_dir}/manifest.json"

  if [[ ! -f "${path}" ]]; then
    gyte__m_log "item manifest missing, recreating skeleton"
    : "${GYTE_ITEM_ID:?missing GYTE_ITEM_ID for recovery init}"
    : "${GYTE_AI_MODE:?missing GYTE_AI_MODE for recovery init}"
    gyte__m_item_manifest_init
  fi

  local updated
  updated="$(gyte__m_now_iso)"

  python3 - <<'PY' \
    "${item_dir}" "${path}" "${updated}" \
    "${GYTE_TITLE-}" "${GYTE_URL-}" "${GYTE_LANGS_CSV-}" "${GYTE_AI_MODE-}" \
    "${GYTE_TRANSCRIPT_SOURCE-}" "${GYTE_SUMMARY_SOURCE-}" \
    "${GYTE_STATUS-}" "${GYTE_ERROR_MESSAGE-}" \
    "${GYTE_REFLOWED-}" "${GYTE_STDOUT_SUMMARY_EMITTED-}" "${GYTE_TSV_ROW_PRESENT-}" \
  | gyte__m_atomic_write_json "${path}"
import json, os, sys

item_dir, path, updated = sys.argv[1:4]
title, url, langs_csv, ai_mode = sys.argv[4:8]
transcript_source, summary_source = sys.argv[8:10]
status, error_message = sys.argv[10:12]
reflowed, stdout_emitted, tsv_row_present = sys.argv[12:15]

with open(path, "r", encoding="utf-8") as f:
  doc = json.load(f)

def set_if_nonempty(key, val):
  if val is not None and val != "":
    doc[key] = val

def parse_langs(csv):
  if csv is None or csv == "":
    return None
  return [x.strip() for x in csv.split(",") if x.strip()]

set_if_nonempty("title", title)
set_if_nonempty("url", url)
if langs_csv not in (None, ""):
  doc["langs"] = parse_langs(langs_csv) or []
set_if_nonempty("ai_mode", ai_mode)

if transcript_source in ("subs", "whisper", "none"):
  doc["transcript_source"] = transcript_source
if summary_source in ("local", "openai", "none"):
  doc["summary_source"] = summary_source
if status in ("ok", "no_transcript", "invalid_url", "error"):
  doc["status"] = status

if error_message == "__NULL__":
  doc["error_message"] = None
elif error_message not in (None, ""):
  doc["error_message"] = str(error_message).splitlines()[0][:300]

doc.setdefault("timestamps", {})
doc["timestamps"]["updated"] = updated
doc["timestamps"].setdefault("created", updated)

doc.setdefault("meta", {})
if reflowed in ("0", "1"):
  doc["meta"]["reflowed_transcript"] = (reflowed == "1")
if stdout_emitted in ("0", "1"):
  doc["meta"]["stdout_summary_emitted"] = (stdout_emitted == "1")
doc["meta"].setdefault("inputs", {})
if tsv_row_present in ("0", "1"):
  doc["meta"]["inputs"]["tsv_row_present"] = (tsv_row_present == "1")

fixed = {
  "title": "title.txt",
  "url": "url.txt",
  "langs": "langs.txt",
  "row_tsv": "row.tsv",
  "transcript": "transcript.txt",
  "summary": "summary.txt",
  "transcript_error": "transcript_error.txt",
}
doc["paths"] = (doc.get("paths") or {})
doc["paths"].update(fixed)

exists = {k: os.path.exists(os.path.join(item_dir, rel)) for k, rel in fixed.items()}
doc["meta"].setdefault("exists", {})
doc["meta"]["exists"] = exists

print(json.dumps(doc, ensure_ascii=False, indent=2, sort_keys=True))
PY
}

gyte__m_item_manifest_finalize() {
  local item_dir="${GYTE_ITEM_DIR:?missing GYTE_ITEM_DIR}"
  local path="${item_dir}/manifest.json"
  if [[ ! -f "${path}" ]]; then
    gyte__m_log "finalize: missing item manifest, creating skeleton"
    : "${GYTE_ITEM_ID:?missing GYTE_ITEM_ID for recovery init}"
    : "${GYTE_AI_MODE:?missing GYTE_AI_MODE for recovery init}"
    gyte__m_item_manifest_init
  fi

  local updated
  updated="$(gyte__m_now_iso)"

  python3 - <<'PY' \
    "${item_dir}" "${path}" "${updated}" \
    "${GYTE_STATUS-}" \
  | gyte__m_atomic_write_json "${path}"
import json, os, sys

item_dir, path, updated, forced_status = sys.argv[1:]

with open(path, "r", encoding="utf-8") as f:
  doc = json.load(f)

doc.setdefault("timestamps", {})
doc["timestamps"]["updated"] = updated
doc["timestamps"].setdefault("created", updated)

fixed = {
  "title": "title.txt",
  "url": "url.txt",
  "langs": "langs.txt",
  "row_tsv": "row.tsv",
  "transcript": "transcript.txt",
  "summary": "summary.txt",
  "transcript_error": "transcript_error.txt",
}
doc["paths"] = (doc.get("paths") or {})
doc["paths"].update(fixed)

exists = {k: os.path.exists(os.path.join(item_dir, rel)) for k, rel in fixed.items()}
doc.setdefault("meta", {})
doc["meta"]["exists"] = exists

if forced_status in ("ok", "no_transcript", "invalid_url", "error"):
  doc["status"] = forced_status
else:
  cur = doc.get("status")
  if cur == "error":
    ts = doc.get("transcript_source", "none")
    em = doc.get("error_message")
    if ts in ("subs", "whisper") and em in (None, "") and exists.get("transcript"):
      doc["status"] = "ok"
  elif cur not in ("ok", "no_transcript", "invalid_url", "error"):
    ts = doc.get("transcript_source", "none")
    em = doc.get("error_message")
    if ts in ("subs", "whisper") and em in (None, "") and exists.get("transcript"):
      doc["status"] = "ok"
    else:
      doc["status"] = "no_transcript" if ts == "none" else "error"

print(json.dumps(doc, ensure_ascii=False, indent=2, sort_keys=True))
PY
}

gyte__m_run_manifest_update() {
  local run_dir="${GYTE_RUN_DIR:?missing GYTE_RUN_DIR}"
  local run_id="${GYTE_RUN_ID:?missing GYTE_RUN_ID}"
  local ai_mode="${GYTE_AI_MODE:?missing GYTE_AI_MODE}"
  local langs_csv="${GYTE_LANGS_CSV:-}"
  local item_id="${GYTE_ITEM_ID:?missing GYTE_ITEM_ID}"
  local gyte_version="${GYTE_GYTE_VERSION:-UNKNOWN}"
  local argv_str="${GYTE_ARGV:-}"
  local argv_json="${GYTE_ARGV_JSON:-}"
  local path="${run_dir}/manifest.json"
  local now
  now="$(gyte__m_now_iso)"

  local item_status="error"
  if [[ -f "${run_dir}/items/${item_id}/manifest.json" ]]; then
    item_status="$(python3 - <<'PY' "${run_dir}/items/${item_id}/manifest.json"
import json, sys
p = sys.argv[1]
try:
  with open(p, "r", encoding="utf-8") as f:
    d = json.load(f)
  print(d.get("status","error"))
except Exception:
  print("error")
PY
)"
  fi

  python3 - <<'PY' \
    "${path}" "${run_id}" "${gyte_version}" "${ai_mode}" "${langs_csv}" \
    "${argv_json}" "${argv_str}" \
    "${item_id}" "${item_status}" "${now}" "${GYTE_RUN_STATUS_FORCED-}" \
  | gyte__m_atomic_write_json "${path}"
import json, os, sys

path, run_id, gyte_version, ai_mode, langs_csv, argv_json, argv_str, item_id, item_status, now, forced_run_status = sys.argv[1:]

def parse_langs(csv):
  if not csv:
    return []
  return [x.strip() for x in csv.split(",") if x.strip()]

def argv_from_json(s):
  if not s:
    return None
  try:
    v = json.loads(s)
  except Exception:
    return None
  if isinstance(v, list) and all(isinstance(x, str) for x in v):
    return v
  return None

def safe_argv_fallback(s):
  return [s] if s else []

argv_list = argv_from_json(argv_json)
if argv_list is None:
  argv_list = safe_argv_fallback(argv_str)

doc = None
if os.path.exists(path):
  try:
    with open(path, "r", encoding="utf-8") as f:
      doc = json.load(f)
  except Exception:
    doc = None

if not isinstance(doc, dict):
  doc = {
    "schema": "gyte.manifest.run.v1",
    "gyte_version": gyte_version,
    "run": {"id": run_id, "dir": ".", "timestamp_start": now, "timestamp_end": now, "status": "error"},
    "config": {"ai_mode": ai_mode, "langs": parse_langs(langs_csv), "argv": argv_list},
    "counts": {"items_total": 0, "items_ok": 0, "items_error": 0, "items_no_transcript": 0, "items_invalid_url": 0},
    "items": {},
    "paths": {"run_manifest": "manifest.json", "items_dir": "items"},
    "notes": []
  }

doc["schema"] = "gyte.manifest.run.v1"
doc["gyte_version"] = gyte_version
doc.setdefault("run", {})
doc["run"]["id"] = run_id
doc["run"]["dir"] = "."
doc["run"].setdefault("timestamp_start", now)
doc["run"]["timestamp_end"] = now

doc.setdefault("config", {})
doc["config"]["ai_mode"] = ai_mode
doc["config"]["langs"] = parse_langs(langs_csv)
doc["config"]["argv"] = argv_list

items = doc.get("items")
if isinstance(items, list):
  m = {}
  for it in items:
    if isinstance(it, dict) and "id" in it:
      _id = str(it["id"])
      m[_id] = {"status": it.get("status","error"), "path": it.get("path", f"items/{_id}/manifest.json")}
  items = m
if not isinstance(items, dict):
  items = {}
doc["items"] = items

st = item_status if item_status in ("ok","no_transcript","invalid_url","error") else "error"
doc["items"][item_id] = {"status": st, "path": f"items/{item_id}/manifest.json"}

counts = {"items_total":0,"items_ok":0,"items_error":0,"items_no_transcript":0,"items_invalid_url":0}
for _id, it in doc["items"].items():
  counts["items_total"] += 1
  s = (it or {}).get("status","error")
  if s == "ok":
    counts["items_ok"] += 1
  elif s == "no_transcript":
    counts["items_no_transcript"] += 1
  elif s == "invalid_url":
    counts["items_invalid_url"] += 1
  else:
    counts["items_error"] += 1
doc["counts"] = counts

if forced_run_status in ("ok","error"):
  doc["run"]["status"] = forced_run_status
else:
  doc["run"]["status"] = "error" if counts["items_error"] > 0 else "ok"

print(json.dumps(doc, ensure_ascii=False, indent=2, sort_keys=True))
PY
}
