module lsp
import x.json2
import os

const (
	content_length = 'Content-Length: '
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

pub fn on_init(npp_pid int, current_directory string) {
	p.console_window.log('on_init: $npp_pid', p.info_style_id)
	lsp.write_to(
		p.current_stdin, 
		lsp.initialize_msg(npp_pid, current_directory)
	)
}

pub fn on_file_opened(file_name string) {
	if file_name.len == 0 { return }
	lang_id := if p.current_language == 'vlang' { 'v' } else { p.current_language }
	p.console_window.log('on_file_opened:: $p.current_language: $file_name', p.info_style_id)
	p.console_window.log('on_file_opened: initialized=${p.lsp_config.lspservers[p.current_language].initialized}', p.info_style_id)
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.send_open_close_notif
   {
		content := editor.get_text()
		lsp.write_to(
			p.current_stdin,
			lsp.did_open(file_name, 0, lang_id, content)
		)
	}
}

pub fn on_file_before_saved(file_name string) {
	p.console_window.log('on_file_before_saved: $file_name', p.info_style_id)
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
	p.console_window.log('on_file_saved: $file_name', p.info_style_id)
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.send_save_notif
   {
		mut content := ''
		if p.lsp_config.lspservers[p.current_language].features.include_text_in_save_notif {
			content = editor.get_text()
		}
		lsp.write_to(
			p.current_stdin,
			lsp.did_save(file_name, content)
		)
	}
}
pub fn on_will_save_wait_until(file_name string) {
	// TODO: make this an lspclient configuration parameter?
	p.console_window.log('on_file_saved: $file_name', p.info_style_id)
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
	p.console_window.log('on_file_closed: $file_name', p.info_style_id)
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.send_open_close_notif
	{
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

		match p.lsp_config.lspservers[p.current_language].features.text_document_sync {
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
		// if text in p.lsp_config.lspservers[p.current_language].features.compl_trigger_chars {
		if text in p.lsp_config.lspservers[p.current_language].features.completion_provider.trigger_characters {
			lsp.write_to(
				p.current_stdin,
				lsp.request_completion(file_name, start_line, start_char_pos+1, text)  // ?? why +1
			)
		}
		// if text in p.lsp_config.lspservers[p.current_language].features.sig_help_trigger_chars {
		if text in p.lsp_config.lspservers[p.current_language].features.signature_help_provider.trigger_characters {
			lsp.write_to(
				p.current_stdin,
				lsp.request_signature_help(file_name, start_line, start_char_pos+1, text)
			)
		}
	}
}

pub fn on_format_document(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.document_formatting_provider
	{
		lsp.write_to(
			p.current_stdin,
			lsp.format_document(file_name, editor.get_tab_size(), editor.use_spaces(), true, true, true)
		)	
	}
}

pub fn on_format_selected_range(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.document_range_formatting_provider
	{
		start_line, end_line, start_char, end_char := editor.get_range_from_selection()
		lsp.write_to(
			p.current_stdin,
			lsp.format_selected_range(file_name, start_line, end_line, start_char, end_char, editor.get_tab_size(), editor.use_spaces(), true, true, true)
		)	
	}
}

pub fn on_goto_definition(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.definition_provider
	{
		current_line, char_pos := editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.goto_definition(file_name, current_line, char_pos)
		)	
	}
}

pub fn on_goto_implementation(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.implementation_provider
	{
		current_line, char_pos := editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.goto_implementation(file_name, current_line, char_pos)
		)	
	}
}

pub fn on_peek_definition(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.definition_provider
	{
		current_line, char_pos := editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.peek_definition(file_name, current_line, char_pos)
		)	
	}
}

pub fn on_peek_implementation(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.implementation_provider
	{
		current_line, char_pos := editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.peek_implementation(file_name, current_line, char_pos)
		)	
	}
}

pub fn on_goto_declaration(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.declaration_provider
	{
		current_line, char_pos := editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.goto_declaration(file_name, current_line, char_pos)
		)	
	}
}

