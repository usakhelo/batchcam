/*****************************************
Script by Jos Balcaen
you can contact me @ josbalcaen.com
*****************************************/

global myRoll
global roll_GlobalSettings
global mf_render_rollout

try (closeRolloutFloater mf_render_rollout) catch ()

(
	struct strMaxFile
	(
		bPrivateOverride = false,
		bTimeOutput = false,
		TimeOutputType = 1,
		RangeFrom = 0,
		RangeTo = 1,
		bOutputSize = false,
		OutputWidth = 0,
		OutputHeight = 0,
		bSave = false,
		SaveFolder = "",
		SaveType = ""
	)
	
	local ArrMaxFiles = #()
	
	rollout myRoll "Render Multiple Max Files with BatchCam support"
	(
		local number_of_files = 0
		local ListOfMaxFiles = #()
		local savePath = ""
		local numberselected = 0
		
		button btnBrowseFile "Browse for files" across:2 width:500 align:#left
		button btnBrowseFolder "Folder" width:60 align:#left offset:[220,0]
		multilistbox mlbMaxFiles
		label lbNumberOfFiles " No files selected" across:3 align:#left
		button btnRemoveSelected "Remove" align:#right width:100 offset:[85,0] tooltip:"Remove selected files from list."
		button btnRemoveAll "Remove all" align:#right width:100 tooltip:"Remove all files from the list."
		-- SubRollout subroll_OverwriteSettings "Overwrite Settings" height:65
		button btnRender "Render all files" width:480 height:30 align:#left across:2
		button btnRender2 "BatchCamera" width:80 height:30 align:#right enabled:(doesfileexist ((getdir #usermacros) + @"\Sergo Pogosyan-BatchCameraRender.mcr"))
		
		progressbar prgProgressFiles value:100 color:green height:7
		label lblInfo "Select Files To Render..." align:#left across:2
		label jos "Made by Jos Balcaen" align:#right
		
		on btnBrowseFile pressed do
		(
			theDialog = dotNetObject "System.Windows.Forms.OpenFileDialog" --create a OpenFileDialog 
			theDialog.title = "PLEASE Select One Or More Files" --set the title
			theDialog.Multiselect = true --allow multiple files to be selected
			theDialog.Filter = "MAX Files (*.max)|*.max"--|"All Files (*.*)|*.*" --specify the filter
			theDialog.FilterIndex = 1 --set the filter drop-down list to All Files
			result = theDialog.showDialog() --display the dialog, get result into variable
			result.ToString() --when closed, convert the result to string
			--result.Equals result.OK --returns TRUE if OK was pressed, FALSE otherwise
			result.Equals result.Cancel --returns TRUE if Cancel was pressed, FALSE otherwise
			if result.Equals result.OK == true do
			(
				files =  theDialog.fileNames --the selected filenames will be returned as an array
				for file in files do
				(
					appendIfUnique ListOfMaxFiles file
				)
				mlbMaxFiles.items = ListOfMaxFiles
				number_of_files = mlbMaxFiles.items.count
				lbNumberOfFiles.text = "All files"
			)

		)

		on btnBrowseFolder pressed do
		(
			folder = getSavePath "Save to:" initialDir:"" as string
			files = getFiles(folder + "\*.max") -- get max files in folder
			for file in files do
			(
				appendIfUnique ListOfMaxFiles file
			)
			mlbMaxFiles.items = ListOfMaxFiles
			number_of_files = mlbMaxFiles.items.count
			lbNumberOfFiles.text = "All files"
		)
				
		on mlbMaxFiles selected arg do
		(
			numberselected = 0
			bitArr = mlbMaxFiles.selection
			for i = 1 to bitArr.count do (if bitArr[i] == true do numberselected+=1)
			lbNumberOfFiles.text = numberselected as string + " files selected"
		)
		
		on mlbMaxFiles doubleClicked index do
		(
			itemArr = mlbMaxFiles.items
			ListOfMaxFiles = deleteItem itemArr index
			mlbMaxFiles.items = ListOfMaxFiles
		)

		on btnRemoveAll pressed do
		(
			ListOfMaxFiles = #()
			mlbMaxFiles.items = ListOfMaxFiles
		)

		on btnRemoveSelected pressed do
		(
			itemArr = mlbMaxFiles.items
			sel = mlbMaxFiles.selection
			print sel
			itemsToDel = #()
			for i in sel do 
			(
				append itemsToDel itemArr[i]
			)
			print itemsToDel
			
			for toDel in itemsToDel do
			(
				check = findItem itemArr toDel
				if check != 0 do (deleteItem itemArr check)
			)
			ListOfMaxFiles =  itemArr
			mlbMaxFiles.items = ListOfMaxFiles
			mlbMaxFiles.selection = #()
			lbNumberOfFiles.text = "selected files deleted"
		)

		fn regularRenderFn = 
		(
			--max file is geladen
			--file instellen waar nodig
			sFrame = ""
			sCamera = ""
			sFramerange = ""
			sFromframe = ""
			sToframe = ""
			sOutputwidth = ""
			sOutputHeight = ""
			sOutputfile = ""
			sVfb = ""
			
			if roll_GlobalSettings.chbTimeOutput.checked == true then
			(
				case roll_GlobalSettings.rdbTimeOutput.state of
				(
					1:(sFrame = "frame:#current ") -- single frame
					2:(sFramerange = "framerange:#active ") -- active time segment
					3:(sFromframe = "fromframe:" + roll_GlobalSettings.spnFrom.value as string + " " -- user specified range
					sToframe = "toframe:" + roll_GlobalSettings.spnTo.value as string + " ")
				)
				
			)
			else -- get timeoutput from file
			(
				case rendTimeType of
				(
					1:(sFrame = "frame:#current ")
					2:(sFramerange = "framerange:#active ")
					3:(sFromframe = "fromframe:" + rendStart as string + " "; sToframe = "toframe:" + rendEnd as string + " ")
				)
			)
			
			if roll_GlobalSettings.chbOutputSize.checked == true then
			(
				sOutputwidth = "outputwidth:" + roll_GlobalSettings.spnWidth.value as string + " "
				sOutputHeight = "outputheight:" + roll_GlobalSettings.spnHeight.value as string + " "
			)
			else -- get width and height from file 
			(
				sOutputwidth = "outputwidth:" + renderWidth as string +" "
				sOutputHeight = "outputheight:" + renderHeight as string + " "
			)
				
			if roll_GlobalSettings.chbSave.checked == true then
			(
				outputpath = roll_GlobalSettings.edtSavePath.text +"\\"
				filetype = roll_GlobalSettings.ddlFileType.items[roll_GlobalSettings.ddlFileType.selection]
				maxfolder = ""
				if roll_GlobalSettings.chbFolder.checked == true do ( maxfolder = (getFilenameFile maxFileName) as string +"\\")
				prefix = ""
				if roll_GlobalSettings.chbPrefix.checked do ( prefix = (getFilenameFile maxFileName) as string)
				filename = roll_GlobalSettings.edtFileName.text
				makeDir (outputpath + maxfolder)
				sOutputfile = "outputfile:\"" + outputpath + maxfolder + prefix + filename + filetype + "\" "
				tokens = filterString sOutputfile "\\"
				sOutputfile = ""
				for i = 1 to tokens.count do
				(
					if i != 1 then (sOutputfile += "\\\\" + tokens[i])
					else (sOutputfile += tokens[i])
					
				)
			)
			else -- geen save overwrites, dus we halen deze op van de file zelf
			(
				if rendSaveFile do (sOutputfile =  "outputfile:\"" + rendOutputFilename+ "\" ")
			)
			
			--other params
			sVfb = "vfb:" + "false "
			sRender = "render " + sFrame + sCamera + sFramerange + sFromframe + sToframe + sOutputwidth + sOutputHeight + sOutputfile + sVfb
			print sRender
			execute sRender
		)
		
		fn batchCamRenderFn = 
		(
			try (closeRolloutFloater batchCameraRender_floater) catch ()
			macros.run "Sergo Pogosyan" "BatchCameraRender"
			batchCameraRender_mainRollOut.quietRender()
		)

		fn RenderLoop renderFn =
		(
			prgProgressFiles.value = 0
			
			if mlbMaxFiles.items.count > 0 do
			(
				bitArr = #()
				print numberSelected
				if numberselected > 0 do
				(
					bitArr = mlbMaxFiles.selection
					returnval = queryBox "Render selected files only? If you press No all files will be rendered." title:"MFRender"
					if returnval == false then bitArr = #()
				)
				
				starttime = timeStamp()
				for i = 1 to (mlbMaxFiles.items.count) do
				(
					if bitArr[i] == true or numberselected < 1 do
					(
						if numberselected > 0 then (prgProgressFiles.value += (100/numberselected))
						else (prgProgressFiles.value += (100/mlbMaxFiles.items.count))
							
						--maxfile openen
						loadMaxFile (mlbMaxFiles.items[i] as string) quiet:true
						renderFn()
					)
				)
				endtime = timeStamp()
				tijdsinterval = ((endtime - starttime) / 1000.0)
				tijdinuur = ((endtime - starttime) / 1000.0)/3600
				prgProgressFiles.value = 100
				
				--check what to do is render is complete
				case roll_settings.rdbAfterRender.state of
				(
					2: DOSCommand "shutdown -s" --shutdown computer
					3: DOSCommand "shutdown -l" --logoff
					4: quitMax #noPrompt  --quit max 
					default: messagebox("succeeded, het renderen duurde \n" +  tijdsinterval as string + " seconden \n" + tijdinuur as string+ " uur")
				)
			)
		)

		on btnRender2 pressed do
		(
			RenderLoop BatchCamRenderFn
		)

		on btnRender pressed do
		(
			RenderLoop regularRenderFn
		)
	)

	rollout roll_GlobalSettings "Global Overwrite Settings"
	(
		checkbox chbTimeOutput "Time Output"
		radiobuttons rdbTimeOutput labels:#("Single", "Active Time Segment","Range") columns:1 enabled:false align:#left offset:[150,-20]
		spinner spnFrom "From: " across:2 enabled:false width:60 range:[0,10000,0] type:#integer offset:[100,-15]
		spinner spnTo "To: " enabled:false width:60 range:[0,10000,1] type:#integer offset:[-50,-15]
		checkbox chbOutputSize "OutputSize" across:3 offset:[0,5]
		spinner spnWidth "width :" range:[1,100000,1024] type:#integer enabled:false offset:[-80,5]
		spinner spnHeight "height :" range:[1,100000,768] type:#integer enabled:false offset:[-100,5]
		checkbox chbSave "Save" across:4 offset:[-0,5]
		button btnGetSavePath "Get folder" enabled:false offset:[-17,5]
		dropdownlist ddlFileType items:#(".jpg",".png",".tga",".bmp") width:50 enabled:false offset:[-47,5]
		edittext edtSavePath text:"folder" enabled:false offset:[-130,5] width:270
		checkbox chbFolder "\maxfilename\\" checked:true  enabled:false across:3 offset:[150,0]
		checkbox chbPrefix "maxfilename" checked:true  enabled:false offset:[70,0]
		edittext edtFileName text:"_name"  enabled:false offset:[0,0]

		on chbTimeOutput changed arg do (rdbTimeOutput.enabled = arg; rdbTimeOutput.state = 1;rdbTimeOutput.changed 1)
		on rdbTimeOutput changed arg do
		(
			spnFrom.enabled = spnTo.enabled = false
			case arg of
			(
				3: (spnFrom.enabled = true; spnTo.enabled = true)
			)
		)

		on chbOutputSize changed arg do
		(
			spnWidth.enabled = arg
			spnHeight.enabled = arg
		)

		on chbSave changed arg do
		(
			btnGetSavePath.enabled = ddlFileType.enabled = edtSavePath.enabled = chbFolder.enabled = chbPrefix.enabled = edtFileName.enabled = arg
		)

		on btnGetSavePath pressed do
		(
			savePath = getSavePath caption:"Select Folder"-- ] [ initialDir:<pathname> ] 
			edtSavePath.text = savePath
		)
	)

	rollout roll_settings "Other Settings"
	(
		radiobuttons rdbAfterRender "What after rendering :" labels:#("Nothing","Shut Down","Log Out","Quit Max") columns:1 align:#left
	)

	rollout roll_info "Info"
	(
		label lblInfo "How to use" width:600 align:#left
		label lblInfo2 "\t- Select files by selecting multiple files or a folder" width:600 align:#left
		label lblInfo3 "\t- All rendersettings will be taken from the maxfile unless you overwrite one or more settings." width:600 align:#left
		label lblInfo4 "\t- You can overwrite settings if you want in the 'Global Overwrite Settings' section." height:60 width:600 align:#left
		label lblInfo10 "feel free to contact me at contact@josbalcaen.com" align:#right
	)
	
	mf_render_rollout = newRolloutFloater "Render Multiple Max Files with BatchCam support" 600 450 lockWidth:true autoLayoutOnResize:true
	addRollout myRoll mf_render_rollout autoLayoutOnResize:true rolledUp:false
	addRollout roll_GlobalSettings mf_render_rollout autoLayoutOnResize:true rolledUp:false
	addRollout roll_info mf_render_rollout autoLayoutOnResize:true rolledUp:false
	addRollout roll_settings mf_render_rollout autoLayoutOnResize:true rolledUp:false
)