module npp_plugin

import os
import notepadpp
import scintilla as sci
import lsp
import about_dialog
import console

fn C._vinit(int, voidptr)
fn C._vcleanup()
fn C.GC_INIT()

const (
	plugin_name = 'NppLspClient'
	configuration_file = 'NppLspClientConfig.json'
	log_file = 'NppLspClient.log'
)

__global (
	npp_data NppData
	func_items []FuncItem
	editor sci.Editor
	npp notepadpp.Npp
	dll_instance voidptr
	p Plugin
)

pub struct Plugin {
pub mut:
	name string = plugin_name
	main_config_file string
	console_window console.DockableDialog
	lsp_config lsp.Configs
	cur_lang_srv_running bool
	proc_manager lsp.ProcessManager
	message_queue chan string = chan string{cap: 100}
	incomplete_msg string
	current_language string
	current_stdin voidptr
	current_file_path string
	current_file_version u32
	working_buffer_id u64
	file_version_map map[u64]u32
	document_is_of_interest bool
	new_file_opened u64
	open_response_messages map[int]fn(json_message string)
}

pub struct NppData {
pub mut:
	npp_handle voidptr
	scintilla_main_handle voidptr
	scintilla_second_handle voidptr
}

struct FuncItem {
mut:
	item_name [64]u16
	p_func fn()
	cmd_id int
	init_to_check bool
	p_sh_key voidptr
}

[export: isUnicode]
fn is_unicode() bool { return true }

[export: getName]
fn get_name() &u16 { return plugin_name.to_wide() }

[export: setInfo]
fn set_info(nppData NppData) {
	npp_data = nppData
	npp = notepadpp.Npp{npp_data.npp_handle}
	editor = sci.create_editors(nppData.scintilla_main_handle, nppData.scintilla_second_handle)
	// create as soon as possible because nppn_ready is NOT the first message received
	p.console_window = console.DockableDialog{ name: 'LSP output console'.to_wide() }
	p.console_window.create(npp_data.npp_handle, plugin_name)
}

[export: beNotified]
fn be_notified(notification &sci.SCNotification) {
	match notification.nmhdr.code {
		notepadpp.nppn_ready {

			back_color := npp.get_editor_default_background_color()
			fore_color := npp.get_editor_default_foreground_color()
			p.console_window.init_scintilla(fore_color, back_color)

			plugin_config_dir := os.join_path(npp.get_plugin_config_dir(), plugin_name)
			p.main_config_file = os.join_path(plugin_config_dir, configuration_file)

			if ! os.exists(plugin_config_dir) {
				os.mkdir(plugin_config_dir) or { return }
			}

			if os.exists(p.main_config_file) {
				read_main_config()
			}
			editor.alloc_styles()
		}

		notepadpp.nppn_bufferactivated {
			current_view := npp.get_current_view()
			if current_view == 0 {
				editor.current_func = editor.main_func
				editor.current_hwnd = editor.main_hwnd
			}
			else {
				editor.current_func = editor.second_func
				editor.current_hwnd = editor.second_hwnd
			}

			editor.init_styles()
			check_lexer(u64(notification.nmhdr.id_from))
			if !(p.document_is_of_interest && p.cur_lang_srv_running) { 
				editor.clear_diagnostics()
				return 
			}

			if p.lsp_config.lspservers[p.current_language].initialized {
				p.current_file_path = npp.get_filename_from_id(notification.nmhdr.id_from)
				if p.working_buffer_id == u64(notification.nmhdr.id_from) {
					return
				}
				// saving old buffer states
				if p.lsp_config.lspservers[p.current_language].initialized {
					p.file_version_map[p.working_buffer_id] = p.current_file_version
				}
				// assign new buffer related settings
				p.working_buffer_id = u64(notification.nmhdr.id_from)
				p.current_file_version = p.file_version_map[p.working_buffer_id]

				if p.new_file_opened == p.working_buffer_id {
					p.new_file_opened = 0
					lsp.on_file_opened(p.current_file_path)
				}
			} else {
				p.current_file_path = npp.get_filename_from_id(u64(notification.nmhdr.id_from))
				current_directory := os.dir(p.current_file_path)
				lsp.on_init(os.getpid(), current_directory)
			}
		}

		notepadpp.nppn_fileopened {
			p.new_file_opened = u64(notification.nmhdr.id_from)
		}

		// using nppn_filebeforeclose because it is to late to get the file_name with nppn_fileclosed
		notepadpp.nppn_filebeforeclose {
			if p.document_is_of_interest {
				current_filename := npp.get_filename_from_id(notification.nmhdr.id_from)
				lsp.on_file_closed(current_filename)
				p.file_version_map.delete(u64(notification.nmhdr.id_from))
			}
		}

		notepadpp.nppn_filesaved {
			if p.document_is_of_interest {
				p.current_language = npp.get_language_name_from_id(notification.nmhdr.id_from)
				lsp.on_file_saved(p.current_file_path)
			}
		}

		notepadpp.nppn_shutdown {
			stop_all_server()
		}

		notepadpp.nppn_langchanged {
			p.current_language = npp.get_language_name_from_id(notification.nmhdr.id_from)
			editor.clear_diagnostics()
			check_lexer(u64(notification.nmhdr.id_from))
		}

		sci.scn_modified {
			if p.document_is_of_interest {
				mod_type := notification.modification_type & (sci.sc_mod_inserttext | sci.sc_mod_deletetext)
				if mod_type > 0 {
					text := unsafe { cstring_to_vstring(notification.text)[..int(notification.length)] }
					lsp.on_buffer_modified(p.current_file_path, 
										   notification.position, 
										   text, 
										   notification.length, 
										   notification.lines_added,
										   mod_type == 1)
				}
			}
		}
		else {}  // make match happy
	}
}

