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

# 8.1) --help contract (robust: stdout OR stderr; no anchors)
set +e
"$ROOT/scripts/gyte-transcript" --help >"$TMPDIR_SMOKE/transcript_help.stdout" 2>"$TMPDIR_SMOKE/transcript_help.stderr"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || die "expected rc=0 for gyte-transcript --help, got rc=$RC"

cat "$TMPDIR_SMOKE/transcript_help.stdout" "$TMPDIR_SMOKE/transcript_help.stderr" >"$TMPDIR_SMOKE/transcript_help.all" || true

grep -q "Uso:" "$TMPDIR_SMOKE/transcript_help.all" || {
  echo "[smoke] DEBUG: gyte-transcript --help stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_help.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-transcript --help stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_help.stderr" >&2 || true
  die "expected 'Uso:' in gyte-transcript --help output"
}

grep -q "YT_TRANSCRIPT_LANGS" "$TMPDIR_SMOKE/transcript_help.all" || {
  echo "[smoke] DEBUG: gyte-transcript --help stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_help.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-transcript --help stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_help.stderr" >&2 || true
  die "expected 'YT_TRANSCRIPT_LANGS' in gyte-transcript --help output"
}

ok "gyte-transcript: --help contract (rc=0, output ok) OK"

# 8.2) deterministic error: URL cannot start with '-' (flags in URL position)
set +e
"$ROOT/scripts/gyte-transcript" --nope >"$TMPDIR_SMOKE/transcript_flag_as_url.stdout" 2>"$TMPDIR_SMOKE/transcript_flag_as_url.stderr"
RC=$?
set -e
[[ "$RC" -eq 1 ]] || {
  echo "[smoke] DEBUG: gyte-transcript --nope stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_flag_as_url.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-transcript --nope stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_flag_as_url.stderr" >&2 || true
  die "expected rc=1 for gyte-transcript flag-as-url error, got rc=$RC"
}
[[ ! -s "$TMPDIR_SMOKE/transcript_flag_as_url.stdout" ]] || die "expected empty stdout for gyte-transcript flag-as-url error"
grep -q "Errore: l'URL non può iniziare con '-'" "$TMPDIR_SMOKE/transcript_flag_as_url.stderr" || {
  echo "[smoke] DEBUG: gyte-transcript --nope stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_flag_as_url.stderr" >&2 || true
  die "expected URL-leading-dash error message in stderr"
}
ok "gyte-transcript: deterministic flag-as-url error (rc=1, stderr message) OK"

# 9) gyte-transcript-pl deterministic contracts (OFFLINE)

# 9.1) --help contract
set +e
"$ROOT/scripts/gyte-transcript-pl" --help >"$TMPDIR_SMOKE/transcript_pl_help.stdout" 2>"$TMPDIR_SMOKE/transcript_pl_help.stderr"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || die "expected rc=0 for gyte-transcript-pl --help, got rc=$RC"

cat "$TMPDIR_SMOKE/transcript_pl_help.stdout" "$TMPDIR_SMOKE/transcript_pl_help.stderr" >"$TMPDIR_SMOKE/transcript_pl_help.all" || true
grep -q "Uso:" "$TMPDIR_SMOKE/transcript_pl_help.all" || {
  echo "[smoke] DEBUG: gyte-transcript-pl --help output:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_pl_help.all" >&2 || true
  die "expected 'Uso:' in gyte-transcript-pl --help output"
}
ok "gyte-transcript-pl: --help contract (rc=0, output ok) OK"

# 9.2) missing URL -> usage, rc=1
set +e
"$ROOT/scripts/gyte-transcript-pl" >"$TMPDIR_SMOKE/transcript_pl_noargs.stdout" 2>"$TMPDIR_SMOKE/transcript_pl_noargs.stderr"
RC=$?
set -e
[[ "$RC" -eq 1 ]] || {
  echo "[smoke] DEBUG: gyte-transcript-pl (no args) output:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_pl_noargs.stdout" >&2 || true
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_pl_noargs.stderr" >&2 || true
  die "expected rc=1 for gyte-transcript-pl with no args, got rc=$RC"
}

cat "$TMPDIR_SMOKE/transcript_pl_noargs.stdout" "$TMPDIR_SMOKE/transcript_pl_noargs.stderr" >"$TMPDIR_SMOKE/transcript_pl_noargs.all" || true
grep -q "Uso:" "$TMPDIR_SMOKE/transcript_pl_noargs.all" || {
  echo "[smoke] DEBUG: gyte-transcript-pl (no args) combined output:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_pl_noargs.all" >&2 || true
  die "expected 'Uso:' in gyte-transcript-pl no-args output"
}
ok "gyte-transcript-pl: no-args usage contract (rc=1, output has Uso:) OK"

