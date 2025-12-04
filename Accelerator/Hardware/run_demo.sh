#!/bin/bash
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p output

# Helper function
run_demo() {
    local name=$1
    local files=$2
    local tb_file=$3
    
    # Extract filename without path and extension for the binary name (e.g., tb_pe_demo)
    local tb_name=$(basename "$tb_file" .v)
    
    echo -e "${BLUE}Running: ${name}${NC}"
    
    # Compile
    # FIX: Only pass ${files} to iverilog. Do NOT append ${tb_file} again, 
    # as it is already included in the ${files} string.
    if iverilog -g2012 -o output/${tb_name}.vvp ${files}; then
        # Run and strip VCD info to just show the clean output
        vvp output/${tb_name}.vvp | grep -v "VCD"
        echo -e "${GREEN}--------------------------------------${NC}"
    else
        echo -e "${RED}Compilation failed! Check errors above.${NC}"
        echo -e "${RED}--------------------------------------${NC}"
    fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   LIVE PRESENTATION DEMO MODE${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Edit files in the 'demo/' folder to change inputs."
echo ""

# 1. PE
run_demo "1. Processing Element (demo/tb_pe_demo.v)" \
    "src/pe.v demo/tb_pe_demo.v" \
    "demo/tb_pe_demo.v"

# 2. Array
run_demo "2. Systolic Array 3x3 (demo/tb_array_demo.v)" \
    "src/pe.v src/systolic_array.v demo/tb_array_demo.v" \
    "demo/tb_array_demo.v"

# 3. Tiling
if [ -f "src/systolic_tiler.v" ]; then
    run_demo "3. Tiling 6x6 (demo/tb_tiling_demo.v)" \
        "src/pe.v src/systolic_array.v src/systolic_tiler.v demo/tb_tiling_demo.v" \
        "demo/tb_tiling_demo.v"
fi

# 4. Convolution
if [ -f "src/conv_im2col.v" ]; then
    run_demo "4. Convolution (demo/tb_conv_demo.v)" \
        "src/pe.v src/systolic_array.v src/conv_im2col.v demo/tb_conv_demo.v" \
        "demo/tb_conv_demo.v"
fi