const std = @import("std.zig");
const builtin = @import("builtin");
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const debug = std.debug;
const panic = std.debug.panic;
const assert = debug.assert;
const log = std.log;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Allocator = mem.Allocator;
const process = std.process;
const EnvMap = std.process.EnvMap;
const fmt_lib = std.fmt;
const File = std.fs.File;
const CrossTarget = std.zig.CrossTarget;
const NativeTargetInfo = std.zig.system.NativeTargetInfo;
const Sha256 = std.crypto.hash.sha2.Sha256;
const Build = @This();

pub const Cache = @import("Build/Cache.zig");

/// deprecated: use `Step.Compile`.
pub const LibExeObjStep = Step.Compile;
/// deprecated: use `Build`.
pub const Builder = Build;
/// deprecated: use `Step.InstallDir.Options`
pub const InstallDirectoryOptions = Step.InstallDir.Options;

pub const Step = @import("Build/Step.zig");
/// deprecated: use `Step.CheckFile`.
pub const CheckFileStep = @import("Build/Step/CheckFile.zig");
/// deprecated: use `Step.CheckObject`.
pub const CheckObjectStep = @import("Build/Step/CheckObject.zig");
/// deprecated: use `Step.ConfigHeader`.
pub const ConfigHeaderStep = @import("Build/Step/ConfigHeader.zig");
/// deprecated: use `Step.Fmt`.
pub const FmtStep = @import("Build/Step/Fmt.zig");
/// deprecated: use `Step.InstallArtifact`.
pub const InstallArtifactStep = @import("Build/Step/InstallArtifact.zig");
/// deprecated: use `Step.InstallDir`.
pub const InstallDirStep = @import("Build/Step/InstallDir.zig");
/// deprecated: use `Step.InstallFile`.
pub const InstallFileStep = @import("Build/Step/InstallFile.zig");
/// deprecated: use `Step.ObjCopy`.
pub const ObjCopyStep = @import("Build/Step/ObjCopy.zig");
/// deprecated: use `Step.Compile`.
pub const CompileStep = @import("Build/Step/Compile.zig");
/// deprecated: use `Step.Options`.
pub const OptionsStep = @import("Build/Step/Options.zig");
/// deprecated: use `Step.RemoveDir`.
pub const RemoveDirStep = @import("Build/Step/RemoveDir.zig");
/// deprecated: use `Step.Run`.
pub const RunStep = @import("Build/Step/Run.zig");
/// deprecated: use `Step.TranslateC`.
pub const TranslateCStep = @import("Build/Step/TranslateC.zig");
/// deprecated: use `Step.WriteFile`.
pub const WriteFileStep = @import("Build/Step/WriteFile.zig");
/// deprecated: use `LazyPath`.
pub const FileSource = LazyPath;

install_tls: TopLevelStep,
uninstall_tls: TopLevelStep,
allocator: Allocator,
user_input_options: UserInputOptionsMap,
available_options_map: AvailableOptionsMap,
available_options_list: ArrayList(AvailableOption),
verbose: bool,
verbose_link: bool,
verbose_cc: bool,
verbose_air: bool,
verbose_llvm_ir: ?[]const u8,
verbose_llvm_bc: ?[]const u8,
verbose_cimport: bool,
verbose_llvm_cpu_features: bool,
reference_trace: ?u32 = null,
invalid_user_input: bool,
zig_exe: [:0]const u8,
default_step: *Step,
env_map: *EnvMap,
top_level_steps: std.StringArrayHashMapUnmanaged(*TopLevelStep),
install_prefix: []const u8,
dest_dir: ?[]const u8,
lib_dir: []const u8,
exe_dir: []const u8,
h_dir: []const u8,
install_path: []const u8,
sysroot: ?[]const u8 = null,
search_prefixes: ArrayList([]const u8),
libc_file: ?[]const u8 = null,
installed_files: ArrayList(InstalledFile),
/// Path to the directory containing build.zig.
build_root: Cache.Directory,
cache_root: Cache.Directory,
global_cache_root: Cache.Directory,
cache: *Cache,
zig_lib_dir: ?LazyPath,
vcpkg_root: VcpkgRoot = .unattempted,
pkg_config_pkg_list: ?(PkgConfigError![]const PkgConfigPkg) = null,
args: ?[][]const u8 = null,
debug_log_scopes: []const []const u8 = &.{},
debug_compile_errors: bool = false,
debug_pkg_config: bool = false,

/// Experimental. Use system Darling installation to run cross compiled macOS build artifacts.
enable_darling: bool = false,
/// Use system QEMU installation to run cross compiled foreign architecture build artifacts.
enable_qemu: bool = false,
/// Darwin. Use Rosetta to run x86_64 macOS build artifacts on arm64 macOS.
enable_rosetta: bool = false,
/// Use system Wasmtime installation to run cross compiled wasm/wasi build artifacts.
enable_wasmtime: bool = false,
/// Use system Wine installation to run cross compiled Windows build artifacts.
enable_wine: bool = false,
/// After following the steps in https://github.com/ziglang/zig/wiki/Updating-libc#glibc,
/// this will be the directory $glibc-build-dir/install/glibcs
/// Given the example of the aarch64 target, this is the directory
/// that contains the path `aarch64-linux-gnu/lib/ld-linux-aarch64.so.1`.
glibc_runtimes_dir: ?[]const u8 = null,

/// Information about the native target. Computed before build() is invoked.
host: NativeTargetInfo,

dep_prefix: []const u8 = "",

modules: std.StringArrayHashMap(*Module),
/// A map from build root dirs to the corresponding `*Dependency`. This is shared with all child
/// `Build`s.
initialized_deps: *std.StringHashMap(*Dependency),

pub const ExecError = error{
    ReadFailure,
    ExitCodeFailure,
    ProcessTerminated,
    ExecNotSupported,
} || std.ChildProcess.SpawnError;

pub const PkgConfigError = error{
    PkgConfigCrashed,
    PkgConfigFailed,
    PkgConfigNotInstalled,
    PkgConfigInvalidOutput,
};

pub const PkgConfigPkg = struct {
    name: []const u8,
    desc: []const u8,
};

pub const CStd = enum {
    C89,
    C99,
    C11,
};

const UserInputOptionsMap = StringHashMap(UserInputOption);
const AvailableOptionsMap = StringHashMap(AvailableOption);

const AvailableOption = struct {
    name: []const u8,
    type_id: TypeId,
    description: []const u8,
    /// If the `type_id` is `enum` this provides the list of enum options
    enum_options: ?[]const []const u8,
};

const UserInputOption = struct {
    name: []const u8,
    value: UserValue,
    used: bool,
};

const UserValue = union(enum) {
    flag: void,
    scalar: []const u8,
    list: ArrayList([]const u8),
    map: StringHashMap(*const UserValue),
};

const TypeId = enum {
    bool,
    int,
    float,
    @"enum",
    string,
    list,
    build_id,
};

const TopLevelStep = struct {
    pub const base_id = .top_level;

    step: Step,
    description: []const u8,
};

pub const DirList = struct {
    lib_dir: ?[]const u8 = null,
    exe_dir: ?[]const u8 = null,
    include_dir: ?[]const u8 = null,
};

