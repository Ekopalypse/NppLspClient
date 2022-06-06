module lsp

import x.json2

// used for decoding
struct JsonMessage {
pub mut:
	jsonrpc string
	// all
	method string
	// request and notification
	id string
	// request and response
	params string
	// request and notification
	result string
	// response
	error string
	// response
}

pub fn (mut m JsonMessage) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'jsonrpc' {
				m.jsonrpc = v.str()
			}
			'method' {
				m.method = v.str()
			}
			'id' {
				m.id = if v.type_name() == 'string' {
					'"$v.str()"'
				} else {
					v.str()
				}
			}
			'params' {
				m.params = v.str()
			}
			'result' {
				m.result = v.str()
			}
			'error' {
				m.error = v.str()
			}
			else {}
		}
	}
}

type DocumentUri = string

fn make_path(uri string) string {
	return uri.all_after('file:///').replace_each(['/', '\\', '%3A', ':'])
}

fn make_uri(path string) string {
	escaped := path.replace_each(['\\', '/', ':', '%3A'])
	return 'file:///$escaped'
}

fn make_range(start_line u32, start_char u32, end_line u32, end_char u32) string {
	return '"range":{"start":{"line":$start_line,"character":$start_char},"end":{"line":$end_line,"character":$end_char}}'
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
	line      u32
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
	end   Position
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
	uri   DocumentUri
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
			'originSelectionRange' {
				ll.origin_selection_range = json2.decode<Range>(v.str()) or { Range{} }
			}
			'targetUri' {
				ll.target_uri = make_path(v.str())
			}
			'targetRange' {
				ll.target_range = json2.decode<Range>(v.str()) or { Range{} }
			}
			'targetSelectionRange' {
				ll.target_selection_range = json2.decode<Range>(v.str()) or { Range{} }
			}
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
	range    Range
	severity int
	// DiagnosticSeverity
	code             string
	code_description string
	// CodeDescription
	source  string
	message string
	tags    string
	// []DiagnosticTag
	related_information string
	// []DiagnosticRelatedInformation
	data string
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
	message  string
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
pub mut:
	uri         DocumentUri
	version     u32
	diagnostics []Diagnostic
}

pub fn (mut pd PublishDiagnosticsParams) from_json(f json2.Any) {
	obj_map := f.as_map()
	for k, v in obj_map {
		match k {
			'uri' {
				pd.uri = make_path(v.str())
			}
			'version' {
				pd.version = u32(v.int())
			}
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
	items         []CompletionItem
}

pub fn (mut cl CompletionList) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'is_incomplete' {
				cl.is_incomplete = v.bool()
			}
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
	label                 string
	label_details         string
	kind                  string
	tags                  string
	detail                string
	documentation         string
	deprecated_           bool
	preselect             bool
	sort_text             string
	filter_text           string
	insert_text           string
	insert_text_format    string
	insert_text_mode      string
	text_edit             string
	additional_text_edits string
	commit_characters     string
	command               string
	data                  string
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
	signatures       []SignatureInformation
	active_signature u32
	active_parameter u32
}

pub fn (mut sh SignatureHelp) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'signatures' {
				for item in v.arr() {
					sh.signatures << json2.decode<SignatureInformation>(item.str()) or {
						SignatureInformation{}
					}
				}
			}
			'activeSignature' {
				sh.active_signature = u32(v.int())
			}
			'activeParameter' {
				sh.active_parameter = u32(v.int())
			}
			else {}
		}
	}
}

pub struct SignatureInformation {
pub mut:
	label            string
	documentation    string
	parameters       []ParameterInformation
	active_parameter u32
}

pub fn (mut si SignatureInformation) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'label' {
				si.label = v.str()
			}
			'documentation' {
				si.documentation = v.str()
			}
			'parameters' {
				for item in v.arr() {
					si.parameters << json2.decode<ParameterInformation>(item.str()) or {
						ParameterInformation{}
					}
				}
			}
			'activeParameter' {
				si.active_parameter = u32(v.int())
			}
			else {}
		}
	}
}

