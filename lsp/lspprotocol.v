module lsp

// import x.json2

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
	method   string
	id       string
	params   string
	response string
}

fn (m Message) encode() string {
	body := match m.msg_type {
		.request {
			'{"jsonrpc":"2.0","id":$m.id,"method":$m.method,"params":$m.params}'
		}
		.response {
			'{"jsonrpc":"2.0","id":$m.id,$m.response}' // m.response is either result or an error object
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
	return 'Content-Length: $body.len\r\n\r\n$body'
}

pub fn initialize(pid int, file_path string) string {
	uri_path := make_uri(file_path)
	client_info := '"clientInfo":{"name":"NppLspClient","version":"0.0.1"}'
	initialization_options := '"initializationOptions":{}'
	capabilities := '"capabilities":{
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
	}'.replace_each([
		'\t',
		'',
		'\n',
		'',
		'\r',
		'',
	])
	trace := '"trace":"off"'
	workspace_folders := '"workspaceFolders":null'

	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].init_id()
		method: '"initialize"'
		params: '{"processId":$pid,$client_info,"rootUri":"$uri_path",$initialization_options,$capabilities,$trace,$workspace_folders}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = initialize_response
	return m.encode()
}

pub fn initialized() string {
	m := Message{
		msg_type: JsonRpcMessageType.notification
		method: '"initialized"'
		params: '{}'
	}
	return m.encode()
}

pub fn exit_msg() string {
	m := Message{
		msg_type: JsonRpcMessageType.exit
		method: '"exit"'
	}
	return m.encode()
}

pub fn shutdown_msg() string {
	m := Message{
		msg_type: JsonRpcMessageType.shutdown
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"shutdown"'
	}
	// p.lsp_config.lspservers[p.current_language].message_id_counter++
	_ := p.lsp_config.lspservers[p.current_language].get_next_id()
	return m.encode()
}

pub fn did_open(file_path DocumentUri, file_version int, language_id string, content string) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/didOpen"'
		params: '{"textDocument":{"uri":"$uri_path","languageId":"$language_id","version":$file_version,"text":"$content"}}'
	}
	return m.encode()
}

pub fn did_change_incremental(file_path DocumentUri, file_version int, text_changes string, start_line u32, start_char u32, end_line u32, end_char u32, range_length u32) string {
	uri_path := make_uri(file_path)
	range := make_range(start_line, start_char, end_line, end_char)
	changes := '{$range,"rangeLength":$range_length,"text":"$text_changes"}'

	m := Message{
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/didChange"'
		params: '{"textDocument":{"uri":"$uri_path","version":$file_version},"contentChanges":[$changes]}'
	}
	return m.encode()
}

pub fn did_change_full(file_path DocumentUri, file_version int, text_changes string) string {
	uri_path := make_uri(file_path)
	changes := '{"text":"$text_changes"}'
	m := Message{
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/didChange"'
		params: '{"textDocument":{"uri":"$uri_path","version":$file_version},"contentChanges":[$changes]}'
	}
	return m.encode()
}

pub fn will_save(file_path DocumentUri) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/willSave"'
		params: '{"textDocument":{"uri":"$uri_path"},"reason":1'
	}
	return m.encode()
}

pub fn will_save_wait_until(file_path DocumentUri, reason int) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/willSaveWaitUntil"'
		params: '{"textDocument":{"uri":"$uri_path"},"reason":$reason'
	}
	return m.encode()
}

pub fn did_save(file_path DocumentUri, content string) string {
	uri_path := make_uri(file_path)
	params__ := if content.len == 0 {
		'{"textDocument":{"uri":"$uri_path"}}'
	} else {
		'{"textDocument":{"uri":"$uri_path","text":$content}}'
	}
	m := Message{
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/didSave"'
		params: params__
	}
	return m.encode()
}

pub fn did_close(file_path DocumentUri) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.notification
		method: '"textDocument/didClose"'
		params: '{"textDocument":{"uri":"$uri_path"}}'
	}
	return m.encode()
}

