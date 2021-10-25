module lsp
import notepadpp
import winapi { read_file, write_file, send_message }

pub const (
	bufsize = 4096 
	new_message = 1
	pipe_closed = 2
	new_message_arrived = notepadpp.CommunicationInfo{
		internal_msg: new_message
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
fn read_from(pipe voidptr, msg_queue chan string) {
	mut dw_read := u32(0)
	mut buffer := [bufsize]i8{}
	mut success := false
	for {
		success = read_file(pipe, &buffer[0], bufsize, &dw_read, voidptr(0))
		if ! success || dw_read == 0 { break }
		content := unsafe { tos(&buffer[0], int(dw_read)) }

		_ := msg_queue.try_push(content)
		send_message(
			npp_data.npp_handle, 
			notepadpp.nppm_msgtoplugin, 
			usize('${p.name}.dll'.to_wide()),
			isize(&new_message_arrived)
		)
	}
	send_message(
		npp_data.npp_handle, 
		notepadpp.nppm_msgtoplugin, 
		usize('${p.name}.dll'.to_wide()),
		isize(&pipe_closed_event)
	)	
}

// write_to stdin - main thread
pub fn write_to(pipe voidptr, message string) bool {
	if pipe == voidptr(0) {
		p.console_window.log('ERROR: attempt to write to non-existent pipe\n: $message', 4)
		return false
	}
	
	p.console_window.log('$message', 1)
	mut dw_written := u32(0)
	mut success := false
	success = write_file(pipe, message.str, u32(message.len), &dw_written, voidptr(0))

	if !success {
		p.console_window.log('writing to pipe failed\n $message', 4)
		return false
	} else

	if dw_written != message.len {
		p.console_window.log('writing to pipe incomplete!!: written=$dw_written expected=${message.len}\n $message', 4)
		return false
	}
	return true
}