pub fn on_find_references(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.references_provider
	{
		current_line, char_pos := editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.find_references(file_name, current_line, char_pos)
		)
	}
}

pub fn on_document_highlight(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.document_highlight_provider
	{
		current_line, char_pos := editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.document_highlight(file_name, current_line, char_pos)
		)
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

pub fn on_hover(file_name string) {
	// TODO: use dwellstart and dwellend events to call this method
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.hover_provider
	{
		current_line, char_pos := editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.hover(file_name, current_line, char_pos)
		)	
	}
}

pub fn on_rename(file_name string, new_name string) {
	// TODO: use dwellstart and dwellend events to call this method
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.rename_provider
	{
		current_line, char_pos := editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.rename(file_name, current_line, char_pos, new_name)
		)	
	}
}

pub fn on_prepare_rename(file_name string) {
	// TODO: how to use ??
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.rename_provider
	{
		current_line, char_pos := editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.prepare_rename(file_name, current_line, char_pos)
		)	
	}
}

pub fn on_folding_range(file_name string) {
	// TODO: how to use ??
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.folding_range_provider
	{
		lsp.write_to(
			p.current_stdin,
			lsp.folding_range(file_name)
		)	
	}
}

pub fn on_selection_range(file_name string) {
	// TODO: how to use ??
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.selection_range_provider
	{
		current_line, char_pos := editor.get_lsp_position_info()
		lsp.write_to(
			p.current_stdin,
			lsp.selection_range(file_name, current_line, char_pos)
		)	
	}
}

pub fn todo_on_cancel_request(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_cancel_request(file_name)
		)
	}
}

pub fn todo_on_log_trace(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_log_trace(file_name)
		)
	}
}

pub fn todo_on_progress(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_progress(file_name)
		)
	}
}

pub fn todo_on_set_trace(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_set_trace(file_name)
		)
	}
}

pub fn todo_on_incoming_calls(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_incoming_calls(file_name)
		)
	}
}

pub fn todo_on_outgoing_calls(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_outgoing_calls(file_name)
		)
	}
}

pub fn todo_on_register_capability(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_register_capability(file_name)
		)
	}
}

pub fn todo_on_unregister_capability(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_unregister_capability(file_name)
		)
	}
}

pub fn todo_on_code_action_resolve(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_code_action_resolve(file_name)
		)
	}
}

pub fn todo_on_code_lens_resolve(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_code_lens_resolve(file_name)
		)
	}
}

pub fn todo_on_completion_item_resolve(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_completion_item_resolve(file_name)
		)
	}
}

pub fn todo_on_document_link_resolve(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_document_link_resolve(file_name)
		)
	}
}

pub fn todo_on_telemetry_event(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_telemetry_event(file_name)
		)
	}
}

pub fn todo_on_code_action(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_code_action(file_name)
		)
	}
}

pub fn todo_on_code_lens(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_code_lens(file_name)
		)
	}
}

pub fn todo_on_color_presentation(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_color_presentation(file_name)
		)
	}
}

pub fn todo_on_document_color(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_document_color(file_name)
		)
	}
}

pub fn todo_on_document_link(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_document_link(file_name)
		)
	}
}

pub fn todo_on_linked_editing_range(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_linked_editing_range(file_name)
		)
	}
}

pub fn todo_on_moniker(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_moniker(file_name)
		)
	}
}

pub fn todo_on_on_type_formatting(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_on_type_formatting(file_name)
		)
	}
}

pub fn todo_on_prepare_call_hierarchy(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_prepare_call_hierarchy(file_name)
		)
	}
}

pub fn todo_on_semantic_tokens_full(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_semantic_tokens_full(file_name)
		)
	}
}

pub fn todo_on_semantic_tokens_delta(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_semantic_tokens_delta(file_name)
		)
	}
}

pub fn todo_on_semantic_tokens_range(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_semantic_tokens_range(file_name)
		)
	}
}

