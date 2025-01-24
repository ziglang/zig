const native_os = @import("builtin").os.tag;

pub const InputPool = switch (native_os) {
    .linux => @import("InputPoolPosix.zig"),
    else => @compileError("Unsupported os"),
};
