target: std.Target,
zig_backend: std.builtin.CompilerBackend,
output_mode: std.builtin.OutputMode,
link_mode: std.builtin.LinkMode,
unwind_tables: std.builtin.UnwindTables,
is_test: bool,
single_threaded: bool,
link_libc: bool,
link_libcpp: bool,
optimize_mode: std.builtin.OptimizeMode,
error_tracing: bool,
valgrind: bool,
sanitize_thread: bool,
fuzz: bool,
pic: bool,
pie: bool,
strip: bool,
code_model: std.builtin.CodeModel,
omit_frame_pointer: bool,
wasi_exec_model: std.builtin.WasiExecModel,

/// Compute an abstract hash representing this `Builtin`. This is *not* a hash
/// of the resulting file contents.
pub fn hash(opts: @This()) [std.Build.Cache.bin_digest_len]u8 {
    var h: Cache.Hasher = Cache.hasher_init;
    inline for (@typeInfo(@This()).@"struct".fields) |f| {
        if (comptime std.mem.eql(u8, f.name, "target")) {
            // This needs special handling.
            std.hash.autoHash(&h, opts.target.cpu);
            std.hash.autoHash(&h, opts.target.os.tag);
            std.hash.autoHash(&h, opts.target.os.versionRange());
            std.hash.autoHash(&h, opts.target.abi);
            std.hash.autoHash(&h, opts.target.ofmt);
            std.hash.autoHash(&h, opts.target.dynamic_linker);
        } else {
            std.hash.autoHash(&h, @field(opts, f.name));
        }
    }
    return h.finalResult();
}

pub fn generate(opts: @This(), allocator: Allocator) Allocator.Error![:0]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    try append(opts, &buffer);
    return buffer.toOwnedSliceSentinel(0);
}

