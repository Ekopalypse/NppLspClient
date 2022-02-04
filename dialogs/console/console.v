module console
/*
	Mainly a view of the language server log communication,
	but also some other information, like the messages reported by the language server to be logged or displayed
	and some information about the plugin itself.
	
	Here's how it should work:
		Any message sent to or received from a language server is added.
		The decoded result of showMessage and logMessage is added additionally.
		Basic plugin functionality is added.

*/
import util.winapi as api
import notepadpp
import scintilla as sci

#include "resource.h"

[windows_stdcall]
fn dialog_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	match int(message) {
		C.WM_COMMAND {
		}
		C.WM_INITDIALOG {
			api.set_parent(p.console_window.output_hwnd, hwnd)
			api.show_window(p.console_window.output_hwnd, C.SW_SHOW)
		}
		C.WM_SIZE {
			api.move_window(p.console_window.output_hwnd, 0, 0, api.loword(u64(lparam)), api.hiword(u64(lparam)), true)
		}
		C.WM_DESTROY {
			api.destroy_window(hwnd)
			return 1
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
	outgoing_msg_style = byte(5)
	incoming_msg_style = byte(6)
)

pub struct DockableDialog {
	name &u16 = 'LSP output console'.to_wide()
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
	incoming_msg_color int
	outgoing_msg_color int
	selected_text_color int
}

[inline]
fn (mut d DockableDialog) call(msg int, wparam usize, lparam isize) isize {
	return d.output_editor_func(d.output_editor_hwnd, u32(msg), wparam, lparam)
}

pub fn (mut d DockableDialog) clear() {
	d.call(sci.sci_clearall, 0, 0)
}

fn (mut d DockableDialog) log(text string, style byte) {
	mut text__ := if text.ends_with('\n') { text } else { text + '\n'}
	if style == 3 {
		d.call(sci.sci_appendtext, usize(text__.len), isize(text__.str))
	} else {
		mut buffer := []byte{len: text__.len * 2}
		for i:=0; i<text__.len; i++ {
			buffer[i*2] = text__[i]
			buffer[i*2+1] = style
		}
		d.call(sci.sci_addstyledtext, usize(buffer.len), isize(buffer.data))
	}
	line_count := d.call(sci.sci_getlinecount, 0, 0)
	d.call(sci.sci_gotoline, usize(line_count-1), 0)
}

pub fn (mut d DockableDialog) log_error(text string) {
	if d.logging_enabled { d.log(text, error_style) }
}

pub fn (mut d DockableDialog) log_warning(text string) {
	if d.logging_enabled { d.log(text, warning_style) }
}

pub fn (mut d DockableDialog) log_info(text string) {
	if d.logging_enabled { d.log(text, info_style) }
}

pub fn (mut d DockableDialog) log_hint(text string) {
	if d.logging_enabled { d.log(text, hint_style) }
}

pub fn (mut d DockableDialog) log_outgoing(text string) {
	if d.logging_enabled { d.log(text, outgoing_msg_style) }
}

pub fn (mut d DockableDialog) log_incoming(text string) {
	if d.logging_enabled { d.log(text, incoming_msg_style) }
}

pub fn (mut d DockableDialog) log_styled(text string, style byte) {
	if d.logging_enabled { d.log(text, style) }
}

pub fn (mut d DockableDialog) create(npp_hwnd voidptr, plugin_name string) {
	d.output_hwnd = p.npp.create_scintilla(voidptr(0))
	d.hwnd = voidptr(api.create_dialog_param(p.dll_instance, api.make_int_resource(C.IDD_CONSOLEDLG), npp_hwnd, api.WndProc(dialog_proc), 0))
	icon := api.load_image(p.dll_instance, api.make_int_resource(200), u32(C.IMAGE_ICON), 16, 16, 0)
	d.tbdata = notepadpp.TbData {
		client: d.hwnd
		name: d.name
		dlg_id: 6
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
	d.call(sci.sci_stylesetfore, info_style, d.fore_color)	// normal log messages
	d.call(sci.sci_stylesetfore, hint_style, d.fore_color)	// normal log messages
	d.call(sci.sci_stylesetfore, outgoing_msg_style, d.outgoing_msg_color)
	d.call(sci.sci_stylesetfore, incoming_msg_style, d.incoming_msg_color)
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
											  incoming_msg_color int,
											  outgoing_msg_color int,
											  selected_text_color int,
											  enable_logging bool) {
	d.logging_enabled = enable_logging
	d.fore_color = fore_color
	d.back_color = back_color
	d.error_color = error_color
	d.warning_color = warning_color
	d.incoming_msg_color = incoming_msg_color
	d.outgoing_msg_color = outgoing_msg_color
	d.selected_text_color = selected_text_color
	d.init_scintilla()
}
