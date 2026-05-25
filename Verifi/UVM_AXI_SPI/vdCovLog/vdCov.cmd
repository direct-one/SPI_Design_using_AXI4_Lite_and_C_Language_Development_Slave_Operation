verdiWindowResize -win $_vdCoverage_1 "830" "370" "900" "700"
gui_set_pref_value -category {coveragesetting} -key {geninfodumping} -value 1
gui_exclusion -set_force true
verdiSetFont  -font  {DejaVu Sans}  -size  11
verdiSetFont -font "DejaVu Sans" -size "11"
gui_assert_mode -mode flat
gui_class_mode -mode hier
gui_excl_mgr_flat_list -on  0
gui_covdetail_select -id  CovDetail.1   -name   Line
verdiWindowWorkMode -win $_vdCoverage_1 -coverageAnalysis
verdiSetActWin -dock widgetDock_Message
gui_open_cov  -hier coverage.vdb -testdir {} -test {coverage/sim1} -merge MergedTest -db_max_tests 10 -sdc_level 1 -fsm transition
verdiWindowResize -win $_vdCoverage_1 "830" "370" "1015" "709"
gui_covtable_show -show  { Function Groups } -id  CoverageTable.1  -test  MergedTest
verdiSetActWin -dock widgetDock_<Summary>
gui_list_select -id CoverageTable.1 -list covtblFGroupsList { {/$unit::spi_coverage::spi_data_cg}   }
gui_list_expand -id  CoverageTable.1   -list {covtblFGroupsList} {/$unit::spi_coverage::spi_data_cg}
gui_list_expand -id CoverageTable.1   {/$unit::spi_coverage::spi_data_cg}
gui_list_action -id  CoverageTable.1 -list {covtblFGroupsList} {/$unit::spi_coverage::spi_data_cg}  -column {Group} 
verdiWindowResize -win $_vdCoverage_1 "830" "370" "1311" "709"
gui_list_select -id CoverageTable.1 -list covtblFGroupsList { {/$unit::spi_coverage::spi_data_cg}   }
vdCovExit -noprompt
