const Compilation = @This();

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.compilation);
const Target = std.Target;
const ThreadPool = std.Thread.Pool;
const WaitGroup = std.Thread.WaitGroup;
const ErrorBundle = std.zig.ErrorBundle;
const Path = Cache.Path;

const Value = @import("Value.zig");
const Type = @import("Type.zig");
const target_util = @import("target.zig");
const Package = @import("Package.zig");
const link = @import("link.zig");
const tracy = @import("tracy.zig");
const trace = tracy.trace;
const build_options = @import("build_options");
const LibCInstallation = std.zig.LibCInstallation;
const glibc = @import("glibc.zig");
const musl = @import("musl.zig");
const mingw = @import("mingw.zig");
const libunwind = @import("libunwind.zig");
const libcxx = @import("libcxx.zig");
const wasi_libc = @import("wasi_libc.zig");
const fatal = @import("main.zig").fatal;
const clangMain = @import("main.zig").clangMain;
const Zcu = @import("Zcu.zig");
const Sema = @import("Sema.zig");
const InternPool = @import("InternPool.zig");
const Cache = std.Build.Cache;
const c_codegen = @import("codegen/c.zig");
const libtsan = @import("libtsan.zig");
const Zir = std.zig.Zir;
const Air = @import("Air.zig");
const Builtin = @import("Builtin.zig");
const LlvmObject = @import("codegen/llvm.zig").Object;
const dev = @import("dev.zig");
const ThreadSafeQueue = @import("ThreadSafeQueue.zig").ThreadSafeQueue;

pub const Directory = Cache.Directory;
pub const Config = @import("Compilation/Config.zig");

/// General-purpose allocator. Used for both temporary and long-term storage.
gpa: Allocator,
/// Arena-allocated memory, mostly used during initialization. However, it can
/// be used for other things requiring the same lifetime as the `Compilation`.
/// Not thread-safe - lock `mutex` if potentially accessing from multiple
/// threads at once.
arena: Allocator,
/// Not every Compilation compiles .zig code! For example you could do `zig build-exe foo.o`.
zcu: ?*Zcu,
/// Contains different state depending on whether the Compilation uses
/// incremental or whole cache mode.
cache_use: CacheUse,
/// All compilations have a root module because this is where some important
/// settings are stored, such as target and optimization mode. This module
/// might not have any .zig code associated with it, however.
root_mod: *Package.Module,

/// User-specified settings that have all the defaults resolved into concrete values.
config: Config,

/// The main output file.
/// In whole cache mode, this is null except for during the body of the update
/// function. In incremental cache mode, this is a long-lived object.
/// In both cases, this is `null` when `-fno-emit-bin` is used.
bin_file: ?*link.File,

/// The root path for the dynamic linker and system libraries (as well as frameworks on Darwin)
sysroot: ?[]const u8,
/// This is `null` when not building a Windows DLL, or when `-fno-emit-implib` is used.
implib_emit: ?Path,
/// This is non-null when `-femit-docs` is provided.
docs_emit: ?Path,
root_name: [:0]const u8,
include_compiler_rt: bool,
/// Resolved into known paths, any GNU ld scripts already resolved.
link_inputs: []const link.Input,
/// Needed only for passing -F args to clang.
framework_dirs: []const []const u8,
/// These are only for DLLs dependencies fulfilled by the `.def` files shipped
/// with Zig. Static libraries are provided as `link.Input` values.
windows_libs: std.StringArrayHashMapUnmanaged(void),
version: ?std.SemanticVersion,
libc_installation: ?*const LibCInstallation,
skip_linker_dependencies: bool,
function_sections: bool,
data_sections: bool,
link_eh_frame_hdr: bool,
native_system_include_paths: []const []const u8,
/// List of symbols forced as undefined in the symbol table
/// thus forcing their resolution by the linker.
/// Corresponds to `-u <symbol>` for ELF/MachO and `/include:<symbol>` for COFF/PE.
force_undefined_symbols: std.StringArrayHashMapUnmanaged(void),

c_object_table: std.AutoArrayHashMapUnmanaged(*CObject, void) = .empty,
win32_resource_table: if (dev.env.supports(.win32_resource)) std.AutoArrayHashMapUnmanaged(*Win32Resource, void) else struct {
    pub fn keys(_: @This()) [0]void {
        return .{};
    }
    pub fn count(_: @This()) u0 {
        return 0;
    }
    pub fn deinit(_: @This(), _: Allocator) void {}
} = .{},

link_diags: link.Diags,
link_task_queue: ThreadSafeQueue(link.Task) = .empty,
/// Ensure only 1 simultaneous call to `flushTaskQueue`.
link_task_queue_safety: std.debug.SafetyLock = .{},
/// If any tasks are queued up that depend on prelink being finished, they are moved
/// here until prelink finishes.
link_task_queue_postponed: std.ArrayListUnmanaged(link.Task) = .empty,
/// Initialized with how many link input tasks are expected. After this reaches zero
/// the linker will begin the prelink phase.
/// Initialized in the Compilation main thread before the pipeline; modified only in
/// the linker task thread.
remaining_prelink_tasks: u32,

/// Set of work that can be represented by only flags to determine whether the
/// work is queued or not.
queued_jobs: QueuedJobs,

work_queues: [
    len: {
        var len: usize = 0;
        for (std.enums.values(Job.Tag)) |tag| {
            len = @max(Job.stage(tag) + 1, len);
        }
        break :len len;
    }
]std.fifo.LinearFifo(Job, .Dynamic),

/// These jobs are to invoke the Clang compiler to create an object file, which
/// gets linked with the Compilation.
c_object_work_queue: std.fifo.LinearFifo(*CObject, .Dynamic),

/// These jobs are to invoke the RC compiler to create a compiled resource file (.res), which
/// gets linked with the Compilation.
win32_resource_work_queue: if (dev.env.supports(.win32_resource)) std.fifo.LinearFifo(*Win32Resource, .Dynamic) else struct {
    pub fn ensureUnusedCapacity(_: @This(), _: u0) error{}!void {}
    pub fn readItem(_: @This()) ?noreturn {
        return null;
    }
    pub fn deinit(_: @This()) void {}
},

/// These jobs are to tokenize, parse, and astgen files, which may be outdated
/// since the last compilation, as well as scan for `@import` and queue up
/// additional jobs corresponding to those new files.
astgen_work_queue: std.fifo.LinearFifo(Zcu.File.Index, .Dynamic),

/// The ErrorMsg memory is owned by the `CObject`, using Compilation's general purpose allocator.
/// This data is accessed by multiple threads and is protected by `mutex`.
failed_c_objects: std.AutoArrayHashMapUnmanaged(*CObject, *CObject.Diag.Bundle) = .empty,

/// The ErrorBundle memory is owned by the `Win32Resource`, using Compilation's general purpose allocator.
/// This data is accessed by multiple threads and is protected by `mutex`.
failed_win32_resources: if (dev.env.supports(.win32_resource)) std.AutoArrayHashMapUnmanaged(*Win32Resource, ErrorBundle) else struct {
    pub fn values(_: @This()) [0]void {
        return .{};
    }
    pub fn deinit(_: @This(), _: Allocator) void {}
} = .{},

/// Miscellaneous things that can fail.
misc_failures: std.AutoArrayHashMapUnmanaged(MiscTask, MiscError) = .empty,

/// When this is `true` it means invoking clang as a sub-process is expected to inherit
/// stdin, stdout, stderr, and if it returns non success, to forward the exit code.
/// Otherwise we attempt to parse the error messages and expose them via the Compilation API.
/// This is `true` for `zig cc`, `zig c++`, and `zig translate-c`.
clang_passthrough_mode: bool,
clang_preprocessor_mode: ClangPreprocessorMode,
/// Whether to print clang argvs to stdout.
verbose_cc: bool,
verbose_air: bool,
verbose_intern_pool: bool,
verbose_generic_instances: bool,
verbose_llvm_ir: ?[]const u8,
verbose_llvm_bc: ?[]const u8,
verbose_cimport: bool,
verbose_llvm_cpu_features: bool,
verbose_link: bool,
disable_c_depfile: bool,
time_report: bool,
stack_report: bool,
debug_compiler_runtime_libs: bool,
debug_compile_errors: bool,
incremental: bool,
alloc_failure_occurred: bool = false,
last_update_was_cache_hit: bool = false,

c_source_files: []const CSourceFile,
rc_source_files: []const RcSourceFile,
global_cc_argv: []const []const u8,
cache_parent: *Cache,
/// Populated when a sub-Compilation is created during the `update` of its parent.
/// In this case the child must additionally add file system inputs to this object.
parent_whole_cache: ?ParentWholeCache,
/// Path to own executable for invoking `zig clang`.
self_exe_path: ?[]const u8,
zig_lib_directory: Directory,
local_cache_directory: Directory,
global_cache_directory: Directory,
libc_include_dir_list: []const []const u8,
libc_framework_dir_list: []const []const u8,
rc_includes: RcIncludes,
mingw_unicode_entry_point: bool,
thread_pool: *ThreadPool,

/// Populated when we build the libc++ static library. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
libcxx_static_lib: ?CrtFile = null,
/// Populated when we build the libc++abi static library. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
libcxxabi_static_lib: ?CrtFile = null,
/// Populated when we build the libunwind static library. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
libunwind_static_lib: ?CrtFile = null,
/// Populated when we build the TSAN library. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
tsan_lib: ?CrtFile = null,
/// Populated when we build the libc static library. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
libc_static_lib: ?CrtFile = null,
/// Populated when we build the libcompiler_rt static library. A Job to build this is indicated
/// by setting `queued_jobs.compiler_rt_lib` and resolved before calling linker.flush().
compiler_rt_lib: ?CrtFile = null,
/// Populated when we build the compiler_rt_obj object. A Job to build this is indicated
/// by setting `queued_jobs.compiler_rt_obj` and resolved before calling linker.flush().
compiler_rt_obj: ?CrtFile = null,
/// Populated when we build the libfuzzer static library. A Job to build this
/// is indicated by setting `queued_jobs.fuzzer_lib` and resolved before
/// calling linker.flush().
fuzzer_lib: ?CrtFile = null,

glibc_so_files: ?glibc.BuiltSharedObjects = null,
wasi_emulated_libs: []const wasi_libc.CrtFile,

/// For example `Scrt1.o` and `libc_nonshared.a`. These are populated after building libc from source,
/// The set of needed CRT (C runtime) files differs depending on the target and compilation settings.
/// The key is the basename, and the value is the absolute path to the completed build artifact.
crt_files: std.StringHashMapUnmanaged(CrtFile) = .empty,

/// How many lines of reference trace should be included per compile error.
/// Null means only show snippet on first error.
reference_trace: ?u32 = null,

libcxx_abi_version: libcxx.AbiVersion = libcxx.AbiVersion.default,

/// This mutex guards all `Compilation` mutable state.
/// Disabled in single-threaded mode because the thread pool spawns in the same thread.
mutex: if (builtin.single_threaded) struct {
    pub inline fn tryLock(_: @This()) void {}
    pub inline fn lock(_: @This()) void {}
    pub inline fn unlock(_: @This()) void {}
} else std.Thread.Mutex = .{},

test_filters: []const []const u8,
test_name_prefix: ?[]const u8,

emit_asm: ?EmitLoc,
emit_llvm_ir: ?EmitLoc,
emit_llvm_bc: ?EmitLoc,

link_task_wait_group: WaitGroup = .{},
work_queue_progress_node: std.Progress.Node = .none,

llvm_opt_bisect_limit: c_int,

file_system_inputs: ?*std.ArrayListUnmanaged(u8),

/// This is the digest of the cache for the current compilation.
/// This digest will be known after update() is called.
digest: ?[Cache.bin_digest_len]u8 = null,

const QueuedJobs = struct {
    compiler_rt_lib: bool = false,
    compiler_rt_obj: bool = false,
    fuzzer_lib: bool = false,
    update_builtin_zig: bool,
    musl_crt_file: [@typeInfo(musl.CrtFile).@"enum".fields.len]bool = @splat(false),
    glibc_crt_file: [@typeInfo(glibc.CrtFile).@"enum".fields.len]bool = @splat(false),
    /// one of WASI libc static objects
    wasi_libc_crt_file: [@typeInfo(wasi_libc.CrtFile).@"enum".fields.len]bool = @splat(false),
    /// one of the mingw-w64 static objects
    mingw_crt_file: [@typeInfo(mingw.CrtFile).@"enum".fields.len]bool = @splat(false),
    /// all of the glibc shared objects
    glibc_shared_objects: bool = false,
    /// libunwind.a, usually needed when linking libc
    libunwind: bool = false,
    libcxx: bool = false,
    libcxxabi: bool = false,
    libtsan: bool = false,
    zig_libc: bool = false,
};

pub const default_stack_protector_buffer_size = target_util.default_stack_protector_buffer_size;
pub const SemaError = Zcu.SemaError;

pub const CrtFile = struct {
    lock: Cache.Lock,
    full_object_path: Path,

    pub fn isObject(cf: CrtFile) bool {
        return switch (classifyFileExt(cf.full_object_path.sub_path)) {
            .object => true,
            else => false,
        };
    }

    pub fn deinit(self: *CrtFile, gpa: Allocator) void {
        self.lock.release();
        gpa.free(self.full_object_path.sub_path);
        self.* = undefined;
    }
};

/// Supported languages for "zig clang -x <lang>".
/// Loosely based on llvm-project/clang/include/clang/Driver/Types.def
pub const LangToExt = std.StaticStringMap(FileExt).initComptime(.{
    .{ "c", .c },
    .{ "c-header", .h },
    .{ "c++", .cpp },
    .{ "c++-header", .hpp },
    .{ "objective-c", .m },
    .{ "objective-c-header", .hm },
    .{ "objective-c++", .mm },
    .{ "objective-c++-header", .hmm },
    .{ "assembler", .assembly },
    .{ "assembler-with-cpp", .assembly_with_cpp },
});

/// For passing to a C compiler.
pub const CSourceFile = struct {
    /// Many C compiler flags are determined by settings contained in the owning Module.
    owner: *Package.Module,
    src_path: []const u8,
    extra_flags: []const []const u8 = &.{},
    /// Same as extra_flags except they are not added to the Cache hash.
    cache_exempt_flags: []const []const u8 = &.{},
    /// This field is non-null if and only if the language was explicitly set
    /// with "-x lang".
    ext: ?FileExt = null,
};

/// For passing to resinator.
pub const RcSourceFile = struct {
    owner: *Package.Module,
    src_path: []const u8,
    extra_flags: []const []const u8 = &.{},
};

pub const RcIncludes = enum {
    /// Use MSVC if available, fall back to MinGW.
    any,
    /// Use MSVC include paths (MSVC install + Windows SDK, must be present on the system).
    msvc,
    /// Use MinGW include paths (distributed with Zig).
    gnu,
    /// Do not use any autodetected include paths.
    none,
};

const Job = union(enum) {
    /// Corresponds to the task in `link.Task`.
    /// Only needed for backends that haven't yet been updated to not race against Sema.
    codegen_nav: InternPool.Nav.Index,
    /// Corresponds to the task in `link.Task`.
    /// Only needed for backends that haven't yet been updated to not race against Sema.
    codegen_func: link.Task.CodegenFunc,
    /// Corresponds to the task in `link.Task`.
    /// Only needed for backends that haven't yet been updated to not race against Sema.
    codegen_type: InternPool.Index,
    update_line_number: InternPool.TrackedInst.Index,
    /// The `AnalUnit`, which is *not* a `func`, must be semantically analyzed.
    /// This may be its first time being analyzed, or it may be outdated.
    /// If the unit is a function, a `codegen_func` job will then be queued.
    analyze_comptime_unit: InternPool.AnalUnit,
    /// This function must be semantically analyzed.
    /// This may be its first time being analyzed, or it may be outdated.
    /// After analysis, a `codegen_func` job will be queued.
    /// These must be separate jobs to ensure any needed type resolution occurs *before* codegen.
    /// This job is separate from `analyze_comptime_unit` because it has a different priority.
    analyze_func: InternPool.Index,
    /// The main source file for the module needs to be analyzed.
    analyze_mod: *Package.Module,
    /// Fully resolve the given `struct` or `union` type.
    resolve_type_fully: InternPool.Index,

    /// The value is the index into `windows_libs`.
    windows_import_lib: usize,

    const Tag = @typeInfo(Job).@"union".tag_type.?;
    fn stage(tag: Tag) usize {
        return switch (tag) {
            // Prioritize functions so that codegen can get to work on them on a
            // separate thread, while Sema goes back to its own work.
            .resolve_type_fully, .analyze_func, .codegen_func => 0,
            else => 1,
        };
    }
    comptime {
        // Job dependencies
        assert(stage(.resolve_type_fully) <= stage(.codegen_func));
    }
};

pub const CObject = struct {
    /// Relative to cwd. Owned by arena.
    src: CSourceFile,
    status: union(enum) {
        new,
        success: struct {
            /// The outputted result. `sub_path` owned by gpa.
            object_path: Path,
            /// This is a file system lock on the cache hash manifest representing this
            /// object. It prevents other invocations of the Zig compiler from interfering
            /// with this object until released.
            lock: Cache.Lock,
        },
        /// There will be a corresponding ErrorMsg in Compilation.failed_c_objects.
        failure,
        /// A transient failure happened when trying to compile the C Object; it may
        /// succeed if we try again. There may be a corresponding ErrorMsg in
        /// Compilation.failed_c_objects. If there is not, the failure is out of memory.
        failure_retryable,
    },

    pub const Diag = struct {
        level: u32 = 0,
        category: u32 = 0,
        msg: []const u8 = &.{},
        src_loc: SrcLoc = .{},
        src_ranges: []const SrcRange = &.{},
        sub_diags: []const Diag = &.{},

        pub const SrcLoc = struct {
            file: u32 = 0,
            line: u32 = 0,
            column: u32 = 0,
            offset: u32 = 0,
        };

        pub const SrcRange = struct {
            start: SrcLoc = .{},
            end: SrcLoc = .{},
        };

        pub fn deinit(diag: *Diag, gpa: Allocator) void {
            gpa.free(diag.msg);
            gpa.free(diag.src_ranges);
            for (diag.sub_diags) |sub_diag| {
                var sub_diag_mut = sub_diag;
                sub_diag_mut.deinit(gpa);
            }
            gpa.free(diag.sub_diags);
            diag.* = undefined;
        }

        pub fn count(diag: Diag) u32 {
            var total: u32 = 1;
            for (diag.sub_diags) |sub_diag| total += sub_diag.count();
            return total;
        }

        pub fn addToErrorBundle(diag: Diag, eb: *ErrorBundle.Wip, bundle: Bundle, note: *u32) !void {
            const err_msg = try eb.addErrorMessage(try diag.toErrorMessage(eb, bundle, 0));
            eb.extra.items[note.*] = @intFromEnum(err_msg);
            note.* += 1;
            for (diag.sub_diags) |sub_diag| try sub_diag.addToErrorBundle(eb, bundle, note);
        }

        pub fn toErrorMessage(
            diag: Diag,
            eb: *ErrorBundle.Wip,
            bundle: Bundle,
            notes_len: u32,
        ) !ErrorBundle.ErrorMessage {
            var start = diag.src_loc.offset;
            var end = diag.src_loc.offset;
            for (diag.src_ranges) |src_range| {
                if (src_range.start.file == diag.src_loc.file and
                    src_range.start.line == diag.src_loc.line)
                {
                    start = @min(src_range.start.offset, start);
                }
                if (src_range.end.file == diag.src_loc.file and
                    src_range.end.line == diag.src_loc.line)
                {
                    end = @max(src_range.end.offset, end);
                }
            }

            const file_name = bundle.file_names.get(diag.src_loc.file) orelse "";
            const source_line = source_line: {
                if (diag.src_loc.offset == 0 or diag.src_loc.column == 0) break :source_line 0;

                const file = std.fs.cwd().openFile(file_name, .{}) catch break :source_line 0;
                defer file.close();
                file.seekTo(diag.src_loc.offset + 1 - diag.src_loc.column) catch break :source_line 0;

                var line = std.ArrayList(u8).init(eb.gpa);
                defer line.deinit();
                file.reader().readUntilDelimiterArrayList(&line, '\n', 1 << 10) catch break :source_line 0;

                break :source_line try eb.addString(line.items);
            };

            return .{
                .msg = try eb.addString(diag.msg),
                .src_loc = try eb.addSourceLocation(.{
                    .src_path = try eb.addString(file_name),
                    .line = diag.src_loc.line -| 1,
                    .column = diag.src_loc.column -| 1,
                    .span_start = start,
                    .span_main = diag.src_loc.offset,
                    .span_end = end + 1,
                    .source_line = source_line,
                }),
                .notes_len = notes_len,
            };
        }

        pub const Bundle = struct {
            file_names: std.AutoArrayHashMapUnmanaged(u32, []const u8) = .empty,
            category_names: std.AutoArrayHashMapUnmanaged(u32, []const u8) = .empty,
            diags: []Diag = &.{},

            pub fn destroy(bundle: *Bundle, gpa: Allocator) void {
                for (bundle.file_names.values()) |file_name| gpa.free(file_name);
                for (bundle.category_names.values()) |category_name| gpa.free(category_name);
                for (bundle.diags) |*diag| diag.deinit(gpa);
                gpa.free(bundle.diags);
                gpa.destroy(bundle);
            }

            pub fn parse(gpa: Allocator, path: []const u8) !*Bundle {
                const BitcodeReader = @import("codegen/llvm/BitcodeReader.zig");
                const BlockId = enum(u32) {
                    Meta = 8,
                    Diag,
                    _,
                };
                const RecordId = enum(u32) {
                    Version = 1,
                    DiagInfo,
                    SrcRange,
                    DiagFlag,
                    CatName,
                    FileName,
                    FixIt,
                    _,
                };
                const WipDiag = struct {
                    level: u32 = 0,
                    category: u32 = 0,
                    msg: []const u8 = &.{},
                    src_loc: SrcLoc = .{},
                    src_ranges: std.ArrayListUnmanaged(SrcRange) = .empty,
                    sub_diags: std.ArrayListUnmanaged(Diag) = .empty,

                    fn deinit(wip_diag: *@This(), allocator: Allocator) void {
                        allocator.free(wip_diag.msg);
                        wip_diag.src_ranges.deinit(allocator);
                        for (wip_diag.sub_diags.items) |*sub_diag| sub_diag.deinit(allocator);
                        wip_diag.sub_diags.deinit(allocator);
                        wip_diag.* = undefined;
                    }
                };

                const file = try std.fs.cwd().openFile(path, .{});
                defer file.close();
                var br = std.io.bufferedReader(file.reader());
                const reader = br.reader();
                var bc = BitcodeReader.init(gpa, .{ .reader = reader.any() });
                defer bc.deinit();

                var file_names: std.AutoArrayHashMapUnmanaged(u32, []const u8) = .empty;
                errdefer {
                    for (file_names.values()) |file_name| gpa.free(file_name);
                    file_names.deinit(gpa);
                }

                var category_names: std.AutoArrayHashMapUnmanaged(u32, []const u8) = .empty;
                errdefer {
                    for (category_names.values()) |category_name| gpa.free(category_name);
                    category_names.deinit(gpa);
                }

                var stack: std.ArrayListUnmanaged(WipDiag) = .empty;
                defer {
                    for (stack.items) |*wip_diag| wip_diag.deinit(gpa);
                    stack.deinit(gpa);
                }
                try stack.append(gpa, .{});

                try bc.checkMagic("DIAG");
                while (try bc.next()) |item| switch (item) {
                    .start_block => |block| switch (@as(BlockId, @enumFromInt(block.id))) {
                        .Meta => if (stack.items.len > 0) try bc.skipBlock(block),
                        .Diag => try stack.append(gpa, .{}),
                        _ => try bc.skipBlock(block),
                    },
                    .record => |record| switch (@as(RecordId, @enumFromInt(record.id))) {
                        .Version => if (record.operands[0] != 2) return error.InvalidVersion,
                        .DiagInfo => {
                            const top = &stack.items[stack.items.len - 1];
                            top.level = @intCast(record.operands[0]);
                            top.src_loc = .{
                                .file = @intCast(record.operands[1]),
                                .line = @intCast(record.operands[2]),
                                .column = @intCast(record.operands[3]),
                                .offset = @intCast(record.operands[4]),
                            };
                            top.category = @intCast(record.operands[5]);
                            top.msg = try gpa.dupe(u8, record.blob);
                        },
                        .SrcRange => try stack.items[stack.items.len - 1].src_ranges.append(gpa, .{
                            .start = .{
                                .file = @intCast(record.operands[0]),
                                .line = @intCast(record.operands[1]),
                                .column = @intCast(record.operands[2]),
                                .offset = @intCast(record.operands[3]),
                            },
                            .end = .{
                                .file = @intCast(record.operands[4]),
                                .line = @intCast(record.operands[5]),
                                .column = @intCast(record.operands[6]),
                                .offset = @intCast(record.operands[7]),
                            },
                        }),
                        .DiagFlag => {},
                        .CatName => {
                            try category_names.ensureUnusedCapacity(gpa, 1);
                            category_names.putAssumeCapacity(
                                @intCast(record.operands[0]),
                                try gpa.dupe(u8, record.blob),
                            );
                        },
                        .FileName => {
                            try file_names.ensureUnusedCapacity(gpa, 1);
                            file_names.putAssumeCapacity(
                                @intCast(record.operands[0]),
                                try gpa.dupe(u8, record.blob),
                            );
                        },
                        .FixIt => {},
                        _ => {},
                    },
                    .end_block => |block| switch (@as(BlockId, @enumFromInt(block.id))) {
                        .Meta => {},
                        .Diag => {
                            var wip_diag = stack.pop().?;
                            errdefer wip_diag.deinit(gpa);

                            const src_ranges = try wip_diag.src_ranges.toOwnedSlice(gpa);
                            errdefer gpa.free(src_ranges);

                            const sub_diags = try wip_diag.sub_diags.toOwnedSlice(gpa);
                            errdefer {
                                for (sub_diags) |*sub_diag| sub_diag.deinit(gpa);
                                gpa.free(sub_diags);
                            }

                            try stack.items[stack.items.len - 1].sub_diags.append(gpa, .{
                                .level = wip_diag.level,
                                .category = wip_diag.category,
                                .msg = wip_diag.msg,
                                .src_loc = wip_diag.src_loc,
                                .src_ranges = src_ranges,
                                .sub_diags = sub_diags,
                            });
                        },
                        _ => {},
                    },
                };

                const bundle = try gpa.create(Bundle);
                assert(stack.items.len == 1);
                bundle.* = .{
                    .file_names = file_names,
                    .category_names = category_names,
                    .diags = try stack.items[0].sub_diags.toOwnedSlice(gpa),
                };
                return bundle;
            }

            pub fn addToErrorBundle(bundle: Bundle, eb: *ErrorBundle.Wip) !void {
                for (bundle.diags) |diag| {
                    const notes_len = diag.count() - 1;
                    try eb.addRootErrorMessage(try diag.toErrorMessage(eb, bundle, notes_len));
                    if (notes_len > 0) {
                        var note = try eb.reserveNotes(notes_len);
                        for (diag.sub_diags) |sub_diag|
                            try sub_diag.addToErrorBundle(eb, bundle, &note);
                    }
                }
            }
        };
    };

    /// Returns if there was failure.
    pub fn clearStatus(self: *CObject, gpa: Allocator) bool {
        switch (self.status) {
            .new => return false,
            .failure, .failure_retryable => {
                self.status = .new;
                return true;
            },
            .success => |*success| {
                gpa.free(success.object_path.sub_path);
                success.lock.release();
                self.status = .new;
                return false;
            },
        }
    }

    pub fn destroy(self: *CObject, gpa: Allocator) void {
        _ = self.clearStatus(gpa);
        gpa.destroy(self);
    }
};

pub const Win32Resource = struct {
    /// Relative to cwd. Owned by arena.
    src: union(enum) {
        rc: RcSourceFile,
        manifest: []const u8,
    },
    status: union(enum) {
        new,
        success: struct {
            /// The outputted result. Owned by gpa.
            res_path: []u8,
            /// This is a file system lock on the cache hash manifest representing this
            /// object. It prevents other invocations of the Zig compiler from interfering
            /// with this object until released.
            lock: Cache.Lock,
        },
        /// There will be a corresponding ErrorMsg in Compilation.failed_win32_resources.
        failure,
        /// A transient failure happened when trying to compile the resource file; it may
        /// succeed if we try again. There may be a corresponding ErrorMsg in
        /// Compilation.failed_win32_resources. If there is not, the failure is out of memory.
        failure_retryable,
    },

    /// Returns true if there was failure.
    pub fn clearStatus(self: *Win32Resource, gpa: Allocator) bool {
        switch (self.status) {
            .new => return false,
            .failure, .failure_retryable => {
                self.status = .new;
                return true;
            },
            .success => |*success| {
                gpa.free(success.res_path);
                success.lock.release();
                self.status = .new;
                return false;
            },
        }
    }

    pub fn destroy(self: *Win32Resource, gpa: Allocator) void {
        _ = self.clearStatus(gpa);
        gpa.destroy(self);
    }
};

pub const MiscTask = enum {
    write_builtin_zig,
    rename_results,
    check_whole_cache,
    glibc_crt_file,
    glibc_shared_objects,
    musl_crt_file,
    mingw_crt_file,
    windows_import_lib,
    libunwind,
    libcxx,
    libcxxabi,
    libtsan,
    libfuzzer,
    wasi_libc_crt_file,
    compiler_rt,
    zig_libc,
    analyze_mod,
    docs_copy,
    docs_wasm,

    @"musl crt1.o",
    @"musl rcrt1.o",
    @"musl Scrt1.o",
    @"musl libc.a",
    @"musl libc.so",

    @"wasi crt1-reactor.o",
    @"wasi crt1-command.o",
    @"wasi libc.a",
    @"wasi libdl.a",
    @"libwasi-emulated-process-clocks.a",
    @"libwasi-emulated-getpid.a",
    @"libwasi-emulated-mman.a",
    @"libwasi-emulated-signal.a",

    @"glibc Scrt1.o",
    @"glibc libc_nonshared.a",
    @"glibc shared object",

    @"mingw-w64 crt2.o",
    @"mingw-w64 dllcrt2.o",
    @"mingw-w64 mingw32.lib",
};

pub const MiscError = struct {
    /// Allocated with gpa.
    msg: []u8,
    children: ?ErrorBundle = null,

    pub fn deinit(misc_err: *MiscError, gpa: Allocator) void {
        gpa.free(misc_err.msg);
        if (misc_err.children) |*children| {
            children.deinit(gpa);
        }
        misc_err.* = undefined;
    }
};

pub const EmitLoc = struct {
    /// If this is `null` it means the file will be output to the cache directory.
    /// When provided, both the open file handle and the path name must outlive the `Compilation`.
    directory: ?Compilation.Directory,
    /// This may not have sub-directories in it.
    basename: []const u8,
};