pub fn create(
    allocator: Allocator,
    zig_exe: [:0]const u8,
    build_root: Cache.Directory,
    cache_root: Cache.Directory,
    global_cache_root: Cache.Directory,
    host: NativeTargetInfo,
    cache: *Cache,
) !*Build {
    const env_map = try allocator.create(EnvMap);
    env_map.* = try process.getEnvMap(allocator);

    const initialized_deps = try allocator.create(std.StringHashMap(*Dependency));
    initialized_deps.* = std.StringHashMap(*Dependency).init(allocator);

    const self = try allocator.create(Build);
    self.* = .{
        .zig_exe = zig_exe,
        .build_root = build_root,
        .cache_root = cache_root,
        .global_cache_root = global_cache_root,
        .cache = cache,
        .verbose = false,
        .verbose_link = false,
        .verbose_cc = false,
        .verbose_air = false,
        .verbose_llvm_ir = null,
        .verbose_llvm_bc = null,
        .verbose_cimport = false,
        .verbose_llvm_cpu_features = false,
        .invalid_user_input = false,
        .allocator = allocator,
        .user_input_options = UserInputOptionsMap.init(allocator),
        .available_options_map = AvailableOptionsMap.init(allocator),
        .available_options_list = ArrayList(AvailableOption).init(allocator),
        .top_level_steps = .{},
        .default_step = undefined,
        .env_map = env_map,
        .search_prefixes = ArrayList([]const u8).init(allocator),
        .install_prefix = undefined,
        .lib_dir = undefined,
        .exe_dir = undefined,
        .h_dir = undefined,
        .dest_dir = env_map.get("DESTDIR"),
        .installed_files = ArrayList(InstalledFile).init(allocator),
        .install_tls = .{
            .step = Step.init(.{
                .id = .top_level,
                .name = "install",
                .owner = self,
            }),
            .description = "Copy build artifacts to prefix path",
        },
        .uninstall_tls = .{
            .step = Step.init(.{
                .id = .top_level,
                .name = "uninstall",
                .owner = self,
                .makeFn = makeUninstall,
            }),
            .description = "Remove build artifacts from prefix path",
        },
        .zig_lib_dir = null,
        .install_path = undefined,
        .args = null,
        .host = host,
        .modules = std.StringArrayHashMap(*Module).init(allocator),
        .initialized_deps = initialized_deps,
    };
    try self.top_level_steps.put(allocator, self.install_tls.step.name, &self.install_tls);
    try self.top_level_steps.put(allocator, self.uninstall_tls.step.name, &self.uninstall_tls);
    self.default_step = &self.install_tls.step;
    return self;
}

fn createChild(
    parent: *Build,
    dep_name: []const u8,
    build_root: Cache.Directory,
    args: anytype,
) !*Build {
    const child = try createChildOnly(parent, dep_name, build_root);
    try applyArgs(child, args);
    return child;
}

fn createChildOnly(parent: *Build, dep_name: []const u8, build_root: Cache.Directory) !*Build {
    const allocator = parent.allocator;
    const child = try allocator.create(Build);
    child.* = .{
        .allocator = allocator,
        .install_tls = .{
            .step = Step.init(.{
                .id = .top_level,
                .name = "install",
                .owner = child,
            }),
            .description = "Copy build artifacts to prefix path",
        },
        .uninstall_tls = .{
            .step = Step.init(.{
                .id = .top_level,
                .name = "uninstall",
                .owner = child,
                .makeFn = makeUninstall,
            }),
            .description = "Remove build artifacts from prefix path",
        },
        .user_input_options = UserInputOptionsMap.init(allocator),
        .available_options_map = AvailableOptionsMap.init(allocator),
        .available_options_list = ArrayList(AvailableOption).init(allocator),
        .verbose = parent.verbose,
        .verbose_link = parent.verbose_link,
        .verbose_cc = parent.verbose_cc,
        .verbose_air = parent.verbose_air,
        .verbose_llvm_ir = parent.verbose_llvm_ir,
        .verbose_llvm_bc = parent.verbose_llvm_bc,
        .verbose_cimport = parent.verbose_cimport,
        .verbose_llvm_cpu_features = parent.verbose_llvm_cpu_features,
        .reference_trace = parent.reference_trace,
        .invalid_user_input = false,
        .zig_exe = parent.zig_exe,
        .default_step = undefined,
        .env_map = parent.env_map,
        .top_level_steps = .{},
        .install_prefix = undefined,
        .dest_dir = parent.dest_dir,
        .lib_dir = parent.lib_dir,
        .exe_dir = parent.exe_dir,
        .h_dir = parent.h_dir,
        .install_path = parent.install_path,
        .sysroot = parent.sysroot,
        .search_prefixes = ArrayList([]const u8).init(allocator),
        .libc_file = parent.libc_file,
        .installed_files = ArrayList(InstalledFile).init(allocator),
        .build_root = build_root,
        .cache_root = parent.cache_root,
        .global_cache_root = parent.global_cache_root,
        .cache = parent.cache,
        .zig_lib_dir = parent.zig_lib_dir,
        .debug_log_scopes = parent.debug_log_scopes,
        .debug_compile_errors = parent.debug_compile_errors,
        .debug_pkg_config = parent.debug_pkg_config,
        .enable_darling = parent.enable_darling,
        .enable_qemu = parent.enable_qemu,
        .enable_rosetta = parent.enable_rosetta,
        .enable_wasmtime = parent.enable_wasmtime,
        .enable_wine = parent.enable_wine,
        .glibc_runtimes_dir = parent.glibc_runtimes_dir,
        .host = parent.host,
        .dep_prefix = parent.fmt("{s}{s}.", .{ parent.dep_prefix, dep_name }),
        .modules = std.StringArrayHashMap(*Module).init(allocator),
        .initialized_deps = parent.initialized_deps,
    };
    try child.top_level_steps.put(allocator, child.install_tls.step.name, &child.install_tls);
    try child.top_level_steps.put(allocator, child.uninstall_tls.step.name, &child.uninstall_tls);
    child.default_step = &child.install_tls.step;
    return child;
}

fn applyArgs(b: *Build, args: anytype) !void {
    inline for (@typeInfo(@TypeOf(args)).Struct.fields) |field| {
        const v = @field(args, field.name);
        const T = @TypeOf(v);
        switch (T) {
            CrossTarget => {
                try b.user_input_options.put(field.name, .{
                    .name = field.name,
                    .value = .{ .scalar = try v.zigTriple(b.allocator) },
                    .used = false,
                });
                try b.user_input_options.put("cpu", .{
                    .name = "cpu",
                    .value = .{ .scalar = try serializeCpu(b.allocator, v.getCpu()) },
                    .used = false,
                });
            },
            []const u8 => {
                try b.user_input_options.put(field.name, .{
                    .name = field.name,
                    .value = .{ .scalar = v },
                    .used = false,
                });
            },
            else => switch (@typeInfo(T)) {
                .Bool => {
                    try b.user_input_options.put(field.name, .{
                        .name = field.name,
                        .value = .{ .scalar = if (v) "true" else "false" },
                        .used = false,
                    });
                },
                .Enum, .EnumLiteral => {
                    try b.user_input_options.put(field.name, .{
                        .name = field.name,
                        .value = .{ .scalar = @tagName(v) },
                        .used = false,
                    });
                },
                .Int => {
                    try b.user_input_options.put(field.name, .{
                        .name = field.name,
                        .value = .{ .scalar = try std.fmt.allocPrint(b.allocator, "{d}", .{v}) },
                        .used = false,
                    });
                },
                else => @compileError("option '" ++ field.name ++ "' has unsupported type: " ++ @typeName(T)),
            },
        }
    }

    // Create an installation directory local to this package. This will be used when
    // dependant packages require a standard prefix, such as include directories for C headers.
    var hash = b.cache.hash;
    // Random bytes to make unique. Refresh this with new random bytes when
    // implementation is modified in a non-backwards-compatible way.
    hash.add(@as(u32, 0xd8cb0055));
    hash.addBytes(b.dep_prefix);
    // TODO additionally update the hash with `args`.
    const digest = hash.final();
    const install_prefix = try b.cache_root.join(b.allocator, &.{ "i", &digest });
    b.resolveInstallPrefix(install_prefix, .{});
}

pub fn destroy(b: *Build) void {
    b.env_map.deinit();
    b.top_level_steps.deinit(b.allocator);
    b.allocator.destroy(b);
}

/// This function is intended to be called by lib/build_runner.zig, not a build.zig file.
pub fn resolveInstallPrefix(self: *Build, install_prefix: ?[]const u8, dir_list: DirList) void {
    if (self.dest_dir) |dest_dir| {
        self.install_prefix = install_prefix orelse "/usr";
        self.install_path = self.pathJoin(&.{ dest_dir, self.install_prefix });
    } else {
        self.install_prefix = install_prefix orelse
            (self.build_root.join(self.allocator, &.{"zig-out"}) catch @panic("unhandled error"));
        self.install_path = self.install_prefix;
    }

    var lib_list = [_][]const u8{ self.install_path, "lib" };
    var exe_list = [_][]const u8{ self.install_path, "bin" };
    var h_list = [_][]const u8{ self.install_path, "include" };

    if (dir_list.lib_dir) |dir| {
        if (std.fs.path.isAbsolute(dir)) lib_list[0] = self.dest_dir orelse "";
        lib_list[1] = dir;
    }

    if (dir_list.exe_dir) |dir| {
        if (std.fs.path.isAbsolute(dir)) exe_list[0] = self.dest_dir orelse "";
        exe_list[1] = dir;
    }

    if (dir_list.include_dir) |dir| {
        if (std.fs.path.isAbsolute(dir)) h_list[0] = self.dest_dir orelse "";
        h_list[1] = dir;
    }

    self.lib_dir = self.pathJoin(&lib_list);
    self.exe_dir = self.pathJoin(&exe_list);
    self.h_dir = self.pathJoin(&h_list);
}