pub fn request_completion(file_path DocumentUri, line u32, char_pos u32, trigger_character string) string {
	uri_path := make_uri(file_path)
	context := if trigger_character.len == 0 {
		'"context":{"triggerKind":1}'
	} else {
		'"context":{"triggerKind":2,"triggerCharacter":"$trigger_character"}'
	}
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/completion"'
		params: '{"textDocument":{"uri":"$uri_path"},"position":{"line":$line,"character":$char_pos},$context}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = completion_response
	return m.encode()
}

pub fn request_signature_help(file_path DocumentUri, line u32, char_pos u32, trigger_character string) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/signatureHelp"'
		params: '{"textDocument":{"uri":"$uri_path"},"position":{"line":$line,"character":$char_pos},"context":{"isRetrigger":false,"triggerCharacter":"$trigger_character","triggerKind":2}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = signature_help_response
	return m.encode()
}

pub fn format_document(file_path DocumentUri, tab_size u32, insert_spaces bool, trim_trailing_whitespace bool, insert_final_new_line bool, trim_final_new_lines bool) string {
	text_document := '"textDocument":{"uri":"${make_uri(file_path)}"}'
	options := '"options":{"insertSpaces":$insert_spaces,"tabSize":$tab_size,"trimTrailingWhitespace":$trim_trailing_whitespace,"insertFinalNewline":$insert_final_new_line,"trimFinalNewlines":$trim_final_new_lines}'
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/formatting"'
		params: '{$text_document,$options}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = format_document_response
	return m.encode()
}

pub fn format_selected_range(file_path DocumentUri, start_line u32, start_char u32, end_line u32, end_char u32, tab_size u32, insert_spaces bool, trim_trailing_whitespace bool, insert_final_new_line bool, trim_final_new_lines bool) string {
	text_document := '"textDocument":{"uri":"${make_uri(file_path)}"}'
	range := make_range(start_line, start_char, end_line, end_char)
	options := '"options":{"insertSpaces":$insert_spaces,"tabSize":$tab_size,"trimTrailingWhitespace":$trim_trailing_whitespace,"insertFinalNewline":$insert_final_new_line,"trimFinalNewlines":$trim_final_new_lines}'
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/formatting"'
		params: '{$text_document,$range,$options}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = format_document_response
	return m.encode()
}

pub fn goto_definition(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/definition"'
		params: '{"textDocument":{"uri":"$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = goto_definition_response
	return m.encode()
}

pub fn peek_definition(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/definition"'
		params: '{"textDocument":{"uri":"$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = peek_definition_response
	return m.encode()
}

pub fn goto_implementation(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/implementation"'
		params: '{"textDocument":{"uri":"$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = goto_implementation_response
	return m.encode()
}

pub fn peek_implementation(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/implementation"'
		params: '{"textDocument":{"uri":"$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = peek_implementation_response
	return m.encode()
}

pub fn goto_declaration(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/declaration"'
		params: '{"textDocument":{"uri":"$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = goto_declaration_response
	return m.encode()
}

pub fn find_references(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/references"'
		params: '{"textDocument":{"uri":"$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = find_references_response
	return m.encode()
}

pub fn document_highlight(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/documentHighlight"'
		params: '{"textDocument":{"uri":"$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = document_highlight_response
	return m.encode()
}

pub fn document_symbols(file_path DocumentUri) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/documentSymbol"'
		params: '{"textDocument":{"uri":"$uri_path"}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = document_symbols_response
	return m.encode()
}

pub fn hover(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/hover"'
		params: '{"textDocument":{"uri":"$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = hover_response
	return m.encode()
}

pub fn rename(file_path DocumentUri, line u32, char_position u32, replacement string) string {
	uri_path := make_uri(file_path)
	position := '"position":{"character":$char_position,"line":$line}'
	new_name := '"newName":$replacement'
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/rename"'
		params: '{"textDocument":{"uri":"$uri_path"},$position,$new_name}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = rename_response
	return m.encode()
}

