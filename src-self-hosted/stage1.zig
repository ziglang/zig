//! This is the main entry point for the Zig/C++ hybrid compiler (stage1).
//! It has the functions exported from Zig, called in C++, and bindings for
//! the functions exported from C++, called from Zig.

const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const build_options = @import("build_options");
const stage2 = @import("main.zig");
const fatal = stage2.fatal;
const CrossTarget = std.zig.CrossTarget;
const Target = std.Target;

comptime {
    assert(std.builtin.link_libc);
    assert(build_options.is_stage1);
    _ = @import("compiler_rt");
}

pub const log = stage2.log;
pub const log_level = stage2.log_level;

pub export fn main(argc: c_int, argv: [*]const [*:0]const u8) c_int {
    std.debug.maybeEnableSegfaultHandler();

    const gpa = std.heap.c_allocator;
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = &arena_instance.allocator;

    const args = arena.alloc([]const u8, @intCast(usize, argc)) catch fatal("out of memory", .{});
    for (args) |*arg, i| {
        arg.* = mem.spanZ(argv[i]);
    }
    stage2.mainArgs(gpa, arena, args) catch |err| fatal("{}", .{err});
    return 0;
}

// ABI warning
export fn stage2_panic(ptr: [*]const u8, len: usize) void {
    @panic(ptr[0..len]);
}

// ABI warning
const Error = extern enum {
    None,
    OutOfMemory,
    InvalidFormat,
    SemanticAnalyzeFail,
    AccessDenied,
    Interrupted,
    SystemResources,
    FileNotFound,
    FileSystem,
    FileTooBig,
    DivByZero,
    Overflow,
    PathAlreadyExists,
    Unexpected,
    ExactDivRemainder,
    NegativeDenominator,
    ShiftedOutOneBits,
    CCompileErrors,
    EndOfFile,
    IsDir,
    NotDir,
    UnsupportedOperatingSystem,
    SharingViolation,
    PipeBusy,
    PrimitiveTypeNotFound,
    CacheUnavailable,
    PathTooLong,
    CCompilerCannotFindFile,
    NoCCompilerInstalled,
    ReadingDepFile,
    InvalidDepFile,
    MissingArchitecture,
    MissingOperatingSystem,
    UnknownArchitecture,
    UnknownOperatingSystem,
    UnknownABI,
    InvalidFilename,
    DiskQuota,
    DiskSpace,
    UnexpectedWriteFailure,
    UnexpectedSeekFailure,
    UnexpectedFileTruncationFailure,
    Unimplemented,
    OperationAborted,
    BrokenPipe,
    NoSpaceLeft,
    NotLazy,
    IsAsync,
    ImportOutsidePkgPath,
    UnknownCpuModel,
    UnknownCpuFeature,
    InvalidCpuFeatures,
    InvalidLlvmCpuFeaturesFormat,
    UnknownApplicationBinaryInterface,
    ASTUnitFailure,
    BadPathName,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    NoDevice,
    DeviceBusy,
    UnableToSpawnCCompiler,
    CCompilerExitCode,
    CCompilerCrashed,
    CCompilerCannotFindHeaders,
    LibCRuntimeNotFound,
    LibCStdLibHeaderNotFound,
    LibCKernel32LibNotFound,
    UnsupportedArchitecture,
    WindowsSdkNotFound,
    UnknownDynamicLinkerPath,
    TargetHasNoDynamicLinker,
    InvalidAbiVersion,
    InvalidOperatingSystemVersion,
    UnknownClangOption,
    NestedResponseFile,
    ZigIsTheCCompiler,
    FileBusy,
    Locked,
};

// ABI warning
export fn stage2_attach_segfault_handler() void {
    if (std.debug.runtime_safety and std.debug.have_segfault_handling_support) {
        std.debug.attachSegfaultHandler();
    }
}

// ABI warning
export fn stage2_progress_create() *std.Progress {
    const ptr = std.heap.c_allocator.create(std.Progress) catch @panic("out of memory");
    ptr.* = std.Progress{};
    return ptr;
}

// ABI warning
export fn stage2_progress_destroy(progress: *std.Progress) void {
    std.heap.c_allocator.destroy(progress);
}

// ABI warning
export fn stage2_progress_start_root(
    progress: *std.Progress,
    name_ptr: [*]const u8,
    name_len: usize,
    estimated_total_items: usize,
) *std.Progress.Node {
    return progress.start(
        name_ptr[0..name_len],
        if (estimated_total_items == 0) null else estimated_total_items,
    ) catch @panic("timer unsupported");
}

// ABI warning
export fn stage2_progress_disable_tty(progress: *std.Progress) void {
    progress.terminal = null;
}

// ABI warning
export fn stage2_progress_start(
    node: *std.Progress.Node,
    name_ptr: [*]const u8,
    name_len: usize,
    estimated_total_items: usize,
) *std.Progress.Node {
    const child_node = std.heap.c_allocator.create(std.Progress.Node) catch @panic("out of memory");
    child_node.* = node.start(
        name_ptr[0..name_len],
        if (estimated_total_items == 0) null else estimated_total_items,
    );
    child_node.activate();
    return child_node;
}

