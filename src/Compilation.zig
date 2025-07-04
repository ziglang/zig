const Compilation = @This();

const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.compilation);
const Target = std.Target;
const ThreadPool = std.Thread.Pool;
const WaitGroup = std.Thread.WaitGroup;
const ErrorBundle = std.zig.ErrorBundle;
const fatal = std.process.fatal;

const Value = @import("Value.zig");
const Type = @import("Type.zig");
const target_util = @import("target.zig");
const Package = @import("Package.zig");
const introspect = @import("introspect.zig");
const link = @import("link.zig");
const tracy = @import("tracy.zig");
const trace = tracy.trace;
const build_options = @import("build_options");
const LibCInstallation = std.zig.LibCInstallation;
const glibc = @import("libs/glibc.zig");
const musl = @import("libs/musl.zig");
const freebsd = @import("libs/freebsd.zig");
const netbsd = @import("libs/netbsd.zig");
const mingw = @import("libs/mingw.zig");
const libunwind = @import("libs/libunwind.zig");
const libcxx = @import("libs/libcxx.zig");
const wasi_libc = @import("libs/wasi_libc.zig");
const clangMain = @import("main.zig").clangMain;
const Zcu = @import("Zcu.zig");
const Sema = @import("Sema.zig");
const InternPool = @import("InternPool.zig");
const Cache = std.Build.Cache;
const c_codegen = @import("codegen/c.zig");
const libtsan = @import("libs/libtsan.zig");
const Zir = std.zig.Zir;
const Air = @import("Air.zig");
const Builtin = @import("Builtin.zig");
const LlvmObject = @import("codegen/llvm.zig").Object;
const dev = @import("dev.zig");

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
/// Contains different state depending on the `CacheMode` used by this `Compilation`.
cache_use: CacheUse,
/// All compilations have a root module because this is where some important
/// settings are stored, such as target and optimization mode. This module
/// might not have any .zig code associated with it, however.
root_mod: *Package.Module,

/// User-specified settings that have all the defaults resolved into concrete values.
config: Config,

/// The main output file.
/// In `CacheMode.whole`, this is null except for during the body of `update`.
/// In `CacheMode.none` and `CacheMode.incremental`, this is long-lived.
/// Regardless of cache mode, this is `null` when `-fno-emit-bin` is used.
bin_file: ?*link.File,

/// The root path for the dynamic linker and system libraries (as well as frameworks on Darwin)
sysroot: ?[]const u8,
root_name: [:0]const u8,
compiler_rt_strat: RtStrat,
ubsan_rt_strat: RtStrat,
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
link_task_queue: link.Queue = .empty,

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
/// Do not check this field directly. Instead, use the `debugIncremental` wrapper function.
debug_incremental: bool,
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
/// Owned by the caller of `Compilation.create`.
dirs: Directories,
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
/// Populated when we build the UBSAN library. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
ubsan_rt_lib: ?CrtFile = null,
/// Populated when we build the UBSAN object. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
ubsan_rt_obj: ?CrtFile = null,
/// Populated when we build the libc static library. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
zigc_static_lib: ?CrtFile = null,
/// Populated when we build the libcompiler_rt static library. A Job to build this is indicated
/// by setting `queued_jobs.compiler_rt_lib` and resolved before calling linker.flush().
compiler_rt_lib: ?CrtFile = null,
/// Populated when we build the compiler_rt_obj object. A Job to build this is indicated
/// by setting `queued_jobs.compiler_rt_obj` and resolved before calling linker.flush().
compiler_rt_obj: ?CrtFile = null,
/// hack for stage2_x86_64 + coff
compiler_rt_dyn_lib: ?CrtFile = null,
/// Populated when we build the libfuzzer static library. A Job to build this
/// is indicated by setting `queued_jobs.fuzzer_lib` and resolved before
/// calling linker.flush().
fuzzer_lib: ?CrtFile = null,

glibc_so_files: ?glibc.BuiltSharedObjects = null,
freebsd_so_files: ?freebsd.BuiltSharedObjects = null,
netbsd_so_files: ?netbsd.BuiltSharedObjects = null,

/// For example `Scrt1.o` and `libc_nonshared.a`. These are populated after building libc from source,
/// The set of needed CRT (C runtime) files differs depending on the target and compilation settings.
/// The key is the basename, and the value is the absolute path to the completed build artifact.
crt_files: std.StringHashMapUnmanaged(CrtFile) = .empty,

/// How many lines of reference trace should be included per compile error.
/// Null means only show snippet on first error.
reference_trace: ?u32 = null,

/// This mutex guards all `Compilation` mutable state.
/// Disabled in single-threaded mode because the thread pool spawns in the same thread.
mutex: if (builtin.single_threaded) struct {
    pub inline fn tryLock(_: @This()) void {}
    pub inline fn lock(_: @This()) void {}
    pub inline fn unlock(_: @This()) void {}
} else std.Thread.Mutex = .{},

test_filters: []const []const u8,
test_name_prefix: ?[]const u8,

link_task_wait_group: WaitGroup = .{},
link_prog_node: std.Progress.Node = std.Progress.Node.none,

llvm_opt_bisect_limit: c_int,

file_system_inputs: ?*std.ArrayListUnmanaged(u8),

/// This is the digest of the cache for the current compilation.
/// This digest will be known after update() is called.
digest: ?[Cache.bin_digest_len]u8 = null,

/// Non-`null` iff we are emitting a binary.
/// Does not change for the lifetime of this `Compilation`.
/// Cwd-relative if `cache_use == .none`. Otherwise, relative to our subdirectory in the cache.
emit_bin: ?[]const u8,
/// Non-`null` iff we are emitting assembly.
/// Does not change for the lifetime of this `Compilation`.
/// Cwd-relative if `cache_use == .none`. Otherwise, relative to our subdirectory in the cache.
emit_asm: ?[]const u8,
/// Non-`null` iff we are emitting an implib.
/// Does not change for the lifetime of this `Compilation`.
/// Cwd-relative if `cache_use == .none`. Otherwise, relative to our subdirectory in the cache.
emit_implib: ?[]const u8,
/// Non-`null` iff we are emitting LLVM IR.
/// Does not change for the lifetime of this `Compilation`.
/// Cwd-relative if `cache_use == .none`. Otherwise, relative to our subdirectory in the cache.
emit_llvm_ir: ?[]const u8,
/// Non-`null` iff we are emitting LLVM bitcode.
/// Does not change for the lifetime of this `Compilation`.
/// Cwd-relative if `cache_use == .none`. Otherwise, relative to our subdirectory in the cache.
emit_llvm_bc: ?[]const u8,
/// Non-`null` iff we are emitting documentation.
/// Does not change for the lifetime of this `Compilation`.
/// Cwd-relative if `cache_use == .none`. Otherwise, relative to our subdirectory in the cache.
emit_docs: ?[]const u8,

const QueuedJobs = struct {
    /// hack for stage2_x86_64 + coff
    compiler_rt_dyn_lib: bool = false,
    compiler_rt_lib: bool = false,
    compiler_rt_obj: bool = false,
    ubsan_rt_lib: bool = false,
    ubsan_rt_obj: bool = false,
    fuzzer_lib: bool = false,
    musl_crt_file: [@typeInfo(musl.CrtFile).@"enum".fields.len]bool = @splat(false),
    glibc_crt_file: [@typeInfo(glibc.CrtFile).@"enum".fields.len]bool = @splat(false),
    freebsd_crt_file: [@typeInfo(freebsd.CrtFile).@"enum".fields.len]bool = @splat(false),
    netbsd_crt_file: [@typeInfo(netbsd.CrtFile).@"enum".fields.len]bool = @splat(false),
    /// one of WASI libc static objects
    wasi_libc_crt_file: [@typeInfo(wasi_libc.CrtFile).@"enum".fields.len]bool = @splat(false),
    /// one of the mingw-w64 static objects
    mingw_crt_file: [@typeInfo(mingw.CrtFile).@"enum".fields.len]bool = @splat(false),
    /// all of the glibc shared objects
    glibc_shared_objects: bool = false,
    freebsd_shared_objects: bool = false,
    netbsd_shared_objects: bool = false,
    /// libunwind.a, usually needed when linking libc
    libunwind: bool = false,
    libcxx: bool = false,
    libcxxabi: bool = false,
    libtsan: bool = false,
    zigc_lib: bool = false,
};

/// A filesystem path, represented relative to one of a few specific directories where possible.
/// Every path (considering symlinks as distinct paths) has a canonical representation in this form.
/// This abstraction allows us to:
/// * always open files relative to a consistent root on the filesystem
/// * detect when two paths correspond to the same file, e.g. for deduplicating `@import`s
pub const Path = struct {
    root: Root,
    /// This path is always in a normalized form, where:
    /// * All components are separated by `fs.path.sep`
    /// * There are no repeated separators (like "foo//bar")
    /// * There are no "." or ".." components
    /// * There is no trailing path separator
    ///
    /// There is a leading separator iff `root` is `.none` *and* `builtin.target.os.tag != .wasi`.
    ///
    /// If this `Path` exactly represents a `Root`, the sub path is "", not ".".
    sub_path: []u8,

    const Root = enum {
        /// `sub_path` is relative to the Zig lib directory on `Compilation`.
        zig_lib,
        /// `sub_path` is relative to the global cache directory on `Compilation`.
        global_cache,
        /// `sub_path` is relative to the local cache directory on `Compilation`.
        local_cache,
        /// `sub_path` is not relative to any of the roots listed above.
        /// It is resolved starting with `Directories.cwd`; so it is an absolute path on most
        /// targets, but cwd-relative on WASI. We do not make it cwd-relative on other targets
        /// so that `Path.digest` gives hashes which can be stored in the Zig cache (as they
        /// don't depend on a specific compiler instance).
        none,
    };

    /// In general, we can only construct canonical `Path`s at runtime, because weird nesting might
    /// mean that e.g. a sub path inside zig/lib/ is actually in the global cache. However, because
    /// `Directories` guarantees that `zig_lib` is a distinct path from both cache directories, it's
    /// okay for us to construct this path, and only this path, as a comptime constant.
    pub const zig_lib_root: Path = .{ .root = .zig_lib, .sub_path = "" };

    pub fn deinit(p: Path, gpa: Allocator) void {
        gpa.free(p.sub_path);
    }

    /// The added data is relocatable across any compiler process using the same lib and cache
    /// directories; it does not depend on cwd.
    pub fn addToHasher(p: Path, h: *Cache.Hasher) void {
        h.update(&.{@intFromEnum(p.root)});
        h.update(p.sub_path);
    }

    /// Small convenience wrapper around `addToHasher`.
    pub fn digest(p: Path) Cache.BinDigest {
        var h = Cache.hasher_init;
        p.addToHasher(&h);
        return h.finalResult();
    }

    /// Given a `Path`, returns the directory handle and sub path to be used to open the path.
    pub fn openInfo(p: Path, dirs: Directories) struct { fs.Dir, []const u8 } {
        const dir = switch (p.root) {
            .none => {
                const cwd_sub_path = absToCwdRelative(p.sub_path, dirs.cwd);
                return .{ fs.cwd(), cwd_sub_path };
            },
            .zig_lib => dirs.zig_lib.handle,
            .global_cache => dirs.global_cache.handle,
            .local_cache => dirs.local_cache.handle,
        };
        if (p.sub_path.len == 0) return .{ dir, "." };
        assert(!fs.path.isAbsolute(p.sub_path));
        return .{ dir, p.sub_path };
    }

    pub const format = unreachable; // do not format direcetly
    pub fn fmt(p: Path, comp: *Compilation) Formatter {
        return .{ .p = p, .comp = comp };
    }
    const Formatter = struct {
        p: Path,
        comp: *Compilation,
        pub fn format(f: Formatter, w: *std.io.Writer, comptime unused_fmt: []const u8) std.io.Writer.Error!void {
            comptime assert(unused_fmt.len == 0);
            const root_path: []const u8 = switch (f.p.root) {
                .zig_lib => f.comp.dirs.zig_lib.path orelse ".",
                .global_cache => f.comp.dirs.global_cache.path orelse ".",
                .local_cache => f.comp.dirs.local_cache.path orelse ".",
                .none => {
                    const cwd_sub_path = absToCwdRelative(f.p.sub_path, f.comp.dirs.cwd);
                    try w.writeAll(cwd_sub_path);
                    return;
                },
            };
            assert(root_path.len != 0);
            try w.writeAll(root_path);
            if (f.p.sub_path.len > 0) {
                try w.writeByte(fs.path.sep);
                try w.writeAll(f.p.sub_path);
            }
        }
    };

    /// Given the `sub_path` of a `Path` with `Path.root == .none`, attempts to convert
    /// the (absolute) path to a cwd-relative path. Otherwise, returns the absolute path
    /// unmodified. The returned string is never empty: "" is converted to ".".
    fn absToCwdRelative(sub_path: []const u8, cwd_path: []const u8) []const u8 {
        if (builtin.target.os.tag == .wasi) {
            if (sub_path.len == 0) return ".";
            assert(!fs.path.isAbsolute(sub_path));
            return sub_path;
        }
        assert(fs.path.isAbsolute(sub_path));
        if (!std.mem.startsWith(u8, sub_path, cwd_path)) return sub_path;
        if (sub_path.len == cwd_path.len) return "."; // the strings are equal
        if (sub_path[cwd_path.len] != fs.path.sep) return sub_path; // last component before cwd differs
        return sub_path[cwd_path.len + 1 ..]; // remove '/path/to/cwd/' prefix
    }

    /// From an unresolved path (which can be made of multiple not-yet-joined strings), construct a
    /// canonical `Path`.
    pub fn fromUnresolved(gpa: Allocator, dirs: Compilation.Directories, unresolved_parts: []const []const u8) Allocator.Error!Path {
        const resolved = try introspect.resolvePath(gpa, dirs.cwd, unresolved_parts);
        errdefer gpa.free(resolved);

        // If, for instance, `dirs.local_cache.path` is within the lib dir, it must take priority,
        // so that we prefer `.root = .local_cache` over `.root = .zig_lib`. The easiest way to do
        // this is simply to prioritize the longest root path.
        const PathAndRoot = struct { ?[]const u8, Root };
        var roots: [3]PathAndRoot = .{
            .{ dirs.zig_lib.path, .zig_lib },
            .{ dirs.global_cache.path, .global_cache },
            .{ dirs.local_cache.path, .local_cache },
        };
        // This must be a stable sort, because the global and local cache directories may be the same, in
        // which case we need to make a consistent choice.
        std.mem.sort(PathAndRoot, &roots, {}, struct {
            fn lessThan(_: void, lhs: PathAndRoot, rhs: PathAndRoot) bool {
                const lhs_path_len = if (lhs[0]) |p| p.len else 0;
                const rhs_path_len = if (rhs[0]) |p| p.len else 0;
                return lhs_path_len > rhs_path_len; // '>' instead of '<' to sort descending
            }
        }.lessThan);

        for (roots) |path_and_root| {
            const opt_root_path, const root = path_and_root;
            const root_path = opt_root_path orelse {
                // This root is the cwd.
                if (!fs.path.isAbsolute(resolved)) {
                    return .{
                        .root = root,
                        .sub_path = resolved,
                    };
                }
                continue;
            };
            if (!mem.startsWith(u8, resolved, root_path)) continue;
            const sub: []const u8 = if (resolved.len != root_path.len) sub: {
                // Check the trailing slash, so that we don't match e.g. `/foo/bar` with `/foo/barren`
                if (resolved[root_path.len] != fs.path.sep) continue;
                break :sub resolved[root_path.len + 1 ..];
            } else "";
            const duped = try gpa.dupe(u8, sub);
            gpa.free(resolved);
            return .{ .root = root, .sub_path = duped };
        }

        // We're not relative to any root, so we will use an absolute path (on targets where they are available).

        if (builtin.target.os.tag == .wasi or fs.path.isAbsolute(resolved)) {
            // `resolved` is already absolute (or we're on WASI, where absolute paths don't really exist).
            return .{ .root = .none, .sub_path = resolved };
        }

        if (resolved.len == 0) {
            // We just need the cwd path, no trailing separator. Note that `gpa.free(resolved)` would be a nop.
            return .{ .root = .none, .sub_path = try gpa.dupe(u8, dirs.cwd) };
        }

        // We need to make an absolute path. Because `resolved` came from `introspect.resolvePath`, we can just
        // join the paths with a simple format string.
        const abs_path = try std.fmt.allocPrint(gpa, "{s}{c}{s}", .{ dirs.cwd, fs.path.sep, resolved });
        gpa.free(resolved);
        return .{ .root = .none, .sub_path = abs_path };
    }

    /// Constructs a canonical `Path` representing `sub_path` relative to `root`.
    ///
    /// If `sub_path` is resolved, this is almost like directly constructing a `Path`, but this
    /// function also canonicalizes the result, which matters because `sub_path` may move us into
    /// a different root.
    ///
    /// For instance, if the Zig lib directory is inside the global cache, passing `root` as
    /// `.global_cache` could still end up returning a `Path` with `Path.root == .zig_lib`.
    pub fn fromRoot(
        gpa: Allocator,
        dirs: Compilation.Directories,
        root: Path.Root,
        sub_path: []const u8,
    ) Allocator.Error!Path {
        // Currently, this just wraps `fromUnresolved` for simplicity. A more efficient impl is
        // probably possible if this function ever ends up impacting performance somehow.
        return .fromUnresolved(gpa, dirs, &.{
            switch (root) {
                .zig_lib => dirs.zig_lib.path orelse "",
                .global_cache => dirs.global_cache.path orelse "",
                .local_cache => dirs.local_cache.path orelse "",
                .none => "",
            },
            sub_path,
        });
    }

    /// Given a `Path` and an (unresolved) sub path relative to it, construct a `Path` representing
    /// the joined path `p/sub_path`. Note that, like with `fromRoot`, the `sub_path` might cause us
    /// to move into a different `Path.Root`.
    pub fn join(
        p: Path,
        gpa: Allocator,
        dirs: Compilation.Directories,
        sub_path: []const u8,
    ) Allocator.Error!Path {
        // Currently, this just wraps `fromUnresolved` for simplicity. A more efficient impl is
        // probably possible if this function ever ends up impacting performance somehow.
        return .fromUnresolved(gpa, dirs, &.{
            switch (p.root) {
                .zig_lib => dirs.zig_lib.path orelse "",
                .global_cache => dirs.global_cache.path orelse "",
                .local_cache => dirs.local_cache.path orelse "",
                .none => "",
            },
            p.sub_path,
            sub_path,
        });
    }

    /// Like `join`, but `sub_path` is relative to the dirname of `p` instead of `p` itself.
    pub fn upJoin(
        p: Path,
        gpa: Allocator,
        dirs: Compilation.Directories,
        sub_path: []const u8,
    ) Allocator.Error!Path {
        return .fromUnresolved(gpa, dirs, &.{
            switch (p.root) {
                .zig_lib => dirs.zig_lib.path orelse "",
                .global_cache => dirs.global_cache.path orelse "",
                .local_cache => dirs.local_cache.path orelse "",
                .none => "",
            },
            p.sub_path,
            "..",
            sub_path,
        });
    }

    pub fn toCachePath(p: Path, dirs: Directories) Cache.Path {
        const root_dir: Cache.Directory = switch (p.root) {
            .zig_lib => dirs.zig_lib,
            .global_cache => dirs.global_cache,
            .local_cache => dirs.local_cache,
            else => {
                const cwd_sub_path = absToCwdRelative(p.sub_path, dirs.cwd);
                return .{
                    .root_dir = .cwd(),
                    .sub_path = cwd_sub_path,
                };
            },
        };
        assert(!fs.path.isAbsolute(p.sub_path));
        return .{
            .root_dir = root_dir,
            .sub_path = p.sub_path,
        };
    }

    /// This should not be used for most of the compiler pipeline, but is useful when emitting
    /// paths from the compilation (e.g. in debug info), because they will not depend on the cwd.
    /// The returned path is owned by the caller and allocated into `gpa`.
    pub fn toAbsolute(p: Path, dirs: Directories, gpa: Allocator) Allocator.Error![]u8 {
        const root_path: []const u8 = switch (p.root) {
            .zig_lib => dirs.zig_lib.path orelse "",
            .global_cache => dirs.global_cache.path orelse "",
            .local_cache => dirs.local_cache.path orelse "",
            .none => "",
        };
        return fs.path.resolve(gpa, &.{
            dirs.cwd,
            root_path,
            p.sub_path,
        });
    }

    pub fn isNested(inner: Path, outer: Path) union(enum) {
        /// Value is the sub path, which is a sub-slice of `inner.sub_path`.
        yes: []const u8,
        no,
        different_roots,
    } {
        if (inner.root != outer.root) return .different_roots;
        if (!mem.startsWith(u8, inner.sub_path, outer.sub_path)) return .no;
        if (inner.sub_path.len == outer.sub_path.len) return .no;
        if (outer.sub_path.len == 0) return .{ .yes = inner.sub_path };
        if (inner.sub_path[outer.sub_path.len] != fs.path.sep) return .no;
        return .{ .yes = inner.sub_path[outer.sub_path.len + 1 ..] };
    }

    /// Returns whether this `Path` is illegal to have as a user-imported `Zcu.File` (including
    /// as the root of a module). Such paths exist in directories which the Zig compiler treats
    /// specially, like 'global_cache/b/', which stores 'builtin.zig' files.
    pub fn isIllegalZigImport(p: Path, gpa: Allocator, dirs: Directories) Allocator.Error!bool {
        const zig_builtin_dir: Path = try .fromRoot(gpa, dirs, .global_cache, "b");
        defer zig_builtin_dir.deinit(gpa);
        return switch (p.isNested(zig_builtin_dir)) {
            .yes => true,
            .no, .different_roots => false,
        };
    }
};