pub const cache_helpers = struct {
    pub fn addModule(hh: *Cache.HashHelper, mod: *const Package.Module) void {
        addResolvedTarget(hh, mod.resolved_target);
        hh.add(mod.optimize_mode);
        hh.add(mod.code_model);
        hh.add(mod.single_threaded);
        hh.add(mod.error_tracing);
        hh.add(mod.valgrind);
        hh.add(mod.pic);
        hh.add(mod.strip);
        hh.add(mod.omit_frame_pointer);
        hh.add(mod.stack_check);
        hh.add(mod.red_zone);
        hh.add(mod.sanitize_c);
        hh.add(mod.sanitize_thread);
        hh.add(mod.fuzz);
        hh.add(mod.unwind_tables);
        hh.add(mod.structured_cfg);
        hh.add(mod.no_builtin);
        hh.addListOfBytes(mod.cc_argv);
    }

    pub fn addResolvedTarget(
        hh: *Cache.HashHelper,
        resolved_target: Package.Module.ResolvedTarget,
    ) void {
        const target = resolved_target.result;
        hh.add(target.cpu.arch);
        hh.addBytes(target.cpu.model.name);
        hh.add(target.cpu.features.ints);
        hh.add(target.os.tag);
        hh.add(target.os.versionRange());
        hh.add(target.abi);
        hh.add(target.ofmt);
        hh.add(resolved_target.is_native_os);
        hh.add(resolved_target.is_native_abi);
    }

    pub fn addEmitLoc(hh: *Cache.HashHelper, emit_loc: EmitLoc) void {
        hh.addBytes(emit_loc.basename);
    }

    pub fn addOptionalEmitLoc(hh: *Cache.HashHelper, optional_emit_loc: ?EmitLoc) void {
        hh.add(optional_emit_loc != null);
        addEmitLoc(hh, optional_emit_loc orelse return);
    }

    pub fn addOptionalDebugFormat(hh: *Cache.HashHelper, x: ?Config.DebugFormat) void {
        hh.add(x != null);
        addDebugFormat(hh, x orelse return);
    }

    pub fn addDebugFormat(hh: *Cache.HashHelper, x: Config.DebugFormat) void {
        const tag: @typeInfo(Config.DebugFormat).@"union".tag_type.? = x;
        hh.add(tag);
        switch (x) {
            .strip, .code_view => {},
            .dwarf => |f| hh.add(f),
        }
    }

    pub fn hashCSource(self: *Cache.Manifest, c_source: CSourceFile) !void {
        _ = try self.addFile(c_source.src_path, null);
        // Hash the extra flags, with special care to call addFile for file parameters.
        // TODO this logic can likely be improved by utilizing clang_options_data.zig.
        const file_args = [_][]const u8{"-include"};
        var arg_i: usize = 0;
        while (arg_i < c_source.extra_flags.len) : (arg_i += 1) {
            const arg = c_source.extra_flags[arg_i];
            self.hash.addBytes(arg);
            for (file_args) |file_arg| {
                if (mem.eql(u8, file_arg, arg) and arg_i + 1 < c_source.extra_flags.len) {
                    arg_i += 1;
                    _ = try self.addFile(c_source.extra_flags[arg_i], null);
                }
            }
        }
    }
};

pub const ClangPreprocessorMode = enum {
    no,
    /// This means we are doing `zig cc -E -o <path>`.
    yes,
    /// This means we are doing `zig cc -E`.
    stdout,
    /// precompiled C header
    pch,
};

pub const Framework = link.File.MachO.Framework;
pub const SystemLib = link.SystemLib;

pub const CacheMode = enum { incremental, whole };

pub const ParentWholeCache = struct {
    manifest: *Cache.Manifest,
    mutex: *std.Thread.Mutex,
    prefix_map: [4]u8,
};

const CacheUse = union(CacheMode) {
    incremental: *Incremental,
    whole: *Whole,

    const Whole = struct {
        /// This is a pointer to a local variable inside `update()`.
        cache_manifest: ?*Cache.Manifest = null,
        cache_manifest_mutex: std.Thread.Mutex = .{},
        /// null means -fno-emit-bin.
        /// This is mutable memory allocated into the Compilation-lifetime arena (`arena`)
        /// of exactly the correct size for "o/[digest]/[basename]".
        /// The basename is of the outputted binary file in case we don't know the directory yet.
        bin_sub_path: ?[]u8,
        /// Same as `bin_sub_path` but for implibs.
        implib_sub_path: ?[]u8,
        docs_sub_path: ?[]u8,
        lf_open_opts: link.File.OpenOptions,
        tmp_artifact_directory: ?Directory,
        /// Prevents other processes from clobbering files in the output directory.
        lock: ?Cache.Lock,

        fn releaseLock(whole: *Whole) void {
            if (whole.lock) |*lock| {
                lock.release();
                whole.lock = null;
            }
        }

        fn moveLock(whole: *Whole) Cache.Lock {
            const result = whole.lock.?;
            whole.lock = null;
            return result;
        }
    };

    const Incremental = struct {
        /// Where build artifacts and incremental compilation metadata serialization go.
        artifact_directory: Compilation.Directory,
    };

    fn deinit(cu: CacheUse) void {
        switch (cu) {
            .incremental => |incremental| {
                incremental.artifact_directory.handle.close();
            },
            .whole => |whole| {
                whole.releaseLock();
            },
        }
    }
};

pub const CreateOptions = struct {
    zig_lib_directory: Directory,
    local_cache_directory: Directory,
    global_cache_directory: Directory,
    thread_pool: *ThreadPool,
    self_exe_path: ?[]const u8 = null,

    /// Options that have been resolved by calling `resolveDefaults`.
    config: Compilation.Config,

    root_mod: *Package.Module,
    /// Normally, `main_mod` and `root_mod` are the same. The exception is `zig
    /// test`, in which `root_mod` is the test runner, and `main_mod` is the
    /// user's source file which has the tests.
    main_mod: ?*Package.Module = null,
    /// This is provided so that the API user has a chance to tweak the
    /// per-module settings of the standard library.
    /// When this is null, a default configuration of the std lib is created
    /// based on the settings of root_mod.
    std_mod: ?*Package.Module = null,
    root_name: []const u8,
    sysroot: ?[]const u8 = null,
    /// `null` means to not emit a binary file.
    emit_bin: ?EmitLoc,
    /// `null` means to not emit a C header file.
    emit_h: ?EmitLoc = null,
    /// `null` means to not emit assembly.
    emit_asm: ?EmitLoc = null,
    /// `null` means to not emit LLVM IR.
    emit_llvm_ir: ?EmitLoc = null,
    /// `null` means to not emit LLVM module bitcode.
    emit_llvm_bc: ?EmitLoc = null,
    /// `null` means to not emit docs.
    emit_docs: ?EmitLoc = null,
    /// `null` means to not emit an import lib.
    emit_implib: ?EmitLoc = null,
    /// Normally when using LLD to link, Zig uses a file named "lld.id" in the
    /// same directory as the output binary which contains the hash of the link
    /// operation, allowing Zig to skip linking when the hash would be unchanged.
    /// In the case that the output binary is being emitted into a directory which
    /// is externally modified - essentially anything other than zig-cache - then
    /// this flag would be set to disable this machinery to avoid false positives.
    disable_lld_caching: bool = false,
    cache_mode: CacheMode = .incremental,
    /// This field is intended to be removed.
    /// The ELF implementation no longer uses this data, however the MachO and COFF
    /// implementations still do.
    lib_directories: []const Directory = &.{},
    rpath_list: []const []const u8 = &[0][]const u8{},
    symbol_wrap_set: std.StringArrayHashMapUnmanaged(void) = .empty,
    c_source_files: []const CSourceFile = &.{},
    rc_source_files: []const RcSourceFile = &.{},
    manifest_file: ?[]const u8 = null,
    rc_includes: RcIncludes = .any,
    link_inputs: []const link.Input = &.{},
    framework_dirs: []const []const u8 = &[0][]const u8{},
    frameworks: []const Framework = &.{},
    windows_lib_names: []const []const u8 = &.{},
    /// These correspond to the WASI libc emulated subcomponents including:
    /// * process clocks
    /// * getpid
    /// * mman
    /// * signal
    wasi_emulated_libs: []const wasi_libc.CrtFile = &.{},
    /// This means that if the output mode is an executable it will be a
    /// Position Independent Executable. If the output mode is not an
    /// executable this field is ignored.
    want_compiler_rt: ?bool = null,
    want_lto: ?bool = null,
    function_sections: bool = false,
    data_sections: bool = false,
    time_report: bool = false,
    stack_report: bool = false,
    link_eh_frame_hdr: bool = false,
    link_emit_relocs: bool = false,
    linker_script: ?[]const u8 = null,
    version_script: ?[]const u8 = null,
    linker_allow_undefined_version: bool = false,
    linker_enable_new_dtags: ?bool = null,
    soname: ?[]const u8 = null,
    linker_gc_sections: ?bool = null,
    linker_repro: ?bool = null,
    linker_allow_shlib_undefined: ?bool = null,
    linker_bind_global_refs_locally: ?bool = null,
    linker_import_symbols: bool = false,
    linker_import_table: bool = false,
    linker_export_table: bool = false,
    linker_initial_memory: ?u64 = null,
    linker_max_memory: ?u64 = null,
    linker_global_base: ?u64 = null,
    linker_export_symbol_names: []const []const u8 = &.{},
    linker_print_gc_sections: bool = false,
    linker_print_icf_sections: bool = false,
    linker_print_map: bool = false,
    llvm_opt_bisect_limit: i32 = -1,
    build_id: ?std.zig.BuildId = null,
    disable_c_depfile: bool = false,
    linker_z_nodelete: bool = false,
    linker_z_notext: bool = false,
    linker_z_defs: bool = false,
    linker_z_origin: bool = false,
    linker_z_now: bool = true,
    linker_z_relro: bool = true,
    linker_z_nocopyreloc: bool = false,
    linker_z_common_page_size: ?u64 = null,
    linker_z_max_page_size: ?u64 = null,
    linker_tsaware: bool = false,
    linker_nxcompat: bool = false,
    linker_dynamicbase: bool = true,
    linker_compress_debug_sections: ?link.File.Elf.CompressDebugSections = null,
    linker_module_definition_file: ?[]const u8 = null,
    linker_sort_section: ?link.File.Elf.SortSection = null,
    major_subsystem_version: ?u16 = null,
    minor_subsystem_version: ?u16 = null,
    clang_passthrough_mode: bool = false,
    verbose_cc: bool = false,
    verbose_link: bool = false,
    verbose_air: bool = false,
    verbose_intern_pool: bool = false,
    verbose_generic_instances: bool = false,
    verbose_llvm_ir: ?[]const u8 = null,
    verbose_llvm_bc: ?[]const u8 = null,
    verbose_cimport: bool = false,
    verbose_llvm_cpu_features: bool = false,
    debug_compiler_runtime_libs: bool = false,
    debug_compile_errors: bool = false,
    incremental: bool = false,
    /// Normally when you create a `Compilation`, Zig will automatically build
    /// and link in required dependencies, such as compiler-rt and libc. When
    /// building such dependencies themselves, this flag must be set to avoid
    /// infinite recursion.
    skip_linker_dependencies: bool = false,
    hash_style: link.File.Elf.HashStyle = .both,
    entry: Entry = .default,
    force_undefined_symbols: std.StringArrayHashMapUnmanaged(void) = .empty,
    stack_size: ?u64 = null,
    image_base: ?u64 = null,
    version: ?std.SemanticVersion = null,
    compatibility_version: ?std.SemanticVersion = null,
    libc_installation: ?*const LibCInstallation = null,
    native_system_include_paths: []const []const u8 = &.{},
    clang_preprocessor_mode: ClangPreprocessorMode = .no,
    reference_trace: ?u32 = null,
    test_filters: []const []const u8 = &.{},
    test_name_prefix: ?[]const u8 = null,
    test_runner_path: ?[]const u8 = null,
    subsystem: ?std.Target.SubSystem = null,
    mingw_unicode_entry_point: bool = false,
    /// (Zig compiler development) Enable dumping linker's state as JSON.
    enable_link_snapshots: bool = false,
    /// (Darwin) Install name of the dylib
    install_name: ?[]const u8 = null,
    /// (Darwin) Path to entitlements file
    entitlements: ?[]const u8 = null,
    /// (Darwin) size of the __PAGEZERO segment
    pagezero_size: ?u64 = null,
    /// (Darwin) set minimum space for future expansion of the load commands
    headerpad_size: ?u32 = null,
    /// (Darwin) set enough space as if all paths were MATPATHLEN
    headerpad_max_install_names: bool = false,
    /// (Darwin) remove dylibs that are unreachable by the entry point or exported symbols
    dead_strip_dylibs: bool = false,
    /// (Darwin) Force load all members of static archives that implement an Objective-C class or category
    force_load_objc: bool = false,
    libcxx_abi_version: libcxx.AbiVersion = libcxx.AbiVersion.default,
    /// (Windows) PDB source path prefix to instruct the linker how to resolve relative
    /// paths when consolidating CodeView streams into a single PDB file.
    pdb_source_path: ?[]const u8 = null,
    /// (Windows) PDB output path
    pdb_out_path: ?[]const u8 = null,
    error_limit: ?Zcu.ErrorInt = null,
    global_cc_argv: []const []const u8 = &.{},

    /// Tracks all files that can cause the Compilation to be invalidated and need a rebuild.
    file_system_inputs: ?*std.ArrayListUnmanaged(u8) = null,

    parent_whole_cache: ?ParentWholeCache = null,

    pub const Entry = link.File.OpenOptions.Entry;
};

fn addModuleTableToCacheHash(
    gpa: Allocator,
    arena: Allocator,
    hash: *Cache.HashHelper,
    root_mod: *Package.Module,
    main_mod: *Package.Module,
    hash_type: union(enum) { path_bytes, files: *Cache.Manifest },
) (error{OutOfMemory} || std.process.GetCwdError)!void {
    var seen_table: std.AutoArrayHashMapUnmanaged(*Package.Module, void) = .empty;
    defer seen_table.deinit(gpa);

    // root_mod and main_mod may be the same pointer. In fact they usually are.
    // However in the case of `zig test` or `zig build` they will be different,
    // and it's possible for one to not reference the other via the import table.
    try seen_table.put(gpa, root_mod, {});
    try seen_table.put(gpa, main_mod, {});

    const SortByName = struct {
        has_builtin: bool,
        names: []const []const u8,

        pub fn lessThan(ctx: @This(), lhs: usize, rhs: usize) bool {
            return if (ctx.has_builtin and (lhs == 0 or rhs == 0))
                lhs < rhs
            else
                mem.lessThan(u8, ctx.names[lhs], ctx.names[rhs]);
        }
    };

    var i: usize = 0;
    while (i < seen_table.count()) : (i += 1) {
        const mod = seen_table.keys()[i];
        if (mod.isBuiltin()) {
            // Skip builtin.zig; it is useless as an input, and we don't want to
            // have to write it before checking for a cache hit.
            continue;
        }

        cache_helpers.addModule(hash, mod);

        switch (hash_type) {
            .path_bytes => {
                hash.addBytes(mod.root_src_path);
                hash.addOptionalBytes(mod.root.root_dir.path);
                hash.addBytes(mod.root.sub_path);
            },
            .files => |man| if (mod.root_src_path.len != 0) {
                const pkg_zig_file = try mod.root.joinString(arena, mod.root_src_path);
                _ = try man.addFile(pkg_zig_file, null);
            },
        }

        mod.deps.sortUnstable(SortByName{
            .has_builtin = mod.deps.count() >= 1 and
                mod.deps.values()[0].isBuiltin(),
            .names = mod.deps.keys(),
        });

        hash.addListOfBytes(mod.deps.keys());

        const deps = mod.deps.values();
        try seen_table.ensureUnusedCapacity(gpa, deps.len);
        for (deps) |dep| seen_table.putAssumeCapacity(dep, {});
    }
}

pub fn create(gpa: Allocator, arena: Allocator, options: CreateOptions) !*Compilation {
    const output_mode = options.config.output_mode;
    const is_dyn_lib = switch (output_mode) {
        .Obj, .Exe => false,
        .Lib => options.config.link_mode == .dynamic,
    };
    const is_exe_or_dyn_lib = switch (output_mode) {
        .Obj => false,
        .Lib => is_dyn_lib,
        .Exe => true,
    };

    if (options.linker_export_table and options.linker_import_table) {
        return error.ExportTableAndImportTableConflict;
    }

    const have_zcu = options.config.have_zcu;

    const comp: *Compilation = comp: {
        // We put the `Compilation` itself in the arena. Freeing the arena will free the module.
        // It's initialized later after we prepare the initialization options.
        const root_name = try arena.dupeZ(u8, options.root_name);

        const use_llvm = options.config.use_llvm;

        // The "any" values provided by resolved config only account for
        // explicitly-provided settings. We now make them additionally account
        // for default setting resolution.
        const any_unwind_tables = options.config.any_unwind_tables or options.root_mod.unwind_tables != .none;
        const any_non_single_threaded = options.config.any_non_single_threaded or !options.root_mod.single_threaded;
        const any_sanitize_thread = options.config.any_sanitize_thread or options.root_mod.sanitize_thread;
        const any_fuzz = options.config.any_fuzz or options.root_mod.fuzz;

        const link_eh_frame_hdr = options.link_eh_frame_hdr or any_unwind_tables;
        const build_id = options.build_id orelse .none;

        const link_libc = options.config.link_libc;

        const libc_dirs = try std.zig.LibCDirs.detect(
            arena,
            options.zig_lib_directory.path.?,
            options.root_mod.resolved_target.result,
            options.root_mod.resolved_target.is_native_abi,
            link_libc,
            options.libc_installation,
        );

        const sysroot = options.sysroot orelse libc_dirs.sysroot;

        const include_compiler_rt = options.want_compiler_rt orelse
            (!options.skip_linker_dependencies and is_exe_or_dyn_lib);

        if (include_compiler_rt and output_mode == .Obj) {
            // For objects, this mechanism relies on essentially `_ = @import("compiler-rt");`
            // injected into the object.
            const compiler_rt_mod = try Package.Module.create(arena, .{
                .global_cache_directory = options.global_cache_directory,
                .paths = .{
                    .root = .{
                        .root_dir = options.zig_lib_directory,
                    },
                    .root_src_path = "compiler_rt.zig",
                },
                .fully_qualified_name = "compiler_rt",
                .cc_argv = &.{},
                .inherited = .{
                    .stack_check = false,
                    .stack_protector = 0,
                    .no_builtin = true,
                },
                .global = options.config,
                .parent = options.root_mod,
                .builtin_mod = options.root_mod.getBuiltinDependency(),
                .builtin_modules = null, // `builtin_mod` is set
            });
            try options.root_mod.deps.putNoClobber(arena, "compiler_rt", compiler_rt_mod);
        }

        if (options.verbose_llvm_cpu_features) {
            if (options.root_mod.resolved_target.llvm_cpu_features) |cf| print: {
                const target = options.root_mod.resolved_target.result;
                std.debug.lockStdErr();
                defer std.debug.unlockStdErr();
                const stderr = std.io.getStdErr().writer();
                nosuspend {
                    stderr.print("compilation: {s}\n", .{options.root_name}) catch break :print;
                    stderr.print("  target: {s}\n", .{try target.zigTriple(arena)}) catch break :print;
                    stderr.print("  cpu: {s}\n", .{target.cpu.model.name}) catch break :print;
                    stderr.print("  features: {s}\n", .{cf}) catch {};
                }
            }
        }

        const error_limit = options.error_limit orelse (std.math.maxInt(u16) - 1);

        // We put everything into the cache hash that *cannot be modified
        // during an incremental update*. For example, one cannot change the
        // target between updates, but one can change source files, so the
        // target goes into the cache hash, but source files do not. This is so
        // that we can find the same binary and incrementally update it even if
        // there are modified source files. We do this even if outputting to
        // the current directory because we need somewhere to store incremental
        // compilation metadata.
        const cache = try arena.create(Cache);
        cache.* = .{
            .gpa = gpa,
            .manifest_dir = try options.local_cache_directory.handle.makeOpenPath("h", .{}),
        };
        // These correspond to std.zig.Server.Message.PathPrefix.
        cache.addPrefix(.{ .path = null, .handle = std.fs.cwd() });
        cache.addPrefix(options.zig_lib_directory);
        cache.addPrefix(options.local_cache_directory);
        cache.addPrefix(options.global_cache_directory);
        errdefer cache.manifest_dir.close();

        // This is shared hasher state common to zig source and all C source files.
        cache.hash.addBytes(build_options.version);
        cache.hash.add(builtin.zig_backend);
        cache.hash.add(options.config.pie);
        cache.hash.add(options.config.lto);
        cache.hash.add(options.config.link_mode);
        cache.hash.add(options.config.any_unwind_tables);
        cache.hash.add(options.function_sections);
        cache.hash.add(options.data_sections);
        cache.hash.add(link_libc);
        cache.hash.add(options.config.link_libcpp);
        cache.hash.add(options.config.link_libunwind);
        cache.hash.add(output_mode);
        cache_helpers.addDebugFormat(&cache.hash, options.config.debug_format);
        cache_helpers.addOptionalEmitLoc(&cache.hash, options.emit_bin);
        cache_helpers.addOptionalEmitLoc(&cache.hash, options.emit_implib);
        cache_helpers.addOptionalEmitLoc(&cache.hash, options.emit_docs);
        cache.hash.addBytes(options.root_name);
        cache.hash.add(options.config.wasi_exec_model);
        cache.hash.add(options.config.san_cov_trace_pc_guard);
        cache.hash.add(options.debug_compiler_runtime_libs);
        // TODO audit this and make sure everything is in it

        const main_mod = options.main_mod orelse options.root_mod;
        const comp = try arena.create(Compilation);
        const opt_zcu: ?*Zcu = if (have_zcu) blk: {
            // Pre-open the directory handles for cached ZIR code so that it does not need
            // to redundantly happen for each AstGen operation.
            const zir_sub_dir = "z";

            var local_zir_dir = try options.local_cache_directory.handle.makeOpenPath(zir_sub_dir, .{});
            errdefer local_zir_dir.close();
            const local_zir_cache: Directory = .{
                .handle = local_zir_dir,
                .path = try options.local_cache_directory.join(arena, &[_][]const u8{zir_sub_dir}),
            };
            var global_zir_dir = try options.global_cache_directory.handle.makeOpenPath(zir_sub_dir, .{});
            errdefer global_zir_dir.close();
            const global_zir_cache: Directory = .{
                .handle = global_zir_dir,
                .path = try options.global_cache_directory.join(arena, &[_][]const u8{zir_sub_dir}),
            };

            const std_mod = options.std_mod orelse try Package.Module.create(arena, .{
                .global_cache_directory = options.global_cache_directory,
                .paths = .{
                    .root = .{
                        .root_dir = options.zig_lib_directory,
                        .sub_path = "std",
                    },
                    .root_src_path = "std.zig",
                },
                .fully_qualified_name = "std",
                .cc_argv = &.{},
                .inherited = .{},
                .global = options.config,
                .parent = options.root_mod,
                .builtin_mod = options.root_mod.getBuiltinDependency(),
                .builtin_modules = null, // `builtin_mod` is set
            });

            const zcu = try arena.create(Zcu);
            zcu.* = .{
                .gpa = gpa,
                .comp = comp,
                .main_mod = main_mod,
                .root_mod = options.root_mod,
                .std_mod = std_mod,
                .global_zir_cache = global_zir_cache,
                .local_zir_cache = local_zir_cache,
                .error_limit = error_limit,
                .llvm_object = null,
            };
            try zcu.init(options.thread_pool.getIdCount());
            break :blk zcu;
        } else blk: {
            if (options.emit_h != null) return error.NoZigModuleForCHeader;
            break :blk null;
        };
        errdefer if (opt_zcu) |zcu| zcu.deinit();

        var windows_libs = try std.StringArrayHashMapUnmanaged(void).init(gpa, options.windows_lib_names, &.{});
        errdefer windows_libs.deinit(gpa);

        comp.* = .{
            .gpa = gpa,
            .arena = arena,
            .zcu = opt_zcu,
            .cache_use = undefined, // populated below
            .bin_file = null, // populated below
            .implib_emit = null, // handled below
            .docs_emit = null, // handled below
            .root_mod = options.root_mod,
            .config = options.config,
            .zig_lib_directory = options.zig_lib_directory,
            .local_cache_directory = options.local_cache_directory,
            .global_cache_directory = options.global_cache_directory,
            .emit_asm = options.emit_asm,
            .emit_llvm_ir = options.emit_llvm_ir,
            .emit_llvm_bc = options.emit_llvm_bc,
            .work_queues = .{std.fifo.LinearFifo(Job, .Dynamic).init(gpa)} ** @typeInfo(std.meta.FieldType(Compilation, .work_queues)).array.len,
            .c_object_work_queue = std.fifo.LinearFifo(*CObject, .Dynamic).init(gpa),
            .win32_resource_work_queue = if (dev.env.supports(.win32_resource)) std.fifo.LinearFifo(*Win32Resource, .Dynamic).init(gpa) else .{},
            .astgen_work_queue = std.fifo.LinearFifo(Zcu.File.Index, .Dynamic).init(gpa),
            .c_source_files = options.c_source_files,
            .rc_source_files = options.rc_source_files,
            .cache_parent = cache,
            .self_exe_path = options.self_exe_path,
            .libc_include_dir_list = libc_dirs.libc_include_dir_list,
            .libc_framework_dir_list = libc_dirs.libc_framework_dir_list,
            .rc_includes = options.rc_includes,
            .mingw_unicode_entry_point = options.mingw_unicode_entry_point,
            .thread_pool = options.thread_pool,
            .clang_passthrough_mode = options.clang_passthrough_mode,
            .clang_preprocessor_mode = options.clang_preprocessor_mode,
            .verbose_cc = options.verbose_cc,
            .verbose_air = options.verbose_air,
            .verbose_intern_pool = options.verbose_intern_pool,
            .verbose_generic_instances = options.verbose_generic_instances,
            .verbose_llvm_ir = options.verbose_llvm_ir,
            .verbose_llvm_bc = options.verbose_llvm_bc,
            .verbose_cimport = options.verbose_cimport,
            .verbose_llvm_cpu_features = options.verbose_llvm_cpu_features,
            .verbose_link = options.verbose_link,
            .disable_c_depfile = options.disable_c_depfile,
            .reference_trace = options.reference_trace,
            .time_report = options.time_report,
            .stack_report = options.stack_report,
            .test_filters = options.test_filters,
            .test_name_prefix = options.test_name_prefix,
            .debug_compiler_runtime_libs = options.debug_compiler_runtime_libs,
            .debug_compile_errors = options.debug_compile_errors,
            .incremental = options.incremental,
            .libcxx_abi_version = options.libcxx_abi_version,
            .root_name = root_name,
            .sysroot = sysroot,
            .windows_libs = windows_libs,
            .version = options.version,
            .libc_installation = libc_dirs.libc_installation,
            .include_compiler_rt = include_compiler_rt,
            .link_inputs = options.link_inputs,
            .framework_dirs = options.framework_dirs,
            .llvm_opt_bisect_limit = options.llvm_opt_bisect_limit,
            .skip_linker_dependencies = options.skip_linker_dependencies,
            .queued_jobs = .{
                .update_builtin_zig = have_zcu,
            },
            .function_sections = options.function_sections,
            .data_sections = options.data_sections,
            .native_system_include_paths = options.native_system_include_paths,
            .wasi_emulated_libs = options.wasi_emulated_libs,
            .force_undefined_symbols = options.force_undefined_symbols,
            .link_eh_frame_hdr = link_eh_frame_hdr,
            .global_cc_argv = options.global_cc_argv,
            .file_system_inputs = options.file_system_inputs,
            .parent_whole_cache = options.parent_whole_cache,
            .link_diags = .init(gpa),
            .remaining_prelink_tasks = 0,
        };

        // Prevent some footguns by making the "any" fields of config reflect
        // the default Module settings.
        comp.config.any_unwind_tables = any_unwind_tables;
        comp.config.any_non_single_threaded = any_non_single_threaded;
        comp.config.any_sanitize_thread = any_sanitize_thread;
        comp.config.any_fuzz = any_fuzz;

        const lf_open_opts: link.File.OpenOptions = .{
            .linker_script = options.linker_script,
            .z_nodelete = options.linker_z_nodelete,
            .z_notext = options.linker_z_notext,
            .z_defs = options.linker_z_defs,
            .z_origin = options.linker_z_origin,
            .z_nocopyreloc = options.linker_z_nocopyreloc,
            .z_now = options.linker_z_now,
            .z_relro = options.linker_z_relro,
            .z_common_page_size = options.linker_z_common_page_size,
            .z_max_page_size = options.linker_z_max_page_size,
            .darwin_sdk_layout = libc_dirs.darwin_sdk_layout,
            .frameworks = options.frameworks,
            .lib_directories = options.lib_directories,
            .framework_dirs = options.framework_dirs,
            .rpath_list = options.rpath_list,
            .symbol_wrap_set = options.symbol_wrap_set,
            .repro = options.linker_repro orelse (options.root_mod.optimize_mode != .Debug),
            .allow_shlib_undefined = options.linker_allow_shlib_undefined,
            .bind_global_refs_locally = options.linker_bind_global_refs_locally orelse false,
            .compress_debug_sections = options.linker_compress_debug_sections orelse .none,
            .module_definition_file = options.linker_module_definition_file,
            .sort_section = options.linker_sort_section,
            .import_symbols = options.linker_import_symbols,
            .import_table = options.linker_import_table,
            .export_table = options.linker_export_table,
            .initial_memory = options.linker_initial_memory,
            .max_memory = options.linker_max_memory,
            .global_base = options.linker_global_base,
            .export_symbol_names = options.linker_export_symbol_names,
            .print_gc_sections = options.linker_print_gc_sections,
            .print_icf_sections = options.linker_print_icf_sections,
            .print_map = options.linker_print_map,
            .tsaware = options.linker_tsaware,
            .nxcompat = options.linker_nxcompat,
            .dynamicbase = options.linker_dynamicbase,
            .major_subsystem_version = options.major_subsystem_version,
            .minor_subsystem_version = options.minor_subsystem_version,
            .entry = options.entry,
            .stack_size = options.stack_size,
            .image_base = options.image_base,
            .version_script = options.version_script,
            .allow_undefined_version = options.linker_allow_undefined_version,
            .enable_new_dtags = options.linker_enable_new_dtags,
            .gc_sections = options.linker_gc_sections,
            .emit_relocs = options.link_emit_relocs,
            .soname = options.soname,
            .compatibility_version = options.compatibility_version,
            .build_id = build_id,
            .disable_lld_caching = options.disable_lld_caching or options.cache_mode == .whole,
            .subsystem = options.subsystem,
            .hash_style = options.hash_style,
            .enable_link_snapshots = options.enable_link_snapshots,
            .install_name = options.install_name,
            .entitlements = options.entitlements,
            .pagezero_size = options.pagezero_size,
            .headerpad_size = options.headerpad_size,
            .headerpad_max_install_names = options.headerpad_max_install_names,
            .dead_strip_dylibs = options.dead_strip_dylibs,
            .force_load_objc = options.force_load_objc,
            .pdb_source_path = options.pdb_source_path,
            .pdb_out_path = options.pdb_out_path,
            .entry_addr = null, // CLI does not expose this option (yet?)
            .object_host_name = "env",
        };

        switch (options.cache_mode) {
            .incremental => {
                // Options that are specific to zig source files, that cannot be
                // modified between incremental updates.
                var hash = cache.hash;

                // Synchronize with other matching comments: ZigOnlyHashStuff
                hash.add(use_llvm);
                hash.add(options.config.use_lib_llvm);
                hash.add(options.config.dll_export_fns);
                hash.add(options.config.is_test);
                hash.addListOfBytes(options.test_filters);
                hash.addOptionalBytes(options.test_name_prefix);
                hash.add(options.skip_linker_dependencies);
                hash.add(options.emit_h != null);
                hash.add(error_limit);

                // Here we put the root source file path name, but *not* with addFile.
                // We want the hash to be the same regardless of the contents of the
                // source file, because incremental compilation will handle it, but we
                // do want to namespace different source file names because they are
                // likely different compilations and therefore this would be likely to
                // cause cache hits.
                try addModuleTableToCacheHash(gpa, arena, &hash, options.root_mod, main_mod, .path_bytes);

                // In the case of incremental cache mode, this `artifact_directory`
                // is computed based on a hash of non-linker inputs, and it is where all
                // build artifacts are stored (even while in-progress).
                comp.digest = hash.peekBin();
                const digest = hash.final();

                const artifact_sub_dir = "o" ++ std.fs.path.sep_str ++ digest;
                var artifact_dir = try options.local_cache_directory.handle.makeOpenPath(artifact_sub_dir, .{});
                errdefer artifact_dir.close();
                const artifact_directory: Directory = .{
                    .handle = artifact_dir,
                    .path = try options.local_cache_directory.join(arena, &[_][]const u8{artifact_sub_dir}),
                };

                const incremental = try arena.create(CacheUse.Incremental);
                incremental.* = .{
                    .artifact_directory = artifact_directory,
                };
                comp.cache_use = .{ .incremental = incremental };

                if (options.emit_bin) |emit_bin| {
                    const emit: Path = .{
                        .root_dir = emit_bin.directory orelse artifact_directory,
                        .sub_path = emit_bin.basename,
                    };
                    comp.bin_file = try link.File.open(arena, comp, emit, lf_open_opts);
                }

                if (options.emit_implib) |emit_implib| {
                    comp.implib_emit = .{
                        .root_dir = emit_implib.directory orelse artifact_directory,
                        .sub_path = emit_implib.basename,
                    };
                }

                if (options.emit_docs) |emit_docs| {
                    comp.docs_emit = .{
                        .root_dir = emit_docs.directory orelse artifact_directory,
                        .sub_path = emit_docs.basename,
                    };
                }
            },
            .whole => {
                // For whole cache mode, we don't know where to put outputs from
                // the linker until the final cache hash, which is available after
                // the compilation is complete.
                //
                // Therefore, bin_file is left null until the beginning of update(),
                // where it may find a cache hit, or use a temporary directory to
                // hold output artifacts.
                const whole = try arena.create(CacheUse.Whole);
                whole.* = .{
                    // This is kept here so that link.File.open can be called later.
                    .lf_open_opts = lf_open_opts,
                    // This is so that when doing `CacheMode.whole`, the mechanism in update()
                    // can use it for communicating the result directory via `bin_file.emit`.
                    // This is used to distinguish between -fno-emit-bin and -femit-bin
                    // for `CacheMode.whole`.
                    // This memory will be overwritten with the real digest in update() but
                    // the basename will be preserved.
                    .bin_sub_path = try prepareWholeEmitSubPath(arena, options.emit_bin),
                    .implib_sub_path = try prepareWholeEmitSubPath(arena, options.emit_implib),
                    .docs_sub_path = try prepareWholeEmitSubPath(arena, options.emit_docs),
                    .tmp_artifact_directory = null,
                    .lock = null,
                };
                comp.cache_use = .{ .whole = whole };
            },
        }

        // Handle the case of e.g. -fno-emit-bin -femit-llvm-ir.
        if (options.emit_bin == null and (comp.verbose_llvm_ir != null or
            comp.verbose_llvm_bc != null or
            (use_llvm and comp.emit_asm != null) or
            comp.emit_llvm_ir != null or
            comp.emit_llvm_bc != null))
        {
            if (opt_zcu) |zcu| zcu.llvm_object = try LlvmObject.create(arena, comp);
        }

        break :comp comp;
    };
    errdefer comp.destroy();

    const target = comp.root_mod.resolved_target.result;

    const capable_of_building_compiler_rt = canBuildLibCompilerRt(target, comp.config.use_llvm);
    const capable_of_building_zig_libc = canBuildZigLibC(target, comp.config.use_llvm);

    // Add a `CObject` for each `c_source_files`.
    try comp.c_object_table.ensureTotalCapacity(gpa, options.c_source_files.len);
    for (options.c_source_files) |c_source_file| {
        const c_object = try gpa.create(CObject);
        errdefer gpa.destroy(c_object);

        c_object.* = .{
            .status = .{ .new = {} },
            .src = c_source_file,
        };
        comp.c_object_table.putAssumeCapacityNoClobber(c_object, {});
    }
    comp.remaining_prelink_tasks += @intCast(comp.c_object_table.count());

    // Add a `Win32Resource` for each `rc_source_files` and one for `manifest_file`.
    const win32_resource_count =
        options.rc_source_files.len + @intFromBool(options.manifest_file != null);
    if (win32_resource_count > 0) {
        dev.check(.win32_resource);
        try comp.win32_resource_table.ensureTotalCapacity(gpa, win32_resource_count);
        // Add this after adding logic to updateWin32Resource to pass the
        // result into link.loadInput. loadInput integration is not implemented
        // for Windows linking logic yet.
        //comp.remaining_prelink_tasks += @intCast(win32_resource_count);
        for (options.rc_source_files) |rc_source_file| {
            const win32_resource = try gpa.create(Win32Resource);
            errdefer gpa.destroy(win32_resource);

            win32_resource.* = .{
                .status = .{ .new = {} },
                .src = .{ .rc = rc_source_file },
            };
            comp.win32_resource_table.putAssumeCapacityNoClobber(win32_resource, {});
        }

        if (options.manifest_file) |manifest_path| {
            const win32_resource = try gpa.create(Win32Resource);
            errdefer gpa.destroy(win32_resource);

            win32_resource.* = .{
                .status = .{ .new = {} },
                .src = .{ .manifest = manifest_path },
            };
            comp.win32_resource_table.putAssumeCapacityNoClobber(win32_resource, {});
        }
    }

    const have_bin_emit = switch (comp.cache_use) {
        .whole => |whole| whole.bin_sub_path != null,
        .incremental => comp.bin_file != null,
    };

    if (have_bin_emit and target.ofmt != .c) {
        if (!comp.skip_linker_dependencies) {
            // If we need to build libc for the target, add work items for it.
            // We go through the work queue so that building can be done in parallel.
            // If linking against host libc installation, instead queue up jobs
            // for loading those files in the linker.
            if (comp.config.link_libc and is_exe_or_dyn_lib) {
                // If the "is darwin" check is moved below the libc_installation check below,
                // error.LibCInstallationMissingCrtDir is returned from lci.resolveCrtPaths().
                if (target.isDarwin()) {
                    switch (target.abi) {
                        .none, .simulator, .macabi => {},
                        else => return error.LibCUnavailable,
                    }
                    // TODO delete logic from MachO flush() and queue up tasks here instead.
                } else if (comp.libc_installation) |lci| {
                    const basenames = LibCInstallation.CrtBasenames.get(.{
                        .target = target,
                        .link_libc = comp.config.link_libc,
                        .output_mode = comp.config.output_mode,
                        .link_mode = comp.config.link_mode,
                        .pie = comp.config.pie,
                    });
                    const paths = try lci.resolveCrtPaths(arena, basenames, target);

                    const fields = @typeInfo(@TypeOf(paths)).@"struct".fields;
                    try comp.link_task_queue.shared.ensureUnusedCapacity(gpa, fields.len + 1);
                    inline for (fields) |field| {
                        if (@field(paths, field.name)) |path| {
                            comp.link_task_queue.shared.appendAssumeCapacity(.{ .load_object = path });
                            comp.remaining_prelink_tasks += 1;
                        }
                    }
                    // Loads the libraries provided by `target_util.libcFullLinkFlags(target)`.
                    comp.link_task_queue.shared.appendAssumeCapacity(.load_host_libc);
                    comp.remaining_prelink_tasks += 1;
                } else if (target.isMusl() and !target.isWasm()) {
                    if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

                    if (musl.needsCrt0(comp.config.output_mode, comp.config.link_mode, comp.config.pie)) |f| {
                        comp.queued_jobs.musl_crt_file[@intFromEnum(f)] = true;
                        comp.remaining_prelink_tasks += 1;
                    }
                    switch (comp.config.link_mode) {
                        .static => comp.queued_jobs.musl_crt_file[@intFromEnum(musl.CrtFile.libc_a)] = true,
                        .dynamic => comp.queued_jobs.musl_crt_file[@intFromEnum(musl.CrtFile.libc_so)] = true,
                    }
                    comp.remaining_prelink_tasks += 1;
                } else if (target.isGnuLibC()) {
                    if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

                    if (glibc.needsCrt0(comp.config.output_mode)) |f| {
                        comp.queued_jobs.glibc_crt_file[@intFromEnum(f)] = true;
                        comp.remaining_prelink_tasks += 1;
                    }
                    comp.queued_jobs.glibc_shared_objects = true;
                    comp.remaining_prelink_tasks += glibc.sharedObjectsCount(&target);

                    comp.queued_jobs.glibc_crt_file[@intFromEnum(glibc.CrtFile.libc_nonshared_a)] = true;
                    comp.remaining_prelink_tasks += 1;
                } else if (target.isWasm() and target.os.tag == .wasi) {
                    if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

                    for (comp.wasi_emulated_libs) |crt_file| {
                        comp.queued_jobs.wasi_libc_crt_file[@intFromEnum(crt_file)] = true;
                    }
                    comp.remaining_prelink_tasks += @intCast(comp.wasi_emulated_libs.len);

                    comp.queued_jobs.wasi_libc_crt_file[@intFromEnum(wasi_libc.execModelCrtFile(comp.config.wasi_exec_model))] = true;
                    comp.queued_jobs.wasi_libc_crt_file[@intFromEnum(wasi_libc.CrtFile.libc_a)] = true;
                    comp.remaining_prelink_tasks += 2;
                } else if (target.isMinGW()) {
                    if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

                    const main_crt_file: mingw.CrtFile = if (is_dyn_lib) .dllcrt2_o else .crt2_o;
                    comp.queued_jobs.mingw_crt_file[@intFromEnum(main_crt_file)] = true;
                    comp.queued_jobs.mingw_crt_file[@intFromEnum(mingw.CrtFile.mingw32_lib)] = true;
                    comp.remaining_prelink_tasks += 2;

                    // When linking mingw-w64 there are some import libs we always need.
                    try comp.windows_libs.ensureUnusedCapacity(gpa, mingw.always_link_libs.len);
                    for (mingw.always_link_libs) |name| comp.windows_libs.putAssumeCapacity(name, {});
                } else if (target.isDarwin()) {
                    switch (target.abi) {
                        .none, .simulator, .macabi => {},
                        else => return error.LibCUnavailable,
                    }
                } else if (target.os.tag == .freestanding and capable_of_building_zig_libc) {
                    comp.queued_jobs.zig_libc = true;
                    comp.remaining_prelink_tasks += 1;
                } else {
                    return error.LibCUnavailable;
                }
            }

            // Generate Windows import libs.
            if (target.os.tag == .windows) {
                const count = comp.windows_libs.count();
                for (0..count) |i| {
                    try comp.queueJob(.{ .windows_import_lib = i });
                }
                // when integrating coff linker with prelink, the above
                // queueJob will need to change into something else since those
                // jobs are dispatched *after* the link_task_wait_group.wait()
                // that happens when separateCodegenThreadOk() is false.
            }
            if (comp.wantBuildLibUnwindFromSource()) {
                comp.queued_jobs.libunwind = true;
                comp.remaining_prelink_tasks += 1;
            }
            if (build_options.have_llvm and is_exe_or_dyn_lib and comp.config.link_libcpp) {
                comp.queued_jobs.libcxx = true;
                comp.queued_jobs.libcxxabi = true;
                comp.remaining_prelink_tasks += 2;
            }
            if (build_options.have_llvm and is_exe_or_dyn_lib and comp.config.any_sanitize_thread) {
                comp.queued_jobs.libtsan = true;
                comp.remaining_prelink_tasks += 1;
            }

            if (comp.include_compiler_rt and capable_of_building_compiler_rt) {
                if (is_exe_or_dyn_lib) {
                    log.debug("queuing a job to build compiler_rt_lib", .{});
                    comp.queued_jobs.compiler_rt_lib = true;
                    comp.remaining_prelink_tasks += 1;
                } else if (output_mode != .Obj) {
                    log.debug("queuing a job to build compiler_rt_obj", .{});
                    // In this case we are making a static library, so we ask
                    // for a compiler-rt object to put in it.
                    comp.queued_jobs.compiler_rt_obj = true;
                    comp.remaining_prelink_tasks += 1;
                }
            }

            if (is_exe_or_dyn_lib and comp.config.any_fuzz and capable_of_building_compiler_rt) {
                log.debug("queuing a job to build libfuzzer", .{});
                comp.queued_jobs.fuzzer_lib = true;
                comp.remaining_prelink_tasks += 1;
            }
        }

        try comp.link_task_queue.shared.append(gpa, .load_explicitly_provided);
        comp.remaining_prelink_tasks += 1;
    }
    log.debug("total prelink tasks: {d}", .{comp.remaining_prelink_tasks});

    return comp;
}

