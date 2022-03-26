export fn a() void {
    comptime {
      var x = @as(i32, 1);
      x <<|= @as(i32, -2);
  }
}

// saturating shl assign does not allow negative rhs at comptime
//
// error: shift by negative value -2
