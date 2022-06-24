module symbols

/*
A "poor man's function list"-like view of the symbols available in the current document.
	Currently (as of version 3.16), the LSP API only provides the name of the various symbols
	together with the start and end position.
	To make it more user-friendly, it needs to include additional information,
	such as the members of the structure/class, or the parameters of a function etc....
	
	Here's how it should work:
		Sort and update the view when
			- opening a file
			- current file is saved
			- previous buffer is different from the current one
		Clear the view when
			- no symbols in current file
			- language server shuts down
			- document is not of interest
*/
import util.winapi as api
import notepadpp
import scintilla as sci
import common { Symbol }

#include "resource.h"

const (
	symbol_style   = u8(1)
	symbol_map     = {
			0: '?  '
			1: '\u24BB\t'  // File Ⓕ
			2: '\u24C2\t'  // Module Ⓜ
			3: '\u24C3\t'  // Namespace Ⓝ
			4: '\u24C5\t'  // Package Ⓟ
			5: '\u24B8\t'  // Class Ⓒ
			6: '\u24DC\t'  // Method ⓜ
			7: '\u24DF\t'  // Property ⓟ
			8: '\u24D5\t'  // Field ⓕ
			9: '\u24D2\t'  // Constructor ⓒ
			10: '\u24BA\t'  // Enum Ⓔ
			11: '\u24BE\t'  // Interface Ⓘ
			12: '\u0192\t'  // Function ƒ
			13: '\u24CB\t'  // Variable Ⓥ
			14: '\u2282\t'  // Constant ⊂
			15: '\u24E2\t'  // String ⓢ
			16: '\u24DD\t'  // Number ⓝ
			17: '\u24B7\t'  // Boolean Ⓑ
			18: '\u24B6\t'  // Array Ⓐ
			19: '\u24C4\t'  // Object Ⓞ
			20: '\u24C0\t'  // Key Ⓚ
			21: '\u00D8\t'  // Null Ø
			22: '\u24D4\t'  // EnumMember ⓔ
			23: '\u24C8\t'  // Struct Ⓢ
			24: '\u0404\t'  // Event Є
			25: '\u24DE\t'  // Operator ⓞ
			26: '\u24C9\t'  // TypeParameter Ⓣ
		}
)