pub fn append(opts: @This(), buffer: *std.ArrayList(u8)) Allocator.Error!void {
    const target = opts.target;
    const arch_family_name = @tagName(target.cpu.arch.family());
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
        \\pub const output_mode: std.builtin.OutputMode = .{p_};
        \\pub const link_mode: std.builtin.LinkMode = .{p_};
        \\pub const unwind_tables: std.builtin.UnwindTables = .{p_};
        \\pub const is_test = {};
        \\pub const single_threaded = {};
        \\pub const abi: std.Target.Abi = .{p_};
        \\pub const cpu: std.Target.Cpu = .{{
        \\    .arch = .{p_},
        \\    .model = &std.Target.{p_}.cpu.{p_},
        \\    .features = std.Target.{p_}.featureSet(&.{{
        \\
    , .{
        build_options.version,
        std.zig.fmtId(@tagName(zig_backend)),
        std.zig.fmtId(@tagName(opts.output_mode)),
        std.zig.fmtId(@tagName(opts.link_mode)),
        std.zig.fmtId(@tagName(opts.unwind_tables)),
        opts.is_test,
        opts.single_threaded,
        std.zig.fmtId(@tagName(target.abi)),
        std.zig.fmtId(@tagName(target.cpu.arch)),
        std.zig.fmtId(arch_family_name),
        std.zig.fmtId(target.cpu.model.name),
        std.zig.fmtId(arch_family_name),
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
        \\pub const os: std.Target.Os = .{{
        \\    .tag = .{p_},
        \\    .version_range = .{{
    ,
        .{std.zig.fmtId(@tagName(target.os.tag))},
    );

    switch (target.os.versionRange()) {
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
            \\        .android = {},
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

            linux.android,
        }),
        .hurd => |hurd| try buffer.writer().print(
            \\ .hurd = .{{
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
            hurd.range.min.major,
            hurd.range.min.minor,
            hurd.range.min.patch,

            hurd.range.max.major,
            hurd.range.max.minor,
            hurd.range.max.patch,

            hurd.glibc.major,
            hurd.glibc.minor,
            hurd.glibc.patch,
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
            \\    .dynamic_linker = .init("{s}"),
            \\}};
            \\
        , .{dl});
    } else {
        try buffer.appendSlice(
            \\    .dynamic_linker = .none,
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
        \\pub const object_format: std.Target.ObjectFormat = .{p_};
        \\pub const mode: std.builtin.OptimizeMode = .{p_};
        \\pub const link_libc = {};
        \\pub const link_libcpp = {};
        \\pub const have_error_return_tracing = {};
        \\pub const valgrind_support = {};
        \\pub const sanitize_thread = {};
        \\pub const fuzz = {};
        \\pub const position_independent_code = {};
        \\pub const position_independent_executable = {};
        \\pub const strip_debug_info = {};
        \\pub const code_model: std.builtin.CodeModel = .{p_};
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
        opts.fuzz,
        opts.pic,
        opts.pie,
        opts.strip,
        std.zig.fmtId(@tagName(opts.code_model)),
        opts.omit_frame_pointer,
    });

    if (target.os.tag == .wasi) {
        try buffer.writer().print(
            \\pub const wasi_exec_model: std.builtin.WasiExecModel = .{p_};
            \\
        , .{std.zig.fmtId(@tagName(opts.wasi_exec_model))});
    }

    if (opts.is_test) {
        try buffer.appendSlice(
            \\pub var test_functions: []const std.builtin.TestFn = &.{}; // overwritten later
            \\
        );
    }
}

/// This essentially takes the place of `Zcu.PerThread.updateFile`, but for 'builtin' modules.
/// Instead of reading the file from disk, its contents are generated in-memory.
pub fn populateFile(opts: @This(), gpa: Allocator, file: *File) Allocator.Error!void {
    assert(file.is_builtin);
    assert(file.status == .never_loaded);
    assert(file.source == null);
    assert(file.tree == null);
    assert(file.zir == null);

    file.source = try opts.generate(gpa);

    log.debug("parsing and generating 'builtin.zig'", .{});

    file.tree = try std.zig.Ast.parse(gpa, file.source.?, .zig);
    assert(file.tree.?.errors.len == 0); // builtin.zig must parse

    file.zir = try AstGen.generate(gpa, file.tree.?);
    assert(!file.zir.?.hasCompileErrors()); // builtin.zig must not have astgen errors
    file.status = .success;
}

/// After `populateFile` succeeds, call this function to write the generated file out to disk
/// if necessary. This is useful for external tooling such as debuggers.
/// Assumes that `file.mod` is correctly set to the builtin module.
pub fn updateFileOnDisk(file: *File, comp: *Compilation) !void {
    assert(file.is_builtin);
    assert(file.status == .success);
    assert(file.source != null);

    const root_dir, const sub_path = file.path.openInfo(comp.dirs);

    if (root_dir.statFile(sub_path)) |stat| {
        if (stat.size != file.source.?.len) {
            std.log.warn(
                "the cached file '{}' had the wrong size. Expected {d}, found {d}. " ++
                    "Overwriting with correct file contents now",
                .{ file.path.fmt(comp), file.source.?.len, stat.size },
            );
        } else {
            file.stat = .{
                .size = stat.size,
                .inode = stat.inode,
                .mtime = stat.mtime,
            };
            return;
        }
    } else |err| switch (err) {
        error.FileNotFound => {},

        error.WouldBlock => unreachable, // not asking for non-blocking I/O
        error.BadPathName => unreachable, // it's always "o/digest/builtin.zig"
        error.NameTooLong => unreachable, // it's always "o/digest/builtin.zig"

        // We don't expect the file to be a pipe, but can't mark `error.PipeBusy` as `unreachable`,
        // because the user could always replace the file on disk.
        else => |e| return e,
    }

    // `make_path` matters because the dir hasn't actually been created yet.
    var af = try root_dir.atomicFile(sub_path, .{ .make_path = true });
    defer af.deinit();
    try af.file.writeAll(file.source.?);
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
        .size = file.source.?.len,
        .inode = 0, // dummy value
        .mtime = 0, // dummy value
    };
}

const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const Cache = std.Build.Cache;
const build_options = @import("build_options");
const Module = @import("Package/Module.zig");
const assert = std.debug.assert;
const AstGen = std.zig.AstGen;
const File = @import("Zcu.zig").File;
const Compilation = @import("Compilation.zig");
const log = std.log.scoped(.builtin);
