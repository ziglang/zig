const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

const archs = [2]std.Target.Cpu.Arch{
    .aarch64, .x86_64,
};

pub fn addCases(ctx: *TestContext) !void {
    for (archs) |arch| {
        const target: std.zig.CrossTarget = .{
            .cpu_arch = arch,
            .os_tag = .macos,
        };
        {
            var case = ctx.exe("hello world with updates", target);
            case.addError("", &[_][]const u8{"error: no entry point found"});

            // Incorrect return type
            case.addError(
                \\export fn _start() noreturn {
                \\}
            , &[_][]const u8{":2:1: error: expected noreturn, found void"});

            // Regular old hello world
            case.addCompareOutput(
                \\extern "c" fn write(usize, usize, usize) usize;
                \\extern "c" fn exit(usize) noreturn;
                \\
                \\export fn _start() noreturn {
                \\    print();
                \\
                \\    exit(0);
                \\}
                \\
                \\fn print() void {
                \\    const msg = @ptrToInt("Hello, World!\n");
                \\    const len = 14;
                \\    _ = write(1, msg, len);
                \\}
            ,
                "Hello, World!\n",
            );

            // Now change the message only
            case.addCompareOutput(
                \\extern "c" fn write(usize, usize, usize) usize;
                \\extern "c" fn exit(usize) noreturn;
                \\
                \\export fn _start() noreturn {
                \\    print();
                \\
                \\    exit(0);
                \\}
                \\
                \\fn print() void {
                \\    const msg = @ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n");
                \\    const len = 104;
                \\    _ = write(1, msg, len);
                \\}
            ,
                "What is up? This is a longer message that will force the data to be relocated in virtual address space.\n",
            );

            // Now we print it twice.
            case.addCompareOutput(
                \\extern "c" fn write(usize, usize, usize) usize;
                \\extern "c" fn exit(usize) noreturn;
                \\
                \\export fn _start() noreturn {
                \\    print();
                \\    print();
                \\
                \\    exit(0);
                \\}
                \\
                \\fn print() void {
                \\    const msg = @ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n");
                \\    const len = 104;
                \\    _ = write(1, msg, len);
                \\}
            ,
                \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
                \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
                \\
            );
        }
        {
            var case = ctx.exe("corner case - update existing, singular TextBlock", target);

            // This test case also covers an infrequent scenarion where the string table *may* be relocated
            // into the position preceeding the symbol table which results in a dyld error.
            case.addCompareOutput(
                \\extern "c" fn exit(usize) noreturn;
                \\
                \\export fn _start() noreturn {
                \\    exit(0);
                \\}
            ,
                "",
            );

            case.addCompareOutput(
                \\extern "c" fn exit(usize) noreturn;
                \\extern "c" fn write(usize, usize, usize) usize;
                \\
                \\export fn _start() noreturn {
                \\    _ = write(1, @ptrToInt("Hey!\n"), 5);
                \\    exit(0);
                \\}
            ,
                "Hey!\n",
            );
        }
    }
}
