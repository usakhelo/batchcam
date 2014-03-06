--############################################################
--#	This script is supposed to be used in BatchCameraRender as Post render script.
--#	BatchCameraRender as Post render script is executed after every frame, so some sort of treking of the rendered frames is needed to run scripts after all frames will be rendered.
--#	Counting of the rendered frames performed by writing the rendered frame numbers to text file located in rendering folder.
--#	This file is shared across the render servers and named after backburner job ensuring name uniqueness (sort of).
--#	
--#	Created on: 2010-07-14
--############################################################

--get some input information
--get render directory
ini_file_path = getFilenamePath rendOutputFilename
--get max file name
ini_file_name = getFilenameFile maxFileName
ini_file_name = ini_file_name + ".ini"
ini_file_full_name = pathConfig.appendPath ini_file_path ini_file_name
--obtain number of frames to be rendered or frame numbers
--create/open ini file:
--look if the ini file already exists
if not (doesFileExist ini_file_full_name)
then
	--if no create ini file in render directory with maxfile name
	ini_file = createFile ini_file_full_name
	--add some header info
else
	--if yes open ini file in append mode
	ini_file = openFile ini_file_full_name mode:"a+"
--try to add rendered frame number to file
--(consider already added frames. don't know how to know if the frame was actualy rendered or not.)
try
(
	format "%\n" currentTime to:ini_file
)
catch
(
	sleep 2
	format "%\n" currentTime to:ini_file
	--messagebox (getCurrentException()) title:"Error"
	close ini_file
)
--if adding is failed wait for 1-2 second
--try it for 10 times
--(what to do if all attempts failed?)
--close ini file
close ini_file
--reopen ini file and check if it contains all frames' numbers.
--(how to know how many frames should be rendered?)
--if yes then start some other scripts or commands
--and delete ini file to ensure it's uniqueness
--if no then simply quit.