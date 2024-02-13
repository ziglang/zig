fn assert(ok: bool) void {
    if (!ok) unreachable;
}

fn setFs(value: c_ulong) void {
    asm volatile (
        \\syscall
        :
        : [number] "{rax}" (158),
          [code] "{rdi}" (0x1002),
          [val] "{rsi}" (value),
        : "rcx", "r11", "memory"
    );
}

fn getFs() c_ulong {
    var result: c_ulong = undefined;
    asm volatile (
        \\syscall
        :
        : [number] "{rax}" (158),
          [code] "{rdi}" (0x1003),
          [ptr] "{rsi}" (@intFromPtr(&result)),
        : "rcx", "r11", "memory"
    );
    return result;
}

var test_value: u64 = 12345;

pub fn main() void {
    const orig_fs = getFs();

    setFs(@intFromPtr(&test_value));
    assert(getFs() == @intFromPtr(&test_value));

    var test_ptr: *allowzero addrspace(.fs) u64 = @ptrFromInt(0);
    _ = &test_ptr;
    assert(test_ptr.* == 12345);
    test_ptr.* = 98765;
    assert(test_value == 98765);

    setFs(orig_fs);
}

// run
// backend=llvm
// target=x86_64-linux
//
