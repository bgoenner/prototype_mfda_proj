if {![info exists standalone] || $standalone} {
  # Read lef
  read_lef $::env(TECH_LEF)
  read_lef $::env(SC_LEF)
  if {[info exist ::env(ADDITIONAL_LEFS)]} {
    foreach lef $::env(ADDITIONAL_LEFS) {
      read_lef $lef
    }
  }

  # Read liberty files
  foreach libFile $::env(LIB_FILES) {
    read_liberty $libFile
  }

  # Read design files
  read_def $::env(RESULTS_DIR)/1_floorplan.def
  read_sdc $::env(RESULTS_DIR)/1_floorplan.sdc
  if [file exists $::env(PLATFORM_DIR)/derate.tcl] {
    source $::env(PLATFORM_DIR)/derate.tcl
  }
} else {
  puts "Starting global placement"
}


# Set res and cap
source $::env(PLATFORM_DIR)/setRC.tcl
# set_dont_use $::env(DONT_USE_CELLS)

# set fastroute layer reduction
if {[info exist env(FASTROUTE_TCL)]} {
  source $env(FASTROUTE_TCL)
} else {
  set_global_routing_layer_adjustment $env(MIN_ROUTING_LAYER)-$env(MAX_ROUTING_LAYER) 0.5
  set_routing_layers -signal $env(MIN_ROUTING_LAYER)-$env(MAX_ROUTING_LAYER)
  set_macro_extension 2
}

# check the lower boundary of the PLACE_DENSITY and add PLACE_DENSITY_LB_ADDON if it exists
if {[info exist ::env(PLACE_DENSITY_LB_ADDON)]} {
  set place_density_lb [gpl::get_global_placement_uniform_density \
  -pad_left $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT) \
  -pad_right $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT)]
  set place_density [expr $place_density_lb + $::env(PLACE_DENSITY_LB_ADDON) + 0.01]
  if {$place_density > 1.0} {
    set place_density 1.0
  }
} else {
  set place_density $::env(PLACE_DENSITY)
}

if {[info exist ::env(PLACE_OVERFLOW)]} {
  set place_overflow $::env(PLACE_OVERFLOW)
} else {
  set place_overflow 0.1
}

#if {info exist ::env(GLOBAL_PLACEMENT_ARGS_PATH)} {
#  source GLOBAL_PLACEMENT_ARGS_PATH
#}

if { 0 != [llength [array get ::env GLOBAL_PLACEMENT_ARGS]] } {
global_placement -routability_driven -density $place_density \
    -pad_left $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT) \
    -pad_right $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT) \
    -overflow $place_overflow \
    $::env(GLOBAL_PLACEMENT_ARGS)
} elseif {[info exist ::env(GLOBAL_PLACEMENT_ARGS_PATH)]} {
  source $::env(GLOBAL_PLACEMENT_ARGS_PATH)
  global_placement -routability_driven -density $place_density \
    -pad_left $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT) \
    -pad_right $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT) \
    -bin_grid_count $bin_grid_count \
    -init_density_penalty $init_density_penalty \
    -init_wirelength_coef $init_wirelength_coef \
    -min_phi_coef $min_phi_coef \
    -max_phi_coef $max_phi_coef \
    -overflow $overflow \
    -initial_place_max_iter $initial_place_max_iter \
    -initial_place_max_fanout $initial_place_max_fanout
} else {
global_placement -routability_driven -density $place_density \
    -pad_left $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT) \
    -pad_right $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT) \
    -overflow $place_overflow
}

estimate_parasitics -placement

source $::env(SCRIPTS_DIR)/report_metrics.tcl
report_metrics "global place" false

if {![info exists standalone] || $standalone} {
  write_def $::env(RESULTS_DIR)/2_1_place_gp.def
  exit
}