pub struct ParameterInformation {
pub mut:
	label         string
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
	range    Range
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
	type_   int
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
	type_   int
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
	kind int
	// DocumentHighlightKind
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
	kind int
	// SymbolKind
	// Tags for this document symbol.
	// @since 3.16.0
	tags []int
	// SymbolTag[]
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
	selection_range Range
	// selectionRange
	// Children of this symbol, e.g. properties of a class.
	children []DocumentSymbol
}

pub fn (mut ds DocumentSymbol) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'name' {
				ds.name = v.str()
			}
			'detail' {
				ds.detail = v.str()
			}
			'kind' {
				ds.kind = v.int()
			}
			'tags' {
				ds.tags << v.arr().map(it.int())
			}
			'deprecated' {
				ds.deprecated = v.bool()
			}
			'range' {
				ds.range = json2.decode<Range>(v.str()) or { Range{} }
			}
			'selectionRange' {
				ds.selection_range = json2.decode<Range>(v.str()) or { Range{} }
			}
			'children' {
				for item in v.arr() {
					ds.children << json2.decode<DocumentSymbol>(item.str()) or { DocumentSymbol{} }
				}
			}
			else {}
		}
	}
}

pub struct SymbolInformation {
pub mut:
	// The name of this symbol.
	name string
	// The kind of this symbol.
	kind int
	// SymbolKind
	// Tags for this symbol.
	// @since 3.16.0
	tags []int
	// SymbolTag
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
	container_name string
	// containerName
}

pub fn (mut si SymbolInformation) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'name' { si.name = v.str() }
			'kind' { si.kind = v.int() }
			'tags' { si.tags << v.arr().map(it.int()) }
			'deprecated' { si.deprecated = v.bool() }
			'location' { si.location = json2.decode<Location>(v.str()) or { Location{} } }
			'containerName' { si.container_name = v.str() }
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
	contents string
	// MarkedString | MarkedString[] | MarkupContent
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
			'range' {
				h.range = json2.decode<Range>(v.str()) or { Range{} }
			}
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
	// The token to be used to report progress.
	token string
}

pub fn (mut wdpcp WorkDoneProgressCreateParams) from_json(f json2.Any) {
	wdpcp.token = f.str()
}

pub struct WorkDoneProgressCancelParams {
pub mut:
	// The token to be used to report progress.
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
	obj := f.as_map()
	for k, v in obj {
		match k {
			'registrations' {
				rp.registrations = v.arr().map(json2.decode<Registration>(it.str()) or {
					Registration{}
				})
			}
			else {}
		}
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
	obj := f.as_map()
	for k, v in obj {
		match k {
			'unregistrations' {
				up.unregistrations = v.arr().map(json2.decode<Unregistration>(it.str()) or {
					Unregistration{}
				})
			}
			else {}
		}
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

pub struct ColorInformationArray {
pub mut:
	items []ColorInformation
}

pub fn (mut cia ColorInformationArray) from_json(f json2.Any) {
	items := f.arr()
	for item in items {
		cia.items << json2.decode<ColorInformation>(item.str()) or { ColorInformation{} }
	}
}

pub struct ColorInformation {
pub mut:
	// The range in the document where this color appears.
	range Range
	// The actual color value for this color range.
	color Color
}

pub fn (mut ci ColorInformation) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'range' { ci.range = json2.decode<Range>(v.str()) or { Range{} } }
			'color' { ci.color = json2.decode<Color>(v.str()) or { Color{} } }
			else {}
		}
	}
}

pub struct Color {
pub mut:
	// The red component of this color in the range [0-1].
	red f32
	// The green component of this color in the range [0-1].
	green f32
	// The blue component of this color in the range [0-1].
	blue f32
	// The alpha component of this color in the range [0-1].
	alpha f32
}

pub fn (mut c Color) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'red' { c.red = v.f32() }
			'green' { c.green = v.f32() }
			'blue' { c.blue = v.f32() }
			'alpha' { c.alpha = v.f32() }
			else {}
		}
	}
}

pub struct ColorPresentationArray {
pub mut:
	items []ColorPresentation
}

