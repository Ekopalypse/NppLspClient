module lsp

import toml
import os
import util.winapi { message_box }

const (
	example_config_content = '
[general]
diag_indicator_id = 12  # indicator used to draw the squiggle lines
# the following colors, hex notation of a rgb value, are used by the diagnostics indicator, the annotation method and the console output window
error_color = 0x756ce0  # values must be in the range 0 - 0xffffff
warning_color = 0x64e0ff  # values must be in the range 0 - 0xffffff
# these three colors are only used in the lsp console window
incoming_msg_color = 0x7bc399  # values must be in the range 0 - 0xffffff
outgoing_msg_color = 0xffac59  # values must be in the range 0 - 0xffffff
selected_text_color = 0x745227  # values must be in the range 0 - 0xffffff

highlight_indicator_id = 13  # indicator used to highlights all references to the symbol scoped to this file
highlight_indicator_color = 0x64e0ff  # values must be in the range 0 - 0xffffff

# define only if themes default fore- and background colors should be replaced
# calltip_foreground_color = -1  # values must be in the range -1 - 0xffffff
# calltip_background_color = -1  # values must be in the range -1 - 0xffffff

# enable or disable logging functionality
enable_logging = false  # values must be either false or true

# each configured lanugage server needs to start with a section called
# [lspservers.NAME_OF_THE_LANGUAGE_SERVER] eg. [lspservers.python]
# the NAME_OF_THE_LANGUAGE_SERVER must be the same as displayed in the language menu
# if the name contains non ASCII letters like C++, then it needs to be encased in double quotes like
# [lspservers."c++"]

# Currently, four attributes can be set, which are listed below
# mode - Note, ONLY IO is implemented currently, value encased in a double quotes.
# e.g.  mode = "io"

# executable - the full path to the language server executable encased in SINGLE quotes.
# e.g.  executable = \'D:\ProgramData\Python\Python38_64\Scripts\pyls.exe\'

# args - arguments passed to the language server executable encased in SINGLE quotes.
# e.g.  args = \'--check-parent-process --log-file D:\log.txt -vvv\'

# auto_start_server - true or false; indicates whether the language server will be started automatically when a corresponding document gets opened.
# NOTE: currently only false should be used
# e.g.  auto_start_server = false

# language server configuration example
# [lspservers.python]
# mode = "io"
# executable = \'D:\ProgramData\Python\Python38_64\Scripts\pyls.exe\'
# args = \'--check-parent-process --log-file D:\log.txt -vvv\'
# auto_start_server = false	
'
)

pub struct ServerConfig {
mut:
	message_id_counter int = -1
pub mut:
	mode string
	executable string
	args string
	port int
	tcpretries int
	auto_start_server bool
	initialized bool
	// open_documents []string  // used to prevent sending didOpen multiple times
	features ServerCapabilities
	open_response_messages map[string]fn(json_message string)
	// diag_messages map[string][]Diagnostic
}

pub fn (mut sc ServerConfig) get_next_id() string {
	sc.message_id_counter++
	return sc.message_id_counter.str()
}

pub fn (mut sc ServerConfig) init_id() string {
	sc.message_id_counter = 0
	return sc.message_id_counter.str()
}


pub struct Configs {
pub mut:
	diag_indicator_id int = 12
	error_color int = 0x756ce0
	warning_color int = 0x64e0ff
	incoming_msg_color int = 0x7bc399
	outgoing_msg_color int = 0xffac59
	selected_text_color int = 0x745227
	enable_logging bool
	lspservers map[string]ServerConfig
	calltip_foreground_color int = -1
	calltip_background_color int = -1
	highlight_indicator_id int = 13
	highlight_indicator_color int = 0x64e0ff
}
	
pub fn create_default() string {
	return example_config_content
}

fn is_null(item toml.Any) bool {
	return item == toml.Any(toml.Null{})
}

