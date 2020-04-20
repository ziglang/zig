test "hello world IR" {
    exeCmp(
        \\@0 = str("Hello, world!\n")
        \\@1 = primitive(void)
        \\@2 = primitive(usize)
        \\@3 = fntype([], @1, cc=Naked)
        \\@4 = int(0)
        \\@5 = int(1)
        \\@6 = int(231)
        \\@7 = str("len")
        \\
        \\@8 = fn(@3, {
        \\  %0 = as(@2, @5) ; SYS_write
        \\  %1 = as(@2, @5) ; STDOUT_FILENO
        \\  %2 = ptrtoint(@0) ; msg ptr
        \\  %3 = fieldptr(@0, @7) ; msg len ptr
        \\  %4 = deref(%3) ; msg len
        \\  %sysoutreg = str("={rax}")
        \\  %rax = str("{rax}")
        \\  %rdi = str("{rdi}")
        \\  %rsi = str("{rsi}")
        \\  %rdx = str("{rdx}")
        \\  %rcx = str("rcx")
        \\  %r11 = str("r11")
        \\  %memory = str("memory")
        \\  %syscall = str("syscall")
        \\  %5 = asm(%syscall, @2,
        \\    volatile=1,
        \\    output=%sysoutreg,
        \\    inputs=[%rax, %rdi, %rsi, %rdx],
        \\    clobbers=[%rcx, %r11, %memory],
        \\    args=[%0, %1, %2, %4])
        \\
        \\  %6 = as(@2, @6) ;SYS_exit_group
        \\  %7 = as(@2, @4) ;exit code
        \\  %8 = asm(%syscall, @2,
        \\    volatile=1,
        \\    output=%sysoutreg,
        \\    inputs=[%rax, %rdi],
        \\    clobbers=[%rcx, %r11, %memory],
        \\    args=[%6, %7])
        \\
        \\  %9 = unreachable()
        \\})
        \\
        \\@9 = str("_start")
        \\@10 = export(@9, @8)
    ,
        \\Hello, world!
        \\
    );
}

fn exeCmp(src: []const u8, expected_stdout: []const u8) void {}
