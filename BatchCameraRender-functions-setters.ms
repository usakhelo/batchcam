--########################--
--FUNCTIONS for batch camera render script
--Function to save (set) rendering options to camera objects
--########################--

--general function to set filename property to user properties
fn set_file_name_property cameraItems property_name fullfilename=
(
	fullfilename = trimLeadTrailSpaces fullfilename	
	--cameraItems - listItems in activeX control
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			
-- 			fullfilename = pathConfig.convertPathToAbsolute fullfilename
			setUserProperty i ("BatchCameraRender_" + property_name) (fullfilename as string)
			set_sub_item i (fullfilename as string) property_name
		)
	)
)

-- general function to set checkbox value to user properties
fn set_checkbox_property cameraItems property_name checkbox_value =
(
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			
			setUserProperty i ("BatchCameraRender_" + property_name) (checkbox_value as string)
			set_sub_item i (checkbox_value as string) property_name
		)
	)
)

-- general function to set checkbox value to user properties
fn set_checkbox_property_no_listview cameraItems property_name checkbox_value =
(
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			
			setUserProperty i ("BatchCameraRender_" + property_name) (checkbox_value as string)
		)
	)
)

--general function to set integer elements and display given integer value's name in listview
fn set_string_property cameraItems property_name string_value =
(
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			
			setUserProperty i ("BatchCameraRender_" + property_name) (string_value as string)
			set_sub_item i (string_value as string) property_name
		)
	)
)

--general function to set integer elements and display given integer value's name in listview
fn set_named_integer_property cameraItems property_name integer_value value_name=
(
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			
			setUserProperty i ("BatchCameraRender_" + property_name) (integer_value as string)
			set_sub_item i (value_name as string) property_name
		)
	)
)

--general function to set integer elements and display given integer value's name in listview
fn set_named_integer_property_no_listview cameraItems property_name integer_value =
(
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			
			setUserProperty i ("BatchCameraRender_" + property_name) (integer_value as string)
			-- set_sub_item i (value_name as string) property_name
		)
	)
)

--function to set frame size to selected cameras in listitems
fn set_resolution cameraItems width height =
(
	--cameraItems - listItems in activeX control
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			x_res = width as integer
			y_res = height as integer
			setUserProperty i "BatchCameraRender_frame_width" x_res
			setUserProperty i "BatchCameraRender_frame_heigth" y_res
			set_sub_item i ( x_res as string + " x " + y_res as string) "resolution"
			--compute and save new image aspect property
			image_aspect = (x_res as float)/(y_res as float)
			setUserProperty i "BatchCameraRender_image_aspect" image_aspect
			set_sub_item i (image_aspect as string) "image_aspect"			
		)
	)
)
--function to set frame size to selected cameras in listitems
fn set_resolution_by_ratio cameraItems x_ratio y_ratio =
(
	--cameraItems - listItems in activeX control
	for i in cameraItems do
	(
		if i.selected then
		(
			obj_itself = i.tag.value
			old_x_res = getUserProperty obj_itself "BatchCameraRender_frame_width"
			old_y_res = getUserProperty obj_itself "BatchCameraRender_frame_heigth"
			if (isNotUndefined old_y_res) and (isNotUndefined old_x_res) then
			(
				x_res = (old_x_res as integer )* x_ratio
				y_res = (old_y_res as integer)* y_ratio
				x_res = x_res as integer
				y_res = y_res as integer
				setUserProperty i "BatchCameraRender_frame_width" x_res
				setUserProperty i "BatchCameraRender_frame_heigth" y_res
				set_sub_item i ( x_res as string + " x " + y_res as string) "resolution"
			)
		)
	)
)

--function to set frame size to selected cameras in listitems
fn set_aspect_ratio cameraItems image_aspect =
(
	--cameraItems - listItems in activeX control
	for i in cameraItems do
	(
		if i.selected then
		(
			obj_itself = i.tag.value
			x_res = (getUserProperty obj_itself "BatchCameraRender_frame_width") as integer
			local y_res = undefined
			if (isNotUndefined x_res) then
			(				
				y_res = x_res / image_aspect
				y_res = y_res as integer
				setUserProperty i "BatchCameraRender_frame_heigth" y_res
			)
			if (y_res as integer) != undefined then
				set_sub_item i (x_res as string + " x " + y_res as string) "resolution"
			setUserProperty i "BatchCameraRender_image_aspect" image_aspect
			set_sub_item i (image_aspect as string) "image_aspect"	
		)
	)
)

