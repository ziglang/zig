thisfileisautotranslatedfromc;

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
// :4:8: error: extern structs cannot contain fields of type 'fn () callconv(.C) void'
// :4:8: note: type has no guaranteed in-memory representation
// :4:8: note: use '*const ' to make a function pointer type
// :10:13: error: C pointers cannot point to non-C-ABI-compatible type '[4]fn () callconv(.C) void'
// :10:13: note: type has no guaranteed in-memory representation
// :10:13: note: use '*const ' to make a function pointer type