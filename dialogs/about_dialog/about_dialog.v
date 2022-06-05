module about_dialog

import util.winapi as api

#include "resource.h"

fn about_dialog_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	match int(message) {
		C.WM_COMMAND {
			id := api.loword(wparam)
			match int(id) {
				C.IDOK {
					api.end_dialog(hwnd, id)
					return 1
				}
				else {}
			}
		}
		C.WM_INITDIALOG {
			return 1
		}
		C.WM_DESTROY {
			api.destroy_window(hwnd)
			return 1
		}
		else {}
	}
	return 0
}

pub fn show(npp_hwnd voidptr) {
	dlg_hwnd := voidptr(api.create_dialog_param(p.dll_instance, api.make_int_resource(C.IDD_ABOUTDLG),
		npp_hwnd, api.WndProc(about_dialog_proc), 0))

	npp_rect := api.RECT{}
	api.get_client_rect(npp_hwnd, &npp_rect)
	mut center := api.POINT{}
	mut width := npp_rect.right - npp_rect.left
	mut height := npp_rect.bottom - npp_rect.top
	center.x = npp_rect.left + (width / 2)
	center.y = npp_rect.top + (height / 2)
	api.client_to_screen(npp_hwnd, &center)

	dlg_rect := api.RECT{}
	api.get_client_rect(dlg_hwnd, &dlg_rect)
	x := center.x - (dlg_rect.right - dlg_rect.left) / 2
	y := center.y - (dlg_rect.bottom - dlg_rect.top) / 2
	width = (dlg_rect.right - dlg_rect.left)
	height = (dlg_rect.bottom - dlg_rect.top)
	api.set_window_pos(dlg_hwnd, voidptr(C.HWND_TOP), x, y, width, height, u32(C.SWP_SHOWWINDOW))
}
