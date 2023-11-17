const S = extern struct {
    a: fn () callconv(.C) void,
};
comptime {
    _ = @sizeOf(S) == 1;
}
comptime {
    _ = [*c][4]fn () callconv(.C) void;
}

// error
// backend=stage2
// target=native
//
// :2:8: error: extern structs cannot contain fields of type 'fn () callconv(.C) void'
// :2:8: note: type has no guaranteed in-memory representation
// :2:8: note: use '*const ' to make a function pointer type
// :8:13: error: C pointers cannot point to non-C-ABI-compatible type '[4]fn () callconv(.C) void'
// :8:13: note: type has no guaranteed in-memory representation
// :8:13: note: use '*const ' to make a function pointer type
