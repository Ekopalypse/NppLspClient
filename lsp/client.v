module lsp
import x.json2
import os

const (
	content_length = 'Content-Length: '
	report_at = 'please report this as an issue at https://github.com/Ekopalypse/NppLspClient/issues'
)

pub fn on_message_received(message string) {
	p.console_window.log('on_message_received: $message', p.incoming_msg_style_id)
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

pub fn on_initialize(npp_pid int, current_directory string) {
	p.console_window.log('on_initialize: $npp_pid', 0)
	lsp.write_to(
		p.current_stdin, 
		lsp.initialize(npp_pid, current_directory)
	)
}

fn initialize_response(json_message string) {
	result := json2.raw_decode(json_message) or { '' }
	result_map := result.as_map()
	if 'capabilities' in result_map {
		capabilities := result_map['capabilities'] or { '' }
		sc := json2.decode<ServerCapabilities>(capabilities.str()) or { ServerCapabilities{} }
		p.console_window.log('    initialized response received', 0)

		p.lsp_config.lspservers[p.current_language].features = sc
		
		lsp.write_to(
			p.current_stdin,
			lsp.initialized()
		)

		p.lsp_config.lspservers[p.current_language].initialized = true
		p.working_buffer_id = u64(p.npp.get_current_buffer_id())
		p.current_file_version = 0
		p.file_version_map[p.working_buffer_id] = p.current_file_version
		on_file_opened(p.npp.get_current_filename())
	} else {
		p.console_window.log('  unexpected initialize response received', p.error_style_id)
	}
}

pub fn on_file_opened(file_name string) {
	if file_name.len == 0 { return }
	lang_id := if p.current_language == 'vlang' { 'v' } else { p.current_language }
	p.console_window.log('on_file_opened:: $p.current_language: $file_name', 0)
	p.console_window.log('on_file_opened: initialized=${p.lsp_config.lspservers[p.current_language].initialized}', 0)
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.send_open_close_notif
   {
		content := p.editor.get_text()
		lsp.write_to(
			p.current_stdin,
			lsp.did_open(file_name, 0, lang_id, content)
		)
	}
}

pub fn on_file_before_saved(file_name string) {
	p.console_window.log('on_file_before_saved: $file_name', 0)
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.supports_will_save
   {
		lsp.write_to(
			p.current_stdin,
			lsp.will_save(file_name)
		)
	}
}

pub fn on_file_saved(file_name string) {
	p.console_window.log('on_file_saved: $file_name', 0)
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.send_save_notif
   {
		mut content := ''
		if p.lsp_config.lspservers[p.current_language].features.include_text_in_save_notif {
			content = p.editor.get_text()
		}
		lsp.write_to(
			p.current_stdin,
			lsp.did_save(file_name, content)
		)
	}
}

pub fn on_will_save_wait_until(file_name string) {
	// TODO: make this an lspclient configuration parameter?
	p.console_window.log('on_file_saved: $file_name', 0)
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.supports_will_save_wait_until
   {
		lsp.write_to(
			p.current_stdin,
			lsp.will_save_wait_until(file_name, 3)  // TextDocumentSaveReason.FocusOut = 3
		)
	}
}

pub fn on_file_closed(file_name string) {
	p.console_window.log('on_file_closed: $file_name', 0)
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.send_open_close_notif
	{
		lsp.write_to(
			p.current_stdin,
			lsp.did_close(file_name)
		)
		// array_index := p.lsp_config.lspservers[p.current_language].open_documents.index(file_name)
		// if array_index > -1  {
			// p.lsp_config.lspservers[p.current_language].open_documents.delete(array_index)
		// }		
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

		match p.lsp_config.lspservers[p.current_language].features.text_document_sync {
			1 {  // TextDocumentSyncKind.full
				lsp.write_to(
					p.current_stdin,
					lsp.did_change_full(file_name, p.current_file_version, p.editor.get_text())
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
											   end_char_pos,
											   range_length)
				)
			}
			else{}
		}
		// on_completion(file_name, start_line, start_char_pos+1, text)
		// on_signature_help(file_name, start_line, start_char_pos+1, text)
	}
}

pub fn on_completion(file_name string, 
					 start_line u32,
					 start_char_pos u32, 
					 text string) {
	if p.lsp_config.lspservers[p.current_language].initialized {
		text__ := if text in p.lsp_config.lspservers[p.current_language].features.completion_provider.trigger_characters {
			text
		} else {
			''
		}
	
		lsp.write_to(
			p.current_stdin,
			lsp.request_completion(file_name, start_line, start_char_pos, text__)
		)
	}
}

