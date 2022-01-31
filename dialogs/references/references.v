module references
/*
	A "poor man's search window result"-like view of the found references.
	
	Here's how it should work:
		each result of a new search is inserted at the beginning of the view 
		and thus previous results are still available 
		but it cannot be guaranteed that they are still valid.
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
			api.set_parent(p.references_window.output_hwnd, hwnd)
			api.show_window(p.references_window.output_hwnd, C.SW_SHOW)
		}
		C.WM_SIZE {
			api.move_window(p.references_window.output_hwnd, 0, 0, api.loword(u64(lparam)), api.hiword(u64(lparam)), true)
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
	hwnd voidptr
	is_visible bool
mut:
	tbdata notepadpp.TbData
	output_hwnd voidptr
	output_editor_func sci.SCI_FN_DIRECT
	output_editor_hwnd voidptr
	fore_color int
	back_color int
	selected_text_color int
}

[inline]
fn (mut d DockableDialog) call(msg int, wparam usize, lparam isize) isize {
	return d.output_editor_func(d.output_editor_hwnd, u32(msg), wparam, lparam)
}

pub fn (mut d DockableDialog) clear() {
	d.call(sci.sci_clearall, 0, 0)
}

pub fn (mut d DockableDialog) log(text string) {
	mut text__ := if text.ends_with('\n') { text } else { text + '\n'}
	d.call(sci.sci_appendtext, usize(text__.len), isize(text__.str))
	line_count := d.call(sci.sci_getlinecount, 0, 0)
	d.call(sci.sci_gotoline, usize(line_count-1), 0)
}

pub fn (mut d DockableDialog) create(npp_hwnd voidptr, plugin_name string) {
	d.output_hwnd = p.npp.create_scintilla(voidptr(0))
	d.hwnd = voidptr(api.create_dialog_param(p.dll_instance, api.make_int_resource(C.IDD_REFERENCESSDLG), npp_hwnd, api.WndProc(dialog_proc), 0))
	icon := api.load_image(p.dll_instance, api.make_int_resource(200), u32(C.IMAGE_ICON), 16, 16, 0)
	d.tbdata = notepadpp.TbData {
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

pub fn (mut d DockableDialog) init_scintilla() {
	d.call(sci.sci_stylesetfore, 32, d.fore_color)
	d.call(sci.sci_stylesetback, 32, d.back_color)
	d.call(sci.sci_styleclearall, 0, 0)
	d.call(sci.sci_stylesethotspot, 32, 1)
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

pub fn (mut d DockableDialog) update_settings(fore_color int, back_color int, selected_text_color int) {
	d.fore_color = fore_color
	d.back_color = back_color
	d.selected_text_color = selected_text_color
	d.init_scintilla()
}

pub fn (mut d DockableDialog) on_hotspot_click(position isize) {
	// FILEPATH [line:LINENUMBER]

    line := d.call(sci.sci_linefromposition, usize(position), 0)
	buffer_length := int(d.call(sci.sci_linelength, usize(line), 0))
	
	if buffer_length > 0 {
		mut buffer := vcalloc(buffer_length)
		result := int(d.call(sci.sci_getline, usize(line), isize(buffer)))
		if result > 0 {
			content := unsafe { buffer.vstring_with_len(result) }
			file_name := content.all_before(' [line:')
			line__ := content.find_between('[line:', ']').u32()
			p.npp.open_document(file_name)
			line_pos := p.editor.position_from_line(line__)
			p.editor.goto_pos(line_pos)
		}
	}
}

/* EXAMPLE
{
    "result": [
        {
            "range": {
                "end": {
                    "character": 7,
                    "line": 15
                },
                "start": {
                    "character": 4,
                    "line": 15
                }
            },
            "uri": "file:///D:/Repositories/eko/npplspclient/tests/go/example.go"
        },
        {
            "range": {
                "end": {
                    "character": 7,
                    "line": 18
                },
                "start": {
                    "character": 4,
                    "line": 18
                }
            },
            "uri": "file:///D:/Repositories/eko/npplspclient/tests/go/example.go"
        },
        {
            "range": {
                "end": {
                    "character": 7,
                    "line": 21
                },
                "start": {
                    "character": 4,
                    "line": 21
                }
            },
            "uri": "file:///D:/Repositories/eko/npplspclient/tests/go/example.go"
        },
        {
            "range": {
                "end": {
                    "character": 7,
                    "line": 23
                },
                "start": {
                    "character": 4,
                    "line": 23
                }
            },
            "uri": "file:///D:/Repositories/eko/npplspclient/tests/go/example.go"
        },
        {
            "range": {
                "end": {
                    "character": 7,
                    "line": 24
                },
                "start": {
                    "character": 4,
                    "line": 24
                }
            },
            "uri": "file:///D:/Repositories/eko/npplspclient/tests/go/example.go"
        },
        {
            "range": {
                "end": {
                    "character": 24,
                    "line": 24
                },
                "start": {
                    "character": 21,
                    "line": 24
                }
            },
            "uri": "file:///D:/Repositories/eko/npplspclient/tests/go/example.go"
        }
    ]
}
*/