pub fn destroy(comp: *Compilation) void {
    const gpa = comp.gpa;

    if (comp.bin_file) |lf| lf.destroy();
    if (comp.zcu) |zcu| zcu.deinit();
    comp.cache_use.deinit();
    for (comp.work_queues) |work_queue| work_queue.deinit();
    comp.c_object_work_queue.deinit();
    comp.win32_resource_work_queue.deinit();
    comp.astgen_work_queue.deinit();

    comp.windows_libs.deinit(gpa);

    {
        var it = comp.crt_files.iterator();
        while (it.next()) |entry| {
            gpa.free(entry.key_ptr.*);
            entry.value_ptr.deinit(gpa);
        }
        comp.crt_files.deinit(gpa);
    }

    if (comp.libunwind_static_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }
    if (comp.libcxx_static_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }
    if (comp.libcxxabi_static_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }
    if (comp.compiler_rt_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }
    if (comp.compiler_rt_obj) |*crt_file| {
        crt_file.deinit(gpa);
    }
    if (comp.fuzzer_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }
    if (comp.libc_static_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }

    if (comp.glibc_so_files) |*glibc_file| {
        glibc_file.deinit(gpa);
    }

    for (comp.c_object_table.keys()) |key| {
        key.destroy(gpa);
    }
    comp.c_object_table.deinit(gpa);

    for (comp.failed_c_objects.values()) |bundle| {
        bundle.destroy(gpa);
    }
    comp.failed_c_objects.deinit(gpa);

    for (comp.win32_resource_table.keys()) |key| {
        key.destroy(gpa);
    }
    comp.win32_resource_table.deinit(gpa);

    for (comp.failed_win32_resources.values()) |*value| {
        value.deinit(gpa);
    }
    comp.failed_win32_resources.deinit(gpa);

    comp.link_diags.deinit();
    comp.link_task_queue.deinit(gpa);
    comp.link_task_queue_postponed.deinit(gpa);

    comp.clearMiscFailures();

    comp.cache_parent.manifest_dir.close();
}

pub fn clearMiscFailures(comp: *Compilation) void {
    comp.alloc_failure_occurred = false;
    for (comp.misc_failures.values()) |*value| {
        value.deinit(comp.gpa);
    }
    comp.misc_failures.deinit(comp.gpa);
    comp.misc_failures = .{};
}

pub fn getTarget(self: Compilation) Target {
    return self.root_mod.resolved_target.result;
}

/// Only legal to call when cache mode is incremental and a link file is present.
pub fn hotCodeSwap(
    comp: *Compilation,
    prog_node: std.Progress.Node,
    pid: std.process.Child.Id,
) !void {
    const lf = comp.bin_file.?;
    lf.child_pid = pid;
    try lf.makeWritable();
    try comp.update(prog_node);
    try lf.makeExecutable();
}

fn cleanupAfterUpdate(comp: *Compilation) void {
    switch (comp.cache_use) {
        .incremental => return,
        .whole => |whole| {
            if (whole.cache_manifest) |man| {
                man.deinit();
                whole.cache_manifest = null;
            }
            if (comp.bin_file) |lf| {
                lf.destroy();
                comp.bin_file = null;
            }
            if (whole.tmp_artifact_directory) |*directory| {
                directory.handle.close();
                if (directory.path) |p| comp.gpa.free(p);
                whole.tmp_artifact_directory = null;
            }
        },
    }
}

/// Detect changes to source files, perform semantic analysis, and update the output files.
pub fn update(comp: *Compilation, main_progress_node: std.Progress.Node) !void {
    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    // This arena is scoped to this one update.
    const gpa = comp.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    comp.clearMiscFailures();
    comp.last_update_was_cache_hit = false;

    var man: Cache.Manifest = undefined;
    defer cleanupAfterUpdate(comp);

    var tmp_dir_rand_int: u64 = undefined;

    // If using the whole caching strategy, we check for *everything* up front, including
    // C source files.
    switch (comp.cache_use) {
        .whole => |whole| {
            assert(comp.bin_file == null);
            // We are about to obtain this lock, so here we give other processes a chance first.
            whole.releaseLock();

            man = comp.cache_parent.obtain();
            whole.cache_manifest = &man;
            try addNonIncrementalStuffToCacheManifest(comp, arena, &man);

            const is_hit = man.hit() catch |err| switch (err) {
                error.CacheCheckFailed => switch (man.diagnostic) {
                    .none => unreachable,
                    .manifest_create, .manifest_read, .manifest_lock => |e| return comp.setMiscFailure(
                        .check_whole_cache,
                        "failed to check cache: {s} {s}",
                        .{ @tagName(man.diagnostic), @errorName(e) },
                    ),
                    .file_open, .file_stat, .file_read, .file_hash => |op| {
                        const pp = man.files.keys()[op.file_index].prefixed_path;
                        const prefix = man.cache.prefixes()[pp.prefix];
                        return comp.setMiscFailure(
                            .check_whole_cache,
                            "failed to check cache: '{}{s}' {s} {s}",
                            .{ prefix, pp.sub_path, @tagName(man.diagnostic), @errorName(op.err) },
                        );
                    },
                },
                error.OutOfMemory => return error.OutOfMemory,
                error.InvalidFormat => return comp.setMiscFailure(
                    .check_whole_cache,
                    "failed to check cache: invalid manifest file format",
                    .{},
                ),
            };
            if (is_hit) {
                // In this case the cache hit contains the full set of file system inputs. Nice!
                if (comp.file_system_inputs) |buf| try man.populateFileSystemInputs(buf);
                if (comp.parent_whole_cache) |pwc| {
                    pwc.mutex.lock();
                    defer pwc.mutex.unlock();
                    try man.populateOtherManifest(pwc.manifest, pwc.prefix_map);
                }

                comp.last_update_was_cache_hit = true;
                log.debug("CacheMode.whole cache hit for {s}", .{comp.root_name});
                const bin_digest = man.finalBin();
                const hex_digest = Cache.binToHex(bin_digest);

                comp.digest = bin_digest;
                comp.wholeCacheModeSetBinFilePath(whole, &hex_digest);

                assert(whole.lock == null);
                whole.lock = man.toOwnedLock();
                return;
            }
            log.debug("CacheMode.whole cache miss for {s}", .{comp.root_name});

            // Compile the artifacts to a temporary directory.
            const tmp_artifact_directory: Directory = d: {
                const s = std.fs.path.sep_str;
                tmp_dir_rand_int = std.crypto.random.int(u64);
                const tmp_dir_sub_path = "tmp" ++ s ++ std.fmt.hex(tmp_dir_rand_int);

                const path = try comp.local_cache_directory.join(gpa, &.{tmp_dir_sub_path});
                errdefer gpa.free(path);

                const handle = try comp.local_cache_directory.handle.makeOpenPath(tmp_dir_sub_path, .{});
                errdefer handle.close();

                break :d .{
                    .path = path,
                    .handle = handle,
                };
            };
            whole.tmp_artifact_directory = tmp_artifact_directory;

            // Now that the directory is known, it is time to create the Emit
            // objects and call link.File.open.

            if (whole.implib_sub_path) |sub_path| {
                comp.implib_emit = .{
                    .root_dir = tmp_artifact_directory,
                    .sub_path = std.fs.path.basename(sub_path),
                };
            }

            if (whole.docs_sub_path) |sub_path| {
                comp.docs_emit = .{
                    .root_dir = tmp_artifact_directory,
                    .sub_path = std.fs.path.basename(sub_path),
                };
            }

            if (whole.bin_sub_path) |sub_path| {
                const emit: Path = .{
                    .root_dir = tmp_artifact_directory,
                    .sub_path = std.fs.path.basename(sub_path),
                };
                comp.bin_file = try link.File.createEmpty(arena, comp, emit, whole.lf_open_opts);
            }
        },
        .incremental => {
            log.debug("Compilation.update for {s}, CacheMode.incremental", .{comp.root_name});
        },
    }

    // From this point we add a preliminary set of file system inputs that
    // affects both incremental and whole cache mode. For incremental cache
    // mode, the long-lived compiler state will track additional file system
    // inputs discovered after this point. For whole cache mode, we rely on
    // these inputs to make it past AstGen, and once there, we can rely on
    // learning file system inputs from the Cache object.

    // For compiling C objects, we rely on the cache hash system to avoid duplicating work.
    // Add a Job for each C object.
    try comp.c_object_work_queue.ensureUnusedCapacity(comp.c_object_table.count());
    for (comp.c_object_table.keys()) |key| {
        comp.c_object_work_queue.writeItemAssumeCapacity(key);
    }
    if (comp.file_system_inputs) |fsi| {
        for (comp.c_object_table.keys()) |c_object| {
            try comp.appendFileSystemInput(fsi, Cache.Path.cwd(), c_object.src.src_path);
        }
    }

    // For compiling Win32 resources, we rely on the cache hash system to avoid duplicating work.
    // Add a Job for each Win32 resource file.
    try comp.win32_resource_work_queue.ensureUnusedCapacity(comp.win32_resource_table.count());
    for (comp.win32_resource_table.keys()) |key| {
        comp.win32_resource_work_queue.writeItemAssumeCapacity(key);
    }
    if (comp.file_system_inputs) |fsi| {
        for (comp.win32_resource_table.keys()) |win32_resource| switch (win32_resource.src) {
            .rc => |f| try comp.appendFileSystemInput(fsi, Cache.Path.cwd(), f.src_path),
            .manifest => continue,
        };
    }

    if (comp.zcu) |zcu| {
        const pt: Zcu.PerThread = .activate(zcu, .main);
        defer pt.deactivate();

        zcu.compile_log_text.shrinkAndFree(gpa, 0);

        zcu.skip_analysis_errors = false;

        // Make sure std.zig is inside the import_table. We unconditionally need
        // it for start.zig.
        const std_mod = zcu.std_mod;
        _ = try pt.importPkg(std_mod);

        // Normally we rely on importing std to in turn import the root source file
        // in the start code, but when using the stage1 backend that won't happen,
        // so in order to run AstGen on the root source file we put it into the
        // import_table here.
        // Likewise, in the case of `zig test`, the test runner is the root source file,
        // and so there is nothing to import the main file.
        if (comp.config.is_test) {
            _ = try pt.importPkg(zcu.main_mod);
        }

        if (zcu.root_mod.deps.get("compiler_rt")) |compiler_rt_mod| {
            _ = try pt.importPkg(compiler_rt_mod);
        }

        // Put a work item in for every known source file to detect if
        // it changed, and, if so, re-compute ZIR and then queue the job
        // to update it.
        try comp.astgen_work_queue.ensureUnusedCapacity(zcu.import_table.count());
        for (zcu.import_table.values()) |file_index| {
            if (zcu.fileByIndex(file_index).mod.isBuiltin()) continue;
            comp.astgen_work_queue.writeItemAssumeCapacity(file_index);
        }
        if (comp.file_system_inputs) |fsi| {
            for (zcu.import_table.values()) |file_index| {
                const file = zcu.fileByIndex(file_index);
                try comp.appendFileSystemInput(fsi, file.mod.root, file.sub_file_path);
            }
        }

        if (comp.file_system_inputs) |fsi| {
            const ip = &zcu.intern_pool;
            for (zcu.embed_table.values()) |embed_file| {
                const sub_file_path = embed_file.sub_file_path.toSlice(ip);
                try comp.appendFileSystemInput(fsi, embed_file.owner.root, sub_file_path);
            }
        }

        zcu.analysis_roots.clear();

        try comp.queueJob(.{ .analyze_mod = std_mod });
        zcu.analysis_roots.appendAssumeCapacity(std_mod);

        if (comp.config.is_test and zcu.main_mod != std_mod) {
            try comp.queueJob(.{ .analyze_mod = zcu.main_mod });
            zcu.analysis_roots.appendAssumeCapacity(zcu.main_mod);
        }

        if (zcu.root_mod.deps.get("compiler_rt")) |compiler_rt_mod| {
            try comp.queueJob(.{ .analyze_mod = compiler_rt_mod });
            zcu.analysis_roots.appendAssumeCapacity(compiler_rt_mod);
        }
    }

    try comp.performAllTheWork(main_progress_node);

    if (comp.zcu) |zcu| {
        const pt: Zcu.PerThread = .activate(zcu, .main);
        defer pt.deactivate();

        if (build_options.enable_debug_extensions and comp.verbose_intern_pool) {
            std.debug.print("intern pool stats for '{s}':\n", .{
                comp.root_name,
            });
            zcu.intern_pool.dump();
        }

        if (build_options.enable_debug_extensions and comp.verbose_generic_instances) {
            std.debug.print("generic instances for '{s}:0x{x}':\n", .{
                comp.root_name,
                @intFromPtr(zcu),
            });
            zcu.intern_pool.dumpGenericInstances(gpa);
        }

        if (comp.config.is_test) {
            // The `test_functions` decl has been intentionally postponed until now,
            // at which point we must populate it with the list of test functions that
            // have been discovered and not filtered out.
            try pt.populateTestFunctions(main_progress_node);
        }

        try pt.processExports();
    }

    if (anyErrors(comp)) {
        // Skip flushing and keep source files loaded for error reporting.
        comp.link_diags.flags = .{};
        return;
    }

    // Flush below handles -femit-bin but there is still -femit-llvm-ir,
    // -femit-llvm-bc, and -femit-asm, in the case of C objects.
    comp.emitOthers();

    switch (comp.cache_use) {
        .whole => |whole| {
            if (comp.file_system_inputs) |buf| try man.populateFileSystemInputs(buf);
            if (comp.parent_whole_cache) |pwc| {
                pwc.mutex.lock();
                defer pwc.mutex.unlock();
                try man.populateOtherManifest(pwc.manifest, pwc.prefix_map);
            }

            const bin_digest = man.finalBin();
            const hex_digest = Cache.binToHex(bin_digest);

            // Rename the temporary directory into place.
            // Close tmp dir and link.File to avoid open handle during rename.
            if (whole.tmp_artifact_directory) |*tmp_directory| {
                tmp_directory.handle.close();
                if (tmp_directory.path) |p| gpa.free(p);
                whole.tmp_artifact_directory = null;
            } else unreachable;

            const s = std.fs.path.sep_str;
            const tmp_dir_sub_path = "tmp" ++ s ++ std.fmt.hex(tmp_dir_rand_int);
            const o_sub_path = "o" ++ s ++ hex_digest;

            // Work around windows `AccessDenied` if any files within this
            // directory are open by closing and reopening the file handles.
            const need_writable_dance = w: {
                if (builtin.os.tag == .windows) {
                    if (comp.bin_file) |lf| {
                        // We cannot just call `makeExecutable` as it makes a false
                        // assumption that we have a file handle open only when linking
                        // an executable file. This used to be true when our linkers
                        // were incapable of emitting relocatables and static archive.
                        // Now that they are capable, we need to unconditionally close
                        // the file handle and re-open it in the follow up call to
                        // `makeWritable`.
                        if (lf.file) |f| {
                            f.close();
                            lf.file = null;
                            break :w true;
                        }
                    }
                }
                break :w false;
            };

            renameTmpIntoCache(comp.local_cache_directory, tmp_dir_sub_path, o_sub_path) catch |err| {
                return comp.setMiscFailure(
                    .rename_results,
                    "failed to rename compilation results ('{}{s}') into local cache ('{}{s}'): {s}",
                    .{
                        comp.local_cache_directory, tmp_dir_sub_path,
                        comp.local_cache_directory, o_sub_path,
                        @errorName(err),
                    },
                );
            };
            comp.digest = bin_digest;
            comp.wholeCacheModeSetBinFilePath(whole, &hex_digest);

            // The linker flush functions need to know the final output path
            // for debug info purposes because executable debug info contains
            // references object file paths.
            if (comp.bin_file) |lf| {
                lf.emit = .{
                    .root_dir = comp.local_cache_directory,
                    .sub_path = whole.bin_sub_path.?,
                };

                // Has to be after the `wholeCacheModeSetBinFilePath` above.
                if (need_writable_dance) {
                    try lf.makeWritable();
                }
            }

            try flush(comp, arena, .{
                .root_dir = comp.local_cache_directory,
                .sub_path = o_sub_path,
            }, .main, main_progress_node);

            // Calling `flush` may have produced errors, in which case the
            // cache manifest must not be written.
            if (anyErrors(comp)) return;

            // Failure here only means an unnecessary cache miss.
            man.writeManifest() catch |err| {
                log.warn("failed to write cache manifest: {s}", .{@errorName(err)});
            };

            if (comp.bin_file) |lf| {
                lf.destroy();
                comp.bin_file = null;
            }

            assert(whole.lock == null);
            whole.lock = man.toOwnedLock();
        },
        .incremental => |incremental| {
            try flush(comp, arena, .{
                .root_dir = incremental.artifact_directory,
            }, .main, main_progress_node);
        },
    }
}

pub fn appendFileSystemInput(
    comp: *Compilation,
    file_system_inputs: *std.ArrayListUnmanaged(u8),
    root: Cache.Path,
    sub_file_path: []const u8,
) Allocator.Error!void {
    const gpa = comp.gpa;
    const prefixes = comp.cache_parent.prefixes();
    try file_system_inputs.ensureUnusedCapacity(gpa, root.sub_path.len + sub_file_path.len + 3);
    if (file_system_inputs.items.len > 0) file_system_inputs.appendAssumeCapacity(0);
    for (prefixes, 1..) |prefix_directory, i| {
        if (prefix_directory.eql(root.root_dir)) {
            file_system_inputs.appendAssumeCapacity(@intCast(i));
            if (root.sub_path.len > 0) {
                file_system_inputs.appendSliceAssumeCapacity(root.sub_path);
                file_system_inputs.appendAssumeCapacity(std.fs.path.sep);
            }
            file_system_inputs.appendSliceAssumeCapacity(sub_file_path);
            return;
        }
    }
    std.debug.panic("missing prefix directory: {}, {s}", .{ root, sub_file_path });
}

fn flush(
    comp: *Compilation,
    arena: Allocator,
    default_artifact_directory: Path,
    tid: Zcu.PerThread.Id,
    prog_node: std.Progress.Node,
) !void {
    if (comp.bin_file) |lf| {
        // This is needed before reading the error flags.
        lf.flush(arena, tid, prog_node) catch |err| switch (err) {
            error.LinkFailure => {}, // Already reported.
            error.OutOfMemory => return error.OutOfMemory,
        };
    }

    if (comp.zcu) |zcu| {
        try link.File.C.flushEmitH(zcu);

        if (zcu.llvm_object) |llvm_object| {
            try emitLlvmObject(comp, arena, default_artifact_directory, null, llvm_object, prog_node);
        }
    }
}

/// This function is called by the frontend before flush(). It communicates that
/// `options.bin_file.emit` directory needs to be renamed from
/// `[zig-cache]/tmp/[random]` to `[zig-cache]/o/[digest]`.
/// The frontend would like to simply perform a file system rename, however,
/// some linker backends care about the file paths of the objects they are linking.
/// So this function call tells linker backends to rename the paths of object files
/// to observe the new directory path.
/// Linker backends which do not have this requirement can fall back to the simple
/// implementation at the bottom of this function.
/// This function is only called when CacheMode is `whole`.
fn renameTmpIntoCache(
    cache_directory: Compilation.Directory,
    tmp_dir_sub_path: []const u8,
    o_sub_path: []const u8,
) !void {
    var seen_eaccess = false;
    while (true) {
        std.fs.rename(
            cache_directory.handle,
            tmp_dir_sub_path,
            cache_directory.handle,
            o_sub_path,
        ) catch |err| switch (err) {
            // On Windows, rename fails with `AccessDenied` rather than `PathAlreadyExists`.
            // See https://github.com/ziglang/zig/issues/8362
            error.AccessDenied => switch (builtin.os.tag) {
                .windows => {
                    if (seen_eaccess) return error.AccessDenied;
                    seen_eaccess = true;
                    try cache_directory.handle.deleteTree(o_sub_path);
                    continue;
                },
                else => return error.AccessDenied,
            },
            error.PathAlreadyExists => {
                try cache_directory.handle.deleteTree(o_sub_path);
                continue;
            },
            error.FileNotFound => {
                try cache_directory.handle.makePath("o");
                continue;
            },
            else => |e| return e,
        };
        break;
    }
}

/// Communicate the output binary location to parent Compilations.
fn wholeCacheModeSetBinFilePath(
    comp: *Compilation,
    whole: *CacheUse.Whole,
    digest: *const [Cache.hex_digest_len]u8,
) void {
    const digest_start = 2; // "o/[digest]/[basename]"

    if (whole.bin_sub_path) |sub_path| {
        @memcpy(sub_path[digest_start..][0..digest.len], digest);
    }

    if (whole.implib_sub_path) |sub_path| {
        @memcpy(sub_path[digest_start..][0..digest.len], digest);

        comp.implib_emit = .{
            .root_dir = comp.local_cache_directory,
            .sub_path = sub_path,
        };
    }

    if (whole.docs_sub_path) |sub_path| {
        @memcpy(sub_path[digest_start..][0..digest.len], digest);

        comp.docs_emit = .{
            .root_dir = comp.local_cache_directory,
            .sub_path = sub_path,
        };
    }
}

