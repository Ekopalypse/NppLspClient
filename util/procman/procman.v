module procman

import os
import net
import util.winapi as api
import lsp { ServerConfig }

pub struct Process {
pub mut:
	exe           string
	args          string
	working_dir   string
	pid           u32
	handle        voidptr
	stdin         voidptr
	stdout        voidptr
	stderr        voidptr
	error_message string
	socket        &net.TcpConn
}

fn (mut proc Process) start() bool {
	mut g_hchild_std_out_wr := voidptr(0)
	mut g_hchild_std_err_wr := voidptr(0)
	mut g_hchild_std_in_rd := voidptr(0)
	mut sa_attr := api.SECURITY_ATTRIBUTES{}

	// Set the bInheritHandle flag so pipe handles are inherited.
	sa_attr.n_length = sizeof(api.SECURITY_ATTRIBUTES)
	sa_attr.b_inherit_handle = true
	sa_attr.lp_security_descriptor = voidptr(0)

	// Create a pipe for the child process's STDOUT.
	if !api.create_pipe(&proc.stdout, &g_hchild_std_out_wr, &sa_attr, 0) {
		proc.error_message = 'Failed to create stdout pipe. Error returned: $winapi_lasterr_str()'
		return false
	}

	// Ensure the read handle to the pipe for STDOUT is not inherited.
	if !api.set_handle_information(proc.stdout, u32(C.HANDLE_FLAG_INHERIT), 0) {
		proc.error_message = 'Failed to set handle information for stdout pipe. Error returned: $winapi_lasterr_str()'
		return false
	}

	// Create a pipe for the child process's STDERR.
	if !api.create_pipe(&proc.stderr, &g_hchild_std_err_wr, &sa_attr, 0) {
		proc.error_message = 'Failed to create stderr pipe. Error returned: $winapi_lasterr_str()'
		return false
	}

	// Ensure the read handle to the pipe for STDERR is not inherited.
	if !api.set_handle_information(proc.stderr, u32(C.HANDLE_FLAG_INHERIT), 0) {
		proc.error_message = 'Failed to set handle information for stderr pipe. Error returned: $winapi_lasterr_str()'
		return false
	}

	// Create a pipe for the child process's STDIN.
	if !api.create_pipe(&g_hchild_std_in_rd, &proc.stdin, &sa_attr, 0) {
		proc.error_message = 'Failed to create stdin pipe. Error returned: $winapi_lasterr_str()'
		return false
	}

	// Ensure the write handle to the pipe for STDIN is not inherited.
	if !api.set_handle_information(proc.stdin, u32(C.HANDLE_FLAG_INHERIT), 0) {
		proc.error_message = 'Failed to set handle information for stdin pipe. Error returned: $winapi_lasterr_str()'
		return false
	}

	cmdline := proc.exe + ' ' + proc.args
	mut proc_info := api.PROCESS_INFORMATION{}
	mut start_info := api.STARTUPINFO{
		lp_title: 0
		lp_reserved: 0
		lp_desktop: 0
		lp_reserved2: 0
	}
	mut success := false

	start_info.cb = sizeof(api.STARTUPINFO)
	start_info.h_std_error = g_hchild_std_err_wr
	start_info.h_std_output = g_hchild_std_out_wr
	start_info.h_std_input = g_hchild_std_in_rd
	start_info.dw_flags |= u32(C.STARTF_USESTDHANDLES | C.STARTF_USESHOWWINDOW)
	start_info.w_show_window = 0

	mut working_dir := voidptr(0)
	if proc.working_dir.len > 0 {
		if os.exists(proc.working_dir) && os.is_dir(proc.working_dir) {
			working_dir = proc.working_dir.to_wide()
		} else {
			proc.error_message = 'Cannot use $proc.working_dir as the working directory for $proc.exe'
			return false
		}
	}

	// Create the child process.
	success = // application name
	// command line
	// process security attributes
	// primary thread security attributes
	// handles are inherited
	// creation flags
	// use parent's environment
	// use parent's current directory
	// STARTUPINFO pointer
	api.create_process(voidptr(0), cmdline, voidptr(0), voidptr(0), true, 0, voidptr(0),
		working_dir, &start_info, &proc_info) // receives PROCESS_INFORMATION
	// If an error occurs, exit the application.
	if !success {
		proc.error_message = 'Error creating process. Error returned: $winapi_lasterr_str()'
		return false
	}

	// Close handles to the pipes no longer needed by the child process.
	// If they are not explicitly closed, there is no way to recognize that the child process has ended.
	api.close_handle(g_hchild_std_out_wr)
	api.close_handle(g_hchild_std_err_wr)
	api.close_handle(g_hchild_std_in_rd)

	proc.handle = proc_info.h_process
	proc.pid = proc_info.dw_process_id
	return true
}

fn (proc Process) still_running() bool {
	exit_code := u32(0)
	api.get_exit_code_process(proc.handle, &exit_code)
	return exit_code == 259
}

fn (mut proc Process) kill() ?bool {
	if !api.terminate_process(proc.handle, 0) {
		mut exit_code := u32(0)
		api.get_exit_code_process(proc.handle, &exit_code)
		if exit_code in [u32(0), 259] {
			return error('FAILED to kill ${proc.pid}. Error returned: $winapi_lasterr_str()')
		}
	}
	return true
}

pub struct ProcessManager {
pub mut:
	running_processes map[string]Process
}

// pub fn (mut pm ProcessManager) start(language string, exe string, args string, mode string) ? {
pub fn (mut pm ProcessManager) start(language string, config ServerConfig) ? {
	pm.check_running_processes()
	if language in pm.running_processes {
		return
	}

	mut process := Process{
		exe: config.executable
		args: config.args
		socket: &net.TcpConn{}
	}
	if !os.exists(config.executable) {
		return error('Cannot find executable: $config.executable')
	}
	if !process.start() {
		return error('$process.error_message')
	}

	if config.mode == 'tcp' {
		connection_string := '$config.host:$config.port'
		mut socket := net.dial_tcp(connection_string) or {
			return error('Unable to connect to $connection_string')
		}
		process.socket = socket
	}

	pm.running_processes[language] = process
}

pub fn (mut pm ProcessManager) check_running_processes() {
	for k, proc in pm.running_processes {
		if !proc.still_running() {
			pm.running_processes.delete(k)
		}
	}
}

pub fn (mut pm ProcessManager) remove(language_server string) {
	if language_server in pm.running_processes {
		pm.running_processes.delete(language_server)
	}
}
