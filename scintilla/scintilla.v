module scintilla

import util.winapi { send_message }

pub type SCI_FN_DIRECT = fn(hwnd isize, msg u32, param usize, lparam isize) isize

pub struct SciNotifyHeader {
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
	error_msg_color int = 0x756ce0
	warning_msg_color int = 0x64e0ff
	info_msg_color int = 0xbfb2ab
	diag_indicator usize = 12
	highlight_indicator usize = 13
	highlight_indicator_color int = 0x64e0ff
	calltip_foreground_color int = 0x0
	calltip_background_color int = 0xffffff
}

[inline]
fn (e Editor) call(msg int, wparam usize, lparam isize) isize {
	return e.current_func(e.current_hwnd, u32(msg), wparam, lparam)
	// return send_message(e.current_hwnd, u32(msg), wparam, lparam)
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

pub fn (e Editor) grab_focus() {
	e.call(sci_grabfocus, 0, 0)
}

pub fn (mut e Editor) initialize() {
	e.call(sci_setmousedwelltime, 500, 0)

	e.call(sci_annotationsetvisible, usize(annotation_boxed), 0)

	e.call(sci_indicsetstyle, e.diag_indicator, indic_squiggle)
	e.call(sci_indicsetflags, e.diag_indicator, sc_indicflag_valuefore)
	e.call(sci_indicsetstyle, e.highlight_indicator, indic_roundbox)
	e.call(sci_indicsetflags, e.highlight_indicator, sc_indicflag_valuefore)
	e.call(sci_indicsetalpha, e.highlight_indicator, 40)
	e.call(sci_indicsetoutlinealpha, e.highlight_indicator, 100)
	
	e.call(sci_calltipsetfore, usize(e.calltip_foreground_color), 0)
	e.call(sci_calltipsetback, usize(e.calltip_background_color), 0)
}

pub fn (mut e Editor) update_styles() {
	e.call(sci_calltipsetfore, usize(e.calltip_foreground_color), 0)
	e.call(sci_calltipsetback, usize(e.calltip_background_color), 0)	
}

pub fn (e Editor) get_tab_size() u32 {
	return u32(e.call(sci_gettabwidth, 0, 0))
}

pub fn (e Editor) use_spaces() bool {
	return e.call(sci_getusetabs, 0, 0) == 0
}

pub fn (e Editor) goto_pos(position u32) {
	e.call(sci_gotopos, usize(position), 0)
}
pub fn (e Editor) goto_line(line u32) {
	e.call(sci_gotoline, usize(line), 0)
}

pub fn (e Editor) get_document_pointer() isize {
	return e.call(sci_getdocpointer, 0, 0)
}

pub fn (e Editor) autocompletion_is_active() bool {
	return e.call(sci_autocactive, 0, 0) == 1
}

pub fn (e Editor) goto_centered_line(line isize) {
	e.call(sci_setvisiblepolicy, usize(visible_strict), isize(caret_strict))
	e.call(sci_ensurevisibleenforcepolicy, usize(line), 0)
}

pub fn (e Editor) line_from_current_position() isize {
	pos := e.call(sci_getcurrentpos, 0, 0)
	return e.call(sci_linefromposition, usize(pos), 0)
}

pub fn (e Editor) get_char_at(pos isize) int {
	return int(e.call(sci_getcharat, usize(pos), 0))
}