pub fn todo_on_type_definition(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_type_definition(file_name)
		)
	}
}

pub fn todo_on_work_done_progress_cancel(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_work_done_progress_cancel(file_name)
		)
	}
}

pub fn todo_on_work_done_progress_create(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_work_done_progress_create(file_name)
		)
	}
}

pub fn todo_on_workspace_apply_edit(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_apply_edit(file_name)
		)
	}
}

pub fn todo_on_workspace_code_lens_refresh(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_code_lens_refresh(file_name)
		)
	}
}

pub fn todo_on_workspace_configuration(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_configuration(file_name)
		)
	}
}

pub fn todo_on_workspace_did_change_configuration(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_did_change_configuration(file_name)
		)
	}
}

pub fn todo_on_workspace_did_change_watched_files(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_did_change_watched_files(file_name)
		)
	}
}

pub fn todo_on_workspace_did_change_workspace_folders(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_did_change_workspace_folders(file_name)
		)
	}
}

pub fn todo_on_workspace_did_create_files(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_did_create_files(file_name)
		)
	}
}

pub fn todo_on_workspace_did_delete_files(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_did_delete_files(file_name)
		)
	}
}

pub fn todo_on_workspace_did_rename_files(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_did_rename_files(file_name)
		)
	}
}

pub fn todo_on_workspace_execute_command(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_execute_command(file_name)
		)
	}
}

pub fn todo_on_workspace_sematic_tokens_refresh(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_sematic_tokens_refresh(file_name)
		)
	}
}

pub fn todo_on_workspace_symbol(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_symbol(file_name)
		)
	}
}

pub fn todo_on_workspace_will_create_files(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_will_create_files(file_name)
		)
	}
}

pub fn todo_on_workspace_will_delete_files(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_will_delete_files(file_name)
		)
	}
}

pub fn todo_on_workspace_will_rename_files(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_will_rename_files(file_name)
		)
	}
}

pub fn todo_on_workspace_folders(file_name string) {
	if p.lsp_config.lspservers[p.current_language].initialized &&
	   p.lsp_config.lspservers[p.current_language].features.fake
	{
		lsp.write_to(
			p.current_stdin,
			lsp.todo_workspace_folders(file_name)
		)
	}
}

fn notification_handler(json_message JsonMessage) {
	match json_message.method {
		'textDocument/publishDiagnostics' {
			publish_diagnostics(json_message.params)
		}
		'window/showMessage' {
			log_message(json_message.params)
		}
		'window/logMessage' {
			log_message(json_message.params)
		}
		else {
			p.console_window.log('  unhandled notification $json_message.method received', p.warning_style_id)
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
			p.console_window.log('  unexpected response received', p.warning_style_id)
		}
	}
	p.open_response_messages.delete(id)
}

fn error_response_handler(json_message JsonMessage) {
	p.console_window.log('  !! ERROR RESPONSE !! received', p.error_style_id)
	p.open_response_messages.delete(json_message.id.int())
}

fn request_handler(json_message JsonMessage) {
	match json_message.method {
		'window/showMessageRequest' {
			smrp := json2.decode<ShowMessageRequestParams>(json_message.params) or { ShowMessageRequestParams{} }
			p.console_window.log('$smrp.message\n${smrp.actions.join("\n")}', byte(smrp.type_))
			m := Message {
				msg_type: JsonRpcMessageType.response
				id: json_message.id.int()
				response: '"result":null'
			}
			lsp.write_to(p.current_stdin, m.encode())
		}
		'window/showDocument' {
			sdp := json2.decode<ShowDocumentParams>(json_message.params) or { ShowDocumentParams{} }
			// TODO: need some examples
			p.console_window.log('window/showDocument\n $sdp', p.info_style_id)
			m := Message {
				msg_type: JsonRpcMessageType.response
				id: json_message.id.int()
				response: '"result":{"success": false}'  // TODO: 
			}
			lsp.write_to(p.current_stdin, m.encode())

		}
		else {
			p.console_window.log('  unhandled request received', p.warning_style_id)
		}
	}
}

