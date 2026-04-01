#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
FW_DIR="$ROOT_DIR/framework"
SRC_DIR="$ROOT_DIR/src"

ERRORS=0
echo -e "${YELLOW}Starting AsmFrameWork Linter...${NC}"

DIRS="$FW_DIR $SRC_DIR"

# 1. Проверка на 'default rel'
for dir in $DIRS; do
    for file in $(find "$dir" -name '*.asm' -not -path '*/example/*' 2>/dev/null); do
        if grep -qE "section \.text|section \.data" "$file"; then
            if ! grep -q "default rel" "$file"; then
                rel_path="${file#$ROOT_DIR/}"
                echo -e "${RED}[LINT]${NC} Missing 'default rel' in $rel_path"
                ERRORS=$((ERRORS+1))
            fi
        fi
    done
done

# 2. Проверка на опечатки с запятыми (mov, rdi вместо mov rdi,)
for dir in $DIRS; do
    BAD_COMMAS=$(grep -rEn "^[[:space:]]*[a-zA-Z]+," "$dir"/ --include="*.asm" 2>/dev/null | grep -v '%macro\|%define\|;')
    if [ -n "$BAD_COMMAS" ]; then
        echo -e "${RED}[LINT]${NC} Comma immediately after instruction (typo?):"
        while IFS= read -r line; do
            clean="${line#$ROOT_DIR/}"
            echo "  $clean"
        done <<< "$BAD_COMMAS"
        ERRORS=$((ERRORS+1))
    fi
done

# 3. Trailing whitespace
for dir in $DIRS; do
    TRAILING=$(grep -rEn '[[:space:]]+$' "$dir"/ --include="*.asm" 2>/dev/null)
    if [ -n "$TRAILING" ]; then
        count=$(echo "$TRAILING" | wc -l)
        echo -e "${YELLOW}[WARN]${NC} Trailing whitespace in $count line(s) (run 'apm fmt' to fix)"
    fi
done

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}Linting failed! $ERRORS error(s) found.${NC}"
    exit 1
else
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
fi
