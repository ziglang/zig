export fn x() void {
    var a: *u32 = undefined;
    var b: []anyopaque = undefined;
    b = a;
    _ = &a;
}

// error
// backend=stage2
// target=native
//
// :4:9: error: expected type '[]anyopaque', found '*u32'