pub fn (mut cpa ColorPresentationArray) from_json(f json2.Any) {
	items := f.arr()
	for item in items {
		cpa.items << json2.decode<ColorPresentation>(item.str()) or { ColorPresentation{} }
	}
}

pub struct ColorPresentation {
pub mut:
	// The label of this color presentation. It will be shown on the color
	// picker header. By default this is also the text that is inserted when
	// selecting this color presentation.
	label string
	// An [edit](#TextEdit) which is applied to a document when selecting
	// this presentation for the color. When `falsy` the
	// [label](#ColorPresentation.label) is used.
	text_edit TextEdit
	// An optional array of additional [text edits](#TextEdit) that are applied
	// when selecting this color presentation.
	// Edits must not overlap with the main [edit](#ColorPresentation.textEdit) nor with themselves.
	additional_text_edits []TextEdit
}

pub fn (mut cp ColorPresentation) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'label' {
				cp.label = v.str()
			}
			'TextEdit' {
				cp.text_edit = json2.decode<TextEdit>(v.str()) or { TextEdit{} }
			}
			'additionalTextEdits' {
				text_edit_array := json2.decode<TextEditArray>(v.str()) or { TextEditArray{} }
				for item in text_edit_array.items {
					cp.additional_text_edits << item
				}
			}
			else {}
		}
	}
}

pub struct WorkspaceFolder {
pub mut:
	uri  string
	name string
}

pub struct WorkspaceFolderArray {
pub mut:
	folders []WorkspaceFolder
}

fn (wfa WorkspaceFolderArray) make_lsp_message() string {
	mut folders__ := []string{}
	for folder in wfa.folders {
		uri_path := make_uri(folder.uri)
		folders__ << '{"uri":"$uri_path","name":"$folder.name"}'
	}
	return '[${folders__.join(',')}]'
}

pub struct FileEvent {
pub mut:
	uri    string
	type__ u32
}

pub struct FileEventArray {
pub mut:
	events []FileEvent
}

fn (fea FileEventArray) make_lsp_message() string {
	mut changes := []string{}
	for event in fea.events {
		uri_path := make_uri(event.uri)
		changes << '{"uri":"$uri_path","type":event.type__}'
	}
	return '[${changes.join(',')}]'
}

pub struct FileCreateArray {
pub mut:
	files []FileCreate
}

fn (fca FileCreateArray) make_lsp_message() string {
	mut files__ := []string{}
	for f in fca.files {
		uri_path := make_uri(f.uri)
		files__ << '{"uri":"$uri_path"}'
	}
	return '[${files__.join(',')}]'
}

pub struct FileDeleteArray {
pub mut:
	files []FileDelete
}

fn (fda FileDeleteArray) make_lsp_message() string {
	mut files__ := []string{}
	for f in fda.files {
		uri_path := make_uri(f.uri)
		files__ << '{"uri":"$uri_path"}'
	}
	return '[${files__.join(',')}]'
}

pub struct FileRenameArray {
pub mut:
	files []FileRename
}

fn (fra FileRenameArray) make_lsp_message() string {
	mut files__ := []string{}
	for f in fra.files {
		old_uri_path := make_uri(f.old_uri)
		new_uri_path := make_uri(f.new_uri)
		files__ << '{"oldUri":"$old_uri_path","newUri":"$new_uri_path"}'
	}
	return '[${files__.join(',')}]'
}

pub struct ConfigurationItem {
pub mut:
	// The scope to get the configuration section for.
	scope_uri string
	//  scopeUri DocumentUri
	// The configuration section asked for.
	section string
}

pub fn (mut ci ConfigurationItem) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'scopeUri' { ci.scope_uri = v.str() }
			'section' { ci.section = v.str() }
			else {}
		}
	}
}

pub struct ConfigurationParams {
pub mut:
	items []ConfigurationItem
}

pub fn (mut cp ConfigurationParams) from_json(f json2.Any) {
	obj := f.as_map()
	for k, v in obj {
		match k {
			'items' {
				cp.items = v.arr().map(json2.decode<ConfigurationItem>(it.str()) or {
					ConfigurationItem{}
				})
			}
			else {}
		}
	}
}
