export fn f() void {
  var cstr: []const u8 = "Hat";
  cstr[0] = 'W';
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:13: error: cannot assign to constant
