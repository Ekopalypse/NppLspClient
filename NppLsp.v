module npp_plugin

import os
import notepadpp
import scintilla as sci
import lsp
import dialogs.about_dialog
import dialogs.console
import dialogs.diagnostics
import dialogs.references
import dialogs.symbols
import util.io_handler as io
import util.procman as pm

fn C._vinit(int, voidptr)
fn C._vcleanup()
fn C.GC_INIT()

const (
	plugin_name = 'NppLspClient'
	configuration_file = 'NppLspClientConfig.toml'
	log_file = 'NppLspClient.log'
)

__global (
	p Plugin
)

pub struct Plugin {
mut:
	end_line u32
	end_char u32
pub mut:
	// npp plugin related
	npp_data NppData
	func_items []FuncItem
	editor sci.Editor
	npp notepadpp.Npp
	dll_instance voidptr

	name string = plugin_name
	main_config_file string
	console_window console.DockableDialog
	diag_window diagnostics.DockableDialog
	references_window references.DockableDialog
	symbols_window symbols.DockableDialog
	message_queue chan string = chan string{cap: 100}

	// lsp client related
	document_is_of_interest bool
	lsp_config lsp.Configs
	proc_manager pm.ProcessManager
	lsp_client lsp.Client

	current_language string
	current_file_path string
	current_file_version int
	working_buffer_id u64
	file_version_map map[u64]int
}

pub struct NppData {
pub mut:
	npp_handle voidptr
	scintilla_main_handle voidptr
	scintilla_second_handle voidptr
}

fn (nd NppData) is_valid(handle voidptr) bool {
	return handle == nd.npp_handle || 
		   handle == nd.scintilla_main_handle || 
		   handle == nd.scintilla_second_handle
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
	p.npp_data = nppData
	p.npp = notepadpp.Npp{p.npp_data.npp_handle}
	p.editor = sci.create_editors(nppData.scintilla_main_handle, nppData.scintilla_second_handle)
	// Create as early as possible, as nppn_ready is NOT the first message received.
	p.console_window = console.DockableDialog{}
	p.console_window.create(p.npp_data.npp_handle, plugin_name)
	p.diag_window = diagnostics.DockableDialog{}
	p.diag_window.create(p.npp_data.npp_handle, plugin_name)
	p.references_window = references.DockableDialog{}
	p.references_window.create(p.npp_data.npp_handle, plugin_name)
	p.symbols_window = symbols.DockableDialog{}
	p.symbols_window.create(p.npp_data.npp_handle, plugin_name)
}

