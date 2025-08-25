const a = @import("a.zig").hello;
const b = @import("b.zig").hello;
export fn foo() void {
    _ = a();
    _ = b();
}
