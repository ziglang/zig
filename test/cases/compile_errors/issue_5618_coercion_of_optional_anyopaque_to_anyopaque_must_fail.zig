export fn foo() void {
    var u: ?*anyopaque = null;
    var v: *anyopaque = undefined;
    v = (&u).*;
}

// error
// backend=stage2
// target=native
//
// :4:13: error: expected type '*anyopaque', found '?*anyopaque'
// :4:13: note: cannot convert optional to payload type
// :4:13: note: consider using '.?', 'orelse', or 'if'
// :4:13: note: '?*anyopaque' could have null values which are illegal in type '*anyopaque'
