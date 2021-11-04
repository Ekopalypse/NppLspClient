module lsp
import x.json2

pub struct ServerCapabilities {
pub mut:
	text_document_sync                   int // | TextDocumentSyncOptions
	send_open_close_notif				 bool = true
	completion_provider                  CompletionOptions
	hover_provider                       bool
	signature_help_provider              SignatureHelpOptions
	declaration_provider                 bool
	definition_provider                  bool
	type_definition_provider             bool
	implementation_provider              bool
	references_provider                  bool
	document_highlight_provider          bool
	document_symbol_provider             bool	// DocumentSymbolOptions 
	code_action_provider                 bool	// CodeActionOptions 
	code_lens_provider                   CodeLensOptions
	document_link_provider               bool   //  DocumentLinkOptions 
	color_provider                       bool
	document_formatting_provider         bool
	document_range_formatting_provider 	 bool // boolean | DocumentRangeFormattingOptions
	document_on_type_formatting_provider DocumentOnTypeFormattingOptions
	rename_provider                      bool // RenameOptions
	folding_range_provider               bool
	execute_command_provider             string // ExecuteCommandOptions
	selection_range_provider 			 bool
	linked_editing_range_provider 		 bool
	call_hierarchy_provider 			 bool
	semantic_tokens_provider 			 bool // SemanticTokensOptions | SemanticTokensRegistrationOptions;
	moniker_provider 					 bool
	experimental                         map[string]bool
	workspace_symbol_provider            bool
}

pub fn (mut sc ServerCapabilities) from_json(f json2.Any) {
	obj_map := f.as_map()
    for k, v in obj_map {
        match k {
			'textDocumentSync' {
				if v.str().contains('{') {
					sync_opt := json2.decode<TextDocumentSyncOptions>(v.str()) or { TextDocumentSyncOptions{} }
					sc.text_document_sync = sync_opt.change
					sc.send_open_close_notif = sync_opt.open_close
				} else {
					sc.text_document_sync = v.int()	
				}
			}
			'hoverProvider' { sc.hover_provider = v.bool() }
			'completionProvider' { 
				sc.completion_provider = json2.decode<CompletionOptions>(v.str()) or { CompletionOptions{} }
			}
			'signatureHelpProvider' { 
				sc.signature_help_provider = json2.decode<SignatureHelpOptions>(v.str()) or { SignatureHelpOptions{} }
			}
			'definitionProvider' { sc.definition_provider = v.bool() }
			'typeDefinitionProvider' { sc.type_definition_provider = v.bool() }
			'implementationProvider' { sc.implementation_provider = v.bool() }
			'referencesProvider' { sc.references_provider = v.bool() }
			'documentHighlightProvider' { sc.document_highlight_provider = v.bool() }
			'documentSymbolProvider' { sc.document_symbol_provider = v.bool() }
			'workspaceSymbolProvider' { sc.workspace_symbol_provider = v.bool() }
			'codeActionProvider' { sc.code_action_provider = v.bool() }
			'codeLensProvider' { 
				sc.code_lens_provider = json2.decode<CodeLensOptions>(v.str()) or { CodeLensOptions{} }
			}
			'documentFormattingProvider' { sc.document_formatting_provider = v.bool() }
			'documentOnTypeFormattingProvider' {
				sc.document_on_type_formatting_provider = json2.decode<DocumentOnTypeFormattingOptions>(v.str()) or { DocumentOnTypeFormattingOptions{} }
			}
			'renameProvider' { sc.rename_provider = v.bool() }
			'documentLinkProvider' { sc.document_link_provider = v.bool() }
			'colorProvider' { sc.color_provider = v.bool() }
			'declarationProvider' { sc.declaration_provider = v.bool() }
			'executeCommandProvider' { sc.execute_command_provider = v.str() }
			'foldingRangeProvider' { sc.folding_range_provider = v.bool() }
			// 'experimental' { sc.experimental = v.str() }
			
			'documentRangeFormattingProvider' { sc.document_range_formatting_provider = v.bool() }
			'selectionRangeProvider' { sc.selection_range_provider = v.bool() }
			'linkedEditingRangeProvider' { sc.linked_editing_range_provider = v.bool() }
			'callHierarchyProvider' { sc.call_hierarchy_provider = v.bool() }
			'monikerProvider' { sc.moniker_provider = v.bool() }

			else {}
        }
    }
}
