export fn f() void {
  var cstr: []const u8 = "Hat";
  cstr[0] = 'W';
}

// assign through constant slice
//
// tmp.zig:3:13: error: cannot assign to constant
