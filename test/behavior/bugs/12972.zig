const builtin = @import("builtin");

pub fn f(_: [:null]const ?u8) void {}

test {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const c: u8 = 42;
    f(&[_:null]?u8{c});
    f(&.{c});

    var v: u8 = 42;
    f(&[_:null]?u8{v});
    f(&.{v});
}
