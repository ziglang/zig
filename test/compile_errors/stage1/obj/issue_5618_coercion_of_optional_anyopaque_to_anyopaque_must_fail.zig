export fn foo() void {
    var u: ?*anyopaque = null;
    var v: *anyopaque = undefined;
    v = u;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:9: error: cannot convert optional to payload type. consider using `.?`, `orelse`, or `if`. expected type '*anyopaque', found '?*anyopaque'