fn completion_response(json_message string) {
	// p.console_window.log('json_message: $json_message', 0)
	mut ci := []CompletionItem{}
	if json_message.contains('"items":') {
		cl := json2.decode<CompletionList>(json_message) or { CompletionList{} }
		ci = cl.items
	} else {
		cia := json2.decode<CompletionItemArray>(json_message) or { CompletionItemArray{} }
		ci = cia.items
	}
	if ci.len > 0 { 
		// mut ci__ := ci.map(it.label)
		mut ci__ := ci.map(fn (item CompletionItem) string {
			label := if item.insert_text.len > 0 {
				item.insert_text.trim_space()
			} else {
				item.label.trim_space()
			}
			return label
		})
		// mut ci__ := ci.map(it.insert_text)
		ci__.sort()
		
		p.editor.display_completion_list(ci__.join('\n')) 
	}
}

pub fn on_signature_help(file_name string, 
						 start_line u32,
						 start_char_pos u32, 
						 text string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
		text in p.lsp_config.lspservers[p.current_language].features.signature_help_provider.trigger_characters 
	{
		lsp.write_to(
			p.current_stdin,
			lsp.request_signature_help(file_name, start_line, start_char_pos, text)
		)
	}
}

fn signature_help_response(json_message string) {
	p.console_window.log('  signature help response received: $json_message', 0)
	sh := json2.decode<SignatureHelp>(json_message) or { SignatureHelp{} }
	if sh.signatures.len > 0 {
		p.editor.display_signature_hints(sh.signatures[0].label)
	}
	p.console_window.log('$sh', 0)
}

pub fn on_format_document(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.document_formatting_provider
	{
		lsp.write_to(
			p.current_stdin,
			lsp.format_document(file_name, p.editor.get_tab_size(), p.editor.use_spaces(), true, true, true)
		)	
	}
}

fn format_document_response(json_message string) {
	p.console_window.log('  format document response received: $json_message', 0)
	tea := json2.decode<TextEditArray>(json_message) or { TextEditArray{} }
	p.editor.begin_undo_action()
	for item in tea.items {
		start_pos := u32(p.editor.position_from_line(item.range.start.line)) + item.range.start.character
		end_pos := u32(p.editor.position_from_line(item.range.end.line)) + item.range.end.character
		p.editor.replace_target(start_pos, end_pos, item.new_text)
	}
	p.editor.end_undo_action()
}

pub fn on_format_selected_range(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.document_range_formatting_provider
	{
		start_line, end_line, start_char, end_char := p.editor.get_range_from_selection()
		lsp.write_to(
			p.current_stdin,
			lsp.format_selected_range(file_name, start_line, end_line, start_char, end_char, p.editor.get_tab_size(), p.editor.use_spaces(), true, true, true)
		)	
	}
}

pub fn on_goto_definition(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.definition_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.goto_definition(file_name, current_line, char_pos)
		)	
	}
}

fn goto_definition_response(json_message string) {
	p.console_window.log('goto definition response received: $json_message', 0)
	goto_location_helper(json_message)
}

pub fn on_goto_implementation(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.implementation_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.goto_implementation(file_name, current_line, char_pos)
		)	
	}
}

fn goto_implementation_response(json_message string) {
	p.console_window.log('goto implementation response received: $json_message', 0)
	goto_location_helper(json_message)
}

fn goto_location_helper(json_message string) {
	mut start_pos := u32(0)
	if json_message.starts_with('[') {
		if json_message.contains('originSelectionRange') {
			lla := json2.decode<LocationLinkArray>(json_message) or { LocationLinkArray{} }
			if lla.items.len > 0 {
				p.npp.open_document(lla.items[0].target_uri)
				start_pos = u32(p.editor.position_from_line(lla.items[0].target_range.start.line))
				start_pos += lla.items[0].target_range.start.character
			}
		} else {
			loca := json2.decode<LocationArray>(json_message) or { LocationArray{} }
			if loca.items.len > 0 {

				p.npp.open_document(loca.items[0].uri)
				start_pos = u32(p.editor.position_from_line(loca.items[0].range.start.line))
				start_pos += loca.items[0].range.start.character
			}
		}
	} else {
		loc := json2.decode<Location>(json_message) or { Location{} }
		p.npp.open_document(loc.uri)
		start_pos = u32(p.editor.position_from_line(loc.range.start.line))
		start_pos += loc.range.start.character
	}
	p.editor.goto_pos(start_pos)	
}

pub fn on_peek_definition(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.definition_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.peek_definition(file_name, current_line, char_pos)
		)	
	}
}

fn peek_definition_response(json_message string) {
	p.console_window.log('peek definition response received: $json_message', 0)
	peek_helper(json_message)
}

