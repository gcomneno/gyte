#!/usr/bin/env bash
set -euo pipefail

# GYTE smoke test (offline / deterministic)
# Goals:
# - No network / no auth required
# - Validate deterministic contracts for:
#   - gyte-explain invalid_url behavior
#   - gyte-digest validation (browser whitelist, cookies fail-fast) via dry-run
#
# NOTE:
# - Shellcheck gate is already enforced by the CI workflow step "Shellcheck scripts".
# - This smoke must NOT depend on user-local installs or live YouTube sessions.

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "[smoke] ERROR: $*" >&2; exit 1; }
ok()  { echo "[smoke] OK: $*" >&2; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

need bash
need mktemp
need python3
need find
need stat
need sed

# Ensure scripts exist (gyte-explain is used by the smoke)
[[ -x "$ROOT/scripts/gyte-explain" ]] || die "missing or not executable: scripts/gyte-explain"

# IMPORTANT: make repo commands available in CI (no user-local install).
export PATH="$ROOT/bin:$ROOT/scripts:$PATH"

ok "repo root: $ROOT"

# 0) gyte-digest offline validation (dry-run only)
# 0.1) anon cookies -> must fail fast (R7), even in dry-run
TMPDIR_SMOKE="$(mktemp -d -t gyte-smoke.XXXXXX)"
cleanup_smoke() { rm -rf "$TMPDIR_SMOKE" 2>/dev/null || true; }
trap cleanup_smoke EXIT

ANON="$TMPDIR_SMOKE/anon.cookies"
AUTH="$TMPDIR_SMOKE/auth.cookies"

printf "# Netscape HTTP Cookie File\n.youtube.com\tTRUE\t/\tFALSE\t0\tPREF\thl=en\n" >"$ANON"

set +e
"$ROOT/bin/gyte-digest" --cookies "$ANON" --dry-run >/dev/null 2>&1
RC=$?
set -e
[[ "$RC" -eq 1 ]] || die "expected rc=1 for anon cookies (fail-fast), got rc=$RC"
ok "gyte-digest: anon cookies fail-fast (rc=1) OK"

# 0.2) auth-like cookies (dummy) -> must pass validation and print dry-run (rc=0)
printf "# Netscape HTTP Cookie File\n.youtube.com\tTRUE\t/\tTRUE\t0\tSAPISID\tDUMMY\n" >"$AUTH"
"$ROOT/bin/gyte-digest" --cookies "$AUTH" --dry-run >/dev/null
ok "gyte-digest: auth-like cookies dummy passes validation in dry-run OK"

# 0.3) invalid browser -> must fail rc=1
set +e
"$ROOT/bin/gyte-digest" --dry-run --browser ie >/dev/null 2>&1
RC=$?
set -e
[[ "$RC" -eq 1 ]] || die "expected rc=1 for invalid browser, got rc=$RC"
ok "gyte-digest: invalid browser whitelist (rc=1) OK"

# 1) Prepare a deterministic fake TSV (invalid URL -> no network)
OUT_BASE="$TMPDIR_SMOKE/out"
mkdir -p "$OUT_BASE"

TSV="$TMPDIR_SMOKE/in.tsv"
cat >"$TSV" <<'TSVEOF'
#id	title	url
1	Video finto (invalid url)	https://example.com/not-youtube
TSVEOF

# 2) Run gyte-explain
# Expect:
# - exit code 2 (invalid_url)
# - stdout empty (no summary)
# - stderr non-empty (error message)
STDOUT="$TMPDIR_SMOKE/stdout.txt"
STDERR="$TMPDIR_SMOKE/stderr.txt"
set +e
"$ROOT/scripts/gyte-explain" 1 --in "$TSV" --ai off --out-base "$OUT_BASE" >"$STDOUT" 2>"$STDERR"
RC=$?
set -e

[[ "$RC" -eq 2 ]] || die "expected rc=2 for invalid_url, got rc=$RC"
[[ ! -s "$STDOUT" ]] || die "expected stdout empty for invalid_url (summary must not be emitted)"
[[ -s "$STDERR" ]] || die "expected stderr non-empty for invalid_url"
ok "gyte-explain invalid_url contract (rc/stdout/stderr) OK"

# 3) Locate last run in OUT_BASE (robust: do not rely on directory naming)
# A "run dir" is identified by:
# - <run>/manifest.json
# - <run>/items/001/manifest.json
best_run=""
best_mtime=0

while IFS= read -r run_manifest; do
  run_dir="$(dirname -- "$run_manifest")"
  [[ -d "$run_dir/items/001" ]] || continue
  [[ -f "$run_dir/items/001/manifest.json" ]] || continue

  mtime="$(stat -c %Y -- "$run_dir" 2>/dev/null || echo 0)"
  if [[ "$mtime" -ge "$best_mtime" ]]; then
    best_mtime="$mtime"
    best_run="$run_dir"
  fi
done < <(find "$OUT_BASE" -maxdepth 4 -type f -name "manifest.json" 2>/dev/null || true)

RUN="$best_run"

if [[ -z "$RUN" ]]; then
  echo "[smoke] DEBUG: cannot locate run dir under OUT_BASE: $OUT_BASE" >&2
  echo "[smoke] DEBUG: OUT_BASE listing:" >&2
  find "$OUT_BASE" -maxdepth 6 -print >&2 || true

  echo "[smoke] DEBUG: gyte-explain stderr (first 200 lines):" >&2
  sed -n '1,200p' "$STDERR" >&2 || true

  echo "[smoke] DEBUG: gyte-explain stdout (first 200 lines):" >&2
  sed -n '1,200p' "$STDOUT" >&2 || true

  echo "[smoke] DEBUG: TMPDIR tree (maxdepth 6): $TMPDIR_SMOKE" >&2
  find "$TMPDIR_SMOKE" -maxdepth 6 -print >&2 || true

  echo "[smoke] DEBUG: searching for manifest.json anywhere under TMPDIR:" >&2
  find "$TMPDIR_SMOKE" -type f -name "manifest.json" -print >&2 || true

  die "cannot find run dir in $OUT_BASE"
fi

[[ -d "$RUN" ]] || die "run is not a directory: $RUN"

ITEM="$RUN/items/001"
[[ -d "$ITEM" ]] || die "missing item dir: $ITEM"

# 4) Manifests must always exist
[[ -f "$RUN/manifest.json" ]] || die "missing run manifest: $RUN/manifest.json"
[[ -f "$ITEM/manifest.json" ]] || die "missing item manifest: $ITEM/manifest.json"
ok "manifest files exist (run + item)"

# 5) Validate essential fields + status
python3 - "$ITEM/manifest.json" <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p, "r", encoding="utf-8"))
req = [
  "id","title","url","langs","ai_mode",
  "transcript_source","summary_source","status","error_message",
  "paths","timestamps","meta"
]
missing = [k for k in req if k not in m]
if missing:
  raise SystemExit(f"missing keys in item manifest: {missing}")

assert m["status"] == "invalid_url", m.get("status")
assert m["transcript_source"] == "none", m.get("transcript_source")
assert m["summary_source"] == "none", m.get("summary_source")
print("status:", m["status"])
print("error_message:", m["error_message"])
PY

ok "item manifest fields + invalid_url status OK"
ok "SMOKE TEST PASSED"
