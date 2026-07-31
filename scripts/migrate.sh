#!/bin/bash

# migrate.sh - Run the legacy-to-ledger migration against the real database.
#
# The migration lives in a test (halfhazardTests/MigrationHarness) so it can be run on
# demand without a screen to hang it off. This wrapper exists because `xcodebuild test`
# buries anything the test prints under thousands of lines of build log, and because a
# harness that skips itself still reports "TEST SUCCEEDED" — which looks exactly like a
# migration that worked.
#
# Usage:
#   ./scripts/migrate.sh dry-run              # read and report. Writes nothing.
#   ./scripts/migrate.sh commit               # write entries and ledgers, then read back.
#   ./scripts/migrate.sh commit --force       # commit despite blocking issues.
#   ./scripts/migrate.sh audit                # check what is in the database. Writes nothing.
#   ./scripts/migrate.sh store                # what the app screen would show. Writes nothing.
#   ./scripts/migrate.sh inspect <id> [<id>…] # dump a legacy expense, stored and migrated.
#
# Configuration lives in .migration-env in the repo root (gitignored):
#   HALFHAZARD_MIGRATION_HARNESS=1
#   HALFHAZARD_EMAIL=you@example.com
#   HALFHAZARD_PASSWORD=…
#
# It is a file rather than exported variables because xcodebuild does not pass its
# environment through to the test process.

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd "$(dirname "$0")/.." || exit 1

MODE=${1:-dry-run}
shift 2>/dev/null
case "$MODE" in
  dry-run) TEST=testDryRun ;;
  commit)  TEST=testCommit ;;
  audit)   TEST=testAudit ;;
  store)   TEST=testLiveStore ;;
  inspect)
    TEST=testInspect
    if [ $# -eq 0 ]; then
      echo -e "${RED}inspect needs at least one expense id.${NC}"
      exit 1
    fi
    ;;
  --help|-h)
    sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo -e "${RED}Unknown mode: $MODE${NC}  (expected dry-run, commit, or audit)"
    exit 1
    ;;
esac

if [ ! -f .migration-env ]; then
  echo -e "${RED}No .migration-env in $(pwd).${NC}"
  echo "Create it with:"
  echo
  echo "  HALFHAZARD_MIGRATION_HARNESS=1"
  echo "  HALFHAZARD_EMAIL=you@example.com"
  echo "  HALFHAZARD_PASSWORD=your-password"
  echo
  echo "It is gitignored. The harness reads it directly; exported variables do not"
  echo "reach the test process."
  exit 1
fi

for key in HALFHAZARD_MIGRATION_HARNESS HALFHAZARD_EMAIL HALFHAZARD_PASSWORD; do
  if ! grep -q "^${key}=" .migration-env; then
    echo -e "${RED}.migration-env is missing ${key}.${NC}"
    exit 1
  fi
done

LOG=$(mktemp -t halfhazard-migration)

# The test host is the app itself, so it opens Firestore's on-disk cache in the app's
# sandbox container. Only one process can hold that leveldb lock: if a previous run left a
# host behind — a crashed run always does — the next one aborts inside
# FirestoreClient::Initialize before any test runs, which surfaces as an unexplained
# "crashed while preparing to run tests". Clear the strays first.
STALE=$(pgrep -f "DerivedData/halfhazard.*\.app/Contents/MacOS/halfhazard" 2>/dev/null)
if [ -n "$STALE" ]; then
  echo -e "${YELLOW}Clearing $(echo "$STALE" | wc -l | tr -d ' ') stale test host(s) holding the Firestore cache lock.${NC}"
  # shellcheck disable=SC2086
  kill -9 $STALE 2>/dev/null
  sleep 1
fi

# A copy launched from /Applications holds the same lock and is not ours to kill.
if pgrep -f "/Applications/halfhazard.app" > /dev/null 2>&1; then
  echo -e "${RED}halfhazard is running. Quit it first — it holds the Firestore cache lock${NC}"
  echo -e "${RED}and the test host will abort at launch.${NC}"
  exit 1
fi

