module lsp
import x.json2

enum JsonRpcMessageType {
	response
	notification
	request
	shutdown
	exit
}

// used for encoding json messages
struct Message {
	msg_type JsonRpcMessageType
	method string
	id int
	params string
	response string
}

fn (m Message) encode() string {
	body := match m.msg_type {
		.request {
			'{"jsonrpc":"2.0","id":$m.id,"method":$m.method,"params":$m.params}'
		}
		.response {
			'{"jsonrpc":"2.0","id":$m.id,$m.response}'	//m.response is either result or an error object
		}
		.notification {
			'{"jsonrpc":"2.0","method":$m.method,"params":$m.params}'
		}
		.shutdown {
			'{"jsonrpc":"2.0","id":$m.id,"method":$m.method}'
		}
		.exit {
			'{"jsonrpc":"2.0","method":$m.method}'
		}
	}
	return 'Content-Length: ${body.len}\r\n\r\n${body}'
}

pub fn initialize(pid int, file_path string) string {
	uri_path := make_uri(file_path)
	client_info := '"clientInfo":{"name":"NppLspClient","version":"0.0.1"}'
	initialization_options:='"initializationOptions":{}'
	capabilities:='"capabilities":{
		"workspace":{
			"applyEdit":false,
			"workspaceEdit":{"documentChanges":false},
			"didChangeConfiguration":{"dynamicRegistration":false},
			"didChangeWatchedFiles":{"dynamicRegistration":false},
			"symbol":{
				"dynamicRegistration":false,
				"symbolKind":{
					"valueSet":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26]
				}
			},
			"executeCommand":{"dynamicRegistration":false},
			"configuration":false,
			"workspaceFolders":false
		},
		"textDocument":{
			"publishDiagnostics":{"relatedInformation":false},
			"synchronization":{
				"dynamicRegistration":false,
				"willSave":false,
				"willSaveWaitUntil":false,
				"didSave":true
			},
			"completion":{
				"dynamicRegistration":false,
				"contextSupport":false,
				"completionItem":{
					"snippetSupport":false,
					"commitCharactersSupport":false,
					"documentationFormat":["plaintext"],
					"deprecatedSupport":false
				},
				"completionItemKind":{
					"valueSet":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25]
				}
			},
			"hover":{
				"dynamicRegistration":false,
				"contentFormat":["plaintext"]
			},
			"signatureHelp":{
				"dynamicRegistration":false,
				"signatureInformation":{"documentationFormat":["plaintext"]}
			},
			"definition":{"dynamicRegistration":false},
			"references":{"dynamicRegistration":false},
			"documentHighlight":{"dynamicRegistration":false},
			"documentSymbol":{
				"dynamicRegistration":false,
				"symbolKind":{"valueSet":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26]}
			},
			"codeAction":{"dynamicRegistration":false},
			"codeLens":{"dynamicRegistration":false},
			"formatting":{"dynamicRegistration":false},
			"rangeFormatting":{"dynamicRegistration":false},
			"onTypeFormatting":{"dynamicRegistration":false},
			"rename":{"dynamicRegistration":false},
			"documentLink":{"dynamicRegistration":false},
			"typeDefinition":{"dynamicRegistration":false},
			"implementation":{"dynamicRegistration":false},
			"colorProvider":{"dynamicRegistration":false},
			"foldingRange":{
				"dynamicRegistration":false,
				"rangeLimit":100,
				"lineFoldingOnly":true
			}
		}
	}'.replace_each(['\t','','\n','','\r',''])
	trace := '"trace":"off"'
	workspace_folders := '"workspaceFolders":null'
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"initialize"'
		params: '{"processId":$pid,$client_info,"rootUri":"file:///$uri_path",$initialization_options,$capabilities,$trace,$workspace_folders}'
	}
	p.open_response_messages[m.id] = initialize_response
	return m.encode()
}

pub fn initialized() string {
	m := Message {
		msg_type: JsonRpcMessageType.notification
		method: '"initialized"'
		params: '{}'
	}
	return m.encode()
}

pub fn exit_msg() string {
	m := Message {
		msg_type: JsonRpcMessageType.exit
		method: '"exit"'
	}
	return m.encode()	
}

pub fn shutdown_msg() string {
	m := Message {
		msg_type: JsonRpcMessageType.shutdown
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"shutdown"'
	}
	p.lsp_config.lspservers[p.current_language].message_id_counter++
	return m.encode()	
}

pub fn did_open(file_path DocumentUri, file_version u32, language_id string, content string) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/didOpen"'
		params: '{"textDocument":{"uri":"file:///$uri_path","languageId":"$language_id","version":$file_version,"text":"$content"}}'
	}
	return m.encode()
}