fn prepareWholeEmitSubPath(arena: Allocator, opt_emit: ?EmitLoc) error{OutOfMemory}!?[]u8 {
    const emit = opt_emit orelse return null;
    if (emit.directory != null) return null;
    const s = std.fs.path.sep_str;
    const format = "o" ++ s ++ ("x" ** Cache.hex_digest_len) ++ s ++ "{s}";
    return try std.fmt.allocPrint(arena, format, .{emit.basename});
}

/// This is only observed at compile-time and used to emit a compile error
/// to remind the programmer to update multiple related pieces of code that
/// are in different locations. Bump this number when adding or deleting
/// anything from the link cache manifest.
pub const link_hash_implementation_version = 14;

fn addNonIncrementalStuffToCacheManifest(
    comp: *Compilation,
    arena: Allocator,
    man: *Cache.Manifest,
) !void {
    const gpa = comp.gpa;

    comptime assert(link_hash_implementation_version == 14);

    if (comp.zcu) |mod| {
        try addModuleTableToCacheHash(gpa, arena, &man.hash, mod.root_mod, mod.main_mod, .{ .files = man });

        // Synchronize with other matching comments: ZigOnlyHashStuff
        man.hash.addListOfBytes(comp.test_filters);
        man.hash.addOptionalBytes(comp.test_name_prefix);
        man.hash.add(comp.skip_linker_dependencies);
        //man.hash.add(mod.emit_h != null);
        man.hash.add(mod.error_limit);
    } else {
        cache_helpers.addModule(&man.hash, comp.root_mod);
    }

    try link.hashInputs(man, comp.link_inputs);

    for (comp.c_object_table.keys()) |key| {
        _ = try man.addFile(key.src.src_path, null);
        man.hash.addOptional(key.src.ext);
        man.hash.addListOfBytes(key.src.extra_flags);
    }

    for (comp.win32_resource_table.keys()) |key| {
        switch (key.src) {
            .rc => |rc_src| {
                _ = try man.addFile(rc_src.src_path, null);
                man.hash.addListOfBytes(rc_src.extra_flags);
            },
            .manifest => |manifest_path| {
                _ = try man.addFile(manifest_path, null);
            },
        }
    }

    man.hash.add(comp.config.use_llvm);
    man.hash.add(comp.config.use_lib_llvm);
    man.hash.add(comp.config.is_test);
    man.hash.add(comp.config.import_memory);
    man.hash.add(comp.config.export_memory);
    man.hash.add(comp.config.shared_memory);
    man.hash.add(comp.config.dll_export_fns);
    man.hash.add(comp.config.rdynamic);

    man.hash.addOptionalBytes(comp.sysroot);
    man.hash.addOptional(comp.version);
    man.hash.add(comp.link_eh_frame_hdr);
    man.hash.add(comp.skip_linker_dependencies);
    man.hash.add(comp.include_compiler_rt);
    man.hash.add(comp.rc_includes);
    man.hash.addListOfBytes(comp.force_undefined_symbols.keys());
    man.hash.addListOfBytes(comp.framework_dirs);
    man.hash.addListOfBytes(comp.windows_libs.keys());

    cache_helpers.addOptionalEmitLoc(&man.hash, comp.emit_asm);
    cache_helpers.addOptionalEmitLoc(&man.hash, comp.emit_llvm_ir);
    cache_helpers.addOptionalEmitLoc(&man.hash, comp.emit_llvm_bc);

    man.hash.addListOfBytes(comp.global_cc_argv);

    const opts = comp.cache_use.whole.lf_open_opts;

    try man.addOptionalFile(opts.linker_script);
    try man.addOptionalFile(opts.version_script);
    man.hash.add(opts.allow_undefined_version);
    man.hash.addOptional(opts.enable_new_dtags);

    man.hash.addOptional(opts.stack_size);
    man.hash.addOptional(opts.image_base);
    man.hash.addOptional(opts.gc_sections);
    man.hash.add(opts.emit_relocs);
    const target = comp.root_mod.resolved_target.result;
    if (target.ofmt == .macho or target.ofmt == .coff) {
        // TODO remove this, libraries need to be resolved by the frontend. this is already
        // done by ELF.
        for (opts.lib_directories) |lib_directory| man.hash.addOptionalBytes(lib_directory.path);
    }
    man.hash.addListOfBytes(opts.rpath_list);
    man.hash.addListOfBytes(opts.symbol_wrap_set.keys());
    if (comp.config.link_libc) {
        man.hash.add(comp.libc_installation != null);
        if (comp.libc_installation) |libc_installation| {
            man.hash.addOptionalBytes(libc_installation.crt_dir);
            if (target.abi == .msvc or target.abi == .itanium) {
                man.hash.addOptionalBytes(libc_installation.msvc_lib_dir);
                man.hash.addOptionalBytes(libc_installation.kernel32_lib_dir);
            }
        }
        man.hash.addOptionalBytes(target.dynamic_linker.get());
    }
    man.hash.add(opts.repro);
    man.hash.addOptional(opts.allow_shlib_undefined);
    man.hash.add(opts.bind_global_refs_locally);

    // ELF specific stuff
    man.hash.add(opts.z_nodelete);
    man.hash.add(opts.z_notext);
    man.hash.add(opts.z_defs);
    man.hash.add(opts.z_origin);
    man.hash.add(opts.z_nocopyreloc);
    man.hash.add(opts.z_now);
    man.hash.add(opts.z_relro);
    man.hash.add(opts.z_common_page_size orelse 0);
    man.hash.add(opts.z_max_page_size orelse 0);
    man.hash.add(opts.hash_style);
    man.hash.add(opts.compress_debug_sections);
    man.hash.addOptional(opts.sort_section);
    man.hash.addOptionalBytes(opts.soname);
    man.hash.add(opts.build_id);

    // WASM specific stuff
    man.hash.addOptional(opts.initial_memory);
    man.hash.addOptional(opts.max_memory);
    man.hash.addOptional(opts.global_base);
    man.hash.addListOfBytes(opts.export_symbol_names);

    // Mach-O specific stuff
    try link.File.MachO.hashAddFrameworks(man, opts.frameworks);
    try man.addOptionalFile(opts.entitlements);
    man.hash.addOptional(opts.pagezero_size);
    man.hash.addOptional(opts.headerpad_size);
    man.hash.add(opts.headerpad_max_install_names);
    man.hash.add(opts.dead_strip_dylibs);
    man.hash.add(opts.force_load_objc);

    // COFF specific stuff
    man.hash.addOptional(opts.subsystem);
    man.hash.add(opts.tsaware);
    man.hash.add(opts.nxcompat);
    man.hash.add(opts.dynamicbase);
    man.hash.addOptional(opts.major_subsystem_version);
    man.hash.addOptional(opts.minor_subsystem_version);
}

fn emitOthers(comp: *Compilation) void {
    if (comp.config.output_mode != .Obj or comp.zcu != null or
        comp.c_object_table.count() == 0)
    {
        return;
    }
    const obj_path = comp.c_object_table.keys()[0].status.success.object_path;
    const ext = std.fs.path.extension(obj_path.sub_path);
    const dirname = obj_path.sub_path[0 .. obj_path.sub_path.len - ext.len];
    // This obj path always ends with the object file extension, but if we change the
    // extension to .ll, .bc, or .s, then it will be the path to those things.
    const outs = [_]struct {
        emit: ?EmitLoc,
        ext: []const u8,
    }{
        .{ .emit = comp.emit_asm, .ext = ".s" },
        .{ .emit = comp.emit_llvm_ir, .ext = ".ll" },
        .{ .emit = comp.emit_llvm_bc, .ext = ".bc" },
    };
    for (outs) |out| {
        if (out.emit) |loc| {
            if (loc.directory) |directory| {
                const src_path = std.fmt.allocPrint(comp.gpa, "{s}{s}", .{
                    dirname, out.ext,
                }) catch |err| {
                    log.err("unable to copy {s}{s}: {s}", .{ dirname, out.ext, @errorName(err) });
                    continue;
                };
                defer comp.gpa.free(src_path);
                obj_path.root_dir.handle.copyFile(src_path, directory.handle, loc.basename, .{}) catch |err| {
                    log.err("unable to copy {s}: {s}", .{ src_path, @errorName(err) });
                };
            }
        }
    }
}

pub fn emitLlvmObject(
    comp: *Compilation,
    arena: Allocator,
    default_artifact_directory: Path,
    bin_emit_loc: ?EmitLoc,
    llvm_object: LlvmObject.Ptr,
    prog_node: std.Progress.Node,
) !void {
    const sub_prog_node = prog_node.start("LLVM Emit Object", 0);
    defer sub_prog_node.end();

    try llvm_object.emit(.{
        .pre_ir_path = comp.verbose_llvm_ir,
        .pre_bc_path = comp.verbose_llvm_bc,
        .bin_path = try resolveEmitLoc(arena, default_artifact_directory, bin_emit_loc),
        .asm_path = try resolveEmitLoc(arena, default_artifact_directory, comp.emit_asm),
        .post_ir_path = try resolveEmitLoc(arena, default_artifact_directory, comp.emit_llvm_ir),
        .post_bc_path = try resolveEmitLoc(arena, default_artifact_directory, comp.emit_llvm_bc),

        .is_debug = comp.root_mod.optimize_mode == .Debug,
        .is_small = comp.root_mod.optimize_mode == .ReleaseSmall,
        .time_report = comp.time_report,
        .sanitize_thread = comp.config.any_sanitize_thread,
        .fuzz = comp.config.any_fuzz,
        .lto = comp.config.lto,
    });
}

fn resolveEmitLoc(
    arena: Allocator,
    default_artifact_directory: Path,
    opt_loc: ?EmitLoc,
) Allocator.Error!?[*:0]const u8 {
    const loc = opt_loc orelse return null;
    const slice = if (loc.directory) |directory|
        try directory.joinZ(arena, &.{loc.basename})
    else
        try default_artifact_directory.joinStringZ(arena, loc.basename);
    return slice.ptr;
}

fn reportMultiModuleErrors(pt: Zcu.PerThread) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    // Some cases can give you a whole bunch of multi-module errors, which it's not helpful to
    // print all of, so we'll cap the number of these to emit.
    var num_errors: u32 = 0;
    const max_errors = 5;
    // Attach the "some omitted" note to the final error message
    var last_err: ?*Zcu.ErrorMsg = null;

    for (zcu.import_table.values()) |file_index| {
        const file = zcu.fileByIndex(file_index);
        if (!file.multi_pkg) continue;

        num_errors += 1;
        if (num_errors > max_errors) continue;

        const err = err_blk: {
            // Like with errors, let's cap the number of notes to prevent a huge error spew.
            const max_notes = 5;
            const omitted = file.references.items.len -| max_notes;
            const num_notes = file.references.items.len - omitted;

            const notes = try gpa.alloc(Zcu.ErrorMsg, if (omitted > 0) num_notes + 1 else num_notes);
            errdefer gpa.free(notes);

            for (notes[0..num_notes], file.references.items[0..num_notes], 0..) |*note, ref, i| {
                errdefer for (notes[0..i]) |*n| n.deinit(gpa);
                note.* = switch (ref) {
                    .import => |import| try Zcu.ErrorMsg.init(
                        gpa,
                        .{
                            .base_node_inst = try ip.trackZir(gpa, pt.tid, .{
                                .file = import.file,
                                .inst = .main_struct_inst,
                            }),
                            .offset = .{ .token_abs = import.token },
                        },
                        "imported from module {s}",
                        .{zcu.fileByIndex(import.file).mod.fully_qualified_name},
                    ),
                    .root => |pkg| try Zcu.ErrorMsg.init(
                        gpa,
                        .{
                            .base_node_inst = try ip.trackZir(gpa, pt.tid, .{
                                .file = file_index,
                                .inst = .main_struct_inst,
                            }),
                            .offset = .entire_file,
                        },
                        "root of module {s}",
                        .{pkg.fully_qualified_name},
                    ),
                };
            }
            errdefer for (notes[0..num_notes]) |*n| n.deinit(gpa);

            if (omitted > 0) {
                notes[num_notes] = try Zcu.ErrorMsg.init(
                    gpa,
                    .{
                        .base_node_inst = try ip.trackZir(gpa, pt.tid, .{
                            .file = file_index,
                            .inst = .main_struct_inst,
                        }),
                        .offset = .entire_file,
                    },
                    "{} more references omitted",
                    .{omitted},
                );
            }
            errdefer if (omitted > 0) notes[num_notes].deinit(gpa);

            const err = try Zcu.ErrorMsg.create(
                gpa,
                .{
                    .base_node_inst = try ip.trackZir(gpa, pt.tid, .{
                        .file = file_index,
                        .inst = .main_struct_inst,
                    }),
                    .offset = .entire_file,
                },
                "file exists in multiple modules",
                .{},
            );
            err.notes = notes;
            break :err_blk err;
        };
        errdefer err.destroy(gpa);
        try zcu.failed_files.putNoClobber(gpa, file, err);
        last_err = err;
    }

    // If we omitted any errors, add a note saying that
    if (num_errors > max_errors) {
        const err = last_err.?;

        // There isn't really any meaningful place to put this note, so just attach it to the
        // last failed file
        var note = try Zcu.ErrorMsg.init(
            gpa,
            err.src_loc,
            "{} more errors omitted",
            .{num_errors - max_errors},
        );
        errdefer note.deinit(gpa);

        const i = err.notes.len;
        err.notes = try gpa.realloc(err.notes, i + 1);
        err.notes[i] = note;
    }

    // Now that we've reported the errors, we need to deal with
    // dependencies. Any file referenced by a multi_pkg file should also be
    // marked multi_pkg and have its status set to astgen_failure, as it's
    // ambiguous which package they should be analyzed as a part of. We need
    // to add this flag after reporting the errors however, as otherwise
    // we'd get an error for every single downstream file, which wouldn't be
    // very useful.
    for (zcu.import_table.values()) |file_index| {
        const file = zcu.fileByIndex(file_index);
        if (file.multi_pkg) file.recursiveMarkMultiPkg(pt);
    }
}

/// Having the file open for writing is problematic as far as executing the
/// binary is concerned. This will remove the write flag, or close the file,
/// or whatever is needed so that it can be executed.
/// After this, one must call` makeFileWritable` before calling `update`.
pub fn makeBinFileExecutable(comp: *Compilation) !void {
    if (!dev.env.supports(.make_executable)) return;
    const lf = comp.bin_file orelse return;
    return lf.makeExecutable();
}

pub fn makeBinFileWritable(comp: *Compilation) !void {
    const lf = comp.bin_file orelse return;
    return lf.makeWritable();
}

const Header = extern struct {
    intern_pool: extern struct {
        thread_count: u32,
        src_hash_deps_len: u32,
        nav_val_deps_len: u32,
        nav_ty_deps_len: u32,
        interned_deps_len: u32,
        zon_file_deps_len: u32,
        embed_file_deps_len: u32,
        namespace_deps_len: u32,
        namespace_name_deps_len: u32,
        first_dependency_len: u32,
        dep_entries_len: u32,
        free_dep_entries_len: u32,
    },

    const PerThread = extern struct {
        intern_pool: extern struct {
            items_len: u32,
            extra_len: u32,
            limbs_len: u32,
            string_bytes_len: u32,
            tracked_insts_len: u32,
            files_len: u32,
        },
    };
};

/// Note that all state that is included in the cache hash namespace is *not*
/// saved, such as the target and most CLI flags. A cache hit will only occur
/// when subsequent compiler invocations use the same set of flags.
pub fn saveState(comp: *Compilation) !void {
    dev.check(.incremental);

    const lf = comp.bin_file orelse return;

    const gpa = comp.gpa;

    var bufs = std.ArrayList(std.posix.iovec_const).init(gpa);
    defer bufs.deinit();

    var pt_headers = std.ArrayList(Header.PerThread).init(gpa);
    defer pt_headers.deinit();

    if (comp.zcu) |zcu| {
        const ip = &zcu.intern_pool;
        const header: Header = .{
            .intern_pool = .{
                .thread_count = @intCast(ip.locals.len),
                .src_hash_deps_len = @intCast(ip.src_hash_deps.count()),
                .nav_val_deps_len = @intCast(ip.nav_val_deps.count()),
                .nav_ty_deps_len = @intCast(ip.nav_ty_deps.count()),
                .interned_deps_len = @intCast(ip.interned_deps.count()),
                .zon_file_deps_len = @intCast(ip.zon_file_deps.count()),
                .embed_file_deps_len = @intCast(ip.embed_file_deps.count()),
                .namespace_deps_len = @intCast(ip.namespace_deps.count()),
                .namespace_name_deps_len = @intCast(ip.namespace_name_deps.count()),
                .first_dependency_len = @intCast(ip.first_dependency.count()),
                .dep_entries_len = @intCast(ip.dep_entries.items.len),
                .free_dep_entries_len = @intCast(ip.free_dep_entries.items.len),
            },
        };

        try pt_headers.ensureTotalCapacityPrecise(header.intern_pool.thread_count);
        for (ip.locals) |*local| pt_headers.appendAssumeCapacity(.{
            .intern_pool = .{
                .items_len = @intCast(local.mutate.items.len),
                .extra_len = @intCast(local.mutate.extra.len),
                .limbs_len = @intCast(local.mutate.limbs.len),
                .string_bytes_len = @intCast(local.mutate.strings.len),
                .tracked_insts_len = @intCast(local.mutate.tracked_insts.len),
                .files_len = @intCast(local.mutate.files.len),
            },
        });

        try bufs.ensureTotalCapacityPrecise(14 + 8 * pt_headers.items.len);
        addBuf(&bufs, mem.asBytes(&header));
        addBuf(&bufs, mem.sliceAsBytes(pt_headers.items));

        addBuf(&bufs, mem.sliceAsBytes(ip.src_hash_deps.keys()));
        addBuf(&bufs, mem.sliceAsBytes(ip.src_hash_deps.values()));
        addBuf(&bufs, mem.sliceAsBytes(ip.nav_val_deps.keys()));
        addBuf(&bufs, mem.sliceAsBytes(ip.nav_val_deps.values()));
        addBuf(&bufs, mem.sliceAsBytes(ip.nav_ty_deps.keys()));
        addBuf(&bufs, mem.sliceAsBytes(ip.nav_ty_deps.values()));
        addBuf(&bufs, mem.sliceAsBytes(ip.interned_deps.keys()));
        addBuf(&bufs, mem.sliceAsBytes(ip.interned_deps.values()));
        addBuf(&bufs, mem.sliceAsBytes(ip.zon_file_deps.keys()));
        addBuf(&bufs, mem.sliceAsBytes(ip.zon_file_deps.values()));
        addBuf(&bufs, mem.sliceAsBytes(ip.embed_file_deps.keys()));
        addBuf(&bufs, mem.sliceAsBytes(ip.embed_file_deps.values()));
        addBuf(&bufs, mem.sliceAsBytes(ip.namespace_deps.keys()));
        addBuf(&bufs, mem.sliceAsBytes(ip.namespace_deps.values()));
        addBuf(&bufs, mem.sliceAsBytes(ip.namespace_name_deps.keys()));
        addBuf(&bufs, mem.sliceAsBytes(ip.namespace_name_deps.values()));

        addBuf(&bufs, mem.sliceAsBytes(ip.first_dependency.keys()));
        addBuf(&bufs, mem.sliceAsBytes(ip.first_dependency.values()));
        addBuf(&bufs, mem.sliceAsBytes(ip.dep_entries.items));
        addBuf(&bufs, mem.sliceAsBytes(ip.free_dep_entries.items));

        for (ip.locals, pt_headers.items) |*local, pt_header| {
            if (pt_header.intern_pool.limbs_len > 0) {
                addBuf(&bufs, mem.sliceAsBytes(local.shared.limbs.view().items(.@"0")[0..pt_header.intern_pool.limbs_len]));
            }
            if (pt_header.intern_pool.extra_len > 0) {
                addBuf(&bufs, mem.sliceAsBytes(local.shared.extra.view().items(.@"0")[0..pt_header.intern_pool.extra_len]));
            }
            if (pt_header.intern_pool.items_len > 0) {
                addBuf(&bufs, mem.sliceAsBytes(local.shared.items.view().items(.data)[0..pt_header.intern_pool.items_len]));
                addBuf(&bufs, mem.sliceAsBytes(local.shared.items.view().items(.tag)[0..pt_header.intern_pool.items_len]));
            }
            if (pt_header.intern_pool.string_bytes_len > 0) {
                addBuf(&bufs, local.shared.strings.view().items(.@"0")[0..pt_header.intern_pool.string_bytes_len]);
            }
            if (pt_header.intern_pool.tracked_insts_len > 0) {
                addBuf(&bufs, mem.sliceAsBytes(local.shared.tracked_insts.view().items(.@"0")[0..pt_header.intern_pool.tracked_insts_len]));
            }
            if (pt_header.intern_pool.files_len > 0) {
                addBuf(&bufs, mem.sliceAsBytes(local.shared.files.view().items(.bin_digest)[0..pt_header.intern_pool.files_len]));
                addBuf(&bufs, mem.sliceAsBytes(local.shared.files.view().items(.root_type)[0..pt_header.intern_pool.files_len]));
            }
        }

        //// TODO: compilation errors
        //// TODO: namespaces
        //// TODO: decls
    }

    // linker state
    switch (lf.tag) {
        .wasm => {
            dev.check(link.File.Tag.wasm.devFeature());
            const wasm = lf.cast(.wasm).?;
            const is_obj = comp.config.output_mode == .Obj;
            try bufs.ensureUnusedCapacity(85);
            addBuf(&bufs, wasm.string_bytes.items);
            // TODO make it well-defined memory layout
            //addBuf(&bufs, mem.sliceAsBytes(wasm.objects.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.func_types.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_function_imports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_function_imports.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_functions.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_global_imports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_global_imports.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_globals.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_table_imports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_table_imports.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_tables.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_memory_imports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_memory_imports.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_memories.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_relocations.items(.tag)));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_relocations.items(.offset)));
            // TODO handle the union safety field
            //addBuf(&bufs, mem.sliceAsBytes(wasm.object_relocations.items(.pointee)));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_relocations.items(.addend)));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_init_funcs.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_data_segments.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_datas.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_data_imports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_data_imports.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_custom_segments.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_custom_segments.values()));
            // TODO make it well-defined memory layout
            // addBuf(&bufs, mem.sliceAsBytes(wasm.object_comdats.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_relocations_table.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_relocations_table.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_comdat_symbols.items(.kind)));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_comdat_symbols.items(.index)));
            addBuf(&bufs, mem.sliceAsBytes(wasm.out_relocs.items(.tag)));
            addBuf(&bufs, mem.sliceAsBytes(wasm.out_relocs.items(.offset)));
            // TODO handle the union safety field
            //addBuf(&bufs, mem.sliceAsBytes(wasm.out_relocs.items(.pointee)));
            addBuf(&bufs, mem.sliceAsBytes(wasm.out_relocs.items(.addend)));
            addBuf(&bufs, mem.sliceAsBytes(wasm.uav_fixups.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.nav_fixups.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.func_table_fixups.items));
            if (is_obj) {
                addBuf(&bufs, mem.sliceAsBytes(wasm.navs_obj.keys()));
                addBuf(&bufs, mem.sliceAsBytes(wasm.navs_obj.values()));
                addBuf(&bufs, mem.sliceAsBytes(wasm.uavs_obj.keys()));
                addBuf(&bufs, mem.sliceAsBytes(wasm.uavs_obj.values()));
            } else {
                addBuf(&bufs, mem.sliceAsBytes(wasm.navs_exe.keys()));
                addBuf(&bufs, mem.sliceAsBytes(wasm.navs_exe.values()));
                addBuf(&bufs, mem.sliceAsBytes(wasm.uavs_exe.keys()));
                addBuf(&bufs, mem.sliceAsBytes(wasm.uavs_exe.values()));
            }
            addBuf(&bufs, mem.sliceAsBytes(wasm.overaligned_uavs.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.overaligned_uavs.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.zcu_funcs.keys()));
            // TODO handle the union safety field
            // addBuf(&bufs, mem.sliceAsBytes(wasm.zcu_funcs.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.nav_exports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.nav_exports.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.uav_exports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.uav_exports.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.imports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.missing_exports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.function_exports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.function_exports.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.hidden_function_exports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.hidden_function_exports.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.global_exports.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.functions.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.function_imports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.function_imports.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.data_imports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.data_imports.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.data_segments.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.globals.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.global_imports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.global_imports.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.tables.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.table_imports.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.table_imports.values()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.zcu_indirect_function_set.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_indirect_function_import_set.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.object_indirect_function_set.keys()));
            addBuf(&bufs, mem.sliceAsBytes(wasm.mir_instructions.items(.tag)));
            // TODO handle the union safety field
            //addBuf(&bufs, mem.sliceAsBytes(wasm.mir_instructions.items(.data)));
            addBuf(&bufs, mem.sliceAsBytes(wasm.mir_extra.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.all_zcu_locals.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.tag_name_bytes.items));
            addBuf(&bufs, mem.sliceAsBytes(wasm.tag_name_offs.items));

            // TODO add as header fields
            // entry_resolution: FunctionImport.Resolution
            // function_exports_len: u32
            // global_exports_len: u32
            // functions_end_prelink: u32
            // globals_end_prelink: u32
            // error_name_table_ref_count: u32
            // tag_name_table_ref_count: u32
            // any_tls_relocs: bool
            // any_passive_inits: bool
        },
        else => log.err("TODO implement saving linker state for {s}", .{@tagName(lf.tag)}),
    }

    var basename_buf: [255]u8 = undefined;
    const basename = std.fmt.bufPrint(&basename_buf, "{s}.zcs", .{
        comp.root_name,
    }) catch o: {
        basename_buf[basename_buf.len - 4 ..].* = ".zcs".*;
        break :o &basename_buf;
    };

    // Using an atomic file prevents a crash or power failure from corrupting
    // the previous incremental compilation state.
    var af = try lf.emit.root_dir.handle.atomicFile(basename, .{});
    defer af.deinit();
    try af.file.pwritevAll(bufs.items, 0);
    try af.finish();
}

fn addBuf(list: *std.ArrayList(std.posix.iovec_const), buf: []const u8) void {
    // Even when len=0, the undefined pointer might cause EFAULT.
    if (buf.len == 0) return;
    list.appendAssumeCapacity(.{ .base = buf.ptr, .len = buf.len });
}

/// This function is temporally single-threaded.
pub fn getAllErrorsAlloc(comp: *Compilation) !ErrorBundle {
    const gpa = comp.gpa;

    var bundle: ErrorBundle.Wip = undefined;
    try bundle.init(gpa);
    defer bundle.deinit();

    for (comp.failed_c_objects.values()) |diag_bundle| {
        try diag_bundle.addToErrorBundle(&bundle);
    }

    for (comp.failed_win32_resources.values()) |error_bundle| {
        try bundle.addBundleAsRoots(error_bundle);
    }

    for (comp.link_diags.lld.items) |lld_error| {
        const notes_len = @as(u32, @intCast(lld_error.context_lines.len));

        try bundle.addRootErrorMessage(.{
            .msg = try bundle.addString(lld_error.msg),
            .notes_len = notes_len,
        });
        const notes_start = try bundle.reserveNotes(notes_len);
        for (notes_start.., lld_error.context_lines) |note, context_line| {
            bundle.extra.items[note] = @intFromEnum(bundle.addErrorMessageAssumeCapacity(.{
                .msg = try bundle.addString(context_line),
            }));
        }
    }
    for (comp.misc_failures.values()) |*value| {
        try bundle.addRootErrorMessage(.{
            .msg = try bundle.addString(value.msg),
            .notes_len = if (value.children) |b| b.errorMessageCount() else 0,
        });
        if (value.children) |b| try bundle.addBundleAsNotes(b);
    }
    if (comp.alloc_failure_occurred or comp.link_diags.flags.alloc_failure_occurred) {
        try bundle.addRootErrorMessage(.{
            .msg = try bundle.addString("memory allocation failure"),
        });
    }

    if (comp.zcu) |zcu| zcu_errors: {
        for (zcu.failed_files.keys(), zcu.failed_files.values()) |file, error_msg| {
            if (error_msg) |msg| {
                try addModuleErrorMsg(zcu, &bundle, msg.*);
            } else {
                // Must be ZIR or Zoir errors. Note that this may include AST errors.
                _ = try file.getTree(gpa); // Tree must be loaded.
                if (file.zir != null) {
                    try addZirErrorMessages(&bundle, file);
                } else if (file.zoir != null) {
                    try addZoirErrorMessages(&bundle, file);
                } else {
                    // Either Zir or Zoir must have been loaded.
                    unreachable;
                }
            }
        }
        if (zcu.skip_analysis_errors) break :zcu_errors;
        var sorted_failed_analysis: std.AutoArrayHashMapUnmanaged(InternPool.AnalUnit, *Zcu.ErrorMsg).DataList.Slice = s: {
            const SortOrder = struct {
                zcu: *Zcu,
                errors: []const *Zcu.ErrorMsg,
                err: *?Error,

                const Error = @typeInfo(
                    @typeInfo(@TypeOf(Zcu.SrcLoc.span)).@"fn".return_type.?,
                ).error_union.error_set;

                pub fn lessThan(ctx: @This(), lhs_index: usize, rhs_index: usize) bool {
                    if (ctx.err.*) |_| return lhs_index < rhs_index;
                    const lhs_src_loc = ctx.errors[lhs_index].src_loc.upgradeOrLost(ctx.zcu) orelse {
                        // LHS source location lost, so should never be referenced. Just sort it to the end.
                        return false;
                    };
                    const rhs_src_loc = ctx.errors[rhs_index].src_loc.upgradeOrLost(ctx.zcu) orelse {
                        // RHS source location lost, so should never be referenced. Just sort it to the end.
                        return true;
                    };
                    return if (lhs_src_loc.file_scope != rhs_src_loc.file_scope) std.mem.order(
                        u8,
                        lhs_src_loc.file_scope.sub_file_path,
                        rhs_src_loc.file_scope.sub_file_path,
                    ).compare(.lt) else (lhs_src_loc.span(ctx.zcu.gpa) catch |e| {
                        ctx.err.* = e;
                        return lhs_index < rhs_index;
                    }).main < (rhs_src_loc.span(ctx.zcu.gpa) catch |e| {
                        ctx.err.* = e;
                        return lhs_index < rhs_index;
                    }).main;
                }
            };

            // We can't directly sort `zcu.failed_analysis.entries`, because that would leave the map
            // in an invalid state, and we need it intact for future incremental updates. The amount
            // of data here is only as large as the number of analysis errors, so just dupe it all.
            var entries = try zcu.failed_analysis.entries.clone(gpa);
            errdefer entries.deinit(gpa);

            var err: ?SortOrder.Error = null;
            entries.sort(SortOrder{
                .zcu = zcu,
                .errors = entries.items(.value),
                .err = &err,
            });
            if (err) |e| return e;
            break :s entries.slice();
        };
        defer sorted_failed_analysis.deinit(gpa);
        for (sorted_failed_analysis.items(.key), sorted_failed_analysis.items(.value)) |anal_unit, error_msg| {
            if (comp.incremental) {
                const refs = try zcu.resolveReferences();
                if (!refs.contains(anal_unit)) continue;
            }

            std.log.scoped(.zcu).debug("analysis error '{s}' reported from unit '{}'", .{
                error_msg.msg,
                zcu.fmtAnalUnit(anal_unit),
            });

            try addModuleErrorMsg(zcu, &bundle, error_msg.*);
            if (zcu.cimport_errors.get(anal_unit)) |errors| {
                for (errors.getMessages()) |err_msg_index| {
                    const err_msg = errors.getErrorMessage(err_msg_index);
                    try bundle.addRootErrorMessage(.{
                        .msg = try bundle.addString(errors.nullTerminatedString(err_msg.msg)),
                        .src_loc = if (err_msg.src_loc != .none) blk: {
                            const src_loc = errors.getSourceLocation(err_msg.src_loc);
                            break :blk try bundle.addSourceLocation(.{
                                .src_path = try bundle.addString(errors.nullTerminatedString(src_loc.src_path)),
                                .span_start = src_loc.span_start,
                                .span_main = src_loc.span_main,
                                .span_end = src_loc.span_end,
                                .line = src_loc.line,
                                .column = src_loc.column,
                                .source_line = if (src_loc.source_line != 0) try bundle.addString(errors.nullTerminatedString(src_loc.source_line)) else 0,
                            });
                        } else .none,
                    });
                }
            }
        }
        for (zcu.failed_codegen.values()) |error_msg| {
            try addModuleErrorMsg(zcu, &bundle, error_msg.*);
        }
        for (zcu.failed_types.values()) |error_msg| {
            try addModuleErrorMsg(zcu, &bundle, error_msg.*);
        }
        for (zcu.failed_exports.values()) |value| {
            try addModuleErrorMsg(zcu, &bundle, value.*);
        }

        const actual_error_count = zcu.intern_pool.global_error_set.getNamesFromMainThread().len;
        if (actual_error_count > zcu.error_limit) {
            try bundle.addRootErrorMessage(.{
                .msg = try bundle.printString("ZCU used more errors than possible: used {d}, max {d}", .{
                    actual_error_count, zcu.error_limit,
                }),
                .notes_len = 1,
            });
            const notes_start = try bundle.reserveNotes(1);
            bundle.extra.items[notes_start] = @intFromEnum(try bundle.addErrorMessage(.{
                .msg = try bundle.printString("use '--error-limit {d}' to increase limit", .{
                    actual_error_count,
                }),
            }));
        }
    }

    if (bundle.root_list.items.len == 0) {
        if (comp.link_diags.flags.no_entry_point_found) {
            try bundle.addRootErrorMessage(.{
                .msg = try bundle.addString("no entry point found"),
            });
        }
    }

    if (comp.link_diags.flags.missing_libc) {
        try bundle.addRootErrorMessage(.{
            .msg = try bundle.addString("libc not available"),
            .notes_len = 2,
        });
        const notes_start = try bundle.reserveNotes(2);
        bundle.extra.items[notes_start + 0] = @intFromEnum(try bundle.addErrorMessage(.{
            .msg = try bundle.addString("run 'zig libc -h' to learn about libc installations"),
        }));
        bundle.extra.items[notes_start + 1] = @intFromEnum(try bundle.addErrorMessage(.{
            .msg = try bundle.addString("run 'zig targets' to see the targets for which zig can always provide libc"),
        }));
    }

    try comp.link_diags.addMessagesToBundle(&bundle, comp.bin_file);

    if (comp.zcu) |zcu| {
        if (!zcu.skip_analysis_errors and bundle.root_list.items.len == 0 and zcu.compile_log_sources.count() != 0) {
            const values = zcu.compile_log_sources.values();
            // First one will be the error; subsequent ones will be notes.
            const src_loc = values[0].src();
            const err_msg: Zcu.ErrorMsg = .{
                .src_loc = src_loc,
                .msg = "found compile log statement",
                .notes = try gpa.alloc(Zcu.ErrorMsg, zcu.compile_log_sources.count() - 1),
            };
            defer gpa.free(err_msg.notes);

            for (values[1..], err_msg.notes) |src_info, *note| {
                note.* = .{
                    .src_loc = src_info.src(),
                    .msg = "also here",
                };
            }

            try addModuleErrorMsg(zcu, &bundle, err_msg);
        }
    }

    // TODO: eventually, this should be behind `std.debug.runtime_safety`. But right now, this is a
    // very common way for incremental compilation bugs to manifest, so let's always check it.
    if (comp.zcu) |zcu| if (comp.incremental and bundle.root_list.items.len == 0) {
        for (zcu.transitive_failed_analysis.keys()) |failed_unit| {
            const refs = try zcu.resolveReferences();
            var ref = refs.get(failed_unit) orelse continue;
            // This AU is referenced and has a transitive compile error, meaning it referenced something with a compile error.
            // However, we haven't reported any such error.
            // This is a compiler bug.
            const stderr = std.io.getStdErr().writer();
            try stderr.writeAll("referenced transitive analysis errors, but none actually emitted\n");
            try stderr.print("{} [transitive failure]\n", .{zcu.fmtAnalUnit(failed_unit)});
            while (ref) |r| {
                try stderr.print("referenced by: {}{s}\n", .{
                    zcu.fmtAnalUnit(r.referencer),
                    if (zcu.transitive_failed_analysis.contains(r.referencer)) " [transitive failure]" else "",
                });
                ref = refs.get(r.referencer).?;
            }

            @panic("referenced transitive analysis errors, but none actually emitted");
        }
    };

    const compile_log_text = if (comp.zcu) |m| m.compile_log_text.items else "";
    return bundle.toOwnedBundle(compile_log_text);
}

