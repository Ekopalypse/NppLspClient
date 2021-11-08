module lsp
import x.json2

pub struct ServerCapabilities {
pub mut:
	text_document_sync                   int
	send_open_close_notif				 bool = true
	send_save_notif						 bool
	include_text_in_save_notif			 bool	
	supports_will_save					 bool
	supports_will_save_wait_until		 bool
	
	completion_provider                  CompletionOptions
	hover_provider                       bool
	signature_help_provider              SignatureHelpOptions
	declaration_provider                 bool
	definition_provider                  bool
	type_definition_provider             bool
	implementation_provider              bool
	references_provider                  bool
	document_highlight_provider          bool
	document_symbol_provider             bool
	code_action_provider                 bool
	code_lens_provider                   CodeLensOptions
	document_link_provider               bool
	color_provider                       bool
	document_formatting_provider         bool
	document_range_formatting_provider 	 bool
	document_on_type_formatting_provider DocumentOnTypeFormattingOptions
	rename_provider                      bool
	folding_range_provider               bool
	execute_command_provider             bool
	execute_commands					 []string
	selection_range_provider 			 bool
	linked_editing_range_provider 		 bool
	call_hierarchy_provider 			 bool
	semantic_tokens_provider 			 bool
	moniker_provider 					 bool
	workspace_symbol_provider            bool
	workspace_capabilities				 WorkspaceCapabilities
	supports_workspace_capabilities		 bool

	experimental                         map[string]bool
	
	fake								 bool
}

