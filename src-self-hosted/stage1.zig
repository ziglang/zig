// This is Zig code that is used by both stage1 and stage2.
// The prototypes in src/userland.h must match these definitions.
comptime {
    _ = @import("translate_c.zig");
}

pub const info_zen =
    \\
    \\ * Communicate intent precisely.
    \\ * Edge cases matter.
    \\ * Favor reading code over writing code.
    \\ * Only one obvious way to do things.
    \\ * Runtime crashes are better than bugs.
    \\ * Compile errors are better than runtime crashes.
    \\ * Incremental improvements.
    \\ * Avoid local maximums.
    \\ * Reduce the amount one must remember.
    \\ * Minimize energy spent on coding style.
    \\ * Together we serve end users.
    \\
    \\
;

export fn stage2_attach_segv_handler() void {
    const builtin = @import("builtin");
    if (builtin.os == .linux and (builtin.arch == .x86_64 or builtin.arch == .i386)) {
        @import("segv_handler/handler.zig").attach();
    }
}

export fn stage2_zen(ptr: *[*]const u8, len: *usize) void {
    ptr.* = &info_zen;
    len.* = info_zen.len;
}

export fn stage2_panic(ptr: [*]const u8, len: usize) void {
    @panic(ptr[0..len]);
}
