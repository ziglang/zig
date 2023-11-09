pub fn build(b: *Build) void {
    const test_step = b.step("test-link", "Run link tests");
    b.default_step = test_step;

    test_step.dependOn(@import("elf.zig").testAll(b));
    test_step.dependOn(@import("macho.zig").testAll(b));
}

pub const Options = struct {
    target: CrossTarget,
    optimize: std.builtin.OptimizeMode = .Debug,
    use_llvm: bool = true,
    use_lld: bool = false,
};

pub fn addTestStep(b: *Build, comptime prefix: []const u8, opts: Options) *Step {
    const target = opts.target.zigTriple(b.allocator) catch @panic("OOM");
    const optimize = @tagName(opts.optimize);
    const use_llvm = if (opts.use_llvm) "llvm" else "no-llvm";
    const name = std.fmt.allocPrint(b.allocator, "test-" ++ prefix ++ "-{s}-{s}-{s}", .{
        target,
        optimize,
        use_llvm,
    }) catch @panic("OOM");
    return b.step(name, "");
}

pub fn addExecutable(b: *Build, name: []const u8, opts: Options) *Compile {
    return b.addExecutable(.{
        .name = name,
        .target = opts.target,
        .optimize = opts.optimize,
        .use_llvm = opts.use_llvm,
        .use_lld = opts.use_lld,
    });
}

pub fn addObject(b: *Build, name: []const u8, opts: Options) *Compile {
    return b.addObject(.{
        .name = name,
        .target = opts.target,
        .optimize = opts.optimize,
        .use_llvm = opts.use_llvm,
        .use_lld = opts.use_lld,
    });
}

pub fn addStaticLibrary(b: *Build, name: []const u8, opts: Options) *Compile {
    return b.addStaticLibrary(.{
        .name = name,
        .target = opts.target,
        .optimize = opts.optimize,
        .use_llvm = opts.use_llvm,
        .use_lld = opts.use_lld,
    });
}

pub fn addSharedLibrary(b: *Build, name: []const u8, opts: Options) *Compile {
    return b.addSharedLibrary(.{
        .name = name,
        .target = opts.target,
        .optimize = opts.optimize,
        .use_llvm = opts.use_llvm,
        .use_lld = opts.use_lld,
    });
}

pub fn addRunArtifact(comp: *Compile) *Run {
    const b = comp.step.owner;
    const run = b.addRunArtifact(comp);
    run.skip_foreign_checks = true;
    return run;
}

pub fn addZigSourceBytes(comp: *Compile, bytes: []const u8) void {
    const b = comp.step.owner;
    const file = WriteFile.create(b).add("a.zig", bytes);
    file.addStepDependencies(&comp.step);
    comp.root_src = file;
}

pub fn addCSourceBytes(comp: *Compile, bytes: []const u8, flags: []const []const u8) void {
    const b = comp.step.owner;
    const file = WriteFile.create(b).add("a.c", bytes);
    comp.addCSourceFile(.{ .file = file, .flags = flags });
}

pub fn addCppSourceBytes(comp: *Compile, bytes: []const u8, flags: []const []const u8) void {
    const b = comp.step.owner;
    const file = WriteFile.create(b).add("a.cpp", bytes);
    comp.addCSourceFile(.{ .file = file, .flags = flags });
}

pub fn addAsmSourceBytes(comp: *Compile, bytes: []const u8) void {
    const b = comp.step.owner;
    const actual_bytes = std.fmt.allocPrint(b.allocator, "{s}\n", .{bytes}) catch @panic("OOM");
    const file = WriteFile.create(b).add("a.s", actual_bytes);
    comp.addAssemblyFile(file);
}

pub fn expectLinkErrors(comp: *Compile, test_step: *Step, expected_errors: Compile.ExpectedCompileErrors) void {
    comp.expect_errors = expected_errors;
    const bin_file = comp.getEmittedBin();
    bin_file.addStepDependencies(test_step);
}

const std = @import("std");

const Build = std.Build;
const Compile = Step.Compile;
const CrossTarget = std.zig.CrossTarget;
const Run = Step.Run;
const Step = Build.Step;
const WriteFile = Step.WriteFile;
