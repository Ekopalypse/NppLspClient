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
	configuration_file = 'NppLspClientConfig.toml'
	log_file = 'NppLspClient.log'
)

__global (
	npp_data NppData
	func_items []FuncItem
	editor sci.Editor
	npp notepadpp.Npp
	dll_instance voidptr
	p Plugin
	end_line u32
	end_char u32
)

pub struct Plugin {
pub:
	error_style_id byte = 1
	warning_style_id byte = 2
	info_style_id byte = 3
	hint_style_id byte = 4
	outgoing_msg_style_id byte = 5
	incoming_msg_style_id byte = 6
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
			update_settings()
			plugin_config_dir := os.join_path(npp.get_plugin_config_dir(), plugin_name)
			p.main_config_file = os.join_path(plugin_config_dir, configuration_file)

			if ! os.exists(plugin_config_dir) {
				os.mkdir(plugin_config_dir) or { return }
			}

			if os.exists(p.main_config_file) {
				read_main_config()
			}
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
			p.current_file_path = npp.get_filename_from_id(notification.nmhdr.id_from)
			check_lexer(u64(notification.nmhdr.id_from))

			if !(p.document_is_of_interest && p.cur_lang_srv_running) { 
				editor.clear_diagnostics()
				return 
			}

			if p.lsp_config.lspservers[p.current_language].initialized {
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
		notepadpp.nppn_filebeforesave {
			if p.document_is_of_interest {
				p.current_language = npp.get_language_name_from_id(notification.nmhdr.id_from)
				lsp.on_file_before_saved(p.current_file_path)
			}
		}
		notepadpp.nppn_filesaved {
			if p.document_is_of_interest {
				p.current_language = npp.get_language_name_from_id(notification.nmhdr.id_from)
				lsp.on_file_saved(p.current_file_path)
			}
			if p.current_file_path == p.main_config_file {
				lsp.analyze_config(p.main_config_file)
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
				if notification.modification_type & sci.sc_mod_beforedelete == sci.sc_mod_beforedelete {
					end_pos := u32(notification.position + notification.length)
					end_line = editor.line_from_position(usize(end_pos))
					end_line_start_pos := editor.position_from_line(end_line)
					end_char = end_pos - end_line_start_pos
				} else {
					mod_type := notification.modification_type & (sci.sc_mod_inserttext | sci.sc_mod_deletetext)
					if mod_type > 0 {
						start_line := editor.line_from_position(usize(notification.position))
						line_start_pos := editor.position_from_line(start_line)
						start_char := u32(notification.position) - line_start_pos
						mut range_length := u32(notification.length)
						mut content := ''
						
						if mod_type & sci.sc_mod_inserttext == sci.sc_mod_inserttext {
							end_line = start_line
							end_char = start_char
							range_length = 0
							content = unsafe { cstring_to_vstring(notification.text)[..int(notification.length)] }
						}
						
						lsp.on_buffer_modified(p.current_file_path, 
											   start_line,
											   start_char,
											   end_line, 
											   end_char,
											   range_length,
											   content)
					}
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
		'---': voidptr(0)
		'Format document': format_document
		'Format selected text': format_selected_range
		'Goto definition': goto_definition
		'Peek definition': peek_definition
		'Goto implementation': goto_implementation
		'Peek implementation': peek_implementation
		'Goto declaration': goto_declaration
		'Find references': find_references
		'Highlight in document': document_highlight
		'List all symbols from document': document_symbols
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
	p.console_window.log('checking current lexer', p.info_style_id)
	p.current_language = npp.get_language_name_from_id(buffer_id)
	p.document_is_of_interest = p.current_language in p.lsp_config.lspservers
	p.console_window.log('', p.info_style_id)
	check_ls_status(true)
}

pub fn apply_config() {
	stop_all_server()
	read_main_config()
}

fn read_main_config() {
	p.console_window.log('rereading main config', p.info_style_id)
	p.lsp_config = lsp.decode_config(p.main_config_file)
	update_settings()
}

pub fn open_config() {
	if ! os.exists(p.main_config_file) {
		mut f := os.open_append(p.main_config_file) or { return }
		f.write_string(lsp.create_default()) or { return }
		f.close()
	}
	if os.exists(p.main_config_file) { npp.open_document(p.main_config_file) }
}

fn update_settings() {
	p.console_window.log('update settings', p.info_style_id)
	fore_color := npp.get_editor_default_foreground_color()
	back_color := npp.get_editor_default_background_color()
	p.console_window.update_settings(fore_color, 
									 back_color,
									 p.lsp_config.error_color,
									 p.lsp_config.warning_color,
									 p.lsp_config.incoming_msg_color,
									 p.lsp_config.outgoing_msg_color,
									 p.lsp_config.enable_logging,
									 p.lsp_config.log_level)

	editor.error_msg_color = p.lsp_config.error_color
	editor.warning_msg_color = p.lsp_config.warning_color
	editor.info_msg_color = fore_color
	editor.diag_indicator = usize(p.lsp_config.indicator_id)
	editor.update_styles()
}

pub fn start_lsp_server() {
	p.console_window.log('starting language server: ${p.current_language}', p.info_style_id)
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
	p.console_window.log('stopping language server: ${p.current_language}', p.info_style_id)
	p.proc_manager.stop(p.current_language)
	p.lsp_config.lspservers[p.current_language].initialized = false
	p.console_window.log('initialized = ${p.lsp_config.lspservers[p.current_language].initialized}', p.info_style_id)
	p.current_file_version = 0
}

pub fn restart_lsp_server() {
	p.console_window.log('restarting lsp server: ${p.current_language}', p.info_style_id)
	stop_lsp_server()
	start_lsp_server()
}

pub fn stop_all_server() {
	p.console_window.log('stop all running language server', p.info_style_id)
	p.proc_manager.stop_all_running_processes()
	for language, _ in p.lsp_config.lspservers {
		p.lsp_config.lspservers[language].initialized = false
		p.console_window.log('$language initialized = ${p.lsp_config.lspservers[language].initialized}', p.info_style_id)
	}
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
	p.console_window.log('checking language server status: ${p.current_language}', p.info_style_id)
	if p.current_language in p.proc_manager.running_processes {
		p.console_window.log('  is already running', p.info_style_id)
		p.cur_lang_srv_running = true
		return
	}

	if check_auto_start && !p.lsp_config.lspservers[p.current_language].auto_start_server {
		p.console_window.log('  either unknown language or server should not be started automatically', p.info_style_id)
		p.cur_lang_srv_running = false
		return
	}
	
	p.console_window.log('  trying to start ${p.lsp_config.lspservers[p.current_language].executable}', p.info_style_id)
	proc_status := p.proc_manager.start(p.current_language,
										p.lsp_config.lspservers[p.current_language].executable,
										p.lsp_config.lspservers[p.current_language].args)
	
	match proc_status {
		.running {
			p.console_window.log('  running', p.info_style_id)
			p.console_window.log('${p.current_language} server is running', p.info_style_id)
			p.cur_lang_srv_running = true
			p.current_stdin = p.proc_manager.running_processes[p.current_language].stdin
		}
		.error_no_executable {
			p.console_window.log('  cannot find executable', p.info_style_id)
			p.cur_lang_srv_running = false
		}
		.failed_to_start {
			p.console_window.log('  failed to start', p.info_style_id)
			p.cur_lang_srv_running = false
		}
	}
}

pub fn format_document() {
	lsp.on_format_document(p.current_file_path)
}

pub fn format_selected_range() {
	lsp.on_format_selected_range(p.current_file_path)
}

pub fn goto_definition() {
	lsp.on_goto_definition(p.current_file_path)
}

pub fn peek_definition() {
	lsp.on_peek_definition(p.current_file_path)
}

pub fn goto_implementation() {
	lsp.on_goto_implementation(p.current_file_path)
}

pub fn peek_implementation() {
	lsp.on_peek_implementation(p.current_file_path)
}

pub fn goto_declaration() {
	lsp.on_goto_declaration(p.current_file_path)	
}

pub fn find_references() {
	lsp.on_find_references(p.current_file_path)	
}

pub fn document_highlight() {
	// TODO: isn't that npps smarthighlight feature?? If it is, is there any benefit using it?
	lsp.on_document_highlight(p.current_file_path)		
}

pub fn document_symbols() {
	lsp.on_document_symbols(p.current_file_path)		
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