pub fn on_peek_implementation(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.implementation_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.peek_implementation(file_name, current_line, char_pos)
		)	
	}
}

fn peek_implementation_response(json_message string) {
	p.console_window.log('peek implementation response received: $json_message', 0)
	peek_helper(json_message)
}

fn peek_helper(json_message string) {
	mut start_line := u32(0)
	mut end_line := u32(0)
	mut source_file := ''
	if json_message.starts_with('[') {
		if json_message.contains('originSelectionRange') {
			lla := json2.decode<LocationLinkArray>(json_message) or { LocationLinkArray{} }
			if lla.items.len > 0 {
				source_file = lla.items[0].target_uri
				start_line = lla.items[0].target_range.start.line
				end_line = lla.items[0].target_range.end.line
			}
		} else {
			loca := json2.decode<LocationArray>(json_message) or { LocationArray{} }
			if loca.items.len > 0 {
				source_file = loca.items[0].uri
				start_line = loca.items[0].range.start.line
				end_line = loca.items[0].range.end.line
			}
		}
	} else {
		loc := json2.decode<Location>(json_message) or { Location{} }
		source_file = loc.uri
		start_line = loc.range.start.line
		end_line = loc.range.end.line
	}
	
	if source_file.len > 0 {
		if os.exists(source_file) {
			content := os.read_lines(source_file) or { [''] }
			first_line := int(start_line)
			last_line__ := int(end_line)
			if content.len >= last_line__ {
				last_line := if content.len >= last_line__ + 4 { last_line__ + 4} else { content.len }
				peeked_code := '\n${content[first_line..last_line].join("\n")}'
				p.editor.show_peeked_info(peeked_code)
			}
		}
	}	
}

pub fn on_goto_declaration(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.declaration_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.goto_declaration(file_name, current_line, char_pos)
		)	
	}
}

fn goto_declaration_response(json_message string) {
	p.console_window.log('declaration response received: $json_message', 0)
	goto_location_helper(json_message)
}

pub fn on_find_references(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.references_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.find_references(file_name, current_line, char_pos)
		)
	}
}

fn find_references_response(json_message string) {
	p.console_window.log('find references response received: $json_message', p.info_style_id)
	if json_message.starts_with('[') {
		loca := json2.decode<LocationArray>(json_message) or { LocationArray{} }
		if loca.items.len > 0 {
			// TODO: simulate a find in files output seems to make sense but means another docked panel or a tabbed panel??
			for item in loca.items {
				p.console_window.log('  ${item.uri} ${item.range.start.line}', p.info_style_id)	
			}
		}
	}
}

pub fn on_document_highlight(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.document_highlight_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.document_highlight(file_name, current_line, char_pos)
		)
	}
}

fn document_highlight_response(json_message string) {
	// TODO: is this feature really needed??
	p.console_window.log('document highlight response received: $json_message', p.info_style_id)
	if json_message.starts_with('[') {
		dha := json2.decode<DocumentHighlightArray>(json_message) or { DocumentHighlightArray{} }
		if dha.items.len > 0 {
			for item in dha.items {
				p.console_window.log('  ${item.kind} ${item.range}', p.info_style_id)	
			}
		}
	}
}

pub fn on_document_symbols(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.document_symbol_provider
	{
		lsp.write_to(
			p.current_stdin,
			lsp.document_symbols(file_name)
		)
	}
}

fn document_symbols_response(json_message string) {
	p.console_window.log('document symbols response received: $json_message', 0)
	if json_message.starts_with('[') {
		if json_message.contains('selectionRange') {
			dsa := json2.decode<DocumentSymbolArray>(json_message) or { DocumentSymbolArray{} }
			for item in dsa.items {
				p.console_window.log('  ${item.name} ${item.detail} ${item.kind} ', p.info_style_id)
			}
		} else {
			sia := json2.decode<SymbolInformationArray>(json_message) or { SymbolInformationArray{} }
			for item in sia.items {
				p.console_window.log('  ${item.name} ${item.kind} ', p.info_style_id)
			}
		}
	}
}

pub fn on_hover(file_name string, position u32) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.hover_provider
	{
		current_line := p.editor.line_from_position(usize(position))
		char_pos := position - p.editor.position_from_line(current_line)
		lsp.write_to(
			p.current_stdin,
			lsp.hover(file_name, current_line, char_pos)
		)	
	}
}

fn hover_response(json_message string) {
	p.console_window.log('hover response received: $json_message', 0)
	h := json2.decode<Hover>(json_message) or { Hover{} }
	p.editor.display_hover_hints(p.current_hover_position, h.contents)
}

