export fn f() void {
  var cstr = "Hat";
  cstr[0] = 'W';
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:13: error: cannot assign to constant
