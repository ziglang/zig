const std = @import("std");
const TestContext = @import("../../src-self-hosted/test.zig").TestContext;
// self-hosted does not yet support PE executable files / COFF object files
// or mach-o files. So we do the ZIR transform test cases cross compiling for
// x86_64-linux.
const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) void {
    ctx.addZIRTransform("elemptr, add, cmp, condbr, return, breakpoint", linux_x64,
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
        \\  %aref = ref(%a)
        \\  %eptr0 = elemptr(%aref, @0)
        \\  %eptr1 = elemptr(%aref, @1)
        \\  %eptr2 = elemptr(%aref, @2)
        \\  %eptr3 = elemptr(%aref, @3)
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
        \\@10 = ref(@9)
        \\@11 = export(@10, @entry)
    ,
        \\@0 = primitive(void)
        \\@1 = fntype([], @0, cc=C)
        \\@2 = fn(@1, {
        \\  %0 = return()
        \\})
        \\@3 = str("entry")
        \\@4 = ref(@3)
        \\@5 = export(@4, @2)
        \\
    );

    if (std.Target.current.os.tag != .linux or
        std.Target.current.cpu.arch != .x86_64)
    {
        // TODO implement self-hosted PE (.exe file) linking
        // TODO implement more ZIR so we don't depend on x86_64-linux
        return;
    }

    ctx.addZIRCompareOutput(
        "hello world ZIR, update msg",
        &[_][]const u8{
            \\@noreturn = primitive(noreturn)
            \\@void = primitive(void)
            \\@usize = primitive(usize)
            \\@0 = int(0)
            \\@1 = int(1)
            \\@2 = int(2)
            \\@3 = int(3)
            \\
            \\@syscall_array = str("syscall")
            \\@sysoutreg_array = str("={rax}")
            \\@rax_array = str("{rax}")
            \\@rdi_array = str("{rdi}")
            \\@rcx_array = str("rcx")
            \\@r11_array = str("r11")
            \\@rdx_array = str("{rdx}")
            \\@rsi_array = str("{rsi}")
            \\@memory_array = str("memory")
            \\@len_array = str("len")
            \\
            \\@msg = str("Hello, world!\n")
            \\
            \\@start_fnty = fntype([], @noreturn, cc=Naked)
            \\@start = fn(@start_fnty, {
            \\  %SYS_exit_group = int(231)
            \\  %exit_code = as(@usize, @0)
            \\
            \\  %syscall = ref(@syscall_array)
            \\  %sysoutreg = ref(@sysoutreg_array)
            \\  %rax = ref(@rax_array)
            \\  %rdi = ref(@rdi_array)
            \\  %rcx = ref(@rcx_array)
            \\  %rdx = ref(@rdx_array)
            \\  %rsi = ref(@rsi_array)
            \\  %r11 = ref(@r11_array)
            \\  %memory = ref(@memory_array)
            \\
            \\  %SYS_write = as(@usize, @1)
            \\  %STDOUT_FILENO = as(@usize, @1)
            \\
            \\  %msg_ptr = ref(@msg)
            \\  %msg_addr = ptrtoint(%msg_ptr)
            \\
            \\  %len_name = ref(@len_array)
            \\  %msg_len_ptr = fieldptr(%msg_ptr, %len_name)
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
            \\@10 = ref(@9)
            \\@11 = export(@10, @start)
        ,
            \\@noreturn = primitive(noreturn)
            \\@void = primitive(void)
            \\@usize = primitive(usize)
            \\@0 = int(0)
            \\@1 = int(1)
            \\@2 = int(2)
            \\@3 = int(3)
            \\
            \\@syscall_array = str("syscall")
            \\@sysoutreg_array = str("={rax}")
            \\@rax_array = str("{rax}")
            \\@rdi_array = str("{rdi}")
            \\@rcx_array = str("rcx")
            \\@r11_array = str("r11")
            \\@rdx_array = str("{rdx}")
            \\@rsi_array = str("{rsi}")
            \\@memory_array = str("memory")
            \\@len_array = str("len")
            \\
            \\@msg = str("Hello, world!\n")
            \\@msg2 = str("HELL WORLD\n")
            \\
            \\@start_fnty = fntype([], @noreturn, cc=Naked)
            \\@start = fn(@start_fnty, {
            \\  %SYS_exit_group = int(231)
            \\  %exit_code = as(@usize, @0)
            \\
            \\  %syscall = ref(@syscall_array)
            \\  %sysoutreg = ref(@sysoutreg_array)
            \\  %rax = ref(@rax_array)
            \\  %rdi = ref(@rdi_array)
            \\  %rcx = ref(@rcx_array)
            \\  %rdx = ref(@rdx_array)
            \\  %rsi = ref(@rsi_array)
            \\  %r11 = ref(@r11_array)
            \\  %memory = ref(@memory_array)
            \\
            \\  %SYS_write = as(@usize, @1)
            \\  %STDOUT_FILENO = as(@usize, @1)
            \\
            \\  %msg_ptr = ref(@msg2)
            \\  %msg_addr = ptrtoint(%msg_ptr)
            \\
            \\  %len_name = ref(@len_array)
            \\  %msg_len_ptr = fieldptr(%msg_ptr, %len_name)
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
            \\@10 = ref(@9)
            \\@11 = export(@10, @start)
        },
        &[_][]const u8{
            \\Hello, world!
            \\
        ,
            \\HELL WORLD
            \\
        },
    );
}
