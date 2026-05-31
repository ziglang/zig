comptime {
    const opt_ptr: ?*i32 = null;
    const ptr: *i32 = @ptrCast(opt_ptr);
    _ = ptr;
}

// error
//
// :3:32: error: null pointer casted to type '*i32'
