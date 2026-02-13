#!/usr/bin/env bash
set -euo pipefail

# GYTE smoke test (offline / deterministic)
# Goals:
# - No network / no auth required
# - Validate deterministic contracts for:
#   - gyte-explain invalid_url behavior
#   - gyte-digest validation (browser whitelist, cookies fail-fast) via dry-run
#   - gyte-lint --manifest contracts (stdlib only)
#   - gyte-install (non-destructive, --dry-run only; CI-safe even if bin/ is generated)
#   - gyte-transcript (offline: --help + --dry-run only)
#
# NOTE:
# - Shellcheck gate is already enforced by the CI workflow step "Shellcheck scripts".
# - This smoke must NOT depend on user-local installs or live YouTube sessions.
# - Wrappers under ./bin may be generated; smoke calls ./scripts directly and bootstraps bin/ only if needed.

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
need ls
need grep
need chmod
need mkdir
need rm

# Ensure scripts exist (smoke calls scripts directly)
[[ -x "$ROOT/scripts/gyte-explain" ]] || die "missing or not executable: scripts/gyte-explain"
[[ -x "$ROOT/scripts/gyte-lint" ]] || die "missing or not executable: scripts/gyte-lint"
[[ -x "$ROOT/scripts/gyte-digest" ]] || die "missing or not executable: scripts/gyte-digest"
[[ -x "$ROOT/scripts/gyte-install" ]] || die "missing or not executable: scripts/gyte-install"
[[ -x "$ROOT/scripts/gyte-transcript" ]] || die "missing or not executable: scripts/gyte-transcript"

# Make repo commands available (still useful if some scripts call others).
export PATH="$ROOT/bin:$ROOT/scripts:$PATH"

ok "repo root: $ROOT"

# 0) gyte-digest offline validation (dry-run only)
TMPDIR_SMOKE="$(mktemp -d -t gyte-smoke.XXXXXX)"

# Track temporary bootstrap of bin/ wrappers (CI-safe)
BOOTSTRAPPED_BIN=0
BOOTSTRAP_DUMMY=""

cleanup_smoke() {
  # Clean temporary wrapper if we created it
  if [[ "$BOOTSTRAPPED_BIN" -eq 1 ]] && [[ -n "$BOOTSTRAP_DUMMY" ]]; then
    rm -f -- "$BOOTSTRAP_DUMMY" 2>/dev/null || true
  fi
  # If we created an empty bin/ directory, leave it (non-destructive) OR remove if empty.
  # We remove only if empty to avoid touching real repo state.
  if [[ "$BOOTSTRAPPED_BIN" -eq 1 ]] && [[ -d "$ROOT/bin" ]]; then
    if ! find "$ROOT/bin" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
      rmdir -- "$ROOT/bin" 2>/dev/null || true
    fi
  fi

  rm -rf "$TMPDIR_SMOKE" 2>/dev/null || true
}
trap cleanup_smoke EXIT

ANON="$TMPDIR_SMOKE/anon.cookies"

# 0.1) plain dry-run (no cookies) -> must succeed (rc=0)
set +e
"$ROOT/scripts/gyte-digest" --dry-run >"$TMPDIR_SMOKE/plain.stdout" 2>"$TMPDIR_SMOKE/plain.stderr"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || {
  echo "[smoke] DEBUG: plain dry-run failed rc=$RC" >&2
  echo "[smoke] DEBUG: stdout (first 200 lines):" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/plain.stdout" >&2 || true
  echo "[smoke] DEBUG: stderr (first 200 lines):" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/plain.stderr" >&2 || true

  echo "[smoke] DEBUG: environment snapshot (minimal):" >&2
  echo "[smoke] DEBUG: PATH=$PATH" >&2
  echo "[smoke] DEBUG: which bash: $(command -v bash || true)" >&2
  echo "[smoke] DEBUG: which yt-dlp: $(command -v yt-dlp || true)" >&2
  echo "[smoke] DEBUG: yt-dlp --version:" >&2
  (yt-dlp --version 2>&1 | sed -n '1,5p' >&2) || true

  echo "[smoke] DEBUG: trace scripts/gyte-digest (bash -x) --dry-run:" >&2
  set +e
  bash -x "$ROOT/scripts/gyte-digest" --dry-run >&2
  TRC2=$?
  set -e
  echo "[smoke] DEBUG: scripts trace rc=$TRC2" >&2

  die "expected rc=0 for plain --dry-run, got rc=$RC"
}
ok "gyte-digest: plain --dry-run (rc=0) OK"

