fn dump(anytype) void {}
export fn entry() void {
    var a: u8 = 9;
    dump(a);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:9: error: missing parameter name
