const X = packed struct {
    x: u64,
};

pub fn main() void {
    const obj = X{ .x = 1 };
    _ = asm volatile ("movq %[obj], %[ret]"
        : [ret] "={rbx}" (-> u64),
        : [obj] "{rcx}" (obj),
    );
}

// compile
// target=x86_64-linux
// backend=llvm
//