pub const Directories = struct {
    /// The string returned by `introspect.getResolvedCwd`. This is typically an absolute path,
    /// but on WASI is the empty string "" instead, because WASI does not have absolute paths.
    cwd: []const u8,
    /// The Zig 'lib' directory.
    /// `zig_lib.path` is resolved (`introspect.resolvePath`) or `null` for cwd.
    /// Guaranteed to be a different path from `global_cache` and `local_cache`.
    zig_lib: Cache.Directory,
    /// The global Zig cache directory.
    /// `global_cache.path` is resolved (`introspect.resolvePath`) or `null` for cwd.
    global_cache: Cache.Directory,
    /// The local Zig cache directory.
    /// `local_cache.path` is resolved (`introspect.resolvePath`) or `null` for cwd.
    /// This may be the same as `global_cache`.
    local_cache: Cache.Directory,

    pub fn deinit(dirs: *Directories) void {
        // The local and global caches could be the same.
        const close_local = dirs.local_cache.handle.fd != dirs.global_cache.handle.fd;

        dirs.global_cache.handle.close();
        if (close_local) dirs.local_cache.handle.close();
        dirs.zig_lib.handle.close();
    }

    /// Returns a `Directories` where `local_cache` is replaced with `global_cache`, intended for
    /// use by sub-compilations (e.g. compiler_rt). Do not `deinit` the returned `Directories`; it
    /// shares handles with `dirs`.
    pub fn withoutLocalCache(dirs: Directories) Directories {
        return .{
            .cwd = dirs.cwd,
            .zig_lib = dirs.zig_lib,
            .global_cache = dirs.global_cache,
            .local_cache = dirs.global_cache,
        };
    }

    /// Uses `std.process.fatal` on error conditions.
    pub fn init(
        arena: Allocator,
        override_zig_lib: ?[]const u8,
        override_global_cache: ?[]const u8,
        local_cache_strat: union(enum) {
            override: []const u8,
            search,
            global,
        },
        wasi_preopens: switch (builtin.target.os.tag) {
            .wasi => std.fs.wasi.Preopens,
            else => void,
        },
        self_exe_path: switch (builtin.target.os.tag) {
            .wasi => void,
            else => []const u8,
        },
    ) Directories {
        const wasi = builtin.target.os.tag == .wasi;

        const cwd = introspect.getResolvedCwd(arena) catch |err| {
            fatal("unable to get cwd: {s}", .{@errorName(err)});
        };

        const zig_lib: Cache.Directory = d: {
            if (override_zig_lib) |path| break :d openUnresolved(arena, cwd, path, .@"zig lib");
            if (wasi) break :d openWasiPreopen(wasi_preopens, "/lib");
            break :d introspect.findZigLibDirFromSelfExe(arena, cwd, self_exe_path) catch |err| {
                fatal("unable to find zig installation directory '{s}': {s}", .{ self_exe_path, @errorName(err) });
            };
        };

        const global_cache: Cache.Directory = d: {
            if (override_global_cache) |path| break :d openUnresolved(arena, cwd, path, .@"global cache");
            if (wasi) break :d openWasiPreopen(wasi_preopens, "/cache");
            const path = introspect.resolveGlobalCacheDir(arena) catch |err| {
                fatal("unable to resolve zig cache directory: {s}", .{@errorName(err)});
            };
            break :d openUnresolved(arena, cwd, path, .@"global cache");
        };

        const local_cache: Cache.Directory = switch (local_cache_strat) {
            .override => |path| openUnresolved(arena, cwd, path, .@"local cache"),
            .search => d: {
                const maybe_path = introspect.resolveSuitableLocalCacheDir(arena, cwd) catch |err| {
                    fatal("unable to resolve zig cache directory: {s}", .{@errorName(err)});
                };
                const path = maybe_path orelse break :d global_cache;
                break :d openUnresolved(arena, cwd, path, .@"local cache");
            },
            .global => global_cache,
        };

        if (std.mem.eql(u8, zig_lib.path orelse "", global_cache.path orelse "")) {
            fatal("zig lib directory '{f}' cannot be equal to global cache directory '{f}'", .{ zig_lib, global_cache });
        }
        if (std.mem.eql(u8, zig_lib.path orelse "", local_cache.path orelse "")) {
            fatal("zig lib directory '{f}' cannot be equal to local cache directory '{f}'", .{ zig_lib, local_cache });
        }

        return .{
            .cwd = cwd,
            .zig_lib = zig_lib,
            .global_cache = global_cache,
            .local_cache = local_cache,
        };
    }
    fn openWasiPreopen(preopens: std.fs.wasi.Preopens, name: []const u8) Cache.Directory {
        return .{
            .path = if (std.mem.eql(u8, name, ".")) null else name,
            .handle = .{
                .fd = preopens.find(name) orelse fatal("WASI preopen not found: '{s}'", .{name}),
            },
        };
    }
    fn openUnresolved(arena: Allocator, cwd: []const u8, unresolved_path: []const u8, thing: enum { @"zig lib", @"global cache", @"local cache" }) Cache.Directory {
        const path = introspect.resolvePath(arena, cwd, &.{unresolved_path}) catch |err| {
            fatal("unable to resolve {s} directory: {s}", .{ @tagName(thing), @errorName(err) });
        };
        const nonempty_path = if (path.len == 0) "." else path;
        const handle_or_err = switch (thing) {
            .@"zig lib" => std.fs.cwd().openDir(nonempty_path, .{}),
            .@"global cache", .@"local cache" => std.fs.cwd().makeOpenPath(nonempty_path, .{}),
        };
        return .{
            .path = if (path.len == 0) null else path,
            .handle = handle_or_err catch |err| {
                const extra_str: []const u8 = e: {
                    if (thing == .@"global cache") switch (err) {
                        error.AccessDenied, error.ReadOnlyFileSystem => break :e "\n" ++
                            "If this location is not writable then consider specifying an alternative with " ++
                            "the ZIG_GLOBAL_CACHE_DIR environment variable or the --global-cache-dir option.",
                        else => {},
                    };
                    break :e "";
                };
                fatal("unable to open {s} directory '{s}': {s}{s}", .{ @tagName(thing), nonempty_path, @errorName(err), extra_str });
            },
        };
    }
};

/// This small wrapper function just checks whether debug extensions are enabled before checking
/// `comp.debug_incremental`. It is inline so that comptime-known `false` propagates to the caller,
/// preventing debugging features from making it into release builds of the compiler.
pub inline fn debugIncremental(comp: *const Compilation) bool {
    if (!build_options.enable_debug_extensions or builtin.single_threaded) return false;
    return comp.debug_incremental;
}

pub const default_stack_protector_buffer_size = target_util.default_stack_protector_buffer_size;
pub const SemaError = Zcu.SemaError;