pub fn addOptions(self: *Build) *Step.Options {
    return Step.Options.create(self);
}

pub const ExecutableOptions = struct {
    name: []const u8,
    root_source_file: ?LazyPath = null,
    version: ?std.SemanticVersion = null,
    target: CrossTarget = .{},
    optimize: std.builtin.Mode = .Debug,
    linkage: ?Step.Compile.Linkage = null,
    max_rss: usize = 0,
    link_libc: ?bool = null,
    single_threaded: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    zig_lib_dir: ?LazyPath = null,
    main_pkg_path: ?LazyPath = null,
};

pub fn addExecutable(b: *Build, options: ExecutableOptions) *Step.Compile {
    return Step.Compile.create(b, .{
        .name = options.name,
        .root_source_file = options.root_source_file,
        .version = options.version,
        .target = options.target,
        .optimize = options.optimize,
        .kind = .exe,
        .linkage = options.linkage,
        .max_rss = options.max_rss,
        .link_libc = options.link_libc,
        .single_threaded = options.single_threaded,
        .use_llvm = options.use_llvm,
        .use_lld = options.use_lld,
        .zig_lib_dir = options.zig_lib_dir orelse b.zig_lib_dir,
        .main_pkg_path = options.main_pkg_path,
    });
}

pub const ObjectOptions = struct {
    name: []const u8,
    root_source_file: ?LazyPath = null,
    target: CrossTarget,
    optimize: std.builtin.Mode,
    max_rss: usize = 0,
    link_libc: ?bool = null,
    single_threaded: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    zig_lib_dir: ?LazyPath = null,
    main_pkg_path: ?LazyPath = null,
};

pub fn addObject(b: *Build, options: ObjectOptions) *Step.Compile {
    return Step.Compile.create(b, .{
        .name = options.name,
        .root_source_file = options.root_source_file,
        .target = options.target,
        .optimize = options.optimize,
        .kind = .obj,
        .max_rss = options.max_rss,
        .link_libc = options.link_libc,
        .single_threaded = options.single_threaded,
        .use_llvm = options.use_llvm,
        .use_lld = options.use_lld,
        .zig_lib_dir = options.zig_lib_dir orelse b.zig_lib_dir,
        .main_pkg_path = options.main_pkg_path,
    });
}

pub const SharedLibraryOptions = struct {
    name: []const u8,
    root_source_file: ?LazyPath = null,
    version: ?std.SemanticVersion = null,
    target: CrossTarget,
    optimize: std.builtin.Mode,
    max_rss: usize = 0,
    link_libc: ?bool = null,
    single_threaded: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    zig_lib_dir: ?LazyPath = null,
    main_pkg_path: ?LazyPath = null,
};

pub fn addSharedLibrary(b: *Build, options: SharedLibraryOptions) *Step.Compile {
    return Step.Compile.create(b, .{
        .name = options.name,
        .root_source_file = options.root_source_file,
        .kind = .lib,
        .linkage = .dynamic,
        .version = options.version,
        .target = options.target,
        .optimize = options.optimize,
        .max_rss = options.max_rss,
        .link_libc = options.link_libc,
        .single_threaded = options.single_threaded,
        .use_llvm = options.use_llvm,
        .use_lld = options.use_lld,
        .zig_lib_dir = options.zig_lib_dir orelse b.zig_lib_dir,
        .main_pkg_path = options.main_pkg_path,
    });
}

pub const StaticLibraryOptions = struct {
    name: []const u8,
    root_source_file: ?LazyPath = null,
    target: CrossTarget,
    optimize: std.builtin.Mode,
    version: ?std.SemanticVersion = null,
    max_rss: usize = 0,
    link_libc: ?bool = null,
    single_threaded: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    zig_lib_dir: ?LazyPath = null,
    main_pkg_path: ?LazyPath = null,
};

pub fn addStaticLibrary(b: *Build, options: StaticLibraryOptions) *Step.Compile {
    return Step.Compile.create(b, .{
        .name = options.name,
        .root_source_file = options.root_source_file,
        .kind = .lib,
        .linkage = .static,
        .version = options.version,
        .target = options.target,
        .optimize = options.optimize,
        .max_rss = options.max_rss,
        .link_libc = options.link_libc,
        .single_threaded = options.single_threaded,
        .use_llvm = options.use_llvm,
        .use_lld = options.use_lld,
        .zig_lib_dir = options.zig_lib_dir orelse b.zig_lib_dir,
        .main_pkg_path = options.main_pkg_path,
    });
}

pub const TestOptions = struct {
    name: []const u8 = "test",
    root_source_file: LazyPath,
    target: CrossTarget = .{},
    optimize: std.builtin.Mode = .Debug,
    version: ?std.SemanticVersion = null,
    max_rss: usize = 0,
    filter: ?[]const u8 = null,
    test_runner: ?[]const u8 = null,
    link_libc: ?bool = null,
    single_threaded: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    zig_lib_dir: ?LazyPath = null,
    main_pkg_path: ?LazyPath = null,
};

pub fn addTest(b: *Build, options: TestOptions) *Step.Compile {
    return Step.Compile.create(b, .{
        .name = options.name,
        .kind = .@"test",
        .root_source_file = options.root_source_file,
        .target = options.target,
        .optimize = options.optimize,
        .max_rss = options.max_rss,
        .filter = options.filter,
        .test_runner = options.test_runner,
        .link_libc = options.link_libc,
        .single_threaded = options.single_threaded,
        .use_llvm = options.use_llvm,
        .use_lld = options.use_lld,
        .zig_lib_dir = options.zig_lib_dir orelse b.zig_lib_dir,
        .main_pkg_path = options.main_pkg_path,
    });
}

pub const AssemblyOptions = struct {
    name: []const u8,
    source_file: LazyPath,
    target: CrossTarget,
    optimize: std.builtin.Mode,
    max_rss: usize = 0,
    zig_lib_dir: ?LazyPath = null,
};

pub fn addAssembly(b: *Build, options: AssemblyOptions) *Step.Compile {
    const obj_step = Step.Compile.create(b, .{
        .name = options.name,
        .kind = .obj,
        .root_source_file = null,
        .target = options.target,
        .optimize = options.optimize,
        .max_rss = options.max_rss,
        .zig_lib_dir = options.zig_lib_dir orelse b.zig_lib_dir,
    });
    obj_step.addAssemblyLazyPath(options.source_file.dupe(b));
    return obj_step;
}

/// This function creates a module and adds it to the package's module set, making
/// it available to other packages which depend on this one.
/// `createModule` can be used instead to create a private module.
pub fn addModule(b: *Build, name: []const u8, options: CreateModuleOptions) *Module {
    const module = b.createModule(options);
    b.modules.put(b.dupe(name), module) catch @panic("OOM");
    return module;
}

pub const ModuleDependency = struct {
    name: []const u8,
    module: *Module,
};

pub const CreateModuleOptions = struct {
    source_file: LazyPath,
    dependencies: []const ModuleDependency = &.{},
};

/// This function creates a private module, to be used by the current package,
/// but not exposed to other packages depending on this one.
/// `addModule` can be used instead to create a public module.
pub fn createModule(b: *Build, options: CreateModuleOptions) *Module {
    const module = b.allocator.create(Module) catch @panic("OOM");
    module.* = .{
        .builder = b,
        .source_file = options.source_file,
        .dependencies = moduleDependenciesToArrayHashMap(b.allocator, options.dependencies),
    };
    return module;
}

fn moduleDependenciesToArrayHashMap(arena: Allocator, deps: []const ModuleDependency) std.StringArrayHashMap(*Module) {
    var result = std.StringArrayHashMap(*Module).init(arena);
    for (deps) |dep| {
        result.put(dep.name, dep.module) catch @panic("OOM");
    }
    return result;
}

