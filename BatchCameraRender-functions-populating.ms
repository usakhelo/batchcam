--########################--
--FUNCTIONS for batch camera render script
--########################--
--

--function to populate spinner fields with info from selected list items
fn populate_spinner_field cameraItems property_name rollout_control  =
(
	local spinner = rollout_control
	
	--collect selected items
	local selected_items = cameraItems
		
	if selected_items.count == 1 then
	(
		i = selected_items[1]
		obj_name = i.text
		obj_itself = getNodeByName obj_name
		temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)

		--fill elements path field
		if isNotUndefined temp_string then
-- 			spinner.value = (temp_string as integer) 
			spinner.value = execute (temp_string as string)
		else
			spinner.indeterminate  = true
	)
	else --multiple selection
	(	
		prev_value = ""
		diff_flag = false
		
		for i=1 to selected_items.count while not diff_flag do
		(
			obj_name = selected_items[i].text
			obj_itself = getNodeByName obj_name
			temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
			if isNotUndefined temp_string then
			(
				--set previous value to first value
				if i==1 then prev_value = temp_string
				--show path if previous path and current are similar
				if temp_string != prev_value then 
				(
					diff_flag = true	--set flag if values differ
					spinner.indeterminate  = true
				)
				else if not diff_flag then	--if values are same and flag hasn't been set
					spinner.value = execute (temp_string as string) 
				
				prev_value = temp_string
			)
			else
			(
				spinner.indeterminate  = true
			)
		)
	)
)

--function to populate ui textfield element from given listItems with property name
--this function automaticaly detects if one or several items are selected and
--sets correct textfield text value depend on the content of the listitem
--if the content is equal the this content is displayed, if not "varies" text is shown.
fn populate_text_fields cameraItems property_name rollout_control =
(
	local uiTextField = rollout_control
	
	--collect selected items
	local selected_items = cameraItems
		
	if selected_items.count == 1 then
	(
		i = selected_items[1]
		obj_name = i.text
		obj_itself = getNodeByName obj_name
		temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)

		--fill elements path field
		if isNotUndefined temp_string then
			uiTextField.text = (temp_string as string) 
		else
			uiTextField.text = "undefined"
	)
	else --multiple selection
	(	
		prev_path = ""
		path_diff_flag = false
		
		for i=1 to selected_items.count while not path_diff_flag do
		(
			obj_name = selected_items[i].text
			obj_itself = getNodeByName obj_name
			temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
			if isNotUndefined temp_string then
			(
				--set previous value to first value
				if i==1 then prev_path = temp_string
				--show path if previous path and current are similar
				if temp_string != prev_path then 
				(
					path_diff_flag = true	--set flag if values differ
					uiTextField.text = "Varies"
				)
				else if not path_diff_flag then	--if values are same and flag hasn't been set
					uiTextField.text = temp_string
				
				prev_path = temp_string
			)
			else
			(
				uiTextField.text = "Varies"
			)
		)
	)
)

--function to populate checkbox from the one or multiple selection of the listview items
fn populate_checkbox_item cameraItems property_name rollout_control =
(
	local uiCheckBox  = rollout_control
	
	local selected_items = cameraItems
		
	if selected_items.count == 1 then
	(
		i = selected_items[1]
		obj_name = i.text
		obj_itself = getNodeByName obj_name
		
		temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
		if isNotUndefined temp_string then
			uiCheckBox.state = (temp_string as booleanclass)
		else
		(
			if (classof uiCheckBox) != CheckButtonControl then
				uiCheckBox.triState = 2
		)
	)
	else --multiple selection
	(	
		prev_state
		state_diff_flag = false
		
		for i=1 to selected_items.count while not state_diff_flag do
		(
			obj_name = selected_items[i].text
			obj_itself = getNodeByName obj_name

			--populate checkbox state for multiple items checked
			temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
			if isNotUndefined temp_string then
			(
				temp_string = (temp_string as booleanclass)
				--set previous value to first value
				if i==1 then prev_state = temp_string
				--show path if previous path and current are the similar
				if temp_string != prev_state then 
				(
					state_diff_flag = true	--set flag if values differ
					if (classof uiCheckBox) != CheckButtonControl then
						uiCheckBox.triState = 2
				)
				else if not state_diff_flag then	--if values are same and flag hasn't been set
				(
					if (classof uiCheckBox) != CheckButtonControl then
						uiCheckBox.triState = if temp_string then 1 else 0
				)
				
				prev_state = temp_string
			)
			else
			(
				if (classof uiCheckBox) != CheckButtonControl then
						uiCheckBox.triState = 2
			)			
		)
	)
)