pub fn decode_config(full_file_path string) Configs {
	mut failed := false
	content := os.read_file(full_file_path) or { '' }
	doc := toml.parse(content) or { 
		failed = true
		toml.parse('') or { panic(err) }
	}
	
	mut lsp_config := Configs{}
	if failed { 
		p.console_window.log_error('error decoding the configuration file')
		analyze_config(full_file_path)
		return lsp_config
	}
	
	if doc.value('general').string().len == 0 {
		message_box(p.npp_data.npp_handle, 'Configuration file is missing the general section', 'ERROR', 3)
		return lsp_config
	}
	
	if !is_null(doc.value('general.diag_indicator_id')) {
		lsp_config.diag_indicator_id = doc.value('general.diag_indicator_id').int()
	}

	if !is_null(doc.value('general.error_color')) {
		lsp_config.error_color = doc.value('general.error_color').int()
	}

	if !is_null(doc.value('general.warning_color')) {
		lsp_config.warning_color = doc.value('general.warning_color').int()
	}

	if !is_null(doc.value('general.outgoing_msg_color')) {
		lsp_config.outgoing_msg_color = doc.value('general.outgoing_msg_color').int()
	}
	
	if !is_null(doc.value('general.incoming_msg_color')) {
		lsp_config.incoming_msg_color = doc.value('general.incoming_msg_color').int()
	}
	
	if !is_null(doc.value('general.selected_text_color')) {
		lsp_config.selected_text_color = doc.value('general.selected_text_color').int()
	}
	
	if !is_null(doc.value('general.enable_logging')) {
		lsp_config.enable_logging =	doc.value('general.enable_logging').bool()
	}

	if !is_null(doc.value('general.calltip_foreground_color')) {
		lsp_config.calltip_foreground_color = doc.value('general.calltip_foreground_color').int()
	}
	
	if !is_null(doc.value('general.calltip_background_color')) {
		lsp_config.calltip_background_color = doc.value('general.calltip_background_color').int()
	}

	if !is_null(doc.value('general.highlight_indicator_id')) {
		lsp_config.highlight_indicator_id = doc.value('general.highlight_indicator_id').int()
	}

	if !is_null(doc.value('general.highlight_indicator_color')) {
		lsp_config.highlight_indicator_color = doc.value('general.highlight_indicator_color').int()
	}

	// lspservers
	for k, _ in doc.value('lspservers').as_map() {
		if k != '0' {
			mut sc := ServerConfig{}
			if is_null(doc.value('lspservers.${k}.mode')) {
				p.console_window.log_error('$k - mandatory field missing: mode')
				continue
			}
			sc.mode = doc.value('lspservers.${k}.mode').string()
			
			if is_null(doc.value('lspservers.${k}.executable')) {
				p.console_window.log_error('$k - mandatory field missing: executable')
				continue
			}
			sc.executable = doc.value('lspservers.${k}.executable').string()
			
			if !is_null(doc.value('lspservers.${k}.args')) {
				sc.args = doc.value('lspservers.${k}.args').string()
			}
			
			if !is_null(doc.value('lspservers.${k}.auto_start_server')) {
				sc.auto_start_server = doc.value('lspservers.${k}.auto_start_server').bool()
			}
			
			if !is_null(doc.value('lspservers.${k}.port')) {
				sc.port = doc.value('lspservers.${k}.port').int()
			}
			
			if !is_null(doc.value('lspservers.${k}.tcpretries')) {
				sc.tcpretries = doc.value('lspservers.${k}.tcpretries').int()
			}
			
			lsp_config.lspservers[k] = sc
		}
	}
	if lsp_config.lspservers.len == 0 {
		p.console_window.log_error('cannot identify any configured language server')
		p.console_window.log_warning('$lsp_config')
	}
	return lsp_config
}

