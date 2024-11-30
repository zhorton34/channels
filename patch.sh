#!/bin/bash

set -euo pipefail

WORKFLOW_FILE=".github/workflows/build_php.yaml"
TEMP_FILE=$(mktemp)

# Fix the top-level YAML structure first
cat > "$TEMP_FILE" << 'EOF'
name: Build and Publish PHP Packages

on:
  push:
    branches: [ main ]
  schedule:
    - cron: '0 0 * * 0'  # Weekly builds
  workflow_dispatch:

env:
  RATTLER_CHANNEL_NAME: "php-dist"
  GITHUB_PAGES_URL: "https://zhorton34.github.io/channels"

permissions:
  contents: write
  pages: write
  id-token: write
EOF

# Fix jobs indentation and structure
cat >> "$TEMP_FILE" << 'EOF'

jobs:
  setup-repository:
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Setup GitHub Pages branch
        run: |
          # Create and setup gh-pages branch if it doesn't exist
          if ! git ls-remote --heads origin gh-pages; then
            git checkout --orphan gh-pages
            git rm -rf .
            echo "# PHP Distributions Channel" > README.md
            git add README.md
            git config --global user.email "github-actions[bot]@users.noreply.github.com"
            git config --global user.name "github-actions[bot]"
            git commit -m "Initial gh-pages commit"
            git push origin gh-pages
          fi
EOF

# Continue with the rest of the file, but fix indentation and remove duplicates
sed -n '/prepare:/,$p' "$WORKFLOW_FILE" | \
  sed 's/^[[:space:]]*brew install libiconv[[:space:]]*brew install libiconv/brew install libiconv/' | \
  sed '/Set up macOS dependencies/,+3d' | \
  sed 's/if \[ "\${{ runner.os }}" == "Windows" \]/if [ "${{ runner.os }}" == "Windows" ]/' | \
  sed 's/[[:space:]]*$//' >> "$TEMP_FILE"

# Fix Windows Rattler installation section
sed -i.bak '/if \[ "\${{ runner.os }}" == "Windows" \]/,/fi/ c\
          if [ "${{ runner.os }}" == "Windows" ]; then\
            curl -L -o rattler.zip "${DOWNLOAD_URL}"\
            if [ $? -ne 0 ]; then\
              echo "Failed to download Rattler"\
              exit 1\
            fi\
            unzip rattler.zip\
            if [ $? -ne 0 ]; then\
              echo "Failed to unzip Rattler"\
              exit 1\
            fi\
            mkdir -p "%USERPROFILE%\\rattler"\
            mv rattler.exe "%USERPROFILE%\\rattler\\"\
            echo "%USERPROFILE%\\rattler" >> $GITHUB_PATH\
          fi' "$TEMP_FILE"

# Fix macOS dependencies - add in correct location only
sed -i.bak '/steps:/a\
      - name: Set up macOS dependencies\
        if: runner.os == '"'"'macOS'"'"'\
        run: |\
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"\
          brew install libiconv' "$TEMP_FILE"

# Clean up and replace original file
mv "$TEMP_FILE" "$WORKFLOW_FILE"
find . -name "*.bak" -type f -delete

echo "Workflow file has been repaired!"