# 9.3) flag as URL -> rc=1 + specific error
set +e
"$ROOT/scripts/gyte-transcript-pl" --nope >"$TMPDIR_SMOKE/transcript_pl_flag.stdout" 2>"$TMPDIR_SMOKE/transcript_pl_flag.stderr"
RC=$?
set -e
[[ "$RC" -eq 1 ]] || {
  echo "[smoke] DEBUG: gyte-transcript-pl --nope output:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_pl_flag.stdout" >&2 || true
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_pl_flag.stderr" >&2 || true
  die "expected rc=1 for gyte-transcript-pl flag-as-url error, got rc=$RC"
}

grep -q "l'URL non può iniziare con '-'" "$TMPDIR_SMOKE/transcript_pl_flag.stderr" || {
  echo "[smoke] DEBUG: gyte-transcript-pl --nope stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/transcript_pl_flag.stderr" >&2 || true
  die "expected URL-leading-dash error message in gyte-transcript-pl stderr"
}
ok "gyte-transcript-pl: flag-as-url error contract (rc=1, stderr message) OK"

# 10) gyte-translate deterministic contracts (OFFLINE)

[[ -x "$ROOT/scripts/gyte-translate" ]] || die "missing or not executable: scripts/gyte-translate"

# 10.1) --help contract (rc=0, output contains stable tokens)
set +e
"$ROOT/scripts/gyte-translate" --help >"$TMPDIR_SMOKE/translate_help.stdout" 2>"$TMPDIR_SMOKE/translate_help.stderr"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || die "expected rc=0 for gyte-translate --help, got rc=$RC"

cat "$TMPDIR_SMOKE/translate_help.stdout" "$TMPDIR_SMOKE/translate_help.stderr" >"$TMPDIR_SMOKE/translate_help.all" || true

grep -q "Uso:" "$TMPDIR_SMOKE/translate_help.all" || {
  echo "[smoke] DEBUG: gyte-translate --help output:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/translate_help.all" >&2 || true
  die "expected 'Uso:' in gyte-translate --help output"
}

grep -q -- "--dry-run" "$TMPDIR_SMOKE/translate_help.all" || {
  echo "[smoke] DEBUG: gyte-translate --help output:" >&2
  sed -n '1,220p' "$TMPDIR_SMOKE/translate_help.all" >&2 || true
  die "expected '--dry-run' in gyte-translate --help output"
}

grep -q "GYTE_AI_CMD" "$TMPDIR_SMOKE/translate_help.all" || {
  echo "[smoke] DEBUG: gyte-translate --help output:" >&2
  sed -n '1,240p' "$TMPDIR_SMOKE/translate_help.all" >&2 || true
  die "expected 'GYTE_AI_CMD' in gyte-translate --help output"
}
ok "gyte-translate: --help contract (rc=0, output ok) OK"

# 10.2) missing input file -> rc=1, stderr mentions not found
set +e
"$ROOT/scripts/gyte-translate" "$TMPDIR_SMOKE/does-not-exist.txt" --to en >"$TMPDIR_SMOKE/translate_missing.stdout" 2>"$TMPDIR_SMOKE/translate_missing.stderr"
RC=$?
set -e
[[ "$RC" -eq 1 ]] || {
  echo "[smoke] DEBUG: gyte-translate missing-file stdout:" >&2
  sed -n '1,120p' "$TMPDIR_SMOKE/translate_missing.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-translate missing-file stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/translate_missing.stderr" >&2 || true
  die "expected rc=1 for gyte-translate missing input, got rc=$RC"
}
[[ ! -s "$TMPDIR_SMOKE/translate_missing.stdout" ]] || die "expected empty stdout for missing input file"
grep -Eqi "non trovato|not found|missing file" "$TMPDIR_SMOKE/translate_missing.stderr" || {
  echo "[smoke] DEBUG: gyte-translate missing-file stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/translate_missing.stderr" >&2 || true
  die "expected 'not found' message in stderr for missing input file"
}
ok "gyte-translate: missing-input contract (rc=1, stderr message) OK"

# 10.3) --dry-run requires GYTE_AI_CMD; set it to a deterministic no-op pipeline and expect rc=0
IN_TXT="$TMPDIR_SMOKE/translate_in.txt"
printf "ciao mondo\n" >"$IN_TXT"

