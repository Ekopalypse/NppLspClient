module winapi

#include <shellapi.h>

#flag -luser32
#flag -lShell32

pub type WndProc = fn (hwnd voidptr, message u32, wparam usize, lparam isize) isize
pub type WndEnumProc = fn (hwnd voidptr, lparam isize) bool

pub const (
	still_active = u32(259)
	tvif_text = 1
	tvif_param = 4
	tvgn_root = 0
	tvgn_next = 1
	tv_first = 0x1100
	tvm_getcount = tv_first + 5
	tvm_getnextitem = tv_first + 10
	tvm_getitemw = tv_first + 62
	tvm_getitem = tvm_getitemw
)

pub struct RECT {
pub mut:
	left   int
	top    int
	right  int
	bottom int
}

pub struct POINT {
pub mut:
	x int
	y int
}

pub struct PROCESS_INFORMATION {
pub mut:
	h_process     voidptr
	h_thread      voidptr
	dw_process_id u32
	dw_thread_id  u32
}

pub struct STARTUPINFO {
pub mut:
	cb                 u32
	lp_reserved        &u16
	lp_desktop         &u16
	lp_title           &u16
	dw_x               u32
	dw_y               u32
	dw_x_size          u32
	dw_y_size          u32
	dw_x_count_chars   u32
	dw_y_count_chars   u32
	dw_fill_attributes u32
	dw_flags           u32
	w_show_window      u16
	cb_reserved2       u16
	lp_reserved2       &u8
	h_std_input        voidptr
	h_std_output       voidptr
	h_std_error        voidptr
}

pub struct SECURITY_ATTRIBUTES {
pub mut:
	n_length               u32
	lp_security_descriptor voidptr
	b_inherit_handle       bool
}

pub struct TVITEMEX {
pub mut:
	mask           u32
	hitem          voidptr
	state          u32
	state_mask     u32
	text           &u16
	text_max       int
	image          int
	selected_image int
	children       int
	lparam         &Dummy
	integral       int
	state_ex       u32
	hwnd           voidptr
	expanded_image int
	reserved       int
}


pub struct Dummy {
pub mut:
	root_path &u16
}

// helper functions
pub fn loword(value usize) u16 {
	return u16(value & 0xFFFF)
}

pub fn hiword(value usize) u16 {
	return u16((value >> 16) & 0xFFFF)
}

pub fn create_unicode_buffer(size isize) &u8 {
	return unsafe { vcalloc((size + 1) * 2) }
}

// macro
fn C.MAKEINTRESOURCE(dialogID int) voidptr
pub fn make_int_resource(dialog_id int) voidptr {
	return C.MAKEINTRESOURCE(dialog_id)
}

fn C.SendMessageW(hwnd voidptr, msg u32, wparam usize, lparam isize) isize
pub fn send_message(hwnd voidptr, msg u32, wparam usize, lparam isize) isize {
	return C.SendMessageW(hwnd, msg, wparam, lparam)
}

fn C.PostMessageW(hwnd voidptr, msg u32, wparam usize, lparam isize) bool
pub fn post_message(hwnd voidptr, msg u32, wparam usize, lparam isize) bool {
	return C.PostMessageW(hwnd, msg, wparam, lparam)
}

fn C.EndDialog(hDlg voidptr, nResult usize) bool
pub fn end_dialog(dlg_handle voidptr, result usize) bool {
	return C.EndDialog(dlg_handle, result)
}

fn C.CreateDialogParamW(hInstance voidptr, lpTemplateName &u16, hWndParent voidptr, lpDialogFunc WndProc, dwInitParam isize) isize
pub fn create_dialog_param(instance voidptr, template voidptr, parent_hwnd voidptr, dialog_func WndProc, init_param isize) isize {
	return C.CreateDialogParamW(instance, template, parent_hwnd, dialog_func, init_param)
}

fn C.GetClientRect(hWnd voidptr, lpRect &RECT) bool
pub fn get_client_rect(hwnd voidptr, rect &RECT) bool {
	return C.GetClientRect(hwnd, rect)
}

fn C.ClientToScreen(hWnd voidptr, lpPoint &POINT) bool
pub fn client_to_screen(hwnd voidptr, point &POINT) bool {
	return C.ClientToScreen(hwnd, point)
}

fn C.SetWindowPos(hWnd voidptr, hWndInsertAfter voidptr, X int, Y int, cx int, cy int, uFlags u32) bool
pub fn set_window_pos(hwnd voidptr, insert_after_hwnd voidptr, x int, y int, cx int, cy int, flags u32) bool {
	return C.SetWindowPos(hwnd, insert_after_hwnd, x, y, cx, cy, flags)
}

