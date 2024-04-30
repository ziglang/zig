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

const Value = @import("Value.zig");
const Type = @import("type.zig").Type;
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
const Zcu = @import("Module.zig");
/// Deprecated; use `Zcu`.
const Module = Zcu;
const InternPool = @import("InternPool.zig");
const Cache = std.Build.Cache;
const c_codegen = @import("codegen/c.zig");
const libtsan = @import("libtsan.zig");
const Zir = std.zig.Zir;
const Builtin = @import("Builtin.zig");
const LlvmObject = @import("codegen/llvm.zig").Object;

pub const Config = @import("Compilation/Config.zig");

/// General-purpose allocator. Used for both temporary and long-term storage.
gpa: Allocator,
/// Arena-allocated memory, mostly used during initialization. However, it can
/// be used for other things requiring the same lifetime as the `Compilation`.
arena: Allocator,
/// Not every Compilation compiles .zig code! For example you could do `zig build-exe foo.o`.
/// TODO: rename to zcu: ?*Zcu
module: ?*Module,
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
implib_emit: ?Emit,
/// This is non-null when `-femit-docs` is provided.
docs_emit: ?Emit,
root_name: [:0]const u8,
include_compiler_rt: bool,
objects: []Compilation.LinkObject,
/// Needed only for passing -F args to clang.
framework_dirs: []const []const u8,
/// These are *always* dynamically linked. Static libraries will be
/// provided as positional arguments.
system_libs: std.StringArrayHashMapUnmanaged(SystemLib),
version: ?std.SemanticVersion,
libc_installation: ?*const LibCInstallation,
skip_linker_dependencies: bool,
no_builtin: bool,
function_sections: bool,
data_sections: bool,
link_eh_frame_hdr: bool,
native_system_include_paths: []const []const u8,
/// List of symbols forced as undefined in the symbol table
/// thus forcing their resolution by the linker.
/// Corresponds to `-u <symbol>` for ELF/MachO and `/include:<symbol>` for COFF/PE.
force_undefined_symbols: std.StringArrayHashMapUnmanaged(void),

c_object_table: std.AutoArrayHashMapUnmanaged(*CObject, void) = .{},
win32_resource_table: if (build_options.only_core_functionality) void else std.AutoArrayHashMapUnmanaged(*Win32Resource, void) =
    if (build_options.only_core_functionality) {} else .{},

link_error_flags: link.File.ErrorFlags = .{},
link_errors: std.ArrayListUnmanaged(link.File.ErrorMsg) = .{},
lld_errors: std.ArrayListUnmanaged(LldError) = .{},

work_queue: std.fifo.LinearFifo(Job, .Dynamic),

/// These jobs are to invoke the Clang compiler to create an object file, which
/// gets linked with the Compilation.
c_object_work_queue: std.fifo.LinearFifo(*CObject, .Dynamic),

/// These jobs are to invoke the RC compiler to create a compiled resource file (.res), which
/// gets linked with the Compilation.
win32_resource_work_queue: if (build_options.only_core_functionality) void else std.fifo.LinearFifo(*Win32Resource, .Dynamic),

/// These jobs are to tokenize, parse, and astgen files, which may be outdated
/// since the last compilation, as well as scan for `@import` and queue up
/// additional jobs corresponding to those new files.
astgen_work_queue: std.fifo.LinearFifo(*Module.File, .Dynamic),
/// These jobs are to inspect the file system stat() and if the embedded file has changed
/// on disk, mark the corresponding Decl outdated and queue up an `analyze_decl`
/// task for it.
embed_file_work_queue: std.fifo.LinearFifo(*Module.EmbedFile, .Dynamic),

/// The ErrorMsg memory is owned by the `CObject`, using Compilation's general purpose allocator.
/// This data is accessed by multiple threads and is protected by `mutex`.
failed_c_objects: std.AutoArrayHashMapUnmanaged(*CObject, *CObject.Diag.Bundle) = .{},

/// The ErrorBundle memory is owned by the `Win32Resource`, using Compilation's general purpose allocator.
/// This data is accessed by multiple threads and is protected by `mutex`.
failed_win32_resources: if (build_options.only_core_functionality) void else std.AutoArrayHashMapUnmanaged(*Win32Resource, ErrorBundle) =
    if (build_options.only_core_functionality) {} else .{},

/// Miscellaneous things that can fail.
misc_failures: std.AutoArrayHashMapUnmanaged(MiscTask, MiscError) = .{},

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
debug_incremental: bool,
job_queued_compiler_rt_lib: bool = false,
job_queued_compiler_rt_obj: bool = false,
job_queued_update_builtin_zig: bool,
alloc_failure_occurred: bool = false,
formatted_panics: bool = false,
last_update_was_cache_hit: bool = false,

c_source_files: []const CSourceFile,
rc_source_files: []const RcSourceFile,
global_cc_argv: []const []const u8,
cache_parent: *Cache,
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
libcxx_static_lib: ?CRTFile = null,
/// Populated when we build the libc++abi static library. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
libcxxabi_static_lib: ?CRTFile = null,
/// Populated when we build the libunwind static library. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
libunwind_static_lib: ?CRTFile = null,
/// Populated when we build the TSAN static library. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
tsan_static_lib: ?CRTFile = null,
/// Populated when we build the libc static library. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
libc_static_lib: ?CRTFile = null,
/// Populated when we build the libcompiler_rt static library. A Job to build this is indicated
/// by setting `job_queued_compiler_rt_lib` and resolved before calling linker.flush().
compiler_rt_lib: ?CRTFile = null,
/// Populated when we build the compiler_rt_obj object. A Job to build this is indicated
/// by setting `job_queued_compiler_rt_obj` and resolved before calling linker.flush().
compiler_rt_obj: ?CRTFile = null,

glibc_so_files: ?glibc.BuiltSharedObjects = null,
wasi_emulated_libs: []const wasi_libc.CRTFile,

/// For example `Scrt1.o` and `libc_nonshared.a`. These are populated after building libc from source,
/// The set of needed CRT (C runtime) files differs depending on the target and compilation settings.
/// The key is the basename, and the value is the absolute path to the completed build artifact.
crt_files: std.StringHashMapUnmanaged(CRTFile) = .{},

/// How many lines of reference trace should be included per compile error.
/// Null means only show snippet on first error.
reference_trace: ?u32 = null,

libcxx_abi_version: libcxx.AbiVersion = libcxx.AbiVersion.default,

/// This mutex guards all `Compilation` mutable state.
mutex: std.Thread.Mutex = .{},

test_filters: []const []const u8,
test_name_prefix: ?[]const u8,

emit_asm: ?EmitLoc,
emit_llvm_ir: ?EmitLoc,
emit_llvm_bc: ?EmitLoc,

work_queue_wait_group: WaitGroup = .{},
astgen_wait_group: WaitGroup = .{},

llvm_opt_bisect_limit: c_int,

pub const Emit = struct {
    /// Where the output will go.
    directory: Directory,
    /// Path to the output file, relative to `directory`.
    sub_path: []const u8,

    /// Returns the full path to `basename` if it were in the same directory as the
    /// `Emit` sub_path.
    pub fn basenamePath(emit: Emit, arena: Allocator, basename: []const u8) ![:0]const u8 {
        const full_path = if (emit.directory.path) |p|
            try std.fs.path.join(arena, &[_][]const u8{ p, emit.sub_path })
        else
            emit.sub_path;

        if (std.fs.path.dirname(full_path)) |dirname| {
            return try std.fs.path.joinZ(arena, &.{ dirname, basename });
        } else {
            return try arena.dupeZ(u8, basename);
        }
    }
};

pub const default_stack_protector_buffer_size = target_util.default_stack_protector_buffer_size;
pub const SemaError = Module.SemaError;

