export fn foo() void {
    comptime var a: u8 = 0;
    _ = [0:&a]*u8;
}

export fn baz() void {
    comptime var a: u8 = 0;
    _ = [:&a]*u8;
}
export fn qux() void {
    comptime var a: u8 = 0;
    _ = @Pointer(.many, .{}, *u8, &a);
}

// error
//
// :3:12: error: sentinel contains reference to comptime var
// :2:14: note: 'sentinel' points to comptime var declared here
// :8:11: error: sentinel contains reference to comptime var
// :7:14: note: 'sentinel' points to comptime var declared here
// :12:35: error: sentinel contains reference to comptime var
// :11:14: note: 'sentinel' points to comptime var declared here
