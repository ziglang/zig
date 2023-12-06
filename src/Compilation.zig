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

const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const target_util = @import("target.zig");
const Package = @import("Package.zig");
const link = @import("link.zig");
const tracy = @import("tracy.zig");
const trace = tracy.trace;
const build_options = @import("build_options");
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;
const glibc = @import("glibc.zig");
const musl = @import("musl.zig");
const mingw = @import("mingw.zig");
const libunwind = @import("libunwind.zig");
const libcxx = @import("libcxx.zig");
const wasi_libc = @import("wasi_libc.zig");
const fatal = @import("main.zig").fatal;
const clangMain = @import("main.zig").clangMain;
const Module = @import("Module.zig");
const InternPool = @import("InternPool.zig");
const BuildId = std.Build.CompileStep.BuildId;
const Cache = std.Build.Cache;
const c_codegen = @import("codegen/c.zig");
const libtsan = @import("libtsan.zig");
const Zir = @import("Zir.zig");
const Autodoc = @import("Autodoc.zig");
const Color = @import("main.zig").Color;
const resinator = @import("resinator.zig");

/// General-purpose allocator. Used for both temporary and long-term storage.
gpa: Allocator,
/// Arena-allocated memory, mostly used during initialization. However, it can be used
/// for other things requiring the same lifetime as the `Compilation`.
arena: std.heap.ArenaAllocator,
bin_file: *link.File,
c_object_table: std.AutoArrayHashMapUnmanaged(*CObject, void) = .{},
win32_resource_table: if (build_options.only_core_functionality) void else std.AutoArrayHashMapUnmanaged(*Win32Resource, void) =
    if (build_options.only_core_functionality) {} else .{},
/// This is a pointer to a local variable inside `update()`.
whole_cache_manifest: ?*Cache.Manifest = null,
whole_cache_manifest_mutex: std.Thread.Mutex = .{},

link_error_flags: link.File.ErrorFlags = .{},
lld_errors: std.ArrayListUnmanaged(LldError) = .{},

work_queue: std.fifo.LinearFifo(Job, .Dynamic),
anon_work_queue: std.fifo.LinearFifo(Job, .Dynamic),

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

keep_source_files_loaded: bool,
c_frontend: CFrontend,
sanitize_c: bool,
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
disable_c_depfile: bool,
time_report: bool,
stack_report: bool,
unwind_tables: bool,
test_evented_io: bool,
debug_compiler_runtime_libs: bool,
debug_compile_errors: bool,
job_queued_compiler_rt_lib: bool = false,
job_queued_compiler_rt_obj: bool = false,
alloc_failure_occurred: bool = false,
formatted_panics: bool = false,
last_update_was_cache_hit: bool = false,

c_source_files: []const CSourceFile,
clang_argv: []const []const u8,
rc_source_files: []const RcSourceFile,
cache_parent: *Cache,
/// Path to own executable for invoking `zig clang`.
self_exe_path: ?[]const u8,
/// null means -fno-emit-bin.
/// This is mutable memory allocated into the Compilation-lifetime arena (`arena`)
/// of exactly the correct size for "o/[digest]/[basename]".
/// The basename is of the outputted binary file in case we don't know the directory yet.
whole_bin_sub_path: ?[]u8,
/// Same as `whole_bin_sub_path` but for implibs.
whole_implib_sub_path: ?[]u8,
whole_docs_sub_path: ?[]u8,
zig_lib_directory: Directory,
local_cache_directory: Directory,
global_cache_directory: Directory,
libc_include_dir_list: []const []const u8,
libc_framework_dir_list: []const []const u8,
rc_include_dir_list: []const []const u8,
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

/// For example `Scrt1.o` and `libc_nonshared.a`. These are populated after building libc from source,
/// The set of needed CRT (C runtime) files differs depending on the target and compilation settings.
/// The key is the basename, and the value is the absolute path to the completed build artifact.
crt_files: std.StringHashMapUnmanaged(CRTFile) = .{},

/// Keeping track of this possibly open resource so we can close it later.
owned_link_dir: ?std.fs.Dir,

/// This is for stage1 and should be deleted upon completion of self-hosting.
/// Don't use this for anything other than stage1 compatibility.
color: Color = .auto,

/// How many lines of reference trace should be included per compile error.
/// Null means only show snippet on first error.
reference_trace: ?u32 = null,

libcxx_abi_version: libcxx.AbiVersion = libcxx.AbiVersion.default,

/// This mutex guards all `Compilation` mutable state.
mutex: std.Thread.Mutex = .{},

test_filter: ?[]const u8,
test_name_prefix: ?[]const u8,

emit_asm: ?EmitLoc,
emit_llvm_ir: ?EmitLoc,
emit_llvm_bc: ?EmitLoc,

work_queue_wait_group: WaitGroup = .{},
astgen_wait_group: WaitGroup = .{},

pub const default_stack_protector_buffer_size = 4;
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

// supported languages for "zig clang -x <lang>".
// Loosely based on llvm-project/clang/include/clang/Driver/Types.def
pub const LangToExt = std.ComptimeStringMap(FileExt, .{
    .{ "c", .c },
    .{ "c-header", .h },
    .{ "c++", .cpp },
    .{ "c++-header", .h },
    .{ "objective-c", .m },
    .{ "objective-c-header", .h },
    .{ "objective-c++", .mm },
    .{ "objective-c++-header", .h },
    .{ "assembler", .assembly },
    .{ "assembler-with-cpp", .assembly_with_cpp },
    .{ "cuda", .cu },
});

/// For passing to a C compiler.
pub const CSourceFile = struct {
    src_path: []const u8,
    extra_flags: []const []const u8 = &.{},
    /// Same as extra_flags except they are not added to the Cache hash.
    cache_exempt_flags: []const []const u8 = &.{},
    // this field is non-null iff language was explicitly set with "-x lang".
    ext: ?FileExt = null,
};

