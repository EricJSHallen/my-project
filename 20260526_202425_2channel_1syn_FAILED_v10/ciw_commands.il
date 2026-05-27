; CIW launch commands for 20260526_202425_2channel_1syn
; Paste into CIW, preferably 10-20 seconds apart while testing.
; Per-job wrapper handles CAD_PROJECT_DIR and ade_e.scs seeding.
ipcBeginProcess("sh -c '/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260526_202425_2channel_1syn/run_ocean_job.sh 0'")
ipcBeginProcess("sh -c '/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260526_202425_2channel_1syn/run_ocean_job.sh 1'")
ipcBeginProcess("sh -c '/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260526_202425_2channel_1syn/run_ocean_job.sh 2'")
ipcBeginProcess("sh -c '/home/s5117909/Documents/thesis/thesis_codebase/thesis_database/20260526_202425_2channel_1syn/run_ocean_job.sh 3'")
