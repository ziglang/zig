export fn a() void {
    comptime {
      var x = @as(i32, 1);
      x <<|= @as(i32, -2);
  }
}

// error
// backend=stage1
// target=native
//
// error: shift by negative value -2
