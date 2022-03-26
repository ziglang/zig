comptime {
    var c_ptr: [*c]u8 = undefined;
    var zig_ptr: *u8 = c_ptr;
    _ = zig_ptr;
}

// implicit casting undefined c pointer to zig pointer
//
// tmp.zig:3:24: error: use of undefined value here causes undefined behavior