/// Initializes a `Step.Run` with argv, which must at least have the path to the
/// executable. More command line arguments can be added with `addArg`,
/// `addArgs`, and `addArtifactArg`.
/// Be careful using this function, as it introduces a system dependency.
/// To run an executable built with zig build, see `Step.Compile.run`.
pub fn addSystemCommand(self: *Build, argv: []const []const u8) *Step.Run {
    assert(argv.len >= 1);
    const run_step = Step.Run.create(self, self.fmt("run {s}", .{argv[0]}));
    run_step.addArgs(argv);
    return run_step;
}

/// Creates a `Step.Run` with an executable built with `addExecutable`.
/// Add command line arguments with methods of `Step.Run`.
pub fn addRunArtifact(b: *Build, exe: *Step.Compile) *Step.Run {
    // It doesn't have to be native. We catch that if you actually try to run it.
    // Consider that this is declarative; the run step may not be run unless a user
    // option is supplied.
    const run_step = Step.Run.create(b, b.fmt("run {s}", .{exe.name}));
    run_step.addArtifactArg(exe);

    if (exe.kind == .@"test") {
        run_step.enableTestRunnerMode();
    }

    if (exe.vcpkg_bin_path) |path| {
        run_step.addPathDir(path);
    }

    return run_step;
}

/// Using the `values` provided, produces a C header file, possibly based on a
/// template input file (e.g. config.h.in).
/// When an input template file is provided, this function will fail the build
/// when an option not found in the input file is provided in `values`, and
/// when an option found in the input file is missing from `values`.
pub fn addConfigHeader(
    b: *Build,
    options: Step.ConfigHeader.Options,
    values: anytype,
) *Step.ConfigHeader {
    var options_copy = options;
    if (options_copy.first_ret_addr == null)
        options_copy.first_ret_addr = @returnAddress();

    const config_header_step = Step.ConfigHeader.create(b, options_copy);
    config_header_step.addValues(values);
    return config_header_step;
}

/// Allocator.dupe without the need to handle out of memory.
pub fn dupe(self: *Build, bytes: []const u8) []u8 {
    return self.allocator.dupe(u8, bytes) catch @panic("OOM");
}

/// Duplicates an array of strings without the need to handle out of memory.
pub fn dupeStrings(self: *Build, strings: []const []const u8) [][]u8 {
    const array = self.allocator.alloc([]u8, strings.len) catch @panic("OOM");
    for (strings, 0..) |s, i| {
        array[i] = self.dupe(s);
    }
    return array;
}

/// Duplicates a path and converts all slashes to the OS's canonical path separator.
pub fn dupePath(self: *Build, bytes: []const u8) []u8 {
    const the_copy = self.dupe(bytes);
    for (the_copy) |*byte| {
        switch (byte.*) {
            '/', '\\' => byte.* = fs.path.sep,
            else => {},
        }
    }
    return the_copy;
}

pub fn addWriteFile(self: *Build, file_path: []const u8, data: []const u8) *Step.WriteFile {
    const write_file_step = self.addWriteFiles();
    _ = write_file_step.add(file_path, data);
    return write_file_step;
}

pub fn addWriteFiles(b: *Build) *Step.WriteFile {
    return Step.WriteFile.create(b);
}

pub fn addRemoveDirTree(self: *Build, dir_path: []const u8) *Step.RemoveDir {
    const remove_dir_step = self.allocator.create(Step.RemoveDir) catch @panic("OOM");
    remove_dir_step.* = Step.RemoveDir.init(self, dir_path);
    return remove_dir_step;
}

pub fn addFmt(b: *Build, options: Step.Fmt.Options) *Step.Fmt {
    return Step.Fmt.create(b, options);
}

pub fn addTranslateC(self: *Build, options: Step.TranslateC.Options) *Step.TranslateC {
    return Step.TranslateC.create(self, options);
}

pub fn getInstallStep(self: *Build) *Step {
    return &self.install_tls.step;
}

pub fn getUninstallStep(self: *Build) *Step {
    return &self.uninstall_tls.step;
}

fn makeUninstall(uninstall_step: *Step, prog_node: *std.Progress.Node) anyerror!void {
    _ = prog_node;
    const uninstall_tls = @fieldParentPtr(TopLevelStep, "step", uninstall_step);
    const self = @fieldParentPtr(Build, "uninstall_tls", uninstall_tls);

    for (self.installed_files.items) |installed_file| {
        const full_path = self.getInstallPath(installed_file.dir, installed_file.path);
        if (self.verbose) {
            log.info("rm {s}", .{full_path});
        }
        fs.cwd().deleteTree(full_path) catch {};
    }

    // TODO remove empty directories
}

pub fn option(self: *Build, comptime T: type, name_raw: []const u8, description_raw: []const u8) ?T {
    const name = self.dupe(name_raw);
    const description = self.dupe(description_raw);
    const type_id = comptime typeToEnum(T);
    const enum_options = if (type_id == .@"enum") blk: {
        const fields = comptime std.meta.fields(T);
        var options = ArrayList([]const u8).initCapacity(self.allocator, fields.len) catch @panic("OOM");

        inline for (fields) |field| {
            options.appendAssumeCapacity(field.name);
        }

        break :blk options.toOwnedSlice() catch @panic("OOM");
    } else null;
    const available_option = AvailableOption{
        .name = name,
        .type_id = type_id,
        .description = description,
        .enum_options = enum_options,
    };
    if ((self.available_options_map.fetchPut(name, available_option) catch @panic("OOM")) != null) {
        panic("Option '{s}' declared twice", .{name});
    }
    self.available_options_list.append(available_option) catch @panic("OOM");

    const option_ptr = self.user_input_options.getPtr(name) orelse return null;
    option_ptr.used = true;
    switch (type_id) {
        .bool => switch (option_ptr.value) {
            .flag => return true,
            .scalar => |s| {
                if (mem.eql(u8, s, "true")) {
                    return true;
                } else if (mem.eql(u8, s, "false")) {
                    return false;
                } else {
                    log.err("Expected -D{s} to be a boolean, but received '{s}'", .{ name, s });
                    self.markInvalidUserInput();
                    return null;
                }
            },
            .list, .map => {
                log.err("Expected -D{s} to be a boolean, but received a {s}.", .{
                    name, @tagName(option_ptr.value),
                });
                self.markInvalidUserInput();
                return null;
            },
        },
        .int => switch (option_ptr.value) {
            .flag, .list, .map => {
                log.err("Expected -D{s} to be an integer, but received a {s}.", .{
                    name, @tagName(option_ptr.value),
                });
                self.markInvalidUserInput();
                return null;
            },
            .scalar => |s| {
                const n = std.fmt.parseInt(T, s, 10) catch |err| switch (err) {
                    error.Overflow => {
                        log.err("-D{s} value {s} cannot fit into type {s}.", .{ name, s, @typeName(T) });
                        self.markInvalidUserInput();
                        return null;
                    },
                    else => {
                        log.err("Expected -D{s} to be an integer of type {s}.", .{ name, @typeName(T) });
                        self.markInvalidUserInput();
                        return null;
                    },
                };
                return n;
            },
        },
        .float => switch (option_ptr.value) {
            .flag, .map, .list => {
                log.err("Expected -D{s} to be a float, but received a {s}.", .{
                    name, @tagName(option_ptr.value),
                });
                self.markInvalidUserInput();
                return null;
            },
            .scalar => |s| {
                const n = std.fmt.parseFloat(T, s) catch {
                    log.err("Expected -D{s} to be a float of type {s}.", .{ name, @typeName(T) });
                    self.markInvalidUserInput();
                    return null;
                };
                return n;
            },
        },
        .@"enum" => switch (option_ptr.value) {
            .flag, .map, .list => {
                log.err("Expected -D{s} to be an enum, but received a {s}.", .{
                    name, @tagName(option_ptr.value),
                });
                self.markInvalidUserInput();
                return null;
            },
            .scalar => |s| {
                if (std.meta.stringToEnum(T, s)) |enum_lit| {
                    return enum_lit;
                } else {
                    log.err("Expected -D{s} to be of type {s}.", .{ name, @typeName(T) });
                    self.markInvalidUserInput();
                    return null;
                }
            },
        },
        .string => switch (option_ptr.value) {
            .flag, .list, .map => {
                log.err("Expected -D{s} to be a string, but received a {s}.", .{
                    name, @tagName(option_ptr.value),
                });
                self.markInvalidUserInput();
                return null;
            },
            .scalar => |s| return s,
        },
        .build_id => switch (option_ptr.value) {
            .flag, .map, .list => {
                log.err("Expected -D{s} to be an enum, but received a {s}.", .{
                    name, @tagName(option_ptr.value),
                });
                self.markInvalidUserInput();
                return null;
            },
            .scalar => |s| {
                if (Step.Compile.BuildId.parse(s)) |build_id| {
                    return build_id;
                } else |err| {
                    log.err("unable to parse option '-D{s}': {s}", .{ name, @errorName(err) });
                    self.markInvalidUserInput();
                    return null;
                }
            },
        },
        .list => switch (option_ptr.value) {
            .flag, .map => {
                log.err("Expected -D{s} to be a list, but received a {s}.", .{
                    name, @tagName(option_ptr.value),
                });
                self.markInvalidUserInput();
                return null;
            },
            .scalar => |s| {
                return self.allocator.dupe([]const u8, &[_][]const u8{s}) catch @panic("OOM");
            },
            .list => |lst| return lst.items,
        },
    }
}