pub fn did_change_incremental(file_path DocumentUri, 
							  file_version u32, 
							  text_changes string, 
							  start_line u32, 
							  start_char u32, 
							  end_line u32, 
							  end_char u32) string {
	uri_path := make_uri(file_path)
	changes := '{"range":{"start":{"line":$start_line,"character":$start_char},"end":{"line":$end_line,"character":$end_char}},"rangeLength":0,"text":"$text_changes"}'

	m := Message {
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/didChange"'
		params: '{"textDocument":{"uri":"file:///$uri_path","version":$file_version},"contentChanges":[$changes]}'
	}	
	return m.encode()
}

pub fn did_change_full(file_path DocumentUri, file_version u32, changes string) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/didChange"'
		params: '{"textDocument":{"uri":"file:///$uri_path","version":$file_version},"contentChanges":[$changes]}'
	}	
	return m.encode()
}

pub fn will_save(file_path DocumentUri) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/willSave"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},"reason":1'
	}	
	return m.encode()
}

pub fn will_save_wait_until(file_path DocumentUri, reason int) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/willSaveWaitUntil"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},"reason":$reason'
	}	
	return m.encode()
}

pub fn did_save(file_path DocumentUri, content string) string {
	uri_path := make_uri(file_path)
	params__ := if content.len == 0 {
		'{"textDocument":{"uri":"file:///$uri_path"}}'
	} else {
		'{"textDocument":{"uri":"file:///$uri_path","text":$content}}'
	}
	m := Message {
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/didSave"'
		params: params__
	}
	return m.encode()
}

pub fn did_close(file_path DocumentUri) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/didClose"'
		params: '{"textDocument":{"uri":"file:///$uri_path"}}'
	}
	return m.encode()
}

pub fn request_completion(file_path DocumentUri, line u32, char_pos u32, trigger_character string) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/completion"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},"position":{"line":$line,"character":$char_pos},"context":{"triggerKind":1,"triggerCharacter":"$trigger_character"}}'
	}
	p.open_response_messages[m.id] = completion_response
	return m.encode()
}

pub fn request_signature_help(file_path DocumentUri, line u32, char_pos u32, trigger_character string) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/signatureHelp"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},"position":{"line":$line,"character":$char_pos},"context":{"isRetrigger":false,"triggerCharacter":"$trigger_character","triggerKind":2}}'
	}
	p.open_response_messages[m.id] = signature_help_response
	return m.encode()
}

pub fn format_document(file_path DocumentUri, 
					   tab_size u32,
					   insert_spaces bool,
					   trim_trailing_whitespace bool,
					   insert_final_new_line bool,
					   trim_final_new_lines bool) string {

	text_document := '"textDocument":{"uri":"file:///${make_uri(file_path)}"}'
	options := '"options":{"insertSpaces":$insert_spaces,"tabSize":$tab_size,"trimTrailingWhitespace":$trim_trailing_whitespace,"insertFinalNewline":$insert_final_new_line,"trimFinalNewlines":$trim_final_new_lines}'
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/formatting"'
		params: '{$text_document,$options}'
	}
	p.open_response_messages[m.id] = format_document_response
	return m.encode()
}

pub fn format_selected_range(file_path DocumentUri,
							 start_line u32, 
							 start_char u32, 
							 end_line u32, 
							 end_char u32,
							 tab_size u32,
							 insert_spaces bool,
							 trim_trailing_whitespace bool,
							 insert_final_new_line bool,
							 trim_final_new_lines bool) string {

	text_document := '"textDocument":{"uri":"file:///${make_uri(file_path)}"}'
	range := '"range":{"start":{"line":$start_line,"character":$start_char},"end":{"line":$end_line,"character":$end_char}'
	options := '"options":{"insertSpaces":$insert_spaces,"tabSize":$tab_size,"trimTrailingWhitespace":$trim_trailing_whitespace,"insertFinalNewline":$insert_final_new_line,"trimFinalNewlines":$trim_final_new_lines}'
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/formatting"'
		params: '{$text_document,$range,$options}'
	}
	p.open_response_messages[m.id] = format_document_response
	return m.encode()
}

pub fn goto_definition(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/definition"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.open_response_messages[m.id] = goto_definition_response
	return m.encode()
}

pub fn peek_definition(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/definition"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.open_response_messages[m.id] = peek_definition_response
	return m.encode()
}

pub fn goto_implementation(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/implementation"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.open_response_messages[m.id] = goto_implementation_response
	return m.encode()
}

pub fn peek_implementation(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/implementation"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.open_response_messages[m.id] = peek_implementation_response
	return m.encode()
}

pub fn goto_declaration(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/declaration"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.open_response_messages[m.id] = goto_declaration_response
	return m.encode()
}