pub fn on_rename(file_name string, new_name string) {
	// TODO: really needed ?? - Npp offers replace in files, opened documents etc...
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.rename_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.rename(file_name, current_line, char_pos, new_name)
		)	
	}
}

fn rename_response(json_message string) {
	p.console_window.log('rename response received: $json_message', p.info_style_id)
	// TODO

}

pub fn on_prepare_rename(file_name string) {
	// TODO: really needed ?? - Could be interesting to see if the name given is valid
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.rename_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.prepare_rename(file_name, current_line, char_pos)
		)	
	}
}

fn prepare_rename_response(json_message string) {
	p.console_window.log('prepare rename response received: $json_message', p.info_style_id)
	// TODO

}

pub fn on_folding_range(file_name string) {
	// TODO: really needed ?? Could be interesting to fold the next folding level from a given position ??
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.folding_range_provider
	{
		lsp.write_to(
			p.current_stdin,
			lsp.folding_range(file_name)
		)	
	}
}

fn folding_range_response(json_message string) {
	p.console_window.log('folding range response received: $json_message', p.info_style_id)
	// TODO

}

pub fn on_selection_range(file_name string) {
	// TODO: really needed ?? would be another way of selecting text ??
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.selection_range_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.selection_range(file_name, current_line, char_pos)
		)	
	}
}

fn selection_range_response(json_message string) {
	p.console_window.log('selection range response received: $json_message', p.info_style_id)
	// TODO
}

pub fn on_cancel_request(request_id int) {
	// TODO: which requests should be cancellable??
	if p.lsp_config.lspservers[p.current_language].initialized {
		lsp.write_to(
			p.current_stdin,
			lsp.cancel_request(request_id)
		)
	}
}

pub fn on_progress(token int, value string) {
	// TODO: why would a client sent a progress notification to a server ??
	if p.lsp_config.lspservers[p.current_language].initialized {
		lsp.write_to(
			p.current_stdin,
			lsp.progress(token, value)
		)
	}
}

pub fn on_set_trace(trace_value string) {
	// TODO: find out where the valid values come from
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   (trace_value == 'off' || trace_value ==  'messages' || trace_value == 'verbose')
	{
		lsp.write_to(
			p.current_stdin,
			lsp.set_trace(trace_value)
		)
	}
}

pub fn on_incoming_calls() {
	// The request doesn’t define its own client and server capabilities.
	// It is only issued if a server registers for the textDocument/prepareCallHierarchy request.
	//  TODO: WorkDoneProgressParams
	token := 0
	value := ''
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.call_hierarchy_prepare_call
	{
		lsp.write_to(
			p.current_stdin,
			lsp.incoming_calls(token, value)
		)
	}
}

fn incoming_calls_response(json_message string) {
	// TODO:
	p.console_window.log('incoming_calls_response: $json_message', p.info_style_id)
}

pub fn on_outgoing_calls() {
	// see on_incoming_calls note
	//  TODO: WorkDoneProgressParams
	token := 0
	value := ''
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.call_hierarchy_prepare_call
	{
		lsp.write_to(
			p.current_stdin,
			lsp.outgoing_calls(token, value)
		)
	}
}

fn outgoing_calls_response(json_message string) {
	// TODO:
	p.console_window.log('outgoing_calls_response: $json_message', p.info_style_id)
}

pub fn on_code_action_resolve() {
	// TODO: how should this get be triggered?
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.code_action_resolve_provider
	{
		title := ''
		lsp.write_to(
			p.current_stdin,
			lsp.code_action_resolve(title)
		)
	}
}

fn code_action_resolve_response(json_message string) {
	// TODO:
	p.console_window.log('resolve_response: $json_message', p.info_style_id)
}

pub fn on_code_lens_resolve(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.code_lens_provider
	{
		lsp.write_to(
			p.current_stdin,
			lsp.code_lens_resolve(file_name)
		)
	}
}

fn code_lens_resolve_response(json_message string) {
	// TODO:
	p.console_window.log('resolve_response: $json_message', p.info_style_id)
}

pub fn on_completion_item_resolve(label string) {
	// TODO: supposed to be a request which gathers additional information about
	// the selected completion item.
	// Either use SCN_AUTOCSELECTION or SCN_USERLISTSELECTION (or both ?)
	// But how to display such additional information?
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.completion_provider.resolve_provider
	{
		lsp.write_to(
			p.current_stdin,
			lsp.completion_item_resolve(label)
		)
	}
}

fn completion_item_resolve_response(json_message string) {
	// TODO:
	p.console_window.log('resolve_response: $json_message', p.info_style_id)
}

pub fn on_document_link_resolve() {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.document_link_provider
	{
		// TODO:
		start_line, start_char, end_line, end_char := u32(0), u32(0), u32(0), u32(0)
		lsp.write_to(
			p.current_stdin,
			lsp.document_link_resolve(start_line, start_char, end_line, end_char)
		)
	}
}

