const S = struct {
    comptime_field: comptime_int = 2,
    normal_ptr: *u32,
};

export fn a() void {
  var value: u32 = 3;
  const comptimeStruct = S {
    .normal_ptr = &value,
  };
  _ = comptimeStruct;
}

// error
// backend=stage2
// target=native
//
// 9:6: error: unable to resolve comptime value
// 9:6: note: initializer of comptime only struct must be comptime-known
