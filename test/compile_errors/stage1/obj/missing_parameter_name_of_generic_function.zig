fn dump(anytype) void {}
export fn entry() void {
    var a: u8 = 9;
    dump(a);
}

// missing parameter name of generic function
//
// tmp.zig:1:9: error: missing parameter name
