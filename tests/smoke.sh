#!/usr/bin/env bash
set -euo pipefail

# GYTE smoke test (offline / deterministic)
# - shellcheck gate via ./scripts/gyte-lint
# - manifest contract via ./scripts/gyte-explain on invalid_url
# - validate manifest via ./scripts/gyte-lint --manifest <run>

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "[smoke] ERROR: $*" >&2; exit 1; }
ok()  { echo "[smoke] OK: $*" >&2; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

need bash
need mktemp
need python3

# Ensure scripts exist
[[ -x "$ROOT/scripts/gyte-lint" ]] || die "missing or not executable: scripts/gyte-lint"
[[ -x "$ROOT/scripts/gyte-explain" ]] || die "missing or not executable: scripts/gyte-explain"

ok "repo root: $ROOT"

# 1) Shell lint (shellcheck)
"$ROOT/scripts/gyte-lint" >/dev/null
ok "gyte-lint (shellcheck) passes"

# 2) Prepare a deterministic fake TSV (invalid URL -> no network)
TMPDIR="$(mktemp -d -t gyte-smoke.XXXXXX)"
cleanup() { rm -rf "$TMPDIR" 2>/dev/null || true; }
trap cleanup EXIT

OUT_BASE="$TMPDIR/out"
mkdir -p "$OUT_BASE"

TSV="$TMPDIR/in.tsv"
cat >"$TSV" <<'TSVEOF'
#id	title	url
1	Video finto (invalid url)	https://example.com/not-youtube
TSVEOF

# 3) Run gyte-explain
# Expect:
# - exit code 2 (invalid_url)
# - stdout empty (no summary)
# - stderr non-empty (error message)
STDOUT="$TMPDIR/stdout.txt"
STDERR="$TMPDIR/stderr.txt"
set +e
"$ROOT/scripts/gyte-explain" 1 --in "$TSV" --ai off --out-base "$OUT_BASE" >"$STDOUT" 2>"$STDERR"
RC=$?
set -e

[[ "$RC" -eq 2 ]] || die "expected rc=2 for invalid_url, got rc=$RC"
[[ ! -s "$STDOUT" ]] || die "expected stdout empty for invalid_url (summary must not be emitted)"
[[ -s "$STDERR" ]] || die "expected stderr non-empty for invalid_url"

ok "gyte-explain invalid_url contract (rc/stdout/stderr) OK"

# 4) Locate last run in OUT_BASE
RUN="$(ls -1dt "$OUT_BASE"/gyte-explain-* 2>/dev/null | head -n 1 || true)"
[[ -n "$RUN" ]] || die "cannot find run dir in $OUT_BASE"
[[ -d "$RUN" ]] || die "run is not a directory: $RUN"

ITEM="$RUN/items/001"
[[ -d "$ITEM" ]] || die "missing item dir: $ITEM"

# 5) Manifests must always exist
[[ -f "$RUN/manifest.json" ]] || die "missing run manifest: $RUN/manifest.json"
[[ -f "$ITEM/manifest.json" ]] || die "missing item manifest: $ITEM/manifest.json"
ok "manifest files exist (run + item)"

# 6) Validate essential fields + status
python3 - "$ITEM/manifest.json" <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p, "r", encoding="utf-8"))
# Minimal required keys
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
# For invalid_url we expect a message (string or null); prefer string, but don't hard-fail if null.
# We'll just print it for visibility.
print("status:", m["status"])
print("error_message:", m["error_message"])
PY

ok "item manifest fields + invalid_url status OK"

# 7) Manifest lint must pass on that run
"$ROOT/scripts/gyte-lint" --manifest "$RUN" >/dev/null
ok "gyte-lint --manifest passes on generated run"

ok "SMOKE TEST PASSED"
