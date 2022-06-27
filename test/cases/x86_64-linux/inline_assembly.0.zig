pub fn main() void {
    const number = 1234;
    const x = asm volatile ("syscall"
        : [o] "{rax}" (-> number),
        : [number] "{rax}" (231),
          [arg1] "{rdi}" (60),
        : "rcx", "r11", "memory"
    );
    _ = x;
}

// error
// output_mode=Exe
// target=x86_64-linux
//
// :4:27: error: expected type 'type', found 'comptime_int'
