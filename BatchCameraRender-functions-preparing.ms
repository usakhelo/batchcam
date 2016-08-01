--########################--
--FUNCTIONS for batch camera render script
--Functions to prepare scene for the rendering, 
--to get properties from camera objects and set 
--them to render dialog 
--########################--
struct BatchCam_RenderParameterStore
(
	old_rendUseActiveView,
	viewport_type,
	old_camera,
	oldrendType,
	oldrendStart,
	oldrendEnd,
	oldrendPickupFrames,
	oldrendNThFrame,
	oldrenderWidth,
	oldrenderHeight,
	oldfilename,
	oldsavestate,
	numOfElements,
	oldElementsFullPaths,
	oldElementsState,
	oldoutput_saveRawFile,
	oldoutput_rawFileName,
	oldoutput_on,
	oldoutput_splitgbuffer,
	oldoutput_splitfilename,
	oldoutput_splitbitmap,
	oldoutput_getsetsfrommax,
	oldoutput_width,
	oldoutput_height,
	old_vray_ortho_mode,
	old_adv_irradmap_mode,
	old_adv_irradmap_loadFileName,
	old_adv_irradmap_autoSaveFileName,
	old_adv_irradmap_autoSave,
	old_adv_irradmap_switchToSavedMap,
	old_lightcache_mode,
	old_lightcache_loadFileName,
	old_lightcache_autoSave,
	old_lightcache_autoSaveFileName,
	old_lightcache_switchToSavedMap,
	oldrenderUseNet,
	oldRenderType
)

fn storeRenderParams buffer=
(
	buffer.old_rendUseActiveView = rendUseActiveView
	buffer.viewport_type = viewport.getType()
	if buffer.viewport_type == #view_camera then
		buffer.old_camera = viewport.getCamera()
	buffer.oldrendType = rendTimeType
	buffer.oldrendStart = rendStart
	buffer.oldrendEnd = rendEnd
	buffer.oldrendPickupFrames = rendPickupFrames
	buffer.oldrendNThFrame = rendNThFrame
	buffer.oldrenderWidth = renderWidth
	buffer.oldrenderHeight = renderHeight
	buffer.oldfilename = rendOutputFilename
	buffer.oldsavestate = rendSaveFile
	buffer.oldrenderUseNet = rendUseNet 
	buffer.oldRenderType = getRenderType()

	elementMgr = maxOps.GetCurRenderElementMgr()
	buffer.numOfElements = elementMgr.NumRenderElements()
	buffer.oldElementsFullPaths = #()
	for index=0 to (buffer.numOfElements-1) do
	(
		tempPath = elementMgr.getrenderelementfilename index
		if tempPath != undefined then
			append buffer.oldElementsFullPaths tempPath
		else
			append buffer.oldElementsFullPaths ""
	)
	buffer.oldElementsState = elementMgr.GetElementsActive()
	
	--store V-ray image properties
	buffer.oldoutput_saveRawFile = false
	buffer.oldoutput_rawFileName = ""
	buffer.oldoutput_on = false
	buffer.oldoutput_splitgbuffer = false
	buffer.oldoutput_splitfilename = ""
	buffer.oldoutput_splitbitmap = ""				
	buffer.oldoutput_getsetsfrommax = false
	buffer.oldoutput_width = 0
	buffer.oldoutput_height = 0
	
	buffer.old_vray_ortho_mode = undefined
	buffer.old_adv_irradmap_mode = undefined
	buffer.old_adv_irradmap_loadFileName	= ""
	buffer.old_adv_irradmap_autoSaveFileName = ""
	buffer.old_adv_irradmap_autoSave = false
	buffer.old_adv_irradmap_switchToSavedMap = false
	
	buffer.old_lightcache_mode = undefined
	buffer.old_lightcache_loadFileName = ""
	buffer.old_lightcache_autoSave = ""
	buffer.old_lightcache_autoSaveFileName = false
	buffer.old_lightcache_switchToSavedMap = false
	
	if isVrayRenderer() then
	(
		vr = renderers.current
		
		if (hasproperty vr "V_Ray_settings") then
			vr = vr.V_Ray_settings

		buffer.oldoutput_saveRawFile = vr.output_saveRawFile
		buffer.oldoutput_rawFileName = vr.output_rawFileName
		buffer.oldoutput_on = vr.output_on
		
		buffer.oldoutput_splitgbuffer = vr.output_splitgbuffer
		buffer.oldoutput_splitfilename = vr.output_splitfilename
		
		buffer.oldoutput_getsetsfrommax = vr.output_getsetsfrommax
		buffer.oldoutput_width = vr.output_width
		buffer.oldoutput_height = vr.output_height
		
		buffer.old_vray_ortho_mode = vr.camera_type
		
		buffer.old_adv_irradmap_mode = vr.adv_irradmap_mode
		buffer.old_adv_irradmap_loadFileName	= vr.adv_irradmap_loadFileName
		buffer.old_adv_irradmap_autoSaveFileName = vr.adv_irradmap_autoSaveFileName 
		buffer.old_adv_irradmap_autoSave = vr.adv_irradmap_autoSave 
		buffer.old_adv_irradmap_switchToSavedMap = vr.adv_irradmap_switchToSavedMap 
		
		buffer.old_lightcache_mode = vr.lightcache_mode
		buffer.old_lightcache_loadFileName = vr.lightcache_loadFileName
		buffer.old_lightcache_autoSave = vr.lightcache_autoSave
		buffer.old_lightcache_autoSaveFileName = vr.lightcache_autoSaveFileName
		buffer.old_lightcache_switchToSavedMap = vr.lightcache_switchToSavedMap
	)
	buffer
)

