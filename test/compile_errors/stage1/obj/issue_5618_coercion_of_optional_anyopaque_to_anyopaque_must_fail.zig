export fn foo() void {
    var u: ?*anyopaque = null;
    var v: *anyopaque = undefined;
    v = u;
}

// Issue #5618: coercion of ?*anyopaque to *anyopaque must fail.
//
// tmp.zig:4:9: error: cannot convert optional to payload type. consider using `.?`, `orelse`, or `if`. expected type '*anyopaque', found '?*anyopaque'