# The harness refuses to write unless a marker is present, so running the test class by
# hand cannot commit by accident. Removed however this script exits — along with any host
# process left behind, which would otherwise hold the cache lock and break the next run.
cleanup() {
  rm -f .migration-commit .migration-force .migration-inspect
  pkill -9 -f "DerivedData/halfhazard.*\.app/Contents/MacOS/halfhazard" 2>/dev/null || true
}
trap cleanup EXIT

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Migration: $MODE${NC}"
echo -e "${BLUE}==========================================${NC}"
case "$MODE" in
  commit)
    echo -e "${YELLOW}This writes to the database. It only touches the entries and ledgers${NC}"
    echo -e "${YELLOW}collections; the old expenses collection is never modified.${NC}"
    touch .migration-commit
    if [ "${1:-}" == "--force" ]; then
      echo -e "${RED}--force: committing even where the dry run reported blocking issues.${NC}"
      touch .migration-force
    fi
    ;;
  inspect)
    printf '%s\n' "$@" > .migration-inspect
    ;;
esac
echo

WORK=$(mktemp -d)
BUNDLE="$WORK/result.xcresult"
ATTACHMENTS="$WORK/attachments"

xcodebuild test \
  -project halfhazard.xcodeproj \
  -scheme halfhazard \
  -destination 'platform=macOS' \
  -resultBundlePath "$BUNDLE" \
  -only-testing:"halfhazardTests/MigrationHarness/$TEST" > "$LOG" 2>&1
RESULT=$?

# The report comes back as a test attachment: a sandboxed, app-hosted test can neither
# print to xcodebuild's output nor write a file into the repo.
mkdir -p "$ATTACHMENTS"
xcrun xcresulttool export attachments --path "$BUNDLE" --output-path "$ATTACHMENTS" > /dev/null 2>&1
REPORT=$(find "$ATTACHMENTS" -type f ! -name 'manifest.json' 2>/dev/null | head -1)

if [ -n "$REPORT" ] && [ -s "$REPORT" ]; then
  cat "$REPORT"
  echo
elif grep -q "Test case.*skipped" "$LOG"; then
  echo -e "${RED}The harness skipped itself and did nothing.${NC}"
  echo "Check that .migration-env has HALFHAZARD_MIGRATION_HARNESS=1."
  echo "  full log: $LOG"
  exit 1
else
  echo -e "${RED}The harness produced no report.${NC}"
  grep -E "error:|Testing failed|\*\* .* \*\*" "$LOG" | head -10 | sed 's/^/  /'
  echo "  full log: $LOG"
  exit 1
fi

if grep -q "^FAILURE:" "$REPORT"; then
  echo -e "${RED}The run reported failures — see the lines above.${NC}"
fi

# xcodebuild's exit code is not a reliable verdict here. A leftover host process holding
# Firestore's cache lock makes a *second* host abort at launch, and xcodebuild reports the
# whole run as failed even though the test itself ran and passed. Judge by the tests.
PASSED=$(grep -ac "Test case.*passed" "$LOG")
FAILED=$(grep -ac "Test case.*failed" "$LOG")
if [ $RESULT -ne 0 ] && [ "$FAILED" -eq 0 ] && [ "$PASSED" -gt 0 ] && ! grep -q "^FAILURE:" "$REPORT"; then
  if grep -q "Early unexpected exit" "$LOG"; then
    echo -e "${YELLOW}Note: a stray test host crashed at launch on the Firestore cache lock.${NC}"
    echo -e "${YELLOW}The run above is unaffected — it is reported by the tests, not the exit code.${NC}"
  fi
  RESULT=0
fi

if [ $RESULT -eq 0 ]; then
  case "$MODE" in
    dry-run) echo -e "${GREEN}✓ Clean. Run './scripts/migrate.sh commit' to write it.${NC}" ;;
    commit)  echo -e "${GREEN}✓ Migrated, and the entries read back correctly.${NC}" ;;
    audit)   echo -e "${GREEN}✓ The ledger matches the old data.${NC}" ;;
  esac
  rm -rf "$LOG" "$WORK"
  exit 0
else
  echo -e "${RED}✗ $MODE did not pass. Full log: $LOG${NC}"
  exit 1
fi