fn anyErrors(comp: *Compilation) bool {
    return (totalErrorCount(comp) catch return true) != 0;
}

fn totalErrorCount(comp: *Compilation) !u32 {
    var errors = try comp.getAllErrorsAlloc();
    defer errors.deinit(comp.gpa);
    return errors.errorMessageCount();
}

pub const ErrorNoteHashContext = struct {
    eb: *const ErrorBundle.Wip,

    pub fn hash(ctx: ErrorNoteHashContext, key: ErrorBundle.ErrorMessage) u32 {
        var hasher = std.hash.Wyhash.init(0);
        const eb = ctx.eb.tmpBundle();

        hasher.update(eb.nullTerminatedString(key.msg));
        if (key.src_loc != .none) {
            const src = eb.getSourceLocation(key.src_loc);
            hasher.update(eb.nullTerminatedString(src.src_path));
            std.hash.autoHash(&hasher, src.line);
            std.hash.autoHash(&hasher, src.column);
            std.hash.autoHash(&hasher, src.span_main);
        }

        return @as(u32, @truncate(hasher.final()));
    }

    pub fn eql(
        ctx: ErrorNoteHashContext,
        a: ErrorBundle.ErrorMessage,
        b: ErrorBundle.ErrorMessage,
        b_index: usize,
    ) bool {
        _ = b_index;
        const eb = ctx.eb.tmpBundle();
        const msg_a = eb.nullTerminatedString(a.msg);
        const msg_b = eb.nullTerminatedString(b.msg);
        if (!mem.eql(u8, msg_a, msg_b)) return false;

        if (a.src_loc == .none and b.src_loc == .none) return true;
        if (a.src_loc == .none or b.src_loc == .none) return false;
        const src_a = eb.getSourceLocation(a.src_loc);
        const src_b = eb.getSourceLocation(b.src_loc);

        const src_path_a = eb.nullTerminatedString(src_a.src_path);
        const src_path_b = eb.nullTerminatedString(src_b.src_path);

        return mem.eql(u8, src_path_a, src_path_b) and
            src_a.line == src_b.line and
            src_a.column == src_b.column and
            src_a.span_main == src_b.span_main;
    }
};

pub fn addModuleErrorMsg(
    zcu: *Zcu,
    eb: *ErrorBundle.Wip,
    module_err_msg: Zcu.ErrorMsg,
) !void {
    const gpa = eb.gpa;
    const ip = &zcu.intern_pool;
    const err_src_loc = module_err_msg.src_loc.upgrade(zcu);
    const err_source = err_src_loc.file_scope.getSource(gpa) catch |err| {
        const file_path = try err_src_loc.file_scope.fullPath(gpa);
        defer gpa.free(file_path);
        try eb.addRootErrorMessage(.{
            .msg = try eb.printString("unable to load '{s}': {s}", .{
                file_path, @errorName(err),
            }),
        });
        return;
    };
    const err_span = try err_src_loc.span(gpa);
    const err_loc = std.zig.findLineColumn(err_source.bytes, err_span.main);
    const file_path = try err_src_loc.file_scope.fullPath(gpa);
    defer gpa.free(file_path);

    var ref_traces: std.ArrayListUnmanaged(ErrorBundle.ReferenceTrace) = .empty;
    defer ref_traces.deinit(gpa);

    if (module_err_msg.reference_trace_root.unwrap()) |rt_root| {
        const all_references = try zcu.resolveReferences();

        var seen: std.AutoHashMapUnmanaged(InternPool.AnalUnit, void) = .empty;
        defer seen.deinit(gpa);

        const max_references = zcu.comp.reference_trace orelse Sema.default_reference_trace_len;

        var referenced_by = rt_root;
        while (all_references.get(referenced_by)) |maybe_ref| {
            const ref = maybe_ref orelse break;
            const gop = try seen.getOrPut(gpa, ref.referencer);
            if (gop.found_existing) break;
            if (ref_traces.items.len < max_references) skip: {
                const src = ref.src.upgrade(zcu);
                const source = try src.file_scope.getSource(gpa);
                const span = try src.span(gpa);
                const loc = std.zig.findLineColumn(source.bytes, span.main);
                const rt_file_path = try src.file_scope.fullPath(gpa);
                defer gpa.free(rt_file_path);
                const name = switch (ref.referencer.unwrap()) {
                    .@"comptime" => "comptime",
                    .nav_val, .nav_ty => |nav| ip.getNav(nav).name.toSlice(ip),
                    .type => |ty| Type.fromInterned(ty).containerTypeName(ip).toSlice(ip),
                    .func => |f| ip.getNav(zcu.funcInfo(f).owner_nav).name.toSlice(ip),
                    .memoized_state => break :skip,
                };
                try ref_traces.append(gpa, .{
                    .decl_name = try eb.addString(name),
                    .src_loc = try eb.addSourceLocation(.{
                        .src_path = try eb.addString(rt_file_path),
                        .span_start = span.start,
                        .span_main = span.main,
                        .span_end = span.end,
                        .line = @intCast(loc.line),
                        .column = @intCast(loc.column),
                        .source_line = 0,
                    }),
                });
            }
            referenced_by = ref.referencer;
        }

        if (seen.count() > ref_traces.items.len) {
            try ref_traces.append(gpa, .{
                .decl_name = @intCast(seen.count() - ref_traces.items.len),
                .src_loc = .none,
            });
        }
    }

    const src_loc = try eb.addSourceLocation(.{
        .src_path = try eb.addString(file_path),
        .span_start = err_span.start,
        .span_main = err_span.main,
        .span_end = err_span.end,
        .line = @intCast(err_loc.line),
        .column = @intCast(err_loc.column),
        .source_line = if (err_src_loc.lazy == .entire_file)
            0
        else
            try eb.addString(err_loc.source_line),
        .reference_trace_len = @intCast(ref_traces.items.len),
    });

    for (ref_traces.items) |rt| {
        try eb.addReferenceTrace(rt);
    }

    // De-duplicate error notes. The main use case in mind for this is
    // too many "note: called from here" notes when eval branch quota is reached.
    var notes: std.ArrayHashMapUnmanaged(ErrorBundle.ErrorMessage, void, ErrorNoteHashContext, true) = .empty;
    defer notes.deinit(gpa);

    var last_note_loc: ?std.zig.Loc = null;
    for (module_err_msg.notes) |module_note| {
        const note_src_loc = module_note.src_loc.upgrade(zcu);
        const source = try note_src_loc.file_scope.getSource(gpa);
        const span = try note_src_loc.span(gpa);
        const loc = std.zig.findLineColumn(source.bytes, span.main);
        const note_file_path = try note_src_loc.file_scope.fullPath(gpa);
        defer gpa.free(note_file_path);

        const omit_source_line = loc.eql(err_loc) or (last_note_loc != null and loc.eql(last_note_loc.?));
        last_note_loc = loc;

        const gop = try notes.getOrPutContext(gpa, .{
            .msg = try eb.addString(module_note.msg),
            .src_loc = try eb.addSourceLocation(.{
                .src_path = try eb.addString(note_file_path),
                .span_start = span.start,
                .span_main = span.main,
                .span_end = span.end,
                .line = @intCast(loc.line),
                .column = @intCast(loc.column),
                .source_line = if (omit_source_line) 0 else try eb.addString(loc.source_line),
            }),
        }, .{ .eb = eb });
        if (gop.found_existing) {
            gop.key_ptr.count += 1;
        }
    }

    const notes_len: u32 = @intCast(notes.entries.len);

    try eb.addRootErrorMessage(.{
        .msg = try eb.addString(module_err_msg.msg),
        .src_loc = src_loc,
        .notes_len = notes_len,
    });

    const notes_start = try eb.reserveNotes(notes_len);

    for (notes_start.., notes.keys()) |i, note| {
        eb.extra.items[i] = @intFromEnum(try eb.addErrorMessage(note));
    }
}

pub fn addZirErrorMessages(eb: *ErrorBundle.Wip, file: *Zcu.File) !void {
    const gpa = eb.gpa;
    const src_path = try file.fullPath(gpa);
    defer gpa.free(src_path);
    return eb.addZirErrorMessages(file.zir.?, file.tree.?, file.source.?, src_path);
}

pub fn addZoirErrorMessages(eb: *ErrorBundle.Wip, file: *Zcu.File) !void {
    const gpa = eb.gpa;
    const src_path = try file.fullPath(gpa);
    defer gpa.free(src_path);
    return eb.addZoirErrorMessages(file.zoir.?, file.tree.?, file.source.?, src_path);
}

pub fn performAllTheWork(
    comp: *Compilation,
    main_progress_node: std.Progress.Node,
) JobError!void {
    comp.work_queue_progress_node = main_progress_node;
    defer comp.work_queue_progress_node = .none;

    defer if (comp.zcu) |zcu| {
        zcu.sema_prog_node.end();
        zcu.sema_prog_node = .none;
        zcu.codegen_prog_node.end();
        zcu.codegen_prog_node = .none;

        zcu.generation += 1;
    };
    try comp.performAllTheWorkInner(main_progress_node);
}

fn performAllTheWorkInner(
    comp: *Compilation,
    main_progress_node: std.Progress.Node,
) JobError!void {
    // Here we queue up all the AstGen tasks first, followed by C object compilation.
    // We wait until the AstGen tasks are all completed before proceeding to the
    // (at least for now) single-threaded main work queue. However, C object compilation
    // only needs to be finished by the end of this function.

    var work_queue_wait_group: WaitGroup = .{};
    defer work_queue_wait_group.wait();

    comp.link_task_wait_group.reset();
    defer comp.link_task_wait_group.wait();

    if (comp.link_task_queue.start()) {
        comp.thread_pool.spawnWgId(&comp.link_task_wait_group, link.flushTaskQueue, .{comp});
    }

    if (comp.docs_emit != null) {
        dev.check(.docs_emit);
        comp.thread_pool.spawnWg(&work_queue_wait_group, workerDocsCopy, .{comp});
        work_queue_wait_group.spawnManager(workerDocsWasm, .{ comp, main_progress_node });
    }

    // In case it failed last time, try again. `clearMiscFailures` was already
    // called at the start of `update`.
    if (comp.queued_jobs.compiler_rt_lib and comp.compiler_rt_lib == null) {
        // LLVM disables LTO for its compiler-rt and we've had various issues with LTO of our
        // compiler-rt due to LLD bugs as well, e.g.:
        //
        // https://github.com/llvm/llvm-project/issues/43698#issuecomment-2542660611
        comp.link_task_wait_group.spawnManager(buildRt, .{ comp, "compiler_rt.zig", .compiler_rt, .Lib, false, &comp.compiler_rt_lib, main_progress_node });
    }

    if (comp.queued_jobs.compiler_rt_obj and comp.compiler_rt_obj == null) {
        comp.link_task_wait_group.spawnManager(buildRt, .{ comp, "compiler_rt.zig", .compiler_rt, .Obj, false, &comp.compiler_rt_obj, main_progress_node });
    }

    if (comp.queued_jobs.fuzzer_lib and comp.fuzzer_lib == null) {
        comp.link_task_wait_group.spawnManager(buildRt, .{ comp, "fuzzer.zig", .libfuzzer, .Lib, true, &comp.fuzzer_lib, main_progress_node });
    }

    if (comp.queued_jobs.glibc_shared_objects) {
        comp.link_task_wait_group.spawnManager(buildGlibcSharedObjects, .{ comp, main_progress_node });
    }

    if (comp.queued_jobs.libunwind) {
        comp.link_task_wait_group.spawnManager(buildLibUnwind, .{ comp, main_progress_node });
    }

    if (comp.queued_jobs.libcxx) {
        comp.link_task_wait_group.spawnManager(buildLibCxx, .{ comp, main_progress_node });
    }

    if (comp.queued_jobs.libcxxabi) {
        comp.link_task_wait_group.spawnManager(buildLibCxxAbi, .{ comp, main_progress_node });
    }

    if (comp.queued_jobs.libtsan) {
        comp.link_task_wait_group.spawnManager(buildLibTsan, .{ comp, main_progress_node });
    }

    if (comp.queued_jobs.zig_libc and comp.libc_static_lib == null) {
        comp.link_task_wait_group.spawnManager(buildZigLibc, .{ comp, main_progress_node });
    }

    for (0..@typeInfo(musl.CrtFile).@"enum".fields.len) |i| {
        if (comp.queued_jobs.musl_crt_file[i]) {
            const tag: musl.CrtFile = @enumFromInt(i);
            comp.link_task_wait_group.spawnManager(buildMuslCrtFile, .{ comp, tag, main_progress_node });
        }
    }

    for (0..@typeInfo(glibc.CrtFile).@"enum".fields.len) |i| {
        if (comp.queued_jobs.glibc_crt_file[i]) {
            const tag: glibc.CrtFile = @enumFromInt(i);
            comp.link_task_wait_group.spawnManager(buildGlibcCrtFile, .{ comp, tag, main_progress_node });
        }
    }

    for (0..@typeInfo(wasi_libc.CrtFile).@"enum".fields.len) |i| {
        if (comp.queued_jobs.wasi_libc_crt_file[i]) {
            const tag: wasi_libc.CrtFile = @enumFromInt(i);
            comp.link_task_wait_group.spawnManager(buildWasiLibcCrtFile, .{ comp, tag, main_progress_node });
        }
    }

    for (0..@typeInfo(mingw.CrtFile).@"enum".fields.len) |i| {
        if (comp.queued_jobs.mingw_crt_file[i]) {
            const tag: mingw.CrtFile = @enumFromInt(i);
            comp.link_task_wait_group.spawnManager(buildMingwCrtFile, .{ comp, tag, main_progress_node });
        }
    }

    {
        const astgen_frame = tracy.namedFrame("astgen");
        defer astgen_frame.end();

        const zir_prog_node = main_progress_node.start("AST Lowering", 0);
        defer zir_prog_node.end();

        var astgen_wait_group: WaitGroup = .{};
        defer astgen_wait_group.wait();

        // builtin.zig is handled specially for two reasons:
        // 1. to avoid race condition of zig processes truncating each other's builtin.zig files
        // 2. optimization; in the hot path it only incurs a stat() syscall, which happens
        //    in the `astgen_wait_group`.
        if (comp.queued_jobs.update_builtin_zig) b: {
            comp.queued_jobs.update_builtin_zig = false;
            if (comp.zcu == null) break :b;
            // TODO put all the modules in a flat array to make them easy to iterate.
            var seen: std.AutoArrayHashMapUnmanaged(*Package.Module, void) = .empty;
            defer seen.deinit(comp.gpa);
            try seen.put(comp.gpa, comp.root_mod, {});
            var i: usize = 0;
            while (i < seen.count()) : (i += 1) {
                const mod = seen.keys()[i];
                for (mod.deps.values()) |dep|
                    try seen.put(comp.gpa, dep, {});

                const file = mod.builtin_file orelse continue;

                comp.thread_pool.spawnWg(&astgen_wait_group, workerUpdateBuiltinZigFile, .{
                    comp, mod, file,
                });
            }
        }

        if (comp.zcu) |zcu| {
            {
                // Worker threads may append to zcu.files and zcu.import_table
                // so we must hold the lock while spawning those tasks, since
                // we access those tables in this loop.
                comp.mutex.lock();
                defer comp.mutex.unlock();

                while (comp.astgen_work_queue.readItem()) |file_index| {
                    // Pre-load these things from our single-threaded context since they
                    // will be needed by the worker threads.
                    const path_digest = zcu.filePathDigest(file_index);
                    const file = zcu.fileByIndex(file_index);
                    comp.thread_pool.spawnWgId(&astgen_wait_group, workerUpdateFile, .{
                        comp, file, file_index, path_digest, zir_prog_node, &astgen_wait_group, .root,
                    });
                }
            }

            for (0.., zcu.embed_table.values()) |ef_index_usize, ef| {
                const ef_index: Zcu.EmbedFile.Index = @enumFromInt(ef_index_usize);
                comp.thread_pool.spawnWgId(&astgen_wait_group, workerUpdateEmbedFile, .{
                    comp, ef_index, ef,
                });
            }
        }

        while (comp.c_object_work_queue.readItem()) |c_object| {
            comp.thread_pool.spawnWg(&comp.link_task_wait_group, workerUpdateCObject, .{
                comp, c_object, main_progress_node,
            });
        }

        while (comp.win32_resource_work_queue.readItem()) |win32_resource| {
            comp.thread_pool.spawnWg(&comp.link_task_wait_group, workerUpdateWin32Resource, .{
                comp, win32_resource, main_progress_node,
            });
        }
    }

    if (comp.zcu) |zcu| {
        const pt: Zcu.PerThread = .activate(zcu, .main);
        defer pt.deactivate();

        // If the cache mode is `whole`, then add every source file to the cache manifest.
        switch (comp.cache_use) {
            .whole => |whole| if (whole.cache_manifest) |man| {
                const gpa = zcu.gpa;
                for (zcu.import_table.values()) |file_index| {
                    const file = zcu.fileByIndex(file_index);
                    const source = file.getSource(gpa) catch |err| {
                        try pt.reportRetryableFileError(file_index, "unable to load source: {s}", .{@errorName(err)});
                        continue;
                    };
                    const resolved_path = try std.fs.path.resolve(gpa, &.{
                        file.mod.root.root_dir.path orelse ".",
                        file.mod.root.sub_path,
                        file.sub_file_path,
                    });
                    errdefer gpa.free(resolved_path);
                    whole.cache_manifest_mutex.lock();
                    defer whole.cache_manifest_mutex.unlock();
                    man.addFilePostContents(resolved_path, source.bytes, source.stat) catch |err| switch (err) {
                        error.OutOfMemory => |e| return e,
                        else => {
                            try pt.reportRetryableFileError(file_index, "unable to update cache: {s}", .{@errorName(err)});
                            continue;
                        },
                    };
                }
            },
            .incremental => {},
        }

        try reportMultiModuleErrors(pt);

        const any_fatal_files = for (zcu.import_table.values()) |file_index| {
            const file = zcu.fileByIndex(file_index);
            switch (file.status) {
                .never_loaded => unreachable, // everything is loaded by the workers
                .retryable_failure, .astgen_failure => break true,
                .success => {},
            }
        } else false;

        if (any_fatal_files or comp.alloc_failure_occurred) {
            // We give up right now! No updating of ZIR refs, no nothing. The idea is that this prevents
            // us from invalidating lots of incremental dependencies due to files with e.g. parse errors.
            // However, this means our analysis data is invalid, so we want to omit all analysis errors.

            assert(zcu.failed_files.count() > 0); // we will get an error
            zcu.skip_analysis_errors = true;
            return;
        }

        if (comp.incremental) {
            const update_zir_refs_node = main_progress_node.start("Update ZIR References", 0);
            defer update_zir_refs_node.end();
            try pt.updateZirRefs();
        }
        try zcu.flushRetryableFailures();

        zcu.sema_prog_node = main_progress_node.start("Semantic Analysis", 0);
        zcu.codegen_prog_node = if (comp.bin_file != null) main_progress_node.start("Code Generation", 0) else .none;
    }

    if (!comp.separateCodegenThreadOk()) {
        // Waits until all input files have been parsed.
        comp.link_task_wait_group.wait();
        comp.link_task_wait_group.reset();
        std.log.scoped(.link).debug("finished waiting for link_task_wait_group", .{});
        if (comp.remaining_prelink_tasks > 0) {
            // Indicates an error occurred preventing prelink phase from completing.
            return;
        }
    }

    work: while (true) {
        for (&comp.work_queues) |*work_queue| if (work_queue.readItem()) |job| {
            try processOneJob(@intFromEnum(Zcu.PerThread.Id.main), comp, job);
            continue :work;
        };
        if (comp.zcu) |zcu| {
            // If there's no work queued, check if there's anything outdated
            // which we need to work on, and queue it if so.
            if (try zcu.findOutdatedToAnalyze()) |outdated| {
                try comp.queueJob(switch (outdated.unwrap()) {
                    .func => |f| .{ .analyze_func = f },
                    .memoized_state,
                    .@"comptime",
                    .nav_ty,
                    .nav_val,
                    .type,
                    => .{ .analyze_comptime_unit = outdated },
                });
                continue;
            }
            zcu.sema_prog_node.end();
            zcu.sema_prog_node = .none;
        }
        break;
    }
}

const JobError = Allocator.Error;

pub fn queueJob(comp: *Compilation, job: Job) !void {
    try comp.work_queues[Job.stage(job)].writeItem(job);
}

pub fn queueJobs(comp: *Compilation, jobs: []const Job) !void {
    for (jobs) |job| try comp.queueJob(job);
}

fn processOneJob(tid: usize, comp: *Compilation, job: Job) JobError!void {
    switch (job) {
        .codegen_nav => |nav_index| {
            const zcu = comp.zcu.?;
            const nav = zcu.intern_pool.getNav(nav_index);
            if (nav.analysis != null) {
                const unit: InternPool.AnalUnit = .wrap(.{ .nav_val = nav_index });
                if (zcu.failed_analysis.contains(unit) or zcu.transitive_failed_analysis.contains(unit)) {
                    return;
                }
            }
            assert(nav.status == .fully_resolved);
            comp.dispatchCodegenTask(tid, .{ .codegen_nav = nav_index });
        },
        .codegen_func => |func| {
            comp.dispatchCodegenTask(tid, .{ .codegen_func = func });
        },
        .codegen_type => |ty| {
            comp.dispatchCodegenTask(tid, .{ .codegen_type = ty });
        },
        .update_line_number => |ti| {
            comp.dispatchCodegenTask(tid, .{ .update_line_number = ti });
        },
        .analyze_func => |func| {
            const named_frame = tracy.namedFrame("analyze_func");
            defer named_frame.end();

            const pt: Zcu.PerThread = .activate(comp.zcu.?, @enumFromInt(tid));
            defer pt.deactivate();

            pt.ensureFuncBodyUpToDate(func) catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                error.AnalysisFail => return,
            };
        },
        .analyze_comptime_unit => |unit| {
            const named_frame = tracy.namedFrame("analyze_comptime_unit");
            defer named_frame.end();

            const pt: Zcu.PerThread = .activate(comp.zcu.?, @enumFromInt(tid));
            defer pt.deactivate();

            const maybe_err: Zcu.SemaError!void = switch (unit.unwrap()) {
                .@"comptime" => |cu| pt.ensureComptimeUnitUpToDate(cu),
                .nav_ty => |nav| pt.ensureNavTypeUpToDate(nav),
                .nav_val => |nav| pt.ensureNavValUpToDate(nav),
                .type => |ty| if (pt.ensureTypeUpToDate(ty)) |_| {} else |err| err,
                .memoized_state => |stage| pt.ensureMemoizedStateUpToDate(stage),
                .func => unreachable,
            };
            maybe_err catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                error.AnalysisFail => return,
            };

            queue_test_analysis: {
                if (!comp.config.is_test) break :queue_test_analysis;
                const nav = switch (unit.unwrap()) {
                    .nav_val => |nav| nav,
                    else => break :queue_test_analysis,
                };

                // Check if this is a test function.
                const ip = &pt.zcu.intern_pool;
                if (!pt.zcu.test_functions.contains(nav)) {
                    break :queue_test_analysis;
                }

                // Tests are always emitted in test binaries. The decl_refs are created by
                // Zcu.populateTestFunctions, but this will not queue body analysis, so do
                // that now.
                try pt.zcu.ensureFuncBodyAnalysisQueued(ip.getNav(nav).status.fully_resolved.val);
            }
        },
        .resolve_type_fully => |ty| {
            const named_frame = tracy.namedFrame("resolve_type_fully");
            defer named_frame.end();

            const pt: Zcu.PerThread = .activate(comp.zcu.?, @enumFromInt(tid));
            defer pt.deactivate();
            Type.fromInterned(ty).resolveFully(pt) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => return,
            };
        },
        .analyze_mod => |mod| {
            const named_frame = tracy.namedFrame("analyze_mod");
            defer named_frame.end();

            const pt: Zcu.PerThread = .activate(comp.zcu.?, @enumFromInt(tid));
            defer pt.deactivate();
            pt.semaPkg(mod) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => return,
            };
        },
        .windows_import_lib => |index| {
            const named_frame = tracy.namedFrame("windows_import_lib");
            defer named_frame.end();

            const link_lib = comp.windows_libs.keys()[index];
            mingw.buildImportLib(comp, link_lib) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(
                    .windows_import_lib,
                    "unable to generate DLL import .lib file for {s}: {s}",
                    .{ link_lib, @errorName(err) },
                );
            };
        },
    }
}

/// The reason for the double-queue here is that the first queue ensures any
/// resolve_type_fully tasks are complete before this dispatch function is called.
fn dispatchCodegenTask(comp: *Compilation, tid: usize, link_task: link.Task) void {
    if (comp.separateCodegenThreadOk()) {
        comp.queueLinkTasks(&.{link_task});
    } else {
        assert(comp.remaining_prelink_tasks == 0);
        link.doTask(comp, tid, link_task);
    }
}

fn separateCodegenThreadOk(comp: *const Compilation) bool {
    if (InternPool.single_threaded) return false;
    const zcu = comp.zcu orelse return true;
    return zcu.backendSupportsFeature(.separate_thread);
}

fn workerDocsCopy(comp: *Compilation) void {
    docsCopyFallible(comp) catch |err| {
        return comp.lockAndSetMiscFailure(
            .docs_copy,
            "unable to copy autodocs artifacts: {s}",
            .{@errorName(err)},
        );
    };
}

fn docsCopyFallible(comp: *Compilation) anyerror!void {
    const zcu = comp.zcu orelse
        return comp.lockAndSetMiscFailure(.docs_copy, "no Zig code to document", .{});

    const emit = comp.docs_emit.?;
    var out_dir = emit.root_dir.handle.makeOpenPath(emit.sub_path, .{}) catch |err| {
        return comp.lockAndSetMiscFailure(
            .docs_copy,
            "unable to create output directory '{}{s}': {s}",
            .{ emit.root_dir, emit.sub_path, @errorName(err) },
        );
    };
    defer out_dir.close();

    for (&[_][]const u8{ "docs/main.js", "docs/index.html" }) |sub_path| {
        const basename = std.fs.path.basename(sub_path);
        comp.zig_lib_directory.handle.copyFile(sub_path, out_dir, basename, .{}) catch |err| {
            comp.lockAndSetMiscFailure(.docs_copy, "unable to copy {s}: {s}", .{
                sub_path,
                @errorName(err),
            });
            return;
        };
    }

    var tar_file = out_dir.createFile("sources.tar", .{}) catch |err| {
        return comp.lockAndSetMiscFailure(
            .docs_copy,
            "unable to create '{}{s}/sources.tar': {s}",
            .{ emit.root_dir, emit.sub_path, @errorName(err) },
        );
    };
    defer tar_file.close();

    var seen_table: std.AutoArrayHashMapUnmanaged(*Package.Module, []const u8) = .empty;
    defer seen_table.deinit(comp.gpa);

    try seen_table.put(comp.gpa, zcu.main_mod, comp.root_name);
    try seen_table.put(comp.gpa, zcu.std_mod, zcu.std_mod.fully_qualified_name);

    var i: usize = 0;
    while (i < seen_table.count()) : (i += 1) {
        const mod = seen_table.keys()[i];
        try comp.docsCopyModule(mod, seen_table.values()[i], tar_file);

        const deps = mod.deps.values();
        try seen_table.ensureUnusedCapacity(comp.gpa, deps.len);
        for (deps) |dep| seen_table.putAssumeCapacity(dep, dep.fully_qualified_name);
    }
}

fn docsCopyModule(comp: *Compilation, module: *Package.Module, name: []const u8, tar_file: std.fs.File) !void {
    const root = module.root;
    const sub_path = if (root.sub_path.len == 0) "." else root.sub_path;
    var mod_dir = root.root_dir.handle.openDir(sub_path, .{ .iterate = true }) catch |err| {
        return comp.lockAndSetMiscFailure(.docs_copy, "unable to open directory '{}': {s}", .{
            root, @errorName(err),
        });
    };
    defer mod_dir.close();

    var walker = try mod_dir.walk(comp.gpa);
    defer walker.deinit();

    var archiver = std.tar.writer(tar_file.writer().any());
    archiver.prefix = name;

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .file => {
                if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
                if (std.mem.eql(u8, entry.basename, "test.zig")) continue;
                if (std.mem.endsWith(u8, entry.basename, "_test.zig")) continue;
            },
            else => continue,
        }
        var file = mod_dir.openFile(entry.path, .{}) catch |err| {
            return comp.lockAndSetMiscFailure(.docs_copy, "unable to open '{}{s}': {s}", .{
                root, entry.path, @errorName(err),
            });
        };
        defer file.close();
        archiver.writeFile(entry.path, file) catch |err| {
            return comp.lockAndSetMiscFailure(.docs_copy, "unable to archive '{}{s}': {s}", .{
                root, entry.path, @errorName(err),
            });
        };
    }
}

