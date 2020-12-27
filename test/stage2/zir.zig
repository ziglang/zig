const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;
// self-hosted does not yet support PE executable files / COFF object files
// or mach-o files. So we do the ZIR transform test cases cross compiling for
// x86_64-linux.
const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    ctx.transformZIR("referencing decls which appear later in the file", linux_x64,
        \\@void = primitive(void)
        \\@fnty = fntype([], @void, cc=C)
        \\
        \\@9 = str("entry")
        \\@11 = export(@9, "entry")
        \\
        \\@entry = fn(@fnty, {
        \\  %11 = returnvoid()
        \\})
    ,
        \\@void = primitive(void)
        \\@fnty = fntype([], @void, cc=C)
        \\@9 = declref("9__anon_0")
        \\@9__anon_0 = str("entry")
        \\@unnamed$4 = str("entry")
        \\@unnamed$5 = export(@unnamed$4, "entry")
        \\@11 = primitive(void_value)
        \\@unnamed$7 = fntype([], @void, cc=C)
        \\@entry = fn(@unnamed$7, {
        \\  %0 = returnvoid() ; deaths=0b1000000000000000
        \\})
        \\
    );
    ctx.transformZIR("elemptr, add, cmp, condbr, return, breakpoint", linux_x64,
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
        \\  %a_ref = ref(%a)
        \\  %eptr0 = elemptr(%a_ref, @0)
        \\  %eptr1 = elemptr(%a_ref, @1)
        \\  %eptr2 = elemptr(%a_ref, @2)
        \\  %eptr3 = elemptr(%a_ref, @3)
        \\  %v0 = deref(%eptr0)
        \\  %v1 = deref(%eptr1)
        \\  %v2 = deref(%eptr2)
        \\  %v3 = deref(%eptr3)
        \\  %x0 = add(%v0, %v1)
        \\  %x1 = add(%v2, %v3)
        \\  %result = add(%x0, %x1)
        \\
        \\  %expected = int(69)
        \\  %ok = cmp_eq(%result, %expected)
        \\  %10 = condbr(%ok, {
        \\    %11 = returnvoid()
        \\  }, {
        \\    %12 = breakpoint()
        \\  })
        \\})
        \\
        \\@9 = str("entry")
        \\@11 = export(@9, "entry")
    ,
        \\@void = primitive(void)
        \\@fnty = fntype([], @void, cc=C)
        \\@0 = int(0)
        \\@1 = int(1)
        \\@2 = int(2)
        \\@3 = int(3)
        \\@unnamed$6 = fntype([], @void, cc=C)
        \\@entry = fn(@unnamed$6, {
        \\  %0 = returnvoid() ; deaths=0b1000000000000000
        \\})
        \\@entry__anon_1 = str("2\x08\x01\n")
        \\@9 = declref("9__anon_0")
        \\@9__anon_0 = str("entry")
        \\@unnamed$11 = str("entry")
        \\@unnamed$12 = export(@unnamed$11, "entry")
        \\@11 = primitive(void_value)
        \\
    );

    {
        var case = ctx.objZIR("reference cycle with compile error in the cycle", linux_x64);
        case.addTransform(
            \\@void = primitive(void)
            \\@fnty = fntype([], @void, cc=C)
            \\
            \\@9 = str("entry")
            \\@11 = export(@9, "entry")
            \\
            \\@entry = fn(@fnty, {
            \\  %0 = call(@a, [])
            \\  %1 = returnvoid()
            \\})
            \\
            \\@a = fn(@fnty, {
            \\  %0 = call(@b, [])
            \\  %1 = returnvoid()
            \\})
            \\
            \\@b = fn(@fnty, {
            \\  %0 = call(@a, [])
            \\  %1 = returnvoid()
            \\})
        ,
            \\@void = primitive(void)
            \\@fnty = fntype([], @void, cc=C)
            \\@9 = declref("9__anon_0")
            \\@9__anon_0 = str("entry")
            \\@unnamed$4 = str("entry")
            \\@unnamed$5 = export(@unnamed$4, "entry")
            \\@11 = primitive(void_value)
            \\@unnamed$7 = fntype([], @void, cc=C)
            \\@entry = fn(@unnamed$7, {
            \\  %0 = call(@a, [], modifier=auto) ; deaths=0b1000000000000001
            \\  %1 = returnvoid() ; deaths=0b1000000000000000
            \\})
            \\@unnamed$9 = fntype([], @void, cc=C)
            \\@a = fn(@unnamed$9, {
            \\  %0 = call(@b, [], modifier=auto) ; deaths=0b1000000000000001
            \\  %1 = returnvoid() ; deaths=0b1000000000000000
            \\})
            \\@unnamed$11 = fntype([], @void, cc=C)
            \\@b = fn(@unnamed$11, {
            \\  %0 = call(@a, [], modifier=auto) ; deaths=0b1000000000000001
            \\  %1 = returnvoid() ; deaths=0b1000000000000000
            \\})
            \\
        );
        // Now we introduce a compile error
        case.addError(
            \\@void = primitive(void)
            \\@fnty = fntype([], @void, cc=C)
            \\
            \\@9 = str("entry")
            \\@11 = export(@9, "entry")
            \\
            \\@entry = fn(@fnty, {
            \\  %0 = call(@a, [])
            \\  %1 = returnvoid()
            \\})
            \\
            \\@a = fn(@fnty, {
            \\  %0 = call(@c, [])
            \\  %1 = returnvoid()
            \\})
            \\
            \\@b = str("message")
            \\
            \\@c = fn(@fnty, {
            \\  %9 = compileerror(@b)
            \\  %0 = call(@a, [])
            \\  %1 = returnvoid()
            \\})
        ,
            &[_][]const u8{
                ":20:21: error: message",
            },
        );
        // Now we remove the call to `a`. `a` and `b` form a cycle, but no entry points are
        // referencing either of them. This tests that the cycle is detected, and the error
        // goes away.
        case.addTransform(
            \\@void = primitive(void)
            \\@fnty = fntype([], @void, cc=C)
            \\
            \\@9 = str("entry")
            \\@11 = export(@9, "entry")
            \\
            \\@entry = fn(@fnty, {
            \\  %0 = returnvoid()
            \\})
            \\
            \\@a = fn(@fnty, {
            \\  %0 = call(@c, [])
            \\  %1 = returnvoid()
            \\})
            \\
            \\@b = str("message")
            \\
            \\@c = fn(@fnty, {
            \\  %9 = compileerror(@b)
            \\  %0 = call(@a, [])
            \\  %1 = returnvoid()
            \\})
        ,
            \\@void = primitive(void)
            \\@fnty = fntype([], @void, cc=C)
            \\@9 = declref("9__anon_3")
            \\@9__anon_3 = str("entry")
            \\@unnamed$4 = str("entry")
            \\@unnamed$5 = export(@unnamed$4, "entry")
            \\@11 = primitive(void_value)
            \\@unnamed$7 = fntype([], @void, cc=C)
            \\@entry = fn(@unnamed$7, {
            \\  %0 = returnvoid() ; deaths=0b1000000000000000
            \\})
            \\
        );
    }

    if (std.Target.current.os.tag != .linux or
        std.Target.current.cpu.arch != .x86_64)
    {
        // TODO implement self-hosted PE (.exe file) linking
        // TODO implement more ZIR so we don't depend on x86_64-linux
        return;
    }

    ctx.compareOutputZIR("hello world ZIR",
        \\@noreturn = primitive(noreturn)
        \\@void = primitive(void)
        \\@usize = primitive(usize)
        \\@0 = int(0)
        \\@1 = int(1)
        \\@2 = int(2)
        \\@3 = int(3)
        \\
        \\@msg = str("Hello, world!\n")
        \\
        \\@start_fnty = fntype([], @noreturn, cc=Naked)
        \\@start = fn(@start_fnty, {
        \\  %SYS_exit_group = int(231)
        \\  %exit_code = as(@usize, @0)
        \\
        \\  %syscall = str("syscall")
        \\  %sysoutreg = str("={rax}")
        \\  %rax = str("{rax}")
        \\  %rdi = str("{rdi}")
        \\  %rcx = str("rcx")
        \\  %rdx = str("{rdx}")
        \\  %rsi = str("{rsi}")
        \\  %r11 = str("r11")
        \\  %memory = str("memory")
        \\
        \\  %SYS_write = as(@usize, @1)
        \\  %STDOUT_FILENO = as(@usize, @1)
        \\
        \\  %msg_addr = ptrtoint(@msg)
        \\
        \\  %len_name = str("len")
        \\  %msg_len_ptr = fieldptr(@msg, %len_name)
        \\  %msg_len = deref(%msg_len_ptr)
        \\  %rc_write = asm(%syscall, @usize,
        \\    volatile=1,
        \\    output=%sysoutreg,
        \\    inputs=[%rax, %rdi, %rsi, %rdx],
        \\    clobbers=[%rcx, %r11, %memory],
        \\    args=[%SYS_write, %STDOUT_FILENO, %msg_addr, %msg_len])
        \\
        \\  %rc_exit = asm(%syscall, @usize,
        \\    volatile=1,
        \\    output=%sysoutreg,
        \\    inputs=[%rax, %rdi],
        \\    clobbers=[%rcx, %r11, %memory],
        \\    args=[%SYS_exit_group, %exit_code])
        \\
        \\  %99 = unreachable()
        \\});
        \\
        \\@9 = str("_start")
        \\@11 = export(@9, "start")
    ,
        \\Hello, world!
        \\
    );

    ctx.compareOutputZIR("function call with no args no return value",
        \\@noreturn = primitive(noreturn)
        \\@void = primitive(void)
        \\@usize = primitive(usize)
        \\@0 = int(0)
        \\@1 = int(1)
        \\@2 = int(2)
        \\@3 = int(3)
        \\
        \\@exit0_fnty = fntype([], @noreturn)
        \\@exit0 = fn(@exit0_fnty, {
        \\  %SYS_exit_group = int(231)
        \\  %exit_code = as(@usize, @0)
        \\
        \\  %syscall = str("syscall")
        \\  %sysoutreg = str("={rax}")
        \\  %rax = str("{rax}")
        \\  %rdi = str("{rdi}")
        \\  %rcx = str("rcx")
        \\  %r11 = str("r11")
        \\  %memory = str("memory")
        \\
        \\  %rc = asm(%syscall, @usize,
        \\    volatile=1,
        \\    output=%sysoutreg,
        \\    inputs=[%rax, %rdi],
        \\    clobbers=[%rcx, %r11, %memory],
        \\    args=[%SYS_exit_group, %exit_code])
        \\
        \\  %99 = unreachable()
        \\});
        \\
        \\@start_fnty = fntype([], @noreturn, cc=Naked)
        \\@start = fn(@start_fnty, {
        \\  %0 = call(@exit0, [])
        \\})
        \\@9 = str("_start")
        \\@11 = export(@9, "start")
    , "");
}
