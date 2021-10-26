module scintilla

import winapi { send_message }

pub type SCI_FN_DIRECT = fn(hwnd isize, msg u32, param usize, lparam isize) isize

struct SciNotifyHeader {
pub mut:
	hwnd_from voidptr
	id_from usize
	code u32
}

pub struct SCNotification {
pub mut:
	nmhdr SciNotifyHeader
	position isize					// SCN_STYLENEEDED, SCN_DOUBLECLICK, SCN_MODIFIED, SCN_MARGINCLICK, 
									// SCN_NEEDSHOWN, SCN_DWELLSTART, SCN_DWELLEND, SCN_CALLTIPCLICK, 
									// SCN_HOTSPOTCLICK, SCN_HOTSPOTDOUBLECLICK, SCN_HOTSPOTRELEASECLICK, 
									// SCN_INDICATORCLICK, SCN_INDICATORRELEASE, 
									// SCN_USERLISTSELECTION, SCN_AUTOCSELECTION
	
	ch int							// SCN_CHARADDED, SCN_KEY, SCN_AUTOCCOMPLETED, SCN_AUTOCSELECTION, 
									// SCN_USERLISTSELECTION
	
	modifiers int					// SCN_KEY, SCN_DOUBLECLICK, SCN_HOTSPOTCLICK, SCN_HOTSPOTDOUBLECLICK, 
									// SCN_HOTSPOTRELEASECLICK, SCN_INDICATORCLICK, SCN_INDICATORRELEASE, 
	
	modification_type int			// SCN_MODIFIED
	
	text &char						// SCN_MODIFIED, SCN_USERLISTSELECTION, 
									// SCN_AUTOCSELECTION, SCN_URIDROPPED
	
	length isize					// SCN_MODIFIED 
	lines_added isize				// SCN_MODIFIED 
	message int						// SCN_MACRORECORD 
	wparam usize					// SCN_MACRORECORD 
	lparam isize					// SCN_MACRORECORD 
	line isize						// SCN_MODIFIED 
	fold_level_now int				// SCN_MODIFIED 
	fold_level_prev int				// SCN_MODIFIED 
	margin int						// SCN_MARGINCLICK 
	list_type int					// SCN_USERLISTSELECTION 
	x int							// SCN_DWELLSTART, SCN_DWELLEND 
	y int							// SCN_DWELLSTART, SCN_DWELLEND 
	token int						// SCN_MODIFIED with SC_MOD_CONTAINER 
	annotation_lines_added isize	// SCN_MODIFIED with SC_MOD_CHANGEANNOTATION 
	updated int						// SCN_UPDATEUI 
	list_completion_method int		// SCN_AUTOCSELECTION, SCN_AUTOCCOMPLETED, SCN_USERLISTSELECTION, 
	character_source int			// SCN_CHARADDED 
}

pub struct Editor {
pub mut:
	main_func SCI_FN_DIRECT
	main_hwnd voidptr
	second_func SCI_FN_DIRECT
	second_hwnd voidptr
	current_func SCI_FN_DIRECT
	current_hwnd voidptr
	error_msg_id_style usize
	warning_msg_id_style usize
	info_msg_id_style usize
	diagnostic_offset usize
}
[inline]
fn (e Editor) call(msg int, wparam usize, lparam isize) isize {
	return e.current_func(e.current_hwnd, msg, wparam, lparam)
}

pub fn create_editors(main_handle voidptr, second_handle voidptr) Editor {
	mut editor := Editor{}
	editor.main_func = SCI_FN_DIRECT(send_message(main_handle, sci_getdirectfunction, 0, 0))
	editor.main_hwnd = voidptr(send_message(main_handle, sci_getdirectpointer, 0, 0))
	editor.second_func = SCI_FN_DIRECT(send_message(second_handle, sci_getdirectfunction, 0, 0))
	editor.second_hwnd = voidptr(send_message(second_handle, sci_getdirectpointer, 0, 0))
	editor.current_func = editor.main_func
	editor.current_hwnd = editor.main_hwnd
	return editor
}

pub fn (e Editor) get_text() string {
	start_ptr := byteptr(e.call(sci_getcharacterpointer, 0, 0))
	if start_ptr == byteptr(0) { return '' }  // should not happen at all but who knows ...
	
	mut content := unsafe { cstring_to_vstring(start_ptr) }
	content = content.replace_each(['\\', '\\\\', '\b', r'\b', '\f', r'\f', '\r', r'\r', '\n', r'\n', '\t', r'\t', '"', r'\"'])
	return content
}

pub fn (e Editor) line_from_position(pos usize) isize {
	return e.call(sci_linefromposition, pos, 0)
}

pub fn (e Editor) position_from_line(line usize) isize {
	return e.call(sci_positionfromline, line, 0)
}

pub fn (e Editor) clear_diagnostics() {
	e.call(sci_annotationclearall, 0, 0)
}

pub fn (e Editor) add_diagnostics_info(line int, message string, severity int) {
	p.console_window.log('add_diagnostics_info', 0)
	
	mut style := match severity {
		1 { 0 }
		2 { 1 }
		else { 2 }
	}
	
	mut previous_diag := ''
	buffer_size := e.call(sci_annotationgettext, usize(line), 0)
	if buffer_size > 0 {
		buffer := vcalloc(int(buffer_size))
		e.call(sci_annotationgettext, usize(line), isize(buffer))
		previous_diag = unsafe { cstring_to_vstring(buffer) }
		previous_style := int(e.call(sci_annotationgetstyle, usize(line), 0))
		if previous_style < style {
			style = if previous_style >= 0 { previous_style } else { style }
		}
	}
	
	merged_messages := if previous_diag.len > 0 { '$previous_diag\n$message' } else { message }
	e.call(sci_annotationsettext, usize(line), isize(merged_messages.str))
	e.call(sci_annotationsetstyle, usize(line), style)
	p.console_window.log('  line:$line - $message', 0)
}

pub fn (e Editor) display_signature_hints(hints string) {
	pos := e.call(sci_getcurrentpos, 0, 0)
	e.call(sci_calltipshow, usize(pos), isize(hints.str))
}

pub fn (e Editor) display_completion_list(completions string) {
	e.call(sci_autocsetseparator, 10, 0)
	e.call(sci_autocshow, 0, isize(completions.str))
}

pub fn (e Editor) grab_focus() {
	e.call(sci_grabfocus, 0, 0)
}

pub fn (mut e Editor) alloc_styles() {
	e.diagnostic_offset = usize(e.call(sci_allocateextendedstyles, 3, 0))
	e.error_msg_id_style = e.diagnostic_offset
	e.warning_msg_id_style = e.diagnostic_offset + 1
	e.info_msg_id_style = e.diagnostic_offset + 2
	
	// initialize the current view
	e.init_styles()
}

pub fn (mut e Editor) init_styles() {
	e.call(sci_annotationsetstyleoffset, e.diagnostic_offset, 0)
	e.call(sci_annotationsetvisible, usize(annotation_boxed), 0)

	e.call(sci_stylesetfore, e.error_msg_id_style, 0x756ce0)
	e.call(sci_stylesetfore, e.warning_msg_id_style, 0x64e0ff)
	e.call(sci_stylesetfore, e.info_msg_id_style, 0xbfb2ab)
}
