module notepadpp

import util.winapi { send_message, RECT }

pub struct TbData {
	client voidptr		// client Window Handle
	name &u16			// name of plugin (shown in window)
	dlg_id int			// a funcItem provides the function pointer to start a dialog. Please parse here these ID

	// user modifications
	mask u32			// mask params: look to above defines
	icon_tab voidptr	// icon for tabs
	add_info &u16		// for plugin to display additional informations

	// internal data, do not use !!!  - except for inializing it.
	rc_float RECT		// floating position
	prev_cont int		// stores the privious container (toggling between float and dock)
	module_name &u16	// it's the plugin file name. It's used to identify the plugin
} 

pub struct CommunicationInfo {
pub:
	internal_msg int
	src_module_name &u16
	info voidptr
}

struct SessionInfo {
	session_file_path_name &u16
	nb_file int
	files voidptr //TCHAR** 
}

struct ToolbarIcons {
	h_toolbar_bmp voidptr
	h_toolbar_icon voidptr
}

pub struct Npp {
mut:
	hwnd voidptr
}

[inline]
fn alloc_wide(size isize) &byte { return vcalloc(int(size) * 2 ) }

[inline]
fn (n Npp) call(msg int, wparam usize, lparam isize) isize {
	return send_message(n.hwnd, u32(msg), wparam, lparam)
}

pub fn (n Npp) get_filename_from_id(buffer_id usize) string {
	buffer_size := n.call(nppm_getfullpathfrombufferid, buffer_id, 0) + 1
	if buffer_size == 0 { return ''}  // nppm_getfullpathfrombufferid returns -1 on error
	mut buffer := alloc_wide(buffer_size)
	n.call(nppm_getfullpathfrombufferid, buffer_id, voidptr(buffer))
	return unsafe { string_from_wide(&u16(buffer)) }
}

pub fn (n Npp) get_current_buffer_id() isize {
	return n.call(nppm_getcurrentbufferid, 0, 0)
}

pub fn (n Npp) get_current_view() isize {
	return n.call(nppm_getcurrentview, 0, 0)
}

pub fn (n Npp) get_language_name_from_id(buffer_id usize) string {
	lang_type := n.call(nppm_getbufferlangtype, buffer_id, 0)
	buffer_size := n.call(nppm_getlanguagename, usize(lang_type), 0) + 1
	mut buffer := alloc_wide(buffer_size)
	
	n.call(nppm_getlanguagename, usize(lang_type), voidptr(buffer))
	mut lang_name := unsafe { string_from_wide(&u16(buffer)) }
	return if lang_name.starts_with('udf - ') { lang_name[6..].to_lower() } else { lang_name.to_lower() }
}

pub fn (n Npp) get_language_name_for_current_buffer() string {
	id := n.get_current_buffer_id()
	return n.get_language_name_from_id(usize(id))
}

pub fn (n Npp) get_plugin_config_dir() string {
	buffer_size := n.call(nppm_getpluginsconfigdir, 0, 0) + 1
	mut buffer := alloc_wide(buffer_size)
	
	n.call(nppm_getpluginsconfigdir, usize(buffer_size), voidptr(buffer))
	return unsafe { string_from_wide(&u16(buffer)) }
}

pub fn (n Npp) open_document(filename string) {
	wide_filename := filename.to_wide()
	n.call(nppm_doopen, 0, isize(wide_filename))
}

pub fn(n Npp) create_scintilla(parent_hwnd voidptr) voidptr {
	return voidptr(n.call(nppm_createscintillahandle, 0, isize(parent_hwnd)))
}

pub fn(n Npp) register_dialog(tbdata TbData) {
	n.call(nppm_dmmregasdckdlg, 0, voidptr(&tbdata))
}

pub fn(n Npp) show_dialog(hwnd voidptr) {
	n.call(nppm_dmmshow, 0, hwnd)
}

pub fn(n Npp) hide_dialog(hwnd voidptr) {
	n.call(nppm_dmmhide, 0, hwnd)
}

pub fn(n Npp) get_editor_default_background_color() int {
	return int(n.call(nppm_geteditordefaultbackgroundcolor, 0, 0))
}

pub fn(n Npp) get_editor_default_foreground_color() int {
	return int(n.call(nppm_geteditordefaultforegroundcolor, 0, 0))
}

pub fn(n Npp) get_current_filename() string {
	id := n.get_current_buffer_id()
	filename := n.get_filename_from_id(usize(id))
	return filename
}