pub fn step(self: *Build, name: []const u8, description: []const u8) *Step {
    const step_info = self.allocator.create(TopLevelStep) catch @panic("OOM");
    step_info.* = .{
        .step = Step.init(.{
            .id = .top_level,
            .name = name,
            .owner = self,
        }),
        .description = self.dupe(description),
    };
    const gop = self.top_level_steps.getOrPut(self.allocator, name) catch @panic("OOM");
    if (gop.found_existing) std.debug.panic("A top-level step with name \"{s}\" already exists", .{name});

    gop.key_ptr.* = step_info.step.name;
    gop.value_ptr.* = step_info;

    return &step_info.step;
}

pub const StandardOptimizeOptionOptions = struct {
    preferred_optimize_mode: ?std.builtin.Mode = null,
};

pub fn standardOptimizeOption(self: *Build, options: StandardOptimizeOptionOptions) std.builtin.Mode {
    if (options.preferred_optimize_mode) |mode| {
        if (self.option(bool, "release", "optimize for end users") orelse false) {
            return mode;
        } else {
            return .Debug;
        }
    } else {
        return self.option(
            std.builtin.Mode,
            "optimize",
            "Prioritize performance, safety, or binary size (-O flag)",
        ) orelse .Debug;
    }
}

pub const StandardTargetOptionsArgs = struct {
    whitelist: ?[]const CrossTarget = null,

    default_target: CrossTarget = CrossTarget{},
};

/// Exposes standard `zig build` options for choosing a target.
pub fn standardTargetOptions(self: *Build, args: StandardTargetOptionsArgs) CrossTarget {
    const maybe_triple = self.option(
        []const u8,
        "target",
        "The CPU architecture, OS, and ABI to build for",
    );
    const mcpu = self.option([]const u8, "cpu", "Target CPU features to add or subtract");

    if (maybe_triple == null and mcpu == null) {
        return args.default_target;
    }

    const triple = maybe_triple orelse "native";

    var diags: CrossTarget.ParseOptions.Diagnostics = .{};
    const selected_target = CrossTarget.parse(.{
        .arch_os_abi = triple,
        .cpu_features = mcpu,
        .diagnostics = &diags,
    }) catch |err| switch (err) {
        error.UnknownCpuModel => {
            log.err("Unknown CPU: '{s}'\nAvailable CPUs for architecture '{s}':", .{
                diags.cpu_name.?,
                @tagName(diags.arch.?),
            });
            for (diags.arch.?.allCpuModels()) |cpu| {
                log.err(" {s}", .{cpu.name});
            }
            self.markInvalidUserInput();
            return args.default_target;
        },
        error.UnknownCpuFeature => {
            log.err(
                \\Unknown CPU feature: '{s}'
                \\Available CPU features for architecture '{s}':
                \\
            , .{
                diags.unknown_feature_name.?,
                @tagName(diags.arch.?),
            });
            for (diags.arch.?.allFeaturesList()) |feature| {
                log.err(" {s}: {s}", .{ feature.name, feature.description });
            }
            self.markInvalidUserInput();
            return args.default_target;
        },
        error.UnknownOperatingSystem => {
            log.err(
                \\Unknown OS: '{s}'
                \\Available operating systems:
                \\
            , .{diags.os_name.?});
            inline for (std.meta.fields(std.Target.Os.Tag)) |field| {
                log.err(" {s}", .{field.name});
            }
            self.markInvalidUserInput();
            return args.default_target;
        },
        else => |e| {
            log.err("Unable to parse target '{s}': {s}\n", .{ triple, @errorName(e) });
            self.markInvalidUserInput();
            return args.default_target;
        },
    };

    const selected_canonicalized_triple = selected_target.zigTriple(self.allocator) catch @panic("OOM");

    if (args.whitelist) |list| whitelist_check: {
        // Make sure it's a match of one of the list.
        var mismatch_triple = true;
        var mismatch_cpu_features = true;
        var whitelist_item = CrossTarget{};
        for (list) |t| {
            mismatch_cpu_features = true;
            mismatch_triple = true;

            const t_triple = t.zigTriple(self.allocator) catch @panic("OOM");
            if (mem.eql(u8, t_triple, selected_canonicalized_triple)) {
                mismatch_triple = false;
                whitelist_item = t;
                if (t.getCpuFeatures().isSuperSetOf(selected_target.getCpuFeatures())) {
                    mismatch_cpu_features = false;
                    break :whitelist_check;
                } else {
                    break;
                }
            }
        }
        if (mismatch_triple) {
            log.err("Chosen target '{s}' does not match one of the supported targets:", .{
                selected_canonicalized_triple,
            });
            for (list) |t| {
                const t_triple = t.zigTriple(self.allocator) catch @panic("OOM");
                log.err(" {s}", .{t_triple});
            }
        } else {
            assert(mismatch_cpu_features);
            const whitelist_cpu = whitelist_item.getCpu();
            const selected_cpu = selected_target.getCpu();
            log.err("Chosen CPU model '{s}' does not match one of the supported targets:", .{
                selected_cpu.model.name,
            });
            log.err("  Supported feature Set: ", .{});
            const all_features = whitelist_cpu.arch.allFeaturesList();
            var populated_cpu_features = whitelist_cpu.model.features;
            populated_cpu_features.populateDependencies(all_features);
            for (all_features, 0..) |feature, i_usize| {
                const i = @as(std.Target.Cpu.Feature.Set.Index, @intCast(i_usize));
                const in_cpu_set = populated_cpu_features.isEnabled(i);
                if (in_cpu_set) {
                    log.err("{s} ", .{feature.name});
                }
            }
            log.err("  Remove: ", .{});
            for (all_features, 0..) |feature, i_usize| {
                const i = @as(std.Target.Cpu.Feature.Set.Index, @intCast(i_usize));
                const in_cpu_set = populated_cpu_features.isEnabled(i);
                const in_actual_set = selected_cpu.features.isEnabled(i);
                if (in_actual_set and !in_cpu_set) {
                    log.err("{s} ", .{feature.name});
                }
            }
        }
        self.markInvalidUserInput();
        return args.default_target;
    }

    return selected_target;
}

pub fn addUserInputOption(self: *Build, name_raw: []const u8, value_raw: []const u8) !bool {
    const name = self.dupe(name_raw);
    const value = self.dupe(value_raw);
    const gop = try self.user_input_options.getOrPut(name);
    if (!gop.found_existing) {
        gop.value_ptr.* = UserInputOption{
            .name = name,
            .value = .{ .scalar = value },
            .used = false,
        };
        return false;
    }

    // option already exists
    switch (gop.value_ptr.value) {
        .scalar => |s| {
            // turn it into a list
            var list = ArrayList([]const u8).init(self.allocator);
            try list.append(s);
            try list.append(value);
            try self.user_input_options.put(name, .{
                .name = name,
                .value = .{ .list = list },
                .used = false,
            });
        },
        .list => |*list| {
            // append to the list
            try list.append(value);
            try self.user_input_options.put(name, .{
                .name = name,
                .value = .{ .list = list.* },
                .used = false,
            });
        },
        .flag => {
            log.warn("Option '-D{s}={s}' conflicts with flag '-D{s}'.", .{ name, value, name });
            return true;
        },
        .map => |*map| {
            _ = map;
            log.warn("TODO maps as command line arguments is not implemented yet.", .{});
            return true;
        },
    }
    return false;
}