fn restoreRenderParams buffer=
(
		rendUseActiveView = buffer.old_rendUseActiveView
		rendTimeType = buffer.oldrendType 
		rendStart = buffer.oldrendStart
		rendEnd = buffer.oldrendEnd
		rendPickupFrames = buffer.oldrendPickupFrames
		rendNThFrame = buffer.oldrendNThFrame
		renderWidth = buffer.oldrenderWidth
		renderHeight = buffer.oldrenderHeight
		rendOutputFilename = buffer.oldfilename
		rendSaveFile = buffer.oldsavestate
		elementMgr = maxOps.GetCurRenderElementMgr()
		for index=0 to (buffer.numOfElements-1) do
			elementMgr.setRenderElementFilename index buffer.oldElementsFullPaths[index+1]
		elementMgr.SetElementsActive buffer.oldElementsState
		
		--vray options
		if isVrayRenderer() then
		(
			vr = renderers.current

			if (hasproperty vr "V_Ray_settings") then
				vr = vr.V_Ray_settings

			vr.output_saveRawFile = buffer.oldoutput_saveRawFile
			if buffer.oldoutput_rawFileName != undefined then vr.output_rawFileName = buffer.oldoutput_rawFileName
			vr.output_on = buffer.oldoutput_on
			
			vr.output_splitgbuffer = buffer.oldoutput_splitgbuffer
			if buffer.oldoutput_splitfilename != undefined then vr.output_splitfilename = buffer.oldoutput_splitfilename
			
			vr.output_getsetsfrommax = buffer.oldoutput_getsetsfrommax
			vr.output_width = buffer.oldoutput_width
			vr.output_height = buffer.oldoutput_height
			
			vr.camera_type = buffer.old_vray_ortho_mode
			
			vr.adv_irradmap_mode = buffer.old_adv_irradmap_mode
			if buffer.old_adv_irradmap_loadFileName != undefined then vr.adv_irradmap_loadFileName = buffer.old_adv_irradmap_loadFileName
			if buffer.old_adv_irradmap_autoSaveFileName != undefined then vr.adv_irradmap_autoSaveFileName = buffer.old_adv_irradmap_autoSaveFileName
			vr.adv_irradmap_autoSave = buffer.old_adv_irradmap_autoSave
			vr.adv_irradmap_switchToSavedMap = buffer.old_adv_irradmap_switchToSavedMap
			
			vr.lightcache_mode = buffer.old_lightcache_mode
			if buffer.old_lightcache_loadFileName != undefined then vr.lightcache_loadFileName = buffer.old_lightcache_loadFileName
			if buffer.old_lightcache_autoSaveFileName != undefined then vr.lightcache_autoSaveFileName = buffer.old_lightcache_autoSaveFileName
			vr.lightcache_autoSave = buffer.old_lightcache_autoSave
			vr.lightcache_switchToSavedMap = buffer.old_lightcache_switchToSavedMap
		)
		rendUseNet = buffer.oldrenderUseNet
		setRenderType (buffer.oldRenderType)

		--restore viewport type and camera if not silent submit mode
		if (not batchCamPreview) and ((batchCameraRender_mainRollOut.show_net_submit.enabled and batchCameraRender_mainRollOut.show_net_submit.checked) or (not batchCameraRender_mainRollOut.net_render.checked)) then
		(
			if buffer.viewport_type == #view_camera then
				viewport.setCamera buffer.old_camera
			else
				viewport.setType buffer.viewport_type
		)
)

