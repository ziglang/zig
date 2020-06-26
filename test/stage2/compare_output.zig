const std = @import("std");
const TestContext = @import("../../src-self-hosted/test.zig").TestContext;
// self-hosted does not yet support PE executable files / COFF object files
// or mach-o files. So we do these test cases cross compiling for x86_64-linux.
const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    if (std.Target.current.os.tag != .linux or
        std.Target.current.cpu.arch != .x86_64)
    {
        // TODO implement self-hosted PE (.exe file) linking
        // TODO implement more ZIR so we don't depend on x86_64-linux
        return;
    }

    {
        var case = ctx.exe("hello world with updates", linux_x64);
        // Regular old hello world
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    print();
            \\
            \\    exit();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{rdx}" (14)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "Hello, World!\n",
        );
        // Now change the message only
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    print();
            \\
            \\    exit();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n")),
            \\          [arg3] "{rdx}" (104)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "What is up? This is a longer message that will force the data to be relocated in virtual address space.\n",
        );
        // Now we print it twice.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    print();
            \\    print();
            \\
            \\    exit();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n")),
            \\          [arg3] "{rdx}" (104)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\
        );
    }
    ctx.compareOutputZIR("function call with args",
        \\@noreturn = primitive(noreturn)
        \\@void = primitive(void)
        \\@usize = primitive(usize)
        \\
        \\@0 = int(0)
        \\@1 = int(1)
        \\@2 = int(2)
        \\@3 = int(3)
        \\
        \\@rax = str("{rax}")
        \\@rdi = str("{rdi}")
        \\@rcx = str("rcx")
        \\@rdx = str("{rdx}")
        \\@rsi = str("{rsi}")
        \\@r11 = str("r11")
        \\@memory = str("memory")
        \\
        \\@sysoutreg = str("={rax}")
        \\
        \\@syscall = str("syscall")
        \\
        \\@write_fnty = fntype([@usize, @usize], @void, cc=C)
        \\@write = fn(@write_fnty, {
        \\  %0 = arg(0)
        \\  %1 = arg(1)
        \\
        \\  %SYS_write = as(@usize, @1)
        \\  %STDOUT_FILENO = as(@usize, @1)
        \\
        \\  %rc_write = asm(@syscall, @usize,
        \\    volatile=1,
        \\    output=@sysoutreg,
        \\    inputs=[@rax, @rdi, @rsi, @rdx],
        \\    clobbers=[@rcx, @r11, @memory],
        \\    args=[%SYS_write, %STDOUT_FILENO, %0, %1])
        \\  %2 = returnvoid()
        \\})
        \\
        \\@start_fnty = fntype([], @noreturn, cc=Naked)
        \\@start = fn(@start_fnty, {
        \\  %SYS_exit_group = int(231)
        \\  %exit_code = as(@usize, @0)
        \\
        \\  %msg = str("Hello, world!\n")
        \\  %msg_addr = ptrtoint(%msg)
        \\  %len_name = str("len")
        \\  %msg_len_ptr = fieldptr(%msg, %len_name)
        \\  %msg_len = deref(%msg_len_ptr)
        \\
        \\  %nothing = call(@write, [%msg_addr, %msg_len])
        \\
        \\  %rc_exit = asm(@syscall, @usize,
        \\    volatile=1,
        \\    output=@sysoutreg,
        \\    inputs=[@rax, @rdi],
        \\    clobbers=[@rcx, @r11, @memory],
        \\    args=[%SYS_exit_group, %exit_code])
        \\
        \\  %99 = unreachable()
        \\});
        \\
        \\@9 = str("_start")
        \\@11 = export(@9, "start")
    , "Hello, world!\n");

    //    ctx.exe("function call with args", linux_x64).addCompareOutput(
    //        \\export fn _start() noreturn {
    //        \\    print(@ptrToInt("Hello, World!\n"), 14);
    //        \\
    //        \\    exit();
    //        \\}
    //        \\
    //        \\fn print(arg: usize, len: usize) void {
    //        \\    asm volatile ("syscall"
    //        \\        :
    //        \\        : [number] "{rax}" (1),
    //        \\          [arg1] "{rdi}" (1),
    //        \\          [arg2] "{rsi}" (arg),
    //        \\          [arg3] "{rdx}" (len)
    //        \\        : "rcx", "r11", "memory"
    //        \\    );
    //        \\    return;
    //        \\}
    //        \\
    //        \\fn exit() noreturn {
    //        \\    asm volatile ("syscall"
    //        \\        :
    //        \\        : [number] "{rax}" (231),
    //        \\          [arg1] "{rdi}" (0)
    //        \\        : "rcx", "r11", "memory"
    //        \\    );
    //        \\    unreachable;
    //        \\}
    //    ,
    //        "Hello, World!\n",
    //    );
}