--function to populate dropdown box with given item number
fn populate_dropdownbox_integer_item cameraItems property_name rollout_control =
(
	local uiDropDownBox  = rollout_control
	
	--collect selected items
	local selected_items = cameraItems
	
	if selected_items.count == 1 then
	(
		i = selected_items[1]
		obj_name = i.text
		obj_itself = getNodeByName obj_name
		
		temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
		if (isNotUndefined temp_string) then
			uiDropDownBox.selection  = (temp_string as integer)
		else
			uiDropDownBox.selection = 0
	)
	else --multiple selection
	(	
		prev_state
		state_diff_flag = false
		
		for i=1 to selected_items.count while not state_diff_flag do
		(
			obj_name = selected_items[i].text
			obj_itself = getNodeByName obj_name

			--populate checkbox state for multiple items checked
			temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
			if (isNotUndefined temp_string) then
			(
				--set previous value to first value
				if i==1 then prev_state = temp_string
				--show path if previous path and current are the similar
				if temp_string != prev_state then 
				(
					state_diff_flag = true	--set flag if values differ
					uiDropDownBox.selection = 0
				)
				else if not state_diff_flag then	--if values are same and flag hasn't been set
					uiDropDownBox.selection = (temp_string as integer)
				
				prev_state = temp_string
			)
			else
			(
				uiDropDownBox.selection = 0
			)			
		)
	)
)

--function to populate dropdown box with given string
fn populate_combobox_string_item cameraItems property_name rollout_control =
(
	local uiComboBox  = rollout_control
	
	--collect selected items
	local selected_items = cameraItems
	
	if selected_items.count == 1 then
	(
		i = selected_items[1]
		obj_name = i.text
		obj_itself = getNodeByName obj_name
		
		temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
		if (isNotUndefined temp_string) then
		(
			if (uiComboBox.FindStringExact temp_string) != -1 then
				uiComboBox.SelectedItem = temp_string
			else
			(
				uiComboBox.Items.Add temp_string
				uiComboBox.SelectedItem = temp_string
			)
		)
		else
			uiComboBox.SelectedIndex = 0
	)
	else --multiple selection
	(	
		prev_state
		state_diff_flag = false
		
		for i=1 to selected_items.count while (not state_diff_flag) do
		(
			obj_name = selected_items[i].text
			obj_itself = getNodeByName obj_name
			
			temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
			temp_string = temp_string as string

			if i==1 then prev_state = temp_string
			if temp_string != prev_state then 
				state_diff_flag = true
			
			prev_state = temp_string
		)
		if state_diff_flag then
			uiComboBox.SelectedIndex = -1
		else
		(
			if (uiComboBox.FindStringExact temp_string) != -1 then
				uiComboBox.SelectedItem = temp_string
			else
			(
				uiComboBox.Items.Add temp_string
				uiComboBox.SelectedItem = temp_string
			)
		)
	)
)