# 0.2) anon cookies -> must fail fast (R7), even in dry-run
printf "# Netscape HTTP Cookie File\n.youtube.com\tTRUE\t/\tFALSE\t0\tPREF\thl=en\n" >"$ANON"

set +e
"$ROOT/scripts/gyte-digest" --cookies "$ANON" --dry-run >"$TMPDIR_SMOKE/anon.stdout" 2>"$TMPDIR_SMOKE/anon.stderr"
RC=$?
set -e
[[ "$RC" -eq 1 ]] || {
  echo "[smoke] DEBUG: anon cookies stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/anon.stdout" >&2 || true
  echo "[smoke] DEBUG: anon cookies stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/anon.stderr" >&2 || true
  die "expected rc=1 for anon cookies (fail-fast), got rc=$RC"
}
ok "gyte-digest: anon cookies fail-fast (rc=1) OK"

# 0.3) invalid browser -> must fail rc=1
set +e
"$ROOT/scripts/gyte-digest" --dry-run --browser ie >"$TMPDIR_SMOKE/browser.stdout" 2>"$TMPDIR_SMOKE/browser.stderr"
RC=$?
set -e
[[ "$RC" -eq 1 ]] || {
  echo "[smoke] DEBUG: invalid browser stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/browser.stdout" >&2 || true
  echo "[smoke] DEBUG: invalid browser stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/browser.stderr" >&2 || true
  die "expected rc=1 for invalid browser, got rc=$RC"
}
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

# 6) gyte-lint --manifest deterministic contracts (stdlib only)

# 6.1) --help -> rc=0, stderr empty, stdout contains stable text
set +e
"$ROOT/scripts/gyte-lint" --help >"$TMPDIR_SMOKE/lint_help.stdout" 2>"$TMPDIR_SMOKE/lint_help.stderr"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || die "expected rc=0 for gyte-lint --help, got rc=$RC"
grep -q "Exit codes" "$TMPDIR_SMOKE/lint_help.stdout" || {
  echo "[smoke] DEBUG: gyte-lint --help stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_help.stdout" >&2 || true
  die "expected 'Exit codes' in gyte-lint --help stdout"
}
[[ ! -s "$TMPDIR_SMOKE/lint_help.stderr" ]] || {
  echo "[smoke] DEBUG: gyte-lint --help stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_help.stderr" >&2 || true
  die "expected empty stderr for gyte-lint --help"
}
ok "gyte-lint: --help contract (rc=0, stdout ok, stderr empty) OK"

# 6.2) --manifest with no PATH and no out/ -> rc=1, deterministic stderr
EMPTY="$TMPDIR_SMOKE/empty"
mkdir -p "$EMPTY"
set +e
(cd "$EMPTY" && "$ROOT/scripts/gyte-lint" --manifest >"$TMPDIR_SMOKE/lint_no_run.stdout" 2>"$TMPDIR_SMOKE/lint_no_run.stderr")
RC=$?
set -e
[[ "$RC" -eq 1 ]] || {
  echo "[smoke] DEBUG: gyte-lint --manifest (no out/) stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_no_run.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-lint --manifest (no out/) stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_no_run.stderr" >&2 || true
  die "expected rc=1 for gyte-lint --manifest with no out/, got rc=$RC"
}
grep -q "ERRORE: nessuna run trovata" "$TMPDIR_SMOKE/lint_no_run.stderr" || {
  echo "[smoke] DEBUG: gyte-lint --manifest (no out/) stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_no_run.stderr" >&2 || true
  die "expected 'nessuna run trovata' in stderr"
}
ok "gyte-lint: --manifest no-run operational error contract (rc=1) OK"

# 6.3) --manifest PATH OK/KO fixtures (generated on the fly, deterministic)
FIX_OK="$TMPDIR_SMOKE/fixture_ok"
mkdir -p "$FIX_OK/items/001"