pub fn (mut sc ServerCapabilities) from_json(f json2.Any) {
	obj_map := f.as_map()
    for k, v in obj_map {
        match k {
			'textDocumentSync' {
				if v.str().starts_with('{') {
					sync_opt := json2.decode<TextDocumentSyncOptions>(v.str()) or { TextDocumentSyncOptions{} }
					sc.text_document_sync = sync_opt.change
					sc.send_open_close_notif = sync_opt.open_close
					sc.send_save_notif	= sync_opt.save_options
					sc.include_text_in_save_notif	= sync_opt.include_text
					sc.supports_will_save = sync_opt.will_save
					sc.supports_will_save_wait_until = sync_opt.will_save_wait_until
				} else {
					sc.text_document_sync = v.int()	
				}
			}
			'hoverProvider' { 
				if v.str().starts_with('{') {
					ho := json2.decode<HoverOptions>(v.str()) or { HoverOptions{} }
					sc.hover_provider = ho.work_done_progress
				} else {
					sc.hover_provider = v.bool() 					
				}
			}
			'completionProvider' { 
				sc.completion_provider = json2.decode<CompletionOptions>(v.str()) or { CompletionOptions{} }
			}
			'signatureHelpProvider' { 
				sc.signature_help_provider = json2.decode<SignatureHelpOptions>(v.str()) or { SignatureHelpOptions{} }
			}
			'definitionProvider' { 
				if v.str().starts_with('{') {
					do := json2.decode<DefinitionOptions>(v.str()) or { DefinitionOptions{} }
					sc.definition_provider = do.work_done_progress
				} else {
					sc.definition_provider = v.bool() 					
				}
			}
			'typeDefinitionProvider' {
				if v.str().starts_with('{') {
					tdo := json2.decode<TypeDefinitionOptions>(v.str()) or { TypeDefinitionOptions{} }
					sc.type_definition_provider = tdo.work_done_progress
				} else {
					sc.type_definition_provider = v.bool()
				}
			}
			'implementationProvider' {
				if v.str().starts_with('{') {
					io := json2.decode<ImplementationOptions>(v.str()) or { ImplementationOptions{} }
					sc.implementation_provider = io.work_done_progress
				} else {
					sc.implementation_provider = v.bool()
				}
			}  // | ImplementationOptions | ImplementationRegistrationOptions
			'referencesProvider' { 
				if v.str().starts_with('{') {
					ro := json2.decode<ReferenceOptions>(v.str()) or { ReferenceOptions{} }
					sc.references_provider = ro.work_done_progress
				} else {
					sc.references_provider = v.bool() 
				}
			}  // | ReferenceOptions
			'documentHighlightProvider' {
				if v.str().starts_with('{') {
					dho := json2.decode<DocumentHighlightOptions>(v.str()) or { DocumentHighlightOptions{} }
					sc.document_highlight_provider = dho.work_done_progress
				} else {
					sc.document_highlight_provider = v.bool() 
				}
			}
			'documentSymbolProvider' {
				if v.str().starts_with('{') {
					dso := json2.decode<DocumentSymbolOptions>(v.str()) or { DocumentSymbolOptions{} }
					sc.document_symbol_provider = dso.work_done_progress
				} else {
					sc.document_symbol_provider = v.bool() 
				}
			}
			'workspaceSymbolProvider' { sc.workspace_symbol_provider = v.bool() }  // | WorkspaceSymbolOptions
			'codeActionProvider' {
				if v.str().starts_with('{') {
					cao := json2.decode<CodeActionOptions>(v.str()) or { CodeActionOptions{} }
					sc.code_action_provider = cao.work_done_progress
				} else {
					sc.code_action_provider = v.bool()
				}
			}  // | 
			'codeLensProvider' { 
				sc.code_lens_provider = json2.decode<CodeLensOptions>(v.str()) or { CodeLensOptions{} }
			}
			'documentFormattingProvider' {
				if v.str().starts_with('{') {
					dfo := json2.decode<DocumentFormattingOptions>(v.str()) or { DocumentFormattingOptions{} }
					sc.document_formatting_provider = dfo.work_done_progress
				} else {
					sc.document_formatting_provider = v.bool()
				}
			}
			'documentOnTypeFormattingProvider' {
				sc.document_on_type_formatting_provider = json2.decode<DocumentOnTypeFormattingOptions>(v.str()) or { DocumentOnTypeFormattingOptions{} }
			}
			'renameProvider' {
				if v.str().starts_with('{') {
					ro := json2.decode<RenameOptions>(v.str()) or { RenameOptions{} }
					sc.rename_provider = ro.work_done_progress
				} else {
					sc.rename_provider = v.bool()
				}
			}
			'documentLinkProvider' {
				dlo := json2.decode<DocumentLinkOptions>(v.str()) or { DocumentLinkOptions{} }
				sc.document_link_provider = dlo.work_done_progress
			}
			'colorProvider' {
				if v.str().starts_with('{') {
					dco := json2.decode<DocumentColorOptions>(v.str()) or { DocumentColorOptions{} }
					sc.color_provider = dco.work_done_progress
				} else {
					sc.color_provider = v.bool()
				}
			}
			'declarationProvider' {
				if v.str().starts_with('{') {
					do := json2.decode<DeclarationOptions>(v.str()) or { DeclarationOptions{} }
					sc.declaration_provider = do.work_done_progress
				} else {
					sc.declaration_provider = v.bool()
				}
			}
			'executeCommandProvider' {
				eco := json2.decode<ExecuteCommandOptions>(v.str()) or { ExecuteCommandOptions{} }
				sc.execute_command_provider = eco.work_done_progress
				sc.execute_commands = eco.commands
			}
			'foldingRangeProvider' {
				if v.str().starts_with('{') {
					fro := json2.decode<FoldingRangeOptions>(v.str()) or { FoldingRangeOptions{} }
					sc.folding_range_provider = fro.work_done_progress
				} else {
					sc.folding_range_provider = v.bool()
				}
			}
			'semanticTokensProvider' {
				sto := json2.decode<SemanticTokensOptions>(v.str()) or { SemanticTokensOptions{} }
				sc.semantic_tokens_provider = sto.work_done_progress
			}
			
			'documentRangeFormattingProvider' {
				if v.str().starts_with('{') {
					drfo := json2.decode<DocumentRangeFormattingOptions>(v.str()) or { DocumentRangeFormattingOptions{} }
					sc.document_range_formatting_provider = drfo.work_done_progress
				} else {
					sc.document_range_formatting_provider = v.bool() 
				}
			}
			'selectionRangeProvider' {
				if v.str().starts_with('{') {
					sro := json2.decode<SelectionRangeOptions>(v.str()) or { SelectionRangeOptions{} }
					sc.selection_range_provider = sro.work_done_progress
				} else {
					sc.selection_range_provider = v.bool()
				}
			}
			'linkedEditingRangeProvider' {
				if v.str().starts_with('{') {
					lero := json2.decode<LinkedEditingRangeOptions>(v.str()) or { LinkedEditingRangeOptions{} }
					sc.linked_editing_range_provider = lero.work_done_progress
				} else {
					sc.linked_editing_range_provider = v.bool()
				}
			}
			'callHierarchyProvider' {
				if v.str().starts_with('{') {
					cho := json2.decode<CallHierarchyOptions>(v.str()) or { CallHierarchyOptions{} }
					sc.call_hierarchy_provider = cho.work_done_progress
				} else {
					sc.call_hierarchy_provider = v.bool() 
				}
			}
			'monikerProvider' {
				if v.str().starts_with('{') {
					mo := json2.decode<MonikerOptions>(v.str()) or { MonikerOptions{} }
					sc.moniker_provider = mo.work_done_progress
				} else {
					sc.moniker_provider = v.bool()
				}
			}
			'workspace' { 
				sc.supports_workspace_capabilities = true
				sc.workspace_capabilities = json2.decode<WorkspaceCapabilities>(v.str()) or { WorkspaceCapabilities{} } 
			}

			// 'experimental' { sc.experimental = v.str() }
			else {}
        }
    }
}


