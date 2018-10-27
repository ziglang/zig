const assert = @import("std").debug.assert;
const builtin = @import("builtin");

const Foo = struct {
    x: u32,
    y: u32,
    z: u32,
};

test "@alignOf(T) before referencing T" {
    comptime assert(@alignOf(Foo) != @maxValue(usize));
    if (builtin.arch == builtin.Arch.x86_64) {
        comptime assert(@alignOf(Foo) == 4);
    }
}
