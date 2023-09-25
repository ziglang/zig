//! Here we test our ELF linker for correctness and functionality.
//! Currently, we support linking x86_64 Linux, but in the future we
//! will progressively relax those to exercise more combinations.

pub fn build(b: *Build) void {
    const elf_step = b.step("test-elf", "Run ELF tests");
    b.default_step = elf_step;

    const target: CrossTarget = .{
        .cpu_arch = .x86_64, // TODO relax this once ELF linker is able to handle other archs
        .os_tag = .linux,
    };

    elf_step.dependOn(testHelloStatic(b, .{ .target = target, .use_llvm = true }));
    elf_step.dependOn(testHelloStatic(b, .{ .target = target, .use_llvm = false }));
}

fn testHelloStatic(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "hello-static", opts);

    const exe = addExecutable(b, opts);
    addZigSourceBytes(exe,
        \\pub fn main() void {
        \\    @import("std").debug.print("Hello World!\n", .{});
        \\}
    );
    exe.linkage = .static;

    const run = b.addRunArtifact(exe);
    run.expectStdErrEqual("Hello World!\n");
    test_step.dependOn(&run.step);

    const check = exe.checkObject();
    check.checkStart();
    check.checkExact("header");
    check.checkExact("type EXEC");
    check.checkStart();
    check.checkExact("section headers");
    check.checkNotPresent("name .dynamic");
    test_step.dependOn(&check.step);

    return test_step;
}

const Options = struct {
    target: CrossTarget = .{ .os_tag = .linux },
    optimize: std.builtin.OptimizeMode = .Debug,
    use_llvm: bool = true,
};

fn addTestStep(b: *Build, comptime prefix: []const u8, opts: Options) *Step {
    const target = opts.target.zigTriple(b.allocator) catch @panic("OOM");
    const optimize = @tagName(opts.optimize);
    const use_llvm = if (opts.use_llvm) "llvm" else "no-llvm";
    const name = std.fmt.allocPrint(b.allocator, "test-elf-" ++ prefix ++ "-{s}-{s}-{s}", .{
        target,
        optimize,
        use_llvm,
    }) catch @panic("OOM");
    return b.step(name, "");
}

fn addExecutable(b: *Build, opts: Options) *Compile {
    return b.addExecutable(.{
        .name = "test",
        .target = opts.target,
        .optimize = opts.optimize,
        .single_threaded = true, // TODO temp until we teach linker how to handle TLS
        .use_llvm = opts.use_llvm,
        .use_lld = false,
    });
}

fn addZigSourceBytes(comp: *Compile, bytes: []const u8) void {
    const b = comp.step.owner;
    const file = WriteFile.create(b).add("a.zig", bytes);
    file.addStepDependencies(&comp.step);
    comp.root_src = file;
}

const std = @import("std");

const Build = std.Build;
const Compile = Step.Compile;
const CrossTarget = std.zig.CrossTarget;
const LazyPath = Build.LazyPath;
const Run = Step.Run;
const Step = Build.Step;
const WriteFile = Step.WriteFile;