fn document_link_resolve_response(json_message string) {
	// TODO:
	p.console_window.log('resolve_response: $json_message', p.info_style_id)
}

pub fn on_code_action(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.code_action_provider
	{
		start_line, start_char, end_line, end_char := u32(0), u32(0), u32(0), u32(0)
		lsp.write_to(
			p.current_stdin,
			lsp.code_action(file_name, start_line, start_char, end_line, end_char)
		)
	}
}

fn code_action_response(json_message string) {
	// TODO:
	p.console_window.log('code_action_response: $json_message', p.info_style_id)
}

pub fn on_code_lens(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.code_lens_provider
	{
		lsp.write_to(
			p.current_stdin,
			lsp.code_lens(file_name)
		)
	}
}

fn code_lens_response(json_message string) {
	// TODO:
	p.console_window.log('code_lens_response: $json_message', p.info_style_id)
}

pub fn on_color_presentation(file_name string) {
	// TODO:
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.color_provider
	{
		// lsp.write_to(
			// p.current_stdin,
			// lsp.color_presentation(file_name,
								   // start_line, 
								   // start_char, 
								   // end_line, 
								   // end_char,
								   // red,
								   // green,
								   // blue,
								   // alpha)
		// )
	}
}

fn color_presentation_response(json_message string) {
	p.console_window.log('color_presentation_response', p.info_style_id)
	cpa := json2.decode<ColorPresentationArray>(json_message) or { ColorPresentationArray{} }
	for item in cpa.items {
		p.console_window.log('$item', p.info_style_id)
	}
}

pub fn on_document_color(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.color_provider
	{
		lsp.write_to(
			p.current_stdin,
			lsp.document_color(file_name)
		)
	}
}

fn document_color_response(json_message string) {
	p.console_window.log('document_color_response', p.info_style_id)
	cia := json2.decode<ColorInformationArray>(json_message) or { ColorInformationArray{} }
	for item in cia.items {
		p.console_window.log('  ${item.range}', p.info_style_id)	
		p.console_window.log('  ${item.color}', p.info_style_id)	
	}
	
}

pub fn on_document_link(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.document_link_provider
	{
		lsp.write_to(
			p.current_stdin,
			lsp.document_link(file_name)
		)
	}
}

fn document_link_response(json_message string) {
	// TODO:
	p.console_window.log('document_link_response: $json_message', p.info_style_id)
}

pub fn on_linked_editing_range(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.linked_editing_range_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.linked_editing_range(file_name, current_line, char_pos)
		)
	}
}

fn linked_editing_range_response(json_message string) {
	// TODO:
	p.console_window.log('linked_editing_range_response: $json_message', p.info_style_id)
}

pub fn on_moniker(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.moniker_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.moniker(file_name, current_line, char_pos)
		)
	}
}

fn moniker_response(json_message string) {
	p.console_window.log('moniker_response: $json_message', p.info_style_id)
}

pub fn on_on_type_formatting(file_name string, ch string) {
	// TODO: I assume makes only sense with SCN_CHARADDED notification or
	// buffer modified with inserted text filter
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.document_on_type_formatting_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.on_type_formatting(file_name, 
								   current_line,
								   char_pos,
								   ch,
								   p.editor.get_tab_size(),
								   p.editor.use_spaces())
		)
	}
}

fn on_type_formatting_response(json_message string) {
	// TODO:
	p.console_window.log('on_type_formatting_response: $json_message', p.info_style_id)
}

pub fn on_prepare_call_hierarchy(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.call_hierarchy_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.prepare_call_hierarchy(file_name, current_line, char_pos)
		)
	}
}

fn prepare_call_hierarchy_response(json_message string) {
	// TODO:
	p.console_window.log('prepare_call_hierarchy_response: $json_message', p.info_style_id)
}

pub fn on_semantic_tokens_full(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.semantic_tokens_provider
	{
		lsp.write_to(
			p.current_stdin,
			lsp.semantic_tokens_full(file_name)
		)
	}
}

fn semantic_tokens_full_response(json_message string) {
	// TODO:
	p.console_window.log('full_response: $json_message', p.info_style_id)
}

pub fn on_semantic_tokens_delta(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.semantic_tokens_provider
	{
		// TODO:
		// The result id of a previous response.
		// The result Id can either point to a full response or 
		// a delta response depending on what was received last.
		previous_result_id := ''
		lsp.write_to(
			p.current_stdin,
			lsp.semantic_tokens_delta(file_name, previous_result_id)
		)
	}
}