fn prepare_render_elements camera_to_render=
(
	temp_string = getUserProperty camera_to_render "BatchCameraRender_elements_state"
	elementsFullPath = undefined
	if (isNotUndefined temp_string) then
	(
		elementMgr = maxOps.GetCurRenderElementMgr()
		if shouldBeSaved() and (temp_string as booleanClass) then
		(
			elementMgr.SetElementsActive true

			numOfElements = elementMgr.NumRenderElements()
			if numOfElements != 0 then
			(
				for index=0 to (numOfElements-1) do
				(
					--get element's path
					element = elementMgr.getrenderelement index				
					--extract element name
					elementNameParts = filterString (element as string) ":"
					elementType = elementNameParts[2] as string
					elementName = element.elementName
-- 					elementName = elementNameParts[2] as string
					syntaxExtraItems = #(#("elementtype", (elementType as string)), #("elementname", (elementName as string)))
					
					--make new file path
					mainOutput = rendOutputFilename
					mainPath = getFilenamePath mainOutput
					mainFileNameOnly = getFilenameFile mainOutput
					mainFileType = getFilenameType mainOutput
					-- mainFileType = ".tga"
					
					newPath = getUserProperty camera_to_render "BatchCameraRender_elements_output"
					if (isNotUndefined newPath) then
					(
						newPath = parse_file_name_template newPath (compose_full_parsing_dictionary camera_to_render extraItems:syntaxExtraItems)
					)
					else
					(
						newPath = mainPath	--Use elements path same as main output if elements path is empty. May be warning message will be useful here.
					)
					
					elementNamePattern = Net_Render_Options_Rollout.renderElementNamePattern.text
-- 					append syntaxExtraItems #("mainoutput", (mainFileNameOnly as string))
					if (isNotUndefinedOrEmpty elementNamePattern) then
					(
						elementsFileName = parse_file_name_template elementNamePattern (compose_full_parsing_dictionary camera_to_render extraItems:syntaxExtraItems)
					)
					else
						elementsFileName = mainFileNameOnly + "_" +  elementType + "_" + elementName
					
					elementsFileName += mainFileType
					
					if (isPathAbsolute newPath) then
					(
						--use absolute path + existing or composed file name
						elementsFullPath = pathConfig.appendPath newPath elementsFileName
					)
					else
					(
						--if subfolder then add subfolder to main path
						elementsNewPath = pathConfig.appendPath mainPath newPath	--path is main + elements subfolder
						elementsFullPath = pathConfig.appendPath elementsNewPath elementsFileName
					)
					
					--check if the path (without filename) exist
					temp_path = getFilenamePath elementsFullPath
					if (not (doesFileExist temp_path)) then
					(
						--if silent_mode is on try to create new path
						if  Net_Render_Options_Rollout.silent_add_path_mode.checked then
						(
							if not makeDir temp_path all:true then
								throw ("Failed to create path: "+ temp_path) --if path making fails throw exception
						)
						else
						(
							throw ("Path does not exist: "+ temp_path) --if path making fails throw exception
						)
					)
					--set new path to element
					elementMgr.setRenderElementFilename index elementsFullPath
				)
			)
		)
		else
		(
			elementMgr.SetElementsActive false
		)
	)
	elementsFullPath
)