/// For passing to resinator.
pub const RcSourceFile = struct {
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

    /// The value is the index into `link.File.Options.system_libs`.
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
            file_names: std.AutoHashMapUnmanaged(u32, []const u8) = .{},
            category_names: std.AutoHashMapUnmanaged(u32, []const u8) = .{},
            diags: []Diag = &.{},

            pub fn destroy(bundle: *Bundle, gpa: Allocator) void {
                var file_name_it = bundle.file_names.valueIterator();
                while (file_name_it.next()) |file_name| gpa.free(file_name.*);
                bundle.file_names.deinit(gpa);

                var category_name_it = bundle.category_names.valueIterator();
                while (category_name_it.next()) |category_name| gpa.free(category_name.*);
                bundle.category_names.deinit(gpa);

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

                var file_names: std.AutoHashMapUnmanaged(u32, []const u8) = .{};
                errdefer {
                    var file_name_it = file_names.valueIterator();
                    while (file_name_it.next()) |file_name| gpa.free(file_name.*);
                    file_names.deinit(gpa);
                }

                var category_names: std.AutoHashMapUnmanaged(u32, []const u8) = .{};
                errdefer {
                    var category_name_it = category_names.valueIterator();
                    while (category_name_it.next()) |category_name| gpa.free(category_name.*);
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
    @"mingw-w64 msvcrt-os.lib",
    @"mingw-w64 mingwex.lib",
    @"mingw-w64 uuid.lib",
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
    pub fn addEmitLoc(hh: *Cache.HashHelper, emit_loc: EmitLoc) void {
        hh.addBytes(emit_loc.basename);
    }

    pub fn addOptionalEmitLoc(hh: *Cache.HashHelper, optional_emit_loc: ?EmitLoc) void {
        hh.add(optional_emit_loc != null);
        addEmitLoc(hh, optional_emit_loc orelse return);
    }

    pub fn hashCSource(self: *Cache.Manifest, c_source: Compilation.CSourceFile) !void {
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

pub const CFrontend = enum { clang, aro };

pub const ClangPreprocessorMode = enum {
    no,
    /// This means we are doing `zig cc -E -o <path>`.
    yes,
    /// This means we are doing `zig cc -E`.
    stdout,
};

pub const Framework = link.Framework;
pub const SystemLib = link.SystemLib;
pub const CacheMode = link.CacheMode;

pub const LinkObject = struct {
    path: []const u8,
    must_link: bool = false,
    // When the library is passed via a positional argument, it will be
    // added as a full path. If it's `-l<lib>`, then just the basename.
    //
    // Consistent with `withLOption` variable name in lld ELF driver.
    loption: bool = false,
};

pub const InitOptions = struct {
    zig_lib_directory: Directory,
    local_cache_directory: Directory,
    global_cache_directory: Directory,
    target: Target,
    root_name: []const u8,
    main_mod: ?*Package.Module,
    output_mode: std.builtin.OutputMode,
    thread_pool: *ThreadPool,
    dynamic_linker: ?[]const u8 = null,
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
    link_mode: ?std.builtin.LinkMode = null,
    dll_export_fns: ?bool = false,
    /// Normally when using LLD to link, Zig uses a file named "lld.id" in the
    /// same directory as the output binary which contains the hash of the link
    /// operation, allowing Zig to skip linking when the hash would be unchanged.
    /// In the case that the output binary is being emitted into a directory which
    /// is externally modified - essentially anything other than zig-cache - then
    /// this flag would be set to disable this machinery to avoid false positives.
    disable_lld_caching: bool = false,
    cache_mode: CacheMode = .incremental,
    optimize_mode: std.builtin.OptimizeMode = .Debug,
    keep_source_files_loaded: bool = false,
    clang_argv: []const []const u8 = &[0][]const u8{},
    lib_dirs: []const []const u8 = &[0][]const u8{},
    rpath_list: []const []const u8 = &[0][]const u8{},
    symbol_wrap_set: std.StringArrayHashMapUnmanaged(void) = .{},
    c_source_files: []const CSourceFile = &[0]CSourceFile{},
    rc_source_files: []const RcSourceFile = &[0]RcSourceFile{},
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
    wasi_emulated_libs: []const wasi_libc.CRTFile = &[0]wasi_libc.CRTFile{},
    link_libc: bool = false,
    link_libcpp: bool = false,
    link_libunwind: bool = false,
    want_pic: ?bool = null,
    /// This means that if the output mode is an executable it will be a
    /// Position Independent Executable. If the output mode is not an
    /// executable this field is ignored.
    want_pie: ?bool = null,
    want_sanitize_c: ?bool = null,
    want_stack_check: ?bool = null,
    /// null means default.
    /// 0 means no stack protector.
    /// other number means stack protection with that buffer size.
    want_stack_protector: ?u32 = null,
    want_red_zone: ?bool = null,
    omit_frame_pointer: ?bool = null,
    want_valgrind: ?bool = null,
    want_tsan: ?bool = null,
    want_compiler_rt: ?bool = null,
    want_lto: ?bool = null,
    want_unwind_tables: ?bool = null,
    use_llvm: ?bool = null,
    use_lib_llvm: ?bool = null,
    use_lld: ?bool = null,
    use_clang: ?bool = null,
    single_threaded: ?bool = null,
    strip: ?bool = null,
    formatted_panics: ?bool = null,
    rdynamic: bool = false,
    function_sections: bool = false,
    data_sections: bool = false,
    no_builtin: bool = false,
    is_native_os: bool,
    is_native_abi: bool,
    time_report: bool = false,
    stack_report: bool = false,
    link_eh_frame_hdr: bool = false,
    link_emit_relocs: bool = false,
    linker_script: ?[]const u8 = null,
    version_script: ?[]const u8 = null,
    soname: ?[]const u8 = null,
    linker_gc_sections: ?bool = null,
    linker_allow_shlib_undefined: ?bool = null,
    linker_bind_global_refs_locally: ?bool = null,
    linker_import_memory: ?bool = null,
    linker_export_memory: ?bool = null,
    linker_import_symbols: bool = false,
    linker_import_table: bool = false,
    linker_export_table: bool = false,
    linker_initial_memory: ?u64 = null,
    linker_max_memory: ?u64 = null,
    linker_shared_memory: bool = false,
    linker_global_base: ?u64 = null,
    linker_export_symbol_names: []const []const u8 = &.{},
    linker_print_gc_sections: bool = false,
    linker_print_icf_sections: bool = false,
    linker_print_map: bool = false,
    linker_opt_bisect_limit: i32 = -1,
    each_lib_rpath: ?bool = null,
    build_id: ?BuildId = null,
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
    linker_optimization: ?u8 = null,
    linker_compress_debug_sections: ?link.CompressDebugSections = null,
    linker_module_definition_file: ?[]const u8 = null,
    linker_sort_section: ?link.SortSection = null,
    major_subsystem_version: ?u32 = null,
    minor_subsystem_version: ?u32 = null,
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
    is_test: bool = false,
    test_evented_io: bool = false,
    debug_compiler_runtime_libs: bool = false,
    debug_compile_errors: bool = false,
    /// Normally when you create a `Compilation`, Zig will automatically build
    /// and link in required dependencies, such as compiler-rt and libc. When
    /// building such dependencies themselves, this flag must be set to avoid
    /// infinite recursion.
    skip_linker_dependencies: bool = false,
    parent_compilation_link_libc: bool = false,
    hash_style: link.HashStyle = .both,
    entry: ?[]const u8 = null,
    force_undefined_symbols: std.StringArrayHashMapUnmanaged(void) = .{},
    stack_size_override: ?u64 = null,
    image_base_override: ?u64 = null,
    self_exe_path: ?[]const u8 = null,
    version: ?std.SemanticVersion = null,
    compatibility_version: ?std.SemanticVersion = null,
    libc_installation: ?*const LibCInstallation = null,
    machine_code_model: std.builtin.CodeModel = .default,
    clang_preprocessor_mode: ClangPreprocessorMode = .no,
    /// This is for stage1 and should be deleted upon completion of self-hosting.
    color: Color = .auto,
    reference_trace: ?u32 = null,
    error_tracing: ?bool = null,
    test_filter: ?[]const u8 = null,
    test_name_prefix: ?[]const u8 = null,
    test_runner_path: ?[]const u8 = null,
    subsystem: ?std.Target.SubSystem = null,
    dwarf_format: ?std.dwarf.Format = null,
    /// WASI-only. Type of WASI execution model ("command" or "reactor").
    wasi_exec_model: ?std.builtin.WasiExecModel = null,
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
    libcxx_abi_version: libcxx.AbiVersion = libcxx.AbiVersion.default,
    /// (Windows) PDB source path prefix to instruct the linker how to resolve relative
    /// paths when consolidating CodeView streams into a single PDB file.
    pdb_source_path: ?[]const u8 = null,
    /// (Windows) PDB output path
    pdb_out_path: ?[]const u8 = null,
    error_limit: ?Module.ErrorInt = null,
    /// (SPIR-V) whether to generate a structured control flow graph or not
    want_structured_cfg: ?bool = null,
};

fn addModuleTableToCacheHash(
    hash: *Cache.HashHelper,
    arena: *std.heap.ArenaAllocator,
    mod_table: Package.Module.Deps,
    seen_table: *std.AutoHashMap(*Package.Module, void),
    hash_type: union(enum) { path_bytes, files: *Cache.Manifest },
) (error{OutOfMemory} || std.os.GetCwdError)!void {
    const allocator = arena.allocator();

    const modules = try allocator.alloc(Package.Module.Deps.KV, mod_table.count());
    {
        // Copy over the hashmap entries to our slice
        var table_it = mod_table.iterator();
        var idx: usize = 0;
        while (table_it.next()) |entry| : (idx += 1) {
            modules[idx] = .{
                .key = entry.key_ptr.*,
                .value = entry.value_ptr.*,
            };
        }
    }
    // Sort the slice by package name
    mem.sortUnstable(Package.Module.Deps.KV, modules, {}, struct {
        fn lessThan(_: void, lhs: Package.Module.Deps.KV, rhs: Package.Module.Deps.KV) bool {
            return std.mem.lessThan(u8, lhs.key, rhs.key);
        }
    }.lessThan);

    for (modules) |mod| {
        if ((try seen_table.getOrPut(mod.value)).found_existing) continue;

        // Finally insert the package name and path to the cache hash.
        hash.addBytes(mod.key);
        switch (hash_type) {
            .path_bytes => {
                hash.addBytes(mod.value.root_src_path);
                hash.addOptionalBytes(mod.value.root.root_dir.path);
                hash.addBytes(mod.value.root.sub_path);
            },
            .files => |man| {
                const pkg_zig_file = try mod.value.root.joinString(
                    allocator,
                    mod.value.root_src_path,
                );
                _ = try man.addFile(pkg_zig_file, null);
            },
        }
        // Recurse to handle the module's dependencies
        try addModuleTableToCacheHash(hash, arena, mod.value.deps, seen_table, hash_type);
    }
}

pub fn create(gpa: Allocator, options: InitOptions) !*Compilation {
    const is_dyn_lib = switch (options.output_mode) {
        .Obj, .Exe => false,
        .Lib => (options.link_mode orelse .Static) == .Dynamic,
    };
    const is_exe_or_dyn_lib = switch (options.output_mode) {
        .Obj => false,
        .Lib => is_dyn_lib,
        .Exe => true,
    };

    // WASI-only. Resolve the optional exec-model option, defaults to command.
    const wasi_exec_model = if (options.target.os.tag != .wasi) undefined else options.wasi_exec_model orelse .command;

    if (options.linker_export_table and options.linker_import_table) {
        return error.ExportTableAndImportTableConflict;
    }

    const comp: *Compilation = comp: {
        // For allocations that have the same lifetime as Compilation. This arena is used only during this
        // initialization and then is freed in deinit().
        var arena_allocator = std.heap.ArenaAllocator.init(gpa);
        errdefer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        // We put the `Compilation` itself in the arena. Freeing the arena will free the module.
        // It's initialized later after we prepare the initialization options.
        const comp = try arena.create(Compilation);
        const root_name = try arena.dupeZ(u8, options.root_name);

        // Make a decision on whether to use LLVM or our own backend.
        const use_lib_llvm = options.use_lib_llvm orelse build_options.have_llvm;
        const use_llvm = blk: {
            if (options.use_llvm) |explicit|
                break :blk explicit;

            // If emitting to LLVM bitcode object format, must use LLVM backend.
            if (options.emit_llvm_ir != null or options.emit_llvm_bc != null)
                break :blk true;

            // If we have no zig code to compile, no need for LLVM.
            if (options.main_mod == null)
                break :blk false;

            // If we cannot use LLVM libraries, then our own backends will be a
            // better default since the LLVM backend can only produce bitcode
            // and not an object file or executable.
            if (!use_lib_llvm)
                break :blk false;

            // If LLVM does not support the target, then we can't use it.
            if (!target_util.hasLlvmSupport(options.target, options.target.ofmt))
                break :blk false;

            // Prefer LLVM for release builds.
            if (options.optimize_mode != .Debug)
                break :blk true;

            // At this point we would prefer to use our own self-hosted backend,
            // because the compilation speed is better than LLVM. But only do it if
            // we are confident in the robustness of the backend.
            break :blk !target_util.selfHostedBackendIsAsRobustAsLlvm(options.target);
        };
        if (!use_llvm) {
            if (options.use_llvm == true) {
                return error.ZigCompilerNotBuiltWithLLVMExtensions;
            }
            if (options.emit_llvm_ir != null or options.emit_llvm_bc != null) {
                return error.EmittingLlvmModuleRequiresUsingLlvmBackend;
            }
        }

        // TODO: once we support incremental compilation for the LLVM backend via
        // saving the LLVM module into a bitcode file and restoring it, along with
        // compiler state, the second clause here can be removed so that incremental
        // cache mode is used for LLVM backend too. We need some fuzz testing before
        // that can be enabled.
        const cache_mode = if ((use_llvm or options.main_mod == null) and !options.disable_lld_caching)
            CacheMode.whole
        else
            options.cache_mode;

        const tsan = options.want_tsan orelse false;
        // TSAN is implemented in C++ so it requires linking libc++.
        const link_libcpp = options.link_libcpp or tsan;
        const link_libc = link_libcpp or options.link_libc or options.link_libunwind or
            target_util.osRequiresLibC(options.target);

        const link_libunwind = options.link_libunwind or
            (link_libcpp and target_util.libcNeedsLibUnwind(options.target));
        const unwind_tables = options.want_unwind_tables orelse
            (link_libunwind or target_util.needUnwindTables(options.target));
        const link_eh_frame_hdr = options.link_eh_frame_hdr or unwind_tables;
        const build_id = options.build_id orelse .none;

        // Make a decision on whether to use LLD or our own linker.
        const use_lld = options.use_lld orelse blk: {
            if (options.target.isDarwin()) {
                break :blk false;
            }

            if (!build_options.have_llvm)
                break :blk false;

            if (options.target.ofmt == .c)
                break :blk false;

            if (options.want_lto) |lto| {
                if (lto) {
                    break :blk true;
                }
            }

            // Our linker can't handle objects or most advanced options yet.
            if (options.link_objects.len != 0 or
                options.c_source_files.len != 0 or
                options.frameworks.len != 0 or
                options.system_lib_names.len != 0 or
                options.link_libc or options.link_libcpp or
                link_eh_frame_hdr or
                options.link_emit_relocs or
                options.output_mode == .Lib or
                options.linker_script != null or options.version_script != null or
                options.emit_implib != null or
                build_id != .none or
                options.symbol_wrap_set.count() > 0)
            {
                break :blk true;
            }

            if (use_llvm) {
                // If stage1 generates an object file, self-hosted linker is not
                // yet sophisticated enough to handle that.
                break :blk options.main_mod != null;
            }

            break :blk false;
        };

        const lto = blk: {
            if (options.want_lto) |want_lto| {
                if (want_lto and !use_lld and !options.target.isDarwin())
                    return error.LtoUnavailableWithoutLld;
                break :blk want_lto;
            } else if (!use_lld) {
                // zig ld LTO support is tracked by
                // https://github.com/ziglang/zig/issues/8680
                break :blk false;
            } else if (options.c_source_files.len == 0) {
                break :blk false;
            } else if (options.target.cpu.arch.isRISCV()) {
                // Clang and LLVM currently don't support RISC-V target-abi for LTO.
                // Compiling with LTO may fail or produce undesired results.
                // See https://reviews.llvm.org/D71387
                // See https://reviews.llvm.org/D102582
                break :blk false;
            } else switch (options.output_mode) {
                .Lib, .Obj => break :blk false,
                .Exe => switch (options.optimize_mode) {
                    .Debug => break :blk false,
                    .ReleaseSafe, .ReleaseFast, .ReleaseSmall => break :blk true,
                },
            }
        };

        const must_dynamic_link = dl: {
            if (target_util.cannotDynamicLink(options.target))
                break :dl false;
            if (is_exe_or_dyn_lib and link_libc and
                (options.target.isGnuLibC() or target_util.osRequiresLibC(options.target)))
            {
                break :dl true;
            }
            const any_dyn_libs: bool = x: {
                if (options.system_lib_names.len != 0)
                    break :x true;
                for (options.link_objects) |obj| {
                    switch (classifyFileExt(obj.path)) {
                        .shared_library => break :x true,
                        else => continue,
                    }
                }
                break :x false;
            };
            if (any_dyn_libs) {
                // When creating a executable that links to system libraries,
                // we require dynamic linking, but we must not link static libraries
                // or object files dynamically!
                break :dl (options.output_mode == .Exe);
            }

            break :dl false;
        };
        const default_link_mode: std.builtin.LinkMode = blk: {
            if (must_dynamic_link) {
                break :blk .Dynamic;
            } else if (is_exe_or_dyn_lib and link_libc and
                options.is_native_abi and options.target.abi.isMusl())
            {
                // If targeting the system's native ABI and the system's
                // libc is musl, link dynamically by default.
                break :blk .Dynamic;
            } else {
                break :blk .Static;
            }
        };
        const link_mode: std.builtin.LinkMode = if (options.link_mode) |lm| blk: {
            if (lm == .Static and must_dynamic_link) {
                return error.UnableToStaticLink;
            }
            break :blk lm;
        } else default_link_mode;

        const dll_export_fns = options.dll_export_fns orelse (is_dyn_lib or options.rdynamic);

        const libc_dirs = try detectLibCIncludeDirs(
            arena,
            options.zig_lib_directory.path.?,
            options.target,
            options.is_native_abi,
            link_libc,
            options.libc_installation,
        );

        const rc_dirs = try detectWin32ResourceIncludeDirs(
            arena,
            options,
        );

        const sysroot = options.sysroot orelse libc_dirs.sysroot;

        const pie: bool = pie: {
            if (is_dyn_lib) {
                if (options.want_pie == true) return error.OutputModeForbidsPie;
                break :pie false;
            }
            if (target_util.requiresPIE(options.target)) {
                if (options.want_pie == false) return error.TargetRequiresPie;
                break :pie true;
            }
            if (tsan) {
                if (options.want_pie == false) return error.TsanRequiresPie;
                break :pie true;
            }
            if (options.want_pie) |want_pie| {
                break :pie want_pie;
            }
            break :pie false;
        };

        const must_pic: bool = b: {
            if (target_util.requiresPIC(options.target, link_libc))
                break :b true;
            break :b link_mode == .Dynamic;
        };
        const pic = if (options.want_pic) |explicit| pic: {
            if (!explicit) {
                if (must_pic) {
                    return error.TargetRequiresPIC;
                }
                if (pie) {
                    return error.PIERequiresPIC;
                }
            }
            break :pic explicit;
        } else pie or must_pic;

        // Make a decision on whether to use Clang or Aro for translate-c and compiling C files.
        const c_frontend: CFrontend = blk: {
            if (options.use_clang) |want_clang| {
                break :blk if (want_clang) .clang else .aro;
            }
            break :blk if (build_options.have_llvm) .clang else .aro;
        };
        if (!build_options.have_llvm and c_frontend == .clang) {
            return error.ZigCompilerNotBuiltWithLLVMExtensions;
        }

        const is_safe_mode = switch (options.optimize_mode) {
            .Debug, .ReleaseSafe => true,
            .ReleaseFast, .ReleaseSmall => false,
        };

        const sanitize_c = options.want_sanitize_c orelse is_safe_mode;

        const stack_check: bool = options.want_stack_check orelse b: {
            if (!target_util.supportsStackProbing(options.target)) break :b false;
            break :b is_safe_mode;
        };
        if (stack_check and !target_util.supportsStackProbing(options.target))
            return error.StackCheckUnsupportedByTarget;

        const stack_protector: u32 = sp: {
            const zig_backend = zigBackend(options.target, use_llvm);
            if (!target_util.supportsStackProtector(options.target, zig_backend)) {
                if (options.want_stack_protector) |x| {
                    if (x > 0) return error.StackProtectorUnsupportedByTarget;
                }
                break :sp 0;
            }

            // This logic is checking for linking libc because otherwise our start code
            // which is trying to set up TLS (i.e. the fs/gs registers) but the stack
            // protection code depends on fs/gs registers being already set up.
            // If we were able to annotate start code, or perhaps the entire std lib,
            // as being exempt from stack protection checks, we could change this logic
            // to supporting stack protection even when not linking libc.
            // TODO file issue about this
            if (!link_libc) {
                if (options.want_stack_protector) |x| {
                    if (x > 0) return error.StackProtectorUnavailableWithoutLibC;
                }
                break :sp 0;
            }

            if (options.want_stack_protector) |x| break :sp x;
            if (is_safe_mode) break :sp default_stack_protector_buffer_size;
            break :sp 0;
        };

        const include_compiler_rt = options.want_compiler_rt orelse
            (!options.skip_linker_dependencies and is_exe_or_dyn_lib);

        const single_threaded = st: {
            if (target_util.isSingleThreaded(options.target)) {
                if (options.single_threaded == false)
                    return error.TargetRequiresSingleThreaded;
                break :st true;
            }
            if (options.main_mod != null) {
                const zig_backend = zigBackend(options.target, use_llvm);
                if (!target_util.supportsThreads(options.target, zig_backend)) {
                    if (options.single_threaded == false)
                        return error.BackendRequiresSingleThreaded;
                    break :st true;
                }
            }
            break :st options.single_threaded orelse false;
        };

        const llvm_cpu_features: ?[*:0]const u8 = if (use_llvm) blk: {
            var buf = std.ArrayList(u8).init(arena);
            for (options.target.cpu.arch.allFeaturesList(), 0..) |feature, index_usize| {
                const index = @as(Target.Cpu.Feature.Set.Index, @intCast(index_usize));
                const is_enabled = options.target.cpu.features.isEnabled(index);

                if (feature.llvm_name) |llvm_name| {
                    const plus_or_minus = "-+"[@intFromBool(is_enabled)];
                    try buf.ensureUnusedCapacity(2 + llvm_name.len);
                    buf.appendAssumeCapacity(plus_or_minus);
                    buf.appendSliceAssumeCapacity(llvm_name);
                    buf.appendSliceAssumeCapacity(",");
                }
            }
            if (buf.items.len == 0) break :blk "";
            assert(mem.endsWith(u8, buf.items, ","));
            buf.items[buf.items.len - 1] = 0;
            buf.shrinkAndFree(buf.items.len);
            break :blk buf.items[0 .. buf.items.len - 1 :0].ptr;
        } else null;

        if (options.verbose_llvm_cpu_features) {
            if (llvm_cpu_features) |cf| print: {
                std.debug.getStderrMutex().lock();
                defer std.debug.getStderrMutex().unlock();
                const stderr = std.io.getStdErr().writer();
                nosuspend stderr.print("compilation: {s}\n", .{options.root_name}) catch break :print;
                nosuspend stderr.print("  target: {s}\n", .{try options.target.zigTriple(arena)}) catch break :print;
                nosuspend stderr.print("  cpu: {s}\n", .{options.target.cpu.model.name}) catch break :print;
                nosuspend stderr.print("  features: {s}\n", .{cf}) catch {};
            }
        }

        const strip = options.strip orelse !target_util.hasDebugInfo(options.target);
        const valgrind: bool = b: {
            if (!target_util.hasValgrindSupport(options.target)) break :b false;
            if (options.want_valgrind) |explicit| break :b explicit;
            if (strip) break :b false;
            break :b options.optimize_mode == .Debug;
        };
        if (!valgrind and options.want_valgrind == true)
            return error.ValgrindUnsupportedOnTarget;

        const red_zone = options.want_red_zone orelse target_util.hasRedZone(options.target);
        const omit_frame_pointer = options.omit_frame_pointer orelse (options.optimize_mode != .Debug);
        const linker_optimization: u8 = options.linker_optimization orelse switch (options.optimize_mode) {
            .Debug => @as(u8, 0),
            else => @as(u8, 3),
        };
        const formatted_panics = options.formatted_panics orelse (options.optimize_mode == .Debug);

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
        cache.hash.add(options.optimize_mode);
        cache.hash.add(options.target.cpu.arch);
        cache.hash.addBytes(options.target.cpu.model.name);
        cache.hash.add(options.target.cpu.features.ints);
        cache.hash.add(options.target.os.tag);
        cache.hash.add(options.target.os.getVersionRange());
        cache.hash.add(options.is_native_os);
        cache.hash.add(options.target.abi);
        cache.hash.add(options.target.ofmt);
        cache.hash.add(pic);
        cache.hash.add(pie);
        cache.hash.add(lto);
        cache.hash.add(unwind_tables);
        cache.hash.add(tsan);
        cache.hash.add(stack_check);
        cache.hash.add(stack_protector);
        cache.hash.add(red_zone);
        cache.hash.add(omit_frame_pointer);
        cache.hash.add(link_mode);
        cache.hash.add(options.function_sections);
        cache.hash.add(options.data_sections);
        cache.hash.add(options.no_builtin);
        cache.hash.add(strip);
        cache.hash.add(link_libc);
        cache.hash.add(link_libcpp);
        cache.hash.add(link_libunwind);
        cache.hash.add(options.output_mode);
        cache.hash.add(options.machine_code_model);
        cache.hash.addOptional(options.dwarf_format);
        cache_helpers.addOptionalEmitLoc(&cache.hash, options.emit_bin);
        cache_helpers.addOptionalEmitLoc(&cache.hash, options.emit_implib);
        cache_helpers.addOptionalEmitLoc(&cache.hash, options.emit_docs);
        cache.hash.addBytes(options.root_name);
        if (options.target.os.tag == .wasi) cache.hash.add(wasi_exec_model);
        // TODO audit this and make sure everything is in it

        const module: ?*Module = if (options.main_mod) |main_mod| blk: {
            // Options that are specific to zig source files, that cannot be
            // modified between incremental updates.
            var hash = cache.hash;

            switch (cache_mode) {
                .incremental => {
                    // Here we put the root source file path name, but *not* with addFile.
                    // We want the hash to be the same regardless of the contents of the
                    // source file, because incremental compilation will handle it, but we
                    // do want to namespace different source file names because they are
                    // likely different compilations and therefore this would be likely to
                    // cause cache hits.
                    hash.addBytes(main_mod.root_src_path);
                    hash.addOptionalBytes(main_mod.root.root_dir.path);
                    hash.addBytes(main_mod.root.sub_path);
                    {
                        var seen_table = std.AutoHashMap(*Package.Module, void).init(arena);
                        try addModuleTableToCacheHash(&hash, &arena_allocator, main_mod.deps, &seen_table, .path_bytes);
                    }
                },
                .whole => {
                    // In this case, we postpone adding the input source file until
                    // we create the cache manifest, in update(), because we want to
                    // track it and packages as files.
                },
            }

            // Synchronize with other matching comments: ZigOnlyHashStuff
            hash.add(valgrind);
            hash.add(single_threaded);
            hash.add(use_llvm);
            hash.add(use_lib_llvm);
            hash.add(dll_export_fns);
            hash.add(options.is_test);
            hash.add(options.test_evented_io);
            hash.addOptionalBytes(options.test_filter);
            hash.addOptionalBytes(options.test_name_prefix);
            hash.add(options.skip_linker_dependencies);
            hash.add(options.parent_compilation_link_libc);
            hash.add(formatted_panics);
            hash.add(options.emit_h != null);
            hash.add(error_limit);
            hash.addOptional(options.want_structured_cfg);

            // In the case of incremental cache mode, this `zig_cache_artifact_directory`
            // is computed based on a hash of non-linker inputs, and it is where all
            // build artifacts are stored (even while in-progress).
            //
            // For whole cache mode, it is still used for builtin.zig so that the file
            // path to builtin.zig can remain consistent during a debugging session at
            // runtime. However, we don't know where to put outputs from the linker
            // until the final cache hash, which is available after the
            // compilation is complete.
            //
            // Therefore, in whole cache mode, we additionally create a temporary cache
            // directory for these two kinds of build artifacts, and then rename it
            // into place after the final hash is known. However, we don't want
            // to create the temporary directory here, because in the case of a cache hit,
            // this would have been wasted syscalls to make the directory and then not
            // use it (or delete it).
            //
            // In summary, for whole cache mode, we simulate `-fno-emit-bin` in this
            // function, and `zig_cache_artifact_directory` is *wrong* except for builtin.zig,
            // and then at the beginning of `update()` when we find out whether we need
            // a temporary directory, we patch up all the places that the incorrect
            // `zig_cache_artifact_directory` was passed to various components of the compiler.

            const digest = hash.final();
            const artifact_sub_dir = try std.fs.path.join(arena, &[_][]const u8{ "o", &digest });
            var artifact_dir = try options.local_cache_directory.handle.makeOpenPath(artifact_sub_dir, .{});
            errdefer artifact_dir.close();
            const zig_cache_artifact_directory: Directory = .{
                .handle = artifact_dir,
                .path = try options.local_cache_directory.join(arena, &[_][]const u8{artifact_sub_dir}),
            };

            const builtin_mod = try Package.Module.create(arena, .{
                .root = .{ .root_dir = zig_cache_artifact_directory },
                .root_src_path = "builtin.zig",
                .fully_qualified_name = "builtin",
            });

            // When you're testing std, the main module is std. In that case,
            // we'll just set the std module to the main one, since avoiding
            // the errors caused by duplicating it is more effort than it's
            // worth.
            const main_mod_is_std = m: {
                const std_path = try std.fs.path.resolve(arena, &[_][]const u8{
                    options.zig_lib_directory.path orelse ".",
                    "std",
                    "std.zig",
                });
                const main_path = try std.fs.path.resolve(arena, &[_][]const u8{
                    main_mod.root.root_dir.path orelse ".",
                    main_mod.root.sub_path,
                    main_mod.root_src_path,
                });
                break :m mem.eql(u8, main_path, std_path);
            };

            const std_mod = if (main_mod_is_std)
                main_mod
            else
                try Package.Module.create(arena, .{
                    .root = .{
                        .root_dir = options.zig_lib_directory,
                        .sub_path = "std",
                    },
                    .root_src_path = "std.zig",
                    .fully_qualified_name = "std",
                });

            const root_mod = if (options.is_test) root_mod: {
                const test_mod = if (options.test_runner_path) |test_runner| test_mod: {
                    const pkg = try Package.Module.create(arena, .{
                        .root = .{
                            .root_dir = Directory.cwd(),
                            .sub_path = std.fs.path.dirname(test_runner) orelse "",
                        },
                        .root_src_path = std.fs.path.basename(test_runner),
                        .fully_qualified_name = "root",
                    });

                    pkg.deps = try main_mod.deps.clone(arena);
                    break :test_mod pkg;
                } else try Package.Module.create(arena, .{
                    .root = .{
                        .root_dir = options.zig_lib_directory,
                    },
                    .root_src_path = "test_runner.zig",
                    .fully_qualified_name = "root",
                });

                break :root_mod test_mod;
            } else main_mod;

            const compiler_rt_mod = if (include_compiler_rt and options.output_mode == .Obj) compiler_rt_mod: {
                break :compiler_rt_mod try Package.Module.create(arena, .{
                    .root = .{
                        .root_dir = options.zig_lib_directory,
                    },
                    .root_src_path = "compiler_rt.zig",
                    .fully_qualified_name = "compiler_rt",
                });
            } else null;

            {
                try main_mod.deps.ensureUnusedCapacity(arena, 4);
                main_mod.deps.putAssumeCapacity("builtin", builtin_mod);
                main_mod.deps.putAssumeCapacity("root", root_mod);
                main_mod.deps.putAssumeCapacity("std", std_mod);
                if (compiler_rt_mod) |m|
                    main_mod.deps.putAssumeCapacity("compiler_rt", m);
            }

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
                const eh = try gpa.create(Module.GlobalEmitH);
                eh.* = .{ .loc = loc };
                break :eh eh;
            } else null;
            errdefer if (emit_h) |eh| gpa.destroy(eh);

            // TODO when we implement serialization and deserialization of incremental
            // compilation metadata, this is where we would load it. We have open a handle
            // to the directory where the output either already is, or will be.
            // However we currently do not have serialization of such metadata, so for now
            // we set up an empty Module that does the entire compilation fresh.

            const module = try arena.create(Module);
            errdefer module.deinit();
            module.* = .{
                .gpa = gpa,
                .comp = comp,
                .main_mod = main_mod,
                .root_mod = root_mod,
                .zig_cache_artifact_directory = zig_cache_artifact_directory,
                .global_zir_cache = global_zir_cache,
                .local_zir_cache = local_zir_cache,
                .emit_h = emit_h,
                .tmp_hack_arena = std.heap.ArenaAllocator.init(gpa),
                .error_limit = error_limit,
            };
            try module.init();

            break :blk module;
        } else blk: {
            if (options.emit_h != null) return error.NoZigModuleForCHeader;
            break :blk null;
        };
        errdefer if (module) |zm| zm.deinit();

        const error_return_tracing = !strip and switch (options.optimize_mode) {
            .Debug, .ReleaseSafe => (!options.target.isWasm() or options.target.os.tag == .emscripten) and
                !options.target.cpu.arch.isBpf() and (options.error_tracing orelse true),
            .ReleaseFast => options.error_tracing orelse false,
            .ReleaseSmall => false,
        };

        // For resource management purposes.
        var owned_link_dir: ?std.fs.Dir = null;
        errdefer if (owned_link_dir) |*dir| dir.close();

        const bin_file_emit: ?link.Emit = blk: {
            const emit_bin = options.emit_bin orelse break :blk null;

            if (emit_bin.directory) |directory| {
                break :blk link.Emit{
                    .directory = directory,
                    .sub_path = emit_bin.basename,
                };
            }

            // In case of whole cache mode, `whole_bin_sub_path` is used to distinguish
            // between -femit-bin and -fno-emit-bin.
            switch (cache_mode) {
                .whole => break :blk null,
                .incremental => {},
            }

            if (module) |zm| {
                break :blk link.Emit{
                    .directory = zm.zig_cache_artifact_directory,
                    .sub_path = emit_bin.basename,
                };
            }

            // We could use the cache hash as is no problem, however, we increase
            // the likelihood of cache hits by adding the first C source file
            // path name (not contents) to the hash. This way if the user is compiling
            // foo.c and bar.c as separate compilations, they get different cache
            // directories.
            var hash = cache.hash;
            if (options.c_source_files.len >= 1) {
                hash.addBytes(options.c_source_files[0].src_path);
            } else if (options.link_objects.len >= 1) {
                hash.addBytes(options.link_objects[0].path);
            }

            const digest = hash.final();
            const artifact_sub_dir = try std.fs.path.join(arena, &[_][]const u8{ "o", &digest });
            const artifact_dir = try options.local_cache_directory.handle.makeOpenPath(artifact_sub_dir, .{});
            owned_link_dir = artifact_dir;
            const link_artifact_directory: Directory = .{
                .handle = artifact_dir,
                .path = try options.local_cache_directory.join(arena, &[_][]const u8{artifact_sub_dir}),
            };
            break :blk link.Emit{
                .directory = link_artifact_directory,
                .sub_path = emit_bin.basename,
            };
        };

        const implib_emit: ?link.Emit = blk: {
            const emit_implib = options.emit_implib orelse break :blk null;

            if (emit_implib.directory) |directory| {
                break :blk link.Emit{
                    .directory = directory,
                    .sub_path = emit_implib.basename,
                };
            }

            // This is here for the same reason as in `bin_file_emit` above.
            switch (cache_mode) {
                .whole => break :blk null,
                .incremental => {},
            }

            // Use the same directory as the bin. The CLI already emits an
            // error if -fno-emit-bin is combined with -femit-implib.
            break :blk link.Emit{
                .directory = bin_file_emit.?.directory,
                .sub_path = emit_implib.basename,
            };
        };

        const docs_emit: ?link.Emit = blk: {
            const emit_docs = options.emit_docs orelse break :blk null;

            if (emit_docs.directory) |directory| {
                break :blk .{
                    .directory = directory,
                    .sub_path = emit_docs.basename,
                };
            }

            // This is here for the same reason as in `bin_file_emit` above.
            switch (cache_mode) {
                .whole => break :blk null,
                .incremental => {},
            }

            // Use the same directory as the bin, if possible.
            if (bin_file_emit) |x| break :blk .{
                .directory = x.directory,
                .sub_path = emit_docs.basename,
            };

            break :blk .{
                .directory = module.?.zig_cache_artifact_directory,
                .sub_path = emit_docs.basename,
            };
        };

        // This is so that when doing `CacheMode.whole`, the mechanism in update()
        // can use it for communicating the result directory via `bin_file.emit`.
        // This is used to distinguish between -fno-emit-bin and -femit-bin
        // for `CacheMode.whole`.
        // This memory will be overwritten with the real digest in update() but
        // the basename will be preserved.
        const whole_bin_sub_path: ?[]u8 = try prepareWholeEmitSubPath(arena, options.emit_bin);
        // Same thing but for implibs.
        const whole_implib_sub_path: ?[]u8 = try prepareWholeEmitSubPath(arena, options.emit_implib);
        const whole_docs_sub_path: ?[]u8 = try prepareWholeEmitSubPath(arena, options.emit_docs);

        var system_libs: std.StringArrayHashMapUnmanaged(SystemLib) = .{};
        errdefer system_libs.deinit(gpa);
        try system_libs.ensureTotalCapacity(gpa, options.system_lib_names.len);
        for (options.system_lib_names, 0..) |lib_name, i| {
            system_libs.putAssumeCapacity(lib_name, options.system_lib_infos[i]);
        }

        const bin_file = try link.File.openPath(gpa, .{
            .emit = bin_file_emit,
            .implib_emit = implib_emit,
            .docs_emit = docs_emit,
            .root_name = root_name,
            .module = module,
            .target = options.target,
            .dynamic_linker = options.dynamic_linker,
            .sysroot = sysroot,
            .output_mode = options.output_mode,
            .link_mode = link_mode,
            .optimize_mode = options.optimize_mode,
            .use_lld = use_lld,
            .use_llvm = use_llvm,
            .use_lib_llvm = use_lib_llvm,
            .link_libc = link_libc,
            .link_libcpp = link_libcpp,
            .link_libunwind = link_libunwind,
            .darwin_sdk_layout = libc_dirs.darwin_sdk_layout,
            .objects = options.link_objects,
            .frameworks = options.frameworks,
            .framework_dirs = options.framework_dirs,
            .system_libs = system_libs,
            .wasi_emulated_libs = options.wasi_emulated_libs,
            .lib_dirs = options.lib_dirs,
            .rpath_list = options.rpath_list,
            .symbol_wrap_set = options.symbol_wrap_set,
            .strip = strip,
            .is_native_os = options.is_native_os,
            .is_native_abi = options.is_native_abi,
            .function_sections = options.function_sections,
            .data_sections = options.data_sections,
            .no_builtin = options.no_builtin,
            .allow_shlib_undefined = options.linker_allow_shlib_undefined,
            .bind_global_refs_locally = options.linker_bind_global_refs_locally orelse false,
            .compress_debug_sections = options.linker_compress_debug_sections orelse .none,
            .module_definition_file = options.linker_module_definition_file,
            .sort_section = options.linker_sort_section,
            .import_memory = options.linker_import_memory orelse false,
            .export_memory = options.linker_export_memory orelse !(options.linker_import_memory orelse false),
            .import_symbols = options.linker_import_symbols,
            .import_table = options.linker_import_table,
            .export_table = options.linker_export_table,
            .initial_memory = options.linker_initial_memory,
            .max_memory = options.linker_max_memory,
            .shared_memory = options.linker_shared_memory,
            .global_base = options.linker_global_base,
            .export_symbol_names = options.linker_export_symbol_names,
            .print_gc_sections = options.linker_print_gc_sections,
            .print_icf_sections = options.linker_print_icf_sections,
            .print_map = options.linker_print_map,
            .opt_bisect_limit = options.linker_opt_bisect_limit,
            .z_nodelete = options.linker_z_nodelete,
            .z_notext = options.linker_z_notext,
            .z_defs = options.linker_z_defs,
            .z_origin = options.linker_z_origin,
            .z_nocopyreloc = options.linker_z_nocopyreloc,
            .z_now = options.linker_z_now,
            .z_relro = options.linker_z_relro,
            .z_common_page_size = options.linker_z_common_page_size,
            .z_max_page_size = options.linker_z_max_page_size,
            .tsaware = options.linker_tsaware,
            .nxcompat = options.linker_nxcompat,
            .dynamicbase = options.linker_dynamicbase,
            .linker_optimization = linker_optimization,
            .major_subsystem_version = options.major_subsystem_version,
            .minor_subsystem_version = options.minor_subsystem_version,
            .entry = options.entry,
            .stack_size_override = options.stack_size_override,
            .image_base_override = options.image_base_override,
            .include_compiler_rt = include_compiler_rt,
            .linker_script = options.linker_script,
            .version_script = options.version_script,
            .gc_sections = options.linker_gc_sections,
            .eh_frame_hdr = link_eh_frame_hdr,
            .emit_relocs = options.link_emit_relocs,
            .rdynamic = options.rdynamic,
            .soname = options.soname,
            .version = options.version,
            .compatibility_version = options.compatibility_version,
            .libc_installation = libc_dirs.libc_installation,
            .pic = pic,
            .pie = pie,
            .lto = lto,
            .valgrind = valgrind,
            .tsan = tsan,
            .stack_check = stack_check,
            .stack_protector = stack_protector,
            .red_zone = red_zone,
            .omit_frame_pointer = omit_frame_pointer,
            .single_threaded = single_threaded,
            .verbose_link = options.verbose_link,
            .machine_code_model = options.machine_code_model,
            .dll_export_fns = dll_export_fns,
            .error_return_tracing = error_return_tracing,
            .llvm_cpu_features = llvm_cpu_features,
            .skip_linker_dependencies = options.skip_linker_dependencies,
            .parent_compilation_link_libc = options.parent_compilation_link_libc,
            .each_lib_rpath = options.each_lib_rpath orelse options.is_native_os,
            .build_id = build_id,
            .cache_mode = cache_mode,
            .disable_lld_caching = options.disable_lld_caching or cache_mode == .whole,
            .subsystem = options.subsystem,
            .is_test = options.is_test,
            .dwarf_format = options.dwarf_format,
            .wasi_exec_model = wasi_exec_model,
            .hash_style = options.hash_style,
            .enable_link_snapshots = options.enable_link_snapshots,
            .install_name = options.install_name,
            .entitlements = options.entitlements,
            .pagezero_size = options.pagezero_size,
            .headerpad_size = options.headerpad_size,
            .headerpad_max_install_names = options.headerpad_max_install_names,
            .dead_strip_dylibs = options.dead_strip_dylibs,
            .force_undefined_symbols = options.force_undefined_symbols,
            .pdb_source_path = options.pdb_source_path,
            .pdb_out_path = options.pdb_out_path,
            .want_structured_cfg = options.want_structured_cfg,
        });
        errdefer bin_file.destroy();
        comp.* = .{
            .gpa = gpa,
            .arena = arena_allocator,
            .zig_lib_directory = options.zig_lib_directory,
            .local_cache_directory = options.local_cache_directory,
            .global_cache_directory = options.global_cache_directory,
            .bin_file = bin_file,
            .whole_bin_sub_path = whole_bin_sub_path,
            .whole_implib_sub_path = whole_implib_sub_path,
            .whole_docs_sub_path = whole_docs_sub_path,
            .emit_asm = options.emit_asm,
            .emit_llvm_ir = options.emit_llvm_ir,
            .emit_llvm_bc = options.emit_llvm_bc,
            .work_queue = std.fifo.LinearFifo(Job, .Dynamic).init(gpa),
            .anon_work_queue = std.fifo.LinearFifo(Job, .Dynamic).init(gpa),
            .c_object_work_queue = std.fifo.LinearFifo(*CObject, .Dynamic).init(gpa),
            .win32_resource_work_queue = if (build_options.only_core_functionality) {} else std.fifo.LinearFifo(*Win32Resource, .Dynamic).init(gpa),
            .astgen_work_queue = std.fifo.LinearFifo(*Module.File, .Dynamic).init(gpa),
            .embed_file_work_queue = std.fifo.LinearFifo(*Module.EmbedFile, .Dynamic).init(gpa),
            .keep_source_files_loaded = options.keep_source_files_loaded,
            .c_frontend = c_frontend,
            .clang_argv = options.clang_argv,
            .c_source_files = options.c_source_files,
            .rc_source_files = options.rc_source_files,
            .cache_parent = cache,
            .self_exe_path = options.self_exe_path,
            .libc_include_dir_list = libc_dirs.libc_include_dir_list,
            .libc_framework_dir_list = libc_dirs.libc_framework_dir_list,
            .rc_include_dir_list = rc_dirs.libc_include_dir_list,
            .sanitize_c = sanitize_c,
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
            .disable_c_depfile = options.disable_c_depfile,
            .owned_link_dir = owned_link_dir,
            .color = options.color,
            .reference_trace = options.reference_trace,
            .formatted_panics = formatted_panics,
            .time_report = options.time_report,
            .stack_report = options.stack_report,
            .unwind_tables = unwind_tables,
            .test_filter = options.test_filter,
            .test_name_prefix = options.test_name_prefix,
            .test_evented_io = options.test_evented_io,
            .debug_compiler_runtime_libs = options.debug_compiler_runtime_libs,
            .debug_compile_errors = options.debug_compile_errors,
            .libcxx_abi_version = options.libcxx_abi_version,
        };
        break :comp comp;
    };
    errdefer comp.destroy();

    const target = comp.getTarget();

    const capable_of_building_compiler_rt = canBuildLibCompilerRt(target, comp.bin_file.options.use_llvm);
    const capable_of_building_zig_libc = canBuildZigLibC(target, comp.bin_file.options.use_llvm);

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

    const have_bin_emit = comp.bin_file.options.emit != null or comp.whole_bin_sub_path != null;

    if (have_bin_emit and !comp.bin_file.options.skip_linker_dependencies and target.ofmt != .c) {
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
            if (!target_util.canBuildLibC(target)) return error.LibCUnavailable;

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
            if (!target_util.canBuildLibC(target)) return error.LibCUnavailable;

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
                switch (comp.bin_file.options.link_mode) {
                    .Static => .{ .musl_crt_file = .libc_a },
                    .Dynamic => .{ .musl_crt_file = .libc_so },
                },
            });
        }
        if (comp.wantBuildWasiLibcFromSource()) {
            if (!target_util.canBuildLibC(target)) return error.LibCUnavailable;

            const wasi_emulated_libs = comp.bin_file.options.wasi_emulated_libs;
            try comp.work_queue.ensureUnusedCapacity(wasi_emulated_libs.len + 2); // worst-case we need all components
            for (wasi_emulated_libs) |crt_file| {
                comp.work_queue.writeItemAssumeCapacity(.{
                    .wasi_libc_crt_file = crt_file,
                });
            }
            comp.work_queue.writeAssumeCapacity(&[_]Job{
                .{ .wasi_libc_crt_file = wasi_libc.execModelCrtFile(wasi_exec_model) },
                .{ .wasi_libc_crt_file = .libc_a },
            });
        }
        if (comp.wantBuildMinGWFromSource()) {
            if (!target_util.canBuildLibC(target)) return error.LibCUnavailable;

            const static_lib_jobs = [_]Job{
                .{ .mingw_crt_file = .mingw32_lib },
                .{ .mingw_crt_file = .msvcrt_os_lib },
                .{ .mingw_crt_file = .mingwex_lib },
                .{ .mingw_crt_file = .uuid_lib },
            };
            const crt_job: Job = .{ .mingw_crt_file = if (is_dyn_lib) .dllcrt2_o else .crt2_o };
            try comp.work_queue.ensureUnusedCapacity(static_lib_jobs.len + 1);
            comp.work_queue.writeAssumeCapacity(&static_lib_jobs);
            comp.work_queue.writeItemAssumeCapacity(crt_job);

            // When linking mingw-w64 there are some import libs we always need.
            for (mingw.always_link_libs) |name| {
                try comp.bin_file.options.system_libs.put(comp.gpa, name, .{
                    .needed = false,
                    .weak = false,
                    .path = null,
                });
            }
        }
        // Generate Windows import libs.
        if (target.os.tag == .windows) {
            const count = comp.bin_file.options.system_libs.count();
            try comp.work_queue.ensureUnusedCapacity(count);
            for (0..count) |i| {
                comp.work_queue.writeItemAssumeCapacity(.{ .windows_import_lib = i });
            }
        }
        if (comp.wantBuildLibUnwindFromSource()) {
            try comp.work_queue.writeItem(.{ .libunwind = {} });
        }
        if (build_options.have_llvm and is_exe_or_dyn_lib and comp.bin_file.options.link_libcpp) {
            try comp.work_queue.writeItem(.libcxx);
            try comp.work_queue.writeItem(.libcxxabi);
        }
        if (build_options.have_llvm and comp.bin_file.options.tsan) {
            try comp.work_queue.writeItem(.libtsan);
        }

        if (comp.getTarget().isMinGW() and !comp.bin_file.options.single_threaded) {
            // LLD might drop some symbols as unused during LTO and GCing, therefore,
            // we force mark them for resolution here.

            const tls_index_sym = switch (comp.getTarget().cpu.arch) {
                .x86 => "__tls_index",
                else => "_tls_index",
            };

            try comp.bin_file.options.force_undefined_symbols.put(comp.gpa, tls_index_sym, {});
        }

        if (comp.bin_file.options.include_compiler_rt and capable_of_building_compiler_rt) {
            if (is_exe_or_dyn_lib) {
                log.debug("queuing a job to build compiler_rt_lib", .{});
                comp.job_queued_compiler_rt_lib = true;
            } else if (options.output_mode != .Obj) {
                log.debug("queuing a job to build compiler_rt_obj", .{});
                // In this case we are making a static library, so we ask
                // for a compiler-rt object to put in it.
                comp.job_queued_compiler_rt_obj = true;
            }
        }

        if (!comp.bin_file.options.skip_linker_dependencies and is_exe_or_dyn_lib and
            !comp.bin_file.options.link_libc and capable_of_building_zig_libc)
        {
            try comp.work_queue.writeItem(.{ .zig_libc = {} });
        }
    }

    return comp;
}

