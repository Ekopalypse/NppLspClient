module scintilla

import lsp { DocumentHighlightArray, TextEditArray }

pub fn (e Editor) add_diag_indicator(position u32, length u32, severity int) {
	mut color := match severity {
		1 { e.error_msg_color }
		2 { e.warning_msg_color }
		else { e.info_msg_color }
	}
	e.call(sci_setindicatorcurrent, e.diag_indicator, 0)
	e.call(sci_setindicatorvalue, usize(color | sc_indicvaluebit), 0)
	if length == 0 {
		word_length := e.get_current_word_length()
		if word_length == 0 {
			start, end := e.get_current_line_positions(position)
			e.call(sci_indicatorfillrange, usize(start), isize(end - start))
		} else {
			e.call(sci_indicatorfillrange, usize(position), isize(word_length))
		}
	} else {
		e.call(sci_indicatorfillrange, usize(position), isize(length))
	}
}

pub fn (e Editor) add_diag_annotation(line u32, severity int, message string) {
	style := match severity {
		1 { e.eol_error_style }
		2 { e.eol_warning_style }
		else { e.eol_info_style }
	}
	e.call(sci_eolannotationsetstyle, usize(line), isize(style))
	e.call(sci_eolannotationsettext, usize(line), isize(message.str))
	e.call(sci_eolannotationsetvisible, eolannotation_angle_circle, 0)
}

pub fn (e Editor) clear_diagnostics() {
	e.call(sci_annotationclearall, 0, 0)
	e.call(sci_eolannotationclearall, 0, 0)
	e.call(sci_setindicatorcurrent, e.diag_indicator, 0)
	e.call(sci_indicatorclearrange, 0, e.call(sci_getlength, 0, 0))
}

pub fn (e Editor) display_signature_hints(hints string) {
	pos := e.call(sci_getcurrentpos, 0, 0)
	e.call(sci_calltipsetposition, 1, 0)
	e.call(sci_calltipshow, usize(pos), isize(hints.str))
}

pub fn (e Editor) display_completion_list(completions string) {
	e.call(sci_autocsetseparator, 10, 0)
	word_length := e.get_current_word_length()
	e.call(sci_autocshow, usize(word_length), isize(completions.str))
}

pub fn (e Editor) get_lsp_position_info() (u32, u32) {
	pos := u32(e.call(sci_getcurrentpos, 0, 0))
	line := e.line_from_position(pos)
	start := e.position_from_line(line)
	return line, pos - start
}

pub fn (e Editor) format_document(tea TextEditArray) {
	e.call(sci_beginundoaction, 0, 0)
	reversed_tea := tea.items.reverse()
	for item in reversed_tea {
		start_pos := u32(e.position_from_line(item.range.start.line)) + item.range.start.character
		end_pos := u32(e.position_from_line(item.range.end.line)) + item.range.end.character
		e.call(sci_settargetstart, usize(start_pos), 0)
		e.call(sci_settargetend, usize(end_pos), 0)
		e.call(sci_replacetarget, -1, isize(item.new_text.str))
	}
	e.call(sci_endundoaction, 0, 0)
}

pub fn (e Editor) goto_position(line u32, column u32) {
	position := u32(p.editor.position_from_line(line)) + column
	e.call(sci_gotopos, usize(position), 0)
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
	pos := u32(e.call(sci_getcurrentpos, 0, 0))
	line := e.line_from_position(usize(pos))
	e.call(sci_annotationsettext, usize(line), isize(message.str))
	e.call(sci_annotationsetstyle, usize(line), 2)
}

pub fn (e Editor) clear_peeked_info() {
	e.call(sci_annotationclearall, 0, 0)
}

pub fn (e Editor) display_hover_hints(position u32, hints string) {
	e.call(sci_calltipsetposition, 1, 0)
	e.call(sci_calltipshow, usize(position), isize(hints.str))
}

pub fn (e Editor) get_current_word_length() u32 {
	pos := u32(e.call(sci_getcurrentpos, 0, 0))
	start := e.call(sci_wordstartposition, usize(pos), 1)
	end := e.call(sci_wordendposition, usize(pos), 1)
	return u32(end - start)
}

pub fn (e Editor) get_current_line_positions(position u32) (u32, u32) {
	line := e.line_from_position(position)
	start := e.position_from_line(line)
	end := u32(e.call(sci_getlineendposition, usize(line), 0))
	return start, end
}

pub fn (e Editor) cancel_calltip() {
	e.call(sci_calltipcancel, 0, 0)
}

pub fn (e Editor) highlight_occurances(dha DocumentHighlightArray) {
	e.call(sci_setindicatorcurrent, e.highlight_indicator, 0)
	for item in dha.items {
		start_pos := u32(e.position_from_line(item.range.start.line)) + item.range.start.character
		end_pos := u32(e.position_from_line(item.range.end.line)) + item.range.end.character
		e.call(sci_setindicatorvalue, usize(e.highlight_indicator_color | sc_indicvaluebit),
			0)
		e.call(sci_indicatorfillrange, usize(start_pos), isize(end_pos - start_pos))
	}
}

pub fn (e Editor) clear_highlighted_occurances() {
	e.call(sci_setindicatorcurrent, e.highlight_indicator, 0)
	e.call(sci_indicatorclearrange, 0, e.call(sci_getlength, 0, 0))
}

pub fn (e Editor) clear_indicators() {
	e.clear_diagnostics()
	e.clear_highlighted_occurances()
}
