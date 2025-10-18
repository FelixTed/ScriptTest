#!/bin/bash
# Script to create a PR with ONLY specific files (ignores other remote changes)
# Usage: ./create-surgical-pr.sh <branch-name> <base-branch> <file1> [file2] [file3] ...

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse arguments
if [ "$#" -lt 3 ]; then
    echo -e "${RED}Usage: $0 <branch-name> <base-branch> <file1> [file2] [file3] ...${NC}"
    echo "Example: $0 fix/spi-only main BMS_LP_App/Services/src/SPIScheduler/SPIScheduler.c"
    exit 1
fi

BRANCH_NAME=$1
BASE_BRANCH=$2
shift 2
FILES=("$@")

echo -e "${CYAN}=== Creating Clean PR with Only Specified Files ===${NC}"
echo -e "${CYAN}Branch: $BRANCH_NAME${NC}"
echo -e "${CYAN}Base: $BASE_BRANCH${NC}"
echo -e "${CYAN}Files: ${#FILES[@]}${NC}"

# Create temp directory for file storage
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Save current file states
echo -e "\n${GREEN}Saving current file states...${NC}"
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        dest_path="$TEMP_DIR/$file"
        dest_dir=$(dirname "$dest_path")
        mkdir -p "$dest_dir"
        cp "$file" "$dest_path"
        echo -e "  ${CYAN}✓ Saved: $file${NC}"
    else
        echo -e "  ${YELLOW}⚠ Not found: $file${NC}"
    fi
done

# Fetch and prepare clean branch
echo -e "\n${GREEN}Fetching from remote...${NC}"
git fetch origin

echo -e "${GREEN}Checking out $BASE_BRANCH...${NC}"
git checkout "$BASE_BRANCH"
git pull origin "$BASE_BRANCH"

# Delete branch if exists
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo -e "${YELLOW}Deleting existing local branch: $BRANCH_NAME${NC}"
    git branch -D "$BRANCH_NAME"
fi

# Create fresh branch
echo -e "${GREEN}Creating fresh branch: $BRANCH_NAME${NC}"
git checkout -b "$BRANCH_NAME"

# Restore ONLY the specified files
echo -e "\n${GREEN}Restoring ONLY specified files to new branch:${NC}"
FILES_ADDED=0
for file in "${FILES[@]}"; do
    source_path="$TEMP_DIR/$file"
    if [ -f "$source_path" ]; then
        dest_dir=$(dirname "$file")
        if [ ! -z "$dest_dir" ] && [ "$dest_dir" != "." ]; then
            mkdir -p "$dest_dir"
        fi
        cp "$source_path" "$file"
        git add -f "$file"
        echo -e "  ${CYAN}✓ $file${NC}"
        ((FILES_ADDED++))
    else
        echo -e "  ${RED}✗ $file (NOT FOUND)${NC}"
    fi
done

if [ $FILES_ADDED -eq 0 ]; then
    echo -e "\n${RED}No files were found. Aborting.${NC}"
    git checkout "$BASE_BRANCH"
    git branch -D "$BRANCH_NAME"
    exit 1
fi

# Show what will be committed
echo -e "\n${GREEN}Files staged for commit:${NC}"
git diff --cached --name-status

echo -e "\n${GREEN}Full diff:${NC}"
git diff --cached

# Confirm commit
echo -e "\n${YELLOW}Commit these changes? (y/n)${NC}"
read -r confirm
if [ "$confirm" != "y" ]; then
    echo -e "${YELLOW}Cancelled. Cleaning up...${NC}"
    git reset --hard
    git checkout "$BASE_BRANCH"
    git branch -D "$BRANCH_NAME"
    exit 0
fi

# Get commit message
echo -e "${YELLOW}Enter commit message (or press Enter for default):${NC}"
read -r COMMIT_MSG
if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="Update specific service files"
fi

# Commit
git commit -m "$COMMIT_MSG"

# Push
echo -e "\n${YELLOW}Force push to origin/$BRANCH_NAME? This will overwrite remote branch if it exists. (y/n)${NC}"
read -r push_confirm
if [ "$push_confirm" == "y" ]; then
    git push -f origin "$BRANCH_NAME"
    
    echo -e "\n${GREEN}=== SUCCESS ===${NC}"
    echo -e "${GREEN}Branch pushed with ONLY the specified files!${NC}"
    echo -e "\n${CYAN}Create PR on Bitbucket:${NC}"
    echo -e "${CYAN}https://bitbucket.org/YOUR_WORKSPACE/YOUR_REPO/pull-requests/new?source=$BRANCH_NAME&dest=$BASE_BRANCH${NC}"
    
    git checkout "$BASE_BRANCH"
else
    echo -e "${YELLOW}Push cancelled.${NC}"
    git checkout "$BASE_BRANCH"
fi