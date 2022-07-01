const builtin = @import("builtin");
pub const pthread_mutex_t = extern struct {
    size: [__SIZEOF_PTHREAD_MUTEX_T]u8 align(@alignOf(usize)) = [_]u8{0} ** __SIZEOF_PTHREAD_MUTEX_T,
};
pub const pthread_cond_t = extern struct {
    size: [__SIZEOF_PTHREAD_COND_T]u8 align(@alignOf(usize)) = [_]u8{0} ** __SIZEOF_PTHREAD_COND_T,
};
const __SIZEOF_PTHREAD_COND_T = 48;
const __SIZEOF_PTHREAD_MUTEX_T = switch (builtin.abi) {
    .musl, .musleabi, .musleabihf => if (@sizeOf(usize) == 8) 40 else 24,
    .gnu, .gnuabin32, .gnuabi64, .gnueabi, .gnueabihf, .gnux32 => switch (builtin.cpu.arch) {
        .aarch64 => 48,
        .x86_64 => if (builtin.abi == .gnux32) 40 else 32,
        .mips64, .powerpc64, .powerpc64le, .sparc64 => 40,
        else => if (@sizeOf(usize) == 8) 40 else 24,
    },
    else => unreachable,
};