--function to populate dropdown box with given string
fn populate_dropdownbox_string_item cameraItems property_name rollout_control =
(
	local uiDropDownBox  = rollout_control
	
	--collect selected items
	local selected_items = cameraItems
	
	if selected_items.count == 1 then
	(
		i = selected_items[1]
		obj_name = i.text
		obj_itself = getNodeByName obj_name
		
		temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
		if (isNotUndefined temp_string) then
			uiDropDownBox.selection  = finditem (uiDropDownBox.items) temp_string
		else
			uiDropDownBox.selection = 0
	)
	else --multiple selection
	(	
		prev_state
		state_diff_flag = false
		
		for i=1 to selected_items.count while (not state_diff_flag) do
		(
			obj_name = selected_items[i].text
			obj_itself = getNodeByName obj_name

			--populate checkbox state for multiple items checked
			temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
			if (isNotUndefined temp_string) then
			(
				--set previous value to first value
				if i==1 then prev_state = temp_string
				--show path if previous path and current are the similar
				if temp_string != prev_state then 
				(
					state_diff_flag = true	--set flag if values differ
					uiDropDownBox.selection = 0
				)
				else if not state_diff_flag then	--if values are same and flag hasn't been set
					uiDropDownBox.selection  = finditem (uiDropDownBox.items) temp_string
				
				prev_state = temp_string
			)
			else
			(
				uiDropDownBox.selection = 0
			)			
		)
	)
)

--function to populate resolution dropdown box from listitem selection
fn populate_dropdownbox_resolution cameraItems rollout_control =
(
	local uiDropDownBox  = rollout_control
	
	--collect selected items
	local selected_items = cameraItems
	
	if selected_items.count == 1 then
	(
		i = selected_items[1]
		obj_name = i.text
		obj_itself = getNodeByName obj_name
		
		temp_width = getUserProperty obj_itself "BatchCameraRender_frame_width"
		temp_height = getUserProperty obj_itself "BatchCameraRender_frame_heigth"
		temp_string = (temp_width as string) + " x " + (temp_height as string)
		if (isNotUndefined temp_string) then
			uiDropDownBox.selection  = finditem (uiDropDownBox.items) temp_string
		else
			uiDropDownBox.selection = 0
	)
	else --multiple selection
	(	
		prev_state
		state_diff_flag = false
		
		for i=1 to selected_items.count while (not state_diff_flag) do
		(
			obj_name = selected_items[i].text
			obj_itself = getNodeByName obj_name

			--populate checkbox state for multiple items checked
			temp_width = getUserProperty obj_itself "BatchCameraRender_frame_width"
			temp_height = getUserProperty obj_itself "BatchCameraRender_frame_heigth"
			temp_string = (temp_width as string) + " x " + (temp_height as string)
			if (isNotUndefined temp_string) then
			(
				--set previous value to first value
				if i==1 then prev_state = temp_string
				--show path if previous path and current are the similar
				if temp_string != prev_state then 
				(
					state_diff_flag = true	--set flag if values differ
					uiDropDownBox.selection = 0
				)
				else if not state_diff_flag then	--if values are same and flag hasn't been set
					uiDropDownBox.selection  = finditem (uiDropDownBox.items) temp_string
				
				prev_state = temp_string
			)
			else
			(
				uiDropDownBox.selection = 0
			)			
		)
	)
)

