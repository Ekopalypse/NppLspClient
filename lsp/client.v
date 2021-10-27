module lsp
import x.json2

const (
	content_length = 'Content-Length: '
)

pub fn on_message_received(message string) {
	p.console_window.log('on_message_received: $message', 2)
	mut start_position := 0
	mut length := 0
	message__ := if p.incomplete_msg.len != 0 { p.incomplete_msg + message } else { message }
	for {
		end_of_header := message__.index_after('\r\n\r\n', start_position)
		if end_of_header > 16 {
			length = message__[start_position..end_of_header].find_between(content_length, '\r\n').int()
			if message__.len >= length + end_of_header + 4 {
				json_message := json2.decode<JsonMessage>('${message__[end_of_header + 4..length + end_of_header + 4]}') or { JsonMessage{} }
				match true {
					json_message.id.len == 0 {
						notification_handler(json_message)
					}
					json_message.result.len != 0 {
						response_handler(json_message)
					}
					json_message.error.len != 0 {
						error_response_handler(json_message)
					}
					else {
						request_handler(json_message)
					}
				}
				p.incomplete_msg = ''
			} else {
				p.incomplete_msg = message__[start_position ..]
				break
			}
		} else {
			p.incomplete_msg += if message__.len > start_position { message__[start_position ..] } else {''}
			break
		}
		start_position = length + end_of_header + 4
	}
}

pub fn on_init(npp_pid int, current_directory string) {
	p.console_window.log('on_init: $npp_pid', 0)
	lsp.write_to(
		p.current_stdin, 
		lsp.initialize_msg(npp_pid, current_directory)
	)
}

pub fn on_file_opened(file_name string) {
	if file_name.len == 0 { return }
	lang_id := if p.current_language == 'vlang' { 'v' } else { p.current_language }
	p.console_window.log('on_file_opened:: $p.current_language: $file_name', 0)
	p.console_window.log('on_file_opened: initialized=${p.lsp_config.lspservers[p.current_language].initialized}', 0)
	if p.lsp_config.lspservers[p.current_language].initialized {
		content := editor.get_text()
		lsp.write_to(
			p.current_stdin,
			lsp.did_open(file_name, 0, lang_id, content)
		)
	}
}

pub fn on_file_saved(file_name string) {
	p.console_window.log('on_file_saved: $file_name', 0)
	if p.lsp_config.lspservers[p.current_language].initialized {
		p.current_file_version++
		lsp.write_to(
			p.current_stdin,
			lsp.did_save(file_name, p.current_file_version)
		)
	}
}

pub fn on_file_closed(file_name string) {
	p.console_window.log('on_file_closed: $file_name', 0)
	if p.lsp_config.lspservers[p.current_language].initialized {
		lsp.write_to(
			p.current_stdin,
			lsp.did_close(file_name)
		)
	}
}

pub fn on_buffer_modified(file_name string, 
						  start_line u32,
						  start_char_pos u32, 
						  end_line u32, 
						  end_char_pos u32, 
						  range_length u32, 
						  text string) {

	if p.lsp_config.lspservers[p.current_language].initialized {
		p.current_file_version++

		match p.lsp_config.lspservers[p.current_language].features.doc_sync_type {
			1 {  // TextDocumentSyncKind.full
				lsp.write_to(
					p.current_stdin,
					lsp.did_change_full(file_name, p.current_file_version, editor.get_text())
				)
			}
			2 {  // TextDocumentSyncKind.incremental
				content := text.replace_each(['\\', '\\\\', '\b', r'\b', '\f', r'\f', '\r', r'\r', '\n', r'\n', '\t', r'\t', '"', r'\"'])
				lsp.write_to(
					p.current_stdin,
					lsp.did_change_incremental(file_name, 
											   p.current_file_version, 
											   content, 
											   start_line, 
											   start_char_pos, 
											   end_line, 
											   end_char_pos)
				)
			}
			else{}
		}

		// trigger_characters might be in both lists, hence two if's
		// not sure if this is a good idea.
		if text in p.lsp_config.lspservers[p.current_language].features.compl_trigger_chars {
			lsp.write_to(
				p.current_stdin,
				lsp.request_completion(file_name, start_line, start_char_pos+1, text)  // ?? why +1
			)
		}
		if text in p.lsp_config.lspservers[p.current_language].features.sig_help_trigger_chars {
			lsp.write_to(
				p.current_stdin,
				lsp.request_signature_help(file_name, start_line, start_char_pos+1, text)
			)
		}
	}
}

pub fn on_format_document(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized {
		lsp.write_to(
			p.current_stdin,
			lsp.format_document(file_name, editor.get_tab_size(), editor.use_spaces(), true, true, true)
		)	
	}
}

pub fn on_goto_definition(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized {
		current_pos := editor.get_current_position()
		current_line := editor.line_from_position(usize(current_pos))
		line_start_pos := editor.position_from_line(usize(current_line))
		char_pos := current_pos - line_start_pos
		lsp.write_to(
			p.current_stdin,
			lsp.goto_definition(file_name, u32(current_line), u32(char_pos))
		)	
	}
}

