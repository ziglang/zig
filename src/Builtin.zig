target: std.Target,
zig_backend: std.builtin.CompilerBackend,
output_mode: std.builtin.OutputMode,
link_mode: std.builtin.LinkMode,
is_test: bool,
single_threaded: bool,
link_libc: bool,
link_libcpp: bool,
optimize_mode: std.builtin.OptimizeMode,
error_tracing: bool,
valgrind: bool,
sanitize_thread: bool,
pic: bool,
pie: bool,
strip: bool,
code_model: std.builtin.CodeModel,
omit_frame_pointer: bool,
wasi_exec_model: std.builtin.WasiExecModel,

pub fn generate(opts: @This(), allocator: Allocator) Allocator.Error![:0]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    try append(opts, &buffer);
    return buffer.toOwnedSliceSentinel(0);
}

pub fn append(opts: @This(), buffer: *std.ArrayList(u8)) Allocator.Error!void {
    const target = opts.target;
    const generic_arch_name = target.cpu.arch.genericName();
    const zig_backend = opts.zig_backend;

    @setEvalBranchQuota(4000);
    try buffer.writer().print(
        \\const std = @import("std");
        \\/// Zig version. When writing code that supports multiple versions of Zig, prefer
        \\/// feature detection (i.e. with `@hasDecl` or `@hasField`) over version checks.
        \\pub const zig_version = std.SemanticVersion.parse(zig_version_string) catch unreachable;
        \\pub const zig_version_string = "{s}";
        \\pub const zig_backend = std.builtin.CompilerBackend.{p_};
        \\
        \\pub const output_mode = std.builtin.OutputMode.{p_};
        \\pub const link_mode = std.builtin.LinkMode.{p_};
        \\pub const is_test = {};
        \\pub const single_threaded = {};
        \\pub const abi = std.Target.Abi.{p_};
        \\pub const cpu: std.Target.Cpu = .{{
        \\    .arch = .{p_},
        \\    .model = &std.Target.{p_}.cpu.{p_},
        \\    .features = std.Target.{p_}.featureSet(&[_]std.Target.{p_}.Feature{{
        \\
    , .{
        build_options.version,
        std.zig.fmtId(@tagName(zig_backend)),
        std.zig.fmtId(@tagName(opts.output_mode)),
        std.zig.fmtId(@tagName(opts.link_mode)),
        opts.is_test,
        opts.single_threaded,
        std.zig.fmtId(@tagName(target.abi)),
        std.zig.fmtId(@tagName(target.cpu.arch)),
        std.zig.fmtId(generic_arch_name),
        std.zig.fmtId(target.cpu.model.name),
        std.zig.fmtId(generic_arch_name),
        std.zig.fmtId(generic_arch_name),
    });

    for (target.cpu.arch.allFeaturesList(), 0..) |feature, index_usize| {
        const index = @as(std.Target.Cpu.Feature.Set.Index, @intCast(index_usize));
        const is_enabled = target.cpu.features.isEnabled(index);
        if (is_enabled) {
            try buffer.writer().print("        .{p_},\n", .{std.zig.fmtId(feature.name)});
        }
    }
    try buffer.writer().print(
        \\    }}),
        \\}};
        \\pub const os = std.Target.Os{{
        \\    .tag = .{p_},
        \\    .version_range = .{{
    ,
        .{std.zig.fmtId(@tagName(target.os.tag))},
    );

    switch (target.os.getVersionRange()) {
        .none => try buffer.appendSlice(" .none = {} },\n"),
        .semver => |semver| try buffer.writer().print(
            \\ .semver = .{{
            \\        .min = .{{
            \\            .major = {},
            \\            .minor = {},
            \\            .patch = {},
            \\        }},
            \\        .max = .{{
            \\            .major = {},
            \\            .minor = {},
            \\            .patch = {},
            \\        }},
            \\    }}}},
            \\
        , .{
            semver.min.major,
            semver.min.minor,
            semver.min.patch,

            semver.max.major,
            semver.max.minor,
            semver.max.patch,
        }),
        .linux => |linux| try buffer.writer().print(
            \\ .linux = .{{
            \\        .range = .{{
            \\            .min = .{{
            \\                .major = {},
            \\                .minor = {},
            \\                .patch = {},
            \\            }},
            \\            .max = .{{
            \\                .major = {},
            \\                .minor = {},
            \\                .patch = {},
            \\            }},
            \\        }},
            \\        .glibc = .{{
            \\            .major = {},
            \\            .minor = {},
            \\            .patch = {},
            \\        }},
            \\    }}}},
            \\
        , .{
            linux.range.min.major,
            linux.range.min.minor,
            linux.range.min.patch,

            linux.range.max.major,
            linux.range.max.minor,
            linux.range.max.patch,

            linux.glibc.major,
            linux.glibc.minor,
            linux.glibc.patch,
        }),
        .windows => |windows| try buffer.writer().print(
            \\ .windows = .{{
            \\        .min = {c},
            \\        .max = {c},
            \\    }}}},
            \\
        , .{ windows.min, windows.max }),
    }
    try buffer.appendSlice(
        \\};
        \\pub const target: std.Target = .{
        \\    .cpu = cpu,
        \\    .os = os,
        \\    .abi = abi,
        \\    .ofmt = object_format,
        \\
    );

    if (target.dynamic_linker.get()) |dl| {
        try buffer.writer().print(
            \\    .dynamic_linker = std.Target.DynamicLinker.init("{s}"),
            \\}};
            \\
        , .{dl});
    } else {
        try buffer.appendSlice(
            \\    .dynamic_linker = std.Target.DynamicLinker.none,
            \\};
            \\
        );
    }

    // This is so that compiler_rt and libc.zig libraries know whether they
    // will eventually be linked with libc. They make different decisions
    // about what to export depending on whether another libc will be linked
    // in. For example, compiler_rt will not export the __chkstk symbol if it
    // knows libc will provide it, and likewise c.zig will not export memcpy.
    const link_libc = opts.link_libc;

    try buffer.writer().print(
        \\pub const object_format = std.Target.ObjectFormat.{p_};
        \\pub const mode = std.builtin.OptimizeMode.{p_};
        \\pub const link_libc = {};
        \\pub const link_libcpp = {};
        \\pub const have_error_return_tracing = {};
        \\pub const valgrind_support = {};
        \\pub const sanitize_thread = {};
        \\pub const position_independent_code = {};
        \\pub const position_independent_executable = {};
        \\pub const strip_debug_info = {};
        \\pub const code_model = std.builtin.CodeModel.{p_};
        \\pub const omit_frame_pointer = {};
        \\
    , .{
        std.zig.fmtId(@tagName(target.ofmt)),
        std.zig.fmtId(@tagName(opts.optimize_mode)),
        link_libc,
        opts.link_libcpp,
        opts.error_tracing,
        opts.valgrind,
        opts.sanitize_thread,
        opts.pic,
        opts.pie,
        opts.strip,
        std.zig.fmtId(@tagName(opts.code_model)),
        opts.omit_frame_pointer,
    });

    if (target.os.tag == .wasi) {
        try buffer.writer().print(
            \\pub const wasi_exec_model = std.builtin.WasiExecModel.{p_};
            \\
        , .{std.zig.fmtId(@tagName(opts.wasi_exec_model))});
    }

    if (opts.is_test) {
        try buffer.appendSlice(
            \\pub var test_functions: []const std.builtin.TestFn = undefined; // overwritten later
            \\
        );
    }
}

