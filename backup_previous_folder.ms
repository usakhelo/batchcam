dotnet.loadassembly "Microsoft.VisualBasic.dll"
cam_object = (globalvars.get #batchCameraRender_currentcamera)
if (cam_object != undefined) then
(
	print cam_object
	property_value = getAppData cam_object 7842
	print property_value
	if (property_value != undefined) then
	(
		prev_path = getFilenamePath property_value
		root_path = pathConfig.removePathLeaf prev_path
		new_path = pathConfig.appendPath root_path ((dotnetclass "System.IO.Path").GetRandomFileName())
		(dotnetclass "Microsoft.VisualBasic.FileIO.FileSystem").CopyDirectory prev_path new_path
	)
)