fn C.DestroyWindow(hWnd voidptr) bool
pub fn destroy_window(hwnd voidptr) bool {
	return C.DestroyWindow(hwnd)
}

fn C.MoveWindow(hWnd voidptr, X int, Y int, nWidth int, nHeight int, bRepaint bool) bool
pub fn move_window(hwnd voidptr, x int, y int, width int, height int, repaint bool) bool {
	return C.MoveWindow(hwnd, x, y, width, height, repaint)
}

fn C.GetDlgItem(hDlg voidptr, nIDDlgItem int) voidptr
pub fn get_dlg_item(dlg_handle voidptr, dlg_item_id int) voidptr {
	return C.GetDlgItem(dlg_handle, dlg_item_id)
}

fn C.SetParent(hWndChild voidptr, hWndNewParent voidptr) voidptr
pub fn set_parent(child_hwnd voidptr, new_parent_hwnd voidptr) voidptr {
	return C.SetParent(child_hwnd, new_parent_hwnd)
}

fn C.ShowWindow(hWnd voidptr, nCmdShow int) bool
pub fn show_window(hwnd voidptr, cmd_show int) bool {
	return C.ShowWindow(hwnd, cmd_show)
}

fn C.SetWindowLongPtrW(hWnd voidptr, nIndex int, dwNewLong isize) isize
pub fn set_window_long_ptr(hwnd voidptr, index int, new_long isize) isize {
	return C.SetWindowLongPtrW(hwnd, index, new_long)
}

fn C.FindWindowExW(hWndParent voidptr, hWndChildAfter voidptr, lpszClass &u16, lpszWindow &u16) voidptr
pub fn find_window_ex(parent_hwnd voidptr, child_after_hwnd voidptr, class string, window string) voidptr {
	return C.FindWindowExW(parent_hwnd, child_after_hwnd, class.to_wide(), window.to_wide())
}

fn C.CallWindowProcW(lpPrevWndFunc WndProc, hWnd voidptr, Msg u32, wParam usize, lParam isize) isize
pub fn call_window_proc(prev_wnd_func WndProc, hwnd voidptr, msg u32, wparam usize, lparam isize) isize {
	return C.CallWindowProcW(prev_wnd_func, hwnd, msg, wparam, lparam)
}

fn C.GetWindowTextLengthW(hWnd voidptr) int
pub fn get_window_text_length(hwnd voidptr) int {
	return C.GetWindowTextLengthW(hwnd)
}

fn C.GetWindowTextW(hWnd voidptr, lpString &u16, nMaxCount int) int
pub fn get_window_text(hwnd voidptr, text &u16, max_count int) int {
	return C.GetWindowTextW(hwnd, text, max_count)
}

fn C.SetWindowTextW(hWnd voidptr, lpString &u16) bool
pub fn set_window_text(hwnd voidptr, text string) bool {
	return C.SetWindowTextW(hwnd, text.to_wide())
}

fn C.LoadImageW(hInstance voidptr, name &u16, image_type u32, cx int, cy int, fuLoad u32) voidptr
pub fn load_image(hinstance voidptr, name voidptr, image_type u32, cx int, cy int, fuload u32) voidptr {
	return C.LoadImageW(hinstance, name, image_type, cx, cy, fuload)
}

fn C.ShellExecuteW(hwnd voidptr, lpOperation &u16, lpFile &u16, lpParameters &u16, lpDirectory &u16, nShowCmd int) voidptr
pub fn shell_execute(hwnd voidptr, lpoperation &u16, lpfile &u16, lpparameters &u16, lpdirectory &u16, nshowcmd int) voidptr {
	return C.ShellExecuteW(hwnd, lpoperation, lpfile, lpparameters, lpdirectory, nshowcmd)
}

fn C.MessageBoxW(voidptr, &u16, &u16, u32) int
pub fn message_box(hwnd voidptr, text string, title string, flags u32) int {
	return C.MessageBoxW(hwnd, text.to_wide(), title.to_wide(), flags)
}

fn C.DialogBoxW(hInstance voidptr, lpTemplate &u16, hWndParent voidptr, lpDialogFunc WndProc)
pub fn dialog_box(hinstance voidptr, lptemplate &u16, hwndparent voidptr, lpdialogfunc WndProc) {
	C.DialogBoxW(hinstance, lptemplate, hwndparent, lpdialogfunc)
}

fn C.GetParent(hWnd voidptr) voidptr
pub fn get_parent(hwnd voidptr) voidptr {
	return C.GetParent(hwnd)
}

