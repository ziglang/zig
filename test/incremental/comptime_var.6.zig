const builtin = @import("builtin");

extern "c" fn write(usize, usize, usize) usize;

pub fn main() void {
    comptime var i: u64 = 2;
    inline while (i < 6) : (i += 1) {
        print(i);
    }
}
fn print(len: usize) void {
    switch (builtin.os.tag) {
        .linux => {
            asm volatile ("syscall"
                :
                : [number] "{rax}" (1),
                  [arg1] "{rdi}" (1),
                  [arg2] "{rsi}" (@ptrToInt("Hello")),
                  [arg3] "{rdx}" (len),
                : "rcx", "r11", "memory"
            );
        },
        .macos => {
            _ = write(1, @ptrToInt("Hello"), len);
        },
        else => unreachable,
    }
}

// run
//
// HeHelHellHello