pub fn populateFile(comp: *Compilation, mod: *Module, file: *File) !void {
    assert(file.source_loaded == true);

    if (mod.root.statFile(mod.root_src_path)) |stat| {
        if (stat.size != file.source.len) {
            std.log.warn(
                "the cached file '{}{s}' had the wrong size. Expected {d}, found {d}. " ++
                    "Overwriting with correct file contents now",
                .{ mod.root, mod.root_src_path, file.source.len, stat.size },
            );

            try writeFile(file, mod);
        } else {
            file.stat = .{
                .size = stat.size,
                .inode = stat.inode,
                .mtime = stat.mtime,
            };
        }
    } else |err| switch (err) {
        error.BadPathName => unreachable, // it's always "builtin.zig"
        error.NameTooLong => unreachable, // it's always "builtin.zig"
        error.PipeBusy => unreachable, // it's not a pipe
        error.WouldBlock => unreachable, // not asking for non-blocking I/O

        error.FileNotFound => try writeFile(file, mod),

        else => |e| return e,
    }

    log.debug("parsing and generating '{s}'", .{mod.root_src_path});

    file.tree = try std.zig.Ast.parse(comp.gpa, file.source, .zig);
    assert(file.tree.errors.len == 0); // builtin.zig must parse
    file.tree_loaded = true;

    file.zir = try AstGen.generate(comp.gpa, file.tree);
    assert(!file.zir.hasCompileErrors()); // builtin.zig must not have astgen errors
    file.zir_loaded = true;
    file.status = .success_zir;
    // Note that whilst we set `zir_loaded` here, we populated `path_digest`
    // all the way back in `Package.Module.create`.
}

fn writeFile(file: *File, mod: *Module) !void {
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var af = try mod.root.atomicFile(mod.root_src_path, .{ .make_path = true }, &buf);
    defer af.deinit();
    try af.file.writeAll(file.source);
    af.finish() catch |err| switch (err) {
        error.AccessDenied => switch (builtin.os.tag) {
            .windows => {
                // Very likely happened due to another process or thread
                // simultaneously creating the same, correct builtin.zig file.
                // This is not a problem; ignore it.
            },
            else => return err,
        },
        else => return err,
    };

    file.stat = .{
        .size = file.source.len,
        .inode = 0, // dummy value
        .mtime = 0, // dummy value
    };
}

const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const build_options = @import("build_options");
const Module = @import("Package/Module.zig");
const assert = std.debug.assert;
const AstGen = std.zig.AstGen;
const File = @import("Module.zig").File;
const Compilation = @import("Compilation.zig");
const log = std.log.scoped(.builtin);