pub fn prepare_rename(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	position := '"position":{"character":$char_position,"line":$line}'
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/prepareRename"'
		params: '{"textDocument":{"uri":"$uri_path"},$position}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = prepare_rename_response
	return m.encode()
}

pub fn folding_range(file_path DocumentUri) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/prepareRename"'
		params: '{"textDocument":{"uri":"$uri_path"}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = folding_range_response
	return m.encode()
}

pub fn selection_range(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	position := '"position":{"character":$char_position,"line":$line}'

	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/selectionRange"'
		params: '{"textDocument":{"uri":"$uri_path"},$position}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = selection_range_response
	return m.encode()
}

pub fn cancel_request(request_id int) string {
	m := Message{
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"$/cancelRequest"'
		params: '{"id":$request_id}'
	}
	return m.encode()
}

pub fn progress(token int, value string) string {
	m := Message{
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"$/progress"'
		params: '{"token":$token,"value":"$value"}'
	}
	return m.encode()
}

pub fn set_trace(trace_value string) string {
	m := Message{
		msg_type: JsonRpcMessageType.notification
		method: '"$/setTrace"'
		params: '{"value":"$trace_value"}'
	}
	return m.encode()
}

pub fn incoming_calls(token int, value string) string {
	//  TODO: WorkDoneProgressParams
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"callHierarchy/incomingCalls"'
		// params: '{"workDoneToken":{"token":"","value":null}}'
		params: '{}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = incoming_calls_response
	return m.encode()
}

pub fn outgoing_calls(token int, value string) string {
	//  TODO: WorkDoneProgressParams
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"callHierarchy/outgoingCalls"'
		// params: '{"workDoneToken":{"token":"","value":null}}'
		params: '{}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = outgoing_calls_response
	return m.encode()
}

pub fn code_action_resolve(title string) string {
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"codeAction/resolve"'
		params: '{"title":"$title"}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = code_action_resolve_response
	return m.encode()
}

pub fn code_lens_resolve(file_path DocumentUri) string {
	//  TODO: WorkDoneProgressParams
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"codeLens/resolve"'
		params: '{"textDocument":{"uri":"$uri_path"}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = code_lens_resolve_response
	return m.encode()
}

pub fn completion_item_resolve(label string) string {
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"completionItem/resolve"'
		params: '{"label":"$label"}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = completion_item_resolve_response
	return m.encode()
}

pub fn document_link_resolve(start_line u32, start_char u32, end_line u32, end_char u32) string {
	range := make_range(start_line, start_char, end_line, end_char)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"documentLink/resolve"'
		params: '{$range}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = document_link_resolve_response
	return m.encode()
}

pub fn code_action(file_path DocumentUri, start_line u32, start_char u32, end_line u32, end_char u32) string {
	//  TODO: WorkDoneProgressParams
	uri_path := make_uri(file_path)
	text_document := '"textDocument":{"uri":"$uri_path"}'
	range := make_range(start_line, start_char, end_line, end_char)
	// export interface CodeActionContext {
	// /**
	// * An array of diagnostics known on the client side overlapping the range
	// * provided to the `textDocument/codeAction` request. They are provided so
	// * that the server knows which errors are currently presented to the user
	// * for the given range. There is no guarantee that these accurately reflect
	// * the error state of the resource. The primary parameter
	// * to compute code actions is the provided range.
	// */
	// diagnostics: Diagnostic[];

	// /**
	// * Requested kind of actions to return.
	// *
	// * Actions not of this kind are filtered out by the client before being
	// * shown. So servers can omit computing them.
	// */
	// only?: CodeActionKind[];

	// /**
	// * The reason why code actions were requested.
	// *
	// * @since 3.17.0
	// */
	// triggerKind?: CodeActionTriggerKind;
	// }
	context := '{"diagnostics":[]}'
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/codeAction"'
		params: '{$text_document,$range,$context}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = code_action_response
	return m.encode()
}