--populate frame range parameters
fn populate_framerange cameraItems =
(
	lis = cameraItems
	rendType1 = Frame_Range_Rollout.rendType1
	rendType2 = Frame_Range_Rollout.rendType2
	rendType3 = Frame_Range_Rollout.rendType3
	rendType5 = Frame_Range_Rollout.rendType5
	
	render_from = Frame_Range_Rollout.render_from
	render_to = Frame_Range_Rollout.render_to
	render_anim_from = Frame_Range_Rollout.render_anim_from
	render_anim_to = Frame_Range_Rollout.render_anim_to
	render_frames = Frame_Range_Rollout.render_frames
	render_single = Frame_Range_Rollout.render_single
	
	--exclude selected items
	local selected_items = #()
	for i in lis do
		if i.selected then
			append selected_items i
		
	if selected_items.count == 1 then
	(
		i = selected_items[1]
		obj_name = i.text
		obj_itself = getNodeByName obj_name
		
		temp_string1 = getUserProperty obj_itself "BatchCameraRender_frames"
		temp_string2 = getUserProperty obj_itself "BatchCameraRender_framerange_from"
		temp_string5 = getUserProperty obj_itself "BatchCameraRender_anim_frame_range"
		
		if (isNotUndefined temp_string5) then
		(	--render_frames
			rendType1.state = 0
			rendType2.state = 0
			rendType3.state = 0
			rendType5.state = 1
			render_anim_from.enabled = render_anim_to.enabled = true
			render_single.enabled = render_frames.enabled = render_from.enabled = render_to.enabled = false
			temp_frame_range = get_key_range obj_itself
			render_anim_from.text = (temp_frame_range[1].frame as integer) as string
			render_anim_to.text = (temp_frame_range[2].frame as integer) as string
		)
		else if (isNotUndefined temp_string1) then
		(	--render_frames
			rendType1.state = 0
			rendType2.state = 0
			rendType3.state = 1
			rendType5.state = 0
			render_frames.text = temp_string1 as string
			render_from.enabled = render_to.enabled = false
			render_frames.enabled = true
		)
		else if (isNotUndefined temp_string2) then
		(
			temp_string3 = getUserProperty obj_itself "BatchCameraRender_framerange_to"
			if (temp_string2 as integer == temp_string3 as integer) then
			(	--single frame
				rendType1.state = 1
				rendType2.state = 0
				rendType3.state = 0
				rendType5.state = 0
				render_from.enabled = render_to.enabled = render_frames.enabled = false
				render_single.value = temp_string2 as integer

			)
			else
			(	--frame range
				rendType1.state = 0
				rendType2.state = 1
				rendType3.state = 0
				rendType5.state = 0
				render_single.enabled = false
				render_from.enabled = render_to.enabled = true
				render_from.value = temp_string2 as integer
				render_to.value = temp_string3 as integer
			)
		)
		else
		(
			--resolution is undefined
			case rendTimeType of
			(
				1:	(
					rendType1.state = 1
					rendType2.state = 0
					rendType3.state = 0
					rendType5.state = 0
				)
				2: (
					render_from.value = animationRange.start.frame as integer
					render_to.value = animationRange.end.frame as integer
					rendType1.state = 0
					rendType2.state = 1
					rendType3.state = 0
					rendType5.state = 0
				)
				3:	(
					render_from.value = rendStart
					render_to.value = rendEnd
					rendType1.state = 0
					rendType2.state = 1
					rendType3.state = 0
					rendType5.state = 0
				)
				4:	(
					render_frames.text = rendPickupFrames
					rendType1.state = 0
					rendType2.state = 0
					rendType3.state = 1
					rendType5.state = 0
				)
			)

-- 			rendType1.state = 0
-- 			rendType2.state = 0
-- 			rendType3.state = 0
-- 			rendType5.state = 0
		)
	)
	else --multiple selection
	(
	)
)

