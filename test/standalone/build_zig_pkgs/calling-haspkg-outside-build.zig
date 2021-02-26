pub fn main() void {
    if (@import("std").builtin.hasPkg("foo")) {
        @compileError("calling hasPkg outside of build.zig should be a compile error");
    }
}