set +e
GYTE_AI_CMD="cat" "$ROOT/scripts/gyte-translate" "$IN_TXT" --from it --to en --dry-run >"$TMPDIR_SMOKE/translate_dry.stdout" 2>"$TMPDIR_SMOKE/translate_dry.stderr"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || {
  echo "[smoke] DEBUG: gyte-translate --dry-run stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/translate_dry.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-translate --dry-run stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/translate_dry.stderr" >&2 || true
  die "expected rc=0 for gyte-translate --dry-run with GYTE_AI_CMD set, got rc=$RC"
}

grep -q "Modalità dry-run" "$TMPDIR_SMOKE/translate_dry.stdout" || {
  echo "[smoke] DEBUG: gyte-translate --dry-run stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/translate_dry.stdout" >&2 || true
  die "expected 'Modalità dry-run' marker in gyte-translate --dry-run stdout"
}

grep -q "GYTE_AI_CMD" "$TMPDIR_SMOKE/translate_dry.stdout" || {
  echo "[smoke] DEBUG: gyte-translate --dry-run stdout:" >&2
  sed -n '1,220p' "$TMPDIR_SMOKE/translate_dry.stdout" >&2 || true
  die "expected 'GYTE_AI_CMD' mention in gyte-translate --dry-run stdout"
}

[[ ! -s "$TMPDIR_SMOKE/translate_dry.stderr" ]] || {
  echo "[smoke] DEBUG: gyte-translate --dry-run stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/translate_dry.stderr" >&2 || true
  die "expected empty stderr for gyte-translate --dry-run"
}
ok "gyte-translate: --dry-run contract (rc=0 with GYTE_AI_CMD set, stdout ok, stderr empty) OK"

# 10.4) unknown arg -> rc=2 + Unknown argument on stderr
set +e
"$ROOT/scripts/gyte-translate" --nope >"$TMPDIR_SMOKE/translate_bad.stdout" 2>"$TMPDIR_SMOKE/translate_bad.stderr"
RC=$?
set -e
[[ "$RC" -eq 2 ]] || {
  echo "[smoke] DEBUG: gyte-translate --nope stdout:" >&2
  sed -n '1,120p' "$TMPDIR_SMOKE/translate_bad.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-translate --nope stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/translate_bad.stderr" >&2 || true
  die "expected rc=2 for gyte-translate unknown arg, got rc=$RC"
}
grep -q "Opzione non riconosciuta:" "$TMPDIR_SMOKE/translate_bad.stderr" || {
  echo "[smoke] DEBUG: gyte-translate --nope stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/translate_bad.stderr" >&2 || true
  die "expected 'Opzione non riconosciuta:' in stderr for gyte-translate unknown option"
}
ok "gyte-translate: unknown-arg contract (rc=2, stderr message) OK"

# 11) gyte-reflow-text deterministic contracts (OFFLINE)

[[ -x "$ROOT/scripts/gyte-reflow-text" ]] || die "missing or not executable: scripts/gyte-reflow-text"

# 11.1) --help contract (rc=0, output contains stable tokens)
set +e
"$ROOT/scripts/gyte-reflow-text" --help >"$TMPDIR_SMOKE/reflow_help.stdout" 2>"$TMPDIR_SMOKE/reflow_help.stderr"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || die "expected rc=0 for gyte-reflow-text --help, got rc=$RC"

cat "$TMPDIR_SMOKE/reflow_help.stdout" "$TMPDIR_SMOKE/reflow_help.stderr" >"$TMPDIR_SMOKE/reflow_help.all" || true

grep -q "Uso:" "$TMPDIR_SMOKE/reflow_help.all" || {
  echo "[smoke] DEBUG: gyte-reflow-text --help stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/reflow_help.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-reflow-text --help stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/reflow_help.stderr" >&2 || true
  die "expected 'Uso:' in gyte-reflow-text --help output"
}

grep -q -- "--ai-friendly" "$TMPDIR_SMOKE/reflow_help.all" || {
  echo "[smoke] DEBUG: gyte-reflow-text --help output:" >&2
  sed -n '1,240p' "$TMPDIR_SMOKE/reflow_help.all" >&2 || true
  die "expected '--ai-friendly' in gyte-reflow-text --help output"
}
ok "gyte-reflow-text: --help contract (rc=0, output ok) OK"

