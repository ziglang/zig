const MyStruct = struct { x: bool = false };

comptime {
    const x = &[_]MyStruct{ .{}, .{} };
    const y = x[0..1] ++ &[_]MyStruct{};
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :5:16: error: comptime dereference requires '[1]tmp.MyStruct' to have a well-defined layout, but it does not.