fn workerDocsWasm(comp: *Compilation, parent_prog_node: std.Progress.Node) void {
    const prog_node = parent_prog_node.start("Compile Autodocs", 0);
    defer prog_node.end();

    workerDocsWasmFallible(comp, prog_node) catch |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.docs_wasm, "unable to build autodocs: {s}", .{
            @errorName(err),
        }),
    };
}

fn workerDocsWasmFallible(comp: *Compilation, prog_node: std.Progress.Node) anyerror!void {
    const gpa = comp.gpa;

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const optimize_mode = std.builtin.OptimizeMode.ReleaseSmall;
    const output_mode = std.builtin.OutputMode.Exe;
    const resolved_target: Package.Module.ResolvedTarget = .{
        .result = std.zig.system.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
            .cpu_features_add = std.Target.wasm.featureSet(&.{
                .atomics,
                // .extended_const, not supported by Safari
                .reference_types,
                //.relaxed_simd, not supported by Firefox or Safari
                // observed to cause Error occured during wast conversion :
                // Unknown operator: 0xfd058 in Firefox 117
                //.simd128,
                // .tail_call, not supported by Safari
            }),
        }) catch unreachable,

        .is_native_os = false,
        .is_native_abi = false,
    };

    const config = try Config.resolve(.{
        .output_mode = output_mode,
        .resolved_target = resolved_target,
        .is_test = false,
        .have_zcu = true,
        .emit_bin = true,
        .root_optimize_mode = optimize_mode,
        .link_libc = false,
        .rdynamic = true,
    });

    const src_basename = "main.zig";
    const root_name = std.fs.path.stem(src_basename);

    const root_mod = try Package.Module.create(arena, .{
        .global_cache_directory = comp.global_cache_directory,
        .paths = .{
            .root = .{
                .root_dir = comp.zig_lib_directory,
                .sub_path = "docs/wasm",
            },
            .root_src_path = src_basename,
        },
        .fully_qualified_name = root_name,
        .inherited = .{
            .resolved_target = resolved_target,
            .optimize_mode = optimize_mode,
        },
        .global = config,
        .cc_argv = &.{},
        .parent = null,
        .builtin_mod = null,
        .builtin_modules = null,
    });
    const walk_mod = try Package.Module.create(arena, .{
        .global_cache_directory = comp.global_cache_directory,
        .paths = .{
            .root = .{
                .root_dir = comp.zig_lib_directory,
                .sub_path = "docs/wasm",
            },
            .root_src_path = "Walk.zig",
        },
        .fully_qualified_name = "Walk",
        .inherited = .{
            .resolved_target = resolved_target,
            .optimize_mode = optimize_mode,
        },
        .global = config,
        .cc_argv = &.{},
        .parent = root_mod,
        .builtin_mod = root_mod.getBuiltinDependency(),
        .builtin_modules = null, // `builtin_mod` is set
    });
    try root_mod.deps.put(arena, "Walk", walk_mod);
    const bin_basename = try std.zig.binNameAlloc(arena, .{
        .root_name = root_name,
        .target = resolved_target.result,
        .output_mode = output_mode,
    });

    const sub_compilation = try Compilation.create(gpa, arena, .{
        .global_cache_directory = comp.global_cache_directory,
        .local_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .self_exe_path = comp.self_exe_path,
        .config = config,
        .root_mod = root_mod,
        .entry = .disabled,
        .cache_mode = .whole,
        .root_name = root_name,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.libc_installation,
        .emit_bin = .{
            .directory = null, // Put it in the cache directory.
            .basename = bin_basename,
        },
        .verbose_cc = comp.verbose_cc,
        .verbose_link = comp.verbose_link,
        .verbose_air = comp.verbose_air,
        .verbose_intern_pool = comp.verbose_intern_pool,
        .verbose_generic_instances = comp.verbose_intern_pool,
        .verbose_llvm_ir = comp.verbose_llvm_ir,
        .verbose_llvm_bc = comp.verbose_llvm_bc,
        .verbose_cimport = comp.verbose_cimport,
        .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
    });
    defer sub_compilation.destroy();

    try comp.updateSubCompilation(sub_compilation, .docs_wasm, prog_node);

    const emit = comp.docs_emit.?;
    var out_dir = emit.root_dir.handle.makeOpenPath(emit.sub_path, .{}) catch |err| {
        return comp.lockAndSetMiscFailure(
            .docs_copy,
            "unable to create output directory '{}{s}': {s}",
            .{ emit.root_dir, emit.sub_path, @errorName(err) },
        );
    };
    defer out_dir.close();

    sub_compilation.local_cache_directory.handle.copyFile(
        sub_compilation.cache_use.whole.bin_sub_path.?,
        out_dir,
        "main.wasm",
        .{},
    ) catch |err| {
        return comp.lockAndSetMiscFailure(.docs_copy, "unable to copy '{}{s}' to '{}{s}': {s}", .{
            sub_compilation.local_cache_directory,
            sub_compilation.cache_use.whole.bin_sub_path.?,
            emit.root_dir,
            emit.sub_path,
            @errorName(err),
        });
    };
}

fn workerUpdateFile(
    tid: usize,
    comp: *Compilation,
    file: *Zcu.File,
    file_index: Zcu.File.Index,
    path_digest: Cache.BinDigest,
    prog_node: std.Progress.Node,
    wg: *WaitGroup,
    src: Zcu.AstGenSrc,
) void {
    const child_prog_node = prog_node.start(file.sub_file_path, 0);
    defer child_prog_node.end();

    const pt: Zcu.PerThread = .activate(comp.zcu.?, @enumFromInt(tid));
    defer pt.deactivate();
    pt.updateFile(file, path_digest) catch |err| switch (err) {
        error.AnalysisFail => return,
        else => {
            pt.reportRetryableAstGenError(src, file_index, err) catch |oom| switch (oom) {
                error.OutOfMemory => {
                    comp.mutex.lock();
                    defer comp.mutex.unlock();
                    comp.setAllocFailure();
                },
            };
            return;
        },
    };

    switch (file.getMode()) {
        .zig => {}, // continue to logic below
        .zon => return, // ZON can't import anything so we're done
    }

    // Pre-emptively look for `@import` paths and queue them up.
    // If we experience an error preemptively fetching the
    // file, just ignore it and let it happen again later during Sema.
    const imports_index = file.zir.?.extra[@intFromEnum(Zir.ExtraIndex.imports)];
    if (imports_index != 0) {
        const extra = file.zir.?.extraData(Zir.Inst.Imports, imports_index);
        var import_i: u32 = 0;
        var extra_index = extra.end;

        while (import_i < extra.data.imports_len) : (import_i += 1) {
            const item = file.zir.?.extraData(Zir.Inst.Imports.Item, extra_index);
            extra_index = item.end;

            const import_path = file.zir.?.nullTerminatedString(item.data.name);
            // `@import("builtin")` is handled specially.
            if (mem.eql(u8, import_path, "builtin")) continue;

            const import_result, const imported_path_digest = blk: {
                comp.mutex.lock();
                defer comp.mutex.unlock();

                const res = pt.importFile(file, import_path) catch continue;
                if (!res.is_pkg) {
                    res.file.addReference(pt.zcu, .{ .import = .{
                        .file = file_index,
                        .token = item.data.token,
                    } }) catch continue;
                }
                if (res.is_new) if (comp.file_system_inputs) |fsi| {
                    comp.appendFileSystemInput(fsi, res.file.mod.root, res.file.sub_file_path) catch continue;
                };
                const imported_path_digest = pt.zcu.filePathDigest(res.file_index);
                break :blk .{ res, imported_path_digest };
            };
            if (import_result.is_new) {
                log.debug("AstGen of {s} has import '{s}'; queuing AstGen of {s}", .{
                    file.sub_file_path, import_path, import_result.file.sub_file_path,
                });
                const sub_src: Zcu.AstGenSrc = .{ .import = .{
                    .importing_file = file_index,
                    .import_tok = item.data.token,
                } };
                comp.thread_pool.spawnWgId(wg, workerUpdateFile, .{
                    comp, import_result.file, import_result.file_index, imported_path_digest, prog_node, wg, sub_src,
                });
            }
        }
    }
}

fn workerUpdateBuiltinZigFile(
    comp: *Compilation,
    mod: *Package.Module,
    file: *Zcu.File,
) void {
    Builtin.populateFile(comp, mod, file) catch |err| {
        comp.mutex.lock();
        defer comp.mutex.unlock();

        comp.setMiscFailure(.write_builtin_zig, "unable to write '{}{s}': {s}", .{
            mod.root, mod.root_src_path, @errorName(err),
        });
    };
}

fn workerUpdateEmbedFile(tid: usize, comp: *Compilation, ef_index: Zcu.EmbedFile.Index, ef: *Zcu.EmbedFile) void {
    comp.detectEmbedFileUpdate(@enumFromInt(tid), ef_index, ef) catch |err| switch (err) {
        error.OutOfMemory => {
            comp.mutex.lock();
            defer comp.mutex.unlock();
            comp.setAllocFailure();
        },
    };
}

fn detectEmbedFileUpdate(comp: *Compilation, tid: Zcu.PerThread.Id, ef_index: Zcu.EmbedFile.Index, ef: *Zcu.EmbedFile) !void {
    const zcu = comp.zcu.?;
    const pt: Zcu.PerThread = .activate(zcu, tid);
    defer pt.deactivate();

    const old_val = ef.val;
    const old_err = ef.err;

    try pt.updateEmbedFile(ef, null);

    if (ef.val != .none and ef.val == old_val) return; // success, value unchanged
    if (ef.val == .none and old_val == .none and ef.err == old_err) return; // failure, error unchanged

    comp.mutex.lock();
    defer comp.mutex.unlock();

    try zcu.markDependeeOutdated(.not_marked_po, .{ .embed_file = ef_index });
}

pub fn obtainCObjectCacheManifest(
    comp: *const Compilation,
    owner_mod: *Package.Module,
) Cache.Manifest {
    var man = comp.cache_parent.obtain();

    // Only things that need to be added on top of the base hash, and only things
    // that apply both to @cImport and compiling C objects. No linking stuff here!
    // Also nothing that applies only to compiling .zig code.
    cache_helpers.addModule(&man.hash, owner_mod);
    man.hash.addListOfBytes(comp.global_cc_argv);
    man.hash.add(comp.config.link_libcpp);

    // When libc_installation is null it means that Zig generated this dir list
    // based on the zig library directory alone. The zig lib directory file
    // path is purposefully either in the cache or not in the cache. The
    // decision should not be overridden here.
    if (comp.libc_installation != null) {
        man.hash.addListOfBytes(comp.libc_include_dir_list);
    }

    return man;
}

pub fn obtainWin32ResourceCacheManifest(comp: *const Compilation) Cache.Manifest {
    var man = comp.cache_parent.obtain();

    man.hash.add(comp.rc_includes);

    return man;
}

pub const CImportResult = struct {
    digest: [Cache.bin_digest_len]u8,
    cache_hit: bool,
    errors: std.zig.ErrorBundle,

    pub fn deinit(result: *CImportResult, gpa: mem.Allocator) void {
        result.errors.deinit(gpa);
    }
};

/// Caller owns returned memory.
pub fn cImport(comp: *Compilation, c_src: []const u8, owner_mod: *Package.Module) !CImportResult {
    dev.check(.translate_c_command);

    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    const cimport_zig_basename = "cimport.zig";

    var man = comp.obtainCObjectCacheManifest(owner_mod);
    defer man.deinit();

    man.hash.add(@as(u16, 0xb945)); // Random number to distinguish translate-c from compiling C objects
    man.hash.addBytes(c_src);
    man.hash.add(comp.config.c_frontend);

    // If the previous invocation resulted in clang errors, we will see a hit
    // here with 0 files in the manifest, in which case it is actually a miss.
    // We need to "unhit" in this case, to keep the digests matching.
    const prev_hash_state = man.hash.peekBin();
    const actual_hit = hit: {
        _ = try man.hit();
        if (man.files.entries.len == 0) {
            man.unhit(prev_hash_state, 0);
            break :hit false;
        }
        break :hit true;
    };
    const digest = if (!actual_hit) digest: {
        var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        const tmp_digest = man.hash.peek();
        const tmp_dir_sub_path = try std.fs.path.join(arena, &[_][]const u8{ "o", &tmp_digest });
        var zig_cache_tmp_dir = try comp.local_cache_directory.handle.makeOpenPath(tmp_dir_sub_path, .{});
        defer zig_cache_tmp_dir.close();
        const cimport_basename = "cimport.h";
        const out_h_path = try comp.local_cache_directory.join(arena, &[_][]const u8{
            tmp_dir_sub_path, cimport_basename,
        });
        const out_dep_path = try std.fmt.allocPrint(arena, "{s}.d", .{out_h_path});

        try zig_cache_tmp_dir.writeFile(.{ .sub_path = cimport_basename, .data = c_src });
        if (comp.verbose_cimport) {
            log.info("C import source: {s}", .{out_h_path});
        }

        var argv = std.ArrayList([]const u8).init(comp.gpa);
        defer argv.deinit();

        try argv.append(@tagName(comp.config.c_frontend)); // argv[0] is program name, actual args start at [1]
        try comp.addTranslateCCArgs(arena, &argv, .c, out_dep_path, owner_mod);

        try argv.append(out_h_path);

        if (comp.verbose_cc) {
            dump_argv(argv.items);
        }
        var tree = switch (comp.config.c_frontend) {
            .aro => tree: {
                if (true) @panic("TODO");
                break :tree undefined;
            },
            .clang => tree: {
                if (!build_options.have_llvm) unreachable;
                const translate_c = @import("translate_c.zig");

                // Convert to null terminated args.
                const new_argv_with_sentinel = try arena.alloc(?[*:0]const u8, argv.items.len + 1);
                new_argv_with_sentinel[argv.items.len] = null;
                const new_argv = new_argv_with_sentinel[0..argv.items.len :null];
                for (argv.items, 0..) |arg, i| {
                    new_argv[i] = try arena.dupeZ(u8, arg);
                }

                const c_headers_dir_path_z = try comp.zig_lib_directory.joinZ(arena, &[_][]const u8{"include"});
                var errors = std.zig.ErrorBundle.empty;
                errdefer errors.deinit(comp.gpa);
                break :tree translate_c.translate(
                    comp.gpa,
                    new_argv.ptr,
                    new_argv.ptr + new_argv.len,
                    &errors,
                    c_headers_dir_path_z,
                ) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.SemanticAnalyzeFail => {
                        return CImportResult{
                            .digest = undefined,
                            .cache_hit = actual_hit,
                            .errors = errors,
                        };
                    },
                };
            },
        };
        defer tree.deinit(comp.gpa);

        if (comp.verbose_cimport) {
            log.info("C import .d file: {s}", .{out_dep_path});
        }

        const dep_basename = std.fs.path.basename(out_dep_path);
        try man.addDepFilePost(zig_cache_tmp_dir, dep_basename);
        switch (comp.cache_use) {
            .whole => |whole| if (whole.cache_manifest) |whole_cache_manifest| {
                whole.cache_manifest_mutex.lock();
                defer whole.cache_manifest_mutex.unlock();
                try whole_cache_manifest.addDepFilePost(zig_cache_tmp_dir, dep_basename);
            },
            .incremental => {},
        }

        const bin_digest = man.finalBin();
        const hex_digest = Cache.binToHex(bin_digest);
        const o_sub_path = "o" ++ std.fs.path.sep_str ++ hex_digest;
        var o_dir = try comp.local_cache_directory.handle.makeOpenPath(o_sub_path, .{});
        defer o_dir.close();

        var out_zig_file = try o_dir.createFile(cimport_zig_basename, .{});
        defer out_zig_file.close();

        const formatted = try tree.render(comp.gpa);
        defer comp.gpa.free(formatted);

        try out_zig_file.writeAll(formatted);

        break :digest bin_digest;
    } else man.finalBin();

    if (man.have_exclusive_lock) {
        // Write the updated manifest. This is a no-op if the manifest is not dirty. Note that it is
        // possible we had a hit and the manifest is dirty, for example if the file mtime changed but
        // the contents were the same, we hit the cache but the manifest is dirty and we need to update
        // it to prevent doing a full file content comparison the next time around.
        man.writeManifest() catch |err| {
            log.warn("failed to write cache manifest for C import: {s}", .{@errorName(err)});
        };
    }

    return CImportResult{
        .digest = digest,
        .cache_hit = actual_hit,
        .errors = std.zig.ErrorBundle.empty,
    };
}

fn workerUpdateCObject(
    comp: *Compilation,
    c_object: *CObject,
    progress_node: std.Progress.Node,
) void {
    comp.updateCObject(c_object, progress_node) catch |err| switch (err) {
        error.AnalysisFail => return,
        else => {
            comp.reportRetryableCObjectError(c_object, err) catch |oom| switch (oom) {
                // Swallowing this error is OK because it's implied to be OOM when
                // there is a missing failed_c_objects error message.
                error.OutOfMemory => {},
            };
        },
    };
}

fn workerUpdateWin32Resource(
    comp: *Compilation,
    win32_resource: *Win32Resource,
    progress_node: std.Progress.Node,
) void {
    comp.updateWin32Resource(win32_resource, progress_node) catch |err| switch (err) {
        error.AnalysisFail => return,
        else => {
            comp.reportRetryableWin32ResourceError(win32_resource, err) catch |oom| switch (oom) {
                // Swallowing this error is OK because it's implied to be OOM when
                // there is a missing failed_win32_resources error message.
                error.OutOfMemory => {},
            };
        },
    };
}

fn buildRt(
    comp: *Compilation,
    root_source_name: []const u8,
    misc_task: MiscTask,
    output_mode: std.builtin.OutputMode,
    allow_lto: bool,
    out: *?CrtFile,
    prog_node: std.Progress.Node,
) void {
    comp.buildOutputFromZig(
        root_source_name,
        output_mode,
        allow_lto,
        out,
        misc_task,
        prog_node,
    ) catch |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(misc_task, "unable to build {s}: {s}", .{
            @tagName(misc_task), @errorName(err),
        }),
    };
}

fn buildMuslCrtFile(comp: *Compilation, crt_file: musl.CrtFile, prog_node: std.Progress.Node) void {
    if (musl.buildCrtFile(comp, crt_file, prog_node)) |_| {
        comp.queued_jobs.musl_crt_file[@intFromEnum(crt_file)] = false;
    } else |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.musl_crt_file, "unable to build musl {s}: {s}", .{
            @tagName(crt_file), @errorName(err),
        }),
    }
}

fn buildGlibcCrtFile(comp: *Compilation, crt_file: glibc.CrtFile, prog_node: std.Progress.Node) void {
    if (glibc.buildCrtFile(comp, crt_file, prog_node)) |_| {
        comp.queued_jobs.glibc_crt_file[@intFromEnum(crt_file)] = false;
    } else |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.glibc_crt_file, "unable to build glibc {s}: {s}", .{
            @tagName(crt_file), @errorName(err),
        }),
    }
}

fn buildGlibcSharedObjects(comp: *Compilation, prog_node: std.Progress.Node) void {
    if (glibc.buildSharedObjects(comp, prog_node)) |_| {
        // The job should no longer be queued up since it succeeded.
        comp.queued_jobs.glibc_shared_objects = false;
    } else |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.glibc_shared_objects, "unable to build glibc shared objects: {s}", .{
            @errorName(err),
        }),
    }
}

fn buildMingwCrtFile(comp: *Compilation, crt_file: mingw.CrtFile, prog_node: std.Progress.Node) void {
    if (mingw.buildCrtFile(comp, crt_file, prog_node)) |_| {
        comp.queued_jobs.mingw_crt_file[@intFromEnum(crt_file)] = false;
    } else |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.mingw_crt_file, "unable to build mingw-w64 {s}: {s}", .{
            @tagName(crt_file), @errorName(err),
        }),
    }
}

fn buildWasiLibcCrtFile(comp: *Compilation, crt_file: wasi_libc.CrtFile, prog_node: std.Progress.Node) void {
    if (wasi_libc.buildCrtFile(comp, crt_file, prog_node)) |_| {
        comp.queued_jobs.wasi_libc_crt_file[@intFromEnum(crt_file)] = false;
    } else |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.wasi_libc_crt_file, "unable to build WASI libc {s}: {s}", .{
            @tagName(crt_file), @errorName(err),
        }),
    }
}

fn buildLibUnwind(comp: *Compilation, prog_node: std.Progress.Node) void {
    if (libunwind.buildStaticLib(comp, prog_node)) |_| {
        comp.queued_jobs.libunwind = false;
    } else |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.libunwind, "unable to build libunwind: {s}", .{@errorName(err)}),
    }
}

fn buildLibCxx(comp: *Compilation, prog_node: std.Progress.Node) void {
    if (libcxx.buildLibCxx(comp, prog_node)) |_| {
        comp.queued_jobs.libcxx = false;
    } else |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.libcxx, "unable to build libcxx: {s}", .{@errorName(err)}),
    }
}

fn buildLibCxxAbi(comp: *Compilation, prog_node: std.Progress.Node) void {
    if (libcxx.buildLibCxxAbi(comp, prog_node)) |_| {
        comp.queued_jobs.libcxxabi = false;
    } else |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.libcxxabi, "unable to build libcxxabi: {s}", .{@errorName(err)}),
    }
}

fn buildLibTsan(comp: *Compilation, prog_node: std.Progress.Node) void {
    if (libtsan.buildTsan(comp, prog_node)) |_| {
        comp.queued_jobs.libtsan = false;
    } else |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.libtsan, "unable to build TSAN library: {s}", .{@errorName(err)}),
    }
}

fn buildZigLibc(comp: *Compilation, prog_node: std.Progress.Node) void {
    comp.buildOutputFromZig(
        "c.zig",
        .Lib,
        true,
        &comp.libc_static_lib,
        .zig_libc,
        prog_node,
    ) catch |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.zig_libc, "unable to build zig's multitarget libc: {s}", .{@errorName(err)}),
    };
}

fn reportRetryableCObjectError(
    comp: *Compilation,
    c_object: *CObject,
    err: anyerror,
) error{OutOfMemory}!void {
    c_object.status = .failure_retryable;

    switch (comp.failCObj(c_object, "{s}", .{@errorName(err)})) {
        error.AnalysisFail => return,
        else => |e| return e,
    }
}

fn reportRetryableWin32ResourceError(
    comp: *Compilation,
    win32_resource: *Win32Resource,
    err: anyerror,
) error{OutOfMemory}!void {
    win32_resource.status = .failure_retryable;

    var bundle: ErrorBundle.Wip = undefined;
    try bundle.init(comp.gpa);
    errdefer bundle.deinit();
    try bundle.addRootErrorMessage(.{
        .msg = try bundle.printString("{s}", .{@errorName(err)}),
        .src_loc = try bundle.addSourceLocation(.{
            .src_path = try bundle.addString(switch (win32_resource.src) {
                .rc => |rc_src| rc_src.src_path,
                .manifest => |manifest_src| manifest_src,
            }),
            .line = 0,
            .column = 0,
            .span_start = 0,
            .span_main = 0,
            .span_end = 0,
        }),
    });
    const finished_bundle = try bundle.toOwnedBundle("");
    {
        comp.mutex.lock();
        defer comp.mutex.unlock();
        try comp.failed_win32_resources.putNoClobber(comp.gpa, win32_resource, finished_bundle);
    }
}

fn updateCObject(comp: *Compilation, c_object: *CObject, c_obj_prog_node: std.Progress.Node) !void {
    if (comp.config.c_frontend == .aro) {
        return comp.failCObj(c_object, "aro does not support compiling C objects yet", .{});
    }
    if (!build_options.have_llvm) {
        return comp.failCObj(c_object, "clang not available: compiler built without LLVM extensions", .{});
    }
    const self_exe_path = comp.self_exe_path orelse
        return comp.failCObj(c_object, "clang compilation disabled", .{});

    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    log.debug("updating C object: {s}", .{c_object.src.src_path});

    const gpa = comp.gpa;

    if (c_object.clearStatus(gpa)) {
        // There was previous failure.
        comp.mutex.lock();
        defer comp.mutex.unlock();
        // If the failure was OOM, there will not be an entry here, so we do
        // not assert discard.
        _ = comp.failed_c_objects.swapRemove(c_object);
    }

    var man = comp.obtainCObjectCacheManifest(c_object.src.owner);
    defer man.deinit();

    man.hash.add(comp.clang_preprocessor_mode);
    cache_helpers.addOptionalEmitLoc(&man.hash, comp.emit_asm);
    cache_helpers.addOptionalEmitLoc(&man.hash, comp.emit_llvm_ir);
    cache_helpers.addOptionalEmitLoc(&man.hash, comp.emit_llvm_bc);

    try cache_helpers.hashCSource(&man, c_object.src);

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const c_source_basename = std.fs.path.basename(c_object.src.src_path);

    const child_progress_node = c_obj_prog_node.start(c_source_basename, 0);
    defer child_progress_node.end();

    // Special case when doing build-obj for just one C file. When there are more than one object
    // file and building an object we need to link them together, but with just one it should go
    // directly to the output file.
    const direct_o = comp.c_source_files.len == 1 and comp.zcu == null and
        comp.config.output_mode == .Obj and !link.anyObjectInputs(comp.link_inputs);
    const o_basename_noext = if (direct_o)
        comp.root_name
    else
        c_source_basename[0 .. c_source_basename.len - std.fs.path.extension(c_source_basename).len];

    const target = comp.getTarget();
    const o_ext = target.ofmt.fileExt(target.cpu.arch);
    const digest = if (!comp.disable_c_depfile and try man.hit()) man.final() else blk: {
        var argv = std.ArrayList([]const u8).init(gpa);
        defer argv.deinit();

        // In case we are doing passthrough mode, we need to detect -S and -emit-llvm.
        const out_ext = e: {
            if (!comp.clang_passthrough_mode)
                break :e o_ext;
            if (comp.emit_asm != null)
                break :e ".s";
            if (comp.emit_llvm_ir != null)
                break :e ".ll";
            if (comp.emit_llvm_bc != null)
                break :e ".bc";

            break :e o_ext;
        };
        const o_basename = try std.fmt.allocPrint(arena, "{s}{s}", .{ o_basename_noext, out_ext });
        const ext = c_object.src.ext orelse classifyFileExt(c_object.src.src_path);

        try argv.appendSlice(&[_][]const u8{ self_exe_path, "clang" });
        // if "ext" is explicit, add "-x <lang>". Otherwise let clang do its thing.
        if (c_object.src.ext != null or ext.clangNeedsLanguageOverride()) {
            try argv.appendSlice(&[_][]const u8{ "-x", switch (ext) {
                .assembly => "assembler",
                .assembly_with_cpp => "assembler-with-cpp",
                .c => "c",
                .h => "c-header",
                .cpp => "c++",
                .hpp => "c++-header",
                .m => "objective-c",
                .hm => "objective-c-header",
                .mm => "objective-c++",
                .hmm => "objective-c++-header",
                else => fatal("language '{s}' is unsupported in this context", .{@tagName(ext)}),
            } });
        }
        try argv.append(c_object.src.src_path);

        // When all these flags are true, it means that the entire purpose of
        // this compilation is to perform a single zig cc operation. This means
        // that we could "tail call" clang by doing an execve, and any use of
        // the caching system would actually be problematic since the user is
        // presumably doing their own caching by using dep file flags.
        if (std.process.can_execv and direct_o and
            comp.disable_c_depfile and comp.clang_passthrough_mode)
        {
            try comp.addCCArgs(arena, &argv, ext, null, c_object.src.owner);
            try argv.appendSlice(c_object.src.extra_flags);
            try argv.appendSlice(c_object.src.cache_exempt_flags);

            const out_obj_path = if (comp.bin_file) |lf|
                try lf.emit.root_dir.join(arena, &.{lf.emit.sub_path})
            else
                "/dev/null";

            try argv.ensureUnusedCapacity(6);
            switch (comp.clang_preprocessor_mode) {
                .no => argv.appendSliceAssumeCapacity(&.{ "-c", "-o", out_obj_path }),
                .yes => argv.appendSliceAssumeCapacity(&.{ "-E", "-o", out_obj_path }),
                .pch => argv.appendSliceAssumeCapacity(&.{ "-Xclang", "-emit-pch", "-o", out_obj_path }),
                .stdout => argv.appendAssumeCapacity("-E"),
            }

            if (comp.emit_asm != null) {
                argv.appendAssumeCapacity("-S");
            } else if (comp.emit_llvm_ir != null) {
                argv.appendSliceAssumeCapacity(&[_][]const u8{ "-emit-llvm", "-S" });
            } else if (comp.emit_llvm_bc != null) {
                argv.appendAssumeCapacity("-emit-llvm");
            }

            if (comp.verbose_cc) {
                dump_argv(argv.items);
            }

            const err = std.process.execv(arena, argv.items);
            fatal("unable to execv clang: {s}", .{@errorName(err)});
        }

        // We can't know the digest until we do the C compiler invocation,
        // so we need a temporary filename.
        const out_obj_path = try comp.tmpFilePath(arena, o_basename);
        var zig_cache_tmp_dir = try comp.local_cache_directory.handle.makeOpenPath("tmp", .{});
        defer zig_cache_tmp_dir.close();

        const out_diag_path = if (comp.clang_passthrough_mode or !ext.clangSupportsDiagnostics())
            null
        else
            try std.fmt.allocPrint(arena, "{s}.diag", .{out_obj_path});
        const out_dep_path = if (comp.disable_c_depfile or !ext.clangSupportsDepFile())
            null
        else
            try std.fmt.allocPrint(arena, "{s}.d", .{out_obj_path});

        try comp.addCCArgs(arena, &argv, ext, out_dep_path, c_object.src.owner);
        try argv.appendSlice(c_object.src.extra_flags);
        try argv.appendSlice(c_object.src.cache_exempt_flags);

        try argv.ensureUnusedCapacity(6);
        switch (comp.clang_preprocessor_mode) {
            .no => argv.appendSliceAssumeCapacity(&.{ "-c", "-o", out_obj_path }),
            .yes => argv.appendSliceAssumeCapacity(&.{ "-E", "-o", out_obj_path }),
            .pch => argv.appendSliceAssumeCapacity(&.{ "-Xclang", "-emit-pch", "-o", out_obj_path }),
            .stdout => argv.appendAssumeCapacity("-E"),
        }
        if (out_diag_path) |diag_file_path| {
            argv.appendSliceAssumeCapacity(&.{ "--serialize-diagnostics", diag_file_path });
        } else if (comp.clang_passthrough_mode) {
            if (comp.emit_asm != null) {
                argv.appendAssumeCapacity("-S");
            } else if (comp.emit_llvm_ir != null) {
                argv.appendSliceAssumeCapacity(&.{ "-emit-llvm", "-S" });
            } else if (comp.emit_llvm_bc != null) {
                argv.appendAssumeCapacity("-emit-llvm");
            }
        }

        if (comp.verbose_cc) {
            dump_argv(argv.items);
        }

        // Just to save disk space, we delete the files that are never needed again.
        defer if (out_diag_path) |diag_file_path| zig_cache_tmp_dir.deleteFile(std.fs.path.basename(diag_file_path)) catch |err| {
            log.warn("failed to delete '{s}': {s}", .{ diag_file_path, @errorName(err) });
        };
        defer if (out_dep_path) |dep_file_path| zig_cache_tmp_dir.deleteFile(std.fs.path.basename(dep_file_path)) catch |err| {
            log.warn("failed to delete '{s}': {s}", .{ dep_file_path, @errorName(err) });
        };
        if (std.process.can_spawn) {
            var child = std.process.Child.init(argv.items, arena);
            if (comp.clang_passthrough_mode) {
                child.stdin_behavior = .Inherit;
                child.stdout_behavior = .Inherit;
                child.stderr_behavior = .Inherit;

                const term = child.spawnAndWait() catch |err| {
                    return comp.failCObj(c_object, "failed to spawn zig clang (passthrough mode) {s}: {s}", .{ argv.items[0], @errorName(err) });
                };
                switch (term) {
                    .Exited => |code| {
                        if (code != 0) {
                            std.process.exit(code);
                        }
                        if (comp.clang_preprocessor_mode == .stdout)
                            std.process.exit(0);
                    },
                    else => std.process.abort(),
                }
            } else {
                child.stdin_behavior = .Ignore;
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Pipe;

                try child.spawn();

                const stderr = try child.stderr.?.reader().readAllAlloc(arena, std.math.maxInt(usize));

                const term = child.wait() catch |err| {
                    return comp.failCObj(c_object, "failed to spawn zig clang {s}: {s}", .{ argv.items[0], @errorName(err) });
                };

                switch (term) {
                    .Exited => |code| if (code != 0) if (out_diag_path) |diag_file_path| {
                        const bundle = CObject.Diag.Bundle.parse(gpa, diag_file_path) catch |err| {
                            log.err("{}: failed to parse clang diagnostics: {s}", .{ err, stderr });
                            return comp.failCObj(c_object, "clang exited with code {d}", .{code});
                        };
                        return comp.failCObjWithOwnedDiagBundle(c_object, bundle);
                    } else {
                        log.err("clang failed with stderr: {s}", .{stderr});
                        return comp.failCObj(c_object, "clang exited with code {d}", .{code});
                    },
                    else => {
                        log.err("clang terminated with stderr: {s}", .{stderr});
                        return comp.failCObj(c_object, "clang terminated unexpectedly", .{});
                    },
                }
            }
        } else {
            const exit_code = try clangMain(arena, argv.items);
            if (exit_code != 0) {
                if (comp.clang_passthrough_mode) {
                    std.process.exit(exit_code);
                } else {
                    return comp.failCObj(c_object, "clang exited with code {d}", .{exit_code});
                }
            }
            if (comp.clang_passthrough_mode and
                comp.clang_preprocessor_mode == .stdout)
            {
                std.process.exit(0);
            }
        }

        if (out_dep_path) |dep_file_path| {
            const dep_basename = std.fs.path.basename(dep_file_path);
            // Add the files depended on to the cache system.
            try man.addDepFilePost(zig_cache_tmp_dir, dep_basename);
            switch (comp.cache_use) {
                .whole => |whole| {
                    if (whole.cache_manifest) |whole_cache_manifest| {
                        whole.cache_manifest_mutex.lock();
                        defer whole.cache_manifest_mutex.unlock();
                        try whole_cache_manifest.addDepFilePost(zig_cache_tmp_dir, dep_basename);
                    }
                },
                .incremental => {},
            }
        }

        // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
        if (comp.disable_c_depfile) _ = try man.hit();

        // Rename into place.
        const digest = man.final();
        const o_sub_path = try std.fs.path.join(arena, &[_][]const u8{ "o", &digest });
        var o_dir = try comp.local_cache_directory.handle.makeOpenPath(o_sub_path, .{});
        defer o_dir.close();
        const tmp_basename = std.fs.path.basename(out_obj_path);
        try std.fs.rename(zig_cache_tmp_dir, tmp_basename, o_dir, o_basename);
        break :blk digest;
    };

    if (man.have_exclusive_lock) {
        // Write the updated manifest. This is a no-op if the manifest is not dirty. Note that it is
        // possible we had a hit and the manifest is dirty, for example if the file mtime changed but
        // the contents were the same, we hit the cache but the manifest is dirty and we need to update
        // it to prevent doing a full file content comparison the next time around.
        man.writeManifest() catch |err| {
            log.warn("failed to write cache manifest when compiling '{s}': {s}", .{
                c_object.src.src_path, @errorName(err),
            });
        };
    }

    const o_basename = try std.fmt.allocPrint(arena, "{s}{s}", .{ o_basename_noext, o_ext });

    c_object.status = .{
        .success = .{
            .object_path = .{
                .root_dir = comp.local_cache_directory,
                .sub_path = try std.fs.path.join(gpa, &.{ "o", &digest, o_basename }),
            },
            .lock = man.toOwnedLock(),
        },
    };

    comp.queueLinkTasks(&.{.{ .load_object = c_object.status.success.object_path }});
}

