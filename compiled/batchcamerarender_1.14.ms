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
-- tested using Max 2009, Max 2010, Max 2011, Max 2012, Max 2016
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
local isDialogOpen = false    --variable to save main window open/close state
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
batchCamPreview = false --if the rendering is preview
global_found_ini_file_paths = #()
global_listview_height = 170
--listView items array
LV_ITEMS = #()
--default vray image file saving state
SAVE_VRAY_IMAGE_FILE_STATE = false
--script version
VERSION_STRING = "1.14"

BatchCam_CommonPropertiesNames = #("frames", "framerange_from", "framerange_to", "anim_frame_range", "frame_width", "frame_heigth", "render_output", \
                          "elements_state", "not_save_elements", "elements_output", "solo_lights", "on_lights", "off_lights", "scene_state", "state_set", "render_preset", "image_aspect", \
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
global BatchCam_rollout_state; if BatchCam_rollout_state == undefined then BatchCam_rollout_state = #(  true, false, \
                                                                          true , true, true, \
                                                                          false, false, false, \
                                                                          false, false
                                                                          )
                                                                          
global BatchCam_rollout_names; if BatchCam_rollout_names == undefined then BatchCam_rollout_names = #(  "batchCameraRender_mainRollOut", "Net_Render_Options_Rollout", \
                                                                            "Output_Size_Rollout" , "Frame_Range_Rollout", "Render_Output_Rollout", \
                                                                            "Vray_Settings_Rollout", "Scene_States_Rollout", "Scripts_Rollout", "Light_Assignement_Rollout", \
                                                                            "aboutRoll"
                                                                          )
global BatchCam_listItem_state
--########################--
--end of session-wide persistent variables
--########################--

--########################--
--FUNCTIONS for batch camera render script
--########################--
--
fn CompileDotNet src =
(
  local csharpProvider = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
  local compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"
  compilerParams.ReferencedAssemblies.AddRange #("System.dll", "System.Windows.Forms.dll")
  compilerParams.GenerateInMemory = true
  local compilerResults = csharpProvider.CompileAssemblyFromSource compilerParams #(src)
  if (compilerResults.Errors.Count > 0 ) then
  (
    local errs = stringstream ""
    for i = 0 to (compilerResults.Errors.Count-1) do
    (
      err = compilerResults.Errors.Item[i]
      format "Error:% Line:% Column:% %\n" err.ErrorNumber err.Line err.Column err.ErrorText to:errs 
    )
    format "Errors encountered while compiling C# code\n" errs
    format "%\n" errs
  )
)

fn CreateNativeWindowOps =
(
  local source ="
  using System;
  using System.Windows.Forms;
  public class WindowHook : NativeWindow
  {
    private const int WM_COMMAND = 0x0111;
    
    public event EventHandler WmCommand;
    
    protected override void WndProc(ref Message m)
    {
      switch (m.Msg)
      {
        case WM_COMMAND:
        this.ReleaseHandle();
        if (this.WmCommand != null) this.WmCommand(this, EventArgs.Empty);
        break;
      }
      base.WndProc(ref m);
    }
  }
  "
  CompileDotNet source
)

fn CreatePostNotifier =
(
  local source = "
  using System;
  using System.Windows.Forms;
  using System.Threading;
  public class PostNotifier
  {
    public event EventHandler PostEvent;
    public void PostNotify() {
      SynchronizationContext.Current.Post(delegate(object x) { if (this.PostEvent != null) this.PostEvent(this, EventArgs.Empty); }, null);
      //SynchronizationContext.Current.Post(delegate(object x) { Application.RaiseIdle(EventArgs.Empty); }, null);
    }
  }"

  CompileDotNet source
)

isVrayRenderer
fn shouldBeSaved = 
(
  local result = false

  if (isVrayRenderer()) then
    result = (not batchCamPreview) and (Render_Output_Rollout.save_file.checked or Vray_Settings_Rollout.save_vray_image_file.checked)
  else
    result = (not batchCamPreview) and (Render_Output_Rollout.save_file.checked)
    
  result
)

--function adds subitem to list item and makes it style active or inactive
fn  add_sub_item listItem subitem_value subitem_name active_state =
(
  sub_item = undefined
  if active_state then
  (
    sub_item = listItem.SubItems.add (subitem_value as string)
    sub_item.ForeColor = sub_item.ForeColor.Black
    sub_item.Font = dotnetobject "System.Drawing.Font" sub_item.Font (dotnetclass "System.Drawing.FontStyle").Regular
  )
  else
  (
    sub_item = listItem.SubItems.add ("undefined")
    sub_item.ForeColor = sub_item.ForeColor.LightGray
    sub_item.Font = dotnetobject "System.Drawing.Font" sub_item.Font (dotnetclass "System.Drawing.FontStyle").Italic
  )
  sub_item.name = subitem_name
)

fn set_sub_item listItem subitem_value subitem_name=
(
  sub_item = listItem.SubItems.Item subitem_name
  sub_item.text = subitem_value
  sub_item.ForeColor = sub_item.ForeColor.Black
  sub_item.Font = dotnetobject "System.Drawing.Font" sub_item.Font (dotnetclass "System.Drawing.FontStyle").Regular
)

fn clear_sub_item listItem subitem_name=
(
  sub_item = listItem.SubItems.Item subitem_name
  sub_item.text = "undefined"
  sub_item.ForeColor = sub_item.ForeColor.LightGray
  sub_item.Font = dotnetobject "System.Drawing.Font" sub_item.Font (dotnetclass "System.Drawing.FontStyle").Italic
)

fn get_camera_list = 
(
  local camera_array = #()
  local camera_list = for obj in cameras where iskindof obj camera collect obj
  for cam in camera_list do
  (
    append camera_array cam
    for attr in cam.baseobject.custattributes do
    (
      if attr.name == "BatchCamAttr" then
        append camera_array (attr)
    )
  )

  camera_array
)

fn trimLeadTrailSpaces path_string =
(
  path_string  = trimRight path_string  " "
  path_string = trimLeft path_string " "
  path_string 
)

fn isNotUndefinedOrEmpty var = 
(
  result = true
  
  if var == undefined then
    result = false
  else if (trimleft (var as string) " ") == "" then
    result = false
  result
)

fn isNotUndefined var = 
(
  result = true
  if var != undefined and var != "undefined" and var != "" then
--  if (isNotUndefinedOrEmpty var) and var != "undefined" then
    result = true
  else
    result = false
  result
)

fn isUndefined var = 
(
  result = true
  if var == undefined or var == "undefined" or var == "" then
--  if (not isNotUndefinedOrEmpty var)  or var == "undefined" then
    result = true
  else
    result = false
  result
)


fn get_render_preset_array =
(
  render_preset_array = #()
  if (maxVersion())[1] >= 11000 then  --run renderPresetMRUList command only if script is running under 3dsmax 2009+
    render_preset_array = for i in renderPresetMRUList where (i[1]!="") collect i[1]
  sort render_preset_array
  render_preset_array 
)

fn get_scene_state_array =
(
  scenestate_count = sceneStateMgr.GetCount()
  scenestate_array = for i=1 to scenestate_count collect ((sceneStateMgr.GetSceneState i) as string)
  sort scenestate_array
  scenestate_array 
)

fn get_state_sets_array =
(
  local stateSetsDotNetObject = dotNetObject "Autodesk.Max.StateSets.Plugin"
  local stateSets = stateSetsDotNetObject.Instance
  local masterState = stateSets.EntityManager.RootEntity.MasterStateSet
  local statesList = dotnetobject "System.Collections.Generic.List`1[[Autodesk.Max.StateSets.Entities.StateSets.StateSet, Autodesk.Max.StateSets, Version=19.51.835.0, Culture=neutral, PublicKeyToken=null]]"
  masterState.CollectDescendantStateSets statesList
  local scenestate_count = masterState.DescendantStateCount
  local scenestate_array = for i=1 to scenestate_count where not (statesList.item[i-1].IsObjectStateSet) collect ((statesList.item[i-1].Name) as string)
  sort scenestate_array
  scenestate_array 
)

