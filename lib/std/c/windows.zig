pub extern "c" fn _errno() *c_int;

pub extern "c" fn _msize(memblock: ?*c_void) usize;