pub fn find_references(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/references"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.open_response_messages[m.id] = find_references_response
	return m.encode()
}

pub fn document_highlight(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/documentHighlight"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.open_response_messages[m.id] = document_highlight_response
	return m.encode()
}

pub fn document_symbols(file_path DocumentUri) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/documentSymbol"'
		params: '{"textDocument":{"uri":"file:///$uri_path"}}'
	}
	p.open_response_messages[m.id] = document_symbols_response
	return m.encode()
}

pub fn hover(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/hover"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.open_response_messages[m.id] = hover_response
	return m.encode()
}

pub fn rename(file_path DocumentUri, line u32, char_position u32, replacement string) string {
	uri_path := make_uri(file_path)
	position := '"position":{"character":$char_position,"line":$line}'
	new_name := '"newName":$replacement'
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/rename"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},$position,$new_name}'
	}
	p.open_response_messages[m.id] = rename_response
	return m.encode()
}

pub fn prepare_rename(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	position := '"position":{"character":$char_position,"line":$line}'
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/prepareRename"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},$position}'
	}
	p.open_response_messages[m.id] = prepare_rename_response
	return m.encode()
}

pub fn folding_range(file_path DocumentUri) string {
	uri_path := make_uri(file_path)
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/prepareRename"'
		params: '{"textDocument":{"uri":"file:///$uri_path"}}'
	}
	p.open_response_messages[m.id] = folding_range_response
	return m.encode()
}

pub fn selection_range(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	position := '"position":{"character":$char_position,"line":$line}'

	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/selectionRange"'
		params: '{"textDocument":{"uri":"file:///$uri_path"},$position}'
	}
	p.open_response_messages[m.id] = selection_range_response
	return m.encode()
}

pub fn cancel_request(request_id int) string {
	m := Message {
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"$/cancelRequest"'
		params: '{"id":$request_id}'
	}
	return m.encode()
}

pub fn progress(token int, value string) string {
	m := Message {
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"$/progress"'
		params: '{"token":$token,"value":"$value"}'
	}
	return m.encode()
}

pub fn set_trace(trace_value string) string {
	m := Message {
		msg_type: JsonRpcMessageType.notification
		method: '"$/setTrace"'
		params: '{"value":"$trace_value"}'
	}
	return m.encode()
}

pub fn todo_incoming_calls(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"callHierarchy/incomingCalls"'
		params: '{"workDoneToken":{"token":"","value":null},}'
	}
	p.open_response_messages[m.id] = incoming_calls_response
	return m.encode()
}

pub fn todo_outgoing_calls(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"callHierarchy/outgoingCalls"'
		params: '{}'
	}
	p.open_response_messages[m.id] = outgoing_calls_response
	return m.encode()
}

pub fn todo_code_action_resolve(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"codeAction/resolve"'
		params: '{}'
	}
	p.open_response_messages[m.id] = code_action_resolve_response
	return m.encode()
}

pub fn todo_code_lens_resolve(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"codeLens/resolve"'
		params: '{}'
	}
	p.open_response_messages[m.id] = code_lens_resolve_response
	return m.encode()
}

pub fn todo_completion_item_resolve(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"completionItem/resolve"'
		params: '{}'
	}
	p.open_response_messages[m.id] = completion_item_resolve_response
	return m.encode()
}

pub fn todo_document_link_resolve(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"documentLink/resolve"'
		params: '{}'
	}
	p.open_response_messages[m.id] = document_link_resolve_response
	return m.encode()
}

pub fn todo_code_action(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/codeAction"'
		params: '{}'
	}
	p.open_response_messages[m.id] = code_action_response
	return m.encode()
}

pub fn todo_code_lens(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/codeLens"'
		params: '{}'
	}
	p.open_response_messages[m.id] = code_lens_response
	return m.encode()
}

pub fn todo_color_presentation(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/colorPresentation"'
		params: '{}'
	}
	p.open_response_messages[m.id] = color_presentation_response
	return m.encode()
}

pub fn todo_document_color(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/documentColor"'
		params: '{}'
	}
	p.open_response_messages[m.id] = document_color_response
	return m.encode()
}

pub fn todo_document_link(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/documentLink"'
		params: '{}'
	}
	p.open_response_messages[m.id] = document_link_response
	return m.encode()
}

pub fn todo_linked_editing_range(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/linkedEditingRange"'
		params: '{}'
	}
	p.open_response_messages[m.id] = linked_editing_range_response
	return m.encode()
}

pub fn todo_moniker(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/moniker"'
		params: '{}'
	}
	p.open_response_messages[m.id] = moniker_response
	return m.encode()
}

pub fn todo_on_type_formatting(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/onTypeFormatting"'
		params: '{}'
	}
	p.open_response_messages[m.id] = on_type_formatting_response
	return m.encode()
}

