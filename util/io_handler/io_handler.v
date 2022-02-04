module io_handler
import notepadpp
import util.winapi { read_file, write_file, send_message }

pub const (
	bufsize = 4096 
	new_message = 1
	pipe_closed = 2
	new_err_message = 3
	new_message_arrived = notepadpp.CommunicationInfo{
		internal_msg: new_message
		src_module_name: 0
		info: 0
	}
	new_err_message_arrived = notepadpp.CommunicationInfo{
		internal_msg: new_err_message
		src_module_name: 0
		info: 0
	}
	pipe_closed_event = notepadpp.CommunicationInfo{
		internal_msg: pipe_closed
		src_module_name: 0
		info: 0
	}	
)

// read_from stdout runs on a different thread, using p.console_window.log is not safe !!
pub fn read_from_stdout(pipe voidptr, msg_queue chan string) {
	mut dw_read := u32(0)
	mut buffer := [bufsize]i8{}
	mut success := false
	for {
		success = read_file(pipe, &buffer[0], bufsize, &dw_read, voidptr(0))
		if ! success || dw_read == 0 { break }
		content := unsafe { tos(&buffer[0], int(dw_read)) }

		_ := msg_queue.try_push(content)
		send_message(
			p.npp_data.npp_handle, 
			notepadpp.nppm_msgtoplugin, 
			usize('${p.name}.dll'.to_wide()),
			isize(&new_message_arrived)
		)
	}
	send_message(
		p.npp_data.npp_handle, 
		notepadpp.nppm_msgtoplugin, 
		usize('${p.name}.dll'.to_wide()),
		isize(&pipe_closed_event)
	)	
}

pub fn read_from_stderr(pipe voidptr, msg_queue chan string) {
	mut dw_read := u32(0)
	mut buffer := [bufsize]i8{}
	mut success := false
	for {
		success = read_file(pipe, &buffer[0], bufsize, &dw_read, voidptr(0))
		if ! success || dw_read == 0 { break }
		content := unsafe { tos(&buffer[0], int(dw_read)) }

		if p.lsp_config.enable_logging {
			_ := msg_queue.try_push(content)
			send_message(
				p.npp_data.npp_handle, 
				notepadpp.nppm_msgtoplugin, 
				usize('${p.name}.dll'.to_wide()),
				isize(&new_err_message_arrived)
			)
		}
	}
	send_message(
		p.npp_data.npp_handle, 
		notepadpp.nppm_msgtoplugin, 
		usize('${p.name}.dll'.to_wide()),
		isize(&pipe_closed_event)
	)	
}

// write_to stdin - main thread
pub fn write_to(message string) bool {
	if p.proc_manager.running_processes[p.current_language].stdin == voidptr(0) {
		p.console_window.log_error('ERROR: attempt to write to non-existent pipe\n: $message')
		return false
	}
	p.console_window.log_outgoing('$message')
	mut dw_written := u32(0)
	mut success := false
	success = write_file(p.proc_manager.running_processes[p.current_language].stdin, 
						 message.str, 
						 u32(message.len), 
						 &dw_written, 
						 voidptr(0))

	if !success {
		p.console_window.log_error('writing to pipe failed\n $message')
		return false
	} else

	if dw_written != message.len {
		p.console_window.log_error('writing to pipe incomplete!!: written=$dw_written expected=${message.len}\n $message')
		return false
	}
	return true
}

pub fn write_to_socket(socket voidptr, message string) bool {
	return false
}

fn read_from_socket(socket voidptr, msg_queue chan string) {
	
}