pub fn addUserInputFlag(self: *Build, name_raw: []const u8) !bool {
    const name = self.dupe(name_raw);
    const gop = try self.user_input_options.getOrPut(name);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{
            .name = name,
            .value = .{ .flag = {} },
            .used = false,
        };
        return false;
    }

    // option already exists
    switch (gop.value_ptr.value) {
        .scalar => |s| {
            log.err("Flag '-D{s}' conflicts with option '-D{s}={s}'.", .{ name, name, s });
            return true;
        },
        .list, .map => {
            log.err("Flag '-D{s}' conflicts with multiple options of the same name.", .{name});
            return true;
        },
        .flag => {},
    }
    return false;
}

fn typeToEnum(comptime T: type) TypeId {
    return switch (T) {
        Step.Compile.BuildId => .build_id,
        else => return switch (@typeInfo(T)) {
            .Int => .int,
            .Float => .float,
            .Bool => .bool,
            .Enum => .@"enum",
            else => switch (T) {
                []const u8 => .string,
                []const []const u8 => .list,
                else => @compileError("Unsupported type: " ++ @typeName(T)),
            },
        },
    };
}

fn markInvalidUserInput(self: *Build) void {
    self.invalid_user_input = true;
}

pub fn validateUserInputDidItFail(self: *Build) bool {
    // make sure all args are used
    var it = self.user_input_options.iterator();
    while (it.next()) |entry| {
        if (!entry.value_ptr.used) {
            log.err("Invalid option: -D{s}", .{entry.key_ptr.*});
            self.markInvalidUserInput();
        }
    }

    return self.invalid_user_input;
}

fn allocPrintCmd(ally: Allocator, opt_cwd: ?[]const u8, argv: []const []const u8) ![]u8 {
    var buf = ArrayList(u8).init(ally);
    if (opt_cwd) |cwd| try buf.writer().print("cd {s} && ", .{cwd});
    for (argv) |arg| {
        try buf.writer().print("{s} ", .{arg});
    }
    return buf.toOwnedSlice();
}

fn printCmd(ally: Allocator, cwd: ?[]const u8, argv: []const []const u8) void {
    const text = allocPrintCmd(ally, cwd, argv) catch @panic("OOM");
    std.debug.print("{s}\n", .{text});
}

/// This creates the install step and adds it to the dependencies of the
/// top-level install step, using all the default options.
/// See `addInstallArtifact` for a more flexible function.
pub fn installArtifact(self: *Build, artifact: *Step.Compile) void {
    self.getInstallStep().dependOn(&self.addInstallArtifact(artifact, .{}).step);
}

/// This merely creates the step; it does not add it to the dependencies of the
/// top-level install step.
pub fn addInstallArtifact(
    self: *Build,
    artifact: *Step.Compile,
    options: Step.InstallArtifact.Options,
) *Step.InstallArtifact {
    return Step.InstallArtifact.create(self, artifact, options);
}

///`dest_rel_path` is relative to prefix path
pub fn installFile(self: *Build, src_path: []const u8, dest_rel_path: []const u8) void {
    self.getInstallStep().dependOn(&self.addInstallFileWithDir(.{ .path = src_path }, .prefix, dest_rel_path).step);
}

pub fn installDirectory(self: *Build, options: InstallDirectoryOptions) void {
    self.getInstallStep().dependOn(&self.addInstallDirectory(options).step);
}

///`dest_rel_path` is relative to bin path
pub fn installBinFile(self: *Build, src_path: []const u8, dest_rel_path: []const u8) void {
    self.getInstallStep().dependOn(&self.addInstallFileWithDir(.{ .path = src_path }, .bin, dest_rel_path).step);
}

///`dest_rel_path` is relative to lib path
pub fn installLibFile(self: *Build, src_path: []const u8, dest_rel_path: []const u8) void {
    self.getInstallStep().dependOn(&self.addInstallFileWithDir(.{ .path = src_path }, .lib, dest_rel_path).step);
}

pub fn addObjCopy(b: *Build, source: LazyPath, options: Step.ObjCopy.Options) *Step.ObjCopy {
    return Step.ObjCopy.create(b, source, options);
}

///`dest_rel_path` is relative to install prefix path
pub fn addInstallFile(self: *Build, source: LazyPath, dest_rel_path: []const u8) *Step.InstallFile {
    return self.addInstallFileWithDir(source.dupe(self), .prefix, dest_rel_path);
}

///`dest_rel_path` is relative to bin path
pub fn addInstallBinFile(self: *Build, source: LazyPath, dest_rel_path: []const u8) *Step.InstallFile {
    return self.addInstallFileWithDir(source.dupe(self), .bin, dest_rel_path);
}

///`dest_rel_path` is relative to lib path
pub fn addInstallLibFile(self: *Build, source: LazyPath, dest_rel_path: []const u8) *Step.InstallFile {
    return self.addInstallFileWithDir(source.dupe(self), .lib, dest_rel_path);
}

pub fn addInstallHeaderFile(b: *Build, src_path: []const u8, dest_rel_path: []const u8) *Step.InstallFile {
    return b.addInstallFileWithDir(.{ .path = src_path }, .header, dest_rel_path);
}

pub fn addInstallFileWithDir(
    self: *Build,
    source: LazyPath,
    install_dir: InstallDir,
    dest_rel_path: []const u8,
) *Step.InstallFile {
    return Step.InstallFile.create(self, source.dupe(self), install_dir, dest_rel_path);
}

pub fn addInstallDirectory(self: *Build, options: InstallDirectoryOptions) *Step.InstallDir {
    return Step.InstallDir.create(self, options);
}

pub fn addCheckFile(
    b: *Build,
    file_source: LazyPath,
    options: Step.CheckFile.Options,
) *Step.CheckFile {
    return Step.CheckFile.create(b, file_source, options);
}

/// deprecated: https://github.com/ziglang/zig/issues/14943
pub fn pushInstalledFile(self: *Build, dir: InstallDir, dest_rel_path: []const u8) void {
    const file = InstalledFile{
        .dir = dir,
        .path = dest_rel_path,
    };
    self.installed_files.append(file.dupe(self)) catch @panic("OOM");
}

pub fn truncateFile(self: *Build, dest_path: []const u8) !void {
    if (self.verbose) {
        log.info("truncate {s}", .{dest_path});
    }
    const cwd = fs.cwd();
    var src_file = cwd.createFile(dest_path, .{}) catch |err| switch (err) {
        error.FileNotFound => blk: {
            if (fs.path.dirname(dest_path)) |dirname| {
                try cwd.makePath(dirname);
            }
            break :blk try cwd.createFile(dest_path, .{});
        },
        else => |e| return e,
    };
    src_file.close();
}

pub fn pathFromRoot(b: *Build, p: []const u8) []u8 {
    return fs.path.resolve(b.allocator, &.{ b.build_root.path orelse ".", p }) catch @panic("OOM");
}

fn pathFromCwd(b: *Build, p: []const u8) []u8 {
    const cwd = process.getCwdAlloc(b.allocator) catch @panic("OOM");
    return fs.path.resolve(b.allocator, &.{ cwd, p }) catch @panic("OOM");
}

pub fn pathJoin(self: *Build, paths: []const []const u8) []u8 {
    return fs.path.join(self.allocator, paths) catch @panic("OOM");
}

pub fn fmt(self: *Build, comptime format: []const u8, args: anytype) []u8 {
    return fmt_lib.allocPrint(self.allocator, format, args) catch @panic("OOM");
}

pub fn findProgram(self: *Build, names: []const []const u8, paths: []const []const u8) ![]const u8 {
    // TODO report error for ambiguous situations
    const exe_extension = @as(CrossTarget, .{}).exeFileExt();
    for (self.search_prefixes.items) |search_prefix| {
        for (names) |name| {
            if (fs.path.isAbsolute(name)) {
                return name;
            }
            const full_path = self.pathJoin(&.{
                search_prefix,
                "bin",
                self.fmt("{s}{s}", .{ name, exe_extension }),
            });
            return fs.realpathAlloc(self.allocator, full_path) catch continue;
        }
    }
    if (self.env_map.get("PATH")) |PATH| {
        for (names) |name| {
            if (fs.path.isAbsolute(name)) {
                return name;
            }
            var it = mem.tokenizeScalar(u8, PATH, fs.path.delimiter);
            while (it.next()) |path| {
                const full_path = self.pathJoin(&.{
                    path,
                    self.fmt("{s}{s}", .{ name, exe_extension }),
                });
                return fs.realpathAlloc(self.allocator, full_path) catch continue;
            }
        }
    }
    for (names) |name| {
        if (fs.path.isAbsolute(name)) {
            return name;
        }
        for (paths) |path| {
            const full_path = self.pathJoin(&.{
                path,
                self.fmt("{s}{s}", .{ name, exe_extension }),
            });
            return fs.realpathAlloc(self.allocator, full_path) catch continue;
        }
    }
    return error.FileNotFound;
}

