const std = @import("std");
const tests = @import("tests.zig");

pub fn addCases(cases: *tests.CompareOutputContext) void {
    if (std.Target.current.os.tag == .linux and std.Target.current.cpu.arch == .x86_64) {
        cases.addAsm("hello world linux x86_64",
            \\.text
            \\.globl _start
            \\
            \\_start:
            \\    mov $1, %rax
            \\    mov $1, %rdi
            \\    mov $msg, %rsi
            \\    mov $14, %rdx
            \\    syscall
            \\
            \\    mov $60, %rax
            \\    mov $0, %rdi
            \\    syscall
            \\
            \\.data
            \\msg:
            \\    .ascii "Hello, world!\n"
        , "Hello, world!\n");
    }
}
