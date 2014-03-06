--build.ms file. compiles script in current directory.
--this file gets called by build_script maxscript.

--here can be additionally present some preparetion code
--closing windows, cleaning listener output and so on

-- ShellLaunch ("explorer.exe") ( "/n, " + (getdir #usermacros))
-- try CloseRolloutFloater batchCameraRender_floater catch()
-- filein @"BatchCameraRender.ms"
-- macros.run "Sergo Pogosyan" "BatchCameraRender"


category_name = "Sergo Pogosyan"
script_name = "BatchCameraRender"
output_file = "BatchCameraRender_compiled.ms"
full_output_file = pathConfig.appendPath (getFilenamePath (getSourceFileName())) output_file
try CloseRolloutFloater batchCameraRender_floater catch()

filein @"BatchCameraRender.ms"

if (doesFileExist full_output_file) then
	deleteFile full_output_file	
copyFile (pathConfig.appendPath (getdir #usermacros) (category_name + "-" + script_name + ".mcr")) full_output_file

macros.run category_name script_name