fn semantic_tokens_delta_response(json_message string) {
	// TODO:
	p.console_window.log('delta_response: $json_message', p.info_style_id)
}

pub fn on_semantic_tokens_range(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.semantic_tokens_provider
	{
		// TODO:
		start_line, start_char, end_line, end_char := u32(0), u32(0), u32(0), u32(0)
		lsp.write_to(
			p.current_stdin,
			lsp.semantic_tokens_range(file_name, start_line, start_char, end_line, end_char)
		)
	}
}

fn semantic_tokens_range_response(json_message string) {
	// TODO:
	p.console_window.log('range_response: $json_message', p.info_style_id)
}

pub fn on_type_definition(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.type_definition_provider
	{
		current_line, char_pos := p.editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.type_definition(file_name, current_line, char_pos)
		)
	}
}

fn type_definition_response(json_message string) {
	p.console_window.log('type_definition_response: $json_message', p.info_style_id)
	goto_location_helper(json_message)
}

pub fn on_work_done_progress_cancel(file_name string) {
	// TODO:
	if p.lsp_config.lspservers[p.current_language].initialized {
		// lsp.write_to(
			// p.current_stdin,
			// lsp.work_done_progress_cancel(token, value)
		// )
	}
}

pub fn on_workspace_did_change_configuration() {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.supports_workspace_capabilities
	{
		// TODO: How to know what kind of settings are expected??
		// and how to get informed about those changes??
		lsp.write_to(
			p.current_stdin,
			lsp.workspace_did_change_configuration('null')
		)
	}
}

pub fn on_workspace_did_change_watched_files() {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.supports_workspace_capabilities
	{
		// TODO: Either Npp's or an own file/folder change monitor needs to be implemented.
		file_event_array := FileEventArray{}
		lsp.write_to(
			p.current_stdin,
			lsp.workspace_did_change_watched_files(file_event_array)
		)
	}
}

pub fn on_workspace_did_change_workspace_folders() {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.supports_workspace_capabilities
	{
		// TODO: needs support from Npp to retrieve the folders from FAW and Projects
		added_folders := WorkspaceFolderArray{}
		removed_folders := WorkspaceFolderArray{}
		lsp.write_to(
			p.current_stdin,
			lsp.workspace_did_change_workspace_folders(added_folders, removed_folders)
		)
	}
}

pub fn on_workspace_did_create_files() {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.workspace_capabilities.file_operations.did_create_supported
	{
		// TODO:
		files_created := FileCreateArray{}
		lsp.write_to(
			p.current_stdin,
			lsp.workspace_did_create_files(files_created)
		)
	}
}

pub fn on_workspace_did_delete_files() {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.workspace_capabilities.file_operations.did_delete_supported
	{
		// TODO:
		files_deleted := FileDeleteArray{}
		lsp.write_to(
			p.current_stdin,
			lsp.workspace_did_delete_files(files_deleted)
		)
	}
}

pub fn on_workspace_did_rename_files() {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.workspace_capabilities.file_operations.did_rename_supported
	{
		// TODO:
		files_renamed := FileRenameArray{}
		lsp.write_to(
			p.current_stdin,
			lsp.workspace_did_rename_files(files_renamed)
		)
	}
}

pub fn on_workspace_execute_command() {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.supports_workspace_capabilities
	{
		// TODO:
		command := ''
		args := ['']
		lsp.write_to(
			p.current_stdin,
			lsp.workspace_execute_command(command, args)
		)
	}
}

fn workspace_execute_command_response(json_message string) {
	// TODO:
	p.console_window.log('execute_command_response: $json_message', p.info_style_id)
}

pub fn on_workspace_symbol(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.workspace_symbol_provider
	{
		lsp.write_to(
			p.current_stdin,
			lsp.workspace_symbol(file_name)
		)
	}
}

fn workspace_symbol_response(json_message string) {
	p.console_window.log('symbol_response: $json_message', p.info_style_id)
	if json_message.starts_with('[') {
		sia := json2.decode<SymbolInformationArray>(json_message) or { SymbolInformationArray{} }
		for item in sia.items {
			p.console_window.log('  ${item.name} ${item.kind} ', p.info_style_id)
		}
	}
}

pub fn on_workspace_will_create_files() {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.workspace_capabilities.file_operations.will_create_supported
	{		
		// TODO:
		files_created := FileCreateArray{}
		lsp.write_to(
			p.current_stdin,
			lsp.workspace_will_create_files(files_created)
		)
	}
}

fn workspace_will_create_files_response(json_message string) {
	// TODO:
	p.console_window.log('will_create_files_response: $json_message', p.info_style_id)
}