[export: beNotified]
fn be_notified(notification &sci.SCNotification) {
	if !p.npp_data.is_valid(notification.nmhdr.hwnd_from) { return }
	match notification.nmhdr.code {
		notepadpp.nppn_ready {
			update_settings()
			plugin_config_dir := os.join_path(p.npp.get_plugin_config_dir(), plugin_name)
			if ! os.exists(plugin_config_dir) {
				os.mkdir(plugin_config_dir) or { return }
			}

			p.main_config_file = os.join_path(plugin_config_dir, configuration_file)
			if os.exists(p.main_config_file) {
				read_main_config()
			}
			// simulate a fake nppn_bufferactivated event
			p.on_buffer_activated(usize(p.npp.get_current_buffer_id()))
		}

		notepadpp.nppn_bufferactivated {
			p.on_buffer_activated(notification.nmhdr.id_from)
		}

		// notepadpp.nppn_fileopened is handled in nppn_bufferactivated

		// using nppn_filebeforeclose because it is to late to get the file_name with nppn_fileclosed
		notepadpp.nppn_filebeforeclose {
			if p.document_is_of_interest {
				p.console_window.log_info('>>> Items in current map: ${p.file_version_map}')
				current_filename := p.npp.get_filename_from_id(notification.nmhdr.id_from)
				lsp.on_file_closed(current_filename)
				p.console_window.log_info('>>> Removing ${u64(notification.nmhdr.id_from)} from map')
				p.file_version_map.delete(u64(notification.nmhdr.id_from))
				p.console_window.log_info('>>> ${p.file_version_map}')
			}
		}
		
		notepadpp.nppn_filebeforesave {
			if p.document_is_of_interest {
				lsp.on_file_before_saved(p.current_file_path)
			}
		}
		
		notepadpp.nppn_filesaved {
			if p.document_is_of_interest {
				p.current_file_path = p.npp.get_filename_from_id(notification.nmhdr.id_from)
				if p.current_file_version == -1 {
					lsp.on_file_opened(p.current_file_path)
					return
				}
				lsp.on_file_saved(p.current_file_path)
				p.diag_window.on_save()
			}
			if p.current_file_path == p.main_config_file {
				lsp.analyze_config(p.main_config_file)
			}
		}

		notepadpp.nppn_shutdown {
			stop_all_server()
		}

		notepadpp.nppn_langchanged {
			p.current_language = p.npp.get_language_name_from_id(notification.nmhdr.id_from)
			p.editor.clear_diagnostics()
			check_lexer(u64(notification.nmhdr.id_from))
			if p.document_is_of_interest && p.current_file_version == -1 {
				lsp.on_file_opened(p.current_file_path)
				return
			}
		}

		sci.scn_modified {
			if p.document_is_of_interest {
				mut deleted := true
				if notification.modification_type & sci.sc_mod_beforedelete == sci.sc_mod_beforedelete {
					pos := u32(notification.position + notification.length)
					p.end_line, p.end_char = p.editor.get_lsp_position_from_position(pos)
				} else {
					mod_type := notification.modification_type & (sci.sc_mod_inserttext | sci.sc_mod_deletetext)
					if mod_type > 0 {
						start_line, start_char := p.editor.get_lsp_position_from_position(u32(notification.position))
						mut range_length := u32(notification.length)
						mut content := ''
						
						if mod_type & sci.sc_mod_inserttext == sci.sc_mod_inserttext {
							deleted = false
							p.end_line = start_line
							p.end_char = start_char
							range_length = 0
							content = unsafe { cstring_to_vstring(notification.text)[..int(notification.length)] }
						}
						
						lsp.on_buffer_modified(p.current_file_path, 
											   start_line,
											   start_char,
											   p.end_line, 
											   p.end_char,
											   range_length,
											   content)
						if deleted {
							if notification.position > 0 {
								ch := p.editor.get_char_at(notification.position-1)
								if ch > 32 {
									chr := rune(ch).str()
									lsp.on_completion(p.current_file_path, start_line, start_char, chr)
									lsp.on_signature_help(p.current_file_path, start_line, start_char, chr)
								}
							}
						}
					}
				}
			}
		}
		
		sci.scn_charadded {
			line, pos := p.editor.get_lsp_position_info()
			if notification.ch > 32 {
				chr := rune(notification.ch).str()
				lsp.on_completion(p.current_file_path, line, pos, chr)
				lsp.on_signature_help(p.current_file_path, line, pos, chr)
			}
		}

		sci.scn_dwellend {
			p.editor.cancel_calltip()
			p.lsp_client.current_hover_position = 0
		}
		
		sci.scn_dwellstart {
			if notification.position != -1 {
				p.lsp_client.current_hover_position = u32(notification.position)
				lsp.on_hover(p.current_file_path)
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
			io.new_message {
				new_message := <- p.message_queue
				p.lsp_client.on_message_received(new_message)
			}
			io.new_err_message {
				err_message := <- p.message_queue
				p.console_window.log_info('$err_message')
			}
			io.pipe_closed {
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
		'Open configuration file': open_config
		'Apply current configuration': apply_config
		'--': voidptr(0)
		'Toggle console': toggle_console
		'Toggle diagnostics window': toggle_diag_window
		'Toggle references window': toggle_references_window
		'Toggle symbols window': toggle_symbols_window
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
		'Clear highlighting': clear_document_highlighting
		'Clear peeked implemenation': clear_implementation
		'Clear peeked definition': clear_definition
		'Goto next diagnostic message': goto_next_message
		'----': voidptr(0)
		'About': about
	}
	mut cmd_id := -1
	for k, v in menu_functions {
		if v != voidptr(0) { cmd_id++ }
		mut func_name := [64]u16 {init: 0}
		func_name_length := k.len*2
		unsafe { C.memcpy(&func_name[0], k.to_wide(), if func_name_length < 128 { func_name_length } else { 127 }) }
		p.func_items << FuncItem {
			item_name: func_name
			p_func: v
			cmd_id: cmd_id
			init_to_check: false
			p_sh_key: voidptr(0)
		}
	}
	unsafe { *nb_func = p.func_items.len }
	return p.func_items.data
}

fn (mut p Plugin) on_buffer_activated(buffer_id usize) {
	current_view := p.npp.get_current_view()
	if current_view == 0 {
		p.editor.current_func = p.editor.main_func
		p.editor.current_hwnd = p.editor.main_hwnd
	}
	else {
		p.editor.current_func = p.editor.second_func
		p.editor.current_hwnd = p.editor.second_hwnd
	}
	check_lexer(u64(buffer_id))
	p.current_file_path = p.npp.get_filename_from_id(buffer_id)

	// Return early if document is not of interest or language server is not running
	// if !(p.document_is_of_interest && p.lsp_client.cur_lang_srv_running && os.exists(p.current_file_path)) { 
	if !(p.document_is_of_interest && p.lsp_client.cur_lang_srv_running) { 
		p.editor.clear_diagnostics()
		p.symbols_window.clear()
		p.diag_window.clear(p.current_language)
		p.console_window.log_info('Document: either not of interest, LS not running or File does not exist')
		p.working_buffer_id = u64(buffer_id)
		p.current_file_version = -1
		return 
	}

	p.editor.initialize()

	if p.lsp_config.lspservers[p.current_language].initialized {
		// If we receive a buffer ID that is identical to the one currently in use, 
		// it is a reload event or it has been moved from the other view or something like nppm_switchtofile ...
		// In case of a relaod event the buffer id is still in the map as there was no file close event sent,
		// in case the buffer was moved from one view to the other the file close event has been sent. 
		if p.working_buffer_id == u64(buffer_id) {
			p.console_window.log_info('buffer reloaded, activated or moved between views')
			// p.current_file_version = 0
			// if p.working_buffer_id in p.file_version_map {
				// lsp.on_file_closed(p.current_file_path)
			// }
			// lsp.on_file_opened(p.current_file_path)
			return
		}
		// Saving the old buffer state if it has not been closed in the meantime.
		if p.working_buffer_id in p.file_version_map {
			p.console_window.log_info('Saving the state of the previous buffer (${p.working_buffer_id}) : ${p.current_file_version}')
			p.file_version_map[p.working_buffer_id] = p.current_file_version
		}
		// Assign new buffer as working buffer
		p.working_buffer_id = u64(buffer_id)
		p.console_window.log_info('Assigned new working buffer: ${p.working_buffer_id}')
		
		p.current_file_version = p.file_version_map[p.working_buffer_id] or { -1 }
		p.console_window.log_info('The last used file version for ${p.working_buffer_id} (${p.current_file_path}) is: ${p.current_file_version}')
		// V's map behaviour ensures that a newly added object receives an intial value of -1.
		// If this is the case, it must be a new buffer.
		if p.current_file_version == -1 {
			p.current_file_version = 0
			lsp.on_file_opened(p.current_file_path)
			p.file_version_map[p.working_buffer_id] = p.current_file_version
		}
		// reapply diagnostics
		p.diag_window.republish(p.current_language)

		// rerequest symbols
		lsp.on_document_symbols(p.current_file_path)
		
	} else {
		// Sending the didOpen notification as well as setting the initial parameters
		// is handled within the initialize_response function. 
		// Since there is no way to be sure which open files are handled by this language server,
		// this is only done for the current buffer.
		current_directory := os.dir(p.current_file_path)
		lsp.on_initialize(os.getpid(), current_directory)
	}
}

fn check_lexer(buffer_id u64) {
	p.console_window.log_info('checking current lexer')
	p.current_language = p.npp.get_language_name_from_id(buffer_id)
	p.document_is_of_interest = p.current_language in p.lsp_config.lspservers
	if p.document_is_of_interest {
		check_ls_status(true)
	} else {
		p.lsp_client.cur_lang_srv_running = false
	}
}

pub fn apply_config() {
	stop_all_server()
	read_main_config()
}

fn read_main_config() {
	p.console_window.log_info('rereading configuration file: ${p.main_config_file}')
	p.lsp_config = lsp.decode_config(p.main_config_file)
	p.lsp_client.config = p.lsp_config
	update_settings()
}

pub fn open_config() {
	if ! os.exists(p.main_config_file) {
		mut f := os.open_append(p.main_config_file) or { return }
		f.write_string(lsp.create_default()) or { return }
		f.close()
	}
	if os.exists(p.main_config_file) { p.npp.open_document(p.main_config_file) }
}

fn update_settings() {
	p.console_window.log_info('update settings')
	fore_color := p.npp.get_editor_default_foreground_color()
	back_color := p.npp.get_editor_default_background_color()
	p.diag_window.update_settings(fore_color, 
								  back_color,
								  p.lsp_config.error_color,
								  p.lsp_config.warning_color,
								  p.lsp_config.selected_text_color)
	p.console_window.update_settings(fore_color, 
									 back_color,
									 p.lsp_config.error_color,
									 p.lsp_config.warning_color,
									 p.lsp_config.incoming_msg_color,
									 p.lsp_config.outgoing_msg_color,
									 p.lsp_config.selected_text_color,
									 p.lsp_config.enable_logging)
	p.symbols_window.update_settings(fore_color, 
									 back_color,
									 p.lsp_config.selected_text_color)
	p.references_window.update_settings(fore_color, 
										back_color,
										p.lsp_config.selected_text_color,
										p.lsp_config.outgoing_msg_color,
										p.lsp_config.error_color)

	p.editor.error_msg_color = p.lsp_config.error_color
	p.editor.warning_msg_color = p.lsp_config.warning_color
	p.editor.info_msg_color = fore_color
	p.editor.diag_indicator = usize(p.lsp_config.diag_indicator_id)
	p.editor.calltip_foreground_color = fore_color
	if p.lsp_config.calltip_foreground_color != -1 { p.editor.calltip_foreground_color = p.lsp_config.calltip_foreground_color}
	p.editor.calltip_background_color = back_color
	if p.lsp_config.calltip_background_color != -1 { p.editor.calltip_background_color = p.lsp_config.calltip_background_color}
	p.editor.highlight_indicator = usize(p.lsp_config.highlight_indicator_id)
	p.editor.highlight_indicator_color = p.lsp_config.highlight_indicator_color

	p.editor.update_styles()
}

pub fn start_lsp_server() {
	p.console_window.log_info('starting language server: ${p.current_language}')
	check_ls_status(false)
	// create and send a fake nppn_bufferactivated event
	mut sci_header := sci.SCNotification{text: &char(0)}
	sci_header.nmhdr.hwnd_from = p.npp_data.npp_handle
	sci_header.nmhdr.id_from = usize(p.npp.get_current_buffer_id())
	sci_header.nmhdr.code = notepadpp.nppn_bufferactivated
	be_notified(sci_header)
	p.editor.grab_focus()
}

pub fn stop_lsp_server() {
	p.console_window.log_info('stopping language server: ${p.current_language}')
	lsp.stop_ls()
	p.proc_manager.remove(p.current_language)
	p.lsp_config.lspservers[p.current_language].initialized = false
	p.console_window.log_info('initialized = ${p.lsp_config.lspservers[p.current_language].initialized}')
	p.current_file_version = 0
	p.editor.clear_indicators()
}

pub fn restart_lsp_server() {
	p.console_window.log_info('restarting lsp server: ${p.current_language}')
	stop_lsp_server()
	start_lsp_server()
}

pub fn stop_all_server() {
	p.console_window.log_info('stop all running language server')
	for language, _ in p.proc_manager.running_processes {
		lsp.stop_ls()
		p.lsp_config.lspservers[language].initialized = false
		p.console_window.log_info('$language initialized = ${p.lsp_config.lspservers[language].initialized}')
	}
}

pub fn toggle_console() {
	if p.console_window.is_visible {
		p.npp.hide_dialog(p.console_window.hwnd)
	} else {
		p.npp.show_dialog(p.console_window.hwnd)
	}
	p.console_window.is_visible = ! p.console_window.is_visible
}

pub fn toggle_diag_window() {
	if p.diag_window.is_visible {
		p.npp.hide_dialog(p.diag_window.hwnd)
	} else {
		p.npp.show_dialog(p.diag_window.hwnd)
	}
	p.diag_window.is_visible = ! p.diag_window.is_visible
}

pub fn toggle_references_window() {
	if p.references_window.is_visible {
		p.npp.hide_dialog(p.references_window.hwnd)
	} else {
		p.npp.show_dialog(p.references_window.hwnd)
	}
	p.references_window.is_visible = ! p.references_window.is_visible
}
pub fn toggle_symbols_window() {
	if p.symbols_window.is_visible {
		p.npp.hide_dialog(p.symbols_window.hwnd)
	} else {
		p.npp.show_dialog(p.symbols_window.hwnd)
	}
	p.symbols_window.is_visible = ! p.symbols_window.is_visible
}

pub fn about() {
	about_dialog.show(p.npp_data.npp_handle)
}

fn check_ls_status(check_auto_start bool) {
	p.console_window.log_info('checking language server status: ${p.current_language}')
	p.proc_manager.check_running_processes()
	if p.current_language in p.proc_manager.running_processes {
		p.console_window.log_info('  is already running')
		p.lsp_client.cur_lang_srv_running = true
		return
	}

	if check_auto_start && !p.lsp_config.lspservers[p.current_language].auto_start_server {
		p.console_window.log_info('  either unknown language or server should not be started automatically')
		p.lsp_client.cur_lang_srv_running = false
		p.editor.clear_diagnostics()
		return
	}
	
	p.console_window.log_info('  trying to start ${p.lsp_config.lspservers[p.current_language].executable}')
	start_ls(p.current_language) or {
		p.console_window.log_error('  $err')
		p.lsp_client.cur_lang_srv_running = false
		p.editor.clear_diagnostics()
		return
	}

	p.console_window.log_info('  running')
	p.lsp_client.cur_lang_srv_running = true
}

fn start_ls(language string) ? {
	p.proc_manager.start(language, p.lsp_config.lspservers[language]) or { return err }
	match p.lsp_config.lspservers[language].mode {
		'io' {
			go io.read_from_stdout(p.proc_manager.running_processes[language].stdout, p.message_queue)
			go io.read_from_stderr(p.proc_manager.running_processes[language].stderr, p.message_queue)
		}
		'tcp' {
			go io.read_from_socket(p.proc_manager.running_processes[language].socket, p.message_queue)
		}
		else {}
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

pub fn clear_definition() {
	p.editor.clear_peeked_info()
}

pub fn goto_implementation() {
	lsp.on_goto_implementation(p.current_file_path)
}

pub fn peek_implementation() {
	lsp.on_peek_implementation(p.current_file_path)
}

pub fn clear_implementation() {
	p.editor.clear_peeked_info()
}

pub fn goto_declaration() {
	lsp.on_goto_declaration(p.current_file_path)	
}

pub fn find_references() {
	lsp.on_find_references(p.current_file_path)	
}

pub fn document_highlight() {
	lsp.on_document_highlight(p.current_file_path)		
}

pub fn clear_document_highlighting() {
	p.editor.clear_highlighted_occurances()
}

pub fn document_symbols() {
	lsp.on_document_symbols(p.current_file_path)		
}

pub fn goto_next_message() {
	p.diag_window.goto_next_message()
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
			p.dll_instance = hinst
			p.file_version_map = map[u64]int{}
		}
		C.DLL_THREAD_ATTACH {
		}
		C.DLL_THREAD_DETACH {}
		C.DLL_PROCESS_DETACH {}
		else { return false }
	}
	return true
}
