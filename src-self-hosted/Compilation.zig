const Compilation = @This();

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;
const assert = std.debug.assert;
const log = std.log.scoped(.compilation);
const Target = std.Target;
const target_util = @import("target.zig");
const Package = @import("Package.zig");
const link = @import("link.zig");
const trace = @import("tracy.zig").trace;
const liveness = @import("liveness.zig");
const build_options = @import("build_options");
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;
const glibc = @import("glibc.zig");
const libunwind = @import("libunwind.zig");
const fatal = @import("main.zig").fatal;
const Module = @import("Module.zig");
const Cache = @import("Cache.zig");

/// General-purpose allocator. Used for both temporary and long-term storage.
gpa: *Allocator,
/// Arena-allocated memory used during initialization. Should be untouched until deinit.
arena_state: std.heap.ArenaAllocator.State,
bin_file: *link.File,
c_object_table: std.AutoArrayHashMapUnmanaged(*CObject, void) = .{},

link_error_flags: link.File.ErrorFlags = .{},

work_queue: std.fifo.LinearFifo(Job, .Dynamic),

/// The ErrorMsg memory is owned by the `CObject`, using Compilation's general purpose allocator.
failed_c_objects: std.AutoArrayHashMapUnmanaged(*CObject, *ErrorMsg) = .{},

keep_source_files_loaded: bool,
use_clang: bool,
sanitize_c: bool,
/// When this is `true` it means invoking clang as a sub-process is expected to inherit
/// stdin, stdout, stderr, and if it returns non success, to forward the exit code.
/// Otherwise we attempt to parse the error messages and expose them via the Compilation API.
/// This is `true` for `zig cc`, `zig c++`, and `zig translate-c`.
clang_passthrough_mode: bool,
/// Whether to print clang argvs to stdout.
verbose_cc: bool,
disable_c_depfile: bool,
is_test: bool,

c_source_files: []const CSourceFile,
clang_argv: []const []const u8,
cache_parent: *Cache,
/// Path to own executable for invoking `zig clang`.
self_exe_path: ?[]const u8,
zig_lib_directory: Directory,
zig_cache_directory: Directory,
libc_include_dir_list: []const []const u8,
rand: *std.rand.Random,

/// Populated when we build libc++.a. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
libcxx_static_lib: ?[]const u8 = null,
/// Populated when we build libc++abi.a. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
libcxxabi_static_lib: ?[]const u8 = null,
/// Populated when we build libunwind.a. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
libunwind_static_lib: ?CRTFile = null,
/// Populated when we build c.a. A Job to build this is placed in the queue
/// and resolved before calling linker.flush().
libc_static_lib: ?[]const u8 = null,

glibc_so_files: ?glibc.BuiltSharedObjects = null,

/// For example `Scrt1.o` and `libc_nonshared.a`. These are populated after building libc from source,
/// The set of needed CRT (C runtime) files differs depending on the target and compilation settings.
/// The key is the basename, and the value is the absolute path to the completed build artifact.
crt_files: std.StringHashMapUnmanaged(CRTFile) = .{},

/// Keeping track of this possibly open resource so we can close it later.
owned_link_dir: ?std.fs.Dir,

pub const InnerError = Module.InnerError;

