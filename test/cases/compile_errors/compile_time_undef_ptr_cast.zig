comptime {
    var undef_ptr: *i32 = undefined;
    const ptr = @ptrCast(*i32, undef_ptr);
    _ = ptr;
}

// error
// backend=llvm
// target=native
//
// :3:32: error: use of undefined value here causes undefined behavior