pub fn on_workspace_will_delete_files() {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.workspace_capabilities.file_operations.will_delete_supported
	{
		// TODO:
		files_deleted := FileDeleteArray{}
		lsp.write_to(
			p.current_stdin,
			lsp.workspace_will_delete_files(files_deleted)
		)
	}
}

fn workspace_will_delete_files_response(json_message string) {
	// TODO:
	p.console_window.log('will_delete_files_response: $json_message', p.info_style_id)
}

pub fn on_workspace_will_rename_files() {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.workspace_capabilities.file_operations.will_rename_supported
	{
		// TODO:
		files_renamed := FileRenameArray{}
		lsp.write_to(
			p.current_stdin,
			lsp.workspace_will_rename_files(files_renamed)
		)
	}
}

fn workspace_will_rename_files_response(json_message string) {
	// TODO:
	p.console_window.log('will_rename_files_response: $json_message', p.info_style_id)
}

fn notification_handler(json_message JsonMessage) {
	match json_message.method {
		'textDocument/publishDiagnostics' { publish_diagnostics(json_message.params) }
		'window/showMessage' { log_message(json_message.params) }
		'window/logMessage' { log_message(json_message.params) }
		// TODO
		'$/cancelRequest' { decode_cancel_request_notification(json_message.params) }
		'$/progress' { decode_progress_notification(json_message.params) }
		'window/workDoneProgress/cancel' { decode_window_work_done_progress_cancel(json_message.params) }
		'telemetry/event' { decode_telemetry_event(json_message.params) }
		// 'workspace/didCreateFiles' { decode_workspace_did_create_files(json_message.params) }
		// 'workspace/didRenameFiles' { decode_workspace_did_rename_files(json_message.params) }
		// 'workspace/didDeleteFiles' { decode_workspace_did_delete_files(json_message.params) }
		else {
			p.console_window.log('An unexpected notification has been received, ${report_at}.', p.warning_style_id)
		}
	}
}

fn publish_diagnostics(params string) {
	diag := json2.decode<PublishDiagnosticsParams>(params) or { PublishDiagnosticsParams{} }
	p.editor.clear_diagnostics()
	p.diag_window.clear()
	for d in diag.diagnostics {
		// p.editor.add_diagnostics_info(d.range.start.line, d.message, d.severity)
		start := p.editor.position_from_line(d.range.start.line) + d.range.start.character
		end := p.editor.position_from_line(d.range.end.line) + d.range.end.character
		p.editor.add_diag_indicator(start, end-start, d.severity)
		p.diag_window.log('${diag.uri} [line:${d.range.start.line} col:${d.range.start.character}] - ${d.message}', byte(d.severity))
	}
}

fn log_message(json_message string) {
	smp := json2.decode<ShowMessageParams>(json_message) or { ShowMessageParams{} }
	p.console_window.log(smp.message, byte(smp.type_))
}

fn decode_cancel_request_notification(json_message string) {
	// TODO: once supported it needs some kind of stored requests container
	cp := json2.decode<CancelParams>(json_message) or { CancelParams{} }
	p.console_window.log('cancel_request_notification: ${cp.str()}', p.info_style_id)
}

fn decode_progress_notification(json_message string) {
	// TODO: is supposed to show any progress - how should this be implemented in Npp?
	pp := json2.decode<ProgressParams>(json_message) or { ProgressParams{} }
	p.console_window.log('progress_notification: ${pp.str()}', p.info_style_id)
}

fn decode_window_work_done_progress_cancel(json_message string) {
	// TODO: is supposed to end a progress widget(?).
	wdpcp := json2.decode<WorkDoneProgressCancelParams>(json_message) or { WorkDoneProgressCancelParams{} }
	p.console_window.log('window_work_done_progress_cancel: ${wdpcp.str()}', p.info_style_id)
}

fn decode_telemetry_event(json_message string) {
	// TODO: to quote from lsp specification
	// The protocol doesn’t specify the payload
	// since no interpretation of the data happens in the protocol. 
	// Most clients even don’t handle the event directly but forward 
	// them to the extensions owing the corresponding server issuing the event.
	// The open question is: how to forward ??
	p.console_window.log('telemetry_event: $json_message', p.info_style_id)
}

fn response_handler(json_message JsonMessage) {
	id := json_message.id
	if json_message.result != 'null' {
		func_ptr := p.open_response_messages[id]
		if func_ptr != voidptr(0) {
			func_ptr(json_message.result.str())
		} else {
			p.console_window.log('An unexpected response has been received, ${report_at}.', p.warning_style_id)
		}
	}
	p.open_response_messages.delete(id)
}

fn error_response_handler(json_message JsonMessage) {
	p.console_window.log('  !! ERROR RESPONSE !! received', p.error_style_id)
	p.open_response_messages.delete(json_message.id)
}