pub const CRTFile = struct {
    lock: Cache.Lock,
    full_object_path: []const u8,

    pub fn deinit(self: *CRTFile, gpa: Allocator) void {
        self.lock.release();
        gpa.free(self.full_object_path);
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
    .{ "cuda", .cu },
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
    /// Write the constant value for a Decl to the output file.
    codegen_decl: InternPool.DeclIndex,
    /// Write the machine code for a function to the output file.
    /// This will either be a non-generic `func_decl` or a `func_instance`.
    codegen_func: InternPool.Index,
    /// Render the .h file snippet for the Decl.
    emit_h_decl: InternPool.DeclIndex,
    /// The Decl needs to be analyzed and possibly export itself.
    /// It may have already be analyzed, or it may have been determined
    /// to be outdated; in this case perform semantic analysis again.
    analyze_decl: InternPool.DeclIndex,
    /// The source file containing the Decl has been updated, and so the
    /// Decl may need its line number information updated in the debug info.
    update_line_number: InternPool.DeclIndex,
    /// The main source file for the module needs to be analyzed.
    analyze_mod: *Package.Module,

    /// one of the glibc static objects
    glibc_crt_file: glibc.CRTFile,
    /// all of the glibc shared objects
    glibc_shared_objects,
    /// one of the musl static objects
    musl_crt_file: musl.CRTFile,
    /// one of the mingw-w64 static objects
    mingw_crt_file: mingw.CRTFile,
    /// libunwind.a, usually needed when linking libc
    libunwind: void,
    libcxx: void,
    libcxxabi: void,
    libtsan: void,
    /// needed when not linking libc and using LLVM for code generation because it generates
    /// calls to, for example, memcpy and memset.
    zig_libc: void,
    /// one of WASI libc static objects
    wasi_libc_crt_file: wasi_libc.CRTFile,

    /// The value is the index into `system_libs`.
    windows_import_lib: usize,
};

pub const CObject = struct {
    /// Relative to cwd. Owned by arena.
    src: CSourceFile,
    status: union(enum) {
        new,
        success: struct {
            /// The outputted result. Owned by gpa.
            object_path: []u8,
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
            file_names: std.AutoArrayHashMapUnmanaged(u32, []const u8) = .{},
            category_names: std.AutoArrayHashMapUnmanaged(u32, []const u8) = .{},
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
                    src_ranges: std.ArrayListUnmanaged(SrcRange) = .{},
                    sub_diags: std.ArrayListUnmanaged(Diag) = .{},

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

                var file_names: std.AutoArrayHashMapUnmanaged(u32, []const u8) = .{};
                errdefer {
                    for (file_names.values()) |file_name| gpa.free(file_name);
                    file_names.deinit(gpa);
                }

                var category_names: std.AutoArrayHashMapUnmanaged(u32, []const u8) = .{};
                errdefer {
                    for (category_names.values()) |category_name| gpa.free(category_name);
                    category_names.deinit(gpa);
                }

                var stack: std.ArrayListUnmanaged(WipDiag) = .{};
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
                            var wip_diag = stack.pop();
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
                gpa.free(success.object_path);
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
    wasi_libc_crt_file,
    compiler_rt,
    zig_libc,
    analyze_mod,
    docs_copy,
    docs_wasm,

    @"musl crti.o",
    @"musl crtn.o",
    @"musl crt1.o",
    @"musl rcrt1.o",
    @"musl Scrt1.o",
    @"musl libc.a",
    @"musl libc.so",

    @"wasi crt1-reactor.o",
    @"wasi crt1-command.o",
    @"wasi libc.a",
    @"libwasi-emulated-process-clocks.a",
    @"libwasi-emulated-getpid.a",
    @"libwasi-emulated-mman.a",
    @"libwasi-emulated-signal.a",

    @"glibc crti.o",
    @"glibc crtn.o",
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

pub const LldError = struct {
    /// Allocated with gpa.
    msg: []const u8,
    context_lines: []const []const u8 = &.{},

    pub fn deinit(self: *LldError, gpa: Allocator) void {
        for (self.context_lines) |line| {
            gpa.free(line);
        }

        gpa.free(self.context_lines);
        gpa.free(self.msg);
    }
};

pub const Directory = Cache.Directory;

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
        hh.add(mod.unwind_tables);
        hh.add(mod.structured_cfg);
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
        hh.add(target.os.getVersionRange());
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
        const tag: @typeInfo(Config.DebugFormat).Union.tag_type.? = x;
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
        tmp_artifact_directory: ?Cache.Directory,
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

pub const LinkObject = struct {
    path: []const u8,
    must_link: bool = false,
    // When the library is passed via a positional argument, it will be
    // added as a full path. If it's `-l<lib>`, then just the basename.
    //
    // Consistent with `withLOption` variable name in lld ELF driver.
    loption: bool = false,
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
    lib_dirs: []const []const u8 = &[0][]const u8{},
    rpath_list: []const []const u8 = &[0][]const u8{},
    symbol_wrap_set: std.StringArrayHashMapUnmanaged(void) = .{},
    c_source_files: []const CSourceFile = &.{},
    rc_source_files: []const RcSourceFile = &.{},
    manifest_file: ?[]const u8 = null,
    rc_includes: RcIncludes = .any,
    link_objects: []LinkObject = &[0]LinkObject{},
    framework_dirs: []const []const u8 = &[0][]const u8{},
    frameworks: []const Framework = &.{},
    system_lib_names: []const []const u8 = &.{},
    system_lib_infos: []const SystemLib = &.{},
    /// These correspond to the WASI libc emulated subcomponents including:
    /// * process clocks
    /// * getpid
    /// * mman
    /// * signal
    wasi_emulated_libs: []const wasi_libc.CRTFile = &.{},
    /// This means that if the output mode is an executable it will be a
    /// Position Independent Executable. If the output mode is not an
    /// executable this field is ignored.
    want_compiler_rt: ?bool = null,
    want_lto: ?bool = null,
    formatted_panics: ?bool = null,
    function_sections: bool = false,
    data_sections: bool = false,
    no_builtin: bool = false,
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
    debug_incremental: bool = false,
    /// Normally when you create a `Compilation`, Zig will automatically build
    /// and link in required dependencies, such as compiler-rt and libc. When
    /// building such dependencies themselves, this flag must be set to avoid
    /// infinite recursion.
    skip_linker_dependencies: bool = false,
    hash_style: link.File.Elf.HashStyle = .both,
    entry: Entry = .default,
    force_undefined_symbols: std.StringArrayHashMapUnmanaged(void) = .{},
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
    error_limit: ?Compilation.Module.ErrorInt = null,
    global_cc_argv: []const []const u8 = &.{},

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
    var seen_table: std.AutoArrayHashMapUnmanaged(*Package.Module, void) = .{};
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
        const any_unwind_tables = options.config.any_unwind_tables or options.root_mod.unwind_tables;
        const any_non_single_threaded = options.config.any_non_single_threaded or !options.root_mod.single_threaded;
        const any_sanitize_thread = options.config.any_sanitize_thread or options.root_mod.sanitize_thread;

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
                .inherited = .{},
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
                std.debug.getStderrMutex().lock();
                defer std.debug.getStderrMutex().unlock();
                const stderr = std.io.getStdErr().writer();
                nosuspend {
                    stderr.print("compilation: {s}\n", .{options.root_name}) catch break :print;
                    stderr.print("  target: {s}\n", .{try target.zigTriple(arena)}) catch break :print;
                    stderr.print("  cpu: {s}\n", .{target.cpu.model.name}) catch break :print;
                    stderr.print("  features: {s}\n", .{cf}) catch {};
                }
            }
        }

        // TODO: https://github.com/ziglang/zig/issues/17969
        const formatted_panics = options.formatted_panics orelse (options.root_mod.optimize_mode == .Debug);

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
        cache.addPrefix(.{ .path = null, .handle = std.fs.cwd() });
        cache.addPrefix(options.zig_lib_directory);
        cache.addPrefix(options.local_cache_directory);
        errdefer cache.manifest_dir.close();

        // This is shared hasher state common to zig source and all C source files.
        cache.hash.addBytes(build_options.version);
        cache.hash.add(builtin.zig_backend);
        cache.hash.add(options.config.pie);
        cache.hash.add(options.config.lto);
        cache.hash.add(options.config.link_mode);
        cache.hash.add(options.function_sections);
        cache.hash.add(options.data_sections);
        cache.hash.add(options.no_builtin);
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
        // TODO audit this and make sure everything is in it

        const main_mod = options.main_mod orelse options.root_mod;
        const comp = try arena.create(Compilation);
        const opt_zcu: ?*Module = if (have_zcu) blk: {
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

            const emit_h: ?*Module.GlobalEmitH = if (options.emit_h) |loc| eh: {
                const eh = try arena.create(Module.GlobalEmitH);
                eh.* = .{ .loc = loc };
                break :eh eh;
            } else null;

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

            const zcu = try arena.create(Module);
            zcu.* = .{
                .gpa = gpa,
                .comp = comp,
                .main_mod = main_mod,
                .root_mod = options.root_mod,
                .std_mod = std_mod,
                .global_zir_cache = global_zir_cache,
                .local_zir_cache = local_zir_cache,
                .emit_h = emit_h,
                .error_limit = error_limit,
                .llvm_object = null,
            };
            try zcu.init();
            break :blk zcu;
        } else blk: {
            if (options.emit_h != null) return error.NoZigModuleForCHeader;
            break :blk null;
        };
        errdefer if (opt_zcu) |zcu| zcu.deinit();

        var system_libs = try std.StringArrayHashMapUnmanaged(SystemLib).init(
            gpa,
            options.system_lib_names,
            options.system_lib_infos,
        );
        errdefer system_libs.deinit(gpa);

        comp.* = .{
            .gpa = gpa,
            .arena = arena,
            .module = opt_zcu,
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
            .work_queue = std.fifo.LinearFifo(Job, .Dynamic).init(gpa),
            .c_object_work_queue = std.fifo.LinearFifo(*CObject, .Dynamic).init(gpa),
            .win32_resource_work_queue = if (build_options.only_core_functionality) {} else std.fifo.LinearFifo(*Win32Resource, .Dynamic).init(gpa),
            .astgen_work_queue = std.fifo.LinearFifo(*Module.File, .Dynamic).init(gpa),
            .embed_file_work_queue = std.fifo.LinearFifo(*Module.EmbedFile, .Dynamic).init(gpa),
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
            .formatted_panics = formatted_panics,
            .time_report = options.time_report,
            .stack_report = options.stack_report,
            .test_filters = options.test_filters,
            .test_name_prefix = options.test_name_prefix,
            .debug_compiler_runtime_libs = options.debug_compiler_runtime_libs,
            .debug_compile_errors = options.debug_compile_errors,
            .debug_incremental = options.debug_incremental,
            .libcxx_abi_version = options.libcxx_abi_version,
            .root_name = root_name,
            .sysroot = sysroot,
            .system_libs = system_libs,
            .version = options.version,
            .libc_installation = libc_dirs.libc_installation,
            .include_compiler_rt = include_compiler_rt,
            .objects = options.link_objects,
            .framework_dirs = options.framework_dirs,
            .llvm_opt_bisect_limit = options.llvm_opt_bisect_limit,
            .skip_linker_dependencies = options.skip_linker_dependencies,
            .no_builtin = options.no_builtin,
            .job_queued_update_builtin_zig = have_zcu,
            .function_sections = options.function_sections,
            .data_sections = options.data_sections,
            .native_system_include_paths = options.native_system_include_paths,
            .wasi_emulated_libs = options.wasi_emulated_libs,
            .force_undefined_symbols = options.force_undefined_symbols,
            .link_eh_frame_hdr = link_eh_frame_hdr,
            .global_cc_argv = options.global_cc_argv,
        };

        // Prevent some footguns by making the "any" fields of config reflect
        // the default Module settings.
        comp.config.any_unwind_tables = any_unwind_tables;
        comp.config.any_non_single_threaded = any_non_single_threaded;
        comp.config.any_sanitize_thread = any_sanitize_thread;

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
            .lib_dirs = options.lib_dirs,
            .framework_dirs = options.framework_dirs,
            .rpath_list = options.rpath_list,
            .symbol_wrap_set = options.symbol_wrap_set,
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
                hash.add(formatted_panics);
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
                    const emit: Emit = .{
                        .directory = emit_bin.directory orelse artifact_directory,
                        .sub_path = emit_bin.basename,
                    };
                    comp.bin_file = try link.File.open(arena, comp, emit, lf_open_opts);
                }

                if (options.emit_implib) |emit_implib| {
                    comp.implib_emit = .{
                        .directory = emit_implib.directory orelse artifact_directory,
                        .sub_path = emit_implib.basename,
                    };
                }

                if (options.emit_docs) |emit_docs| {
                    comp.docs_emit = .{
                        .directory = emit_docs.directory orelse artifact_directory,
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
            if (build_options.only_c) unreachable;
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

    // Add a `Win32Resource` for each `rc_source_files` and one for `manifest_file`.
    if (!build_options.only_core_functionality) {
        try comp.win32_resource_table.ensureTotalCapacity(gpa, options.rc_source_files.len + @intFromBool(options.manifest_file != null));
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

    if (have_bin_emit and !comp.skip_linker_dependencies and target.ofmt != .c) {
        if (target.isDarwin()) {
            switch (target.abi) {
                .none,
                .simulator,
                .macabi,
                => {},
                else => return error.LibCUnavailable,
            }
        }
        // If we need to build glibc for the target, add work items for it.
        // We go through the work queue so that building can be done in parallel.
        if (comp.wantBuildGLibCFromSource()) {
            if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

            if (glibc.needsCrtiCrtn(target)) {
                try comp.work_queue.write(&[_]Job{
                    .{ .glibc_crt_file = .crti_o },
                    .{ .glibc_crt_file = .crtn_o },
                });
            }
            try comp.work_queue.write(&[_]Job{
                .{ .glibc_crt_file = .scrt1_o },
                .{ .glibc_crt_file = .libc_nonshared_a },
                .{ .glibc_shared_objects = {} },
            });
        }
        if (comp.wantBuildMuslFromSource()) {
            if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

            try comp.work_queue.ensureUnusedCapacity(6);
            if (musl.needsCrtiCrtn(target)) {
                comp.work_queue.writeAssumeCapacity(&[_]Job{
                    .{ .musl_crt_file = .crti_o },
                    .{ .musl_crt_file = .crtn_o },
                });
            }
            comp.work_queue.writeAssumeCapacity(&[_]Job{
                .{ .musl_crt_file = .crt1_o },
                .{ .musl_crt_file = .scrt1_o },
                .{ .musl_crt_file = .rcrt1_o },
                switch (comp.config.link_mode) {
                    .static => .{ .musl_crt_file = .libc_a },
                    .dynamic => .{ .musl_crt_file = .libc_so },
                },
            });
        }

        if (comp.wantBuildWasiLibcFromSource()) {
            if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

            // worst-case we need all components
            try comp.work_queue.ensureUnusedCapacity(comp.wasi_emulated_libs.len + 2);

            for (comp.wasi_emulated_libs) |crt_file| {
                comp.work_queue.writeItemAssumeCapacity(.{
                    .wasi_libc_crt_file = crt_file,
                });
            }
            comp.work_queue.writeAssumeCapacity(&[_]Job{
                .{ .wasi_libc_crt_file = wasi_libc.execModelCrtFile(comp.config.wasi_exec_model) },
                .{ .wasi_libc_crt_file = .libc_a },
            });
        }

        if (comp.wantBuildMinGWFromSource()) {
            if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

            const crt_job: Job = .{ .mingw_crt_file = if (is_dyn_lib) .dllcrt2_o else .crt2_o };
            try comp.work_queue.ensureUnusedCapacity(2);
            comp.work_queue.writeItemAssumeCapacity(.{ .mingw_crt_file = .mingw32_lib });
            comp.work_queue.writeItemAssumeCapacity(crt_job);

            // When linking mingw-w64 there are some import libs we always need.
            for (mingw.always_link_libs) |name| {
                try comp.system_libs.put(comp.gpa, name, .{
                    .needed = false,
                    .weak = false,
                    .path = null,
                });
            }
        }
        // Generate Windows import libs.
        if (target.os.tag == .windows) {
            const count = comp.system_libs.count();
            try comp.work_queue.ensureUnusedCapacity(count);
            for (0..count) |i| {
                comp.work_queue.writeItemAssumeCapacity(.{ .windows_import_lib = i });
            }
        }
        if (comp.wantBuildLibUnwindFromSource()) {
            try comp.work_queue.writeItem(.{ .libunwind = {} });
        }
        if (build_options.have_llvm and is_exe_or_dyn_lib and comp.config.link_libcpp) {
            try comp.work_queue.writeItem(.libcxx);
            try comp.work_queue.writeItem(.libcxxabi);
        }
        if (build_options.have_llvm and comp.config.any_sanitize_thread) {
            try comp.work_queue.writeItem(.libtsan);
        }

        if (target.isMinGW() and comp.config.any_non_single_threaded) {
            // LLD might drop some symbols as unused during LTO and GCing, therefore,
            // we force mark them for resolution here.

            const tls_index_sym = switch (target.cpu.arch) {
                .x86 => "__tls_index",
                else => "_tls_index",
            };

            try comp.force_undefined_symbols.put(comp.gpa, tls_index_sym, {});
        }

        if (comp.include_compiler_rt and capable_of_building_compiler_rt) {
            if (is_exe_or_dyn_lib) {
                log.debug("queuing a job to build compiler_rt_lib", .{});
                comp.job_queued_compiler_rt_lib = true;
            } else if (output_mode != .Obj) {
                log.debug("queuing a job to build compiler_rt_obj", .{});
                // In this case we are making a static library, so we ask
                // for a compiler-rt object to put in it.
                comp.job_queued_compiler_rt_obj = true;
            }
        }

        if (!comp.skip_linker_dependencies and is_exe_or_dyn_lib and
            !comp.config.link_libc and capable_of_building_zig_libc)
        {
            try comp.work_queue.writeItem(.{ .zig_libc = {} });
        }
    }

    return comp;
}

pub fn destroy(comp: *Compilation) void {
    if (comp.bin_file) |lf| lf.destroy();
    if (comp.module) |zcu| zcu.deinit();
    comp.cache_use.deinit();
    comp.work_queue.deinit();
    comp.c_object_work_queue.deinit();
    if (!build_options.only_core_functionality) {
        comp.win32_resource_work_queue.deinit();
    }
    comp.astgen_work_queue.deinit();
    comp.embed_file_work_queue.deinit();

    const gpa = comp.gpa;
    comp.system_libs.deinit(gpa);

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

    if (!build_options.only_core_functionality) {
        for (comp.win32_resource_table.keys()) |key| {
            key.destroy(gpa);
        }
        comp.win32_resource_table.deinit(gpa);

        for (comp.failed_win32_resources.values()) |*value| {
            value.deinit(gpa);
        }
        comp.failed_win32_resources.deinit(gpa);
    }

    for (comp.link_errors.items) |*item| item.deinit(gpa);
    comp.link_errors.deinit(gpa);

    for (comp.lld_errors.items) |*lld_error| {
        lld_error.deinit(gpa);
    }
    comp.lld_errors.deinit(gpa);

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
    prog_node: *std.Progress.Node,
    pid: std.ChildProcess.Id,
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
pub fn update(comp: *Compilation, main_progress_node: *std.Progress.Node) !void {
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

            const is_hit = man.hit() catch |err| {
                const i = man.failed_file_index orelse return err;
                const pp = man.files.keys()[i].prefixed_path;
                const prefix = man.cache.prefixes()[pp.prefix];
                return comp.setMiscFailure(
                    .check_whole_cache,
                    "unable to check cache: stat file '{}{s}' failed: {s}",
                    .{ prefix, pp.sub_path, @errorName(err) },
                );
            };
            if (is_hit) {
                comp.last_update_was_cache_hit = true;
                log.debug("CacheMode.whole cache hit for {s}", .{comp.root_name});
                const digest = man.final();

                comp.wholeCacheModeSetBinFilePath(whole, &digest);

                assert(whole.lock == null);
                whole.lock = man.toOwnedLock();
                return;
            }
            log.debug("CacheMode.whole cache miss for {s}", .{comp.root_name});

            // Compile the artifacts to a temporary directory.
            const tmp_artifact_directory = d: {
                const s = std.fs.path.sep_str;
                tmp_dir_rand_int = std.crypto.random.int(u64);
                const tmp_dir_sub_path = "tmp" ++ s ++ Package.Manifest.hex64(tmp_dir_rand_int);

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
                    .directory = tmp_artifact_directory,
                    .sub_path = std.fs.path.basename(sub_path),
                };
            }

            if (whole.docs_sub_path) |sub_path| {
                comp.docs_emit = .{
                    .directory = tmp_artifact_directory,
                    .sub_path = std.fs.path.basename(sub_path),
                };
            }

            if (whole.bin_sub_path) |sub_path| {
                const emit: Emit = .{
                    .directory = tmp_artifact_directory,
                    .sub_path = std.fs.path.basename(sub_path),
                };
                comp.bin_file = try link.File.createEmpty(arena, comp, emit, whole.lf_open_opts);
            }
        },
        .incremental => {},
    }

    // For compiling C objects, we rely on the cache hash system to avoid duplicating work.
    // Add a Job for each C object.
    try comp.c_object_work_queue.ensureUnusedCapacity(comp.c_object_table.count());
    for (comp.c_object_table.keys()) |key| {
        comp.c_object_work_queue.writeItemAssumeCapacity(key);
    }

    // For compiling Win32 resources, we rely on the cache hash system to avoid duplicating work.
    // Add a Job for each Win32 resource file.
    if (!build_options.only_core_functionality) {
        try comp.win32_resource_work_queue.ensureUnusedCapacity(comp.win32_resource_table.count());
        for (comp.win32_resource_table.keys()) |key| {
            comp.win32_resource_work_queue.writeItemAssumeCapacity(key);
        }
    }

    if (comp.module) |module| {
        module.compile_log_text.shrinkAndFree(gpa, 0);

        // Make sure std.zig is inside the import_table. We unconditionally need
        // it for start.zig.
        const std_mod = module.std_mod;
        _ = try module.importPkg(std_mod);

        // Normally we rely on importing std to in turn import the root source file
        // in the start code, but when using the stage1 backend that won't happen,
        // so in order to run AstGen on the root source file we put it into the
        // import_table here.
        // Likewise, in the case of `zig test`, the test runner is the root source file,
        // and so there is nothing to import the main file.
        if (comp.config.is_test) {
            _ = try module.importPkg(module.main_mod);
        }

        if (module.root_mod.deps.get("compiler_rt")) |compiler_rt_mod| {
            _ = try module.importPkg(compiler_rt_mod);
        }

        // Put a work item in for every known source file to detect if
        // it changed, and, if so, re-compute ZIR and then queue the job
        // to update it.
        try comp.astgen_work_queue.ensureUnusedCapacity(module.import_table.count());
        for (module.import_table.values()) |file| {
            if (file.mod.isBuiltin()) continue;
            comp.astgen_work_queue.writeItemAssumeCapacity(file);
        }

        // Put a work item in for checking if any files used with `@embedFile` changed.
        try comp.embed_file_work_queue.ensureUnusedCapacity(module.embed_table.count());
        for (module.embed_table.values()) |embed_file| {
            comp.embed_file_work_queue.writeItemAssumeCapacity(embed_file);
        }

        try comp.work_queue.writeItem(.{ .analyze_mod = std_mod });
        if (comp.config.is_test) {
            try comp.work_queue.writeItem(.{ .analyze_mod = module.main_mod });
        }

        if (module.root_mod.deps.get("compiler_rt")) |compiler_rt_mod| {
            try comp.work_queue.writeItem(.{ .analyze_mod = compiler_rt_mod });
        }
    }

    try comp.performAllTheWork(main_progress_node);

    if (comp.module) |module| {
        if (build_options.enable_debug_extensions and comp.verbose_intern_pool) {
            std.debug.print("intern pool stats for '{s}':\n", .{
                comp.root_name,
            });
            module.intern_pool.dump();
        }

        if (build_options.enable_debug_extensions and comp.verbose_generic_instances) {
            std.debug.print("generic instances for '{s}:0x{x}':\n", .{
                comp.root_name,
                @as(usize, @intFromPtr(module)),
            });
            module.intern_pool.dumpGenericInstances(gpa);
        }

        if (comp.config.is_test and comp.totalErrorCount() == 0) {
            // The `test_functions` decl has been intentionally postponed until now,
            // at which point we must populate it with the list of test functions that
            // have been discovered and not filtered out.
            try module.populateTestFunctions(main_progress_node);
        }

        try module.processExports();
    }

    if (comp.totalErrorCount() != 0) {
        // Skip flushing and keep source files loaded for error reporting.
        comp.link_error_flags = .{};
        return;
    }

    // Flush below handles -femit-bin but there is still -femit-llvm-ir,
    // -femit-llvm-bc, and -femit-asm, in the case of C objects.
    comp.emitOthers();

    switch (comp.cache_use) {
        .whole => |whole| {
            const digest = man.final();

            // Rename the temporary directory into place.
            // Close tmp dir and link.File to avoid open handle during rename.
            if (whole.tmp_artifact_directory) |*tmp_directory| {
                tmp_directory.handle.close();
                if (tmp_directory.path) |p| gpa.free(p);
                whole.tmp_artifact_directory = null;
            } else unreachable;

            const s = std.fs.path.sep_str;
            const tmp_dir_sub_path = "tmp" ++ s ++ Package.Manifest.hex64(tmp_dir_rand_int);
            const o_sub_path = "o" ++ s ++ digest;

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
            comp.wholeCacheModeSetBinFilePath(whole, &digest);

            // The linker flush functions need to know the final output path
            // for debug info purposes because executable debug info contains
            // references object file paths.
            if (comp.bin_file) |lf| {
                lf.emit = .{
                    .directory = comp.local_cache_directory,
                    .sub_path = whole.bin_sub_path.?,
                };

                // Has to be after the `wholeCacheModeSetBinFilePath` above.
                if (need_writable_dance) {
                    try lf.makeWritable();
                }
            }

            try flush(comp, arena, main_progress_node);
            if (comp.totalErrorCount() != 0) return;

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
        .incremental => {
            try flush(comp, arena, main_progress_node);
            if (comp.totalErrorCount() != 0) return;
        },
    }
}

fn flush(comp: *Compilation, arena: Allocator, prog_node: *std.Progress.Node) !void {
    if (comp.bin_file) |lf| {
        // This is needed before reading the error flags.
        lf.flush(arena, prog_node) catch |err| switch (err) {
            error.FlushFailure => {}, // error reported through link_error_flags
            error.LLDReportedFailure => {}, // error reported via lockAndParseLldStderr
            else => |e| return e,
        };
    }

    if (comp.module) |zcu| {
        try link.File.C.flushEmitH(zcu);

        if (zcu.llvm_object) |llvm_object| {
            if (build_options.only_c) unreachable;
            const default_emit = switch (comp.cache_use) {
                .whole => |whole| .{
                    .directory = whole.tmp_artifact_directory.?,
                    .sub_path = "dummy",
                },
                .incremental => |incremental| .{
                    .directory = incremental.artifact_directory,
                    .sub_path = "dummy",
                },
            };
            try emitLlvmObject(comp, arena, default_emit, null, llvm_object, prog_node);
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
            .directory = comp.local_cache_directory,
            .sub_path = sub_path,
        };
    }

    if (whole.docs_sub_path) |sub_path| {
        @memcpy(sub_path[digest_start..][0..digest.len], digest);

        comp.docs_emit = .{
            .directory = comp.local_cache_directory,
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
pub const link_hash_implementation_version = 13;

fn addNonIncrementalStuffToCacheManifest(
    comp: *Compilation,
    arena: Allocator,
    man: *Cache.Manifest,
) !void {
    const gpa = comp.gpa;

    comptime assert(link_hash_implementation_version == 13);

    if (comp.module) |mod| {
        try addModuleTableToCacheHash(gpa, arena, &man.hash, mod.root_mod, mod.main_mod, .{ .files = man });

        // Synchronize with other matching comments: ZigOnlyHashStuff
        man.hash.addListOfBytes(comp.test_filters);
        man.hash.addOptionalBytes(comp.test_name_prefix);
        man.hash.add(comp.skip_linker_dependencies);
        man.hash.add(comp.formatted_panics);
        man.hash.add(mod.emit_h != null);
        man.hash.add(mod.error_limit);
    } else {
        cache_helpers.addModule(&man.hash, comp.root_mod);
    }

    for (comp.objects) |obj| {
        _ = try man.addFile(obj.path, null);
        man.hash.add(obj.must_link);
        man.hash.add(obj.loption);
    }

    for (comp.c_object_table.keys()) |key| {
        _ = try man.addFile(key.src.src_path, null);
        man.hash.addOptional(key.src.ext);
        man.hash.addListOfBytes(key.src.extra_flags);
    }

    if (!build_options.only_core_functionality) {
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
    try link.hashAddSystemLibs(man, comp.system_libs);

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
    man.hash.addListOfBytes(opts.lib_dirs);
    man.hash.addListOfBytes(opts.rpath_list);
    man.hash.addListOfBytes(opts.symbol_wrap_set.keys());
    if (comp.config.link_libc) {
        man.hash.add(comp.libc_installation != null);
        const target = comp.root_mod.resolved_target.result;
        if (comp.libc_installation) |libc_installation| {
            man.hash.addOptionalBytes(libc_installation.crt_dir);
            if (target.abi == .msvc) {
                man.hash.addOptionalBytes(libc_installation.msvc_lib_dir);
                man.hash.addOptionalBytes(libc_installation.kernel32_lib_dir);
            }
        }
        man.hash.addOptionalBytes(target.dynamic_linker.get());
    }
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
    if (comp.config.output_mode != .Obj or comp.module != null or
        comp.c_object_table.count() == 0)
    {
        return;
    }
    const obj_path = comp.c_object_table.keys()[0].status.success.object_path;
    const cwd = std.fs.cwd();
    const ext = std.fs.path.extension(obj_path);
    const basename = obj_path[0 .. obj_path.len - ext.len];
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
                    basename, out.ext,
                }) catch |err| {
                    log.err("unable to copy {s}{s}: {s}", .{ basename, out.ext, @errorName(err) });
                    continue;
                };
                defer comp.gpa.free(src_path);
                cwd.copyFile(src_path, directory.handle, loc.basename, .{}) catch |err| {
                    log.err("unable to copy {s}: {s}", .{ src_path, @errorName(err) });
                };
            }
        }
    }
}

pub fn emitLlvmObject(
    comp: *Compilation,
    arena: Allocator,
    default_emit: Emit,
    bin_emit_loc: ?EmitLoc,
    llvm_object: *LlvmObject,
    prog_node: *std.Progress.Node,
) !void {
    if (build_options.only_c) @compileError("unreachable");

    var sub_prog_node = prog_node.start("LLVM Emit Object", 0);
    sub_prog_node.activate();
    sub_prog_node.context.refresh();
    defer sub_prog_node.end();

    try llvm_object.emit(.{
        .pre_ir_path = comp.verbose_llvm_ir,
        .pre_bc_path = comp.verbose_llvm_bc,
        .bin_path = try resolveEmitLoc(arena, default_emit, bin_emit_loc),
        .asm_path = try resolveEmitLoc(arena, default_emit, comp.emit_asm),
        .post_ir_path = try resolveEmitLoc(arena, default_emit, comp.emit_llvm_ir),
        .post_bc_path = try resolveEmitLoc(arena, default_emit, comp.emit_llvm_bc),

        .is_debug = comp.root_mod.optimize_mode == .Debug,
        .is_small = comp.root_mod.optimize_mode == .ReleaseSmall,
        .time_report = comp.time_report,
        .sanitize_thread = comp.config.any_sanitize_thread,
        .lto = comp.config.lto,
    });
}

fn resolveEmitLoc(
    arena: Allocator,
    default_emit: Emit,
    opt_loc: ?EmitLoc,
) Allocator.Error!?[*:0]const u8 {
    const loc = opt_loc orelse return null;
    const slice = if (loc.directory) |directory|
        try directory.joinZ(arena, &.{loc.basename})
    else
        try default_emit.basenamePath(arena, loc.basename);
    return slice.ptr;
}

fn reportMultiModuleErrors(mod: *Module) !void {
    // Some cases can give you a whole bunch of multi-module errors, which it's not helpful to
    // print all of, so we'll cap the number of these to emit.
    var num_errors: u32 = 0;
    const max_errors = 5;
    // Attach the "some omitted" note to the final error message
    var last_err: ?*Module.ErrorMsg = null;

    for (mod.import_table.values()) |file| {
        if (!file.multi_pkg) continue;

        num_errors += 1;
        if (num_errors > max_errors) continue;

        const err = err_blk: {
            // Like with errors, let's cap the number of notes to prevent a huge error spew.
            const max_notes = 5;
            const omitted = file.references.items.len -| max_notes;
            const num_notes = file.references.items.len - omitted;

            const notes = try mod.gpa.alloc(Module.ErrorMsg, if (omitted > 0) num_notes + 1 else num_notes);
            errdefer mod.gpa.free(notes);

            for (notes[0..num_notes], file.references.items[0..num_notes], 0..) |*note, ref, i| {
                errdefer for (notes[0..i]) |*n| n.deinit(mod.gpa);
                note.* = switch (ref) {
                    .import => |loc| blk: {
                        break :blk try Module.ErrorMsg.init(
                            mod.gpa,
                            loc,
                            "imported from module {s}",
                            .{loc.file_scope.mod.fully_qualified_name},
                        );
                    },
                    .root => |pkg| blk: {
                        break :blk try Module.ErrorMsg.init(
                            mod.gpa,
                            .{ .file_scope = file, .parent_decl_node = 0, .lazy = .entire_file },
                            "root of module {s}",
                            .{pkg.fully_qualified_name},
                        );
                    },
                };
            }
            errdefer for (notes[0..num_notes]) |*n| n.deinit(mod.gpa);

            if (omitted > 0) {
                notes[num_notes] = try Module.ErrorMsg.init(
                    mod.gpa,
                    .{ .file_scope = file, .parent_decl_node = 0, .lazy = .entire_file },
                    "{} more references omitted",
                    .{omitted},
                );
            }
            errdefer if (omitted > 0) notes[num_notes].deinit(mod.gpa);

            const err = try Module.ErrorMsg.create(
                mod.gpa,
                .{ .file_scope = file, .parent_decl_node = 0, .lazy = .entire_file },
                "file exists in multiple modules",
                .{},
            );
            err.notes = notes;
            break :err_blk err;
        };
        errdefer err.destroy(mod.gpa);
        try mod.failed_files.putNoClobber(mod.gpa, file, err);
        last_err = err;
    }

    // If we omitted any errors, add a note saying that
    if (num_errors > max_errors) {
        const err = last_err.?;

        // There isn't really any meaningful place to put this note, so just attach it to the
        // last failed file
        var note = try Module.ErrorMsg.init(
            mod.gpa,
            err.src_loc,
            "{} more errors omitted",
            .{num_errors - max_errors},
        );
        errdefer note.deinit(mod.gpa);

        const i = err.notes.len;
        err.notes = try mod.gpa.realloc(err.notes, i + 1);
        err.notes[i] = note;
    }

    // Now that we've reported the errors, we need to deal with
    // dependencies. Any file referenced by a multi_pkg file should also be
    // marked multi_pkg and have its status set to astgen_failure, as it's
    // ambiguous which package they should be analyzed as a part of. We need
    // to add this flag after reporting the errors however, as otherwise
    // we'd get an error for every single downstream file, which wouldn't be
    // very useful.
    for (mod.import_table.values()) |file| {
        if (file.multi_pkg) file.recursiveMarkMultiPkg(mod);
    }
}

/// Having the file open for writing is problematic as far as executing the
/// binary is concerned. This will remove the write flag, or close the file,
/// or whatever is needed so that it can be executed.
/// After this, one must call` makeFileWritable` before calling `update`.
pub fn makeBinFileExecutable(comp: *Compilation) !void {
    const lf = comp.bin_file orelse return;
    return lf.makeExecutable();
}

pub fn makeBinFileWritable(comp: *Compilation) !void {
    const lf = comp.bin_file orelse return;
    return lf.makeWritable();
}

const Header = extern struct {
    intern_pool: extern struct {
        items_len: u32,
        extra_len: u32,
        limbs_len: u32,
        string_bytes_len: u32,
        tracked_insts_len: u32,
        src_hash_deps_len: u32,
        decl_val_deps_len: u32,
        namespace_deps_len: u32,
        namespace_name_deps_len: u32,
        first_dependency_len: u32,
        dep_entries_len: u32,
        free_dep_entries_len: u32,
    },
};

/// Note that all state that is included in the cache hash namespace is *not*
/// saved, such as the target and most CLI flags. A cache hit will only occur
/// when subsequent compiler invocations use the same set of flags.
pub fn saveState(comp: *Compilation) !void {
    var bufs_list: [19]std.posix.iovec_const = undefined;
    var bufs_len: usize = 0;

    const lf = comp.bin_file orelse return;

    if (comp.module) |zcu| {
        const ip = &zcu.intern_pool;
        const header: Header = .{
            .intern_pool = .{
                .items_len = @intCast(ip.items.len),
                .extra_len = @intCast(ip.extra.items.len),
                .limbs_len = @intCast(ip.limbs.items.len),
                .string_bytes_len = @intCast(ip.string_bytes.items.len),
                .tracked_insts_len = @intCast(ip.tracked_insts.count()),
                .src_hash_deps_len = @intCast(ip.src_hash_deps.count()),
                .decl_val_deps_len = @intCast(ip.decl_val_deps.count()),
                .namespace_deps_len = @intCast(ip.namespace_deps.count()),
                .namespace_name_deps_len = @intCast(ip.namespace_name_deps.count()),
                .first_dependency_len = @intCast(ip.first_dependency.count()),
                .dep_entries_len = @intCast(ip.dep_entries.items.len),
                .free_dep_entries_len = @intCast(ip.free_dep_entries.items.len),
            },
        };
        addBuf(&bufs_list, &bufs_len, mem.asBytes(&header));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.limbs.items));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.extra.items));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.items.items(.data)));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.items.items(.tag)));
        addBuf(&bufs_list, &bufs_len, ip.string_bytes.items);
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.tracked_insts.keys()));

        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.src_hash_deps.keys()));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.src_hash_deps.values()));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.decl_val_deps.keys()));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.decl_val_deps.values()));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.namespace_deps.keys()));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.namespace_deps.values()));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.namespace_name_deps.keys()));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.namespace_name_deps.values()));

        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.first_dependency.keys()));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.first_dependency.values()));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.dep_entries.items));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.free_dep_entries.items));

        // TODO: compilation errors
        // TODO: files
        // TODO: namespaces
        // TODO: decls
        // TODO: linker state
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
    var af = try lf.emit.directory.handle.atomicFile(basename, .{});
    defer af.deinit();
    try af.file.pwritevAll(bufs_list[0..bufs_len], 0);
    try af.finish();
}

