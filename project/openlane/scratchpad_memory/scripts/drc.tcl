# =============================================================================
# drc.tcl — batch DRC on a GDS with Magic (sky130)
#
# Run:
#   export DESIGN_NAME=scratchpad_memory
#   export GDS_PATH=/path/to/runs/<tag>/results/final/gds/scratchpad_memory.gds
#   export OUT_DIR=./drc_out          # optional, defaults to cwd
#   magic -dnull -noconsole \
#     -rcfile $PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc scripts/drc.tcl
#
# Exit code: 0 = clean, 1 = violations found, 2 = bad invocation
# =============================================================================

if {![info exists ::env(DESIGN_NAME)] || ![info exists ::env(GDS_PATH)]} {
    puts "ERROR: set DESIGN_NAME and GDS_PATH in the environment."
    exit 2
}
set design  $::env(DESIGN_NAME)
set gds     $::env(GDS_PATH)
set outdir  [expr {[info exists ::env(OUT_DIR)] ? $::env(OUT_DIR) : [pwd]}]
file mkdir $outdir

crashbackups stop
drc off
snap internal

puts "\[INFO] Reading GDS: $gds"
gds read $gds
load $design -dereference
select top cell

# Full (not incremental) rule deck, euclidean spacing as the fab measures it
drc euclidean on
drc style drc(full)
drc on
drc catchup

set total 0
set fout [open "$outdir/$design.drc.rpt" w]
puts $fout "DRC report — $design"
puts $fout "GDS: $gds"
puts $fout "Date: [clock format [clock seconds]]"
puts $fout "----------------------------------------"

foreach {why locs} [drc listall why] {
    puts $fout "\nVIOLATION: $why"
    foreach l $locs {
        incr total
        puts $fout "  $l"
    }
}

puts $fout "\n----------------------------------------"
puts $fout "Total DRC violations: $total"
close $fout

puts "\[INFO] DRC finished: $total violation(s)."
puts "\[INFO] Report: $outdir/$design.drc.rpt"
exit [expr {$total > 0 ? 1 : 0}]