pub fn code_lens(file_path DocumentUri) string {
	// TODO: WorkDoneProgressParams
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/codeLens"'
		params: '{"textDocument":{"uri":"$uri_path"}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = code_lens_response
	return m.encode()
}

pub fn color_presentation(file_path DocumentUri, start_line u32, start_char u32, end_line u32, end_char u32, red f32, green f32, blue f32, alpha f32) string {
	// TODO: WorkDoneProgressParams
	uri_path := make_uri(file_path)
	text_document := '"textDocument":{"uri":"$uri_path"}'
	color := '"color":{"red":$red,"green":$green,"blue":$blue,"alpha":$alpha}'
	range := make_range(start_line, start_char, end_line, end_char)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/colorPresentation"'
		params: '{$text_document,$color,$range}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = color_presentation_response
	return m.encode()
}

pub fn document_color(file_path DocumentUri) string {
	// TODO: WorkDoneProgressParams
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/documentColor"'
		params: '{"textDocument":{"uri":"$uri_path"}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = document_color_response
	return m.encode()
}

pub fn document_link(file_path DocumentUri) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/documentLink"'
		params: '{"textDocument":{"uri":"$uri_path"}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = document_link_response
	return m.encode()
}

pub fn linked_editing_range(file_path DocumentUri, line u32, char_position u32) string {
	// TODO: WorkDoneProgressParams
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/linkedEditingRange"'
		params: '{"textDocument":{"uri":"$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = linked_editing_range_response
	return m.encode()
}

pub fn moniker(file_path DocumentUri, line u32, char_position u32) string {
	// TODO: WorkDoneProgressParams
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/moniker"'
		params: '{"textDocument":{"uri":"$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = moniker_response
	return m.encode()
}

pub fn on_type_formatting(file_path DocumentUri, line u32, char_position u32, ch string, tab_size u32, insert_spaces bool) string {
	uri_path := make_uri(file_path)

	text_document := '"textDocument":{"uri":"$uri_path"}'
	position := '"position":{"character":$char_position,"line":$line}'
	character := '"ch":"$ch"'
	// FormattingOptions
	// Size of a tab in spaces.
	// tabSize: u32

	// Prefer spaces over tabs.
	// insertSpaces: bool

	// Trim trailing whitespace on a line.
	// trimTrailingWhitespace?: bool

	// Insert a newline character at the end of the file if one does not exist.
	// insertFinalNewline?: bool

	// Trim all newlines after the final newline at the end of the file.
	// trimFinalNewlines?: bool

	// Signature for further properties.
	// [key: string]: bool | integer | string;
	options := '{"tabSize":tab_size,"insertSpaces":$insert_spaces}'

	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/onTypeFormatting"'
		params: '{$text_document,$position,$character,$options}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = on_type_formatting_response
	return m.encode()
}

pub fn prepare_call_hierarchy(file_path DocumentUri, line u32, char_position u32) string {
	// TODO: WorkDoneProgressParams
	uri_path := make_uri(file_path)
	text_document := '"textDocument":{"uri":"$uri_path"}'
	position := '"position":{"character":$char_position,"line":$line}'
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/prepareCallHierarchy"'
		params: '{$text_document,$position}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = prepare_call_hierarchy_response
	return m.encode()
}

pub fn semantic_tokens_full(file_path DocumentUri) string {
	// TODO: WorkDoneProgressParams
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/semanticTokens/full"'
		params: '{"textDocument":{"uri":"$uri_path"}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = semantic_tokens_full_response
	return m.encode()
}

pub fn semantic_tokens_delta(file_path DocumentUri, previous_result_id string) string {
	// TODO: WorkDoneProgressParams
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/semanticTokens/full/delta"'
		params: '{"textDocument":{"uri":"$uri_path"},"previousResultId":"previous_result_id"}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = semantic_tokens_delta_response
	return m.encode()
}

