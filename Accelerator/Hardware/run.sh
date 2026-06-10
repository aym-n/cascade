#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Systolic Array Simulation Runner${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check dependencies
if ! command -v iverilog &> /dev/null; then
    echo -e "${RED}Error: iverilog not found!${NC}"
    exit 1
fi

mkdir -p output

# Function to run simulation
run_simulation() {
    local test_name=$1
    local src_files=$2
    local tb_file=$3
    local output_name=$4
    
    echo -e "${YELLOW}Running: ${test_name}${NC}"
    echo "  Compiling..."
    
    # Compile
    if iverilog -g2012 -o output/${output_name}.vvp ${src_files} ${tb_file} 2>output/${output_name}_compile.log; then
        echo -e "  ${GREEN}✓${NC} Compilation successful"
    else
        echo -e "  ${RED}✗${NC} Compilation failed"
        cat output/${output_name}_compile.log
        return 1
    fi
    
    # Run simulation
    echo "  Simulating..."
    if vvp output/${output_name}.vvp > output/${output_name}_sim.log 2>&1; then
        echo -e "  ${GREEN}✓${NC} Simulation completed"
        
        # Check if VCD was generated
        if [ -f "${output_name}.vcd" ]; then
            mv ${output_name}.vcd output/
        fi
        return 0
    else
        echo -e "  ${RED}✗${NC} Simulation failed"
        return 1
    fi
}

# --- TEST 1: Processing Element ---
echo -e "\n${BLUE}[1/3] Testing Processing Element${NC}"
echo "--------------------------------------"
run_simulation "PE Test" "src/pe.v" "sim/tb_pe.v" "tb_pe"
pe_result=$?

# --- TEST 2: Systolic Array (3x3) ---
echo -e "\n${BLUE}[2/3] Testing Systolic Array (3x3)${NC}"
echo "--------------------------------------"
run_simulation "Systolic Array Test" "src/pe.v src/systolic_array.v" "sim/tb_systolic_array.v" "tb_systolic_array"
array_result=$?

if [ $array_result -eq 0 ]; then
    # Show the matrix result from the log
    echo -e "${BLUE}--- Matrix Output ---${NC}"
    grep -A 4 "Expected" output/tb_systolic_array_sim.log
fi

# --- TEST 3: Tiling (6x6 on 3x3 HW) ---
echo -e "\n${BLUE}[3/3] Testing Tiling Support (6x6)${NC}"
echo "--------------------------------------"
# Note: This requires src/systolic_tiler_6x6.v to exist
if [ -f "src/systolic_tiler.v" ]; then
    run_simulation "Tiling Test" \
        "src/pe.v src/systolic_array.v src/systolic_tiler.v" \
        "sim/tb_tiling.v" \
        "tb_tiling"
    tiling_result=$?
    
    if [ $tiling_result -eq 0 ]; then
        echo -e "${BLUE}--- 6x6 Matrix Result ---${NC}"
        # grep the row outputs from the log
        grep "Row" output/tb_tiling_sim.log
        grep "SUCCESS" output/tb_tiling_sim.log
    fi
else
    echo -e "${YELLOW}Skipping: src/systolic_tiler_6x6.v not found${NC}"
    tiling_result=1
fi

# --- TEST 4: Convolution Engine ---
echo -e "\n${BLUE}[4/4] Testing Convolution Engine (im2col)${NC}"
echo "--------------------------------------"
if [ -f "src/conv_im2col.v" ]; then
    run_simulation "Conv Test" \
        "src/pe.v src/systolic_array.v src/conv_im2col.v" \
        "sim/tb_conv.v" \
        "tb_conv"
    conv_result=$?
    
    if [ $conv_result -eq 0 ]; then
         sed '1,2d' output/tb_conv_sim.log
    fi
else
    echo -e "${YELLOW}Skipping: src/conv_im2col.v not found${NC}"
    conv_result=1
fi

# --- TEST 5: 16x16 Matrix Multiply (no tiling) ---
echo -e "\n${BLUE}[5/5] Testing 16x16 Matrix Multiply (no tiling)${NC}"
echo "--------------------------------------"
if [ -f "src/systolic_matmul_16x16.v" ]; then
    run_simulation "16x16 Matmul Test" \
        "src/pe.v src/systolic_array_16x16.v src/systolic_matmul_16x16.v" \
        "sim/tb_matmul_16x16.v" \
        "tb_matmul_16x16"
    matmul16_result=$?

    if [ $matmul16_result -eq 0 ]; then
        grep -E "\[PASS\]|\[FAIL\]" output/tb_matmul_16x16_sim.log || true
    fi
else
    echo -e "${YELLOW}Skipping: src/systolic_matmul_16x16.v not found${NC}"
    matmul16_result=1
fi

# --- SUMMARY ---
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Simulation Summary${NC}"
echo -e "${BLUE}========================================${NC}"

[ $pe_result -eq 0 ]    && echo -e "PE Unit Test:      ${GREEN}PASSED${NC}" || echo -e "PE Unit Test:      ${RED}FAILED${NC}"
[ $array_result -eq 0 ] && echo -e "Systolic 3x3:      ${GREEN}PASSED${NC}" || echo -e "Systolic 3x3:      ${RED}FAILED${NC}"
[ $tiling_result -eq 0 ]&& echo -e "Tiling 6x6:        ${GREEN}PASSED${NC}" || echo -e "Tiling 6x6:        ${RED}FAILED${NC}"
[ $conv_result -eq 0 ]  && echo -e "Convolution Test:  ${GREEN}PASSED${NC}" || echo -e "Convolution Test:  ${RED}FAILED${NC}"
[ $matmul16_result -eq 0 ] && echo -e "16x16 Matmul:      ${GREEN}PASSED${NC}" || echo -e "16x16 Matmul:      ${RED}FAILED${NC}"
echo -e "\nLogs and Waveforms are in: ${BLUE}output/${NC}"