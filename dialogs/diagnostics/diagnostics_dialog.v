module diagnostics
/*
	A view of the found issues reported by the language server.
	
	Here's how it should work:
		the view is updated each time the server reports diagnostic messages, 
		which may include diagnostics for files other than the one currently in use.
		Sorted by level: first Error, then Warning and finally Info and Hints.
*/
import winapi as api
import notepadpp
import scintilla as sci

#include "resource.h"

[windows_stdcall]
fn dialog_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	match int(message) {
		C.WM_COMMAND {
		}
		C.WM_INITDIALOG {
			api.set_parent(p.diag_window.output_hwnd, hwnd)
			api.show_window(p.diag_window.output_hwnd, C.SW_SHOW)
		}
		C.WM_SIZE {
			api.move_window(p.diag_window.output_hwnd, 0, 0, api.loword(u64(lparam)), api.hiword(u64(lparam)), true)
		}
		C.WM_DESTROY {
			api.destroy_window(hwnd)
			return 1
		}
		C.WM_NOTIFY {
			nmhdr := &sci.SciNotifyHeader(lparam)
			if nmhdr.hwnd_from == p.diag_window.output_hwnd {
				match int(nmhdr.code) {
					sci.scn_hotspotclick {
						scnotification := &sci.SCNotification(lparam)
						p.diag_window.on_hotspot_click(scnotification.position)
					}
					else {}
				}
			}
		}
		else {}
	}
	return 0
}

const (
	error_style = byte(1)
	warning_style = byte(2)
	info_style = byte(3)
	hint_style = byte(4)
)

pub struct DockableDialog {
	name &u16 = 'LSP diagnostics output'.to_wide()
pub mut:
	hwnd voidptr
	is_visible bool
mut:
	tbdata notepadpp.TbData
	output_hwnd voidptr
	output_editor_func sci.SCI_FN_DIRECT
	output_editor_hwnd voidptr
	logging_enabled bool
	fore_color int
	back_color int
	error_color int
	warning_color int
	selected_text_color int
}

[inline]
fn (mut d DockableDialog) call(msg int, wparam usize, lparam isize) isize {
	return d.output_editor_func(d.output_editor_hwnd, u32(msg), wparam, lparam)
}

pub fn (mut d DockableDialog) clear() {
	d.call(sci.sci_clearall, 0, 0)
}

pub fn (mut d DockableDialog) log(text string, style byte) {
	mut text__ := if text.ends_with('\n') { text } else { text + '\n'}
	if d.logging_enabled {
		match style {
			1...4 {
				mut buffer := vcalloc(text__.len * 2)
				unsafe {
					for i:=0; i<text__.len; i++ {
						buffer[i*2] = text__.str[i]
						buffer[i*2+1] = style
					}
				}
				d.call(sci.sci_addstyledtext, usize(text__.len * 2), isize(buffer))
			}
			else {
				d.call(sci.sci_appendtext, usize(text__.len), isize(text__.str))
			}
		}
		line_count := d.call(sci.sci_getlinecount, 0, 0)
		d.call(sci.sci_gotoline, usize(line_count-1), 0)
	}
}

pub fn (mut d DockableDialog) create(npp_hwnd voidptr, plugin_name string) {
	d.output_hwnd = p.npp.create_scintilla(voidptr(0))
	d.hwnd = voidptr(api.create_dialog_param(p.dll_instance, api.make_int_resource(C.IDD_DIAGNOSTICSDLG), npp_hwnd, api.WndProc(dialog_proc), 0))
	icon := api.load_image(p.dll_instance, api.make_int_resource(200), u32(C.IMAGE_ICON), 16, 16, 0)
	d.tbdata = notepadpp.TbData {
		client: d.hwnd
		name: d.name
		dlg_id: 7
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

pub fn (mut d DockableDialog) init_scintilla() {
	d.call(sci.sci_stylesetfore, 32, d.fore_color)
	d.call(sci.sci_stylesetback, 32, d.back_color)
	d.call(sci.sci_styleclearall, 0, 0)
	d.call(sci.sci_stylesetfore, error_style, d.error_color)
	d.call(sci.sci_stylesethotspot, error_style, 1)
	d.call(sci.sci_stylesetfore, warning_style, d.warning_color)
	d.call(sci.sci_stylesethotspot, warning_style, 1)
	d.call(sci.sci_stylesetfore, info_style, d.fore_color)
	d.call(sci.sci_stylesethotspot, info_style, 1)
	d.call(sci.sci_stylesetfore, hint_style, d.fore_color)
	d.call(sci.sci_stylesethotspot, hint_style, 1)
	d.call(sci.sci_setselback, 1, d.selected_text_color)
	d.call(sci.sci_setmargins, 0, 0)
}

pub fn (mut d DockableDialog) show() {
	p.npp.show_dialog(d.hwnd)
	d.is_visible = true
}

pub fn (mut d DockableDialog) hide() {
	p.npp.hide_dialog(d.hwnd)
	d.is_visible = false
}

pub fn (mut d DockableDialog) update_settings(fore_color int,
											  back_color int,
											  error_color int,
											  warning_color int,
											  selected_text_color int,
											  enable_logging bool) {
	d.logging_enabled = enable_logging
	d.fore_color = fore_color
	d.back_color = back_color
	d.error_color = error_color
	d.warning_color = warning_color
	d.selected_text_color = selected_text_color
	d.init_scintilla()
	
}

pub fn (mut d DockableDialog) on_hotspot_click(position isize) {
    line := d.call(sci.sci_linefromposition, usize(position), 0)
	buffer_length := int(d.call(sci.sci_linelength, usize(line), 0))
	
	if buffer_length > 0 {
		mut buffer := vcalloc(buffer_length)
		result := int(d.call(sci.sci_getline, usize(line), isize(buffer)))
		if result > 0 {
			content := unsafe { buffer.vstring_with_len(result) }
			file_name := content.all_before(' [line:')
			line__ := content.find_between(' [line:', ' col:').u32()
			pos__ := content.find_between(' col:', '] -').u32()

			p.npp.open_document(file_name)
			line_pos := p.editor.position_from_line(line__) + pos__
			p.editor.goto_pos(line_pos)
		}
	}
}