fn C.GetStdHandle(nStdHandle u32) voidptr
pub fn get_std_handle(std_handle u32) voidptr {
	return C.GetStdHandle(std_handle)
}

fn C.TerminateProcess(h_process voidptr, u_exit_code u32) bool
pub fn terminate_process(h_process voidptr, exit_code u32) bool {
	return C.TerminateProcess(h_process, exit_code)
}

fn C.GetExitCodeProcess(h_process voidptr, lp_exit_code &u32) bool
pub fn get_exit_code_process(process_handle voidptr, exit_code &u32) bool {
	return C.GetExitCodeProcess(process_handle, exit_code)
}

// conflicts with the one V defines itself -- ??
// fn C.ReadFile(hFile voidptr, lpBuffer &i8, nNumberOfBytesToRead u32, lpNumberOfBytesRead &u32, lpOverlapped voidptr) bool
pub fn read_file(file_handle voidptr, buffer &i8, number_of_bytes_to_read u32, number_of_bytes_read &u32, overlapped voidptr) bool {
	return C.ReadFile(file_handle, buffer, number_of_bytes_to_read, C.LPDWORD(number_of_bytes_read),
		overlapped)
}

fn C.WriteFile(hFile voidptr, lpBuffer &i8, nNumberOfBytesToWrite u32, lpNumberOfBytesWritten &u32, lpOverlapped voidptr) bool
pub fn write_file(file_handle voidptr, buffer &i8, number_of_bytes_to_write u32, lnumber_of_bytes_written &u32, overlapped voidptr) bool {
	return C.WriteFile(file_handle, buffer, number_of_bytes_to_write, lnumber_of_bytes_written,
		overlapped)
}

fn C.CreatePipe(hReadPipe voidptr, hWritePipe voidptr, lpPipeAttributes voidptr, nSize u32) bool
pub fn create_pipe(read_pipe_handle voidptr, write_pipe_handle voidptr, pipe_attributes voidptr, size u32) bool {
	return C.CreatePipe(read_pipe_handle, write_pipe_handle, pipe_attributes, size)
}

fn C.SetHandleInformation(hObject voidptr, dwMask u32, dwFlags u32) bool
pub fn set_handle_information(object_handle voidptr, mask u32, flags u32) bool {
	return C.SetHandleInformation(object_handle, mask, flags)
}

fn C.CloseHandle(hObject voidptr) bool
pub fn close_handle(object_handle voidptr) bool {
	return C.CloseHandle(object_handle)
}

fn C.CreateProcessW(lpApplicationName &u16, lpCommandLine &u16, lpProcessAttributes voidptr, lpThreadAttributes voidptr, bInheritHandles bool, dwCreationFlags u32, lpEnvironment voidptr, lpCurrentDirectory &u16, lpStartupInfo &STARTUPINFO, lpProcessInformation &PROCESS_INFORMATION) bool
pub fn create_process(application_name voidptr, command_line string, process_attributes voidptr, thread_attributes voidptr, inherit_handles bool, creation_flags u32, environment voidptr, current_directory &u16, startup_info &STARTUPINFO, process_information &PROCESS_INFORMATION) bool {
	return C.CreateProcessW(application_name, command_line.to_wide(), process_attributes,
		thread_attributes, inherit_handles, creation_flags, environment, current_directory,
		startup_info, process_information)
}

fn C.GetLastError() u32
pub fn get_last_error() int {
	return int(C.GetLastError())
}

fn C.GetCurrentThreadId() u32
pub fn get_current_thread_id() u32 {
	return C.GetCurrentThreadId()
}

fn C.FindWindowW(lpClassName &u16, lpWindowName &u16) voidptr
pub fn findwindoww(class_name &u16, window_name &u16) voidptr {
	return C.FindWindowW(class_name, window_name) 
}

fn C.EnumChildWindows(hWndParent voidptr, lpEnumFunc WndEnumProc, lParam isize) bool
pub fn enum_child_windows(hwnd_parent voidptr, enum_callback WndEnumProc, lparam isize) bool {
	return C.EnumChildWindows(hwnd_parent, enum_callback, lparam) 
}

fn C.IsWindowVisible(hWnd voidptr) bool
pub fn is_window_visible(hwnd voidptr) bool {
	return C.IsWindowVisible(hwnd) 
}

fn C.GetClassNameW(hWnd voidptr, lpClassName &u16, nMaxCount int) int
pub fn get_class_name(hwnd voidptr, class_name &u16, max_count int) int {
	return C.GetClassNameW(hwnd, class_name, max_count ) 
}