fn populate_elements_options cameraItems=
(
	lis = cameraItems
	result_file_name = Render_Output_Rollout.result_file_name
	elements_path = Render_Output_Rollout.elements_path
	elements_state = Render_Output_Rollout.save_elements
	
	--exclude selected items
	local selected_items = #()
	for i in lis do
		if i.selected then
			append selected_items i
		
	if selected_items.count == 1 then
	(
		i = selected_items[1]
		obj_name = i.text
		obj_itself = getNodeByName obj_name
		temp_string = getUserProperty obj_itself "BatchCameraRender_elements_output"

		--fill elements path field
		if (isNotUndefined temp_string) then
			elements_path.text = (temp_string as string) 
		else
			elements_path.text = "undefined"
		
		--set state here
		temp_string = getUserProperty obj_itself "BatchCameraRender_elements_state"
			if (isNotUndefined temp_string) then
				elements_state.state = (temp_string as booleanclass)
			else
				elements_state.triState = 2
	)
	else --multiple selection
	(	
		prev_path = ""
		prev_state
		path_diff_flag = false
		state_diff_flag = false
		
		for i=1 to selected_items.count while not path_diff_flag do
		(
			obj_name = selected_items[i].text
			obj_itself = getNodeByName obj_name
			temp_string = getUserProperty obj_itself "BatchCameraRender_elements_output"
			if (isNotUndefined temp_string) then
			(
				--set previous value to first value
				if i==1 then prev_path = temp_string
				--show path if previous path and current are the similar
				if temp_string != prev_path then 
				(
					path_diff_flag = true	--set flag if values differ
					elements_path.text = "Varies"
				)
				else if not path_diff_flag then	--if values are same and flag hasn't been set
					elements_path.text = temp_string
				
				prev_path = temp_string
			)
			else
			(
				elements_path.text = "Varies"
			)
			
			--populate elemetns state for multiple items checked
			temp_string = getUserProperty obj_itself "BatchCameraRender_elements_state"
			if (isNotUndefined temp_string) then
			(
				temp_string = temp_string as booleanclass
				--set previous value to first value
				if i==1 then prev_state = temp_string
				--show path if previous path and current are the similar
				if temp_string != prev_state then 
				(
					state_diff_flag = true	--set flag if values differ
					elements_state.triState = 2
				)
				else if not state_diff_flag then	--if values are same and flag hasn't been set
					elements_state.triState = if temp_string then 1 else 0
				
				prev_state = temp_string
			)
			else
			(
				elements_state.triState = 2
			)			
		)
	)
)

