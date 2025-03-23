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
  
  # Run the specific test file
  if [ -n "$test_file" ]; then
    # For UI tests, don't add the halfhazardTests/ prefix
    if [[ "$test_file" == "halfhazardUITests" ]]; then
      xcodebuild test -project halfhazard.xcodeproj -scheme halfhazard -destination 'platform=macOS' -only-testing:$test_file
    else
      xcodebuild test -project halfhazard.xcodeproj -scheme halfhazard -destination 'platform=macOS' -only-testing:halfhazardTests/$test_file
    fi
  else
    # Run all tests if no specific file is provided
    xcodebuild test -project halfhazard.xcodeproj -scheme halfhazard -destination 'platform=macOS'
  fi
  
  # Check if the tests passed
  RESULT=$?
  
  # Force cleanup - this helps clear any lingering resources
  # that might affect subsequent test runs
  killall -9 Simulator 2>/dev/null || true
  xcrun simctl shutdown all 2>/dev/null || true
  
  if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ $test_name passed${NC}"
    return 0
  else
    echo -e "${RED}✗ $test_name failed${NC}"
    return 1
  fi
}

# Parse command line arguments
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
  echo "Usage: ./run_tests.sh [test_suite]"
  echo "Available test suites:"
  echo "  all          Run all tests (default)"
  echo "  models       Run model tests"
  echo "  services     Run service behavior tests"
  echo "  mocks        Run mock services tests"
  echo "  firebase     Run mock Firebase tests"
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
    
    echo -e "\n${YELLOW}Running Service Behavior Tests...${NC}"
    run_test_suite "Service Behavior Tests" "ServiceBehaviorTests" || SUCCESS=false
    sleep 2
    
    echo -e "\n${YELLOW}Running Mock Services Tests...${NC}"
    run_test_suite "Mock Services Tests" "Services/MockServiceTests" || SUCCESS=false
    sleep 2
    
    echo -e "\n${YELLOW}Running Mock Firebase Tests...${NC}"
    run_test_suite "Mock Firebase Tests" "Services/MockFirebaseTests" || SUCCESS=false
    ;;
    
  "models")
    run_test_suite "Model Tests" "ModelsTests" || SUCCESS=false
    ;;
    
  "services")
    run_test_suite "Service Behavior Tests" "ServiceBehaviorTests" || SUCCESS=false
    ;;
    
  "mocks")
    run_test_suite "Mock Services Tests" "Services/MockServiceTests" || SUCCESS=false
    ;;
    
  "firebase")
    run_test_suite "Mock Firebase Tests" "Services/MockFirebaseTests" || SUCCESS=false
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