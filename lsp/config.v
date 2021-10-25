module lsp
import os
import json

pub struct LanguageFeatures {
pub mut:
	doc_sync_type int
	compl_trigger_chars []string
	sig_help_trigger_chars []string
	sig_help_retrigger_chars []string
}

pub struct ServerConfig {
pub mut:
	pipe string
	executable string
	args []string
	port int
	tcpretries int
	auto_start_server bool
	message_id_counter int = -1
	// initialize_msg_sent bool
	initialized bool
	features LanguageFeatures
}

pub fn (mut sc ServerConfig) get_next_id() int {
	sc.message_id_counter++
	return sc.message_id_counter
}

pub struct Configs {
pub mut:
	version string
	loglevel string
	logpath string
	lspservers map[string]ServerConfig
}

pub fn create_default() string {
	pyls := ServerConfig{
		pipe: 'io or tcp'
		executable: "full path to language server executable"
		args: ["paramters", "passed", "to", "language", "server"]
		auto_start_server: true
	}
	rls := ServerConfig{
		pipe: 'io' 
		executable: "C:\\Users\\XYZ\\.cargo\\bin\\rls.exe"
	}
	lsp_config := Configs {
		version: '0.1'
		loglevel: 'info - not implemented yet'
		logpath: 'full path - can be used to debug lsp. If empty string, no debugging - not implemented yet'
		lspservers: {
			'python': pyls
			'rust': rls
		}
	}
	mut config := json.encode_pretty(lsp_config)
	config = config.replace_each([':\t', ': ', '\n', '\r\n'])
	return config
}

pub fn decode_config(full_file_path string) Configs {
	config := os.read_file(full_file_path) or { '' }
	lsp_config := json.decode(Configs, config) or { Configs{} }
	return lsp_config
}

pub fn is_config_valid(lsp_config Configs) bool {
	return true
}