fn updateWin32Resource(comp: *Compilation, win32_resource: *Win32Resource, win32_resource_prog_node: std.Progress.Node) !void {
    if (!std.process.can_spawn) {
        return comp.failWin32Resource(win32_resource, "{s} does not support spawning a child process", .{@tagName(builtin.os.tag)});
    }

    const self_exe_path = comp.self_exe_path orelse
        return comp.failWin32Resource(win32_resource, "unable to find self exe path", .{});

    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    const src_path = switch (win32_resource.src) {
        .rc => |rc_src| rc_src.src_path,
        .manifest => |src_path| src_path,
    };
    const src_basename = std.fs.path.basename(src_path);

    log.debug("updating win32 resource: {s}", .{src_path});

    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    if (win32_resource.clearStatus(comp.gpa)) {
        // There was previous failure.
        comp.mutex.lock();
        defer comp.mutex.unlock();
        // If the failure was OOM, there will not be an entry here, so we do
        // not assert discard.
        _ = comp.failed_win32_resources.swapRemove(win32_resource);
    }

    const child_progress_node = win32_resource_prog_node.start(src_basename, 0);
    defer child_progress_node.end();

    var man = comp.obtainWin32ResourceCacheManifest();
    defer man.deinit();

    // For .manifest files, we ultimately just want to generate a .res with
    // the XML data as a RT_MANIFEST resource. This means we can skip preprocessing,
    // include paths, CLI options, etc.
    if (win32_resource.src == .manifest) {
        _ = try man.addFile(src_path, null);

        const rc_basename = try std.fmt.allocPrint(arena, "{s}.rc", .{src_basename});
        const res_basename = try std.fmt.allocPrint(arena, "{s}.res", .{src_basename});

        const digest = if (try man.hit()) man.final() else blk: {
            // The digest only depends on the .manifest file, so we can
            // get the digest now and write the .res directly to the cache
            const digest = man.final();

            const o_sub_path = try std.fs.path.join(arena, &.{ "o", &digest });
            var o_dir = try comp.local_cache_directory.handle.makeOpenPath(o_sub_path, .{});
            defer o_dir.close();

            const in_rc_path = try comp.local_cache_directory.join(comp.gpa, &.{
                o_sub_path, rc_basename,
            });
            const out_res_path = try comp.local_cache_directory.join(comp.gpa, &.{
                o_sub_path, res_basename,
            });

            // In .rc files, a " within a quoted string is escaped as ""
            const fmtRcEscape = struct {
                fn formatRcEscape(bytes: []const u8, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
                    _ = fmt;
                    _ = options;
                    for (bytes) |byte| switch (byte) {
                        '"' => try writer.writeAll("\"\""),
                        '\\' => try writer.writeAll("\\\\"),
                        else => try writer.writeByte(byte),
                    };
                }

                pub fn fmtRcEscape(bytes: []const u8) std.fmt.Formatter(formatRcEscape) {
                    return .{ .data = bytes };
                }
            }.fmtRcEscape;

            // https://learn.microsoft.com/en-us/windows/win32/sbscs/using-side-by-side-assemblies-as-a-resource
            // WinUser.h defines:
            // CREATEPROCESS_MANIFEST_RESOURCE_ID to 1, which is the default
            // ISOLATIONAWARE_MANIFEST_RESOURCE_ID to 2, which must be used for .dlls
            const resource_id: u32 = if (comp.config.output_mode == .Lib and comp.config.link_mode == .dynamic) 2 else 1;

            // 24 is RT_MANIFEST
            const resource_type = 24;

            const input = try std.fmt.allocPrint(arena, "{} {} \"{s}\"", .{ resource_id, resource_type, fmtRcEscape(src_path) });

            try o_dir.writeFile(.{ .sub_path = rc_basename, .data = input });

            var argv = std.ArrayList([]const u8).init(comp.gpa);
            defer argv.deinit();

            try argv.appendSlice(&.{
                self_exe_path,
                "rc",
                "--zig-integration",
                "/:no-preprocess",
                "/x", // ignore INCLUDE environment variable
                "/c65001", // UTF-8 codepage
                "/:auto-includes",
                "none",
            });
            try argv.appendSlice(&.{ "--", in_rc_path, out_res_path });

            try spawnZigRc(comp, win32_resource, arena, argv.items, child_progress_node);

            break :blk digest;
        };

        if (man.have_exclusive_lock) {
            man.writeManifest() catch |err| {
                log.warn("failed to write cache manifest when compiling '{s}': {s}", .{ src_path, @errorName(err) });
            };
        }

        win32_resource.status = .{
            .success = .{
                .res_path = try comp.local_cache_directory.join(comp.gpa, &[_][]const u8{
                    "o", &digest, res_basename,
                }),
                .lock = man.toOwnedLock(),
            },
        };
        return;
    }

    // We now know that we're compiling an .rc file
    const rc_src = win32_resource.src.rc;

    _ = try man.addFile(rc_src.src_path, null);
    man.hash.addListOfBytes(rc_src.extra_flags);

    const rc_basename_noext = src_basename[0 .. src_basename.len - std.fs.path.extension(src_basename).len];

    const digest = if (try man.hit()) man.final() else blk: {
        var zig_cache_tmp_dir = try comp.local_cache_directory.handle.makeOpenPath("tmp", .{});
        defer zig_cache_tmp_dir.close();

        const res_filename = try std.fmt.allocPrint(arena, "{s}.res", .{rc_basename_noext});

        // We can't know the digest until we do the compilation,
        // so we need a temporary filename.
        const out_res_path = try comp.tmpFilePath(arena, res_filename);

        var argv = std.ArrayList([]const u8).init(comp.gpa);
        defer argv.deinit();

        const depfile_filename = try std.fmt.allocPrint(arena, "{s}.d.json", .{rc_basename_noext});
        const out_dep_path = try comp.tmpFilePath(arena, depfile_filename);
        try argv.appendSlice(&.{
            self_exe_path,
            "rc",
            "--zig-integration",
            "/:depfile",
            out_dep_path,
            "/:depfile-fmt",
            "json",
            "/x", // ignore INCLUDE environment variable
            "/:auto-includes",
            @tagName(comp.rc_includes),
        });
        // While these defines are not normally present when calling rc.exe directly,
        // them being defined matches the behavior of how MSVC calls rc.exe which is the more
        // relevant behavior in this case.
        switch (rc_src.owner.optimize_mode) {
            .Debug => try argv.append("-D_DEBUG"),
            .ReleaseSafe => {},
            .ReleaseFast, .ReleaseSmall => try argv.append("-DNDEBUG"),
        }
        try argv.appendSlice(rc_src.extra_flags);
        try argv.appendSlice(&.{ "--", rc_src.src_path, out_res_path });

        try spawnZigRc(comp, win32_resource, arena, argv.items, child_progress_node);

        // Read depfile and update cache manifest
        {
            const dep_basename = std.fs.path.basename(out_dep_path);
            const dep_file_contents = try zig_cache_tmp_dir.readFileAlloc(arena, dep_basename, 50 * 1024 * 1024);
            defer arena.free(dep_file_contents);

            const value = try std.json.parseFromSliceLeaky(std.json.Value, arena, dep_file_contents, .{});
            if (value != .array) {
                return comp.failWin32Resource(win32_resource, "depfile from zig rc has unexpected format", .{});
            }

            for (value.array.items) |element| {
                if (element != .string) {
                    return comp.failWin32Resource(win32_resource, "depfile from zig rc has unexpected format", .{});
                }
                const dep_file_path = element.string;
                try man.addFilePost(dep_file_path);
                switch (comp.cache_use) {
                    .whole => |whole| if (whole.cache_manifest) |whole_cache_manifest| {
                        whole.cache_manifest_mutex.lock();
                        defer whole.cache_manifest_mutex.unlock();
                        try whole_cache_manifest.addFilePost(dep_file_path);
                    },
                    .incremental => {},
                }
            }
        }

        // Rename into place.
        const digest = man.final();
        const o_sub_path = try std.fs.path.join(arena, &[_][]const u8{ "o", &digest });
        var o_dir = try comp.local_cache_directory.handle.makeOpenPath(o_sub_path, .{});
        defer o_dir.close();
        const tmp_basename = std.fs.path.basename(out_res_path);
        try std.fs.rename(zig_cache_tmp_dir, tmp_basename, o_dir, res_filename);
        break :blk digest;
    };

    if (man.have_exclusive_lock) {
        // Write the updated manifest. This is a no-op if the manifest is not dirty. Note that it is
        // possible we had a hit and the manifest is dirty, for example if the file mtime changed but
        // the contents were the same, we hit the cache but the manifest is dirty and we need to update
        // it to prevent doing a full file content comparison the next time around.
        man.writeManifest() catch |err| {
            log.warn("failed to write cache manifest when compiling '{s}': {s}", .{ rc_src.src_path, @errorName(err) });
        };
    }

    const res_basename = try std.fmt.allocPrint(arena, "{s}.res", .{rc_basename_noext});

    win32_resource.status = .{
        .success = .{
            .res_path = try comp.local_cache_directory.join(comp.gpa, &[_][]const u8{
                "o", &digest, res_basename,
            }),
            .lock = man.toOwnedLock(),
        },
    };
}

fn spawnZigRc(
    comp: *Compilation,
    win32_resource: *Win32Resource,
    arena: Allocator,
    argv: []const []const u8,
    child_progress_node: std.Progress.Node,
) !void {
    var node_name: std.ArrayListUnmanaged(u8) = .empty;
    defer node_name.deinit(arena);

    var child = std.process.Child.init(argv, arena);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.progress_node = child_progress_node;

    child.spawn() catch |err| {
        return comp.failWin32Resource(win32_resource, "unable to spawn {s} rc: {s}", .{ argv[0], @errorName(err) });
    };

    var poller = std.io.poll(comp.gpa, enum { stdout }, .{
        .stdout = child.stdout.?,
    });
    defer poller.deinit();

    const stdout = poller.fifo(.stdout);

    poll: while (true) {
        while (stdout.readableLength() < @sizeOf(std.zig.Server.Message.Header)) {
            if (!(try poller.poll())) break :poll;
        }
        const header = stdout.reader().readStruct(std.zig.Server.Message.Header) catch unreachable;
        while (stdout.readableLength() < header.bytes_len) {
            if (!(try poller.poll())) break :poll;
        }
        const body = stdout.readableSliceOfLen(header.bytes_len);

        switch (header.tag) {
            // We expect exactly one ErrorBundle, and if any error_bundle header is
            // sent then it's a fatal error.
            .error_bundle => {
                const EbHdr = std.zig.Server.Message.ErrorBundle;
                const eb_hdr = @as(*align(1) const EbHdr, @ptrCast(body));
                const extra_bytes =
                    body[@sizeOf(EbHdr)..][0 .. @sizeOf(u32) * eb_hdr.extra_len];
                const string_bytes =
                    body[@sizeOf(EbHdr) + extra_bytes.len ..][0..eb_hdr.string_bytes_len];
                const unaligned_extra = std.mem.bytesAsSlice(u32, extra_bytes);
                const extra_array = try comp.gpa.alloc(u32, unaligned_extra.len);
                @memcpy(extra_array, unaligned_extra);
                const error_bundle = std.zig.ErrorBundle{
                    .string_bytes = try comp.gpa.dupe(u8, string_bytes),
                    .extra = extra_array,
                };
                return comp.failWin32ResourceWithOwnedBundle(win32_resource, error_bundle);
            },
            else => {}, // ignore other messages
        }

        stdout.discard(body.len);
    }

    // Just in case there's a failure that didn't send an ErrorBundle (e.g. an error return trace)
    const stderr_reader = child.stderr.?.reader();
    const stderr = try stderr_reader.readAllAlloc(arena, 10 * 1024 * 1024);

    const term = child.wait() catch |err| {
        return comp.failWin32Resource(win32_resource, "unable to wait for {s} rc: {s}", .{ argv[0], @errorName(err) });
    };

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                log.err("zig rc failed with stderr:\n{s}", .{stderr});
                return comp.failWin32Resource(win32_resource, "zig rc exited with code {d}", .{code});
            }
        },
        else => {
            log.err("zig rc terminated with stderr:\n{s}", .{stderr});
            return comp.failWin32Resource(win32_resource, "zig rc terminated unexpectedly", .{});
        },
    }
}

pub fn tmpFilePath(comp: Compilation, ally: Allocator, suffix: []const u8) error{OutOfMemory}![]const u8 {
    const s = std.fs.path.sep_str;
    const rand_int = std.crypto.random.int(u64);
    if (comp.local_cache_directory.path) |p| {
        return std.fmt.allocPrint(ally, "{s}" ++ s ++ "tmp" ++ s ++ "{x}-{s}", .{ p, rand_int, suffix });
    } else {
        return std.fmt.allocPrint(ally, "tmp" ++ s ++ "{x}-{s}", .{ rand_int, suffix });
    }
}

pub fn addTranslateCCArgs(
    comp: *Compilation,
    arena: Allocator,
    argv: *std.ArrayList([]const u8),
    ext: FileExt,
    out_dep_path: ?[]const u8,
    owner_mod: *Package.Module,
) !void {
    try argv.appendSlice(&.{ "-x", "c" });
    try comp.addCCArgs(arena, argv, ext, out_dep_path, owner_mod);
    // This gives us access to preprocessing entities, presumably at the cost of performance.
    try argv.appendSlice(&.{ "-Xclang", "-detailed-preprocessing-record" });
}

/// Add common C compiler args between translate-c and C object compilation.
pub fn addCCArgs(
    comp: *const Compilation,
    arena: Allocator,
    argv: *std.ArrayList([]const u8),
    ext: FileExt,
    out_dep_path: ?[]const u8,
    mod: *Package.Module,
) !void {
    const target = mod.resolved_target.result;

    // As of Clang 16.x, it will by default read extra flags from /etc/clang.
    // I'm sure the person who implemented this means well, but they have a lot
    // to learn about abstractions and where the appropriate boundaries between
    // them are. The road to hell is paved with good intentions. Fortunately it
    // can be disabled.
    try argv.append("--no-default-config");

    // We don't ever put `-fcolor-diagnostics` or `-fno-color-diagnostics` because in passthrough mode
    // we want Clang to infer it, and in normal mode we always want it off, which will be true since
    // clang will detect stderr as a pipe rather than a terminal.
    if (!comp.clang_passthrough_mode and ext.clangSupportsDiagnostics()) {
        // Make stderr more easily parseable.
        try argv.append("-fno-caret-diagnostics");
    }

    // We never want clang to invoke the system assembler for anything. So we would want
    // this option always enabled. However, it only matters for some targets. To avoid
    // "unused parameter" warnings, and to keep CLI spam to a minimum, we only put this
    // flag on the command line if it is necessary.
    if (target_util.clangMightShellOutForAssembly(target)) {
        try argv.append("-integrated-as");
    }

    const llvm_triple = try @import("codegen/llvm.zig").targetTriple(arena, target);
    try argv.appendSlice(&[_][]const u8{ "-target", llvm_triple });

    if (target.cpu.arch.isArm()) {
        try argv.append(if (target.cpu.arch.isThumb()) "-mthumb" else "-mno-thumb");
    }

    if (target_util.llvmMachineAbi(target)) |mabi| {
        try argv.append(try std.fmt.allocPrint(arena, "-mabi={s}", .{mabi}));
    }

    // We might want to support -mfloat-abi=softfp for Arm and CSKY here in the future.
    if (target_util.clangSupportsFloatAbiArg(target)) {
        const fabi = @tagName(target.floatAbi());

        try argv.append(switch (target.cpu.arch) {
            // For whatever reason, Clang doesn't support `-mfloat-abi` for s390x.
            .s390x => try std.fmt.allocPrint(arena, "-m{s}-float", .{fabi}),
            else => try std.fmt.allocPrint(arena, "-mfloat-abi={s}", .{fabi}),
        });
    }

    if (target_util.supports_fpic(target)) {
        try argv.append(if (mod.pic) "-fPIC" else "-fno-PIC");
    }

    if (comp.mingw_unicode_entry_point) {
        try argv.append("-municode");
    }

    if (mod.code_model != .default) {
        try argv.append(try std.fmt.allocPrint(arena, "-mcmodel={s}", .{@tagName(mod.code_model)}));
    }

    try argv.ensureUnusedCapacity(2);
    switch (comp.config.debug_format) {
        .strip => {},
        .code_view => {
            // -g is required here because -gcodeview doesn't trigger debug info
            // generation, it only changes the type of information generated.
            argv.appendSliceAssumeCapacity(&.{ "-g", "-gcodeview" });
        },
        .dwarf => |f| {
            argv.appendAssumeCapacity("-gdwarf-4");
            switch (f) {
                .@"32" => argv.appendAssumeCapacity("-gdwarf32"),
                .@"64" => argv.appendAssumeCapacity("-gdwarf64"),
            }
        },
    }

    switch (comp.config.lto) {
        .none => try argv.append("-fno-lto"),
        .full => try argv.append("-flto=full"),
        .thin => try argv.append("-flto=thin"),
    }

    // This only works for preprocessed files. Guarded by `FileExt.clangSupportsDepFile`.
    if (out_dep_path) |p| {
        try argv.appendSlice(&[_][]const u8{ "-MD", "-MV", "-MF", p });
    }

    // Non-preprocessed assembly files don't support these flags.
    if (ext != .assembly) {
        try argv.append(if (target.os.tag == .freestanding) "-ffreestanding" else "-fhosted");

        if (target_util.clangSupportsNoImplicitFloatArg(target) and target.floatAbi() == .soft) {
            try argv.append("-mno-implicit-float");
        }

        if (target_util.hasRedZone(target)) {
            try argv.append(if (mod.red_zone) "-mred-zone" else "-mno-red-zone");
        }

        try argv.append(if (mod.omit_frame_pointer) "-fomit-frame-pointer" else "-fno-omit-frame-pointer");

        const ssp_buf_size = mod.stack_protector;
        if (ssp_buf_size != 0) {
            try argv.appendSlice(&[_][]const u8{
                "-fstack-protector-strong",
                "--param",
                try std.fmt.allocPrint(arena, "ssp-buffer-size={d}", .{ssp_buf_size}),
            });
        } else {
            try argv.append("-fno-stack-protector");
        }

        try argv.append(if (mod.no_builtin) "-fno-builtin" else "-fbuiltin");

        try argv.append(if (comp.function_sections) "-ffunction-sections" else "-fno-function-sections");
        try argv.append(if (comp.data_sections) "-fdata-sections" else "-fno-data-sections");

        switch (mod.unwind_tables) {
            .none => {
                try argv.append("-fno-unwind-tables");
                try argv.append("-fno-asynchronous-unwind-tables");
            },
            .sync => {
                // Need to override Clang's convoluted default logic.
                try argv.append("-fno-asynchronous-unwind-tables");
                try argv.append("-funwind-tables");
            },
            .@"async" => try argv.append("-fasynchronous-unwind-tables"),
        }

        try argv.append("-nostdinc");

        if (ext == .cpp or ext == .hpp) {
            try argv.append("-nostdinc++");
        }

        // LLVM IR files don't support these flags.
        if (ext != .ll and ext != .bc) {
            // https://github.com/llvm/llvm-project/issues/105972
            if (target.cpu.arch.isPowerPC() and target.floatAbi() == .soft) {
                try argv.append("-D__NO_FPRS__");
                try argv.append("-D_SOFT_FLOAT");
                try argv.append("-D_SOFT_DOUBLE");
            }

            if (comp.config.link_libc) {
                if (target.isGnuLibC()) {
                    const target_version = target.os.versionRange().gnuLibCVersion().?;
                    const glibc_minor_define = try std.fmt.allocPrint(arena, "-D__GLIBC_MINOR__={d}", .{
                        target_version.minor,
                    });
                    try argv.append(glibc_minor_define);
                } else if (target.isMinGW()) {
                    try argv.append("-D__MSVCRT_VERSION__=0xE00"); // use ucrt

                    const minver: u16 = @truncate(@intFromEnum(target.os.versionRange().windows.min) >> 16);
                    try argv.append(
                        try std.fmt.allocPrint(arena, "-D_WIN32_WINNT=0x{x:0>4}", .{minver}),
                    );
                }
            }

            if (comp.config.link_libcpp) {
                try argv.append("-isystem");
                try argv.append(try std.fs.path.join(arena, &[_][]const u8{
                    comp.zig_lib_directory.path.?, "libcxx", "include",
                }));

                try argv.append("-isystem");
                try argv.append(try std.fs.path.join(arena, &[_][]const u8{
                    comp.zig_lib_directory.path.?, "libcxxabi", "include",
                }));

                if (target.abi.isMusl()) {
                    try argv.append("-D_LIBCPP_HAS_MUSL_LIBC");
                }

                try argv.append("-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS");
                try argv.append("-D_LIBCPP_HAS_NO_VENDOR_AVAILABILITY_ANNOTATIONS");
                try argv.append("-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS");

                if (!comp.config.any_non_single_threaded) {
                    try argv.append("-D_LIBCPP_HAS_NO_THREADS");
                }

                // See the comment in libcxx.zig for more details about this.
                try argv.append("-D_LIBCPP_PSTL_BACKEND_SERIAL");

                try argv.append(try std.fmt.allocPrint(arena, "-D_LIBCPP_ABI_VERSION={d}", .{
                    @intFromEnum(comp.libcxx_abi_version),
                }));
                try argv.append(try std.fmt.allocPrint(arena, "-D_LIBCPP_ABI_NAMESPACE=__{d}", .{
                    @intFromEnum(comp.libcxx_abi_version),
                }));

                try argv.append(libcxx.hardeningModeFlag(mod.optimize_mode));
            }

            // According to Rich Felker libc headers are supposed to go before C language headers.
            // However as noted by @dimenus, appending libc headers before compiler headers breaks
            // intrinsics and other compiler specific items.
            try argv.append("-isystem");
            try argv.append(try std.fs.path.join(arena, &[_][]const u8{ comp.zig_lib_directory.path.?, "include" }));

            try argv.ensureUnusedCapacity(comp.libc_include_dir_list.len * 2);
            for (comp.libc_include_dir_list) |include_dir| {
                try argv.append("-isystem");
                try argv.append(include_dir);
            }

            if (mod.resolved_target.is_native_os and mod.resolved_target.is_native_abi) {
                try argv.ensureUnusedCapacity(comp.native_system_include_paths.len * 2);
                for (comp.native_system_include_paths) |include_path| {
                    argv.appendAssumeCapacity("-isystem");
                    argv.appendAssumeCapacity(include_path);
                }
            }

            if (comp.config.link_libunwind) {
                try argv.append("-isystem");
                try argv.append(try std.fs.path.join(arena, &[_][]const u8{
                    comp.zig_lib_directory.path.?, "libunwind", "include",
                }));
            }

            try argv.ensureUnusedCapacity(comp.libc_framework_dir_list.len * 2);
            for (comp.libc_framework_dir_list) |framework_dir| {
                try argv.appendSlice(&.{ "-iframework", framework_dir });
            }

            try argv.ensureUnusedCapacity(comp.framework_dirs.len * 2);
            for (comp.framework_dirs) |framework_dir| {
                try argv.appendSlice(&.{ "-F", framework_dir });
            }
        }
    }

    // Only assembly files support these flags.
    switch (ext) {
        .assembly,
        .assembly_with_cpp,
        => {
            // The Clang assembler does not accept the list of CPU features like the
            // compiler frontend does. Therefore we must hard-code the -m flags for
            // all CPU features here.
            switch (target.cpu.arch) {
                .riscv32, .riscv64 => {
                    const RvArchFeat = struct { char: u8, feat: std.Target.riscv.Feature };
                    const letters = [_]RvArchFeat{
                        .{ .char = 'm', .feat = .m },
                        .{ .char = 'a', .feat = .a },
                        .{ .char = 'f', .feat = .f },
                        .{ .char = 'd', .feat = .d },
                        .{ .char = 'c', .feat = .c },
                    };
                    const prefix: []const u8 = if (target.cpu.arch == .riscv64) "rv64" else "rv32";
                    const prefix_len = 4;
                    assert(prefix.len == prefix_len);
                    var march_buf: [prefix_len + letters.len + 1]u8 = undefined;
                    var march_index: usize = prefix_len;
                    @memcpy(march_buf[0..prefix.len], prefix);

                    if (std.Target.riscv.featureSetHas(target.cpu.features, .e)) {
                        march_buf[march_index] = 'e';
                    } else {
                        march_buf[march_index] = 'i';
                    }
                    march_index += 1;

                    for (letters) |letter| {
                        if (std.Target.riscv.featureSetHas(target.cpu.features, letter.feat)) {
                            march_buf[march_index] = letter.char;
                            march_index += 1;
                        }
                    }

                    const march_arg = try std.fmt.allocPrint(arena, "-march={s}", .{
                        march_buf[0..march_index],
                    });
                    try argv.append(march_arg);

                    if (std.Target.riscv.featureSetHas(target.cpu.features, .relax)) {
                        try argv.append("-mrelax");
                    } else {
                        try argv.append("-mno-relax");
                    }
                    if (std.Target.riscv.featureSetHas(target.cpu.features, .save_restore)) {
                        try argv.append("-msave-restore");
                    } else {
                        try argv.append("-mno-save-restore");
                    }
                },
                .mips, .mipsel, .mips64, .mips64el => {
                    if (target.cpu.model.llvm_name) |llvm_name| {
                        try argv.append(try std.fmt.allocPrint(arena, "-march={s}", .{llvm_name}));
                    }
                },
                else => {
                    // TODO
                },
            }

            if (target_util.clangAssemblerSupportsMcpuArg(target)) {
                if (target.cpu.model.llvm_name) |llvm_name| {
                    try argv.append(try std.fmt.allocPrint(arena, "-mcpu={s}", .{llvm_name}));
                }
            }
        },
        else => {},
    }

    // Only C-family files support these flags.
    switch (ext) {
        .c,
        .h,
        .cpp,
        .hpp,
        .m,
        .hm,
        .mm,
        .hmm,
        => {
            try argv.append("-fno-spell-checking");

            if (target_util.clangSupportsTargetCpuArg(target)) {
                if (target.cpu.model.llvm_name) |llvm_name| {
                    try argv.appendSlice(&[_][]const u8{
                        "-Xclang", "-target-cpu", "-Xclang", llvm_name,
                    });
                }
            }

            // It would be really nice if there was a more compact way to communicate this info to Clang.
            const all_features_list = target.cpu.arch.allFeaturesList();
            try argv.ensureUnusedCapacity(all_features_list.len * 4);
            for (all_features_list, 0..) |feature, index_usize| {
                const index = @as(std.Target.Cpu.Feature.Set.Index, @intCast(index_usize));
                const is_enabled = target.cpu.features.isEnabled(index);

                if (feature.llvm_name) |llvm_name| {
                    // We communicate float ABI to Clang through the dedicated options further down.
                    if (std.mem.eql(u8, llvm_name, "soft-float")) continue;

                    argv.appendSliceAssumeCapacity(&[_][]const u8{ "-Xclang", "-target-feature", "-Xclang" });
                    const plus_or_minus = "-+"[@intFromBool(is_enabled)];
                    const arg = try std.fmt.allocPrint(arena, "{c}{s}", .{ plus_or_minus, llvm_name });
                    argv.appendAssumeCapacity(arg);
                }
            }

            switch (target.os.tag) {
                .windows => {
                    // windows.h has files such as pshpack1.h which do #pragma packing,
                    // triggering a clang warning. So for this target, we disable this warning.
                    if (target.abi.isGnu()) {
                        try argv.append("-Wno-pragma-pack");
                    }
                },
                .macos => {
                    try argv.ensureUnusedCapacity(2);
                    // Pass the proper -m<os>-version-min argument for darwin.
                    const ver = target.os.version_range.semver.min;
                    argv.appendAssumeCapacity(try std.fmt.allocPrint(arena, "-mmacos-version-min={d}.{d}.{d}", .{
                        ver.major, ver.minor, ver.patch,
                    }));
                    // This avoids a warning that sometimes occurs when
                    // providing both a -target argument that contains a
                    // version as well as the -mmacosx-version-min argument.
                    // Zig provides the correct value in both places, so it
                    // doesn't matter which one gets overridden.
                    argv.appendAssumeCapacity("-Wno-overriding-option");
                },
                .ios => switch (target.cpu.arch) {
                    // Pass the proper -m<os>-version-min argument for darwin.
                    .x86, .x86_64 => {
                        const ver = target.os.version_range.semver.min;
                        try argv.append(try std.fmt.allocPrint(
                            arena,
                            "-m{s}-simulator-version-min={d}.{d}.{d}",
                            .{ @tagName(target.os.tag), ver.major, ver.minor, ver.patch },
                        ));
                    },
                    else => {
                        const ver = target.os.version_range.semver.min;
                        try argv.append(try std.fmt.allocPrint(arena, "-m{s}-version-min={d}.{d}.{d}", .{
                            @tagName(target.os.tag), ver.major, ver.minor, ver.patch,
                        }));
                    },
                },
                else => {},
            }

            {
                var san_arg: std.ArrayListUnmanaged(u8) = .empty;
                const prefix = "-fsanitize=";
                if (mod.sanitize_c) {
                    if (san_arg.items.len == 0) try san_arg.appendSlice(arena, prefix);
                    try san_arg.appendSlice(arena, "undefined,");
                }
                if (mod.sanitize_thread) {
                    if (san_arg.items.len == 0) try san_arg.appendSlice(arena, prefix);
                    try san_arg.appendSlice(arena, "thread,");
                }
                if (mod.fuzz) {
                    if (san_arg.items.len == 0) try san_arg.appendSlice(arena, prefix);
                    try san_arg.appendSlice(arena, "fuzzer-no-link,");
                }
                // Chop off the trailing comma and append to argv.
                if (san_arg.pop()) |_| {
                    try argv.append(san_arg.items);

                    // These args have to be added after the `-fsanitize` arg or
                    // they won't take effect.
                    if (mod.sanitize_c) {
                        try argv.append("-fsanitize-trap=undefined");
                        // It is very common, and well-defined, for a pointer on one side of a C ABI
                        // to have a different but compatible element type. Examples include:
                        // `char*` vs `uint8_t*` on a system with 8-bit bytes
                        // `const char*` vs `char*`
                        // `char*` vs `unsigned char*`
                        // Without this flag, Clang would invoke UBSAN when such an extern
                        // function was called.
                        try argv.append("-fno-sanitize=function");
                    }

                    if (comp.config.san_cov_trace_pc_guard) {
                        try argv.appendSlice(&.{ "-Xclang", "-fsanitize-coverage-trace-pc-guard" });
                    }
                }
            }

            switch (mod.optimize_mode) {
                .Debug => {
                    // windows c runtime requires -D_DEBUG if using debug libraries
                    try argv.append("-D_DEBUG");
                    // Clang has -Og for compatibility with GCC, but currently it is just equivalent
                    // to -O1. Besides potentially impairing debugging, -O1/-Og significantly
                    // increases compile times.
                    try argv.append("-O0");
                },
                .ReleaseSafe => {
                    // See the comment in the BuildModeFastRelease case for why we pass -O2 rather
                    // than -O3 here.
                    try argv.append("-O2");
                    try argv.append("-D_FORTIFY_SOURCE=2");
                },
                .ReleaseFast => {
                    try argv.append("-DNDEBUG");
                    // Here we pass -O2 rather than -O3 because, although we do the equivalent of
                    // -O3 in Zig code, the justification for the difference here is that Zig
                    // has better detection and prevention of undefined behavior, so -O3 is safer for
                    // Zig code than it is for C code. Also, C programmers are used to their code
                    // running in -O2 and thus the -O3 path has been tested less.
                    try argv.append("-O2");
                },
                .ReleaseSmall => {
                    try argv.append("-DNDEBUG");
                    try argv.append("-Os");
                },
            }

            if (mod.optimize_mode != .Debug) {
                try argv.append("-Werror=date-time");
            }
        },
        else => {},
    }

    try argv.appendSlice(comp.global_cc_argv);
    try argv.appendSlice(mod.cc_argv);
}