fn populate_filename_fields cameraItems=
(
	--get selected items
	--get filename from one item
	--split to name and path
	--compare to UIfield text
	--if differs then enter "varies" text
	--go to next item
	
	lis = cameraItems
	result_file_name = Render_Output_Rollout.result_file_name
	file_name = Render_Output_Rollout.file_name
	file_path = Render_Output_Rollout.file_path
	elements_path = Render_Output_Rollout.elements_path
	
	--exclude selected items
	local selected_items = #()
	for i in lis do
		if i.selected then
			append selected_items i
		
	if selected_items.count == 1 then
	(
		i = selected_items[1]
		obj_name = i.text
		obj_itself = getNodeByName obj_name
		temp_string = getUserProperty obj_itself "BatchCameraRender_render_output"
		
		if (isNotUndefined temp_string) then
		(
			--put parsed string in full text textfield
			result_file_name.text = parse_file_name_template temp_string (compose_parsing_dictionary obj_name) 
			file_name.text = filenameFromPath temp_string
			file_path.text = getFilenamePath temp_string
		)
		else
		(
			result_file_name.text = "undefined"
			file_name.text = "undefined"
			file_path.text = "undefined"
		)		
	)
	else
	(	
		prev_parsed_path = ""
		prev_templated_path = ""
		prev_path = ""
		prev_file = ""		
		
		parsed_diff_flag = false
		templated_diff_flag = false
		path_diff_flag = false
		file_diff_flag = false
		
		temp_string = ""
		
		for i=1 to selected_items.count do
		(			
			obj_name = selected_items[i].text
			obj_itself = getNodeByName obj_name
			temp_string = getUserProperty obj_itself "BatchCameraRender_render_output"
			if (isNotUndefined temp_string) then
			(
				--if multiple items are selected
				--show only similar parts of the filename
				
				-- for the full path textfield consider parsed path string
				parsed_path = parse_file_name_template temp_string (compose_parsing_dictionary obj_name) 
				
				--init previous values for the first time
				if i==1 then 
				(
					prev_parsed_path = parsed_path
					prev_templated_path = temp_string
					prev_path = getFilenamePath temp_string
					prev_file = filenameFromPath temp_string	
				)
				
				--flag setting section
				if parsed_path != prev_parsed_path then
					parsed_diff_flag = true
				
				if temp_string != prev_templated_path then
					templated_diff_flag = true
				
				if (getFilenamePath temp_string) != prev_path then
					path_diff_flag = true
				
				if (filenameFromPath temp_string) != prev_file then
					file_diff_flag = true
				
				prev_parsed_path = parsed_path
				prev_templated_path = temp_string
				prev_path = getFilenamePath temp_string
				prev_file = filenameFromPath temp_string	
			)
			else
			(
				result_file_name.text = "Varies"
				file_name.text = "Varies"
				file_path.text = "Varies"
				parsed_diff_flag = true
				templated_diff_flag = true
				path_diff_flag = true
				file_diff_flag = true
				--put "undefined" text to UI fields
			)			
		)
		--set text fields after for loop
-- 		temp_string = temp_string as string	-- as string added in case temp_string is not a string or undefined
		if not parsed_diff_flag then
		(
			--if parsed full paths are similar show all parts
			result_file_name.text = temp_string
			file_name.text = filenameFromPath temp_string
			file_path.text = getFilenamePath temp_string
		)
		else if not templated_diff_flag then
		(
			--check if template strings are similar
			--show similar file names and folder name
			result_file_name.text = "Varies"
			file_name.text = filenameFromPath temp_string
			file_path.text = getFilenamePath temp_string
		)
		else if not path_diff_flag then
		(
			--if full path varies but folder is similar
			--show the folder path
			--in other parts show "varies" text
			result_file_name.text = "Varies"
			file_name.text = "Varies"
			file_path.text = getFilenamePath temp_string
		)
		else if not file_diff_flag  then
		(
			--if folder path varies but filename is equal
			--show the filename part
			--in other parts show "varies" text
			result_file_name.text = "Varies"
			file_name.text = filenameFromPath temp_string
			file_path.text = "Varies"
		)
		else
		(
			--if all parts are different
			--show "varies" text in all parts
			result_file_name.text = "Varies"
			file_name.text = "Varies"
			file_path.text = "Varies"
		)
	)
	
	populate_elements_options cameraItems
	--populate last render field
	populate_text_fields cameraItems "lastRenderPath" Render_Output_Rollout.last_render_path
)

fn populate_light_state cameraItems=
(
	lis = cameraItems
	solo_lights = Light_Assignement_Rollout.light_box_solo
	on_lights = Light_Assignement_Rollout.light_box_forceon 
	off_lights = Light_Assignement_Rollout.light_box_forceoff 
	
	--exclude selected items
	local selected_items = #()
	for i in lis do
		if i.selected then
			append selected_items i
		
	if selected_items.count == 1 then
	(
		i = selected_items[1]
		obj_name = i.text
		obj_itself = getNodeByName obj_name
		
		temp_string1 = getUserProperty obj_itself "BatchCameraRender_solo_lights"
		temp_string2 = getUserProperty obj_itself "BatchCameraRender_on_lights"
		temp_string3 = getUserProperty obj_itself "BatchCameraRender_off_lights"
		if (isNotUndefined temp_string1) then
		(
			temparray = filterString temp_string1 ","
			solo_lights.items = temparray
		)
		else
		(
			solo_lights.items = #()
		)
		if (isNotUndefined temp_string2) then
		(
			temparray = filterString temp_string2 ","
			on_lights.items = temparray
		)
		else
		(
			on_lights.items = #()
		)
		if (isNotUndefined temp_string3) then
		(
			temparray = filterString temp_string3 ","
			off_lights.items = temparray
		)
		else
		(
			off_lights.items = #()
		)
	)
)