pub fn semantic_tokens_range(file_path DocumentUri, start_line u32, start_char u32, end_line u32, end_char u32) string {
	// TODO: WorkDoneProgressParams
	uri_path := make_uri(file_path)
	text_document := '"textDocument":{"uri":"$uri_path"}'
	range := make_range(start_line, start_char, end_line, end_char)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/semanticTokens/range"'
		params: '{$text_document,$range}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = semantic_tokens_range_response
	return m.encode()
}

pub fn type_definition(file_path DocumentUri, line u32, char_position u32) string {
	uri_path := make_uri(file_path)
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"textDocument/typeDefinition"'
		params: '{"textDocument":{"uri":"$uri_path"},"position":{"character":$char_position,"line":$line}}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = type_definition_response
	return m.encode()
}

pub fn work_done_progress_cancel(token int, value string) string {
	// TODO:
	m := Message{
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"window/workDoneProgress/cancel"'
		params: '{"token":$token,"value":"$value"}'
	}
	return m.encode()
}

pub fn workspace_did_change_workspace_folders(added_folders WorkspaceFolderArray, removed_folders WorkspaceFolderArray) string {
	added := added_folders.make_lsp_message()
	removed := removed_folders.make_lsp_message()

	m := Message{
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/didChangeWorkspaceFolders"'
		params: '{"event":{"added":$added,"removed":$removed}}'
	}
	return m.encode()
}

pub fn workspace_did_change_configuration(settings string) string {
	m := Message{
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/didChangeConfiguration"'
		params: '{"settings":$settings}'
	}
	return m.encode()
}

pub fn workspace_did_change_watched_files(file_events FileEventArray) string {
	changes := file_events.make_lsp_message()
	m := Message{
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/didChangeWatchedFiles"'
		params: '{"changes":$changes}'
	}
	return m.encode()
}

pub fn workspace_did_rename_files(files_renamed FileRenameArray) string {
	renamed_files := files_renamed.make_lsp_message()
	m := Message{
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/didRenameFiles"'
		params: '{"files":$renamed_files}'
	}
	return m.encode()
}

pub fn workspace_did_create_files(files_created FileCreateArray) string {
	created_files := files_created.make_lsp_message()
	m := Message{
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/didCreateFiles"'
		params: '{"files":$created_files}'
	}
	return m.encode()
}

pub fn workspace_did_delete_files(files_deleted FileDeleteArray) string {
	deleted_files := files_deleted.make_lsp_message()
	m := Message{
		msg_type: JsonRpcMessageType.notification
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/didDeleteFiles"'
		params: '{"files":$deleted_files}'
	}
	return m.encode()
}

pub fn workspace_execute_command(command string, args []string) string {
	params__ := if args.len == 0 {
		'"command":"$command"'
	} else {
		'"command":"$command","arguments":[${args.join(',')}]'
	}
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/executeCommand"'
		params: '{$params__}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = workspace_execute_command_response
	return m.encode()
}

pub fn workspace_symbol(query string) string {
	// TODO: WorkDoneProgressParams
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/symbol"'
		params: '{"query":"$query"}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = workspace_symbol_response
	return m.encode()
}

pub fn workspace_will_create_files(files_created FileCreateArray) string {
	created_files := files_created.make_lsp_message()
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/willCreateFiles"'
		params: '{"files":$created_files}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = workspace_will_create_files_response
	return m.encode()
}

pub fn workspace_will_delete_files(files_deleted FileDeleteArray) string {
	deleted_files := files_deleted.make_lsp_message()
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/willDeleteFiles"'
		params: '{"files":$deleted_files}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = workspace_will_delete_files_response
	return m.encode()
}

pub fn workspace_will_rename_files(files_renamed FileRenameArray) string {
	renamed_files := files_renamed.make_lsp_message()
	m := Message{
		msg_type: JsonRpcMessageType.request
		id: p.lsp_config.lspservers[p.current_language].get_next_id()
		method: '"workspace/willRenameFiles"'
		params: '{"files":$renamed_files}'
	}
	p.lsp_config.lspservers[p.current_language].open_response_messages[m.id] = workspace_will_rename_files_response
	return m.encode()
}
