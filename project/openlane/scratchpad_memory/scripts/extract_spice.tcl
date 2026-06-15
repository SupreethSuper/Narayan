# =============================================================================
# extract_spice.tcl — extract a LVS-ready SPICE netlist from GDS with Magic
# (called by run_lvs.sh; needs DESIGN_NAME, GDS_PATH, OUT_DIR in env)
# =============================================================================

set design $::env(DESIGN_NAME)
set gds    $::env(GDS_PATH)
set outdir $::env(OUT_DIR)
file mkdir $outdir

crashbackups stop
drc off

gds read $gds
load $design -dereference
select top cell

# LVS-style extraction: connectivity only, no parasitics
extract do local
extract no capacitance
extract no coupling
extract no resistance
extract no adjust
extract unique
extract

ext2spice lvs
ext2spice -o $outdir/$design.spice $design

puts "\[INFO] SPICE written: $outdir/$design.spice"
exit 0