[callconv: stdcall]
fn dialog_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	match int(message) {
		C.WM_COMMAND {}
		C.WM_INITDIALOG {
			api.set_parent(p.symbols_window.output_hwnd, hwnd)
			api.show_window(p.symbols_window.output_hwnd, C.SW_SHOW)
		}
		C.WM_SIZE {
			api.move_window(p.symbols_window.output_hwnd, 0, 0, api.loword(u64(lparam)),
				api.hiword(u64(lparam)), true)
		}
		C.WM_DESTROY {
			api.destroy_window(hwnd)
			return 1
		}
		C.WM_NOTIFY {
			nmhdr := &sci.SciNotifyHeader(lparam)
			if nmhdr.hwnd_from == p.symbols_window.output_hwnd {
				match int(nmhdr.code) {
					sci.scn_hotspotclick {
						scnotification := &sci.SCNotification(lparam)
						p.symbols_window.on_hotspot_click(scnotification.position)
					}
					sci.scn_marginclick {
						scnotification := &sci.SCNotification(lparam)
						p.symbols_window.on_marginclick(scnotification.position)
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
	name &u16 = 'Symbols'.to_wide()
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
	symbols_location    map[int]Symbol
	initialized         bool
}

[inline]
fn (mut d DockableDialog) call(msg int, wparam usize, lparam isize) isize {
	return d.output_editor_func(d.output_editor_hwnd, u32(msg), wparam, lparam)
}

pub fn (mut d DockableDialog) clear() {
	d.call(sci.sci_setreadonly, 0, 0)
	d.call(sci.sci_clearall, 0, 0)
	d.call(sci.sci_setreadonly, 1, 0)
}

pub fn (mut d DockableDialog) update(mut symbols []Symbol) {
	d.call(sci.sci_setreadonly, 0, 0)
	d.call(sci.sci_clearall, 0, 0)

	for i, symbol in symbols {
		d.symbols_location[i] = symbol
	
		sym := symbol_map[symbol.kind]
		mut buffer := []u8{len: sym.len * 2}
		for j := 0; j < sym.len; j++ {
			buffer[j * 2] = sym[j]
			buffer[j * 2 + 1] = symbol_style
		}

		pos := d.call(sci.sci_gettextlength, 0, 0)
		d.call(sci.sci_setcurrentpos, usize(pos), 0)
		d.call(sci.sci_addstyledtext, usize(buffer.len), isize(buffer.data))
		d.call(sci.sci_appendtext, usize(symbol.name.len), isize(symbol.name.str))
		d.call(sci.sci_appendtext, usize(1), isize('\n'.str))
	}
	
	d.call(sci.sci_setreadonly, 1, 0)
	d.show()
}

pub fn (mut d DockableDialog) create(npp_hwnd voidptr, plugin_name string) {
	d.output_hwnd = p.npp.create_scintilla(voidptr(0))
	d.hwnd = voidptr(api.create_dialog_param(p.dll_instance, api.make_int_resource(C.IDD_SYMBOLSDLG),
		npp_hwnd, api.WndProc(dialog_proc), 0))
	icon := api.load_image(p.dll_instance, api.make_int_resource(200), u32(C.IMAGE_ICON),
		16, 16, 0)
	d.tbdata = notepadpp.TbData{
		client: d.hwnd
		name: d.name
		dlg_id: 9
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

	d.call(sci.sci_stylesetfore, symbol_style, 0x7FC0E5)
	d.call(sci.sci_stylesetback, symbol_style, d.back_color)
	d.call(sci.sci_stylesethotspot, 32, 1)
	d.call(sci.sci_sethotspotactiveunderline, 0, 0)
	d.call(sci.sci_sethotspotactiveback, 1, d.selected_text_color)
	d.call(sci.sci_setselback, 1, d.selected_text_color)
	d.call(sci.sci_setcaretfore, usize(d.back_color), 0)

	d.call(sci.sci_setmargins, 1, 0)
	
	// folding markers and margin setup
	folding_marker_definitions := [
		[sci.sc_marknum_folderopen, sci.sc_mark_arrowdown, d.back_color, d.fore_color, 0x70635C],
		[sci.sc_marknum_folder, sci.sc_mark_arrow, d.back_color, d.fore_color, 0x70635C],
		[sci.sc_marknum_foldersub, sci.sc_mark_empty, d.back_color, d.fore_color, 0x70635C],
		[sci.sc_marknum_foldertail, sci.sc_mark_empty, d.back_color, d.fore_color, 0x70635C],
		[sci.sc_marknum_foldermidtail, sci.sc_mark_empty, d.back_color, d.fore_color, 0x70635C],
		[sci.sc_marknum_folderopenmid, sci.sc_mark_empty, d.back_color, d.fore_color, 0x70635C],
		[sci.sc_marknum_folderend, sci.sc_mark_empty, d.back_color, d.fore_color, 0x70635C],
	]

	for marker_defines in folding_marker_definitions {
		d.call(sci.sci_markerdefine, usize(marker_defines[0]), isize(marker_defines[1]))
		d.call(sci.sci_markersetback, usize(marker_defines[0]), isize(marker_defines[3]))
		d.call(sci.sci_markersetfore, usize(marker_defines[0]), isize(marker_defines[2]))
		d.call(sci.sci_markersetbackselected, usize(marker_defines[0]), isize(marker_defines[4]))
	}

	d.call(sci.sci_setmarginmaskn, 0, sci.sc_mask_folders)  // sci.sc_mask_folders
	d.call(sci.sci_setmargintypen, 0, sci.sc_margin_symbol)
	d.call(sci.sci_setmarginwidthn, 0, 14)
	d.call(sci.sci_setmarginsensitiven, 0, 1)

	// these two lines are responsible for the margin background coloring !!
	d.call(sci.sci_setfoldmargincolour, 1, d.back_color)
	d.call(sci.sci_setfoldmarginhicolour, 1, d.back_color)

	// // symbol markers and margin setup
	// for i in 0 .. 27 {
		// if i > 0 {
			// d.call(sci.sci_markerdefine, usize(i), isize(sci.sc_mark_character+0x24D0+i))
		// } else {
			// d.call(sci.sci_markerdefine, usize(i), isize(sci.sc_mark_character+0x3f))
		// }
		// d.call(sci.sci_markersetback, usize(i), isize(d.back_color))
		// d.call(sci.sci_markersetfore, usize(i), isize(d.fore_color))
		// d.call(sci.sci_markersetbackselected, usize(i), isize(0x70635C))
	// }
	
	// d.call(sci.sci_setmarginmaskn, 1, 0x07FFFFFF)  // 1 - 26
	// d.call(sci.sci_setmargintypen, 1, sci.sc_margin_colour)
	// d.call(sci.sci_setmarginwidthn, 1, 16)
	// d.call(sci.sci_setmarginbackn, 1, d.back_color)
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
	line := int(d.call(sci.sci_linefromposition, usize(position), 0))
	symbol := d.symbols_location[line]
	if (symbol.file_name.len > 0) && (p.current_file_path != symbol.file_name) {
		p.npp.open_document(symbol.file_name)
	}
	p.editor.goto_line(symbol.line)

	// d.call(sci.sci_togglefold, usize(line), 0)
}

pub fn (mut d DockableDialog) on_marginclick(position isize) {
	line_number := d.call(sci.sci_linefromposition, usize(position), 0)
	d.call(sci.sci_togglefold, usize(line_number), 0)
}

/*
EXAMPLE
{
    "result": [
        {
            "kind": 23,
            "location": {
                "range": {
                    "end": {
                        "character": 1,
                        "line": 10
                    },
                    "start": {
                        "character": 5,
                        "line": 7
                    }
                },
                "uri": "file:///D%3A/Repositories/eko/npplspclient/tests/go/example.go"
            },
            "name": "person"
        }, ...
    ]
}
*/

/*
{
    "id": 1,
    "jsonrpc": "2.0",
    "result": [
        {
            "containerName": null,
            "kind": 2,
            "location": {
                "range": {
                    "end": {
                        "character": 9,
                        "line": 0
                    },
                    "start": {
                        "character": 0,
                        "line": 0
                    }
                },
                "uri": "file:///D%3A/Repositories/eko/npplspclient/tests/python/example.py"
            },
            "name": "os"
        }, ...
    ]
}
*/
