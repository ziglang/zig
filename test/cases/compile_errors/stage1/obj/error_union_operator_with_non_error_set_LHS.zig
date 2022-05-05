comptime {
    const z = i32!i32;
    var x: z = undefined;
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:15: error: expected error set type, found type 'i32'