--function to set frame size to selected cameras in listitems
fn set_resolution_width cameraItems width =
(
	--cameraItems - listItems in activeX control
	for i in cameraItems do
	(
		if i.selected then
		(
			obj_itself = i.tag.value
			x_res = getUserProperty obj_itself "BatchCameraRender_frame_width"
			y_res = getUserProperty obj_itself "BatchCameraRender_frame_heigth"
			image_aspect = getUserProperty obj_itself "BatchCameraRender_image_aspect"
			--if aspect is not saved in camera then compute it and save
			if (isUndefined image_aspect) then
			(
				--if width and height are given then compute overwise use 1.333
				if (isNotUndefined y_res) and (isNotUndefined x_res) then
					image_aspect =  (x_res as float) / (y_res as float)
				else
					image_aspect =  1.333
				setUserProperty i "BatchCameraRender_image_aspect" image_aspect
				set_sub_item i (image_aspect as string) "image_aspect"	
			)
			setUserProperty i "BatchCameraRender_frame_width" (width as integer)
			if Output_Size_Rollout.lock_aspect.checked then 
			(
				y_res = (width as float) / (image_aspect as float)
				y_res = ((dotnetclass "System.Math").Round y_res)	--apply dotnet rounding
				setUserProperty i "BatchCameraRender_frame_heigth" (y_res as integer)
			)
			else --if lock is not pressed
			(
				image_aspect =  (width as float) / (y_res as float)
				setUserProperty i "BatchCameraRender_image_aspect" image_aspect
				set_sub_item i (image_aspect as string) "image_aspect"					
			)
			
			if (width as integer) != undefined then
				set_sub_item i ((width as integer) as string + " x " + y_res as string) "resolution"
		)
	)
)

fn set_resolution_height cameraItems height =
(
	--cameraItems - listItems in activeX control
	for i in cameraItems do
	(
		if i.selected then
		(
			obj_itself = i.tag.value
			x_res = getUserProperty obj_itself "BatchCameraRender_frame_width"
			y_res = getUserProperty obj_itself "BatchCameraRender_frame_heigth"
			image_aspect = getUserProperty obj_itself "BatchCameraRender_image_aspect"
			--if aspect is not saved in camera then compute it and save
			if (isUndefined image_aspect) then
			(
				--if width and height are given then compute overwise use 1.333
				if (isNotUndefined y_res) and (isNotUndefined x_res) then
					image_aspect =  (x_res as float) / (y_res as float)
				else
					image_aspect =  1.333
				setUserProperty i "BatchCameraRender_image_aspect" image_aspect
				set_sub_item i (image_aspect as string) "image_aspect"	
			)
			setUserProperty i "BatchCameraRender_frame_heigth" (height as integer)
			if Output_Size_Rollout.lock_aspect.checked then 
			(
				x_res = (height as float) * (image_aspect as float)
				x_res = ((dotnetclass "System.Math").Round x_res)	--apply dotnet rounding
				setUserProperty i "BatchCameraRender_frame_width" (x_res as integer)
			)
			else --if lock is not pressed
			(
				image_aspect =  (x_res as float) / (height as float)
				setUserProperty i "BatchCameraRender_image_aspect" image_aspect
				set_sub_item i (image_aspect as string) "image_aspect"					
			)
			if (height as integer) != undefined then
				set_sub_item i ((x_res as integer) as string + " x " + (height as integer) as string) "resolution"
		)
	)
)

fn set_render_output cameraItems fullfilename=
(
	--cameraItems - listItems in activeX control
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			
			fullfilename = pathConfig.convertPathToAbsolute fullfilename
			setUserProperty i "BatchCameraRender_render_output" (fullfilename as string)
			set_sub_item i (fullfilename as string) "path"
		)
	)
)

fn set_elements_state cameraItems elements_state=
(
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			
			setUserProperty i "BatchCameraRender_elements_state" (elements_state as string)
			set_sub_item i (elements_state as string) "elements_state"
		)
	)
)

fn set_elements_path cameraItems elementsPath=
(
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			
			elementsPath = trimLeadTrailSpaces elementsPath
-- 			elementsPath = pathConfig.convertPathToRelativeTo elementsPath ""
			if not (pathConfig.isLegalPath elementsPath) then 
				elementsPath="" 
			else
				elementsPath = pathConfig.appendPath elementsPath ""

			setUserProperty i "BatchCameraRender_elements_output" (elementsPath as string)
			set_sub_item i (elementsPath as string) "elements_path"
		)
	)
)

fn set_render_folder cameraItems foldername=
(
	--cameraItems - listItems in activeX control
	for i in cameraItems do
	(
		if i.selected then
		(
			obj_itself = i.tag.value
			temp_string = getUserProperty obj_itself "BatchCameraRender_render_output"
			--get path from function parameters
			temp_path = foldername
			--trim leading and trailing spaces
			temp_path = trimLeadTrailSpaces temp_path

			if isNotUndefined temp_string then
			(
				--get name from camera properties
				temp_name = filenameFromPath temp_string			--exclude file name
				temp_fullname = pathConfig.appendPath temp_path temp_name	--append new folder path to the file name
-- 				temp_fullname = pathConfig.convertPathToAbsolute temp_fullname
				
				setUserProperty i "BatchCameraRender_render_output" (temp_fullname as string)
				set_sub_item i (temp_fullname as string) "path"
			)
		)
	)
)

