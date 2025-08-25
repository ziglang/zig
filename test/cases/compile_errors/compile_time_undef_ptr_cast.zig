comptime {
    var undef_ptr: *i32 = undefined;
    const ptr: *i32 = @ptrCast(undef_ptr);
    _ = &undef_ptr;
    _ = ptr;
}

// error
//
// :3:32: error: use of undefined value here causes illegal behavior