fn publish_diagnostics(params string) {
	diag := json2.decode<PublishDiagnosticsParams>(params) or { PublishDiagnosticsParams{} }
	editor.clear_diagnostics()
	for d in diag.diagnostics {
		// editor.add_diagnostics_info(d.range.start.line, d.message, d.severity)
		start := editor.position_from_line(d.range.start.line) + d.range.start.character
		end := editor.position_from_line(d.range.end.line) + d.range.end.character
		editor.add_diag_indicator(start, end-start, d.severity)
		p.console_window.log('${diag.uri}\n\tline:${d.range.start.line} - ${d.message}', byte(d.severity))
	}
}

fn initialize_msg_response(json_message string) {
	result := json2.raw_decode(json_message) or { '' }
	result_map := result.as_map()
	if 'capabilities' in result_map {
		capabilities := result_map['capabilities'] or { '' }
		sc := json2.decode<ServerCapabilities>(capabilities.str()) or { ServerCapabilities{} }
		p.console_window.log('    initialized response received', p.info_style_id)

		p.lsp_config.lspservers[p.current_language].features = sc
		// p.lsp_config.lspservers[p.current_language].features.text_document_sync = sc.text_document_sync
		// p.lsp_config.lspservers[p.current_language].features.send_open_close_notif = sc.send_open_close_notif
		// p.lsp_config.lspservers[p.current_language].features.send_save_notif = sc.send_save_notif
		// p.lsp_config.lspservers[p.current_language].features.include_text_in_save_notif = sc.include_text_in_save_notif
		// p.lsp_config.lspservers[p.current_language].features.compl_trigger_chars = sc.completion_provider.trigger_characters
		// p.lsp_config.lspservers[p.current_language].features.sig_help_trigger_chars = sc.signature_help_provider.trigger_characters
		// p.lsp_config.lspservers[p.current_language].features.sig_help_retrigger_chars = sc.signature_help_provider.retrigger_characters
		// p.lsp_config.lspservers[p.current_language].features.definition_provider = sc.definition_provider
		// p.lsp_config.lspservers[p.current_language].features.implementation_provider = sc.implementation_provider
		// p.lsp_config.lspservers[p.current_language].features.document_formatting_provider = sc.document_formatting_provider
		// p.lsp_config.lspservers[p.current_language].features.document_range_formatting_provider = sc.document_range_formatting_provider
		// p.lsp_config.lspservers[p.current_language].features.declaration_provider = sc.declaration_provider
		// p.lsp_config.lspservers[p.current_language].features.references_provider = sc.references_provider
		// p.lsp_config.lspservers[p.current_language].features.document_highlight_provider = sc.document_highlight_provider
		// p.lsp_config.lspservers[p.current_language].features.document_symbol_provider = sc.document_symbol_provider
		// p.lsp_config.lspservers[p.current_language].features.supports_will_save = sc.supports_will_save
		// p.lsp_config.lspservers[p.current_language].features.supports_will_save_wait_until = sc.supports_will_save_wait_until
		// p.lsp_config.lspservers[p.current_language].features.hover_provider = sc.hover_provider
		// p.lsp_config.lspservers[p.current_language].features.rename_provider = sc.rename_provider
		// p.lsp_config.lspservers[p.current_language].features.folding_range_provider = sc.folding_range_provider
		// p.lsp_config.lspservers[p.current_language].features.selection_range_provider = sc.selection_range_provider
		
		
		// lsp.ServerCapabilities{
			// type_definition_provider: true
			// code_action_provider: true
			// code_lens_provider: lsp.CodeLensOptions{
				// resolve_provider: false
			// }
			// document_link_provider: false
			// color_provider: false
			// document_on_type_formatting_provider: lsp.DocumentOnTypeFormattingOptions{
				// first_trigger_character: ''
				// more_trigger_character: []
			// }
			// execute_command_provider: '{"commands":["gopls.add_dependency","gopls.add_import","gopls.apply_fix","gopls.check_upgrades","gopls.gc_details","gopls.generate","gopls.generate_gopls_mod","gopls.go_get_package","gopls.list_known_packages","gopls.regenerate_cgo","gopls.remove_dependency","gopls.run_tests","gopls.start_debugging","gopls.test","gopls.tidy","gopls.toggle_gc_details","gopls.update_go_sum","gopls.upgrade_dependency","gopls.vendor","gopls.workspace_metadata"]}'
			// linked_editing_range_provider: false
			// call_hierarchy_provider: true
			// semantic_tokens_provider: false
			// moniker_provider: false
			// experimental: {}
			// workspace_symbol_provider: true
			// workspace_capabilities: lsp.WorkspaceCapabilities{
				// workspace_folders: lsp.WorkspaceFoldersServerCapabilities{
					// supported: true
					// change_notifications: 'workspace/didChangeWorkspaceFolders'
				// }
				// file_operations: lsp.FileOperation{
					// did_create: lsp.FileOperationRegistrationOptions{
						// filters: []
					// }
					// will_create: lsp.FileOperationRegistrationOptions{
						// filters: []
					// }
					// did_rename: lsp.FileOperationRegistrationOptions{
						// filters: []
					// }
					// will_rename: lsp.FileOperationRegistrationOptions{
						// filters: []
					// }
					// did_delete: lsp.FileOperationRegistrationOptions{
						// filters: []
					// }
					// will_delete: lsp.FileOperationRegistrationOptions{
						// filters: []
					// }
				// }
			// }
		// }		
		
		
		
		
		lsp.write_to(
			p.current_stdin,
			lsp.initialized_msg()
		)

		p.lsp_config.lspservers[p.current_language].initialized = true
		current_file := npp.get_current_filename()
		on_file_opened(current_file)
	} else {
		p.console_window.log('  unexpected initialize response received', p.error_style_id)
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

fn signature_help_response(json_message string) {
	p.console_window.log('  signature help response received: $json_message', p.info_style_id)
	sh := json2.decode<SignatureHelp>(json_message) or { SignatureHelp{} }
	if sh.signatures.len > 0 {
		editor.display_signature_hints(sh.signatures[0].label)
	}
	p.console_window.log('$sh', p.info_style_id)
}

fn format_document_response(json_message string) {
	p.console_window.log('  format document response received: $json_message', p.info_style_id)
	tea := json2.decode<TextEditArray>(json_message) or { TextEditArray{} }
	editor.begin_undo_action()
	for item in tea.items {
		start_pos := u32(editor.position_from_line(item.range.start.line)) + item.range.start.character
		end_pos := u32(editor.position_from_line(item.range.end.line)) + item.range.end.character
		editor.replace_target(start_pos, end_pos, item.new_text)
	}
	editor.end_undo_action()
}

fn goto_location_helper(json_message string) {
	mut start_pos := u32(0)
	if json_message.starts_with('[') {
		if json_message.contains('originSelectionRange') {
			lla := json2.decode<LocationLinkArray>(json_message) or { LocationLinkArray{} }
			if lla.items.len > 0 {
				npp.open_document(lla.items[0].target_uri)
				start_pos = u32(editor.position_from_line(lla.items[0].target_range.start.line))
				start_pos += lla.items[0].target_range.start.character
			}
		} else {
			loca := json2.decode<LocationArray>(json_message) or { LocationArray{} }
			if loca.items.len > 0 {

				npp.open_document(loca.items[0].uri)
				start_pos = u32(editor.position_from_line(loca.items[0].range.start.line))
				start_pos += loca.items[0].range.start.character
			}
		}
	} else {
		loc := json2.decode<Location>(json_message) or { Location{} }
		npp.open_document(loc.uri)
		start_pos = u32(editor.position_from_line(loc.range.start.line))
		start_pos += loc.range.start.character
	}
	editor.goto_pos(start_pos)	
}

fn goto_definition_response(json_message string) {
	p.console_window.log('goto definition response received: $json_message', p.info_style_id)
	goto_location_helper(json_message)
}

fn goto_implementation_response(json_message string) {
	p.console_window.log('goto implementation response received: $json_message', p.info_style_id)
	goto_location_helper(json_message)
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
				editor.show_peeked_info(peeked_code)
			}
		}
	}	
}