pub struct CompletionOptions {
pub mut:
	resolve_provider   bool
	trigger_characters []string
}

pub fn (mut co CompletionOptions) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'resolveProvider' { co.resolve_provider =  v.bool() }
			'triggerCharacters' { co.trigger_characters = v.arr().map(it.str()) }
			else {}
		}
	}
}

pub struct TextDocumentSyncOptions {
pub mut:
	// Open and close notifications are sent to the server.
	// If omitted open close notification should not be sent.
	open_close bool

	// Change notifications are sent to the server.
	// TextDocumentSyncKind.None, TextDocumentSyncKind.Full and
	// TextDocumentSyncKind.Incremental.
	// If omitted it defaults to TextDocumentSyncKind.None.
	change int

	// If present will save notifications are sent to the server.
	// If omitted the notification should not be sent.
	will_save bool

	// If present will save wait until requests are sent to the server.
	// If omitted the request should not be sent.
	will_save_wait_until bool

	// If present save notifications are sent to the server.
	// If omitted the notification should not be sent.
	save_options bool
	include_text bool
}

pub fn (mut tdso TextDocumentSyncOptions) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'openClose' { tdso.open_close = v.bool() }
			'change' { tdso.change = v.int() }
			'willSave' { tdso.will_save = v.bool() }
			'willSaveWaitUntil' { tdso.will_save_wait_until = v.bool() }
			'save' {
				if v.str().starts_with('{') {
					tdso.save_options = true
					so := json2.decode<SaveOptions>(v.str()) or { SaveOptions{} }
					tdso.include_text = so.include_text
				} else {
					tdso.save_options = v.bool()
				}
			}
			else {}
		}
	}
}

pub struct SaveOptions {
pub mut:
	// The client is supposed to include the content on save.
	include_text bool
}

pub fn (mut so SaveOptions) from_json(f json2.Any) {
	so.include_text = f.bool()
}

pub struct SignatureHelpOptions {
pub mut:
	trigger_characters	 []string
	retrigger_characters []string
}

pub fn (mut sho SignatureHelpOptions) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'triggerCharacters' { sho.trigger_characters = v.arr().map(it.str()) }
			'retriggerCharacters' { sho.retrigger_characters =	v.arr().map(it.str()) }
			else {}
		}
	}
}

pub struct CodeLensOptions {
pub mut:
	resolve_provider bool
}

pub fn (mut clo CodeLensOptions) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'resolveProvider' { clo.resolve_provider =	v.bool() }
			else {}
		}
	}
}

pub struct DocumentOnTypeFormattingOptions {
pub mut:
	first_trigger_character string
	more_trigger_character	[]string
}

pub fn (mut dtfo DocumentOnTypeFormattingOptions) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'firstTriggerCharacter' { dtfo.first_trigger_character =  v.str() }
			'moreTriggerCharacter' { dtfo.more_trigger_character = v.arr().map(it.str()) }
			else {}
		}
	}
}

pub struct WorkspaceCapabilities {
pub mut:
	workspace_folders WorkspaceFoldersServerCapabilities
	file_operations FileOperation
}

pub fn (mut wc WorkspaceCapabilities) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'workspaceFolders' { wc.workspace_folders = json2.decode<WorkspaceFoldersServerCapabilities>(v.str()) or { WorkspaceFoldersServerCapabilities{} } } 
			'fileOperations' { wc.file_operations = json2.decode<FileOperation>(v.str()) or { FileOperation{} } } 
			else {}
		}
	}
}

pub struct WorkspaceFoldersServerCapabilities {
pub mut:
	supported bool