pub fn todo_prepare_call_hierarchy(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/prepareCallHierarchy"'
		params: '{}'
	}
	p.open_response_messages[m.id] = prepare_call_hierarchy_response
	return m.encode()
}

pub fn todo_semantic_tokens_full(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/semanticTokens/full"'
		params: '{}'
	}
	p.open_response_messages[m.id] = semantic_tokens_full_response
	return m.encode()
}

pub fn todo_semantic_tokens_delta(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/semanticTokens/full/delta"'
		params: '{}'
	}
	p.open_response_messages[m.id] = semantic_tokens_delta_response
	return m.encode()
}

pub fn todo_semantic_tokens_range(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/semanticTokens/range"'
		params: '{}'
	}
	p.open_response_messages[m.id] = semantic_tokens_range_response
	return m.encode()
}

pub fn todo_type_definition(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/typeDefinition"'
		params: '{}'
	}
	p.open_response_messages[m.id] = type_definition_response
	return m.encode()
}

pub fn todo_work_done_progress_cancel(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"window/workDoneProgress/cancel"'
		params: '{}'
	}
	return m.encode()
}

pub fn todo_workspace_did_change_workspace_folders(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/didChangeWorkspaceFolders"'
		params: '{}'
	}
	return m.encode()
}
pub fn todo_workspace_did_change_configuration(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace.didChangeConfiguration"'
		params: '{}'
	}
	return m.encode()
}

pub fn todo_workspace_did_change_watched_files(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace.didChangeWatchedFiles"'
		params: '{}'
	}
	return m.encode()
}
		
pub fn todo_workspace_did_rename_files(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/didRenameFiles"'
		params: '{}'
	}
	return m.encode()
}
		
pub fn todo_workspace_did_create_files(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/didCreateFiles"'
		params: '{}'
	}
	return m.encode()
}		
pub fn todo_workspace_did_delete_files(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/didDeleteFiles"'
		params: '{}'
	}
	return m.encode()
}
pub fn todo_workspace_execute_command(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/executeCommand"'
		params: '{}'
	}
	p.open_response_messages[m.id] = workspace_execute_command_response
	return m.encode()
}

pub fn todo_workspace_symbol(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/symbol"'
		params: '{}'
	}
	p.open_response_messages[m.id] = workspace_symbol_response
	return m.encode()
}

pub fn todo_workspace_will_create_files(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/willCreateFiles"'
		params: '{}'
	}
	p.open_response_messages[m.id] = workspace_will_create_files_response
	return m.encode()
}

pub fn todo_workspace_will_delete_files(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/willDeleteFiles"'
		params: '{}'
	}
	p.open_response_messages[m.id] = workspace_will_delete_files_response
	return m.encode()
}

pub fn todo_workspace_will_rename_files(file_path DocumentUri) string {
	m := Message {
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/willRenameFiles"'
		params: '{}'
	}
	p.open_response_messages[m.id] = workspace_will_rename_files_response
	return m.encode()
}


//////***********************************************************************
// JSON Structures
//////***********************************************************************

// pub fn (mut xx XXX) from_json(f json2.Any) {
	// obj := f.as_map()
	// for k, v in obj {
		// match k {
			// else {}
		// }
	// }
// }


// used for decoding
struct JsonMessage {
pub mut:
	jsonrpc string	// all
	method string	// request and notification
	id string		// request and response
	params string	// request and notification
	result string	// response
	error string	// response
}

pub fn (mut m JsonMessage) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'jsonrpc' { m.jsonrpc =	 v.str() }
			'method' { m.method = v.str() }
			'id' { m.id = v.str() }
			'params' { m.params = v.str() }
			'result' { m.result = v.str() }
			'error' { m.error = v.str() }
			else {}
		}
	}
}

type DocumentUri = string

pub fn make_path(uri string) string {
	return uri.all_after('file:///').replace_each(['/', '\\', '%3A', ':'])
}

pub fn make_uri(path string) string {
	return path.replace_each(['\\', '/', ':', '%3A'])
}

pub struct TextDocumentIdentifier {
pub mut:
	uri DocumentUri
}

pub fn (mut tdi TextDocumentIdentifier) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'uri' { tdi.uri = v.str() }
			else {}
		}
	}
}

pub struct Position {
pub mut:
	line	  u32
	character u32
}

pub fn (mut p Position) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'line' { p.line = u32(v.int()) }
			'character' { p.character = u32(v.int()) }
			else {}
		}
	}
}

pub struct Range {
pub mut:
	start Position
	end	  Position
}

pub fn (mut r Range) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'start' { r.start = json2.decode<Position>(v.str()) or { Position{} } }
			'end' { r.end = json2.decode<Position>(v.str()) or { Position{} } }
			else {}
		}
	}
}

