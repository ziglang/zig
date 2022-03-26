comptime {
    var c_ptr: [*c]u8 = 0;
    var zig_ptr: *u8 = c_ptr;
    _ = zig_ptr;
}

// implicit casting null c pointer to zig pointer
//
// tmp.zig:3:24: error: null pointer casted to type '*u8'