pub fn destroy(self: *Compilation) void {
    const optional_module = self.bin_file.options.module;
    self.bin_file.destroy();
    if (optional_module) |module| module.deinit();

    const gpa = self.gpa;
    self.work_queue.deinit();
    self.anon_work_queue.deinit();
    self.c_object_work_queue.deinit();
    if (!build_options.only_core_functionality) {
        self.win32_resource_work_queue.deinit();
    }
    self.astgen_work_queue.deinit();
    self.embed_file_work_queue.deinit();

    {
        var it = self.crt_files.iterator();
        while (it.next()) |entry| {
            gpa.free(entry.key_ptr.*);
            entry.value_ptr.deinit(gpa);
        }
        self.crt_files.deinit(gpa);
    }

    if (self.libunwind_static_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }
    if (self.libcxx_static_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }
    if (self.libcxxabi_static_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }
    if (self.compiler_rt_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }
    if (self.compiler_rt_obj) |*crt_file| {
        crt_file.deinit(gpa);
    }
    if (self.libc_static_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }

    if (self.glibc_so_files) |*glibc_file| {
        glibc_file.deinit(gpa);
    }

    for (self.c_object_table.keys()) |key| {
        key.destroy(gpa);
    }
    self.c_object_table.deinit(gpa);

    for (self.failed_c_objects.values()) |value| {
        value.destroy(gpa);
    }
    self.failed_c_objects.deinit(gpa);

    if (!build_options.only_core_functionality) {
        for (self.win32_resource_table.keys()) |key| {
            key.destroy(gpa);
        }
        self.win32_resource_table.deinit(gpa);

        for (self.failed_win32_resources.values()) |*value| {
            value.deinit(gpa);
        }
        self.failed_win32_resources.deinit(gpa);
    }

    for (self.lld_errors.items) |*lld_error| {
        lld_error.deinit(gpa);
    }
    self.lld_errors.deinit(gpa);

    self.clearMiscFailures();

    self.cache_parent.manifest_dir.close();
    if (self.owned_link_dir) |*dir| dir.close();

    // This destroys `self`.
    var arena_instance = self.arena;
    arena_instance.deinit();
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
    return self.bin_file.options.target;
}

