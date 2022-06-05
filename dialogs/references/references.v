module references

/*
A "poor man's search window result"-like view of the found references.
	
	Here's how it should work:
		each result of a new search is appended at the end of the view
		and thus previous results are still available
		but it cannot be guaranteed that they are still valid.
*/
import util.winapi as api
import notepadpp
import scintilla as sci
import common { Reference }
import os
import arrays

#include "resource.h"

const (
	line_style   = byte(0)
	header_style = byte(1)
	error_style  = byte(2)
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
					else {}
				}
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
	d.call(sci.sci_clearall, 0, 0)
	d.reference_cursor = 0
}

pub fn (mut d DockableDialog) update(references []Reference) {
	mut file_map := map[string][]u32{}
	for reference in references {
		d.reference_cursor++
		d.references_map[d.reference_cursor] = reference
		file_map[reference.file_name] << reference.line
	}
	d.reference_cursor++

	d.call(sci.sci_setreadonly, 0, 0)
	for file_name, line_positions in file_map {
		mut ref := ''
		lines := os.read_lines(file_name) or { []string{} }
		max_line_pos := arrays.max(file_map[file_name]) or { -1 }
		if lines.len >= max_line_pos {
			for position in line_positions {
				ref += '  [line:${position + 1}] ${lines[position].trim_space()}\n'
			}
		} else {
			ref = '  ERROR: expected maximum lines to be $lines.len but got $max_line_pos instead'
			mut buffer := vcalloc(ref.len * 2)
			unsafe {
				for i := 0; i < ref.len; i++ {
					buffer[i * 2] = ref.str[i]
					buffer[i * 2 + 1] = error_style
				}
			}
			d.call(sci.sci_addstyledtext, usize(ref.len * 2), isize(buffer))
		}

		// goto end of buffer
		line_count := d.call(sci.sci_getlinecount, 0, 0)
		d.call(sci.sci_gotoline, usize(line_count - 1), 0)

		// add styled header line
		file_name__ := file_name + '\n'
		mut buffer2 := vcalloc(file_name__.len * 2)
		unsafe {
			for i := 0; i < file_name__.len; i++ {
				buffer2[i * 2] = file_name__.str[i]
				buffer2[i * 2 + 1] = header_style
			}
		}
		d.call(sci.sci_addstyledtext, usize(file_name__.len * 2), isize(buffer2))

		// add found lines
		d.call(sci.sci_appendtext, usize(ref.len), isize(ref.str))
	}
	d.call(sci.sci_setreadonly, 1, 0)
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
	d.output_editor_func = sci.SCI_FN_DIRECT(api.send_message(d.output_hwnd, 2184, 0,
		0))
	d.output_editor_hwnd = voidptr(api.send_message(d.output_hwnd, 2185, 0, 0))
}

pub fn (mut d DockableDialog) init_scintilla() {
	d.call(sci.sci_stylesetfore, 32, d.fore_color)
	d.call(sci.sci_stylesetback, 32, d.back_color)
	d.call(sci.sci_styleclearall, 0, 0)
	d.call(sci.sci_stylesetfore, references.header_style, d.header_style_color)
	d.call(sci.sci_stylesetfore, references.line_style, d.fore_color)
	d.call(sci.sci_stylesethotspot, references.line_style, 1)
	d.call(sci.sci_stylesetfore, references.error_style, d.error_style_color)
	d.call(sci.sci_setselback, 1, d.selected_text_color)
	d.call(sci.sci_setmargins, 0, 0)
	d.call(sci.sci_setcaretfore, usize(d.back_color), 0)
}

pub fn (mut d DockableDialog) show() {
	p.npp.show_dialog(d.hwnd)
	d.is_visible = true
}

pub fn (mut d DockableDialog) hide() {
	p.npp.hide_dialog(d.hwnd)
	d.is_visible = false
}

pub fn (mut d DockableDialog) update_settings(fore_color int, back_color int, selected_text_color int, header_style_color int, error_style_color int) {
	d.fore_color = fore_color
	d.back_color = back_color
	d.selected_text_color = selected_text_color
	d.header_style_color = header_style_color
	d.error_style_color = error_style_color
	d.init_scintilla()
}

pub fn (mut d DockableDialog) on_hotspot_click(position isize) {
	line := u32(d.call(sci.sci_linefromposition, usize(position), 0))
	reference := d.references_map[line]
	if (reference.file_name.len > 0) && (p.current_file_path != reference.file_name) {
		p.npp.open_document(reference.file_name)
	}
	p.editor.goto_line(reference.line)
}
