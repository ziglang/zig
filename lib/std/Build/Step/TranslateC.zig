const std = @import("std");
const Step = std.Build.Step;
const LazyPath = std.Build.LazyPath;
const fs = std.fs;
const mem = std.mem;

const TranslateC = @This();

pub const base_id: Step.Id = .translate_c;

step: Step,
source: std.Build.LazyPath,
include_dirs: std.ArrayList(std.Build.Module.IncludeDir),
c_macros: std.ArrayList([]const u8),
out_basename: []const u8,
target: std.Build.ResolvedTarget,
optimize: std.builtin.OptimizeMode,
output_file: std.Build.GeneratedFile,
link_libc: bool,
use_clang: bool,

pub const Options = struct {
    root_source_file: std.Build.LazyPath,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    link_libc: bool = true,
    use_clang: bool = true,
};

pub fn create(owner: *std.Build, options: Options) *TranslateC {
    const translate_c = owner.allocator.create(TranslateC) catch @panic("OOM");
    const source = options.root_source_file.dupe(owner);
    translate_c.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = "translate-c",
            .owner = owner,
            .makeFn = make,
        }),
        .source = source,
        .include_dirs = std.ArrayList(std.Build.Module.IncludeDir).init(owner.allocator),
        .c_macros = std.ArrayList([]const u8).init(owner.allocator),
        .out_basename = undefined,
        .target = options.target,
        .optimize = options.optimize,
        .output_file = .{ .step = &translate_c.step },
        .link_libc = options.link_libc,
        .use_clang = options.use_clang,
    };
    source.addStepDependencies(&translate_c.step);
    return translate_c;
}

pub const AddExecutableOptions = struct {
    name: ?[]const u8 = null,
    version: ?std.SemanticVersion = null,
    target: ?std.Build.ResolvedTarget = null,
    optimize: ?std.builtin.OptimizeMode = null,
    linkage: ?std.builtin.LinkMode = null,
};

pub fn getOutput(translate_c: *TranslateC) std.Build.LazyPath {
    return .{ .generated = .{ .file = &translate_c.output_file } };
}

/// Creates a step to build an executable from the translated source.
pub fn addExecutable(translate_c: *TranslateC, options: AddExecutableOptions) *Step.Compile {
    return translate_c.step.owner.addExecutable(.{
        .root_source_file = translate_c.getOutput(),
        .name = options.name orelse "translated_c",
        .version = options.version,
        .target = options.target orelse translate_c.target,
        .optimize = options.optimize orelse translate_c.optimize,
        .linkage = options.linkage,
    });
}

/// Creates a module from the translated source and adds it to the package's
/// module set making it available to other packages which depend on this one.
/// `createModule` can be used instead to create a private module.
pub fn addModule(translate_c: *TranslateC, name: []const u8) *std.Build.Module {
    return translate_c.step.owner.addModule(name, .{
        .root_source_file = translate_c.getOutput(),
    });
}

/// Creates a private module from the translated source to be used by the
/// current package, but not exposed to other packages depending on this one.
/// `addModule` can be used instead to create a public module.
pub fn createModule(translate_c: *TranslateC) *std.Build.Module {
    return translate_c.step.owner.createModule(.{
        .root_source_file = translate_c.getOutput(),
        .target = translate_c.target,
        .optimize = translate_c.optimize,
        .link_libc = translate_c.link_libc,
    });
}

pub fn addAfterIncludePath(translate_c: *TranslateC, lazy_path: LazyPath) void {
    const b = translate_c.step.owner;
    translate_c.include_dirs.append(.{ .path_after = lazy_path.dupe(b) }) catch
        @panic("OOM");
    lazy_path.addStepDependencies(&translate_c.step);
}

pub fn addSystemIncludePath(translate_c: *TranslateC, lazy_path: LazyPath) void {
    const b = translate_c.step.owner;
    translate_c.include_dirs.append(.{ .path_system = lazy_path.dupe(b) }) catch
        @panic("OOM");
    lazy_path.addStepDependencies(&translate_c.step);
}

