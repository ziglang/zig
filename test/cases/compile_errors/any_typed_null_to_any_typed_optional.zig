pub export fn entry() void {
    var a: ?*anyopaque = undefined;
    a = @as(?usize, null);
}

// error
// backend=stage2
// target=native
//
// :3:9: error: expected type '?*anyopaque', found '?usize'
// :3:9: note: optional type child 'usize' cannot cast into optional type child '*anyopaque'