fn peek_definition_response(json_message string) {
	p.console_window.log('peek definition response received: $json_message', p.info_style_id)
	peek_helper(json_message)
}

fn peek_implementation_response(json_message string) {
	p.console_window.log('peek implementation response received: $json_message', p.info_style_id)
	peek_helper(json_message)
}

fn log_message(json_message string) {
	smp := json2.decode<ShowMessageParams>(json_message) or { ShowMessageParams{} }
	p.console_window.log(smp.message, byte(smp.type_))
}

fn goto_declaration_response(json_message string) {
	p.console_window.log('declaration response received: $json_message', p.info_style_id)
	goto_location_helper(json_message)
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

fn document_symbols_response(json_message string) {
	p.console_window.log('document symbols response received: $json_message', p.info_style_id)
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

fn hover_response(json_message string) {
	p.console_window.log('hover response received: $json_message', p.info_style_id)
	// TODO: contents: MarkedString | MarkedString[] | MarkupContent;
	if json_message.contains('contents') {
		//
	}
}

fn rename_response(json_message string) {
	p.console_window.log('rename response received: $json_message', p.info_style_id)
	// TODO

}

fn prepare_rename_response(json_message string) {
	p.console_window.log('prepare rename response received: $json_message', p.info_style_id)
	// TODO

}

fn folding_range_response(json_message string) {
	p.console_window.log('folding range response received: $json_message', p.info_style_id)
	// TODO

}

fn selection_range_response(json_message string) {
	p.console_window.log('selection range response received: $json_message', p.info_style_id)
	// TODO

}



fn todo_cancel_request_response(json_message string) {
	p.console_window.log('cancel_request_response: $json_message', p.info_style_id)
}

fn todo_log_trace_response(json_message string) {
	p.console_window.log('log_trace_response: $json_message', p.info_style_id)
}

fn todo_progress_response(json_message string) {
	p.console_window.log('progress_response: $json_message', p.info_style_id)
}

fn todo_set_trace_response(json_message string) {
	p.console_window.log('set_trace_response: $json_message', p.info_style_id)
}

fn todo_incoming_calls_response(json_message string) {
	p.console_window.log('incoming_calls_response: $json_message', p.info_style_id)
}

fn todo_outgoing_calls_response(json_message string) {
	p.console_window.log('outgoing_calls_response: $json_message', p.info_style_id)
}

fn todo_register_capability_response(json_message string) {
	p.console_window.log('register_capability_response: $json_message', p.info_style_id)
}

fn todo_unregister_capability_response(json_message string) {
	p.console_window.log('unregister_capability_response: $json_message', p.info_style_id)
}

fn todo_code_action_resolve_response(json_message string) {
	p.console_window.log('resolve_response: $json_message', p.info_style_id)
}

fn todo_code_lens_resolve_response(json_message string) {
	p.console_window.log('resolve_response: $json_message', p.info_style_id)
}

fn todo_completion_item_resolve_response(json_message string) {
	p.console_window.log('resolve_response: $json_message', p.info_style_id)
}

fn todo_document_link_resolve_response(json_message string) {
	p.console_window.log('resolve_response: $json_message', p.info_style_id)
}

fn todo_telemetry_event_response(json_message string) {
	p.console_window.log('event_response: $json_message', p.info_style_id)
}

fn todo_code_action_response(json_message string) {
	p.console_window.log('code_action_response: $json_message', p.info_style_id)
}

fn todo_code_lens_response(json_message string) {
	p.console_window.log('code_lens_response: $json_message', p.info_style_id)
}

fn todo_color_presentation_response(json_message string) {
	p.console_window.log('color_presentation_response: $json_message', p.info_style_id)
}

fn todo_document_color_response(json_message string) {
	p.console_window.log('document_color_response: $json_message', p.info_style_id)
}

fn todo_document_link_response(json_message string) {
	p.console_window.log('document_link_response: $json_message', p.info_style_id)
}

fn todo_linked_editing_range_response(json_message string) {
	p.console_window.log('linked_editing_range_response: $json_message', p.info_style_id)
}

fn todo_moniker_response(json_message string) {
	p.console_window.log('moniker_response: $json_message', p.info_style_id)
}

fn todo_on_type_formatting_response(json_message string) {
	p.console_window.log('on_type_formatting_response: $json_message', p.info_style_id)
}

fn todo_prepare_call_hierarchy_response(json_message string) {
	p.console_window.log('prepare_call_hierarchy_response: $json_message', p.info_style_id)
}

fn todo_semantic_tokens_full_response(json_message string) {
	p.console_window.log('full_response: $json_message', p.info_style_id)
}

fn todo_semantic_tokens_delta_response(json_message string) {
	p.console_window.log('delta_response: $json_message', p.info_style_id)
}

fn todo_semantic_tokens_range_response(json_message string) {
	p.console_window.log('range_response: $json_message', p.info_style_id)
}

fn todo_type_definition_response(json_message string) {
	p.console_window.log('type_definition_response: $json_message', p.info_style_id)
}

fn todo_work_done_progress_cancel_response(json_message string) {
	p.console_window.log('cancel_response: $json_message', p.info_style_id)
}

fn todo_work_done_progress_create_response(json_message string) {
	p.console_window.log('create_response: $json_message', p.info_style_id)
}

fn todo_workspace_apply_edit_response(json_message string) {
	p.console_window.log('apply_edit_response: $json_message', p.info_style_id)
}

fn todo_workspace_code_lens_refresh_response(json_message string) {
	p.console_window.log('refresh_response: $json_message', p.info_style_id)
}

fn todo_workspace_configuration_response(json_message string) {
	p.console_window.log('configuration_response: $json_message', p.info_style_id)
}

fn todo_workspace_did_change_configuration_response(json_message string) {
	p.console_window.log('did_change_configuration_response: $json_message', p.info_style_id)
}

fn todo_workspace_did_change_watched_files_response(json_message string) {
	p.console_window.log('did_change_watched_files_response: $json_message', p.info_style_id)
}

fn todo_workspace_did_change_workspace_folders_response(json_message string) {
	p.console_window.log('did_change_workspace_folders_response: $json_message', p.info_style_id)
}

fn todo_workspace_did_create_files_response(json_message string) {
	p.console_window.log('did_create_files_response: $json_message', p.info_style_id)
}

fn todo_workspace_did_delete_files_response(json_message string) {
	p.console_window.log('did_delete_files_response: $json_message', p.info_style_id)
}

fn todo_workspace_did_rename_files_response(json_message string) {
	p.console_window.log('did_rename_files_response: $json_message', p.info_style_id)
}

fn todo_workspace_execute_command_response(json_message string) {
	p.console_window.log('execute_command_response: $json_message', p.info_style_id)
}

fn todo_workspace_sematic_tokens_refresh_response(json_message string) {
	p.console_window.log('refresh_response: $json_message', p.info_style_id)
}

fn todo_workspace_symbol_response(json_message string) {
	p.console_window.log('symbol_response: $json_message', p.info_style_id)
}

fn todo_workspace_will_create_files_response(json_message string) {
	p.console_window.log('will_create_files_response: $json_message', p.info_style_id)
}

fn todo_workspace_will_delete_files_response(json_message string) {
	p.console_window.log('will_delete_files_response: $json_message', p.info_style_id)
}

fn todo_workspace_will_rename_files_response(json_message string) {
	p.console_window.log('will_rename_files_response: $json_message', p.info_style_id)
}

fn todo_workspace_folders_response(json_message string) {
	p.console_window.log('workspace_folders_response: $json_message', p.info_style_id)
}