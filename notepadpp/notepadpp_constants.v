module notepadpp

pub const (
	wm_user = 1024
	nppmsg = wm_user + 1000

	nppm_getcurrentscintilla = nppmsg + 4
	nppm_getcurrentlangtype = nppmsg + 5
	nppm_setcurrentlangtype = nppmsg + 6

	nppm_getnbopenfiles = nppmsg + 7
	all_open_files = 0
	primary_view = 1
	second_view = 2

	nppm_getopenfilenames = nppmsg + 8
	nppm_modelessdialog = nppmsg + 12
	modelessdialogadd = 0
	modelessdialogremove = 1

	nppm_getnbsessionfiles = nppmsg + 13
	nppm_getsessionfiles = nppmsg + 14
	nppm_savesession = nppmsg + 15
	nppm_savecurrentsession = nppmsg + 16
	nppm_getopenfilenamesprimary = nppmsg + 17
	nppm_getopenfilenamessecond = nppmsg + 18
	nppm_createscintillahandle = nppmsg + 20
	nppm_destroyscintillahandle = nppmsg + 21
	nppm_getnbuserlang = nppmsg + 22
	nppm_getcurrentdocindex = nppmsg + 23
	main_view = 0
	sub_view = 1

	nppm_setstatusbar = nppmsg + 24
	statusbar_doc_type = 0
	statusbar_doc_size = 1
	statusbar_cur_pos = 2
	statusbar_eof_format = 3
	statusbar_unicode_type = 4
	statusbar_typing_mode = 5

	nppm_getmenuhandle = nppmsg + 25
	npppluginmenu = 0
	nppmainmenu = 1
	nppm_encodesci = nppmsg + 26
	nppm_decodesci = nppmsg + 27
	nppm_activatedoc = nppmsg + 28
	nppm_launchfindinfilesdlg = nppmsg + 29
	nppm_dmmshow = nppmsg + 30
	nppm_dmmhide = nppmsg + 31
	nppm_dmmupdatedispinfo = nppmsg + 32
	nppm_dmmregasdckdlg = nppmsg + 33
	nppm_loadsession = nppmsg + 34
	nppm_dmmviewothertab = nppmsg + 35
	nppm_reloadfile = nppmsg + 36
	nppm_switchtofile = nppmsg + 37
	nppm_savecurrentfile = nppmsg + 38
	nppm_saveallfiles = nppmsg + 39
	nppm_setmenuitemcheck = nppmsg + 40
	nppm_addtoolbaricon = nppmsg + 41
	nppm_getwindowsversion = nppmsg + 42
	nppm_dmmgetpluginhwndbyname = nppmsg + 43
	nppm_makecurrentbufferdirty = nppmsg + 44
	nppm_getenablethemetexturefunc = nppmsg + 45
	nppm_getpluginsconfigdir = nppmsg + 46
	nppm_msgtoplugin = nppmsg + 47
	nppm_menucommand = nppmsg + 48
	nppm_triggertabbarcontextmenu = nppmsg + 49
	nppm_getnppversion = nppmsg + 50
	nppm_hidetabbar = nppmsg + 51
	nppm_istabbarhidden = nppmsg + 52
	nppm_getposfrombufferid = nppmsg + 57
	nppm_getfullpathfrombufferid = nppmsg + 58
	nppm_getbufferidfrompos = nppmsg + 59
	nppm_getcurrentbufferid = nppmsg + 60
	nppm_reloadbufferid = nppmsg + 61
	nppm_getbufferlangtype = nppmsg + 64
	nppm_setbufferlangtype = nppmsg + 65
	nppm_getbufferencoding = nppmsg + 66
	nppm_setbufferencoding = nppmsg + 67
	nppm_getbufferformat = nppmsg + 68
	nppm_setbufferformat = nppmsg + 69
	nppm_hidetoolbar = nppmsg + 70
	nppm_istoolbarhidden = nppmsg + 71
	nppm_hidemenu = nppmsg + 72
	nppm_ismenuhidden = nppmsg + 73
	nppm_hidestatusbar = nppmsg + 74
	nppm_isstatusbarhidden = nppmsg + 75
	nppm_getshortcutbycmdid = nppmsg + 76
	nppm_doopen = nppmsg + 77
	nppm_savecurrentfileas = nppmsg + 78
	nppm_getcurrentnativelangencoding = nppmsg + 79
	nppm_allocatesupported = nppmsg + 80
	nppm_allocatecmdid = nppmsg + 81
	nppm_allocatemarker = nppmsg + 82
	nppm_getlanguagename = nppmsg + 83
	nppm_getlanguagedesc = nppmsg + 84
	nppm_showdocswitcher = nppmsg + 85
	nppm_isdocswitchershown = nppmsg + 86
	nppm_getappdatapluginsallowed = nppmsg + 87
	nppm_getcurrentview = nppmsg + 88
	nppm_docswitcherdisablecolumn = nppmsg + 89
	nppm_geteditordefaultforegroundcolor = nppmsg + 90
	nppm_geteditordefaultbackgroundcolor = nppmsg + 91
	nppm_setsmoothfont = nppmsg + 92
	nppm_seteditorborderedge = nppmsg + 93
	nppm_savefile = nppmsg + 94
	nppm_disableautoupdate = nppmsg + 95
	nppm_removeshortcutbycmdid = nppmsg + 96
	nppm_getpluginhomepath = nppmsg + 97
	nppm_getsettingsoncloudpath = nppmsg + 98

	var_not_recognized = 0
	full_current_path = 1
	current_directory = 2
	file_name = 3
	name_part = 4
	ext_part = 5
	current_word = 6
	npp_directory = 7
	current_line = 8
	current_column = 9
	npp_full_file_path = 10
	getfilenameatcursor = 11

	runcommand_user = wm_user + 3000
	nppm_getfullcurrentpath = runcommand_user + full_current_path
	nppm_getcurrentdirectory = runcommand_user + current_directory
	nppm_getfilename = runcommand_user + file_name
	nppm_getnamepart = runcommand_user + name_part
	nppm_getextpart = runcommand_user + ext_part
	nppm_getcurrentword = runcommand_user + current_word
	nppm_getnppdirectory = runcommand_user + npp_directory
	nppm_getfilenameatcursor = runcommand_user + getfilenameatcursor
	nppm_getcurrentline = runcommand_user + current_line
	nppm_getcurrentcolumn = runcommand_user + current_column
	nppm_getnppfullfilepath = runcommand_user + npp_full_file_path

	// Notification code
	nppn_first = 1000
	nppn_ready = nppn_first + 1
	nppn_tbmodification = nppn_first + 2
	nppn_filebeforeclose = nppn_first + 3
	nppn_fileopened = nppn_first + 4
	nppn_fileclosed = nppn_first + 5
	nppn_filebeforeopen = nppn_first + 6
	nppn_filebeforesave = nppn_first + 7
	nppn_filesaved = nppn_first + 8
	nppn_shutdown = nppn_first + 9
	nppn_bufferactivated = nppn_first + 10
	nppn_langchanged = nppn_first + 11
	nppn_wordstylesupdated = nppn_first + 12
	nppn_shortcutremapped = nppn_first + 13
	nppn_filebeforeload = nppn_first + 14
	nppn_fileloadfailed = nppn_first + 15
	nppn_readonlychanged = nppn_first + 16

	docstatus_readonly = 1
	docstatus_bufferdirty = 2

	nppn_docorderchanged = nppn_first + 17
	nppn_snapshotdirtyfileloaded = nppn_first + 18
	nppn_beforeshutdown = nppn_first + 19
	nppn_cancelshutdown = nppn_first + 20
	nppn_filebeforerename = nppn_first + 21
	nppn_filerenamecancel = nppn_first + 22
	nppn_filerenamed = nppn_first + 23
	nppn_filebeforedelete = nppn_first + 24
	nppn_filedeletefailed = nppn_first + 25
	nppn_filedeleted = nppn_first + 26

	// docking dialog related
	//   defines for docking manager
	cont_left	 = 0
	cont_right	 = 1
	cont_top	 = 2
	cont_bottom	 = 3
	dockcont_max = 4	
	// mask params for plugins of internal dialogs
	dws_icontab			= 0x00000001			// icon for tabs are available
	dws_iconbar			= 0x00000002			// icon for icon bar are available (currently not supported)
	dws_addinfo			= 0x00000004			// additional information are in use
	dws_paramsall		= (dws_icontab|dws_iconbar|dws_addinfo)

	// default docking values for first call of plugin
	dws_df_cont_left	= (cont_left	<< 28)	// default docking on left
	dws_df_cont_right	= (cont_right	<< 28)	// default docking on right
	dws_df_cont_top		= (cont_top	<< 28)	// default docking on top
	dws_df_cont_bottom	= (cont_bottom << 28)	// default docking on bottom
	dws_df_floating		= 0x80000000			// default state is floating	
)