pub struct Location {
pub mut:
	valid bool = true
	uri	  DocumentUri
	range Range
}

pub fn (mut l Location) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'uri' { l.uri = make_path(v.str()) }
			'range' { l.range = json2.decode<Range>(v.str()) or { Range{} } } 
			else {}
		}
	}
}

pub struct LocationArray {
pub mut:
	items []Location
}

pub fn (mut la LocationArray) from_json(f json2.Any) {
	for item in f.arr() {
		la.items << json2.decode<Location>(item.str()) or { Location{} }
	}
}

pub struct LocationLink {
pub mut:
	//
	// Span of the origin of this link.
	//
	// Used as the underlined span for mouse interaction. Defaults to the word
	// range at the mouse position.
	///
	origin_selection_range Range

	//
	// The target resource identifier of this link.
	///
	target_uri DocumentUri

	//
	// The full target range of this link. If the target for example is a symbol
	// then target range is the range enclosing this symbol not including
	// leading/trailing whitespace but everything else like comments. This
	// information is typically used to highlight the range in the editor.
	///
	target_range Range

	//
	// The range that should be selected and revealed when this link is being
	// followed, e.g the name of a function. Must be contained by the the
	// `targetRange`. See also `DocumentSymbol#range`
	///
	target_selection_range Range
}

pub fn (mut ll LocationLink) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'originSelectionRange' { ll.origin_selection_range = json2.decode<Range>(v.str()) or { Range{} } }
			'targetUri' { ll.target_uri = make_path(v.str()) }
			'targetRange' { ll.target_range = json2.decode<Range>(v.str()) or { Range{} } }
			'targetSelectionRange' { ll.target_selection_range = json2.decode<Range>(v.str()) or { Range{} } }
			else {}
		}
	}
}

pub struct LocationLinkArray {
pub mut:
	items []LocationLink
}

pub fn (mut lla LocationLinkArray) from_json(f json2.Any) {
	for item in f.arr() {
		lla.items << json2.decode<LocationLink>(item.str()) or { LocationLink{} }
	}
}

pub struct Diagnostic {
pub mut:
	range				Range
	severity			int		// DiagnosticSeverity
	code				string
	code_description	string	// CodeDescription
	source				string
	message				string
	tags				string	// []DiagnosticTag
	related_information string	// []DiagnosticRelatedInformation
	data				string
}

pub fn (mut d Diagnostic) from_json(f json2.Any) {
	obj_map := f.as_map()
	for k, v in obj_map {
		match k {
			'range' { d.range = json2.decode<Range>(v.str()) or { Range{} } }
			'severity' { d.severity = v.int() }
			'code' { d.code = v.str() }
			'code_description' { d.code_description = v.str() }
			'source' { d.source = v.str() }
			'message' { d.message = v.str() }
			'tags' { d.tags = v.str() }
			'related_information' { d.related_information = v.str() }
			'data' { d.data = v.str() }
			else {}
		}
	}
}

pub struct DiagnosticRelatedInformation {
pub mut:
	location Location
	message	 string
}

pub fn (mut dri DiagnosticRelatedInformation) from_json(f json2.Any) {
	obj_map := f.as_map()
	for k, v in obj_map {
		match k {
			'location' { dri.location = json2.decode<Location>(v.str()) or { Location{} } }
			'message' { dri.message = v.str() }
			else {}
		}
	}
}

pub struct PublishDiagnosticsParams {
pub mut :
	uri			DocumentUri
	version		u32
	diagnostics []Diagnostic
}

pub fn (mut pd PublishDiagnosticsParams) from_json(f json2.Any) {
	obj_map := f.as_map()
	for k, v in obj_map {
		match k {
			'uri' { pd.uri = make_path(v.str()) }
			'version' { pd.version = u32(v.int()) }
			'diagnostics' { 
				for diag in v.arr() {
					pd.diagnostics << json2.decode<Diagnostic>(diag.str()) or { Diagnostic{} }
				}
			}
			else {}
		}
	}
}

pub struct CompletionList {
pub mut:
	is_incomplete bool
	items		  []CompletionItem
}

pub fn (mut cl CompletionList) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'is_incomplete' { cl.is_incomplete = v.bool() }
			'items' { 
				for item in v.arr() {
					cl.items << json2.decode<CompletionItem>(item.str()) or { CompletionItem{} }
				}
			}
			else {}
		}
	}
}

pub struct CompletionItem {
pub mut:
	label					string
	label_details			string
	kind					string
	tags					string
	detail					string
	documentation			string
	deprecated_				bool
	preselect				bool
	sort_text				string
	filter_text				string
	insert_text				string
	insert_text_format		string
	insert_text_mode		string
	text_edit				string
	additional_text_edits	string
	commit_characters		string
	command					string
	data					string
}

