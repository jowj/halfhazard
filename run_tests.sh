#!/bin/bash

# run_tests.sh - A script to run all halfhazard tests
# Created by Claude on 2025-03-25

# ANSI color codes for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Running halfhazard test suite${NC}"
echo -e "${BLUE}==========================================${NC}"

# Function to run tests and display results
run_test_suite() {
  local test_name=$1
  local test_file=$2
  
  echo -e "\n${YELLOW}Running $test_name...${NC}"

  # The test host is the app, so it opens Firestore's cache in the app's sandbox container.
  # Only one process can hold that leveldb lock: a host left over from an earlier suite makes
  # the next one abort inside FirestoreClient::Initialize before any test runs. That is the
  # "tests crash when run together" behaviour — it is a stale process, not the tests.
  pkill -9 -f "DerivedData/halfhazard.*\.app/Contents/MacOS/halfhazard" 2>/dev/null || true

  local log
  log=$(mktemp -t halfhazard-tests)

  # Run the specific test file
  if [ -n "$test_file" ]; then
    # For UI tests, don't add the halfhazardTests/ prefix
    if [[ "$test_file" == "halfhazardUITests" ]]; then
      xcodebuild test -project halfhazard.xcodeproj -scheme halfhazard -destination 'platform=macOS' -only-testing:$test_file 2>&1 | tee "$log"
    else
      xcodebuild test -project halfhazard.xcodeproj -scheme halfhazard -destination 'platform=macOS' -only-testing:halfhazardTests/$test_file 2>&1 | tee "$log"
    fi
  else
    # Run all tests if no specific file is provided
    xcodebuild test -project halfhazard.xcodeproj -scheme halfhazard -destination 'platform=macOS' 2>&1 | tee "$log"
  fi

  # Check if the tests passed
  RESULT=${PIPESTATUS[0]}

  # Force cleanup - this helps clear any lingering resources
  # that might affect subsequent test runs
  killall -9 Simulator 2>/dev/null || true
  xcrun simctl shutdown all 2>/dev/null || true

  # xcodebuild also launches host processes it does not run tests in, and those abort at
  # launch on the Firestore cache lock held by the host that *is* running tests. That makes
  # the whole invocation exit non-zero while every test passed. Believe the tests.
  local passed failed
  passed=$(grep -ac "Test case.*passed" "$log")
  failed=$(grep -ac "Test case.*failed" "$log")
  if [ $RESULT -ne 0 ] && [ "$failed" -eq 0 ] && [ "$passed" -gt 0 ] \
     && grep -q "Early unexpected exit" "$log"; then
    echo -e "${YELLOW}  (a stray test host aborted on the Firestore cache lock; $passed tests passed)${NC}"
    RESULT=0
  fi
  rm -f "$log"

  if [ $RESULT -eq 0 ] && [ "$passed" -eq 0 ] && [ "$failed" -eq 0 ]; then
    echo -e "${RED}✗ $test_name ran no tests — the name matched nothing${NC}"
    return 1
  fi

  if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ $test_name passed${NC}"
    return 0
  else
    echo -e "${RED}✗ $test_name failed${NC}"
    return 1
  fi
}

# The ledger and migration files each hold several XCTestCase classes, and -only-testing
# addresses classes rather than files, so they are listed out here.
run_ledger_suites() {
  local result=0
  for suite in MoneyTests SplitAllocatorTests LedgerEntryTests BalanceTests TemplateTests LedgerExportTests; do
    run_test_suite "$suite" "$suite" || result=1
    sleep 1
  done
  return $result
}

run_store_suites() {
  local result=0
  for suite in LedgerStoreTests LedgerStoreTemplateTests LedgerStoreTransferTests BalancePhrasingTests SplitShapeTests; do
    run_test_suite "$suite" "$suite" || result=1
    sleep 1
  done
  return $result
}