pub fn execAllowFail(
    self: *Build,
    argv: []const []const u8,
    out_code: *u8,
    stderr_behavior: std.ChildProcess.StdIo,
) ExecError![]u8 {
    assert(argv.len != 0);

    if (!process.can_spawn)
        return error.ExecNotSupported;

    const max_output_size = 400 * 1024;
    var child = std.ChildProcess.init(argv, self.allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = stderr_behavior;
    child.env_map = self.env_map;

    try child.spawn();

    const stdout = child.stdout.?.reader().readAllAlloc(self.allocator, max_output_size) catch {
        return error.ReadFailure;
    };
    errdefer self.allocator.free(stdout);

    const term = try child.wait();
    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                out_code.* = @as(u8, @truncate(code));
                return error.ExitCodeFailure;
            }
            return stdout;
        },
        .Signal, .Stopped, .Unknown => |code| {
            out_code.* = @as(u8, @truncate(code));
            return error.ProcessTerminated;
        },
    }
}

/// This is a helper function to be called from build.zig scripts, *not* from
/// inside step make() functions. If any errors occur, it fails the build with
/// a helpful message.
pub fn exec(b: *Build, argv: []const []const u8) []u8 {
    if (!process.can_spawn) {
        std.debug.print("unable to spawn the following command: cannot spawn child process\n{s}\n", .{
            try allocPrintCmd(b.allocator, null, argv),
        });
        process.exit(1);
    }

    var code: u8 = undefined;
    return b.execAllowFail(argv, &code, .Inherit) catch |err| {
        const printed_cmd = allocPrintCmd(b.allocator, null, argv) catch @panic("OOM");
        std.debug.print("unable to spawn the following command: {s}\n{s}\n", .{
            @errorName(err), printed_cmd,
        });
        process.exit(1);
    };
}

pub fn addSearchPrefix(self: *Build, search_prefix: []const u8) void {
    self.search_prefixes.append(self.dupePath(search_prefix)) catch @panic("OOM");
}

pub fn getInstallPath(self: *Build, dir: InstallDir, dest_rel_path: []const u8) []const u8 {
    assert(!fs.path.isAbsolute(dest_rel_path)); // Install paths must be relative to the prefix
    const base_dir = switch (dir) {
        .prefix => self.install_path,
        .bin => self.exe_dir,
        .lib => self.lib_dir,
        .header => self.h_dir,
        .custom => |path| self.pathJoin(&.{ self.install_path, path }),
    };
    return fs.path.resolve(
        self.allocator,
        &[_][]const u8{ base_dir, dest_rel_path },
    ) catch @panic("OOM");
}

pub const Dependency = struct {
    builder: *Build,

    pub fn artifact(d: *Dependency, name: []const u8) *Step.Compile {
        var found: ?*Step.Compile = null;
        for (d.builder.install_tls.step.dependencies.items) |dep_step| {
            const inst = dep_step.cast(Step.InstallArtifact) orelse continue;
            if (mem.eql(u8, inst.artifact.name, name)) {
                if (found != null) panic("artifact name '{s}' is ambiguous", .{name});
                found = inst.artifact;
            }
        }
        return found orelse {
            for (d.builder.install_tls.step.dependencies.items) |dep_step| {
                const inst = dep_step.cast(Step.InstallArtifact) orelse continue;
                log.info("available artifact: '{s}'", .{inst.artifact.name});
            }
            panic("unable to find artifact '{s}'", .{name});
        };
    }

    pub fn module(d: *Dependency, name: []const u8) *Module {
        return d.builder.modules.get(name) orelse {
            panic("unable to find module '{s}'", .{name});
        };
    }
};

pub fn dependency(b: *Build, name: []const u8, args: anytype) *Dependency {
    const build_runner = @import("root");
    const deps = build_runner.dependencies;

    inline for (@typeInfo(deps.imports).Struct.decls) |decl| {
        if (mem.startsWith(u8, decl.name, b.dep_prefix) and
            mem.endsWith(u8, decl.name, name) and
            decl.name.len == b.dep_prefix.len + name.len)
        {
            const build_zig = @field(deps.imports, decl.name);
            const build_root = @field(deps.build_root, decl.name);
            return dependencyInner(b, name, build_root, build_zig, args);
        }
    }

    const full_path = b.pathFromRoot("build.zig.zon");
    std.debug.print("no dependency named '{s}' in '{s}'. All packages used in build.zig must be declared in this file.\n", .{ name, full_path });
    process.exit(1);
}

pub fn anonymousDependency(
    b: *Build,
    /// The path to the directory containing the dependency's build.zig file,
    /// relative to the current package's build.zig.
    relative_build_root: []const u8,
    /// A direct `@import` of the build.zig of the dependency.
    comptime build_zig: type,
    args: anytype,
) *Dependency {
    const arena = b.allocator;
    const build_root = b.build_root.join(arena, &.{relative_build_root}) catch @panic("OOM");
    const name = arena.dupe(u8, relative_build_root) catch @panic("OOM");
    for (name) |*byte| switch (byte.*) {
        '/', '\\' => byte.* = '.',
        else => continue,
    };
    return dependencyInner(b, name, build_root, build_zig, args);
}

pub fn dependencyInner(
    b: *Build,
    name: []const u8,
    build_root_string: []const u8,
    comptime build_zig: type,
    args: anytype,
) *Dependency {
    if (b.initialized_deps.get(build_root_string)) |dep| {
        // TODO: check args are the same
        return dep;
    }

    const build_root: std.Build.Cache.Directory = .{
        .path = build_root_string,
        .handle = std.fs.cwd().openDir(build_root_string, .{}) catch |err| {
            std.debug.print("unable to open '{s}': {s}\n", .{
                build_root_string, @errorName(err),
            });
            process.exit(1);
        },
    };
    const sub_builder = b.createChild(name, build_root, args) catch @panic("unhandled error");
    sub_builder.runBuild(build_zig) catch @panic("unhandled error");

    if (sub_builder.validateUserInputDidItFail()) {
        std.debug.dumpCurrentStackTrace(@returnAddress());
    }

    const dep = b.allocator.create(Dependency) catch @panic("OOM");
    dep.* = .{ .builder = sub_builder };

    b.initialized_deps.put(build_root_string, dep) catch @panic("OOM");

    return dep;
}

pub fn runBuild(b: *Build, build_zig: anytype) anyerror!void {
    switch (@typeInfo(@typeInfo(@TypeOf(build_zig.build)).Fn.return_type.?)) {
        .Void => build_zig.build(b),
        .ErrorUnion => try build_zig.build(b),
        else => @compileError("expected return type of build to be 'void' or '!void'"),
    }
}

pub const Module = struct {
    builder: *Build,
    /// This could either be a generated file, in which case the module
    /// contains exactly one file, or it could be a path to the root source
    /// file of directory of files which constitute the module.
    source_file: LazyPath,
    dependencies: std.StringArrayHashMap(*Module),
};

/// A file that is generated by a build step.
/// This struct is an interface that is meant to be used with `@fieldParentPtr` to implement the actual path logic.
pub const GeneratedFile = struct {
    /// The step that generates the file
    step: *Step,

    /// The path to the generated file. Must be either absolute or relative to the build root.
    /// This value must be set in the `fn make()` of the `step` and must not be `null` afterwards.
    path: ?[]const u8 = null,

    pub fn getPath(self: GeneratedFile) []const u8 {
        return self.path orelse std.debug.panic(
            "getPath() was called on a GeneratedFile that wasn't built yet. Is there a missing Step dependency on step '{s}'?",
            .{self.step.name},
        );
    }
};

