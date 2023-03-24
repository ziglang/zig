const Struct = struct {
    a: u32,
};
fn getIndex() usize {
    return 2;
}
export fn entry() void {
    const index = getIndex();
    const field = @typeInfo(Struct).Struct.fields[index];
    _ = field;
}

// error
// backend=stage2
// target=native
//
// :9:51: error: values of type '[]const builtin.Type.StructField' must be comptime-known, but index value is runtime-known
// : note: struct requires comptime because of this field
// : note: types are not available at runtime
// : struct requires comptime because of this field
