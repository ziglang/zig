pub export fn entry1() void {
    const x: usize = 5;

    const ptr: *const anyopaque = &(&x);
    _ = ptr;
}
pub export fn entry2() void {
    var val: [*:0]u8 = undefined;
    func(&val);
}
fn func(_: ?*anyopaque) void {}
pub export fn entry3() void {
    var x: *?*usize = undefined;

    const ptr: *const anyopaque = x;
    _ = ptr;
}

// error
// backend=stage2
// target=native
//
// :4:35: error: expected type '*const anyopaque', found '*const *const usize'
// :4:35: note: cannot implicitly cast double pointer '*const *const usize' to anyopaque pointer '*const anyopaque'
// :9:10: error: expected type '?*anyopaque', found '*[*:0]u8'
// :9:10: note: cannot implicitly cast double pointer '*[*:0]u8' to anyopaque pointer '?*anyopaque'
// :15:35: error: expected type '*const anyopaque', found '*?*usize'
// :15:35: note: cannot implicitly cast double pointer '*?*usize' to anyopaque pointer '*const anyopaque'
