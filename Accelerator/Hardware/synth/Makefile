# Vivado synthesis benchmark for AWS F1 (xcvu9p).
#
# Quick start on AWS FPGA Developer AMI:
#   cd Accelerator/Hardware/synth
#   make impl TARGET=tiler
#   make report
#
# Targets: array | tiler | conv | all

TARGET ?= tiler
FPGA_PART ?= xcvu9p-flgb2104-2-i
BUILD_DIR ?= build
SRC_ROOT := $(abspath .)
VIVADO ?= vivado
VIVADO_JOBS ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

ifeq ($(TARGET),array)
  SYNTH_TOP := cascade_synth_top_array
else ifeq ($(TARGET),tiler)
  SYNTH_TOP := cascade_synth_top_tiler
else ifeq ($(TARGET),conv)
  SYNTH_TOP := cascade_synth_top_conv
else ifeq ($(TARGET),all)
  SYNTH_TOP :=
else
  $(error Unknown TARGET=$(TARGET). Use array, tiler, conv, or all)
endif

.PHONY: help check-vivado synth impl report clean all-targets

help:
	@echo "Cascade AWS F1 synthesis benchmark"
	@echo ""
	@echo "Usage:"
	@echo "  make impl TARGET=tiler     # recommended: synth + place/route"
	@echo "  make synth TARGET=array    # faster: synthesis only"
	@echo "  make report                # print LUT/DSP/Fmax summary"
	@echo "  make all-targets           # run impl for array, tiler, conv"
	@echo ""
	@echo "AWS FPGA Developer AMI setup:"
	@echo "  1. Launch FPGA Developer AMI in us-east-1 (or other F1 region)"
	@echo "  2. Use f1.2xlarge (or m5.2xlarge for synthesis-only)"
	@echo "  3. git clone repo && cd Accelerator/Hardware/synth"
	@echo "  4. source /opt/Xilinx/Vivado/<version>/settings64.sh"
	@echo "  5. make impl && make report"
	@echo ""
	@echo "Variables: TARGET, FPGA_PART, BUILD_DIR, VIVADO_JOBS"

check-vivado:
	@command -v $(VIVADO) >/dev/null || ( \
		echo "vivado not found. On AWS FPGA Developer AMI run:"; \
		echo "  source /opt/Xilinx/Vivado/<version>/settings64.sh"; \
		exit 1 \
	)

synth: check-vivado
	@mkdir -p $(BUILD_DIR)
	RUN_IMPL=0 BUILD_DIR=$(BUILD_DIR) SRC_ROOT=$(SRC_ROOT) \
		FPGA_PART=$(FPGA_PART) SYNTH_TOP=$(SYNTH_TOP) VIVADO_JOBS=$(VIVADO_JOBS) \
		$(VIVADO) -mode batch -notrace -source scripts/run_vivado.tcl
	@bash scripts/print_summary.sh $(BUILD_DIR)

impl: check-vivado
	@mkdir -p $(BUILD_DIR)
	RUN_IMPL=1 BUILD_DIR=$(BUILD_DIR) SRC_ROOT=$(SRC_ROOT) \
		FPGA_PART=$(FPGA_PART) SYNTH_TOP=$(SYNTH_TOP) VIVADO_JOBS=$(VIVADO_JOBS) \
		$(VIVADO) -mode batch -notrace -source scripts/run_vivado.tcl
	@bash scripts/print_summary.sh $(BUILD_DIR)

report:
	@bash scripts/print_summary.sh $(BUILD_DIR)

all-targets:
	@$(MAKE) impl TARGET=array BUILD_DIR=build-array
	@$(MAKE) impl TARGET=tiler BUILD_DIR=build-tiler
	@$(MAKE) impl TARGET=conv  BUILD_DIR=build-conv

clean:
	rm -rf build build-array build-tiler build-conv