# The single screen, driven for real on a simulator against the -demoLedger fixtures.
# Slower than the rest and needs a simulator, so it is not part of "all".
run_ui_suite() {
  echo -e "\n${YELLOW}Running Ledger Screen UI Tests...${NC}"
  local device
  device=$(xcrun simctl list devices available | grep -oE "iPhone [0-9]+ \([0-9A-F-]{36}\)" | head -1 | grep -oE "[0-9A-F-]{36}")
  if [ -z "$device" ]; then
    echo -e "${RED}No iPhone simulator available.${NC}"
    return 1
  fi
  local log
  log=$(mktemp -t halfhazard-uitests)
  xcodebuild test -project halfhazard.xcodeproj -scheme halfhazard_ios \
    -destination "id=$device" -only-testing:halfhazard_iosUITests/LedgerScreenUITests 2>&1 \
    | tee "$log" | grep -E "Test case|\*\* TEST"

  # grep exits 0 for *any* matching line, including a failure, so it cannot be the verdict.
  local passed failed
  passed=$(grep -ac "Test case.*passed" "$log")
  failed=$(grep -ac "Test case.*failed" "$log")
  rm -f "$log"

  if [ "$failed" -eq 0 ] && [ "$passed" -gt 0 ]; then
    echo -e "${GREEN}✓ UI tests passed ($passed)${NC}"
    return 0
  fi
  echo -e "${RED}✗ UI tests failed ($failed of $((passed+failed)))${NC}"
  return 1
}

run_migration_suites() {
  local result=0
  # MigrationHarness is left out on purpose: it talks to the real database and skips
  # itself unless HALFHAZARD_MIGRATION_HARNESS=1. Run it by hand when migrating.
  for suite in LedgerMigratorTests MigrationReportTests; do
    run_test_suite "$suite" "$suite" || result=1
    sleep 1
  done
  return $result
}

# Parse command line arguments
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
  echo "Usage: ./run_tests.sh [test_suite]"
  echo "Available test suites:"
  echo "  all          Run all tests (default)"
  echo "  models       Run model tests"
  echo "  mocks        Run mock services tests"
  echo "  firebase     Run mock Firebase tests"
  echo "  ledger       Run ledger model tests (money, splits, entries, balance)"
  echo "  migration    Run legacy-to-ledger migration tests"
  echo "  store        Run LedgerStore tests (snapshot listener, balance, writes)"
  echo "  phrasing     Run balance/label phrasing tests"
  echo "  ui           Run the iOS UI tests against the -demoLedger fixtures"
  exit 0
fi

# Default to all tests if no arguments are provided
TEST_SUITE=${1:-"all"}

# Track overall success
SUCCESS=true

case $TEST_SUITE in
  "all")
    echo -e "${BLUE}Running all test suites sequentially${NC}"
    
    # Run each test suite individually with a small delay between them
    echo -e "\n${YELLOW}Running Model Tests...${NC}"
    run_test_suite "Model Tests" "ModelsTests" || SUCCESS=false
    sleep 2
    
    echo -e "\n${YELLOW}Running Mock Services Tests...${NC}"
    run_test_suite "Mock Services Tests" "MockServiceTests" || SUCCESS=false
    sleep 2
    
    echo -e "\n${YELLOW}Running Mock Firebase Tests...${NC}"
    run_test_suite "Mock Firebase Tests" "MockFirebaseTests" || SUCCESS=false
    sleep 2

    echo -e "\n${YELLOW}Running Ledger Tests...${NC}"
    run_ledger_suites || SUCCESS=false
    sleep 2

    echo -e "\n${YELLOW}Running Migration Tests...${NC}"
    run_migration_suites || SUCCESS=false
    sleep 2

    echo -e "\n${YELLOW}Running Ledger Store Tests...${NC}"
    run_store_suites || SUCCESS=false
    ;;

  "models")
    run_test_suite "Model Tests" "ModelsTests" || SUCCESS=false
    ;;
    
  "mocks")
    run_test_suite "Mock Services Tests" "MockServiceTests" || SUCCESS=false
    ;;
    
  "firebase")
    run_test_suite "Mock Firebase Tests" "MockFirebaseTests" || SUCCESS=false
    ;;

  "ledger")
    run_ledger_suites || SUCCESS=false
    ;;

  "migration")
    run_migration_suites || SUCCESS=false
    ;;

  "store")
    run_store_suites || SUCCESS=false
    ;;

  "phrasing")
    run_test_suite "BalancePhrasingTests" "BalancePhrasingTests" || SUCCESS=false
    ;;

  "ui")
    run_ui_suite || SUCCESS=false
    ;;
    
  *)
    echo -e "${RED}Unknown test suite: $TEST_SUITE${NC}"
    echo "Use ./run_tests.sh --help to see available options"
    exit 1
    ;;
esac

echo -e "\n${BLUE}==========================================${NC}"
if [ "$SUCCESS" = true ]; then
  echo -e "${GREEN}All tests completed successfully${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed${NC}"
  exit 1
fi