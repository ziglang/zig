export fn f() void {
    var cstr: []const u8 = "Hat";
    cstr[0] = 'W';
}

// error
//
// :3:9: error: cannot assign to constant