pub fn analyze_config(full_file_path string) {
	p.console_window.log_error('Analyzing: $full_file_path')
	content := os.read_file(full_file_path) or { '' }
	if content.len == 0 {
		p.console_window.log_error('Config file: $full_file_path seems to be empty')
	}
	
	mut in_general_section := false
	mut in_lspservers_section := false
	for line in content.split_into_lines() {
		p.console_window.log_info('line: $line')
		if line.starts_with('#') || line.trim_space().len == 0 { continue }
		match true {
			line.starts_with('[general]') {
				in_lspservers_section = false
				in_general_section = true
			}
			line.starts_with('[lspservers') {
				in_general_section = false
				in_lspservers_section = true
			}
			line.starts_with('diag_indicator_id') {
				if in_general_section {
					check_if_integer_value(line)
				} else {
					p.console_window.log_error('diag_indicator_id must be a field in general section')
				}
			}
			line.starts_with('error_color') {
				if in_general_section {
					check_if_integer_value(line)
				} else {
					p.console_window.log_error('error_color must be a field in general section')
				}
			}
			line.starts_with('warning_color') {
				if in_general_section {
					check_if_integer_value(line)
				} else {
					p.console_window.log_error('warning_color must be a field in general section')
				}
			}
			line.starts_with('incoming_msg_color') {
				if in_general_section {
					check_if_integer_value(line)
				} else {
					p.console_window.log_error('incoming_msg_color must be a field in general section')
				}
			}
			line.starts_with('outgoing_msg_color') {
				if in_general_section {
					check_if_integer_value(line)
				} else {
					p.console_window.log_error('outgoing_msg_color must be a field in general section')
				}
			}
			line.starts_with('selected_text_color') {
				if in_general_section {
					check_if_integer_value(line)
				} else {
					p.console_window.log_error('selected_text_color must be a field in general section')
				}
			}
			line.starts_with('enable_logging') {
				if in_general_section {
					check_if_boolean_value(line)
				} else {
					p.console_window.log_error('enable_logging must be a field in general section')
				}
			}
			line.starts_with('calltip_foreground_color') {
				if in_general_section {
					check_if_integer_value(line)
				} else {
					p.console_window.log_error('calltip_foreground_color must be a field in general section')
				}
			}
			line.starts_with('calltip_background_color') {
				if in_general_section {
					check_if_integer_value(line)
				} else {
					p.console_window.log_error('calltip_background_color must be a field in general section')
				}
			}
			line.starts_with('mode') {
				if in_lspservers_section {
					check_if_string_value(line)
				} else {
					p.console_window.log_error('mode must be in lspservers section')
				}
			}
			line.starts_with('executable') {
				if in_lspservers_section {
					check_if_string_value(line)
				} else {
					p.console_window.log_error('executable must be in lspservers section')
				}
			}
			line.starts_with('args') {
				if in_lspservers_section {
					check_if_string_value(line)
				} else {
					p.console_window.log_error('args must be in lspservers section')
				}
			}
			line.starts_with('auto_start_server') {
				if in_lspservers_section {
					check_if_boolean_value(line)
				} else {
					p.console_window.log_error('auto_start_server must be in lspservers section')
				}
			}
			line.starts_with('highlight_indicator_id') {
				if in_general_section {
					check_if_integer_value(line)
				} else {
					p.console_window.log_error('highlight_indicator_id must be a field in general section')
				}
			}
			line.starts_with('highlight_indicator_color') {
				if in_general_section {
					check_if_integer_value(line)
				} else {
					p.console_window.log_error('highlight_indicator_color must be a field in general section')
				}
			}
			else {
				p.console_window.log_error('unexpected line read: $line')
			}
		}
	}
}

fn strip_added_comment(line string) string {
	return line.all_before('#')
}

fn check_if_boolean_value(line string) {
	parts := strip_added_comment(line).split('=')
	if parts.len != 2 {
		p.console_window.log_error('$line\nexpected key=value scheme but received: ${parts.join("=")}')
	}
	trimmed_string := parts[1].trim_space()
	if trimmed_string != 'false' && trimmed_string != 'true' {
		p.console_window.log_error('$line\nvalue must be either false or true but received: ${parts[1]}')
	}
}

fn check_if_integer_value(line string) {
	parts := strip_added_comment(line).split('=')
	if parts.len != 2 {
		p.console_window.log_error('$line\nexpected key=value scheme but received: ${parts.join("=")}')
	}
	trimmed_string := parts[1].trim_space()
	if trimmed_string.u64() == 0 {
		if trimmed_string != '0' && trimmed_string.to_lower() != '0x0' {
			p.console_window.log_error('$line\nvalue must be an integer but received: ${trimmed_string}')
		}
	}
}

fn check_if_string_value(line string) {
	stripped_line := strip_added_comment(line)
	// key := stripped_line.all_before('=').trim_space()
	value := stripped_line.all_after('=').trim_space()

	start_quote := value[0].ascii_str()
	end_quote := value[value.len-1].ascii_str()

	if start_quote in ["'", '"'] && end_quote in ["'", '"'] {
		if start_quote != end_quote {
			p.console_window.log_error('$line\nvalue must be using the same start and end quotes but received: $line')
		}
	} else {
		p.console_window.log_error('$line\nvalue must be a quotted string but received: $line')
	}
}