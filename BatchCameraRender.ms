macroScript BatchCameraRender
	category:"Sergo Pogosyan"
	toolTip:""
	buttonText:"BatchCam"
/*
Batch Camera Render, maxscript tool for batch rendering in 3ds max
Copyright (C) 2010-2011, Sergo Pogosyan

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

*/

------------------------------------------------------------------------------
-- BatchCameraRender.ms
-- By Sergo Pogosyan (www.sergepogosyan.com, contact@sergepogosyan.com)
-- Created On: 2009-05-25
-- tested using Max 2009, Max 2010, Max 2011, Max 2012
-------------------------------------------------------------------------------
-- Description:
-- macroscript aims to replace builtin batch render
-------------------------------------------------------------------------------
-- Installing and usage:
-- When you start this script it iterates over all cameras in scene and list them in the dialog box. 
-- To each of these cameras you can assign frame resolution, number of frames to render including 
-- nonsequential frames, output file location and lighting setup. All these properties can be changed 
-- for one or several selected cameras. Output file location is split to folder path and file name, 
-- so you can specify new folder for all selected cameras in scene. 'Lighting assignement' section contains 
-- three list: Solo light list contains lights that will be only lights turned on during the rendering, 'Forced On' 
-- and 'Forced Off' lights are turned on or off respectively during the rendering. After all these settings are setted 
-- up check the camera(s) in the list and hit Render button. Check Net Render checkbox to submit network render job.
-------------------------------------------------------------------------------

(
--########################--
--GLOBAL VARS--
--########################--
--lights
LIGHT_LIST
--lighting state array structure: #( #(light_name, on/off), #(light_name, on/off), #(light_name, on/off) ... )
LIGHTING_STATE = #()
--render size presets
RESOLUTIONS = #([640,480],[768,576],[900,600],[1200,800],[1200,960],[1500,1000],[1920,1080],[2400,1200],[2400,1920])
--main rollout
local isDialogOpen = false		--variable to save main window open/close state
global batchCameraRender_mainRollOut
WindowHook --native window object to handle local render cancellation
RenderCancelled = false
Output_Size_Rollout
Render_Output_Rollout
Frame_Range_Rollout
Scene_States_Rollout
Light_Assignement_Rollout
Net_Render_Options_Rollout
Vray_Settings_Rollout
Scripts_Rollout
global batchCameraRender_floater
global batchCameraRender_RenderCounter
global batchCameraRender_reload_cameras
global batchCameraRender_reset_render_counter
global batchCameraRender_getUserProperty
global batchCameraRender_populateScripts
global batchCameraRender_currentcamera
PostNotifier
PostNotifierInstalled = false
batchCamPreview = false	--if the rendering is preview
global_found_ini_file_paths = #()
global_listview_height = 170
--listView items array
LV_ITEMS = #()
--default vray image file saving state
SAVE_VRAY_IMAGE_FILE_STATE = false
--script version
VERSION_STRING = "1.9.21"

BatchCam_CommonPropertiesNames = #("frames", "framerange_from", "framerange_to", "anim_frame_range", "frame_width", "frame_heigth", "render_output", \
													"elements_state", "elements_output", "solo_lights", "on_lights", "off_lights", "scene_state", "render_preset", "image_aspect", \
													"region_enabled", "region_x", "region_y", "region_w", "region_h" )
BatchCam_ScriptsPropertiesNames = #("OnSubmitScriptEnable", "OnSubmitScript", "perCameraScriptEnable", "perCameraScript", "prerender_script", "prerender_enabled", "postrender_script", "postrender_enabled")
BatchCam_UserValuePropertiesNames = #("UserKey1", "UserKey2", "UserKey3", "UserVal1", "UserVal2", "UserVal3", "bbJobName", "elementName")
--########################--
--vray global vars
--########################--
struct BatchCam_VrayPropertiesMapping (propertyName, propertyUIelement, propertyType)

BatchCam_VrayPropertiesNames = #("irmap_mode", "auto_save_irmap", "auto_switch_irmap", "irmap_read_file", "irmap_save_file", \
	"lcmap_mode", "auto_save_lcmap", "auto_switch_lcmap", "lcmap_read_file", "lcmap_save_file", "vray_ortho_mode" )

BatchCam_VrayPropertiesMappingArray = #()
	
BatchCam_Vray_irmap_modes = #("Single Frame", "Multiframe incremental", "From file", "Add to current map", "Incremental add to current map", "Bucket mode",\ 
	"Animation (prepass)", "Animation (rendering)")
	
BatchCam_Vray_lcmap_modes = #("Single Frame", "Fly-through", "From file", "Progressive path tracing")
	
--########################--
--Session-wide persistent variables
--########################--
global BatchCamRenderParamsBuffer
global BatchCam_rollout_state; if BatchCam_rollout_state == undefined then BatchCam_rollout_state = #(	true, false, \
																																					true , true, true, \
																																					false, false, false, \
																																					false, false
																																					)
																																					
global BatchCam_rollout_names; if BatchCam_rollout_names == undefined then BatchCam_rollout_names = #(	"batchCameraRender_mainRollOut", "Net_Render_Options_Rollout", \
																																						"Output_Size_Rollout" , "Frame_Range_Rollout", "Render_Output_Rollout", \
																																						"Vray_Settings_Rollout", "Scene_States_Rollout", "Scripts_Rollout", "Light_Assignement_Rollout", \
																																						"aboutRoll"
																																					)
global BatchCam_listItem_state
--########################--
--end of session-wide persistent variables
--########################--