fn addBuf(bufs_list: []std.posix.iovec_const, bufs_len: *usize, buf: []const u8) void {
    const i = bufs_len.*;
    bufs_len.* = i + 1;
    bufs_list[i] = .{
        .base = buf.ptr,
        .len = buf.len,
    };
}

/// This function is temporally single-threaded.
pub fn totalErrorCount(comp: *Compilation) u32 {
    var total: usize =
        comp.misc_failures.count() +
        @intFromBool(comp.alloc_failure_occurred) +
        comp.lld_errors.items.len;

    for (comp.failed_c_objects.values()) |bundle| {
        total += bundle.diags.len;
    }

    if (!build_options.only_core_functionality) {
        for (comp.failed_win32_resources.values()) |errs| {
            total += errs.errorMessageCount();
        }
    }

    if (comp.module) |module| {
        total += module.failed_exports.count();
        total += module.failed_embed_files.count();

        for (module.failed_files.keys(), module.failed_files.values()) |file, error_msg| {
            if (error_msg) |_| {
                total += 1;
            } else {
                assert(file.zir_loaded);
                const payload_index = file.zir.extra[@intFromEnum(Zir.ExtraIndex.compile_errors)];
                assert(payload_index != 0);
                const header = file.zir.extraData(Zir.Inst.CompileErrors, payload_index);
                total += header.data.items_len;
            }
        }

        // Skip errors for Decls within files that failed parsing.
        // When a parse error is introduced, we keep all the semantic analysis for
        // the previous parse success, including compile errors, but we cannot
        // emit them until the file succeeds parsing.
        for (module.failed_decls.keys()) |key| {
            if (module.declFileScope(key).okToReportErrors()) {
                total += 1;
                if (module.cimport_errors.get(key)) |errors| {
                    total += errors.errorMessageCount();
                }
            }
        }
        if (module.emit_h) |emit_h| {
            for (emit_h.failed_decls.keys()) |key| {
                if (module.declFileScope(key).okToReportErrors()) {
                    total += 1;
                }
            }
        }

        if (module.global_error_set.entries.len - 1 > module.error_limit) {
            total += 1;
        }
    }

    // The "no entry point found" error only counts if there are no semantic analysis errors.
    if (total == 0) {
        total += @intFromBool(comp.link_error_flags.no_entry_point_found);
    }
    total += @intFromBool(comp.link_error_flags.missing_libc);

    total += comp.link_errors.items.len;

    // Compile log errors only count if there are no other errors.
    if (total == 0) {
        if (comp.module) |module| {
            total += @intFromBool(module.compile_log_decls.count() != 0);
        }
    }

    return @as(u32, @intCast(total));
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

    if (!build_options.only_core_functionality) {
        for (comp.failed_win32_resources.values()) |error_bundle| {
            try bundle.addBundleAsRoots(error_bundle);
        }
    }

    for (comp.lld_errors.items) |lld_error| {
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
    if (comp.alloc_failure_occurred) {
        try bundle.addRootErrorMessage(.{
            .msg = try bundle.addString("memory allocation failure"),
        });
    }
    if (comp.module) |module| {
        for (module.failed_files.keys(), module.failed_files.values()) |file, error_msg| {
            if (error_msg) |msg| {
                try addModuleErrorMsg(module, &bundle, msg.*);
            } else {
                // Must be ZIR errors. Note that this may include AST errors.
                // addZirErrorMessages asserts that the tree is loaded.
                _ = try file.getTree(gpa);
                try addZirErrorMessages(&bundle, file);
            }
        }
        for (module.failed_embed_files.values()) |error_msg| {
            try addModuleErrorMsg(module, &bundle, error_msg.*);
        }
        for (module.failed_decls.keys(), module.failed_decls.values()) |decl_index, error_msg| {
            // Skip errors for Decls within files that had a parse failure.
            // We'll try again once parsing succeeds.
            if (module.declFileScope(decl_index).okToReportErrors()) {
                try addModuleErrorMsg(module, &bundle, error_msg.*);
                if (module.cimport_errors.get(decl_index)) |errors| {
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
        }
        if (module.emit_h) |emit_h| {
            for (emit_h.failed_decls.keys(), emit_h.failed_decls.values()) |decl_index, error_msg| {
                // Skip errors for Decls within files that had a parse failure.
                // We'll try again once parsing succeeds.
                if (module.declFileScope(decl_index).okToReportErrors()) {
                    try addModuleErrorMsg(module, &bundle, error_msg.*);
                }
            }
        }
        for (module.failed_exports.values()) |value| {
            try addModuleErrorMsg(module, &bundle, value.*);
        }

        const actual_error_count = module.global_error_set.entries.len - 1;
        if (actual_error_count > module.error_limit) {
            try bundle.addRootErrorMessage(.{
                .msg = try bundle.printString("module used more errors than possible: used {d}, max {d}", .{
                    actual_error_count, module.error_limit,
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
        if (comp.link_error_flags.no_entry_point_found) {
            try bundle.addRootErrorMessage(.{
                .msg = try bundle.addString("no entry point found"),
            });
        }
    }

    if (comp.link_error_flags.missing_libc) {
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

    for (comp.link_errors.items) |link_err| {
        try bundle.addRootErrorMessage(.{
            .msg = try bundle.addString(link_err.msg),
            .notes_len = @intCast(link_err.notes.len),
        });
        const notes_start = try bundle.reserveNotes(@intCast(link_err.notes.len));
        for (link_err.notes, 0..) |note, i| {
            bundle.extra.items[notes_start + i] = @intFromEnum(try bundle.addErrorMessage(.{
                .msg = try bundle.addString(note.msg),
            }));
        }
    }

    if (comp.module) |module| {
        if (bundle.root_list.items.len == 0 and module.compile_log_decls.count() != 0) {
            const keys = module.compile_log_decls.keys();
            const values = module.compile_log_decls.values();
            // First one will be the error; subsequent ones will be notes.
            const err_decl = module.declPtr(keys[0]);
            const src_loc = err_decl.nodeOffsetSrcLoc(values[0], module);
            const err_msg = Module.ErrorMsg{
                .src_loc = src_loc,
                .msg = "found compile log statement",
                .notes = try gpa.alloc(Module.ErrorMsg, module.compile_log_decls.count() - 1),
            };
            defer gpa.free(err_msg.notes);

            for (keys[1..], 0..) |key, i| {
                const note_decl = module.declPtr(key);
                err_msg.notes[i] = .{
                    .src_loc = note_decl.nodeOffsetSrcLoc(values[i + 1], module),
                    .msg = "also here",
                };
            }

            try addModuleErrorMsg(module, &bundle, err_msg);
        }
    }

    assert(comp.totalErrorCount() == bundle.root_list.items.len);

    const compile_log_text = if (comp.module) |m| m.compile_log_text.items else "";
    return bundle.toOwnedBundle(compile_log_text);
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

pub fn addModuleErrorMsg(mod: *Module, eb: *ErrorBundle.Wip, module_err_msg: Module.ErrorMsg) !void {
    const gpa = eb.gpa;
    const ip = &mod.intern_pool;
    const err_source = module_err_msg.src_loc.file_scope.getSource(gpa) catch |err| {
        const file_path = try module_err_msg.src_loc.file_scope.fullPath(gpa);
        defer gpa.free(file_path);
        try eb.addRootErrorMessage(.{
            .msg = try eb.printString("unable to load '{s}': {s}", .{
                file_path, @errorName(err),
            }),
        });
        return;
    };
    const err_span = try module_err_msg.src_loc.span(gpa);
    const err_loc = std.zig.findLineColumn(err_source.bytes, err_span.main);
    const file_path = try module_err_msg.src_loc.file_scope.fullPath(gpa);
    defer gpa.free(file_path);

    var ref_traces: std.ArrayListUnmanaged(ErrorBundle.ReferenceTrace) = .{};
    defer ref_traces.deinit(gpa);

    const remaining_references: ?u32 = remaining: {
        if (mod.comp.reference_trace) |_| {
            if (module_err_msg.hidden_references > 0) break :remaining module_err_msg.hidden_references;
        } else {
            if (module_err_msg.reference_trace.len > 0) break :remaining 0;
        }
        break :remaining null;
    };
    try ref_traces.ensureTotalCapacityPrecise(gpa, module_err_msg.reference_trace.len +
        @intFromBool(remaining_references != null));

    for (module_err_msg.reference_trace) |module_reference| {
        const source = try module_reference.src_loc.file_scope.getSource(gpa);
        const span = try module_reference.src_loc.span(gpa);
        const loc = std.zig.findLineColumn(source.bytes, span.main);
        const rt_file_path = try module_reference.src_loc.file_scope.fullPath(gpa);
        defer gpa.free(rt_file_path);
        ref_traces.appendAssumeCapacity(.{
            .decl_name = try eb.addString(module_reference.decl.toSlice(ip)),
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
    if (remaining_references) |remaining| ref_traces.appendAssumeCapacity(
        .{ .decl_name = remaining, .src_loc = .none },
    );

    const src_loc = try eb.addSourceLocation(.{
        .src_path = try eb.addString(file_path),
        .span_start = err_span.start,
        .span_main = err_span.main,
        .span_end = err_span.end,
        .line = @intCast(err_loc.line),
        .column = @intCast(err_loc.column),
        .source_line = if (module_err_msg.src_loc.lazy == .entire_file)
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
    var notes: std.ArrayHashMapUnmanaged(ErrorBundle.ErrorMessage, void, ErrorNoteHashContext, true) = .{};
    defer notes.deinit(gpa);

    for (module_err_msg.notes) |module_note| {
        const source = try module_note.src_loc.file_scope.getSource(gpa);
        const span = try module_note.src_loc.span(gpa);
        const loc = std.zig.findLineColumn(source.bytes, span.main);
        const note_file_path = try module_note.src_loc.file_scope.fullPath(gpa);
        defer gpa.free(note_file_path);

        const gop = try notes.getOrPutContext(gpa, .{
            .msg = try eb.addString(module_note.msg),
            .src_loc = try eb.addSourceLocation(.{
                .src_path = try eb.addString(note_file_path),
                .span_start = span.start,
                .span_main = span.main,
                .span_end = span.end,
                .line = @intCast(loc.line),
                .column = @intCast(loc.column),
                .source_line = if (err_loc.eql(loc)) 0 else try eb.addString(loc.source_line),
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

pub fn addZirErrorMessages(eb: *ErrorBundle.Wip, file: *Module.File) !void {
    assert(file.zir_loaded);
    assert(file.tree_loaded);
    assert(file.source_loaded);
    const gpa = eb.gpa;
    const src_path = try file.fullPath(gpa);
    defer gpa.free(src_path);
    return eb.addZirErrorMessages(file.zir, file.tree, file.source, src_path);
}

pub fn performAllTheWork(
    comp: *Compilation,
    main_progress_node: *std.Progress.Node,
) error{ TimerUnsupported, OutOfMemory }!void {
    // Here we queue up all the AstGen tasks first, followed by C object compilation.
    // We wait until the AstGen tasks are all completed before proceeding to the
    // (at least for now) single-threaded main work queue. However, C object compilation
    // only needs to be finished by the end of this function.

    var zir_prog_node = main_progress_node.start("AST Lowering", 0);
    defer zir_prog_node.end();

    var wasm_prog_node = main_progress_node.start("Compile Autodocs", 0);
    defer wasm_prog_node.end();

    var c_obj_prog_node = main_progress_node.start("Compile C Objects", comp.c_source_files.len);
    defer c_obj_prog_node.end();

    var win32_resource_prog_node = main_progress_node.start("Compile Win32 Resources", comp.rc_source_files.len);
    defer win32_resource_prog_node.end();

    comp.work_queue_wait_group.reset();
    defer comp.work_queue_wait_group.wait();

    if (!build_options.only_c and !build_options.only_core_functionality) {
        if (comp.docs_emit != null) {
            try taskDocsCopy(comp, &comp.work_queue_wait_group);
            comp.work_queue_wait_group.spawnManager(workerDocsWasm, .{ comp, &wasm_prog_node });
        }
    }

    {
        const astgen_frame = tracy.namedFrame("astgen");
        defer astgen_frame.end();

        comp.astgen_wait_group.reset();
        defer comp.astgen_wait_group.wait();

        // builtin.zig is handled specially for two reasons:
        // 1. to avoid race condition of zig processes truncating each other's builtin.zig files
        // 2. optimization; in the hot path it only incurs a stat() syscall, which happens
        //    in the `astgen_wait_group`.
        if (comp.job_queued_update_builtin_zig) b: {
            comp.job_queued_update_builtin_zig = false;
            const zcu = comp.module orelse break :b;
            _ = zcu;
            // TODO put all the modules in a flat array to make them easy to iterate.
            var seen: std.AutoArrayHashMapUnmanaged(*Package.Module, void) = .{};
            defer seen.deinit(comp.gpa);
            try seen.put(comp.gpa, comp.root_mod, {});
            var i: usize = 0;
            while (i < seen.count()) : (i += 1) {
                const mod = seen.keys()[i];
                for (mod.deps.values()) |dep|
                    try seen.put(comp.gpa, dep, {});

                const file = mod.builtin_file orelse continue;

                comp.astgen_wait_group.start();
                try comp.thread_pool.spawn(workerUpdateBuiltinZigFile, .{
                    comp, mod, file, &comp.astgen_wait_group,
                });
            }
        }

        while (comp.astgen_work_queue.readItem()) |file| {
            comp.astgen_wait_group.start();
            try comp.thread_pool.spawn(workerAstGenFile, .{
                comp, file, &zir_prog_node, &comp.astgen_wait_group, .root,
            });
        }

        while (comp.embed_file_work_queue.readItem()) |embed_file| {
            comp.astgen_wait_group.start();
            try comp.thread_pool.spawn(workerCheckEmbedFile, .{
                comp, embed_file, &comp.astgen_wait_group,
            });
        }

        while (comp.c_object_work_queue.readItem()) |c_object| {
            comp.work_queue_wait_group.start();
            try comp.thread_pool.spawn(workerUpdateCObject, .{
                comp, c_object, &c_obj_prog_node, &comp.work_queue_wait_group,
            });
        }

        if (!build_options.only_core_functionality) {
            while (comp.win32_resource_work_queue.readItem()) |win32_resource| {
                comp.work_queue_wait_group.start();
                try comp.thread_pool.spawn(workerUpdateWin32Resource, .{
                    comp, win32_resource, &win32_resource_prog_node, &comp.work_queue_wait_group,
                });
            }
        }
    }

    if (comp.module) |mod| {
        try reportMultiModuleErrors(mod);
        try mod.flushRetryableFailures();
        mod.sema_prog_node = main_progress_node.start("Semantic Analysis", 0);
        mod.sema_prog_node.activate();
    }
    defer if (comp.module) |mod| {
        mod.sema_prog_node.end();
        mod.sema_prog_node = undefined;
    };

    while (true) {
        if (comp.work_queue.readItem()) |work_item| {
            try processOneJob(comp, work_item, main_progress_node);
            continue;
        }
        if (comp.module) |zcu| {
            // If there's no work queued, check if there's anything outdated
            // which we need to work on, and queue it if so.
            if (try zcu.findOutdatedToAnalyze()) |outdated| {
                switch (outdated.unwrap()) {
                    .decl => |decl| try comp.work_queue.writeItem(.{ .analyze_decl = decl }),
                    .func => |func| try comp.work_queue.writeItem(.{ .codegen_func = func }),
                }
                continue;
            }
        }
        break;
    }

    if (comp.job_queued_compiler_rt_lib) {
        comp.job_queued_compiler_rt_lib = false;
        buildCompilerRtOneShot(comp, .Lib, &comp.compiler_rt_lib, main_progress_node);
    }

    if (comp.job_queued_compiler_rt_obj) {
        comp.job_queued_compiler_rt_obj = false;
        buildCompilerRtOneShot(comp, .Obj, &comp.compiler_rt_obj, main_progress_node);
    }
}

fn processOneJob(comp: *Compilation, job: Job, prog_node: *std.Progress.Node) !void {
    switch (job) {
        .codegen_decl => |decl_index| {
            const module = comp.module.?;
            const decl = module.declPtr(decl_index);

            switch (decl.analysis) {
                .unreferenced => unreachable,
                .in_progress => unreachable,

                .file_failure,
                .sema_failure,
                .codegen_failure,
                .dependency_failure,
                => return,

                .complete => {
                    const named_frame = tracy.namedFrame("codegen_decl");
                    defer named_frame.end();

                    assert(decl.has_tv);

                    try module.linkerUpdateDecl(decl_index);
                    return;
                },
            }
        },
        .codegen_func => |func| {
            const named_frame = tracy.namedFrame("codegen_func");
            defer named_frame.end();

            const module = comp.module.?;
            module.ensureFuncBodyAnalyzed(func) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => return,
            };
        },
        .emit_h_decl => |decl_index| {
            const module = comp.module.?;
            const decl = module.declPtr(decl_index);

            switch (decl.analysis) {
                .unreferenced => unreachable,
                .in_progress => unreachable,

                .file_failure,
                .sema_failure,
                .dependency_failure,
                => return,

                // emit-h only requires semantic analysis of the Decl to be complete,
                // it does not depend on machine code generation to succeed.
                .codegen_failure, .complete => {
                    const named_frame = tracy.namedFrame("emit_h_decl");
                    defer named_frame.end();

                    const gpa = comp.gpa;
                    const emit_h = module.emit_h.?;
                    _ = try emit_h.decl_table.getOrPut(gpa, decl_index);
                    const decl_emit_h = emit_h.declPtr(decl_index);
                    const fwd_decl = &decl_emit_h.fwd_decl;
                    fwd_decl.shrinkRetainingCapacity(0);
                    var ctypes_arena = std.heap.ArenaAllocator.init(gpa);
                    defer ctypes_arena.deinit();

                    var dg: c_codegen.DeclGen = .{
                        .gpa = gpa,
                        .zcu = module,
                        .mod = module.namespacePtr(decl.src_namespace).file_scope.mod,
                        .error_msg = null,
                        .pass = .{ .decl = decl_index },
                        .is_naked_fn = false,
                        .fwd_decl = fwd_decl.toManaged(gpa),
                        .ctype_pool = c_codegen.CType.Pool.empty,
                        .scratch = .{},
                        .anon_decl_deps = .{},
                        .aligned_anon_decls = .{},
                    };
                    defer {
                        fwd_decl.* = dg.fwd_decl.moveToUnmanaged();
                        fwd_decl.shrinkAndFree(gpa, fwd_decl.items.len);
                        dg.ctype_pool.deinit(gpa);
                        dg.scratch.deinit(gpa);
                    }
                    try dg.ctype_pool.init(gpa);

                    c_codegen.genHeader(&dg) catch |err| switch (err) {
                        error.AnalysisFail => {
                            try emit_h.failed_decls.put(gpa, decl_index, dg.error_msg.?);
                            return;
                        },
                        else => |e| return e,
                    };
                },
            }
        },
        .analyze_decl => |decl_index| {
            const module = comp.module.?;
            module.ensureDeclAnalyzed(decl_index) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => return,
            };
            const decl = module.declPtr(decl_index);
            if (decl.kind == .@"test" and comp.config.is_test) {
                // Tests are always emitted in test binaries. The decl_refs are created by
                // Module.populateTestFunctions, but this will not queue body analysis, so do
                // that now.
                try module.ensureFuncBodyAnalysisQueued(decl.val.toIntern());
            }
        },
        .update_line_number => |decl_index| {
            const named_frame = tracy.namedFrame("update_line_number");
            defer named_frame.end();

            const gpa = comp.gpa;
            const module = comp.module.?;
            const decl = module.declPtr(decl_index);
            const lf = comp.bin_file.?;
            lf.updateDeclLineNumber(module, decl_index) catch |err| {
                try module.failed_decls.ensureUnusedCapacity(gpa, 1);
                module.failed_decls.putAssumeCapacityNoClobber(decl_index, try Module.ErrorMsg.create(
                    gpa,
                    decl.srcLoc(module),
                    "unable to update line number: {s}",
                    .{@errorName(err)},
                ));
                decl.analysis = .codegen_failure;
                try module.retryable_failures.append(gpa, InternPool.Depender.wrap(.{ .decl = decl_index }));
            };
        },
        .analyze_mod => |pkg| {
            const named_frame = tracy.namedFrame("analyze_mod");
            defer named_frame.end();

            const module = comp.module.?;
            module.semaPkg(pkg) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => return,
            };
        },
        .glibc_crt_file => |crt_file| {
            const named_frame = tracy.namedFrame("glibc_crt_file");
            defer named_frame.end();

            glibc.buildCRTFile(comp, crt_file, prog_node) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(.glibc_crt_file, "unable to build glibc CRT file: {s}", .{
                    @errorName(err),
                });
            };
        },
        .glibc_shared_objects => {
            const named_frame = tracy.namedFrame("glibc_shared_objects");
            defer named_frame.end();

            glibc.buildSharedObjects(comp, prog_node) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(
                    .glibc_shared_objects,
                    "unable to build glibc shared objects: {s}",
                    .{@errorName(err)},
                );
            };
        },
        .musl_crt_file => |crt_file| {
            const named_frame = tracy.namedFrame("musl_crt_file");
            defer named_frame.end();

            musl.buildCRTFile(comp, crt_file, prog_node) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(
                    .musl_crt_file,
                    "unable to build musl CRT file: {s}",
                    .{@errorName(err)},
                );
            };
        },
        .mingw_crt_file => |crt_file| {
            const named_frame = tracy.namedFrame("mingw_crt_file");
            defer named_frame.end();

            mingw.buildCRTFile(comp, crt_file, prog_node) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(
                    .mingw_crt_file,
                    "unable to build mingw-w64 CRT file {s}: {s}",
                    .{ @tagName(crt_file), @errorName(err) },
                );
            };
        },
        .windows_import_lib => |index| {
            if (build_options.only_c)
                @panic("building import libs not included in core functionality");

            const named_frame = tracy.namedFrame("windows_import_lib");
            defer named_frame.end();

            const link_lib = comp.system_libs.keys()[index];
            mingw.buildImportLib(comp, link_lib) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(
                    .windows_import_lib,
                    "unable to generate DLL import .lib file for {s}: {s}",
                    .{ link_lib, @errorName(err) },
                );
            };
        },
        .libunwind => {
            const named_frame = tracy.namedFrame("libunwind");
            defer named_frame.end();

            libunwind.buildStaticLib(comp, prog_node) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(
                    .libunwind,
                    "unable to build libunwind: {s}",
                    .{@errorName(err)},
                );
            };
        },
        .libcxx => {
            const named_frame = tracy.namedFrame("libcxx");
            defer named_frame.end();

            libcxx.buildLibCXX(comp, prog_node) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(
                    .libcxx,
                    "unable to build libcxx: {s}",
                    .{@errorName(err)},
                );
            };
        },
        .libcxxabi => {
            const named_frame = tracy.namedFrame("libcxxabi");
            defer named_frame.end();

            libcxx.buildLibCXXABI(comp, prog_node) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(
                    .libcxxabi,
                    "unable to build libcxxabi: {s}",
                    .{@errorName(err)},
                );
            };
        },
        .libtsan => {
            const named_frame = tracy.namedFrame("libtsan");
            defer named_frame.end();

            libtsan.buildTsan(comp, prog_node) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.SubCompilationFailed => return, // error reported already
                else => comp.lockAndSetMiscFailure(
                    .libtsan,
                    "unable to build TSAN library: {s}",
                    .{@errorName(err)},
                ),
            };
        },
        .wasi_libc_crt_file => |crt_file| {
            const named_frame = tracy.namedFrame("wasi_libc_crt_file");
            defer named_frame.end();

            wasi_libc.buildCRTFile(comp, crt_file, prog_node) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(
                    .wasi_libc_crt_file,
                    "unable to build WASI libc CRT file: {s}",
                    .{@errorName(err)},
                );
            };
        },
        .zig_libc => {
            const named_frame = tracy.namedFrame("zig_libc");
            defer named_frame.end();

            comp.buildOutputFromZig(
                "c.zig",
                .Lib,
                &comp.libc_static_lib,
                .zig_libc,
                prog_node,
            ) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.SubCompilationFailed => return, // error reported already
                else => comp.lockAndSetMiscFailure(
                    .zig_libc,
                    "unable to build zig's multitarget libc: {s}",
                    .{@errorName(err)},
                ),
            };
        },
    }
}

fn taskDocsCopy(comp: *Compilation, wg: *WaitGroup) !void {
    wg.start();
    errdefer wg.finish();
    try comp.thread_pool.spawn(workerDocsCopy, .{ comp, wg });
}

fn workerDocsCopy(comp: *Compilation, wg: *WaitGroup) void {
    defer wg.finish();
    docsCopyFallible(comp) catch |err| {
        return comp.lockAndSetMiscFailure(
            .docs_copy,
            "unable to copy autodocs artifacts: {s}",
            .{@errorName(err)},
        );
    };
}

fn docsCopyFallible(comp: *Compilation) anyerror!void {
    const zcu = comp.module orelse
        return comp.lockAndSetMiscFailure(.docs_copy, "no Zig code to document", .{});

    const emit = comp.docs_emit.?;
    var out_dir = emit.directory.handle.makeOpenPath(emit.sub_path, .{}) catch |err| {
        return comp.lockAndSetMiscFailure(
            .docs_copy,
            "unable to create output directory '{}{s}': {s}",
            .{ emit.directory, emit.sub_path, @errorName(err) },
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
            .{ emit.directory, emit.sub_path, @errorName(err) },
        );
    };
    defer tar_file.close();

    var seen_table: std.AutoArrayHashMapUnmanaged(*Package.Module, []const u8) = .{};
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

    const padding_buffer = [1]u8{0} ** 512;

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

        const stat = file.stat() catch |err| {
            return comp.lockAndSetMiscFailure(.docs_copy, "unable to stat '{}{s}': {s}", .{
                root, entry.path, @errorName(err),
            });
        };

        var file_header = std.tar.output.Header.init();
        file_header.typeflag = .regular;
        try file_header.setPath(name, entry.path);
        try file_header.setSize(stat.size);
        try file_header.updateChecksum();

        const header_bytes = std.mem.asBytes(&file_header);
        const padding = p: {
            const remainder: u16 = @intCast(stat.size % 512);
            const n = if (remainder > 0) 512 - remainder else 0;
            break :p padding_buffer[0..n];
        };

        var header_and_trailer: [2]std.posix.iovec_const = .{
            .{ .base = header_bytes.ptr, .len = header_bytes.len },
            .{ .base = padding.ptr, .len = padding.len },
        };

        try tar_file.writeFileAll(file, .{
            .in_len = stat.size,
            .headers_and_trailers = &header_and_trailer,
            .header_count = 1,
        });
    }
}

fn workerDocsWasm(comp: *Compilation, prog_node: *std.Progress.Node) void {
    workerDocsWasmFallible(comp, prog_node) catch |err| {
        comp.lockAndSetMiscFailure(.docs_wasm, "unable to build autodocs: {s}", .{
            @errorName(err),
        });
    };
}

fn workerDocsWasmFallible(comp: *Compilation, prog_node: *std.Progress.Node) anyerror!void {
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
                .bulk_memory,
                // .extended_const, not supported by Safari
                .multivalue,
                .mutable_globals,
                .nontrapping_fptoint,
                .reference_types,
                //.relaxed_simd, not supported by Firefox or Safari
                .sign_ext,
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
        .builtin_modules = null, // there is only one module in this compilation
    });
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
    var out_dir = emit.directory.handle.makeOpenPath(emit.sub_path, .{}) catch |err| {
        return comp.lockAndSetMiscFailure(
            .docs_copy,
            "unable to create output directory '{}{s}': {s}",
            .{ emit.directory, emit.sub_path, @errorName(err) },
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
            emit.directory,
            emit.sub_path,
            @errorName(err),
        });
    };
}

const AstGenSrc = union(enum) {
    root,
    import: struct {
        importing_file: *Module.File,
        import_tok: std.zig.Ast.TokenIndex,
    },
};

fn workerAstGenFile(
    comp: *Compilation,
    file: *Module.File,
    prog_node: *std.Progress.Node,
    wg: *WaitGroup,
    src: AstGenSrc,
) void {
    defer wg.finish();

    var child_prog_node = prog_node.start(file.sub_file_path, 0);
    child_prog_node.activate();
    defer child_prog_node.end();

    const mod = comp.module.?;
    mod.astGenFile(file) catch |err| switch (err) {
        error.AnalysisFail => return,
        else => {
            file.status = .retryable_failure;
            comp.reportRetryableAstGenError(src, file, err) catch |oom| switch (oom) {
                // Swallowing this error is OK because it's implied to be OOM when
                // there is a missing `failed_files` error message.
                error.OutOfMemory => {},
            };
            return;
        },
    };

    // Pre-emptively look for `@import` paths and queue them up.
    // If we experience an error preemptively fetching the
    // file, just ignore it and let it happen again later during Sema.
    assert(file.zir_loaded);
    const imports_index = file.zir.extra[@intFromEnum(Zir.ExtraIndex.imports)];
    if (imports_index != 0) {
        const extra = file.zir.extraData(Zir.Inst.Imports, imports_index);
        var import_i: u32 = 0;
        var extra_index = extra.end;

        while (import_i < extra.data.imports_len) : (import_i += 1) {
            const item = file.zir.extraData(Zir.Inst.Imports.Item, extra_index);
            extra_index = item.end;

            const import_path = file.zir.nullTerminatedString(item.data.name);
            // `@import("builtin")` is handled specially.
            if (mem.eql(u8, import_path, "builtin")) continue;

            const import_result = blk: {
                comp.mutex.lock();
                defer comp.mutex.unlock();

                const res = mod.importFile(file, import_path) catch continue;
                if (!res.is_pkg) {
                    res.file.addReference(mod.*, .{ .import = .{
                        .file_scope = file,
                        .parent_decl_node = 0,
                        .lazy = .{ .token_abs = item.data.token },
                    } }) catch continue;
                }
                break :blk res;
            };
            if (import_result.is_new) {
                log.debug("AstGen of {s} has import '{s}'; queuing AstGen of {s}", .{
                    file.sub_file_path, import_path, import_result.file.sub_file_path,
                });
                const sub_src: AstGenSrc = .{ .import = .{
                    .importing_file = file,
                    .import_tok = item.data.token,
                } };
                wg.start();
                comp.thread_pool.spawn(workerAstGenFile, .{
                    comp, import_result.file, prog_node, wg, sub_src,
                }) catch {
                    wg.finish();
                    continue;
                };
            }
        }
    }
}

fn workerUpdateBuiltinZigFile(
    comp: *Compilation,
    mod: *Package.Module,
    file: *Module.File,
    wg: *WaitGroup,
) void {
    defer wg.finish();
    Builtin.populateFile(comp, mod, file) catch |err| {
        comp.mutex.lock();
        defer comp.mutex.unlock();

        comp.setMiscFailure(.write_builtin_zig, "unable to write '{}{s}': {s}", .{
            mod.root, mod.root_src_path, @errorName(err),
        });
    };
}

fn workerCheckEmbedFile(
    comp: *Compilation,
    embed_file: *Module.EmbedFile,
    wg: *WaitGroup,
) void {
    defer wg.finish();

    comp.detectEmbedFileUpdate(embed_file) catch |err| {
        comp.reportRetryableEmbedFileError(embed_file, err) catch |oom| switch (oom) {
            // Swallowing this error is OK because it's implied to be OOM when
            // there is a missing `failed_embed_files` error message.
            error.OutOfMemory => {},
        };
        return;
    };
}

fn detectEmbedFileUpdate(comp: *Compilation, embed_file: *Module.EmbedFile) !void {
    const mod = comp.module.?;
    const ip = &mod.intern_pool;
    var file = try embed_file.owner.root.openFile(embed_file.sub_file_path.toSlice(ip), .{});
    defer file.close();

    const stat = try file.stat();

    const unchanged_metadata =
        stat.size == embed_file.stat.size and
        stat.mtime == embed_file.stat.mtime and
        stat.inode == embed_file.stat.inode;

    if (unchanged_metadata) return;

    @panic("TODO: handle embed file incremental update");
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
    out_zig_path: []u8,
    cache_hit: bool,
    errors: std.zig.ErrorBundle,

    pub fn deinit(result: *CImportResult, gpa: mem.Allocator) void {
        result.errors.deinit(gpa);
    }
};

/// Caller owns returned memory.
/// This API is currently coupled pretty tightly to stage1's needs; it will need to be reworked
/// a bit when we want to start using it from self-hosted.
pub fn cImport(comp: *Compilation, c_src: []const u8, owner_mod: *Package.Module) !CImportResult {
    if (build_options.only_core_functionality) @panic("@cImport is not available in a zig2.c build");
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

        try zig_cache_tmp_dir.writeFile(cimport_basename, c_src);
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
                            .out_zig_path = "",
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

        const digest = man.final();
        const o_sub_path = try std.fs.path.join(arena, &[_][]const u8{ "o", &digest });
        var o_dir = try comp.local_cache_directory.handle.makeOpenPath(o_sub_path, .{});
        defer o_dir.close();

        var out_zig_file = try o_dir.createFile(cimport_zig_basename, .{});
        defer out_zig_file.close();

        const formatted = try tree.render(comp.gpa);
        defer comp.gpa.free(formatted);

        try out_zig_file.writeAll(formatted);

        break :digest digest;
    } else man.final();

    if (man.have_exclusive_lock) {
        // Write the updated manifest. This is a no-op if the manifest is not dirty. Note that it is
        // possible we had a hit and the manifest is dirty, for example if the file mtime changed but
        // the contents were the same, we hit the cache but the manifest is dirty and we need to update
        // it to prevent doing a full file content comparison the next time around.
        man.writeManifest() catch |err| {
            log.warn("failed to write cache manifest for C import: {s}", .{@errorName(err)});
        };
    }

    const out_zig_path = try comp.local_cache_directory.join(comp.arena, &.{
        "o", &digest, cimport_zig_basename,
    });
    if (comp.verbose_cimport) {
        log.info("C import output: {s}", .{out_zig_path});
    }
    return CImportResult{
        .out_zig_path = out_zig_path,
        .cache_hit = actual_hit,
        .errors = std.zig.ErrorBundle.empty,
    };
}

fn workerUpdateCObject(
    comp: *Compilation,
    c_object: *CObject,
    progress_node: *std.Progress.Node,
    wg: *WaitGroup,
) void {
    defer wg.finish();

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
    progress_node: *std.Progress.Node,
    wg: *WaitGroup,
) void {
    defer wg.finish();

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

fn buildCompilerRtOneShot(
    comp: *Compilation,
    output_mode: std.builtin.OutputMode,
    out: *?CRTFile,
    prog_node: *std.Progress.Node,
) void {
    comp.buildOutputFromZig(
        "compiler_rt.zig",
        output_mode,
        out,
        .compiler_rt,
        prog_node,
    ) catch |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(
            .compiler_rt,
            "unable to build compiler_rt: {s}",
            .{@errorName(err)},
        ),
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

fn reportRetryableAstGenError(
    comp: *Compilation,
    src: AstGenSrc,
    file: *Module.File,
    err: anyerror,
) error{OutOfMemory}!void {
    const mod = comp.module.?;
    const gpa = mod.gpa;

    file.status = .retryable_failure;

    const src_loc: Module.SrcLoc = switch (src) {
        .root => .{
            .file_scope = file,
            .parent_decl_node = 0,
            .lazy = .entire_file,
        },
        .import => |info| blk: {
            const importing_file = info.importing_file;

            break :blk .{
                .file_scope = importing_file,
                .parent_decl_node = 0,
                .lazy = .{ .token_abs = info.import_tok },
            };
        },
    };

    const err_msg = try Module.ErrorMsg.create(gpa, src_loc, "unable to load '{}{s}': {s}", .{
        file.mod.root, file.sub_file_path, @errorName(err),
    });
    errdefer err_msg.destroy(gpa);

    {
        comp.mutex.lock();
        defer comp.mutex.unlock();
        try mod.failed_files.putNoClobber(gpa, file, err_msg);
    }
}

fn reportRetryableEmbedFileError(
    comp: *Compilation,
    embed_file: *Module.EmbedFile,
    err: anyerror,
) error{OutOfMemory}!void {
    const mod = comp.module.?;
    const gpa = mod.gpa;
    const src_loc = embed_file.src_loc;
    const ip = &mod.intern_pool;
    const err_msg = try Module.ErrorMsg.create(gpa, src_loc, "unable to load '{}{s}': {s}", .{
        embed_file.owner.root,
        embed_file.sub_file_path.toSlice(ip),
        @errorName(err),
    });

    errdefer err_msg.destroy(gpa);

    {
        comp.mutex.lock();
        defer comp.mutex.unlock();
        try mod.failed_embed_files.putNoClobber(gpa, embed_file, err_msg);
    }
}

fn updateCObject(comp: *Compilation, c_object: *CObject, c_obj_prog_node: *std.Progress.Node) !void {
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

    if (c_object.clearStatus(comp.gpa)) {
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

    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const c_source_basename = std.fs.path.basename(c_object.src.src_path);

    c_obj_prog_node.activate();
    var child_progress_node = c_obj_prog_node.start(c_source_basename, 0);
    child_progress_node.activate();
    defer child_progress_node.end();

    // Special case when doing build-obj for just one C file. When there are more than one object
    // file and building an object we need to link them together, but with just one it should go
    // directly to the output file.
    const direct_o = comp.c_source_files.len == 1 and comp.module == null and
        comp.config.output_mode == .Obj and comp.objects.len == 0;
    const o_basename_noext = if (direct_o)
        comp.root_name
    else
        c_source_basename[0 .. c_source_basename.len - std.fs.path.extension(c_source_basename).len];

    const target = comp.getTarget();
    const o_ext = target.ofmt.fileExt(target.cpu.arch);
    const digest = if (!comp.disable_c_depfile and try man.hit()) man.final() else blk: {
        var argv = std.ArrayList([]const u8).init(comp.gpa);
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
        if (c_object.src.ext != null) {
            try argv.appendSlice(&[_][]const u8{ "-x", switch (ext) {
                .assembly => "assembler",
                .assembly_with_cpp => "assembler-with-cpp",
                .c => "c",
                .cpp => "c++",
                .h => "c-header",
                .hpp => "c++-header",
                .hm => "objective-c-header",
                .hmm => "objective-c++-header",
                .cu => "cuda",
                .m => "objective-c",
                .mm => "objective-c++",
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
                try lf.emit.directory.join(arena, &.{lf.emit.sub_path})
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
        const out_diag_path = try std.fmt.allocPrint(arena, "{s}.diag", .{out_obj_path});
        var zig_cache_tmp_dir = try comp.local_cache_directory.handle.makeOpenPath("tmp", .{});
        defer zig_cache_tmp_dir.close();

        const out_dep_path: ?[]const u8 = if (comp.disable_c_depfile or !ext.clangSupportsDepFile())
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
        if (comp.clang_passthrough_mode) {
            if (comp.emit_asm != null) {
                argv.appendAssumeCapacity("-S");
            } else if (comp.emit_llvm_ir != null) {
                argv.appendSliceAssumeCapacity(&.{ "-emit-llvm", "-S" });
            } else if (comp.emit_llvm_bc != null) {
                argv.appendAssumeCapacity("-emit-llvm");
            }
        } else {
            argv.appendSliceAssumeCapacity(&.{ "--serialize-diagnostics", out_diag_path });
        }

        if (comp.verbose_cc) {
            dump_argv(argv.items);
        }

        if (std.process.can_spawn) {
            var child = std.ChildProcess.init(argv.items, arena);
            if (comp.clang_passthrough_mode) {
                child.stdin_behavior = .Inherit;
                child.stdout_behavior = .Inherit;
                child.stderr_behavior = .Inherit;

                const term = child.spawnAndWait() catch |err| {
                    return comp.failCObj(c_object, "unable to spawn {s}: {s}", .{ argv.items[0], @errorName(err) });
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
                    return comp.failCObj(c_object, "unable to spawn {s}: {s}", .{ argv.items[0], @errorName(err) });
                };

                switch (term) {
                    .Exited => |code| {
                        if (code != 0) {
                            const bundle = CObject.Diag.Bundle.parse(comp.gpa, out_diag_path) catch |err| {
                                log.err("{}: failed to parse clang diagnostics: {s}", .{ err, stderr });
                                return comp.failCObj(c_object, "clang exited with code {d}", .{code});
                            };
                            zig_cache_tmp_dir.deleteFile(out_diag_path) catch |err| {
                                log.warn("failed to delete '{s}': {s}", .{ out_diag_path, @errorName(err) });
                            };
                            return comp.failCObjWithOwnedDiagBundle(c_object, bundle);
                        }
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
            // Just to save disk space, we delete the file because it is never needed again.
            zig_cache_tmp_dir.deleteFile(dep_basename) catch |err| {
                log.warn("failed to delete '{s}': {s}", .{ dep_file_path, @errorName(err) });
            };
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
            log.warn("failed to write cache manifest when compiling '{s}': {s}", .{ c_object.src.src_path, @errorName(err) });
        };
    }

    const o_basename = try std.fmt.allocPrint(arena, "{s}{s}", .{ o_basename_noext, o_ext });

    c_object.status = .{
        .success = .{
            .object_path = try comp.local_cache_directory.join(comp.gpa, &[_][]const u8{
                "o", &digest, o_basename,
            }),
            .lock = man.toOwnedLock(),
        },
    };
}

fn updateWin32Resource(comp: *Compilation, win32_resource: *Win32Resource, win32_resource_prog_node: *std.Progress.Node) !void {
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

    win32_resource_prog_node.activate();
    var child_progress_node = win32_resource_prog_node.start(src_basename, 0);
    child_progress_node.activate();
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

            // 1 is CREATEPROCESS_MANIFEST_RESOURCE_ID which is the default ID used for RT_MANIFEST resources
            // 24 is RT_MANIFEST
            const input = try std.fmt.allocPrint(arena, "1 24 \"{s}\"", .{fmtRcEscape(src_path)});
            try o_dir.writeFile(rc_basename, input);

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

            try spawnZigRc(comp, win32_resource, src_basename, arena, argv.items, &child_progress_node);

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

        try spawnZigRc(comp, win32_resource, src_basename, arena, argv.items, &child_progress_node);

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
            // Just to save disk space, we delete the file because it is never needed again.
            zig_cache_tmp_dir.deleteFile(dep_basename) catch |err| {
                log.warn("failed to delete '{s}': {s}", .{ out_dep_path, @errorName(err) });
            };
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
    src_basename: []const u8,
    arena: Allocator,
    argv: []const []const u8,
    child_progress_node: *std.Progress.Node,
) !void {
    var node_name: std.ArrayListUnmanaged(u8) = .{};
    defer node_name.deinit(arena);

    var child = std.ChildProcess.init(argv, arena);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

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
            .progress => {
                node_name.clearRetainingCapacity();
                // <resinator> is a special string that indicates that the child
                // process has reached resinator's main function
                if (std.mem.eql(u8, body, "<resinator>")) {
                    child_progress_node.setName(src_basename);
                }
                // Ignore 0-length strings since if multiple zig rc commands
                // are executed at the same time, only one will send progress strings
                // while the other(s) will send empty strings.
                else if (body.len > 0) {
                    try node_name.appendSlice(arena, "build 'zig rc'... ");
                    try node_name.appendSlice(arena, body);
                    child_progress_node.setName(node_name.items);
                }
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

pub fn tmpFilePath(comp: *Compilation, ally: Allocator, suffix: []const u8) error{OutOfMemory}![]const u8 {
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

    if (ext == .cpp) {
        try argv.append("-nostdinc++");
    }

    // We don't ever put `-fcolor-diagnostics` or `-fno-color-diagnostics` because in passthrough mode
    // we want Clang to infer it, and in normal mode we always want it off, which will be true since
    // clang will detect stderr as a pipe rather than a terminal.
    if (!comp.clang_passthrough_mode) {
        // Make stderr more easily parseable.
        try argv.append("-fno-caret-diagnostics");
    }

    if (comp.function_sections) {
        try argv.append("-ffunction-sections");
    }

    if (comp.data_sections) {
        try argv.append("-fdata-sections");
    }

    if (comp.no_builtin) {
        try argv.append("-fno-builtin");
    }

    if (comp.config.link_libcpp) {
        const libcxx_include_path = try std.fs.path.join(arena, &[_][]const u8{
            comp.zig_lib_directory.path.?, "libcxx", "include",
        });
        const libcxxabi_include_path = try std.fs.path.join(arena, &[_][]const u8{
            comp.zig_lib_directory.path.?, "libcxxabi", "include",
        });

        try argv.append("-isystem");
        try argv.append(libcxx_include_path);

        try argv.append("-isystem");
        try argv.append(libcxxabi_include_path);

        if (target.abi.isMusl()) {
            try argv.append("-D_LIBCPP_HAS_MUSL_LIBC");
        }
        try argv.append("-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS");
        try argv.append("-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS");
        try argv.append("-D_LIBCPP_HAS_NO_VENDOR_AVAILABILITY_ANNOTATIONS");

        if (!comp.config.any_non_single_threaded) {
            try argv.append("-D_LIBCPP_HAS_NO_THREADS");
        }

        // See the comment in libcxx.zig for more details about this.
        try argv.append("-D_LIBCPP_PSTL_CPU_BACKEND_SERIAL");

        try argv.append(try std.fmt.allocPrint(arena, "-D_LIBCPP_ABI_VERSION={d}", .{
            @intFromEnum(comp.libcxx_abi_version),
        }));
        try argv.append(try std.fmt.allocPrint(arena, "-D_LIBCPP_ABI_NAMESPACE=__{d}", .{
            @intFromEnum(comp.libcxx_abi_version),
        }));
    }

    if (comp.config.link_libunwind) {
        const libunwind_include_path = try std.fs.path.join(arena, &[_][]const u8{
            comp.zig_lib_directory.path.?, "libunwind", "include",
        });

        try argv.append("-isystem");
        try argv.append(libunwind_include_path);
    }

    if (comp.config.link_libc) {
        if (target.isGnuLibC()) {
            const target_version = target.os.version_range.linux.glibc;
            const glibc_minor_define = try std.fmt.allocPrint(arena, "-D__GLIBC_MINOR__={d}", .{
                target_version.minor,
            });
            try argv.append(glibc_minor_define);
        } else if (target.isMinGW()) {
            try argv.append("-D__MSVCRT_VERSION__=0xE00"); // use ucrt

            switch (ext) {
                .c, .cpp, .m, .mm, .h, .hpp, .hm, .hmm, .cu, .rc, .assembly, .assembly_with_cpp => {
                    const minver: u16 = @truncate(@intFromEnum(target.os.getVersionRange().windows.min) >> 16);
                    try argv.append(
                        try std.fmt.allocPrint(arena, "-D_WIN32_WINNT=0x{x:0>4}", .{minver}),
                    );
                },
                else => {},
            }
        }
    }

    const llvm_triple = try @import("codegen/llvm.zig").targetTriple(arena, target);
    try argv.appendSlice(&[_][]const u8{ "-target", llvm_triple });

    switch (ext) {
        .c, .cpp, .m, .mm, .h, .hpp, .hm, .hmm, .cu, .rc => {
            try argv.appendSlice(&[_][]const u8{
                "-nostdinc",
                "-fno-spell-checking",
            });
            if (comp.config.lto) {
                try argv.append("-flto");
            }

            if (ext == .mm) {
                try argv.append("-ObjC++");
            }

            for (comp.libc_framework_dir_list) |framework_dir| {
                try argv.appendSlice(&.{ "-iframework", framework_dir });
            }

            for (comp.framework_dirs) |framework_dir| {
                try argv.appendSlice(&.{ "-F", framework_dir });
            }

            // According to Rich Felker libc headers are supposed to go before C language headers.
            // However as noted by @dimenus, appending libc headers before c_headers breaks intrinsics
            // and other compiler specific items.
            const c_headers_dir = try std.fs.path.join(arena, &[_][]const u8{ comp.zig_lib_directory.path.?, "include" });
            try argv.append("-isystem");
            try argv.append(c_headers_dir);

            for (comp.libc_include_dir_list) |include_dir| {
                try argv.append("-isystem");
                try argv.append(include_dir);
            }

            if (target.cpu.model.llvm_name) |llvm_name| {
                try argv.appendSlice(&[_][]const u8{
                    "-Xclang", "-target-cpu", "-Xclang", llvm_name,
                });
            }

            // It would be really nice if there was a more compact way to communicate this info to Clang.
            const all_features_list = target.cpu.arch.allFeaturesList();
            try argv.ensureUnusedCapacity(all_features_list.len * 4);
            for (all_features_list, 0..) |feature, index_usize| {
                const index = @as(std.Target.Cpu.Feature.Set.Index, @intCast(index_usize));
                const is_enabled = target.cpu.features.isEnabled(index);

                if (feature.llvm_name) |llvm_name| {
                    argv.appendSliceAssumeCapacity(&[_][]const u8{ "-Xclang", "-target-feature", "-Xclang" });
                    const plus_or_minus = "-+"[@intFromBool(is_enabled)];
                    const arg = try std.fmt.allocPrint(arena, "{c}{s}", .{ plus_or_minus, llvm_name });
                    argv.appendAssumeCapacity(arg);
                }
            }
            if (mod.code_model != .default) {
                try argv.append(try std.fmt.allocPrint(arena, "-mcmodel={s}", .{@tagName(mod.code_model)}));
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
                    argv.appendAssumeCapacity("-Wno-overriding-t-option");
                },
                .ios, .tvos, .watchos => switch (target.cpu.arch) {
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

            if (target.cpu.arch.isThumb()) {
                try argv.append("-mthumb");
            }

            if (mod.sanitize_c and !mod.sanitize_thread) {
                try argv.append("-fsanitize=undefined");
                try argv.append("-fsanitize-trap=undefined");
                // It is very common, and well-defined, for a pointer on one side of a C ABI
                // to have a different but compatible element type. Examples include:
                // `char*` vs `uint8_t*` on a system with 8-bit bytes
                // `const char*` vs `char*`
                // `char*` vs `unsigned char*`
                // Without this flag, Clang would invoke UBSAN when such an extern
                // function was called.
                try argv.append("-fno-sanitize=function");
            } else if (mod.sanitize_c and mod.sanitize_thread) {
                try argv.append("-fsanitize=undefined,thread");
                try argv.append("-fsanitize-trap=undefined");
                try argv.append("-fno-sanitize=function");
            } else if (!mod.sanitize_c and mod.sanitize_thread) {
                try argv.append("-fsanitize=thread");
            }

            if (mod.red_zone) {
                try argv.append("-mred-zone");
            } else if (target_util.hasRedZone(target)) {
                try argv.append("-mno-red-zone");
            }

            if (mod.omit_frame_pointer) {
                try argv.append("-fomit-frame-pointer");
            } else {
                try argv.append("-fno-omit-frame-pointer");
            }

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

            if (target_util.supports_fpic(target) and mod.pic) {
                try argv.append("-fPIC");
            }

            if (mod.unwind_tables) {
                try argv.append("-funwind-tables");
            } else {
                try argv.append("-fno-unwind-tables");
            }
        },
        .shared_library, .ll, .bc, .unknown, .static_library, .object, .def, .zig, .res, .manifest => {},
        .assembly, .assembly_with_cpp => {
            if (ext == .assembly_with_cpp) {
                const c_headers_dir = try std.fs.path.join(arena, &[_][]const u8{ comp.zig_lib_directory.path.?, "include" });
                try argv.append("-isystem");
                try argv.append(c_headers_dir);
            }

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

                    if (std.Target.mips.featureSetHas(target.cpu.features, .soft_float)) {
                        try argv.append("-msoft-float");
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

    if (target_util.llvmMachineAbi(target)) |mabi| {
        try argv.append(try std.fmt.allocPrint(arena, "-mabi={s}", .{mabi}));
    }

    if (out_dep_path) |p| {
        try argv.appendSlice(&[_][]const u8{ "-MD", "-MV", "-MF", p });
    }

    // We never want clang to invoke the system assembler for anything. So we would want
    // this option always enabled. However, it only matters for some targets. To avoid
    // "unused parameter" warnings, and to keep CLI spam to a minimum, we only put this
    // flag on the command line if it is necessary.
    if (target_util.clangMightShellOutForAssembly(target)) {
        try argv.append("-integrated-as");
    }

    if (target.os.tag == .freestanding) {
        try argv.append("-ffreestanding");
    }

    if (mod.resolved_target.is_native_os and mod.resolved_target.is_native_abi) {
        try argv.ensureUnusedCapacity(comp.native_system_include_paths.len * 2);
        for (comp.native_system_include_paths) |include_path| {
            argv.appendAssumeCapacity("-isystem");
            argv.appendAssumeCapacity(include_path);
        }
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
    @setCold(true);
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
    @setCold(true);
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
    @setCold(true);
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
    @setCold(true);
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
    cu,
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

    pub fn clangSupportsDepFile(ext: FileExt) bool {
        return switch (ext) {
            .c, .cpp, .h, .hpp, .hm, .hmm, .m, .mm, .cu => true,

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

    pub fn canonicalName(ext: FileExt, target: Target) [:0]const u8 {
        return switch (ext) {
            .c => ".c",
            .cpp => ".cpp",
            .cu => ".cu",
            .h => ".h",
            .hpp => ".h",
            .hm => ".h",
            .hmm => ".h",
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
    return mem.endsWith(u8, filename, ".o") or mem.endsWith(u8, filename, ".obj");
}

pub fn hasStaticLibraryExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".a") or mem.endsWith(u8, filename, ".lib");
}

pub fn hasCExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".c");
}

pub fn hasCppExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".C") or
        mem.endsWith(u8, filename, ".cc") or
        mem.endsWith(u8, filename, ".cpp") or
        mem.endsWith(u8, filename, ".cxx") or
        mem.endsWith(u8, filename, ".stub");
}

pub fn hasObjCExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".m");
}

pub fn hasObjCppExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".mm");
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
    } else if (hasCppExt(filename)) {
        return .cpp;
    } else if (hasObjCExt(filename)) {
        return .m;
    } else if (hasObjCppExt(filename)) {
        return .mm;
    } else if (mem.endsWith(u8, filename, ".ll")) {
        return .ll;
    } else if (mem.endsWith(u8, filename, ".bc")) {
        return .bc;
    } else if (mem.endsWith(u8, filename, ".s")) {
        return .assembly;
    } else if (mem.endsWith(u8, filename, ".S")) {
        return .assembly_with_cpp;
    } else if (mem.endsWith(u8, filename, ".h")) {
        return .h;
    } else if (mem.endsWith(u8, filename, ".zig")) {
        return .zig;
    } else if (hasSharedLibraryExt(filename)) {
        return .shared_library;
    } else if (hasStaticLibraryExt(filename)) {
        return .static_library;
    } else if (hasObjectExt(filename)) {
        return .object;
    } else if (mem.endsWith(u8, filename, ".cu")) {
        return .cu;
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

pub fn get_libc_crt_file(comp: *Compilation, arena: Allocator, basename: []const u8) ![]const u8 {
    if (comp.wantBuildGLibCFromSource() or
        comp.wantBuildMuslFromSource() or
        comp.wantBuildMinGWFromSource() or
        comp.wantBuildWasiLibcFromSource())
    {
        return comp.crt_files.get(basename).?.full_object_path;
    }
    const lci = comp.libc_installation orelse return error.LibCInstallationNotAvailable;
    const crt_dir_path = lci.crt_dir orelse return error.LibCInstallationMissingCRTDir;
    const full_path = try std.fs.path.join(arena, &[_][]const u8{ crt_dir_path, basename });
    return full_path;
}

fn wantBuildLibCFromSource(comp: Compilation) bool {
    const is_exe_or_dyn_lib = switch (comp.config.output_mode) {
        .Obj => false,
        .Lib => comp.config.link_mode == .dynamic,
        .Exe => true,
    };
    const ofmt = comp.root_mod.resolved_target.result.ofmt;
    return comp.config.link_libc and is_exe_or_dyn_lib and
        comp.libc_installation == null and ofmt != .c;
}

fn wantBuildGLibCFromSource(comp: Compilation) bool {
    return comp.wantBuildLibCFromSource() and comp.getTarget().isGnuLibC();
}

fn wantBuildMuslFromSource(comp: Compilation) bool {
    return comp.wantBuildLibCFromSource() and comp.getTarget().isMusl() and
        !comp.getTarget().isWasm();
}

fn wantBuildWasiLibcFromSource(comp: Compilation) bool {
    return comp.wantBuildLibCFromSource() and comp.getTarget().isWasm() and
        comp.getTarget().os.tag == .wasi;
}

fn wantBuildMinGWFromSource(comp: Compilation) bool {
    return comp.wantBuildLibCFromSource() and comp.getTarget().isMinGW();
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

fn setAllocFailure(comp: *Compilation) void {
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

fn parseLldStderr(comp: *Compilation, comptime prefix: []const u8, stderr: []const u8) Allocator.Error!void {
    var context_lines = std.ArrayList([]const u8).init(comp.gpa);
    defer context_lines.deinit();

    var current_err: ?*LldError = null;
    var lines = mem.splitSequence(u8, stderr, if (builtin.os.tag == .windows) "\r\n" else "\n");
    while (lines.next()) |line| {
        if (mem.startsWith(u8, line, prefix ++ ":")) {
            if (current_err) |err| {
                err.context_lines = try context_lines.toOwnedSlice();
            }

            var split = mem.splitSequence(u8, line, "error: ");
            _ = split.first();

            const duped_msg = try std.fmt.allocPrint(comp.gpa, "{s}: {s}", .{ prefix, split.rest() });
            errdefer comp.gpa.free(duped_msg);

            current_err = try comp.lld_errors.addOne(comp.gpa);
            current_err.?.* = .{ .msg = duped_msg };
        } else if (current_err != null) {
            const context_prefix = ">>> ";
            var trimmed = mem.trimRight(u8, line, &std.ascii.whitespace);
            if (mem.startsWith(u8, trimmed, context_prefix)) {
                trimmed = trimmed[context_prefix.len..];
            }

            if (trimmed.len > 0) {
                const duped_line = try comp.gpa.dupe(u8, trimmed);
                try context_lines.append(duped_line);
            }
        }
    }

    if (current_err) |err| {
        err.context_lines = try context_lines.toOwnedSlice();
    }
}

pub fn lockAndParseLldStderr(comp: *Compilation, comptime prefix: []const u8, stderr: []const u8) void {
    comp.mutex.lock();
    defer comp.mutex.unlock();

    comp.parseLldStderr(prefix, stderr) catch comp.setAllocFailure();
}

pub fn dump_argv(argv: []const []const u8) void {
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
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
        .spirv32, .spirv64 => return false,
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
        .spirv32, .spirv64 => return false,
        else => {},
    }
    return switch (target_util.zigBackend(target, use_llvm)) {
        .stage2_llvm => true,
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
    prog_node: *std.Progress.Node,
) !void {
    {
        var sub_node = prog_node.start(@tagName(misc_task), 0);
        sub_node.activate();
        defer sub_node.end();

        try sub_comp.update(prog_node);
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
    out: *?CRTFile,
    misc_task_tag: MiscTask,
    prog_node: *std.Progress.Node,
) !void {
    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    const gpa = comp.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    assert(output_mode != .Exe);

    const unwind_tables = comp.link_eh_frame_hdr;
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
        .any_unwind_tables = unwind_tables,
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
            .unwind_tables = unwind_tables,
            .pic = comp.root_mod.pic,
            .optimize_mode = optimize_mode,
            .structured_cfg = comp.root_mod.structured_cfg,
            .code_model = comp.root_mod.code_model,
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

    const sub_compilation = try Compilation.create(gpa, arena, .{
        .global_cache_directory = comp.global_cache_directory,
        .local_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .self_exe_path = comp.self_exe_path,
        .config = config,
        .root_mod = root_mod,
        .cache_mode = .whole,
        .root_name = root_name,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.libc_installation,
        .emit_bin = .{
            .directory = null, // Put it in the cache directory.
            .basename = bin_basename,
        },
        .function_sections = true,
        .data_sections = true,
        .no_builtin = true,
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

    assert(out.* == null);
    out.* = try sub_compilation.toCrtFile();
}

pub fn build_crt_file(
    comp: *Compilation,
    root_name: []const u8,
    output_mode: std.builtin.OutputMode,
    misc_task_tag: MiscTask,
    prog_node: *std.Progress.Node,
    /// These elements have to get mutated to add the owner module after it is
    /// created within this function.
    c_source_files: []CSourceFile,
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
        .lto = switch (output_mode) {
            .Lib => comp.config.lto,
            .Obj, .Exe => false,
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
            .omit_frame_pointer = comp.root_mod.omit_frame_pointer,
            .valgrind = false,
            .unwind_tables = false,
            .pic = comp.root_mod.pic,
            .optimize_mode = comp.compilerRtOptMode(),
            .structured_cfg = comp.root_mod.structured_cfg,
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

    try comp.crt_files.ensureUnusedCapacity(gpa, 1);
    comp.crt_files.putAssumeCapacityNoClobber(basename, try sub_compilation.toCrtFile());
}

pub fn toCrtFile(comp: *Compilation) Allocator.Error!CRTFile {
    return .{
        .full_object_path = try comp.local_cache_directory.join(comp.gpa, &.{
            comp.cache_use.whole.bin_sub_path.?,
        }),
        .lock = comp.cache_use.whole.moveLock(),
    };
}

pub fn addLinkLib(comp: *Compilation, lib_name: []const u8) !void {
    // Avoid deadlocking on building import libs such as kernel32.lib
    // This can happen when the user uses `build-exe foo.obj -lkernel32` and
    // then when we create a sub-Compilation for zig libc, it also tries to
    // build kernel32.lib.
    if (comp.skip_linker_dependencies) return;

    // This happens when an `extern "foo"` function is referenced.
    // If we haven't seen this library yet and we're targeting Windows, we need
    // to queue up a work item to produce the DLL import library for this.
    const gop = try comp.system_libs.getOrPut(comp.gpa, lib_name);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{
            .needed = true,
            .weak = false,
            .path = null,
        };
        const target = comp.root_mod.resolved_target.result;
        if (target.os.tag == .windows and target.ofmt != .c) {
            try comp.work_queue.writeItem(.{
                .windows_import_lib = comp.system_libs.count() - 1,
            });
        }
    }
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