	// If a string is provided, the string is treated as an ID
	// under which the notification is registered on the client
	// side. The ID can be used to unregister for these events
	// using the `client/unregisterCapability` request.
	change_notifications string // | boolean
}

pub fn (mut wfsc WorkspaceFoldersServerCapabilities) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'supported' { wfsc.supported = v.bool() }
			'changeNotifications' { wfsc.change_notifications = v.str() }
			else {}
		}
	}
}

pub struct FileOperation {
pub mut:
	did_create FileOperationRegistrationOptions
	will_create FileOperationRegistrationOptions
	did_rename FileOperationRegistrationOptions
	will_rename FileOperationRegistrationOptions
	did_delete FileOperationRegistrationOptions
	will_delete FileOperationRegistrationOptions

}

pub fn (mut fo FileOperation) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'didCreate' { fo.did_create = json2.decode<FileOperationRegistrationOptions>(v.str()) or { FileOperationRegistrationOptions{} } }
			'willCreate' { fo.will_create = json2.decode<FileOperationRegistrationOptions>(v.str()) or { FileOperationRegistrationOptions{} } }
			'didRename' { fo.did_rename = json2.decode<FileOperationRegistrationOptions>(v.str()) or { FileOperationRegistrationOptions{} } }
			'willRename' { fo.will_rename = json2.decode<FileOperationRegistrationOptions>(v.str()) or { FileOperationRegistrationOptions{} } }
			'didDelete' { fo.did_delete = json2.decode<FileOperationRegistrationOptions>(v.str()) or { FileOperationRegistrationOptions{} } }
			'willDelete' { fo.will_delete = json2.decode<FileOperationRegistrationOptions>(v.str()) or { FileOperationRegistrationOptions{} } }
			else {}
		}
	}
}

pub struct FileOperationRegistrationOptions {
pub mut:
	filters []FileOperationFilter
}

pub fn (mut foro FileOperationRegistrationOptions) from_json(f json2.Any) {
	items := f.arr()
	for item in items {
		foro.filters << json2.decode<FileOperationFilter>(item.str()) or { FileOperationFilter{} }
	}
}

pub struct FileOperationFilter {
pub mut:
	// A Uri like `file` or `untitled`.
	scheme string
	pattern FileOperationPattern
}

pub fn (mut fof FileOperationFilter) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'scheme' { fof.scheme = v.str() }
			'pattern' { fof.pattern = json2.decode<FileOperationPattern>(v.str()) or { FileOperationPattern{} } }
			else {}
		}
	}
}

pub struct FileOperationPattern {
pub mut:
	// The glob pattern to match. Glob patterns can have the following syntax:
	// - `*` to match one or more characters in a path segment
	// - `?` to match on one character in a path segment
	// - `**` to match any number of path segments, including none
	// - `{}` to group sub patterns into an OR expression. (e.g. `**​/*.{ts,js}`
	//   matches all TypeScript and JavaScript files)
	// - `[]` to declare a range of characters to match in a path segment
	//   (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)
	// - `[!...]` to negate a range of characters to match in a path segment
	//   (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but
	//   not `example.0`)

	glob string
	matches string  // is either 'file' | 'folder', matches both if undefined.

	// Additional options used during matching
	options FileOperationPatternOptions
}

pub fn (mut fop FileOperationPattern) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'glob' { fop.glob = v.str() }
			'matches' { fop.matches = v.str() }
			'options' { fop.options = json2.decode<FileOperationPatternOptions>(v.str()) or { FileOperationPatternOptions{} } }
			else {}
		}
	}
}

pub struct FileOperationPatternOptions {
pub mut:
	ignore_case bool
}

pub fn (mut fopo FileOperationPatternOptions) from_json(f json2.Any) {
	fopo.ignore_case = f.bool()
}

pub struct HoverOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut ho HoverOptions) from_json(f json2.Any) {
	ho.work_done_progress = f.bool()
}

pub struct DefinitionOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut do DefinitionOptions) from_json(f json2.Any) {
	do.work_done_progress = f.bool()
}

pub struct DeclarationOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut do DeclarationOptions) from_json(f json2.Any) {
	do.work_done_progress = f.bool()
}

pub struct TypeDefinitionOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut tdo TypeDefinitionOptions) from_json(f json2.Any) {
	tdo.work_done_progress = f.bool()
}

pub struct ImplementationOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut io ImplementationOptions) from_json(f json2.Any) {
	io.work_done_progress = f.bool()
}