pub fn on_goto_implementation(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized {
		current_pos := editor.get_current_position()
		current_line := editor.line_from_position(usize(current_pos))
		line_start_pos := editor.position_from_line(usize(current_line))
		char_pos := current_pos - line_start_pos
		lsp.write_to(
			p.current_stdin,
			lsp.goto_implementation(file_name, u32(current_line), u32(char_pos))
		)	
	}
}

pub fn on_peek_definition(file_name string) {
	p.console_window.log('on_peek_definition not implemented yet', 3)
}

pub fn on_peek_implementation(file_name string) {
	p.console_window.log('on_peek_implementation not implemented yet', 3)
}

fn notification_handler(json_message JsonMessage) {
	match json_message.method {
		'textDocument/publishDiagnostics' {
			publish_diagnostics(json_message.params)
		}
		else {
			p.console_window.log('  unhandled notification $json_message.method received', 3)
		}
	}
}

fn response_handler(json_message JsonMessage) {
	id := json_message.id.int()
	if json_message.result != 'null' {
		func_ptr := p.open_response_messages[id]
		if func_ptr != voidptr(0) {
			func_ptr(json_message.result.str())
		} else {
			p.console_window.log('  unexpected response received', 3)
		}
	}
	p.open_response_messages.delete(id)
}

fn error_response_handler(json_message JsonMessage) {
	p.console_window.log('  !! ERROR RESPONSE !! received', 4)
	p.open_response_messages.delete(json_message.id.int())
}

fn request_handler(json_message JsonMessage) {
	p.console_window.log('  unhandled request received', 3)
}

fn publish_diagnostics(params string) {
	diag := json2.decode<PublishDiagnosticsParams>(params) or { PublishDiagnosticsParams{} }
	editor.clear_diagnostics()
	for d in diag.diagnostics {
		editor.add_diagnostics_info(d.range.start.line, d.message, d.severity)
	}
}

fn initialize_msg_response(json_message string) {
	result := json2.raw_decode(json_message) or { '' }
	result_map := result.as_map()
	if 'capabilities' in result_map {
		capabilities := result_map['capabilities'] or { '' }
		sc := json2.decode<ServerCapabilities>(capabilities.str()) or { ServerCapabilities{} }
		p.console_window.log('    initialized response received', 0)
		p.lsp_config.lspservers[p.current_language].features.doc_sync_type = sc.text_document_sync
		p.lsp_config.lspservers[p.current_language].features.compl_trigger_chars = sc.completion_provider.trigger_characters
		p.lsp_config.lspservers[p.current_language].features.sig_help_trigger_chars = sc.signature_help_provider.trigger_characters
		p.lsp_config.lspservers[p.current_language].features.sig_help_retrigger_chars = sc.signature_help_provider.retrigger_characters

		lsp.write_to(
			p.current_stdin,
			lsp.initialized_msg()
		)

		p.lsp_config.lspservers[p.current_language].initialized = true
		current_file := npp.get_current_filename()
		on_file_opened(current_file)
	} else {
		p.console_window.log('  unexpected initialize response received', 4)
	}
}

fn completion_response(json_message string) {
	cl := json2.decode<CompletionList>(json_message) or { CompletionList{} }
	mut ci := []CompletionItem{}
	if cl.items.len != 0 {
		ci = cl.items
	} else {
		cia := json2.decode<CompletionItemArray>(json_message) or { CompletionItemArray{} }
		ci = cia.items
	}
	if ci.len > 0 { editor.display_completion_list(ci.map(it.label).join('\n')) }
}

fn signature_help_repsonse(json_message string) {
	p.console_window.log('  signature help response received: $json_message', 0)
	sh := json2.decode<SignatureHelp>(json_message) or { SignatureHelp{} }
	if sh.signatures.len > 0 {
		editor.display_signature_hints(sh.signatures[0].label)
	}
	p.console_window.log('$sh', 0)
}

fn format_document_repsonse(json_message string) {
	p.console_window.log('  format document response received: $json_message', 0)
	tea := json2.decode<TextEditArray>(json_message) or { TextEditArray{} }
	editor.begin_undo_action()
	for item in tea.items {
		start_pos := u32(editor.position_from_line(usize(item.range.start.line))) + item.range.start.character
		end_pos := u32(editor.position_from_line(usize(item.range.end.line))) + item.range.end.character
		editor.replace_target(start_pos, end_pos, item.new_text)
	}
	editor.end_undo_action()
}

fn goto_definition_repsonse(json_message string) {
	p.console_window.log('NOT IMPLEMENTED YET: goto definition response received: $json_message', 3)
}

fn goto_implementation_repsonse(json_message string) {
	p.console_window.log('NOT IMPLEMENTED YET: goto implementation response received: $json_message', 3)
}