fn set_render_file cameraItems file_name_only=
(
	--cameraItems - listItems in activeX control
	for i in cameraItems do
	(
		if i.selected then
		(
			obj_itself = i.tag.value
			temp_string = getUserProperty obj_itself "BatchCameraRender_render_output"	--full path from camera object
			--get name from function parameters
			temp_name = filenameFromPath file_name_only	--exclude file name from function argument, in case file path given along with file name
			
			if isNotUndefined temp_string then
			(
				--get path from camera properties
				temp_path = getFilenamePath temp_string	--exclude path from full name

				temp_fullname = pathConfig.appendPath temp_path temp_name	--create new full name with path and file name from function argument
-- 				temp_fullname = pathConfig.convertPathToAbsolute temp_fullname
				
				setUserProperty i "BatchCameraRender_render_output" (temp_fullname as string)
				set_sub_item i (temp_fullname as string) "path"
			)
		)
	)
)

--Function to set frame range to camera objects
--Frame range
fn set_frame_range cameraItems frame_from frame_to=
(
	--cameraItems - listItems in activeX control
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			frame_from = frame_from as integer
			frame_to = frame_to as integer
			setUserProperty i "BatchCameraRender_anim_frame_range" undefined
			setUserProperty i "BatchCameraRender_framerange_from" frame_from
			setUserProperty i "BatchCameraRender_framerange_to" frame_to
			setUserProperty i "BatchCameraRender_frames" undefined
			set_sub_item i (frame_from as string + "..." + frame_to as string) "frames"
		)
	)
)

--Single frame
fn set_frame_single cameraItems frame_num =
(
	--cameraItems - listItems in activeX control
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			frame_from = frame_num as integer
			frame_to = frame_num as integer
			setUserProperty i "BatchCameraRender_anim_frame_range" undefined
			setUserProperty i "BatchCameraRender_framerange_from" frame_from
			setUserProperty i "BatchCameraRender_framerange_to" frame_to
			setUserProperty i "BatchCameraRender_frames" undefined
			set_sub_item i (frame_from as string) "frames"
		)
	)
)

--animated frame range
fn set_anim_frame_range cameraItems =
(
	--cameraItems - listItems in activeX control
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			obj_itself = i.tag.value
			if (superclassof obj_itself == camera) then
			(
				temp_frame_range = get_key_range obj_itself
				frame_from = temp_frame_range[1].frame
				frame_to = temp_frame_range[2].frame
				setUserProperty i "BatchCameraRender_anim_frame_range" true
				setUserProperty i "BatchCameraRender_framerange_from" undefined
				setUserProperty i "BatchCameraRender_framerange_to" undefined
				setUserProperty i "BatchCameraRender_frames" undefined
				set_sub_item i ("anim.range:" + (frame_from as integer) as string + "..." + (frame_to as integer) as string) "frames"
				
				Frame_Range_Rollout.render_anim_from.text = (temp_frame_range[1].frame as integer) as string
				Frame_Range_Rollout.render_anim_to.text = (temp_frame_range[2].frame as integer) as string
			)
		)
	)
)

--set frames string to render individual frames
fn set_frames cameraItems frames =
(
	--cameraItems - listItems in activeX control
	for i in cameraItems do
	(
		if i.selected then
		(
			-- obj_name = i.text
			-- obj_itself = getNodeByName obj_name
			setUserProperty i "BatchCameraRender_anim_frame_range" undefined
			setUserProperty i "BatchCameraRender_frames" frames  as string
			setUserProperty i "BatchCameraRender_framerange_from" undefined
			setUserProperty i "BatchCameraRender_framerange_to" undefined
			set_sub_item i (frames as string) "frames"
		)
	)
)

--function to store light state to the camera properties
fn set_light_state cameraItems: solo_lights: on_lights: off_lights: =
(
	for i in cameraItems do
	(
		if i.selected then
		(
			tempstr = "" --this string contains light names
			-- obj_name = i.text	--this is camera name
			-- obj_itself = getNodeByName obj_name --get the camera to set properties to
			
			if solo_lights != unsupplied then
			(
				for str in solo_lights do
				(
					if tempstr.count != 0 then --if string is empty don't add comma
						tempstr = tempstr + "," + str as string 
					else
						tempstr = tempstr + str as string
				)
				setUserProperty i "BatchCameraRender_solo_lights" tempstr
				
				if tempstr == "undefined" then
					clear_sub_item i "solo_lights"
				else
					set_sub_item i (tempstr as string) "solo_lights"
			)
			if on_lights != unsupplied then
			(
				for str in on_lights do
				(
					if tempstr.count != 0 then
						tempstr = tempstr + "," + str as string
					else
						tempstr = tempstr + str as string
				)
				setUserProperty i "BatchCameraRender_on_lights" tempstr
				
				if tempstr == "undefined" then
					clear_sub_item i "on_lights"
				else
					set_sub_item i (tempstr as string) "on_lights"
			)
			if off_lights != unsupplied then
			(
				for str in off_lights do
				(
					if tempstr.count != 0 then
						tempstr = tempstr + "," + str as string
					else
						tempstr = tempstr + str as string
				)
				setUserProperty i "BatchCameraRender_off_lights" tempstr
				
				if tempstr == "undefined" then
					clear_sub_item i "off_lights"
				else
					set_sub_item i (tempstr as string) "off_lights"
			)
		)
	)	
)