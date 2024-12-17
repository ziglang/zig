threadlocal var global: u32 = 23;
threadlocal var global_ptr: *u32 = &global;

pub export fn entry() void {
    if (global_ptr.* != 23) unreachable;
}

// error
// backend=stage2
// target=native
//
// :2:36: error: unable to resolve comptime value
// :2:36: note: global variable initializer must be comptime-known
// :2:36: note: thread local and dll imported variables have runtime-known addresses
