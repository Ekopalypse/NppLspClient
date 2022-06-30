module references


// A "poor man's search window result"-like view of the found references.

	// Here's how it works:
		// each result of a new search is appended at the end of the view
		// and thus previous results are still available
		// but it cannot be guaranteed that they are still valid.

import util.winapi as api
import notepadpp
import scintilla as sci
import common { Reference }
import os
import arrays

#include "resource.h"

const (
	line_style   = u8(0)
	header_style = u8(1)
	error_style  = u8(2)
	search_style = u8(3)
)

[callconv: stdcall]
fn dialog_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	match int(message) {
		C.WM_COMMAND {}
		C.WM_INITDIALOG {
			api.set_parent(p.references_window.output_hwnd, hwnd)
			api.show_window(p.references_window.output_hwnd, C.SW_SHOW)
		}
		C.WM_SIZE {
			api.move_window(p.references_window.output_hwnd, 0, 0, api.loword(u64(lparam)),
				api.hiword(u64(lparam)), true)
		}
		C.WM_DESTROY {
			api.destroy_window(hwnd)
			return 1
		}
		C.WM_NOTIFY {
			nmhdr := &sci.SciNotifyHeader(lparam)
			if nmhdr.hwnd_from == p.references_window.output_hwnd {
				match int(nmhdr.code) {
					sci.scn_hotspotclick {
						scnotification := &sci.SCNotification(lparam)
						p.references_window.on_hotspot_click(scnotification.position)
					}
					sci.scn_marginclick {
						scnotification := &sci.SCNotification(lparam)
						p.references_window.on_marginclick(scnotification.position)
					}
					else {}
				}
			}
		}
		C.WM_SHOWWINDOW {
			p.references_window.is_visible = if wparam == 0 { false } else { true }
		}
		C.WM_KEYUP {
			println('wparam: $wparam ${C.VK_ESCAPE}')
			if wparam == usize(C.VK_ESCAPE) {
				p.editor.grab_focus()
			}
		}
		else {}
	}
	return 0
}

pub struct DockableDialog {
	name &u16 = 'Found references'.to_wide()
pub mut:
	hwnd       voidptr
	is_visible bool
mut:
	tbdata              notepadpp.TbData
	output_hwnd         voidptr
	output_editor_func  sci.SCI_FN_DIRECT
	output_editor_hwnd  voidptr
	fore_color          int
	back_color          int
	selected_text_color int
	search_style_color  int
	header_style_color  int
	error_style_color   int
	reference_cursor    u32
	references_map      map[u32]Reference
}

[inline]
fn (mut d DockableDialog) call(msg int, wparam usize, lparam isize) isize {
	return d.output_editor_func(d.output_editor_hwnd, u32(msg), wparam, lparam)
}

pub fn (mut d DockableDialog) clear() {
	d.call(sci.sci_setreadonly, 0, 0)
	d.call(sci.sci_clearall, 0, 0)
	d.call(sci.sci_setreadonly, 1, 0)
	d.reference_cursor = 0
}