pub const CRTFile = struct {
    lock: Cache.Lock,
    full_object_path: []const u8,

    fn deinit(self: *CRTFile, gpa: *Allocator) void {
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
    /// Write the machine code for a Decl to the output file.
    codegen_decl: *Module.Decl,
    /// The Decl needs to be analyzed and possibly export itself.
    /// It may have already be analyzed, or it may have been determined
    /// to be outdated; in this case perform semantic analysis again.
    analyze_decl: *Module.Decl,
    /// The source file containing the Decl has been updated, and so the
    /// Decl may need its line number information updated in the debug info.
    update_line_number: *Module.Decl,
    /// Invoke the Clang compiler to create an object file, which gets linked
    /// with the Compilation.
    c_object: *CObject,

    /// one of the glibc static objects
    glibc_crt_file: glibc.CRTFile,
    /// all of the glibc shared objects
    glibc_shared_objects,
    /// libunwind.a, usually needed when linking libc
    libunwind: void,

    /// Generate builtin.zig source code and write it into the correct place.
    generate_builtin_zig: void,
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
    },

    /// Returns if there was failure.
    pub fn clearStatus(self: *CObject, gpa: *Allocator) bool {
        switch (self.status) {
            .new => return false,
            .failure => {
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

    pub fn destroy(self: *CObject, gpa: *Allocator) void {
        _ = self.clearStatus(gpa);
        gpa.destroy(self);
    }
};

pub const AllErrors = struct {
    arena: std.heap.ArenaAllocator.State,
    list: []const Message,

    pub const Message = struct {
        src_path: []const u8,
        line: usize,
        column: usize,
        byte_offset: usize,
        msg: []const u8,

        pub fn renderToStdErr(self: Message) void {
            std.debug.print("{}:{}:{}: error: {}\n", .{
                self.src_path,
                self.line + 1,
                self.column + 1,
                self.msg,
            });
        }
    };

    pub fn deinit(self: *AllErrors, gpa: *Allocator) void {
        self.arena.promote(gpa).deinit();
    }

    fn add(
        arena: *std.heap.ArenaAllocator,
        errors: *std.ArrayList(Message),
        sub_file_path: []const u8,
        source: []const u8,
        simple_err_msg: ErrorMsg,
    ) !void {
        const loc = std.zig.findLineColumn(source, simple_err_msg.byte_offset);
        try errors.append(.{
            .src_path = try arena.allocator.dupe(u8, sub_file_path),
            .msg = try arena.allocator.dupe(u8, simple_err_msg.msg),
            .byte_offset = simple_err_msg.byte_offset,
            .line = loc.line,
            .column = loc.column,
        });
    }
};

pub const Directory = struct {
    /// This field is redundant for operations that can act on the open directory handle
    /// directly, but it is needed when passing the directory to a child process.
    /// `null` means cwd.
    path: ?[]const u8,
    handle: std.fs.Dir,

    pub fn join(self: Directory, allocator: *Allocator, paths: []const []const u8) ![]u8 {
        if (self.path) |p| {
            // TODO clean way to do this with only 1 allocation
            const part2 = try std.fs.path.join(allocator, paths);
            defer allocator.free(part2);
            return std.fs.path.join(allocator, &[_][]const u8{ p, part2 });
        } else {
            return std.fs.path.join(allocator, paths);
        }
    }
};

pub const EmitLoc = struct {
    /// If this is `null` it means the file will be output to the cache directory.
    /// When provided, both the open file handle and the path name must outlive the `Compilation`.
    directory: ?Compilation.Directory,
    /// This may not have sub-directories in it.
    basename: []const u8,
};

pub const InitOptions = struct {
    zig_lib_directory: Directory,
    zig_cache_directory: Directory,
    target: Target,
    root_name: []const u8,
    root_pkg: ?*Package,
    output_mode: std.builtin.OutputMode,
    rand: *std.rand.Random,
    dynamic_linker: ?[]const u8 = null,
    /// `null` means to not emit a binary file.
    emit_bin: ?EmitLoc,
    /// `null` means to not emit a C header file.
    emit_h: ?EmitLoc = null,
    link_mode: ?std.builtin.LinkMode = null,
    dll_export_fns: ?bool = false,
    object_format: ?std.builtin.ObjectFormat = null,
    optimize_mode: std.builtin.Mode = .Debug,
    keep_source_files_loaded: bool = false,
    clang_argv: []const []const u8 = &[0][]const u8{},
    lld_argv: []const []const u8 = &[0][]const u8{},
    lib_dirs: []const []const u8 = &[0][]const u8{},
    rpath_list: []const []const u8 = &[0][]const u8{},
    c_source_files: []const CSourceFile = &[0]CSourceFile{},
    link_objects: []const []const u8 = &[0][]const u8{},
    framework_dirs: []const []const u8 = &[0][]const u8{},
    frameworks: []const []const u8 = &[0][]const u8{},
    system_libs: []const []const u8 = &[0][]const u8{},
    link_libc: bool = false,
    link_libcpp: bool = false,
    want_pic: ?bool = null,
    want_sanitize_c: ?bool = null,
    want_stack_check: ?bool = null,
    want_valgrind: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    use_clang: ?bool = null,
    rdynamic: bool = false,
    strip: bool = false,
    single_threaded: bool = false,
    is_native_os: bool,
    link_eh_frame_hdr: bool = false,
    linker_script: ?[]const u8 = null,
    version_script: ?[]const u8 = null,
    override_soname: ?[]const u8 = null,
    linker_gc_sections: ?bool = null,
    function_sections: ?bool = null,
    linker_allow_shlib_undefined: ?bool = null,
    linker_bind_global_refs_locally: ?bool = null,
    disable_c_depfile: bool = false,
    linker_z_nodelete: bool = false,
    linker_z_defs: bool = false,
    clang_passthrough_mode: bool = false,
    verbose_cc: bool = false,
    verbose_link: bool = false,
    is_test: bool = false,
    stack_size_override: ?u64 = null,
    self_exe_path: ?[]const u8 = null,
    version: ?std.builtin.Version = null,
    libc_installation: ?*const LibCInstallation = null,
    machine_code_model: std.builtin.CodeModel = .default,
};

pub fn create(gpa: *Allocator, options: InitOptions) !*Compilation {
    const comp: *Compilation = comp: {
        // For allocations that have the same lifetime as Compilation. This arena is used only during this
        // initialization and then is freed in deinit().
        var arena_allocator = std.heap.ArenaAllocator.init(gpa);
        errdefer arena_allocator.deinit();
        const arena = &arena_allocator.allocator;

        // We put the `Compilation` itself in the arena. Freeing the arena will free the module.
        // It's initialized later after we prepare the initialization options.
        const comp = try arena.create(Compilation);
        const root_name = try arena.dupe(u8, options.root_name);

        const ofmt = options.object_format orelse options.target.getObjectFormat();

        // Make a decision on whether to use LLD or our own linker.
        const use_lld = if (options.use_lld) |explicit| explicit else blk: {
            if (!build_options.have_llvm)
                break :blk false;

            if (ofmt == .c)
                break :blk false;

            // Our linker can't handle objects or most advanced options yet.
            if (options.link_objects.len != 0 or
                options.c_source_files.len != 0 or
                options.frameworks.len != 0 or
                options.system_libs.len != 0 or
                options.link_libc or options.link_libcpp or
                options.link_eh_frame_hdr or
                options.output_mode == .Lib or
                options.lld_argv.len != 0 or
                options.linker_script != null or options.version_script != null)
            {
                break :blk true;
            }
            break :blk false;
        };

        // Make a decision on whether to use LLVM or our own backend.
        const use_llvm = if (options.use_llvm) |explicit| explicit else blk: {
            // We would want to prefer LLVM for release builds when it is available, however
            // we don't have an LLVM backend yet :)
            // We would also want to prefer LLVM for architectures that we don't have self-hosted support for too.
            break :blk false;
        };
        if (!use_llvm and options.machine_code_model != .default) {
            return error.MachineCodeModelNotSupported;
        }

        const is_dyn_lib = switch (options.output_mode) {
            .Obj, .Exe => false,
            .Lib => (options.link_mode orelse .Static) == .Dynamic,
        };
        const is_exe_or_dyn_lib = switch (options.output_mode) {
            .Obj => false,
            .Lib => is_dyn_lib,
            .Exe => true,
        };
        const must_dynamic_link = dl: {
            if (target_util.cannotDynamicLink(options.target))
                break :dl false;
            if (target_util.osRequiresLibC(options.target))
                break :dl true;
            if (is_exe_or_dyn_lib and options.link_libc and options.target.isGnuLibC())
                break :dl true;
            if (options.system_libs.len != 0)
                break :dl true;

            break :dl false;
        };
        const default_link_mode: std.builtin.LinkMode = if (must_dynamic_link) .Dynamic else .Static;
        const link_mode: std.builtin.LinkMode = if (options.link_mode) |lm| blk: {
            if (lm == .Static and must_dynamic_link) {
                return error.UnableToStaticLink;
            }
            break :blk lm;
        } else default_link_mode;

        const dll_export_fns = if (options.dll_export_fns) |explicit| explicit else is_dyn_lib;

        const libc_dirs = try detectLibCIncludeDirs(
            arena,
            options.zig_lib_directory.path.?,
            options.target,
            options.is_native_os,
            options.link_libc,
            options.libc_installation,
        );

        const must_pic: bool = b: {
            if (target_util.requiresPIC(options.target, options.link_libc))
                break :b true;
            break :b link_mode == .Dynamic;
        };
        const pic = if (options.want_pic) |explicit| pic: {
            if (!explicit and must_pic) {
                return error.TargetRequiresPIC;
            }
            break :pic explicit;
        } else must_pic;

        if (options.emit_h != null) fatal("-femit-h not supported yet", .{}); // TODO

        const emit_bin = options.emit_bin orelse fatal("-fno-emit-bin not supported yet", .{}); // TODO

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

        const single_threaded = options.single_threaded or target_util.isSingleThreaded(options.target);

        // We put everything into the cache hash that *cannot be modified during an incremental update*.
        // For example, one cannot change the target between updates, but one can change source files,
        // so the target goes into the cache hash, but source files do not. This is so that we can
        // find the same binary and incrementally update it even if there are modified source files.
        // We do this even if outputting to the current directory because we need somewhere to store
        // incremental compilation metadata.
        const cache = try arena.create(Cache);
        cache.* = .{
            .gpa = gpa,
            .manifest_dir = try options.zig_cache_directory.handle.makeOpenPath("h", .{}),
        };
        errdefer cache.manifest_dir.close();

        // This is shared hasher state common to zig source and all C source files.
        cache.hash.addBytes(build_options.version);
        cache.hash.addBytes(options.zig_lib_directory.path orelse ".");
        cache.hash.add(options.optimize_mode);
        cache.hash.add(options.target.cpu.arch);
        cache.hash.addBytes(options.target.cpu.model.name);
        cache.hash.add(options.target.cpu.features.ints);
        cache.hash.add(options.target.os.tag);
        cache.hash.add(options.is_native_os);
        cache.hash.add(options.target.abi);
        cache.hash.add(ofmt);
        cache.hash.add(pic);
        cache.hash.add(stack_check);
        cache.hash.add(link_mode);
        cache.hash.add(options.strip);
        cache.hash.add(options.link_libc);
        cache.hash.add(options.output_mode);
        cache.hash.add(options.machine_code_model);
        // TODO audit this and make sure everything is in it

        const module: ?*Module = if (options.root_pkg) |root_pkg| blk: {
            // Options that are specific to zig source files, that cannot be
            // modified between incremental updates.
            var hash = cache.hash;

            // Here we put the root source file path name, but *not* with addFile. We want the
            // hash to be the same regardless of the contents of the source file, because
            // incremental compilation will handle it, but we do want to namespace different
            // source file names because they are likely different compilations and therefore this
            // would be likely to cause cache hits.
            hash.addBytes(root_pkg.root_src_path);
            hash.addOptionalBytes(root_pkg.root_src_directory.path);
            hash.add(valgrind);
            hash.add(single_threaded);
            hash.add(options.target.os.getVersionRange());
            hash.add(dll_export_fns);

            const digest = hash.final();
            const artifact_sub_dir = try std.fs.path.join(arena, &[_][]const u8{ "o", &digest });
            var artifact_dir = try options.zig_cache_directory.handle.makeOpenPath(artifact_sub_dir, .{});
            errdefer artifact_dir.close();
            const zig_cache_artifact_directory: Directory = .{
                .handle = artifact_dir,
                .path = if (options.zig_cache_directory.path) |p|
                    try std.fs.path.join(arena, &[_][]const u8{ p, artifact_sub_dir })
                else
                    artifact_sub_dir,
            };

            // TODO when we implement serialization and deserialization of incremental compilation metadata,
            // this is where we would load it. We have open a handle to the directory where
            // the output either already is, or will be.
            // However we currently do not have serialization of such metadata, so for now
            // we set up an empty Module that does the entire compilation fresh.

            const root_scope = rs: {
                if (mem.endsWith(u8, root_pkg.root_src_path, ".zig")) {
                    const root_scope = try gpa.create(Module.Scope.File);
                    root_scope.* = .{
                        .sub_file_path = root_pkg.root_src_path,
                        .source = .{ .unloaded = {} },
                        .contents = .{ .not_available = {} },
                        .status = .never_loaded,
                        .root_container = .{
                            .file_scope = root_scope,
                            .decls = .{},
                        },
                    };
                    break :rs &root_scope.base;
                } else if (mem.endsWith(u8, root_pkg.root_src_path, ".zir")) {
                    const root_scope = try gpa.create(Module.Scope.ZIRModule);
                    root_scope.* = .{
                        .sub_file_path = root_pkg.root_src_path,
                        .source = .{ .unloaded = {} },
                        .contents = .{ .not_available = {} },
                        .status = .never_loaded,
                        .decls = .{},
                    };
                    break :rs &root_scope.base;
                } else {
                    unreachable;
                }
            };

            const module = try arena.create(Module);
            module.* = .{
                .gpa = gpa,
                .comp = comp,
                .root_pkg = root_pkg,
                .root_scope = root_scope,
                .zig_cache_artifact_directory = zig_cache_artifact_directory,
            };
            break :blk module;
        } else null;
        errdefer if (module) |zm| zm.deinit();

        // For resource management purposes.
        var owned_link_dir: ?std.fs.Dir = null;
        errdefer if (owned_link_dir) |*dir| dir.close();

        const bin_directory = emit_bin.directory orelse blk: {
            if (module) |zm| break :blk zm.zig_cache_artifact_directory;

            // We could use the cache hash as is no problem, however, we increase
            // the likelihood of cache hits by adding the first C source file
            // path name (not contents) to the hash. This way if the user is compiling
            // foo.c and bar.c as separate compilations, they get different cache
            // directories.
            var hash = cache.hash;
            if (options.c_source_files.len >= 1) {
                hash.addBytes(options.c_source_files[0].src_path);
            } else if (options.link_objects.len >= 1) {
                hash.addBytes(options.link_objects[0]);
            }

            const digest = hash.final();
            const artifact_sub_dir = try std.fs.path.join(arena, &[_][]const u8{ "o", &digest });
            var artifact_dir = try options.zig_cache_directory.handle.makeOpenPath(artifact_sub_dir, .{});
            owned_link_dir = artifact_dir;
            const link_artifact_directory: Directory = .{
                .handle = artifact_dir,
                .path = if (options.zig_cache_directory.path) |p|
                    try std.fs.path.join(arena, &[_][]const u8{ p, artifact_sub_dir })
                else
                    artifact_sub_dir,
            };
            break :blk link_artifact_directory;
        };

        const error_return_tracing = !options.strip and switch (options.optimize_mode) {
            .Debug, .ReleaseSafe => true,
            .ReleaseFast, .ReleaseSmall => false,
        };

        const bin_file = try link.File.openPath(gpa, .{
            .directory = bin_directory,
            .sub_path = emit_bin.basename,
            .root_name = root_name,
            .module = module,
            .target = options.target,
            .dynamic_linker = options.dynamic_linker,
            .output_mode = options.output_mode,
            .link_mode = link_mode,
            .object_format = ofmt,
            .optimize_mode = options.optimize_mode,
            .use_lld = use_lld,
            .use_llvm = use_llvm,
            .link_libc = options.link_libc,
            .link_libcpp = options.link_libcpp,
            .objects = options.link_objects,
            .frameworks = options.frameworks,
            .framework_dirs = options.framework_dirs,
            .system_libs = options.system_libs,
            .lib_dirs = options.lib_dirs,
            .rpath_list = options.rpath_list,
            .strip = options.strip,
            .is_native_os = options.is_native_os,
            .function_sections = options.function_sections orelse false,
            .allow_shlib_undefined = options.linker_allow_shlib_undefined,
            .bind_global_refs_locally = options.linker_bind_global_refs_locally orelse false,
            .z_nodelete = options.linker_z_nodelete,
            .z_defs = options.linker_z_defs,
            .stack_size_override = options.stack_size_override,
            .linker_script = options.linker_script,
            .version_script = options.version_script,
            .gc_sections = options.linker_gc_sections,
            .eh_frame_hdr = options.link_eh_frame_hdr,
            .rdynamic = options.rdynamic,
            .extra_lld_args = options.lld_argv,
            .override_soname = options.override_soname,
            .version = options.version,
            .libc_installation = libc_dirs.libc_installation,
            .pic = pic,
            .valgrind = valgrind,
            .stack_check = stack_check,
            .single_threaded = single_threaded,
            .verbose_link = options.verbose_link,
            .machine_code_model = options.machine_code_model,
            .dll_export_fns = dll_export_fns,
            .error_return_tracing = error_return_tracing,
        });
        errdefer bin_file.destroy();

        comp.* = .{
            .gpa = gpa,
            .arena_state = arena_allocator.state,
            .zig_lib_directory = options.zig_lib_directory,
            .zig_cache_directory = options.zig_cache_directory,
            .bin_file = bin_file,
            .work_queue = std.fifo.LinearFifo(Job, .Dynamic).init(gpa),
            .keep_source_files_loaded = options.keep_source_files_loaded,
            .use_clang = use_clang,
            .clang_argv = options.clang_argv,
            .c_source_files = options.c_source_files,
            .cache_parent = cache,
            .self_exe_path = options.self_exe_path,
            .libc_include_dir_list = libc_dirs.libc_include_dir_list,
            .sanitize_c = sanitize_c,
            .rand = options.rand,
            .clang_passthrough_mode = options.clang_passthrough_mode,
            .verbose_cc = options.verbose_cc,
            .disable_c_depfile = options.disable_c_depfile,
            .owned_link_dir = owned_link_dir,
            .is_test = options.is_test,
        };
        break :comp comp;
    };
    errdefer comp.destroy();

    if (comp.bin_file.options.module) |mod| {
        try comp.work_queue.writeItem(.{ .generate_builtin_zig = {} });
    }

    // Add a `CObject` for each `c_source_files`.
    try comp.c_object_table.ensureCapacity(gpa, options.c_source_files.len);
    for (options.c_source_files) |c_source_file| {
        const c_object = try gpa.create(CObject);
        errdefer gpa.destroy(c_object);

        c_object.* = .{
            .status = .{ .new = {} },
            .src = c_source_file,
        };
        comp.c_object_table.putAssumeCapacityNoClobber(c_object, {});
    }

    // If we need to build glibc for the target, add work items for it.
    // We go through the work queue so that building can be done in parallel.
    if (comp.wantBuildGLibCFromSource()) {
        try comp.addBuildingGLibCJobs();
    }
    if (comp.wantBuildLibUnwindFromSource()) {
        try comp.work_queue.writeItem(.{ .libunwind = {} });
    }

    return comp;
}

pub fn destroy(self: *Compilation) void {
    const optional_module = self.bin_file.options.module;
    self.bin_file.destroy();
    if (optional_module) |module| module.deinit();

    const gpa = self.gpa;
    self.work_queue.deinit();

    {
        var it = self.crt_files.iterator();
        while (it.next()) |entry| {
            entry.value.deinit(gpa);
        }
        self.crt_files.deinit(gpa);
    }

    if (self.libunwind_static_lib) |*unwind_crt_file| {
        unwind_crt_file.deinit(gpa);
    }

    for (self.c_object_table.items()) |entry| {
        entry.key.destroy(gpa);
    }
    self.c_object_table.deinit(gpa);

    for (self.failed_c_objects.items()) |entry| {
        entry.value.destroy(gpa);
    }
    self.failed_c_objects.deinit(gpa);

    self.cache_parent.manifest_dir.close();
    if (self.owned_link_dir) |*dir| dir.close();

    // This destroys `self`.
    self.arena_state.promote(gpa).deinit();
}

pub fn getTarget(self: Compilation) Target {
    return self.bin_file.options.target;
}

/// Detect changes to source files, perform semantic analysis, and update the output files.
pub fn update(self: *Compilation) !void {
    const tracy = trace(@src());
    defer tracy.end();

    // For compiling C objects, we rely on the cache hash system to avoid duplicating work.
    // Add a Job for each C object.
    try self.work_queue.ensureUnusedCapacity(self.c_object_table.items().len);
    for (self.c_object_table.items()) |entry| {
        self.work_queue.writeItemAssumeCapacity(.{ .c_object = entry.key });
    }

    if (self.bin_file.options.module) |module| {
        module.generation += 1;

        // TODO Detect which source files changed.
        // Until then we simulate a full cache miss. Source files could have been loaded for any reason;
        // to force a refresh we unload now.
        if (module.root_scope.cast(Module.Scope.File)) |zig_file| {
            zig_file.unload(module.gpa);
            module.analyzeContainer(&zig_file.root_container) catch |err| switch (err) {
                error.AnalysisFail => {
                    assert(self.totalErrorCount() != 0);
                },
                else => |e| return e,
            };
        } else if (module.root_scope.cast(Module.Scope.ZIRModule)) |zir_module| {
            zir_module.unload(module.gpa);
            module.analyzeRootZIRModule(zir_module) catch |err| switch (err) {
                error.AnalysisFail => {
                    assert(self.totalErrorCount() != 0);
                },
                else => |e| return e,
            };
        }
    }

    try self.performAllTheWork();

    if (self.bin_file.options.module) |module| {
        // Process the deletion set.
        while (module.deletion_set.popOrNull()) |decl| {
            if (decl.dependants.items().len != 0) {
                decl.deletion_flag = false;
                continue;
            }
            try module.deleteDecl(decl);
        }
    }

    if (self.totalErrorCount() != 0) {
        // Skip flushing.
        self.link_error_flags = .{};
        return;
    }

    // This is needed before reading the error flags.
    try self.bin_file.flush(self);

    self.link_error_flags = self.bin_file.errorFlags();

    // If there are any errors, we anticipate the source files being loaded
    // to report error messages. Otherwise we unload all source files to save memory.
    if (self.totalErrorCount() == 0 and !self.keep_source_files_loaded) {
        if (self.bin_file.options.module) |module| {
            module.root_scope.unload(self.gpa);
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

pub fn totalErrorCount(self: *Compilation) usize {
    var total: usize = self.failed_c_objects.items().len;

    if (self.bin_file.options.module) |module| {
        total += module.failed_decls.items().len +
            module.failed_exports.items().len +
            module.failed_files.items().len;
    }

    // The "no entry point found" error only counts if there are no other errors.
    if (total == 0) {
        return @boolToInt(self.link_error_flags.no_entry_point_found);
    }

    return total;
}

pub fn getAllErrorsAlloc(self: *Compilation) !AllErrors {
    var arena = std.heap.ArenaAllocator.init(self.gpa);
    errdefer arena.deinit();

    var errors = std.ArrayList(AllErrors.Message).init(self.gpa);
    defer errors.deinit();

    for (self.failed_c_objects.items()) |entry| {
        const c_object = entry.key;
        const err_msg = entry.value;
        try AllErrors.add(&arena, &errors, c_object.src.src_path, "", err_msg.*);
    }
    if (self.bin_file.options.module) |module| {
        for (module.failed_files.items()) |entry| {
            const scope = entry.key;
            const err_msg = entry.value;
            const source = try scope.getSource(module);
            try AllErrors.add(&arena, &errors, scope.subFilePath(), source, err_msg.*);
        }
        for (module.failed_decls.items()) |entry| {
            const decl = entry.key;
            const err_msg = entry.value;
            const source = try decl.scope.getSource(module);
            try AllErrors.add(&arena, &errors, decl.scope.subFilePath(), source, err_msg.*);
        }
        for (module.failed_exports.items()) |entry| {
            const decl = entry.key.owner_decl;
            const err_msg = entry.value;
            const source = try decl.scope.getSource(module);
            try AllErrors.add(&arena, &errors, decl.scope.subFilePath(), source, err_msg.*);
        }
    }

    if (errors.items.len == 0 and self.link_error_flags.no_entry_point_found) {
        const global_err_src_path = blk: {
            if (self.bin_file.options.module) |module| break :blk module.root_pkg.root_src_path;
            if (self.c_source_files.len != 0) break :blk self.c_source_files[0].src_path;
            if (self.bin_file.options.objects.len != 0) break :blk self.bin_file.options.objects[0];
            break :blk "(no file)";
        };
        try errors.append(.{
            .src_path = global_err_src_path,
            .line = 0,
            .column = 0,
            .byte_offset = 0,
            .msg = try std.fmt.allocPrint(&arena.allocator, "no entry point found", .{}),
        });
    }

    assert(errors.items.len == self.totalErrorCount());

    return AllErrors{
        .list = try arena.allocator.dupe(AllErrors.Message, errors.items),
        .arena = arena.state,
    };
}

pub fn performAllTheWork(self: *Compilation) error{OutOfMemory}!void {
    while (self.work_queue.readItem()) |work_item| switch (work_item) {
        .codegen_decl => |decl| switch (decl.analysis) {
            .unreferenced => unreachable,
            .in_progress => unreachable,
            .outdated => unreachable,

            .sema_failure,
            .codegen_failure,
            .dependency_failure,
            .sema_failure_retryable,
            => continue,

            .complete, .codegen_failure_retryable => {
                const module = self.bin_file.options.module.?;
                if (decl.typed_value.most_recent.typed_value.val.cast(Value.Payload.Function)) |payload| {
                    switch (payload.func.analysis) {
                        .queued => module.analyzeFnBody(decl, payload.func) catch |err| switch (err) {
                            error.AnalysisFail => {
                                assert(payload.func.analysis != .in_progress);
                                continue;
                            },
                            error.OutOfMemory => return error.OutOfMemory,
                        },
                        .in_progress => unreachable,
                        .sema_failure, .dependency_failure => continue,
                        .success => {},
                    }
                    // Here we tack on additional allocations to the Decl's arena. The allocations are
                    // lifetime annotations in the ZIR.
                    var decl_arena = decl.typed_value.most_recent.arena.?.promote(module.gpa);
                    defer decl.typed_value.most_recent.arena.?.* = decl_arena.state;
                    log.debug("analyze liveness of {}\n", .{decl.name});
                    try liveness.analyze(module.gpa, &decl_arena.allocator, payload.func.analysis.success);
                }

                assert(decl.typed_value.most_recent.typed_value.ty.hasCodeGenBits());

                self.bin_file.updateDecl(module, decl) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.AnalysisFail => {
                        decl.analysis = .dependency_failure;
                    },
                    else => {
                        try module.failed_decls.ensureCapacity(module.gpa, module.failed_decls.items().len + 1);
                        module.failed_decls.putAssumeCapacityNoClobber(decl, try ErrorMsg.create(
                            module.gpa,
                            decl.src(),
                            "unable to codegen: {}",
                            .{@errorName(err)},
                        ));
                        decl.analysis = .codegen_failure_retryable;
                    },
                };
            },
        },
        .analyze_decl => |decl| {
            const module = self.bin_file.options.module.?;
            module.ensureDeclAnalyzed(decl) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => continue,
            };
        },
        .update_line_number => |decl| {
            const module = self.bin_file.options.module.?;
            self.bin_file.updateDeclLineNumber(module, decl) catch |err| {
                try module.failed_decls.ensureCapacity(module.gpa, module.failed_decls.items().len + 1);
                module.failed_decls.putAssumeCapacityNoClobber(decl, try ErrorMsg.create(
                    module.gpa,
                    decl.src(),
                    "unable to update line number: {}",
                    .{@errorName(err)},
                ));
                decl.analysis = .codegen_failure_retryable;
            };
        },
        .c_object => |c_object| {
            self.updateCObject(c_object) catch |err| switch (err) {
                error.AnalysisFail => continue,
                else => {
                    try self.failed_c_objects.ensureCapacity(self.gpa, self.failed_c_objects.items().len + 1);
                    self.failed_c_objects.putAssumeCapacityNoClobber(c_object, try ErrorMsg.create(
                        self.gpa,
                        0,
                        "unable to build C object: {}",
                        .{@errorName(err)},
                    ));
                    c_object.status = .{ .failure = {} };
                },
            };
        },
        .glibc_crt_file => |crt_file| {
            glibc.buildCRTFile(self, crt_file) catch |err| {
                // TODO Expose this as a normal compile error rather than crashing here.
                fatal("unable to build glibc CRT file: {}", .{@errorName(err)});
            };
        },
        .glibc_shared_objects => {
            glibc.buildSharedObjects(self) catch |err| {
                // TODO Expose this as a normal compile error rather than crashing here.
                fatal("unable to build glibc shared objects: {}", .{@errorName(err)});
            };
        },
        .libunwind => {
            libunwind.buildStaticLib(self) catch |err| {
                // TODO Expose this as a normal compile error rather than crashing here.
                fatal("unable to build libunwind: {}", .{@errorName(err)});
            };
        },
        .generate_builtin_zig => {
            // This Job is only queued up if there is a zig module.
            self.updateBuiltinZigFile(self.bin_file.options.module.?) catch |err| {
                // TODO Expose this as a normal compile error rather than crashing here.
                fatal("unable to update builtin.zig file: {}", .{@errorName(err)});
            };
        },
    };
}

fn updateCObject(comp: *Compilation, c_object: *CObject) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (!build_options.have_llvm) {
        return comp.failCObj(c_object, "clang not available: compiler not built with LLVM extensions enabled", .{});
    }
    const self_exe_path = comp.self_exe_path orelse
        return comp.failCObj(c_object, "clang compilation disabled", .{});

    if (c_object.clearStatus(comp.gpa)) {
        // There was previous failure.
        comp.failed_c_objects.removeAssertDiscard(c_object);
    }

    var ch = comp.cache_parent.obtain();
    defer ch.deinit();

    ch.hash.add(comp.sanitize_c);
    ch.hash.addListOfBytes(comp.clang_argv);
    ch.hash.add(comp.bin_file.options.link_libcpp);
    ch.hash.addListOfBytes(comp.libc_include_dir_list);
    _ = try ch.addFile(c_object.src.src_path, null);
    {
        // Hash the extra flags, with special care to call addFile for file parameters.
        // TODO this logic can likely be improved by utilizing clang_options_data.zig.
        const file_args = [_][]const u8{"-include"};
        var arg_i: usize = 0;
        while (arg_i < c_object.src.extra_flags.len) : (arg_i += 1) {
            const arg = c_object.src.extra_flags[arg_i];
            ch.hash.addBytes(arg);
            for (file_args) |file_arg| {
                if (mem.eql(u8, file_arg, arg) and arg_i + 1 < c_object.src.extra_flags.len) {
                    arg_i += 1;
                    _ = try ch.addFile(c_object.src.extra_flags[arg_i], null);
                }
            }
        }
    }

    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    const c_source_basename = std.fs.path.basename(c_object.src.src_path);
    // Special case when doing build-obj for just one C file. When there are more than one object
    // file and building an object we need to link them together, but with just one it should go
    // directly to the output file.
    const direct_o = comp.c_source_files.len == 1 and comp.bin_file.options.module == null and
        comp.bin_file.options.output_mode == .Obj and comp.bin_file.options.objects.len == 0;
    const o_basename_noext = if (direct_o)
        comp.bin_file.options.root_name
    else
        mem.split(c_source_basename, ".").next().?;
    const o_basename = try std.fmt.allocPrint(arena, "{}{}", .{ o_basename_noext, comp.getTarget().oFileExt() });

    const digest = if ((try ch.hit()) and !comp.disable_c_depfile) ch.final() else blk: {
        var argv = std.ArrayList([]const u8).init(comp.gpa);
        defer argv.deinit();

        // We can't know the digest until we do the C compiler invocation, so we need a temporary filename.
        const out_obj_path = try comp.tmpFilePath(arena, o_basename);
        var zig_cache_tmp_dir = try comp.zig_cache_directory.handle.makeOpenPath("tmp", .{});
        defer zig_cache_tmp_dir.close();

        try argv.appendSlice(&[_][]const u8{ self_exe_path, "clang", "-c" });

        const ext = classifyFileExt(c_object.src.src_path);
        const out_dep_path: ?[]const u8 = if (comp.disable_c_depfile or !ext.clangSupportsDepFile())
            null
        else
            try std.fmt.allocPrint(arena, "{}.d", .{out_obj_path});
        try comp.addCCArgs(arena, &argv, ext, false, out_dep_path);

        try argv.append("-o");
        try argv.append(out_obj_path);

        try argv.append(c_object.src.src_path);
        try argv.appendSlice(c_object.src.extra_flags);

        if (comp.verbose_cc) {
            for (argv.items[0 .. argv.items.len - 1]) |arg| {
                std.debug.print("{} ", .{arg});
            }
            std.debug.print("{}\n", .{argv.items[argv.items.len - 1]});
        }

        const child = try std.ChildProcess.init(argv.items, arena);
        defer child.deinit();

        if (comp.clang_passthrough_mode) {
            child.stdin_behavior = .Inherit;
            child.stdout_behavior = .Inherit;
            child.stderr_behavior = .Inherit;

            const term = child.spawnAndWait() catch |err| {
                return comp.failCObj(c_object, "unable to spawn {}: {}", .{ argv.items[0], @errorName(err) });
            };
            switch (term) {
                .Exited => |code| {
                    if (code != 0) {
                        // TODO https://github.com/ziglang/zig/issues/6342
                        std.process.exit(1);
                    }
                },
                else => std.process.exit(1),
            }
        } else {
            child.stdin_behavior = .Ignore;
            child.stdout_behavior = .Pipe;
            child.stderr_behavior = .Pipe;

            try child.spawn();

            const stdout_reader = child.stdout.?.reader();
            const stderr_reader = child.stderr.?.reader();

            // TODO https://github.com/ziglang/zig/issues/6343
            const stdout = try stdout_reader.readAllAlloc(arena, std.math.maxInt(u32));
            const stderr = try stderr_reader.readAllAlloc(arena, 10 * 1024 * 1024);

            const term = child.wait() catch |err| {
                return comp.failCObj(c_object, "unable to spawn {}: {}", .{ argv.items[0], @errorName(err) });
            };

            switch (term) {
                .Exited => |code| {
                    if (code != 0) {
                        // TODO parse clang stderr and turn it into an error message
                        // and then call failCObjWithOwnedErrorMsg
                        std.log.err("clang failed with stderr: {}", .{stderr});
                        return comp.failCObj(c_object, "clang exited with code {}", .{code});
                    }
                },
                else => {
                    std.log.err("clang terminated with stderr: {}", .{stderr});
                    return comp.failCObj(c_object, "clang terminated unexpectedly", .{});
                },
            }
        }

        if (out_dep_path) |dep_file_path| {
            const dep_basename = std.fs.path.basename(dep_file_path);
            // Add the files depended on to the cache system.
            try ch.addDepFilePost(zig_cache_tmp_dir, dep_basename);
            // Just to save disk space, we delete the file because it is never needed again.
            zig_cache_tmp_dir.deleteFile(dep_basename) catch |err| {
                std.log.warn("failed to delete '{}': {}", .{ dep_file_path, @errorName(err) });
            };
        }

        // Rename into place.
        const digest = ch.final();
        const o_sub_path = try std.fs.path.join(arena, &[_][]const u8{ "o", &digest });
        var o_dir = try comp.zig_cache_directory.handle.makeOpenPath(o_sub_path, .{});
        defer o_dir.close();
        // TODO https://github.com/ziglang/zig/issues/6344
        const tmp_basename = std.fs.path.basename(out_obj_path);
        try std.os.renameat(zig_cache_tmp_dir.fd, tmp_basename, o_dir.fd, o_basename);

        ch.writeManifest() catch |err| {
            std.log.warn("failed to write cache manifest when compiling '{}': {}", .{ c_object.src.src_path, @errorName(err) });
        };
        break :blk digest;
    };

    const components = if (comp.zig_cache_directory.path) |p|
        &[_][]const u8{ p, "o", &digest, o_basename }
    else
        &[_][]const u8{ "o", &digest, o_basename };

    c_object.status = .{
        .success = .{
            .object_path = try std.fs.path.join(comp.gpa, components),
            .lock = ch.toOwnedLock(),
        },
    };
}

fn tmpFilePath(comp: *Compilation, arena: *Allocator, suffix: []const u8) error{OutOfMemory}![]const u8 {
    const s = std.fs.path.sep_str;
    const rand_int = comp.rand.int(u64);
    if (comp.zig_cache_directory.path) |p| {
        return std.fmt.allocPrint(arena, "{}" ++ s ++ "tmp" ++ s ++ "{x}-{s}", .{ p, rand_int, suffix });
    } else {
        return std.fmt.allocPrint(arena, "tmp" ++ s ++ "{x}-{s}", .{ rand_int, suffix });
    }
}

/// Add common C compiler args between translate-c and C object compilation.
fn addCCArgs(
    comp: *Compilation,
    arena: *Allocator,
    argv: *std.ArrayList([]const u8),
    ext: FileExt,
    translate_c: bool,
    out_dep_path: ?[]const u8,
) !void {
    const target = comp.getTarget();

    if (translate_c) {
        try argv.appendSlice(&[_][]const u8{ "-x", "c" });
    }

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

    try argv.ensureCapacity(argv.items.len + comp.bin_file.options.framework_dirs.len * 2);
    for (comp.bin_file.options.framework_dirs) |framework_dir| {
        argv.appendAssumeCapacity("-iframework");
        argv.appendAssumeCapacity(framework_dir);
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
    }

    const llvm_triple = try @import("codegen/llvm.zig").targetTriple(arena, target);
    try argv.appendSlice(&[_][]const u8{ "-target", llvm_triple });

    switch (ext) {
        .c, .cpp, .h => {
            try argv.appendSlice(&[_][]const u8{
                "-nostdinc",
                "-fno-spell-checking",
            });

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
            try argv.ensureCapacity(argv.items.len + all_features_list.len * 4);
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
                try argv.append(try std.fmt.allocPrint(arena, "-mcmodel={}", .{@tagName(mcmodel)}));
            }
            if (translate_c) {
                // This gives us access to preprocessing entities, presumably at the cost of performance.
                try argv.append("-Xclang");
                try argv.append("-detailed-preprocessing-record");
            }

            // windows.h has files such as pshpack1.h which do #pragma packing, triggering a clang warning.
            // So for this target, we disable this warning.
            if (target.os.tag == .windows and target.abi.isGnu()) {
                try argv.append("-Wno-pragma-pack");
            }

            if (!comp.bin_file.options.strip) {
                try argv.append("-g");
            }

            if (comp.haveFramePointer()) {
                try argv.append("-fno-omit-frame-pointer");
            } else {
                try argv.append("-fomit-frame-pointer");
            }

            if (comp.sanitize_c) {
                try argv.append("-fsanitize=undefined");
                try argv.append("-fsanitize-trap=undefined");
            }

            switch (comp.bin_file.options.optimize_mode) {
                .Debug => {
                    // windows c runtime requires -D_DEBUG if using debug libraries
                    try argv.append("-D_DEBUG");
                    try argv.append("-Og");

                    if (comp.bin_file.options.link_libc) {
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
                    if (comp.bin_file.options.link_libc) {
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
        },
        .so, .assembly, .ll, .bc, .unknown => {},
    }
    if (out_dep_path) |p| {
        try argv.appendSlice(&[_][]const u8{ "-MD", "-MV", "-MF", p });
    }
    // Argh, why doesn't the assembler accept the list of CPU features?!
    // I don't see a way to do this other than hard coding everything.
    switch (target.cpu.arch) {
        .riscv32, .riscv64 => {
            if (std.Target.riscv.featureSetHas(target.cpu.features, .relax)) {
                try argv.append("-mrelax");
            } else {
                try argv.append("-mno-relax");
            }
        },
        else => {
            // TODO
        },
    }

    if (target.os.tag == .freestanding) {
        try argv.append("-ffreestanding");
    }

    try argv.appendSlice(comp.clang_argv);
}

fn failCObj(comp: *Compilation, c_object: *CObject, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    const err_msg = try ErrorMsg.create(comp.gpa, 0, "unable to build C object: " ++ format, args);
    return comp.failCObjWithOwnedErrorMsg(c_object, err_msg);
}

fn failCObjWithOwnedErrorMsg(comp: *Compilation, c_object: *CObject, err_msg: *ErrorMsg) InnerError {
    {
        errdefer err_msg.destroy(comp.gpa);
        try comp.failed_c_objects.ensureCapacity(comp.gpa, comp.failed_c_objects.items().len + 1);
    }
    comp.failed_c_objects.putAssumeCapacityNoClobber(c_object, err_msg);
    c_object.status = .failure;
    return error.AnalysisFail;
}

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,

    pub fn create(gpa: *Allocator, byte_offset: usize, comptime format: []const u8, args: anytype) !*ErrorMsg {
        const self = try gpa.create(ErrorMsg);
        errdefer gpa.destroy(self);
        self.* = try init(gpa, byte_offset, format, args);
        return self;
    }

    /// Assumes the ErrorMsg struct and msg were both allocated with allocator.
    pub fn destroy(self: *ErrorMsg, gpa: *Allocator) void {
        self.deinit(gpa);
        gpa.destroy(self);
    }

    pub fn init(gpa: *Allocator, byte_offset: usize, comptime format: []const u8, args: anytype) !ErrorMsg {
        return ErrorMsg{
            .byte_offset = byte_offset,
            .msg = try std.fmt.allocPrint(gpa, format, args),
        };
    }

    pub fn deinit(self: *ErrorMsg, gpa: *Allocator) void {
        gpa.free(self.msg);
        self.* = undefined;
    }
};

pub const FileExt = enum {
    c,
    cpp,
    h,
    ll,
    bc,
    assembly,
    so,
    unknown,

    pub fn clangSupportsDepFile(ext: FileExt) bool {
        return switch (ext) {
            .c, .cpp, .h => true,
            .ll, .bc, .assembly, .so, .unknown => false,
        };
    }
};

pub fn hasCExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".c");
}

pub fn hasCppExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".C") or
        mem.endsWith(u8, filename, ".cc") or
        mem.endsWith(u8, filename, ".cpp") or
        mem.endsWith(u8, filename, ".cxx");
}

pub fn hasAsmExt(filename: []const u8) bool {
    return mem.endsWith(u8, filename, ".s") or mem.endsWith(u8, filename, ".S");
}

pub fn classifyFileExt(filename: []const u8) FileExt {
    if (hasCExt(filename)) {
        return .c;
    } else if (hasCppExt(filename)) {
        return .cpp;
    } else if (mem.endsWith(u8, filename, ".ll")) {
        return .ll;
    } else if (mem.endsWith(u8, filename, ".bc")) {
        return .bc;
    } else if (hasAsmExt(filename)) {
        return .assembly;
    } else if (mem.endsWith(u8, filename, ".h")) {
        return .h;
    } else if (mem.endsWith(u8, filename, ".so")) {
        return .so;
    }
    // Look for .so.X, .so.X.Y, .so.X.Y.Z
    var it = mem.split(filename, ".");
    _ = it.next().?;
    var so_txt = it.next() orelse return .unknown;
    while (!mem.eql(u8, so_txt, "so")) {
        so_txt = it.next() orelse return .unknown;
    }
    const n1 = it.next() orelse return .unknown;
    const n2 = it.next();
    const n3 = it.next();

    _ = std.fmt.parseInt(u32, n1, 10) catch return .unknown;
    if (n2) |x| _ = std.fmt.parseInt(u32, x, 10) catch return .unknown;
    if (n3) |x| _ = std.fmt.parseInt(u32, x, 10) catch return .unknown;
    if (it.next() != null) return .unknown;

    return .so;
}

test "classifyFileExt" {
    std.testing.expectEqual(FileExt.cpp, classifyFileExt("foo.cc"));
    std.testing.expectEqual(FileExt.unknown, classifyFileExt("foo.nim"));
    std.testing.expectEqual(FileExt.so, classifyFileExt("foo.so"));
    std.testing.expectEqual(FileExt.so, classifyFileExt("foo.so.1"));
    std.testing.expectEqual(FileExt.so, classifyFileExt("foo.so.1.2"));
    std.testing.expectEqual(FileExt.so, classifyFileExt("foo.so.1.2.3"));
    std.testing.expectEqual(FileExt.unknown, classifyFileExt("foo.so.1.2.3~"));
}

fn haveFramePointer(comp: *Compilation) bool {
    // If you complicate this logic make sure you update the parent cache hash.
    // Right now it's not in the cache hash because the value depends on optimize_mode
    // and strip which are both already part of the hash.
    return switch (comp.bin_file.options.optimize_mode) {
        .Debug, .ReleaseSafe => !comp.bin_file.options.strip,
        .ReleaseSmall, .ReleaseFast => false,
    };
}

const LibCDirs = struct {
    libc_include_dir_list: []const []const u8,
    libc_installation: ?*const LibCInstallation,
};

fn detectLibCIncludeDirs(
    arena: *Allocator,
    zig_lib_dir: []const u8,
    target: Target,
    is_native_os: bool,
    link_libc: bool,
    libc_installation: ?*const LibCInstallation,
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

    if (target_util.canBuildLibC(target)) {
        const generic_name = target_util.libCGenericName(target);
        // Some architectures are handled by the same set of headers.
        const arch_name = if (target.abi.isMusl()) target_util.archMuslName(target.cpu.arch) else @tagName(target.cpu.arch);
        const os_name = @tagName(target.os.tag);
        // Musl's headers are ABI-agnostic and so they all have the "musl" ABI name.
        const abi_name = if (target.abi.isMusl()) "musl" else @tagName(target.abi);
        const s = std.fs.path.sep_str;
        const arch_include_dir = try std.fmt.allocPrint(
            arena,
            "{}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{}-{}-{}",
            .{ zig_lib_dir, arch_name, os_name, abi_name },
        );
        const generic_include_dir = try std.fmt.allocPrint(
            arena,
            "{}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "generic-{}",
            .{ zig_lib_dir, generic_name },
        );
        const arch_os_include_dir = try std.fmt.allocPrint(
            arena,
            "{}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{}-{}-any",
            .{ zig_lib_dir, @tagName(target.cpu.arch), os_name },
        );
        const generic_os_include_dir = try std.fmt.allocPrint(
            arena,
            "{}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "any-{}-any",
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
    }

    if (is_native_os) {
        const libc = try arena.create(LibCInstallation);
        libc.* = try LibCInstallation.findNative(.{ .allocator = arena });
        return detectLibCFromLibCInstallation(arena, target, libc);
    }

    return LibCDirs{
        .libc_include_dir_list = &[0][]u8{},
        .libc_installation = null,
    };
}

fn detectLibCFromLibCInstallation(arena: *Allocator, target: Target, lci: *const LibCInstallation) !LibCDirs {
    var list = std.ArrayList([]const u8).init(arena);
    try list.ensureCapacity(4);

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
    return LibCDirs{
        .libc_include_dir_list = list.items,
        .libc_installation = lci,
    };
}

pub fn get_libc_crt_file(comp: *Compilation, arena: *Allocator, basename: []const u8) ![]const u8 {
    if (comp.wantBuildGLibCFromSource()) {
        return comp.crt_files.get(basename).?.full_object_path;
    }
    const lci = comp.bin_file.options.libc_installation orelse return error.LibCInstallationNotAvailable;
    const crt_dir_path = lci.crt_dir orelse return error.LibCInstallationMissingCRTDir;
    const full_path = try std.fs.path.join(arena, &[_][]const u8{ crt_dir_path, basename });
    return full_path;
}

fn addBuildingGLibCJobs(comp: *Compilation) !void {
    try comp.work_queue.write(&[_]Job{
        .{ .glibc_crt_file = .crti_o },
        .{ .glibc_crt_file = .crtn_o },
        .{ .glibc_crt_file = .scrt1_o },
        .{ .glibc_crt_file = .libc_nonshared_a },
        .{ .glibc_shared_objects = {} },
    });
}

fn wantBuildGLibCFromSource(comp: *Compilation) bool {
    const is_exe_or_dyn_lib = switch (comp.bin_file.options.output_mode) {
        .Obj => false,
        .Lib => comp.bin_file.options.link_mode == .Dynamic,
        .Exe => true,
    };
    return comp.bin_file.options.link_libc and is_exe_or_dyn_lib and
        comp.bin_file.options.libc_installation == null and
        comp.bin_file.options.target.isGnuLibC();
}

fn wantBuildLibUnwindFromSource(comp: *Compilation) bool {
    const is_exe_or_dyn_lib = switch (comp.bin_file.options.output_mode) {
        .Obj => false,
        .Lib => comp.bin_file.options.link_mode == .Dynamic,
        .Exe => true,
    };
    return comp.bin_file.options.link_libc and is_exe_or_dyn_lib and
        comp.bin_file.options.libc_installation == null;
}

fn updateBuiltinZigFile(comp: *Compilation, mod: *Module) !void {
    const source = try comp.generateBuiltinZigSource();
    defer comp.gpa.free(source);
    try mod.zig_cache_artifact_directory.handle.writeFile("builtin.zig", source);
}

pub fn generateBuiltinZigSource(comp: *Compilation) ![]u8 {
    var buffer = std.ArrayList(u8).init(comp.gpa);
    defer buffer.deinit();

    const target = comp.getTarget();
    const generic_arch_name = target.cpu.arch.genericName();

    @setEvalBranchQuota(4000);
    try buffer.writer().print(
        \\usingnamespace @import("std").builtin;
        \\/// Deprecated
        \\pub const arch = std.Target.current.cpu.arch;
        \\/// Deprecated
        \\pub const endian = std.Target.current.cpu.arch.endian();
        \\pub const output_mode = OutputMode.{};
        \\pub const link_mode = LinkMode.{};
        \\pub const is_test = {};
        \\pub const single_threaded = {};
        \\pub const abi = Abi.{};
        \\pub const cpu: Cpu = Cpu{{
        \\    .arch = .{},
        \\    .model = &Target.{}.cpu.{},
        \\    .features = Target.{}.featureSet(&[_]Target.{}.Feature{{
        \\
    , .{
        @tagName(comp.bin_file.options.output_mode),
        @tagName(comp.bin_file.options.link_mode),
        comp.is_test,
        comp.bin_file.options.single_threaded,
        @tagName(target.abi),
        @tagName(target.cpu.arch),
        generic_arch_name,
        target.cpu.model.name,
        generic_arch_name,
        generic_arch_name,
    });

    for (target.cpu.arch.allFeaturesList()) |feature, index_usize| {
        const index = @intCast(std.Target.Cpu.Feature.Set.Index, index_usize);
        const is_enabled = target.cpu.features.isEnabled(index);
        if (is_enabled) {
            // TODO some kind of "zig identifier escape" function rather than
            // unconditionally using @"" syntax
            try buffer.appendSlice("        .@\"");
            try buffer.appendSlice(feature.name);
            try buffer.appendSlice("\",\n");
        }
    }

    try buffer.writer().print(
        \\    }}),
        \\}};
        \\pub const os = Os{{
        \\    .tag = .{},
        \\    .version_range = .{{
        ,
        .{@tagName(target.os.tag)},
    );

    switch (target.os.getVersionRange()) {
        .none => try buffer.appendSlice(" .none = {} }\n"),
        .semver => |semver| try buffer.outStream().print(
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
        .linux => |linux| try buffer.outStream().print(
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
        .windows => |windows| try buffer.outStream().print(
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
    try buffer.writer().print(
        \\pub const object_format = ObjectFormat.{};
        \\pub const mode = Mode.{};
        \\pub const link_libc = {};
        \\pub const link_libcpp = {};
        \\pub const have_error_return_tracing = {};
        \\pub const valgrind_support = {};
        \\pub const position_independent_code = {};
        \\pub const strip_debug_info = {};
        \\pub const code_model = CodeModel.{};
        \\
    , .{
        @tagName(comp.bin_file.options.object_format),
        @tagName(comp.bin_file.options.optimize_mode),
        comp.bin_file.options.link_libc,
        comp.bin_file.options.link_libcpp,
        comp.bin_file.options.error_return_tracing,
        comp.bin_file.options.valgrind,
        comp.bin_file.options.pic,
        comp.bin_file.options.strip,
        @tagName(comp.bin_file.options.machine_code_model),
    });
    return buffer.toOwnedSlice();
}
