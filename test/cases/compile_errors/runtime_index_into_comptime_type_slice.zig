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
// :9:51: error: values of type '[]const builtin.Type.StructField' must be comptime known, but index value is runtime known
// :287:21: note: struct requires comptime because of this field
// :287:21: note: types are not available at runtime
// :290:20: note: struct requires comptime because of this field
