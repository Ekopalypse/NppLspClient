module lsp
import os

import winapi as api

pub enum ProcessStatus {
	running
	error_no_executable
	failed_to_start
}

pub struct Process {
pub mut:
	exe string
	args string
	pid u32
	handle voidptr
	stdin voidptr
	stdout voidptr
}

pub struct ProcessManager {
pub mut:
	process_list []Process
	running_processes map[string]Process
}

pub fn (mut pm ProcessManager) start(language string, exe string, args string) ProcessStatus {
	p.console_window.log('ProcessManager start $exe $args', 0)
	pm.check_running_processes()
	if language in pm.running_processes { return ProcessStatus.running }
	if !os.exists(exe) { return ProcessStatus.error_no_executable }
	
	mut process := pm.create_child_process(exe, args)
	if process.pid != 0 {
		pm.running_processes[language] = process
		go read_from(process.stdout, p.message_queue)
		return ProcessStatus.running
	}
	return ProcessStatus.failed_to_start
}

pub fn (mut pm ProcessManager) stop(language string) {
	if language !in pm.running_processes { return }
	write_to(pm.running_processes[language].stdin, lsp.exit_msg())
	write_to(pm.running_processes[language].stdin, lsp.shutdown_msg())
	pm.running_processes.delete(language)
}

pub fn (mut pm ProcessManager) stop_all_running_processes() {
	for k, _ in pm.running_processes {
		pm.stop(k)
	}
}

fn (pm ProcessManager) create_child_process(exe string, args string) Process {
	p.console_window.log('create_child_process $exe $args', 0)
	mut process := Process{
		exe: exe
		args: args
	}
	
	mut g_hchild_std_out_wr := voidptr(0)
	mut g_hchild_std_in_rd := voidptr(0)
	mut sa_attr := api.SECURITY_ATTRIBUTES{}

	// Set the bInheritHandle flag so pipe handles are inherited.
	sa_attr.n_length = sizeof(api.SECURITY_ATTRIBUTES)
	sa_attr.b_inherit_handle = true
	sa_attr.lp_security_descriptor = voidptr(0)
	// Create a pipe for the child process's STDOUT.
	if ! api.create_pipe(&process.stdout, &g_hchild_std_out_wr, &sa_attr, 0) { 
		// show_error_message('FAILED to create Stdout pipe')
		return Process{}
	}
	// Ensure the read handle to the pipe for STDOUT is not inherited.
	if ! api.set_handle_information(process.stdout, u32(C.HANDLE_FLAG_INHERIT), 0) {
		// show_error_message('FAILED to SetHandleInformation Stdout')
		return Process{}
	}
	// Create a pipe for the child process's STDIN.
	if ! api.create_pipe(&g_hchild_std_in_rd, &process.stdin, &sa_attr, 0) {
		// show_error_message('FAILED to create Stdin pipe')
		return Process{}
	}
	// Ensure the write handle to the pipe for STDIN is not inherited.
	if ! api.set_handle_information(process.stdin, u32(C.HANDLE_FLAG_INHERIT), 0) {
		// p.logging('  FAILED to SetHandleInformation Stdout')
		return Process{}
	}
	
	mut proc_info := api.PROCESS_INFORMATION{}
	mut start_info := api.STARTUPINFO{
		lp_title: 0
		lp_reserved: 0
		lp_desktop: 0
		lp_reserved2: 0
	}
	mut success := false

	start_info.cb = sizeof(api.STARTUPINFO)
	start_info.h_std_error = g_hchild_std_out_wr
	start_info.h_std_output = g_hchild_std_out_wr
	start_info.h_std_input = g_hchild_std_in_rd
	start_info.dw_flags |= u32(C.STARTF_USESTDHANDLES | C.STARTF_USESHOWWINDOW)
	start_info.w_show_window = 0
	// Create the child process.
	success = api.create_process(
		voidptr(0),							// application name
		'${process.exe} ${process.args}',	// command line
		voidptr(0),							// process security attributes
		voidptr(0),							// primary thread security attributes
		true,								// handles are inherited
		0,									// creation flags
		voidptr(0),							// use parent's environment
		voidptr(0),							// use parent's current directory
		&start_info,						// STARTUPINFO pointer
		&proc_info)							// receives PROCESS_INFORMATION

	if success {
		// Close handles to the stdin and stdout pipes no longer needed by the child process.
		// If they are not explicitly closed, there is no way to recognize that the child process has ended.
		api.close_handle(g_hchild_std_out_wr)
		api.close_handle(g_hchild_std_in_rd)
		
		process.handle = proc_info.h_process
		process.pid = proc_info.dw_process_id
		return process
	} else {
		error_message := os.get_error_msg(api.get_last_error())
		p.console_window.log('create_child_process returned: $error_message', 4)
	}
	return Process{}
}

pub fn (mut pm ProcessManager) check_running_processes() {
	exit_code := u32(0)
	for k, v in pm.running_processes {
		api.get_exit_code_process(v.handle, &exit_code)
		if exit_code != 259 {   // 259 == still active
			pm.running_processes.delete(k) 
		}
	}
}
