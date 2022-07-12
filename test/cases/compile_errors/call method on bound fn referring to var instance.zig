export fn entry() void {
    bad(bound_fn() == 1237);
}
const SimpleStruct = struct {
    field: i32,

    fn method(self: *const SimpleStruct) i32 {
        return self.field + 3;
    }
};
var simple_struct = SimpleStruct{ .field = 1234 };
const bound_fn = simple_struct.method;
fn bad(ok: bool) void {
    _ = ok;
}
// error
// target=native
// backend=stage2
//
// :12:18: error: cannot load runtime value in comptime block