// ABI warning
export fn stage2_progress_end(node: *std.Progress.Node) void {
    node.end();
    if (&node.context.root != node) {
        std.heap.c_allocator.destroy(node);
    }
}

// ABI warning
export fn stage2_progress_complete_one(node: *std.Progress.Node) void {
    node.completeOne();
}

// ABI warning
export fn stage2_progress_update_node(node: *std.Progress.Node, done_count: usize, total_count: usize) void {
    node.completed_items = done_count;
    node.estimated_total_items = total_count;
    node.activate();
    node.context.maybeRefresh();
}

// ABI warning
const Stage2Target = extern struct {
    arch: c_int,
    vendor: c_int,

    abi: c_int,
    os: c_int,

    is_native_os: bool,
    is_native_cpu: bool,

    llvm_cpu_name: ?[*:0]const u8,
    llvm_cpu_features: ?[*:0]const u8,
    cpu_builtin_str: ?[*:0]const u8,
    os_builtin_str: ?[*:0]const u8,

    dynamic_linker: ?[*:0]const u8,

    llvm_cpu_features_asm_ptr: [*]const [*:0]const u8,
    llvm_cpu_features_asm_len: usize,

    fn fromTarget(self: *Stage2Target, cross_target: CrossTarget) !void {
        const allocator = std.heap.c_allocator;

        var dynamic_linker: ?[*:0]u8 = null;
        const target = try crossTargetToTarget(cross_target, &dynamic_linker);

        const generic_arch_name = target.cpu.arch.genericName();
        var cpu_builtin_str_buffer = try std.ArrayListSentineled(u8, 0).allocPrint(allocator,
            \\Cpu{{
            \\    .arch = .{},
            \\    .model = &Target.{}.cpu.{},
            \\    .features = Target.{}.featureSet(&[_]Target.{}.Feature{{
            \\
        , .{
            @tagName(target.cpu.arch),
            generic_arch_name,
            target.cpu.model.name,
            generic_arch_name,
            generic_arch_name,
        });
        defer cpu_builtin_str_buffer.deinit();

        var llvm_features_buffer = try std.ArrayListSentineled(u8, 0).initSize(allocator, 0);
        defer llvm_features_buffer.deinit();

        // Unfortunately we have to do the work twice, because Clang does not support
        // the same command line parameters for CPU features when assembling code as it does
        // when compiling C code.
        var asm_features_list = std.ArrayList([*:0]const u8).init(allocator);
        defer asm_features_list.deinit();

        for (target.cpu.arch.allFeaturesList()) |feature, index_usize| {
            const index = @intCast(Target.Cpu.Feature.Set.Index, index_usize);
            const is_enabled = target.cpu.features.isEnabled(index);

            if (feature.llvm_name) |llvm_name| {
                const plus_or_minus = "-+"[@boolToInt(is_enabled)];
                try llvm_features_buffer.append(plus_or_minus);
                try llvm_features_buffer.appendSlice(llvm_name);
                try llvm_features_buffer.appendSlice(",");
            }

            if (is_enabled) {
                // TODO some kind of "zig identifier escape" function rather than
                // unconditionally using @"" syntax
                try cpu_builtin_str_buffer.appendSlice("        .@\"");
                try cpu_builtin_str_buffer.appendSlice(feature.name);
                try cpu_builtin_str_buffer.appendSlice("\",\n");
            }
        }

        switch (target.cpu.arch) {
            .riscv32, .riscv64 => {
                if (Target.riscv.featureSetHas(target.cpu.features, .relax)) {
                    try asm_features_list.append("-mrelax");
                } else {
                    try asm_features_list.append("-mno-relax");
                }
            },
            else => {
                // TODO
                // Argh, why doesn't the assembler accept the list of CPU features?!
                // I don't see a way to do this other than hard coding everything.
            },
        }

        try cpu_builtin_str_buffer.appendSlice(
            \\    }),
            \\};
            \\
        );

        assert(mem.endsWith(u8, llvm_features_buffer.span(), ","));
        llvm_features_buffer.shrink(llvm_features_buffer.len() - 1);

        var os_builtin_str_buffer = try std.ArrayListSentineled(u8, 0).allocPrint(allocator,
            \\Os{{
            \\    .tag = .{},
            \\    .version_range = .{{
        , .{@tagName(target.os.tag)});
        defer os_builtin_str_buffer.deinit();

        // We'll re-use the OS version range builtin string for the cache hash.
        const os_builtin_str_ver_start_index = os_builtin_str_buffer.len();

        @setEvalBranchQuota(2000);
        switch (target.os.tag) {
            .freestanding,
            .ananas,
            .cloudabi,
            .dragonfly,
            .fuchsia,
            .ios,
            .kfreebsd,
            .lv2,
            .solaris,
            .haiku,
            .minix,
            .rtems,
            .nacl,
            .cnk,
            .aix,
            .cuda,
            .nvcl,
            .amdhsa,
            .ps4,
            .elfiamcu,
            .tvos,
            .watchos,
            .mesa3d,
            .contiki,
            .amdpal,
            .hermit,
            .hurd,
            .wasi,
            .emscripten,
            .uefi,
            .other,
            => try os_builtin_str_buffer.appendSlice(" .none = {} }\n"),

            .freebsd,
            .macosx,
            .netbsd,
            .openbsd,
            => try os_builtin_str_buffer.outStream().print(
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
                target.os.version_range.semver.min.major,
                target.os.version_range.semver.min.minor,
                target.os.version_range.semver.min.patch,

                target.os.version_range.semver.max.major,
                target.os.version_range.semver.max.minor,
                target.os.version_range.semver.max.patch,
            }),

            .linux => try os_builtin_str_buffer.outStream().print(
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
                target.os.version_range.linux.range.min.major,
                target.os.version_range.linux.range.min.minor,
                target.os.version_range.linux.range.min.patch,

                target.os.version_range.linux.range.max.major,
                target.os.version_range.linux.range.max.minor,
                target.os.version_range.linux.range.max.patch,

                target.os.version_range.linux.glibc.major,
                target.os.version_range.linux.glibc.minor,
                target.os.version_range.linux.glibc.patch,
            }),

            .windows => try os_builtin_str_buffer.outStream().print(
                \\ .windows = .{{
                \\        .min = {s},
                \\        .max = {s},
                \\    }}}},
                \\
            , .{
                target.os.version_range.windows.min,
                target.os.version_range.windows.max,
            }),
        }
        try os_builtin_str_buffer.appendSlice("};\n");

        const glibc_or_darwin_version = blk: {
            if (target.isGnuLibC()) {
                const stage1_glibc = try std.heap.c_allocator.create(Stage2SemVer);
                const stage2_glibc = target.os.version_range.linux.glibc;
                stage1_glibc.* = .{
                    .major = stage2_glibc.major,
                    .minor = stage2_glibc.minor,
                    .patch = stage2_glibc.patch,
                };
                break :blk stage1_glibc;
            } else if (target.isDarwin()) {
                const stage1_semver = try std.heap.c_allocator.create(Stage2SemVer);
                const stage2_semver = target.os.version_range.semver.min;
                stage1_semver.* = .{
                    .major = stage2_semver.major,
                    .minor = stage2_semver.minor,
                    .patch = stage2_semver.patch,
                };
                break :blk stage1_semver;
            } else {
                break :blk null;
            }
        };

        const std_dl = target.standardDynamicLinkerPath();
        const std_dl_z = if (std_dl.get()) |dl|
            (try mem.dupeZ(std.heap.c_allocator, u8, dl)).ptr
        else
            null;

        const asm_features = asm_features_list.toOwnedSlice();
        self.* = .{
            .arch = @enumToInt(target.cpu.arch) + 1, // skip over ZigLLVM_UnknownArch
            .vendor = 0,
            .os = @enumToInt(target.os.tag),
            .abi = @enumToInt(target.abi),
            .llvm_cpu_name = if (target.cpu.model.llvm_name) |s| s.ptr else null,
            .llvm_cpu_features = llvm_features_buffer.toOwnedSlice().ptr,
            .llvm_cpu_features_asm_ptr = asm_features.ptr,
            .llvm_cpu_features_asm_len = asm_features.len,
            .cpu_builtin_str = cpu_builtin_str_buffer.toOwnedSlice().ptr,
            .os_builtin_str = os_builtin_str_buffer.toOwnedSlice().ptr,
            .is_native_os = cross_target.isNativeOs(),
            .is_native_cpu = cross_target.isNativeCpu(),
            .glibc_or_darwin_version = glibc_or_darwin_version,
            .dynamic_linker = dynamic_linker,
            .standard_dynamic_linker_path = std_dl_z,
        };
    }
};

fn crossTargetToTarget(cross_target: CrossTarget, dynamic_linker_ptr: *?[*:0]u8) !Target {
    var info = try std.zig.system.NativeTargetInfo.detect(std.heap.c_allocator, cross_target);
    if (info.cpu_detection_unimplemented) {
        // TODO We want to just use detected_info.target but implementing
        // CPU model & feature detection is todo so here we rely on LLVM.
        const llvm = @import("llvm.zig");
        const llvm_cpu_name = llvm.GetHostCPUName();
        const llvm_cpu_features = llvm.GetNativeFeatures();
        const arch = Target.current.cpu.arch;
        info.target.cpu = try detectNativeCpuWithLLVM(arch, llvm_cpu_name, llvm_cpu_features);
        cross_target.updateCpuFeatures(&info.target.cpu.features);
        info.target.cpu.arch = cross_target.getCpuArch();
    }
    if (info.dynamic_linker.get()) |dl| {
        dynamic_linker_ptr.* = try mem.dupeZ(std.heap.c_allocator, u8, dl);
    } else {
        dynamic_linker_ptr.* = null;
    }
    return info.target;
}

// ABI warning
const Stage2SemVer = extern struct {
    major: u32,
    minor: u32,
    patch: u32,
};
