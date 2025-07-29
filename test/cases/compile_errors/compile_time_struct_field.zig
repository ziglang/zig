const S = struct {
    comptime_field: comptime_int = 2,
    normal_ptr: *u32,
};

export fn a() void {
    var value: u32 = 3;
    const comptimeStruct = S{
        .normal_ptr = &value,
    };
    _ = comptimeStruct;
}

// error
//
// :9:10: error: unable to resolve comptime value
// :9:10: note: initializer of comptime-only struct 'tmp.S' must be comptime-known
// :2:21: note: struct requires comptime because of this field