pub const CrtFile = struct {
    lock: Cache.Lock,
    full_object_path: Cache.Path,

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
    /// Given the generated AIR for a function, put it onto the code generation queue.
    /// This `Job` exists (instead of the `link.ZcuTask` being directly queued) to ensure that
    /// all types are resolved before the linker task is queued.
    /// If the backend does not support `Zcu.Feature.separate_thread`, codegen and linking happen immediately.
    /// Before queueing this `Job`, increase the estimated total item count for both
    /// `comp.zcu.?.codegen_prog_node` and `comp.link_prog_node`.
    codegen_func: struct {
        func: InternPool.Index,
        /// The AIR emitted from analyzing `func`; owned by this `Job` in `gpa`.
        air: Air,
    },
    /// Queue a `link.ZcuTask` to emit this non-function `Nav` into the output binary.
    /// This `Job` exists (instead of the `link.ZcuTask` being directly queued) to ensure that
    /// all types are resolved before the linker task is queued.
    /// If the backend does not support `Zcu.Feature.separate_thread`, the task is run immediately.
    /// Before queueing this `Job`, increase the estimated total item count for `comp.link_prog_node`.
    link_nav: InternPool.Nav.Index,
    /// Queue a `link.ZcuTask` to emit debug information for this container type.
    /// This `Job` exists (instead of the `link.ZcuTask` being directly queued) to ensure that
    /// all types are resolved before the linker task is queued.
    /// If the backend does not support `Zcu.Feature.separate_thread`, the task is run immediately.
    /// Before queueing this `Job`, increase the estimated total item count for `comp.link_prog_node`.
    link_type: InternPool.Index,
    /// Before queueing this `Job`, increase the estimated total item count for `comp.link_prog_node`.
    update_line_number: InternPool.TrackedInst.Index,
    /// The `AnalUnit`, which is *not* a `func`, must be semantically analyzed.
    /// This may be its first time being analyzed, or it may be outdated.
    /// If the unit is a test function, an `analyze_func` job will then be queued.
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
            object_path: Cache.Path,
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
                file.deprecatedReader().readUntilDelimiterArrayList(&line, '\n', 1 << 10) catch break :source_line 0;

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
                var br = std.io.bufferedReader(file.deprecatedReader());
                const reader = br.reader();
                var bc = std.zig.llvm.BitcodeReader.init(gpa, .{ .reader = reader.any() });
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
    freebsd_crt_file,
    freebsd_shared_objects,
    netbsd_crt_file,
    netbsd_shared_objects,
    mingw_crt_file,
    windows_import_lib,
    libunwind,
    libcxx,
    libcxxabi,
    libtsan,
    libubsan,
    libfuzzer,
    wasi_libc_crt_file,
    compiler_rt,
    libzigc,
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

    @"freebsd libc Scrt1.o",
    @"freebsd libc shared object",

    @"netbsd libc Scrt0.o",
    @"netbsd libc shared object",

    @"mingw-w64 crt2.o",
    @"mingw-w64 dllcrt2.o",
    @"mingw-w64 libmingw32.lib",
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
        const target = &resolved_target.result;
        hh.add(target.cpu.arch);
        hh.addBytes(target.cpu.model.name);
        hh.add(target.cpu.features.ints);
        hh.add(target.os.tag);
        hh.add(target.os.versionRange());
        hh.add(target.abi);
        hh.add(target.ofmt);
        hh.add(resolved_target.is_native_os);
        hh.add(resolved_target.is_native_abi);
        hh.add(resolved_target.is_explicit_dynamic_linker);
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

pub const CacheMode = enum {
    /// The results of this compilation are not cached. The compilation is always performed, and the
    /// results are emitted directly to their output locations. Temporary files will be placed in a
    /// temporary directory in the cache, but deleted after the compilation is done.
    ///
    /// This mode is typically used for direct CLI invocations like `zig build-exe`, because such
    /// processes are typically low-level usages which would not make efficient use of the cache.
    none,
    /// The compilation is cached based only on the options given when creating the `Compilation`.
    /// In particular, Zig source file contents are not included in the cache manifest. This mode
    /// allows incremental compilation, because the old cached compilation state can be restored
    /// and the old binary patched up with the changes. All files, including temporary files, are
    /// stored in the cache directory like '<cache>/o/<hash>/'. Temporary files are not deleted.
    ///
    /// At the time of writing, incremental compilation is only supported with the `-fincremental`
    /// command line flag, so this mode is rarely used. However, it is required in order to use
    /// incremental compilation.
    incremental,
    /// The compilation is cached based on the `Compilation` options and every input, including Zig
    /// source files, linker inputs, and `@embedFile` targets. If any of them change, we will see a
    /// cache miss, and the entire compilation will be re-run. On a cache miss, we initially write
    /// all output files to a directory under '<cache>/tmp/', because we don't know the final
    /// manifest digest until the update is almost done. Once we can compute the final digest, this
    /// directory is moved to '<cache>/o/<hash>/'. Temporary files are not deleted.
    ///
    /// At the time of writing, this is the most commonly used cache mode: it is used by the build
    /// system (and any other parent using `--listen`) unless incremental compilation is enabled.
    /// Once incremental compilation is more mature, it will be replaced by `incremental` in many
    /// cases, but still has use cases, such as for release binaries, particularly globally cached
    /// artifacts like compiler_rt.
    whole,
};

pub const ParentWholeCache = struct {
    manifest: *Cache.Manifest,
    mutex: *std.Thread.Mutex,
    prefix_map: [4]u8,
};

const CacheUse = union(CacheMode) {
    none: *None,
    incremental: *Incremental,
    whole: *Whole,

    const None = struct {
        /// User-requested artifacts are written directly to their output path in this cache mode.
        /// However, if we need to emit any temporary files, they are placed in this directory.
        /// We will recursively delete this directory at the end of this update. This field is
        /// non-`null` only inside `update`.
        tmp_artifact_directory: ?Cache.Directory,
    };

    const Incremental = struct {
        /// All output files, including artifacts and incremental compilation metadata, are placed
        /// in this directory, which is some 'o/<hash>' in a cache directory.
        artifact_directory: Cache.Directory,
    };

    const Whole = struct {
        /// Since we don't open the output file until `update`, we must save these options for then.
        lf_open_opts: link.File.OpenOptions,
        /// This is a pointer to a local variable inside `update`.
        cache_manifest: ?*Cache.Manifest,
        cache_manifest_mutex: std.Thread.Mutex,
        /// This is non-`null` for most of the body of `update`. It is the temporary directory which
        /// we initially emit our artifacts to. After the main part of the update is done, it will
        /// be closed and moved to its final location, and this field set to `null`.
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

    fn deinit(cu: CacheUse) void {
        switch (cu) {
            .none => |none| {
                assert(none.tmp_artifact_directory == null);
            },
            .incremental => |incremental| {
                incremental.artifact_directory.handle.close();
            },
            .whole => |whole| {
                assert(whole.tmp_artifact_directory == null);
                whole.releaseLock();
            },
        }
    }
};

pub const CreateOptions = struct {
    dirs: Directories,
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
    cache_mode: CacheMode,
    emit_h: Emit = .no,
    emit_bin: Emit,
    emit_asm: Emit = .no,
    emit_implib: Emit = .no,
    emit_llvm_ir: Emit = .no,
    emit_llvm_bc: Emit = .no,
    emit_docs: Emit = .no,
    /// This field is intended to be removed.
    /// The ELF implementation no longer uses this data, however the MachO and COFF
    /// implementations still do.
    lib_directories: []const Cache.Directory = &.{},
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
    /// This means that if the output mode is an executable it will be a
    /// Position Independent Executable. If the output mode is not an
    /// executable this field is ignored.
    want_compiler_rt: ?bool = null,
    want_ubsan_rt: ?bool = null,
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
    linker_compress_debug_sections: ?link.File.Lld.Elf.CompressDebugSections = null,
    linker_module_definition_file: ?[]const u8 = null,
    linker_sort_section: ?link.File.Lld.Elf.SortSection = null,
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
    incremental: bool = false,
    /// Normally when you create a `Compilation`, Zig will automatically build
    /// and link in required dependencies, such as compiler-rt and libc. When
    /// building such dependencies themselves, this flag must be set to avoid
    /// infinite recursion.
    skip_linker_dependencies: bool = false,
    hash_style: link.File.Lld.Elf.HashStyle = .both,
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
    /// Whether local symbols should be discarded from the symbol table.
    discard_local_symbols: bool = false,
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

    /// Which fields are valid depends on the `cache_mode` given.
    pub const Emit = union(enum) {
        /// Do not emit this file. Always valid.
        no,
        /// Emit this file into its default name in the cache directory.
        /// Requires `cache_mode` to not be `.none`.
        yes_cache,
        /// Emit this file to the given path (absolute or cwd-relative).
        /// Requires `cache_mode` to be `.none`.
        yes_path: []const u8,

        fn resolve(emit: Emit, arena: Allocator, opts: *const CreateOptions, ea: std.zig.EmitArtifact) Allocator.Error!?[]const u8 {
            switch (emit) {
                .no => return null,
                .yes_cache => {
                    assert(opts.cache_mode != .none);
                    return try ea.cacheName(arena, .{
                        .root_name = opts.root_name,
                        .target = &opts.root_mod.resolved_target.result,
                        .output_mode = opts.config.output_mode,
                        .link_mode = opts.config.link_mode,
                        .version = opts.version,
                    });
                },
                .yes_path => |path| {
                    assert(opts.cache_mode == .none);
                    return try arena.dupe(u8, path);
                },
            }
        }
    };
};

fn addModuleTableToCacheHash(
    zcu: *Zcu,
    arena: Allocator,
    hash: *Cache.HashHelper,
    hash_type: union(enum) { path_bytes, files: *Cache.Manifest },
) error{
    OutOfMemory,
    Unexpected,
    CurrentWorkingDirectoryUnlinked,
}!void {
    assert(zcu.module_roots.count() != 0); // module_roots is populated

    for (zcu.module_roots.keys(), zcu.module_roots.values()) |mod, opt_mod_root_file| {
        if (mod == zcu.std_mod) continue; // redundant
        if (opt_mod_root_file.unwrap()) |mod_root_file| {
            if (zcu.fileByIndex(mod_root_file).is_builtin) continue; // redundant
        }
        cache_helpers.addModule(hash, mod);
        switch (hash_type) {
            .path_bytes => {
                hash.add(mod.root.root);
                hash.addBytes(mod.root.sub_path);
                hash.addBytes(mod.root_src_path);
            },
            .files => |man| if (mod.root_src_path.len != 0) {
                const root_src_path = try mod.root.toCachePath(zcu.comp.dirs).join(arena, mod.root_src_path);
                _ = try man.addFilePath(root_src_path, null);
            },
        }
        hash.addListOfBytes(mod.deps.keys());
    }
}

const RtStrat = enum { none, lib, obj, zcu, dyn_lib };

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
    const use_llvm = options.config.use_llvm;
    const target = &options.root_mod.resolved_target.result;

    const comp: *Compilation = comp: {
        // We put the `Compilation` itself in the arena. Freeing the arena will free the module.
        // It's initialized later after we prepare the initialization options.
        const root_name = try arena.dupeZ(u8, options.root_name);

        // The "any" values provided by resolved config only account for
        // explicitly-provided settings. We now make them additionally account
        // for default setting resolution.
        const any_unwind_tables = options.config.any_unwind_tables or options.root_mod.unwind_tables != .none;
        const any_non_single_threaded = options.config.any_non_single_threaded or !options.root_mod.single_threaded;
        const any_sanitize_thread = options.config.any_sanitize_thread or options.root_mod.sanitize_thread;
        const any_sanitize_c: std.zig.SanitizeC = switch (options.config.any_sanitize_c) {
            .off => options.root_mod.sanitize_c,
            .trap => if (options.root_mod.sanitize_c == .full)
                .full
            else
                .trap,
            .full => .full,
        };
        const any_fuzz = options.config.any_fuzz or options.root_mod.fuzz;

        const link_eh_frame_hdr = options.link_eh_frame_hdr or any_unwind_tables;
        const build_id = options.build_id orelse .none;

        const link_libc = options.config.link_libc;

        const libc_dirs = try std.zig.LibCDirs.detect(
            arena,
            options.dirs.zig_lib.path.?,
            target,
            options.root_mod.resolved_target.is_native_abi,
            link_libc,
            options.libc_installation,
        );

        const sysroot = options.sysroot orelse libc_dirs.sysroot;

        const compiler_rt_strat: RtStrat = s: {
            if (options.skip_linker_dependencies) break :s .none;
            const want = options.want_compiler_rt orelse is_exe_or_dyn_lib;
            if (!want) break :s .none;
            if (have_zcu) {
                if (output_mode == .Obj) break :s .zcu;
                if (target.ofmt == .coff and target_util.zigBackend(target, use_llvm) == .stage2_x86_64)
                    break :s if (is_exe_or_dyn_lib) .dyn_lib else .zcu;
            }
            if (is_exe_or_dyn_lib) break :s .lib;
            break :s .obj;
        };

        if (compiler_rt_strat == .zcu) {
            // For objects, this mechanism relies on essentially `_ = @import("compiler-rt");`
            // injected into the object.
            const compiler_rt_mod = try Package.Module.create(arena, .{
                .paths = .{
                    .root = .zig_lib_root,
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
            });
            try options.root_mod.deps.putNoClobber(arena, "compiler_rt", compiler_rt_mod);
        }

        // unlike compiler_rt, we always want to go through the `_ = @import("ubsan-rt")`
        // approach, since the ubsan runtime uses quite a lot of the standard library
        // and this reduces unnecessary bloat.
        const ubsan_rt_strat: RtStrat = s: {
            const can_build_ubsan_rt = target_util.canBuildLibUbsanRt(target);
            const want_ubsan_rt = options.want_ubsan_rt orelse (can_build_ubsan_rt and any_sanitize_c == .full and is_exe_or_dyn_lib);
            if (!want_ubsan_rt) break :s .none;
            if (options.skip_linker_dependencies) break :s .none;
            if (have_zcu) break :s .zcu;
            if (is_exe_or_dyn_lib) break :s .lib;
            break :s .obj;
        };

        if (ubsan_rt_strat == .zcu) {
            const ubsan_rt_mod = try Package.Module.create(arena, .{
                .paths = .{
                    .root = .zig_lib_root,
                    .root_src_path = "ubsan_rt.zig",
                },
                .fully_qualified_name = "ubsan_rt",
                .cc_argv = &.{},
                .inherited = .{},
                .global = options.config,
                .parent = options.root_mod,
            });
            try options.root_mod.deps.putNoClobber(arena, "ubsan_rt", ubsan_rt_mod);
        }

        if (options.verbose_llvm_cpu_features) {
            if (options.root_mod.resolved_target.llvm_cpu_features) |cf| print: {
                std.debug.lockStdErr();
                defer std.debug.unlockStdErr();
                const stderr = std.fs.File.stderr().deprecatedWriter();
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
            .manifest_dir = try options.dirs.local_cache.handle.makeOpenPath("h", .{}),
        };
        // These correspond to std.zig.Server.Message.PathPrefix.
        cache.addPrefix(.{ .path = null, .handle = std.fs.cwd() });
        cache.addPrefix(options.dirs.zig_lib);
        cache.addPrefix(options.dirs.local_cache);
        cache.addPrefix(options.dirs.global_cache);
        errdefer cache.manifest_dir.close();

        // This is shared hasher state common to zig source and all C source files.
        cache.hash.addBytes(build_options.version);
        cache.hash.add(builtin.zig_backend);
        cache.hash.add(options.config.pie);
        cache.hash.add(options.config.lto);
        cache.hash.add(options.config.link_mode);
        cache.hash.add(options.config.any_unwind_tables);
        cache.hash.add(options.config.any_non_single_threaded);
        cache.hash.add(options.config.any_sanitize_thread);
        cache.hash.add(options.config.any_sanitize_c);
        cache.hash.add(options.config.any_fuzz);
        cache.hash.add(options.function_sections);
        cache.hash.add(options.data_sections);
        cache.hash.add(link_libc);
        cache.hash.add(options.config.link_libcpp);
        cache.hash.add(options.config.link_libunwind);
        cache.hash.add(output_mode);
        cache_helpers.addDebugFormat(&cache.hash, options.config.debug_format);
        cache.hash.addBytes(options.root_name);
        cache.hash.add(options.config.wasi_exec_model);
        cache.hash.add(options.config.san_cov_trace_pc_guard);
        cache.hash.add(options.debug_compiler_runtime_libs);
        // The actual emit paths don't matter. They're only user-specified if we aren't using the
        // cache! However, it does matter whether the files are emitted at all.
        cache.hash.add(options.emit_bin != .no);
        cache.hash.add(options.emit_asm != .no);
        cache.hash.add(options.emit_implib != .no);
        cache.hash.add(options.emit_llvm_ir != .no);
        cache.hash.add(options.emit_llvm_bc != .no);
        cache.hash.add(options.emit_docs != .no);
        // TODO audit this and make sure everything is in it

        const main_mod = options.main_mod orelse options.root_mod;
        const comp = try arena.create(Compilation);
        const opt_zcu: ?*Zcu = if (have_zcu) blk: {
            // Pre-open the directory handles for cached ZIR code so that it does not need
            // to redundantly happen for each AstGen operation.
            const zir_sub_dir = "z";

            var local_zir_dir = try options.dirs.local_cache.handle.makeOpenPath(zir_sub_dir, .{});
            errdefer local_zir_dir.close();
            const local_zir_cache: Cache.Directory = .{
                .handle = local_zir_dir,
                .path = try options.dirs.local_cache.join(arena, &.{zir_sub_dir}),
            };
            var global_zir_dir = try options.dirs.global_cache.handle.makeOpenPath(zir_sub_dir, .{});
            errdefer global_zir_dir.close();
            const global_zir_cache: Cache.Directory = .{
                .handle = global_zir_dir,
                .path = try options.dirs.global_cache.join(arena, &.{zir_sub_dir}),
            };

            const std_mod = options.std_mod orelse try Package.Module.create(arena, .{
                .paths = .{
                    .root = try .fromRoot(arena, options.dirs, .zig_lib, "std"),
                    .root_src_path = "std.zig",
                },
                .fully_qualified_name = "std",
                .cc_argv = &.{},
                .inherited = .{},
                .global = options.config,
                .parent = options.root_mod,
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
            if (options.emit_h != .no) return error.NoZigModuleForCHeader;
            break :blk null;
        };
        errdefer if (opt_zcu) |zcu| zcu.deinit();

        comp.* = .{
            .gpa = gpa,
            .arena = arena,
            .zcu = opt_zcu,
            .cache_use = undefined, // populated below
            .bin_file = null, // populated below if necessary
            .root_mod = options.root_mod,
            .config = options.config,
            .dirs = options.dirs,
            .work_queues = @splat(.init(gpa)),
            .c_object_work_queue = .init(gpa),
            .win32_resource_work_queue = if (dev.env.supports(.win32_resource)) .init(gpa) else .{},
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
            .debug_incremental = options.debug_incremental,
            .incremental = options.incremental,
            .root_name = root_name,
            .sysroot = sysroot,
            .windows_libs = .empty,
            .version = options.version,
            .libc_installation = libc_dirs.libc_installation,
            .compiler_rt_strat = compiler_rt_strat,
            .ubsan_rt_strat = ubsan_rt_strat,
            .link_inputs = options.link_inputs,
            .framework_dirs = options.framework_dirs,
            .llvm_opt_bisect_limit = options.llvm_opt_bisect_limit,
            .skip_linker_dependencies = options.skip_linker_dependencies,
            .queued_jobs = .{},
            .function_sections = options.function_sections,
            .data_sections = options.data_sections,
            .native_system_include_paths = options.native_system_include_paths,
            .force_undefined_symbols = options.force_undefined_symbols,
            .link_eh_frame_hdr = link_eh_frame_hdr,
            .global_cc_argv = options.global_cc_argv,
            .file_system_inputs = options.file_system_inputs,
            .parent_whole_cache = options.parent_whole_cache,
            .link_diags = .init(gpa),
            .emit_bin = try options.emit_bin.resolve(arena, &options, .bin),
            .emit_asm = try options.emit_asm.resolve(arena, &options, .@"asm"),
            .emit_implib = try options.emit_implib.resolve(arena, &options, .implib),
            .emit_llvm_ir = try options.emit_llvm_ir.resolve(arena, &options, .llvm_ir),
            .emit_llvm_bc = try options.emit_llvm_bc.resolve(arena, &options, .llvm_bc),
            .emit_docs = try options.emit_docs.resolve(arena, &options, .docs),
        };

        comp.windows_libs = try std.StringArrayHashMapUnmanaged(void).init(gpa, options.windows_lib_names, &.{});
        errdefer comp.windows_libs.deinit(gpa);

        // Prevent some footguns by making the "any" fields of config reflect
        // the default Module settings.
        comp.config.any_unwind_tables = any_unwind_tables;
        comp.config.any_non_single_threaded = any_non_single_threaded;
        comp.config.any_sanitize_thread = any_sanitize_thread;
        comp.config.any_sanitize_c = any_sanitize_c;
        comp.config.any_fuzz = any_fuzz;

        if (opt_zcu) |zcu| {
            // Populate `zcu.module_roots`.
            const pt: Zcu.PerThread = .activate(zcu, .main);
            defer pt.deactivate();
            try pt.populateModuleRootTable();
        }

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
            .discard_local_symbols = options.discard_local_symbols,
            .pdb_source_path = options.pdb_source_path,
            .pdb_out_path = options.pdb_out_path,
            .entry_addr = null, // CLI does not expose this option (yet?)
            .object_host_name = "env",
        };

        switch (options.cache_mode) {
            .none => {
                const none = try arena.create(CacheUse.None);
                none.* = .{ .tmp_artifact_directory = null };
                comp.cache_use = .{ .none = none };
                if (comp.emit_bin) |path| {
                    comp.bin_file = try link.File.open(arena, comp, .{
                        .root_dir = .cwd(),
                        .sub_path = path,
                    }, lf_open_opts);
                }
            },
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
                hash.add(options.emit_h != .no);
                hash.add(error_limit);

                // Here we put the root source file path name, but *not* with addFile.
                // We want the hash to be the same regardless of the contents of the
                // source file, because incremental compilation will handle it, but we
                // do want to namespace different source file names because they are
                // likely different compilations and therefore this would be likely to
                // cause cache hits.
                if (comp.zcu) |zcu| {
                    try addModuleTableToCacheHash(zcu, arena, &hash, .path_bytes);
                } else {
                    cache_helpers.addModule(&hash, options.root_mod);
                }

                // In the case of incremental cache mode, this `artifact_directory`
                // is computed based on a hash of non-linker inputs, and it is where all
                // build artifacts are stored (even while in-progress).
                comp.digest = hash.peekBin();
                const digest = hash.final();

                const artifact_sub_dir = "o" ++ std.fs.path.sep_str ++ digest;
                var artifact_dir = try options.dirs.local_cache.handle.makeOpenPath(artifact_sub_dir, .{});
                errdefer artifact_dir.close();
                const artifact_directory: Cache.Directory = .{
                    .handle = artifact_dir,
                    .path = try options.dirs.local_cache.join(arena, &.{artifact_sub_dir}),
                };

                const incremental = try arena.create(CacheUse.Incremental);
                incremental.* = .{
                    .artifact_directory = artifact_directory,
                };
                comp.cache_use = .{ .incremental = incremental };

                if (comp.emit_bin) |cache_rel_path| {
                    const emit: Cache.Path = .{
                        .root_dir = artifact_directory,
                        .sub_path = cache_rel_path,
                    };
                    comp.bin_file = try link.File.open(arena, comp, emit, lf_open_opts);
                }
            },
            .whole => {
                // For whole cache mode, we don't know where to put outputs from the linker until
                // the final cache hash, which is available after the compilation is complete.
                //
                // Therefore, `comp.bin_file` is left `null` (already done) until `update`, where
                // it may find a cache hit, or else will use a temporary directory to hold output
                // artifacts.
                const whole = try arena.create(CacheUse.Whole);
                whole.* = .{
                    .lf_open_opts = lf_open_opts,
                    .cache_manifest = null,
                    .cache_manifest_mutex = .{},
                    .tmp_artifact_directory = null,
                    .lock = null,
                };
                comp.cache_use = .{ .whole = whole };
            },
        }

        if (use_llvm) {
            if (opt_zcu) |zcu| {
                zcu.llvm_object = try LlvmObject.create(arena, comp);
            }
        }

        break :comp comp;
    };
    errdefer comp.destroy();

    const can_build_compiler_rt = target_util.canBuildLibCompilerRt(target, use_llvm, build_options.have_llvm);

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
    comp.link_task_queue.pending_prelink_tasks += @intCast(comp.c_object_table.count());

    // Add a `Win32Resource` for each `rc_source_files` and one for `manifest_file`.
    const win32_resource_count =
        options.rc_source_files.len + @intFromBool(options.manifest_file != null);
    if (win32_resource_count > 0) {
        dev.check(.win32_resource);
        try comp.win32_resource_table.ensureTotalCapacity(gpa, win32_resource_count);
        // Add this after adding logic to updateWin32Resource to pass the
        // result into link.loadInput. loadInput integration is not implemented
        // for Windows linking logic yet.
        //comp.link_task_queue.pending_prelink_tasks += @intCast(win32_resource_count);
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

    if (comp.emit_bin != null and target.ofmt != .c) {
        if (!comp.skip_linker_dependencies) {
            // These DLLs are always loaded into every Windows process.
            if (target.os.tag == .windows and is_exe_or_dyn_lib) {
                try comp.windows_libs.ensureUnusedCapacity(gpa, 2);
                comp.windows_libs.putAssumeCapacity("kernel32", {});
                comp.windows_libs.putAssumeCapacity("ntdll", {});
            }

            // If we need to build libc for the target, add work items for it.
            // We go through the work queue so that building can be done in parallel.
            // If linking against host libc installation, instead queue up jobs
            // for loading those files in the linker.
            if (comp.config.link_libc and is_exe_or_dyn_lib) {
                // If the "is darwin" check is moved below the libc_installation check below,
                // error.LibCInstallationMissingCrtDir is returned from lci.resolveCrtPaths().
                if (target.isDarwinLibC()) {
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
                    try comp.link_task_queue.queued_prelink.ensureUnusedCapacity(gpa, fields.len + 1);
                    inline for (fields) |field| {
                        if (@field(paths, field.name)) |path| {
                            comp.link_task_queue.queued_prelink.appendAssumeCapacity(.{ .load_object = path });
                        }
                    }
                    // Loads the libraries provided by `target_util.libcFullLinkFlags(target)`.
                    comp.link_task_queue.queued_prelink.appendAssumeCapacity(.load_host_libc);
                } else if (target.isMuslLibC()) {
                    if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

                    if (musl.needsCrt0(comp.config.output_mode, comp.config.link_mode, comp.config.pie)) |f| {
                        comp.queued_jobs.musl_crt_file[@intFromEnum(f)] = true;
                        comp.link_task_queue.pending_prelink_tasks += 1;
                    }
                    switch (comp.config.link_mode) {
                        .static => comp.queued_jobs.musl_crt_file[@intFromEnum(musl.CrtFile.libc_a)] = true,
                        .dynamic => comp.queued_jobs.musl_crt_file[@intFromEnum(musl.CrtFile.libc_so)] = true,
                    }
                    comp.link_task_queue.pending_prelink_tasks += 1;
                } else if (target.isGnuLibC()) {
                    if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

                    if (glibc.needsCrt0(comp.config.output_mode)) |f| {
                        comp.queued_jobs.glibc_crt_file[@intFromEnum(f)] = true;
                        comp.link_task_queue.pending_prelink_tasks += 1;
                    }
                    comp.queued_jobs.glibc_shared_objects = true;
                    comp.link_task_queue.pending_prelink_tasks += glibc.sharedObjectsCount(target);

                    comp.queued_jobs.glibc_crt_file[@intFromEnum(glibc.CrtFile.libc_nonshared_a)] = true;
                    comp.link_task_queue.pending_prelink_tasks += 1;
                } else if (target.isFreeBSDLibC()) {
                    if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

                    if (freebsd.needsCrt0(comp.config.output_mode)) |f| {
                        comp.queued_jobs.freebsd_crt_file[@intFromEnum(f)] = true;
                        comp.link_task_queue.pending_prelink_tasks += 1;
                    }

                    comp.queued_jobs.freebsd_shared_objects = true;
                    comp.link_task_queue.pending_prelink_tasks += freebsd.sharedObjectsCount();
                } else if (target.isNetBSDLibC()) {
                    if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

                    if (netbsd.needsCrt0(comp.config.output_mode)) |f| {
                        comp.queued_jobs.netbsd_crt_file[@intFromEnum(f)] = true;
                        comp.link_task_queue.pending_prelink_tasks += 1;
                    }

                    comp.queued_jobs.netbsd_shared_objects = true;
                    comp.link_task_queue.pending_prelink_tasks += netbsd.sharedObjectsCount();
                } else if (target.isWasiLibC()) {
                    if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

                    comp.queued_jobs.wasi_libc_crt_file[@intFromEnum(wasi_libc.execModelCrtFile(comp.config.wasi_exec_model))] = true;
                    comp.queued_jobs.wasi_libc_crt_file[@intFromEnum(wasi_libc.CrtFile.libc_a)] = true;
                    comp.link_task_queue.pending_prelink_tasks += 2;
                } else if (target.isMinGW()) {
                    if (!std.zig.target.canBuildLibC(target)) return error.LibCUnavailable;

                    const main_crt_file: mingw.CrtFile = if (is_dyn_lib) .dllcrt2_o else .crt2_o;
                    comp.queued_jobs.mingw_crt_file[@intFromEnum(main_crt_file)] = true;
                    comp.queued_jobs.mingw_crt_file[@intFromEnum(mingw.CrtFile.libmingw32_lib)] = true;
                    comp.link_task_queue.pending_prelink_tasks += 2;

                    // When linking mingw-w64 there are some import libs we always need.
                    try comp.windows_libs.ensureUnusedCapacity(gpa, mingw.always_link_libs.len);
                    for (mingw.always_link_libs) |name| comp.windows_libs.putAssumeCapacity(name, {});
                } else {
                    return error.LibCUnavailable;
                }

                if ((target.isMuslLibC() and comp.config.link_mode == .static) or
                    target.isWasiLibC() or
                    target.isMinGW())
                {
                    comp.queued_jobs.zigc_lib = true;
                    comp.link_task_queue.pending_prelink_tasks += 1;
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
                comp.link_task_queue.pending_prelink_tasks += 1;
            }
            if (build_options.have_llvm and is_exe_or_dyn_lib and comp.config.link_libcpp) {
                comp.queued_jobs.libcxx = true;
                comp.queued_jobs.libcxxabi = true;
                comp.link_task_queue.pending_prelink_tasks += 2;
            }
            if (build_options.have_llvm and is_exe_or_dyn_lib and comp.config.any_sanitize_thread) {
                comp.queued_jobs.libtsan = true;
                comp.link_task_queue.pending_prelink_tasks += 1;
            }

            if (can_build_compiler_rt) {
                if (comp.compiler_rt_strat == .lib) {
                    log.debug("queuing a job to build compiler_rt_lib", .{});
                    comp.queued_jobs.compiler_rt_lib = true;
                    comp.link_task_queue.pending_prelink_tasks += 1;
                } else if (comp.compiler_rt_strat == .obj) {
                    log.debug("queuing a job to build compiler_rt_obj", .{});
                    // In this case we are making a static library, so we ask
                    // for a compiler-rt object to put in it.
                    comp.queued_jobs.compiler_rt_obj = true;
                    comp.link_task_queue.pending_prelink_tasks += 1;
                } else if (comp.compiler_rt_strat == .dyn_lib) {
                    // hack for stage2_x86_64 + coff
                    log.debug("queuing a job to build compiler_rt_dyn_lib", .{});
                    comp.queued_jobs.compiler_rt_dyn_lib = true;
                    comp.link_task_queue.pending_prelink_tasks += 1;
                }

                if (comp.ubsan_rt_strat == .lib) {
                    log.debug("queuing a job to build ubsan_rt_lib", .{});
                    comp.queued_jobs.ubsan_rt_lib = true;
                    comp.link_task_queue.pending_prelink_tasks += 1;
                } else if (comp.ubsan_rt_strat == .obj) {
                    log.debug("queuing a job to build ubsan_rt_obj", .{});
                    comp.queued_jobs.ubsan_rt_obj = true;
                    comp.link_task_queue.pending_prelink_tasks += 1;
                }

                if (is_exe_or_dyn_lib and comp.config.any_fuzz) {
                    log.debug("queuing a job to build libfuzzer", .{});
                    comp.queued_jobs.fuzzer_lib = true;
                    comp.link_task_queue.pending_prelink_tasks += 1;
                }
            }
        }

        try comp.link_task_queue.queued_prelink.append(gpa, .load_explicitly_provided);
    }
    log.debug("queued prelink tasks: {d}", .{comp.link_task_queue.queued_prelink.items.len});
    log.debug("pending prelink tasks: {d}", .{comp.link_task_queue.pending_prelink_tasks});

    return comp;
}

pub fn destroy(comp: *Compilation) void {
    const gpa = comp.gpa;

    // This needs to be destroyed first, because it might contain MIR which we only know
    // how to interpret (which kind of MIR it is) from `comp.bin_file`.
    comp.link_task_queue.deinit(comp);

    if (comp.bin_file) |lf| lf.destroy();
    if (comp.zcu) |zcu| zcu.deinit();
    comp.cache_use.deinit();

    for (comp.work_queues) |work_queue| work_queue.deinit();
    comp.c_object_work_queue.deinit();
    comp.win32_resource_work_queue.deinit();

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
    if (comp.ubsan_rt_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }
    if (comp.ubsan_rt_obj) |*crt_file| {
        crt_file.deinit(gpa);
    }
    if (comp.fuzzer_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }

    if (comp.zigc_static_lib) |*crt_file| {
        crt_file.deinit(gpa);
    }

    if (comp.glibc_so_files) |*glibc_file| {
        glibc_file.deinit(gpa);
    }

    if (comp.freebsd_so_files) |*freebsd_file| {
        freebsd_file.deinit(gpa);
    }

    if (comp.netbsd_so_files) |*netbsd_file| {
        netbsd_file.deinit(gpa);
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

    comp.clearMiscFailures();

    comp.cache_parent.manifest_dir.close();
}

pub fn clearMiscFailures(comp: *Compilation) void {
    comp.alloc_failure_occurred = false;
    comp.link_diags.flags = .{};
    for (comp.misc_failures.values()) |*value| {
        value.deinit(comp.gpa);
    }
    comp.misc_failures.deinit(comp.gpa);
    comp.misc_failures = .{};
}

pub fn getTarget(self: *const Compilation) *const Target {
    return &self.root_mod.resolved_target.result;
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

fn cleanupAfterUpdate(comp: *Compilation, tmp_dir_rand_int: u64) void {
    switch (comp.cache_use) {
        .none => |none| {
            if (none.tmp_artifact_directory) |*tmp_dir| {
                tmp_dir.handle.close();
                none.tmp_artifact_directory = null;
                if (dev.env == .bootstrap) {
                    // zig1 uses `CacheMode.none`, but it doesn't need to know how to delete
                    // temporary directories; it doesn't have a real cache directory anyway.
                    return;
                }
                const tmp_dir_sub_path = "tmp" ++ std.fs.path.sep_str ++ std.fmt.hex(tmp_dir_rand_int);
                comp.dirs.local_cache.handle.deleteTree(tmp_dir_sub_path) catch |err| {
                    log.warn("failed to delete temporary directory '{s}{c}{s}': {s}", .{
                        comp.dirs.local_cache.path orelse ".",
                        std.fs.path.sep,
                        tmp_dir_sub_path,
                        @errorName(err),
                    });
                };
            }
        },
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
            if (whole.tmp_artifact_directory) |*tmp_dir| {
                tmp_dir.handle.close();
                whole.tmp_artifact_directory = null;
                const tmp_dir_sub_path = "tmp" ++ std.fs.path.sep_str ++ std.fmt.hex(tmp_dir_rand_int);
                comp.dirs.local_cache.handle.deleteTree(tmp_dir_sub_path) catch |err| {
                    log.warn("failed to delete temporary directory '{s}{c}{s}': {s}", .{
                        comp.dirs.local_cache.path orelse ".",
                        std.fs.path.sep,
                        tmp_dir_sub_path,
                        @errorName(err),
                    });
                };
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

    var tmp_dir_rand_int: u64 = undefined;
    var man: Cache.Manifest = undefined;
    defer cleanupAfterUpdate(comp, tmp_dir_rand_int);

    // If using the whole caching strategy, we check for *everything* up front, including
    // C source files.
    log.debug("Compilation.update for {s}, CacheMode.{s}", .{ comp.root_name, @tagName(comp.cache_use) });
    switch (comp.cache_use) {
        .none => |none| {
            assert(none.tmp_artifact_directory == null);
            none.tmp_artifact_directory = d: {
                tmp_dir_rand_int = std.crypto.random.int(u64);
                const tmp_dir_sub_path = "tmp" ++ std.fs.path.sep_str ++ std.fmt.hex(tmp_dir_rand_int);
                const path = try comp.dirs.local_cache.join(arena, &.{tmp_dir_sub_path});
                break :d .{
                    .path = path,
                    .handle = try comp.dirs.local_cache.handle.makeOpenPath(tmp_dir_sub_path, .{}),
                };
            };
        },
        .incremental => {},
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
                            "failed to check cache: '{f}{s}' {s} {s}",
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

                comp.digest = bin_digest;

                assert(whole.lock == null);
                whole.lock = man.toOwnedLock();
                return;
            }
            log.debug("CacheMode.whole cache miss for {s}", .{comp.root_name});

            // Compile the artifacts to a temporary directory.
            whole.tmp_artifact_directory = d: {
                tmp_dir_rand_int = std.crypto.random.int(u64);
                const tmp_dir_sub_path = "tmp" ++ std.fs.path.sep_str ++ std.fmt.hex(tmp_dir_rand_int);
                const path = try comp.dirs.local_cache.join(arena, &.{tmp_dir_sub_path});
                break :d .{
                    .path = path,
                    .handle = try comp.dirs.local_cache.handle.makeOpenPath(tmp_dir_sub_path, .{}),
                };
            };
            if (comp.emit_bin) |sub_path| {
                const emit: Cache.Path = .{
                    .root_dir = whole.tmp_artifact_directory.?,
                    .sub_path = sub_path,
                };
                comp.bin_file = try link.File.createEmpty(arena, comp, emit, whole.lf_open_opts);
            }
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
    for (comp.c_object_table.keys()) |c_object| {
        comp.c_object_work_queue.writeItemAssumeCapacity(c_object);
        try comp.appendFileSystemInput(try .fromUnresolved(arena, comp.dirs, &.{c_object.src.src_path}));
    }

    // For compiling Win32 resources, we rely on the cache hash system to avoid duplicating work.
    // Add a Job for each Win32 resource file.
    try comp.win32_resource_work_queue.ensureUnusedCapacity(comp.win32_resource_table.count());
    for (comp.win32_resource_table.keys()) |win32_resource| {
        comp.win32_resource_work_queue.writeItemAssumeCapacity(win32_resource);
        switch (win32_resource.src) {
            .rc => |f| {
                try comp.appendFileSystemInput(try .fromUnresolved(arena, comp.dirs, &.{f.src_path}));
            },
            .manifest => {},
        }
    }

    if (comp.zcu) |zcu| {
        const pt: Zcu.PerThread = .activate(zcu, .main);
        defer pt.deactivate();

        zcu.skip_analysis_this_update = false;

        // TODO: doing this in `resolveReferences` later could avoid adding inputs for dead embedfiles. Investigate!
        for (zcu.embed_table.keys()) |embed_file| {
            try comp.appendFileSystemInput(embed_file.path);
        }

        zcu.analysis_roots.clear();

        zcu.analysis_roots.appendAssumeCapacity(zcu.std_mod);

        // Normally we rely on importing std to in turn import the root source file in the start code.
        // However, the main module is distinct from the root module in tests, so that won't happen there.
        if (comp.config.is_test and zcu.main_mod != zcu.std_mod) {
            zcu.analysis_roots.appendAssumeCapacity(zcu.main_mod);
        }

        if (zcu.root_mod.deps.get("compiler_rt")) |compiler_rt_mod| {
            zcu.analysis_roots.appendAssumeCapacity(compiler_rt_mod);
        }

        if (zcu.root_mod.deps.get("ubsan_rt")) |ubsan_rt_mod| {
            zcu.analysis_roots.appendAssumeCapacity(ubsan_rt_mod);
        }
    }

    // The linker progress node is set up here instead of in `performAllTheWork`, because
    // we also want it around during `flush`.
    const have_link_node = comp.bin_file != null;
    if (have_link_node) {
        comp.link_prog_node = main_progress_node.start("Linking", 0);
    }
    defer if (have_link_node) {
        comp.link_prog_node.end();
        comp.link_prog_node = .none;
    };

    try comp.performAllTheWork(main_progress_node);

    if (comp.zcu) |zcu| {
        const pt: Zcu.PerThread = .activate(zcu, .main);
        defer pt.deactivate();

        if (!zcu.skip_analysis_this_update) {
            if (comp.config.is_test) {
                // The `test_functions` decl has been intentionally postponed until now,
                // at which point we must populate it with the list of test functions that
                // have been discovered and not filtered out.
                try pt.populateTestFunctions();
            }

            try pt.processExports();
        }

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
    }

    if (anyErrors(comp)) {
        // Skip flushing and keep source files loaded for error reporting.
        return;
    }

    if (comp.zcu == null and comp.config.output_mode == .Obj and comp.c_object_table.count() == 1) {
        // This is `zig build-obj foo.c`. We can emit asm and LLVM IR/bitcode.
        const c_obj_path = comp.c_object_table.keys()[0].status.success.object_path;
        if (comp.emit_asm) |path| try comp.emitFromCObject(arena, c_obj_path, ".s", path);
        if (comp.emit_llvm_ir) |path| try comp.emitFromCObject(arena, c_obj_path, ".ll", path);
        if (comp.emit_llvm_bc) |path| try comp.emitFromCObject(arena, c_obj_path, ".bc", path);
    }

    switch (comp.cache_use) {
        .none, .incremental => {
            try flush(comp, arena, .main);
        },
        .whole => |whole| {
            if (comp.file_system_inputs) |buf| try man.populateFileSystemInputs(buf);
            if (comp.parent_whole_cache) |pwc| {
                pwc.mutex.lock();
                defer pwc.mutex.unlock();
                try man.populateOtherManifest(pwc.manifest, pwc.prefix_map);
            }

            const bin_digest = man.finalBin();
            const hex_digest = Cache.binToHex(bin_digest);

            // Work around windows `AccessDenied` if any files within this
            // directory are open by closing and reopening the file handles.
            const need_writable_dance: enum { no, lf_only, lf_and_debug } = w: {
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

                            if (lf.closeDebugInfo()) break :w .lf_and_debug;
                            break :w .lf_only;
                        }
                    }
                }
                break :w .no;
            };

            // Rename the temporary directory into place.
            // Close tmp dir and link.File to avoid open handle during rename.
            whole.tmp_artifact_directory.?.handle.close();
            whole.tmp_artifact_directory = null;
            const s = std.fs.path.sep_str;
            const tmp_dir_sub_path = "tmp" ++ s ++ std.fmt.hex(tmp_dir_rand_int);
            const o_sub_path = "o" ++ s ++ hex_digest;
            renameTmpIntoCache(comp.dirs.local_cache, tmp_dir_sub_path, o_sub_path) catch |err| {
                return comp.setMiscFailure(
                    .rename_results,
                    "failed to rename compilation results ('{f}{s}') into local cache ('{f}{s}'): {s}",
                    .{
                        comp.dirs.local_cache, tmp_dir_sub_path,
                        comp.dirs.local_cache, o_sub_path,
                        @errorName(err),
                    },
                );
            };
            comp.digest = bin_digest;

            // The linker flush functions need to know the final output path
            // for debug info purposes because executable debug info contains
            // references object file paths.
            if (comp.bin_file) |lf| {
                lf.emit = .{
                    .root_dir = comp.dirs.local_cache,
                    .sub_path = try std.fs.path.join(arena, &.{ o_sub_path, comp.emit_bin.? }),
                };

                switch (need_writable_dance) {
                    .no => {},
                    .lf_only => try lf.makeWritable(),
                    .lf_and_debug => {
                        try lf.makeWritable();
                        try lf.reopenDebugInfo();
                    },
                }
            }

            try flush(comp, arena, .main);

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
    }
}

pub fn appendFileSystemInput(comp: *Compilation, path: Compilation.Path) Allocator.Error!void {
    const gpa = comp.gpa;
    const fsi = comp.file_system_inputs orelse return;
    const prefixes = comp.cache_parent.prefixes();

    const want_prefix_dir: Cache.Directory = switch (path.root) {
        .zig_lib => comp.dirs.zig_lib,
        .global_cache => comp.dirs.global_cache,
        .local_cache => comp.dirs.local_cache,
        .none => .cwd(),
    };
    const prefix: u8 = for (prefixes, 1..) |prefix_dir, i| {
        if (prefix_dir.eql(want_prefix_dir)) {
            break @intCast(i);
        }
    } else std.debug.panic(
        "missing prefix directory '{s}' ('{f}') for '{s}'",
        .{ @tagName(path.root), want_prefix_dir, path.sub_path },
    );

    try fsi.ensureUnusedCapacity(gpa, path.sub_path.len + 3);
    if (fsi.items.len > 0) fsi.appendAssumeCapacity(0);
    fsi.appendAssumeCapacity(prefix);
    fsi.appendSliceAssumeCapacity(path.sub_path);
}

fn resolveEmitPath(comp: *Compilation, path: []const u8) Cache.Path {
    return .{
        .root_dir = switch (comp.cache_use) {
            .none => .cwd(),
            .incremental => |i| i.artifact_directory,
            .whole => |w| w.tmp_artifact_directory.?,
        },
        .sub_path = path,
    };
}
/// Like `resolveEmitPath`, but for calling during `flush`. The returned `Cache.Path` may reference
/// memory from `arena`, and may reference `path` itself.
/// If `kind == .temp`, then the returned path will be in a temporary or cache directory. This is
/// useful for intermediate files, such as the ZCU object file emitted by the LLVM backend.
pub fn resolveEmitPathFlush(
    comp: *Compilation,
    arena: Allocator,
    kind: enum { temp, artifact },
    path: []const u8,
) Allocator.Error!Cache.Path {
    switch (comp.cache_use) {
        .none => |none| return .{
            .root_dir = switch (kind) {
                .temp => none.tmp_artifact_directory.?,
                .artifact => .cwd(),
            },
            .sub_path = path,
        },
        .incremental, .whole => return .{
            .root_dir = comp.dirs.local_cache,
            .sub_path = try fs.path.join(arena, &.{
                "o",
                &Cache.binToHex(comp.digest.?),
                path,
            }),
        },
    }
}
fn flush(
    comp: *Compilation,
    arena: Allocator,
    tid: Zcu.PerThread.Id,
) !void {
    if (comp.zcu) |zcu| {
        if (zcu.llvm_object) |llvm_object| {
            // Emit the ZCU object from LLVM now; it's required to flush the output file.
            // If there's an output file, it wants to decide where the LLVM object goes!
            const sub_prog_node = comp.link_prog_node.start("LLVM Emit Object", 0);
            defer sub_prog_node.end();
            try llvm_object.emit(.{
                .pre_ir_path = comp.verbose_llvm_ir,
                .pre_bc_path = comp.verbose_llvm_bc,

                .bin_path = p: {
                    const lf = comp.bin_file orelse break :p null;
                    const p = try comp.resolveEmitPathFlush(arena, .temp, lf.zcu_object_basename.?);
                    break :p try p.toStringZ(arena);
                },
                .asm_path = p: {
                    const raw = comp.emit_asm orelse break :p null;
                    const p = try comp.resolveEmitPathFlush(arena, .artifact, raw);
                    break :p try p.toStringZ(arena);
                },
                .post_ir_path = p: {
                    const raw = comp.emit_llvm_ir orelse break :p null;
                    const p = try comp.resolveEmitPathFlush(arena, .artifact, raw);
                    break :p try p.toStringZ(arena);
                },
                .post_bc_path = p: {
                    const raw = comp.emit_llvm_bc orelse break :p null;
                    const p = try comp.resolveEmitPathFlush(arena, .artifact, raw);
                    break :p try p.toStringZ(arena);
                },

                .is_debug = comp.root_mod.optimize_mode == .Debug,
                .is_small = comp.root_mod.optimize_mode == .ReleaseSmall,
                .time_report = comp.time_report,
                .sanitize_thread = comp.config.any_sanitize_thread,
                .fuzz = comp.config.any_fuzz,
                .lto = comp.config.lto,
            });
        }
    }
    if (comp.bin_file) |lf| {
        // This is needed before reading the error flags.
        lf.flush(arena, tid, comp.link_prog_node) catch |err| switch (err) {
            error.LinkFailure => {}, // Already reported.
            error.OutOfMemory => return error.OutOfMemory,
        };
    }
    if (comp.zcu) |zcu| {
        try link.File.C.flushEmitH(zcu);
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
    cache_directory: Cache.Directory,
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
    comptime assert(link_hash_implementation_version == 14);

    if (comp.zcu) |zcu| {
        try addModuleTableToCacheHash(zcu, arena, &man.hash, .{ .files = man });

        // Synchronize with other matching comments: ZigOnlyHashStuff
        man.hash.addListOfBytes(comp.test_filters);
        man.hash.addOptionalBytes(comp.test_name_prefix);
        man.hash.add(comp.skip_linker_dependencies);
        //man.hash.add(zcu.emit_h != .no);
        man.hash.add(zcu.error_limit);
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
    man.hash.add(comp.compiler_rt_strat);
    man.hash.add(comp.ubsan_rt_strat);
    man.hash.add(comp.rc_includes);
    man.hash.addListOfBytes(comp.force_undefined_symbols.keys());
    man.hash.addListOfBytes(comp.framework_dirs);
    man.hash.addListOfBytes(comp.windows_libs.keys());

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
    const target = &comp.root_mod.resolved_target.result;
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

    const EntryTag = @typeInfo(link.File.OpenOptions.Entry).@"union".tag_type.?;
    man.hash.add(@as(EntryTag, opts.entry));
    switch (opts.entry) {
        .default, .disabled, .enabled => {},
        .named => |name| man.hash.addBytes(name),
    }

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
    man.hash.add(opts.import_symbols);
    man.hash.add(opts.import_table);
    man.hash.add(opts.export_table);

    // Mach-O specific stuff
    try link.File.MachO.hashAddFrameworks(man, opts.frameworks);
    try man.addOptionalFile(opts.entitlements);
    man.hash.addOptional(opts.pagezero_size);
    man.hash.addOptional(opts.headerpad_size);
    man.hash.add(opts.headerpad_max_install_names);
    man.hash.add(opts.dead_strip_dylibs);
    man.hash.add(opts.force_load_objc);
    man.hash.add(opts.discard_local_symbols);
    man.hash.addOptional(opts.compatibility_version);
    man.hash.addOptionalBytes(opts.install_name);
    man.hash.addOptional(opts.darwin_sdk_layout);

    // COFF specific stuff
    man.hash.addOptional(opts.subsystem);
    man.hash.add(opts.tsaware);
    man.hash.add(opts.nxcompat);
    man.hash.add(opts.dynamicbase);
    man.hash.addOptional(opts.major_subsystem_version);
    man.hash.addOptional(opts.minor_subsystem_version);
    man.hash.addOptionalBytes(opts.pdb_source_path);
    man.hash.addOptionalBytes(opts.module_definition_file);
}

fn emitFromCObject(
    comp: *Compilation,
    arena: Allocator,
    c_obj_path: Cache.Path,
    new_ext: []const u8,
    unresolved_emit_path: []const u8,
) Allocator.Error!void {
    // The dirname and stem (i.e. everything but the extension), of the sub path of the C object.
    // We'll append `new_ext` to it to get the path to the right thing (asm, LLVM IR, etc).
    const c_obj_dir_and_stem: []const u8 = p: {
        const p = c_obj_path.sub_path;
        const ext_len = fs.path.extension(p).len;
        break :p p[0 .. p.len - ext_len];
    };
    const src_path: Cache.Path = .{
        .root_dir = c_obj_path.root_dir,
        .sub_path = try std.fmt.allocPrint(arena, "{s}{s}", .{
            c_obj_dir_and_stem,
            new_ext,
        }),
    };
    const emit_path = comp.resolveEmitPath(unresolved_emit_path);

    src_path.root_dir.handle.copyFile(
        src_path.sub_path,
        emit_path.root_dir.handle,
        emit_path.sub_path,
        .{},
    ) catch |err| log.err("unable to copy '{f}' to '{f}': {s}", .{
        src_path,
        emit_path,
        @errorName(err),
    });
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
            addBuf(&bufs, mem.sliceAsBytes(wasm.mir_locals.items));
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
        if (zcu.multi_module_err != null) {
            try zcu.addFileInMultipleModulesError(&bundle);
            break :zcu_errors;
        }
        for (zcu.failed_imports.items) |failed| {
            assert(zcu.alive_files.contains(failed.file_index)); // otherwise it wouldn't have been added
            const file = zcu.fileByIndex(failed.file_index);
            const source = try file.getSource(zcu);
            const tree = try file.getTree(zcu);
            const start = tree.tokenStart(failed.import_token);
            const end = start + tree.tokenSlice(failed.import_token).len;
            const loc = std.zig.findLineColumn(source.bytes, start);
            try bundle.addRootErrorMessage(.{
                .msg = switch (failed.kind) {
                    .file_outside_module_root => try bundle.addString("import of file outside module path"),
                    .illegal_zig_import => try bundle.addString("this compiler implementation does not allow importing files from this directory"),
                },
                .src_loc = try bundle.addSourceLocation(.{
                    .src_path = try bundle.printString("{f}", .{file.path.fmt(comp)}),
                    .span_start = start,
                    .span_main = start,
                    .span_end = @intCast(end),
                    .line = @intCast(loc.line),
                    .column = @intCast(loc.column),
                    .source_line = try bundle.addString(loc.source_line),
                }),
                .notes_len = 0,
            });
        }

        // Before iterating `failed_files`, we need to sort it into a consistent order so that error
        // messages appear consistently despite different ordering from the AstGen worker pool. File
        // paths are a great key for this sort! We are using sorting the `ArrayHashMap` itself to
        // make sure it reindexes; that's important because these entries need to be retained for
        // future updates.
        const FileSortCtx = struct {
            zcu: *Zcu,
            failed_files_keys: []const Zcu.File.Index,
            pub fn lessThan(ctx: @This(), lhs_index: usize, rhs_index: usize) bool {
                const lhs_path = ctx.zcu.fileByIndex(ctx.failed_files_keys[lhs_index]).path;
                const rhs_path = ctx.zcu.fileByIndex(ctx.failed_files_keys[rhs_index]).path;
                if (lhs_path.root != rhs_path.root) return @intFromEnum(lhs_path.root) < @intFromEnum(rhs_path.root);
                return std.mem.order(u8, lhs_path.sub_path, rhs_path.sub_path).compare(.lt);
            }
        };
        zcu.failed_files.sort(@as(FileSortCtx, .{
            .zcu = zcu,
            .failed_files_keys = zcu.failed_files.keys(),
        }));

        for (zcu.failed_files.keys(), zcu.failed_files.values()) |file_index, error_msg| {
            if (!zcu.alive_files.contains(file_index)) continue;
            const file = zcu.fileByIndex(file_index);
            const is_retryable = switch (file.status) {
                .retryable_failure => true,
                .success, .astgen_failure => false,
                .never_loaded => unreachable,
            };
            if (error_msg) |msg| {
                assert(is_retryable);
                try addWholeFileError(zcu, &bundle, file_index, msg);
            } else {
                assert(!is_retryable);
                // AstGen/ZoirGen succeeded with errors. Note that this may include AST errors.
                _ = try file.getTree(zcu); // Tree must be loaded.
                const path = try std.fmt.allocPrint(gpa, "{f}", .{file.path.fmt(comp)});
                defer gpa.free(path);
                if (file.zir != null) {
                    try bundle.addZirErrorMessages(file.zir.?, file.tree.?, file.source.?, path);
                } else if (file.zoir != null) {
                    try bundle.addZoirErrorMessages(file.zoir.?, file.tree.?, file.source.?, path);
                } else {
                    // Either Zir or Zoir must have been loaded.
                    unreachable;
                }
            }
        }
        if (zcu.skip_analysis_this_update) break :zcu_errors;
        var sorted_failed_analysis: std.AutoArrayHashMapUnmanaged(InternPool.AnalUnit, *Zcu.ErrorMsg).DataList.Slice = s: {
            const SortOrder = struct {
                zcu: *Zcu,
                errors: []const *Zcu.ErrorMsg,
                err: *?Error,

                const Error = @typeInfo(
                    @typeInfo(@TypeOf(Zcu.LazySrcLoc.lessThan)).@"fn".return_type.?,
                ).error_union.error_set;

                pub fn lessThan(ctx: @This(), lhs_index: usize, rhs_index: usize) bool {
                    if (ctx.err.* != null) return lhs_index < rhs_index;
                    return ctx.errors[lhs_index].src_loc.lessThan(ctx.errors[rhs_index].src_loc, ctx.zcu) catch |e| {
                        ctx.err.* = e;
                        return lhs_index < rhs_index;
                    };
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
        var added_any_analysis_error = false;
        for (sorted_failed_analysis.items(.key), sorted_failed_analysis.items(.value)) |anal_unit, error_msg| {
            if (comp.incremental) {
                const refs = try zcu.resolveReferences();
                if (!refs.contains(anal_unit)) continue;
            }

            std.log.scoped(.zcu).debug("analysis error '{s}' reported from unit '{f}'", .{
                error_msg.msg, zcu.fmtAnalUnit(anal_unit),
            });

            try addModuleErrorMsg(zcu, &bundle, error_msg.*, added_any_analysis_error);
            added_any_analysis_error = true;

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
            try addModuleErrorMsg(zcu, &bundle, error_msg.*, false);
        }
        for (zcu.failed_types.values()) |error_msg| {
            try addModuleErrorMsg(zcu, &bundle, error_msg.*, false);
        }
        for (zcu.failed_exports.values()) |value| {
            try addModuleErrorMsg(zcu, &bundle, value.*, false);
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

    const compile_log_text: []const u8 = compile_log_text: {
        const zcu = comp.zcu orelse break :compile_log_text "";
        if (zcu.skip_analysis_this_update) break :compile_log_text "";
        if (zcu.compile_logs.count() == 0) break :compile_log_text "";

        // If there are no other errors, we include a "found compile log statement" error.
        // Otherwise, we just show the compile log output, with no error.
        const include_compile_log_sources = bundle.root_list.items.len == 0;

        const refs = try zcu.resolveReferences();

        var messages: std.ArrayListUnmanaged(Zcu.ErrorMsg) = .empty;
        defer messages.deinit(gpa);
        for (zcu.compile_logs.keys(), zcu.compile_logs.values()) |logging_unit, compile_log| {
            if (!refs.contains(logging_unit)) continue;
            try messages.append(gpa, .{
                .src_loc = compile_log.src(),
                .msg = undefined, // populated later
                .notes = &.{},
                // We actually clear this later for most of these, but we populate
                // this field for now to avoid having to allocate more data to track
                // which compile log text this corresponds to.
                .reference_trace_root = logging_unit.toOptional(),
            });
        }

        if (messages.items.len == 0) break :compile_log_text "";

        // Okay, there *are* referenced compile logs. Sort them into a consistent order.

        const SortContext = struct {
            err: *?Error,
            zcu: *Zcu,
            const Error = @typeInfo(
                @typeInfo(@TypeOf(Zcu.LazySrcLoc.lessThan)).@"fn".return_type.?,
            ).error_union.error_set;
            fn lessThan(ctx: @This(), lhs: Zcu.ErrorMsg, rhs: Zcu.ErrorMsg) bool {
                if (ctx.err.* != null) return false;
                return lhs.src_loc.lessThan(rhs.src_loc, ctx.zcu) catch |e| {
                    ctx.err.* = e;
                    return false;
                };
            }
        };
        var sort_err: ?SortContext.Error = null;
        std.mem.sort(Zcu.ErrorMsg, messages.items, @as(SortContext, .{ .err = &sort_err, .zcu = zcu }), SortContext.lessThan);
        if (sort_err) |e| return e;

        var log_text: std.ArrayListUnmanaged(u8) = .empty;
        defer log_text.deinit(gpa);

        // Index 0 will be the root message; the rest will be notes.
        // Only the actual message, i.e. index 0, will retain its reference trace.
        try appendCompileLogLines(&log_text, zcu, messages.items[0].reference_trace_root.unwrap().?);
        messages.items[0].notes = messages.items[1..];
        messages.items[0].msg = "found compile log statement";
        for (messages.items[1..]) |*note| {
            try appendCompileLogLines(&log_text, zcu, note.reference_trace_root.unwrap().?);
            note.reference_trace_root = .none; // notes don't have reference traces
            note.msg = "also here";
        }

        // We don't actually include the error here if `!include_compile_log_sources`.
        // The sorting above was still necessary, though, to get `log_text` in the right order.
        if (include_compile_log_sources) {
            try addModuleErrorMsg(zcu, &bundle, messages.items[0], false);
        }

        break :compile_log_text try log_text.toOwnedSlice(gpa);
    };

    // TODO: eventually, this should be behind `std.debug.runtime_safety`. But right now, this is a
    // very common way for incremental compilation bugs to manifest, so let's always check it.
    if (comp.zcu) |zcu| if (comp.incremental and bundle.root_list.items.len == 0) {
        for (zcu.transitive_failed_analysis.keys()) |failed_unit| {
            const refs = try zcu.resolveReferences();
            var ref = refs.get(failed_unit) orelse continue;
            // This AU is referenced and has a transitive compile error, meaning it referenced something with a compile error.
            // However, we haven't reported any such error.
            // This is a compiler bug.
            const stderr = std.fs.File.stderr().deprecatedWriter();
            try stderr.writeAll("referenced transitive analysis errors, but none actually emitted\n");
            try stderr.print("{f} [transitive failure]\n", .{zcu.fmtAnalUnit(failed_unit)});
            while (ref) |r| {
                try stderr.print("referenced by: {f}{s}\n", .{
                    zcu.fmtAnalUnit(r.referencer),
                    if (zcu.transitive_failed_analysis.contains(r.referencer)) " [transitive failure]" else "",
                });
                ref = refs.get(r.referencer).?;
            }

            @panic("referenced transitive analysis errors, but none actually emitted");
        }
    };

    return bundle.toOwnedBundle(compile_log_text);
}

/// Writes all compile log lines belonging to `logging_unit` into `log_text` using `zcu.gpa`.
fn appendCompileLogLines(log_text: *std.ArrayListUnmanaged(u8), zcu: *Zcu, logging_unit: InternPool.AnalUnit) Allocator.Error!void {
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    var opt_line_idx = zcu.compile_logs.get(logging_unit).?.first_line.toOptional();
    while (opt_line_idx.unwrap()) |line_idx| {
        const line = line_idx.get(zcu).*;
        opt_line_idx = line.next;
        const line_slice = line.data.toSlice(ip);
        try log_text.ensureUnusedCapacity(gpa, line_slice.len + 1);
        log_text.appendSliceAssumeCapacity(line_slice);
        log_text.appendAssumeCapacity('\n');
    }
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

const default_reference_trace_len = 2;
pub fn addModuleErrorMsg(
    zcu: *Zcu,
    eb: *ErrorBundle.Wip,
    module_err_msg: Zcu.ErrorMsg,
    /// If `-freference-trace` is not specified, we only want to show the one reference trace.
    /// So, this is whether we have already emitted an error with a reference trace.
    already_added_error: bool,
) !void {
    const gpa = eb.gpa;
    const ip = &zcu.intern_pool;
    const err_src_loc = module_err_msg.src_loc.upgrade(zcu);
    const err_source = err_src_loc.file_scope.getSource(zcu) catch |err| {
        try eb.addRootErrorMessage(.{
            .msg = try eb.printString("unable to load '{f}': {s}", .{
                err_src_loc.file_scope.path.fmt(zcu.comp), @errorName(err),
            }),
        });
        return;
    };
    const err_span = try err_src_loc.span(zcu);
    const err_loc = std.zig.findLineColumn(err_source.bytes, err_span.main);

    var ref_traces: std.ArrayListUnmanaged(ErrorBundle.ReferenceTrace) = .empty;
    defer ref_traces.deinit(gpa);

    rt: {
        const rt_root = module_err_msg.reference_trace_root.unwrap() orelse break :rt;
        const max_references = zcu.comp.reference_trace orelse refs: {
            if (already_added_error) break :rt;
            break :refs default_reference_trace_len;
        };

        const all_references = try zcu.resolveReferences();

        var seen: std.AutoHashMapUnmanaged(InternPool.AnalUnit, void) = .empty;
        defer seen.deinit(gpa);

        var referenced_by = rt_root;
        while (all_references.get(referenced_by)) |maybe_ref| {
            const ref = maybe_ref orelse break;
            const gop = try seen.getOrPut(gpa, ref.referencer);
            if (gop.found_existing) break;
            if (ref_traces.items.len < max_references) {
                var last_call_src = ref.src;
                var opt_inline_frame = ref.inline_frame;
                while (opt_inline_frame.unwrap()) |inline_frame| {
                    const f = inline_frame.ptr(zcu).*;
                    const func_nav = ip.indexToKey(f.callee).func.owner_nav;
                    const func_name = ip.getNav(func_nav).name.toSlice(ip);
                    try addReferenceTraceFrame(zcu, eb, &ref_traces, func_name, last_call_src, true);
                    last_call_src = f.call_src;
                    opt_inline_frame = f.parent;
                }
                const root_name: ?[]const u8 = switch (ref.referencer.unwrap()) {
                    .@"comptime" => "comptime",
                    .nav_val, .nav_ty => |nav| ip.getNav(nav).name.toSlice(ip),
                    .type => |ty| Type.fromInterned(ty).containerTypeName(ip).toSlice(ip),
                    .func => |f| ip.getNav(zcu.funcInfo(f).owner_nav).name.toSlice(ip),
                    .memoized_state => null,
                };
                if (root_name) |n| {
                    try addReferenceTraceFrame(zcu, eb, &ref_traces, n, last_call_src, false);
                }
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
        .src_path = try eb.printString("{f}", .{err_src_loc.file_scope.path.fmt(zcu.comp)}),
        .span_start = err_span.start,
        .span_main = err_span.main,
        .span_end = err_span.end,
        .line = @intCast(err_loc.line),
        .column = @intCast(err_loc.column),
        .source_line = try eb.addString(err_loc.source_line),
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
        const source = try note_src_loc.file_scope.getSource(zcu);
        const span = try note_src_loc.span(zcu);
        const loc = std.zig.findLineColumn(source.bytes, span.main);

        const omit_source_line = loc.eql(err_loc) or (last_note_loc != null and loc.eql(last_note_loc.?));
        last_note_loc = loc;

        const gop = try notes.getOrPutContext(gpa, .{
            .msg = try eb.addString(module_note.msg),
            .src_loc = try eb.addSourceLocation(.{
                .src_path = try eb.printString("{f}", .{note_src_loc.file_scope.path.fmt(zcu.comp)}),
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

fn addReferenceTraceFrame(
    zcu: *Zcu,
    eb: *ErrorBundle.Wip,
    ref_traces: *std.ArrayListUnmanaged(ErrorBundle.ReferenceTrace),
    name: []const u8,
    lazy_src: Zcu.LazySrcLoc,
    inlined: bool,
) !void {
    const gpa = zcu.gpa;
    const src = lazy_src.upgrade(zcu);
    const source = try src.file_scope.getSource(zcu);
    const span = try src.span(zcu);
    const loc = std.zig.findLineColumn(source.bytes, span.main);
    try ref_traces.append(gpa, .{
        .decl_name = try eb.printString("{s}{s}", .{ name, if (inlined) " [inlined]" else "" }),
        .src_loc = try eb.addSourceLocation(.{
            .src_path = try eb.printString("{f}", .{src.file_scope.path.fmt(zcu.comp)}),
            .span_start = span.start,
            .span_main = span.main,
            .span_end = span.end,
            .line = @intCast(loc.line),
            .column = @intCast(loc.column),
            .source_line = 0,
        }),
    });
}

pub fn addWholeFileError(
    zcu: *Zcu,
    eb: *ErrorBundle.Wip,
    file_index: Zcu.File.Index,
    msg: []const u8,
) !void {
    // note: "file imported here" on the import reference token
    const imported_note: ?ErrorBundle.MessageIndex = switch (zcu.alive_files.get(file_index).?) {
        .analysis_root => null,
        .import => |import| try eb.addErrorMessage(.{
            .msg = try eb.addString("file imported here"),
            .src_loc = try zcu.fileByIndex(import.importer).errorBundleTokenSrc(import.tok, zcu, eb),
        }),
    };

    try eb.addRootErrorMessage(.{
        .msg = try eb.addString(msg),
        .src_loc = try zcu.fileByIndex(file_index).errorBundleWholeFileSrc(zcu, eb),
        .notes_len = if (imported_note != null) 1 else 0,
    });
    if (imported_note) |n| {
        const note_idx = try eb.reserveNotes(1);
        eb.extra.items[note_idx] = @intFromEnum(n);
    }
}

fn performAllTheWork(
    comp: *Compilation,
    main_progress_node: std.Progress.Node,
) JobError!void {
    // Regardless of errors, `comp.zcu` needs to update its generation number.
    defer if (comp.zcu) |zcu| {
        zcu.generation += 1;
    };

    // Here we queue up all the AstGen tasks first, followed by C object compilation.
    // We wait until the AstGen tasks are all completed before proceeding to the
    // (at least for now) single-threaded main work queue. However, C object compilation
    // only needs to be finished by the end of this function.

    var work_queue_wait_group: WaitGroup = .{};
    defer work_queue_wait_group.wait();

    comp.link_task_wait_group.reset();
    defer comp.link_task_wait_group.wait();

    comp.link_prog_node.increaseEstimatedTotalItems(
        comp.link_task_queue.queued_prelink.items.len + // already queued prelink tasks
            comp.link_task_queue.pending_prelink_tasks, // prelink tasks which will be queued
    );
    comp.link_task_queue.start(comp);

    if (comp.emit_docs != null) {
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
        comp.link_task_wait_group.spawnManager(buildRt, .{
            comp,
            "compiler_rt.zig",
            "compiler_rt",
            .Lib,
            .static,
            .compiler_rt,
            main_progress_node,
            RtOptions{
                .checks_valgrind = true,
                .allow_lto = false,
            },
            &comp.compiler_rt_lib,
        });
    }

    if (comp.queued_jobs.compiler_rt_obj and comp.compiler_rt_obj == null) {
        comp.link_task_wait_group.spawnManager(buildRt, .{
            comp,
            "compiler_rt.zig",
            "compiler_rt",
            .Obj,
            .static,
            .compiler_rt,
            main_progress_node,
            RtOptions{
                .checks_valgrind = true,
                .allow_lto = false,
            },
            &comp.compiler_rt_obj,
        });
    }

    // hack for stage2_x86_64 + coff
    if (comp.queued_jobs.compiler_rt_dyn_lib and comp.compiler_rt_dyn_lib == null) {
        comp.link_task_wait_group.spawnManager(buildRt, .{
            comp,
            "compiler_rt.zig",
            "compiler_rt",
            .Lib,
            .dynamic,
            .compiler_rt,
            main_progress_node,
            RtOptions{
                .checks_valgrind = true,
                .allow_lto = false,
            },
            &comp.compiler_rt_dyn_lib,
        });
    }

    if (comp.queued_jobs.fuzzer_lib and comp.fuzzer_lib == null) {
        comp.link_task_wait_group.spawnManager(buildRt, .{
            comp,
            "fuzzer.zig",
            "fuzzer",
            .Lib,
            .static,
            .libfuzzer,
            main_progress_node,
            RtOptions{},
            &comp.fuzzer_lib,
        });
    }

    if (comp.queued_jobs.ubsan_rt_lib and comp.ubsan_rt_lib == null) {
        comp.link_task_wait_group.spawnManager(buildRt, .{
            comp,
            "ubsan_rt.zig",
            "ubsan_rt",
            .Lib,
            .static,
            .libubsan,
            main_progress_node,
            RtOptions{
                .allow_lto = false,
            },
            &comp.ubsan_rt_lib,
        });
    }

    if (comp.queued_jobs.ubsan_rt_obj and comp.ubsan_rt_obj == null) {
        comp.link_task_wait_group.spawnManager(buildRt, .{
            comp,
            "ubsan_rt.zig",
            "ubsan_rt",
            .Obj,
            .static,
            .libubsan,
            main_progress_node,
            RtOptions{
                .allow_lto = false,
            },
            &comp.ubsan_rt_obj,
        });
    }

    if (comp.queued_jobs.glibc_shared_objects) {
        comp.link_task_wait_group.spawnManager(buildGlibcSharedObjects, .{ comp, main_progress_node });
    }

    if (comp.queued_jobs.freebsd_shared_objects) {
        comp.link_task_wait_group.spawnManager(buildFreeBSDSharedObjects, .{ comp, main_progress_node });
    }

    if (comp.queued_jobs.netbsd_shared_objects) {
        comp.link_task_wait_group.spawnManager(buildNetBSDSharedObjects, .{ comp, main_progress_node });
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

    if (comp.queued_jobs.zigc_lib and comp.zigc_static_lib == null) {
        comp.link_task_wait_group.spawnManager(buildLibZigC, .{ comp, main_progress_node });
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

    for (0..@typeInfo(freebsd.CrtFile).@"enum".fields.len) |i| {
        if (comp.queued_jobs.freebsd_crt_file[i]) {
            const tag: freebsd.CrtFile = @enumFromInt(i);
            comp.link_task_wait_group.spawnManager(buildFreeBSDCrtFile, .{ comp, tag, main_progress_node });
        }
    }

    for (0..@typeInfo(netbsd.CrtFile).@"enum".fields.len) |i| {
        if (comp.queued_jobs.netbsd_crt_file[i]) {
            const tag: netbsd.CrtFile = @enumFromInt(i);
            comp.link_task_wait_group.spawnManager(buildNetBSDCrtFile, .{ comp, tag, main_progress_node });
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

        if (comp.zcu) |zcu| {
            const gpa = zcu.gpa;

            // We cannot reference `zcu.import_table` after we spawn any `workerUpdateFile` jobs,
            // because on single-threaded targets the worker will be run eagerly, meaning the
            // `import_table` could be mutated, and not even holding `comp.mutex` will save us. So,
            // build up a list of the files to update *before* we spawn any jobs.
            var astgen_work_items: std.MultiArrayList(struct {
                file_index: Zcu.File.Index,
                file: *Zcu.File,
            }) = .empty;
            defer astgen_work_items.deinit(gpa);
            // Not every item in `import_table` will need updating, because some are builtin.zig
            // files. However, most will, so let's just reserve sufficient capacity upfront.
            try astgen_work_items.ensureTotalCapacity(gpa, zcu.import_table.count());
            for (zcu.import_table.keys()) |file_index| {
                const file = zcu.fileByIndex(file_index);
                if (file.is_builtin) {
                    // This is a `builtin.zig`, so updating is redundant. However, we want to make
                    // sure the file contents are still correct on disk, since it can improve the
                    // debugging experience better. That job only needs `file`, so we can kick it
                    // off right now.
                    comp.thread_pool.spawnWg(&astgen_wait_group, workerUpdateBuiltinFile, .{ comp, file });
                    continue;
                }
                astgen_work_items.appendAssumeCapacity(.{
                    .file_index = file_index,
                    .file = file,
                });
            }

            // Now that we're not going to touch `zcu.import_table` again, we can spawn `workerUpdateFile` jobs.
            for (astgen_work_items.items(.file_index), astgen_work_items.items(.file)) |file_index, file| {
                comp.thread_pool.spawnWgId(&astgen_wait_group, workerUpdateFile, .{
                    comp, file, file_index, zir_prog_node, &astgen_wait_group,
                });
            }

            // On the other hand, it's fine to directly iterate `zcu.embed_table.keys()` here
            // because `workerUpdateEmbedFile` can't invalidate it. The different here is that one
            // `@embedFile` can't trigger analysis of a new `@embedFile`!
            for (0.., zcu.embed_table.keys()) |ef_index_usize, ef| {
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

        const gpa = zcu.gpa;

        // On an incremental update, a source file might become "dead", in that all imports of
        // the file were removed. This could even change what module the file belongs to! As such,
        // we do a traversal over the files, to figure out which ones are alive and the modules
        // they belong to.
        const any_fatal_files = try pt.computeAliveFiles();

        // If the cache mode is `whole`, add every alive source file to the manifest.
        switch (comp.cache_use) {
            .whole => |whole| if (whole.cache_manifest) |man| {
                for (zcu.alive_files.keys()) |file_index| {
                    const file = zcu.fileByIndex(file_index);

                    switch (file.status) {
                        .never_loaded => unreachable, // AstGen tried to load it
                        .retryable_failure => continue, // the file cannot be read; this is a guaranteed error
                        .astgen_failure, .success => {}, // the file was read successfully
                    }

                    const path = try file.path.toAbsolute(comp.dirs, gpa);
                    defer gpa.free(path);

                    const result = res: {
                        whole.cache_manifest_mutex.lock();
                        defer whole.cache_manifest_mutex.unlock();
                        if (file.source) |source| {
                            break :res man.addFilePostContents(path, source, file.stat);
                        } else {
                            break :res man.addFilePost(path);
                        }
                    };
                    result catch |err| switch (err) {
                        error.OutOfMemory => |e| return e,
                        else => {
                            try pt.reportRetryableFileError(file_index, "unable to update cache: {s}", .{@errorName(err)});
                            continue;
                        },
                    };
                }
            },
            .none, .incremental => {},
        }

        if (any_fatal_files or
            zcu.multi_module_err != null or
            zcu.failed_imports.items.len > 0 or
            comp.alloc_failure_occurred)
        {
            // We give up right now! No updating of ZIR refs, no nothing. The idea is that this prevents
            // us from invalidating lots of incremental dependencies due to files with e.g. parse errors.
            // However, this means our analysis data is invalid, so we want to omit all analysis errors.
            zcu.skip_analysis_this_update = true;
            return;
        }

        if (comp.incremental) {
            const update_zir_refs_node = main_progress_node.start("Update ZIR References", 0);
            defer update_zir_refs_node.end();
            try pt.updateZirRefs();
        }
        try zcu.flushRetryableFailures();

        // It's analysis time! Queue up our initial analysis.
        for (zcu.analysis_roots.slice()) |mod| {
            try comp.queueJob(.{ .analyze_mod = mod });
        }

        zcu.sema_prog_node = main_progress_node.start("Semantic Analysis", 0);
        if (comp.bin_file != null) {
            zcu.codegen_prog_node = main_progress_node.start("Code Generation", 0);
        }
        // We increment `pending_codegen_jobs` so that it doesn't reach 0 until after analysis finishes.
        // That prevents the "Code Generation" node from constantly disappearing and reappearing when
        // we're probably going to analyze more functions at some point.
        assert(zcu.pending_codegen_jobs.swap(1, .monotonic) == 0); // don't let this become 0 until analysis finishes
    }
    // When analysis ends, delete the progress nodes for "Semantic Analysis" and possibly "Code Generation".
    defer if (comp.zcu) |zcu| {
        zcu.sema_prog_node.end();
        zcu.sema_prog_node = .none;
        if (zcu.pending_codegen_jobs.rmw(.Sub, 1, .monotonic) == 1) {
            // Decremented to 0, so all done.
            zcu.codegen_prog_node.end();
            zcu.codegen_prog_node = .none;
        }
    };

    if (!comp.separateCodegenThreadOk()) {
        // Waits until all input files have been parsed.
        comp.link_task_wait_group.wait();
        comp.link_task_wait_group.reset();
        std.log.scoped(.link).debug("finished waiting for link_task_wait_group", .{});
        if (comp.link_task_queue.pending_prelink_tasks > 0) {
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
        .codegen_func => |func| {
            const zcu = comp.zcu.?;
            const gpa = zcu.gpa;
            var air = func.air;
            errdefer {
                zcu.codegen_prog_node.completeOne();
                comp.link_prog_node.completeOne();
                air.deinit(gpa);
            }
            if (!air.typesFullyResolved(zcu)) {
                // Type resolution failed in a way which affects this function. This is a transitive
                // failure, but it doesn't need recording, because this function semantically depends
                // on the failed type, so when it is changed the function is updated.
                zcu.codegen_prog_node.completeOne();
                comp.link_prog_node.completeOne();
                air.deinit(gpa);
                return;
            }
            const shared_mir = try gpa.create(link.ZcuTask.LinkFunc.SharedMir);
            shared_mir.* = .{
                .status = .init(.pending),
                .value = undefined,
            };
            assert(zcu.pending_codegen_jobs.rmw(.Add, 1, .monotonic) > 0); // the "Code Generation" node hasn't been ended
            // This value is used as a heuristic to avoid queueing too much AIR/MIR at once (hence
            // using a lot of memory). If this would cause too many AIR bytes to be in-flight, we
            // will block on the `dispatchZcuLinkTask` call below.
            const air_bytes: u32 = @intCast(air.instructions.len * 5 + air.extra.items.len * 4);
            if (comp.separateCodegenThreadOk()) {
                // `workerZcuCodegen` takes ownership of `air`.
                comp.thread_pool.spawnWgId(&comp.link_task_wait_group, workerZcuCodegen, .{ comp, func.func, air, shared_mir });
                comp.dispatchZcuLinkTask(tid, .{ .link_func = .{
                    .func = func.func,
                    .mir = shared_mir,
                    .air_bytes = air_bytes,
                } });
            } else {
                {
                    const pt: Zcu.PerThread = .activate(comp.zcu.?, @enumFromInt(tid));
                    defer pt.deactivate();
                    pt.runCodegen(func.func, &air, shared_mir);
                }
                assert(shared_mir.status.load(.monotonic) != .pending);
                comp.dispatchZcuLinkTask(tid, .{ .link_func = .{
                    .func = func.func,
                    .mir = shared_mir,
                    .air_bytes = air_bytes,
                } });
                air.deinit(gpa);
            }
        },
        .link_nav => |nav_index| {
            const zcu = comp.zcu.?;
            const nav = zcu.intern_pool.getNav(nav_index);
            if (nav.analysis != null) {
                const unit: InternPool.AnalUnit = .wrap(.{ .nav_val = nav_index });
                if (zcu.failed_analysis.contains(unit) or zcu.transitive_failed_analysis.contains(unit)) {
                    comp.link_prog_node.completeOne();
                    return;
                }
            }
            assert(nav.status == .fully_resolved);
            if (!Air.valFullyResolved(zcu.navValue(nav_index), zcu)) {
                // Type resolution failed in a way which affects this `Nav`. This is a transitive
                // failure, but it doesn't need recording, because this `Nav` semantically depends
                // on the failed type, so when it is changed the `Nav` will be updated.
                comp.link_prog_node.completeOne();
                return;
            }
            comp.dispatchZcuLinkTask(tid, .{ .link_nav = nav_index });
        },
        .link_type => |ty| {
            const zcu = comp.zcu.?;
            if (zcu.failed_types.fetchSwapRemove(ty)) |*entry| entry.value.deinit(zcu.gpa);
            if (!Air.typeFullyResolved(.fromInterned(ty), zcu)) {
                // Type resolution failed in a way which affects this type. This is a transitive
                // failure, but it doesn't need recording, because this type semantically depends
                // on the failed type, so when that is changed, this type will be updated.
                comp.link_prog_node.completeOne();
                return;
            }
            comp.dispatchZcuLinkTask(tid, .{ .link_type = ty });
        },
        .update_line_number => |ti| {
            comp.dispatchZcuLinkTask(tid, .{ .update_line_number = ti });
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
            pt.semaMod(mod) catch |err| switch (err) {
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

pub fn separateCodegenThreadOk(comp: *const Compilation) bool {
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

    const docs_path = comp.resolveEmitPath(comp.emit_docs.?);
    var out_dir = docs_path.root_dir.handle.makeOpenPath(docs_path.sub_path, .{}) catch |err| {
        return comp.lockAndSetMiscFailure(
            .docs_copy,
            "unable to create output directory '{f}': {s}",
            .{ docs_path, @errorName(err) },
        );
    };
    defer out_dir.close();

    for (&[_][]const u8{ "docs/main.js", "docs/index.html" }) |sub_path| {
        const basename = std.fs.path.basename(sub_path);
        comp.dirs.zig_lib.handle.copyFile(sub_path, out_dir, basename, .{}) catch |err| {
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
            "unable to create '{f}/sources.tar': {s}",
            .{ docs_path, @errorName(err) },
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
    var mod_dir = d: {
        const root_dir, const sub_path = root.openInfo(comp.dirs);
        break :d root_dir.openDir(sub_path, .{ .iterate = true });
    } catch |err| {
        return comp.lockAndSetMiscFailure(.docs_copy, "unable to open directory '{f}': {s}", .{
            root.fmt(comp), @errorName(err),
        });
    };
    defer mod_dir.close();

    var walker = try mod_dir.walk(comp.gpa);
    defer walker.deinit();

    var archiver = std.tar.writer(tar_file.deprecatedWriter().any());
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
            return comp.lockAndSetMiscFailure(.docs_copy, "unable to open '{f}{s}': {s}", .{
                root.fmt(comp), entry.path, @errorName(err),
            });
        };
        defer file.close();
        archiver.writeFile(entry.path, file) catch |err| {
            return comp.lockAndSetMiscFailure(.docs_copy, "unable to archive '{f}{s}': {s}", .{
                root.fmt(comp), entry.path, @errorName(err),
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
        .is_explicit_dynamic_linker = false,
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

    const dirs = comp.dirs.withoutLocalCache();

    const root_mod = try Package.Module.create(arena, .{
        .paths = .{
            .root = try .fromRoot(arena, dirs, .zig_lib, "docs/wasm"),
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
    });
    const walk_mod = try Package.Module.create(arena, .{
        .paths = .{
            .root = try .fromRoot(arena, dirs, .zig_lib, "docs/wasm"),
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
    });
    try root_mod.deps.put(arena, "Walk", walk_mod);

    const sub_compilation = try Compilation.create(gpa, arena, .{
        .dirs = dirs,
        .self_exe_path = comp.self_exe_path,
        .config = config,
        .root_mod = root_mod,
        .entry = .disabled,
        .cache_mode = .whole,
        .root_name = root_name,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.libc_installation,
        .emit_bin = .yes_cache,
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

    var crt_file = try sub_compilation.toCrtFile();
    defer crt_file.deinit(gpa);

    const docs_bin_file = crt_file.full_object_path;
    assert(docs_bin_file.sub_path.len > 0); // emitted binary is not a directory

    const docs_path = comp.resolveEmitPath(comp.emit_docs.?);
    var out_dir = docs_path.root_dir.handle.makeOpenPath(docs_path.sub_path, .{}) catch |err| {
        return comp.lockAndSetMiscFailure(
            .docs_copy,
            "unable to create output directory '{f}': {s}",
            .{ docs_path, @errorName(err) },
        );
    };
    defer out_dir.close();

    crt_file.full_object_path.root_dir.handle.copyFile(
        crt_file.full_object_path.sub_path,
        out_dir,
        "main.wasm",
        .{},
    ) catch |err| {
        return comp.lockAndSetMiscFailure(.docs_copy, "unable to copy '{f}' to '{f}': {s}", .{
            crt_file.full_object_path, docs_path, @errorName(err),
        });
    };
}

fn workerUpdateFile(
    tid: usize,
    comp: *Compilation,
    file: *Zcu.File,
    file_index: Zcu.File.Index,
    prog_node: std.Progress.Node,
    wg: *WaitGroup,
) void {
    const child_prog_node = prog_node.start(std.fs.path.basename(file.path.sub_path), 0);
    defer child_prog_node.end();

    const pt: Zcu.PerThread = .activate(comp.zcu.?, @enumFromInt(tid));
    defer pt.deactivate();
    pt.updateFile(file_index, file) catch |err| {
        pt.reportRetryableFileError(file_index, "unable to load '{s}': {s}", .{ std.fs.path.basename(file.path.sub_path), @errorName(err) }) catch |oom| switch (oom) {
            error.OutOfMemory => {
                comp.mutex.lock();
                defer comp.mutex.unlock();
                comp.setAllocFailure();
            },
        };
        return;
    };

    switch (file.getMode()) {
        .zig => {}, // continue to logic below
        .zon => return, // ZON can't import anything so we're done
    }

    // Discover all imports in the file. Imports of modules we ignore for now since we don't
    // know which module we're in, but imports of file paths might need us to queue up other
    // AstGen jobs.
    const imports_index = file.zir.?.extra[@intFromEnum(Zir.ExtraIndex.imports)];
    if (imports_index != 0) {
        const extra = file.zir.?.extraData(Zir.Inst.Imports, imports_index);
        var import_i: u32 = 0;
        var extra_index = extra.end;

        while (import_i < extra.data.imports_len) : (import_i += 1) {
            const item = file.zir.?.extraData(Zir.Inst.Imports.Item, extra_index);
            extra_index = item.end;

            const import_path = file.zir.?.nullTerminatedString(item.data.name);

            if (pt.discoverImport(file.path, import_path)) |res| switch (res) {
                .module, .existing_file => {},
                .new_file => |new| {
                    comp.thread_pool.spawnWgId(wg, workerUpdateFile, .{
                        comp, new.file, new.index, prog_node, wg,
                    });
                },
            } else |err| switch (err) {
                error.OutOfMemory => {
                    comp.mutex.lock();
                    defer comp.mutex.unlock();
                    comp.setAllocFailure();
                },
            }
        }
    }
}

fn workerUpdateBuiltinFile(comp: *Compilation, file: *Zcu.File) void {
    Builtin.updateFileOnDisk(file, comp) catch |err| {
        comp.mutex.lock();
        defer comp.mutex.unlock();
        comp.setMiscFailure(
            .write_builtin_zig,
            "unable to write '{f}': {s}",
            .{ file.path.fmt(comp), @errorName(err) },
        );
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
        var zig_cache_tmp_dir = try comp.dirs.local_cache.handle.makeOpenPath(tmp_dir_sub_path, .{});
        defer zig_cache_tmp_dir.close();
        const cimport_basename = "cimport.h";
        const out_h_path = try comp.dirs.local_cache.join(arena, &[_][]const u8{
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

                const c_headers_dir_path_z = try comp.dirs.zig_lib.joinZ(arena, &.{"include"});
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
            .incremental, .none => {},
        }

        const bin_digest = man.finalBin();
        const hex_digest = Cache.binToHex(bin_digest);
        const o_sub_path = "o" ++ std.fs.path.sep_str ++ hex_digest;
        var o_dir = try comp.dirs.local_cache.handle.makeOpenPath(o_sub_path, .{});
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

pub const RtOptions = struct {
    checks_valgrind: bool = false,
    allow_lto: bool = true,
};

fn workerZcuCodegen(
    tid: usize,
    comp: *Compilation,
    func_index: InternPool.Index,
    orig_air: Air,
    out: *link.ZcuTask.LinkFunc.SharedMir,
) void {
    var air = orig_air;
    // We own `air` now, so we are responsbile for freeing it.
    defer air.deinit(comp.gpa);
    const pt: Zcu.PerThread = .activate(comp.zcu.?, @enumFromInt(tid));
    defer pt.deactivate();
    pt.runCodegen(func_index, &air, out);
}

fn buildRt(
    comp: *Compilation,
    root_source_name: []const u8,
    root_name: []const u8,
    output_mode: std.builtin.OutputMode,
    link_mode: std.builtin.LinkMode,
    misc_task: MiscTask,
    prog_node: std.Progress.Node,
    options: RtOptions,
    out: *?CrtFile,
) void {
    comp.buildOutputFromZig(
        root_source_name,
        root_name,
        output_mode,
        link_mode,
        misc_task,
        prog_node,
        options,
        out,
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

fn buildFreeBSDCrtFile(comp: *Compilation, crt_file: freebsd.CrtFile, prog_node: std.Progress.Node) void {
    if (freebsd.buildCrtFile(comp, crt_file, prog_node)) |_| {
        comp.queued_jobs.freebsd_crt_file[@intFromEnum(crt_file)] = false;
    } else |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.freebsd_crt_file, "unable to build FreeBSD {s}: {s}", .{
            @tagName(crt_file), @errorName(err),
        }),
    }
}

fn buildFreeBSDSharedObjects(comp: *Compilation, prog_node: std.Progress.Node) void {
    if (freebsd.buildSharedObjects(comp, prog_node)) |_| {
        // The job should no longer be queued up since it succeeded.
        comp.queued_jobs.freebsd_shared_objects = false;
    } else |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.freebsd_shared_objects, "unable to build FreeBSD libc shared objects: {s}", .{
            @errorName(err),
        }),
    }
}

fn buildNetBSDCrtFile(comp: *Compilation, crt_file: netbsd.CrtFile, prog_node: std.Progress.Node) void {
    if (netbsd.buildCrtFile(comp, crt_file, prog_node)) |_| {
        comp.queued_jobs.netbsd_crt_file[@intFromEnum(crt_file)] = false;
    } else |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.netbsd_crt_file, "unable to build NetBSD {s}: {s}", .{
            @tagName(crt_file), @errorName(err),
        }),
    }
}

fn buildNetBSDSharedObjects(comp: *Compilation, prog_node: std.Progress.Node) void {
    if (netbsd.buildSharedObjects(comp, prog_node)) |_| {
        // The job should no longer be queued up since it succeeded.
        comp.queued_jobs.netbsd_shared_objects = false;
    } else |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.netbsd_shared_objects, "unable to build NetBSD libc shared objects: {s}", .{
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

fn buildLibZigC(comp: *Compilation, prog_node: std.Progress.Node) void {
    comp.buildOutputFromZig(
        "c.zig",
        "zigc",
        .Lib,
        .static,
        .libzigc,
        prog_node,
        .{},
        &comp.zigc_static_lib,
    ) catch |err| switch (err) {
        error.SubCompilationFailed => return, // error reported already
        else => comp.lockAndSetMiscFailure(.libzigc, "unable to build libzigc: {s}", .{@errorName(err)}),
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
    man.hash.addOptionalBytes(comp.emit_asm);
    man.hash.addOptionalBytes(comp.emit_llvm_ir);
    man.hash.addOptionalBytes(comp.emit_llvm_bc);

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
        var zig_cache_tmp_dir = try comp.dirs.local_cache.handle.makeOpenPath("tmp", .{});
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
        defer if (out_diag_path) |diag_file_path| zig_cache_tmp_dir.deleteFile(std.fs.path.basename(diag_file_path)) catch |err| switch (err) {
            error.FileNotFound => {}, // the file wasn't created due to an error we reported
            else => log.warn("failed to delete '{s}': {s}", .{ diag_file_path, @errorName(err) }),
        };
        defer if (out_dep_path) |dep_file_path| zig_cache_tmp_dir.deleteFile(std.fs.path.basename(dep_file_path)) catch |err| switch (err) {
            error.FileNotFound => {}, // the file wasn't created due to an error we reported
            else => log.warn("failed to delete '{s}': {s}", .{ dep_file_path, @errorName(err) }),
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

                const stderr = try child.stderr.?.deprecatedReader().readAllAlloc(arena, std.math.maxInt(usize));

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
                .incremental, .none => {},
            }
        }

        // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
        if (comp.disable_c_depfile) _ = try man.hit();

        // Rename into place.
        const digest = man.final();
        const o_sub_path = try std.fs.path.join(arena, &[_][]const u8{ "o", &digest });
        var o_dir = try comp.dirs.local_cache.handle.makeOpenPath(o_sub_path, .{});
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
                .root_dir = comp.dirs.local_cache,
                .sub_path = try std.fs.path.join(gpa, &.{ "o", &digest, o_basename }),
            },
            .lock = man.toOwnedLock(),
        },
    };

    comp.queuePrelinkTasks(&.{.{ .load_object = c_object.status.success.object_path }});
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
            var o_dir = try comp.dirs.local_cache.handle.makeOpenPath(o_sub_path, .{});
            defer o_dir.close();

            const in_rc_path = try comp.dirs.local_cache.join(comp.gpa, &.{
                o_sub_path, rc_basename,
            });
            const out_res_path = try comp.dirs.local_cache.join(comp.gpa, &.{
                o_sub_path, res_basename,
            });

            // In .rc files, a " within a quoted string is escaped as ""
            const fmtRcEscape = struct {
                fn formatRcEscape(bytes: []const u8, writer: *std.io.Writer) std.io.Writer.Error!void {
                    for (bytes) |byte| switch (byte) {
                        '"' => try writer.writeAll("\"\""),
                        '\\' => try writer.writeAll("\\\\"),
                        else => try writer.writeByte(byte),
                    };
                }

                pub fn fmtRcEscape(bytes: []const u8) std.fmt.Formatter([]const u8, formatRcEscape) {
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

            const input = try std.fmt.allocPrint(arena, "{d} {d} \"{f}\"", .{
                resource_id, resource_type, fmtRcEscape(src_path),
            });

            try o_dir.writeFile(.{ .sub_path = rc_basename, .data = input });

            var argv = std.ArrayList([]const u8).init(comp.gpa);
            defer argv.deinit();

            try argv.appendSlice(&.{
                self_exe_path,
                "rc",
                "--zig-integration",
                "/:target",
                @tagName(comp.getTarget().cpu.arch),
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
                .res_path = try comp.dirs.local_cache.join(comp.gpa, &[_][]const u8{
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
        var zig_cache_tmp_dir = try comp.dirs.local_cache.handle.makeOpenPath("tmp", .{});
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
            "/:target",
            @tagName(comp.getTarget().cpu.arch),
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
            .Debug, .ReleaseSafe => {},
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
                    .incremental, .none => {},
                }
            }
        }

        // Rename into place.
        const digest = man.final();
        const o_sub_path = try std.fs.path.join(arena, &[_][]const u8{ "o", &digest });
        var o_dir = try comp.dirs.local_cache.handle.makeOpenPath(o_sub_path, .{});
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
            .res_path = try comp.dirs.local_cache.join(comp.gpa, &[_][]const u8{
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
    const stderr_reader = child.stderr.?.deprecatedReader();
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
    if (comp.dirs.local_cache.path) |p| {
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
    const target = &mod.resolved_target.result;

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

    switch (target.os.tag) {
        .ios, .macos, .tvos, .watchos => |os| {
            try argv.ensureUnusedCapacity(2);
            // Pass the proper -m<os>-version-min argument for darwin.
            const ver = target.os.version_range.semver.min;
            argv.appendAssumeCapacity(try std.fmt.allocPrint(arena, "-m{s}{s}-version-min={d}.{d}.{d}", .{
                @tagName(os),
                switch (target.abi) {
                    .simulator => "-simulator",
                    else => "",
                },
                ver.major,
                ver.minor,
                ver.patch,
            }));
            // This avoids a warning that sometimes occurs when
            // providing both a -target argument that contains a
            // version as well as the -mmacosx-version-min argument.
            // Zig provides the correct value in both places, so it
            // doesn't matter which one gets overridden.
            argv.appendAssumeCapacity("-Wno-overriding-option");
        },
        else => {},
    }

    if (target.cpu.arch.isArm()) {
        try argv.append(if (target.cpu.arch.isThumb()) "-mthumb" else "-mno-thumb");
    }

    if (target_util.llvmMachineAbi(target)) |mabi| {
        // Clang's integrated Arm assembler doesn't support `-mabi` yet...
        // Clang's FreeBSD driver doesn't support `-mabi` on PPC64 (ELFv2 is used anyway).
        if (!(target.cpu.arch.isArm() and (ext == .assembly or ext == .assembly_with_cpp)) and
            !(target.cpu.arch.isPowerPC64() and target.os.tag == .freebsd))
        {
            try argv.append(try std.fmt.allocPrint(arena, "-mabi={s}", .{mabi}));
        }
    }

    // We might want to support -mfloat-abi=softfp for Arm and CSKY here in the future.
    if (target_util.clangSupportsFloatAbiArg(target)) {
        const fabi = @tagName(target.abi.float());

        try argv.append(switch (target.cpu.arch) {
            // For whatever reason, Clang doesn't support `-mfloat-abi` for s390x.
            .s390x => try std.fmt.allocPrint(arena, "-m{s}-float", .{fabi}),
            else => try std.fmt.allocPrint(arena, "-mfloat-abi={s}", .{fabi}),
        });
    }

    if (target_util.supports_fpic(target)) {
        // PIE needs to go before PIC because Clang interprets `-fno-PIE` to imply `-fno-PIC`, which
        // we don't necessarily want.
        try argv.append(if (comp.config.pie) "-fPIE" else "-fno-PIE");
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

        if (target_util.clangSupportsNoImplicitFloatArg(target) and target.abi.float() == .soft) {
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
            .async => try argv.append("-fasynchronous-unwind-tables"),
        }

        try argv.append("-nostdinc");

        if (ext == .cpp or ext == .hpp) {
            try argv.append("-nostdinc++");
        }

        // LLVM IR files don't support these flags.
        if (ext != .ll and ext != .bc) {
            switch (mod.optimize_mode) {
                .Debug => {},
                .ReleaseSafe => {
                    try argv.append("-D_FORTIFY_SOURCE=2");
                },
                .ReleaseFast, .ReleaseSmall => {
                    try argv.append("-DNDEBUG");
                },
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
                } else if (target.isFreeBSDLibC()) {
                    // https://docs.freebsd.org/en/books/porters-handbook/versions
                    const min_ver = target.os.version_range.semver.min;
                    try argv.append(try std.fmt.allocPrint(arena, "-D__FreeBSD_version={d}", .{
                        // We don't currently respect the minor and patch components. This wouldn't be particularly
                        // helpful because our abilists file only tracks major FreeBSD releases, so the link-time stub
                        // symbols would be inconsistent with header declarations.
                        min_ver.major * 100_000,
                    }));
                } else if (target.isNetBSDLibC()) {
                    const min_ver = target.os.version_range.semver.min;
                    try argv.append(try std.fmt.allocPrint(arena, "-D__NetBSD_Version__={d}", .{
                        // We don't currently respect the patch component. This wouldn't be particularly helpful because
                        // our abilists file only tracks major and minor NetBSD releases, so the link-time stub symbols
                        // would be inconsistent with header declarations.
                        (min_ver.major * 100_000_000) + (min_ver.minor * 1_000_000),
                    }));
                }
            }

            if (comp.config.link_libcpp) {
                try argv.append("-isystem");
                try argv.append(try std.fs.path.join(arena, &[_][]const u8{
                    comp.dirs.zig_lib.path.?, "libcxx", "include",
                }));

                try argv.append("-isystem");
                try argv.append(try std.fs.path.join(arena, &[_][]const u8{
                    comp.dirs.zig_lib.path.?, "libcxxabi", "include",
                }));

                try libcxx.addCxxArgs(comp, arena, argv);
            }

            // According to Rich Felker libc headers are supposed to go before C language headers.
            // However as noted by @dimenus, appending libc headers before compiler headers breaks
            // intrinsics and other compiler specific items.
            try argv.append("-isystem");
            try argv.append(try std.fs.path.join(arena, &.{ comp.dirs.zig_lib.path.?, "include" }));

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
                    comp.dirs.zig_lib.path.?, "libunwind", "include",
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

            if (target.os.tag == .windows and target.abi.isGnu()) {
                // windows.h has files such as pshpack1.h which do #pragma packing,
                // triggering a clang warning. So for this target, we disable this warning.
                try argv.append("-Wno-pragma-pack");
            }

            if (mod.optimize_mode != .Debug) {
                try argv.append("-Werror=date-time");
            }
        },
        else => {},
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

                    if (target.cpu.has(.riscv, .e)) {
                        march_buf[march_index] = 'e';
                    } else {
                        march_buf[march_index] = 'i';
                    }
                    march_index += 1;

                    for (letters) |letter| {
                        if (target.cpu.has(.riscv, letter.feat)) {
                            march_buf[march_index] = letter.char;
                            march_index += 1;
                        }
                    }

                    const march_arg = try std.fmt.allocPrint(arena, "-march={s}", .{
                        march_buf[0..march_index],
                    });
                    try argv.append(march_arg);

                    if (target.cpu.has(.riscv, .relax)) {
                        try argv.append("-mrelax");
                    } else {
                        try argv.append("-mno-relax");
                    }
                    if (target.cpu.has(.riscv, .save_restore)) {
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

    // Only compiled files support these flags.
    switch (ext) {
        .c,
        .h,
        .cpp,
        .hpp,
        .m,
        .hm,
        .mm,
        .hmm,
        .ll,
        .bc,
        => {
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
                    // We communicate float ABI to Clang through the dedicated options.
                    if (std.mem.startsWith(u8, llvm_name, "soft-float") or
                        std.mem.startsWith(u8, llvm_name, "hard-float"))
                        continue;

                    // Ignore these until we figure out how to handle the concept of omitting features.
                    // See https://github.com/ziglang/zig/issues/23539
                    if (target_util.isDynamicAMDGCNFeature(target, feature)) continue;

                    argv.appendSliceAssumeCapacity(&[_][]const u8{ "-Xclang", "-target-feature", "-Xclang" });
                    const plus_or_minus = "-+"[@intFromBool(is_enabled)];
                    const arg = try std.fmt.allocPrint(arena, "{c}{s}", .{ plus_or_minus, llvm_name });
                    argv.appendAssumeCapacity(arg);
                }
            }

            {
                var san_arg: std.ArrayListUnmanaged(u8) = .empty;
                const prefix = "-fsanitize=";
                if (mod.sanitize_c != .off) {
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

                    switch (mod.sanitize_c) {
                        .off => {},
                        .trap => {
                            try argv.append("-fsanitize-trap=undefined");
                        },
                        .full => {
                            // This check requires implementing the Itanium C++ ABI.
                            // We would make it `-fsanitize-trap=vptr`, however this check requires
                            // a full runtime due to the type hashing involved.
                            try argv.append("-fno-sanitize=vptr");

                            // It is very common, and well-defined, for a pointer on one side of a C ABI
                            // to have a different but compatible element type. Examples include:
                            // `char*` vs `uint8_t*` on a system with 8-bit bytes
                            // `const char*` vs `char*`
                            // `char*` vs `unsigned char*`
                            // Without this flag, Clang would invoke UBSAN when such an extern
                            // function was called.
                            try argv.append("-fno-sanitize=function");

                            // This is necessary because, by default, Clang instructs LLVM to embed
                            // a COFF link dependency on `libclang_rt.ubsan_standalone.a` when the
                            // UBSan runtime is used.
                            if (target.os.tag == .windows) {
                                try argv.append("-fno-rtlib-defaultlib");
                            }
                        },
                    }
                }

                if (comp.config.san_cov_trace_pc_guard) {
                    try argv.append("-fsanitize-coverage=trace-pc-guard");
                }
            }

            switch (mod.optimize_mode) {
                .Debug => {
                    // Clang has -Og for compatibility with GCC, but currently it is just equivalent
                    // to -O1. Besides potentially impairing debugging, -O1/-Og significantly
                    // increases compile times.
                    try argv.append("-O0");
                },
                .ReleaseSafe => {
                    // See the comment in the BuildModeFastRelease case for why we pass -O2 rather
                    // than -O3 here.
                    try argv.append("-O2");
                },
                .ReleaseFast => {
                    // Here we pass -O2 rather than -O3 because, although we do the equivalent of
                    // -O3 in Zig code, the justification for the difference here is that Zig
                    // has better detection and prevention of undefined behavior, so -O3 is safer for
                    // Zig code than it is for C code. Also, C programmers are used to their code
                    // running in -O2 and thus the -O3 path has been tested less.
                    try argv.append("-O2");
                },
                .ReleaseSmall => {
                    try argv.append("-Os");
                },
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

    pub fn canonicalName(ext: FileExt, target: *const Target) [:0]const u8 {
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

fn get_libc_crt_file(comp: *Compilation, arena: Allocator, basename: []const u8) !Cache.Path {
    return (try crtFilePath(&comp.crt_files, basename)) orelse {
        const lci = comp.libc_installation orelse return error.LibCInstallationNotAvailable;
        const crt_dir_path = lci.crt_dir orelse return error.LibCInstallationMissingCrtDir;
        const full_path = try std.fs.path.join(arena, &[_][]const u8{ crt_dir_path, basename });
        return Cache.Path.initCwd(full_path);
    };
}

pub fn crtFileAsString(comp: *Compilation, arena: Allocator, basename: []const u8) ![]const u8 {
    const path = try get_libc_crt_file(comp, arena, basename);
    return path.toString(arena);
}

fn crtFilePath(crt_files: *std.StringHashMapUnmanaged(CrtFile), basename: []const u8) Allocator.Error!?Cache.Path {
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
    const stderr = std.fs.File.stderr().deprecatedWriter();
    for (argv[0 .. argv.len - 1]) |arg| {
        nosuspend stderr.print("{s} ", .{arg}) catch return;
    }
    nosuspend stderr.print("{s}\n", .{argv[argv.len - 1]}) catch {};
}

pub fn getZigBackend(comp: Compilation) std.builtin.CompilerBackend {
    const target = &comp.root_mod.resolved_target.result;
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
    root_name: []const u8,
    output_mode: std.builtin.OutputMode,
    link_mode: std.builtin.LinkMode,
    misc_task_tag: MiscTask,
    prog_node: std.Progress.Node,
    options: RtOptions,
    out: *?CrtFile,
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
        .link_mode = link_mode,
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
        .lto = if (options.allow_lto) comp.config.lto else .none,
    });

    const root_mod = try Package.Module.create(arena, .{
        .paths = .{
            .root = .zig_lib_root,
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
            .valgrind = if (options.checks_valgrind) comp.root_mod.valgrind else null,
        },
        .global = config,
        .cc_argv = &.{},
        .parent = null,
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
        .incremental, .none => null,
    };

    const sub_compilation = try Compilation.create(gpa, arena, .{
        .dirs = comp.dirs.withoutLocalCache(),
        .cache_mode = .whole,
        .parent_whole_cache = parent_whole_cache,
        .self_exe_path = comp.self_exe_path,
        .config = config,
        .root_mod = root_mod,
        .root_name = root_name,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.libc_installation,
        .emit_bin = .yes_cache,
        .function_sections = true,
        .data_sections = true,
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

    comp.queuePrelinkTaskMode(crt_file.full_object_path, &config);
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
        .target = &comp.root_mod.resolved_target.result,
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
        .paths = .{
            .root = .zig_lib_root,
            .root_src_path = "",
        },
        .fully_qualified_name = "root",
        .inherited = .{
            .resolved_target = comp.root_mod.resolved_target,
            .strip = comp.compilerRtStrip(),
            .stack_check = false,
            .stack_protector = 0,
            .sanitize_c = .off,
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
    });

    for (c_source_files) |*item| {
        item.owner = root_mod;
    }

    const sub_compilation = try Compilation.create(gpa, arena, .{
        .dirs = comp.dirs.withoutLocalCache(),
        .self_exe_path = comp.self_exe_path,
        .cache_mode = .whole,
        .config = config,
        .root_mod = root_mod,
        .root_name = root_name,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.libc_installation,
        .emit_bin = .yes_cache,
        .function_sections = options.function_sections orelse false,
        .data_sections = options.data_sections orelse false,
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
    comp.queuePrelinkTaskMode(crt_file.full_object_path, &config);

    {
        comp.mutex.lock();
        defer comp.mutex.unlock();
        try comp.crt_files.ensureUnusedCapacity(gpa, 1);
        comp.crt_files.putAssumeCapacityNoClobber(basename, crt_file);
    }
}

pub fn queuePrelinkTaskMode(comp: *Compilation, path: Cache.Path, config: *const Compilation.Config) void {
    comp.queuePrelinkTasks(switch (config.output_mode) {
        .Exe => unreachable,
        .Obj => &.{.{ .load_object = path }},
        .Lib => &.{switch (config.link_mode) {
            .static => .{ .load_archive = path },
            .dynamic => .{ .load_dso = path },
        }},
    });
}

/// Only valid to call during `update`. Automatically handles queuing up a
/// linker worker task if there is not already one.
pub fn queuePrelinkTasks(comp: *Compilation, tasks: []const link.PrelinkTask) void {
    comp.link_task_queue.enqueuePrelink(comp, tasks) catch |err| switch (err) {
        error.OutOfMemory => return comp.setAllocFailure(),
    };
}

/// The reason for the double-queue here is that the first queue ensures any
/// resolve_type_fully tasks are complete before this dispatch function is called.
fn dispatchZcuLinkTask(comp: *Compilation, tid: usize, task: link.ZcuTask) void {
    if (!comp.separateCodegenThreadOk()) {
        assert(tid == 0);
        if (task == .link_func) {
            assert(task.link_func.mir.status.load(.monotonic) != .pending);
        }
        link.doZcuTask(comp, tid, task);
        task.deinit(comp.zcu.?);
        return;
    }
    comp.link_task_queue.enqueueZcu(comp, task) catch |err| switch (err) {
        error.OutOfMemory => {
            task.deinit(comp.zcu.?);
            comp.setAllocFailure();
        },
    };
}

pub fn toCrtFile(comp: *Compilation) Allocator.Error!CrtFile {
    return .{
        .full_object_path = .{
            .root_dir = comp.dirs.local_cache,
            .sub_path = try std.fs.path.join(comp.gpa, &.{
                "o",
                &Cache.binToHex(comp.digest.?),
                comp.emit_bin.?,
            }),
        },
        .lock = comp.cache_use.whole.moveLock(),
    };
}

pub fn getCrtPaths(
    comp: *Compilation,
    arena: Allocator,
) error{ OutOfMemory, LibCInstallationMissingCrtDir }!LibCInstallation.CrtPaths {
    const target = &comp.root_mod.resolved_target.result;
    return getCrtPathsInner(arena, target, comp.config, comp.libc_installation, &comp.crt_files);
}

fn getCrtPathsInner(
    arena: Allocator,
    target: *const std.Target,
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

/// This decides the optimization mode for all zig-provided libraries, including
/// compiler-rt, libcxx, libc, libunwind, etc.
pub fn compilerRtOptMode(comp: Compilation) std.builtin.OptimizeMode {
    if (comp.debug_compiler_runtime_libs) {
        return comp.root_mod.optimize_mode;
    }
    const target = &comp.root_mod.resolved_target.result;
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
