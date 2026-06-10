set part      $::env(FPGA_PART)
set top       $::env(SYNTH_TOP)
set builddir  [file normalize $::env(BUILD_DIR)]
set synthroot [file normalize $::env(SRC_ROOT)]
set rtlroot   [file normalize [file join $synthroot .. src]]

file mkdir $builddir/reports

set proj "$builddir/vivado_proj"
file delete -force $proj
create_project cascade_synth $proj -part $part -force

set rtl_files {
    pe.v
    systolic_array.v
    systolic_array_16x16.v
    systolic_matmul_16x16.v
    systolic_tiler.v
    conv_im2col.v
}

foreach f $rtl_files {
    add_files [file join $rtlroot $f]
}

add_files [file join $synthroot tops.v]
add_files -fileset constrs_1 [file join $synthroot constraints.xdc]
set_property top $top [current_fileset]
set_property VERILOG_DEFINE {SYNTHESIS} [current_fileset]

# Use Vivado default strategies for cross-version compatibility (2024/2025+).

launch_runs synth_1 -jobs $::env(VIVADO_JOBS)
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed"
}

open_run synth_1 -name synth_1
report_utilization -file $builddir/reports/utilization_synth.rpt
report_timing_summary -file $builddir/reports/timing_synth.rpt

if {$::env(RUN_IMPL) eq "1"} {
    launch_runs impl_1 -to_step route_design -jobs $::env(VIVADO_JOBS)
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
        error "Implementation failed"
    }

    open_run impl_1 -name impl_1
    report_utilization -file $builddir/reports/utilization.rpt
    report_timing_summary -file $builddir/reports/timing.rpt
    report_power -file $builddir/reports/power.rpt
}

close_project