pub fn (mut d DockableDialog) update(references []Reference) {
	if p.lsp_config.clear_reference_view_always { d.clear() }
	if references.len == 0 { return }

	current_last_line := usize(d.reference_cursor)

	mut file_map := map[string][]u32{}

	mut search_header := ''
	mut search_header_not_set := true
	mut search_header_start := u32(0)
	mut search_header_end := u32(0)
	mut file_header := ''
	for reference in references {
		if search_header.len == 0 {
			search_header_start = reference.start_pos
			search_header_end = reference.end_pos
			d.reference_cursor++
		}
		if reference.file_name != file_header {
			d.reference_cursor++
			file_header = reference.file_name
		}
		d.references_map[d.reference_cursor] = reference
		file_map[reference.file_name] << reference.line
		d.reference_cursor++
	}

	d.call(sci.sci_setreadonly, 0, 0)
	for file_name, line_positions in file_map {
		mut ref := ''
		lines := os.read_lines(file_name) or { []string{} }
		max_line_pos := arrays.max(file_map[file_name]) or { -1 }
		if lines.len >= max_line_pos {
			for position in line_positions {
				if search_header_not_set {
					search_header = lines[position][search_header_start..search_header_end]
					search_header_not_set = false
				}
				ref += '    [line:${position + 1}] ${lines[position].trim_space()}\n'
			}
		} else {
			ref = '  ERROR: expected maximum lines to be $lines.len but got $max_line_pos instead'
			mut buffer := []u8{len: ref.len * 2}
			for j := 0; j < ref.len; j++ {
				buffer[j * 2] = ref[j]
				buffer[j * 2 + 1] = error_style
			}			
			d.call(sci.sci_addstyledtext, usize(buffer.len), isize(buffer.data))
		}

		// goto end of buffer
		mut last_line := d.call(sci.sci_getlinecount, 0, 0) - 1
		d.call(sci.sci_gotoline, usize(last_line), 0)

		// add styled search term header
		if search_header.len != 0 {
			search_header = 'References found for $search_header\n'
			mut buffer := []u8{len: search_header.len * 2}
			for j := 0; j < search_header.len; j++ {
				buffer[j * 2] = search_header[j]
				buffer[j * 2 + 1] = search_style
			}			
			d.call(sci.sci_addstyledtext, usize(buffer.len), isize(buffer.data))
			search_header = ''
			d.call(sci.sci_setfoldlevel, usize(last_line), isize(sci.sc_foldlevelheaderflag | sci.sc_foldlevelbase))
			last_line++
		}

		// add styled file_header line
		file_name__ := '  $file_name\n'
		mut buffer := []u8{len: file_name__.len * 2}
		for j := 0; j < file_name__.len; j++ {
			buffer[j * 2] = file_name__[j]
			buffer[j * 2 + 1] = header_style
		}			
		d.call(sci.sci_addstyledtext, usize(buffer.len), isize(buffer.data))
		d.call(sci.sci_setfoldlevel, usize(last_line),
			(sci.sc_foldlevelheaderflag | sci.sc_foldlevelbase) + 1)
		last_line++

		// add found lines
		d.call(sci.sci_appendtext, usize(ref.len), isize(ref.str))
		new_last_line := d.call(sci.sci_getlinecount, 0, 0)
		for i in last_line .. new_last_line {
			d.call(sci.sci_setfoldlevel, usize(i), sci.sc_foldlevelbase + 2)
		}
	}
	d.call(sci.sci_setfirstvisibleline, current_last_line, 0)
	d.call(sci.sci_setreadonly, 1, 0)
	if !d.is_visible {
		d.show()
	}
}

pub fn (mut d DockableDialog) create(npp_hwnd voidptr, plugin_name string) {
	d.output_hwnd = p.npp.create_scintilla(voidptr(0))
	d.hwnd = voidptr(api.create_dialog_param(p.dll_instance, api.make_int_resource(C.IDD_REFERENCESSDLG),
		npp_hwnd, api.WndProc(dialog_proc), 0))
	icon := api.load_image(p.dll_instance, api.make_int_resource(200), u32(C.IMAGE_ICON),
		16, 16, 0)
	d.tbdata = notepadpp.TbData{
		client: d.hwnd
		name: d.name
		dlg_id: 8
		mask: notepadpp.dws_df_cont_bottom | notepadpp.dws_icontab
		icon_tab: icon
		add_info: voidptr(0)
		rc_float: api.RECT{}
		prev_cont: -1
		module_name: plugin_name.to_wide()
	}
	p.npp.register_dialog(d.tbdata)
	d.hide()
	d.output_editor_func = sci.SCI_FN_DIRECT(api.send_message(d.output_hwnd, 2184, 0, 0))
	d.output_editor_hwnd = voidptr(api.send_message(d.output_hwnd, 2185, 0, 0))
}