fn failCObj(
    comp: *Compilation,
    c_object: *CObject,
    comptime format: []const u8,
    args: anytype,
) SemaError {
    @branchHint(.cold);
    const diag_bundle = blk: {
        const diag_bundle = try comp.gpa.create(CObject.Diag.Bundle);
        diag_bundle.* = .{};
        errdefer diag_bundle.destroy(comp.gpa);

        try diag_bundle.file_names.ensureTotalCapacity(comp.gpa, 1);
        diag_bundle.file_names.putAssumeCapacity(1, try comp.gpa.dupe(u8, c_object.src.src_path));

        diag_bundle.diags = try comp.gpa.alloc(CObject.Diag, 1);
        diag_bundle.diags[0] = .{};
        diag_bundle.diags[0].level = 3;
        diag_bundle.diags[0].msg = try std.fmt.allocPrint(comp.gpa, format, args);
        diag_bundle.diags[0].src_loc.file = 1;
        break :blk diag_bundle;
    };
    return comp.failCObjWithOwnedDiagBundle(c_object, diag_bundle);
}

fn failCObjWithOwnedDiagBundle(
    comp: *Compilation,
    c_object: *CObject,
    diag_bundle: *CObject.Diag.Bundle,
) SemaError {
    @branchHint(.cold);
    assert(diag_bundle.diags.len > 0);
    {
        comp.mutex.lock();
        defer comp.mutex.unlock();
        {
            errdefer diag_bundle.destroy(comp.gpa);
            try comp.failed_c_objects.ensureUnusedCapacity(comp.gpa, 1);
        }
        comp.failed_c_objects.putAssumeCapacityNoClobber(c_object, diag_bundle);
    }
    c_object.status = .failure;
    return error.AnalysisFail;
}

fn failWin32Resource(comp: *Compilation, win32_resource: *Win32Resource, comptime format: []const u8, args: anytype) SemaError {
    @branchHint(.cold);
    var bundle: ErrorBundle.Wip = undefined;
    try bundle.init(comp.gpa);
    errdefer bundle.deinit();
    try bundle.addRootErrorMessage(.{
        .msg = try bundle.printString(format, args),
        .src_loc = try bundle.addSourceLocation(.{
            .src_path = try bundle.addString(switch (win32_resource.src) {
                .rc => |rc_src| rc_src.src_path,
                .manifest => |manifest_src| manifest_src,
            }),
            .line = 0,
            .column = 0,
            .span_start = 0,
            .span_main = 0,
            .span_end = 0,
        }),
    });
    const finished_bundle = try bundle.toOwnedBundle("");
    return comp.failWin32ResourceWithOwnedBundle(win32_resource, finished_bundle);
}

fn failWin32ResourceWithOwnedBundle(
    comp: *Compilation,
    win32_resource: *Win32Resource,
    err_bundle: ErrorBundle,
) SemaError {
    @branchHint(.cold);
    {
        comp.mutex.lock();
        defer comp.mutex.unlock();
        try comp.failed_win32_resources.putNoClobber(comp.gpa, win32_resource, err_bundle);
    }
    win32_resource.status = .failure;
    return error.AnalysisFail;
}

pub const FileExt = enum {
    c,
    cpp,
    h,
    hpp,
    hm,
    hmm,
    m,
    mm,
    ll,
    bc,
    assembly,
    assembly_with_cpp,
    shared_library,
    object,
    static_library,
    zig,
    def,
    rc,
    res,
    manifest,
    unknown,

    pub fn clangNeedsLanguageOverride(ext: FileExt) bool {
        return switch (ext) {
            .h,
            .hpp,
            .hm,
            .hmm,
            => true,

            .c,
            .cpp,
            .m,
            .mm,
            .ll,
            .bc,
            .assembly,
            .assembly_with_cpp,
            .shared_library,
            .object,
            .static_library,
            .zig,
            .def,
            .rc,
            .res,
            .manifest,
            .unknown,
            => false,
        };
    }

    pub fn clangSupportsDiagnostics(ext: FileExt) bool {
        return switch (ext) {
            .c, .cpp, .h, .hpp, .hm, .hmm, .m, .mm, .ll, .bc => true,

            .assembly,
            .assembly_with_cpp,
            .shared_library,
            .object,
            .static_library,
            .zig,
            .def,
            .rc,
            .res,
            .manifest,
            .unknown,
            => false,
        };
    }

    pub fn clangSupportsDepFile(ext: FileExt) bool {
        return switch (ext) {
            .assembly_with_cpp, .c, .cpp, .h, .hpp, .hm, .hmm, .m, .mm => true,

            .ll,
            .bc,
            .assembly,
            .shared_library,
            .object,
            .static_library,
            .zig,
            .def,
            .rc,
            .res,
            .manifest,
            .unknown,
            => false,
        };
    }

    pub fn canonicalName(ext: FileExt, target: Target) [:0]const u8 {
        return switch (ext) {
            .c => ".c",
            .cpp => ".cpp",
            .h => ".h",
            .hpp => ".hpp",
            .hm => ".hm",
            .hmm => ".hmm",
            .m => ".m",
            .mm => ".mm",
            .ll => ".ll",
            .bc => ".bc",
            .assembly => ".s",
            .assembly_with_cpp => ".S",
            .shared_library => target.dynamicLibSuffix(),
            .object => target.ofmt.fileExt(target.cpu.arch),
            .static_library => target.staticLibSuffix(),
            .zig => ".zig",
            .def => ".def",
            .rc => ".rc",
            .res => ".res",
            .manifest => ".manifest",
            .unknown => "",
        };
    }
};

pub fn hasObjectExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".o") or
        mem.endsWith(u8, filename, ".lo") or
        mem.endsWith(u8, filename, ".obj") or
        mem.endsWith(u8, filename, ".rmeta");
}

pub fn hasStaticLibraryExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".a") or
        mem.endsWith(u8, filename, ".lib") or
        mem.endsWith(u8, filename, ".rlib");
}

pub fn hasCExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".c");
}

pub fn hasCHExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".h");
}

pub fn hasCppExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".C") or
        mem.endsWith(u8, filename, ".cc") or
        mem.endsWith(u8, filename, ".cp") or
        mem.endsWith(u8, filename, ".CPP") or
        mem.endsWith(u8, filename, ".cpp") or
        mem.endsWith(u8, filename, ".cxx") or
        mem.endsWith(u8, filename, ".c++");
}

pub fn hasCppHExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".hh") or
        mem.endsWith(u8, filename, ".hpp") or
        mem.endsWith(u8, filename, ".hxx");
}

pub fn hasObjCExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".m");
}

pub fn hasObjCHExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".hm");
}

pub fn hasObjCppExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".M") or
        mem.endsWith(u8, filename, ".mm");
}

pub fn hasObjCppHExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".hmm");
}

pub fn hasSharedLibraryExt(filename: []const u8) bool {
    if (mem.endsWith(u8, filename, ".so") or
        mem.endsWith(u8, filename, ".dll") or
        mem.endsWith(u8, filename, ".dylib") or
        mem.endsWith(u8, filename, ".tbd"))
    {
        return true;
    }
    // Look for .so.X, .so.X.Y, .so.X.Y.Z
    var it = mem.splitScalar(u8, filename, '.');
    _ = it.first();
    var so_txt = it.next() orelse return false;
    while (!mem.eql(u8, so_txt, "so")) {
        so_txt = it.next() orelse return false;
    }
    const n1 = it.next() orelse return false;
    const n2 = it.next();
    const n3 = it.next();

    _ = std.fmt.parseInt(u32, n1, 10) catch return false;
    if (n2) |x| _ = std.fmt.parseInt(u32, x, 10) catch return false;
    if (n3) |x| _ = std.fmt.parseInt(u32, x, 10) catch return false;
    if (it.next() != null) return false;

    return true;
}

pub fn classifyFileExt(filename: []const u8) FileExt {
    if (hasCExt(filename)) {
        return .c;
    } else if (hasCHExt(filename)) {
        return .h;
    } else if (hasCppExt(filename)) {
        return .cpp;
    } else if (hasCppHExt(filename)) {
        return .hpp;
    } else if (hasObjCExt(filename)) {
        return .m;
    } else if (hasObjCHExt(filename)) {
        return .hm;
    } else if (hasObjCppExt(filename)) {
        return .mm;
    } else if (hasObjCppHExt(filename)) {
        return .hmm;
    } else if (mem.endsWith(u8, filename, ".ll")) {
        return .ll;
    } else if (mem.endsWith(u8, filename, ".bc")) {
        return .bc;
    } else if (mem.endsWith(u8, filename, ".s")) {
        return .assembly;
    } else if (mem.endsWith(u8, filename, ".S")) {
        return .assembly_with_cpp;
    } else if (mem.endsWith(u8, filename, ".zig")) {
        return .zig;
    } else if (hasSharedLibraryExt(filename)) {
        return .shared_library;
    } else if (hasStaticLibraryExt(filename)) {
        return .static_library;
    } else if (hasObjectExt(filename)) {
        return .object;
    } else if (mem.endsWith(u8, filename, ".def")) {
        return .def;
    } else if (std.ascii.endsWithIgnoreCase(filename, ".rc")) {
        return .rc;
    } else if (std.ascii.endsWithIgnoreCase(filename, ".res")) {
        return .res;
    } else if (std.ascii.endsWithIgnoreCase(filename, ".manifest")) {
        return .manifest;
    } else {
        return .unknown;
    }
}

test "classifyFileExt" {
    try std.testing.expectEqual(FileExt.cpp, classifyFileExt("foo.cc"));
    try std.testing.expectEqual(FileExt.m, classifyFileExt("foo.m"));
    try std.testing.expectEqual(FileExt.mm, classifyFileExt("foo.mm"));
    try std.testing.expectEqual(FileExt.unknown, classifyFileExt("foo.nim"));
    try std.testing.expectEqual(FileExt.shared_library, classifyFileExt("foo.so"));
    try std.testing.expectEqual(FileExt.shared_library, classifyFileExt("foo.so.1"));
    try std.testing.expectEqual(FileExt.shared_library, classifyFileExt("foo.so.1.2"));
    try std.testing.expectEqual(FileExt.shared_library, classifyFileExt("foo.so.1.2.3"));
    try std.testing.expectEqual(FileExt.unknown, classifyFileExt("foo.so.1.2.3~"));
    try std.testing.expectEqual(FileExt.zig, classifyFileExt("foo.zig"));
}

fn get_libc_crt_file(comp: *Compilation, arena: Allocator, basename: []const u8) !Path {
    return (try crtFilePath(&comp.crt_files, basename)) orelse {
        const lci = comp.libc_installation orelse return error.LibCInstallationNotAvailable;
        const crt_dir_path = lci.crt_dir orelse return error.LibCInstallationMissingCrtDir;
        const full_path = try std.fs.path.join(arena, &[_][]const u8{ crt_dir_path, basename });
        return Path.initCwd(full_path);
    };
}

pub fn crtFileAsString(comp: *Compilation, arena: Allocator, basename: []const u8) ![]const u8 {
    const path = try get_libc_crt_file(comp, arena, basename);
    return path.toString(arena);
}

fn crtFilePath(crt_files: *std.StringHashMapUnmanaged(CrtFile), basename: []const u8) Allocator.Error!?Path {
    const crt_file = crt_files.get(basename) orelse return null;
    return crt_file.full_object_path;
}

fn wantBuildLibUnwindFromSource(comp: *Compilation) bool {
    const is_exe_or_dyn_lib = switch (comp.config.output_mode) {
        .Obj => false,
        .Lib => comp.config.link_mode == .dynamic,
        .Exe => true,
    };
    const ofmt = comp.root_mod.resolved_target.result.ofmt;
    return is_exe_or_dyn_lib and comp.config.link_libunwind and ofmt != .c;
}

pub fn setAllocFailure(comp: *Compilation) void {
    @branchHint(.cold);
    log.debug("memory allocation failure", .{});
    comp.alloc_failure_occurred = true;
}

/// Assumes that Compilation mutex is locked.
/// See also `lockAndSetMiscFailure`.
pub fn setMiscFailure(
    comp: *Compilation,
    tag: MiscTask,
    comptime format: []const u8,
    args: anytype,
) void {
    comp.misc_failures.ensureUnusedCapacity(comp.gpa, 1) catch return comp.setAllocFailure();
    const msg = std.fmt.allocPrint(comp.gpa, format, args) catch return comp.setAllocFailure();
    const gop = comp.misc_failures.getOrPutAssumeCapacity(tag);
    if (gop.found_existing) {
        gop.value_ptr.deinit(comp.gpa);
    }
    gop.value_ptr.* = .{ .msg = msg };
}

/// See also `setMiscFailure`.
pub fn lockAndSetMiscFailure(
    comp: *Compilation,
    tag: MiscTask,
    comptime format: []const u8,
    args: anytype,
) void {
    comp.mutex.lock();
    defer comp.mutex.unlock();

    return setMiscFailure(comp, tag, format, args);
}

pub fn dump_argv(argv: []const []const u8) void {
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    for (argv[0 .. argv.len - 1]) |arg| {
        nosuspend stderr.print("{s} ", .{arg}) catch return;
    }
    nosuspend stderr.print("{s}\n", .{argv[argv.len - 1]}) catch {};
}

fn canBuildLibCompilerRt(target: std.Target, use_llvm: bool) bool {
    switch (target.os.tag) {
        .plan9 => return false,
        else => {},
    }
    switch (target.cpu.arch) {
        .spirv, .spirv32, .spirv64 => return false,
        else => {},
    }
    return switch (target_util.zigBackend(target, use_llvm)) {
        .stage2_llvm => true,
        .stage2_x86_64 => if (target.ofmt == .elf or target.ofmt == .macho) true else build_options.have_llvm,
        else => build_options.have_llvm,
    };
}

/// Not to be confused with canBuildLibC, which builds musl, glibc, and similar.
/// This one builds lib/c.zig.
fn canBuildZigLibC(target: std.Target, use_llvm: bool) bool {
    switch (target.os.tag) {
        .plan9 => return false,
        else => {},
    }
    switch (target.cpu.arch) {
        .spirv, .spirv32, .spirv64 => return false,
        else => {},
    }
    return switch (target_util.zigBackend(target, use_llvm)) {
        .stage2_llvm => true,
        .stage2_riscv64 => true,
        .stage2_x86_64 => if (target.ofmt == .elf or target.ofmt == .macho) true else build_options.have_llvm,
        else => build_options.have_llvm,
    };
}

pub fn getZigBackend(comp: Compilation) std.builtin.CompilerBackend {
    const target = comp.root_mod.resolved_target.result;
    return target_util.zigBackend(target, comp.config.use_llvm);
}

pub fn updateSubCompilation(
    parent_comp: *Compilation,
    sub_comp: *Compilation,
    misc_task: MiscTask,
    prog_node: std.Progress.Node,
) !void {
    {
        const sub_node = prog_node.start(@tagName(misc_task), 0);
        defer sub_node.end();

        try sub_comp.update(sub_node);
    }

    // Look for compilation errors in this sub compilation
    const gpa = parent_comp.gpa;
    var keep_errors = false;
    var errors = try sub_comp.getAllErrorsAlloc();
    defer if (!keep_errors) errors.deinit(gpa);

    if (errors.errorMessageCount() > 0) {
        try parent_comp.misc_failures.ensureUnusedCapacity(gpa, 1);
        parent_comp.misc_failures.putAssumeCapacityNoClobber(misc_task, .{
            .msg = try std.fmt.allocPrint(gpa, "sub-compilation of {s} failed", .{
                @tagName(misc_task),
            }),
            .children = errors,
        });
        keep_errors = true;
        return error.SubCompilationFailed;
    }
}

fn buildOutputFromZig(
    comp: *Compilation,
    src_basename: []const u8,
    output_mode: std.builtin.OutputMode,
    allow_lto: bool,
    out: *?CrtFile,
    misc_task_tag: MiscTask,
    prog_node: std.Progress.Node,
) !void {
    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    const gpa = comp.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    assert(output_mode != .Exe);

    const strip = comp.compilerRtStrip();
    const optimize_mode = comp.compilerRtOptMode();

    const config = try Config.resolve(.{
        .output_mode = output_mode,
        .link_mode = .static,
        .resolved_target = comp.root_mod.resolved_target,
        .is_test = false,
        .have_zcu = true,
        .emit_bin = true,
        .root_optimize_mode = optimize_mode,
        .root_strip = strip,
        .link_libc = comp.config.link_libc,
        .any_unwind_tables = comp.root_mod.unwind_tables != .none,
        .any_error_tracing = false,
        .root_error_tracing = false,
        .lto = if (allow_lto) comp.config.lto else .none,
    });

    const root_mod = try Package.Module.create(arena, .{
        .global_cache_directory = comp.global_cache_directory,
        .paths = .{
            .root = .{ .root_dir = comp.zig_lib_directory },
            .root_src_path = src_basename,
        },
        .fully_qualified_name = "root",
        .inherited = .{
            .resolved_target = comp.root_mod.resolved_target,
            .strip = strip,
            .stack_check = false,
            .stack_protector = 0,
            .red_zone = comp.root_mod.red_zone,
            .omit_frame_pointer = comp.root_mod.omit_frame_pointer,
            .unwind_tables = comp.root_mod.unwind_tables,
            .pic = comp.root_mod.pic,
            .optimize_mode = optimize_mode,
            .structured_cfg = comp.root_mod.structured_cfg,
            .no_builtin = true,
            .code_model = comp.root_mod.code_model,
            .error_tracing = false,
        },
        .global = config,
        .cc_argv = &.{},
        .parent = null,
        .builtin_mod = null,
        .builtin_modules = null, // there is only one module in this compilation
    });
    const root_name = src_basename[0 .. src_basename.len - std.fs.path.extension(src_basename).len];
    const target = comp.getTarget();
    const bin_basename = try std.zig.binNameAlloc(arena, .{
        .root_name = root_name,
        .target = target,
        .output_mode = output_mode,
    });

    const parent_whole_cache: ?ParentWholeCache = switch (comp.cache_use) {
        .whole => |whole| .{
            .manifest = whole.cache_manifest.?,
            .mutex = &whole.cache_manifest_mutex,
            .prefix_map = .{
                0, // cwd is the same
                1, // zig lib dir is the same
                3, // local cache is mapped to global cache
                3, // global cache is the same
            },
        },
        .incremental => null,
    };

    const sub_compilation = try Compilation.create(gpa, arena, .{
        .global_cache_directory = comp.global_cache_directory,
        .local_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .cache_mode = .whole,
        .parent_whole_cache = parent_whole_cache,
        .self_exe_path = comp.self_exe_path,
        .config = config,
        .root_mod = root_mod,
        .root_name = root_name,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.libc_installation,
        .emit_bin = .{
            .directory = null, // Put it in the cache directory.
            .basename = bin_basename,
        },
        .function_sections = true,
        .data_sections = true,
        .emit_h = null,
        .verbose_cc = comp.verbose_cc,
        .verbose_link = comp.verbose_link,
        .verbose_air = comp.verbose_air,
        .verbose_intern_pool = comp.verbose_intern_pool,
        .verbose_generic_instances = comp.verbose_intern_pool,
        .verbose_llvm_ir = comp.verbose_llvm_ir,
        .verbose_llvm_bc = comp.verbose_llvm_bc,
        .verbose_cimport = comp.verbose_cimport,
        .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
        .clang_passthrough_mode = comp.clang_passthrough_mode,
        .skip_linker_dependencies = true,
    });
    defer sub_compilation.destroy();

    try comp.updateSubCompilation(sub_compilation, misc_task_tag, prog_node);

    const crt_file = try sub_compilation.toCrtFile();
    assert(out.* == null);
    out.* = crt_file;

    comp.queueLinkTaskMode(crt_file.full_object_path, output_mode);
}

pub const CrtFileOptions = struct {
    function_sections: ?bool = null,
    data_sections: ?bool = null,
    omit_frame_pointer: ?bool = null,
    unwind_tables: ?std.builtin.UnwindTables = null,
    pic: ?bool = null,
    no_builtin: ?bool = null,

    allow_lto: bool = true,
};

pub fn build_crt_file(
    comp: *Compilation,
    root_name: []const u8,
    output_mode: std.builtin.OutputMode,
    misc_task_tag: MiscTask,
    prog_node: std.Progress.Node,
    /// These elements have to get mutated to add the owner module after it is
    /// created within this function.
    c_source_files: []CSourceFile,
    options: CrtFileOptions,
) !void {
    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    const gpa = comp.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const basename = try std.zig.binNameAlloc(gpa, .{
        .root_name = root_name,
        .target = comp.root_mod.resolved_target.result,
        .output_mode = output_mode,
    });

    const config = try Config.resolve(.{
        .output_mode = output_mode,
        .resolved_target = comp.root_mod.resolved_target,
        .is_test = false,
        .have_zcu = false,
        .emit_bin = true,
        .root_optimize_mode = comp.compilerRtOptMode(),
        .root_strip = comp.compilerRtStrip(),
        .link_libc = false,
        .any_unwind_tables = options.unwind_tables != .none,
        .lto = switch (output_mode) {
            .Lib => if (options.allow_lto) comp.config.lto else .none,
            .Obj, .Exe => .none,
        },
    });
    const root_mod = try Package.Module.create(arena, .{
        .global_cache_directory = comp.global_cache_directory,
        .paths = .{
            .root = .{ .root_dir = comp.zig_lib_directory },
            .root_src_path = "",
        },
        .fully_qualified_name = "root",
        .inherited = .{
            .resolved_target = comp.root_mod.resolved_target,
            .strip = comp.compilerRtStrip(),
            .stack_check = false,
            .stack_protector = 0,
            .sanitize_c = false,
            .sanitize_thread = false,
            .red_zone = comp.root_mod.red_zone,
            // Some libcs (e.g. musl) are opinionated about -fomit-frame-pointer.
            .omit_frame_pointer = options.omit_frame_pointer orelse comp.root_mod.omit_frame_pointer,
            .valgrind = false,
            // Some libcs (e.g. MinGW) are opinionated about -funwind-tables.
            .unwind_tables = options.unwind_tables orelse .none,
            // Some CRT objects (e.g. musl's rcrt1.o and Scrt1.o) are opinionated about PIC.
            .pic = options.pic orelse comp.root_mod.pic,
            .optimize_mode = comp.compilerRtOptMode(),
            .structured_cfg = comp.root_mod.structured_cfg,
            // Some libcs (e.g. musl) are opinionated about -fno-builtin.
            .no_builtin = options.no_builtin orelse comp.root_mod.no_builtin,
            .code_model = comp.root_mod.code_model,
        },
        .global = config,
        .cc_argv = &.{},
        .parent = null,
        .builtin_mod = null,
        .builtin_modules = null, // there is only one module in this compilation
    });

    for (c_source_files) |*item| {
        item.owner = root_mod;
    }

    const sub_compilation = try Compilation.create(gpa, arena, .{
        .local_cache_directory = comp.global_cache_directory,
        .global_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .self_exe_path = comp.self_exe_path,
        .cache_mode = .whole,
        .config = config,
        .root_mod = root_mod,
        .root_name = root_name,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.libc_installation,
        .emit_bin = .{
            .directory = null, // Put it in the cache directory.
            .basename = basename,
        },
        .function_sections = options.function_sections orelse false,
        .data_sections = options.data_sections orelse false,
        .emit_h = null,
        .c_source_files = c_source_files,
        .verbose_cc = comp.verbose_cc,
        .verbose_link = comp.verbose_link,
        .verbose_air = comp.verbose_air,
        .verbose_intern_pool = comp.verbose_intern_pool,
        .verbose_generic_instances = comp.verbose_generic_instances,
        .verbose_llvm_ir = comp.verbose_llvm_ir,
        .verbose_llvm_bc = comp.verbose_llvm_bc,
        .verbose_cimport = comp.verbose_cimport,
        .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
        .clang_passthrough_mode = comp.clang_passthrough_mode,
        .skip_linker_dependencies = true,
    });
    defer sub_compilation.destroy();

    try comp.updateSubCompilation(sub_compilation, misc_task_tag, prog_node);

    const crt_file = try sub_compilation.toCrtFile();
    comp.queueLinkTaskMode(crt_file.full_object_path, output_mode);

    {
        comp.mutex.lock();
        defer comp.mutex.unlock();
        try comp.crt_files.ensureUnusedCapacity(gpa, 1);
        comp.crt_files.putAssumeCapacityNoClobber(basename, crt_file);
    }
}

pub fn queueLinkTaskMode(comp: *Compilation, path: Path, output_mode: std.builtin.OutputMode) void {
    comp.queueLinkTasks(switch (output_mode) {
        .Exe => unreachable,
        .Obj => &.{.{ .load_object = path }},
        .Lib => &.{.{ .load_archive = path }},
    });
}

/// Only valid to call during `update`. Automatically handles queuing up a
/// linker worker task if there is not already one.
pub fn queueLinkTasks(comp: *Compilation, tasks: []const link.Task) void {
    if (comp.link_task_queue.enqueue(comp.gpa, tasks) catch |err| switch (err) {
        error.OutOfMemory => return comp.setAllocFailure(),
    }) {
        comp.thread_pool.spawnWgId(&comp.link_task_wait_group, link.flushTaskQueue, .{comp});
    }
}

pub fn toCrtFile(comp: *Compilation) Allocator.Error!CrtFile {
    return .{
        .full_object_path = .{
            .root_dir = comp.local_cache_directory,
            .sub_path = try comp.gpa.dupe(u8, comp.cache_use.whole.bin_sub_path.?),
        },
        .lock = comp.cache_use.whole.moveLock(),
    };
}

pub fn getCrtPaths(
    comp: *Compilation,
    arena: Allocator,
) error{ OutOfMemory, LibCInstallationMissingCrtDir }!LibCInstallation.CrtPaths {
    const target = comp.root_mod.resolved_target.result;
    return getCrtPathsInner(arena, target, comp.config, comp.libc_installation, &comp.crt_files);
}

fn getCrtPathsInner(
    arena: Allocator,
    target: std.Target,
    config: Config,
    libc_installation: ?*const LibCInstallation,
    crt_files: *std.StringHashMapUnmanaged(CrtFile),
) error{ OutOfMemory, LibCInstallationMissingCrtDir }!LibCInstallation.CrtPaths {
    const basenames = LibCInstallation.CrtBasenames.get(.{
        .target = target,
        .link_libc = config.link_libc,
        .output_mode = config.output_mode,
        .link_mode = config.link_mode,
        .pie = config.pie,
    });
    if (libc_installation) |lci| return lci.resolveCrtPaths(arena, basenames, target);

    return .{
        .crt0 = if (basenames.crt0) |basename| try crtFilePath(crt_files, basename) else null,
        .crti = if (basenames.crti) |basename| try crtFilePath(crt_files, basename) else null,
        .crtbegin = if (basenames.crtbegin) |basename| try crtFilePath(crt_files, basename) else null,
        .crtend = if (basenames.crtend) |basename| try crtFilePath(crt_files, basename) else null,
        .crtn = if (basenames.crtn) |basename| try crtFilePath(crt_files, basename) else null,
    };
}

pub fn addLinkLib(comp: *Compilation, lib_name: []const u8) !void {
    // Avoid deadlocking on building import libs such as kernel32.lib
    // This can happen when the user uses `build-exe foo.obj -lkernel32` and
    // then when we create a sub-Compilation for zig libc, it also tries to
    // build kernel32.lib.
    if (comp.skip_linker_dependencies) return;
    const target = comp.root_mod.resolved_target.result;
    if (target.os.tag != .windows or target.ofmt == .c) return;

    // This happens when an `extern "foo"` function is referenced.
    // If we haven't seen this library yet and we're targeting Windows, we need
    // to queue up a work item to produce the DLL import library for this.
    const gop = try comp.windows_libs.getOrPut(comp.gpa, lib_name);
    if (!gop.found_existing) try comp.queueJob(.{ .windows_import_lib = comp.windows_libs.count() - 1 });
}

/// This decides the optimization mode for all zig-provided libraries, including
/// compiler-rt, libcxx, libc, libunwind, etc.
pub fn compilerRtOptMode(comp: Compilation) std.builtin.OptimizeMode {
    if (comp.debug_compiler_runtime_libs) {
        return comp.root_mod.optimize_mode;
    }
    const target = comp.root_mod.resolved_target.result;
    switch (comp.root_mod.optimize_mode) {
        .Debug, .ReleaseSafe => return target_util.defaultCompilerRtOptimizeMode(target),
        .ReleaseFast => return .ReleaseFast,
        .ReleaseSmall => return .ReleaseSmall,
    }
}

/// This decides whether to strip debug info for all zig-provided libraries, including
/// compiler-rt, libcxx, libc, libunwind, etc.
pub fn compilerRtStrip(comp: Compilation) bool {
    return comp.root_mod.strip;
}