# 11.2) stdin happy-path: --ai-friendly normalizes spaces (no double spaces)
IN1="$TMPDIR_SMOKE/reflow_in1.txt"
printf "Ciao   mondo!  \n\nRiga   con   spazi.\n" >"$IN1"

set +e
"$ROOT/scripts/gyte-reflow-text" --ai-friendly <"$IN1" >"$TMPDIR_SMOKE/reflow_ai.stdout" 2>"$TMPDIR_SMOKE/reflow_ai.stderr"

RC=$?
set -e
[[ "$RC" -eq 0 ]] || {
  echo "[smoke] DEBUG: gyte-reflow-text --ai-friendly stdout:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/reflow_ai.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-reflow-text --ai-friendly stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/reflow_ai.stderr" >&2 || true
  die "expected rc=0 for gyte-reflow-text --ai-friendly (stdin), got rc=$RC"
}

# invariant: stdout should not contain double spaces
if grep -q "  " "$TMPDIR_SMOKE/reflow_ai.stdout"; then
  echo "[smoke] DEBUG: gyte-reflow-text --ai-friendly stdout (found double spaces):" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/reflow_ai.stdout" >&2 || true
  die "expected no double spaces in gyte-reflow-text --ai-friendly output"
fi
ok "gyte-reflow-text: --ai-friendly stdin contract (rc=0, no double spaces) OK"

# 11.3) --strict-utf8: must not crash on invalid bytes; may emit warning to stderr; stdout must be produced
# create invalid UTF-8 byte sequence (0xFF is invalid in UTF-8)
IN2="$TMPDIR_SMOKE/reflow_in2.bin"
python3 - "$IN2" <<'PY'
import sys
p = sys.argv[1]
open(p, "wb").write(b"hello\xffworld\n")
PY

set +e
"$ROOT/scripts/gyte-reflow-text" --strict-utf8 <"$IN2" >"$TMPDIR_SMOKE/reflow_utf8.stdout" 2>"$TMPDIR_SMOKE/reflow_utf8.stderr"
RC=$?
set -e
[[ "$RC" -eq 0 ]] || {
  echo "[smoke] DEBUG: gyte-reflow-text --strict-utf8 stdout:" >&2
  sed -n '1,120p' "$TMPDIR_SMOKE/reflow_utf8.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-reflow-text --strict-utf8 stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/reflow_utf8.stderr" >&2 || true
  die "expected rc=0 for gyte-reflow-text --strict-utf8, got rc=$RC"
}
[[ -s "$TMPDIR_SMOKE/reflow_utf8.stdout" ]] || die "expected non-empty stdout for gyte-reflow-text --strict-utf8"
# stderr may be empty if no warning path triggers; accept either, but it must not contain fatal error patterns.
if grep -Eqi "traceback|fatal|segfault" "$TMPDIR_SMOKE/reflow_utf8.stderr"; then
  echo "[smoke] DEBUG: gyte-reflow-text --strict-utf8 stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/reflow_utf8.stderr" >&2 || true
  die "unexpected fatal-looking stderr for gyte-reflow-text --strict-utf8"
fi
ok "gyte-reflow-text: --strict-utf8 contract (rc=0, stdout produced) OK"

# 11.4) unknown option -> rc=1, stderr mentions unrecognized option
set +e
"$ROOT/scripts/gyte-reflow-text" --nope >"$TMPDIR_SMOKE/reflow_bad.stdout" 2>"$TMPDIR_SMOKE/reflow_bad.stderr"
RC=$?
set -e
[[ "$RC" -eq 1 ]] || {
  echo "[smoke] DEBUG: gyte-reflow-text --nope stdout:" >&2
  sed -n '1,120p' "$TMPDIR_SMOKE/reflow_bad.stdout" >&2 || true
  echo "[smoke] DEBUG: gyte-reflow-text --nope stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/reflow_bad.stderr" >&2 || true
  die "expected rc=1 for gyte-reflow-text unknown option, got rc=$RC"
}

grep -Eqi "opzione sconosciuta|opzione non riconosciuta|unknown option" "$TMPDIR_SMOKE/reflow_bad.stderr" || {
  echo "[smoke] DEBUG: gyte-reflow-text --nope stderr:" >&2
  sed -n '1,200p' "$TMPDIR_SMOKE/reflow_bad.stderr" >&2 || true
  die "expected unrecognized-option message in gyte-reflow-text stderr"
}
ok "gyte-reflow-text: unknown-option contract (rc=1, stderr message) OK"

ok "SMOKE TEST PASSED"