pub fn (mut ci CompletionItem) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'label' { ci.label = v.str() }
			'labelDetails' { ci.label_details = v.str() }
			'kind' { ci.kind = v.str() }
			'tags' { ci.tags = v.str() }
			'detail' { ci.detail = v.str() }
			'documentation' { ci.documentation = v.str() }
			'deprecated' { ci.deprecated_ = v.bool() }
			'preselect' { ci.preselect = v.bool() }
			'sortText' { ci.sort_text = v.str() }
			'filterText' { ci.filter_text = v.str() }
			'insertText' { ci.insert_text = v.str() }
			'insertTextFormat' { ci.insert_text_format = v.str() }
			'insertTextMode' { ci.insert_text_mode = v.str() }
			'textEdit' { ci.text_edit = v.str() }
			'additionalTextEdits' { ci.additional_text_edits = v.str() }
			'commitCharacters' { ci.commit_characters = v.str() }
			'command' { ci.command = v.str() }
			'data' { ci.data = v.str() }
			else {}
		}
	}
}

pub struct CompletionItemArray {
pub mut:
	items []CompletionItem
}

pub fn (mut cla CompletionItemArray) from_json(f json2.Any) {
	for item in f.arr() {
		cla.items << json2.decode<CompletionItem>(item.str()) or { CompletionItem{} }
	}
}

pub struct SignatureHelp {
pub mut:
	signatures []SignatureInformation
	active_signature u32
	active_parameter u32
}

pub fn (mut sh SignatureHelp) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'signatures' { 
				for item in v.arr() {
					sh.signatures << json2.decode<SignatureInformation>(item.str()) or { SignatureInformation{} }
				}
			}
			'activeSignature' { sh.active_signature = u32(v.int()) }
			'activeParameter' { sh.active_parameter = u32(v.int()) }
			else {}
		}
	}
}

pub struct SignatureInformation {
pub mut:
	label string
	documentation string
	parameters []ParameterInformation
	active_parameter u32
}

pub fn (mut si SignatureInformation) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'label' { si.label = v.str() }
			'documentation' { si.documentation = v.str() }
			'parameters' { 
				for item in v.arr() {
					si.parameters << json2.decode<ParameterInformation>(item.str()) or { ParameterInformation{} }
				}			
			}
			'activeParameter' { si.active_parameter = u32(v.int()) }
			else {}
		}
	}
}

pub struct ParameterInformation {
pub mut:
	label string
	documentation string
}

pub fn (mut pi ParameterInformation) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'label' { pi.label = v.str() }
			'documentation' { pi.documentation = v.str() }
			else {}
		}
	}
}

pub struct TextEditArray {
pub mut:
	items []TextEdit
}

pub fn (mut tea TextEditArray) from_json(f json2.Any) {
	for item in f.arr() {
		tea.items << json2.decode<TextEdit>(item.str()) or { TextEdit{} }
	}
}

pub struct TextEdit {
pub mut:
	range Range
	new_text string
}

pub fn (mut te TextEdit) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'range' { te.range = json2.decode<Range>(v.str()) or { Range{} } }
			'newText' { te.new_text = v.str() }
			else {}
		}
	}
}

pub struct ShowMessageParams {
pub mut:
	type_ int
	message string
}

pub fn (mut smp ShowMessageParams) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'type' { smp.type_ = v.int() }
			'message' { smp.message = v.str() }
			else {}
		}
	}
}

pub struct ShowMessageRequestParams {
pub mut:
	type_ int
	message string
	actions []string
}

pub fn (mut smrp ShowMessageRequestParams) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'type' { smrp.type_ = v.int() }
			'message' { smrp.message = v.str() }
			'actions' { smrp.actions = v.arr().map(it.str()) }
			else {}
		}
	}
}

pub struct ShowDocumentParams {
pub mut:
	uri DocumentUri

	// Indicates to show the resource in an external program.
	// To show for example `https://code.visualstudio.com/`
	// in the default WEB browser set `external` to `true`.
	external bool

	// An optional property to indicate whether the editor
	// showing the document should take focus or not.
	// Clients might ignore this property if an external program is started.
	take_focus bool

	// An optional selection range if the document is a text
	// document. Clients might ignore the property if an external program is started 
	// or the file is not a text file.
	selection Range
}

pub fn (mut sdp ShowDocumentParams) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'uri' { sdp.uri = v.str() }
			'external' { sdp.external = v.bool() }
			'takeFocus' { sdp.take_focus = v.bool() }
			'selection' { sdp.selection = json2.decode<Range>(v.str()) or { Range{} } }
			else {}
		}
	}
}