pub fn addIncludePath(translate_c: *TranslateC, lazy_path: LazyPath) void {
    const b = translate_c.step.owner;
    translate_c.include_dirs.append(.{ .path = lazy_path.dupe(b) }) catch
        @panic("OOM");
    lazy_path.addStepDependencies(&translate_c.step);
}

pub fn addConfigHeader(translate_c: *TranslateC, config_header: *Step.ConfigHeader) void {
    translate_c.include_dirs.append(.{ .config_header_step = config_header }) catch
        @panic("OOM");
    translate_c.step.dependOn(&config_header.step);
}

pub fn addSystemFrameworkPath(translate_c: *TranslateC, directory_path: LazyPath) void {
    const b = translate_c.step.owner;
    translate_c.include_dirs.append(.{ .framework_path_system = directory_path.dupe(b) }) catch
        @panic("OOM");
    directory_path.addStepDependencies(&translate_c.step);
}

pub fn addFrameworkPath(translate_c: *TranslateC, directory_path: LazyPath) void {
    const b = translate_c.step.owner;
    translate_c.include_dirs.append(.{ .framework_path = directory_path.dupe(b) }) catch
        @panic("OOM");
    directory_path.addStepDependencies(&translate_c.step);
}

pub fn addCheckFile(translate_c: *TranslateC, expected_matches: []const []const u8) *Step.CheckFile {
    return Step.CheckFile.create(
        translate_c.step.owner,
        translate_c.getOutput(),
        .{ .expected_matches = expected_matches },
    );
}

/// If the value is omitted, it is set to 1.
/// `name` and `value` need not live longer than the function call.
pub fn defineCMacro(translate_c: *TranslateC, name: []const u8, value: ?[]const u8) void {
    const macro = translate_c.step.owner.fmt("{s}={s}", .{ name, value orelse "1" });
    translate_c.c_macros.append(macro) catch @panic("OOM");
}

/// name_and_value looks like [name]=[value]. If the value is omitted, it is set to 1.
pub fn defineCMacroRaw(translate_c: *TranslateC, name_and_value: []const u8) void {
    translate_c.c_macros.append(translate_c.step.owner.dupe(name_and_value)) catch @panic("OOM");
}

fn make(step: *Step, options: Step.MakeOptions) !void {
    const prog_node = options.progress_node;
    const b = step.owner;
    const translate_c: *TranslateC = @fieldParentPtr("step", step);

    var argv_list = std.ArrayList([]const u8).init(b.allocator);
    try argv_list.append(b.graph.zig_exe);
    try argv_list.append("translate-c");
    if (translate_c.link_libc) {
        try argv_list.append("-lc");
    }
    if (!translate_c.use_clang) {
        try argv_list.append("-fno-clang");
    }

    try argv_list.append("--listen=-");

    if (!translate_c.target.query.isNative()) {
        try argv_list.append("-target");
        try argv_list.append(try translate_c.target.query.zigTriple(b.allocator));
    }

    switch (translate_c.optimize) {
        .Debug => {}, // Skip since it's the default.
        else => try argv_list.append(b.fmt("-O{s}", .{@tagName(translate_c.optimize)})),
    }

    for (translate_c.include_dirs.items) |include_dir| {
        try include_dir.appendZigProcessFlags(b, &argv_list, step);
    }

    for (translate_c.c_macros.items) |c_macro| {
        try argv_list.append("-D");
        try argv_list.append(c_macro);
    }

    const c_source_path = translate_c.source.getPath2(b, step);
    try argv_list.append(c_source_path);

    const output_dir = try step.evalZigProcess(argv_list.items, prog_node, false);

    const basename = std.fs.path.stem(std.fs.path.basename(c_source_path));
    translate_c.out_basename = b.fmt("{s}.zig", .{basename});
    translate_c.output_file.path = output_dir.?.joinString(b.allocator, translate_c.out_basename) catch @panic("OOM");
}