pub struct ReferenceOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut ro ReferenceOptions) from_json(f json2.Any) {
	ro.work_done_progress = f.bool()
}

pub struct DocumentHighlightOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut dho DocumentHighlightOptions) from_json(f json2.Any) {
	dho.work_done_progress = f.bool()
}
pub struct DocumentColorOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut dco DocumentColorOptions) from_json(f json2.Any) {
	dco.work_done_progress = f.bool()
}

pub struct DocumentFormattingOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut dfo DocumentFormattingOptions) from_json(f json2.Any) {
	dfo.work_done_progress = f.bool()
}
pub struct DocumentRangeFormattingOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut drfo DocumentRangeFormattingOptions) from_json(f json2.Any) {
	drfo.work_done_progress = f.bool()
}

pub struct FoldingRangeOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut fro FoldingRangeOptions) from_json(f json2.Any) {
	fro.work_done_progress = f.bool()
}
pub struct SelectionRangeOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut sro SelectionRangeOptions) from_json(f json2.Any) {
	sro.work_done_progress = f.bool()
}

pub struct LinkedEditingRangeOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut lero LinkedEditingRangeOptions) from_json(f json2.Any) {
	lero.work_done_progress = f.bool()
}
pub struct CallHierarchyOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut cho CallHierarchyOptions) from_json(f json2.Any) {
	cho.work_done_progress = f.bool()
}

pub struct MonikerOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut mo MonikerOptions) from_json(f json2.Any) {
	mo.work_done_progress = f.bool()
}
pub struct WorkspaceSymbolOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut wso WorkspaceSymbolOptions) from_json(f json2.Any) {
	wso.work_done_progress = f.bool()
}
pub struct DocumentSymbolOptions {
pub mut:
	work_done_progress bool
	label string
}

pub fn (mut dso DocumentSymbolOptions) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'workDoneProgress' { dso.work_done_progress = v.bool() }
			'label' { dso.label = v.str() }
			else {}
		}
	}
}
pub struct CodeActionOptions {
pub mut:
	work_done_progress bool
	code_action_kinds []string
	resolve_provider bool
}

pub fn (mut cao CodeActionOptions) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'workDoneProgress' { cao.work_done_progress = v.bool() }
			'codeActionKinds' { cao.code_action_kinds << v.arr().map(it.str()) }
			'resolveProvider' { cao.resolve_provider = v.bool() }
			else {}
		}
	}
}
pub struct DocumentLinkOptions {
pub mut:
	work_done_progress bool
}

pub fn (mut dlo DocumentLinkOptions) from_json(f json2.Any) {
	dlo.work_done_progress = f.bool()
}pub struct RenameOptions {
pub mut:
	work_done_progress bool
	prepare_provider bool
}

pub fn (mut cao RenameOptions) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'workDoneProgress' { cao.work_done_progress = v.bool() }
			'prepareProvider' { cao.prepare_provider = v.bool() }
			else {}
		}
	}
}
pub struct ExecuteCommandOptions {
pub mut:
	work_done_progress bool
	commands []string
}

pub fn (mut cao ExecuteCommandOptions) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'workDoneProgress' { cao.work_done_progress = v.bool() }
			'commands' { cao.commands = v.arr().map(it.str()) }
			else {}
		}
	}
}

pub struct SemanticTokensOptions {
pub mut:
	work_done_progress bool
	legend SemanticTokensLegend

	// TODO: ?? unsure what that means ??
	
	// // Server supports providing semantic tokens for a specific range of a document.
	// range?: bool | {}

	// // Server supports providing semantic tokens for a full document.
	// full?: bool | {
		// // The server supports deltas for full documents.
		// delta?: bool
	// }
}

pub fn (mut sto SemanticTokensOptions) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'workDoneProgress' { sto.work_done_progress = v.bool() }
			'legend' { sto.legend = json2.decode<SemanticTokensLegend>(v.str()) or { SemanticTokensLegend{} } }
			'range' { }
			'full' { }
			else {}
		}
	}
}
pub struct SemanticTokensLegend {
pub mut:
	token_types []string
	token_modifiers []string
}

pub fn (mut stl SemanticTokensLegend) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'tokenTypes' { stl.token_types = v.arr().map(it.str()) }
			'tokenModifiers' { stl.token_modifiers = v.arr().map(it.str()) }
			else {}
		}
	}
}