fn (mut d DockableDialog) init_scintilla() {
	d.call(sci.sci_stylesetfore, 32, d.fore_color)
	d.call(sci.sci_stylesetback, 32, d.back_color)
	d.call(sci.sci_styleclearall, 0, 0)
	d.call(sci.sci_stylesetfore, search_style, d.search_style_color)
	d.call(sci.sci_stylesetfore, header_style, d.header_style_color)
	d.call(sci.sci_stylesetfore, line_style, d.fore_color)
	d.call(sci.sci_stylesethotspot, line_style, 1)
	d.call(sci.sci_stylesetfore, error_style, d.error_style_color)
	d.call(sci.sci_setselback, 1, d.selected_text_color)
	d.call(sci.sci_setcaretfore, usize(d.back_color), 0)

	// folding margin setup
	marker_definitions := [
		[sci.sc_marknum_folderopen, sci.sc_mark_arrowdown, d.back_color, d.fore_color, 0x70635C],
		[sci.sc_marknum_folder, sci.sc_mark_arrow, d.back_color, d.fore_color, 0x70635C],
		[sci.sc_marknum_foldersub, sci.sc_mark_empty, d.back_color, d.fore_color, 0x70635C],
		[sci.sc_marknum_foldertail, sci.sc_mark_empty, d.back_color, d.fore_color, 0x70635C],
		[sci.sc_marknum_foldermidtail, sci.sc_mark_empty, d.back_color, d.fore_color, 0x70635C],
		[sci.sc_marknum_folderopenmid, sci.sc_mark_empty, d.back_color, d.fore_color, 0x70635C],
		[sci.sc_marknum_folderend, sci.sc_mark_empty, d.back_color, d.fore_color, 0x70635C],
	]

	for marker_defines in marker_definitions {
		d.call(sci.sci_markerdefine, usize(marker_defines[0]), isize(marker_defines[1]))
		d.call(sci.sci_markersetback, usize(marker_defines[0]), isize(marker_defines[3]))
		d.call(sci.sci_markersetfore, usize(marker_defines[0]), isize(marker_defines[2]))
		d.call(sci.sci_markersetbackselected, usize(marker_defines[0]), isize(marker_defines[4]))
	}

	d.call(sci.sci_setmarginleft, 0, 2)
	d.call(sci.sci_setmarginright, 0, 2)

	d.call(sci.sci_setmargins, 1, 0)

	d.call(sci.sci_setmarginmaskn, 0, sci.sc_mask_folders)
	d.call(sci.sci_setmargintypen, 0, sci.sc_margin_symbol)
	d.call(sci.sci_setmarginwidthn, 0, 14)
	d.call(sci.sci_setmarginsensitiven, 0, 1)

	// these two lines are responsible for the margin background coloring !!
	d.call(sci.sci_setfoldmargincolour, 1, d.back_color)
	d.call(sci.sci_setfoldmarginhicolour, 1, d.back_color)
}

pub fn (mut d DockableDialog) toggle() {
	if d.is_visible { d.hide() } else { d.show() }
}

fn (mut d DockableDialog) show() {
	p.npp.show_dialog(d.hwnd)
	d.is_visible = true
	d.call(sci.sci_grabfocus, 1, 0)
}

fn (mut d DockableDialog) hide() {
	p.npp.hide_dialog(d.hwnd)
	d.is_visible = false
}

pub fn (mut d DockableDialog) update_settings(fore_color int, back_color int, selected_text_color int, header_style_color int, error_style_color int, search_style_color int) {
	d.fore_color = fore_color
	d.back_color = back_color
	d.selected_text_color = selected_text_color
	d.header_style_color = header_style_color
	d.error_style_color = error_style_color
	d.search_style_color = search_style_color
	d.init_scintilla()
}

fn (mut d DockableDialog) on_hotspot_click(position isize) {
	line := u32(d.call(sci.sci_linefromposition, usize(position), 0))
	reference := d.references_map[line]
	if (reference.file_name.len > 0) && (p.current_file_path != reference.file_name) {
		p.npp.open_document(reference.file_name)
	}
	p.editor.goto_line(reference.line)
}

fn (mut d DockableDialog) on_marginclick(position isize) {
	line_number := d.call(sci.sci_linefromposition, usize(position), 0)
	d.call(sci.sci_togglefold, usize(line_number), 0)
}
