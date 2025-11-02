#!/bin/bash

# Script to generate changelog.json from git log
# Run during Xcode build phase

set -e

echo "SRCROOT: ${SRCROOT}"
echo "PWD: $(pwd)"

OUTPUT_FILE="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/changelog.json"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Get git log and convert to JSON (last 100 commits)
# Using Python for reliable JSON escaping
# Pass SRCROOT to Python so git commands run in the right directory
python3 << PYTHON_SCRIPT > "$OUTPUT_FILE"
import json
import subprocess
import os
import sys
from datetime import datetime, timezone

# Change to project directory for git commands
srcroot = '${SRCROOT}'
print(f"Python changing to: {srcroot}", file=sys.stderr)
os.chdir(srcroot)
print(f"Python pwd: {os.getcwd()}", file=sys.stderr)

# Get git log - explicitly specify git directory and work tree
git_dir = os.path.join(srcroot, '.git')
result = subprocess.run(
    ['git', '--git-dir', git_dir, '--work-tree', srcroot, 'log', '-100', '--pretty=format:%H%x09%aI%x09%s%x09%an'],
    capture_output=True,
    text=True
)
print(f"Git dir: {git_dir}", file=sys.stderr)
print(f"Git output length: {len(result.stdout)}", file=sys.stderr)

if result.returncode != 0:
    print(f"Git error: {result.stderr}", file=sys.stderr)
    sys.exit(1)

entries = []
for line in result.stdout.strip().split('\n'):
    if not line:
        continue
    parts = line.split('\t')
    if len(parts) == 4:
        entries.append({
            'hash': parts[0],
            'date': parts[1],
            'message': parts[2],
            'author': parts[3]
        })

changelog = {
    'generatedAt': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
    'entries': entries
}

print(json.dumps(changelog, indent=2))
PYTHON_SCRIPT

echo "Generated changelog at: $OUTPUT_FILE"