struct BatchCameraRenderParamsStruct
(
    BatchCameraRender_frames,
    BatchCameraRender_framerange_from,
    BatchCameraRender_framerange_to,  
    BatchCameraRender_anim_frame_range,
    BatchCameraRender_frame_width,
    BatchCameraRender_frame_heigth,
    BatchCameraRender_render_output,
    BatchCameraRender_elements_state,
    BatchCameraRender_not_save_elements,
    BatchCameraRender_elements_output,
    BatchCameraRender_solo_lights,
    BatchCameraRender_on_lights,
    BatchCameraRender_off_lights,
    BatchCameraRender_scene_state,
    BatchCameraRender_render_preset,
    BatchCameraRender_irmap_mode,
    BatchCameraRender_auto_save_irmap,
    BatchCameraRender_auto_switch_irmap,
    BatchCameraRender_irmap_read_file,
    BatchCameraRender_irmap_save_file,
    BatchCameraRender_lcmap_mode,
    BatchCameraRender_auto_save_lcmap,
    BatchCameraRender_auto_switch_lcmap,
    BatchCameraRender_lcmap_read_file,
    BatchCameraRender_lcmap_save_file,
    BatchCameraRender_prerender_script,
    BatchCameraRender_prerender_enabled,
    BatchCameraRender_postrender_script,
    BatchCameraRender_postrender_enabled,
    BatchCameraRender_image_aspect,
    BatchCameraRender_region_enabled,
    BatchCameraRender_region_x,
    BatchCameraRender_region_y,
    BatchCameraRender_region_w,
    BatchCameraRender_region_h,
    BatchCameraRender_perCameraScriptEnable,
    BatchCameraRender_perCameraScript
)
--function to save variable to ini file
fn saveVar2IniFile section_name var_name var_value local_path: = 
(
  INIFileDir = ""
  if (local_path != unsupplied) then
    INIFileDir = local_path
  else
    INIFileDir = ((getdir #plugcfg) + "\\BatchCameraRender\\")
  if (getDirectories INIFileDir).count == 0 then makeDir INIFileDir
  INIFilename = pathConfig.appendPath INIFileDir "BatchCameraRender.ini"
  setINISetting INIFilename section_name var_name (var_value as string)
)

--function to load variable to ini file
fn loadVarFromIniFile section_name var_name local_path: = 
(
  INIFileDir = ""
  if (local_path == unsupplied) then
    INIFileDir = ((getdir #plugcfg) + "\\BatchCameraRender\\")
  else
    INIFileDir = local_path
    
  INIFilename = pathConfig.appendPath INIFileDir "BatchCameraRender.ini"
  temp_value = getINISetting INIFilename section_name var_name
  if temp_value == "" then undefined else temp_value
)

fn propName2Id property_name =
(
  property_id = 0
  case property_name of
  (
    "BatchCameraRender_frames":         property_id = 7801
    "BatchCameraRender_framerange_from":    property_id = 7802
    "BatchCameraRender_framerange_to":      property_id = 7803
    "BatchCameraRender_anim_frame_range":   property_id = 7804
    "BatchCameraRender_frame_width":        property_id = 7805
    "BatchCameraRender_frame_heigth":     property_id = 7806
    "BatchCameraRender_render_output":      property_id = 7807
    "BatchCameraRender_elements_state":     property_id = 7808
    "BatchCameraRender_not_save_elements":	property_id = 78081
    "BatchCameraRender_elements_output":    property_id = 7809
    "BatchCameraRender_solo_lights":        property_id = 7810
    "BatchCameraRender_on_lights":          property_id = 7811
    "BatchCameraRender_off_lights":         property_id = 7812
    "BatchCameraRender_scene_state":        property_id = 7813
    "BatchCameraRender_render_preset":      property_id = 7814
    "BatchCameraRender_irmap_mode":       property_id = 7815
    "BatchCameraRender_auto_save_irmap":    property_id = 7816
    "BatchCameraRender_auto_switch_irmap":  property_id = 7817
    "BatchCameraRender_irmap_read_file":      property_id = 7818
    "BatchCameraRender_irmap_save_file":      property_id = 7819
    "BatchCameraRender_lcmap_mode":       property_id = 7820
    "BatchCameraRender_auto_save_lcmap":    property_id = 7821
    "BatchCameraRender_auto_switch_lcmap":  property_id = 7822
    "BatchCameraRender_lcmap_read_file":      property_id = 7823
    "BatchCameraRender_lcmap_save_file":    property_id = 7824
    "BatchCameraRender_prerender_script":   property_id = 7825
    "BatchCameraRender_prerender_enabled":    property_id = 7826
    "BatchCameraRender_postrender_script":    property_id = 7827
    "BatchCameraRender_postrender_enabled": property_id = 7828
    "BatchCameraRender_image_aspect":     property_id = 7829
    
    "BatchCameraRender_UserKey1":         property_id = 7830
    "BatchCameraRender_UserKey2":         property_id = 7831
    "BatchCameraRender_UserKey3":         property_id = 7832    
    
    "BatchCameraRender_UserVal1":         property_id = 7833
    "BatchCameraRender_UserVal2":         property_id = 7834
    "BatchCameraRender_UserVal3":         property_id = 7835
    
    "BatchCameraRender_bbJobName":        property_id = 7836
    "BatchCameraRender_elementName":      property_id = 7837
    
    "BatchCameraRender_OnSubmitScriptEnable": property_id = 7838
    "BatchCameraRender_OnSubmitScript":       property_id = 7839    
    "BatchCameraRender_perCameraScriptEnable":  property_id = 7840
    "BatchCameraRender_perCameraScript":      property_id = 7841
    
    "BatchCameraRender_lastRenderPath":   property_id = 7842
    
    "BatchCameraRender_vray_ortho_mode":    property_id = 7844
    "BatchCameraRender_item_index":   property_id = 7845
    
    "BatchCameraRender_region_enabled":   property_id = 7846
    "BatchCameraRender_region_x":   property_id = 7847
    "BatchCameraRender_region_y":   property_id = 7848
    "BatchCameraRender_region_w":   property_id = 7849
    "BatchCameraRender_region_h":   property_id = 7850

    "BatchCameraRender_state_set":    property_id = 7851
  )
  property_id
)

-- setUserProp function wrapper to set dirty flag everytime user properties are affected by script
fn setUserProperty list_item property_name property_value=
(
--  format "obj_itself:% property_name:% property_value:%\n" obj_itself property_name property_value
  setAppData (list_item.tag.value) (propName2Id property_name) (property_value as string)
  setSaveRequired true --set dirt flag after setting each user property
)

--temporary helper functions
--used to correctly assign default values
fn getUserPropertyFromObject obj_itself property_name=
(
  property_value = getAppData obj_itself (propName2Id property_name)
  property_value
)

fn isFrameRangeProperty property_name=
(
  if ((property_name == "BatchCameraRender_frames") or (property_name == "BatchCameraRender_framerange_from") or \
  (property_name == "BatchCameraRender_framerange_to")  or (property_name == "BatchCameraRender_anim_frame_range")) then true else false 
)

fn isFrameRangeUndefined camera_object=
(
  temp_string1 = getUserPropertyFromObject camera_object "BatchCameraRender_frames"
  temp_string2 = getUserPropertyFromObject camera_object "BatchCameraRender_framerange_from"
  temp_string3 = getUserPropertyFromObject camera_object "BatchCameraRender_framerange_to"
  temp_string5 = getUserPropertyFromObject camera_object "BatchCameraRender_anim_frame_range"
  
  if (isUndefined temp_string1) and (isUndefined temp_string2) and (isUndefined temp_string3) and (isUndefined temp_string5) then true else false
)
--endof temp functions. will remove them in version 2.x

fn setRootNodeData property_name property_value =
(
  if (isNotUndefinedOrEmpty (property_value as string)) then
    setAppData rootNode (propName2Id property_name) (property_value as string)
  else
    setAppData rootNode (propName2Id property_name) ""
  setSaveRequired true --set dirt flag after setting each user property
)

fn getRootNodeData property_name =
(
  data_string = ""
  data_string = batchCameraRender_getUserProperty rootNode property_name  --user standard function to add default settings ability to rootnode data
  data_string
)

fn getCameraFromCA ca_obj =
(
  local cam_obj = undefined
  if (superclassof ca_obj == AttributeDef) then
  (
    local base_obj = custattributes.getowner ca_obj
    local dep_objs = refs.dependentNodes base_obj
    if (dep_objs.count > 0) then
    (
      local temp_cam = dep_objs[1]
      if (superclassof temp_cam == camera) then
      cam_obj = temp_cam
    )
  )
  else
  (
    cam_obj = ca_obj
  )
  cam_obj
)

fn getPresetName preset_obj =
(
  local result_name = undefined
  if (superclassof preset_obj == camera) then
  (
    result_name = preset_obj.name
  )
  else
  (
    local cam_obj = getCameraFromCA preset_obj
    local preset_index = 0
    local found_obj = undefined
    for obj in cam_obj.baseobject.custattributes while found_obj == undefined do
    (
      preset_index += 1
      local num_str = formattedPrint preset_index format:"03d"
      if (obj == preset_obj) then
      (
        result_name = cam_obj.name + "_preset_" + num_str
      )
    )
  )
  result_name
)

--parser function
--replaces special keywords in string with values from argument dictionary
--dictionary syntax is (keyword, value)
--sample dictionary:
/* param_dictionary = #(
  #("cameraname", "CAMERANAME"),
  #("scenestate", "SCENESTATE"),
  #("resolution", "RESOLUTION"),
  #("date", "DATE"),
  #("var:varname", "VARNAME"),
  #("scenename", "SCENENAME")
  #("projectfolder", "PROJECTNAME")
) */
fn do_modify in_string replace_start replace_end replace_text=
(
  keyword = (substring in_string replace_start replace_end)
--  format "keyword: %\n" keyword
  if keyword == "%up%" then
  (
    --handle %up% keyword
    --remove leaf from the path to point it to upper folder
    currentPath = substring in_string 1 (replace_start - 1)
--    format "currentPath: %\n" currentPath
    if ((pathConfig.isLegalPath currentPath) and (not (pathConfig.isRootPath currentPath))) do
      currentPath = pathConfig.removePathLeaf currentPath     --replace old path with new, truncated one.
    in_string = currentPath + (substring in_string (replace_start + keyword.count) -1)
--    format "in_string: %, currentPath: %\n" in_string currentPath
  )
  else
  (
--    format "in_string: %, replace_text: %\n" in_string replace_text
    in_string = replace in_string replace_start replace_end replace_text  --replace keyword with word from dictionary
  )
  in_string
)

fn parse_file_name_template input_string dictionary = 
(
  found_count = 0
  found_any = false
  result_substring = input_string 
  i_emergency = 0 --emergency counter - some sort of emergency stop in case of infinite loop :)
  do
  (
    i_emergency += 1
    keyword_start = findString result_substring "%"   --search for start of the keyword
    if keyword_start != undefined then
    (
      keyword_substring = substring result_substring (keyword_start+1) -1   -- remaining of the string possibly with keyword 
      keyword_end = findString keyword_substring "%"  --search for end of the keyword
      found_any = true
      found_count += 1
        if keyword_end != undefined then
        (
          found_count += 1
          keyword = substring keyword_substring 1 (keyword_end-1) --exclude the keyword - since we using substring here, keyword is always as start of the string
--          format "keyword: %\n" keyword

          --replace keyword with actual value
          --get keywords and values from argument dictionary
          was_found = false --this flag remains false if none of the dictionary keywords would not equal to template keyword
          for i=1 to dictionary.count do
          (
            if keyword == dictionary[i][1] then
            (
              was_found = true  --set flag to true if keyword is found
--              format "string: %, keyword: % \n" result_substring dictionary[i][2]
              result_substring = do_modify result_substring keyword_start (keyword_end+1) dictionary[i][2]  --replace keyword with word from dictionary
            )
          )
          
          if not was_found then --if flag is not raised then replace quoted keyword with unquoted keyword
          (
            result_substring = replace result_substring keyword_start (keyword_end+1) keyword
          )
        )
        else
        (
          found_any = false --exit loop if end of keyword not found
          -- here delete trailing %-char
          --add template error warning
        )
    )
    else
    (
      found_any = false
    )
--    format "i_emergency: %\n" i_emergency
  )
  while (found_any and not i_emergency > 100 )  --proceed with the loop until start or end are found 
                                --or more then 100 "%" characters found
--  print result_substring
  result_substring
)

fn exec_user_val userValue=
(
  result = ""
  try
  (
    if userValue[1] == "@" then
      result = substring userValue 2 (userValue.count-1)
    else
      result = execute (userValue as string)
  )
  catch
  (
    result = "ErrUserVal"
  )
  (result as string)
)

fn compose_user_dictionary =
(
  parsing_dictionary = #()
    --user-defined keywords
  userKeyword = getRootNodeData "BatchCameraRender_UserKey1"-- getAppData rootnode (propName2Id "BatchCameraRender_UserKey1")
  userValue = getRootNodeData "BatchCameraRender_UserVal1" --getAppData rootnode (propName2Id "BatchCameraRender_UserKey1")
  if isNotUndefinedOrEmpty userKeyword then
    append parsing_dictionary #( (userKeyword as string), (exec_user_val userValue) )
  
  userKeyword = getRootNodeData "BatchCameraRender_UserKey2"-- getAppData rootnode (propName2Id "BatchCameraRender_UserKey1")
  userValue = getRootNodeData "BatchCameraRender_UserVal2" --getAppData rootnode (propName2Id "BatchCameraRender_UserKey1")
  if isNotUndefinedOrEmpty userKeyword then
    append parsing_dictionary #( (userKeyword as string), (exec_user_val userValue) )
  
  userKeyword = getRootNodeData "BatchCameraRender_UserKey3"-- getAppData rootnode (propName2Id "BatchCameraRender_UserKey1")
  userValue = getRootNodeData "BatchCameraRender_UserVal3" --getAppData rootnode (propName2Id "BatchCameraRender_UserKey1")
  if isNotUndefinedOrEmpty userKeyword then
    append parsing_dictionary #( (userKeyword as string), (exec_user_val userValue) )
  
  parsing_dictionary
)
--function to compute global keywords, not realting to any camera object
fn compose_global_dictionary =
(
  local parsing_dictionary = #()
  
  --date keyword
  dateClass = (dotnetclass "System.DateTime").Now
  date_string = dateClass.ToString("yyyy-MM-dd")
  append parsing_dictionary #("date", date_string)
  --scenename keyword
  scenename_string = getFilenameFile maxFileName
  append parsing_dictionary #("scenename", scenename_string)
  --project name keyword
  projectfolder_string = pathConfig.getCurrentProjectFolder()
  append parsing_dictionary #("projectfolder", projectfolder_string)
  append parsing_dictionary #("projectpath", projectfolder_string)
  local projectname_string = pathConfig.getCurrentProjectFolder()
  if (doesFileExist projectname_string) then
    projectname_string = pathConfig.stripPathToLeaf projectname_string
  append parsing_dictionary #("projectname", projectname_string)
--  scene path keyword
  scenepath_string = maxFilePath
  scenepath_string = substring scenepath_string 1 (scenepath_string.count-1)
  append parsing_dictionary #("scenefolder", scenepath_string)
  append parsing_dictionary #("scenepath", scenepath_string)
  append parsing_dictionary #("up", "") --added to dictionary just to have parsing function call do_modify method - this keyword handling happens there.
  append parsing_dictionary #("trynum", (Net_Render_Options_Rollout.Try_Counter.value) as string)

  parsing_dictionary
)

--function to compute camera-related keywords
fn compose_parsing_dictionary camera_obj extraItems: = 
(
  --compose parsing dictionary for given camera
  local parsing_dictionary = #()
  
  join parsing_dictionary (compose_global_dictionary())
  
  join parsing_dictionary (compose_user_dictionary())
  
  --append extra items first. they should not be the same as the ones computed in this function
  if extraItems != unsupplied then
  (
    if (classof extraItems) == Array then
    (
      for item in extraItems do
        append parsing_dictionary item
    )
  )
  --camername keyword
  local preset_name = getPresetName camera_obj
  append parsing_dictionary #("presetname", preset_name)
  local cam_obj = getCameraFromCA camera_obj
  append parsing_dictionary #("cameraname", ((cam_obj.name) as string))
  --scenestate keyword
  append parsing_dictionary #("scenestate", ((batchCameraRender_getUserProperty camera_obj "BatchCameraRender_scene_state") as string))
  --state_sets
  append parsing_dictionary #("stateset", ((batchCameraRender_getUserProperty camera_obj "BatchCameraRender_state_set") as string))
  --renderpreset keyword
  append parsing_dictionary #("renderpreset", ((batchCameraRender_getUserProperty camera_obj "BatchCameraRender_render_preset") as string))
  --resolution keyword
  xres_prop = batchCameraRender_getUserProperty camera_obj "BatchCameraRender_frame_width"
  yres_prop = batchCameraRender_getUserProperty camera_obj "BatchCameraRender_frame_heigth"
  resolution_string = (xres_prop as string + "x" + yres_prop as string )
  append parsing_dictionary #("resolution", resolution_string)

--  print parsing_dictionary
  parsing_dictionary
)

--function to compute camera-related keywords. Computes render output. Should not be used in output path properties.
fn compose_full_parsing_dictionary camera_obj extraItems: = 
(
  local parsing_dictionary = #()
  
  join parsing_dictionary (compose_parsing_dictionary camera_obj)
  
  --append extra items first. they should not be the same as the ones computed in this function
  if extraItems != unsupplied then
  (
    if (classof extraItems) == Array then
    (
      for item in extraItems do
        append parsing_dictionary item
    )
  )
  
  mainoutput = batchCameraRender_getUserProperty camera_obj "BatchCameraRender_render_output"
  if isNotUndefined mainoutput then
    mainoutput = parse_file_name_template mainoutput parsing_dictionary --parse it by using usual dictionary
  else
    mainoutput = "mainoutput"
  
  --exclude filename only
  mainFileNameOnly = getFilenameFile mainOutput
  --exclude path onle
  mainPath = getFilenamePath mainOutput
  
  append parsing_dictionary #("mainoutput", mainFileNameOnly)
  append parsing_dictionary #("renderfile", mainFileNameOnly) 
  append parsing_dictionary #("mainpath", mainPath)
  append parsing_dictionary #("renderpath", mainPath)
  
  parsing_dictionary
)

fn getDefaultFrameRangeValue camera_object property_name = 
(
  result_value = undefined
  
  localINI_path = maxFilePath
  if localINI_path != "" then
  (
    found_value = false
    while (not found_value) and (localINI_path != "") do
    (
      localINI_file = pathConfig.appendPath localINI_path "BatchCameraRender.ini"
      if (doesFileExist localINI_file) then
      (
        --get the framerange value from the local ini file.
        framerange_data1 = loadVarFromIniFile "Default Settings" "BatchCameraRender_frames"        local_path:localINI_path
        framerange_data2 = loadVarFromIniFile "Default Settings" "BatchCameraRender_framerange_from"   local_path:localINI_path 
        framerange_data3 = loadVarFromIniFile "Default Settings" "BatchCameraRender_framerange_to"     local_path:localINI_path 
        framerange_data4 = loadVarFromIniFile "Default Settings" "BatchCameraRender_anim_frame_range"  local_path:localINI_path
        
        found_value = case of
        (
          (isNotUndefined framerange_data1): true
          (isNotUndefined framerange_data2): true
          (isNotUndefined framerange_data3): true
          (isNotUndefined framerange_data4): true
          default: false
        )
        if (found_value) then
          result_value = loadVarFromIniFile "Default Settings" property_name local_path:localINI_path
      )
      if (not found_value) then
        localINI_path = pathConfig.removePathLeaf localINI_path --move to upper folder if ini file not found OR value in found ini file not found
    )
    if (not found_value) then
      result_value = loadVarFromIniFile "Default Settings" property_name
  )
  else  --if local path is invalid
    result_value = loadVarFromIniFile "Default Settings" property_name

  result_value
)

--get default value for the property from the global or local ini files
fn getDefaultValue camera_object property_name = 
(
  result_value = undefined
  global_found_ini_file_paths = #()
  --try to find local ini file recursively starting from scene folder and down to root folder.
  --check each file if it contains default value
  --if none of them contains default value, fall to the global ini file
  localINI_path = maxFilePath
  if localINI_path != "" then
  (
    found_value = false
    while (not found_value) and (localINI_path != "") do
    (
      localINI_file = pathConfig.appendPath localINI_path "BatchCameraRender.ini"
      if (doesFileExist localINI_file) then
      (
        appendIfUnique global_found_ini_file_paths localINI_file
        result_value = loadVarFromIniFile "Default Settings" property_name local_path:localINI_path
        if (isNotUndefined result_value) then
          found_value = true
      )
      if (not found_value) then
        localINI_path = pathConfig.removePathLeaf localINI_path --move to upper folder if ini file not found OR value in found ini file not found
    )
    if (not found_value) then
      result_value = loadVarFromIniFile "Default Settings" property_name
  )
  else
    result_value = loadVarFromIniFile "Default Settings" property_name

  Net_Render_Options_Rollout.found_local_ini_files.items = global_found_ini_file_paths
  result_value
)

--getUserProp wrapper to change property saving mechanism in future
--to change it from user properties to appdata
--also added default value mechanism
fn getUserProperty camera_object property_name=
(
  if (camera_object != undefined) then
  (
    property_value = getAppData camera_object (propName2Id property_name)
    
    if (isUndefined property_value) then --try to read default setting from the INI file.
    (
      --if the property is frame range property check all other frame range properties and only if all that properties are undefined return default property.
      if (isFrameRangeProperty property_name) then
      (
        if (isFrameRangeUndefined camera_object) then --if frame range is undefined in object's data get it from the default
          property_value = getDefaultFrameRangeValue camera_object property_name
      )
      else
        property_value = getDefaultValue camera_object property_name
    )
    (if (isNotUndefined property_value) then property_value else undefined)
  )
)
batchCameraRender_getUserProperty = getUserProperty

-- batchCameraRender_getRootNodeData = getRootNodeData

fn saveDefaultValues camera_object property_names =
(
  try
    ini_file_name = getSaveFileName caption:"INI File Name" filename:"BatchCameraRender.ini" types:"INI files (*.ini)|*.ini|All files (*.*)|*.*|" historyCategory:"Scripts"
  catch (getCurrentException())
  
  if ini_file_name != undefined then
  (
    ini_file_path = getFilenamePath ini_file_name
    for property_name in property_names do
    (
      property_value = getUserProperty camera_object property_name
      saveVar2IniFile "Default Settings" property_name (property_value as string) local_path:ini_file_path
    )
  )
)

--returns true if current renderer is Vray
fn isVrayRenderer =
(
  (findString ((classof (renderers.current)) as string) "v_ray") != undefined
)

fn isPathAbsolute path_string =
(
  pathConfig.isUncPath path_string or  pathConfig.isPathRootedAtDriveLetter path_string
)

--function to switch render buttons' activity state
fn render_buttons_active state =
(
  --main section
  batchCameraRender_mainRollOut.render_start.enabled = state
  batchCameraRender_mainRollOut.net_render.enabled = state
  batchCameraRender_mainRollOut.show_net_submit.enabled = \
    batchCameraRender_mainRollOut.net_render.checked and batchCameraRender_mainRollOut.net_render.enabled
)

--function to switch window element's activity state
fn elements_active state =
(
  -- stack showLocals:false firstFrameOnly:false excludeOwner:true
  batchCameraRender_mainRollOut.select_camera.enabled = state
  batchCameraRender_mainRollOut.set_viewport.enabled = state
  batchCameraRender_mainRollOut.check_selected.enabled = state

  if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
  (
    Net_Render_Options_Rollout.save_all_as_default.enabled = true
    batchCameraRender_mainRollOut.copy_button.enabled = true
    batchCameraRender_mainRollOut.add_button.enabled = ((superclassof (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item[0].tag.value) == camera))
  )
  else
  (
    Net_Render_Options_Rollout.save_all_as_default.enabled = false
    batchCameraRender_mainRollOut.copy_button.enabled = false
    batchCameraRender_mainRollOut.add_button.enabled = false
  )
  
  if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count > 0) then
  (
    batchCameraRender_mainRollOut.paste_button.enabled = (BatchCamRenderParamsBuffer != undefined)
    batchCameraRender_mainRollOut.remove_button.enabled = true
  )
  else
  (
    batchCameraRender_mainRollOut.paste_button.enabled = false  
    batchCameraRender_mainRollOut.remove_button.enabled = false
  )

  --output section
  for control_element in Render_Output_Rollout.controls do
    control_element.enabled = state

  --vray settings section
  if isVrayRenderer() then 
  (
    for control_element in Vray_Settings_Rollout.controls do
    (
      control_element.enabled = state
    )
    Vray_Settings_Rollout.save_vray_image_file.enabled = Vray_Settings_Rollout.save_separate_render_channels.enabled = Vray_Settings_Rollout.show_vray_vfb.checked and state
  )
  else
    for control_element in Vray_Settings_Rollout.controls do
      control_element.enabled = false

  --lights section
  for control_element in Light_Assignement_Rollout.controls do
    control_element.enabled = state
  
  --frame range section
  for control_element in Frame_Range_Rollout.controls do
    control_element.enabled = state

  --resolution section
  for control_element in Output_Size_Rollout.controls do
    control_element.enabled = state
  if Output_Size_Rollout.lock_aspect.checked then
    Output_Size_Rollout.image_aspect_spinner.enabled = false
  
  --scene state section
  for control_element in Scene_States_Rollout.controls do
  (
    case (control_element.name) of
    (
      "state_sets_list":  control_element.enabled  = state and (dotnetclass "Autodesk.Max.StateSets.Plugin" != undefined)
      default:    control_element.enabled = state
    )
  )
)

--function to set all elements "enabled" state depending on list item's selection
fn ui_elements_refresh listview_obj =
(
  --if there's no elements in list then deactivate all elements
  if listview_obj.Items.count == 0 then
  (
    --no camera in scene
    --deactivate render buttons
    render_buttons_active false
    elements_active false
    --and all other elements too
    for control_element in batchCameraRender_mainRollOut.controls do
    (
      case (control_element.name) of
      (
        "Refresh":  control_element.enabled = true
        -- "ADD_BUTTON":      control_element.enabled = true
        default:    control_element.enabled = false
      )
    )
  )
  else  --if there is something...
  (
    --make listview active
    for control_element in batchCameraRender_mainRollOut.controls do
    (
      if control_element.name == "paste_button" then
        control_element.enabled = (BatchCamRenderParamsBuffer != undefined)
      else
        control_element.enabled = true
    )

    --if something is checked then activate render buttons
    render_buttons_active (listview_obj.CheckedItems.Count > 0)

    --if something selected activate all elements and fill some fields
    elements_active (listview_obj.SelectedItems.count > 0)
    
    if listview_obj.SelectedItems.count > 1 then 
    (
      batchCameraRender_mainRollOut.set_viewport.enabled = false
    )
  )
)

fn leadingZero num digitCount=
(
  str = num as string
  while str.count < digitCount do
    str = "0" + str
  str
)

fn submit_to_deadline camera_obj =
(
  global SMTDPaths
  global SMTDSettings 
  global SMTDFunctions

  local theNetworkRoot = Net_Render_Options_Rollout.DeadlineRepo.text
  local remoteScript = theNetworkRoot + @"\submission\3dsmax\main\SubmitMaxToDeadline_Functions.ms" 
  fileIn remoteScript 

  SMTDFunctions.loadSettings()

  local jobName = ""
  jobNamePattern = Net_Render_Options_Rollout.backburnerJobNamePattern.text
  if (isNotUndefinedOrEmpty jobNamePattern) then
    jobName = parse_file_name_template jobNamePattern (compose_full_parsing_dictionary camera_obj)
  else
    jobName = (if maxFileName == "" then "untitled" else maxFileName) + " " + camera_obj.name

  SMTDSettings.JobName = jobName

  local maxFileToSubmit = SMTDPaths.tempdir + (if maxFileName == "" then "untitled.max" else maxFileName)
  SMTDFunctions.SaveMaxFileCopy maxFileToSubmit

  local SubmitInfoFile = SMTDPaths.tempdir + "\\batchcam_submit_info.job"
  local JobInfoFile = SMTDPaths.tempdir+ "\\batchcam_job_info.job"

  --rendOutputFilename = SMTDFunctions.GetFormattedOutputFilename rendOutputFilename addFramePadding:true stripPaddingNumbers:true addFrameDelimiter:true

  SMTDSettings.SubmitSceneMode = #reposave
  --SMTDSettings.SubmitSceneMode = #networksave
  --SMTDSettings.SubmitSceneNetworkLocation = maxFileToSubmit

  SMTDFunctions.CreateSubmitInfoFile SubmitInfoFile batchName:(getFilenameFile (if maxFileName == "" then "Untitled.max" else maxFileName))
  SMTDFunctions.CreateJobInfoFile JobInfoFile

  local initialArgs="\""+SubmitInfoFile+"\" \""+JobInfoFile+"\" \""+maxFileToSubmit+"\" "

  SMTDFunctions.waitForCommandToComplete initialArgs SMTDSettings.TimeoutSubmission 
)

--function to submit current scene to backburner manager
fn net_render_auto_submit camera_obj =
(
  batchManager = NetRender.GetManager() --get NetRender Interface
  --batchManager.connect #manual <manager IP address> [port:<integer>] 
  --batchManager.connect #automatic <subnet mask> [port:<integer>]
  --batchManager.connect #manual managerName
  netrender_port = Net_Render_Options_Rollout.Port.text as integer
  -- if port edit text contains something not integer then use default port - 3234
  if netrender_port == undefined then netrender_port = 3234
  platform_var = if (Net_Render_Options_Rollout.Platform.state == 1) then #32 else #64
  if not (batchManager.connect (if Net_Render_Options_Rollout.Auto_Search.checked then #automatic else #manual) Net_Render_Options_Rollout.Name_Or_Mask.text port:netrender_port platform:platform_var)
  then  --throw error to catch at main try block in on_start_render event handler
    throw ("Failed to connect to manager "+ (Net_Render_Options_Rollout.Name_Or_Mask.text) + " , port:" + (netrender_port as string))
  else
  (
    batchJob = batchManager.NewJob()
    batchJob.renderCamera = camera_obj.name
    --if choosen platform is not default reflect this in the job name
    --since connection to one platform doesn't allow to see existing jobs from another platform this helps to avoid submitting jobs with same name on different platforms
    platform_string = ""
    if is64bitApplication() and (platform_var == #32) then platform_string = "-32bit"
    else if (not is64bitApplication()) and (platform_var == #64) then platform_string = "-64bit"
    
    --get the jobName template from the options rollout
    jobNamePattern = Net_Render_Options_Rollout.backburnerJobNamePattern.text
    if (isNotUndefinedOrEmpty jobNamePattern) then
    (
--      print "test2"
      jobName = parse_file_name_template jobNamePattern (compose_full_parsing_dictionary camera_obj)
--      format "jobName: %\n" jobName
    )
    else
      jobName = batchJob.name + " " + batchJob.renderCamera --add camera name
    jobName += platform_string  -- and platform identifier (if not default) to job name
    
    nameCounter = 1
    alreadyHasName = true
    -- do loop to correctly name render job.
    -- job names composed of scene name + camera name + counter number.
    existingJobs = batchManager.getjobs()
    existingJobNames = for job in existingJobs collect job.name
    do
    (
      tempjobName = jobName + " " + (leadingZero nameCounter ((nameCounter as string).count + 1))
      jobItem = findItem existingJobNames tempjobName
      if jobItem == 0 then
      (
        alreadyHasName = false
        batchJob.name = tempjobName       
      )
      else
        nameCounter = nameCounter + 1
    ) while alreadyHasName

  )
  --set render frames from max render dialog
  batchJob.nthFrame = rendNThFrame
  if rendTimeType == 3 then
  (
    batchJob.fromFrame = rendStart
    batchJob.toFrame = rendEnd
  )
  else if rendTimeType == 4 then
  (
    batchJob.frames = rendPickupFrames
    batchJob.nonSeqFrames = true
  )
  else  --if frame range paramter is undefined then render one current frame
  (
    batchJob.fromFrame = currentTime.frame
    batchJob.toFrame = currentTime.frame
  )
  
  local render_servers = #()
  -- render_servers = batchManager.GetServers filter:#group key:"test_global"
  -- render_servers = batchManager.GetServers filter:#index key:2
  render_servers = batchManager.GetServers()
  local servernames = for i in render_servers collect i.name
  -- format "servernames:%\n" servernames
  batchJob.Submit Servers:render_servers
  -- batchJob.Submit Servers:#(render_servers[1])
  batchManager.Disconnect()
)

--returns the array of animation frames from object's
fn get_key_array obj=
(
  frame_array = #()
  --standard transformation section
  try
    if obj.pos.controller.keys.count > 0 then
      frame_array = frame_array + (for i in obj.pos.controller.keys collect i.time)
  catch ()
--  format "frame_array - %\n" frame_array
  try 
    if obj.rotation.controller.keys.count > 0 then
      frame_array = frame_array + (for i in obj.rotation.controller.keys collect i.time)
  catch ()
--  format "frame_array - %\n" frame_array
  try
    if obj.scale.controller.keys.count > 0 then
      frame_array = frame_array + (for i in obj.scale.controller.keys collect i.time)
  catch ()
--  format "frame_array - %\n" frame_array

  --object properties section
  prop_controller_array = for prop in getPropNames obj where isPropertyAnimatable obj prop collect (getPropertyController obj prop) --get controllers
  prop_controller_array = for prop in prop_controller_array where prop != undefined collect prop  --collect only existing controller
  if prop_controller_array.count > 0 then
    for controller in prop_controller_array do
    (
      key_array = controller.keys
      if key_array.count > 0 then
        frame_array = frame_array + (for i in key_array collect i.time)
    )
  
  --object modifers section
  if obj.modifiers.count > 0 then
    for one_modifier in obj.modifiers do
    (
      modifier_controller_array = for prop in getPropNames one_modifier where isPropertyAnimatable one_modifier prop collect (getPropertyController one_modifier prop)
      modifier_controller_array  = for prop in modifier_controller_array where prop != undefined collect prop
      if modifier_controller_array.count > 0 then
        for controller in modifier_controller_array do
        (
          key_array = controller.keys
          if key_array.count > 0 then
            frame_array = frame_array + (for i in key_array collect i.time)
        )
    )

  frame_array
)

--function to get the whole range of animation for camera and target objects
fn get_key_range camera_obj=
(
  local camera_keys = #()
  local target_keys = #()
  camera_keys = get_key_array camera_obj
  if camera_obj.target != undefined then
    target_keys = get_key_array (camera_obj.target)
  full_range = camera_keys + target_keys
  
  result = #()
  if full_range.count > 0 then
  (
    append result (amin full_range)
    append result (amax full_range)
  )
  else
  (
    result = #(0f, 0f)
  )
  result
)

fn fill_scripts_columns listview_obj =
(
  -- for camera_obj in camera_list do
  -- (
  --  listItem = listview_obj.FindItemWithText camera_obj.name
  local item_count = listview_obj.Items.count
  for i=0 to item_count - 1 do
  (
    local listItem = listview_obj.Items.Item[i]
    local camera_obj = listitem.tag.value
    -- sub_item = undefined  --subitem variable
    
    for property_name in BatchCam_ScriptsPropertiesNames do
    (
      --Vray section
      temp_string = getUserProperty camera_obj ("BatchCameraRender_" + property_name)
      if isNotUndefined temp_string then
        add_sub_item listItem (temp_string as string) property_name true
      else
        add_sub_item listItem "undefined" property_name false
      --End of Vray section
    )
  )
--  listview_obj.AutoResizeColumns (dotNetClass "System.Windows.Forms.ColumnHeaderAutoResizeStyle").HeaderSize
--  listview_obj.Refresh()
  --end of adding vray columns to list view
)

fn fill_vray_columns listview_obj =
(
  local item_count = listview_obj.Items.count
  for i=0 to item_count - 1 do
  (
    local listItem = listview_obj.Items.Item[i]
    local camera_obj = listitem.tag.value
    
    for property_name in BatchCam_VrayPropertiesNames do
    (
      --Vray section
      temp_string = getUserProperty camera_obj ("BatchCameraRender_" + property_name)
      if isNotUndefined temp_string then
      (
        if property_name == "irmap_mode" then
          temp_string = BatchCam_Vray_irmap_modes[temp_string as integer]
        else if property_name == "lcmap_mode" then
          temp_string = BatchCam_Vray_lcmap_modes[temp_string as integer]
        add_sub_item listItem (temp_string as string) property_name true
      )
      else
      (
        add_sub_item listItem "undefined" property_name false
      )
      --End of Vray section
    )
  )
--  listview_obj.AutoResizeColumns (dotNetClass "System.Windows.Forms.ColumnHeaderAutoResizeStyle").HeaderSize
--  listview_obj.Refresh()
  --end of adding vray columns to list view
)

fn fill_ListView listview_obj camera_list = 
(
  --fill in spreadshit dotNet version
  ItemsArray = #() --array to collect the list items
  ItemsIndexArray = #() --array to collect the list items
  
  -- local preset_index = 0
  for camera_obj in camera_list do
  (
    local preset_name = getPresetName camera_obj
    li = dotNetObject "System.Windows.Forms.ListViewItem" preset_name
    li.tag = dotNetMXSValue camera_obj
    li.UseItemStyleForSubItems = false
    sub_li = undefined --subitem variable
    --get framerange
    temp_string1 = getUserProperty camera_obj "BatchCameraRender_frames"
    temp_string2 = getUserProperty camera_obj "BatchCameraRender_framerange_from"
    temp_string3 = getUserProperty camera_obj "BatchCameraRender_framerange_to"
    temp_string5 = getUserProperty camera_obj "BatchCameraRender_anim_frame_range"

    if isNotUndefined temp_string5 then
    ( --render_frames
      temp_frame_range = get_key_range camera_obj
      frame_from = temp_frame_range[1].frame as string
      frame_to = temp_frame_range[2].frame as string
      
      add_sub_item li ("anim.range:" + (frame_from as integer) as string + "..." + (frame_to as integer) as string) "frames" true
    )
    else if isNotUndefined temp_string1 then
    ( --render_frames
      add_sub_item li (temp_string1 as string) "frames" true
    )
    else if isNotUndefined temp_string2 then
    (
      if (temp_string2 as integer == temp_string3 as integer) then  --single frame
        add_sub_item li (temp_string2 as string) "frames" true
      else  --frame range
        add_sub_item li (temp_string2 as string + "..." + temp_string3 as string) "frames" true
    )
    else
    (
      add_sub_item li "undefined" "frames" false
    )
    
    --get frame size
    xres_prop = getUserProperty camera_obj "BatchCameraRender_frame_width"
    yres_prop = getUserProperty camera_obj "BatchCameraRender_frame_heigth"
    if  (isNotUndefined xres_prop) and (isNotUndefined yres_prop) then
      add_sub_item li (xres_prop as string + " x " + yres_prop as string) "resolution" true
    else
      add_sub_item li "undefined" "resolution" false
    
    image_aspect = getUserProperty camera_obj "BatchCameraRender_image_aspect"
    if  (isNotUndefined image_aspect) and (isNotUndefined image_aspect) then
      add_sub_item li (image_aspect as string) "image_aspect" true
    else
      add_sub_item li "undefined" "image_aspect" false
    
    --get filename
    temp_string = getUserProperty camera_obj "BatchCameraRender_render_output"
    if isNotUndefined temp_string then
      add_sub_item li temp_string "path" true
    else
      add_sub_item li "undefined" "path" false
    
    --get elements' state
    temp_string = getUserProperty camera_obj "BatchCameraRender_elements_state"
    if  isNotUndefined temp_string then
      add_sub_item li (temp_string as string) "elements_state" true
    else
      add_sub_item li "undefined" "elements_state" false
    
    --get not_save_elements
    temp_string = getUserProperty camera_obj "BatchCameraRender_not_save_elements"
    if isNotUndefined temp_string then
      add_sub_item li (temp_string as string) "not_save_elements" true
    else
      add_sub_item li "undefined" "not_save_elements" false
    
    --get elements' path
    temp_string = getUserProperty camera_obj "BatchCameraRender_elements_output"
    if  isNotUndefined temp_string then
      add_sub_item li (temp_string as string) "elements_path" true
    else
      add_sub_item li "undefined" "elements_path" false
    
    --get lightstate
    temp_string = getUserProperty camera_obj "BatchCameraRender_solo_lights"
    if  isNotUndefined temp_string then
      add_sub_item li temp_string "solo_lights" true
    else
      add_sub_item li "undefined" "solo_lights" false
    
    temp_string = getUserProperty camera_obj "BatchCameraRender_on_lights"
    if  isNotUndefined temp_string then
      add_sub_item li temp_string "on_lights" true
    else
      add_sub_item li "undefined" "on_lights" false
    
    temp_string = getUserProperty camera_obj "BatchCameraRender_off_lights"
    if  isNotUndefined temp_string then
      add_sub_item li temp_string "off_lights" true
    else
      add_sub_item li "undefined" "off_lights" false
    
    --scene state part
    temp_string = getUserProperty camera_obj "BatchCameraRender_scene_state"
    if  isNotUndefined temp_string then
      add_sub_item li temp_string "scene_state" true
    else
      add_sub_item li "undefined" "scene_state" false
    
    --state sets part
    temp_string = getUserProperty camera_obj "BatchCameraRender_state_set"
    if  isNotUndefined temp_string then
      add_sub_item li temp_string "state_set" true
    else
      add_sub_item li "undefined" "state_set" false
    
    --render preset part
    temp_string = getUserProperty camera_obj "BatchCameraRender_render_preset"
    if isNotUndefined temp_string then
      add_sub_item li temp_string "render_preset" true
    else
      add_sub_item li "undefined" "render_preset" false

    --restore listitem's index
    local itemIndex = -1
    temp_string = getUserProperty camera_obj "BatchCameraRender_item_index"
    if isNotUndefined temp_string then
      itemIndex = (temp_string as integer)
    
    append ItemsArray #(li, itemIndex) --we add the list item to the array
  )
  
  fn compareFN item1 item2 =
  (
    local res 
    if item1[2] == -1 or item2[2] == -1 then
    (
      res = case of
      (
        (item1[1].text < item2[1].text): -1
        (item1[1].text > item2[1].text): 1
        default: 0
      )
    )
    else
    (
      res = case of
      (
        (item1[2] < item2[2]): -1
        (item1[2] > item2[2]): 1
        default: 0
      )
    )
    res
  )
  
  qsort ItemsArray compareFN

  ItemsArray = for item in ItemsArray collect item[1]

  global batchCameraRender_loading_items = true
  listview_obj.Items.AddRange ItemsArray

)

    
fn init_ListView listview_obj camera_list = 
(
  --dotNet object initialization
  listview_obj.GridLines = true
  listview_obj.CheckBoxes = true
  listview_obj.Sorting = (dotNetClass "System.Windows.Forms.SortOrder").None
  listview_obj.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").NonClickable 
  listview_obj.View = (dotNetClass "System.Windows.Forms.View").Details
  listview_obj.FullRowSelect = true
  listview_obj.HideSelection = false
  listview_obj.AutoArrange = false

  listview_obj.AllowDrop = true

  listview_obj.BeginUpdate()
  
  listview_obj.Columns.Clear()
  
  standard_columns = #("Camera", "Frames", "Resolution", "Aspect", "Path", "Elements State", "Elements Path", "Solo Lights", \
            "Lights On", "Lights Off", "Scene State", "State Set", "Render Preset")  
  for i in standard_columns do
    listview_obj.Columns.add i
  
  vray_columns = #("IRmap mode", "Auto Save IRmap", "Auto Switch IRmap", "IRmap Read File", \
    "IRmap Save File", "LCmap Mode", "Auto Save LCmap", "Auto Switch LCmap", "LCmap Read File", "LCmap Save File", "Ortho Mode" )
  for i in vray_columns do
    listview_obj.Columns.add i
  
  script_columns = #("Pre-render script", "Pre-render enabled", "Post-render script", "Post-render enabled")
  for i in script_columns do
    listview_obj.Columns.add i
  
  if camera_list.count > 0 then
  (
    listview_obj.Items.Clear()
    fill_ListView listview_obj camera_list
    fill_vray_columns listview_obj
    fill_scripts_columns listview_obj
    
    listview_obj.AutoResizeColumns (dotNetClass "System.Windows.Forms.ColumnHeaderAutoResizeStyle").HeaderSize
    listview_obj.Refresh()
  )
  else
  (
    listview_obj.Items.Clear()
  )
  
  --code to restore list items' checked state
  --placed here to work with already sorted list of dotnet control items
  --initialize state varialble if it is undefined or if camera count doesn't match with state's count
  if BatchCam_listItem_state == undefined then
    BatchCam_listItem_state = #() --create empty array if there's no state array
  BatchCam_listItem_state.count = camera_list.count --match count
  --iterate over dotnet list items
  for i=1 to listview_obj.Items.count do
  (
    if BatchCam_listItem_state[i] == true then    --if item's state saved then check it in list
      listview_obj.Items.Item[i-1].checked = true
    else                              --else - if item's state is false or UNDEFINED then save state as false and uncheck the item
    (
      BatchCam_listItem_state[i] = false
      listview_obj.Items.Item[i-1].checked = false
    )
  )
  listview_obj.EndUpdate()
)

fn batchCameraRender_reset_render_counter=
(
  Net_Render_Options_Rollout.Try_Counter.value  = batchCameraRender_RenderCounter = 1
)

--reload all cameras
fn batchCameraRender_reload_cameras lv_objects =
(
  selectionArray = for i=0 to (lv_objects.SelectedIndices.Count-1) collect lv_objects.SelectedIndices.Item[i]
  init_ListView lv_objects (get_camera_list())
  for i in selectionArray do
  (
    if not i > (lv_objects.Items.Count-1) then
      (lv_objects.Items.Item[i]).Selected = true
  )
  
  LV_ITEMS = #()  --this array contains listview items for convinience      
  for i=0 to (lv_objects.Items.Count - 1) do
    append LV_ITEMS (lv_objects.Items.Item i)
  
  --refresh ui elements
  if (lv_objects.items.count == 0) then --only call refresh if empty listview, because init_ListView/fill_ListView will refresh anyway
    ui_elements_refresh lv_objects
  
  --reload scene states and render presets
  Scene_States_Rollout.scene_states_list2.Items.Clear()
  Scene_States_Rollout.scene_states_list2.Items.AddRange (join #("undefined") (get_scene_state_array()))
  Scene_States_Rollout.render_preset_list.items = join #("undefined") (get_render_preset_array())
  
  --reload state sets
  local ss_class = dotnetclass "Autodesk.Max.StateSets.Plugin"
  if ss_class != undefined then --if state sets supported
  (
    Scene_States_Rollout.state_sets_list.items = join #("undefined") (get_state_sets_array())
  )

  --custom keywords and names
  if (temp_state = getRootNodeData "BatchCameraRender_UserKey1")  != undefined then
    Net_Render_Options_Rollout.UserKey1.text= (temp_state as string)      
  if (temp_state = getRootNodeData "BatchCameraRender_UserKey2")  != undefined then
    Net_Render_Options_Rollout.UserKey2.text= (temp_state as string)
  if (temp_state = getRootNodeData "BatchCameraRender_UserKey3")  != undefined then
    Net_Render_Options_Rollout.UserKey3.text= (temp_state as string)
  if (temp_state = getRootNodeData "BatchCameraRender_UserVal1")  != undefined then
    Net_Render_Options_Rollout.UserVal1.text= (temp_state as string)
  if (temp_state = getRootNodeData "BatchCameraRender_UserVal2")  != undefined then
    Net_Render_Options_Rollout.UserVal2.text= (temp_state as string)
  if (temp_state = getRootNodeData "BatchCameraRender_UserVal3")  != undefined then
    Net_Render_Options_Rollout.UserVal3.text= (temp_state as string)      
  
  --custom names
  if (temp_state = getRootNodeData "BatchCameraRender_bbJobName")  != undefined then
    Net_Render_Options_Rollout.backburnerJobNamePattern.text= (temp_state as string)
  if (temp_state = getRootNodeData "BatchCameraRender_elementName")  != undefined then
    Net_Render_Options_Rollout.renderElementNamePattern.text= (temp_state as string)
    
  --script sections
  batchCameraRender_populateScripts()
)

--function to collect all lights in scene
fn collect_scene_lights = 
(
  temp_array = #()
  temp_array = for obj in objects where (iskindof obj DaylightAssemblyHead) or ((iskindof obj light) and not (iskindof obj.parent DaylightAssemblyHead)) collect obj
  temp_array
)

--functions to switch the lights
fn switch_lights light_name state =
(
  light_obj = getNodeByName light_name
  if (light_obj != undefined) then --check if light_obj exist in scene
  (
    if (iskindof light_obj DaylightAssemblyHead) then --deal with daylight system
    (
      temp_sun = light_obj.GetSun()
      temp_sky = light_obj.GetSky()
      if temp_sun != undefined then
        temp_sun.enabled = state
      if temp_sky != undefined then
        temp_sky.enabled = state
    )
    else
    (
      if hasProperty light_obj "on" then
        light_obj.on = state
      else if hasProperty light_obj "enabled" then
        light_obj.enabled = state
      else if hasProperty light_obj "Area_Enable" then  --for MR Lights
        light_obj.on = state
    )
  )
  else --if doesn't exist
  (
    --throw error to catch at main try block in on_start_render event handler
    throw ("Light \"" + light_name + "\" not found.")
  )
)

--function to get one light object state
--written to support different light objects
fn get_light_state light_obj =
(
  light_state = false
  if (iskindof light_obj DaylightAssemblyHead) then --deal with daylight system
  (
    sun_state = false
    sky_state = false
    temp_sun = light_obj.GetSun()
    temp_sky = light_obj.GetSky()
    if temp_sun != undefined then
      sun_state = temp_sun.enabled
    if temp_sky != undefined then
      sky_state = temp_sky.enabled
--    format "sun_state: % sky_state: %\n" sun_state sky_state
    light_state = sun_state or sky_state
  )
  else
  (
    if hasProperty light_obj "on" then
      light_state = light_obj.on
    else if hasProperty light_obj "enabled" then
      light_state = light_obj.enabled
    else if hasProperty light_obj "Area_Enable" then  --for MR Lights
      light_state = light_obj.on
  )
  return light_state
)

--function to store lighting state in the scene
--stores light state to the 2 dimensional array
fn store_lighting_state =
(
  LIGHTING_STATE = #()
  local light_state
  local light_name
  for light_obj in LIGHT_LIST do
  (
    light_state = get_light_state light_obj
    light_name = light_obj.name
--    format "light_name: % light_state: %\n" light_name light_state
    one_light_state = #(light_name, light_state)
    append LIGHTING_STATE one_light_state
  )
--  format "LIGHTING_STATE: %\n" LIGHTING_STATE
)

--function restore lighting state in the scene
fn restore_lighting_state =
(
  for light_obj in LIGHTING_STATE do
    switch_lights light_obj[1] light_obj[2]
)

--function to turn on solo lights and switch off all other lights in scene
fn turn_solo_lights_on solo_lights =
(
--  format "solo lights: %\n" solo_lights
--  format "LIGHT_LIST: %\n" LIGHT_LIST
  local light_obj
  for light_obj in LIGHT_LIST do
  (
    if finditem solo_lights light_obj.name == 0 then -- turn off lights that are not in sololight list
--      format "off light %\n" light_obj.name
      switch_lights light_obj.name false
  )
  --now turn lights from sololight list one by one to check their existance in scene
  for light_name in solo_lights do
  (
      switch_lights light_name true
  )
)

--function to force on lights
fn force_lights_on forced_on_lights =
(
  for light_name in forced_on_lights do
      switch_lights light_name true
)

--function to force off lights
fn force_lights_off forced_off_lights =
(
  for light_name in forced_off_lights do
    switch_lights light_name false
)
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
    obj_itself = (selected_items[1]).tag.value
    temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)

    --fill elements path field
    if isNotUndefined temp_string then
--      spinner.value = (temp_string as integer) 
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
      obj_itself = (selected_items[i]).tag.value
      temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
      if isNotUndefined temp_string then
      (
        --set previous value to first value
        if i==1 then prev_value = temp_string
        --show path if previous path and current are similar
        if temp_string != prev_value then 
        (
          diff_flag = true  --set flag if values differ
          spinner.indeterminate  = true
        )
        else if not diff_flag then  --if values are same and flag hasn't been set
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
    obj_itself = (selected_items[1]).tag.value
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
      obj_itself = (selected_items[i]).tag.value
      temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
      if isNotUndefined temp_string then
      (
        --set previous value to first value
        if i==1 then prev_path = temp_string
        --show path if previous path and current are similar
        if temp_string != prev_path then 
        (
          path_diff_flag = true --set flag if values differ
          uiTextField.text = "Varies"
        )
        else if not path_diff_flag then --if values are same and flag hasn't been set
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
    obj_itself = (selected_items[1]).tag.value
    temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
    if isNotUndefined temp_string then
      uiCheckBox.state = (temp_string as booleanclass)
    else
    (
      if (classof uiCheckBox) != CheckButtonControl then
        uiCheckBox.triState = 2
      else
        uiCheckBox.state = false
    )
  )
  else --multiple selection
  ( 
    prev_state
    state_diff_flag = false
    
    for i=1 to selected_items.count while not state_diff_flag do
    (
      --populate checkbox state for multiple items checked
      obj_itself = (selected_items[i]).tag.value
      temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
      if isNotUndefined temp_string then
      (
        temp_string = (temp_string as booleanclass)
        --set previous value to first value
        if i==1 then prev_state = temp_string
        --show path if previous path and current are the similar
        if temp_string != prev_state then 
        (
          state_diff_flag = true  --set flag if values differ
          if (classof uiCheckBox) != CheckButtonControl then
            uiCheckBox.triState = 2
          else
            uiCheckBox.state = false
        )
        else if not state_diff_flag then  --if values are same and flag hasn't been set
        (
          uiCheckBox.state = temp_string
        )
        
        prev_state = temp_string
      )
      else
      (
        if (classof uiCheckBox) != CheckButtonControl then
          uiCheckBox.triState = 2
        else
          uiCheckBox.state = false
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
    obj_itself = (selected_items[1]).tag.value
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
      --populate checkbox state for multiple items checked
      obj_itself = (selected_items[i]).tag.value
      temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
      if (isNotUndefined temp_string) then
      (
        --set previous value to first value
        if i==1 then prev_state = temp_string
        --show path if previous path and current are the similar
        if temp_string != prev_state then 
        (
          state_diff_flag = true  --set flag if values differ
          uiDropDownBox.selection = 0
        )
        else if not state_diff_flag then  --if values are same and flag hasn't been set
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
    obj_itself = (selected_items[1]).tag.value
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
      obj_itself = (selected_items[i]).tag.value
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
    obj_itself = (selected_items[1]).tag.value
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
      --populate checkbox state for multiple items checked
      obj_itself = (selected_items[i]).tag.value
      temp_string = getUserProperty obj_itself ("BatchCameraRender_" + property_name)
      if (isNotUndefined temp_string) then
      (
        --set previous value to first value
        if i==1 then prev_state = temp_string
        --show path if previous path and current are the similar
        if temp_string != prev_state then 
        (
          state_diff_flag = true  --set flag if values differ
          uiDropDownBox.selection = 0
        )
        else if not state_diff_flag then  --if values are same and flag hasn't been set
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
    obj_itself = (selected_items[1]).tag.value
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
      --populate checkbox state for multiple items checked
      obj_itself = (selected_items[i]).tag.value
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
          state_diff_flag = true  --set flag if values differ
          uiDropDownBox.selection = 0
        )
        else if not state_diff_flag then  --if values are same and flag hasn't been set
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
    obj_itself = (selected_items[1]).tag.value
    temp_string1 = getUserProperty obj_itself "BatchCameraRender_frames"
    temp_string2 = getUserProperty obj_itself "BatchCameraRender_framerange_from"
    temp_string5 = getUserProperty obj_itself "BatchCameraRender_anim_frame_range"
    
    if (isNotUndefined temp_string5) then
    ( --render_frames
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
    ( --render_frames
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
      ( --single frame
        rendType1.state = 1
        rendType2.state = 0
        rendType3.state = 0
        rendType5.state = 0
        render_from.enabled = render_to.enabled = render_frames.enabled = false
        render_single.value = temp_string2 as integer

      )
      else
      ( --frame range
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
        1:  (
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
        3:  (
          render_from.value = rendStart
          render_to.value = rendEnd
          rendType1.state = 0
          rendType2.state = 1
          rendType3.state = 0
          rendType5.state = 0
        )
        4:  (
          render_frames.text = rendPickupFrames
          rendType1.state = 0
          rendType2.state = 0
          rendType3.state = 1
          rendType5.state = 0
        )
      )

--      rendType1.state = 0
--      rendType2.state = 0
--      rendType3.state = 0
--      rendType5.state = 0
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
  not_save_elements = Render_Output_Rollout.not_save_elements

  --exclude selected items
  local selected_items = #()
  for i in lis do
    if i.selected then
      append selected_items i
    
  if selected_items.count == 1 then
  (
    obj_itself = (selected_items[1]).tag.value
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

  --set not save RE here
    temp_string = getUserProperty obj_itself "BatchCameraRender_not_save_elements"
    if (isNotUndefined temp_string) then
      not_save_elements.state = (temp_string as booleanclass)
    else
      not_save_elements.triState = 2

  )
  else --multiple selection
  ( 
    prev_path = ""
    prev_state
    path_diff_flag = false
    state_diff_flag = false
    
    for i=1 to selected_items.count while not path_diff_flag do
    (
      obj_itself = (selected_items[i]).tag.value
      temp_string = getUserProperty obj_itself "BatchCameraRender_elements_output"
      if (isNotUndefined temp_string) then
      (
        --set previous value to first value
        if i==1 then prev_path = temp_string
        --show path if previous path and current are the similar
        if temp_string != prev_path then 
        (
          path_diff_flag = true --set flag if values differ
          elements_path.text = "Varies"
        )
        else if not path_diff_flag then --if values are same and flag hasn't been set
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
          state_diff_flag = true  --set flag if values differ
          elements_state.triState = 2
        )
        else if not state_diff_flag then  --if values are same and flag hasn't been set
          elements_state.triState = if temp_string then 1 else 0
        
        prev_state = temp_string
      )
      else
      (
        elements_state.triState = 2
      )
      
      --populate not_save_RE for multiple items checked
      temp_string = getUserProperty obj_itself "BatchCameraRender_not_save_elements"
      if (isNotUndefined temp_string) then
      (
        temp_string = temp_string as booleanclass
        --set previous value to first value
        if i==1 then prev_state = temp_string
        --show path if previous path and current are the similar
        if temp_string != prev_state then 
        (
          state_diff_flag = true  --set flag if values differ
          not_save_elements.triState = 2
        )
        else if not state_diff_flag then  --if values are same and flag hasn't been set
          not_save_elements.triState = if temp_string then 1 else 0
        
        prev_state = temp_string
      )
      else
      (
        not_save_elements.triState = 2
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
  
  result_file_name = Render_Output_Rollout.result_file_name
  file_name = Render_Output_Rollout.file_name
  file_path = Render_Output_Rollout.file_path
  elements_path = Render_Output_Rollout.elements_path
  
  --exclude selected items
  local selected_items = #()
  for i in cameraItems do
    if i.selected then
      append selected_items i
    
  if selected_items.count == 1 then
  (
    obj_itself = (selected_items[1]).tag.value
    temp_string = getUserProperty obj_itself "BatchCameraRender_render_output"
    
    if (isNotUndefined temp_string) then
    (
      --put parsed string in full text textfield
      result_file_name.text = parse_file_name_template temp_string (compose_parsing_dictionary obj_itself) 
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
      obj_itself = (selected_items[i]).tag.value
      temp_string = getUserProperty obj_itself "BatchCameraRender_render_output"
      if (isNotUndefined temp_string) then
      (
        --if multiple items are selected
        --show only similar parts of the filename
        
        -- for the full path textfield consider parsed path string
        parsed_path = parse_file_name_template temp_string (compose_parsing_dictionary obj_itself) 
        
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
--    temp_string = temp_string as string -- as string added in case temp_string is not a string or undefined
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
    obj_itself = (selected_items[1]).tag.value
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
  populate_dropdownbox_string_item selectedItems "state_set" Scene_States_Rollout.state_sets_list
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

--########################--
--FUNCTIONS for batch camera render script
--Function to save (set) rendering options to camera objects
--########################--

--general function to set filename property to user properties
fn set_file_name_property cameraItems property_name fullfilename=
(
  fullfilename = trimLeadTrailSpaces fullfilename 
  for i in cameraItems do
  (
    if i.selected then
    (
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
      setUserProperty i ("BatchCameraRender_" + property_name) (integer_value as string)
    )
  )
)

--function to set frame size to selected cameras in listitems
fn set_resolution cameraItems width height =
(
  for i in cameraItems do
  (
    if i.selected then
    (
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
      if Output_Size_Rollout.lock_aspect.checked or y_res == undefined then 
      (
        y_res = (width as float) / (image_aspect as float)
        y_res = ((dotnetclass "System.Math").Round y_res) --apply dotnet rounding
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
      if Output_Size_Rollout.lock_aspect.checked or x_res == undefined then 
      (
        x_res = (height as float) * (image_aspect as float)
        x_res = ((dotnetclass "System.Math").Round x_res) --apply dotnet rounding
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
  for i in cameraItems do
  (
    if i.selected then
    (
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
      setUserProperty i "BatchCameraRender_elements_state" (elements_state as string)
      set_sub_item i (elements_state as string) "elements_state"
    )
  )
)

fn set_not_save_elements cameraItems not_save_elements=
(
  for i in cameraItems do
  (
    if i.selected then
    (
      setUserProperty i "BatchCameraRender_not_save_elements" (not_save_elements as string)
      set_sub_item i (not_save_elements as string) "not_save_elements"
    )
  )
)

fn set_elements_path cameraItems elementsPath=
(
  for i in cameraItems do
  (
    if i.selected then
    (
      elementsPath = trimLeadTrailSpaces elementsPath
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
        temp_name = filenameFromPath temp_string      --exclude file name
        temp_fullname = pathConfig.appendPath temp_path temp_name --append new folder path to the file name
--        temp_fullname = pathConfig.convertPathToAbsolute temp_fullname
        
        setUserProperty i "BatchCameraRender_render_output" (temp_fullname as string)
        set_sub_item i (temp_fullname as string) "path"
      )
    )
  )
)

fn set_render_file cameraItems file_name_only=
(
  for i in cameraItems do
  (
    if i.selected then
    (
      obj_itself = i.tag.value
      temp_string = getUserProperty obj_itself "BatchCameraRender_render_output"  --full path from camera object
      --get name from function parameters
      temp_name = filenameFromPath file_name_only --exclude file name from function argument, in case file path given along with file name
      
      if isNotUndefined temp_string then
      (
        --get path from camera properties
        temp_path = getFilenamePath temp_string --exclude path from full name

        temp_fullname = pathConfig.appendPath temp_path temp_name --create new full name with path and file name from function argument
        
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
  for i in cameraItems do
  (
    if i.selected then
    (
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
  for i in cameraItems do
  (
    if i.selected then
    (
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
  for i in cameraItems do
  (
    if i.selected then
    (
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
  for i in cameraItems do
  (
    if i.selected then
    (
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
  buffer.old_adv_irradmap_loadFileName  = ""
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
    buffer.old_adv_irradmap_loadFileName  = vr.adv_irradmap_loadFileName
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
  local elements_state = getUserProperty camera_to_render "BatchCameraRender_elements_state"
  local not_save_elements = getUserProperty camera_to_render "BatchCameraRender_not_save_elements"

  elementsFullPath = undefined
  if (isNotUndefined elements_state) then
  (
    if (isNotUndefined not_save_elements) and (not_save_elements as booleanClass) then
    (
      elementMgr = maxOps.GetCurRenderElementMgr()
      numOfElements = elementMgr.NumRenderElements()
      if numOfElements != 0 do
      for index=0 to numOfElements-1 do
      (
        elementMgr.SetRenderElementFilename index ""
      )
      elementsFullPath = ""
    )
    else
    (
      elementMgr = maxOps.GetCurRenderElementMgr()
      if shouldBeSaved() and (elements_state as booleanClass) then
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
            syntaxExtraItems = #(#("elementtype", (elementType as string)), #("elementname", (elementName as string)))
            
            --make new file path
            mainOutput = rendOutputFilename
            mainPath = getFilenamePath mainOutput
            mainFileNameOnly = getFilenameFile mainOutput
            mainFileType = getFilenameType mainOutput
            
            newPath = getUserProperty camera_to_render "BatchCameraRender_elements_output"
            if (isNotUndefined newPath) then
            (
              newPath = parse_file_name_template newPath (compose_full_parsing_dictionary camera_to_render extraItems:syntaxExtraItems)
            )
            else
            (
              newPath = mainPath  --Use elements path same as main output if elements path is empty. May be warning message will be useful here.
            )
            
            elementNamePattern = Net_Render_Options_Rollout.renderElementNamePattern.text
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
              elementsNewPath = pathConfig.appendPath mainPath newPath  --path is main + elements subfolder
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
  )
  elementsFullPath
)

fn checkAndAppendMainPath path_string = 
(
      
  mainOutput = rendOutputFilename
  mainPath = getFilenamePath mainOutput
--  mainFileNameOnly = getFilenameFile mainOutput
  
  fullPath = ""
  
  if (isPathAbsolute path_string) then
    fullPath = path_string
  else
    --if subfolder then add subfolder to main path
    fullPath = pathConfig.appendPath mainPath path_string --path is main + elements subfolder
  
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
      temp_string = parse_file_name_template temp_string (compose_full_parsing_dictionary camera_to_render)
      fullPath = checkAndAppendMainPath temp_string     
      
      vr.adv_irradmap_loadFileName = fullPath
    )
    temp_string = getUserProperty camera_to_render "BatchCameraRender_irmap_save_file"
    if isNotUndefined temp_string then
    (
      --this option should be checked for path existance
      --if path doesn't exist try to create it
      temp_string = parse_file_name_template temp_string (compose_full_parsing_dictionary camera_to_render)
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
      temp_string = parse_file_name_template temp_string (compose_full_parsing_dictionary camera_to_render)
      fullPath = checkAndAppendMainPath temp_string
      vr.lightcache_loadFileName = fullPath
    )
    temp_string = getUserProperty camera_to_render "BatchCameraRender_lcmap_save_file"
    if (isNotUndefined temp_string) and shouldBeSaved() then
    (
      --this option should be checked for path existance
      --if path doesn't exist try to create it
      temp_string = parse_file_name_template temp_string (compose_full_parsing_dictionary camera_to_render)
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
--########################--
--ROLLOUT--
--########################--

  rollout batchCameraRender_mainRollOut "Camera Manager Settings"
  (
    button add_button "Add" align:#left width:65 across:5
    button remove_button "Remove" align:#left offset:[-24,0] width:65
    button copy_button "Copy" align:#right offset:[48,0] width:65
    button paste_button "Paste" align:#right offset:[24,0] width:65
    button refresh "Refresh" align:#right width:65

    dotNetControl lv_objects "ListView" height:global_listview_height --height:170
    
    button toggle_select_all "[Un]Select All" align:#left width:70 across:6
    button toggle_check_all "[Un]Check All" align:#left width:70 offset: [-2,0]
    button check_selected "Check Selected" align:#left width:80 offset: [-4,0]
    button set_viewport "Set Viewport" align:#right width:70 offset: [6,0] tooltip:"Sets selected viewport to the camera selected in the list"
    button get_viewport "Get Viewport" align:#right width:70 offset: [2,0] tooltip:"Selects viewport's camera in the list"
    button get_selection "Get Selection" align:#right width:75 offset: [4,0] tooltip:"Selects cameras in the list based on scene selection"
    
    button render_start "Render" align:#left width:70 offset: [0,0] across:5
    button preview_start "Preview" align:#left width:70 offset: [-18,0]
    checkbox net_render "Net Render" align:#left offset: [-15,4]
    checkbox show_net_submit "Show Submit Dialog" align:#left offset: [-20,4]
    button select_camera "Select Camera" align:#right width:75 offset: [0,0] tooltip:"Selects camera object in the scene"
  
    --#####--
    --list button event handlers--
    --#####--
    on batchCameraRender_mainRollOut resized height do saveVar2IniFile "Main_RollOut" "dialog_height" height[2]
    
    on refresh pressed do
    (
      batchCameraRender_reload_cameras lv_objects
      ui_elements_refresh lv_objects
    )
    
    on remove_button pressed do
    (
      local selectItems = batchCameraRender_mainRollOut.lv_objects.SelectedItems.GetEnumerator()
      while selectItems.MoveNext() do
      (
        if (superclassof (selectItems.Current.tag.value) != camera) then
        (
          local camObj = getCameraFromCA (selectItems.Current.tag.value)
          local custDef = (custAttributes.getDef (selectItems.Current.tag.value) baseObject:true)
          custattributes.delete camObj custDef
        )
      )
      BatchCameraRender_reload_cameras lv_objects
    )

    on add_button pressed do
    (
      local batchcam_custattr = attributes BatchCamAttr version:1
      (
      )
      
      if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
      (
        selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
        camera_obj = selected_item.tag.value
        
        if (camera_obj != undefined) and (superclassof camera_obj == camera) then
        (
          custattributes.add camera_obj batchcam_custattr #unique

          BatchCameraRender_reload_cameras lv_objects
        )
      )

    )

    on copy_button pressed do
    (
      BatchCamRenderParamsBuffer = BatchCameraRenderParamsStruct()
      
      if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
      (
        selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
        camera_obj = selected_item.tag.value
        
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
            propertyNames = getPropNames BatchCamRenderParamsBuffer
            for propertyName in propertyNames do
            (
              prop_value = getProperty BatchCamRenderParamsBuffer propertyName
              setUserProperty selected_item (propertyName as string) prop_value
            )
          )
          BatchCameraRender_reload_cameras lv_objects
        )
      )
    )
    
    on net_render changed state do
    (
      saveVar2IniFile "Main_RollOut" "net_render_state" state
      show_net_submit.enabled = state --enable show_net_submit checkbox
      
      ui_elements_refresh lv_objects  --refresh ui
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
      ui_elements_refresh lv_objects
    )
    
    on select_camera pressed do
    (
      camera_selection_names = for obj in LV_ITEMS where obj.selected collect obj.text    --get camera names from selected items in list
      camera_selection = for obj in get_camera_list() where ((findItem camera_selection_names obj.name) != 0) collect obj --collect camera objects with names is in previous array
      
      select camera_selection
    )
    
    --function to set selected camera to active viewport
    on set_viewport pressed do
    (
      local tag_object = undefined
      for item in LV_ITEMS while tag_object == undefined do
      (
        if item.selected then
        (
          tag_object = item.tag.value
        )
      )

      if (tag_object != undefined) then
      (
        local cam_obj = undefined
        if (superclassof tag_object == camera) then
          cam_obj = tag_object
        else
          cam_obj = getCameraFromCA tag_object
        
        viewport.setCamera cam_obj
        
        local xres_prop = getUserProperty tag_object "BatchCameraRender_frame_width"
        local yres_prop = getUserProperty tag_object "BatchCameraRender_frame_heigth"
        if (isNotUndefined xres_prop) and (isNotUndefined yres_prop) then
        (
          if renderSceneDialog.isOpen() then
              renderSceneDialog.close()

          renderWidth = xres_prop as integer
          renderHeight = yres_prop as integer
        )
      )
    )
    
    on get_selection pressed do
    (
      local camobjs = for obj in selection where superclassof obj == camera collect obj
      local selectedItems = #()
      for obj in camobjs do
      (
        local listItems = lv_objects.Items.GetEnumerator()
        while listItems.MoveNext() do
        (
          local camObj = undefined
          local itemObj = listItems.Current.tag.value
          if (superclassof itemObj == camera) then
              camObj = itemObj
            else
              camObj = getCameraFromCA itemObj
          
          if (camObj.name == obj.name) then
          (
            append selectedItems (listItems.Current)
          )
        )
      )
      if selectedItems.count > 0 then
      (
        lv_objects.SelectedItems.Clear()
        lv_objects.BeginUpdate()                                                           
        for item in selectedItems do
          item.selected = true
        lv_objects.EndUpdate()
        lv_objects.HideSelection = false
      )

      populate_ui_elements selectedItems
        ui_elements_refresh lv_objects
    )
    
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
          if (listItems.Current.tag.value.name == camera_name) then
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

      RenderCancelled = false
      --if not netrender then set cancellation detection handler here
      if (not net_render.checked) do
      (
        DialogMonitorOPS.unRegisterNotification id:#get_render_win
        DialogMonitorOPS.RegisterNotification DMNotification id:#get_render_win
        DialogMonitorOPS.Enabled = true
      )
      --  THIS SECTION SHOULD BE UNDER TRY-CATCH BLOCK
      -- try
      (
        local firstCamera = true
        for item in LV_ITEMS while not RenderCancelled do
        (
          if allCameras or item.checked then
          (
            if isVrayRenderer() and (hasproperty (renderers.current) "V_Ray_settings") then
            (
              -- actionMan.executeAction 369690881 "1"
              if not firstCamera then
                sleep 2
              firstCamera = false
            )
            --get camera name
            local camera_to_render = item.tag.value
            local cam_obj = undefined
            if (superclassof camera_to_render == camera) then
              cam_obj = camera_to_render
            else
              cam_obj = getCameraFromCA camera_to_render

            --unhide camera objects
            if (cam_obj.isHiddenInVpt) then
            (
              cam_obj.isHidden = false
              hideByCategory.cameras = false
            )
            -- set the render preset
            temp_string = getUserProperty camera_to_render "BatchCameraRender_render_preset"
            if isNotUndefined temp_string then
            (
              setSilentMode true --set silent to prevent dialogs with gamma warning
              presetsArray = #()
              if (maxVersion())[1] >= 11000 then  --run renderPresetMRUList command only if script is running under 3dsmax 2009+
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
                temp_frame_range = get_key_range cam_obj
                rendStart = temp_frame_range[1].frame
                rendEnd = temp_frame_range[2].frame
              )
              else if isNotUndefined temp_string1 then
              ( --render_frames
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
              (isNotUndefined reg_w) and (isNotUndefined reg_h) then
              (
                reg_x = reg_x as float
                reg_y = reg_y as float
                reg_w = reg_w as float
                reg_h = reg_h as float
                --convert percentage to viewport sizes
                local x = (renderWidth / 100.0) * reg_x
                local y = (renderHeight / 100.0) * reg_y
                local w = ((renderWidth / 100.0) * (reg_w - reg_x))
                local h = ((renderHeight / 100.0) * (reg_h - reg_y))
                viewport.setRegionRect (viewport.activeViewport) (box2 x y w h) 
              )
            )

            --get and set file name
            temp_string = getUserProperty camera_to_render "BatchCameraRender_render_output"
            if (shouldBeSaved()) and (isNotUndefined temp_string) then
            (
              temp_string = parse_file_name_template temp_string (compose_parsing_dictionary camera_to_render)
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
              if isNotUndefined temp_string2 then --turn on include lights.
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
              temp_string = parse_file_name_template temp_string (compose_parsing_dictionary camera_to_render)
              sceneStateMgr.RestoreAllParts temp_string
            )

            --set state set
            local ss_class = dotnetclass "Autodesk.Max.StateSets.Plugin"
            if ss_class != undefined then --if state sets supported
            (
              temp_string = getUserProperty camera_to_render "BatchCameraRender_state_set"
              if isNotUndefined temp_string then
              (
                local stateSetsDotNetObject = dotNetObject "Autodesk.Max.StateSets.Plugin"
                local stateSets = stateSetsDotNetObject.Instance
                local masterState = stateSets.EntityManager.RootEntity.MasterStateSet
                if (masterState.CurrentState != undefined) then --reset the state before applying anything
                  masterState.SetCurrentStateSet undefined
                local state_set = masterState.GetDescendant temp_string
                if (state_set != undefined) then
                  masterState.SetCurrentStateSet #(state_set)
              )
            )
            --scripts setting
            callbacks.removeScripts id:#BatchCameraRender
            --set global variables to be visible in submit and render scripts
            batchCameraRender_currentcamera = cam_obj
            
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
              setUserProperty item "BatchCameraRender_lastRenderPath" rendOutputFilename
            
            --start render
            if (not preview) and (Net_Render_Options_Rollout.UseDeadline.checked) then
            (
              viewport.setCamera cam_obj
              submit_to_deadline cam_obj
            )
            else if (not preview) and net_render.checked and (not show_net_submit.checked) then
            (
              net_render_auto_submit cam_obj
            )
            else
            (
              if (not preview) then
                rendUseNet = net_render.checked
              else
                rendUseNet = false
              
              viewport.setCamera cam_obj
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
      -- catch
      -- (
      --  messagebox (getCurrentException()) title:"Error"
      --  restore_lighting_state()
      -- )
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
          -- try
          (
            maxscript_file_name = Scripts_Rollout.onsubmit_script.text
            if isNotUndefinedOrEmpty maxscript_file_name then
            (
              if (doesFileExist maxscript_file_name) then
                filein maxscript_file_name
            )
          )
          -- catch
          -- (
          --    messagebox (getCurrentException()) title:"Submit Script Error"
          --  )
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
      if (lv_objects.items.count == 0) then --only call refresh if empty listview, because init_ListView/fill_ListView will refresh anyway
        ui_elements_refresh lv_objects
      
      --add onopen callback
      callbacks.addScript #filePostOpen "batchCameraRender_reload_cameras batchCameraRender_mainRollOut.lv_objects" id:#batchcam
      --  callbacks.addScript #filePostOpen "batchCameraRender_reset_render_counter()" id:#batchcam
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
      if (globalvars.isGlobal #batchCameraRender_loading_items) then
      (
        if not (globalvars.get #batchCameraRender_loading_items) then
        (
          ui_elements_refresh lv_objects
          globalvars.set #batchCameraRender_loading_items false
        )
        else
        (
          globalvars.set #batchCameraRender_loading_items ((lv_objects.items.count-1) != val.item.index) --call refresh when itemcheck
        )
      )
      else
      (
        global batchCameraRender_loading_items = false
      )
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
          setUserProperty listItem ("BatchCameraRender_item_index") (listItem.index as string)
        )
        LV_ITEMS = for i=0 to (lv_objects.Items.Count - 1) collect (lv_objects.Items.Item i)
        for i=1 to LV_ITEMS.count do
        (
          BatchCam_listItem_state[i] = LV_ITEMS[i].checked
        )
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
      spinner preview_width1 "Preview Width: " range:[1,10000,0] type:#integer width:90 align:#left visible:false --simple filler
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
        obj_itself = selected_item.tag.value
        
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
        
        
        property_names = #( \
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
    
    group "Backburner Connection Options"
    (
      checkbox Auto_Search "Automatic Search" align:#left offset: [0,0]
      edittext Name_Or_Mask "Manager Name or IP Address:" labelOnTop:true align:#left fieldWidth:120 offset: [0,0] across:4
      edittext Port "Port:" labelOnTop:true align:#left fieldWidth:60 offset: [35,0] tooltip:""
      label label1 "Submit Job As:" align:#right offset: [50,20]
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
    
    group "Deadline Connection Options"
    (
      checkbox UseDeadline "Use Deadline" align:#left offset:[0,0]
      edittext DeadlineRepo "Deadline Repository:" labelOnTop:false align:#left fieldWidth:250 offset:[0,0]
    )

    on UseDeadline changed val do
    (
      saveVar2IniFile "Deadline settings" "use_deadline" val
    )

    on DeadlineRepo changed val do
    (
      saveVar2IniFile "Deadline settings" "repository" val
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
      property_names = #( "BatchCameraRender_UserKey1", \
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

      --deadline repository
      local repo = loadVarFromIniFile "Deadline settings" "repository"
      if repo != undefined then
        DeadlineRepo.text = repo
      else
      (
        DeadlineRepo.text = @"\\server\DeadlineRepository"
        saveVar2IniFile "Deadline settings" "repository" DeadlineRepo.text 
      )

      if (temp_state = loadVarFromIniFile "Deadline settings" "use_deadline") != undefined then
        UseDeadline.checked = (temp_state as booleanClass)
      else
      (
        UseDeadline.checked = false
        saveVar2IniFile "Deadline settings" "use_deadline" false
      )
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
    dropdownlist out_size_list width:200  across:3
    button clear_resolution "Clear" width:45  offset: [65,0] align:#right
    button save_as_default  "Save to INI..." width:85 align:#right
    
    label label1 "Width:" align:#left across:7
    spinner frame_width range:[1,100000,640] type:#integer align:#left width:60 offset: [-32,0]

    spinner image_aspect_spinner "Aspect:" range:[0,100000,1.333] type:#float width:90 offset: [-20,0]
    checkbutton lock_aspect "Lock" width:30 align:#left offset: [2,-3]
    
    checkbutton use_region "Region" align:#left width:40 offset:[10,-3]
    spinner region_x "X:" range:[0,100,0] type:#float align:#left width:80 offset: [-10,0]
    spinner region_y "Y:" range:[0,100,0] type:#float align:#left width:80 offset: [0,0]

    label label3 "Height:" align:#left across:10
    spinner frame_height range:[1,100000,480] type:#integer width:60 align:#left offset: [-13,0]
    button double_resolution "x2" width:30 align:#left offset: [5,-2]
    button half_resolution "1/2" width:30 align:#left offset: [-8,-2]
    button set_resolution_to_max "Set" width:30 align:#left offset: [-20,-2]
    button get_resolution_from_max "Get" width:30 align:#left offset: [-33,-2]

    button set_region_to_max "Set" width:30 align:#left offset: [-30,-2]
    button get_region_from_max "Get" width:30 align:#left offset: [-42,-2]

    spinner region_w "W:" range:[0,100,0] type:#float align:#left width:92 offset: [-53, 0]
    spinner region_h "H:" range:[0,100,0] type:#float align:#left width:85 offset: [-22,0]
    
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
        camera_object = selected_item.tag.value
        
        property_names = #( "BatchCameraRender_frame_width", \
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
          setUserProperty i "BatchCameraRender_frame_width" undefined
          setUserProperty i "BatchCameraRender_frame_heigth" undefined
          setUserProperty i "BatchCameraRender_image_aspect" undefined
          setUserProperty i "BatchCameraRender_region_x" undefined
          setUserProperty i "BatchCameraRender_region_y" undefined
          setUserProperty i "BatchCameraRender_region_w" undefined
          setUserProperty i "BatchCameraRender_region_h" undefined
          setUserProperty i "BatchCameraRender_region_enabled" undefined
          
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
      set_resolution_to_max.pressed()
      local width = renderWidth
      local height = renderHeight
      if (not frame_width.indeterminate) and (not frame_height.indeterminate) then
      (
        width = frame_width.value
        height = frame_height.value
      )
      if (not region_x.indeterminate) and (not region_y.indeterminate) and\
      (not region_w.indeterminate) and (not region_w.indeterminate) and\
      (not frame_width.indeterminate) and (not frame_height.indeterminate) then
      (
        setRenderType #region
        --convert percentage to viewport sizes
        local x = (width / 100.0) * (region_x.value as float)
        local y = (height / 100.0) * (region_y.value as float)
        local w = ((width / 100.0) * ((region_w.value - region_x.value) as float))
        local h = ((height / 100.0) * ((region_h.value - region_y.value) as float))
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
      local width_ratio = 1.0, height_ratio = 1.0
      if (not frame_width.indeterminate) and (not frame_height.indeterminate) then
      (
        width = frame_width.value
        height = frame_height.value
        width_ratio = renderWidth as float / (frame_width.value as float)
        height_ratio = renderHeight as float / (frame_height.value as float)
      )
      local box_x = (region_box.x as float) / width_ratio
      local box_y = (region_box.y as float) / width_ratio
      local box_w = (region_box.w as float) / height_ratio
      local box_h = (region_box.h as float) / height_ratio
      local x = (box_x / width) * 100
      local y = (box_y / height) * 100
      local w = (((box_x + box_w) as float) / width) * 100
      local h = (((box_y + box_h) as float) / height) * 100

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
      checkbox save_elements "Enable Elements" tooltip:"Enable Render Elements" align:#left
      checkbox not_save_elements "Do not save Elements" toolTip:"Rendering, but not save Render Elements" align:#left
      button elements_folder_button "..." align:#left width:40 offset: [0,-2] across:2
      edittext elements_path width:320 align:#left offset: [-168,0]
    )
    
    on save_as_default pressed do
    (
      if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
      (
        selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
        camera_object = selected_item.tag.value
        
        property_names = #( \
                        "BatchCameraRender_render_output", \
                        "BatchCameraRender_elements_state", \
                        "BatchCameraRender_not_save_elements", \
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
      info_string += "%cameraname%\n%scenestate%\n%renderpreset%\n%resolution%\n%date%\n%scenename%\n%projectfolder% and %projectpath%\n%projectname%\n"
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
        parsed_path = parse_file_name_template temp_path (compose_parsing_dictionary (selected_item.tag.value))
        temp_path  = parsed_path
      )
    
--      format "temp_path1 - %\n" temp_path
      while (temp_path != "") and (not (doesFileExist temp_path)) do
        temp_path = pathConfig.removePathLeaf temp_path
--      format "temp_path2 - %\n" temp_path
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
    
    on not_save_elements changed state do
    (
      set_not_save_elements LV_ITEMS state
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
          setUserProperty i "BatchCameraRender_render_output" undefined
          clear_sub_item i "path"
          setUserProperty i "BatchCameraRender_elements_state" undefined
          clear_sub_item i "elements_state"
          setUserProperty i "BatchCameraRender_not_save_elements" undefined
          clear_sub_item i "not_save_elements"
          setUserProperty i "BatchCameraRender_elements_output" undefined
          clear_sub_item i "elements_path"
        )
      )
      populate_filename_fields LV_ITEMS
    )
    
        --open explorer window
    on open_last_folder pressed do
    (
      temp_path = getFilenamePath last_render_path.text
    
--      format "temp_path3 - %\n" temp_path
      while (temp_path != "") and (not (doesFileExist temp_path)) do
        temp_path = pathConfig.removePathLeaf temp_path
--      format "temp_path4 - %\n" temp_path
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
      button set_current "Set Current" offset: [-20,-3] width:65 align:#left    --button to set current frame
      
      button clear_frames "Clear" width:45 align:#right
      button save_as_default  "Save to INI..." width:85 align:#right
      
      radiobuttons rendType2 labels:#("Range") columns:1 default:0 align:#left across:6
      spinner render_from  range:[-10000,10000,0] type:#integer width:70 align:#left offset: [-10,0] enabled:false
      label label1 "To" align:#left offset: [-9,0]
      spinner render_to  range:[-10000,10000,10] type:#integer width:70 align:#left offset: [-65,0] enabled:false
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
        camera_object = selected_item.tag.value
        
        property_names = #( \
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
          setUserProperty i "BatchCameraRender_framerange_from" undefined
          setUserProperty i "BatchCameraRender_framerange_to" undefined
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
      checkbox distr_rendering "Distributed Rendering" offset:[0,0] align:#left enabled:false
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
        camera_object = selected_item.tag.value
        
        property_names = #( \
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
          for property_name in BatchCam_VrayPropertiesNames do
          (
            setUserProperty i ("BatchCameraRender_" + property_name) undefined
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
  
    on distr_rendering changed state do
      saveVar2IniFile "Vray_Settings_Rollout" "vray_distributed_rendering" state
  
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
      BatchCam_VrayPropertiesMappingArray[2] = BatchCam_VrayPropertiesMapping BatchCam_VrayPropertiesNames[2] Vray_Settings_Rollout.auto_save_irmap   "checkbox"
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

      if (temp_state = loadVarFromIniFile "Vray_Settings_Rollout" "vray_distributed_rendering") != undefined then
        distr_rendering.checked = (temp_state as booleanClass)  
      else
      (
        distr_rendering.checked = false
        saveVar2IniFile "Vray_Settings_Rollout" "vray_distributed_rendering" false
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
  
  rollout Scene_States_Rollout "Scene State - State Sets - Render Preset"
  (
    button clear_scene_states "Clear" width:45 across:2 offset:[142,0] align:#right     
    button save_as_default  "Save to INI..." width:85 align:#right
    label scene_states_list2_label "Scene State" align:#left across:4
    dotNetControl scene_states_list2 "ComboBox" width:150 height:21 offset:[-120,20] align:#left
    dropdownlist state_sets_list "State Sets" width:150 align:#center offset:[-60,2]
    dropdownlist render_preset_list "Render Preset" width:150 align:#right offset:[0,2]
    
    on save_as_default pressed do
    (
      if (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Count == 1) then
      (
        selected_item = (batchCameraRender_mainRollOut.lv_objects.SelectedItems.Item 0)
        camera_object = selected_item.tag.value
        
        property_names = #( \
                      "BatchCameraRender_scene_state", \
                      "BatchCameraRender_state_set", \
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

      local ss_class = dotnetclass "Autodesk.Max.StateSets.Plugin"
      if ss_class != undefined then --if state sets supported
      (
        state_sets_list.items = join #("undefined") (get_state_sets_array())
      )

      render_preset_list.items = join #("undefined") (get_render_preset_array())
    )
    
    on state_sets_list selected item_num do
    (
      set_string_property LV_ITEMS "state_set" state_sets_list.selected
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
          setUserProperty i "BatchCameraRender_scene_state" undefined
          setUserProperty i "BatchCameraRender_render_preset" undefined
          setUserProperty i "BatchCameraRender_state_set" undefined
          clear_sub_item i "scene_state"
          clear_sub_item i "render_preset"
          clear_sub_item i "state_set"
          scene_states_list2.SelectedIndex = 0
          render_preset_list.selection = 1
          state_sets_list.selection = 1
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
      property_names = #( \
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
        camera_object = selected_item.tag.value
        
        property_names = #( \
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
        camera_object = selected_item.tag.value
        
        property_names = #( \
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
    label lb_author "(C) 2009-2016, Sergo Pogosyan"
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
      render_buttons_active false
      
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