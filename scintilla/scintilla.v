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
	error_msg_color int = 0x756ce0
	warning_msg_color int = 0x64e0ff
	info_msg_color int = 0xbfb2ab
	diagnostic_offset usize
	diag_indicator usize = 12
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

pub fn (e Editor) line_from_position(pos usize) u32 {
	return u32(e.call(sci_linefromposition, pos, 0))
}

pub fn (e Editor) position_from_line(line u32) u32 {
	return u32(e.call(sci_positionfromline, usize(line), 0))
}

pub fn (e Editor) clear_diagnostics() {
	e.call(sci_annotationclearall, 0, 0)
	e.call(sci_setindicatorcurrent, e.diag_indicator, 0)
	e.call(sci_indicatorclearrange, 0, e.call(sci_getlength, 0, 0))
}

// pub fn (e Editor) add_diagnostics_info(line u32, message string, severity int) {
	// p.console_window.log('add_diagnostics_info', p.info_style_id)
	
	// mut style := match severity {
		// 1 { 0 }
		// 2 { 1 }
		// else { 2 }
	// }
	
	// mut previous_diag := ''
	// buffer_size := e.call(sci_annotationgettext, usize(line), 0)
	// if buffer_size > 0 {
		// buffer := vcalloc(int(buffer_size))
		// e.call(sci_annotationgettext, usize(line), isize(buffer))
		// previous_diag = unsafe { cstring_to_vstring(buffer) }
		// previous_style := int(e.call(sci_annotationgetstyle, usize(line), 0))
		// if previous_style < style {
			// style = if previous_style >= 0 { previous_style } else { style }
		// }
	// }
	
	// merged_messages := if previous_diag.len > 0 { '$previous_diag\n$message' } else { message }
	// e.call(sci_annotationsettext, usize(line), isize(merged_messages.str))
	// e.call(sci_annotationsetstyle, usize(line), style)
	// p.console_window.log('  line:$line - $message', p.info_style_id)
// }

pub fn (e Editor) add_diag_indicator(position u32, length u32, severity int) {
	p.console_window.log('add_diag_indicator: $position, $length, $severity', p.info_style_id)
	mut color := match severity {
		1 { e.error_msg_color }
		2 { e.warning_msg_color }
		else { e.info_msg_color }
	}	
	e.call(sci_setindicatorcurrent, e.diag_indicator, 0)
	e.call(sci_setindicatorvalue, usize(color | sc_indicvaluebit), 0)
	if length == 0 { 
		word_length := editor.get_current_word_length()
		if word_length == 0 {
			start, end := e.get_current_line_positions(position)
			e.call(sci_indicatorfillrange, usize(start), isize(end-start))
		} else {
			e.call(sci_indicatorfillrange, usize(position), isize(word_length))
		}
	} else { 
		e.call(sci_indicatorfillrange, usize(position), isize(length))
	}
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

pub fn (mut e Editor) alloc_styles(indicator_id int,
								   error_msg_color int,
								   warning_msg_color int,
								   info_msg_color int) {
	e.diagnostic_offset = usize(e.call(sci_allocateextendedstyles, 3, 0))
	e.error_msg_id_style = e.diagnostic_offset
	e.warning_msg_id_style = e.diagnostic_offset + 1
	e.info_msg_id_style = e.diagnostic_offset + 2
	
	e.diag_indicator = usize(indicator_id)
	e.error_msg_color = error_msg_color
	e.warning_msg_color = warning_msg_color
	e.info_msg_color = info_msg_color
	
	// initialize the current view
	e.init_styles()
}

pub fn (mut e Editor) init_styles() {
	e.call(sci_annotationsetstyleoffset, e.diagnostic_offset, 0)
	e.call(sci_annotationsetvisible, usize(annotation_boxed), 0)

	e.call(sci_stylesetfore, e.error_msg_id_style, e.error_msg_color)
	e.call(sci_stylesetfore, e.warning_msg_id_style, e.warning_msg_color)
	e.call(sci_stylesetfore, e.info_msg_id_style, e.info_msg_color)
	
	e.call(sci_indicsetstyle, e.diag_indicator, indic_squiggle)
	e.call(sci_indicsetflags, e.diag_indicator, sc_indicflag_valuefore)
	// e.call(sci_indicsetstrokewidth, e.diag_indicator, 200) - needs release 5.0.2
}

pub fn (mut e Editor) update_styles() {
	e.call(sci_stylesetfore, e.error_msg_id_style, e.error_msg_color)
	e.call(sci_stylesetfore, e.warning_msg_id_style, e.warning_msg_color)
	e.call(sci_stylesetfore, e.info_msg_id_style, e.info_msg_color)
}

pub fn (e Editor) get_tab_size() u32 {
	return u32(e.call(sci_gettabwidth, 0, 0))
}

pub fn (e Editor) use_spaces() bool {
	return e.call(sci_getusetabs, 0, 0) == 0
}


pub fn (e Editor) begin_undo_action() {
	e.call(sci_beginundoaction, 0, 0)
}

pub fn (e Editor) end_undo_action() {
	e.call(sci_endundoaction, 0, 0)
}

pub fn (e Editor) replace_target(start_pos u32, end_pos u32, new_text string) {
	e.call(sci_settargetstart, usize(start_pos), 0)
	e.call(sci_settargetend, usize(end_pos), 0)
	e.call(sci_replacetarget, -1, isize(new_text.str))
}

pub fn (e Editor) get_current_position() u32 {
	return u32(e.call(sci_getcurrentpos, 0, 0))
}

pub fn (e Editor) goto_pos(position u32) {
	e.call(sci_gotopos, usize(position), 0)	
}

pub fn (e Editor) get_current_word_length() u32 {
	pos := e.get_current_position()
	start := e.call(sci_wordstartposition, usize(pos), 1)
	end := e.call(sci_wordendposition, usize(pos), 1)
	return u32(end-start)
}

pub fn (e Editor) get_current_line_positions(position u32) (u32, u32) {
	line := e.line_from_position(position)
	start := e.position_from_line(line)
	end := u32(e.call(sci_getlineendposition, usize(line), 0))
	return start, end
}

pub fn (e Editor) get_range_from_selection() (u32, u32, u32, u32) {
	selection_start := e.call(sci_getselectionstart, 0, 0)
	selection_end := e.call(sci_getselectionend, 0, 0)
	
	start_line := e.line_from_position(usize(selection_start))
	end_line := e.line_from_position(usize(selection_end))
	
	start_char := u32(selection_start) - e.position_from_line(start_line)
	end_char := u32(selection_end) - e.position_from_line(end_line)
	return start_line, end_line, start_char, end_char
}

pub fn (e Editor) show_peeked_info(message string) {
	p.console_window.log('show_peeked_info', p.info_style_id)
	pos := e.get_current_position()
	line := e.line_from_position(usize(pos))
	e.call(sci_annotationsettext, usize(line), isize(message.str))
	e.call(sci_annotationsetstyle, usize(line), 2)
	p.console_window.log('  $message', p.info_style_id)
}
