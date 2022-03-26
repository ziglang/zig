export fn entry() void {
    var slice: []i32 = undefined;
    const info = @TypeOf(slice).unknown;
    _ = info;
}

// field access of slices
//
// tmp.zig:3:32: error: type 'type' does not support field access
