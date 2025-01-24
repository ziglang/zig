const native_os = @import("builtin").os.tag;

pub const MemoryMappedList = switch (native_os) {
    .linux => @import("memory_mapped_list_posix.zig").MemoryMappedList,
    else => @compileError("Unsupported os"),
};
