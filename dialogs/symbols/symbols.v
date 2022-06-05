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

	// symbols.sort(a.name < b.name)
	for i, symbol in symbols {
		d.symbols_location[i] = symbol
		if symbol.parent == 'null' {
			d.call(sci.sci_setfoldlevel, usize(i), 0x2400)
		} else {
			if i > 0 {
				prev_fold_level := d.call(sci.sci_getfoldlevel, usize(i - 1), 0)
				match true {
					prev_fold_level > sci.sc_foldlevelheaderflag {
						d.call(sci.sci_setfoldlevel, usize(i),
							(prev_fold_level & sci.sc_foldlevelnumbermask) + 1)
					}
					prev_fold_level & sci.sc_foldlevelnumbermask == sci.sc_foldlevelbase {
						d.call(sci.sci_setfoldlevel, usize(i), sci.sc_foldlevelbase)
					}
					else {
						d.call(sci.sci_setfoldlevel, usize(i), prev_fold_level)
					}
				}
				if prev_fold_level == sci.sc_foldlevelbase {
					d.call(sci.sci_setfoldlevel, usize(i), sci.sc_foldlevelbase)
				} else {
				}
			} else {
				d.call(sci.sci_setfoldlevel, usize(i), sci.sc_foldlevelbase)
			}
		}
		d.call(sci.sci_appendtext, usize(symbol.name.len), isize(symbol.name.str))
		d.call(sci.sci_appendtext, usize(1), isize('\n'.str))
	}
	d.call(sci.sci_setreadonly, 1, 0)
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

	d.call(sci.sci_stylesethotspot, 32, 1)
	d.call(sci.sci_sethotspotactiveunderline, 0, 0)
	d.call(sci.sci_sethotspotactiveback, 1, d.selected_text_color)
	d.call(sci.sci_setselback, 1, d.selected_text_color)

	for i in 0 .. 5 {
		d.call(sci.sci_setmarginwidthn, usize(i), 0)
	}

	// folding margin setup
	marker_definitions := [
		[sci.sc_marknum_folderopen, sci.sc_mark_arrowdown, 0x70635C, d.back_color, d.fore_color],
		[sci.sc_marknum_folder, sci.sc_mark_arrow, 0x70635C, d.back_color, d.fore_color],
		[sci.sc_marknum_foldersub, sci.sc_mark_empty, 0x70635C, d.back_color, d.fore_color],
		[sci.sc_marknum_foldertail, sci.sc_mark_empty, 0x70635C, d.back_color, d.fore_color],
		[sci.sc_marknum_foldermidtail, sci.sc_mark_empty, 0x70635C, d.back_color, d.fore_color],
		[sci.sc_marknum_folderopenmid, sci.sc_mark_empty, 0x70635C, d.back_color, d.fore_color],
		[sci.sc_marknum_folderend, sci.sc_mark_empty, 0x70635C, d.back_color, d.fore_color],
	]

	for marker_defines in marker_definitions {
		d.call(sci.sci_markerdefine, usize(marker_defines[0]), isize(marker_defines[1]))
		d.call(sci.sci_markersetback, usize(marker_defines[0]), isize(marker_defines[2]))
		d.call(sci.sci_markersetfore, usize(marker_defines[0]), isize(marker_defines[3]))
		d.call(sci.sci_markersetbackselected, usize(marker_defines[0]), isize(marker_defines[4]))
	}

	d.call(sci.sci_setmargintypen, 2, sci.sc_margin_symbol)
	d.call(sci.sci_setmarginwidthn, 2, 24)
	d.call(sci.sci_setmarginmaskn, 2, sci.sc_mask_folders)
	d.call(sci.sci_setmarginsensitiven, 2, 1)
	d.call(sci.sci_setfoldmargincolour, 1, d.back_color)
	d.call(sci.sci_setfoldmarginhicolour, 1, d.back_color)
	d.call(sci.sci_setautomaticfold, 1, 0)
	d.call(sci.sci_setfoldflags, 0, 0)

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