cat >"$FIX_OK/manifest.json" <<'JSON'
{
  "schema": "gyte.manifest.run.v1",
  "gyte_version": "0.0.0-test",
  "run": {
    "id": "gyte-explain-TEST",
    "dir": "out/gyte-explain-TEST",
    "timestamp_start": "1970-01-01T00:00:00Z",
    "timestamp_end": "1970-01-01T00:00:01Z",
    "status": "ok"
  },
  "config": {
    "ai_mode": "off",
    "langs": ["en"],
    "argv": ["gyte-explain", "--in", "in.tsv", "--ai", "off"]
  },
  "counts": {
    "items_total": 1,
    "items_ok": 0,
    "items_error": 0,
    "items_no_transcript": 0,
    "items_invalid_url": 1
  },
  "items": {
    "001": { "status": "invalid_url", "path": "items/001/manifest.json" }
  },
  "paths": {},
  "notes": {}
}
JSON

cat >"$FIX_OK/items/001/manifest.json" <<'JSON'
{
  "schema": "gyte.manifest.item.v1",
  "id": "001",
  "title": "Fixture item",
  "url": "https://example.com/not-youtube",
  "langs": ["en"],
  "ai_mode": "off",
  "transcript_source": "none",
  "summary_source": "none",
  "status": "invalid_url",
  "error_message": "invalid url",
  "paths": {
    "transcript": "",
    "summary": ""
  },
  "timestamps": {
    "created": "1970-01-01T00:00:00Z",
    "updated": "1970-01-01T00:00:01Z"
  },
  "meta": {
    "exists": null,
    "reflowed_transcript": false,
    "stdout_summary_emitted": false
  }
}
JSON

set +e
"$ROOT/scripts/gyte-lint" --manifest "$FIX_OK" >"$TMPDIR_SMOKE/lint_ok.stdout" 2>"$TMPDIR_SMOKE/lint_ok.stderr"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || {
  echo "[smoke] DEBUG: gyte-lint --manifest OK stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_ok.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-lint --manifest OK stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_ok.stderr" >&2 || true
  die "expected rc=0 for manifest OK fixture, got rc=$RC"
}
grep -q "\[OK\] manifest validation passed: warnings=0" "$TMPDIR_SMOKE/lint_ok.stdout" || {
  echo "[smoke] DEBUG: gyte-lint --manifest OK stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_ok.stdout" >&2 || true
  die "expected [OK] line with warnings=0 in stdout for OK fixture"
}
[[ ! -s "$TMPDIR_SMOKE/lint_ok.stderr" ]] || {
  echo "[smoke] DEBUG: gyte-lint --manifest OK stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_ok.stderr" >&2 || true
  die "expected empty stderr for OK fixture"
}
ok "gyte-lint: --manifest PATH OK fixture (rc=0, warnings=0) OK"

# KO fixture: same structure, deterministic schema mismatch
FIX_KO="$TMPDIR_SMOKE/fixture_ko"
mkdir -p "$FIX_KO/items/001"
cp -a "$FIX_OK/manifest.json" "$FIX_KO/manifest.json"
cp -a "$FIX_OK/items/001/manifest.json" "$FIX_KO/items/001/manifest.json"