fn restorePrevZigCacheArtifactDirectory(comp: *Compilation, directory: *Directory) void {
    if (directory.path) |p| comp.gpa.free(p);

    // Restore the Module's previous zig_cache_artifact_directory
    // This is only for cleanup purposes; Module.deinit calls close
    // on the handle of zig_cache_artifact_directory.
    if (comp.bin_file.options.module) |module| {
        const builtin_mod = module.main_mod.deps.get("builtin").?;
        module.zig_cache_artifact_directory = builtin_mod.root.root_dir;
    }
}

fn cleanupTmpArtifactDirectory(
    comp: *Compilation,
    tmp_artifact_directory: *?Directory,
    tmp_dir_sub_path: []const u8,
) void {
    comp.gpa.free(tmp_dir_sub_path);
    if (tmp_artifact_directory.*) |*directory| {
        directory.handle.close();
        restorePrevZigCacheArtifactDirectory(comp, directory);
    }
}

pub fn hotCodeSwap(comp: *Compilation, prog_node: *std.Progress.Node, pid: std.ChildProcess.Id) !void {
    comp.bin_file.child_pid = pid;
    try comp.makeBinFileWritable();
    try comp.update(prog_node);
    try comp.makeBinFileExecutable();
}

/// Detect changes to source files, perform semantic analysis, and update the output files.
pub fn update(comp: *Compilation, main_progress_node: *std.Progress.Node) !void {
    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    comp.clearMiscFailures();
    comp.last_update_was_cache_hit = false;

    var man: Cache.Manifest = undefined;
    defer if (comp.whole_cache_manifest != null) man.deinit();

    var tmp_dir_sub_path: []const u8 = &.{};
    var tmp_artifact_directory: ?Directory = null;
    defer cleanupTmpArtifactDirectory(comp, &tmp_artifact_directory, tmp_dir_sub_path);

    // If using the whole caching strategy, we check for *everything* up front, including
    // C source files.
    if (comp.bin_file.options.cache_mode == .whole) {
        // We are about to obtain this lock, so here we give other processes a chance first.
        comp.bin_file.releaseLock();

        man = comp.cache_parent.obtain();
        comp.whole_cache_manifest = &man;
        try comp.addNonIncrementalStuffToCacheManifest(&man);

        const is_hit = man.hit() catch |err| {
            // TODO properly bubble these up instead of emitting a warning
            const i = man.failed_file_index orelse return err;
            const pp = man.files.items[i].prefixed_path orelse return err;
            const prefix = man.cache.prefixes()[pp.prefix].path orelse "";
            std.log.warn("{s}: {s}{s}", .{ @errorName(err), prefix, pp.sub_path });
            return err;
        };
        if (is_hit) {
            comp.last_update_was_cache_hit = true;
            log.debug("CacheMode.whole cache hit for {s}", .{comp.bin_file.options.root_name});
            const digest = man.final();

            comp.wholeCacheModeSetBinFilePath(&digest);

            assert(comp.bin_file.lock == null);
            comp.bin_file.lock = man.toOwnedLock();
            return;
        }
        log.debug("CacheMode.whole cache miss for {s}", .{comp.bin_file.options.root_name});

        // Initialize `bin_file.emit` with a temporary Directory so that compilation can
        // continue on the same path as incremental, using the temporary Directory.
        tmp_artifact_directory = d: {
            const s = std.fs.path.sep_str;
            const rand_int = std.crypto.random.int(u64);

            tmp_dir_sub_path = try std.fmt.allocPrint(comp.gpa, "tmp" ++ s ++ "{x}", .{rand_int});

            const path = try comp.local_cache_directory.join(comp.gpa, &.{tmp_dir_sub_path});
            errdefer comp.gpa.free(path);

            const handle = try comp.local_cache_directory.handle.makeOpenPath(tmp_dir_sub_path, .{});
            errdefer handle.close();

            break :d .{
                .path = path,
                .handle = handle,
            };
        };

        // This updates the output directory for linker outputs.
        if (comp.bin_file.options.module) |module| {
            module.zig_cache_artifact_directory = tmp_artifact_directory.?;
        }

        // This resets the link.File to operate as if we called openPath() in create()
        // instead of simulating -fno-emit-bin.
        var options = comp.bin_file.options.move();
        if (comp.whole_bin_sub_path) |sub_path| {
            options.emit = .{
                .directory = tmp_artifact_directory.?,
                .sub_path = std.fs.path.basename(sub_path),
            };
        }
        if (comp.whole_implib_sub_path) |sub_path| {
            options.implib_emit = .{
                .directory = tmp_artifact_directory.?,
                .sub_path = std.fs.path.basename(sub_path),
            };
        }
        if (comp.whole_docs_sub_path) |sub_path| {
            options.docs_emit = .{
                .directory = tmp_artifact_directory.?,
                .sub_path = std.fs.path.basename(sub_path),
            };
        }
        var old_bin_file = comp.bin_file;
        comp.bin_file = try link.File.openPath(comp.gpa, options);
        old_bin_file.destroy();
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

    if (comp.bin_file.options.module) |module| {
        module.compile_log_text.shrinkAndFree(module.gpa, 0);
        module.generation += 1;

        // Make sure std.zig is inside the import_table. We unconditionally need
        // it for start.zig.
        const std_mod = module.main_mod.deps.get("std").?;
        _ = try module.importPkg(std_mod);

        // Normally we rely on importing std to in turn import the root source file
        // in the start code, but when using the stage1 backend that won't happen,
        // so in order to run AstGen on the root source file we put it into the
        // import_table here.
        // Likewise, in the case of `zig test`, the test runner is the root source file,
        // and so there is nothing to import the main file.
        if (comp.bin_file.options.is_test) {
            _ = try module.importPkg(module.main_mod);
        }

        if (module.main_mod.deps.get("compiler_rt")) |compiler_rt_mod| {
            _ = try module.importPkg(compiler_rt_mod);
        }

        // Put a work item in for every known source file to detect if
        // it changed, and, if so, re-compute ZIR and then queue the job
        // to update it.
        // We still want AstGen work items for stage1 so that we expose compile errors
        // that are implemented in stage2 but not stage1.
        try comp.astgen_work_queue.ensureUnusedCapacity(module.import_table.count());
        for (module.import_table.values()) |value| {
            comp.astgen_work_queue.writeItemAssumeCapacity(value);
        }

        // Put a work item in for checking if any files used with `@embedFile` changed.
        {
            try comp.embed_file_work_queue.ensureUnusedCapacity(module.embed_table.count());
            var it = module.embed_table.iterator();
            while (it.next()) |entry| {
                const embed_file = entry.value_ptr.*;
                comp.embed_file_work_queue.writeItemAssumeCapacity(embed_file);
            }
        }

        try comp.work_queue.writeItem(.{ .analyze_mod = std_mod });
        if (comp.bin_file.options.is_test) {
            try comp.work_queue.writeItem(.{ .analyze_mod = module.main_mod });
        }

        if (module.main_mod.deps.get("compiler_rt")) |compiler_rt_mod| {
            try comp.work_queue.writeItem(.{ .analyze_mod = compiler_rt_mod });
        }
    }

    try comp.performAllTheWork(main_progress_node);

    if (comp.bin_file.options.module) |module| {
        if (builtin.mode == .Debug and comp.verbose_intern_pool) {
            std.debug.print("intern pool stats for '{s}':\n", .{
                comp.bin_file.options.root_name,
            });
            module.intern_pool.dump();
        }

        if (builtin.mode == .Debug and comp.verbose_generic_instances) {
            std.debug.print("generic instances for '{s}:0x{x}':\n", .{
                comp.bin_file.options.root_name,
                @as(usize, @intFromPtr(module)),
            });
            module.intern_pool.dumpGenericInstances(comp.gpa);
        }

        if (comp.bin_file.options.is_test and comp.totalErrorCount() == 0) {
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

    // Flush takes care of -femit-bin, but we still have -femit-llvm-ir, -femit-llvm-bc, and
    // -femit-asm to handle, in the case of C objects.
    comp.emitOthers();

    if (comp.whole_cache_manifest != null) {
        const digest = man.final();

        // Rename the temporary directory into place.
        var directory = tmp_artifact_directory.?;
        tmp_artifact_directory = null;

        directory.handle.close();
        defer restorePrevZigCacheArtifactDirectory(comp, &directory);

        const o_sub_path = try std.fs.path.join(comp.gpa, &[_][]const u8{ "o", &digest });
        defer comp.gpa.free(o_sub_path);

        // Work around windows `AccessDenied` if any files within this directory are open
        // by closing and reopening the file handles.
        const need_writable_dance = builtin.os.tag == .windows and comp.bin_file.file != null;
        if (need_writable_dance) {
            // We cannot just call `makeExecutable` as it makes a false assumption that we have a
            // file handle open only when linking an executable file. This used to be true when
            // our linkers were incapable of emitting relocatables and static archive. Now that
            // they are capable, we need to unconditionally close the file handle and re-open it
            // in the follow up call to `makeWritable`.
            comp.bin_file.file.?.close();
            comp.bin_file.file = null;
        }

        try comp.bin_file.renameTmpIntoCache(comp.local_cache_directory, tmp_dir_sub_path, o_sub_path);
        comp.wholeCacheModeSetBinFilePath(&digest);

        // Has to be after the `wholeCacheModeSetBinFilePath` above.
        if (need_writable_dance) {
            try comp.bin_file.makeWritable();
        }

        // This is intentionally sandwiched between renameTmpIntoCache() and writeManifest().
        if (comp.bin_file.options.module) |module| {
            // We need to set the zig_cache_artifact_directory for -femit-asm, -femit-llvm-ir,
            // etc to know where to output to.
            var artifact_dir = try comp.local_cache_directory.handle.openDir(o_sub_path, .{});
            defer artifact_dir.close();

            const dir_path = try comp.local_cache_directory.join(comp.gpa, &.{o_sub_path});
            defer comp.gpa.free(dir_path);

            module.zig_cache_artifact_directory = .{
                .handle = artifact_dir,
                .path = dir_path,
            };

            try comp.flush(main_progress_node);
            if (comp.totalErrorCount() != 0) return;

            // Note the placement of this logic is relying on the call to
            // `wholeCacheModeSetBinFilePath` above.
            try maybeGenerateAutodocs(comp, main_progress_node);
        } else {
            try comp.flush(main_progress_node);
            if (comp.totalErrorCount() != 0) return;
        }

        // Failure here only means an unnecessary cache miss.
        man.writeManifest() catch |err| {
            log.warn("failed to write cache manifest: {s}", .{@errorName(err)});
        };

        assert(comp.bin_file.lock == null);
        comp.bin_file.lock = man.toOwnedLock();
    } else {
        try comp.flush(main_progress_node);

        if (comp.totalErrorCount() == 0) {
            try maybeGenerateAutodocs(comp, main_progress_node);
        }
    }

    // Unload all source files to save memory.
    // The ZIR needs to stay loaded in memory because (1) Decl objects contain references
    // to it, and (2) generic instantiations, comptime calls, inline calls will need
    // to reference the ZIR.
    if (!comp.keep_source_files_loaded) {
        if (comp.bin_file.options.module) |module| {
            for (module.import_table.values()) |file| {
                file.unloadTree(comp.gpa);
                file.unloadSource(comp.gpa);
            }
        }
    }
}

fn maybeGenerateAutodocs(comp: *Compilation, prog_node: *std.Progress.Node) !void {
    const mod = comp.bin_file.options.module orelse return;
    // TODO: do this in a separate job during performAllTheWork(). The
    // file copies at the end of generate() can also be extracted to
    // separate jobs
    if (!build_options.only_c and !build_options.only_core_functionality) {
        if (comp.bin_file.options.docs_emit) |emit| {
            var dir = try emit.directory.handle.makeOpenPath(emit.sub_path, .{});
            defer dir.close();

            var sub_prog_node = prog_node.start("Generating documentation", 0);
            sub_prog_node.activate();
            sub_prog_node.context.refresh();
            defer sub_prog_node.end();

            try Autodoc.generate(mod, dir);
        }
    }
}

fn flush(comp: *Compilation, prog_node: *std.Progress.Node) !void {
    // This is needed before reading the error flags.
    comp.bin_file.flush(comp, prog_node) catch |err| switch (err) {
        error.FlushFailure => {}, // error reported through link_error_flags
        error.LLDReportedFailure => {}, // error reported via lockAndParseLldStderr
        else => |e| return e,
    };
    comp.link_error_flags = comp.bin_file.errorFlags();

    if (comp.bin_file.options.module) |module| {
        try link.File.C.flushEmitH(module);
    }
}

/// Communicate the output binary location to parent Compilations.
fn wholeCacheModeSetBinFilePath(comp: *Compilation, digest: *const [Cache.hex_digest_len]u8) void {
    const digest_start = 2; // "o/[digest]/[basename]"

    if (comp.whole_bin_sub_path) |sub_path| {
        @memcpy(sub_path[digest_start..][0..digest.len], digest);

        comp.bin_file.options.emit = .{
            .directory = comp.local_cache_directory,
            .sub_path = sub_path,
        };
    }

    if (comp.whole_implib_sub_path) |sub_path| {
        @memcpy(sub_path[digest_start..][0..digest.len], digest);

        comp.bin_file.options.implib_emit = .{
            .directory = comp.local_cache_directory,
            .sub_path = sub_path,
        };
    }

    if (comp.whole_docs_sub_path) |sub_path| {
        @memcpy(sub_path[digest_start..][0..digest.len], digest);

        comp.bin_file.options.docs_emit = .{
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
pub const link_hash_implementation_version = 10;

fn addNonIncrementalStuffToCacheManifest(comp: *Compilation, man: *Cache.Manifest) !void {
    const gpa = comp.gpa;
    const target = comp.getTarget();

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    comptime assert(link_hash_implementation_version == 10);

    if (comp.bin_file.options.module) |mod| {
        const main_zig_file = try mod.main_mod.root.joinString(arena, mod.main_mod.root_src_path);
        _ = try man.addFile(main_zig_file, null);
        {
            var seen_table = std.AutoHashMap(*Package.Module, void).init(arena);

            // Skip builtin.zig; it is useless as an input, and we don't want to have to
            // write it before checking for a cache hit.
            const builtin_mod = mod.main_mod.deps.get("builtin").?;
            try seen_table.put(builtin_mod, {});

            try addModuleTableToCacheHash(&man.hash, &arena_allocator, mod.main_mod.deps, &seen_table, .{ .files = man });
        }

        // Synchronize with other matching comments: ZigOnlyHashStuff
        man.hash.add(comp.bin_file.options.valgrind);
        man.hash.add(comp.bin_file.options.single_threaded);
        man.hash.add(comp.bin_file.options.use_llvm);
        man.hash.add(comp.bin_file.options.use_lib_llvm);
        man.hash.add(comp.bin_file.options.dll_export_fns);
        man.hash.add(comp.bin_file.options.is_test);
        man.hash.add(comp.test_evented_io);
        man.hash.addOptionalBytes(comp.test_filter);
        man.hash.addOptionalBytes(comp.test_name_prefix);
        man.hash.add(comp.bin_file.options.skip_linker_dependencies);
        man.hash.add(comp.bin_file.options.parent_compilation_link_libc);
        man.hash.add(comp.formatted_panics);
        man.hash.add(mod.emit_h != null);
        man.hash.add(mod.error_limit);
        man.hash.addOptional(comp.bin_file.options.want_structured_cfg);
    }

    try man.addOptionalFile(comp.bin_file.options.linker_script);
    try man.addOptionalFile(comp.bin_file.options.version_script);

    for (comp.bin_file.options.objects) |obj| {
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

    man.hash.addListOfBytes(comp.rc_include_dir_list);

    cache_helpers.addOptionalEmitLoc(&man.hash, comp.emit_asm);
    cache_helpers.addOptionalEmitLoc(&man.hash, comp.emit_llvm_ir);
    cache_helpers.addOptionalEmitLoc(&man.hash, comp.emit_llvm_bc);

    man.hash.addListOfBytes(comp.clang_argv);

    man.hash.addOptional(comp.bin_file.options.stack_size_override);
    man.hash.addOptional(comp.bin_file.options.image_base_override);
    man.hash.addOptional(comp.bin_file.options.gc_sections);
    man.hash.add(comp.bin_file.options.eh_frame_hdr);
    man.hash.add(comp.bin_file.options.emit_relocs);
    man.hash.add(comp.bin_file.options.rdynamic);
    man.hash.addListOfBytes(comp.bin_file.options.lib_dirs);
    man.hash.addListOfBytes(comp.bin_file.options.rpath_list);
    man.hash.addListOfBytes(comp.bin_file.options.symbol_wrap_set.keys());
    man.hash.add(comp.bin_file.options.each_lib_rpath);
    man.hash.add(comp.bin_file.options.build_id);
    man.hash.add(comp.bin_file.options.skip_linker_dependencies);
    man.hash.add(comp.bin_file.options.z_nodelete);
    man.hash.add(comp.bin_file.options.z_notext);
    man.hash.add(comp.bin_file.options.z_defs);
    man.hash.add(comp.bin_file.options.z_origin);
    man.hash.add(comp.bin_file.options.z_nocopyreloc);
    man.hash.add(comp.bin_file.options.z_now);
    man.hash.add(comp.bin_file.options.z_relro);
    man.hash.add(comp.bin_file.options.z_common_page_size orelse 0);
    man.hash.add(comp.bin_file.options.z_max_page_size orelse 0);
    man.hash.add(comp.bin_file.options.hash_style);
    man.hash.add(comp.bin_file.options.compress_debug_sections);
    man.hash.add(comp.bin_file.options.include_compiler_rt);
    man.hash.addOptional(comp.bin_file.options.sort_section);
    if (comp.bin_file.options.link_libc) {
        man.hash.add(comp.bin_file.options.libc_installation != null);
        if (comp.bin_file.options.libc_installation) |libc_installation| {
            man.hash.addOptionalBytes(libc_installation.crt_dir);
            if (target.abi == .msvc) {
                man.hash.addOptionalBytes(libc_installation.msvc_lib_dir);
                man.hash.addOptionalBytes(libc_installation.kernel32_lib_dir);
            }
        }
        man.hash.addOptionalBytes(comp.bin_file.options.dynamic_linker);
    }
    man.hash.addOptionalBytes(comp.bin_file.options.soname);
    man.hash.addOptional(comp.bin_file.options.version);
    try link.hashAddSystemLibs(man, comp.bin_file.options.system_libs);
    man.hash.addListOfBytes(comp.bin_file.options.force_undefined_symbols.keys());
    man.hash.addOptional(comp.bin_file.options.allow_shlib_undefined);
    man.hash.add(comp.bin_file.options.bind_global_refs_locally);
    man.hash.add(comp.bin_file.options.tsan);
    man.hash.addOptionalBytes(comp.bin_file.options.sysroot);
    man.hash.add(comp.bin_file.options.linker_optimization);

    // WASM specific stuff
    man.hash.add(comp.bin_file.options.import_memory);
    man.hash.add(comp.bin_file.options.export_memory);
    man.hash.addOptional(comp.bin_file.options.initial_memory);
    man.hash.addOptional(comp.bin_file.options.max_memory);
    man.hash.add(comp.bin_file.options.shared_memory);
    man.hash.addOptional(comp.bin_file.options.global_base);

    // Mach-O specific stuff
    man.hash.addListOfBytes(comp.bin_file.options.framework_dirs);
    try link.hashAddFrameworks(man, comp.bin_file.options.frameworks);
    try man.addOptionalFile(comp.bin_file.options.entitlements);
    man.hash.addOptional(comp.bin_file.options.pagezero_size);
    man.hash.addOptional(comp.bin_file.options.headerpad_size);
    man.hash.add(comp.bin_file.options.headerpad_max_install_names);
    man.hash.add(comp.bin_file.options.dead_strip_dylibs);

    // COFF specific stuff
    man.hash.addOptional(comp.bin_file.options.subsystem);
    man.hash.add(comp.bin_file.options.tsaware);
    man.hash.add(comp.bin_file.options.nxcompat);
    man.hash.add(comp.bin_file.options.dynamicbase);
    man.hash.addOptional(comp.bin_file.options.major_subsystem_version);
    man.hash.addOptional(comp.bin_file.options.minor_subsystem_version);
}

fn emitOthers(comp: *Compilation) void {
    if (comp.bin_file.options.output_mode != .Obj or comp.bin_file.options.module != null or
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
pub fn makeBinFileExecutable(self: *Compilation) !void {
    return self.bin_file.makeExecutable();
}

pub fn makeBinFileWritable(self: *Compilation) !void {
    return self.bin_file.makeWritable();
}

const Header = extern struct {
    intern_pool: extern struct {
        items_len: u32,
        extra_len: u32,
        limbs_len: u32,
        string_bytes_len: u32,
    },
};

/// Note that all state that is included in the cache hash namespace is *not*
/// saved, such as the target and most CLI flags. A cache hit will only occur
/// when subsequent compiler invocations use the same set of flags.
pub fn saveState(comp: *Compilation) !void {
    var bufs_list: [6]std.os.iovec_const = undefined;
    var bufs_len: usize = 0;

    const emit = comp.bin_file.options.emit orelse return;

    if (comp.bin_file.options.module) |mod| {
        const ip = &mod.intern_pool;
        const header: Header = .{
            .intern_pool = .{
                .items_len = @intCast(ip.items.len),
                .extra_len = @intCast(ip.extra.items.len),
                .limbs_len = @intCast(ip.limbs.items.len),
                .string_bytes_len = @intCast(ip.string_bytes.items.len),
            },
        };
        addBuf(&bufs_list, &bufs_len, mem.asBytes(&header));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.limbs.items));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.extra.items));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.items.items(.data)));
        addBuf(&bufs_list, &bufs_len, mem.sliceAsBytes(ip.items.items(.tag)));
        addBuf(&bufs_list, &bufs_len, ip.string_bytes.items);

        // TODO: compilation errors
        // TODO: files
        // TODO: namespaces
        // TODO: decls
        // TODO: linker state
    }
    var basename_buf: [255]u8 = undefined;
    const basename = std.fmt.bufPrint(&basename_buf, "{s}.zcs", .{
        comp.bin_file.options.root_name,
    }) catch o: {
        basename_buf[basename_buf.len - 4 ..].* = ".zcs".*;
        break :o &basename_buf;
    };

    // Using an atomic file prevents a crash or power failure from corrupting
    // the previous incremental compilation state.
    var af = try emit.directory.handle.atomicFile(basename, .{});
    defer af.deinit();
    try af.file.pwritevAll(bufs_list[0..bufs_len], 0);
    try af.finish();
}

fn addBuf(bufs_list: []std.os.iovec_const, bufs_len: *usize, buf: []const u8) void {
    const i = bufs_len.*;
    bufs_len.* = i + 1;
    bufs_list[i] = .{
        .iov_base = buf.ptr,
        .iov_len = buf.len,
    };
}

/// This function is temporally single-threaded.
pub fn totalErrorCount(self: *Compilation) u32 {
    var total: usize =
        self.misc_failures.count() +
        @intFromBool(self.alloc_failure_occurred) +
        self.lld_errors.items.len;

    {
        var it = self.failed_c_objects.iterator();
        while (it.next()) |entry| total += entry.value_ptr.*.diags.len;
    }

    if (!build_options.only_core_functionality) {
        for (self.failed_win32_resources.values()) |errs| {
            total += errs.errorMessageCount();
        }
    }

    if (self.bin_file.options.module) |module| {
        total += module.failed_exports.count();
        total += module.failed_embed_files.count();

        {
            var it = module.failed_files.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.*) |_| {
                    total += 1;
                } else {
                    const file = entry.key_ptr.*;
                    assert(file.zir_loaded);
                    const payload_index = file.zir.extra[@intFromEnum(Zir.ExtraIndex.compile_errors)];
                    assert(payload_index != 0);
                    const header = file.zir.extraData(Zir.Inst.CompileErrors, payload_index);
                    total += header.data.items_len;
                }
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
        total += @intFromBool(self.link_error_flags.no_entry_point_found);
    }
    total += @intFromBool(self.link_error_flags.missing_libc);

    // Misc linker errors
    total += self.bin_file.miscErrors().len;

    // Compile log errors only count if there are no other errors.
    if (total == 0) {
        if (self.bin_file.options.module) |module| {
            total += @intFromBool(module.compile_log_decls.count() != 0);
        }
    }

    return @as(u32, @intCast(total));
}

/// This function is temporally single-threaded.
pub fn getAllErrorsAlloc(self: *Compilation) !ErrorBundle {
    const gpa = self.gpa;

    var bundle: ErrorBundle.Wip = undefined;
    try bundle.init(gpa);
    defer bundle.deinit();

    {
        var it = self.failed_c_objects.iterator();
        while (it.next()) |entry| try entry.value_ptr.*.addToErrorBundle(&bundle);
    }

    if (!build_options.only_core_functionality) {
        var it = self.failed_win32_resources.iterator();
        while (it.next()) |entry| {
            try bundle.addBundleAsRoots(entry.value_ptr.*);
        }
    }

    for (self.lld_errors.items) |lld_error| {
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
    for (self.misc_failures.values()) |*value| {
        try bundle.addRootErrorMessage(.{
            .msg = try bundle.addString(value.msg),
            .notes_len = if (value.children) |b| b.errorMessageCount() else 0,
        });
        if (value.children) |b| try bundle.addBundleAsNotes(b);
    }
    if (self.alloc_failure_occurred) {
        try bundle.addRootErrorMessage(.{
            .msg = try bundle.addString("memory allocation failure"),
        });
    }
    if (self.bin_file.options.module) |module| {
        {
            var it = module.failed_files.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.*) |msg| {
                    try addModuleErrorMsg(module, &bundle, msg.*);
                } else {
                    // Must be ZIR errors. Note that this may include AST errors.
                    // addZirErrorMessages asserts that the tree is loaded.
                    _ = try entry.key_ptr.*.getTree(gpa);
                    try addZirErrorMessages(&bundle, entry.key_ptr.*);
                }
            }
        }
        {
            var it = module.failed_embed_files.iterator();
            while (it.next()) |entry| {
                const msg = entry.value_ptr.*;
                try addModuleErrorMsg(module, &bundle, msg.*);
            }
        }
        {
            var it = module.failed_decls.iterator();
            while (it.next()) |entry| {
                const decl_index = entry.key_ptr.*;
                // Skip errors for Decls within files that had a parse failure.
                // We'll try again once parsing succeeds.
                if (module.declFileScope(decl_index).okToReportErrors()) {
                    try addModuleErrorMsg(module, &bundle, entry.value_ptr.*.*);
                    if (module.cimport_errors.get(entry.key_ptr.*)) |errors| {
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
        }
        if (module.emit_h) |emit_h| {
            var it = emit_h.failed_decls.iterator();
            while (it.next()) |entry| {
                const decl_index = entry.key_ptr.*;
                // Skip errors for Decls within files that had a parse failure.
                // We'll try again once parsing succeeds.
                if (module.declFileScope(decl_index).okToReportErrors()) {
                    try addModuleErrorMsg(module, &bundle, entry.value_ptr.*.*);
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
        if (self.link_error_flags.no_entry_point_found) {
            try bundle.addRootErrorMessage(.{
                .msg = try bundle.addString("no entry point found"),
            });
        }
    }

    if (self.link_error_flags.missing_libc) {
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

    for (self.bin_file.miscErrors()) |link_err| {
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

    if (self.bin_file.options.module) |module| {
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

    assert(self.totalErrorCount() == bundle.root_list.items.len);

    const compile_log_text = if (self.bin_file.options.module) |m| m.compile_log_text.items else "";
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
        if (!std.mem.eql(u8, msg_a, msg_b)) return false;

        if (a.src_loc == .none and b.src_loc == .none) return true;
        if (a.src_loc == .none or b.src_loc == .none) return false;
        const src_a = eb.getSourceLocation(a.src_loc);
        const src_b = eb.getSourceLocation(b.src_loc);

        const src_path_a = eb.nullTerminatedString(src_a.src_path);
        const src_path_b = eb.nullTerminatedString(src_b.src_path);

        return std.mem.eql(u8, src_path_a, src_path_b) and
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
            .decl_name = try eb.addString(ip.stringToSlice(module_reference.decl)),
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
    const payload_index = file.zir.extra[@intFromEnum(Zir.ExtraIndex.compile_errors)];
    assert(payload_index != 0);
    const gpa = eb.gpa;

    const header = file.zir.extraData(Zir.Inst.CompileErrors, payload_index);
    const items_len = header.data.items_len;
    var extra_index = header.end;
    for (0..items_len) |_| {
        const item = file.zir.extraData(Zir.Inst.CompileErrors.Item, extra_index);
        extra_index = item.end;
        const err_span = blk: {
            if (item.data.node != 0) {
                break :blk Module.SrcLoc.nodeToSpan(&file.tree, item.data.node);
            }
            const token_starts = file.tree.tokens.items(.start);
            const start = token_starts[item.data.token] + item.data.byte_offset;
            const end = start + @as(u32, @intCast(file.tree.tokenSlice(item.data.token).len)) - item.data.byte_offset;
            break :blk Module.SrcLoc.Span{ .start = start, .end = end, .main = start };
        };
        const err_loc = std.zig.findLineColumn(file.source, err_span.main);

        {
            const msg = file.zir.nullTerminatedString(item.data.msg);
            const src_path = try file.fullPath(gpa);
            defer gpa.free(src_path);
            try eb.addRootErrorMessage(.{
                .msg = try eb.addString(msg),
                .src_loc = try eb.addSourceLocation(.{
                    .src_path = try eb.addString(src_path),
                    .span_start = err_span.start,
                    .span_main = err_span.main,
                    .span_end = err_span.end,
                    .line = @as(u32, @intCast(err_loc.line)),
                    .column = @as(u32, @intCast(err_loc.column)),
                    .source_line = try eb.addString(err_loc.source_line),
                }),
                .notes_len = item.data.notesLen(file.zir),
            });
        }

        if (item.data.notes != 0) {
            const notes_start = try eb.reserveNotes(item.data.notes);
            const block = file.zir.extraData(Zir.Inst.Block, item.data.notes);
            const body = file.zir.extra[block.end..][0..block.data.body_len];
            for (notes_start.., body) |note_i, body_elem| {
                const note_item = file.zir.extraData(Zir.Inst.CompileErrors.Item, body_elem);
                const msg = file.zir.nullTerminatedString(note_item.data.msg);
                const span = blk: {
                    if (note_item.data.node != 0) {
                        break :blk Module.SrcLoc.nodeToSpan(&file.tree, note_item.data.node);
                    }
                    const token_starts = file.tree.tokens.items(.start);
                    const start = token_starts[note_item.data.token] + note_item.data.byte_offset;
                    const end = start + @as(u32, @intCast(file.tree.tokenSlice(note_item.data.token).len)) - item.data.byte_offset;
                    break :blk Module.SrcLoc.Span{ .start = start, .end = end, .main = start };
                };
                const loc = std.zig.findLineColumn(file.source, span.main);
                const src_path = try file.fullPath(gpa);
                defer gpa.free(src_path);

                eb.extra.items[note_i] = @intFromEnum(try eb.addErrorMessage(.{
                    .msg = try eb.addString(msg),
                    .src_loc = try eb.addSourceLocation(.{
                        .src_path = try eb.addString(src_path),
                        .span_start = span.start,
                        .span_main = span.main,
                        .span_end = span.end,
                        .line = @as(u32, @intCast(loc.line)),
                        .column = @as(u32, @intCast(loc.column)),
                        .source_line = if (loc.eql(err_loc))
                            0
                        else
                            try eb.addString(loc.source_line),
                    }),
                    .notes_len = 0, // TODO rework this function to be recursive
                }));
            }
        }
    }
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

    var c_obj_prog_node = main_progress_node.start("Compile C Objects", comp.c_source_files.len);
    defer c_obj_prog_node.end();

    var win32_resource_prog_node = main_progress_node.start("Compile Win32 Resources", comp.rc_source_files.len);
    defer win32_resource_prog_node.end();

    comp.work_queue_wait_group.reset();
    defer comp.work_queue_wait_group.wait();

    {
        const astgen_frame = tracy.namedFrame("astgen");
        defer astgen_frame.end();

        comp.astgen_wait_group.reset();
        defer comp.astgen_wait_group.wait();

        // builtin.zig is handled specially for two reasons:
        // 1. to avoid race condition of zig processes truncating each other's builtin.zig files
        // 2. optimization; in the hot path it only incurs a stat() syscall, which happens
        //    in the `astgen_wait_group`.
        if (comp.bin_file.options.module) |mod| {
            if (mod.job_queued_update_builtin_zig) {
                mod.job_queued_update_builtin_zig = false;

                comp.astgen_wait_group.start();
                try comp.thread_pool.spawn(workerUpdateBuiltinZigFile, .{
                    comp, mod, &comp.astgen_wait_group,
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

    if (comp.bin_file.options.module) |mod| {
        try reportMultiModuleErrors(mod);
    }

    if (comp.bin_file.options.module) |mod| {
        mod.sema_prog_node = main_progress_node.start("Semantic Analysis", 0);
        mod.sema_prog_node.activate();
    }
    defer if (comp.bin_file.options.module) |mod| {
        mod.sema_prog_node.end();
        mod.sema_prog_node = undefined;
    };

    // In this main loop we give priority to non-anonymous Decls in the work queue, so
    // that they can establish references to anonymous Decls, setting alive=true in the
    // backend, preventing anonymous Decls from being prematurely destroyed.
    while (true) {
        if (comp.work_queue.readItem()) |work_item| {
            try processOneJob(comp, work_item, main_progress_node);
            continue;
        }
        if (comp.anon_work_queue.readItem()) |work_item| {
            try processOneJob(comp, work_item, main_progress_node);
            continue;
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
            const module = comp.bin_file.options.module.?;
            const decl = module.declPtr(decl_index);

            switch (decl.analysis) {
                .unreferenced => unreachable,
                .in_progress => unreachable,
                .outdated => unreachable,

                .file_failure,
                .sema_failure,
                .liveness_failure,
                .codegen_failure,
                .dependency_failure,
                .sema_failure_retryable,
                => return,

                .complete, .codegen_failure_retryable => {
                    const named_frame = tracy.namedFrame("codegen_decl");
                    defer named_frame.end();

                    assert(decl.has_tv);

                    if (decl.alive) {
                        try module.linkerUpdateDecl(decl_index);
                        return;
                    }

                    // Instead of sending this decl to the linker, we actually will delete it
                    // because we found out that it in fact was never referenced.
                    module.deleteUnusedDecl(decl_index);
                    return;
                },
            }
        },
        .codegen_func => |func| {
            const named_frame = tracy.namedFrame("codegen_func");
            defer named_frame.end();

            const module = comp.bin_file.options.module.?;
            module.ensureFuncBodyAnalyzed(func) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => return,
            };
        },
        .emit_h_decl => |decl_index| {
            const module = comp.bin_file.options.module.?;
            const decl = module.declPtr(decl_index);

            switch (decl.analysis) {
                .unreferenced => unreachable,
                .in_progress => unreachable,
                .outdated => unreachable,

                .file_failure,
                .sema_failure,
                .dependency_failure,
                .sema_failure_retryable,
                => return,

                // emit-h only requires semantic analysis of the Decl to be complete,
                // it does not depend on machine code generation to succeed.
                .liveness_failure, .codegen_failure, .codegen_failure_retryable, .complete => {
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
                        .module = module,
                        .error_msg = null,
                        .pass = .{ .decl = decl_index },
                        .is_naked_fn = false,
                        .fwd_decl = fwd_decl.toManaged(gpa),
                        .ctypes = .{},
                        .anon_decl_deps = .{},
                        .aligned_anon_decls = .{},
                    };
                    defer {
                        dg.ctypes.deinit(gpa);
                        dg.fwd_decl.deinit();
                    }

                    c_codegen.genHeader(&dg) catch |err| switch (err) {
                        error.AnalysisFail => {
                            try emit_h.failed_decls.put(gpa, decl_index, dg.error_msg.?);
                            return;
                        },
                        else => |e| return e,
                    };

                    fwd_decl.* = dg.fwd_decl.moveToUnmanaged();
                    fwd_decl.shrinkAndFree(gpa, fwd_decl.items.len);
                },
            }
        },
        .analyze_decl => |decl_index| {
            const module = comp.bin_file.options.module.?;
            module.ensureDeclAnalyzed(decl_index) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => return,
            };
            const decl = module.declPtr(decl_index);
            if (decl.kind == .@"test" and comp.bin_file.options.is_test) {
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
            const module = comp.bin_file.options.module.?;
            const decl = module.declPtr(decl_index);
            comp.bin_file.updateDeclLineNumber(module, decl_index) catch |err| {
                try module.failed_decls.ensureUnusedCapacity(gpa, 1);
                module.failed_decls.putAssumeCapacityNoClobber(decl_index, try Module.ErrorMsg.create(
                    gpa,
                    decl.srcLoc(module),
                    "unable to update line number: {s}",
                    .{@errorName(err)},
                ));
                decl.analysis = .codegen_failure_retryable;
            };
        },
        .analyze_mod => |pkg| {
            const named_frame = tracy.namedFrame("analyze_mod");
            defer named_frame.end();

            const module = comp.bin_file.options.module.?;
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
            const named_frame = tracy.namedFrame("windows_import_lib");
            defer named_frame.end();

            const link_lib = comp.bin_file.options.system_libs.keys()[index];
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

            libtsan.buildTsan(comp, prog_node) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(
                    .libtsan,
                    "unable to build TSAN library: {s}",
                    .{@errorName(err)},
                );
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

    const mod = comp.bin_file.options.module.?;
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
    mod: *Module,
    wg: *WaitGroup,
) void {
    defer wg.finish();

    mod.populateBuiltinFile() catch |err| {
        const dir_path: []const u8 = mod.zig_cache_artifact_directory.path orelse ".";

        comp.mutex.lock();
        defer comp.mutex.unlock();

        comp.setMiscFailure(.write_builtin_zig, "unable to write builtin.zig to {s}: {s}", .{
            dir_path, @errorName(err),
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
    const mod = comp.bin_file.options.module.?;
    const ip = &mod.intern_pool;
    const sub_file_path = ip.stringToSlice(embed_file.sub_file_path);
    var file = try embed_file.owner.root.openFile(sub_file_path, .{});
    defer file.close();

    const stat = try file.stat();

    const unchanged_metadata =
        stat.size == embed_file.stat.size and
        stat.mtime == embed_file.stat.mtime and
        stat.inode == embed_file.stat.inode;

    if (unchanged_metadata) return;

    @panic("TODO: handle embed file incremental update");
}

pub fn obtainCObjectCacheManifest(comp: *const Compilation) Cache.Manifest {
    var man = comp.cache_parent.obtain();

    // Only things that need to be added on top of the base hash, and only things
    // that apply both to @cImport and compiling C objects. No linking stuff here!
    // Also nothing that applies only to compiling .zig code.
    man.hash.add(comp.sanitize_c);
    man.hash.addListOfBytes(comp.clang_argv);
    man.hash.add(comp.bin_file.options.link_libcpp);

    // When libc_installation is null it means that Zig generated this dir list
    // based on the zig library directory alone. The zig lib directory file
    // path is purposefully either in the cache or not in the cache. The
    // decision should not be overridden here.
    if (comp.bin_file.options.libc_installation != null) {
        man.hash.addListOfBytes(comp.libc_include_dir_list);
    }

    return man;
}

pub fn obtainWin32ResourceCacheManifest(comp: *const Compilation) Cache.Manifest {
    var man = comp.cache_parent.obtain();

    man.hash.addListOfBytes(comp.rc_include_dir_list);

    return man;
}

pub const CImportResult = struct {
    out_zig_path: []u8,
    cache_hit: bool,
    errors: std.zig.ErrorBundle,

    pub fn deinit(result: *CImportResult, gpa: std.mem.Allocator) void {
        result.errors.deinit(gpa);
    }
};

/// Caller owns returned memory.
/// This API is currently coupled pretty tightly to stage1's needs; it will need to be reworked
/// a bit when we want to start using it from self-hosted.
pub fn cImport(comp: *Compilation, c_src: []const u8) !CImportResult {
    if (build_options.only_core_functionality) @panic("@cImport is not available in a zig2.c build");
    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    const cimport_zig_basename = "cimport.zig";

    var man = comp.obtainCObjectCacheManifest();
    defer man.deinit();

    man.hash.add(@as(u16, 0xb945)); // Random number to distinguish translate-c from compiling C objects
    man.hash.addBytes(c_src);
    man.hash.add(comp.c_frontend);

    // If the previous invocation resulted in clang errors, we will see a hit
    // here with 0 files in the manifest, in which case it is actually a miss.
    // We need to "unhit" in this case, to keep the digests matching.
    const prev_hash_state = man.hash.peekBin();
    const actual_hit = hit: {
        _ = try man.hit();
        if (man.files.items.len == 0) {
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

        try argv.append(@tagName(comp.c_frontend)); // argv[0] is program name, actual args start at [1]
        try comp.addTranslateCCArgs(arena, &argv, .c, out_dep_path);

        try argv.append(out_h_path);

        if (comp.verbose_cc) {
            dump_argv(argv.items);
        }
        var tree = switch (comp.c_frontend) {
            .aro => tree: {
                const translate_c = @import("aro_translate_c.zig");
                _ = translate_c;
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
        if (comp.whole_cache_manifest) |whole_cache_manifest| {
            comp.whole_cache_manifest_mutex.lock();
            defer comp.whole_cache_manifest_mutex.unlock();
            try whole_cache_manifest.addDepFilePost(zig_cache_tmp_dir, dep_basename);
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

    const out_zig_path = try comp.local_cache_directory.join(comp.arena.allocator(), &.{
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
    const mod = comp.bin_file.options.module.?;
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
    const mod = comp.bin_file.options.module.?;
    const gpa = mod.gpa;
    const src_loc = embed_file.src_loc;
    const ip = &mod.intern_pool;
    const err_msg = try Module.ErrorMsg.create(gpa, src_loc, "unable to load '{}{s}': {s}", .{
        embed_file.owner.root,
        ip.stringToSlice(embed_file.sub_file_path),
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
    if (comp.c_frontend == .aro) {
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

    var man = comp.obtainCObjectCacheManifest();
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
    const direct_o = comp.c_source_files.len == 1 and comp.bin_file.options.module == null and
        comp.bin_file.options.output_mode == .Obj and comp.bin_file.options.objects.len == 0;
    const o_basename_noext = if (direct_o)
        comp.bin_file.options.root_name
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
            try comp.addCCArgs(arena, &argv, ext, null);
            try argv.appendSlice(c_object.src.extra_flags);
            try argv.appendSlice(c_object.src.cache_exempt_flags);

            const out_obj_path = if (comp.bin_file.options.emit) |emit|
                try emit.directory.join(arena, &.{emit.sub_path})
            else
                "/dev/null";

            try argv.ensureUnusedCapacity(5);
            switch (comp.clang_preprocessor_mode) {
                .no => argv.appendSliceAssumeCapacity(&[_][]const u8{ "-c", "-o", out_obj_path }),
                .yes => argv.appendSliceAssumeCapacity(&[_][]const u8{ "-E", "-o", out_obj_path }),
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
        try comp.addCCArgs(arena, &argv, ext, out_dep_path);
        try argv.appendSlice(c_object.src.extra_flags);
        try argv.appendSlice(c_object.src.cache_exempt_flags);

        try argv.ensureUnusedCapacity(5);
        switch (comp.clang_preprocessor_mode) {
            .no => argv.appendSliceAssumeCapacity(&.{ "-c", "-o", out_obj_path }),
            .yes => argv.appendSliceAssumeCapacity(&.{ "-E", "-o", out_obj_path }),
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
            if (comp.whole_cache_manifest) |whole_cache_manifest| {
                comp.whole_cache_manifest_mutex.lock();
                defer comp.whole_cache_manifest_mutex.unlock();
                try whole_cache_manifest.addDepFilePost(zig_cache_tmp_dir, dep_basename);
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
    if (!build_options.have_llvm) {
        return comp.failWin32Resource(win32_resource, "clang not available: compiler built without LLVM extensions", .{});
    }
    const self_exe_path = comp.self_exe_path orelse
        return comp.failWin32Resource(win32_resource, "clang compilation disabled", .{});

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

        const res_basename = try std.fmt.allocPrint(arena, "{s}.res", .{src_basename});

        const digest = if (try man.hit()) man.final() else blk: {
            // The digest only depends on the .manifest file, so we can
            // get the digest now and write the .res directly to the cache
            const digest = man.final();

            const o_sub_path = try std.fs.path.join(arena, &.{ "o", &digest });
            var o_dir = try comp.local_cache_directory.handle.makeOpenPath(o_sub_path, .{});
            defer o_dir.close();

            var output_file = o_dir.createFile(res_basename, .{}) catch |err| {
                const output_file_path = try comp.local_cache_directory.join(arena, &.{ o_sub_path, res_basename });
                return comp.failWin32Resource(win32_resource, "failed to create output file '{s}': {s}", .{ output_file_path, @errorName(err) });
            };
            var output_file_closed = false;
            defer if (!output_file_closed) output_file.close();

            var diagnostics = resinator.errors.Diagnostics.init(arena);
            defer diagnostics.deinit();

            var output_buffered_stream = std.io.bufferedWriter(output_file.writer());

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

            resinator.compile.compile(arena, input, output_buffered_stream.writer(), .{
                .cwd = std.fs.cwd(),
                .diagnostics = &diagnostics,
                .ignore_include_env_var = true,
                .default_code_page = .utf8,
            }) catch |err| switch (err) {
                error.ParseError, error.CompileError => {
                    // Delete the output file on error
                    output_file.close();
                    output_file_closed = true;
                    // Failing to delete is not really a big deal, so swallow any errors
                    o_dir.deleteFile(res_basename) catch {
                        const output_file_path = try comp.local_cache_directory.join(arena, &.{ o_sub_path, res_basename });
                        log.warn("failed to delete '{s}': {s}", .{ output_file_path, @errorName(err) });
                    };
                    return comp.failWin32ResourceCompile(win32_resource, input, &diagnostics, null);
                },
                else => |e| return e,
            };

            try output_buffered_stream.flush();

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
        const rcpp_filename = try std.fmt.allocPrint(arena, "{s}.rcpp", .{rc_basename_noext});

        const out_rcpp_path = try comp.tmpFilePath(arena, rcpp_filename);
        var zig_cache_tmp_dir = try comp.local_cache_directory.handle.makeOpenPath("tmp", .{});
        defer zig_cache_tmp_dir.close();

        const res_filename = try std.fmt.allocPrint(arena, "{s}.res", .{rc_basename_noext});

        // We can't know the digest until we do the compilation,
        // so we need a temporary filename.
        const out_res_path = try comp.tmpFilePath(arena, res_filename);

        var options = options: {
            var resinator_args = try std.ArrayListUnmanaged([]const u8).initCapacity(comp.gpa, rc_src.extra_flags.len + 4);
            defer resinator_args.deinit(comp.gpa);

            resinator_args.appendAssumeCapacity(""); // dummy 'process name' arg
            resinator_args.appendSliceAssumeCapacity(rc_src.extra_flags);
            resinator_args.appendSliceAssumeCapacity(&.{ "--", out_rcpp_path, out_res_path });

            var cli_diagnostics = resinator.cli.Diagnostics.init(comp.gpa);
            defer cli_diagnostics.deinit();
            const options = resinator.cli.parse(comp.gpa, resinator_args.items, &cli_diagnostics) catch |err| switch (err) {
                error.ParseError => {
                    return comp.failWin32ResourceCli(win32_resource, &cli_diagnostics);
                },
                else => |e| return e,
            };
            break :options options;
        };
        defer options.deinit();

        // We never want to read the INCLUDE environment variable, so
        // unconditionally set `ignore_include_env_var` to true
        options.ignore_include_env_var = true;

        if (options.preprocess != .yes) {
            return comp.failWin32Resource(win32_resource, "the '{s}' option is not supported in this context", .{switch (options.preprocess) {
                .no => "/:no-preprocess",
                .only => "/p",
                .yes => unreachable,
            }});
        }

        var argv = std.ArrayList([]const u8).init(comp.gpa);
        defer argv.deinit();

        try argv.appendSlice(&[_][]const u8{ self_exe_path, "clang" });

        try resinator.preprocess.appendClangArgs(arena, &argv, options, .{
            .clang_target = null, // handled by addCCArgs
            .system_include_paths = &.{}, // handled by addCCArgs
            .needs_gnu_workaround = comp.getTarget().isGnu(),
            .nostdinc = false, // handled by addCCArgs
        });

        try argv.append(rc_src.src_path);
        try argv.appendSlice(&[_][]const u8{
            "-o",
            out_rcpp_path,
        });

        const out_dep_path = try std.fmt.allocPrint(arena, "{s}.d", .{out_rcpp_path});
        // Note: addCCArgs will implicitly add _DEBUG/NDEBUG depending on the optimization
        // mode. While these defines are not normally present when calling rc.exe directly,
        // them being defined matches the behavior of how MSVC calls rc.exe which is the more
        // relevant behavior in this case.
        try comp.addCCArgs(arena, &argv, .rc, out_dep_path);

        if (comp.verbose_cc) {
            dump_argv(argv.items);
        }

        if (std.process.can_spawn) {
            var child = std.ChildProcess.init(argv.items, arena);
            child.stdin_behavior = .Ignore;
            child.stdout_behavior = .Ignore;
            child.stderr_behavior = .Pipe;

            try child.spawn();

            const stderr_reader = child.stderr.?.reader();

            const stderr = try stderr_reader.readAllAlloc(arena, 10 * 1024 * 1024);

            const term = child.wait() catch |err| {
                return comp.failWin32Resource(win32_resource, "unable to spawn {s}: {s}", .{ argv.items[0], @errorName(err) });
            };

            switch (term) {
                .Exited => |code| {
                    if (code != 0) {
                        // TODO parse clang stderr and turn it into an error message
                        // and then call failCObjWithOwnedErrorMsg
                        log.err("clang preprocessor failed with stderr:\n{s}", .{stderr});
                        return comp.failWin32Resource(win32_resource, "clang preprocessor exited with code {d}", .{code});
                    }
                },
                else => {
                    log.err("clang preprocessor terminated with stderr:\n{s}", .{stderr});
                    return comp.failWin32Resource(win32_resource, "clang preprocessor terminated unexpectedly", .{});
                },
            }
        } else {
            const exit_code = try clangMain(arena, argv.items);
            if (exit_code != 0) {
                return comp.failWin32Resource(win32_resource, "clang preprocessor exited with code {d}", .{exit_code});
            }
        }

        const dep_basename = std.fs.path.basename(out_dep_path);
        // Add the files depended on to the cache system.
        try man.addDepFilePost(zig_cache_tmp_dir, dep_basename);
        if (comp.whole_cache_manifest) |whole_cache_manifest| {
            comp.whole_cache_manifest_mutex.lock();
            defer comp.whole_cache_manifest_mutex.unlock();
            try whole_cache_manifest.addDepFilePost(zig_cache_tmp_dir, dep_basename);
        }
        // Just to save disk space, we delete the file because it is never needed again.
        zig_cache_tmp_dir.deleteFile(dep_basename) catch |err| {
            log.warn("failed to delete '{s}': {s}", .{ out_dep_path, @errorName(err) });
        };

        const full_input = std.fs.cwd().readFileAlloc(arena, out_rcpp_path, std.math.maxInt(usize)) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => |e| {
                return comp.failWin32Resource(win32_resource, "failed to read preprocessed file '{s}': {s}", .{ out_rcpp_path, @errorName(e) });
            },
        };

        var mapping_results = try resinator.source_mapping.parseAndRemoveLineCommands(arena, full_input, full_input, .{ .initial_filename = rc_src.src_path });
        defer mapping_results.mappings.deinit(arena);

        const final_input = resinator.comments.removeComments(mapping_results.result, mapping_results.result, &mapping_results.mappings);

        var output_file = zig_cache_tmp_dir.createFile(out_res_path, .{}) catch |err| {
            return comp.failWin32Resource(win32_resource, "failed to create output file '{s}': {s}", .{ out_res_path, @errorName(err) });
        };
        var output_file_closed = false;
        defer if (!output_file_closed) output_file.close();

        var diagnostics = resinator.errors.Diagnostics.init(arena);
        defer diagnostics.deinit();

        var dependencies_list = std.ArrayList([]const u8).init(comp.gpa);
        defer {
            for (dependencies_list.items) |item| {
                comp.gpa.free(item);
            }
            dependencies_list.deinit();
        }

        var output_buffered_stream = std.io.bufferedWriter(output_file.writer());

        resinator.compile.compile(arena, final_input, output_buffered_stream.writer(), .{
            .cwd = std.fs.cwd(),
            .diagnostics = &diagnostics,
            .source_mappings = &mapping_results.mappings,
            .dependencies_list = &dependencies_list,
            .system_include_paths = comp.rc_include_dir_list,
            .ignore_include_env_var = true,
            // options
            .extra_include_paths = options.extra_include_paths.items,
            .default_language_id = options.default_language_id,
            .default_code_page = options.default_code_page orelse .windows1252,
            .verbose = options.verbose,
            .null_terminate_string_table_strings = options.null_terminate_string_table_strings,
            .max_string_literal_codepoints = options.max_string_literal_codepoints,
            .silent_duplicate_control_ids = options.silent_duplicate_control_ids,
            .warn_instead_of_error_on_invalid_code_page = options.warn_instead_of_error_on_invalid_code_page,
        }) catch |err| switch (err) {
            error.ParseError, error.CompileError => {
                // Delete the output file on error
                output_file.close();
                output_file_closed = true;
                // Failing to delete is not really a big deal, so swallow any errors
                zig_cache_tmp_dir.deleteFile(out_res_path) catch {
                    log.warn("failed to delete '{s}': {s}", .{ out_res_path, @errorName(err) });
                };
                return comp.failWin32ResourceCompile(win32_resource, final_input, &diagnostics, mapping_results.mappings);
            },
            else => |e| return e,
        };

        try output_buffered_stream.flush();

        for (dependencies_list.items) |dep_file_path| {
            try man.addFilePost(dep_file_path);
            if (comp.whole_cache_manifest) |whole_cache_manifest| {
                comp.whole_cache_manifest_mutex.lock();
                defer comp.whole_cache_manifest_mutex.unlock();
                try whole_cache_manifest.addFilePost(dep_file_path);
            }
        }

        // Rename into place.
        const digest = man.final();
        const o_sub_path = try std.fs.path.join(arena, &[_][]const u8{ "o", &digest });
        var o_dir = try comp.local_cache_directory.handle.makeOpenPath(o_sub_path, .{});
        defer o_dir.close();
        const tmp_basename = std.fs.path.basename(out_res_path);
        try std.fs.rename(zig_cache_tmp_dir, tmp_basename, o_dir, res_filename);
        const tmp_rcpp_basename = std.fs.path.basename(out_rcpp_path);
        try std.fs.rename(zig_cache_tmp_dir, tmp_rcpp_basename, o_dir, rcpp_filename);
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
) !void {
    try argv.appendSlice(&[_][]const u8{ "-x", "c" });
    try comp.addCCArgs(arena, argv, ext, out_dep_path);
    // This gives us access to preprocessing entities, presumably at the cost of performance.
    try argv.appendSlice(&[_][]const u8{ "-Xclang", "-detailed-preprocessing-record" });
}

/// Add common C compiler args between translate-c and C object compilation.
pub fn addCCArgs(
    comp: *const Compilation,
    arena: Allocator,
    argv: *std.ArrayList([]const u8),
    ext: FileExt,
    out_dep_path: ?[]const u8,
) !void {
    const target = comp.getTarget();

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

    if (comp.bin_file.options.function_sections) {
        try argv.append("-ffunction-sections");
    }

    if (comp.bin_file.options.data_sections) {
        try argv.append("-fdata-sections");
    }

    if (comp.bin_file.options.no_builtin) {
        try argv.append("-fno-builtin");
    }

    if (comp.bin_file.options.link_libcpp) {
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

        if (comp.bin_file.options.single_threaded) {
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

    if (comp.bin_file.options.link_libunwind) {
        const libunwind_include_path = try std.fs.path.join(arena, &[_][]const u8{
            comp.zig_lib_directory.path.?, "libunwind", "include",
        });

        try argv.append("-isystem");
        try argv.append(libunwind_include_path);
    }

    if (comp.bin_file.options.link_libc and target.isGnuLibC()) {
        const target_version = target.os.version_range.linux.glibc;
        const glibc_minor_define = try std.fmt.allocPrint(arena, "-D__GLIBC_MINOR__={d}", .{
            target_version.minor,
        });
        try argv.append(glibc_minor_define);
    }

    const llvm_triple = try @import("codegen/llvm.zig").targetTriple(arena, target);
    try argv.appendSlice(&[_][]const u8{ "-target", llvm_triple });

    if (target.os.tag == .windows) switch (ext) {
        .c, .cpp, .m, .mm, .h, .cu, .rc, .assembly, .assembly_with_cpp => {
            const minver: u16 = @truncate(@intFromEnum(target.os.getVersionRange().windows.min) >> 16);
            try argv.append(try std.fmt.allocPrint(argv.allocator, "-D_WIN32_WINNT=0x{x:0>4}", .{minver}));
        },
        else => {},
    };

    switch (ext) {
        .c, .cpp, .m, .mm, .h, .cu, .rc => {
            try argv.appendSlice(&[_][]const u8{
                "-nostdinc",
                "-fno-spell-checking",
            });
            if (comp.bin_file.options.lto) {
                try argv.append("-flto");
            }

            if (ext == .mm) {
                try argv.append("-ObjC++");
            }

            for (comp.libc_framework_dir_list) |framework_dir| {
                try argv.appendSlice(&.{ "-iframework", framework_dir });
            }

            for (comp.bin_file.options.framework_dirs) |framework_dir| {
                try argv.appendSlice(&.{ "-F", framework_dir });
            }

            // According to Rich Felker libc headers are supposed to go before C language headers.
            // However as noted by @dimenus, appending libc headers before c_headers breaks intrinsics
            // and other compiler specific items.
            const c_headers_dir = try std.fs.path.join(arena, &[_][]const u8{ comp.zig_lib_directory.path.?, "include" });
            try argv.append("-isystem");
            try argv.append(c_headers_dir);

            if (ext == .rc) {
                for (comp.rc_include_dir_list) |include_dir| {
                    try argv.append("-isystem");
                    try argv.append(include_dir);
                }
            } else {
                for (comp.libc_include_dir_list) |include_dir| {
                    try argv.append("-isystem");
                    try argv.append(include_dir);
                }
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
            const mcmodel = comp.bin_file.options.machine_code_model;
            if (mcmodel != .default) {
                try argv.append(try std.fmt.allocPrint(arena, "-mcmodel={s}", .{@tagName(mcmodel)}));
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

            if (comp.sanitize_c and !comp.bin_file.options.tsan) {
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
            } else if (comp.sanitize_c and comp.bin_file.options.tsan) {
                try argv.append("-fsanitize=undefined,thread");
                try argv.append("-fsanitize-trap=undefined");
                try argv.append("-fno-sanitize=function");
            } else if (!comp.sanitize_c and comp.bin_file.options.tsan) {
                try argv.append("-fsanitize=thread");
            }

            if (comp.bin_file.options.red_zone) {
                try argv.append("-mred-zone");
            } else if (target_util.hasRedZone(target)) {
                try argv.append("-mno-red-zone");
            }

            if (comp.bin_file.options.omit_frame_pointer) {
                try argv.append("-fomit-frame-pointer");
            } else {
                try argv.append("-fno-omit-frame-pointer");
            }

            const ssp_buf_size = comp.bin_file.options.stack_protector;
            if (ssp_buf_size != 0) {
                try argv.appendSlice(&[_][]const u8{
                    "-fstack-protector-strong",
                    "--param",
                    try std.fmt.allocPrint(arena, "ssp-buffer-size={d}", .{ssp_buf_size}),
                });
            } else {
                try argv.append("-fno-stack-protector");
            }

            switch (comp.bin_file.options.optimize_mode) {
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

            if (target_util.supports_fpic(target) and comp.bin_file.options.pic) {
                try argv.append("-fPIC");
            }

            if (comp.unwind_tables) {
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

    if (!comp.bin_file.options.strip) {
        switch (target.ofmt) {
            .coff => {
                // -g is required here because -gcodeview doesn't trigger debug info
                // generation, it only changes the type of information generated.
                try argv.appendSlice(&.{ "-g", "-gcodeview" });
            },
            .elf, .macho => {
                try argv.append("-gdwarf-4");
                if (comp.bin_file.options.dwarf_format) |f| switch (f) {
                    .@"32" => try argv.append("-gdwarf32"),
                    .@"64" => try argv.append("-gdwarf64"),
                };
            },
            else => try argv.append("-g"),
        }
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

    try argv.appendSlice(comp.clang_argv);
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

/// The include directories used when preprocessing .rc files are separate from the
/// target. Which include directories are used is determined by `options.rc_includes`.
///
/// Note: It should be okay that the include directories used when compiling .rc
/// files differ from the include directories used when compiling the main
/// binary, since the .res format is not dependent on anything ABI-related. The
/// only relevant differences would be things like `#define` constants being
/// different in the MinGW headers vs the MSVC headers, but any such
/// differences would likely be a MinGW bug.
fn detectWin32ResourceIncludeDirs(arena: Allocator, options: InitOptions) !LibCDirs {
    // Set the includes to .none here when there are no rc files to compile
    var includes = if (options.rc_source_files.len > 0) options.rc_includes else .none;
    if (builtin.target.os.tag != .windows) {
        switch (includes) {
            // MSVC can't be found when the host isn't Windows, so short-circuit.
            .msvc => return error.WindowsSdkNotFound,
            // Skip straight to gnu since we won't be able to detect MSVC on non-Windows hosts.
            .any => includes = .gnu,
            .none, .gnu => {},
        }
    }
    while (true) {
        switch (includes) {
            .any, .msvc => return detectLibCIncludeDirs(
                arena,
                options.zig_lib_directory.path.?,
                .{
                    .cpu = options.target.cpu,
                    .os = options.target.os,
                    .abi = .msvc,
                    .ofmt = options.target.ofmt,
                },
                options.is_native_abi,
                // The .rc preprocessor will need to know the libc include dirs even if we
                // are not linking libc, so force 'link_libc' to true
                true,
                options.libc_installation,
            ) catch |err| {
                if (includes == .any) {
                    // fall back to mingw
                    includes = .gnu;
                    continue;
                }
                return err;
            },
            .gnu => return detectLibCFromBuilding(arena, options.zig_lib_directory.path.?, .{
                .cpu = options.target.cpu,
                .os = options.target.os,
                .abi = .gnu,
                .ofmt = options.target.ofmt,
            }),
            .none => return LibCDirs{
                .libc_include_dir_list = &[0][]u8{},
                .libc_installation = null,
                .libc_framework_dir_list = &.{},
                .sysroot = null,
                .darwin_sdk_layout = null,
            },
        }
    }
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

fn failWin32ResourceCli(
    comp: *Compilation,
    win32_resource: *Win32Resource,
    diagnostics: *resinator.cli.Diagnostics,
) SemaError {
    @setCold(true);

    var bundle: ErrorBundle.Wip = undefined;
    try bundle.init(comp.gpa);
    errdefer bundle.deinit();

    try bundle.addRootErrorMessage(.{
        .msg = try bundle.addString("invalid command line option(s)"),
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

    var cur_err: ?ErrorBundle.ErrorMessage = null;
    var cur_notes: std.ArrayListUnmanaged(ErrorBundle.ErrorMessage) = .{};
    defer cur_notes.deinit(comp.gpa);
    for (diagnostics.errors.items) |err_details| {
        switch (err_details.type) {
            .err => {
                if (cur_err) |err| {
                    try win32ResourceFlushErrorMessage(&bundle, err, cur_notes.items);
                }
                cur_err = .{
                    .msg = try bundle.addString(err_details.msg.items),
                };
                cur_notes.clearRetainingCapacity();
            },
            .warning => cur_err = null,
            .note => {
                if (cur_err == null) continue;
                cur_err.?.notes_len += 1;
                try cur_notes.append(comp.gpa, .{
                    .msg = try bundle.addString(err_details.msg.items),
                });
            },
        }
    }
    if (cur_err) |err| {
        try win32ResourceFlushErrorMessage(&bundle, err, cur_notes.items);
    }

    const finished_bundle = try bundle.toOwnedBundle("");
    return comp.failWin32ResourceWithOwnedBundle(win32_resource, finished_bundle);
}

fn failWin32ResourceCompile(
    comp: *Compilation,
    win32_resource: *Win32Resource,
    source: []const u8,
    diagnostics: *resinator.errors.Diagnostics,
    opt_mappings: ?resinator.source_mapping.SourceMappings,
) SemaError {
    @setCold(true);

    var bundle: ErrorBundle.Wip = undefined;
    try bundle.init(comp.gpa);
    errdefer bundle.deinit();

    var msg_buf: std.ArrayListUnmanaged(u8) = .{};
    defer msg_buf.deinit(comp.gpa);
    var cur_err: ?ErrorBundle.ErrorMessage = null;
    var cur_notes: std.ArrayListUnmanaged(ErrorBundle.ErrorMessage) = .{};
    defer cur_notes.deinit(comp.gpa);
    for (diagnostics.errors.items) |err_details| {
        switch (err_details.type) {
            .hint => continue,
            // Clear the current error so that notes don't bleed into unassociated errors
            .warning => {
                cur_err = null;
                continue;
            },
            .note => if (cur_err == null) continue,
            .err => {},
        }
        const err_line, const err_filename = blk: {
            if (opt_mappings) |mappings| {
                const corresponding_span = mappings.get(err_details.token.line_number);
                const corresponding_file = mappings.files.get(corresponding_span.filename_offset);
                const err_line = corresponding_span.start_line;
                break :blk .{ err_line, corresponding_file };
            } else {
                break :blk .{ err_details.token.line_number, "<generated rc>" };
            }
        };

        const source_line_start = err_details.token.getLineStart(source);
        const column = err_details.token.calculateColumn(source, 1, source_line_start);

        msg_buf.clearRetainingCapacity();
        try err_details.render(msg_buf.writer(comp.gpa), source, diagnostics.strings.items);

        const src_loc = src_loc: {
            var src_loc: ErrorBundle.SourceLocation = .{
                .src_path = try bundle.addString(err_filename),
                .line = @intCast(err_line - 1), // 1-based -> 0-based
                .column = @intCast(column),
                .span_start = 0,
                .span_main = 0,
                .span_end = 0,
            };
            if (err_details.print_source_line) {
                const source_line = err_details.token.getLine(source, source_line_start);
                const visual_info = err_details.visualTokenInfo(source_line_start, source_line_start + source_line.len);
                src_loc.span_start = @intCast(visual_info.point_offset - visual_info.before_len);
                src_loc.span_main = @intCast(visual_info.point_offset);
                src_loc.span_end = @intCast(visual_info.point_offset + 1 + visual_info.after_len);
                src_loc.source_line = try bundle.addString(source_line);
            }
            break :src_loc try bundle.addSourceLocation(src_loc);
        };

        switch (err_details.type) {
            .err => {
                if (cur_err) |err| {
                    try win32ResourceFlushErrorMessage(&bundle, err, cur_notes.items);
                }
                cur_err = .{
                    .msg = try bundle.addString(msg_buf.items),
                    .src_loc = src_loc,
                };
                cur_notes.clearRetainingCapacity();
            },
            .note => {
                cur_err.?.notes_len += 1;
                try cur_notes.append(comp.gpa, .{
                    .msg = try bundle.addString(msg_buf.items),
                    .src_loc = src_loc,
                });
            },
            .warning, .hint => unreachable,
        }
    }
    if (cur_err) |err| {
        try win32ResourceFlushErrorMessage(&bundle, err, cur_notes.items);
    }

    const finished_bundle = try bundle.toOwnedBundle("");
    return comp.failWin32ResourceWithOwnedBundle(win32_resource, finished_bundle);
}

fn win32ResourceFlushErrorMessage(wip: *ErrorBundle.Wip, msg: ErrorBundle.ErrorMessage, notes: []const ErrorBundle.ErrorMessage) !void {
    try wip.addRootErrorMessage(msg);
    const notes_start = try wip.reserveNotes(@intCast(notes.len));
    for (notes_start.., notes) |i, note| {
        wip.extra.items[i] = @intFromEnum(wip.addErrorMessageAssumeCapacity(note));
    }
}

pub const FileExt = enum {
    c,
    cpp,
    cu,
    h,
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
            .c, .cpp, .h, .m, .mm, .cu => true,

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

const LibCDirs = struct {
    libc_include_dir_list: []const []const u8,
    libc_installation: ?*const LibCInstallation,
    libc_framework_dir_list: []const []const u8,
    sysroot: ?[]const u8,
    darwin_sdk_layout: ?link.DarwinSdkLayout,
};

fn getZigShippedLibCIncludeDirsDarwin(arena: Allocator, zig_lib_dir: []const u8) !LibCDirs {
    const s = std.fs.path.sep_str;
    const list = try arena.alloc([]const u8, 1);
    list[0] = try std.fmt.allocPrint(
        arena,
        "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "any-macos-any",
        .{zig_lib_dir},
    );
    return LibCDirs{
        .libc_include_dir_list = list,
        .libc_installation = null,
        .libc_framework_dir_list = &.{},
        .sysroot = null,
        .darwin_sdk_layout = .vendored,
    };
}

pub fn detectLibCIncludeDirs(
    arena: Allocator,
    zig_lib_dir: []const u8,
    target: Target,
    is_native_abi: bool,
    link_libc: bool,
    libc_installation: ?*const LibCInstallation,
) !LibCDirs {
    if (!link_libc) {
        return LibCDirs{
            .libc_include_dir_list = &[0][]u8{},
            .libc_installation = null,
            .libc_framework_dir_list = &.{},
            .sysroot = null,
            .darwin_sdk_layout = null,
        };
    }

    if (libc_installation) |lci| {
        return detectLibCFromLibCInstallation(arena, target, lci);
    }

    // If linking system libraries and targeting the native abi, default to
    // using the system libc installation.
    if (is_native_abi and !target.isMinGW()) {
        const libc = try arena.create(LibCInstallation);
        libc.* = LibCInstallation.findNative(.{ .allocator = arena, .target = target }) catch |err| switch (err) {
            error.CCompilerExitCode,
            error.CCompilerCrashed,
            error.CCompilerCannotFindHeaders,
            error.UnableToSpawnCCompiler,
            error.DarwinSdkNotFound,
            => |e| {
                // We tried to integrate with the native system C compiler,
                // however, it is not installed. So we must rely on our bundled
                // libc files.
                if (target_util.canBuildLibC(target)) {
                    return detectLibCFromBuilding(arena, zig_lib_dir, target);
                }
                return e;
            },
            else => |e| return e,
        };
        return detectLibCFromLibCInstallation(arena, target, libc);
    }

    // If not linking system libraries, build and provide our own libc by
    // default if possible.
    if (target_util.canBuildLibC(target)) {
        return detectLibCFromBuilding(arena, zig_lib_dir, target);
    }

    // If zig can't build the libc for the target and we are targeting the
    // native abi, fall back to using the system libc installation.
    // On windows, instead of the native (mingw) abi, we want to check
    // for the MSVC abi as a fallback.
    const use_system_abi = if (builtin.target.os.tag == .windows)
        target.abi == .msvc
    else
        is_native_abi;

    if (use_system_abi) {
        const libc = try arena.create(LibCInstallation);
        libc.* = try LibCInstallation.findNative(.{ .allocator = arena, .verbose = true, .target = target });
        return detectLibCFromLibCInstallation(arena, target, libc);
    }

    return LibCDirs{
        .libc_include_dir_list = &[0][]u8{},
        .libc_installation = null,
        .libc_framework_dir_list = &.{},
        .sysroot = null,
        .darwin_sdk_layout = null,
    };
}

fn detectLibCFromLibCInstallation(arena: Allocator, target: Target, lci: *const LibCInstallation) !LibCDirs {
    var list = try std.ArrayList([]const u8).initCapacity(arena, 5);
    var framework_list = std.ArrayList([]const u8).init(arena);

    list.appendAssumeCapacity(lci.include_dir.?);

    const is_redundant = mem.eql(u8, lci.sys_include_dir.?, lci.include_dir.?);
    if (!is_redundant) list.appendAssumeCapacity(lci.sys_include_dir.?);

    if (target.os.tag == .windows) {
        if (std.fs.path.dirname(lci.sys_include_dir.?)) |sys_include_dir_parent| {
            // This include path will only exist when the optional "Desktop development with C++"
            // is installed. It contains headers, .rc files, and resources. It is especially
            // necessary when working with Windows resources.
            const atlmfc_dir = try std.fs.path.join(arena, &[_][]const u8{ sys_include_dir_parent, "atlmfc", "include" });
            list.appendAssumeCapacity(atlmfc_dir);
        }
        if (std.fs.path.dirname(lci.include_dir.?)) |include_dir_parent| {
            const um_dir = try std.fs.path.join(arena, &[_][]const u8{ include_dir_parent, "um" });
            list.appendAssumeCapacity(um_dir);

            const shared_dir = try std.fs.path.join(arena, &[_][]const u8{ include_dir_parent, "shared" });
            list.appendAssumeCapacity(shared_dir);
        }
    }
    if (target.os.tag == .haiku) {
        const include_dir_path = lci.include_dir orelse return error.LibCInstallationNotAvailable;
        const os_dir = try std.fs.path.join(arena, &[_][]const u8{ include_dir_path, "os" });
        list.appendAssumeCapacity(os_dir);
        // Errors.h
        const os_support_dir = try std.fs.path.join(arena, &[_][]const u8{ include_dir_path, "os/support" });
        list.appendAssumeCapacity(os_support_dir);

        const config_dir = try std.fs.path.join(arena, &[_][]const u8{ include_dir_path, "config" });
        list.appendAssumeCapacity(config_dir);
    }

    var sysroot: ?[]const u8 = null;

    if (target.isDarwin()) d: {
        const down1 = std.fs.path.dirname(lci.sys_include_dir.?) orelse break :d;
        const down2 = std.fs.path.dirname(down1) orelse break :d;
        try framework_list.append(try std.fs.path.join(arena, &.{ down2, "System", "Library", "Frameworks" }));
        sysroot = down2;
    }

    return LibCDirs{
        .libc_include_dir_list = list.items,
        .libc_installation = lci,
        .libc_framework_dir_list = framework_list.items,
        .sysroot = sysroot,
        .darwin_sdk_layout = if (sysroot == null) null else .sdk,
    };
}

fn detectLibCFromBuilding(
    arena: Allocator,
    zig_lib_dir: []const u8,
    target: std.Target,
) !LibCDirs {
    if (target.isDarwin())
        return getZigShippedLibCIncludeDirsDarwin(arena, zig_lib_dir);

    const generic_name = target_util.libCGenericName(target);
    // Some architectures are handled by the same set of headers.
    const arch_name = if (target.abi.isMusl())
        musl.archNameHeaders(target.cpu.arch)
    else if (target.cpu.arch.isThumb())
        // ARM headers are valid for Thumb too.
        switch (target.cpu.arch) {
            .thumb => "arm",
            .thumbeb => "armeb",
            else => unreachable,
        }
    else
        @tagName(target.cpu.arch);
    const os_name = @tagName(target.os.tag);
    // Musl's headers are ABI-agnostic and so they all have the "musl" ABI name.
    const abi_name = if (target.abi.isMusl()) "musl" else @tagName(target.abi);
    const s = std.fs.path.sep_str;
    const arch_include_dir = try std.fmt.allocPrint(
        arena,
        "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{s}-{s}-{s}",
        .{ zig_lib_dir, arch_name, os_name, abi_name },
    );
    const generic_include_dir = try std.fmt.allocPrint(
        arena,
        "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "generic-{s}",
        .{ zig_lib_dir, generic_name },
    );
    const generic_arch_name = target_util.osArchName(target);
    const arch_os_include_dir = try std.fmt.allocPrint(
        arena,
        "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{s}-{s}-any",
        .{ zig_lib_dir, generic_arch_name, os_name },
    );
    const generic_os_include_dir = try std.fmt.allocPrint(
        arena,
        "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "any-{s}-any",
        .{ zig_lib_dir, os_name },
    );

    const list = try arena.alloc([]const u8, 4);
    list[0] = arch_include_dir;
    list[1] = generic_include_dir;
    list[2] = arch_os_include_dir;
    list[3] = generic_os_include_dir;

    return LibCDirs{
        .libc_include_dir_list = list,
        .libc_installation = null,
        .libc_framework_dir_list = &.{},
        .sysroot = null,
        .darwin_sdk_layout = .vendored,
    };
}

pub fn get_libc_crt_file(comp: *Compilation, arena: Allocator, basename: []const u8) ![]const u8 {
    if (comp.wantBuildGLibCFromSource() or
        comp.wantBuildMuslFromSource() or
        comp.wantBuildMinGWFromSource() or
        comp.wantBuildWasiLibcFromSource())
    {
        return comp.crt_files.get(basename).?.full_object_path;
    }
    const lci = comp.bin_file.options.libc_installation orelse return error.LibCInstallationNotAvailable;
    const crt_dir_path = lci.crt_dir orelse return error.LibCInstallationMissingCRTDir;
    const full_path = try std.fs.path.join(arena, &[_][]const u8{ crt_dir_path, basename });
    return full_path;
}

fn wantBuildLibCFromSource(comp: Compilation) bool {
    const is_exe_or_dyn_lib = switch (comp.bin_file.options.output_mode) {
        .Obj => false,
        .Lib => comp.bin_file.options.link_mode == .Dynamic,
        .Exe => true,
    };
    return comp.bin_file.options.link_libc and is_exe_or_dyn_lib and
        comp.bin_file.options.libc_installation == null and
        comp.bin_file.options.target.ofmt != .c;
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
    const is_exe_or_dyn_lib = switch (comp.bin_file.options.output_mode) {
        .Obj => false,
        .Lib => comp.bin_file.options.link_mode == .Dynamic,
        .Exe => true,
    };
    return is_exe_or_dyn_lib and comp.bin_file.options.link_libunwind and
        comp.bin_file.options.target.ofmt != .c;
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

            var split = std.mem.splitSequence(u8, line, "error: ");
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
    return switch (zigBackend(target, use_llvm)) {
        .stage2_llvm => true,
        .stage2_x86_64 => if (target.ofmt == .elf) true else build_options.have_llvm,
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
    return switch (zigBackend(target, use_llvm)) {
        .stage2_llvm => true,
        .stage2_x86_64 => if (target.ofmt == .elf) true else build_options.have_llvm,
        else => build_options.have_llvm,
    };
}

pub fn getZigBackend(comp: Compilation) std.builtin.CompilerBackend {
    const target = comp.bin_file.options.target;
    return zigBackend(target, comp.bin_file.options.use_llvm);
}

fn zigBackend(target: std.Target, use_llvm: bool) std.builtin.CompilerBackend {
    if (use_llvm) return .stage2_llvm;
    if (target.ofmt == .c) return .stage2_c;
    return switch (target.cpu.arch) {
        .wasm32, .wasm64 => std.builtin.CompilerBackend.stage2_wasm,
        .arm, .armeb, .thumb, .thumbeb => .stage2_arm,
        .x86_64 => .stage2_x86_64,
        .x86 => .stage2_x86,
        .aarch64, .aarch64_be, .aarch64_32 => .stage2_aarch64,
        .riscv64 => .stage2_riscv64,
        .sparc64 => .stage2_sparc64,
        .spirv64 => .stage2_spirv64,
        else => .other,
    };
}

pub fn generateBuiltinZigSource(comp: *Compilation, allocator: Allocator) Allocator.Error![:0]u8 {
    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const target = comp.getTarget();
    const generic_arch_name = target.cpu.arch.genericName();
    const zig_backend = comp.getZigBackend();

    @setEvalBranchQuota(4000);
    try buffer.writer().print(
        \\const std = @import("std");
        \\/// Zig version. When writing code that supports multiple versions of Zig, prefer
        \\/// feature detection (i.e. with `@hasDecl` or `@hasField`) over version checks.
        \\pub const zig_version = std.SemanticVersion.parse(zig_version_string) catch unreachable;
        \\pub const zig_version_string = "{s}";
        \\pub const zig_backend = std.builtin.CompilerBackend.{};
        \\
        \\pub const output_mode = std.builtin.OutputMode.{};
        \\pub const link_mode = std.builtin.LinkMode.{};
        \\pub const is_test = {};
        \\pub const single_threaded = {};
        \\pub const abi = std.Target.Abi.{};
        \\pub const cpu: std.Target.Cpu = .{{
        \\    .arch = .{},
        \\    .model = &std.Target.{}.cpu.{},
        \\    .features = std.Target.{}.featureSet(&[_]std.Target.{}.Feature{{
        \\
    , .{
        build_options.version,
        std.zig.fmtId(@tagName(zig_backend)),
        std.zig.fmtId(@tagName(comp.bin_file.options.output_mode)),
        std.zig.fmtId(@tagName(comp.bin_file.options.link_mode)),
        comp.bin_file.options.is_test,
        comp.bin_file.options.single_threaded,
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
            try buffer.writer().print("        .{},\n", .{std.zig.fmtId(feature.name)});
        }
    }

    try buffer.writer().print(
        \\    }}),
        \\}};
        \\pub const os = std.Target.Os{{
        \\    .tag = .{},
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
            \\        .min = {s},
            \\        .max = {s},
            \\    }}}},
            \\
        ,
            .{ windows.min, windows.max },
        ),
    }
    try buffer.appendSlice("};\n");

    // This is so that compiler_rt and libc.zig libraries know whether they
    // will eventually be linked with libc. They make different decisions
    // about what to export depending on whether another libc will be linked
    // in. For example, compiler_rt will not export the __chkstk symbol if it
    // knows libc will provide it, and likewise c.zig will not export memcpy.
    const link_libc = comp.bin_file.options.link_libc or
        (comp.bin_file.options.skip_linker_dependencies and comp.bin_file.options.parent_compilation_link_libc);

    try buffer.writer().print(
        \\pub const target = std.Target{{
        \\    .cpu = cpu,
        \\    .os = os,
        \\    .abi = abi,
        \\    .ofmt = object_format,
        \\}};
        \\pub const object_format = std.Target.ObjectFormat.{};
        \\pub const mode = std.builtin.OptimizeMode.{};
        \\pub const link_libc = {};
        \\pub const link_libcpp = {};
        \\pub const have_error_return_tracing = {};
        \\pub const valgrind_support = {};
        \\pub const sanitize_thread = {};
        \\pub const position_independent_code = {};
        \\pub const position_independent_executable = {};
        \\pub const strip_debug_info = {};
        \\pub const code_model = std.builtin.CodeModel.{};
        \\pub const omit_frame_pointer = {};
        \\
    , .{
        std.zig.fmtId(@tagName(target.ofmt)),
        std.zig.fmtId(@tagName(comp.bin_file.options.optimize_mode)),
        link_libc,
        comp.bin_file.options.link_libcpp,
        comp.bin_file.options.error_return_tracing,
        comp.bin_file.options.valgrind,
        comp.bin_file.options.tsan,
        comp.bin_file.options.pic,
        comp.bin_file.options.pie,
        comp.bin_file.options.strip,
        std.zig.fmtId(@tagName(comp.bin_file.options.machine_code_model)),
        comp.bin_file.options.omit_frame_pointer,
    });

    if (target.os.tag == .wasi) {
        const wasi_exec_model_fmt = std.zig.fmtId(@tagName(comp.bin_file.options.wasi_exec_model));
        try buffer.writer().print(
            \\pub const wasi_exec_model = std.builtin.WasiExecModel.{};
            \\
        , .{wasi_exec_model_fmt});
    }

    if (comp.bin_file.options.is_test) {
        try buffer.appendSlice(
            \\pub var test_functions: []const std.builtin.TestFn = undefined; // overwritten later
            \\
        );
        if (comp.test_evented_io) {
            try buffer.appendSlice(
                \\pub const test_io_mode = .evented;
                \\
            );
        } else {
            try buffer.appendSlice(
                \\pub const test_io_mode = .blocking;
                \\
            );
        }
    }

    return buffer.toOwnedSliceSentinel(0);
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

    assert(output_mode != .Exe);

    var main_mod: Package.Module = .{
        .root = .{ .root_dir = comp.zig_lib_directory },
        .root_src_path = src_basename,
        .fully_qualified_name = "root",
    };
    const root_name = src_basename[0 .. src_basename.len - std.fs.path.extension(src_basename).len];
    const target = comp.getTarget();
    const bin_basename = try std.zig.binNameAlloc(comp.gpa, .{
        .root_name = root_name,
        .target = target,
        .output_mode = output_mode,
    });
    defer comp.gpa.free(bin_basename);

    const emit_bin = Compilation.EmitLoc{
        .directory = null, // Put it in the cache directory.
        .basename = bin_basename,
    };
    const sub_compilation = try Compilation.create(comp.gpa, .{
        .global_cache_directory = comp.global_cache_directory,
        .local_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .cache_mode = .whole,
        .target = target,
        .root_name = root_name,
        .main_mod = &main_mod,
        .output_mode = output_mode,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.bin_file.options.libc_installation,
        .emit_bin = emit_bin,
        .optimize_mode = comp.compilerRtOptMode(),
        .link_mode = .Static,
        .function_sections = true,
        .data_sections = true,
        .no_builtin = true,
        .want_sanitize_c = false,
        .want_stack_check = false,
        .want_stack_protector = 0,
        .want_red_zone = comp.bin_file.options.red_zone,
        .omit_frame_pointer = comp.bin_file.options.omit_frame_pointer,
        .want_valgrind = false,
        .want_tsan = false,
        .want_unwind_tables = comp.bin_file.options.eh_frame_hdr,
        .want_pic = comp.bin_file.options.pic,
        .want_pie = null,
        .emit_h = null,
        .strip = comp.compilerRtStrip(),
        .is_native_os = comp.bin_file.options.is_native_os,
        .is_native_abi = comp.bin_file.options.is_native_abi,
        .self_exe_path = comp.self_exe_path,
        .verbose_cc = comp.verbose_cc,
        .verbose_link = comp.bin_file.options.verbose_link,
        .verbose_air = comp.verbose_air,
        .verbose_intern_pool = comp.verbose_intern_pool,
        .verbose_generic_instances = comp.verbose_intern_pool,
        .verbose_llvm_ir = comp.verbose_llvm_ir,
        .verbose_llvm_bc = comp.verbose_llvm_bc,
        .verbose_cimport = comp.verbose_cimport,
        .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
        .clang_passthrough_mode = comp.clang_passthrough_mode,
        .skip_linker_dependencies = true,
        .parent_compilation_link_libc = comp.bin_file.options.link_libc,
        .want_structured_cfg = comp.bin_file.options.want_structured_cfg,
    });
    defer sub_compilation.destroy();

    try comp.updateSubCompilation(sub_compilation, misc_task_tag, prog_node);

    assert(out.* == null);
    out.* = Compilation.CRTFile{
        .full_object_path = try sub_compilation.bin_file.options.emit.?.directory.join(comp.gpa, &[_][]const u8{
            sub_compilation.bin_file.options.emit.?.sub_path,
        }),
        .lock = sub_compilation.bin_file.toOwnedLock(),
    };
}

pub fn build_crt_file(
    comp: *Compilation,
    root_name: []const u8,
    output_mode: std.builtin.OutputMode,
    misc_task_tag: MiscTask,
    prog_node: *std.Progress.Node,
    c_source_files: []const Compilation.CSourceFile,
) !void {
    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    const target = comp.getTarget();
    const basename = try std.zig.binNameAlloc(comp.gpa, .{
        .root_name = root_name,
        .target = target,
        .output_mode = output_mode,
    });
    errdefer comp.gpa.free(basename);

    const sub_compilation = try Compilation.create(comp.gpa, .{
        .local_cache_directory = comp.global_cache_directory,
        .global_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .cache_mode = .whole,
        .target = target,
        .root_name = root_name,
        .main_mod = null,
        .output_mode = output_mode,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.bin_file.options.libc_installation,
        .emit_bin = .{
            .directory = null, // Put it in the cache directory.
            .basename = basename,
        },
        .optimize_mode = comp.compilerRtOptMode(),
        .want_sanitize_c = false,
        .want_stack_check = false,
        .want_stack_protector = 0,
        .want_red_zone = comp.bin_file.options.red_zone,
        .omit_frame_pointer = comp.bin_file.options.omit_frame_pointer,
        .want_valgrind = false,
        .want_tsan = false,
        .want_pic = comp.bin_file.options.pic,
        .want_pie = null,
        .want_lto = switch (output_mode) {
            .Lib => comp.bin_file.options.lto,
            .Obj, .Exe => false,
        },
        .emit_h = null,
        .strip = comp.compilerRtStrip(),
        .is_native_os = comp.bin_file.options.is_native_os,
        .is_native_abi = comp.bin_file.options.is_native_abi,
        .self_exe_path = comp.self_exe_path,
        .c_source_files = c_source_files,
        .verbose_cc = comp.verbose_cc,
        .verbose_link = comp.bin_file.options.verbose_link,
        .verbose_air = comp.verbose_air,
        .verbose_intern_pool = comp.verbose_intern_pool,
        .verbose_generic_instances = comp.verbose_generic_instances,
        .verbose_llvm_ir = comp.verbose_llvm_ir,
        .verbose_llvm_bc = comp.verbose_llvm_bc,
        .verbose_cimport = comp.verbose_cimport,
        .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
        .clang_passthrough_mode = comp.clang_passthrough_mode,
        .skip_linker_dependencies = true,
        .parent_compilation_link_libc = comp.bin_file.options.link_libc,
        .want_structured_cfg = comp.bin_file.options.want_structured_cfg,
    });
    defer sub_compilation.destroy();

    try comp.updateSubCompilation(sub_compilation, misc_task_tag, prog_node);

    try comp.crt_files.ensureUnusedCapacity(comp.gpa, 1);

    comp.crt_files.putAssumeCapacityNoClobber(basename, .{
        .full_object_path = try sub_compilation.bin_file.options.emit.?.directory.join(comp.gpa, &[_][]const u8{
            sub_compilation.bin_file.options.emit.?.sub_path,
        }),
        .lock = sub_compilation.bin_file.toOwnedLock(),
    });
}

pub fn addLinkLib(comp: *Compilation, lib_name: []const u8) !void {
    // Avoid deadlocking on building import libs such as kernel32.lib
    // This can happen when the user uses `build-exe foo.obj -lkernel32` and
    // then when we create a sub-Compilation for zig libc, it also tries to
    // build kernel32.lib.
    if (comp.bin_file.options.skip_linker_dependencies) return;

    // This happens when an `extern "foo"` function is referenced.
    // If we haven't seen this library yet and we're targeting Windows, we need
    // to queue up a work item to produce the DLL import library for this.
    const gop = try comp.bin_file.options.system_libs.getOrPut(comp.gpa, lib_name);
    if (!gop.found_existing and comp.getTarget().os.tag == .windows) {
        gop.value_ptr.* = .{
            .needed = true,
            .weak = false,
            .path = null,
        };
        try comp.work_queue.writeItem(.{
            .windows_import_lib = comp.bin_file.options.system_libs.count() - 1,
        });
    }
}

/// This decides the optimization mode for all zig-provided libraries, including
/// compiler-rt, libcxx, libc, libunwind, etc.
pub fn compilerRtOptMode(comp: Compilation) std.builtin.OptimizeMode {
    if (comp.debug_compiler_runtime_libs) {
        return comp.bin_file.options.optimize_mode;
    }
    switch (comp.bin_file.options.optimize_mode) {
        .Debug, .ReleaseSafe => return target_util.defaultCompilerRtOptimizeMode(comp.getTarget()),
        .ReleaseFast => return .ReleaseFast,
        .ReleaseSmall => return .ReleaseSmall,
    }
}

/// This decides whether to strip debug info for all zig-provided libraries, including
/// compiler-rt, libcxx, libc, libunwind, etc.
pub fn compilerRtStrip(comp: Compilation) bool {
    return comp.bin_file.options.strip;
}
