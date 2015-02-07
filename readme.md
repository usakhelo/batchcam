BatchCameraRender
=================

### The Idea

Very first idea to write such script came to me when I started to learn Houdini. Houdini has node architecture, and for the rendering it uses output nodes. These nodes have properties to specify included/excluded lights and objects, so you can create several output nodes and specify camera/lighting/objects relationship for each node. It's a great feature and you can implement same relationship in 3dsmax using batch render command with "scene states" where you can specify lighting options and "render preset" where you can specify rendering properties.

So what the problem with batch render? It lacks two features - you can not specify nonsequential frames and you can not specify new output file location for several cameras at once. So I've started to write this tool to replace standard batch render.

### How it works

When you start this script it collects all cameras in scene and list them in the dialog box. To each of these cameras you can assign frame resolution, number of frames to render including nonsequential frames, output file location and many other options. This infomation is saved with the AppData method to each camera object. Assigned properties can be changed for one or several selected cameras.

### Main Features

Here is the list of options that can be assigned to each camera.

* IMAGE RESOLUTION. Resolution could be selected from the listbox or entered in the width and height spinners. Next to these spinners are placed two buttons to quickly double or halve the resolution. There are also two buttons to get and set resolution from/to Render Setup window.

* OUTPUT FILE LOCATION. This property is split to folder path and file name so file and folder could be changed separetaly for selected cameras. In this section there is the Render Element subfolder option. Relative or absolute path could be used for the Render Elements. All the file/path properties support keyword syntax that will be described later.

* FRAME RANGE. Among the standard frame number options here is the Anim.Range option. With this option script calculates animated range of the selected camera and uses that range in rendering.

* SCENE STATE AND RENDER PRESET. This section contains only two dropdown list with scene states and render presets to assign to camera.

* VRAY OPTIONS. For the Vray renderer script contains some global options and some options that could be assigned to camera. Global options duplicates the standard Vray Global and FrameBuffer options. Per-camera options are the Irradiance and Lightcache map files.

* LIGHT ASSIGNMENT. In this section lighting state of the scene can be assigned to the camera. Lighting state could be set up by the scene states, but this section gives slightly different control. Section contains three lists: 'Solo Light' list contains lights that will be the only lights turned on during the rendering, 'Forced On' and 'Forced Off' lights are turned on or off respectively during the rendering.

* SCRIPTS (BETA). In this section script files can be assigned to the camera. There are to sub-section: Submit Scripts and Render Scripts. Submit Scripts run on local machine before render jobs are submitted to render servers, Render Script run on render servers. Note that this section is in beta stage, especially Render Scripts, so use it carefully.

All sections contain Clear button to delete section properties and use default ones.

### Some Other Features and Usabitility

Keyword syntax is one of the strongest part of the script. Special keywords can be used in all file and folder paths to include camera name, scene state name, date, resolution, scene file name and project folder name in that paths.

Here is the list of currently supported keywords (most have self-explained name):

- %cameraname%
- %scenestate%
- %renderpreset%
- %resolution%
- %date%
- %scenename%
- %projectfolder% and %projectpath% - returns 3dsmax project full pah
- %scenefolder% and %scenepath% - returns full pah of the current scene
- %elementname% and %elementtype% - return name and type of the Render Element, works only in the Render Element (Sub)Folder field and in Render Elements name template
- %up% - this keyword changes the preceding path by going up-folder
- %trynum% - counts how many times the Render button was pressed. Actually uses Render Try Counter spinner located in Options rollout. Reset on new file creation, on file opening and on max reset.
- %mainoutput% and %renderfile% - returns only file name of the main file output. Can be used in all fields except the main ouput path and filename.
- %mainpath% and %renderpath% returns path of the main file. Works in all fields except the main ouput path and filename.

Example usage:

path like this: D:\Work\%projectname%\%date%\%cameraname%.jpg 

produces D:\Work\SomeProject\2010-03-10\interior.jpg

Also script provides a way to specify custom keywords - User Key/Value fields located in the Options rollout. These fields allow user to define custom template keywords. User Key contains the keyword and User Value contains computable expression - e.g. you can enter any maxscript expression into field and it will be computed for every camera before the rendering. For example, if you want to use username in the file or folder name you just enter word "username" to the User Key and sysInfo.username expression to the User Value field. After that %username% keyword will be replaced with actual username of the user who sends the job to the rendering. If the expression could not be computed it is replaced by "ErrUserVal" string. Make sure your expression works in maxscript listener before you use it in the User Value field.

### Default values for all the properties.

Values of all properties in script can be set as default. These values will be assigned to all newly created cameras in scene and will override undefined values in all cameras. There are two kind of default values in the script - Global and Local. Local values, if they exist, override the global values. Global values are stored in the INI file BatchCameraRender.ini and located in the %LOCALAPPDATA%/3dsmax/.../plugcfg/BatchCameraRender folder. Local default values are stored in the INI files that can be located in scene folder and/or in any folder up to root level. You can have one ini file in root folder of all projects and another ini file in each project. In this case settings from root ini file will be overridden by project ini file. This allows you to have project wide settings and default settings specific for each project.

To set the global defaul values, click Save All Settings as Global Defaults button in Options rollout. To set the local defaul values, click To Local Defaults located in each section ( you have to enter local INI path before that ). Alternatively you can edit INI files in text editor, use Open Global/Local INI File button in Options rollout.

All specified paths that don't exist at moment the rendering starts will be created automatically. The "Create new paths silently" checkbox could be used to turn this feature on or off.

Network rendering is also automated - several netrender jobs can be sent with one click, bypassing Submit Network Job Assignement window.

Several buttons below the main camera list are given to make the work with large list more comfortable.

Macroscript is designed as standard dialog window - toolbar button works as a switch, first click runs the script, the second closes the script.

Rollout state and window size and position is saving during the session. Upon the render starts checking is performed if render type is set to view - if render type set to region, blowup or something except view mode warning dialog box appears.

### Limitations and Warning

Some of the properties (if not all) doesn't pass very strict checking. For example if the Vray GI is turned off and in the script Irradiance Map map save file name is specified then the file wouldn't be saved.

I was using this script every day and I'm trying to make it stable but it still may contain some bugs. Use this script at your own risk.

### Thanks

I would like to thank everyone who uses this script and helps me with suggestions and bugreports.