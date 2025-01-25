const A = struct {};
const B = struct {};
comptime {
    const val: [1]A = .{.{}};
    const ptr: *const [1]B = @ptrCast(&val);
    _ = ptr ** 2;
}

// error
//
// :6:9: error: comptime dereference requires '[1]tmp.B' to have a well-defined layout