pub struct DocumentHighlight {
pub mut:
	// The range this highlight applies to.
	range Range

	// The highlight kind, default is DocumentHighlightKind.Text.
	kind int // DocumentHighlightKind
}

pub fn (mut dh DocumentHighlight) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'range' { dh.range = json2.decode<Range>(v.str()) or { Range{} } }
			'kind' { dh.kind = v.int() }
			else {}
		}
	}
}

pub struct DocumentHighlightArray {
pub mut:
	items []DocumentHighlight
}

pub fn (mut dha DocumentHighlightArray) from_json(f json2.Any) {
	for item in f.arr() {
		dha.items << json2.decode<DocumentHighlight>(item.str()) or { DocumentHighlight{} }
	}
}

pub struct DocumentSymbol {
pub mut:
	// The name of this symbol. Will be displayed in the user interface and
	// therefore must not be an empty string or a string only consisting of
	// white spaces.
	name string

	// More detail for this symbol, e.g the signature of a function.
	detail string

	// The kind of this symbol.
	kind int  // SymbolKind

	// Tags for this document symbol.
	// @since 3.16.0
	tags []int  // SymbolTag[]

	// Indicates if this symbol is deprecated.
	// @deprecated Use tags instead
	deprecated bool

	// The range enclosing this symbol not including leading/trailing whitespace
	// but everything else like comments. This information is typically used to
	// determine if the clients cursor is inside the symbol to reveal in the
	// symbol in the UI.
	range Range

	// The range that should be selected and revealed when this symbol is being
	// picked, e.g. the name of a function. Must be contained by the `range`.
	selection_range Range //selectionRange

	// Children of this symbol, e.g. properties of a class.
	children []DocumentSymbol
}

pub fn (mut ds DocumentSymbol) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'name' { ds.name = v.str()}
			'detail' { ds.detail = v.str()}
			'kind' { ds.kind = v.int()}
			'tags' { ds.tags << v.arr().map(it.int())}
			'deprecated' { ds.deprecated = v.bool()}
			'range' { ds.range = json2.decode<Range>(v.str()) or { Range{} }}
			'selectionRange' { ds.selection_range = json2.decode<Range>(v.str()) or { Range{} }}
			'children' { ds.children << json2.decode<DocumentSymbol>(v.str()) or { DocumentSymbol{} }}
			else {}
		}
	}}

pub struct SymbolInformation {
pub mut:
	// The name of this symbol.
	name string

	// The kind of this symbol.
	kind int // SymbolKind

	// Tags for this symbol.
	// @since 3.16.0
	tags []int // SymbolTag

	// Indicates if this symbol is deprecated.
	// @deprecated Use tags instead
	deprecated bool

	// The location of this symbol. The location's range is used by a tool
	// to reveal the location in the editor. If the symbol is selected in the
	// tool the range's start information is used to position the cursor. So
	// the range usually spans more then the actual symbol's name and does
	// normally include things like visibility modifiers.
	//
	// The range doesn't have to denote a node range in the sense of a abstract
	// syntax tree. It can therefore not be used to re-construct a hierarchy of
	// the symbols.
	location Location

	// The name of the symbol containing this symbol. This information is for
	// user interface purposes (e.g. to render a qualifier in the user interface
	// if necessary). It can't be used to re-infer a hierarchy for the document
	// symbols.
	container_name string //containerName
}

pub fn (mut si SymbolInformation) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'name' { si.name = v.str()}
			'kind' { si.kind = v.int()}
			'tags' { si.tags << v.arr().map(it.int())}
			'deprecated' { si.deprecated = v.bool()}
			'location' { si.location = json2.decode<Location>(v.str()) or { Location{} }}
			'containerName' { si.container_name = v.str()}
			else {}
		}
	}
}

pub struct DocumentSymbolArray {
pub mut:
	items []DocumentSymbol
}

pub fn (mut dsa DocumentSymbolArray) from_json(f json2.Any) {
	for item in f.arr() {
		dsa.items << json2.decode<DocumentSymbol>(item.str()) or { DocumentSymbol{} }
	}
}

pub struct SymbolInformationArray {
pub mut:
	items []SymbolInformation
}

pub fn (mut sia SymbolInformationArray) from_json(f json2.Any) {
	for item in f.arr() {
		sia.items << json2.decode<SymbolInformation>(item.str()) or { SymbolInformation{} }
	}
}

pub struct Hover {
pub mut:
	// The hover's content
	contents string // MarkedString | MarkedString[] | MarkupContent

	// An optional range is a range inside a text document
	// that is used to visualize a hover, e.g. by changing the background color.
	range Range
}