[export: messageProc]
fn message_proc(msg u32, wparam usize, lparam isize) isize {
	if msg == notepadpp.nppm_msgtoplugin {
		ci := &notepadpp.CommunicationInfo(lparam)

		match ci.internal_msg {
			lsp.new_message {
				new_message := <- p.message_queue
				lsp.on_message_received(new_message)
			}
			lsp.pipe_closed {
				p.proc_manager.check_running_processes()
			}
			else {}
		}
		return 0
	}
	return 1
}

[export: getFuncsArray]
fn get_funcs_array(mut nb_func &int) &FuncItem {
	menu_functions := {
		'Start server for current language': start_lsp_server
		'Stop server for current language': stop_lsp_server
		'Restart server for current language': restart_lsp_server
		'Stop all configured lsp server': stop_all_server
		'-': voidptr(0)
		'toggle_console': toggle_console
		'Open configuration file': open_config
		'Apply current configuration': apply_config
		'--': voidptr(0)
		'About': about
	}

	for k, v in menu_functions {
		mut func_name := [64]u16 {init: 0}
		func_name_length := k.len*2
		unsafe { C.memcpy(&func_name[0], k.to_wide(), if func_name_length < 128 { func_name_length } else { 127 }) }
		func_items << FuncItem {
			item_name: func_name
			p_func: v
			cmd_id: 0
			init_to_check: false
			p_sh_key: voidptr(0)
		}
	}
	unsafe { *nb_func = func_items.len }
	return func_items.data
}

fn check_lexer(buffer_id u64) {
	p.current_language = npp.get_language_name_from_id(buffer_id)
	p.document_is_of_interest = p.current_language in p.lsp_config.lspservers
	check_ls_status(true)
}

pub fn apply_config() {
	stop_all_server()
	read_main_config()
}

fn read_main_config() {
	p.lsp_config = lsp.decode_config(p.main_config_file)
}

pub fn open_config() {
	if ! os.exists(p.main_config_file) {
		mut f := os.open_append(p.main_config_file) or { return }
		f.write_string(lsp.create_default()) or { return }
		f.close()
	}
	if os.exists(p.main_config_file) { npp.open_document(p.main_config_file) }
}

pub fn start_lsp_server() {
	check_ls_status(false)
	// create and send a fake nppn_bufferactivated event
	mut sci_header := sci.SCNotification{text: &char(0)}
	sci_header.nmhdr.hwnd_from = npp_data.npp_handle
	sci_header.nmhdr.id_from = usize(npp.get_current_buffer_id())
	sci_header.nmhdr.code = notepadpp.nppn_bufferactivated
	be_notified(sci_header)
	editor.grab_focus()
}

pub fn stop_lsp_server() {
	p.proc_manager.stop(p.current_language)
	p.lsp_config.lspservers[p.current_language].initialized = false
	p.console_window.log('initialized = ${p.lsp_config.lspservers[p.current_language].initialized}', 0)
	p.current_file_version = 0
}

pub fn restart_lsp_server() {
	stop_lsp_server()
	start_lsp_server()
}

pub fn stop_all_server() {
	p.proc_manager.stop_all_running_processes()
}

pub fn toggle_console() {
	if p.console_window.is_visible {
		npp.hide_dialog(p.console_window.hwnd)
	} else {
		npp.show_dialog(p.console_window.hwnd)
	}
	p.console_window.is_visible = ! p.console_window.is_visible
}

pub fn about() {
	about_dialog.show(npp_data.npp_handle)
}

fn check_ls_status(check_auto_start bool) {

	if p.current_language in p.proc_manager.running_processes {
		p.cur_lang_srv_running = true
		return
	}

	if check_auto_start && !p.lsp_config.lspservers[p.current_language].auto_start_server {
		p.cur_lang_srv_running = false
		return
	}

	proc_status := p.proc_manager.start(p.current_language,
										p.lsp_config.lspservers[p.current_language].executable,
										p.lsp_config.lspservers[p.current_language].args.join(' '))

	if proc_status == .running {
			p.console_window.log('${p.current_language} server is running', 0)
			p.cur_lang_srv_running = true
			p.current_stdin = p.proc_manager.running_processes[p.current_language].stdin
	} else {
		p.cur_lang_srv_running = false
	}
}

[windows_stdcall]
[export: DllMain]
fn main(hinst voidptr, fdw_reason int, lp_reserved voidptr) bool{
	match fdw_reason {
		C.DLL_PROCESS_ATTACH {
			$if static_boehm ? {
				C.GC_INIT()
			}
			C._vinit(0, 0)
			dll_instance = hinst
			p.file_version_map = map[u64]u32{}
		}
		C.DLL_THREAD_ATTACH {
		}
		C.DLL_THREAD_DETACH {}
		C.DLL_PROCESS_DETACH {}
		else { return false }
	}
	return true
}