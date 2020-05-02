const TestContext = @import("../../src-self-hosted/test.zig").TestContext;

pub fn addCases(ctx: *TestContext) void {
    ctx.addZIRTransform("elemptr, add, cmp, condbr, return, breakpoint",
        \\@void = primitive(void)
        \\@usize = primitive(usize)
        \\@fnty = fntype([], @void, cc=C)
        \\@0 = int(0)
        \\@1 = int(1)
        \\@2 = int(2)
        \\@3 = int(3)
        \\
        \\@entry = fn(@fnty, {
        \\  %a = str("\x32\x08\x01\x0a")
        \\  %eptr0 = elemptr(%a, @0)
        \\  %eptr1 = elemptr(%a, @1)
        \\  %eptr2 = elemptr(%a, @2)
        \\  %eptr3 = elemptr(%a, @3)
        \\  %v0 = deref(%eptr0)
        \\  %v1 = deref(%eptr1)
        \\  %v2 = deref(%eptr2)
        \\  %v3 = deref(%eptr3)
        \\  %x0 = add(%v0, %v1)
        \\  %x1 = add(%v2, %v3)
        \\  %result = add(%x0, %x1)
        \\
        \\  %expected = int(69)
        \\  %ok = cmp(%result, eq, %expected)
        \\  %10 = condbr(%ok, {
        \\    %11 = return()
        \\  }, {
        \\    %12 = breakpoint()
        \\  })
        \\})
        \\
        \\@9 = str("entry")
        \\@10 = export(@9, @entry)
    ,
        \\@0 = primitive(void)
        \\@1 = fntype([], @0, cc=C)
        \\@2 = fn(@1, {
        \\  %0 = return()
        \\})
        \\@3 = str("entry")
        \\@4 = export(@3, @2)
        \\
    );

    if (@import("std").Target.current.os.tag != .linux or
        @import("std").Target.current.cpu.arch != .x86_64)
    {
        // TODO implement self-hosted PE (.exe file) linking
        // TODO implement more ZIR so we don't depend on x86_64-linux
        return;
    }

    ctx.addZIRCompareOutput("hello world ZIR",
        \\@0 = str("Hello, world!\n")
        \\@1 = primitive(noreturn)
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
