export fn entry() void {
    var x: i32 = 1234;
    var p: *i32 = &x;
    var pp: *?*i32 = &p;
    pp.* = null;
    var y = p.*;
    _ = y;
}

// use implicit casts to assign null to non-nullable pointer
//
// tmp.zig:4:23: error: expected type '*?*i32', found '**i32'