fn request_handler(json_message JsonMessage) {
	match json_message.method {
		'window/showMessageRequest' {
			smrp := json2.decode<ShowMessageRequestParams>(json_message.params) or { ShowMessageRequestParams{} }
			p.console_window.log('$smrp.message\n${smrp.actions.join("\n")}', byte(smrp.type_))
			send_null_response(json_message.id)
		}
		'window/showDocument' {
			sdp := json2.decode<ShowDocumentParams>(json_message.params) or { ShowDocumentParams{} }
			// TODO: need some examples
			p.console_window.log('window/showDocument\n $sdp', p.info_style_id)
			m := Message {
				msg_type: JsonRpcMessageType.response
				id: json_message.id
				response: '"result":{"success": false}'  // TODO: 
			}
			lsp.write_to(p.current_stdin, m.encode())
		}
		'client/registerCapability' {
			// TODO:
			//	{
			//		"id": "5fadd9c6-0c75-4499-9dac-19af07962e0f",
			//		"jsonrpc": "2.0",
			//		"method": "client/registerCapability",
			//		"params": {
			//			"registrations": [
			//				{
			//					"id": "profilegc.watchfiles",
			//					"method": "workspace/didChangeWatchedFiles",
			//					"registerOptions": {
			//						"watchers": [
			//							{
			//								"globPattern": "**/profilegc.log",
			//								"kind": null
			// 							}
			// 						]
			// 					}
			// 				}
			// 			]
			// 		}
			//	}

			rp := json2.decode<RegistrationParams>(json_message.params) or { RegistrationParams{} }
			p.console_window.log('registerCapability: ${rp}', p.info_style_id)
			send_null_response(json_message.id)	
		}
		'client/unregisterCapability' {
			// TODO: need some examples how this should work and what it is for.
			up := json2.decode<UnregistrationParams>(json_message.params) or { UnregistrationParams{} }
			p.console_window.log('unregisterCapability: ${up.str()}', p.info_style_id)
			send_null_response(json_message.id)	
		}
		'window/workDoneProgress/create' {
			// TODO: is supposed to inform that the progress widget(?) can be closed.
			wdpcp := json2.decode<WorkDoneProgressCreateParams>(json_message.params) or { WorkDoneProgressCreateParams{} }
			p.console_window.log('window_work_done_progress_create: ${wdpcp.str()}', p.info_style_id)
			send_null_response(json_message.id)
		}
		'workspace/workspaceFolders' {
			// TODO: once this is supported it needs to respond with WorkspaceFolder[] | null
			/*
				export interface WorkspaceFolder {
					// The associated URI for this workspace folder.
					uri: DocumentUri;

					// The name of the workspace folder. Used to refer to this
					// workspace folder in the user interface.
					name: string
				}			
			*/
			p.console_window.log('workspace/workspaceFolders', p.info_style_id)
			send_null_response(json_message.id)
		}
		'workspace/configuration' {
			// TODO: once this is supported it needs to respond with LSPAny[]
			/* example request
				{
					"id": "a7ea181c-28ef-4756-a771-3dcfc6c10cbc",
					"jsonrpc": "2.0",
					"method": "workspace/configuration",
					"params": {
						"items": [
							{"section": "d"},
							{"section": "dfmt"},
							{"section": "dscanner"},
							{"section": "editor"},
							{"section": "git"}
						]
					}
				}			
			*/
			p.console_window.log('workspace/configuration', p.info_style_id)
			cp := json2.decode<ConfigurationParams>(json_message.params) or { ConfigurationParams{} }
			responds := 'null,'.repeat(cp.items.len)  // TODO
			m := Message {
				msg_type: JsonRpcMessageType.response
				id: json_message.id
				response: '"result":[${responds[..responds.len-1]}]'  // TODO
			}
			lsp.write_to(p.current_stdin, m.encode())
		}
		'workspace/applyEdit' {
			m := Message {
				msg_type: JsonRpcMessageType.response
				id: json_message.id
				response: '"result":{"applied": false}'  // TODO: 
			}
			lsp.write_to(p.current_stdin, m.encode())
		}
		'workspace/codeLens/refresh' {
			send_null_response(json_message.id)
		}
		'workspace/semanticTokens/refresh' {
			send_null_response(json_message.id)
		}
		
		else {
			p.console_window.log('An unexpected request has been received, ${report_at}.', p.warning_style_id)
		}
	}
}

fn send_null_response(id string) {
	m := Message {
		msg_type: JsonRpcMessageType.response
		id: id
		response: '"result":null'
	}
	lsp.write_to(p.current_stdin, m.encode())
}