include @"C:\GitHub\batchcam\BatchCameraRender-functions-misc.ms"
include @"C:\GitHub\batchcam\BatchCameraRender-functions-populating.ms"
include @"C:\GitHub\batchcam\BatchCameraRender-functions-setters.ms"
include @"C:\GitHub\batchcam\BatchCameraRender-functions-preparing.ms"
--########################--
--ROLLOUT--
--########################--

	rollout batchCameraRender_mainRollOut "Camera Manager Settings"
	(
		button refresh "Refresh" align:#left width:65 across:3
		button copy_button "Copy" align:#right offset:[85,0] width:65
		button paste_button "Paste" align:#right width:65
		dotNetControl lv_objects "ListView" height:global_listview_height	--height:170
		
		button toggle_select_all "[Un]Select All" align:#left width:75 across:5
		button toggle_check_all "[Un]Check All" align:#left width:75 offset: [-12,0]
		button check_selected "Check Selected" align:#left width:85 offset: [-24,0]
		button set_viewport "Set Viewport" align:#right width:70 offset: [12,0]
		button get_viewport "Get Viewport" align:#right width:75 offset: [0,0]
		
		button render_start "Render" align:#left width:75 offset: [0,0] across:5
		button preview_start "Preview" align:#left width:75 offset: [-12,0]
		checkbox net_render "Net Render" align:#left offset: [-15,4]
		checkbox show_net_submit "Show Submit Dialog" align:#left offset: [-20,4]
		button select_camera "Select Camera" align:#right width:75 offset: [0,0]		
	
		--#####--
		--list button event handlers--
		--#####--
		on batchCameraRender_mainRollOut resized height do saveVar2IniFile "Main_RollOut" "dialog_height" height[2]
		
		on refresh pressed do
		(
			BatchCameraRender_reload_cameras lv_objects
		)
		
		on copy_button pressed do
		(
			if BatchCamRenderParamsBuffer == undefined then
				BatchCamRenderParamsBuffer = BatchCameraRenderParamsStruct()
			
			if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
			(
				selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
				camera_obj = getNodeByName (selected_item.text)
				
				if camera_obj != undefined then
				(
					propertyNames = getPropNames BatchCamRenderParamsBuffer
					for propertyName in propertyNames do
					(
						prop_value = getUserPropertyFromObject camera_obj (propertyName as string)
						setProperty BatchCamRenderParamsBuffer propertyName prop_value
					)
					ui_elements_refresh lv_objects
				)
			)
		)
		
		on paste_button pressed do
		(
			if BatchCamRenderParamsBuffer != undefined then
			(
				if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count > 0) then
				(
					for i=1 to batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count do
					(
						selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item (i-1))
						camera_obj = getNodeByName (selected_item.text)
						
						if camera_obj != undefined then
						(
							propertyNames = getPropNames BatchCamRenderParamsBuffer
							for propertyName in propertyNames do
							(
								prop_value = getProperty BatchCamRenderParamsBuffer propertyName
								setUserProperty camera_obj (propertyName as string) prop_value
							)
						)
					)
					BatchCameraRender_reload_cameras lv_objects
				)
			)
		)
		
		on net_render changed state do
		(
			saveVar2IniFile "Main_RollOut" "net_render_state" state
			show_net_submit.enabled = state	--enable show_net_submit checkbox
			
			ui_elements_refresh lv_objects	--refresh ui
		)
		
		on show_net_submit changed state do
		(
			saveVar2IniFile "Main_RollOut" "show_submit_dialog_state" state
			ui_elements_refresh lv_objects
		)
		
		on toggle_select_all pressed do
    (
      local listItems = for i=0 to (lv_objects.Items.Count - 1) collect (lv_objects.Items.Item i)
      local is_some_selected = (lv_objects.SelectedItems.Count > 0)
     
      if is_some_selected then
        lv_objects.SelectedItems.Clear()
      else
      (             
        lv_objects.BeginUpdate()                                                           
        for i in listItems do
          i.selected = true
        lv_objects.EndUpdate()
      )
     
      lv_objects.HideSelection = false
      local selectedItems = for i=0 to (lv_objects.SelectedItems.Count - 1) collect (lv_objects.SelectedItems.Item i)
      populate_ui_elements selectedItems
      ui_elements_refresh lv_objects
    )

    on toggle_check_all pressed do
		(
		  local listItems = for i=0 to (lv_objects.Items.Count - 1) collect (lv_objects.Items.Item i)
		  is_some_checked = false
		  for i in listItems do
		  (
		    if i.checked then is_some_checked = true
		  )
		 
		  if is_some_checked then
		  (
		    for i in listItems do
		      i.checked = false
		  )
		  else
		  (                                                             
		    for i in listItems do
		      i.checked = true
		  )
		  ui_elements_refresh lv_objects
		)

		on check_selected pressed do
		(
			for i in LV_ITEMS do
			(
				if i.selected then 
					i.checked = true
				else
					i.checked = false
			)
-- 			populate_ui_elements #(LV_ITEMS[index])
			ui_elements_refresh lv_objects
		)
		
		on select_camera pressed do
		(
			camera_selection_names = for obj in LV_ITEMS where obj.selected collect obj.text		--get camera names from selected items in list
			camera_selection = for obj in get_camera_list() where ((findItem camera_selection_names obj.name) != 0) collect obj	--collect camera objects with names is in previous array
			
			select camera_selection
		)
		
		--function to set selected camera to active viewport
		on set_viewport pressed do
		(
			camera_name = ""
			--extract selected item - there should be only one
			for item in LV_ITEMS do
			(
				if item.selected then
					camera_name = item.text
			)
			camera_obj = getNodeByName camera_name
			if (findString ((classof camera_obj) as string) "camera")  != undefined then	--set viewport camera
				viewport.setCamera camera_obj

			local xres_prop = getUserProperty camera_obj "BatchCameraRender_frame_width"
			local yres_prop = getUserProperty camera_obj "BatchCameraRender_frame_heigth"
			if (isNotUndefined xres_prop) and (isNotUndefined yres_prop) then
			(
				if renderSceneDialog.isOpen() then
						renderSceneDialog.close()

				renderWidth = xres_prop as integer
				renderHeight = yres_prop as integer
			)
		)
		
		--function to select active viewport camera in script's list
		on get_viewport pressed do
		(
		  if viewport.getType() == #view_camera then
		  (
		    local camera_obj = viewport.getCamera()
		    local camera_name = camera_obj.name

		    local listItem = undefined
		    local listItems = lv_objects.Items.GetEnumerator()
		    while listItems.MoveNext() do
		    (
		      if (listItems.Current.text == camera_name) then
		      (
		        listItem = listItems.Current
		        listItem.selected = true
		        listItem.EnsureVisible()
		      )
		      else
		      (
		        listItems.Current.selected = false
		      )
		    )
		   
		    if (listItem != undfined) then
		      populate_ui_elements #(listItem)

		    ui_elements_refresh lv_objects
		  )
		)

		fn onWmCommand ev args =
		(
		  -- format "ev:%\n" (ev)
		  -- local query_approved = queryBox "Cancel all jobs?\n\n" title:"Warning: Cancel pressed"
		  -- if query_approved then
		  -- (
	  		RenderCancelled = true
			  dotnet.removeAllEventHandlers WindowHook
		  -- )
		)

		fn DMNotification =
		(
		  local win_handle = DialogMonitorOPS.GetWindowHandle()
		  if (win_handle != 0) then
		  (
			  local win_text = (UIAccessor.GetWindowText win_handle)
			  local win_class = (UIAccessor.GetWindowClassName win_handle)
			  if (matchPattern win_text pattern:"Rendering*" ignoreCase:false) then
			  (
	      	WindowHook.ReleaseHandle()
			    WindowHook.AssignHandle (dotnetobject "IntPtr" win_handle)
			  	dotnet.removeAllEventHandlers WindowHook
			    dotnet.addEventHandler WindowHook "WmCommand" onWmCommand
		    )
	    )
		  true
		)

		fn do_render preview allCameras=
		(
			local temp_string
			local temp_string1
			local temp_string2
			local temp_string3
			local temp_string5
			
		--store parameter
			renderParamBuf = BatchCam_RenderParameterStore()
			renderParamBuf = storeRenderParams renderParamBuf
				
			rendUseActiveView = true
			
			--refill light_list in case some lights were removed or added during script running state
			LIGHT_LIST = collect_scene_lights()
			--save lights state
			store_lighting_state()
			
			--render preset saving
			INIFileDir = ((getdir #plugcfg) + "\\BatchCameraRender\\")
			if (getDirectories INIFileDir).count == 0 then makeDir INIFileDir
			tempRP_file = INIFileDir + "temp_render_preset.rps"
			renderpresets.SaveAll 0 tempRP_file
			
			renderPresetsApplied = false
			lightStateApplied = false
			
			--if not netrender then set cancellation detection handler here
			if (not net_render.checked) do
			(
				RenderCancelled = false
				DialogMonitorOPS.unRegisterNotification id:#get_render_win
				DialogMonitorOPS.RegisterNotification DMNotification id:#get_render_win
				DialogMonitorOPS.Enabled = true
			)
			--	THIS SECTION SHOULD BE UNDER TRY-CATCH BLOCK
			try
			(
				local firstCamera = true
				for i in LV_ITEMS while not RenderCancelled do
				(
					if allCameras or i.checked then
					(
						if isVrayRenderer() and (hasproperty (renderers.current) "V_Ray_settings") then
						(
							-- actionMan.executeAction 369690881 "1"
							if not firstCamera then
								sleep 4
							firstCamera = false
						)
						--get camera name
						camera_name = i.text
						camera_to_render = getNodeByName camera_name
						--unhide camera objects
						if (camera_to_render.isHiddenInVpt) then
						(
							camera_to_render.isHidden = false
							hideByCategory.cameras = false
						)
						-- set the render preset
						temp_string = getUserProperty camera_to_render "BatchCameraRender_render_preset"
						if isNotUndefined temp_string then
						(
							setSilentMode true --set silent to prevent dialogs with gamma warning
							presetsArray = #()
							if (maxVersion())[1] >= 11000 then	--run renderPresetMRUList command only if script is running under 3dsmax 2009+
								presetsArray = renderPresetMRUList
							presetsNames = for preset in presetsArray collect preset[1]
							presetIndex = finditem presetsNames temp_string
							if presetIndex != 0 then
							(
								presetFile = presetsArray[presetIndex][2]
								renderpresets.LoadAll 0 presetFile
								renderPresetsApplied = true
							)

							setSilentMode false
						)
						
						if not preview then
						(
							--set frame range
							temp_string1 = getUserProperty camera_to_render "BatchCameraRender_frames"
							temp_string2 = getUserProperty camera_to_render "BatchCameraRender_framerange_from"
							temp_string3 = getUserProperty camera_to_render "BatchCameraRender_framerange_to"
							temp_string5 = getUserProperty camera_to_render "BatchCameraRender_anim_frame_range"

							if isNotUndefined temp_string5 then
							(
								rendTimeType = 3
								temp_frame_range = get_key_range camera_to_render
								rendStart = temp_frame_range[1].frame
								rendEnd = temp_frame_range[2].frame
							)
							else if isNotUndefined temp_string1 then
							(	--render_frames
								rendTimeType = 4
								rendPickupFrames = temp_string1 as string
							)
							else if isNotUndefined temp_string2 then
							(
								--single frame
								--frame range
								rendTimeType = 3
								rendStart = temp_string2 as integer
								rendEnd = temp_string3 as integer
							)
						)
						else
						rendTimeType = 1
						
						rendNThFrame = Frame_Range_Rollout.render_every_nth.value as integer
						
						if not preview then
						(
							--get and set frame resolution
							xres_prop = getUserProperty camera_to_render "BatchCameraRender_frame_width"
							yres_prop = getUserProperty camera_to_render "BatchCameraRender_frame_heigth"
							if  (isNotUndefined xres_prop) and (isNotUndefined yres_prop) then
							(
								renderWidth = xres_prop as integer
								renderHeight = yres_prop as integer
							)
						)
						else
						(
							local xres_prop = 0
							local yres_prop = 0
							if (temp_width = loadVarFromIniFile "Output_Size_Rollout" "preview_width") != undefined then
								xres_prop = (temp_width as integer)
							else
								xres_prop = 1000

							image_aspect = getUserProperty camera_to_render "BatchCameraRender_image_aspect"
							if (isNotUndefined image_aspect) then
								yres_prop = xres_prop / (image_aspect as float)
							else
								yres_prop = xres_prop / 1.333
							
							renderWidth = xres_prop as integer
							renderHeight = yres_prop as integer
						)
						
						--set render region
						local use_region = getUserProperty camera_to_render "BatchCameraRender_region_enabled"
						if (isNotUndefined use_region) and (use_region as BooleanClass) then
						(
							setRenderType #region
							local reg_x = getUserProperty camera_to_render "BatchCameraRender_region_x"
							local reg_y = getUserProperty camera_to_render "BatchCameraRender_region_y"
							local reg_w = getUserProperty camera_to_render "BatchCameraRender_region_w"
							local reg_h = getUserProperty camera_to_render "BatchCameraRender_region_h"
							if (isNotUndefined reg_x) and (isNotUndefined reg_y) and\
							(isNotUndefined reg_w) and (isNotUndefined reg_h)	then
							(
								local x = (renderWidth / 100.0) * (reg_x as integer)
								local y = (renderHeight / 100.0) * (reg_y as integer)
								local w = ((renderWidth / 100.0) * (reg_w as integer)) + x
								local h = ((renderHeight / 100.0) * (reg_h as integer)) + y
								viewport.setRegionRect (viewport.activeViewport) (box2 x y w h)
							)
						)

						--get and set file name
						temp_string = getUserProperty camera_to_render "BatchCameraRender_render_output"
						if (shouldBeSaved()) and (isNotUndefined temp_string) then
						(
							temp_string = parse_file_name_template temp_string (compose_parsing_dictionary camera_name)
							temp_path = getFilenamePath temp_string
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
							rendSaveFile = Render_Output_Rollout.save_file.checked
							rendOutputFilename = temp_string
						)
						else
							rendSaveFile = false

						local elementsPath = prepare_render_elements camera_to_render
						
						prepare_vray_settings camera_to_render temp_string elementsPath
						
						--get lightstate
						temp_string1 = getUserProperty camera_to_render "BatchCameraRender_solo_lights"
						temp_string2 = getUserProperty camera_to_render "BatchCameraRender_on_lights"
						temp_string3 = getUserProperty camera_to_render "BatchCameraRender_off_lights"
						if isNotUndefined temp_string1 then
						(
							temparray = filterString temp_string1 ","
							turn_solo_lights_on temparray
							lightStateApplied = true
						)
						else --if solo lights are listed then don't process other light setting
						(
							if isNotUndefined temp_string3 then --turn off exclude lights first, then turn on include lights
							(
								temparray = filterString temp_string3 ","
								force_lights_off temparray
								lightStateApplied = true
							)
							if isNotUndefined temp_string2 then	--turn on include lights.
							(
								temparray = filterString temp_string2 ","
								force_lights_on temparray
								lightStateApplied = true
							)
						)
						
						--set scene state
						temp_string = getUserProperty camera_to_render "BatchCameraRender_scene_state"
						if isNotUndefined temp_string then
						(
							temp_string = parse_file_name_template temp_string (compose_parsing_dictionary camera_name)
							sceneStateMgr.RestoreAllParts temp_string
						)
						
						--scripts setting
						callbacks.removeScripts id:#BatchCameraRender
						--set global variables to be visible in submit and render scripts
						batchCameraRender_currentcamera = camera_to_render
-- 							batchCameraRender_currentsettings = #()
-- 							for i=7801 to 7844 do
-- 								append batchCameraRender_currentsettings
						
						temp_string = getUserProperty camera_to_render "BatchCameraRender_prerender_enabled"
						if (not preview) and (isNotUndefined temp_string) then
						(
							if (temp_string as BooleanClass) then
							(
								temp_string = getUserProperty camera_to_render "BatchCameraRender_prerender_script"
								callbacks.addScript #preRender fileName:temp_string id:#BatchCameraRender persistent:true
							)
						)

						temp_string = getUserProperty camera_to_render "BatchCameraRender_postrender_enabled"
						if (not preview) and (isNotUndefined temp_string) then
						(
							if (temp_string as BooleanClass) then
							(
								temp_string = getUserProperty camera_to_render "BatchCameraRender_postrender_script"
								callbacks.addScript #postRender fileName:temp_string id:#BatchCameraRender persistent:true
							)
						)
						
						--per camera submit scripts section
						if  (not preview) and (Scripts_Rollout.enable_percamera_submit.state) then
						(
							try
							(
								maxscript_file_name = Scripts_Rollout.percamera_submit_script.text
								if isNotUndefinedOrEmpty maxscript_file_name then
								(
									if (doesFileExist maxscript_file_name) then
										filein maxscript_file_name
								)
							)
							catch
							(
								messagebox (getCurrentException()) title:"Submit Script Error"
							)
						)
						
						--save render location to last render property
						if (not preview) then
							setUserProperty camera_to_render "BatchCameraRender_lastRenderPath" rendOutputFilename
						--start render
						if (not preview) and net_render.checked and (not show_net_submit.checked) then
						(
							net_render_auto_submit camera_name
						)
						else
						(
							if (not preview)  then
								rendUseNet = net_render.checked
							else
								rendUseNet = false
							
							viewport.setCamera camera_to_render
							max quick render
						)
						
						--remove callbacks after render started
						callbacks.removeScripts id:#BatchCameraRender
						--restore saved render_preset if render presets was applied during the rendering
						if renderPresetsApplied then
						(
							INIFileDir = ((getdir #plugcfg) + "\\BatchCameraRender\\")
							tempRP_file = INIFileDir + "temp_render_preset.rps"
							if doesFileExist tempRP_file then
								renderpresets.LoadAll 0 tempRP_file
						)
						restoreRenderParams renderParamBuf
						--restore lights state
						--light state have to be restored after each camera iteration if it was applied in the loop
						if lightStateApplied then
							restore_lighting_state()
					) -- if close
				) -- end of for loop
				DialogMonitorOPS.unRegisterNotification id:#get_render_win
				DialogMonitorOPS.Enabled = false
			) -- end of try close
			catch
			(
				messagebox (getCurrentException()) title:"Error"
				restore_lighting_state()
			)
		)

		fn quietRender =
		(
			SetQuietMode true

			batchCamPreview = false
			if renderSceneDialog.isOpen() then
				renderSceneDialog.close()	
		
			--increment render try counter to be used in keyword syntax
			Net_Render_Options_Rollout.Try_Counter.value += 1
			batchCameraRender_RenderCounter = Net_Render_Options_Rollout.Try_Counter.value
			renderSceneDialog.close()
			
			batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects
			if (Scripts_Rollout.enable_onsubmit.state) then
			(
				maxscript_file_name = Scripts_Rollout.onsubmit_script.text
				if isNotUndefinedOrEmpty maxscript_file_name then
				(
					if (doesFileExist maxscript_file_name) then
						filein maxscript_file_name
				)
			)
			do_render false true
			SetQuietMode false
		)
		--#####--
		--render button event hadler--
		--#####--
		on render_start pressed do
		(
			batchCamPreview = false
			query_approved = true
			if renderSceneDialog.isOpen() then
				renderSceneDialog.close()	
			
			--check the render type and suggest to switch to view mode
			if (not GetQuietMode()) and query_approved and getRenderType() != #view and getRenderType() != #normal then
			(
				local message_text = "Render Type set to \"" + (getRenderType() as string) + "\".\n\nWould you like to switch to View mode?"
				local message_buttons = (dotnetclass "MessageBoxButtons").YesNoCancel
				local message_icon = (dotnetclass "MessageBoxIcon").Question
				result = (dotnetclass "MessageBox").show message_text "Caution" message_buttons message_icon
				if (result == ((dotnetclass "DialogResult").Yes)) then
					setRenderType #view
				else if (result == ((dotnetclass "DialogResult").No)) then
					query_approved = true
				else 
					query_approved = false
			)
			
			if (not GetQuietMode()) and query_approved and net_render.checked and (not (Render_Output_Rollout.save_file.checked or Vray_Settings_Rollout.save_vray_image_file.checked)) then
				query_approved = queryBox  "You are about to submit network rendering with no assigned file.\n\nDo you want to continue?" title:"Warning:No files saved"
								
			if query_approved then
			(
				--increment render try counter to be used in keyword syntax
				Net_Render_Options_Rollout.Try_Counter.value += 1
				batchCameraRender_RenderCounter = Net_Render_Options_Rollout.Try_Counter.value
				renderSceneDialog.close()
				
				batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects
				--on submit section - runs once per each render submit
				--runs only if at least one job is checked it listview - currently on_render_start get called only if something is checked in listview
				if shouldBeSaved() and (Scripts_Rollout.enable_onsubmit.state) then
				(
-- 					try
					(
						maxscript_file_name = Scripts_Rollout.onsubmit_script.text
						if isNotUndefinedOrEmpty maxscript_file_name then
						(
							if (doesFileExist maxscript_file_name) then
								filein maxscript_file_name
						)
					)
-- 					catch
-- 					(
-- 						messagebox (getCurrentException()) title:"Submit Script Error"
-- 					)
				)
				
				do_render false false

			)
			else
			(
				--cancellation
			)
		)
		
		on preview_start pressed do
		(
			batchCamPreview = true
			renderSceneDialog.close()
			
			batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects

			do_render true false
		)
		
		--############
		--ON OPEN event handler
		--initialization
		--############
		
		on batchCameraRender_mainRollOut open do
		( 
			init_ListView lv_objects (get_camera_list())
				
			--this array contains listview items for convinience
			LV_ITEMS = for i=0 to (lv_objects.Items.Count - 1) collect (lv_objects.Items.Item i)
				
			--init ui elements with session persistent variables
			--net render checkbox
			if (temp_state = loadVarFromIniFile "Main_RollOut" "net_render_state") != undefined then
				net_render.checked = (temp_state as booleanClass)
			else
			(
				net_render.checked = false
				saveVar2IniFile "Main_RollOut" "net_render_state" false
			)
			
			if (temp_state = loadVarFromIniFile "Main_RollOut" "show_submit_dialog_state") != undefined then
				show_net_submit.checked = (temp_state as booleanClass)
			else
			(
				show_net_submit.checked = false
				saveVar2IniFile "Main_RollOut" "show_submit_dialog_state" false
			)

			--refresh ui elements
			ui_elements_refresh lv_objects
			
			--add onopen callback
			callbacks.addScript #filePostOpen "batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects" id:#batchcam
--			callbacks.addScript #filePostOpen "batchCameraRender_reset_render_counter()" id:#batchcam
			callbacks.addScript #filePostMerge "batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects" id:#batchcam
			callbacks.addScript #systemPostNew "batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects" id:#batchcam
			callbacks.addScript #systemPostNew "batchCameraRender_reset_render_counter()" id:#batchcam
			callbacks.addScript #systemPostReset "batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects" id:#batchcam
			callbacks.addScript #systemPostReset "batchCameraRender_reset_render_counter()" id:#batchcam

			  
			if (dotnetclass "WindowHook" == undefined) then
				CreateNativeWindowOps()         --create dotnet object in memory
			if (WindowHook == undefined) then
			(
				WindowHook = dotnetobject "WindowHook"
				-- format "windowhook ready:%\n" WindowHook
			)
			else
			(
      	WindowHook.ReleaseHandle()
		  	dotnet.removeAllEventHandlers WindowHook
	  	)

	  	if (dotnetclass "PostNotifier" == undefined) then
				CreatePostNotifier()
			if (PostNotifier == undefined) then
			(
				PostNotifier = dotnetobject "PostNotifier"
				-- format "PostNotifier ready:%\n" PostNotifier
			)
			else
			(
		  	dotnet.removeAllEventHandlers PostNotifier
	  	)
		)

		on batchCameraRender_mainRollOut close do 
		(
			--store checked state of the items to array
			for i=1 to lv_objects.Items.count do
			(
				BatchCam_listItem_state[i] = lv_objects.Items.Item[i-1].checked
			)
			--set flag to show that main window is closed
			isDialogOpen = false
			updateToolbarButtons()
			--remove all script callbacks
			callbacks.removeScripts id:#batchcam
			if (WindowHook != undefined) then
      (
      	WindowHook.ReleaseHandle()
		  	dotnet.removeAllEventHandlers WindowHook
	  	)
	  	if (PostNotifier != undefined) then
			(
		  	dotnet.removeAllEventHandlers PostNotifier
	  	)
			DialogMonitorOPS.unRegisterNotification id:#get_render_win
			DialogMonitorOPS.Enabled = false
		)
		
		on batchCameraRender_mainRollOut moved pos do
		(
			if (batchCameraRender_mainRollOut.placement != #minimized) and (batchCameraRender_mainRollOut.placement != #maximized) then
			(
				saveVar2IniFile "Main_RollOut" "dialog_height_x" pos[1]
				saveVar2IniFile "Main_RollOut" "dialog_height_y" pos[2]
			)
		)
		--##########--
		--select item event handler - DOTNET VERSION--
		--##########--
		fn ItemsSelected event args=
		(
			selectedItems = #()
			for i=0 to (lv_objects.SelectedItems.Count - 1) do
				append selectedItems (lv_objects.SelectedItems.Item i)
			
			LV_ITEMS = selectedItems

			local t = timeStamp()
			-- print (t)
			populate_ui_elements selectedItems
			-- print (timeStamp() - t)
			-- t = timeStamp()
			ui_elements_refresh lv_objects
			-- print (timeStamp() - t)
		  PostNotifierInstalled = false
		)

		on lv_objects ItemSelectionChanged val  do
		(
			if (not PostNotifierInstalled) do
			(
				-- print (timeStamp())
				dotnet.removeAllEventHandlers PostNotifier
		    dotnet.addEventHandler PostNotifier "PostEvent" ItemsSelected
		    PostNotifier.PostNotify()
		    PostNotifierInstalled = true
			)
		)

		--check event handler
		--used to save items' checked state
		on lv_objects ItemCheck val do
		(
			BatchCam_listItem_state[(val.Index+1)] = (val.NewValue == (dotNetClass "CheckState").Checked )
		)

		on lv_objects ItemChecked val do
		(
			--todo: save checked state to the camera appdata
			ui_elements_refresh lv_objects	
		)
		
		on lv_objects ItemDrag sender args do
		(
			lv_objects.DoDragDrop args.Item (dotnetclass "DragDropEffects").Move
		)
		
		on lv_objects DragEnter sender args do
		(
			args.Effect = args.AllowedEffect
		)

		on lv_objects DragOver sender args do
		(
			local targetPoint = lv_objects.PointToClient (dotnetobject "system.drawing.Point" args.X args.Y)
			local targetIndex = lv_objects.InsertionMark.NearestIndex targetPoint
			if (targetIndex > -1) then
			(
				local itemBounds = lv_objects.GetItemRect targetIndex
				if ( targetPoint.Y > (itemBounds.Top + (itemBounds.Height / 2)) ) then
					lv_objects.InsertionMark.AppearsAfterItem = true
				else
					lv_objects.InsertionMark.AppearsAfterItem = false
			)
			lv_objects.InsertionMark.Index = targetIndex
		)
		
		on lv_objects DragLeave sender args do
		(
			lv_objects.InsertionMark.Index = -1
		)
		
		on lv_objects DragDrop sender args do
		(
			local targetIndex = lv_objects.InsertionMark.Index

		if (targetIndex != -1) then
			(
				if (lv_objects.InsertionMark.AppearsAfterItem) then
					targetIndex += 1

				local draggedItem = args.Data.GetData (dotNet.getType "System.Windows.Forms.ListViewItem")

				local newItem = draggedItem.Clone()
				for i=0 to (newItem.SubItems.Count-1) do ((newItem.SubItems.Item i).Name = (draggedItem.SubItems.Item i).Name)

				lv_objects.Items.Insert targetIndex (newItem)

				lv_objects.Items.Remove draggedItem
				
				for i = 0 to lv_objects.Items.Count-1 do
				(
					local listItem = lv_objects.Items.Item i
					local obj_name = listItem.text
					local obj_itself = getNodeByName obj_name
					setUserProperty obj_itself ("BatchCameraRender_item_index") (listItem.index as string)
				)
				LV_ITEMS = for i=0 to (lv_objects.Items.Count - 1) collect (lv_objects.Items.Item i)
			)
		)

		on batchCameraRender_mainRollOut rolledUp state do
		(
			-- find rollout index in main windows's rollouts
			index = findItem BatchCam_rollout_names batchCameraRender_mainRollOut.name
			-- set rollout state to the apropriate array element
			BatchCam_rollout_state[index] = state
		)
	)
	
	rollout Net_Render_Options_Rollout "Options"
	(		
		group "System"
		(
			button open_ini_file "Open Global INI file..." width:125 align:#left across:2
			button save_all_as_default "Save All Settings as Global Defaults" width:195 align:#left offset:[-100,0]
			
			button open_local_ini_file "Open Local INI file..." width:125 align:#left
			dropdownlist found_local_ini_files "Found local INI files: " align:#left-- offset:[-20,2]
			
			edittext command_line "Open Folder Command Line:" align:#left offset: [0,2]
			checkbox silent_add_path_mode "Create New Paths Silently" align:#left offset: [0,12] \
			tooltip:"If checked new path will be created automaticaly during rendering.\nIf not checked and path doesn't exist exception will be thrown"
			
			spinner listview_height "Listview Height: " range:[50,1000,0] type:#integer width:90 align:#left across:3
			spinner preview_width "Preview Width: " range:[1,10000,0] type:#integer width:90 align:#left
			spinner preview_width1 "Preview Width: " range:[1,10000,0] type:#integer width:90 align:#left visible:false	--simple filler
		)
		
		on open_ini_file pressed do
		(
			INIFileDir = ((getdir #plugcfg) + "\\BatchCameraRender\\")
			-- try to load rollout parameters from ini file
			INIFilename = pathConfig.appendPath INIFileDir "BatchCameraRender.ini"
				
			if (doesFileExist INIFilename) then
				temp_res = ShellLaunch INIFilename ""
			else
				messagebox ("File does not exist: "+ INIFilename) title:"Error"
		)		
		
		on open_local_ini_file pressed do
		(
			INIFilename = found_local_ini_files.selected
			-- try to load rollout parameters from ini file
			if (isNotUndefined INIFilename) then
			(
				if (doesFileExist INIFilename) then
					temp_res = ShellLaunch INIFilename ""
				else
					messagebox ("File does not exist: "+ INIFilename) title:"Error"
			)
		)
		
		--save to global defaults
		on save_all_as_default pressed do
		(
			if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
			(
				selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
				obj_itself = getNodeByName (selected_item.text)
				
				property_names = BatchCam_CommonPropertiesNames + BatchCam_ScriptsPropertiesNames + BatchCam_VrayPropertiesNames

				for property_name in property_names do
				(
					full_property_name = ("BatchCameraRender_" + property_name)
					property_value = getUserProperty obj_itself full_property_name
					saveVar2IniFile "Default Settings" full_property_name (property_value as string)
				)
				
				--save user keywords and bb job and renderelement name
				property_value = Net_Render_Options_Rollout.UserKey1.text
				saveVar2IniFile "Default Settings" "BatchCameraRender_UserKey1" (property_value as string)
				property_value = Net_Render_Options_Rollout.UserKey2.text
				saveVar2IniFile "Default Settings" "BatchCameraRender_UserKey2" (property_value as string)
				property_value = Net_Render_Options_Rollout.UserKey3.text
				saveVar2IniFile "Default Settings" "BatchCameraRender_UserKey3" (property_value as string)
				property_value = Net_Render_Options_Rollout.UserVal1.text
				saveVar2IniFile "Default Settings" "BatchCameraRender_UserVal1" (property_value as string)
				property_value = Net_Render_Options_Rollout.UserVal2.text
				saveVar2IniFile "Default Settings" "BatchCameraRender_UserVal2" (property_value as string)
				property_value = Net_Render_Options_Rollout.UserVal3.text
				saveVar2IniFile "Default Settings" "BatchCameraRender_UserVal3" (property_value as string)
				property_value = Net_Render_Options_Rollout.backburnerJobNamePattern.text
				saveVar2IniFile "Default Settings" "BatchCameraRender_bbJobName" (property_value as string)
				property_value = Net_Render_Options_Rollout.renderElementNamePattern.text
				saveVar2IniFile "Default Settings" "BatchCameraRender_elementName" (property_value as string)
				
				
				property_names = #(	\
										"BatchCameraRender_OnSubmitScriptEnable", \
										"BatchCameraRender_OnSubmitScript", \
										"BatchCameraRender_perCameraScriptEnable", \
										"BatchCameraRender_perCameraScript", \
										"BatchCameraRender_prerender_script", \
										"BatchCameraRender_prerender_enabled", \
										"BatchCameraRender_postrender_script", \
										"BatchCameraRender_postrender_enabled" \
										)

				for property_name in property_names do
				(
					property_value = getUserProperty rootnode property_name
					saveVar2IniFile "Default Settings" property_name (property_value as string)
				)
			)
		)
		
		on command_line entered val do
		(
			saveVar2IniFile "Render_Output_Rollout" "command_line" (val as string)
		)
		
		--save silent mode state
		on silent_add_path_mode changed state do
			saveVar2IniFile "Render_Output_Rollout" "silent_add_path_mode" state
		
		on listview_height changed val do
			saveVar2IniFile "Main_RollOut" "listview_height" val

		on preview_width changed val do
			saveVar2IniFile "Output_Size_Rollout" "preview_width" val
		
		group "Net Render Connection Options"
		(
			checkbox Auto_Search "Automatic Search" align:#left offset: [0,0]
			edittext Name_Or_Mask "Manager Name or IP Address:" labelOnTop:true align:#left fieldWidth:120 offset: [0,0] across:4
			edittext Port "Port:" labelOnTop:true align:#left fieldWidth:60 offset: [20,0] tooltip:""
			label label1 "Submit Job As:" align:#right offset: [0,20]
			radiobuttons Platform labels:#("32-bit ", "64-bit ") align:#right offset: [0,20]
		)

		on Auto_Search changed state do
		(
			saveVar2IniFile "Net_Render_Options_Rollout" "netrender_option_autosearch" state
			if state then
			(
				Name_Or_Mask.caption = "Subnet Mask:"
				Name_Or_Mask.text = ((loadVarFromIniFile "Net_Render_Options_Rollout" "netrender_option_mask") as string)
			)
			else
			(
				Name_Or_Mask.caption = "Manager Name or IP Address:"
				Name_Or_Mask.text = ((loadVarFromIniFile "Net_Render_Options_Rollout" "netrender_option_server") as string)
			)
			--show that the option was changed.
		)

		on Name_Or_Mask entered text_val do
		(
			if auto_search.state then
				saveVar2IniFile "Net_Render_Options_Rollout" "netrender_option_mask" text_val
			else
				saveVar2IniFile "Net_Render_Options_Rollout" "netrender_option_server" text_val
		)
		
		on Port entered text_val do
		(
			saveVar2IniFile "Net_Render_Options_Rollout" "netrender_option_port" text_val
		)
		
		--handle job type changing
		on Platform changed val do
		(
			saveVar2IniFile "Net_Render_Options_Rollout" "netrender_option_platform" val
		)
		
		group "Custom Keywords and Names"
		(
			spinner Try_Counter "Render Try Counter (%trynum%): " range:[0,100000,0] type:#integer width:120 align:#left offset: [0,0] across:3
			button save_as_default2  "Save to INI..." width:90  align:#right offset: [80,0]
			button help_button  "Help" width:65  align:#right
			edittext UserKey1 "Name: " align:#left fieldWidth:100 offset: [0,0] across:2
			edittext UserVal1 "Value: " align:#left fieldWidth:273 offset: [-80,0]			
			edittext UserKey2 "Name: " align:#left fieldWidth:100 offset: [0,0] across:2
			edittext UserVal2 "Value: " align:#left fieldWidth:273 offset: [-80,0]
			edittext UserKey3 "Name: " align:#left fieldWidth:100 offset: [0,0] across:2
			edittext UserVal3 "Value: " align:#left fieldWidth:273 offset: [-80,0]
			edittext backburnerJobNamePattern "Backburner Job Name: " align:#left offset: [0,10]
			edittext renderElementNamePattern "Render Element Filename: " align:#left offset: [0,0]	
		)
		
		on Try_Counter changed val do
		(
			batchCameraRender_RenderCounter = val
			batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects
		)
		
		--save custom keywords and name patterns
		on save_as_default2 pressed do		
		(			
			property_names = #(	"BatchCameraRender_UserKey1", \
											"BatchCameraRender_UserKey2", \
											"BatchCameraRender_UserKey3", \
											"BatchCameraRender_UserVal1", \
											"BatchCameraRender_UserVal2", \
											"BatchCameraRender_UserVal3", \
											"BatchCameraRender_bbJobName", \
											"BatchCameraRender_elementName" \
										)
											
			saveDefaultValues rootnode property_names
		)
		
		on help_button pressed do
		(
			info_string = "In this section you can specify custom keywords to be used in different naming fields.\n"
			info_string += "\"Name\" is a name of the keyword. In the \"Value\" field you can enter any Maxscript \n"
			info_string += "expression, variable name or numeric value - it will be executed via \"execute\" command \n"
			info_string += "on each rendered camera so be careful to not enter some destructive or \"max-hanging\" expression. Good luck :)\n\n"
			info_string += "\"Render Try Counter\" counts how much times the render button was pressed. You can add this counter to output filename to not overwrite older renderings. Enter %trynum% keyword to the any naming field in the script. It is reset on Open File and New File commands.\n\n"
			info_string += "By specifying Backburner Job Name and Element File Name template you can customize default names used in the script in older versions.\n\n"
			info_string += "Custom keywords and both name fields are saved with the scene file, so they stay the same if you open scene on other computer. They also can be saved to INI file to be used as default values across all the scenes on one machine.\n\n"
			messagebox info_string title:"Custom Keywords" beep:false
		)
		
		on UserKey1 entered text_val do
		(
			setRootNodeData "BatchCameraRender_UserKey1" text_val
			batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects
		)
		on UserKey2 entered text_val do
		(
			setRootNodeData "BatchCameraRender_UserKey2" text_val
			batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects
		)
		on UserKey3 entered text_val do
		(
			setRootNodeData "BatchCameraRender_UserKey3" text_val
			batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects
		)		
		on UserVal1 entered text_val do
		(
			setRootNodeData "BatchCameraRender_UserVal1" text_val
			batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects
		)
		on UserVal2 entered text_val do
		(
			setRootNodeData "BatchCameraRender_UserVal2" text_val
			batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects
		)
		on UserVal3 entered text_val do
		(
			setRootNodeData "BatchCameraRender_UserVal3" text_val
			batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects
		)
		
		on backburnerJobNamePattern entered text_val do
		(
			setRootNodeData "BatchCameraRender_bbJobName" text_val
		)

		on renderElementNamePattern entered text_val do
		(
			setRootNodeData "BatchCameraRender_elementName" text_val
		)
		
		on Net_Render_Options_Rollout open do
		(
			--save file state
			if (temp_state = loadVarFromIniFile "Render_Output_Rollout" "command_line")  != undefined then
				command_line.text= (temp_state as string)
			else
			(
				default_command_line = ""
				command_line.text = default_command_line
				saveVar2IniFile "Render_Output_Rollout" "command_line" default_command_line
			)
			
			--save silent mode flag
			if (temp_state = loadVarFromIniFile "Render_Output_Rollout" "silent_add_path_mode") != undefined then
				silent_add_path_mode.checked = (temp_state as booleanClass)
			else
			(
				silent_add_path_mode.checked = true
				saveVar2IniFile "Render_Output_Rollout" "silent_add_path_mode" true
			)
			
			--listview height
			if (temp_state = loadVarFromIniFile "Main_RollOut" "listview_height") != undefined then
			(
				listview_height.value = (temp_state as integer)
				global_listview_height = (temp_state as integer)
			)
			else
			(
				listview_height.value = global_listview_height
				saveVar2IniFile "Main_RollOut" "listview_height" global_listview_height
			)
						
			--preview width
			if (temp_state = loadVarFromIniFile "Output_Size_Rollout" "preview_width") != undefined then
			(
				preview_width.value = (temp_state as integer)
			)
			else
			(
				preview_width.value = 1000
				saveVar2IniFile "Output_Size_Rollout" "preview_width" 1000
			)
						
			--connection section
			if (temp_state = loadVarFromIniFile "Net_Render_Options_Rollout" "netrender_option_autosearch") != undefined then
				Auto_Search.checked = (temp_state as booleanClass)
			else
			(
				Auto_Search.checked = true
				saveVar2IniFile "Net_Render_Options_Rollout" "netrender_option_autosearch" true
			)
			
			if Auto_Search.state then
			(
				Name_Or_Mask.caption = "Subnet Mask:"
				if  (temp_state = loadVarFromIniFile "Net_Render_Options_Rollout" "netrender_option_mask") != undefined then
				(
					Name_Or_Mask.text = temp_state as string
				)
				else
				(
					Name_Or_Mask.text = "255.255.255.0"
					saveVar2IniFile "Net_Render_Options_Rollout" "netrender_option_mask" "255.255.255.0"
				)
			)
			else
			(
				Name_Or_Mask.caption = "Manager Name or IP Address:"
				if (temp_state = loadVarFromIniFile "Net_Render_Options_Rollout" "netrender_option_server")  != undefined then
				(
					Name_Or_Mask.text = temp_state as string
				)
				else
				(
					Name_Or_Mask.text = "192.168.0.1"
					saveVar2IniFile "Net_Render_Options_Rollout" "netrender_option_server" "192.168.0.1"
				)
			)
			
			--port section
			temp_state = loadVarFromIniFile "Net_Render_Options_Rollout" "netrender_option_port"
			if ((temp_state != undefined ) and ((temp_state == "default") or ((temp_state as integer) != undefined)) ) then
				Port.text = temp_state
			else
			(
				Port.text = "default"
				saveVar2IniFile "Net_Render_Options_Rollout" "netrender_option_port" "default"
			)
	
			--get 64-bit state
			is64bit = is64bitApplication() --check if app is running in 64-bit mode
			if (temp_state = loadVarFromIniFile "Net_Render_Options_Rollout" "netrender_option_platform") != undefined then
				Platform.state = (temp_state as integer)
			else 
			(
				temp_platform = if is64bit then 2 else 1
				Platform.state = temp_platform
				saveVar2IniFile "Net_Render_Options_Rollout" "netrender_option_platform" temp_platform
			)
			
			--init try counter from the global var
			if batchCameraRender_RenderCounter != undefined then
				Try_Counter.value = batchCameraRender_RenderCounter
			else
				Try_Counter.value = 0
			--user-defined keywords section
			if (temp_state = getRootNodeData "BatchCameraRender_UserKey1")  != undefined then
				UserKey1.text= (temp_state as string)			
			if (temp_state = getRootNodeData "BatchCameraRender_UserKey2")  != undefined then
				UserKey2.text= (temp_state as string)
			if (temp_state = getRootNodeData "BatchCameraRender_UserKey3")  != undefined then
				UserKey3.text= (temp_state as string)
			if (temp_state = getRootNodeData "BatchCameraRender_UserVal1")  != undefined then
				UserVal1.text= (temp_state as string)
			if (temp_state = getRootNodeData "BatchCameraRender_UserVal2")  != undefined then
				UserVal2.text= (temp_state as string)
			if (temp_state = getRootNodeData "BatchCameraRender_UserVal3")  != undefined then
				UserVal3.text= (temp_state as string)		
			
			--custom names
			if (temp_state = getRootNodeData "BatchCameraRender_bbJobName")  != undefined then
				backburnerJobNamePattern.text= (temp_state as string)
			if (temp_state = getRootNodeData "BatchCameraRender_elementName")  != undefined then
				renderElementNamePattern.text= (temp_state as string)
		)
		
		on Net_Render_Options_Rollout rolledUp state do
		(
			-- find rollout index in main windows's rollouts
			index = findItem BatchCam_rollout_names Net_Render_Options_Rollout.name
			-- set rollout state to the apropriate array element
			BatchCam_rollout_state[index] = state
		)
	)
	
	rollout Output_Size_Rollout "Output Size"
	(
		dropdownlist out_size_list width:200	across:3
		button clear_resolution "Clear" width:45  offset: [65,0] align:#right
		button save_as_default  "Save to INI..." width:85 align:#right
		
		label label1 "Width:" align:#left across:7
		spinner frame_width range:[1,100000,640] type:#integer align:#left width:60 offset: [-32,0]

		spinner image_aspect_spinner "Aspect:" range:[0,100000,1.333] type:#float width:90 offset: [-20,0]
		checkbutton lock_aspect "Lock" width:30 align:#left offset: [2,-3]
		
		checkbutton use_region "Region" align:#left width:40 offset:[10,-3]
		spinner region_x "X:" range:[0,100,0] type:#integer align:#left width:80 offset: [-10,0]
		spinner region_y "Y:" range:[0,100,0] type:#integer align:#left width:80 offset: [0,0]

		label label3 "Height:" align:#left across:10
		spinner frame_height range:[1,100000,480] type:#integer width:60 align:#left offset: [-13,0]
		button double_resolution "x2" width:30 align:#left offset: [5,-2]
		button half_resolution "1/2" width:30 align:#left offset: [-8,-2]
		button set_resolution_to_max "Set" width:30 align:#left offset: [-20,-2]
		button get_resolution_from_max "Get" width:30 align:#left offset: [-33,-2]

		button set_region_to_max "Set" width:30 align:#left offset: [-30,-2]
		button get_region_from_max "Get" width:30 align:#left offset: [-42,-2]

		spinner region_w "W:" range:[0,100,0] type:#integer align:#left width:92 offset: [-53, 0]
		spinner region_h "H:" range:[0,100,0] type:#integer align:#left width:85 offset: [-22,0]
		
		on Output_Size_Rollout open do
		(
			--resolution dropdownlist init
			temparray = #()
			for i in RESOLUTIONS do
			(
				append temparray ("" + (i[1] as integer) as string + " x " + (i[2] as integer) as string)
			)
			out_size_list.items  = temparray
			
			--save lock aspect checked state
			if (temp_state = loadVarFromIniFile "Output_Size_Rollout" "lock_aspect") != undefined then
				lock_aspect.checked = (temp_state as booleanClass) 
			else
			(
				lock_aspect.checked = false
				saveVar2IniFile "Output_Size_Rollout" "lock_aspect" false
			)
		)
		
		--##########--
		--set render size event handler--
		--##########--
		
		on save_as_default pressed do
		(
			if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
			(
				selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
				camera_object = getNodeByName (selected_item.text)
				
				property_names = #(	"BatchCameraRender_frame_width", \
												"BatchCameraRender_frame_heigth", \
												"BatchCameraRender_image_aspect" \
											)

				saveDefaultValues camera_object property_names
			)
		)
		
		on out_size_list selected item do
		(					
			--call method to add/update properties to selected camera object
			set_resolution LV_ITEMS RESOLUTIONS[item][1] RESOLUTIONS[item][2]
			populate_resolution_options LV_ITEMS
		)
		
		on frame_width changed val do
		(
			val = val as float
			set_resolution_width LV_ITEMS val 
			populate_resolution_options LV_ITEMS
		)
		
		on frame_height changed val do
		(
			val = val as float
			set_resolution_height LV_ITEMS val 
			populate_resolution_options LV_ITEMS
		)
		
		on lock_aspect changed state do 
		(
			image_aspect_spinner.enabled = (state != true)
			saveVar2IniFile "Output_Size_Rollout" "lock_aspect" state
			populate_resolution_options LV_ITEMS
		)

		on use_region changed state do 
		(
			set_checkbox_property_no_listview LV_ITEMS "region_enabled" state
			populate_resolution_options LV_ITEMS
		)
		
		on image_aspect_spinner changed val do
		(
			set_aspect_ratio LV_ITEMS val
			populate_resolution_options LV_ITEMS
		)
		
		on clear_resolution pressed do
		(
			for i in LV_ITEMS do
			(
				if i.selected then
				(
					obj_name = i.text
					obj_itself = getNodeByName obj_name
					setUserProperty obj_itself "BatchCameraRender_frame_width" undefined
					setUserProperty obj_itself "BatchCameraRender_frame_heigth" undefined
					setUserProperty obj_itself "BatchCameraRender_image_aspect" undefined
					clear_sub_item i "resolution"
					clear_sub_item i "image_aspect"
				)
			)
			populate_resolution_options LV_ITEMS
		)
		
		on double_resolution pressed do
		(
			set_resolution_by_ratio LV_ITEMS 2 2
			populate_resolution_options LV_ITEMS
		)
		
		on half_resolution pressed do
		(
			set_resolution_by_ratio LV_ITEMS .5 .5
			populate_resolution_options LV_ITEMS
		)
		
		on set_resolution_to_max pressed do
		(
			if (not frame_width.indeterminate) and (not frame_height.indeterminate) then
			(
				query_approved = true
				if renderSceneDialog.isOpen() then
					query_approved = queryBox "Render Setup Dialog is open. To set resolution to Render Setup Dialog it should be closed.\n\nWould you like to close it now?" title:"Caution"
				if query_approved do
				(
						renderSceneDialog.close()
						renderWidth = frame_width.value 
						renderHeight = frame_height.value
				)
			)
		)
		
		on get_resolution_from_max pressed do
		(
			query_approved = true
			if renderSceneDialog.isOpen() then
				query_approved = queryBox "Render Setup Dialog is open. To properly get resolution from Render Setup Dialog it should be closed.\n\nWould you like to close it now?" title:"Caution"
			if query_approved do
			(
				renderSceneDialog.close()
				set_resolution LV_ITEMS (renderWidth) (renderHeight)
				populate_resolution_options LV_ITEMS
			)
		)
		
		on region_x changed val do
		(
			set_named_integer_property_no_listview LV_ITEMS "region_x" val
			populate_spinner_field LV_ITEMS "region_x" Output_Size_Rollout.region_x
		)

		on region_y changed val do
		(
			set_named_integer_property_no_listview LV_ITEMS "region_y" val
			populate_spinner_field LV_ITEMS "region_y" Output_Size_Rollout.region_y
		)

		on region_w changed val do
		(
			set_named_integer_property_no_listview LV_ITEMS "region_w" val
			populate_spinner_field LV_ITEMS "region_w" Output_Size_Rollout.region_w
		)

		on region_h changed val do
		(
			set_named_integer_property_no_listview LV_ITEMS "region_h" val
			populate_spinner_field LV_ITEMS "region_h" Output_Size_Rollout.region_h
		)

		on set_region_to_max pressed do
		(
			if (not region_x.indeterminate) and (not region_y.indeterminate) and\
			(not region_w.indeterminate) and (not region_w.indeterminate) and\
			(not frame_width.indeterminate) and (not frame_height.indeterminate) then
			(
				setRenderType #region
				--convert percentage to viewport sizes
				local x = (renderWidth / 100.0) * region_x.value
				local y = (renderHeight / 100.0) * region_y.value
				local w = ((renderWidth / 100.0) * region_w.value) + x
				local h = ((renderHeight / 100.0) * region_h.value) + y
				viewport.setRegionRect (viewport.activeViewport) (box2 x y w h) 
				if (((maxVersion())[1] / 1000) > 10) then
					EditRenderRegion.UpdateRegion()
			)
		)

		on get_region_from_max pressed do
		(
			local region_box = viewport.getRegionRect (viewport.activeViewport)
			local width = renderWidth
			local height = renderHeight
			if (not frame_width.indeterminate) and (not frame_height.indeterminate) then
			(
				width = frame_width.value
				height = frame_height.value
			)
			local x = ((region_box.x as float) / width) * 100
			local y = ((region_box.y as float) / height) * 100
			local w = (((region_box.x + region_box.w) as float) / width) * 100
			local h = (((region_box.y + region_box.h) as float) / height) * 100

			set_named_integer_property_no_listview LV_ITEMS "region_x" x
			set_named_integer_property_no_listview LV_ITEMS "region_y" y
			set_named_integer_property_no_listview LV_ITEMS "region_w" w
			set_named_integer_property_no_listview LV_ITEMS "region_h" h
			
			populate_resolution_options LV_ITEMS
		)
		
		on Output_Size_Rollout rolledUp state do
		(
			-- find rollout index in main windows's rollouts
			index = findItem BatchCam_rollout_names Output_Size_Rollout.name
			-- set rollout state to the apropriate array element
			BatchCam_rollout_state[index] = state
		)
	)
	
	rollout Render_Output_Rollout "Render Output"
	(
		group "Main Output"
		(
			checkbox save_file "Save File" tooltip:"Common property for all camera.\nPersistent during current 3dsmax session" align:#left across:3
			button clear_render_output "Clear" width:45 offset: [65,0] align:#right
			button save_as_default  "Save to INI..." width:85 align:#right
			
			button file_button "File..." align:#left width:60 across:2
			edittext result_file_name width:320 offset: [-167,0] readonly:true align:#left 
			
			label label1 "Filename:" align:#left across:3
			edittext file_name width:320 offset: [-90,0]
			button syntax_info "Syntax" width:65 align:#right enabled:false
			button folder_button "..." align:#left width:40 offset: [0,-2] across:3
			edittext file_path width:320 align:#left offset: [-90,0]
			button open_current_folder "Open Folder" width:65 align:#right
			
			--last rendered location
			edittext last_render_path "Last Rendered Location: " width:384 readonly:true align:#left across:2
			button open_last_folder "Open Folder" width:65 offset: [0,-2] align:#right
		)
		group "Render Elements Folder/Subfolder"
		(
			checkbox save_elements "Enable Elements" tooltip:"" align:#left
			button elements_folder_button "..." align:#left width:40 offset: [0,-2] across:2
			edittext elements_path width:320 align:#left offset: [-168,0]
		)
		
		on save_as_default pressed do
		(
			if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
			(
				selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
				camera_object = getNodeByName (selected_item.text)
				
				property_names = #(	\
												"BatchCameraRender_render_output", \
												"BatchCameraRender_elements_state", \
												"BatchCameraRender_elements_output" \
											)

				saveDefaultValues camera_object property_names
			)
		)
		
		on Render_Output_Rollout open do
		(			
			--get settings from global variables
			--save file state
			if (temp_state = loadVarFromIniFile "Render_Output_Rollout" "save_file")  != undefined then
				save_file.checked = (temp_state as booleanClass)
			else
			(
				save_file.checked = true
				saveVar2IniFile "Render_Output_Rollout" "save_file" true
			)
		)
		
		--save settings in global vars.
		on save_file changed state do
			saveVar2IniFile "Render_Output_Rollout" "save_file" state
		
		on syntax_info pressed do
		(
			info_string = "You can use special keywords in file name and folder paths.\nCurrently supported keywords are:\n\n"
			info_string += "%cameraname%\n%scenestate%\n%renderpreset%\n%resolution%\n%date%\n%scenename%\n%projectfolder% and %projectpath%\n"
			info_string += "%scenefolder% and %scenepath%\n\n%up%  - to change preceding path one folder upward\n"
			info_string += "%trynum% - counts how many times the render button was pressed\n\n"
			info_string += "%elementtype%\n%elementname%  - both work in element subfolder and element name template\n\n"
			info_string += "%mainoutput%  and %renderfile% - doesn't works in Main Output path and filename\n\n"
			info_string += "%mainpath%  and %renderpath% - doesn't works in Main Output path and filename\n\n"
			info_string += "Example:\nThe string:\nD:\\Work\\%projectname%\\%date%\\%cameraname%.jpg\nwill yield the path:\nD:\\Work\\villa\\2009-10-28\\living room.jpg"
			messagebox info_string title:"File name template info" beep:false
		)
		
		on file_button pressed do
		(
			try
				image_file_name = getBitmapSaveFileName()
			catch (getCurrentException())
			
			if image_file_name != undefined then
			(				
				set_render_output LV_ITEMS image_file_name
				populate_filename_fields LV_ITEMS
			)
		)
		
		on file_name entered val do
		(
			--get full path from camera
			--get filename
			--change filename
			--create new fullpath
			--save full path to camera
			--go to next camera
			
			set_render_file LV_ITEMS val
			populate_filename_fields LV_ITEMS
		)
		
		on file_path entered val do
		(
			set_render_folder LV_ITEMS val
			populate_filename_fields LV_ITEMS
		)
		
		--set the folder via the dialog box
		on folder_button pressed do
		(
			temp_path = getFilenamePath file_path.text
			
			while (temp_path != "") and (not (doesFileExist temp_path)) do
				temp_path = pathConfig.removePathLeaf temp_path
			
			folder_name = getSavePath caption:"Choose Folder" initialDir:temp_path
			if folder_name != undefined then
			(
				set_render_folder LV_ITEMS folder_name
				populate_filename_fields LV_ITEMS
			)
		)
		
		--open explorer window
		on open_current_folder pressed do
		(
			temp_path = getFilenamePath file_path.text
			
			--if only one camera is selected then parse the file path
			if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
			(
				selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
				parsed_path = parse_file_name_template temp_path (compose_parsing_dictionary (selected_item.text))
				temp_path  = parsed_path
			)
		
-- 			format "temp_path1 - %\n" temp_path
			while (temp_path != "") and (not (doesFileExist temp_path)) do
				temp_path = pathConfig.removePathLeaf temp_path
-- 			format "temp_path2 - %\n" temp_path
			if (doesFileExist temp_path) then
			(
				command_line = Net_Render_Options_Rollout.command_line.text
				if command_line == "" then
					temp_res = ShellLaunch ("explorer.exe") ( "/n, " + temp_path)
				else
					temp_res = ShellLaunch command_line ("\"" + temp_path + "\"")
			)
			else
				messagebox ("Path does not exist: "+ temp_path) title:"Error"
		)

		on save_elements changed state do
		(
			set_elements_state LV_ITEMS state
		)
		
		on elements_path entered val do
		(
			set_elements_path LV_ITEMS val
			populate_filename_fields LV_ITEMS
		)
		
		--set the folder via the dialog box
		on elements_folder_button pressed do
		(
			folder_name = getSavePath caption:"Choose Folder" initialDir:file_path.text
			if folder_name != undefined then
			(
				set_elements_path LV_ITEMS folder_name
				populate_filename_fields LV_ITEMS
			)
		)
		
		on clear_render_output pressed do
		(
			for i in LV_ITEMS do
			(
				if i.selected then
				(
					obj_name = i.text
					obj_itself = getNodeByName obj_name
					setUserProperty obj_itself "BatchCameraRender_render_output" undefined
					clear_sub_item i "path"					
					setUserProperty obj_itself "BatchCameraRender_elements_state" undefined
					clear_sub_item i "elements_state"					
					setUserProperty obj_itself "BatchCameraRender_elements_output" undefined
					clear_sub_item i "elements_path"
				)
			)
			populate_filename_fields LV_ITEMS
		)
		
				--open explorer window
		on open_last_folder pressed do
		(
			temp_path = getFilenamePath last_render_path.text
		
-- 			format "temp_path3 - %\n" temp_path
			while (temp_path != "") and (not (doesFileExist temp_path)) do
				temp_path = pathConfig.removePathLeaf temp_path
-- 			format "temp_path4 - %\n" temp_path
			if ((isNotUndefined temp_path) and (doesFileExist temp_path)) then
			(
				command_line = Net_Render_Options_Rollout.command_line.text
				if command_line == "" then
					temp_res = ShellLaunch ("explorer.exe") ( "/n, " + temp_path)
				else
					temp_res = ShellLaunch command_line ("\"" + temp_path + "\"")
			)
			else
				messagebox ("Path does not exist: "+ temp_path) title:"Error"
		)
		
		on Render_Output_Rollout rolledUp state do
		(
			-- find rollout index in main windows's rollouts
			index = findItem BatchCam_rollout_names Render_Output_Rollout.name
			-- set rollout state to the apropriate array element
			BatchCam_rollout_state[index] = state
		)
	)
	
	rollout Frame_Range_Rollout "Frame Range"
	(
			radiobuttons rendType1 labels:#("Single") columns:1 default:1 align:#left across:5
			spinner render_single range:[-10000,10000,0] type:#integer width:70 align:#left offset: [-26,0] enabled:false
			button set_current "Set Current" offset: [-20,-3] width:65 align:#left		--button to set current frame
			
			button clear_frames "Clear" width:45 align:#right
			button save_as_default  "Save to INI..." width:85 align:#right
			
			radiobuttons rendType2 labels:#("Range") columns:1 default:0 align:#left across:6
			spinner render_from  range:[0,10000,0] type:#integer width:70 align:#left offset: [-10,0] enabled:false
			label label1 "To" align:#left offset: [-9,0]
			spinner render_to  range:[0,10000,10] type:#integer width:70 align:#left offset: [-65,0] enabled:false
			label label2 "Every Nth Frame:(not saving)" align:#right offset: [0,0]
			spinner render_every_nth range:[1,10000,0] type:#integer width:70 align:#right offset: [0,0] enabled:false
			
			radiobuttons rendType3 labels:#("Frames") columns:1 default:0 align:#left across:2
			edittext render_frames fieldWidth:250 offset: [-167,0] enabled:false
			
			radiobuttons rendType5 labels:#("Anim. Range") columns:1 default:0 align:#left across:3
			edittext render_anim_from width:70 offset: [-70,0] readonly:true
			edittext render_anim_to width:70 offset: [-150,0] readonly:true
		
		on save_as_default pressed do
		(
			if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
			(
				selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
				camera_object = getNodeByName (selected_item.text)
				
				property_names = #(	\
												"BatchCameraRender_frames", \
												"BatchCameraRender_framerange_from", \
												"BatchCameraRender_framerange_to", \
												"BatchCameraRender_anim_frame_range"
											)

				saveDefaultValues camera_object property_names
			)
		)
		
		on render_every_nth changed val do
			saveVar2IniFile "Frame_Range_Rollout" "render_every_nth" val
		
		on Frame_Range_Rollout open do
		(	
			if (temp_state = loadVarFromIniFile "Frame_Range_Rollout" "render_every_nth") != undefined then
				render_every_nth.value = (temp_state as integer)
			else
			(
				render_every_nth.value = 1
				saveVar2IniFile "Frame_Range_Rollout" "render_every_nth" 1
			)
		)
		
		on rendType1 changed val do
		(
			if val==1 then
			(
				rendType2.state = 0
				rendType3.state = 0
				rendType5.state = 0
				render_single.enabled = true
				render_anim_to.enabled=render_anim_from.enabled= render_from.enabled = render_to.enabled = render_frames.enabled = false
				set_frame_single LV_ITEMS render_single.value
			)
		)

		on set_current pressed do
		(
			rendType1.state = 1
			rendType2.state = 0
			rendType3.state = 0
			rendType5.state = 0
			render_single.enabled = true
			render_anim_to.enabled=render_anim_from.enabled= render_from.enabled = render_to.enabled = render_frames.enabled = false
			
			render_single.value = sliderTime.frame
			set_frame_single LV_ITEMS render_single.value
		)
		
		on rendType2 changed val do
		(
			if val==1 then
			(
				rendType1.state = 0
				rendType3.state = 0
				rendType5.state = 0
				render_from.enabled = render_to.enabled = true
				set_current.enabled = render_single.enabled = render_anim_to.enabled=render_anim_from.enabled= render_frames.enabled = false
				set_frame_range LV_ITEMS render_from.value render_to.value
			)
		)
		on rendType3 changed val do
		(
			if val==1 then
			(
				rendType1.state = 0
				rendType2.state = 0
				rendType5.state = 0
				set_current.enabled = render_anim_to.enabled=render_anim_from.enabled= render_from.enabled = render_to.enabled = false
				render_frames.enabled = true
				
				if render_frames.text != "" then
					set_frames LV_ITEMS render_frames.text
			)
		)
		
		
		on rendType5 changed val do
		(
			if val==1 then
			(
				rendType1.state = 0
				rendType2.state = 0
				rendType3.state = 0
				set_current.enabled = render_single.enabled = render_frames.enabled = render_from.enabled = render_to.enabled = false
				render_anim_to.enabled=render_anim_from.enabled= true
				set_anim_frame_range LV_ITEMS
			)
		)
		on render_from changed val do
		(	
			rendType1.state = 0
			rendType2.state = 1
			rendType3.state = 0
			rendType5.state = 0
			set_frame_range LV_ITEMS render_from.value render_to.value
		)
		on render_to changed val do
		(
			rendType1.state = 0
			rendType2.state = 1
			rendType3.state = 0
			rendType5.state = 0
			set_frame_range LV_ITEMS render_from.value render_to.value
		)
		on render_single changed val do
		(
			rendType1.state = 1
			rendType2.state = 0
			rendType3.state = 0
			rendType5.state = 0
			set_frame_single LV_ITEMS render_single.value
		)
		on render_frames changed val do
		(
			rendType1.state = 0
			rendType2.state = 0
			rendType3.state = 1
			rendType5.state = 0
			
			tempstring = ""
			teststr = #("0","1","2","3","4","5","6","7","8","9","-",","," ")
			for i=1 to val.count do
			(
				tempchar = val[i]
				if finditem teststr tempchar != 0 then
					tempstring = tempstring + tempchar
			)
			render_frames.text  = tempstring
		)
		on render_frames entered val do
		(
			rendType1.state = 0
			rendType2.state = 0
			render_from.enabled = render_to.enabled = false
			set_frames LV_ITEMS val
		)
		on clear_frames pressed do
		(
			for i in LV_ITEMS do
			(
				if i.selected then
				(
					obj_name = i.text
					obj_itself = getNodeByName obj_name
					setUserProperty obj_itself "BatchCameraRender_framerange_from" undefined
					setUserProperty obj_itself "BatchCameraRender_framerange_to" undefined
					clear_sub_item i "Frames"
				)
			)
			populate_framerange LV_ITEMS
		)
		
		on Frame_Range_Rollout rolledUp state do
		(
			index = findItem BatchCam_rollout_names Frame_Range_Rollout.name
			BatchCam_rollout_state[index] = state
		)
	)
	
	rollout Vray_Settings_Rollout  "Vray Settings"
	(
		group "Common Settings (not per camera)"
		(
			checkbox show_vray_vfb "Enable VFB" offset:[0,0] align:#left enabled:false checked:SAVE_VRAY_IMAGE_FILE_STATE across:3
			checkbox save_vray_image_file "Save V-ray Raw Image File" offset:[-65,0] align:#left enabled:false
			spinner vray_image_multiplier "Vray Image Multiplier: " range:[0,100000,1.0] type:#float width:100 offset:[-60,0] align:#left
		
			label label1 "Vray Image Type:" offset: [0,0] align:#left across:2
			dropdownlist vray_extension_list width:55 offset: [-140,-2] align:#left

			checkbox save_separate_render_channels "Save Vray Separate Channels (No effect if Enable Elements is off)" offset:[0,0] align:#left enabled:false
			checkbox save_vray_output "Save Vray Output (includes VFB color corrections)" offset:[0,0] align:#left enabled:false
		)
		
		group "Misc. Settings"
		(
			checkbox vray_ortho_checkbox "Orthographic Camera Mode" offset:[0,0] align:#left enabled:false
		)
		
		group "Irradiance map"
		(
			--irmap section
			dropdownlist irmap_mode "Mode:" width:150 offset: [0,-2] align:#left across:5
			checkbox auto_save_irmap "Auto Save Irmap" offset: [-15,0] align:#left
			checkbox auto_switch_irmap "Switch to Saved Irmap" offset: [0,0] align:#left
			button clear_vray_settings "Clear" width:45 offset: [4,0] align:#right	
			button save_as_default  "Save to INI..." width:85 align:#right
			
			edittext irmap_read_file_name "Load Irmap File:" width:380 offset: [0,0] align:#left across:2 
			button irmap_read_file_button "Browse..." width:60  align:#right
			edittext irmap_save_file_name "Save Irmap File:" width:380 offset: [0,0] align:#left across:2 
			button irmap_save_file_button "Browse..." width:60  align:#right
		)
		group "Light cache"
		(
			--lightcache section
			dropdownlist lcmap_mode "Mode:" width:150 offset: [0,-2] align:#left across:3
			checkbox auto_save_lcmap "Auto Save Cache" offset: [0,0] align:#right
			checkbox auto_switch_lcmap "Switch to Saved Cache" offset: [0,0] align:#right
			edittext lcmap_read_file_name "Load Lmap File:" width:380 offset: [0,0] align:#left across:2 
			button lcmap_read_file_button "Browse..." width:60  align:#right
			edittext lcmap_save_file_name "Save Lmap File:" width:380 offset: [0,0] align:#left across:2 
			button lcmap_save_file_button "Browse..." width:60  align:#right		
		)
		
		on save_as_default pressed do
		(
			if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
			(
				selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
				camera_object = getNodeByName (selected_item.text)
				
				property_names = #(	\
											"BatchCameraRender_irmap_mode", \
											"BatchCameraRender_auto_save_irmap", \
											"BatchCameraRender_auto_switch_irmap", \
											"BatchCameraRender_irmap_read_file", \
											"BatchCameraRender_irmap_save_file", \
											"BatchCameraRender_lcmap_mode", \
											"BatchCameraRender_auto_save_lcmap", \
											"BatchCameraRender_auto_switch_lcmap", \
											"BatchCameraRender_lcmap_read_file", \
											"BatchCameraRender_lcmap_save_file", \
											"BatchCameraRender_vray_ortho_mode"
											)

				saveDefaultValues camera_object property_names
			)
		)
		
		
		--irmap event handlers
		on irmap_read_file_button pressed do
		(
			try
				IRMAP_FILE_NAME = getOpenFileName caption:"Load irradiance map" filename:"" types:"Irradiance map (*.vrmap)|*.vrmap|All files (*.*)|*.*|" historyCategory:"IrradianceMap"
			catch (getCurrentException())
			
			if IRMAP_FILE_NAME != undefined then
			(				
				set_file_name_property LV_ITEMS "irmap_read_file" IRMAP_FILE_NAME
				populate_vray_options LV_ITEMS
			)
		)
		on irmap_save_file_button pressed do
		(
			try
				IRMAP_FILE_NAME = getSaveFileName caption:"Save irradiance map" filename:"" types:"Irradiance map (*.vrmap)|*.vrmap|All files (*.*)|*.*|" historyCategory:"IrradianceMap"
			catch (getCurrentException())
			
			if IRMAP_FILE_NAME != undefined then
			(				
				set_file_name_property LV_ITEMS "irmap_save_file" IRMAP_FILE_NAME
				populate_vray_options LV_ITEMS
			)
		)
		on irmap_read_file_name entered val do
		(
			if pathConfig.isLegalPath val then
			(
				irmap_read_file_name.text = val = pathConfig.appendPath val ""
				
				set_file_name_property LV_ITEMS "irmap_read_file" val
				populate_vray_options LV_ITEMS
			)
			else
				irmap_read_file_name.text = ""
		)
		on irmap_save_file_name entered val do
		(
			if pathConfig.isLegalPath val then
			(
				irmap_save_file_name.text = val = pathConfig.appendPath val ""
				
				set_file_name_property LV_ITEMS "irmap_save_file" val
				populate_vray_options LV_ITEMS
			)
			else
				irmap_save_file_name.text = ""
		)
		
		on vray_ortho_checkbox changed state do
		(
			set_checkbox_property LV_ITEMS "vray_ortho_mode" state
			populate_vray_options LV_ITEMS
		)		
		
		on auto_save_irmap changed state do
		(
			set_checkbox_property LV_ITEMS "auto_save_irmap" state
			populate_vray_options LV_ITEMS
		)
		on auto_switch_irmap changed state do
		(
			set_checkbox_property LV_ITEMS "auto_switch_irmap" state
			populate_vray_options LV_ITEMS
		)
		on irmap_mode selected item_num do
		(				
			set_named_integer_property LV_ITEMS "irmap_mode" item_num irmap_mode.selected
			--call method to add/update properties to selected camera object
			populate_vray_options LV_ITEMS
		)
		
		--lightcache event handlers
		on lcmap_read_file_button pressed do
		(
			try
				LCMAP_FILE_NAME = getOpenFileName caption:"Load Light Cache" filename:"" types:"Light cache (*.vrlmap)|*.vrlmap|All files (*.*)|*.*|" historyCategory:"LightCache"
			catch (getCurrentException())
			
			if LCMAP_FILE_NAME != undefined then
			(				
				set_file_name_property LV_ITEMS "lcmap_read_file" LCMAP_FILE_NAME
				populate_vray_options LV_ITEMS
			)
		)
		on lcmap_save_file_button pressed do
		(
			try
				LCMAP_FILE_NAME = getSaveFileName caption:"Save Light Cache" filename:"" types:"Light cache (*.vrlmap)|*.vrlmap|All files (*.*)|*.*|" historyCategory:"LightCache"
			catch (getCurrentException())
			
			if LCMAP_FILE_NAME != undefined then
			(				
				set_file_name_property LV_ITEMS "lcmap_save_file" LCMAP_FILE_NAME
				populate_vray_options LV_ITEMS
			)
		)
		on lcmap_read_file_name entered val do
		(
			if pathConfig.isLegalPath val then
			(
				lcmap_read_file_name.text = val = pathConfig.appendPath val ""
				
				set_file_name_property LV_ITEMS "lcmap_read_file" val
				populate_vray_options LV_ITEMS
			)
			else
				lcmap_read_file_name.text = ""
		)
		on lcmap_save_file_name entered val do
		(
			if pathConfig.isLegalPath val then
			(
				lcmap_save_file_name.text = val = pathConfig.appendPath val ""
				
				set_file_name_property LV_ITEMS "lcmap_save_file" val
				populate_vray_options LV_ITEMS
			)
			else
				lcmap_save_file_name.text = ""
		)
		on auto_save_lcmap changed state do
		(
			set_checkbox_property LV_ITEMS "auto_save_lcmap" state
			populate_vray_options LV_ITEMS
		)
		on auto_switch_lcmap changed state do
		(
			set_checkbox_property LV_ITEMS "auto_switch_lcmap" state
			populate_vray_options LV_ITEMS
		)
		on lcmap_mode selected item_num do
		(				
			set_named_integer_property LV_ITEMS "lcmap_mode" item_num lcmap_mode.selected
			--call method to add/update properties to selected camera object
			populate_vray_options LV_ITEMS
		)
		
		
		--global properties
		on clear_vray_settings pressed do
		(
			for i in LV_ITEMS do
			(
				if i.selected then
				(
					obj_name = i.text
					obj_itself = getNodeByName obj_name
					for property_name in BatchCam_VrayPropertiesNames do
					(
						setUserProperty obj_itself ("BatchCameraRender_" + property_name) undefined
						clear_sub_item i property_name
					)
				)
			)
			populate_vray_options LV_ITEMS
		)
		
		--save settings in global vars.
		on show_vray_vfb changed state do
		(
			saveVar2IniFile "Vray_Settings_Rollout" "show_vray_vfb" state
			save_vray_image_file.enabled = state
			save_separate_render_channels.enabled = state
			save_vray_output.enabled = state
		)
		
		on vray_image_multiplier changed state do
			saveVar2IniFile "Vray_Settings_Rollout" "vray_image_multiplier" state
		
		on save_vray_image_file changed state do
			saveVar2IniFile "Vray_Settings_Rollout" "save_vray_image_file" state
		
		on save_separate_render_channels changed state do
			saveVar2IniFile "Vray_Settings_Rollout" "save_separate_render_channels" state

		on save_vray_output changed state do
			saveVar2IniFile "Vray_Settings_Rollout" "save_vray_output" state
	
		on vray_extension_list selected index do
			saveVar2IniFile "Vray_Settings_Rollout" "vray_extension" index
		
		--add global var for vray file type
		on Vray_Settings_Rollout open do
		(
			temparray = #(".exr", ".vrimg")
			vray_extension_list.items  = temparray
			
			--set up dropdownlist ui elements
			irmap_mode.items = BatchCam_Vray_irmap_modes
			
			lcmap_mode.items = BatchCam_Vray_lcmap_modes
			
			--struct initiation
			BatchCam_VrayPropertiesMappingArray[1] = BatchCam_VrayPropertiesMapping BatchCam_VrayPropertiesNames[1] Vray_Settings_Rollout.irmap_mode "dropdownlist"
			BatchCam_VrayPropertiesMappingArray[2] = BatchCam_VrayPropertiesMapping BatchCam_VrayPropertiesNames[2] Vray_Settings_Rollout.auto_save_irmap 	"checkbox"
			BatchCam_VrayPropertiesMappingArray[3] = BatchCam_VrayPropertiesMapping BatchCam_VrayPropertiesNames[3] Vray_Settings_Rollout.auto_switch_irmap "checkbox"
			BatchCam_VrayPropertiesMappingArray[4] = BatchCam_VrayPropertiesMapping BatchCam_VrayPropertiesNames[4] Vray_Settings_Rollout.irmap_read_file_name "textfield"
			BatchCam_VrayPropertiesMappingArray[5] = BatchCam_VrayPropertiesMapping BatchCam_VrayPropertiesNames[5] Vray_Settings_Rollout.irmap_save_file_name "textfield"
			BatchCam_VrayPropertiesMappingArray[6] = BatchCam_VrayPropertiesMapping BatchCam_VrayPropertiesNames[6] Vray_Settings_Rollout.lcmap_mode "dropdownlist"
			BatchCam_VrayPropertiesMappingArray[7] = BatchCam_VrayPropertiesMapping BatchCam_VrayPropertiesNames[7] Vray_Settings_Rollout.auto_save_lcmap "checkbox"
			BatchCam_VrayPropertiesMappingArray[8] = BatchCam_VrayPropertiesMapping BatchCam_VrayPropertiesNames[8] Vray_Settings_Rollout.auto_switch_lcmap "checkbox"
			BatchCam_VrayPropertiesMappingArray[9] = BatchCam_VrayPropertiesMapping BatchCam_VrayPropertiesNames[9] Vray_Settings_Rollout.lcmap_read_file_name "textfield"
			BatchCam_VrayPropertiesMappingArray[10] =BatchCam_VrayPropertiesMapping BatchCam_VrayPropertiesNames[10] Vray_Settings_Rollout.lcmap_save_file_name "textfield"
			BatchCam_VrayPropertiesMappingArray[11] =BatchCam_VrayPropertiesMapping BatchCam_VrayPropertiesNames[11] Vray_Settings_Rollout.vray_ortho_checkbox "checkbox"
                                                                                                             
			--save vray image setting
			if (temp_state = loadVarFromIniFile "Vray_Settings_Rollout" "save_vray_image_file") != undefined then
				save_vray_image_file.checked = (temp_state as booleanClass) 
			else
			(
				save_vray_image_file.checked = false
				saveVar2IniFile "Vray_Settings_Rollout" "save_vray_image_file" false
			)
			
			if (temp_state = loadVarFromIniFile "Vray_Settings_Rollout" "save_separate_render_channels") != undefined then
				save_separate_render_channels.checked = (temp_state as booleanClass)  
			else
			(
				save_separate_render_channels.checked = false
				saveVar2IniFile "Vray_Settings_Rollout" "save_separate_render_channels" false
			)
			
			if (temp_state = loadVarFromIniFile "Vray_Settings_Rollout" "save_vray_output") != undefined then
				save_vray_output.checked = (temp_state as booleanClass)  
			else
			(
				save_vray_output.checked = false
				saveVar2IniFile "Vray_Settings_Rollout" "save_vray_output" false
			)
						
			if (temp_state = loadVarFromIniFile "Vray_Settings_Rollout" "show_vray_vfb")  != undefined then
				show_vray_vfb.checked = (temp_state as booleanClass)  
			else
			(
				show_vray_vfb.checked = true
				saveVar2IniFile "Vray_Settings_Rollout" "show_vray_vfb" true
			)
			
			if (temp_state = loadVarFromIniFile "Vray_Settings_Rollout" "vray_image_multiplier") != undefined then
				vray_image_multiplier.value = (temp_state as float)
			else
			(
				vray_image_multiplier.value = 1.0
				saveVar2IniFile "Vray_Settings_Rollout" "vray_image_multiplier" "1.0"
			)
			
			if  (temp_state = loadVarFromIniFile "Vray_Settings_Rollout" "vray_extension") != undefined then
				vray_extension_list.selection = (temp_state as integer)
			else
			(
				vray_extension_list.selection = 1
				saveVar2IniFile "Vray_Settings_Rollout" "vray_extension" 1
			)

		)
		
		on Vray_Settings_Rollout rolledUp state do
		(
			-- find rollout index in main windows's rollouts
			index = findItem BatchCam_rollout_names Vray_Settings_Rollout.name
			-- set rollout state to the apropriate array element
			BatchCam_rollout_state[index] = state
		)
	)
	
	rollout Scene_States_Rollout "Scene State - Render Preset"
	(
		label scene_states_list2_label "Scene State" align:#left across:5
		dotNetControl scene_states_list2 "ComboBox" width:160 height:21 offset:[-95,20] align:#left
		dropdownlist render_preset_list "Render Preset" width:160 align:#left offset:[-20,2]
		button clear_scene_states "Clear" width:45  offset:[2,0] align:#right			
		button save_as_default  "Save to INI..." width:85 align:#right
		
		on save_as_default pressed do
		(
			if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
			(
				selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
				camera_object = getNodeByName (selected_item.text)
				
				property_names = #(	\
											"BatchCameraRender_scene_state", \
											"BatchCameraRender_render_preset" \
											)

				saveDefaultValues camera_object property_names
			)
		)
		
		on Scene_States_Rollout open do
		(
			resolution_array = get_scene_state_array()
			resolution_array = join #("undefined") resolution_array
			scene_states_list2.Items.Clear()
			scene_states_list2.Items.AddRange resolution_array

			render_preset_list.items = join #("undefined") (get_render_preset_array())
		)
		
		on render_preset_list selected item_num do
		(
			set_string_property LV_ITEMS "render_preset" render_preset_list.selected
		)
		
		on scene_states_list2 SelectionChangeCommitted arg do
		(
			set_string_property LV_ITEMS "scene_state" scene_states_list2.SelectedItem
		)

		on scene_states_list2 KeyUp arg do
		(
			tempString = scene_states_list2.text
			if (arg.KeyCode == (dotnetclass "Keys").Enter) then
			(
				if (scene_states_list2.FindStringExact tempString) == -1 then
				(
					scene_states_list2.Items.Add tempString
					scene_states_list2.SelectedItem = tempString
				)
				set_string_property LV_ITEMS "scene_state" scene_states_list2.SelectedItem
				print (scene_states_list2.SelectedItem)
			)
		)
		
		on clear_scene_states pressed do
		(
			for i in LV_ITEMS do
			(
				if i.selected then
				(
					obj_name = i.text
					obj_itself = getNodeByName obj_name
					setUserProperty obj_itself "BatchCameraRender_scene_state" undefined
					setUserProperty obj_itself "BatchCameraRender_render_preset" undefined
					clear_sub_item i "scene_state"
					clear_sub_item i "render_preset"
					scene_states_list2.SelectedIndex = 0
					render_preset_list.selection = 1
				)
			)
			populate_scenestate_renderpreset LV_ITEMS
		)
		
		on Scene_States_Rollout rolledUp state do
		(
			-- find rollout index in main windows's rollouts
			index = findItem BatchCam_rollout_names Scene_States_Rollout.name
			-- set rollout state to the apropriate array element
			BatchCam_rollout_state[index] = state
		)
	)
	
	rollout Scripts_Rollout "Scripts - beta"
	(
		group "Submit Scripts - Runs on Submit PC (Common For All Cameras)"
		(
			checkbox enable_onsubmit "Enable" offset: [3,0] align:#left across:3
			button submit_script_clear "Clear" width:45 offset: [65,0] align:#right
			button save_as_default  "Save to INI..." width:85 align:#right
			
			edittext onsubmit_script "Per Submit: " width:380 offset: [0,0] align:#left across:2
			button onsubmit_script_button "Browse..." width:60 offset: [0,-2] align:#right
			
			checkbox enable_percamera_submit "Enable" offset: [3,0] align:#left
			edittext percamera_submit_script "Per each camera: " width:380 offset: [0,0] align:#left across:2 --labelOnTop:true 
			button percamera_script_button "Browse..." width:60 offset: [0,-2] align:#right
		)
		
		on save_as_default pressed do
		(				
			property_names = #(	\
										"BatchCameraRender_OnSubmitScriptEnable", \
										"BatchCameraRender_OnSubmitScript", \
										"BatchCameraRender_perCameraScriptEnable", \
										"BatchCameraRender_perCameraScript" \
										)

			saveDefaultValues rootnode property_names
		)
		
		on submit_script_clear pressed do
		(
			setRootNodeData "BatchCameraRender_OnSubmitScriptEnable" ""
			setRootNodeData "BatchCameraRender_OnSubmitScript" ""
			setRootNodeData "BatchCameraRender_perCameraScriptEnable" ""
			setRootNodeData "BatchCameraRender_perCameraScript" ""

			populate_submit_scripts_section()
		)
		
		--------#####-------
		on enable_onsubmit changed state do
		(
			setRootNodeData "BatchCameraRender_OnSubmitScriptEnable" state
		)
		on onsubmit_script entered text_val do
		(
			setRootNodeData "BatchCameraRender_OnSubmitScript" text_val
		)
		on onsubmit_script_button pressed do
		(
			try
				onsubmit_script_name = getOpenFileName caption:"On-Submit Script File" filename:"" types:"Script files (*.ms,*.mcr)|*.ms;*.mcr|Data files (*.dat)|*.dat|Text files (*.txt)|*.txt|All files (*.*)|*.*|" historyCategory:"Scripts"
			catch (getCurrentException())
			
			if onsubmit_script_name != undefined then
			(				
				setRootNodeData "BatchCameraRender_OnSubmitScript" onsubmit_script_name
				Scripts_Rollout.onsubmit_script.text = onsubmit_script_name
			)
		)
		--------#####-------
		on enable_percamera_submit changed state do
		(
			setRootNodeData "BatchCameraRender_perCameraScriptEnable" state
		)
		on percamera_submit_script entered text_val do
		(
			setRootNodeData "BatchCameraRender_perCameraScript" text_val
		)
		on percamera_script_button pressed do
		(
			try
				percamera_submit_script_name = getOpenFileName caption:"Per Camera Submit Script File" filename:"" types:"Script files (*.ms,*.mcr)|*.ms;*.mcr|Data files (*.dat)|*.dat|Text files (*.txt)|*.txt|All files (*.*)|*.*|" historyCategory:"Scripts"
			catch (getCurrentException())
			
			if percamera_submit_script_name != undefined then
			(				
				setRootNodeData "BatchCameraRender_perCameraScript" percamera_submit_script_name
				Scripts_Rollout.percamera_submit_script.text = percamera_submit_script_name
			)
		)
		--------#####-------

		group "Render Scripts - Runs on Render Servers (Set Per Camera)"
		(
			checkbox enable_prerender "Enable" offset: [3,0] align:#left  across:3
			button prerender_script_delete  "Clear" width:45 offset: [65,0] align:#right
			button save_as_default2  "Save to INI..." width:85 align:#right
			
			edittext prerender_script "Pre-Render: " width:380 offset: [0,0] align:#left across:2
			button prerender_script_button "Browse..." width:60 offset: [0,-2] align:#right

			checkbox enable_postrender "Enable" offset: [3,0] align:#left
			edittext postrender_script "Post-Render: " width:380 offset: [0,0] align:#left across:2
			button postrender_script_button "Browse..." width:60 offset: [0,-2] align:#right
		)
		
		on save_as_default2 pressed do
		(
			if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
			(
				selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
				camera_object = getNodeByName (selected_item.text)
				
				property_names = #(	\
											"BatchCameraRender_prerender_script", \
											"BatchCameraRender_prerender_enabled", \
											"BatchCameraRender_postrender_script", \
											"BatchCameraRender_postrender_enabled" \
											)

				saveDefaultValues camera_object property_names
			)
		)
		--event handlers
		on enable_prerender changed state do
		(
			set_checkbox_property LV_ITEMS "prerender_enabled" state
			populate_checkbox_item LV_ITEMS "prerender_enabled" Scripts_Rollout.enable_prerender
		)
		
		on prerender_script_button pressed do
		(
			try
				prerender_script_name = getOpenFileName caption:"Pre-render Script File" filename:"" types:"Script files (*.ms,*.mcr)|*.ms;*.mcr|Data files (*.dat)|*.dat|Text files (*.txt)|*.txt|All files (*.*)|*.*|" historyCategory:"Scripts"
			catch (getCurrentException())
			
			if prerender_script_name != undefined then
			(				
				set_file_name_property LV_ITEMS "prerender_script" prerender_script_name
				populate_text_fields LV_ITEMS "prerender_script" Scripts_Rollout.prerender_script
			)
		)
		
		on prerender_script entered val do
		(
			if pathConfig.isLegalPath val then
			(
				prerender_script.text = val = pathConfig.appendPath val ""
				
				set_file_name_property LV_ITEMS "prerender_script" val
				populate_text_fields LV_ITEMS "prerender_script" Scripts_Rollout.prerender_script
			)
			else
				prerender_script.text = ""
		)
		
		on enable_postrender changed state do
		(
			set_checkbox_property LV_ITEMS "postrender_enabled" state
			populate_checkbox_item LV_ITEMS "postrender_enabled" Scripts_Rollout.enable_postrender
		)
		
		on postrender_script_button pressed do
		(
			try
				postrender_script_name = getOpenFileName caption:"Post-render Script File" filename:"" types:"Script files (*.ms,*.mcr)|*.ms;*.mcr|Data files (*.dat)|*.dat|Text files (*.txt)|*.txt|All files (*.*)|*.*|" historyCategory:"Scripts"
			catch (getCurrentException())
			
			if postrender_script_name != undefined then
			(				
				set_file_name_property LV_ITEMS "postrender_script" postrender_script_name
				populate_text_fields LV_ITEMS "postrender_script" Scripts_Rollout.postrender_script
			)
		)
		
		on postrender_script entered val do
		(
			if pathConfig.isLegalPath val then
			(
				postrender_script.text = val = pathConfig.appendPath val ""
				
				set_file_name_property LV_ITEMS "postrender_script" val
				populate_text_fields LV_ITEMS "postrender_script" Scripts_Rollout.postrender_script
			)
			else
				postrender_script.text = ""
		)
		--end of event handlers
		on Scripts_Rollout open do
		(
			populate_submit_scripts_section()
		)
		
		on Scripts_Rollout rolledUp state do
		(
			-- find rollout index in main windows's rollouts
			index = findItem BatchCam_rollout_names Scripts_Rollout.name
			-- set rollout state to the apropriate array element
			BatchCam_rollout_state[index] = state
		)
	)
	
	rollout Light_Assignement_Rollout "Light Assignement"
	(
		label label1 "Solo Lights"align:#left across:3
		label label2 "Lights Forced On" align:#left
		label label3 "Lights Forced Off" align:#left
		button add_solo_lights_button "Add..." align:#left width:65 across:6
		button clear_solo_lights_button "Clear" align:#right width:45 offset:[-20,0]
		button add_forceon_lights_button "Add..." align:#left width:65
		button clear_forceon_lights_button "Clear" align:#right width:45 offset:[-20,0]
		button add_forceoff_lights_button "Add..." align:#left width:65
		button clear_forceoff_lights_button "Clear" align:#right width:45 offset:[-20,0]
		MultiListBox light_box_solo height:5 across:3
		MultiListBox light_box_forceon height:5
		MultiListBox light_box_forceoff height:5
		
		edittext label4 height:32 width:360 align:#left readonly:true across:2 \ 
		text:"Lists are given in order of priority: If Solo lights are present then Off and On\r\nlights are ignored. On lights are on even if they're present in Off lights list."
		button save_as_default  "Save to INI..." width:85 align:#right
		
		fn isLight obj =
		(
			return (iskindof obj DaylightAssemblyHead) or ((iskindof obj light) and not (iskindof obj.parent DaylightAssemblyHead)) 
		)
		
		on save_as_default pressed do
		(
			if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
			(
				selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
				camera_object = getNodeByName (selected_item.text)
				
				property_names = #(	\
											"BatchCameraRender_solo_lights", \
											"BatchCameraRender_on_lights", \
											"BatchCameraRender_off_lights" \
											)

				saveDefaultValues camera_object property_names
			)
		)
		
		on add_solo_lights_button pressed do
		(
			--call dialog box to select the lights
			--store solo-light list
			--fill multilistbox with light names
			templights = selectByName title:"Select Lights" buttonText:"Select" showHidden:true single:false --filter:light_filter --select objects by name
			if templights != undefined then
			(
				lightNames = for i in templights where (isLight i) collect i.name
				light_box_solo.items = lightNames --fill in the listbox ui
				set_light_state cameraItems:LV_ITEMS solo_lights:lightNames
			)
		)
		on clear_solo_lights_button pressed do
		(
			light_box_solo.items = #()
			set_light_state cameraItems:LV_ITEMS solo_lights:#("undefined")
		)
		
		on add_forceon_lights_button pressed do
		(
			--call dialog box to select the lights
			--store solo-light list
			--fill multilistbox with light names
			
			templights = selectByName title:"Select Lights" buttonText:"Select" showHidden:true single:false --filter:light_filter 
			if templights != undefined then
			(
				lightNames = for i in templights where (isLight i) collect i.name
				light_box_forceon.items = lightNames --fill in the listbox ui
				set_light_state cameraItems:LV_ITEMS on_lights:lightNames
			)
		)
		on clear_forceon_lights_button pressed do
		(
			light_box_forceon.items = #()
			set_light_state cameraItems:LV_ITEMS on_lights:#("undefined")
		)
		
		on add_forceoff_lights_button pressed do
		(
			--call dialog box to select the lights
			--store solo-light list
			--fill multilistbox with light names
			
			templights = selectByName title:"Select Lights" buttonText:"Select" showHidden:true single:false --filter:light_filter 
			if templights != undefined then
			(
				lightNames = for i in templights where (isLight i) collect i.name
				light_box_forceoff.items = lightNames
				set_light_state cameraItems:LV_ITEMS off_lights:lightNames
			)
		)
		
		on clear_forceoff_lights_button pressed do
		(
			light_box_forceoff.items = #()
			set_light_state cameraItems:LV_ITEMS off_lights:#("undefined")
		)
		
		on Light_Assignement_Rollout rolledUp state do
		(
			-- find rollout index in main windows's rollouts
			index = findItem BatchCam_rollout_names Light_Assignement_Rollout.name
			-- set rollout state to the apropriate array element
			BatchCam_rollout_state[index] = state
		)		

	)
		
	rollout aboutRoll "About"
	(
		label lb_about ""
		label lb_author "(C) 2009-2012, Sergo Pogosyan"
		hyperLink lb_email "contact@sergepogosyan.com" address:"mailto:contact@sergepogosyan.com" align:#center
		hyperLink lb_homepage "www.sergepogosyan.com" address:"http://www.sergepogosyan.com" align:#center
		edittext license_text "" height:180 align:#center labelOnTop:true readOnly:true text:\
@"This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA."
	
		on aboutRoll rolledUp state do
		(
			-- find rollout index in main windows's rollouts
			index = findItem BatchCam_rollout_names aboutRoll.name
			-- set rollout state to the apropriate array element
			BatchCam_rollout_state[index] = state
		)
		
		on aboutRoll open do
			lb_about.text ="Camera Manager " + VERSION_STRING
	)
	--#################################
	--####          macroscript event handlers       #######
	--#################################
	
	on isChecked do isDialogOpen  --return true if rollout is open
	
	on execute do
	(
		LIGHT_LIST = collect_scene_lights()
		--here can be placed initialization code
		--to set window placement, size, etc.
		--listview height var
		if (temp_listview_height = loadVarFromIniFile "Main_RollOut" "listview_height") != undefined then
			global_listview_height = (temp_listview_height as integer)
		
		if isDialogOpen then --if open, close it
		(
			CloseRolloutFloater batchCameraRender_floater
			isDialogOpen = false --and lower the flag
		)
		else --if closed, open it
		(
			temp_height = (loadVarFromIniFile "Main_RollOut" "dialog_height")
			
			temp_pos_x = (loadVarFromIniFile "Main_RollOut" "dialog_height_x")
			temp_pos_y = (loadVarFromIniFile "Main_RollOut" "dialog_height_y")
			
			if (temp_pos_x == undefined and temp_pos_y == undefined) then
			(
				temp_pos_x = 200
				temp_pos_y = 200
			)
			
			batchCameraRender_floater = newRolloutFloater ("Batch Camera Render " + VERSION_STRING) 500 (if temp_height == undefined then 850 else (temp_height as integer)) (temp_pos_x  as integer) (temp_pos_y as integer)
			
			state = BatchCam_rollout_state[findItem BatchCam_rollout_names "batchCameraRender_mainRollOut"]
			if state != undefined then state else state = false
			addRollout batchCameraRender_mainRollOut batchCameraRender_floater rolledUp:(not state)
			state = BatchCam_rollout_state[findItem BatchCam_rollout_names "Net_Render_Options_Rollout"]
			if state != undefined then state else state = false
			addRollout Net_Render_Options_Rollout batchCameraRender_floater rolledUp:(not state)
			state = BatchCam_rollout_state[findItem BatchCam_rollout_names "Output_Size_Rollout"]
			if state != undefined then state else state = false
			addRollout Output_Size_Rollout batchCameraRender_floater rolledUp:(not state)
			state = BatchCam_rollout_state[findItem BatchCam_rollout_names "Frame_Range_Rollout"]
			if state != undefined then state else state = false			
			addRollout Frame_Range_Rollout batchCameraRender_floater rolledUp:(not state)
			state = BatchCam_rollout_state[findItem BatchCam_rollout_names "Render_Output_Rollout"]
			if state != undefined then state else state = false
			addRollout Render_Output_Rollout batchCameraRender_floater rolledUp:(not state)	
			state = BatchCam_rollout_state[findItem BatchCam_rollout_names "Vray_Settings_Rollout"]
			if state != undefined then state else state = false
			addRollout Vray_Settings_Rollout batchCameraRender_floater rolledUp:(not state)
			state = BatchCam_rollout_state[findItem BatchCam_rollout_names "Scene_States_Rollout"]
			if state != undefined then state else state = false
			addRollout Scene_States_Rollout batchCameraRender_floater rolledUp:(not state)
			
			state = BatchCam_rollout_state[findItem BatchCam_rollout_names "Scripts_Rollout"]
			if state != undefined then state else state = false
			addRollout Scripts_Rollout batchCameraRender_floater rolledUp:(not state)			
			
			state = BatchCam_rollout_state[findItem BatchCam_rollout_names "Light_Assignement_Rollout"]
			if state != undefined then state else state = false
			addRollout Light_Assignement_Rollout batchCameraRender_floater rolledUp:(not state)	
			state = BatchCam_rollout_state[findItem BatchCam_rollout_names "aboutRoll"]
			if state != undefined then state else state = false
			addRollout aboutRoll batchCameraRender_floater rolledUp:(not state)
			elements_active false
			
			BatchCam_rollout_names = for roll in batchCameraRender_floater.rollouts collect roll.name
			--rollout state store and restore function
			for i=1 to batchCameraRender_floater.rollouts.count do
			(
				if BatchCam_rollout_state == undefined then
				(
					BatchCam_rollout_state = #()
					--initial state if no saved state
					aboutRoll.open = False
					Light_Assignement_Rollout.open = False
					Scene_States_Rollout.open = False
					Net_Render_Options_Rollout.open = False
					Vray_Settings_Rollout.open = False
				)
				if BatchCam_rollout_state[i] != undefined then
				(
				)
				else
				(
					BatchCam_rollout_state[i] = batchCameraRender_floater.rollouts[i].open
				)
			)
			batchCameraRender_mainRollOut.scrollPos = 0
			batchCameraRender_mainRollOut.lv_objects.Refresh() --refresh the dotNet control
			escapeEnable = false
			isDialogOpen = true --and raise the flag
		)
	)
	
	on closeDialogs do 
	(
		CloseRolloutFloater batchCameraRender_floater
	)
)