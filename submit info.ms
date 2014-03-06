submitInfoFileName = pathConfig.appendPath (getFilenamePath (rendOutputFilename)) "submitInfo.txt"

submitInfoFile = ""
	
if (doesFileExist submitInfoFileName) then
	submitInfoFile = openFile submitInfoFileName mode:"a+"
else
	submitInfoFile = createfile submitInfoFileName	

dateClass = (dotnetclass "System.DateTime").Now
date_string = dateClass.ToString("yyyy-MM-dd HH:mm:ss")
submitInfo = date_string
format "===============Submitted On: %===============\n"  submitInfo to:submitInfoFile
	
submitInfo = filenameFromPath (rendOutputFilename)
format "Rendered Images: %\n"  submitInfo to:submitInfoFile

format "Camera Name : %\n"  batchCameraRender_currentcamera.name to:submitInfoFile

submitInfo = pathConfig.appendPath maxFilePath maxFileName
format "Submit scene: %\n"  submitInfo to:submitInfoFile

submitInfo = sysInfo.username
format "Username: %\n"  submitInfo to:submitInfoFile

submitInfo = sysInfo.computername
format "Computer: %\n"  submitInfo to:submitInfoFile
	
format "\n"  to:submitInfoFile

close submitInfoFile