test "hello world IR" {
    exeCmp(
        \\@0 = "Hello, world!\n"
        \\
        \\@1 = fn({
        \\  %0 : usize = 1 ;SYS_write
        \\  %1 : usize = 1 ;STDOUT_FILENO
        \\  %2 = ptrtoint(@0) ; msg ptr
        \\  %3 = fieldptr(@0, "len") ; msg len ptr
        \\  %4 = deref(%3) ; msg len
        \\  %5 = asm("syscall",
        \\    volatile=1,
        \\    output="={rax}",
        \\    inputs=["{rax}", "{rdi}", "{rsi}", "{rdx}"],
        \\    clobbers=["rcx", "r11", "memory"],
        \\    args=[%0, %1, %2, %4])
        \\
        \\  %6 : usize = 231 ;SYS_exit_group
        \\  %7 : usize = 0   ;exit code
        \\  %8 = asm("syscall",
        \\    volatile=1,
        \\    output="={rax}",
        \\    inputs=["{rax}", "{rdi}"],
        \\    clobbers=["rcx", "r11", "memory"],
        \\    args=[%6, %7])
        \\
        \\  %9 = unreachable()
        \\}, cc=naked)
        \\
        \\@2 = export("_start", @1)
    ,
        \\Hello, world!
        \\
    );
}

fn exeCmp(src: []const u8, expected_stdout: []const u8) void {}
