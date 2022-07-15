const Compilation = @This();

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.compilation);
const Target = std.Target;

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
const Cache = @import("Cache.zig");
const stage1 = @import("stage1.zig");
const translate_c = @import("translate_c.zig");
const c_codegen = @import("codegen/c.zig");
const ThreadPool = @import("ThreadPool.zig");
const WaitGroup = @import("WaitGroup.zig");
const libtsan = @import("libtsan.zig");
const Zir = @import("Zir.zig");
const Color = @import("main.zig").Color;

/// General-purpose allocator. Used for both temporary and long-term storage.
gpa: Allocator,
/// Arena-allocated memory used during initialization. Should be untouched until deinit.
arena_state: std.heap.ArenaAllocator.State,
bin_file: *link.File,
c_object_table: std.AutoArrayHashMapUnmanaged(*CObject, void) = .{},
/// This is a pointer to a local variable inside `update()`.
whole_cache_manifest: ?*Cache.Manifest = null,

link_error_flags: link.File.ErrorFlags = .{},

work_queue: std.fifo.LinearFifo(Job, .Dynamic),
anon_work_queue: std.fifo.LinearFifo(Job, .Dynamic),

/// These jobs are to invoke the Clang compiler to create an object file, which
/// gets linked with the Compilation.
c_object_work_queue: std.fifo.LinearFifo(*CObject, .Dynamic),

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
failed_c_objects: std.AutoArrayHashMapUnmanaged(*CObject, *CObject.ErrorMsg) = .{},

/// Miscellaneous things that can fail.
misc_failures: std.AutoArrayHashMapUnmanaged(MiscTask, MiscError) = .{},

keep_source_files_loaded: bool,
use_clang: bool,
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
verbose_llvm_ir: bool,
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

c_source_files: []const CSourceFile,
clang_argv: []const []const u8,
cache_parent: *Cache,
/// Path to own executable for invoking `zig clang`.
self_exe_path: ?[]const u8,
/// null means -fno-emit-bin.
/// This is mutable memory allocated into the Compilation-lifetime arena (`arena_state`)
/// of exactly the correct size for "o/[digest]/[basename]".
/// The basename is of the outputted binary file in case we don't know the directory yet.
whole_bin_sub_path: ?[]u8,
/// Same as `whole_bin_sub_path` but for implibs.
whole_implib_sub_path: ?[]u8,
zig_lib_directory: Directory,
local_cache_directory: Directory,
global_cache_directory: Directory,
libc_include_dir_list: []const []const u8,
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
/// Populated when we build the libssp static library. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
libssp_static_lib: ?CRTFile = null,
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

/// This mutex guards all `Compilation` mutable state.
mutex: std.Thread.Mutex = .{},

test_filter: ?[]const u8,
test_name_prefix: ?[]const u8,

emit_asm: ?EmitLoc,
emit_llvm_ir: ?EmitLoc,
emit_llvm_bc: ?EmitLoc,
emit_analysis: ?EmitLoc,
emit_docs: ?EmitLoc,

work_queue_wait_group: WaitGroup = .{},
astgen_wait_group: WaitGroup = .{},

/// Exported symbol names. This is only for when the target is wasm.
/// TODO: Remove this when Stage2 becomes the default compiler as it will already have this information.
export_symbol_names: std.ArrayListUnmanaged([]const u8) = .{},

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

/// For passing to a C compiler.
pub const CSourceFile = struct {
    src_path: []const u8,
    extra_flags: []const []const u8 = &[0][]const u8{},
};

