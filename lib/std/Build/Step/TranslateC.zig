const std = @import("std");
const Step = std.Build.Step;
const fs = std.fs;
const mem = std.mem;

const TranslateC = @This();

pub const base_id: Step.Id = .translate_c;

step: Step,
source: std.Build.LazyPath,
include_dirs: std.ArrayList([]const u8),
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
    translate_c.* = TranslateC{
        .step = Step.init(.{
            .id = base_id,
            .name = "translate-c",
            .owner = owner,
            .makeFn = make,
        }),
        .source = source,
        .include_dirs = std.ArrayList([]const u8).init(owner.allocator),
        .c_macros = std.ArrayList([]const u8).init(owner.allocator),
        .out_basename = undefined,
        .target = options.target,
        .optimize = options.optimize,
        .output_file = std.Build.GeneratedFile{ .step = &translate_c.step },
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
    });
}

pub fn addIncludeDir(translate_c: *TranslateC, include_dir: []const u8) void {
    translate_c.include_dirs.append(translate_c.step.owner.dupePath(include_dir)) catch @panic("OOM");
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
    const macro = std.Build.constructranslate_cMacro(translate_c.step.owner.allocator, name, value);
    translate_c.c_macros.append(macro) catch @panic("OOM");
}

/// name_and_value looks like [name]=[value]. If the value is omitted, it is set to 1.
pub fn defineCMacroRaw(translate_c: *TranslateC, name_and_value: []const u8) void {
    translate_c.c_macros.append(translate_c.step.owner.dupe(name_and_value)) catch @panic("OOM");
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
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
        try argv_list.append("-I");
        try argv_list.append(include_dir);
    }

    for (translate_c.c_macros.items) |c_macro| {
        try argv_list.append("-D");
        try argv_list.append(c_macro);
    }

    try argv_list.append(translate_c.source.getPath2(b, step));

    const output_path = try step.evalZigProcess(argv_list.items, prog_node);

    translate_c.out_basename = fs.path.basename(output_path.?);
    const output_dir = fs.path.dirname(output_path.?).?;

    translate_c.output_file.path = b.pathJoin(&.{ output_dir, translate_c.out_basename });
}
