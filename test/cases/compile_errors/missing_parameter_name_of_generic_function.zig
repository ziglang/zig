fn dump(anytype) void {}
export fn entry() void {
    var a: u8 = 9;
    dump((&a).*);
}

// error
//
// :1:9: error: missing parameter name