const Job = union(enum) {
    /// Write the constant value for a Decl to the output file.
    codegen_decl: Module.Decl.Index,
    /// Write the machine code for a function to the output file.
    codegen_func: *Module.Fn,
    /// Render the .h file snippet for the Decl.
    emit_h_decl: Module.Decl.Index,
    /// The Decl needs to be analyzed and possibly export itself.
    /// It may have already be analyzed, or it may have been determined
    /// to be outdated; in this case perform semantic analysis again.
    analyze_decl: Module.Decl.Index,
    /// The file that was loaded with `@embedFile` has changed on disk
    /// and has been re-loaded into memory. All Decls that depend on it
    /// need to be re-analyzed.
    update_embed_file: *Module.EmbedFile,
    /// The source file containing the Decl has been updated, and so the
    /// Decl may need its line number information updated in the debug info.
    update_line_number: Module.Decl.Index,
    /// The main source file for the package needs to be analyzed.
    analyze_pkg: *Package,

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
    libssp: void,
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

    pub const ErrorMsg = struct {
        msg: []const u8,
        line: u32,
        column: u32,

        pub fn destroy(em: *ErrorMsg, gpa: Allocator) void {
            gpa.free(em.msg);
            gpa.destroy(em);
        }
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
    libssp,
    zig_libc,
    analyze_pkg,
};

pub const MiscError = struct {
    /// Allocated with gpa.
    msg: []u8,
    children: ?AllErrors = null,

    pub fn deinit(misc_err: *MiscError, gpa: Allocator) void {
        gpa.free(misc_err.msg);
        if (misc_err.children) |*children| {
            children.deinit(gpa);
        }
        misc_err.* = undefined;
    }
};

/// To support incremental compilation, errors are stored in various places
/// so that they can be created and destroyed appropriately. This structure
/// is used to collect all the errors from the various places into one
/// convenient place for API users to consume. It is allocated into 1 arena
/// and freed all at once.
pub const AllErrors = struct {
    arena: std.heap.ArenaAllocator.State,
    list: []const Message,

    pub const Message = union(enum) {
        src: struct {
            msg: []const u8,
            src_path: []const u8,
            line: u32,
            column: u32,
            span: Module.SrcLoc.Span,
            /// Usually one, but incremented for redundant messages.
            count: u32 = 1,
            /// Does not include the trailing newline.
            source_line: ?[]const u8,
            notes: []Message = &.{},

            /// Splits the error message up into lines to properly indent them
            /// to allow for long, good-looking error messages.
            ///
            /// This is used to split the message in `@compileError("hello\nworld")` for example.
            fn writeMsg(src: @This(), stderr: anytype, indent: usize) !void {
                var lines = mem.split(u8, src.msg, "\n");
                while (lines.next()) |line| {
                    try stderr.writeAll(line);
                    if (lines.index == null) break;
                    try stderr.writeByte('\n');
                    try stderr.writeByteNTimes(' ', indent);
                }
            }
        },
        plain: struct {
            msg: []const u8,
            notes: []Message = &.{},
            /// Usually one, but incremented for redundant messages.
            count: u32 = 1,
        },

        pub fn incrementCount(msg: *Message) void {
            switch (msg.*) {
                .src => |*src| {
                    src.count += 1;
                },
                .plain => |*plain| {
                    plain.count += 1;
                },
            }
        }

        pub fn renderToStdErr(msg: Message, ttyconf: std.debug.TTY.Config) void {
            std.debug.getStderrMutex().lock();
            defer std.debug.getStderrMutex().unlock();
            const stderr = std.io.getStdErr();
            return msg.renderToWriter(ttyconf, stderr.writer(), "error", .Red, 0) catch return;
        }

        pub fn renderToWriter(
            msg: Message,
            ttyconf: std.debug.TTY.Config,
            stderr: anytype,
            kind: []const u8,
            color: std.debug.TTY.Color,
            indent: usize,
        ) anyerror!void {
            var counting_writer = std.io.countingWriter(stderr);
            const counting_stderr = counting_writer.writer();
            switch (msg) {
                .src => |src| {
                    try counting_stderr.writeByteNTimes(' ', indent);
                    ttyconf.setColor(stderr, .Bold);
                    try counting_stderr.print("{s}:{d}:{d}: ", .{
                        src.src_path,
                        src.line + 1,
                        src.column + 1,
                    });
                    ttyconf.setColor(stderr, color);
                    try counting_stderr.writeAll(kind);
                    try counting_stderr.writeAll(": ");
                    // This is the length of the part before the error message:
                    // e.g. "file.zig:4:5: error: "
                    const prefix_len = @intCast(usize, counting_stderr.context.bytes_written);
                    ttyconf.setColor(stderr, .Reset);
                    ttyconf.setColor(stderr, .Bold);
                    if (src.count == 1) {
                        try src.writeMsg(stderr, prefix_len);
                        try stderr.writeByte('\n');
                    } else {
                        try src.writeMsg(stderr, prefix_len);
                        ttyconf.setColor(stderr, .Dim);
                        try stderr.print(" ({d} times)\n", .{src.count});
                    }
                    ttyconf.setColor(stderr, .Reset);
                    if (ttyconf != .no_color) {
                        if (src.source_line) |line| {
                            for (line) |b| switch (b) {
                                '\t' => try stderr.writeByte(' '),
                                else => try stderr.writeByte(b),
                            };
                            try stderr.writeByte('\n');
                            // TODO basic unicode code point monospace width
                            const before_caret = src.span.main - src.span.start;
                            // -1 since span.main includes the caret
                            const after_caret = src.span.end - src.span.main -| 1;
                            try stderr.writeByteNTimes(' ', src.column - before_caret);
                            ttyconf.setColor(stderr, .Green);
                            try stderr.writeByteNTimes('~', before_caret);
                            try stderr.writeByte('^');
                            try stderr.writeByteNTimes('~', after_caret);
                            try stderr.writeByte('\n');
                            ttyconf.setColor(stderr, .Reset);
                        }
                    }
                    for (src.notes) |note| {
                        try note.renderToWriter(ttyconf, stderr, "note", .Cyan, indent);
                    }
                },
                .plain => |plain| {
                    ttyconf.setColor(stderr, color);
                    try stderr.writeByteNTimes(' ', indent);
                    try stderr.writeAll(kind);
                    try stderr.writeAll(": ");
                    ttyconf.setColor(stderr, .Reset);
                    if (plain.count == 1) {
                        try stderr.print("{s}\n", .{plain.msg});
                    } else {
                        try stderr.print("{s}", .{plain.msg});
                        ttyconf.setColor(stderr, .Dim);
                        try stderr.print(" ({d} times)\n", .{plain.count});
                    }
                    ttyconf.setColor(stderr, .Reset);
                    for (plain.notes) |note| {
                        try note.renderToWriter(ttyconf, stderr, "error", .Red, indent + 4);
                    }
                },
            }
        }

        pub const HashContext = struct {
            pub fn hash(ctx: HashContext, key: *Message) u64 {
                _ = ctx;
                var hasher = std.hash.Wyhash.init(0);

                switch (key.*) {
                    .src => |src| {
                        hasher.update(src.msg);
                        hasher.update(src.src_path);
                        std.hash.autoHash(&hasher, src.line);
                        std.hash.autoHash(&hasher, src.column);
                        std.hash.autoHash(&hasher, src.span.main);
                    },
                    .plain => |plain| {
                        hasher.update(plain.msg);
                    },
                }

                return hasher.final();
            }

            pub fn eql(ctx: HashContext, a: *Message, b: *Message) bool {
                _ = ctx;
                switch (a.*) {
                    .src => |a_src| switch (b.*) {
                        .src => |b_src| {
                            return mem.eql(u8, a_src.msg, b_src.msg) and
                                mem.eql(u8, a_src.src_path, b_src.src_path) and
                                a_src.line == b_src.line and
                                a_src.column == b_src.column and
                                a_src.span.main == b_src.span.main;
                        },
                        .plain => return false,
                    },
                    .plain => |a_plain| switch (b.*) {
                        .src => return false,
                        .plain => |b_plain| {
                            return mem.eql(u8, a_plain.msg, b_plain.msg);
                        },
                    },
                }
            }
        };
    };

    pub fn deinit(self: *AllErrors, gpa: Allocator) void {
        self.arena.promote(gpa).deinit();
    }

    fn add(
        module: *Module,
        arena: *std.heap.ArenaAllocator,
        errors: *std.ArrayList(Message),
        module_err_msg: Module.ErrorMsg,
    ) !void {
        const allocator = arena.allocator();

        const notes_buf = try allocator.alloc(Message, module_err_msg.notes.len);
        var note_i: usize = 0;

        // De-duplicate error notes. The main use case in mind for this is
        // too many "note: called from here" notes when eval branch quota is reached.
        var seen_notes = std.HashMap(
            *Message,
            void,
            Message.HashContext,
            std.hash_map.default_max_load_percentage,
        ).init(allocator);
        const err_source = try module_err_msg.src_loc.file_scope.getSource(module.gpa);
        const err_span = try module_err_msg.src_loc.span(module.gpa);
        const err_loc = std.zig.findLineColumn(err_source.bytes, err_span.main);

        for (module_err_msg.notes) |module_note| {
            const source = try module_note.src_loc.file_scope.getSource(module.gpa);
            const span = try module_note.src_loc.span(module.gpa);
            const loc = std.zig.findLineColumn(source.bytes, span.main);
            const file_path = try module_note.src_loc.file_scope.fullPath(allocator);
            const note = &notes_buf[note_i];
            note.* = .{
                .src = .{
                    .src_path = file_path,
                    .msg = try allocator.dupe(u8, module_note.msg),
                    .span = span,
                    .line = @intCast(u32, loc.line),
                    .column = @intCast(u32, loc.column),
                    .source_line = if (err_loc.eql(loc)) null else try allocator.dupe(u8, loc.source_line),
                },
            };
            const gop = try seen_notes.getOrPut(note);
            if (gop.found_existing) {
                gop.key_ptr.*.incrementCount();
            } else {
                note_i += 1;
            }
        }
        if (module_err_msg.src_loc.lazy == .entire_file) {
            try errors.append(.{
                .plain = .{
                    .msg = try allocator.dupe(u8, module_err_msg.msg),
                },
            });
            return;
        }
        const file_path = try module_err_msg.src_loc.file_scope.fullPath(allocator);
        try errors.append(.{
            .src = .{
                .src_path = file_path,
                .msg = try allocator.dupe(u8, module_err_msg.msg),
                .span = err_span,
                .line = @intCast(u32, err_loc.line),
                .column = @intCast(u32, err_loc.column),
                .notes = notes_buf[0..note_i],
                .source_line = try allocator.dupe(u8, err_loc.source_line),
            },
        });
    }

    pub fn addZir(
        arena: Allocator,
        errors: *std.ArrayList(Message),
        file: *Module.File,
    ) !void {
        assert(file.zir_loaded);
        assert(file.tree_loaded);
        assert(file.source_loaded);
        const payload_index = file.zir.extra[@enumToInt(Zir.ExtraIndex.compile_errors)];
        assert(payload_index != 0);

        const header = file.zir.extraData(Zir.Inst.CompileErrors, payload_index);
        const items_len = header.data.items_len;
        var extra_index = header.end;
        var item_i: usize = 0;
        while (item_i < items_len) : (item_i += 1) {
            const item = file.zir.extraData(Zir.Inst.CompileErrors.Item, extra_index);
            extra_index = item.end;
            const err_span = blk: {
                if (item.data.node != 0) {
                    break :blk Module.SrcLoc.nodeToSpan(&file.tree, item.data.node);
                }
                const token_starts = file.tree.tokens.items(.start);
                const start = token_starts[item.data.token] + item.data.byte_offset;
                const end = start + @intCast(u32, file.tree.tokenSlice(item.data.token).len);
                break :blk Module.SrcLoc.Span{ .start = start, .end = end, .main = start };
            };
            const err_loc = std.zig.findLineColumn(file.source, err_span.main);

            var notes: []Message = &[0]Message{};
            if (item.data.notes != 0) {
                const block = file.zir.extraData(Zir.Inst.Block, item.data.notes);
                const body = file.zir.extra[block.end..][0..block.data.body_len];
                notes = try arena.alloc(Message, body.len);
                for (notes) |*note, i| {
                    const note_item = file.zir.extraData(Zir.Inst.CompileErrors.Item, body[i]);
                    const msg = file.zir.nullTerminatedString(note_item.data.msg);
                    const span = blk: {
                        if (note_item.data.node != 0) {
                            break :blk Module.SrcLoc.nodeToSpan(&file.tree, note_item.data.node);
                        }
                        const token_starts = file.tree.tokens.items(.start);
                        const start = token_starts[note_item.data.token] + note_item.data.byte_offset;
                        const end = start + @intCast(u32, file.tree.tokenSlice(note_item.data.token).len);
                        break :blk Module.SrcLoc.Span{ .start = start, .end = end, .main = start };
                    };
                    const loc = std.zig.findLineColumn(file.source, span.main);

                    note.* = .{
                        .src = .{
                            .src_path = try file.fullPath(arena),
                            .msg = try arena.dupe(u8, msg),
                            .span = span,
                            .line = @intCast(u32, loc.line),
                            .column = @intCast(u32, loc.column),
                            .notes = &.{}, // TODO rework this function to be recursive
                            .source_line = if (loc.eql(err_loc)) null else try arena.dupe(u8, loc.source_line),
                        },
                    };
                }
            }

            const msg = file.zir.nullTerminatedString(item.data.msg);
            try errors.append(.{
                .src = .{
                    .src_path = try file.fullPath(arena),
                    .msg = try arena.dupe(u8, msg),
                    .span = err_span,
                    .line = @intCast(u32, err_loc.line),
                    .column = @intCast(u32, err_loc.column),
                    .notes = notes,
                    .source_line = try arena.dupe(u8, err_loc.source_line),
                },
            });
        }
    }

    fn addPlain(
        arena: *std.heap.ArenaAllocator,
        errors: *std.ArrayList(Message),
        msg: []const u8,
    ) !void {
        _ = arena;
        try errors.append(.{ .plain = .{ .msg = msg } });
    }

    fn addPlainWithChildren(
        arena: *std.heap.ArenaAllocator,
        errors: *std.ArrayList(Message),
        msg: []const u8,
        optional_children: ?AllErrors,
    ) !void {
        const allocator = arena.allocator();
        const duped_msg = try allocator.dupe(u8, msg);
        if (optional_children) |*children| {
            try errors.append(.{ .plain = .{
                .msg = duped_msg,
                .notes = try dupeList(children.list, allocator),
            } });
        } else {
            try errors.append(.{ .plain = .{ .msg = duped_msg } });
        }
    }

    fn dupeList(list: []const Message, arena: Allocator) Allocator.Error![]Message {
        const duped_list = try arena.alloc(Message, list.len);
        for (list) |item, i| {
            duped_list[i] = switch (item) {
                .src => |src| .{ .src = .{
                    .msg = try arena.dupe(u8, src.msg),
                    .src_path = try arena.dupe(u8, src.src_path),
                    .line = src.line,
                    .column = src.column,
                    .span = src.span,
                    .source_line = if (src.source_line) |s| try arena.dupe(u8, s) else null,
                    .notes = try dupeList(src.notes, arena),
                } },
                .plain => |plain| .{ .plain = .{
                    .msg = try arena.dupe(u8, plain.msg),
                    .notes = try dupeList(plain.notes, arena),
                } },
            };
        }
        return duped_list;
    }
};

pub const Directory = struct {
    /// This field is redundant for operations that can act on the open directory handle
    /// directly, but it is needed when passing the directory to a child process.
    /// `null` means cwd.
    path: ?[]const u8,
    handle: std.fs.Dir,

    pub fn join(self: Directory, allocator: Allocator, paths: []const []const u8) ![]u8 {
        if (self.path) |p| {
            // TODO clean way to do this with only 1 allocation
            const part2 = try std.fs.path.join(allocator, paths);
            defer allocator.free(part2);
            return std.fs.path.join(allocator, &[_][]const u8{ p, part2 });
        } else {
            return std.fs.path.join(allocator, paths);
        }
    }

    pub fn joinZ(self: Directory, allocator: Allocator, paths: []const []const u8) ![:0]u8 {
        if (self.path) |p| {
            // TODO clean way to do this with only 1 allocation
            const part2 = try std.fs.path.join(allocator, paths);
            defer allocator.free(part2);
            return std.fs.path.joinZ(allocator, &[_][]const u8{ p, part2 });
        } else {
            return std.fs.path.joinZ(allocator, paths);
        }
    }

    /// Whether or not the handle should be closed, or the path should be freed
    /// is determined by usage, however this function is provided for convenience
    /// if it happens to be what the caller needs.
    pub fn closeAndFree(self: *Directory, gpa: Allocator) void {
        self.handle.close();
        if (self.path) |p| gpa.free(p);
        self.* = undefined;
    }
};

pub const EmitLoc = struct {
    /// If this is `null` it means the file will be output to the cache directory.
    /// When provided, both the open file handle and the path name must outlive the `Compilation`.
    directory: ?Compilation.Directory,
    /// This may not have sub-directories in it.
    basename: []const u8,
};

pub const ClangPreprocessorMode = enum {
    no,
    /// This means we are doing `zig cc -E -o <path>`.
    yes,
    /// This means we are doing `zig cc -E`.
    stdout,
};

pub const SystemLib = link.SystemLib;
pub const CacheMode = link.CacheMode;

pub const LinkObject = struct {
    path: []const u8,
    must_link: bool = false,
};

pub const InitOptions = struct {
    zig_lib_directory: Directory,
    local_cache_directory: Directory,
    global_cache_directory: Directory,
    target: Target,
    root_name: []const u8,
    main_pkg: ?*Package,
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
    /// `null` means to not emit semantic analysis JSON.
    emit_analysis: ?EmitLoc = null,
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
    object_format: ?std.Target.ObjectFormat = null,
    optimize_mode: std.builtin.Mode = .Debug,
    keep_source_files_loaded: bool = false,
    clang_argv: []const []const u8 = &[0][]const u8{},
    lib_dirs: []const []const u8 = &[0][]const u8{},
    rpath_list: []const []const u8 = &[0][]const u8{},
    c_source_files: []const CSourceFile = &[0]CSourceFile{},
    link_objects: []LinkObject = &[0]LinkObject{},
    framework_dirs: []const []const u8 = &[0][]const u8{},
    frameworks: std.StringArrayHashMapUnmanaged(SystemLib) = .{},
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
    want_red_zone: ?bool = null,
    omit_frame_pointer: ?bool = null,
    want_valgrind: ?bool = null,
    want_tsan: ?bool = null,
    want_compiler_rt: ?bool = null,
    want_lto: ?bool = null,
    want_unwind_tables: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    use_clang: ?bool = null,
    use_stage1: ?bool = null,
    single_threaded: ?bool = null,
    rdynamic: bool = false,
    strip: bool = false,
    function_sections: bool = false,
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
    linker_import_table: bool = false,
    linker_export_table: bool = false,
    linker_initial_memory: ?u64 = null,
    linker_max_memory: ?u64 = null,
    linker_shared_memory: bool = false,
    linker_global_base: ?u64 = null,
    linker_export_symbol_names: []const []const u8 = &.{},
    each_lib_rpath: ?bool = null,
    build_id: ?bool = null,
    disable_c_depfile: bool = false,
    linker_z_nodelete: bool = false,
    linker_z_notext: bool = false,
    linker_z_defs: bool = false,
    linker_z_origin: bool = false,
    linker_z_now: bool = true,
    linker_z_relro: bool = true,
    linker_z_nocopyreloc: bool = false,
    linker_tsaware: bool = false,
    linker_nxcompat: bool = false,
    linker_dynamicbase: bool = false,
    linker_optimization: ?u8 = null,
    linker_compress_debug_sections: ?link.CompressDebugSections = null,
    major_subsystem_version: ?u32 = null,
    minor_subsystem_version: ?u32 = null,
    clang_passthrough_mode: bool = false,
    verbose_cc: bool = false,
    verbose_link: bool = false,
    verbose_air: bool = false,
    verbose_llvm_ir: bool = false,
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
    stack_size_override: ?u64 = null,
    image_base_override: ?u64 = null,
    self_exe_path: ?[]const u8 = null,
    version: ?std.builtin.Version = null,
    compatibility_version: ?std.builtin.Version = null,
    libc_installation: ?*const LibCInstallation = null,
    machine_code_model: std.builtin.CodeModel = .default,
    clang_preprocessor_mode: ClangPreprocessorMode = .no,
    /// This is for stage1 and should be deleted upon completion of self-hosting.
    color: Color = .auto,
    test_filter: ?[]const u8 = null,
    test_name_prefix: ?[]const u8 = null,
    subsystem: ?std.Target.SubSystem = null,
    /// WASI-only. Type of WASI execution model ("command" or "reactor").
    wasi_exec_model: ?std.builtin.WasiExecModel = null,
    /// (Zig compiler development) Enable dumping linker's state as JSON.
    enable_link_snapshots: bool = false,
    /// (Darwin) Path and version of the native SDK if detected.
    native_darwin_sdk: ?std.zig.system.darwin.DarwinSDK = null,
    /// (Darwin) Install name of the dylib
    install_name: ?[]const u8 = null,
    /// (Darwin) Path to entitlements file
    entitlements: ?[]const u8 = null,
    /// (Darwin) size of the __PAGEZERO segment
    pagezero_size: ?u64 = null,
    /// (Darwin) search strategy for system libraries
    search_strategy: ?link.File.MachO.SearchStrategy = null,
    /// (Darwin) set minimum space for future expansion of the load commands
    headerpad_size: ?u32 = null,
    /// (Darwin) set enough space as if all paths were MATPATHLEN
    headerpad_max_install_names: bool = false,
    /// (Darwin) remove dylibs that are unreachable by the entry point or exported symbols
    dead_strip_dylibs: bool = false,
};

fn addPackageTableToCacheHash(
    hash: *Cache.HashHelper,
    arena: *std.heap.ArenaAllocator,
    pkg_table: Package.Table,
    seen_table: *std.AutoHashMap(*Package, void),
    hash_type: union(enum) { path_bytes, files: *Cache.Manifest },
) (error{OutOfMemory} || std.os.GetCwdError)!void {
    const allocator = arena.allocator();

    const packages = try allocator.alloc(Package.Table.KV, pkg_table.count());
    {
        // Copy over the hashmap entries to our slice
        var table_it = pkg_table.iterator();
        var idx: usize = 0;
        while (table_it.next()) |entry| : (idx += 1) {
            packages[idx] = .{
                .key = entry.key_ptr.*,
                .value = entry.value_ptr.*,
            };
        }
    }
    // Sort the slice by package name
    std.sort.sort(Package.Table.KV, packages, {}, struct {
        fn lessThan(_: void, lhs: Package.Table.KV, rhs: Package.Table.KV) bool {
            return std.mem.lessThan(u8, lhs.key, rhs.key);
        }
    }.lessThan);

    for (packages) |pkg| {
        if ((try seen_table.getOrPut(pkg.value)).found_existing) continue;

        // Finally insert the package name and path to the cache hash.
        hash.addBytes(pkg.key);
        switch (hash_type) {
            .path_bytes => {
                hash.addBytes(pkg.value.root_src_path);
                hash.addOptionalBytes(pkg.value.root_src_directory.path);
            },
            .files => |man| {
                const pkg_zig_file = try pkg.value.root_src_directory.join(allocator, &[_][]const u8{
                    pkg.value.root_src_path,
                });
                _ = try man.addFile(pkg_zig_file, null);
            },
        }
        // Recurse to handle the package's dependencies
        try addPackageTableToCacheHash(hash, arena, pkg.value.table, seen_table, hash_type);
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

    const needs_c_symbols = !options.skip_linker_dependencies and is_exe_or_dyn_lib;

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

        const ofmt = options.object_format orelse options.target.getObjectFormat();

        const use_stage1 = options.use_stage1 orelse blk: {
            // Even though we may have no Zig code to compile (depending on `options.main_pkg`),
            // we may need to use stage1 for building compiler-rt and other dependencies.

            if (build_options.omit_stage2)
                break :blk true;
            if (options.use_llvm) |use_llvm| {
                if (!use_llvm) {
                    break :blk false;
                }
            }

            break :blk build_options.is_stage1;
        };

        const cache_mode = if (use_stage1 and !options.disable_lld_caching)
            CacheMode.whole
        else
            options.cache_mode;

        // Make a decision on whether to use LLVM or our own backend.
        const use_llvm = build_options.have_llvm and blk: {
            if (options.use_llvm) |explicit|
                break :blk explicit;

            // If emitting to LLVM bitcode object format, must use LLVM backend.
            if (options.emit_llvm_ir != null or options.emit_llvm_bc != null)
                break :blk true;

            // If we have no zig code to compile, no need for LLVM.
            if (options.main_pkg == null)
                break :blk false;

            // The stage1 compiler depends on the stage1 C++ LLVM backend
            // to compile zig code.
            if (use_stage1)
                break :blk true;

            // If LLVM does not support the target, then we can't use it.
            if (!target_util.hasLlvmSupport(options.target, ofmt))
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
        const build_id = options.build_id orelse false;

        // Make a decision on whether to use LLD or our own linker.
        const use_lld = options.use_lld orelse blk: {
            if (options.target.isDarwin()) {
                break :blk false;
            }

            if (!build_options.have_llvm)
                break :blk false;

            if (ofmt == .c)
                break :blk false;

            if (options.want_lto) |lto| {
                if (lto) {
                    break :blk true;
                }
            }

            // Our linker can't handle objects or most advanced options yet.
            if (options.link_objects.len != 0 or
                options.c_source_files.len != 0 or
                options.frameworks.count() != 0 or
                options.system_lib_names.len != 0 or
                options.link_libc or options.link_libcpp or
                link_eh_frame_hdr or
                options.link_emit_relocs or
                options.output_mode == .Lib or
                options.image_base_override != null or
                options.linker_script != null or options.version_script != null or
                options.emit_implib != null or
                build_id)
            {
                break :blk true;
            }

            if (use_llvm) {
                // If stage1 generates an object file, self-hosted linker is not
                // yet sophisticated enough to handle that.
                break :blk options.main_pkg != null;
            }

            break :blk false;
        };

        const sysroot = blk: {
            if (options.sysroot) |sysroot| {
                break :blk sysroot;
            } else if (options.native_darwin_sdk) |sdk| {
                break :blk sdk.path;
            } else {
                break :blk null;
            }
        };

        const lto = blk: {
            if (options.want_lto) |explicit| {
                if (!use_lld and !options.target.isDarwin())
                    return error.LtoUnavailableWithoutLld;
                break :blk explicit;
            } else if (!use_lld) {
                // TODO zig ld LTO support
                // See https://github.com/ziglang/zig/issues/8680
                break :blk false;
            } else if (options.c_source_files.len == 0) {
                break :blk false;
            } else if (options.target.os.tag == .windows and link_libcpp) {
                // https://github.com/ziglang/zig/issues/8531
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

        const dll_export_fns = if (options.dll_export_fns) |explicit| explicit else is_dyn_lib or options.rdynamic;

        const libc_dirs = try detectLibCIncludeDirs(
            arena,
            options.zig_lib_directory.path.?,
            options.target,
            options.is_native_abi,
            link_libc,
            options.system_lib_names.len != 0 or options.frameworks.count() != 0,
            options.libc_installation,
            options.native_darwin_sdk != null,
        );

        const must_pie = target_util.requiresPIE(options.target);
        const pie: bool = if (options.want_pie) |explicit| pie: {
            if (!explicit and must_pie) {
                return error.TargetRequiresPIE;
            }
            break :pie explicit;
        } else must_pie or tsan;

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

        // Make a decision on whether to use Clang for translate-c and compiling C files.
        const use_clang = if (options.use_clang) |explicit| explicit else blk: {
            if (build_options.have_llvm) {
                // Can't use it if we don't have it!
                break :blk false;
            }
            // It's not planned to do our own translate-c or C compilation.
            break :blk true;
        };

        const is_safe_mode = switch (options.optimize_mode) {
            .Debug, .ReleaseSafe => true,
            .ReleaseFast, .ReleaseSmall => false,
        };

        const sanitize_c = options.want_sanitize_c orelse is_safe_mode;

        const stack_check: bool = b: {
            if (!target_util.supportsStackProbing(options.target))
                break :b false;
            break :b options.want_stack_check orelse is_safe_mode;
        };

        const valgrind: bool = b: {
            if (!target_util.hasValgrindSupport(options.target))
                break :b false;
            break :b options.want_valgrind orelse (options.optimize_mode == .Debug);
        };

        const include_compiler_rt = options.want_compiler_rt orelse needs_c_symbols;

        const must_single_thread = target_util.isSingleThreaded(options.target);
        const single_threaded = options.single_threaded orelse must_single_thread;
        if (must_single_thread and !single_threaded) {
            return error.TargetRequiresSingleThreaded;
        }
        if (!single_threaded and options.link_libcpp) {
            if (options.target.cpu.arch.isARM()) {
                log.warn(
                    \\libc++ does not work on multi-threaded ARM yet.
                    \\For more details: https://github.com/ziglang/zig/issues/6573
                , .{});
                return error.TargetRequiresSingleThreaded;
            }
        }

        const llvm_cpu_features: ?[*:0]const u8 = if (build_options.have_llvm and use_llvm) blk: {
            var buf = std.ArrayList(u8).init(arena);
            for (options.target.cpu.arch.allFeaturesList()) |feature, index_usize| {
                const index = @intCast(Target.Cpu.Feature.Set.Index, index_usize);
                const is_enabled = options.target.cpu.features.isEnabled(index);

                if (feature.llvm_name) |llvm_name| {
                    const plus_or_minus = "-+"[@boolToInt(is_enabled)];
                    try buf.ensureUnusedCapacity(2 + llvm_name.len);
                    buf.appendAssumeCapacity(plus_or_minus);
                    buf.appendSliceAssumeCapacity(llvm_name);
                    buf.appendSliceAssumeCapacity(",");
                }
            }
            assert(mem.endsWith(u8, buf.items, ","));
            buf.items[buf.items.len - 1] = 0;
            buf.shrinkAndFree(buf.items.len);
            break :blk buf.items[0 .. buf.items.len - 1 :0].ptr;
        } else null;

        const strip = options.strip or !target_util.hasDebugInfo(options.target);
        const red_zone = options.want_red_zone orelse target_util.hasRedZone(options.target);
        const omit_frame_pointer = options.omit_frame_pointer orelse (options.optimize_mode != .Debug);
        const linker_optimization: u8 = options.linker_optimization orelse switch (options.optimize_mode) {
            .Debug => @as(u8, 0),
            else => @as(u8, 3),
        };

        // We put everything into the cache hash that *cannot be modified during an incremental update*.
        // For example, one cannot change the target between updates, but one can change source files,
        // so the target goes into the cache hash, but source files do not. This is so that we can
        // find the same binary and incrementally update it even if there are modified source files.
        // We do this even if outputting to the current directory because we need somewhere to store
        // incremental compilation metadata.
        const cache = try arena.create(Cache);
        cache.* = .{
            .gpa = gpa,
            .manifest_dir = try options.local_cache_directory.handle.makeOpenPath("h", .{}),
        };
        errdefer cache.manifest_dir.close();

        // This is shared hasher state common to zig source and all C source files.
        cache.hash.addBytes(build_options.version);
        cache.hash.add(builtin.zig_backend);
        cache.hash.addBytes(options.zig_lib_directory.path orelse ".");
        cache.hash.add(options.optimize_mode);
        cache.hash.add(options.target.cpu.arch);
        cache.hash.addBytes(options.target.cpu.model.name);
        cache.hash.add(options.target.cpu.features.ints);
        cache.hash.add(options.target.os.tag);
        cache.hash.add(options.target.os.getVersionRange());
        cache.hash.add(options.is_native_os);
        cache.hash.add(options.target.abi);
        cache.hash.add(ofmt);
        cache.hash.add(pic);
        cache.hash.add(pie);
        cache.hash.add(lto);
        cache.hash.add(unwind_tables);
        cache.hash.add(tsan);
        cache.hash.add(stack_check);
        cache.hash.add(red_zone);
        cache.hash.add(omit_frame_pointer);
        cache.hash.add(link_mode);
        cache.hash.add(options.function_sections);
        cache.hash.add(options.no_builtin);
        cache.hash.add(strip);
        cache.hash.add(link_libc);
        cache.hash.add(link_libcpp);
        cache.hash.add(link_libunwind);
        cache.hash.add(options.output_mode);
        cache.hash.add(options.machine_code_model);
        cache.hash.addOptionalEmitLoc(options.emit_bin);
        cache.hash.addOptionalEmitLoc(options.emit_implib);
        cache.hash.addBytes(options.root_name);
        if (options.target.os.tag == .wasi) cache.hash.add(wasi_exec_model);
        // TODO audit this and make sure everything is in it

        const module: ?*Module = if (options.main_pkg) |main_pkg| blk: {
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
                    hash.addBytes(main_pkg.root_src_path);
                    hash.addOptionalBytes(main_pkg.root_src_directory.path);
                    {
                        var seen_table = std.AutoHashMap(*Package, void).init(arena);
                        try addPackageTableToCacheHash(&hash, &arena_allocator, main_pkg.table, &seen_table, .path_bytes);
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
            hash.add(use_stage1);
            hash.add(use_llvm);
            hash.add(dll_export_fns);
            hash.add(options.is_test);
            hash.add(options.test_evented_io);
            hash.addOptionalBytes(options.test_filter);
            hash.addOptionalBytes(options.test_name_prefix);
            hash.add(options.skip_linker_dependencies);
            hash.add(options.parent_compilation_link_libc);

            // In the case of incremental cache mode, this `zig_cache_artifact_directory`
            // is computed based on a hash of non-linker inputs, and it is where all
            // build artifacts are stored (even while in-progress).
            //
            // For whole cache mode, it is still used for builtin.zig so that the file
            // path to builtin.zig can remain consistent during a debugging session at
            // runtime. However, we don't know where to put outputs from the linker
            // or stage1 backend object files until the final cache hash, which is available
            // after the compilation is complete.
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
            log.debug("zig_cache_artifact_directory='{s}' use_stage1={}", .{
                zig_cache_artifact_directory.path, use_stage1,
            });

            const builtin_pkg = try Package.createWithDir(
                gpa,
                zig_cache_artifact_directory,
                null,
                "builtin.zig",
            );
            errdefer builtin_pkg.destroy(gpa);

            const std_pkg = try Package.createWithDir(
                gpa,
                options.zig_lib_directory,
                "std",
                "std.zig",
            );
            errdefer std_pkg.destroy(gpa);

            const root_pkg = if (options.is_test) root_pkg: {
                const test_pkg = try Package.createWithDir(
                    gpa,
                    options.zig_lib_directory,
                    null,
                    "test_runner.zig",
                );
                errdefer test_pkg.destroy(gpa);

                try test_pkg.add(gpa, "builtin", builtin_pkg);
                try test_pkg.add(gpa, "root", test_pkg);
                try test_pkg.add(gpa, "std", std_pkg);

                break :root_pkg test_pkg;
            } else main_pkg;
            errdefer if (options.is_test) root_pkg.destroy(gpa);

            var other_pkg_iter = main_pkg.table.valueIterator();
            while (other_pkg_iter.next()) |pkg| {
                try pkg.*.add(gpa, "builtin", builtin_pkg);
                try pkg.*.add(gpa, "std", std_pkg);
            }

            try main_pkg.addAndAdopt(gpa, "builtin", builtin_pkg);
            try main_pkg.add(gpa, "root", root_pkg);
            try main_pkg.addAndAdopt(gpa, "std", std_pkg);

            try std_pkg.add(gpa, "builtin", builtin_pkg);
            try std_pkg.add(gpa, "root", root_pkg);
            try std_pkg.add(gpa, "std", std_pkg);

            try builtin_pkg.add(gpa, "std", std_pkg);
            try builtin_pkg.add(gpa, "builtin", builtin_pkg);

            const main_pkg_in_std = m: {
                const std_path = try std.fs.path.resolve(arena, &[_][]const u8{
                    std_pkg.root_src_directory.path orelse ".",
                    std.fs.path.dirname(std_pkg.root_src_path) orelse ".",
                });
                defer arena.free(std_path);
                const main_path = try std.fs.path.resolve(arena, &[_][]const u8{
                    main_pkg.root_src_directory.path orelse ".",
                    main_pkg.root_src_path,
                });
                defer arena.free(main_path);
                break :m mem.startsWith(u8, main_path, std_path);
            };

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
                .main_pkg = main_pkg,
                .main_pkg_in_std = main_pkg_in_std,
                .root_pkg = root_pkg,
                .zig_cache_artifact_directory = zig_cache_artifact_directory,
                .global_zir_cache = global_zir_cache,
                .local_zir_cache = local_zir_cache,
                .emit_h = emit_h,
                .error_name_list = .{},
            };
            try module.error_name_list.append(gpa, "(no error)");

            break :blk module;
        } else blk: {
            if (options.emit_h != null) return error.NoZigModuleForCHeader;
            break :blk null;
        };
        errdefer if (module) |zm| zm.deinit();

        const error_return_tracing = !strip and switch (options.optimize_mode) {
            .Debug, .ReleaseSafe => (!options.target.isWasm() or options.target.os.tag == .emscripten) and
                !options.target.cpu.arch.isBpf(),
            .ReleaseFast, .ReleaseSmall => false,
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
            var artifact_dir = try options.local_cache_directory.handle.makeOpenPath(artifact_sub_dir, .{});
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

        // This is so that when doing `CacheMode.whole`, the mechanism in update()
        // can use it for communicating the result directory via `bin_file.emit`.
        // This is used to distinguish between -fno-emit-bin and -femit-bin
        // for `CacheMode.whole`.
        // This memory will be overwritten with the real digest in update() but
        // the basename will be preserved.
        const whole_bin_sub_path: ?[]u8 = try prepareWholeEmitSubPath(arena, options.emit_bin);
        // Same thing but for implibs.
        const whole_implib_sub_path: ?[]u8 = try prepareWholeEmitSubPath(arena, options.emit_implib);

        var system_libs: std.StringArrayHashMapUnmanaged(SystemLib) = .{};
        errdefer system_libs.deinit(gpa);
        try system_libs.ensureTotalCapacity(gpa, options.system_lib_names.len);
        for (options.system_lib_names) |lib_name, i| {
            system_libs.putAssumeCapacity(lib_name, options.system_lib_infos[i]);
        }

        const bin_file = try link.File.openPath(gpa, .{
            .emit = bin_file_emit,
            .implib_emit = implib_emit,
            .root_name = root_name,
            .module = module,
            .target = options.target,
            .dynamic_linker = options.dynamic_linker,
            .sysroot = sysroot,
            .output_mode = options.output_mode,
            .link_mode = link_mode,
            .object_format = ofmt,
            .optimize_mode = options.optimize_mode,
            .use_lld = use_lld,
            .use_llvm = use_llvm,
            .link_libc = link_libc,
            .link_libcpp = link_libcpp,
            .link_libunwind = link_libunwind,
            .objects = options.link_objects,
            .frameworks = options.frameworks,
            .framework_dirs = options.framework_dirs,
            .system_libs = system_libs,
            .wasi_emulated_libs = options.wasi_emulated_libs,
            .lib_dirs = options.lib_dirs,
            .rpath_list = options.rpath_list,
            .strip = strip,
            .is_native_os = options.is_native_os,
            .is_native_abi = options.is_native_abi,
            .function_sections = options.function_sections,
            .no_builtin = options.no_builtin,
            .allow_shlib_undefined = options.linker_allow_shlib_undefined,
            .bind_global_refs_locally = options.linker_bind_global_refs_locally orelse false,
            .compress_debug_sections = options.linker_compress_debug_sections orelse .none,
            .import_memory = options.linker_import_memory orelse false,
            .import_table = options.linker_import_table,
            .export_table = options.linker_export_table,
            .initial_memory = options.linker_initial_memory,
            .max_memory = options.linker_max_memory,
            .shared_memory = options.linker_shared_memory,
            .global_base = options.linker_global_base,
            .export_symbol_names = options.linker_export_symbol_names,
            .z_nodelete = options.linker_z_nodelete,
            .z_notext = options.linker_z_notext,
            .z_defs = options.linker_z_defs,
            .z_origin = options.linker_z_origin,
            .z_nocopyreloc = options.linker_z_nocopyreloc,
            .z_now = options.linker_z_now,
            .z_relro = options.linker_z_relro,
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
            .wasi_exec_model = wasi_exec_model,
            .use_stage1 = use_stage1,
            .hash_style = options.hash_style,
            .enable_link_snapshots = options.enable_link_snapshots,
            .native_darwin_sdk = options.native_darwin_sdk,
            .install_name = options.install_name,
            .entitlements = options.entitlements,
            .pagezero_size = options.pagezero_size,
            .search_strategy = options.search_strategy,
            .headerpad_size = options.headerpad_size,
            .headerpad_max_install_names = options.headerpad_max_install_names,
            .dead_strip_dylibs = options.dead_strip_dylibs,
        });
        errdefer bin_file.destroy();
        comp.* = .{
            .gpa = gpa,
            .arena_state = arena_allocator.state,
            .zig_lib_directory = options.zig_lib_directory,
            .local_cache_directory = options.local_cache_directory,
            .global_cache_directory = options.global_cache_directory,
            .bin_file = bin_file,
            .whole_bin_sub_path = whole_bin_sub_path,
            .whole_implib_sub_path = whole_implib_sub_path,
            .emit_asm = options.emit_asm,
            .emit_llvm_ir = options.emit_llvm_ir,
            .emit_llvm_bc = options.emit_llvm_bc,
            .emit_analysis = options.emit_analysis,
            .emit_docs = options.emit_docs,
            .work_queue = std.fifo.LinearFifo(Job, .Dynamic).init(gpa),
            .anon_work_queue = std.fifo.LinearFifo(Job, .Dynamic).init(gpa),
            .c_object_work_queue = std.fifo.LinearFifo(*CObject, .Dynamic).init(gpa),
            .astgen_work_queue = std.fifo.LinearFifo(*Module.File, .Dynamic).init(gpa),
            .embed_file_work_queue = std.fifo.LinearFifo(*Module.EmbedFile, .Dynamic).init(gpa),
            .keep_source_files_loaded = options.keep_source_files_loaded,
            .use_clang = use_clang,
            .clang_argv = options.clang_argv,
            .c_source_files = options.c_source_files,
            .cache_parent = cache,
            .self_exe_path = options.self_exe_path,
            .libc_include_dir_list = libc_dirs.libc_include_dir_list,
            .sanitize_c = sanitize_c,
            .thread_pool = options.thread_pool,
            .clang_passthrough_mode = options.clang_passthrough_mode,
            .clang_preprocessor_mode = options.clang_preprocessor_mode,
            .verbose_cc = options.verbose_cc,
            .verbose_air = options.verbose_air,
            .verbose_llvm_ir = options.verbose_llvm_ir,
            .verbose_cimport = options.verbose_cimport,
            .verbose_llvm_cpu_features = options.verbose_llvm_cpu_features,
            .disable_c_depfile = options.disable_c_depfile,
            .owned_link_dir = owned_link_dir,
            .color = options.color,
            .time_report = options.time_report,
            .stack_report = options.stack_report,
            .unwind_tables = unwind_tables,
            .test_filter = options.test_filter,
            .test_name_prefix = options.test_name_prefix,
            .test_evented_io = options.test_evented_io,
            .debug_compiler_runtime_libs = options.debug_compiler_runtime_libs,
            .debug_compile_errors = options.debug_compile_errors,
        };
        break :comp comp;
    };
    errdefer comp.destroy();

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

    const have_bin_emit = comp.bin_file.options.emit != null or comp.whole_bin_sub_path != null;

    if (have_bin_emit and !comp.bin_file.options.skip_linker_dependencies) {
        if (comp.getTarget().isDarwin()) {
            switch (comp.getTarget().abi) {
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
            if (!target_util.canBuildLibC(comp.getTarget())) return error.LibCUnavailable;

            if (glibc.needsCrtiCrtn(comp.getTarget())) {
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
            if (!target_util.canBuildLibC(comp.getTarget())) return error.LibCUnavailable;

            try comp.work_queue.ensureUnusedCapacity(6);
            if (musl.needsCrtiCrtn(comp.getTarget())) {
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
            if (!target_util.canBuildLibC(comp.getTarget())) return error.LibCUnavailable;

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
            if (!target_util.canBuildLibC(comp.getTarget())) return error.LibCUnavailable;

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
                try comp.bin_file.options.system_libs.put(comp.gpa, name, .{});
            }
        }
        // Generate Windows import libs.
        if (comp.getTarget().os.tag == .windows) {
            const count = comp.bin_file.options.system_libs.count();
            try comp.work_queue.ensureUnusedCapacity(count);
            var i: usize = 0;
            while (i < count) : (i += 1) {
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

        // The `have_llvm` condition is here only because native backends cannot yet build compiler-rt.
        // Once they are capable this condition could be removed. When removing this condition,
        // also test the use case of `build-obj -fcompiler-rt` with the native backends
        // and make sure the compiler-rt symbols are emitted.
        const capable_of_building_compiler_rt = build_options.have_llvm;

        const capable_of_building_zig_libc = build_options.have_llvm;
        const capable_of_building_ssp = comp.bin_file.options.use_stage1;

        if (comp.bin_file.options.include_compiler_rt and capable_of_building_compiler_rt) {
            if (is_exe_or_dyn_lib) {
                log.debug("queuing a job to build compiler_rt_lib", .{});
                comp.job_queued_compiler_rt_lib = true;
            } else if (options.output_mode != .Obj) {
                log.debug("queuing a job to build compiler_rt_obj", .{});
                // If build-obj with -fcompiler-rt is requested, that is handled specially
                // elsewhere. In this case we are making a static library, so we ask
                // for a compiler-rt object to put in it.
                comp.job_queued_compiler_rt_obj = true;
            }
        }
        if (needs_c_symbols) {
            // MinGW provides no libssp, use our own implementation.
            if (comp.getTarget().isMinGW() and capable_of_building_ssp) {
                try comp.work_queue.writeItem(.{ .libssp = {} });
            }

            if (!comp.bin_file.options.link_libc and capable_of_building_zig_libc) {
                try comp.work_queue.writeItem(.{ .zig_libc = {} });
            }
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
    if (self.libssp_static_lib) |*crt_file| {
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

    self.clearMiscFailures();

    self.cache_parent.manifest_dir.close();
    if (self.owned_link_dir) |*dir| dir.close();

    for (self.export_symbol_names.items) |symbol_name| {
        gpa.free(symbol_name);
    }
    self.export_symbol_names.deinit(gpa);

    // This destroys `self`.
    self.arena_state.promote(gpa).deinit();
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
        const builtin_pkg = module.main_pkg.table.get("builtin").?;
        module.zig_cache_artifact_directory = builtin_pkg.root_src_directory;
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

/// Detect changes to source files, perform semantic analysis, and update the output files.
pub fn update(comp: *Compilation) !void {
    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    comp.clearMiscFailures();

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

        comp.whole_cache_manifest = &man;
        man = comp.cache_parent.obtain();
        try comp.addNonIncrementalStuffToCacheManifest(&man);

        const is_hit = man.hit() catch |err| {
            // TODO properly bubble these up instead of emitting a warning
            const i = man.failed_file_index orelse return err;
            const file_path = man.files.items[i].path orelse return err;
            std.log.warn("{s}: {s}", .{ @errorName(err), file_path });
            return err;
        };
        if (is_hit) {
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

        // This updates the output directory for stage1 backend and linker outputs.
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
        comp.bin_file.destroy();
        comp.bin_file = try link.File.openPath(comp.gpa, options);
    }

    // For compiling C objects, we rely on the cache hash system to avoid duplicating work.
    // Add a Job for each C object.
    try comp.c_object_work_queue.ensureUnusedCapacity(comp.c_object_table.count());
    for (comp.c_object_table.keys()) |key| {
        comp.c_object_work_queue.writeItemAssumeCapacity(key);
    }

    const use_stage1 = build_options.omit_stage2 or
        (build_options.is_stage1 and comp.bin_file.options.use_stage1);
    if (comp.bin_file.options.module) |module| {
        module.compile_log_text.shrinkAndFree(module.gpa, 0);
        module.generation += 1;

        // Make sure std.zig is inside the import_table. We unconditionally need
        // it for start.zig.
        const std_pkg = module.main_pkg.table.get("std").?;
        _ = try module.importPkg(std_pkg);

        // Normally we rely on importing std to in turn import the root source file
        // in the start code, but when using the stage1 backend that won't happen,
        // so in order to run AstGen on the root source file we put it into the
        // import_table here.
        // Likewise, in the case of `zig test`, the test runner is the root source file,
        // and so there is nothing to import the main file.
        if (use_stage1 or comp.bin_file.options.is_test) {
            _ = try module.importPkg(module.main_pkg);
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

        if (!use_stage1) {
            // Put a work item in for checking if any files used with `@embedFile` changed.
            {
                try comp.embed_file_work_queue.ensureUnusedCapacity(module.embed_table.count());
                var it = module.embed_table.iterator();
                while (it.next()) |entry| {
                    const embed_file = entry.value_ptr.*;
                    comp.embed_file_work_queue.writeItemAssumeCapacity(embed_file);
                }
            }

            try comp.work_queue.writeItem(.{ .analyze_pkg = std_pkg });
            if (comp.bin_file.options.is_test) {
                try comp.work_queue.writeItem(.{ .analyze_pkg = module.main_pkg });
            }
        }
    }

    // If the terminal is dumb, we dont want to show the user all the output.
    var progress: std.Progress = .{ .dont_print_on_dumb = true };
    const main_progress_node = progress.start("", 0);
    defer main_progress_node.end();
    if (comp.color == .off) progress.terminal = null;

    try comp.performAllTheWork(main_progress_node);

    if (!use_stage1) {
        if (comp.bin_file.options.module) |module| {
            if (comp.bin_file.options.is_test and comp.totalErrorCount() == 0) {
                // The `test_functions` decl has been intentionally postponed until now,
                // at which point we must populate it with the list of test functions that
                // have been discovered and not filtered out.
                try module.populateTestFunctions();
            }

            // Process the deletion set. We use a while loop here because the
            // deletion set may grow as we call `clearDecl` within this loop,
            // and more unreferenced Decls are revealed.
            while (module.deletion_set.count() != 0) {
                const decl_index = module.deletion_set.keys()[0];
                const decl = module.declPtr(decl_index);
                assert(decl.deletion_flag);
                assert(decl.dependants.count() == 0);
                const is_anon = if (decl.zir_decl_index == 0) blk: {
                    break :blk decl.src_namespace.anon_decls.swapRemove(decl_index);
                } else false;

                try module.clearDecl(decl_index, null);

                if (is_anon) {
                    module.destroyDecl(decl_index);
                }
            }

            try module.processExports();
        }
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

        try comp.bin_file.renameTmpIntoCache(comp.local_cache_directory, tmp_dir_sub_path, o_sub_path);
        comp.wholeCacheModeSetBinFilePath(&digest);

        // This is intentionally sandwiched between renameTmpIntoCache() and writeManifest().
        if (comp.bin_file.options.module) |module| {
            // We need to set the zig_cache_artifact_directory for -femit-asm, -femit-llvm-ir,
            // etc to know where to output to.
            var artifact_dir = try comp.local_cache_directory.handle.openDir(o_sub_path, .{});
            defer artifact_dir.close();

            var dir_path = try comp.local_cache_directory.join(comp.gpa, &.{o_sub_path});
            defer comp.gpa.free(dir_path);

            module.zig_cache_artifact_directory = .{
                .handle = artifact_dir,
                .path = dir_path,
            };

            try comp.flush(main_progress_node);
        } else {
            try comp.flush(main_progress_node);
        }

        // Failure here only means an unnecessary cache miss.
        man.writeManifest() catch |err| {
            log.warn("failed to write cache manifest: {s}", .{@errorName(err)});
        };

        assert(comp.bin_file.lock == null);
        comp.bin_file.lock = man.toOwnedLock();
    } else {
        try comp.flush(main_progress_node);
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

fn flush(comp: *Compilation, prog_node: *std.Progress.Node) !void {
    // This is needed before reading the error flags.
    comp.bin_file.flush(comp, prog_node) catch |err| switch (err) {
        error.FlushFailure => {}, // error reported through link_error_flags
        error.LLDReportedFailure => {}, // error reported through log.err
        else => |e| return e,
    };
    comp.link_error_flags = comp.bin_file.errorFlags();

    const use_stage1 = build_options.omit_stage2 or
        (build_options.is_stage1 and comp.bin_file.options.use_stage1);
    if (!use_stage1) {
        if (comp.bin_file.options.module) |module| {
            try link.File.C.flushEmitH(module);
        }
    }
}

/// Communicate the output binary location to parent Compilations.
fn wholeCacheModeSetBinFilePath(comp: *Compilation, digest: *const [Cache.hex_digest_len]u8) void {
    const digest_start = 2; // "o/[digest]/[basename]"

    if (comp.whole_bin_sub_path) |sub_path| {
        mem.copy(u8, sub_path[digest_start..], digest);

        comp.bin_file.options.emit = .{
            .directory = comp.local_cache_directory,
            .sub_path = sub_path,
        };
    }

    if (comp.whole_implib_sub_path) |sub_path| {
        mem.copy(u8, sub_path[digest_start..], digest);

        comp.bin_file.options.implib_emit = .{
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
pub const link_hash_implementation_version = 7;

fn addNonIncrementalStuffToCacheManifest(comp: *Compilation, man: *Cache.Manifest) !void {
    const gpa = comp.gpa;
    const target = comp.getTarget();

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    comptime assert(link_hash_implementation_version == 7);

    if (comp.bin_file.options.module) |mod| {
        const main_zig_file = try mod.main_pkg.root_src_directory.join(arena, &[_][]const u8{
            mod.main_pkg.root_src_path,
        });
        _ = try man.addFile(main_zig_file, null);
        {
            var seen_table = std.AutoHashMap(*Package, void).init(arena);

            // Skip builtin.zig; it is useless as an input, and we don't want to have to
            // write it before checking for a cache hit.
            const builtin_pkg = mod.main_pkg.table.get("builtin").?;
            try seen_table.put(builtin_pkg, {});

            try addPackageTableToCacheHash(&man.hash, &arena_allocator, mod.main_pkg.table, &seen_table, .{ .files = man });
        }

        // Synchronize with other matching comments: ZigOnlyHashStuff
        man.hash.add(comp.bin_file.options.valgrind);
        man.hash.add(comp.bin_file.options.single_threaded);
        man.hash.add(comp.bin_file.options.use_stage1);
        man.hash.add(comp.bin_file.options.use_llvm);
        man.hash.add(comp.bin_file.options.dll_export_fns);
        man.hash.add(comp.bin_file.options.is_test);
        man.hash.add(comp.test_evented_io);
        man.hash.addOptionalBytes(comp.test_filter);
        man.hash.addOptionalBytes(comp.test_name_prefix);
        man.hash.add(comp.bin_file.options.skip_linker_dependencies);
        man.hash.add(comp.bin_file.options.parent_compilation_link_libc);
        man.hash.add(mod.emit_h != null);
    }

    try man.addOptionalFile(comp.bin_file.options.linker_script);
    try man.addOptionalFile(comp.bin_file.options.version_script);

    for (comp.bin_file.options.objects) |obj| {
        _ = try man.addFile(obj.path, null);
        man.hash.add(obj.must_link);
    }

    for (comp.c_object_table.keys()) |key| {
        _ = try man.addFile(key.src.src_path, null);
        man.hash.addListOfBytes(key.src.extra_flags);
    }

    man.hash.addOptionalEmitLoc(comp.emit_asm);
    man.hash.addOptionalEmitLoc(comp.emit_llvm_ir);
    man.hash.addOptionalEmitLoc(comp.emit_llvm_bc);
    man.hash.addOptionalEmitLoc(comp.emit_analysis);
    man.hash.addOptionalEmitLoc(comp.emit_docs);

    man.hash.addListOfBytes(comp.clang_argv);

    man.hash.addOptional(comp.bin_file.options.stack_size_override);
    man.hash.addOptional(comp.bin_file.options.image_base_override);
    man.hash.addOptional(comp.bin_file.options.gc_sections);
    man.hash.add(comp.bin_file.options.eh_frame_hdr);
    man.hash.add(comp.bin_file.options.emit_relocs);
    man.hash.add(comp.bin_file.options.rdynamic);
    man.hash.addListOfBytes(comp.bin_file.options.lib_dirs);
    man.hash.addListOfBytes(comp.bin_file.options.rpath_list);
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
    man.hash.add(comp.bin_file.options.hash_style);
    man.hash.add(comp.bin_file.options.compress_debug_sections);
    man.hash.add(comp.bin_file.options.include_compiler_rt);
    if (comp.bin_file.options.link_libc) {
        man.hash.add(comp.bin_file.options.libc_installation != null);
        if (comp.bin_file.options.libc_installation) |libc_installation| {
            man.hash.addBytes(libc_installation.crt_dir.?);
            if (target.abi == .msvc) {
                man.hash.addBytes(libc_installation.msvc_lib_dir.?);
                man.hash.addBytes(libc_installation.kernel32_lib_dir.?);
            }
        }
        man.hash.addOptionalBytes(comp.bin_file.options.dynamic_linker);
    }
    man.hash.addOptionalBytes(comp.bin_file.options.soname);
    man.hash.addOptional(comp.bin_file.options.version);
    link.hashAddSystemLibs(&man.hash, comp.bin_file.options.system_libs);
    man.hash.addOptional(comp.bin_file.options.allow_shlib_undefined);
    man.hash.add(comp.bin_file.options.bind_global_refs_locally);
    man.hash.add(comp.bin_file.options.tsan);
    man.hash.addOptionalBytes(comp.bin_file.options.sysroot);
    man.hash.add(comp.bin_file.options.linker_optimization);

    // WASM specific stuff
    man.hash.add(comp.bin_file.options.import_memory);
    man.hash.addOptional(comp.bin_file.options.initial_memory);
    man.hash.addOptional(comp.bin_file.options.max_memory);
    man.hash.add(comp.bin_file.options.shared_memory);
    man.hash.addOptional(comp.bin_file.options.global_base);

    // Mach-O specific stuff
    man.hash.addListOfBytes(comp.bin_file.options.framework_dirs);
    link.hashAddSystemLibs(&man.hash, comp.bin_file.options.frameworks);
    try man.addOptionalFile(comp.bin_file.options.entitlements);
    man.hash.addOptional(comp.bin_file.options.pagezero_size);
    man.hash.addOptional(comp.bin_file.options.search_strategy);
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

/// This function is temporally single-threaded.
pub fn totalErrorCount(self: *Compilation) usize {
    var total: usize = self.failed_c_objects.count() + self.misc_failures.count() +
        @boolToInt(self.alloc_failure_occurred);

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
                    const payload_index = file.zir.extra[@enumToInt(Zir.ExtraIndex.compile_errors)];
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
            const decl = module.declPtr(key);
            if (decl.getFileScope().okToReportErrors()) {
                total += 1;
            }
        }
        if (module.emit_h) |emit_h| {
            for (emit_h.failed_decls.keys()) |key| {
                const decl = module.declPtr(key);
                if (decl.getFileScope().okToReportErrors()) {
                    total += 1;
                }
            }
        }
    }

    // The "no entry point found" error only counts if there are no semantic analysis errors.
    if (total == 0) {
        total += @boolToInt(self.link_error_flags.no_entry_point_found);
    }
    total += @boolToInt(self.link_error_flags.missing_libc);

    // Compile log errors only count if there are no other errors.
    if (total == 0) {
        if (self.bin_file.options.module) |module| {
            total += @boolToInt(module.compile_log_decls.count() != 0);
        }
    }

    return total;
}

/// This function is temporally single-threaded.
pub fn getAllErrorsAlloc(self: *Compilation) !AllErrors {
    var arena = std.heap.ArenaAllocator.init(self.gpa);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    var errors = std.ArrayList(AllErrors.Message).init(self.gpa);
    defer errors.deinit();

    {
        var it = self.failed_c_objects.iterator();
        while (it.next()) |entry| {
            const c_object = entry.key_ptr.*;
            const err_msg = entry.value_ptr.*;
            // TODO these fields will need to be adjusted when we have proper
            // C error reporting bubbling up.
            try errors.append(.{
                .src = .{
                    .src_path = try arena_allocator.dupe(u8, c_object.src.src_path),
                    .msg = try std.fmt.allocPrint(arena_allocator, "unable to build C object: {s}", .{
                        err_msg.msg,
                    }),
                    .span = .{ .start = 0, .end = 1, .main = 0 },
                    .line = err_msg.line,
                    .column = err_msg.column,
                    .source_line = null, // TODO
                },
            });
        }
    }
    for (self.misc_failures.values()) |*value| {
        try AllErrors.addPlainWithChildren(&arena, &errors, value.msg, value.children);
    }
    if (self.alloc_failure_occurred) {
        try AllErrors.addPlain(&arena, &errors, "memory allocation failure");
    }
    if (self.bin_file.options.module) |module| {
        {
            var it = module.failed_files.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.*) |msg| {
                    try AllErrors.add(module, &arena, &errors, msg.*);
                } else {
                    // Must be ZIR errors. In order for ZIR errors to exist, the parsing
                    // must have completed successfully.
                    const tree = try entry.key_ptr.*.getTree(module.gpa);
                    assert(tree.errors.len == 0);
                    try AllErrors.addZir(arena_allocator, &errors, entry.key_ptr.*);
                }
            }
        }
        {
            var it = module.failed_embed_files.iterator();
            while (it.next()) |entry| {
                const msg = entry.value_ptr.*;
                try AllErrors.add(module, &arena, &errors, msg.*);
            }
        }
        {
            var it = module.failed_decls.iterator();
            while (it.next()) |entry| {
                const decl = module.declPtr(entry.key_ptr.*);
                // Skip errors for Decls within files that had a parse failure.
                // We'll try again once parsing succeeds.
                if (decl.getFileScope().okToReportErrors()) {
                    try AllErrors.add(module, &arena, &errors, entry.value_ptr.*.*);
                }
            }
        }
        if (module.emit_h) |emit_h| {
            var it = emit_h.failed_decls.iterator();
            while (it.next()) |entry| {
                const decl = module.declPtr(entry.key_ptr.*);
                // Skip errors for Decls within files that had a parse failure.
                // We'll try again once parsing succeeds.
                if (decl.getFileScope().okToReportErrors()) {
                    try AllErrors.add(module, &arena, &errors, entry.value_ptr.*.*);
                }
            }
        }
        for (module.failed_exports.values()) |value| {
            try AllErrors.add(module, &arena, &errors, value.*);
        }
    }

    if (errors.items.len == 0) {
        if (self.link_error_flags.no_entry_point_found) {
            try errors.append(.{
                .plain = .{
                    .msg = try std.fmt.allocPrint(arena_allocator, "no entry point found", .{}),
                },
            });
        }
    }

    if (self.link_error_flags.missing_libc) {
        const notes = try arena_allocator.create([2]AllErrors.Message);
        notes.* = .{
            .{ .plain = .{
                .msg = try arena_allocator.dupe(u8, "run 'zig libc -h' to learn about libc installations"),
            } },
            .{ .plain = .{
                .msg = try arena_allocator.dupe(u8, "run 'zig targets' to see the targets for which zig can always provide libc"),
            } },
        };
        try errors.append(.{
            .plain = .{
                .msg = try std.fmt.allocPrint(arena_allocator, "libc not available", .{}),
                .notes = notes,
            },
        });
    }

    if (self.bin_file.options.module) |module| {
        if (errors.items.len == 0 and module.compile_log_decls.count() != 0) {
            const keys = module.compile_log_decls.keys();
            const values = module.compile_log_decls.values();
            // First one will be the error; subsequent ones will be notes.
            const err_decl = module.declPtr(keys[0]);
            const src_loc = err_decl.nodeOffsetSrcLoc(values[0]);
            const err_msg = Module.ErrorMsg{
                .src_loc = src_loc,
                .msg = "found compile log statement",
                .notes = try self.gpa.alloc(Module.ErrorMsg, module.compile_log_decls.count() - 1),
            };
            defer self.gpa.free(err_msg.notes);

            for (keys[1..]) |key, i| {
                const note_decl = module.declPtr(key);
                err_msg.notes[i] = .{
                    .src_loc = note_decl.nodeOffsetSrcLoc(values[i + 1]),
                    .msg = "also here",
                };
            }

            try AllErrors.add(module, &arena, &errors, err_msg);
        }
    }

    assert(errors.items.len == self.totalErrorCount());

    return AllErrors{
        .list = try arena_allocator.dupe(AllErrors.Message, errors.items),
        .arena = arena.state,
    };
}

pub fn getCompileLogOutput(self: *Compilation) []const u8 {
    const module = self.bin_file.options.module orelse return &[0]u8{};
    return module.compile_log_text.items;
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

    var embed_file_prog_node = main_progress_node.start("Detect @embedFile updates", comp.embed_file_work_queue.count);
    defer embed_file_prog_node.end();

    comp.work_queue_wait_group.reset();
    defer comp.work_queue_wait_group.wait();

    const use_stage1 = build_options.is_stage1 and comp.bin_file.options.use_stage1;

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
                comp, embed_file, &embed_file_prog_node, &comp.astgen_wait_group,
            });
        }

        while (comp.c_object_work_queue.readItem()) |c_object| {
            comp.work_queue_wait_group.start();
            try comp.thread_pool.spawn(workerUpdateCObject, .{
                comp, c_object, &c_obj_prog_node, &comp.work_queue_wait_group,
            });
        }
    }

    if (!use_stage1) {
        const outdated_and_deleted_decls_frame = tracy.namedFrame("outdated_and_deleted_decls");
        defer outdated_and_deleted_decls_frame.end();

        // Iterate over all the files and look for outdated and deleted declarations.
        if (comp.bin_file.options.module) |mod| {
            try mod.processOutdatedAndDeletedDecls();
        }
    } else if (comp.bin_file.options.module) |mod| {
        // If there are any AstGen compile errors, report them now to avoid
        // hitting stage1 bugs.
        if (mod.failed_files.count() != 0) {
            return;
        }
        comp.updateStage1Module(main_progress_node) catch |err| {
            fatal("unable to build stage1 zig object: {s}", .{@errorName(err)});
        };
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
            try processOneJob(comp, work_item);
            continue;
        }
        if (comp.anon_work_queue.readItem()) |work_item| {
            try processOneJob(comp, work_item);
            continue;
        }
        break;
    }

    if (comp.job_queued_compiler_rt_lib) {
        comp.job_queued_compiler_rt_lib = false;
        buildCompilerRtOneShot(comp, .Lib, &comp.compiler_rt_lib);
    }

    if (comp.job_queued_compiler_rt_obj) {
        comp.job_queued_compiler_rt_obj = false;
        buildCompilerRtOneShot(comp, .Obj, &comp.compiler_rt_obj);
    }
}

fn processOneJob(comp: *Compilation, job: Job) !void {
    switch (job) {
        .codegen_decl => |decl_index| {
            if (build_options.omit_stage2)
                @panic("sadly stage2 is omitted from this build to save memory on the CI server");

            const module = comp.bin_file.options.module.?;
            const decl = module.declPtr(decl_index);

            switch (decl.analysis) {
                .unreferenced => unreachable,
                .in_progress => unreachable,
                .outdated => unreachable,

                .file_failure,
                .sema_failure,
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
            if (build_options.omit_stage2)
                @panic("sadly stage2 is omitted from this build to save memory on the CI server");

            const named_frame = tracy.namedFrame("codegen_func");
            defer named_frame.end();

            const module = comp.bin_file.options.module.?;
            module.ensureFuncBodyAnalyzed(func) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => return,
            };
        },
        .emit_h_decl => |decl_index| {
            if (build_options.omit_stage2)
                @panic("sadly stage2 is omitted from this build to save memory on the CI server");

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
                .codegen_failure, .codegen_failure_retryable, .complete => {
                    const named_frame = tracy.namedFrame("emit_h_decl");
                    defer named_frame.end();

                    const gpa = comp.gpa;
                    const emit_h = module.emit_h.?;
                    _ = try emit_h.decl_table.getOrPut(gpa, decl_index);
                    const decl_emit_h = emit_h.declPtr(decl_index);
                    const fwd_decl = &decl_emit_h.fwd_decl;
                    fwd_decl.shrinkRetainingCapacity(0);
                    var typedefs_arena = std.heap.ArenaAllocator.init(gpa);
                    defer typedefs_arena.deinit();

                    var dg: c_codegen.DeclGen = .{
                        .gpa = gpa,
                        .module = module,
                        .error_msg = null,
                        .decl_index = decl_index,
                        .decl = decl,
                        .fwd_decl = fwd_decl.toManaged(gpa),
                        .typedefs = c_codegen.TypedefMap.initContext(gpa, .{
                            .mod = module,
                        }),
                        .typedefs_arena = typedefs_arena.allocator(),
                    };
                    defer dg.fwd_decl.deinit();
                    defer dg.typedefs.deinit();

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
            if (build_options.omit_stage2)
                @panic("sadly stage2 is omitted from this build to save memory on the CI server");

            const module = comp.bin_file.options.module.?;
            module.ensureDeclAnalyzed(decl_index) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => return,
            };
        },
        .update_embed_file => |embed_file| {
            if (build_options.omit_stage2)
                @panic("sadly stage2 is omitted from this build to save memory on the CI server");

            const named_frame = tracy.namedFrame("update_embed_file");
            defer named_frame.end();

            const module = comp.bin_file.options.module.?;
            module.updateEmbedFile(embed_file) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => return,
            };
        },
        .update_line_number => |decl_index| {
            if (build_options.omit_stage2)
                @panic("sadly stage2 is omitted from this build to save memory on the CI server");

            const named_frame = tracy.namedFrame("update_line_number");
            defer named_frame.end();

            const gpa = comp.gpa;
            const module = comp.bin_file.options.module.?;
            const decl = module.declPtr(decl_index);
            comp.bin_file.updateDeclLineNumber(module, decl) catch |err| {
                try module.failed_decls.ensureUnusedCapacity(gpa, 1);
                module.failed_decls.putAssumeCapacityNoClobber(decl_index, try Module.ErrorMsg.create(
                    gpa,
                    decl.srcLoc(),
                    "unable to update line number: {s}",
                    .{@errorName(err)},
                ));
                decl.analysis = .codegen_failure_retryable;
            };
        },
        .analyze_pkg => |pkg| {
            if (build_options.omit_stage2)
                @panic("sadly stage2 is omitted from this build to save memory on the CI server");

            const named_frame = tracy.namedFrame("analyze_pkg");
            defer named_frame.end();

            const module = comp.bin_file.options.module.?;
            module.semaPkg(pkg) catch |err| switch (err) {
                error.CurrentWorkingDirectoryUnlinked,
                error.Unexpected,
                => comp.lockAndSetMiscFailure(
                    .analyze_pkg,
                    "unexpected problem analyzing package '{s}'",
                    .{pkg.root_src_path},
                ),
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => return,
            };
        },
        .glibc_crt_file => |crt_file| {
            const named_frame = tracy.namedFrame("glibc_crt_file");
            defer named_frame.end();

            glibc.buildCRTFile(comp, crt_file) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(.glibc_crt_file, "unable to build glibc CRT file: {s}", .{
                    @errorName(err),
                });
            };
        },
        .glibc_shared_objects => {
            const named_frame = tracy.namedFrame("glibc_shared_objects");
            defer named_frame.end();

            glibc.buildSharedObjects(comp) catch |err| {
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

            musl.buildCRTFile(comp, crt_file) catch |err| {
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

            mingw.buildCRTFile(comp, crt_file) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(
                    .mingw_crt_file,
                    "unable to build mingw-w64 CRT file: {s}",
                    .{@errorName(err)},
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
                    "unable to generate DLL import .lib file: {s}",
                    .{@errorName(err)},
                );
            };
        },
        .libunwind => {
            const named_frame = tracy.namedFrame("libunwind");
            defer named_frame.end();

            libunwind.buildStaticLib(comp) catch |err| {
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

            libcxx.buildLibCXX(comp) catch |err| {
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

            libcxx.buildLibCXXABI(comp) catch |err| {
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

            libtsan.buildTsan(comp) catch |err| {
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

            wasi_libc.buildCRTFile(comp, crt_file) catch |err| {
                // TODO Surface more error details.
                comp.lockAndSetMiscFailure(
                    .wasi_libc_crt_file,
                    "unable to build WASI libc CRT file: {s}",
                    .{@errorName(err)},
                );
            };
        },
        .libssp => {
            const named_frame = tracy.namedFrame("libssp");
            defer named_frame.end();

            comp.buildOutputFromZig(
                "ssp.zig",
                .Lib,
                &comp.libssp_static_lib,
                .libssp,
            ) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.SubCompilationFailed => return, // error reported already
                else => comp.lockAndSetMiscFailure(
                    .libssp,
                    "unable to build libssp: {s}",
                    .{@errorName(err)},
                ),
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
    const imports_index = file.zir.extra[@enumToInt(Zir.ExtraIndex.imports)];
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

                break :blk mod.importFile(file, import_path) catch continue;
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
    prog_node: *std.Progress.Node,
    wg: *WaitGroup,
) void {
    defer wg.finish();

    var child_prog_node = prog_node.start(embed_file.sub_file_path, 0);
    child_prog_node.activate();
    defer child_prog_node.end();

    const mod = comp.bin_file.options.module.?;
    mod.detectEmbedFileUpdate(embed_file) catch |err| {
        comp.reportRetryableEmbedFileError(embed_file, err) catch |oom| switch (oom) {
            // Swallowing this error is OK because it's implied to be OOM when
            // there is a missing `failed_embed_files` error message.
            error.OutOfMemory => {},
        };
        return;
    };
}

pub fn obtainCObjectCacheManifest(comp: *const Compilation) Cache.Manifest {
    var man = comp.cache_parent.obtain();

    // Only things that need to be added on top of the base hash, and only things
    // that apply both to @cImport and compiling C objects. No linking stuff here!
    // Also nothing that applies only to compiling .zig code.
    man.hash.add(comp.sanitize_c);
    man.hash.addListOfBytes(comp.clang_argv);
    man.hash.add(comp.bin_file.options.link_libcpp);
    man.hash.addListOfBytes(comp.libc_include_dir_list);

    return man;
}

test "cImport" {
    _ = cImport;
}

const CImportResult = struct {
    out_zig_path: []u8,
    errors: []translate_c.ClangErrMsg,
};

/// Caller owns returned memory.
/// This API is currently coupled pretty tightly to stage1's needs; it will need to be reworked
/// a bit when we want to start using it from self-hosted.
pub fn cImport(comp: *Compilation, c_src: []const u8) !CImportResult {
    if (!build_options.have_llvm)
        return error.ZigCompilerNotBuiltWithLLVMExtensions;

    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    const cimport_zig_basename = "cimport.zig";

    var man = comp.obtainCObjectCacheManifest();
    defer man.deinit();

    const use_stage1 = build_options.is_stage1 and comp.bin_file.options.use_stage1;

    man.hash.add(@as(u16, 0xb945)); // Random number to distinguish translate-c from compiling C objects
    man.hash.add(use_stage1);
    man.hash.addBytes(c_src);

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

        try argv.append(""); // argv[0] is program name, actual args start at [1]
        try comp.addTranslateCCArgs(arena, &argv, .c, out_dep_path);

        try argv.append(out_h_path);

        if (comp.verbose_cc) {
            dump_argv(argv.items);
        }

        // Convert to null terminated args.
        const new_argv_with_sentinel = try arena.alloc(?[*:0]const u8, argv.items.len + 1);
        new_argv_with_sentinel[argv.items.len] = null;
        const new_argv = new_argv_with_sentinel[0..argv.items.len :null];
        for (argv.items) |arg, i| {
            new_argv[i] = try arena.dupeZ(u8, arg);
        }

        const c_headers_dir_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{"include"});
        const c_headers_dir_path_z = try arena.dupeZ(u8, c_headers_dir_path);
        var clang_errors: []translate_c.ClangErrMsg = &[0]translate_c.ClangErrMsg{};
        var tree = translate_c.translate(
            comp.gpa,
            new_argv.ptr,
            new_argv.ptr + new_argv.len,
            &clang_errors,
            c_headers_dir_path_z,
            use_stage1,
        ) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.ASTUnitFailure => {
                log.warn("clang API returned errors but due to a clang bug, it is not exposing the errors for zig to see. For more details: https://github.com/ziglang/zig/issues/4455", .{});
                return error.ASTUnitFailure;
            },
            error.SemanticAnalyzeFail => {
                return CImportResult{
                    .out_zig_path = "",
                    .errors = clang_errors,
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

    // Write the updated manifest. This is a no-op if the manifest is not dirty. Note that it is
    // possible we had a hit and the manifest is dirty, for example if the file mtime changed but
    // the contents were the same, we hit the cache but the manifest is dirty and we need to update
    // it to prevent doing a full file content comparison the next time around.
    man.writeManifest() catch |err| {
        log.warn("failed to write cache manifest for C import: {s}", .{@errorName(err)});
    };

    const out_zig_path = try comp.local_cache_directory.join(comp.gpa, &[_][]const u8{
        "o", &digest, cimport_zig_basename,
    });
    if (comp.verbose_cimport) {
        log.info("C import output: {s}", .{out_zig_path});
    }
    return CImportResult{
        .out_zig_path = out_zig_path,
        .errors = &[0]translate_c.ClangErrMsg{},
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

fn buildCompilerRtOneShot(
    comp: *Compilation,
    output_mode: std.builtin.OutputMode,
    out: *?CRTFile,
) void {
    comp.buildOutputFromZig("compiler_rt.zig", output_mode, out, .compiler_rt) catch |err| switch (err) {
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

    const c_obj_err_msg = try comp.gpa.create(CObject.ErrorMsg);
    errdefer comp.gpa.destroy(c_obj_err_msg);
    const msg = try std.fmt.allocPrint(comp.gpa, "{s}", .{@errorName(err)});
    errdefer comp.gpa.free(msg);
    c_obj_err_msg.* = .{
        .msg = msg,
        .line = 0,
        .column = 0,
    };
    {
        comp.mutex.lock();
        defer comp.mutex.unlock();
        try comp.failed_c_objects.putNoClobber(comp.gpa, c_object, c_obj_err_msg);
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

    const err_msg = if (file.pkg.root_src_directory.path) |dir_path|
        try Module.ErrorMsg.create(
            gpa,
            src_loc,
            "unable to load '{s}" ++ std.fs.path.sep_str ++ "{s}': {s}",
            .{ dir_path, file.sub_file_path, @errorName(err) },
        )
    else
        try Module.ErrorMsg.create(gpa, src_loc, "unable to load '{s}': {s}", .{
            file.sub_file_path, @errorName(err),
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

    const src_loc: Module.SrcLoc = mod.declPtr(embed_file.owner_decl).srcLoc();

    const err_msg = if (embed_file.pkg.root_src_directory.path) |dir_path|
        try Module.ErrorMsg.create(
            gpa,
            src_loc,
            "unable to load '{s}" ++ std.fs.path.sep_str ++ "{s}': {s}",
            .{ dir_path, embed_file.sub_file_path, @errorName(err) },
        )
    else
        try Module.ErrorMsg.create(gpa, src_loc, "unable to load '{s}': {s}", .{
            embed_file.sub_file_path, @errorName(err),
        });
    errdefer err_msg.destroy(gpa);

    {
        comp.mutex.lock();
        defer comp.mutex.unlock();
        try mod.failed_embed_files.putNoClobber(gpa, embed_file, err_msg);
    }
}

fn updateCObject(comp: *Compilation, c_object: *CObject, c_obj_prog_node: *std.Progress.Node) !void {
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
    man.hash.addOptionalEmitLoc(comp.emit_asm);
    man.hash.addOptionalEmitLoc(comp.emit_llvm_ir);
    man.hash.addOptionalEmitLoc(comp.emit_llvm_bc);

    try man.hashCSource(c_object.src);

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

    const o_ext = comp.bin_file.options.object_format.fileExt(comp.bin_file.options.target.cpu.arch);
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

        // We can't know the digest until we do the C compiler invocation,
        // so we need a temporary filename.
        const out_obj_path = try comp.tmpFilePath(arena, o_basename);
        var zig_cache_tmp_dir = try comp.local_cache_directory.handle.makeOpenPath("tmp", .{});
        defer zig_cache_tmp_dir.close();

        try argv.appendSlice(&[_][]const u8{ self_exe_path, "clang" });

        const ext = classifyFileExt(c_object.src.src_path);
        const out_dep_path: ?[]const u8 = if (comp.disable_c_depfile or !ext.clangSupportsDepFile())
            null
        else
            try std.fmt.allocPrint(arena, "{s}.d", .{out_obj_path});
        try comp.addCCArgs(arena, &argv, ext, out_dep_path);

        try argv.ensureUnusedCapacity(6 + c_object.src.extra_flags.len);
        switch (comp.clang_preprocessor_mode) {
            .no => argv.appendSliceAssumeCapacity(&[_][]const u8{ "-c", "-o", out_obj_path }),
            .yes => argv.appendSliceAssumeCapacity(&[_][]const u8{ "-E", "-o", out_obj_path }),
            .stdout => argv.appendAssumeCapacity("-E"),
        }
        if (comp.clang_passthrough_mode) {
            if (comp.emit_asm != null) {
                argv.appendAssumeCapacity("-S");
            } else if (comp.emit_llvm_ir != null) {
                argv.appendSliceAssumeCapacity(&[_][]const u8{ "-emit-llvm", "-S" });
            } else if (comp.emit_llvm_bc != null) {
                argv.appendAssumeCapacity("-emit-llvm");
            }
        }
        argv.appendAssumeCapacity(c_object.src.src_path);
        argv.appendSliceAssumeCapacity(c_object.src.extra_flags);

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

                const stderr_reader = child.stderr.?.reader();

                const stderr = try stderr_reader.readAllAlloc(arena, 10 * 1024 * 1024);

                const term = child.wait() catch |err| {
                    return comp.failCObj(c_object, "unable to spawn {s}: {s}", .{ argv.items[0], @errorName(err) });
                };

                switch (term) {
                    .Exited => |code| {
                        if (code != 0) {
                            // TODO parse clang stderr and turn it into an error message
                            // and then call failCObjWithOwnedErrorMsg
                            log.err("clang failed with stderr: {s}", .{stderr});
                            return comp.failCObj(c_object, "clang exited with code {d}", .{code});
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

    // Write the updated manifest. This is a no-op if the manifest is not dirty. Note that it is
    // possible we had a hit and the manifest is dirty, for example if the file mtime changed but
    // the contents were the same, we hit the cache but the manifest is dirty and we need to update
    // it to prevent doing a full file content comparison the next time around.
    man.writeManifest() catch |err| {
        log.warn("failed to write cache manifest when compiling '{s}': {s}", .{ c_object.src.src_path, @errorName(err) });
    };

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

    switch (ext) {
        .c, .cpp, .m, .mm, .h, .cu => {
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
            for (all_features_list) |feature, index_usize| {
                const index = @intCast(std.Target.Cpu.Feature.Set.Index, index_usize);
                const is_enabled = target.cpu.features.isEnabled(index);

                if (feature.llvm_name) |llvm_name| {
                    argv.appendSliceAssumeCapacity(&[_][]const u8{ "-Xclang", "-target-feature", "-Xclang" });
                    const plus_or_minus = "-+"[@boolToInt(is_enabled)];
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
                    // Pass the proper -m<os>-version-min argument for darwin.
                    const ver = target.os.version_range.semver.min;
                    try argv.append(try std.fmt.allocPrint(arena, "-mmacos-version-min={d}.{d}.{d}", .{
                        ver.major, ver.minor, ver.patch,
                    }));
                },
                .ios, .tvos, .watchos => switch (target.cpu.arch) {
                    // Pass the proper -m<os>-version-min argument for darwin.
                    .i386, .x86_64 => {
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

            if (!comp.bin_file.options.strip) {
                try argv.append("-g");
                switch (comp.bin_file.options.object_format) {
                    .coff => try argv.append("-gcodeview"),
                    else => {},
                }
            }

            if (target.cpu.arch.isThumb()) {
                try argv.append("-mthumb");
            }

            if (comp.sanitize_c and !comp.bin_file.options.tsan) {
                try argv.append("-fsanitize=undefined");
                try argv.append("-fsanitize-trap=undefined");
            } else if (comp.sanitize_c and comp.bin_file.options.tsan) {
                try argv.append("-fsanitize=undefined,thread");
                try argv.append("-fsanitize-trap=undefined");
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

            switch (comp.bin_file.options.optimize_mode) {
                .Debug => {
                    // windows c runtime requires -D_DEBUG if using debug libraries
                    try argv.append("-D_DEBUG");
                    // Clang has -Og for compatibility with GCC, but currently it is just equivalent
                    // to -O1. Besides potentially impairing debugging, -O1/-Og significantly
                    // increases compile times.
                    try argv.append("-O0");

                    if (comp.bin_file.options.link_libc and target.os.tag != .wasi) {
                        try argv.append("-fstack-protector-strong");
                        try argv.append("--param");
                        try argv.append("ssp-buffer-size=4");
                    } else {
                        try argv.append("-fno-stack-protector");
                    }
                },
                .ReleaseSafe => {
                    // See the comment in the BuildModeFastRelease case for why we pass -O2 rather
                    // than -O3 here.
                    try argv.append("-O2");
                    if (comp.bin_file.options.link_libc and target.os.tag != .wasi) {
                        try argv.append("-D_FORTIFY_SOURCE=2");
                        try argv.append("-fstack-protector-strong");
                        try argv.append("--param");
                        try argv.append("ssp-buffer-size=4");
                    } else {
                        try argv.append("-fno-stack-protector");
                    }
                },
                .ReleaseFast => {
                    try argv.append("-DNDEBUG");
                    // Here we pass -O2 rather than -O3 because, although we do the equivalent of
                    // -O3 in Zig code, the justification for the difference here is that Zig
                    // has better detection and prevention of undefined behavior, so -O3 is safer for
                    // Zig code than it is for C code. Also, C programmers are used to their code
                    // running in -O2 and thus the -O3 path has been tested less.
                    try argv.append("-O2");
                    try argv.append("-fno-stack-protector");
                },
                .ReleaseSmall => {
                    try argv.append("-DNDEBUG");
                    try argv.append("-Os");
                    try argv.append("-fno-stack-protector");
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
        .shared_library, .ll, .bc, .unknown, .static_library, .object, .zig => {},
        .assembly => {
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
                    mem.copy(u8, &march_buf, prefix);

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

fn failCObj(comp: *Compilation, c_object: *CObject, comptime format: []const u8, args: anytype) SemaError {
    @setCold(true);
    const err_msg = blk: {
        const msg = try std.fmt.allocPrint(comp.gpa, format, args);
        errdefer comp.gpa.free(msg);
        const err_msg = try comp.gpa.create(CObject.ErrorMsg);
        errdefer comp.gpa.destroy(err_msg);
        err_msg.* = .{
            .msg = msg,
            .line = 0,
            .column = 0,
        };
        break :blk err_msg;
    };
    return comp.failCObjWithOwnedErrorMsg(c_object, err_msg);
}

fn failCObjWithOwnedErrorMsg(
    comp: *Compilation,
    c_object: *CObject,
    err_msg: *CObject.ErrorMsg,
) SemaError {
    @setCold(true);
    {
        comp.mutex.lock();
        defer comp.mutex.unlock();
        {
            errdefer err_msg.destroy(comp.gpa);
            try comp.failed_c_objects.ensureUnusedCapacity(comp.gpa, 1);
        }
        comp.failed_c_objects.putAssumeCapacityNoClobber(c_object, err_msg);
    }
    c_object.status = .failure;
    return error.AnalysisFail;
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
    shared_library,
    object,
    static_library,
    zig,
    unknown,

    pub fn clangSupportsDepFile(ext: FileExt) bool {
        return switch (ext) {
            .c, .cpp, .h, .m, .mm, .cu => true,

            .ll,
            .bc,
            .assembly,
            .shared_library,
            .object,
            .static_library,
            .zig,
            .unknown,
            => false,
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

pub fn hasAsmExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".s") or mem.endsWith(u8, filename, ".S");
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
    var it = mem.split(u8, filename, ".");
    _ = it.next().?;
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
    } else if (hasAsmExt(filename)) {
        return .assembly;
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
};

fn getZigShippedLibCIncludeDirsDarwin(arena: Allocator, zig_lib_dir: []const u8, target: Target) !LibCDirs {
    const arch_name = @tagName(target.cpu.arch);
    const os_name = try std.fmt.allocPrint(arena, "{s}.{d}", .{
        @tagName(target.os.tag),
        target.os.version_range.semver.min.major,
    });
    const s = std.fs.path.sep_str;
    const list = try arena.alloc([]const u8, 3);

    list[0] = try std.fmt.allocPrint(
        arena,
        "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{s}-{s}-none",
        .{ zig_lib_dir, arch_name, os_name },
    );
    list[1] = try std.fmt.allocPrint(
        arena,
        "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "any-{s}-any",
        .{ zig_lib_dir, os_name },
    );
    list[2] = try std.fmt.allocPrint(
        arena,
        "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "any-macos-any",
        .{zig_lib_dir},
    );

    return LibCDirs{
        .libc_include_dir_list = list,
        .libc_installation = null,
    };
}

fn detectLibCIncludeDirs(
    arena: Allocator,
    zig_lib_dir: []const u8,
    target: Target,
    is_native_abi: bool,
    link_libc: bool,
    link_system_libs: bool,
    libc_installation: ?*const LibCInstallation,
    has_macos_sdk: bool,
) !LibCDirs {
    if (!link_libc) {
        return LibCDirs{
            .libc_include_dir_list = &[0][]u8{},
            .libc_installation = null,
        };
    }

    if (libc_installation) |lci| {
        return detectLibCFromLibCInstallation(arena, target, lci);
    }

    // If linking system libraries and targeting the native abi, default to
    // using the system libc installation.
    if (link_system_libs and is_native_abi and !target.isMinGW()) {
        if (target.isDarwin()) {
            return if (has_macos_sdk)
                // For Darwin/macOS, we are all set with getDarwinSDK found earlier.
                LibCDirs{
                    .libc_include_dir_list = &[0][]u8{},
                    .libc_installation = null,
                }
            else
                getZigShippedLibCIncludeDirsDarwin(arena, zig_lib_dir, target);
        }
        const libc = try arena.create(LibCInstallation);
        libc.* = try LibCInstallation.findNative(.{ .allocator = arena, .verbose = true });
        return detectLibCFromLibCInstallation(arena, target, libc);
    }

    // If not linking system libraries, build and provide our own libc by
    // default if possible.
    if (target_util.canBuildLibC(target)) {
        switch (target.os.tag) {
            .macos => return if (has_macos_sdk)
                // For Darwin/macOS, we are all set with getDarwinSDK found earlier.
                LibCDirs{
                    .libc_include_dir_list = &[0][]u8{},
                    .libc_installation = null,
                }
            else
                getZigShippedLibCIncludeDirsDarwin(arena, zig_lib_dir, target),
            else => {
                const generic_name = target_util.libCGenericName(target);
                // Some architectures are handled by the same set of headers.
                const arch_name = if (target.abi.isMusl())
                    musl.archName(target.cpu.arch)
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
                };
            },
        }
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
        libc.* = try LibCInstallation.findNative(.{ .allocator = arena, .verbose = true });
        return detectLibCFromLibCInstallation(arena, target, libc);
    }

    return LibCDirs{
        .libc_include_dir_list = &[0][]u8{},
        .libc_installation = null,
    };
}

fn detectLibCFromLibCInstallation(arena: Allocator, target: Target, lci: *const LibCInstallation) !LibCDirs {
    var list = try std.ArrayList([]const u8).initCapacity(arena, 5);

    list.appendAssumeCapacity(lci.include_dir.?);

    const is_redundant = mem.eql(u8, lci.sys_include_dir.?, lci.include_dir.?);
    if (!is_redundant) list.appendAssumeCapacity(lci.sys_include_dir.?);

    if (target.os.tag == .windows) {
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

    return LibCDirs{
        .libc_include_dir_list = list.items,
        .libc_installation = lci,
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
        comp.bin_file.options.object_format != .c;
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
        comp.bin_file.options.object_format != .c;
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

pub fn dump_argv(argv: []const []const u8) void {
    for (argv[0 .. argv.len - 1]) |arg| {
        std.debug.print("{s} ", .{arg});
    }
    std.debug.print("{s}\n", .{argv[argv.len - 1]});
}

pub fn generateBuiltinZigSource(comp: *Compilation, allocator: Allocator) Allocator.Error![:0]u8 {
    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const target = comp.getTarget();
    const generic_arch_name = target.cpu.arch.genericName();
    const use_stage1 = build_options.is_stage1 and comp.bin_file.options.use_stage1;

    const zig_backend: std.builtin.CompilerBackend = blk: {
        if (use_stage1) break :blk .stage1;
        if (build_options.have_llvm and comp.bin_file.options.use_llvm) break :blk .stage2_llvm;
        if (comp.bin_file.options.object_format == .c) break :blk .stage2_c;
        break :blk switch (target.cpu.arch) {
            .wasm32, .wasm64 => std.builtin.CompilerBackend.stage2_wasm,
            .arm, .armeb, .thumb, .thumbeb => .stage2_arm,
            .x86_64 => .stage2_x86_64,
            .i386 => .stage2_x86,
            .aarch64, .aarch64_be, .aarch64_32 => .stage2_aarch64,
            .riscv64 => .stage2_riscv64,
            .sparc64 => .stage2_sparc64,
            else => .other,
        };
    };

    @setEvalBranchQuota(4000);
    try buffer.writer().print(
        \\const std = @import("std");
        \\/// Zig version. When writing code that supports multiple versions of Zig, prefer
        \\/// feature detection (i.e. with `@hasDecl` or `@hasField`) over version checks.
        \\pub const zig_version = std.SemanticVersion.parse("{s}") catch unreachable;
        \\pub const zig_backend = std.builtin.CompilerBackend.{};
        \\/// Temporary until self-hosted supports the `cpu.arch` value.
        \\pub const stage2_arch: std.Target.Cpu.Arch = .{};
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
        std.zig.fmtId(@tagName(target.cpu.arch)),
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

    for (target.cpu.arch.allFeaturesList()) |feature, index_usize| {
        const index = @intCast(std.Target.Cpu.Feature.Set.Index, index_usize);
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
        \\}};
        \\pub const object_format = std.Target.ObjectFormat.{};
        \\pub const mode = std.builtin.Mode.{};
        \\pub const link_libc = {};
        \\pub const link_libcpp = {};
        \\pub const have_error_return_tracing = {};
        \\pub const valgrind_support = {};
        \\pub const sanitize_thread = {};
        \\pub const position_independent_code = {};
        \\pub const position_independent_executable = {};
        \\pub const strip_debug_info = {};
        \\pub const code_model = std.builtin.CodeModel.{};
        \\
    , .{
        std.zig.fmtId(@tagName(comp.bin_file.options.object_format)),
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
            \\pub var test_functions: []std.builtin.TestFn = undefined; // overwritten later
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

pub fn updateSubCompilation(sub_compilation: *Compilation) !void {
    try sub_compilation.update();

    // Look for compilation errors in this sub_compilation
    // TODO instead of logging these errors, handle them in the callsites
    // of updateSubCompilation and attach them as sub-errors, properly
    // surfacing the errors. You can see an example of this already
    // done inside buildOutputFromZig.
    var errors = try sub_compilation.getAllErrorsAlloc();
    defer errors.deinit(sub_compilation.gpa);

    if (errors.list.len != 0) {
        for (errors.list) |full_err_msg| {
            switch (full_err_msg) {
                .src => |src| {
                    log.err("{s}:{d}:{d}: {s}", .{
                        src.src_path,
                        src.line + 1,
                        src.column + 1,
                        src.msg,
                    });
                },
                .plain => |plain| {
                    log.err("{s}", .{plain.msg});
                },
            }
        }
        return error.BuildingLibCObjectFailed;
    }
}

fn buildOutputFromZig(
    comp: *Compilation,
    src_basename: []const u8,
    output_mode: std.builtin.OutputMode,
    out: *?CRTFile,
    misc_task_tag: MiscTask,
) !void {
    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    std.debug.assert(output_mode != .Exe);

    var main_pkg: Package = .{
        .root_src_directory = comp.zig_lib_directory,
        .root_src_path = src_basename,
    };
    defer main_pkg.deinitTable(comp.gpa);
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
        .main_pkg = &main_pkg,
        .output_mode = output_mode,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.bin_file.options.libc_installation,
        .emit_bin = emit_bin,
        .optimize_mode = comp.compilerRtOptMode(),
        .link_mode = .Static,
        .function_sections = true,
        .no_builtin = true,
        .use_stage1 = build_options.is_stage1 and comp.bin_file.options.use_stage1,
        .want_sanitize_c = false,
        .want_stack_check = false,
        .want_red_zone = comp.bin_file.options.red_zone,
        .omit_frame_pointer = comp.bin_file.options.omit_frame_pointer,
        .want_valgrind = false,
        .want_tsan = false,
        .want_pic = comp.bin_file.options.pic,
        .want_pie = comp.bin_file.options.pie,
        .emit_h = null,
        .strip = comp.compilerRtStrip(),
        .is_native_os = comp.bin_file.options.is_native_os,
        .is_native_abi = comp.bin_file.options.is_native_abi,
        .self_exe_path = comp.self_exe_path,
        .verbose_cc = comp.verbose_cc,
        .verbose_link = comp.bin_file.options.verbose_link,
        .verbose_air = comp.verbose_air,
        .verbose_llvm_ir = comp.verbose_llvm_ir,
        .verbose_cimport = comp.verbose_cimport,
        .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
        .clang_passthrough_mode = comp.clang_passthrough_mode,
        .skip_linker_dependencies = true,
        .parent_compilation_link_libc = comp.bin_file.options.link_libc,
    });
    defer sub_compilation.destroy();

    try sub_compilation.update();
    // Look for compilation errors in this sub_compilation.
    var keep_errors = false;
    var errors = try sub_compilation.getAllErrorsAlloc();
    defer if (!keep_errors) errors.deinit(sub_compilation.gpa);

    if (errors.list.len != 0) {
        try comp.misc_failures.ensureUnusedCapacity(comp.gpa, 1);
        comp.misc_failures.putAssumeCapacityNoClobber(misc_task_tag, .{
            .msg = try std.fmt.allocPrint(comp.gpa, "sub-compilation of {s} failed", .{
                @tagName(misc_task_tag),
            }),
            .children = errors,
        });
        keep_errors = true;
        return error.SubCompilationFailed;
    }

    assert(out.* == null);
    out.* = Compilation.CRTFile{
        .full_object_path = try sub_compilation.bin_file.options.emit.?.directory.join(comp.gpa, &[_][]const u8{
            sub_compilation.bin_file.options.emit.?.sub_path,
        }),
        .lock = sub_compilation.bin_file.toOwnedLock(),
    };
}

fn updateStage1Module(comp: *Compilation, main_progress_node: *std.Progress.Node) !void {
    const tracy_trace = trace(@src());
    defer tracy_trace.end();

    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    // Here we use the legacy stage1 C++ compiler to compile Zig code.
    const mod = comp.bin_file.options.module.?;
    const directory = mod.zig_cache_artifact_directory; // Just an alias to make it shorter to type.
    const main_zig_file = try mod.main_pkg.root_src_directory.join(arena, &[_][]const u8{
        mod.main_pkg.root_src_path,
    });
    const zig_lib_dir = comp.zig_lib_directory.path.?;
    const target = comp.getTarget();

    // The include_compiler_rt stored in the bin file options here means that we need
    // compiler-rt symbols *somehow*. However, in the context of using the stage1 backend
    // we need to tell stage1 to include compiler-rt only if stage1 is the place that
    // needs to provide those symbols. Otherwise the stage2 infrastructure will take care
    // of it in the linker, by putting compiler_rt.o into a static archive, or linking
    // compiler_rt.a against an executable. In other words we only want to set this flag
    // for stage1 if we are using build-obj.
    const include_compiler_rt = comp.bin_file.options.output_mode == .Obj and
        comp.bin_file.options.include_compiler_rt;

    const stage2_target = try arena.create(stage1.Stage2Target);
    stage2_target.* = .{
        .arch = @enumToInt(target.cpu.arch) + 1, // skip over ZigLLVM_UnknownArch
        .os = @enumToInt(target.os.tag),
        .abi = @enumToInt(target.abi),
        .is_native_os = comp.bin_file.options.is_native_os,
        .is_native_cpu = false, // Only true when bootstrapping the compiler.
        .llvm_cpu_name = if (target.cpu.model.llvm_name) |s| s.ptr else null,
        .llvm_cpu_features = comp.bin_file.options.llvm_cpu_features.?,
        .llvm_target_abi = if (target_util.llvmMachineAbi(target)) |s| s.ptr else null,
    };

    const main_pkg_path = mod.main_pkg.root_src_directory.path orelse "";
    const builtin_pkg = mod.main_pkg.table.get("builtin").?;
    const builtin_zig_path = try builtin_pkg.root_src_directory.join(arena, &.{builtin_pkg.root_src_path});

    const stage1_module = stage1.create(
        @enumToInt(comp.bin_file.options.optimize_mode),
        main_pkg_path.ptr,
        main_pkg_path.len,
        main_zig_file.ptr,
        main_zig_file.len,
        zig_lib_dir.ptr,
        zig_lib_dir.len,
        stage2_target,
        comp.bin_file.options.is_test,
    ) orelse return error.OutOfMemory;

    const emit_bin_path = if (comp.bin_file.options.emit != null) blk: {
        const obj_basename = try std.zig.binNameAlloc(arena, .{
            .root_name = comp.bin_file.options.root_name,
            .target = target,
            .output_mode = .Obj,
        });
        break :blk try directory.join(arena, &[_][]const u8{obj_basename});
    } else "";

    if (mod.emit_h != null) {
        log.warn("-femit-h is not available in the stage1 backend; no .h file will be produced", .{});
    }
    const emit_h_loc: ?EmitLoc = if (mod.emit_h) |emit_h| emit_h.loc else null;
    const emit_h_path = try stage1LocPath(arena, emit_h_loc, directory);
    const emit_asm_path = try stage1LocPath(arena, comp.emit_asm, directory);
    const emit_llvm_ir_path = try stage1LocPath(arena, comp.emit_llvm_ir, directory);
    const emit_llvm_bc_path = try stage1LocPath(arena, comp.emit_llvm_bc, directory);
    const emit_analysis_path = try stage1LocPath(arena, comp.emit_analysis, directory);
    const emit_docs_path = try stage1LocPath(arena, comp.emit_docs, directory);
    const stage1_pkg = try createStage1Pkg(arena, "root", mod.main_pkg, null);
    const test_filter = comp.test_filter orelse ""[0..0];
    const test_name_prefix = comp.test_name_prefix orelse ""[0..0];
    const subsystem = if (comp.bin_file.options.subsystem) |s|
        @intToEnum(stage1.TargetSubsystem, @enumToInt(s))
    else
        stage1.TargetSubsystem.Auto;
    stage1_module.* = .{
        .root_name_ptr = comp.bin_file.options.root_name.ptr,
        .root_name_len = comp.bin_file.options.root_name.len,
        .emit_o_ptr = emit_bin_path.ptr,
        .emit_o_len = emit_bin_path.len,
        .emit_h_ptr = emit_h_path.ptr,
        .emit_h_len = emit_h_path.len,
        .emit_asm_ptr = emit_asm_path.ptr,
        .emit_asm_len = emit_asm_path.len,
        .emit_llvm_ir_ptr = emit_llvm_ir_path.ptr,
        .emit_llvm_ir_len = emit_llvm_ir_path.len,
        .emit_bitcode_ptr = emit_llvm_bc_path.ptr,
        .emit_bitcode_len = emit_llvm_bc_path.len,
        .emit_analysis_json_ptr = emit_analysis_path.ptr,
        .emit_analysis_json_len = emit_analysis_path.len,
        .emit_docs_ptr = emit_docs_path.ptr,
        .emit_docs_len = emit_docs_path.len,
        .builtin_zig_path_ptr = builtin_zig_path.ptr,
        .builtin_zig_path_len = builtin_zig_path.len,
        .test_filter_ptr = test_filter.ptr,
        .test_filter_len = test_filter.len,
        .test_name_prefix_ptr = test_name_prefix.ptr,
        .test_name_prefix_len = test_name_prefix.len,
        .userdata = @ptrToInt(comp),
        .main_pkg = stage1_pkg,
        .code_model = @enumToInt(comp.bin_file.options.machine_code_model),
        .subsystem = subsystem,
        .err_color = @enumToInt(comp.color),
        .pic = comp.bin_file.options.pic,
        .pie = comp.bin_file.options.pie,
        .lto = comp.bin_file.options.lto,
        .unwind_tables = comp.unwind_tables,
        .link_libc = comp.bin_file.options.link_libc,
        .link_libcpp = comp.bin_file.options.link_libcpp,
        .strip = comp.bin_file.options.strip,
        .is_single_threaded = comp.bin_file.options.single_threaded,
        .dll_export_fns = comp.bin_file.options.dll_export_fns,
        .link_mode_dynamic = comp.bin_file.options.link_mode == .Dynamic,
        .valgrind_enabled = comp.bin_file.options.valgrind,
        .tsan_enabled = comp.bin_file.options.tsan,
        .function_sections = comp.bin_file.options.function_sections,
        .include_compiler_rt = include_compiler_rt,
        .enable_stack_probing = comp.bin_file.options.stack_check,
        .red_zone = comp.bin_file.options.red_zone,
        .omit_frame_pointer = comp.bin_file.options.omit_frame_pointer,
        .enable_time_report = comp.time_report,
        .enable_stack_report = comp.stack_report,
        .test_is_evented = comp.test_evented_io,
        .verbose_ir = comp.verbose_air,
        .verbose_llvm_ir = comp.verbose_llvm_ir,
        .verbose_cimport = comp.verbose_cimport,
        .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
        .main_progress_node = main_progress_node,
        .have_c_main = false,
        .have_winmain = false,
        .have_wwinmain = false,
        .have_winmain_crt_startup = false,
        .have_wwinmain_crt_startup = false,
        .have_dllmain_crt_startup = false,
    };

    stage1_module.build_object();

    mod.stage1_flags = .{
        .have_c_main = stage1_module.have_c_main,
        .have_winmain = stage1_module.have_winmain,
        .have_wwinmain = stage1_module.have_wwinmain,
        .have_winmain_crt_startup = stage1_module.have_winmain_crt_startup,
        .have_wwinmain_crt_startup = stage1_module.have_wwinmain_crt_startup,
        .have_dllmain_crt_startup = stage1_module.have_dllmain_crt_startup,
    };

    stage1_module.destroy();
}

fn stage1LocPath(arena: Allocator, opt_loc: ?EmitLoc, cache_directory: Directory) ![]const u8 {
    const loc = opt_loc orelse return "";
    const directory = loc.directory orelse cache_directory;
    return directory.join(arena, &[_][]const u8{loc.basename});
}

fn createStage1Pkg(
    arena: Allocator,
    name: []const u8,
    pkg: *Package,
    parent_pkg: ?*stage1.Pkg,
) error{OutOfMemory}!*stage1.Pkg {
    const child_pkg = try arena.create(stage1.Pkg);

    const pkg_children = blk: {
        var children = std.ArrayList(*stage1.Pkg).init(arena);
        var it = pkg.table.iterator();
        while (it.next()) |entry| {
            if (mem.eql(u8, entry.key_ptr.*, "std") or
                mem.eql(u8, entry.key_ptr.*, "builtin") or
                mem.eql(u8, entry.key_ptr.*, "root"))
            {
                continue;
            }
            try children.append(try createStage1Pkg(arena, entry.key_ptr.*, entry.value_ptr.*, child_pkg));
        }
        break :blk children.items;
    };

    const src_path = try pkg.root_src_directory.join(arena, &[_][]const u8{pkg.root_src_path});

    child_pkg.* = .{
        .name_ptr = name.ptr,
        .name_len = name.len,
        .path_ptr = src_path.ptr,
        .path_len = src_path.len,
        .children_ptr = pkg_children.ptr,
        .children_len = pkg_children.len,
        .parent = parent_pkg,
    };
    return child_pkg;
}

pub fn build_crt_file(
    comp: *Compilation,
    root_name: []const u8,
    output_mode: std.builtin.OutputMode,
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

    // TODO: This is extracted into a local variable to work around a stage1 miscompilation.
    const emit_bin = Compilation.EmitLoc{
        .directory = null, // Put it in the cache directory.
        .basename = basename,
    };
    const sub_compilation = try Compilation.create(comp.gpa, .{
        .local_cache_directory = comp.global_cache_directory,
        .global_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .cache_mode = .whole,
        .target = target,
        .root_name = root_name,
        .main_pkg = null,
        .output_mode = output_mode,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.bin_file.options.libc_installation,
        .emit_bin = emit_bin,
        .optimize_mode = comp.compilerRtOptMode(),
        .want_sanitize_c = false,
        .want_stack_check = false,
        .want_red_zone = comp.bin_file.options.red_zone,
        .omit_frame_pointer = comp.bin_file.options.omit_frame_pointer,
        .want_valgrind = false,
        .want_tsan = false,
        .want_pic = comp.bin_file.options.pic,
        .want_pie = comp.bin_file.options.pie,
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
        .verbose_llvm_ir = comp.verbose_llvm_ir,
        .verbose_cimport = comp.verbose_cimport,
        .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
        .clang_passthrough_mode = comp.clang_passthrough_mode,
        .skip_linker_dependencies = true,
        .parent_compilation_link_libc = comp.bin_file.options.link_libc,
    });
    defer sub_compilation.destroy();

    try sub_compilation.updateSubCompilation();

    try comp.crt_files.ensureUnusedCapacity(comp.gpa, 1);

    comp.crt_files.putAssumeCapacityNoClobber(basename, .{
        .full_object_path = try sub_compilation.bin_file.options.emit.?.directory.join(comp.gpa, &[_][]const u8{
            sub_compilation.bin_file.options.emit.?.sub_path,
        }),
        .lock = sub_compilation.bin_file.toOwnedLock(),
    });
}

pub fn stage1AddLinkLib(comp: *Compilation, lib_name: []const u8) !void {
    // Avoid deadlocking on building import libs such as kernel32.lib
    // This can happen when the user uses `build-exe foo.obj -lkernel32` and then
    // when we create a sub-Compilation for zig libc, it also tries to build kernel32.lib.
    if (comp.bin_file.options.skip_linker_dependencies) return;

    // This happens when an `extern "foo"` function is referenced by the stage1 backend.
    // If we haven't seen this library yet and we're targeting Windows, we need to queue up
    // a work item to produce the DLL import library for this.
    const gop = try comp.bin_file.options.system_libs.getOrPut(comp.gpa, lib_name);
    if (!gop.found_existing and comp.getTarget().os.tag == .windows) {
        try comp.work_queue.writeItem(.{
            .windows_import_lib = comp.bin_file.options.system_libs.count() - 1,
        });
    }
}

/// This decides the optimization mode for all zig-provided libraries, including
/// compiler-rt, libcxx, libc, libunwind, etc.
pub fn compilerRtOptMode(comp: Compilation) std.builtin.Mode {
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
    if (comp.debug_compiler_runtime_libs) {
        return comp.bin_file.options.strip;
    } else {
        return true;
    }
}
