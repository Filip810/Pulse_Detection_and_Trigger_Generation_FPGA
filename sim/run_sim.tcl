# =============================================================================
# run_sim.tcl  –  Tworzy projekt Vivado i uruchamia symulację (xsim)
# Użycie: vivado -mode batch -source run_sim.tcl
# =============================================================================

set project_name "pulse_detector_sim"
set project_dir  "./vivado_sim"

# Utwórz projekt (part ZCU106)
create_project $project_name $project_dir -part xczu7ev-ffvc1156-2-e -force

# Dodaj pliki RTL i testbench
add_files -norecurse {
    ../rtl/pulse_detector.v
    ../rtl/pulse_detector_axi.v
}
add_files -fileset sim_1 -norecurse {
    ../sim/tb_pulse_detector.v
}

# Ustaw top module dla symulacji
set_property top tb_pulse_detector [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Uruchom symulację behawioralną
launch_simulation

# Uruchom do końca
run all

# Zamknij projekt
close_project
