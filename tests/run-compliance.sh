#!/usr/bin/env bash

# Run RISCOF compliance tests for MyCPU projects
# Usage:
#   ./run-compliance.sh [PROJECT]
# PROJECT: 1-single-cycle, 2-mmio-trap, or 3-pipeline (default: 1-single-cycle)

set -euo pipefail  # Improved error handling: unset variables and pipe failures

# Force English locale for consistent date output
export LC_ALL=C

# Add common toolchain paths to PATH if not already present
# This must happen BEFORE toolchain detection
for toolchain_path in "$HOME/riscv/toolchain/bin" "/opt/riscv/bin"; do
    if [ -d "$toolchain_path" ]; then
        export PATH="$toolchain_path:$PATH"
    fi
done

# Detect RISC-V GNU Toolchain
# Try toolchain prefixes in order and verify they support RISC-V
check_cross_tools() {
    local prefix=$1
    if command -v "${prefix}gcc" &> /dev/null && \
       command -v "${prefix}cpp" &> /dev/null && \
       "${prefix}cpp" -dM - </dev/null 2>/dev/null | grep __riscv > /dev/null; then
        return 0
    fi
    return 1
}

# Honor CROSS_COMPILE environment variable (Linux kernel convention)
if [ -z "${CROSS_COMPILE:-}" ]; then
    # Auto-detect from common toolchain prefixes
    for prefix in riscv-none-elf- riscv32-unknown-elf- riscv64-unknown-elf- riscv-none-embed-; do
        if check_cross_tools "$prefix"; then
            CROSS_COMPILE="$prefix"
            break
        fi
    done
fi

# Verify we found a working toolchain
if [ -z "${CROSS_COMPILE:-}" ]; then
    echo "Error: RISC-V GNU Toolchain not found"
    echo "Please install a RISC-V toolchain or set CROSS_COMPILE environment variable"
    echo "Example: export CROSS_COMPILE=riscv-none-elf-"
    exit 1
fi

# Determine which project to test
PROJECT="${1:-1-single-cycle}"

# Validate project
if [[ ! -d "../${PROJECT}" ]]; then
    echo "Error: Project directory ../${PROJECT} not found"
    echo "Usage: $0 [1-single-cycle|2-mmio-trap|3-pipeline]"
    exit 1
fi

# Support project-specific work directories for parallel execution
# Default to riscof_work for backward compatibility
WORK_DIR="${RISCOF_WORK:-riscof_work}"

echo "Running RISCOF compliance tests for ${PROJECT}..."

# Select appropriate config file
CONFIG_FILE="config-${PROJECT}.ini"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file $CONFIG_FILE not found"
    exit 1
fi

echo "Using config: $CONFIG_FILE"

# Check if riscof is installed
if ! command -v riscof &> /dev/null; then
    echo "Error: riscof not found in PATH"
    echo ""
    echo "Please install RISCOF framework:"
    echo "  pip install riscof"
    echo ""
    echo "Or if already installed, ensure it's in your PATH:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    exit 1
fi

# Fetch missing dependencies and verify the revisions of existing checkouts.
./setup.sh

# Build rv32emu reference model if not already built
if [[ ! -f "rv32emu/build/rv32emu" ]]; then
    echo "Building rv32emu reference model..."
    echo "This is a one-time setup that may take 1-2 minutes..."
    echo ""
    # The RISCOF reference only needs RV32I and Zicsr. The build does not
    # use upstream prebuilt test artifacts, so skip their release discovery.
    if make -C rv32emu ENABLE_ARCH_TEST=1 ENABLE_FULL4G=1 \
        ENABLE_EXT_F=0 ENABLE_SDL=0 ENABLE_SDL_MIXER=0 LATEST_RELEASE=dummy; then
        echo "✅ rv32emu built successfully"
    else
        echo "❌ Failed to build rv32emu"
        echo "Check the build errors above and rerun this script."
        exit 1
    fi
    echo ""
fi

# Create work directory if it doesn't exist
mkdir -p "$WORK_DIR"

# Run RISCOF with progress tracking
echo "Using RISCOF: $(command -v riscof)"
echo "Using toolchain: $(command -v riscv-none-elf-gcc || command -v riscv32-unknown-elf-gcc)"
echo ""
echo "Starting compliance test run at $(date)"
echo "This may take 10-15 minutes for the full test suite..."
echo ""

if riscof run --config="$CONFIG_FILE" --suite=riscv-arch-test/riscv-test-suite/ --env=riscv-arch-test/riscv-test-suite/env --work-dir="$WORK_DIR"; then
    echo ""
    echo "✅ Compliance tests complete. Results in ${WORK_DIR}/"
    echo "Completion time: $(date)"
    exit 0
else
    echo ""
    echo "❌ Compliance tests encountered errors. Check ${WORK_DIR}/ for details."
    exit 1
fi
