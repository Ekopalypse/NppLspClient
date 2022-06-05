module common

pub struct Symbol {
pub:
	file_name string
	name      string
	kind      int
	line      u32
	parent    string
	// children []Symbol
}

pub struct Reference {
pub:
	file_name string
	line      u32
}

pub struct DiagMessage {
pub:
	file_name string
	line      u32
	column    u32
	message   string
	severity  byte
}