fn populate_submit_scripts_section=
(
	temp_state = getRootNodeData "BatchCameraRender_OnSubmitScriptEnable"

	if isNotUndefinedOrEmpty temp_state then
		Scripts_Rollout.enable_onsubmit.state = (temp_state as BooleanClass)
	else
		Scripts_Rollout.enable_onsubmit.tristate = 2
	
	temp_state = getRootNodeData "BatchCameraRender_OnSubmitScript"

	if isNotUndefinedOrEmpty temp_state then
		Scripts_Rollout.onsubmit_script.text = (temp_state as string)
	else
		Scripts_Rollout.onsubmit_script.text = "undefined"
	
	temp_state = getRootNodeData "BatchCameraRender_perCameraScriptEnable"

	if isNotUndefinedOrEmpty temp_state then
		Scripts_Rollout.enable_percamera_submit.state = (temp_state as BooleanClass)
	else
		Scripts_Rollout.enable_percamera_submit.tristate = 2
	
	temp_state = getRootNodeData "BatchCameraRender_perCameraScript"

	if isNotUndefinedOrEmpty temp_state then
		Scripts_Rollout.percamera_submit_script.text = (temp_state as string)
	else
		Scripts_Rollout.percamera_submit_script.text = "undefined"
)
batchCameraRender_populateScripts = populate_submit_scripts_section


fn populate_script_rollout selectedItems = 
(
	populate_text_fields selectedItems "prerender_script" Scripts_Rollout.prerender_script
	populate_checkbox_item selectedItems "prerender_enabled" Scripts_Rollout.enable_prerender
	populate_text_fields selectedItems "postrender_script" Scripts_Rollout.postrender_script
	populate_checkbox_item selectedItems "postrender_enabled" Scripts_Rollout.enable_postrender
)
--separate function to populate ui elements in vray rollout
fn populate_vray_options selectedItems =
(
	--populate all vray properties for selected items.
	--don't know if it's right.
	--may be it would be more usefull to populate only properties that really exist in selected item's camera

	for vray_property in BatchCam_VrayPropertiesMappingArray do
	(
		if vray_property.propertyType == "textfield" then
			populate_text_fields selectedItems vray_property.propertyName vray_property.propertyUIelement
		if vray_property.propertyType == "checkbox" then
			populate_checkbox_item selectedItems vray_property.propertyName vray_property.propertyUIelement
		if vray_property.propertyType == "dropdownlist" then
			populate_dropdownbox_integer_item selectedItems vray_property.propertyName vray_property.propertyUIelement		
	)
)

fn populate_resolution_options selectedItems =
(
	--populate image size fields
	populate_spinner_field selectedItems "frame_width" Output_Size_Rollout.frame_width
	populate_spinner_field selectedItems "frame_heigth" Output_Size_Rollout.frame_height
	populate_spinner_field selectedItems "image_aspect" Output_Size_Rollout.image_aspect_spinner
	--display selected resolution
	populate_dropdownbox_resolution selectedItems Output_Size_Rollout.out_size_list
	populate_checkbox_item selectedItems "region_enabled" Output_Size_Rollout.use_region
	populate_spinner_field selectedItems "region_x" Output_Size_Rollout.region_x
	populate_spinner_field selectedItems "region_y" Output_Size_Rollout.region_y
	populate_spinner_field selectedItems "region_w" Output_Size_Rollout.region_w
	populate_spinner_field selectedItems "region_h" Output_Size_Rollout.region_h
)

fn populate_scenestate_renderpreset selectedItems =
(
	populate_combobox_string_item selectedItems "scene_state" Scene_States_Rollout.scene_states_list2
	populate_dropdownbox_string_item selectedItems "render_preset" Scene_States_Rollout.render_preset_list
)

fn populate_ui_elements selectedItems=
(
	if selectedItems.count > 0 then
	(
		populate_resolution_options selectedItems
		populate_scenestate_renderpreset selectedItems
		populate_filename_fields selectedItems
		populate_framerange selectedItems
		populate_vray_options selectedItems
		populate_script_rollout selectedItems
		populate_light_state selectedItems
	)
)
