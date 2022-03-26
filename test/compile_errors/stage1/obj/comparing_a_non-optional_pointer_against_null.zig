export fn entry() void {
    var x: i32 = 1;
    _ = &x == null;
}

// comparing a non-optional pointer against null
//
// tmp.zig:3:12: error: comparison of '*i32' with null