/// A reference to an existing or future path.
pub const LazyPath = union(enum) {
    /// A source file path relative to build root.
    /// This should not be an absolute path, but in an older iteration of the zig build
    /// system API, it was allowed to be absolute. Absolute paths should use `cwd_relative`.
    path: []const u8,

    /// A file that is generated by an interface. Those files usually are
    /// not available until built by a build step.
    generated: *const GeneratedFile,

    /// An absolute path or a path relative to the current working directory of
    /// the build runner process.
    /// This is uncommon but used for system environment paths such as `--zig-lib-dir` which
    /// ignore the file system path of build.zig and instead are relative to the directory from
    /// which `zig build` was invoked.
    /// Use of this tag indicates a dependency on the host system.
    cwd_relative: []const u8,

    /// Returns a new file source that will have a relative path to the build root guaranteed.
    /// Asserts the parameter is not an absolute path.
    pub fn relative(path: []const u8) LazyPath {
        std.debug.assert(!std.fs.path.isAbsolute(path));
        return LazyPath{ .path = path };
    }

    /// Returns a string that can be shown to represent the file source.
    /// Either returns the path or `"generated"`.
    pub fn getDisplayName(self: LazyPath) []const u8 {
        return switch (self) {
            .path, .cwd_relative => self.path,
            .generated => "generated",
        };
    }

    /// Adds dependencies this file source implies to the given step.
    pub fn addStepDependencies(self: LazyPath, other_step: *Step) void {
        switch (self) {
            .path, .cwd_relative => {},
            .generated => |gen| other_step.dependOn(gen.step),
        }
    }

    /// Returns an absolute path.
    /// Intended to be used during the make phase only.
    pub fn getPath(self: LazyPath, src_builder: *Build) []const u8 {
        return getPath2(self, src_builder, null);
    }

    /// Returns an absolute path.
    /// Intended to be used during the make phase only.
    ///
    /// `asking_step` is only used for debugging purposes; it's the step being
    /// run that is asking for the path.
    pub fn getPath2(self: LazyPath, src_builder: *Build, asking_step: ?*Step) []const u8 {
        switch (self) {
            .path => |p| return src_builder.pathFromRoot(p),
            .cwd_relative => |p| return src_builder.pathFromCwd(p),
            .generated => |gen| return gen.path orelse {
                std.debug.getStderrMutex().lock();
                const stderr = std.io.getStdErr();
                dumpBadGetPathHelp(gen.step, stderr, src_builder, asking_step) catch {};
                @panic("misconfigured build script");
            },
        }
    }

    /// Duplicates the file source for a given builder.
    pub fn dupe(self: LazyPath, b: *Build) LazyPath {
        return switch (self) {
            .path => |p| .{ .path = b.dupePath(p) },
            .cwd_relative => |p| .{ .cwd_relative = b.dupePath(p) },
            .generated => |gen| .{ .generated = gen },
        };
    }
};

/// In this function the stderr mutex has already been locked.
pub fn dumpBadGetPathHelp(
    s: *Step,
    stderr: fs.File,
    src_builder: *Build,
    asking_step: ?*Step,
) anyerror!void {
    const w = stderr.writer();
    try w.print(
        \\getPath() was called on a GeneratedFile that wasn't built yet.
        \\  source package path: {s}
        \\  Is there a missing Step dependency on step '{s}'?
        \\
    , .{
        src_builder.build_root.path orelse ".",
        s.name,
    });

    const tty_config = std.io.tty.detectConfig(stderr);
    tty_config.setColor(w, .red) catch {};
    try stderr.writeAll("    The step was created by this stack trace:\n");
    tty_config.setColor(w, .reset) catch {};

    const debug_info = std.debug.getSelfDebugInfo() catch |err| {
        try w.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)});
        return;
    };
    const ally = debug_info.allocator;
    std.debug.writeStackTrace(s.getStackTrace(), w, ally, debug_info, tty_config) catch |err| {
        try stderr.writer().print("Unable to dump stack trace: {s}\n", .{@errorName(err)});
        return;
    };
    if (asking_step) |as| {
        tty_config.setColor(w, .red) catch {};
        try stderr.writeAll("    The step that is missing a dependency on the above step was created by this stack trace:\n");
        tty_config.setColor(w, .reset) catch {};

        std.debug.writeStackTrace(as.getStackTrace(), w, ally, debug_info, tty_config) catch |err| {
            try stderr.writer().print("Unable to dump stack trace: {s}\n", .{@errorName(err)});
            return;
        };
    }

    tty_config.setColor(w, .red) catch {};
    try stderr.writeAll("    Hope that helps. Proceeding to panic.\n");
    tty_config.setColor(w, .reset) catch {};
}

/// Allocates a new string for assigning a value to a named macro.
/// If the value is omitted, it is set to 1.
/// `name` and `value` need not live longer than the function call.
pub fn constructCMacro(allocator: Allocator, name: []const u8, value: ?[]const u8) []const u8 {
    var macro = allocator.alloc(
        u8,
        name.len + if (value) |value_slice| value_slice.len + 1 else 0,
    ) catch |err| if (err == error.OutOfMemory) @panic("Out of memory") else unreachable;
    @memcpy(macro[0..name.len], name);
    if (value) |value_slice| {
        macro[name.len] = '=';
        @memcpy(macro[name.len + 1 ..][0..value_slice.len], value_slice);
    }
    return macro;
}

pub const VcpkgRoot = union(VcpkgRootStatus) {
    unattempted: void,
    not_found: void,
    found: []const u8,
};

pub const VcpkgRootStatus = enum {
    unattempted,
    not_found,
    found,
};

pub const InstallDir = union(enum) {
    prefix: void,
    lib: void,
    bin: void,
    header: void,
    /// A path relative to the prefix
    custom: []const u8,

    /// Duplicates the install directory including the path if set to custom.
    pub fn dupe(self: InstallDir, builder: *Build) InstallDir {
        if (self == .custom) {
            return .{ .custom = builder.dupe(self.custom) };
        } else {
            return self;
        }
    }
};

pub const InstalledFile = struct {
    dir: InstallDir,
    path: []const u8,

    /// Duplicates the installed file path and directory.
    pub fn dupe(self: InstalledFile, builder: *Build) InstalledFile {
        return .{
            .dir = self.dir.dupe(builder),
            .path = builder.dupe(self.path),
        };
    }
};

pub fn serializeCpu(allocator: Allocator, cpu: std.Target.Cpu) ![]const u8 {
    // TODO this logic can disappear if cpu model + features becomes part of the target triple
    const all_features = cpu.arch.allFeaturesList();
    var populated_cpu_features = cpu.model.features;
    populated_cpu_features.populateDependencies(all_features);

    if (populated_cpu_features.eql(cpu.features)) {
        // The CPU name alone is sufficient.
        return cpu.model.name;
    } else {
        var mcpu_buffer = ArrayList(u8).init(allocator);
        try mcpu_buffer.appendSlice(cpu.model.name);

        for (all_features, 0..) |feature, i_usize| {
            const i = @as(std.Target.Cpu.Feature.Set.Index, @intCast(i_usize));
            const in_cpu_set = populated_cpu_features.isEnabled(i);
            const in_actual_set = cpu.features.isEnabled(i);
            if (in_cpu_set and !in_actual_set) {
                try mcpu_buffer.writer().print("-{s}", .{feature.name});
            } else if (!in_cpu_set and in_actual_set) {
                try mcpu_buffer.writer().print("+{s}", .{feature.name});
            }
        }

        return try mcpu_buffer.toOwnedSlice();
    }
}

/// This function is intended to be called in the `configure` phase only.
/// It returns an absolute directory path, which is potentially going to be a
/// source of API breakage in the future, so keep that in mind when using this
/// function.
pub fn makeTempPath(b: *Build) []const u8 {
    const rand_int = std.crypto.random.int(u64);
    const tmp_dir_sub_path = "tmp" ++ fs.path.sep_str ++ hex64(rand_int);
    const result_path = b.cache_root.join(b.allocator, &.{tmp_dir_sub_path}) catch @panic("OOM");
    b.cache_root.handle.makePath(tmp_dir_sub_path) catch |err| {
        std.debug.print("unable to make tmp path '{s}': {s}\n", .{
            result_path, @errorName(err),
        });
    };
    return result_path;
}

/// There are a few copies of this function in miscellaneous places. Would be nice to find
/// a home for them.
pub fn hex64(x: u64) [16]u8 {
    const hex_charset = "0123456789abcdef";
    var result: [16]u8 = undefined;
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        const byte: u8 = @truncate(x >> @as(u6, @intCast(8 * i)));
        result[i * 2 + 0] = hex_charset[byte >> 4];
        result[i * 2 + 1] = hex_charset[byte & 15];
    }
    return result;
}

test {
    _ = Step;
}
