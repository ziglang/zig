const S = struct {
    comptime {
        asm volatile (
            \\zig_moment:
            \\syscall
        );
    }
};
pub fn main() void {
    _ = S;
}

// error
//
// :3:13: error: volatile is meaningless on global assembly
