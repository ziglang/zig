export fn f() void {
  var cstr = "Hat";
  cstr[0] = 'W';
}

// assign through constant pointer
//
// tmp.zig:3:13: error: cannot assign to constant
