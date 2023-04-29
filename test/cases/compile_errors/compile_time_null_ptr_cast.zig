comptime {
    var opt_ptr: ?*i32 = null;
    const ptr = @ptrCast(*i32, opt_ptr);
    _ = ptr;
}

// error
// backend=llvm
// target=native
//
// :3:32: error: null pointer casted to type '*i32'