fn checkAndAppendMainPath path_string = 
(
			
	mainOutput = rendOutputFilename
	mainPath = getFilenamePath mainOutput
-- 	mainFileNameOnly = getFilenameFile mainOutput
	
	fullPath = ""
	
	if (isPathAbsolute path_string) then
		fullPath = path_string
	else
		--if subfolder then add subfolder to main path
		fullPath = pathConfig.appendPath mainPath path_string	--path is main + elements subfolder
	
	return fullPath
)

--V-ray settings
fn prepare_vray_settings camera_to_render main_output_file elementsPath =
(
	if isVrayRenderer() then
	(
		vr = renderers.current

		if (hasproperty vr "V_Ray_settings") then
			vr = vr.V_Ray_settings

		--set vray output
		if  (Vray_Settings_Rollout.show_vray_vfb.checked) then
		(
			vr.output_on = true
			--output_saveRawFile flag should be checked only if output file is given
			if shouldBeSaved() and isNotUndefined main_output_file then
			(
				if isNotUndefinedOrEmpty elementsPath then
					elementsPath = getFilenamePath elementsPath
				else
					elementsPath = getFilenamePath main_output_file

				vr.output_saveRawFile = Vray_Settings_Rollout.save_vray_image_file.checked
			
				file_extension = Vray_Settings_Rollout.vray_extension_list.items[Vray_Settings_Rollout.vray_extension_list.selection]
				vrayRawFullPath = elementsPath + (getFilenameFile main_output_file) + ("_vray_") + file_extension 
				vr.output_rawFileName = vrayRawFullPath
				
				vrayOutputFullPath = elementsPath + (getFilenameFile main_output_file) + ("_vrayoutput_") + (getFilenameType main_output_file)
				if (Vray_Settings_Rollout.save_separate_render_channels.checked) or (Vray_Settings_Rollout.save_vray_output.checked) then
				(
					vr.output_splitgbuffer = true
					vr.output_splitfilename = vrayOutputFullPath
					-- hack, to make vray save elements from vfb
					--Thank you, Track! :)
					try
					(
						local split_bitmap=Bitmap 10 10 fileName: vrayOutputFullPath
						save split_bitmap
						close split_bitmap
						vr.output_splitbitmap=split_bitmap
						
						deleteFile vrayOutputFullPath
					)
					catch
					(
						messagebox (getCurrentException()) title:"Error Setting Vray Output"
					)
					
					if (Vray_Settings_Rollout.save_vray_output.checked) then
					(
						vr.output_splitRGB = true
						vr.output_splitAlpha = true
					)
					else
					(
						vr.output_splitRGB = false
						vr.output_splitAlpha = false
					)
				)
				else
				(
					vr.output_splitgbuffer = false
					vr.output_splitRGB = false
					vr.output_splitAlpha = false
				)
				--set vray frame buffer resolution based on multiplier - only in case output_saveRawFile is checked
				if Vray_Settings_Rollout.vray_image_multiplier.value != 1.0 then
				(
					vr.output_getsetsfrommax = false
					vr.output_width =  renderWidth * Vray_Settings_Rollout.vray_image_multiplier.value
					vr.output_height = renderHeight * Vray_Settings_Rollout.vray_image_multiplier.value
				)
				else
				(
					vr.output_getsetsfrommax = true
				)
			)
			else
			(
				vr.output_saveRawFile = false
				vr.output_rawFileName = ""
				vr.output_splitgbuffer = false
				vr.output_splitRGB = false
				vr.output_splitAlpha = false
			)
		)
		else
		(
			--if show_vray_vfb is not checked then uncheck output_on flag
			vr.output_on = false
		)

		vr.system_distributedRender = (Vray_Settings_Rollout.distr_rendering.checked)
		
		--set misc. settings
		temp_string = getUserProperty camera_to_render "BatchCameraRender_vray_ortho_mode"
		if (isNotUndefined temp_string) then
		(
			if (temp_value = temp_string as BooleanClass) != undefined then
			(
				if temp_value then
					vr.camera_type = 7
				else
					vr.camera_type = 0
			)
		)
		
		--set vray global illumination options
		temp_string = getUserProperty camera_to_render "BatchCameraRender_irmap_mode"
		if (isNotUndefined temp_string) then
		(
			if (temp_value = temp_string as integer) != undefined then
			(
				vr.adv_irradmap_mode = temp_value - 1
			)
		)
		temp_string = getUserProperty camera_to_render "BatchCameraRender_irmap_read_file"
		if isNotUndefined temp_string then
		(
			temp_string = parse_file_name_template temp_string (compose_full_parsing_dictionary camera_to_render.name)
			fullPath = checkAndAppendMainPath temp_string			
			
			vr.adv_irradmap_loadFileName = fullPath
		)
		temp_string = getUserProperty camera_to_render "BatchCameraRender_irmap_save_file"
		if isNotUndefined temp_string then
		(
			--this option should be checked for path existance
			--if path doesn't exist try to create it
			temp_string = parse_file_name_template temp_string (compose_full_parsing_dictionary camera_to_render.name)
			fullPath = checkAndAppendMainPath temp_string
			temp_path = getFilenamePath fullPath
			--check if the path exist
			if ((not (doesFileExist temp_path)) and shouldBeSaved()) then
			(
				--if silent_mode is on try to create new path
				if  Net_Render_Options_Rollout.silent_add_path_mode.checked then
				(
					if not makeDir temp_path all:true then
						throw ("Failed to create path: "+ temp_path) --if path making fails throw exception
				)
				else
				(
					throw ("Path does not exist: "+ temp_path) --if path making fails throw exception
				)
			)
			vr.adv_irradmap_autoSaveFileName = fullPath
		)
		temp_string = getUserProperty camera_to_render "BatchCameraRender_auto_save_irmap"
		if (isNotUndefined temp_string) and shouldBeSaved() then
		(
			if (temp_value = temp_string as BooleanClass) != undefined then 
				vr.adv_irradmap_autoSave = temp_value
		)
		temp_string = getUserProperty camera_to_render "BatchCameraRender_auto_switch_irmap"
		if (isNotUndefined temp_string) then
		(
			if (temp_value = temp_string as BooleanClass) != undefined then 
				vr.adv_irradmap_switchToSavedMap = temp_value
		)
		
		--lightcache settings
		temp_string = getUserProperty camera_to_render "BatchCameraRender_lcmap_mode"
		if (isNotUndefined temp_string) then
		(
			if (temp_value = temp_string as integer) != undefined then
			(
				vr.lightcache_mode = temp_value - 1
			)
		)
		temp_string = getUserProperty camera_to_render "BatchCameraRender_lcmap_read_file"
		if (isNotUndefined temp_string) then
		(
			temp_string = parse_file_name_template temp_string (compose_full_parsing_dictionary camera_to_render.name)
			fullPath = checkAndAppendMainPath temp_string
			vr.lightcache_loadFileName = fullPath
		)
		temp_string = getUserProperty camera_to_render "BatchCameraRender_lcmap_save_file"
		if (isNotUndefined temp_string) and shouldBeSaved() then
		(
			--this option should be checked for path existance
			--if path doesn't exist try to create it
			temp_string = parse_file_name_template temp_string (compose_full_parsing_dictionary camera_to_render.name)
			fullPath = checkAndAppendMainPath temp_string
			temp_path = getFilenamePath fullPath
			--check if the path exist
			if ((not (doesFileExist temp_path)) and (Render_Output_Rollout.save_file.checked)) then
			(
				--if silent_mode is on try to create new path
				if  Net_Render_Options_Rollout.silent_add_path_mode.checked then
				(
					if not makeDir temp_path all:true then
						throw ("Failed to create path: "+ temp_path) --if path making fails throw exception
				)
				else
				(
					throw ("Path does not exist: "+ temp_path) --if path making fails throw exception
				)
			)
			vr.lightcache_autoSaveFileName = fullPath
		)
		temp_string = getUserProperty camera_to_render "BatchCameraRender_auto_save_lcmap"
		if (isNotUndefined temp_string) and shouldBeSaved() then
		(
			if (temp_value = temp_string as BooleanClass) != undefined then 
				vr.lightcache_autoSave = temp_value
		)
		temp_string = getUserProperty camera_to_render "BatchCameraRender_auto_switch_lcmap"
		if (isNotUndefined temp_string) then
		(
			if (temp_value = temp_string as BooleanClass) != undefined then 
				vr.lightcache_switchToSavedMap = temp_value									
		)
	)
)