pub fn (mut h Hover) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'contents' {
				match true {
					v.str().starts_with('{') { 
						mc := json2.decode<MarkupContent>(v.str()) or { MarkupContent{} }
						h.contents = mc.value
					}
					v.str().starts_with('[') { 
						h.contents = v.arr().map(it.str()).join('\n')
					}
					else {
						h.contents = v.str()
					}
				}
			}
			'range' { h.range = json2.decode<Range>(v.str()) or { Range{} }}
			else {}
		}
	}	
}

pub struct MarkupContent {
pub mut:
	// The type of the Markup
	kind string

	// The content itself
	value string
}

pub fn (mut mc MarkupContent) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'kind' { mc.kind = v.str() }
			'value' { mc.value = v.str() }
			else {}
		}
	}	
}

pub struct CancelParams {
pub mut:
	id string
}

pub fn (mut cp CancelParams) from_json(f json2.Any) {
	cp.id = f.str()
}

pub struct ProgressParams {
pub mut:
	 // The progress token provided by the client or server.
	token string

	// The progress data.
	value string
}

pub fn (mut pp ProgressParams) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'token' { pp.token = v.str() }
			'value' { pp.value = v.str() }
			else {}
		}
	}	
}

pub struct WorkDoneProgressCreateParams {
pub mut:
	//The token to be used to report progress.
	token string
}

pub fn (mut wdpcp WorkDoneProgressCreateParams) from_json(f json2.Any) {
	wdpcp.token = f.str()
}

pub struct WorkDoneProgressCancelParams {
pub mut:
	//The token to be used to report progress.
	token string
}

pub fn (mut wdpcp WorkDoneProgressCancelParams) from_json(f json2.Any) {
	wdpcp.token = f.str()
}

pub struct CreateFilesParams {
pub mut:
	// An array of all files/folders created in this operation.
	files []FileCreate
}

pub fn (mut cfp CreateFilesParams) from_json(f json2.Any) {
	items := f.arr()
	for item in items {
		cfp.files << json2.decode<FileCreate>(item.str()) or { FileCreate{} }
	}
}

pub struct FileCreate {
pub mut:
	// A file:// URI for the location of the file/folder being created.
	uri string
}

pub fn (mut fc FileCreate) from_json(f json2.Any) {
	fc.uri = make_path(f.str())
}

pub struct RenameFilesParams {
pub mut:
	// An array of all files/folders renamed in this operation.
	files []FileRename
}

pub fn (mut rfp RenameFilesParams) from_json(f json2.Any) {
	items := f.arr()
	for item in items {
		rfp.files << json2.decode<FileRename>(item.str()) or { FileRename{} }
	}
}

pub struct FileRename {
pub mut:
	// A file:// URI for the location of the file/folder being renamed.
	old_uri string
	new_uri string
}

pub fn (mut fr FileRename) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'oldUri' { fr.old_uri = make_path(v.str()) }
			'newUri' { fr.new_uri = make_path(v.str()) }
			else {}
		}
	}	
}

pub struct DeleteFilesParams {
pub mut:
	// An array of all files/folders deleted in this operation.
	files []FileDelete
}

pub fn (mut dfp DeleteFilesParams) from_json(f json2.Any) {
	items := f.arr()
	for item in items {
		dfp.files << json2.decode<FileDelete>(item.str()) or { FileDelete{} }
	}
}

pub struct FileDelete {
pub mut:
	// A file:// URI for the location of the file/folder being deleted.
	uri string
}

pub fn (mut fd FileDelete) from_json(f json2.Any) {
	fd.uri = make_path(f.str())
}

pub struct RegistrationParams {
pub mut:
	registrations []Registration
}

pub fn (mut rp RegistrationParams) from_json(f json2.Any) {
	items := f.arr()
	for item in items {
		rp.registrations << json2.decode<Registration>(item.str()) or { Registration{} }
	}
}

pub struct Registration {
pub mut:
	// The id used to register the request. 
	// The id can be used to deregister the request again.
	id string

	// The method / capability to register for.
	method string

	// Options necessary for the registration.
	register_options string
}
pub fn (mut r Registration) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'id' { r.id = v.str() }
			'method' { r.method = v.str() }
			'registerOptions' { r.register_options = v.str() }
			else {}
		}
	}	
}

pub struct UnregistrationParams {
pub mut:
	unregistrations []Unregistration
}

pub fn (mut up UnregistrationParams) from_json(f json2.Any) {
	items := f.arr()
	for item in items {
		up.unregistrations << json2.decode<Unregistration>(item.str()) or { Unregistration{} }
	}
}

pub struct Unregistration {
pub mut:
	// The id used to unregister the request. 
	id string

	// The method / capability to unregister for.
	method string
}
pub fn (mut u Unregistration) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'id' { u.id = v.str() }
			'method' { u.method = v.str() }
			else {}
		}
	}	
}