# Make it invalid deterministically: break item schema
python3 - "$FIX_KO/items/001/manifest.json" <<'PY'
import json, sys
p = sys.argv[1]
doc = json.load(open(p, 'r', encoding='utf-8'))
doc['schema'] = 'gyte.manifest.item.v0'
json.dump(doc, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
PY

set +e
"$ROOT/scripts/gyte-lint" --manifest "$FIX_KO" >"$TMPDIR_SMOKE/lint_ko.stdout" 2>"$TMPDIR_SMOKE/lint_ko.stderr"
RC=$?
set -e
[[ "$RC" -eq 2 ]] || {
  echo "[smoke] DEBUG: gyte-lint --manifest KO stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_ko.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-lint --manifest KO stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_ko.stderr" >&2 || true
  die "expected rc=2 for manifest KO fixture, got rc=$RC"
}
[[ ! -s "$TMPDIR_SMOKE/lint_ko.stdout" ]] || {
  echo "[smoke] DEBUG: gyte-lint --manifest KO stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_ko.stdout" >&2 || true
  die "expected empty stdout for KO fixture"
}
grep -q "\[FAIL\] manifest validation failed" "$TMPDIR_SMOKE/lint_ko.stderr" || {
  echo "[smoke] DEBUG: gyte-lint --manifest KO stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_ko.stderr" >&2 || true
  die "expected [FAIL] line in stderr for KO fixture"
}
grep -q "\[ERR\]" "$TMPDIR_SMOKE/lint_ko.stderr" || {
  echo "[smoke] DEBUG: gyte-lint --manifest KO stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/lint_ko.stderr" >&2 || true
  die "expected at least one [ERR] in stderr for KO fixture"
}
ok "gyte-lint: --manifest PATH KO fixture (rc=2, stderr has [ERR]/[FAIL]) OK"

# 7) gyte-install deterministic contracts (NON-DESTRUCTIVE: --dry-run only)
#
# gyte-install enumerates wrappers under $REPO_ROOT/bin/gyte-*.
# In CI, bin/ may be generated and absent. For smoke purposes, we bootstrap a minimal bin/ with a dummy wrapper
# ONLY if needed, and clean it up afterward.

if [[ ! -d "$ROOT/bin" ]] || ! find "$ROOT/bin" -maxdepth 1 -type f -name 'gyte-*' -print -quit 2>/dev/null | grep -q .; then
  BOOTSTRAPPED_BIN=1
  mkdir -p "$ROOT/bin"
  BOOTSTRAP_DUMMY="$ROOT/bin/gyte-smoke-dummy"
  cat >"$BOOTSTRAP_DUMMY" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "gyte-smoke-dummy"
EOF
  chmod +x "$BOOTSTRAP_DUMMY"
  ok "bootstrapped minimal bin/ wrapper for gyte-install smoke: $BOOTSTRAP_DUMMY"
fi

# 7.1) --help contract
set +e
"$ROOT/scripts/gyte-install" --help >"$TMPDIR_SMOKE/install_help.stdout" 2>"$TMPDIR_SMOKE/install_help.stderr"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || die "expected rc=0 for gyte-install --help, got rc=$RC"
grep -q "gyte-install - install" "$TMPDIR_SMOKE/install_help.stdout" || {
  echo "[smoke] DEBUG: gyte-install --help stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/install_help.stdout" >&2 || true
  die "expected 'gyte-install - install' in gyte-install --help stdout"
}
[[ ! -s "$TMPDIR_SMOKE/install_help.stderr" ]] || {
  echo "[smoke] DEBUG: gyte-install --help stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/install_help.stderr" >&2 || true
  die "expected empty stderr for gyte-install --help"
}
ok "gyte-install: --help contract (rc=0, stdout ok, stderr empty) OK"

# 7.2) --dry-run --prefix TMP (must not modify filesystem outside TMP; only prints)
PFX="$TMPDIR_SMOKE/prefix"
set +e
"$ROOT/scripts/gyte-install" --dry-run --prefix "$PFX" >"$TMPDIR_SMOKE/install_dry.stdout" 2>"$TMPDIR_SMOKE/install_dry.stderr"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || {
  echo "[smoke] DEBUG: gyte-install --dry-run stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/install_dry.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-install --dry-run stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/install_dry.stderr" >&2 || true
  die "expected rc=0 for gyte-install --dry-run, got rc=$RC"
}
grep -q "GYTE install" "$TMPDIR_SMOKE/install_dry.stdout" || die "expected 'GYTE install' in dry-run stdout"
grep -q "\[dry-run\] " "$TMPDIR_SMOKE/install_dry.stdout" || die "expected '[dry-run]' lines in dry-run stdout"
grep -q "Installed " "$TMPDIR_SMOKE/install_dry.stdout" || die "expected 'Installed' summary in dry-run stdout"
[[ ! -s "$TMPDIR_SMOKE/install_dry.stderr" ]] || {
  echo "[smoke] DEBUG: gyte-install --dry-run stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/install_dry.stderr" >&2 || true
  die "expected empty stderr for gyte-install --dry-run"
}
ok "gyte-install: --dry-run contract (rc=0, stdout has dry-run + Installed, stderr empty) OK"

# 7.3) unknown arg -> rc=2 + usage on stderr
set +e
"$ROOT/scripts/gyte-install" --nope >"$TMPDIR_SMOKE/install_bad.stdout" 2>"$TMPDIR_SMOKE/install_bad.stderr"
RC=$?
set -e
[[ "$RC" -eq 2 ]] || {
  echo "[smoke] DEBUG: gyte-install --nope stdout:" >&2
  sed -n '1,120p' "$TMPDIR_SMOKE/install_bad.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-install --nope stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/install_bad.stderr" >&2 || true
  die "expected rc=2 for unknown arg, got rc=$RC"
}
grep -q "Unknown argument" "$TMPDIR_SMOKE/install_bad.stderr" || {
  echo "[smoke] DEBUG: gyte-install --nope stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/install_bad.stderr" >&2 || true
  die "expected 'Unknown argument' in stderr for unknown arg"
}
ok "gyte-install: unknown-arg contract (rc=2, stderr has Unknown argument) OK"

# 8) gyte-transcript deterministic contracts (OFFLINE: --help + --dry-run only)

# 8.1) --help contract
set +e
"$ROOT/scripts/gyte-transcript" --help >"$TMPDIR_SMOKE/transcript_help.stdout" 2>"$TMPDIR_SMOKE/transcript_help.stderr"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || die "expected rc=0 for gyte-transcript --help, got rc=$RC"
grep -q "gyte-transcript" "$TMPDIR_SMOKE/transcript_help.stdout" || {
  echo "[smoke] DEBUG: gyte-transcript --help stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_help.stdout" >&2 || true
  die "expected 'gyte-transcript' in gyte-transcript --help stdout"
}
[[ ! -s "$TMPDIR_SMOKE/transcript_help.stderr" ]] || {
  echo "[smoke] DEBUG: gyte-transcript --help stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_help.stderr" >&2 || true
  die "expected empty stderr for gyte-transcript --help"
}
ok "gyte-transcript: --help contract (rc=0, stdout ok, stderr empty) OK"

# 8.2) --dry-run prints yt-dlp command and exits 0 (no network)
set +e
"$ROOT/scripts/gyte-transcript" --dry-run "https://example.com/foo" >"$TMPDIR_SMOKE/transcript_dry.stdout" 2>"$TMPDIR_SMOKE/transcript_dry.stderr"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || {
  echo "[smoke] DEBUG: gyte-transcript --dry-run stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_dry.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-transcript --dry-run stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_dry.stderr" >&2 || true
  die "expected rc=0 for gyte-transcript --dry-run, got rc=$RC"
}
grep -q "yt-dlp" "$TMPDIR_SMOKE/transcript_dry.stdout" || {
  echo "[smoke] DEBUG: gyte-transcript --dry-run stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_dry.stdout" >&2 || true
  die "expected 'yt-dlp' in gyte-transcript --dry-run stdout"
}
grep -q -- "--write-auto-subs" "$TMPDIR_SMOKE/transcript_dry.stdout" || {
  echo "[smoke] DEBUG: gyte-transcript --dry-run stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_dry.stdout" >&2 || true
  die "expected '--write-auto-subs' in gyte-transcript --dry-run stdout"
}
[[ ! -s "$TMPDIR_SMOKE/transcript_dry.stderr" ]] || {
  echo "[smoke] DEBUG: gyte-transcript --dry-run stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_dry.stderr" >&2 || true
  die "expected empty stderr for gyte-transcript --dry-run"
}
ok "gyte-transcript: --dry-run contract (rc=0, stdout has yt-dlp + --write-auto-subs, stderr empty) OK"

# 8.3) unknown arg -> rc=2 + Unknown argument on stderr
set +e
"$ROOT/scripts/gyte-transcript" --nope >"$TMPDIR_SMOKE/transcript_bad.stdout" 2>"$TMPDIR_SMOKE/transcript_bad.stderr"
RC=$?
set -e
[[ "$RC" -eq 2 ]] || {
  echo "[smoke] DEBUG: gyte-transcript --nope stdout:" >&2
  sed -n '1,120p' "$TMPDIR_SMOKE/transcript_bad.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-transcript --nope stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_bad.stderr" >&2 || true
  die "expected rc=2 for gyte-transcript unknown arg, got rc=$RC"
}
grep -q "Unknown argument" "$TMPDIR_SMOKE/transcript_bad.stderr" || {
  echo "[smoke] DEBUG: gyte-transcript --nope stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_bad.stderr" >&2 || true
  die "expected 'Unknown argument' in stderr for gyte-transcript unknown arg"
}
ok "gyte-transcript: unknown-arg contract (rc=2, stderr has Unknown argument) OK"

ok "SMOKE TEST PASSED"
