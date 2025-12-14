#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REFLOW="$REPO_ROOT/scripts/gyte-reflow-text"
SAMPLE="$SCRIPT_DIR/reflow-splitter-sample.txt"

if [ ! -x "$REFLOW" ]; then
  echo "Errore: non trovo eseguibile $REFLOW" >&2
  exit 1
fi

echo "== Input ==" >&2
cat "$SAMPLE" >&2
echo "" >&2

echo "== Output (sentences) ==" >&2
"$REFLOW" "$SAMPLE"

echo "" >&2
echo "== Idempotenza ==" >&2
tmp1="$(mktemp -t gyte-reflow-demo.XXXXXX)"
tmp2="$(mktemp -t gyte-reflow-demo.XXXXXX)"
trap 'rm -f "$tmp1" "$tmp2"' EXIT

"$REFLOW" "$SAMPLE" > "$tmp1"
"$REFLOW" "$tmp1" > "$tmp2"

if diff -u "$tmp1" "$tmp2" >/dev/null; then
  echo "OK: idempotente ✅" >&2
else
  echo "ATTENZIONE: non idempotente (diff sotto) ❌" >&2
  diff -u "$tmp1" "$tmp2" >&2 || true
  exit 1
fi
