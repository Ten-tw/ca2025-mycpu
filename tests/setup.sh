#!/usr/bin/env bash

# RISCOF Test Infrastructure Setup Script
# Clones required external repositories for RISCV compliance testing

set -euo pipefail

# Repository URLs
ARCH_TEST_REPO="https://github.com/riscv-non-isa/riscv-arch-test"
# RISCOF expects the legacy riscv-test-suite layout.
ARCH_TEST_REV="281d71ef3d61e32111217b20305ea3ef9b1582e2"
RV32EMU_REPO="https://github.com/sysprog21/rv32emu"
# This revision supports the ENABLE_ARCH_TEST build and signature interface.
RV32EMU_REV="035849042c3468fe9e7893d25745ea26aa4778ec"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "==================================="
echo "RISCOF Test Infrastructure Setup"
echo "==================================="
echo ""

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git not found${NC}"
    echo "Please install git to clone test repositories"
    exit 1
fi

checkout_revision() (
    local directory=$1 repository=$2 revision=$3 checkout

    if [ -d "$directory" ]; then
        if [ "$(git -C "$directory" rev-parse --verify HEAD 2>/dev/null)" != "$revision" ]; then
            echo "Existing $directory checkout differs from $revision."
            echo "Move the existing directory aside and run ./setup.sh again."
            exit 1
        fi
        echo -e "${GREEN}✓${NC} $directory already at $revision"
        return
    fi

    echo -e "${YELLOW}→${NC} Downloading $directory at $revision..."
    checkout=$(mktemp -d ".$directory.XXXXXX")
    trap 'rm -rf -- "$checkout"' EXIT
    git init -q "$checkout"
    git -C "$checkout" remote add origin "$repository"
    git -C "$checkout" fetch --depth=1 origin "$revision"
    git -C "$checkout" checkout --detach FETCH_HEAD
    mv "$checkout" "$directory"
    trap - EXIT
)

checkout_revision riscv-arch-test "$ARCH_TEST_REPO" "$ARCH_TEST_REV"
checkout_revision rv32emu "$RV32EMU_REPO" "$RV32EMU_REV"

# Verify test suite structure
echo ""
echo "Verifying test suite structure..."

if [ -d "riscv-arch-test/riscv-test-suite" ]; then
    TEST_COUNT=$(find riscv-arch-test/riscv-test-suite -name "*.S" | wc -l)
    echo -e "${GREEN}✓${NC} Test suite verified (found $TEST_COUNT test files)"
else
    echo -e "${RED}✗${NC} Test suite structure invalid"
    exit 1
fi

if [ -d "riscv-arch-test/riscv-test-suite/env" ]; then
    echo -e "${GREEN}✓${NC} Test environment verified"
else
    echo -e "${RED}✗${NC} Test environment missing"
    exit 1
fi

echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Run compliance tests: ./run-compliance.sh [PROJECT]"
echo "  2. Projects: 1-single-cycle, 2-mmio-trap, or 3-pipeline"
echo ""
echo "Example:"
echo "  ./run-compliance.sh 1-single-cycle"
echo ""
