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

/// deprecated: use `CompileStep`.
pub const LibExeObjStep = CompileStep;
/// deprecated: use `Build`.
pub const Builder = Build;
/// deprecated: use `InstallDirStep.Options`
pub const InstallDirectoryOptions = InstallDirStep.Options;

pub const Step = @import("Build/Step.zig");
pub const CheckFileStep = @import("Build/CheckFileStep.zig");
pub const CheckObjectStep = @import("Build/CheckObjectStep.zig");
pub const ConfigHeaderStep = @import("Build/ConfigHeaderStep.zig");
pub const EmulatableRunStep = @import("Build/EmulatableRunStep.zig");
pub const FmtStep = @import("Build/FmtStep.zig");
pub const InstallArtifactStep = @import("Build/InstallArtifactStep.zig");
pub const InstallDirStep = @import("Build/InstallDirStep.zig");
pub const InstallFileStep = @import("Build/InstallFileStep.zig");
pub const InstallRawStep = @import("Build/InstallRawStep.zig");
pub const CompileStep = @import("Build/CompileStep.zig");
pub const LogStep = @import("Build/LogStep.zig");
pub const OptionsStep = @import("Build/OptionsStep.zig");
pub const RemoveDirStep = @import("Build/RemoveDirStep.zig");
pub const RunStep = @import("Build/RunStep.zig");
pub const TranslateCStep = @import("Build/TranslateCStep.zig");
pub const WriteFileStep = @import("Build/WriteFileStep.zig");

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
verbose_llvm_ir: bool,
verbose_cimport: bool,
verbose_llvm_cpu_features: bool,
/// The purpose of executing the command is for a human to read compile errors from the terminal
prominent_compile_errors: bool,
color: enum { auto, on, off } = .auto,
reference_trace: ?u32 = null,
invalid_user_input: bool,
zig_exe: []const u8,
default_step: *Step,
env_map: *EnvMap,
top_level_steps: ArrayList(*TopLevelStep),
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
build_root: []const u8,
cache_root: []const u8,
global_cache_root: []const u8,
/// zig lib dir
override_lib_dir: ?[]const u8,
vcpkg_root: VcpkgRoot = .unattempted,
pkg_config_pkg_list: ?(PkgConfigError![]const PkgConfigPkg) = null,
args: ?[][]const u8 = null,
debug_log_scopes: []const []const u8 = &.{},
debug_compile_errors: bool = false,

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
    zig_exe: []const u8,
    build_root: []const u8,
    cache_root: []const u8,
    global_cache_root: []const u8,
    host: NativeTargetInfo,
) !*Build {
    const env_map = try allocator.create(EnvMap);
    env_map.* = try process.getEnvMap(allocator);

    const self = try allocator.create(Build);
    self.* = Build{
        .zig_exe = zig_exe,
        .build_root = build_root,
        .cache_root = try fs.path.relative(allocator, build_root, cache_root),
        .global_cache_root = global_cache_root,
        .verbose = false,
        .verbose_link = false,
        .verbose_cc = false,
        .verbose_air = false,
        .verbose_llvm_ir = false,
        .verbose_cimport = false,
        .verbose_llvm_cpu_features = false,
        .prominent_compile_errors = false,
        .invalid_user_input = false,
        .allocator = allocator,
        .user_input_options = UserInputOptionsMap.init(allocator),
        .available_options_map = AvailableOptionsMap.init(allocator),
        .available_options_list = ArrayList(AvailableOption).init(allocator),
        .top_level_steps = ArrayList(*TopLevelStep).init(allocator),
        .default_step = undefined,
        .env_map = env_map,
        .search_prefixes = ArrayList([]const u8).init(allocator),
        .install_prefix = undefined,
        .lib_dir = undefined,
        .exe_dir = undefined,
        .h_dir = undefined,
        .dest_dir = env_map.get("DESTDIR"),
        .installed_files = ArrayList(InstalledFile).init(allocator),
        .install_tls = TopLevelStep{
            .step = Step.initNoOp(.top_level, "install", allocator),
            .description = "Copy build artifacts to prefix path",
        },
        .uninstall_tls = TopLevelStep{
            .step = Step.init(.top_level, "uninstall", allocator, makeUninstall),
            .description = "Remove build artifacts from prefix path",
        },
        .override_lib_dir = null,
        .install_path = undefined,
        .args = null,
        .host = host,
        .modules = std.StringArrayHashMap(*Module).init(allocator),
    };
    try self.top_level_steps.append(&self.install_tls);
    try self.top_level_steps.append(&self.uninstall_tls);
    self.default_step = &self.install_tls.step;
    return self;
}

fn createChild(
    parent: *Build,
    dep_name: []const u8,
    build_root: []const u8,
    args: anytype,
) !*Build {
    const child = try createChildOnly(parent, dep_name, build_root);
    try applyArgs(child, args);
    return child;
}

fn createChildOnly(parent: *Build, dep_name: []const u8, build_root: []const u8) !*Build {
    const allocator = parent.allocator;
    const child = try allocator.create(Build);
    child.* = .{
        .allocator = allocator,
        .install_tls = .{
            .step = Step.initNoOp(.top_level, "install", allocator),
            .description = "Copy build artifacts to prefix path",
        },
        .uninstall_tls = .{
            .step = Step.init(.top_level, "uninstall", allocator, makeUninstall),
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
        .verbose_cimport = parent.verbose_cimport,
        .verbose_llvm_cpu_features = parent.verbose_llvm_cpu_features,
        .prominent_compile_errors = parent.prominent_compile_errors,
        .color = parent.color,
        .reference_trace = parent.reference_trace,
        .invalid_user_input = false,
        .zig_exe = parent.zig_exe,
        .default_step = undefined,
        .env_map = parent.env_map,
        .top_level_steps = ArrayList(*TopLevelStep).init(allocator),
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
        .override_lib_dir = parent.override_lib_dir,
        .debug_log_scopes = parent.debug_log_scopes,
        .debug_compile_errors = parent.debug_compile_errors,
        .enable_darling = parent.enable_darling,
        .enable_qemu = parent.enable_qemu,
        .enable_rosetta = parent.enable_rosetta,
        .enable_wasmtime = parent.enable_wasmtime,
        .enable_wine = parent.enable_wine,
        .glibc_runtimes_dir = parent.glibc_runtimes_dir,
        .host = parent.host,
        .dep_prefix = parent.fmt("{s}{s}.", .{ parent.dep_prefix, dep_name }),
        .modules = std.StringArrayHashMap(*Module).init(allocator),
    };
    try child.top_level_steps.append(&child.install_tls);
    try child.top_level_steps.append(&child.uninstall_tls);
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
                .Enum => {
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
    const Hasher = std.crypto.auth.siphash.SipHash128(1, 3);
    // Random bytes to make unique. Refresh this with new random bytes when
    // implementation is modified in a non-backwards-compatible way.
    var hash = Hasher.init("ZaEsvQ5ClaA2IdH9");
    hash.update(b.dep_prefix);
    // TODO additionally update the hash with `args`.

    var digest: [16]u8 = undefined;
    hash.final(&digest);
    var hash_basename: [digest.len * 2]u8 = undefined;
    _ = std.fmt.bufPrint(&hash_basename, "{s}", .{std.fmt.fmtSliceHexLower(&digest)}) catch
        unreachable;

    const install_prefix = b.pathJoin(&.{ b.cache_root, "i", &hash_basename });
    b.resolveInstallPrefix(install_prefix, .{});
}

pub fn destroy(self: *Build) void {
    self.env_map.deinit();
    self.top_level_steps.deinit();
    self.allocator.destroy(self);
}

/// This function is intended to be called by lib/build_runner.zig, not a build.zig file.
pub fn resolveInstallPrefix(self: *Build, install_prefix: ?[]const u8, dir_list: DirList) void {
    if (self.dest_dir) |dest_dir| {
        self.install_prefix = install_prefix orelse "/usr";
        self.install_path = self.pathJoin(&.{ dest_dir, self.install_prefix });
    } else {
        self.install_prefix = install_prefix orelse
            (self.pathJoin(&.{ self.build_root, "zig-out" }));
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

pub fn addOptions(self: *Build) *OptionsStep {
    return OptionsStep.create(self);
}

pub const ExecutableOptions = struct {
    name: []const u8,
    root_source_file: ?FileSource = null,
    version: ?std.builtin.Version = null,
    target: CrossTarget = .{},
    optimize: std.builtin.Mode = .Debug,
    linkage: ?CompileStep.Linkage = null,
};

pub fn addExecutable(b: *Build, options: ExecutableOptions) *CompileStep {
    return CompileStep.create(b, .{
        .name = options.name,
        .root_source_file = options.root_source_file,
        .version = options.version,
        .target = options.target,
        .optimize = options.optimize,
        .kind = .exe,
        .linkage = options.linkage,
    });
}

pub const ObjectOptions = struct {
    name: []const u8,
    root_source_file: ?FileSource = null,
    target: CrossTarget,
    optimize: std.builtin.Mode,
};

pub fn addObject(b: *Build, options: ObjectOptions) *CompileStep {
    return CompileStep.create(b, .{
        .name = options.name,
        .root_source_file = options.root_source_file,
        .target = options.target,
        .optimize = options.optimize,
        .kind = .obj,
    });
}

pub const SharedLibraryOptions = struct {
    name: []const u8,
    root_source_file: ?FileSource = null,
    version: ?std.builtin.Version = null,
    target: CrossTarget,
    optimize: std.builtin.Mode,
};

pub fn addSharedLibrary(b: *Build, options: SharedLibraryOptions) *CompileStep {
    return CompileStep.create(b, .{
        .name = options.name,
        .root_source_file = options.root_source_file,
        .kind = .lib,
        .linkage = .dynamic,
        .version = options.version,
        .target = options.target,
        .optimize = options.optimize,
    });
}

pub const StaticLibraryOptions = struct {
    name: []const u8,
    root_source_file: ?FileSource = null,
    target: CrossTarget,
    optimize: std.builtin.Mode,
    version: ?std.builtin.Version = null,
};

pub fn addStaticLibrary(b: *Build, options: StaticLibraryOptions) *CompileStep {
    return CompileStep.create(b, .{
        .name = options.name,
        .root_source_file = options.root_source_file,
        .kind = .lib,
        .linkage = .static,
        .version = options.version,
        .target = options.target,
        .optimize = options.optimize,
    });
}

pub const TestOptions = struct {
    name: []const u8 = "test",
    kind: CompileStep.Kind = .@"test",
    root_source_file: FileSource,
    target: CrossTarget = .{},
    optimize: std.builtin.Mode = .Debug,
    version: ?std.builtin.Version = null,
};

pub fn addTest(b: *Build, options: TestOptions) *CompileStep {
    return CompileStep.create(b, .{
        .name = options.name,
        .kind = options.kind,
        .root_source_file = options.root_source_file,
        .target = options.target,
        .optimize = options.optimize,
    });
}

pub const AssemblyOptions = struct {
    name: []const u8,
    source_file: FileSource,
    target: CrossTarget,
    optimize: std.builtin.Mode,
};

pub fn addAssembly(b: *Build, options: AssemblyOptions) *CompileStep {
    const obj_step = CompileStep.create(b, .{
        .name = options.name,
        .root_source_file = null,
        .target = options.target,
        .optimize = options.optimize,
    });
    obj_step.addAssemblyFileSource(options.source_file.dupe(b));
    return obj_step;
}

pub const AddModuleOptions = struct {
    name: []const u8,
    source_file: FileSource,
    dependencies: []const ModuleDependency = &.{},
};

pub fn addModule(b: *Build, options: AddModuleOptions) void {
    b.modules.put(b.dupe(options.name), b.createModule(.{
        .source_file = options.source_file,
        .dependencies = options.dependencies,
    })) catch @panic("OOM");
}

pub const ModuleDependency = struct {
    name: []const u8,
    module: *Module,
};

pub const CreateModuleOptions = struct {
    source_file: FileSource,
    dependencies: []const ModuleDependency = &.{},
};

/// Prefer to use `addModule` which will make the module available to other
/// packages which depend on this package.
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

/// Initializes a RunStep with argv, which must at least have the path to the
/// executable. More command line arguments can be added with `addArg`,
/// `addArgs`, and `addArtifactArg`.
/// Be careful using this function, as it introduces a system dependency.
/// To run an executable built with zig build, see `CompileStep.run`.
pub fn addSystemCommand(self: *Build, argv: []const []const u8) *RunStep {
    assert(argv.len >= 1);
    const run_step = RunStep.create(self, self.fmt("run {s}", .{argv[0]}));
    run_step.addArgs(argv);
    return run_step;
}

/// Using the `values` provided, produces a C header file, possibly based on a
/// template input file (e.g. config.h.in).
/// When an input template file is provided, this function will fail the build
/// when an option not found in the input file is provided in `values`, and
/// when an option found in the input file is missing from `values`.
pub fn addConfigHeader(
    b: *Build,
    options: ConfigHeaderStep.Options,
    values: anytype,
) *ConfigHeaderStep {
    const config_header_step = ConfigHeaderStep.create(b, options);
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
    for (strings) |s, i| {
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

pub fn addWriteFile(self: *Build, file_path: []const u8, data: []const u8) *WriteFileStep {
    const write_file_step = self.addWriteFiles();
    write_file_step.add(file_path, data);
    return write_file_step;
}

pub fn addWriteFiles(self: *Build) *WriteFileStep {
    const write_file_step = self.allocator.create(WriteFileStep) catch @panic("OOM");
    write_file_step.* = WriteFileStep.init(self);
    return write_file_step;
}

pub fn addLog(self: *Build, comptime format: []const u8, args: anytype) *LogStep {
    const data = self.fmt(format, args);
    const log_step = self.allocator.create(LogStep) catch @panic("OOM");
    log_step.* = LogStep.init(self, data);
    return log_step;
}

pub fn addRemoveDirTree(self: *Build, dir_path: []const u8) *RemoveDirStep {
    const remove_dir_step = self.allocator.create(RemoveDirStep) catch @panic("OOM");
    remove_dir_step.* = RemoveDirStep.init(self, dir_path);
    return remove_dir_step;
}

pub fn addFmt(self: *Build, paths: []const []const u8) *FmtStep {
    return FmtStep.create(self, paths);
}

pub fn addTranslateC(self: *Build, options: TranslateCStep.Options) *TranslateCStep {
    return TranslateCStep.create(self, options);
}

pub fn make(self: *Build, step_names: []const []const u8) !void {
    try self.makePath(self.cache_root);

    var wanted_steps = ArrayList(*Step).init(self.allocator);
    defer wanted_steps.deinit();

    if (step_names.len == 0) {
        try wanted_steps.append(self.default_step);
    } else {
        for (step_names) |step_name| {
            const s = try self.getTopLevelStepByName(step_name);
            try wanted_steps.append(s);
        }
    }

    for (wanted_steps.items) |s| {
        try self.makeOneStep(s);
    }
}

pub fn getInstallStep(self: *Build) *Step {
    return &self.install_tls.step;
}

pub fn getUninstallStep(self: *Build) *Step {
    return &self.uninstall_tls.step;
}

fn makeUninstall(uninstall_step: *Step) anyerror!void {
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

fn makeOneStep(self: *Build, s: *Step) anyerror!void {
    if (s.loop_flag) {
        log.err("Dependency loop detected:\n  {s}", .{s.name});
        return error.DependencyLoopDetected;
    }
    s.loop_flag = true;

    for (s.dependencies.items) |dep| {
        self.makeOneStep(dep) catch |err| {
            if (err == error.DependencyLoopDetected) {
                log.err("  {s}", .{s.name});
            }
            return err;
        };
    }

    s.loop_flag = false;

    try s.make();
}

fn getTopLevelStepByName(self: *Build, name: []const u8) !*Step {
    for (self.top_level_steps.items) |top_level_step| {
        if (mem.eql(u8, top_level_step.step.name, name)) {
            return &top_level_step.step;
        }
    }
    log.err("Cannot run step '{s}' because it does not exist", .{name});
    return error.InvalidStepName;
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
                    log.err("Expected -D{s} to be a boolean, but received '{s}'\n", .{ name, s });
                    self.markInvalidUserInput();
                    return null;
                }
            },
            .list, .map => {
                log.err("Expected -D{s} to be a boolean, but received a {s}.\n", .{
                    name, @tagName(option_ptr.value),
                });
                self.markInvalidUserInput();
                return null;
            },
        },
        .int => switch (option_ptr.value) {
            .flag, .list, .map => {
                log.err("Expected -D{s} to be an integer, but received a {s}.\n", .{
                    name, @tagName(option_ptr.value),
                });
                self.markInvalidUserInput();
                return null;
            },
            .scalar => |s| {
                const n = std.fmt.parseInt(T, s, 10) catch |err| switch (err) {
                    error.Overflow => {
                        log.err("-D{s} value {s} cannot fit into type {s}.\n", .{ name, s, @typeName(T) });
                        self.markInvalidUserInput();
                        return null;
                    },
                    else => {
                        log.err("Expected -D{s} to be an integer of type {s}.\n", .{ name, @typeName(T) });
                        self.markInvalidUserInput();
                        return null;
                    },
                };
                return n;
            },
        },
        .float => switch (option_ptr.value) {
            .flag, .map, .list => {
                log.err("Expected -D{s} to be a float, but received a {s}.\n", .{
                    name, @tagName(option_ptr.value),
                });
                self.markInvalidUserInput();
                return null;
            },
            .scalar => |s| {
                const n = std.fmt.parseFloat(T, s) catch {
                    log.err("Expected -D{s} to be a float of type {s}.\n", .{ name, @typeName(T) });
                    self.markInvalidUserInput();
                    return null;
                };
                return n;
            },
        },
        .@"enum" => switch (option_ptr.value) {
            .flag, .map, .list => {
                log.err("Expected -D{s} to be an enum, but received a {s}.\n", .{
                    name, @tagName(option_ptr.value),
                });
                self.markInvalidUserInput();
                return null;
            },
            .scalar => |s| {
                if (std.meta.stringToEnum(T, s)) |enum_lit| {
                    return enum_lit;
                } else {
                    log.err("Expected -D{s} to be of type {s}.\n", .{ name, @typeName(T) });
                    self.markInvalidUserInput();
                    return null;
                }
            },
        },
        .string => switch (option_ptr.value) {
            .flag, .list, .map => {
                log.err("Expected -D{s} to be a string, but received a {s}.\n", .{
                    name, @tagName(option_ptr.value),
                });
                self.markInvalidUserInput();
                return null;
            },
            .scalar => |s| return s,
        },
        .list => switch (option_ptr.value) {
            .flag, .map => {
                log.err("Expected -D{s} to be a list, but received a {s}.\n", .{
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
    step_info.* = TopLevelStep{
        .step = Step.initNoOp(.top_level, name, self.allocator),
        .description = self.dupe(description),
    };
    self.top_level_steps.append(step_info) catch @panic("OOM");
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
            "prioritize performance, safety, or binary size (-O flag)",
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
            for (all_features) |feature, i_usize| {
                const i = @intCast(std.Target.Cpu.Feature.Set.Index, i_usize);
                const in_cpu_set = populated_cpu_features.isEnabled(i);
                if (in_cpu_set) {
                    log.err("{s} ", .{feature.name});
                }
            }
            log.err("  Remove: ", .{});
            for (all_features) |feature, i_usize| {
                const i = @intCast(std.Target.Cpu.Feature.Set.Index, i_usize);
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
    return switch (@typeInfo(T)) {
        .Int => .int,
        .Float => .float,
        .Bool => .bool,
        .Enum => .@"enum",
        else => switch (T) {
            []const u8 => .string,
            []const []const u8 => .list,
            else => @compileError("Unsupported type: " ++ @typeName(T)),
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

pub fn spawnChild(self: *Build, argv: []const []const u8) !void {
    return self.spawnChildEnvMap(null, self.env_map, argv);
}

fn printCmd(cwd: ?[]const u8, argv: []const []const u8) void {
    if (cwd) |yes_cwd| std.debug.print("cd {s} && ", .{yes_cwd});
    for (argv) |arg| {
        std.debug.print("{s} ", .{arg});
    }
    std.debug.print("\n", .{});
}

pub fn spawnChildEnvMap(self: *Build, cwd: ?[]const u8, env_map: *const EnvMap, argv: []const []const u8) !void {
    if (self.verbose) {
        printCmd(cwd, argv);
    }

    if (!std.process.can_spawn)
        return error.ExecNotSupported;

    var child = std.ChildProcess.init(argv, self.allocator);
    child.cwd = cwd;
    child.env_map = env_map;

    const term = child.spawnAndWait() catch |err| {
        log.err("Unable to spawn {s}: {s}", .{ argv[0], @errorName(err) });
        return err;
    };

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                log.err("The following command exited with error code {}:", .{code});
                printCmd(cwd, argv);
                return error.UncleanExit;
            }
        },
        else => {
            log.err("The following command terminated unexpectedly:", .{});
            printCmd(cwd, argv);

            return error.UncleanExit;
        },
    }
}

pub fn makePath(self: *Build, path: []const u8) !void {
    fs.cwd().makePath(self.pathFromRoot(path)) catch |err| {
        log.err("Unable to create path {s}: {s}", .{ path, @errorName(err) });
        return err;
    };
}

pub fn installArtifact(self: *Build, artifact: *CompileStep) void {
    self.getInstallStep().dependOn(&self.addInstallArtifact(artifact).step);
}

pub fn addInstallArtifact(self: *Build, artifact: *CompileStep) *InstallArtifactStep {
    return InstallArtifactStep.create(self, artifact);
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

/// Output format (BIN vs Intel HEX) determined by filename
pub fn installRaw(self: *Build, artifact: *CompileStep, dest_filename: []const u8, options: InstallRawStep.CreateOptions) *InstallRawStep {
    const raw = self.addInstallRaw(artifact, dest_filename, options);
    self.getInstallStep().dependOn(&raw.step);
    return raw;
}

///`dest_rel_path` is relative to install prefix path
pub fn addInstallFile(self: *Build, source: FileSource, dest_rel_path: []const u8) *InstallFileStep {
    return self.addInstallFileWithDir(source.dupe(self), .prefix, dest_rel_path);
}

///`dest_rel_path` is relative to bin path
pub fn addInstallBinFile(self: *Build, source: FileSource, dest_rel_path: []const u8) *InstallFileStep {
    return self.addInstallFileWithDir(source.dupe(self), .bin, dest_rel_path);
}

///`dest_rel_path` is relative to lib path
pub fn addInstallLibFile(self: *Build, source: FileSource, dest_rel_path: []const u8) *InstallFileStep {
    return self.addInstallFileWithDir(source.dupe(self), .lib, dest_rel_path);
}

pub fn addInstallHeaderFile(b: *Build, src_path: []const u8, dest_rel_path: []const u8) *InstallFileStep {
    return b.addInstallFileWithDir(.{ .path = src_path }, .header, dest_rel_path);
}

pub fn addInstallRaw(self: *Build, artifact: *CompileStep, dest_filename: []const u8, options: InstallRawStep.CreateOptions) *InstallRawStep {
    return InstallRawStep.create(self, artifact, dest_filename, options);
}

pub fn addInstallFileWithDir(
    self: *Build,
    source: FileSource,
    install_dir: InstallDir,
    dest_rel_path: []const u8,
) *InstallFileStep {
    if (dest_rel_path.len == 0) {
        panic("dest_rel_path must be non-empty", .{});
    }
    const install_step = self.allocator.create(InstallFileStep) catch @panic("OOM");
    install_step.* = InstallFileStep.init(self, source.dupe(self), install_dir, dest_rel_path);
    return install_step;
}

pub fn addInstallDirectory(self: *Build, options: InstallDirectoryOptions) *InstallDirStep {
    const install_step = self.allocator.create(InstallDirStep) catch @panic("OOM");
    install_step.* = InstallDirStep.init(self, options);
    return install_step;
}

pub fn pushInstalledFile(self: *Build, dir: InstallDir, dest_rel_path: []const u8) void {
    const file = InstalledFile{
        .dir = dir,
        .path = dest_rel_path,
    };
    self.installed_files.append(file.dupe(self)) catch @panic("OOM");
}

pub fn updateFile(self: *Build, source_path: []const u8, dest_path: []const u8) !void {
    if (self.verbose) {
        log.info("cp {s} {s} ", .{ source_path, dest_path });
    }
    const cwd = fs.cwd();
    const prev_status = try fs.Dir.updateFile(cwd, source_path, cwd, dest_path, .{});
    if (self.verbose) switch (prev_status) {
        .stale => log.info("# installed", .{}),
        .fresh => log.info("# up-to-date", .{}),
    };
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

pub fn pathFromRoot(self: *Build, rel_path: []const u8) []u8 {
    return fs.path.resolve(self.allocator, &[_][]const u8{ self.build_root, rel_path }) catch @panic("OOM");
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
            var it = mem.tokenize(u8, PATH, &[_]u8{fs.path.delimiter});
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

    if (!std.process.can_spawn)
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
                out_code.* = @truncate(u8, code);
                return error.ExitCodeFailure;
            }
            return stdout;
        },
        .Signal, .Stopped, .Unknown => |code| {
            out_code.* = @truncate(u8, code);
            return error.ProcessTerminated;
        },
    }
}

pub fn execFromStep(self: *Build, argv: []const []const u8, src_step: ?*Step) ![]u8 {
    assert(argv.len != 0);

    if (self.verbose) {
        printCmd(null, argv);
    }

    if (!std.process.can_spawn) {
        if (src_step) |s| log.err("{s}...", .{s.name});
        log.err("Unable to spawn the following command: cannot spawn child process", .{});
        printCmd(null, argv);
        std.os.abort();
    }

    var code: u8 = undefined;
    return self.execAllowFail(argv, &code, .Inherit) catch |err| switch (err) {
        error.ExecNotSupported => {
            if (src_step) |s| log.err("{s}...", .{s.name});
            log.err("Unable to spawn the following command: cannot spawn child process", .{});
            printCmd(null, argv);
            std.os.abort();
        },
        error.FileNotFound => {
            if (src_step) |s| log.err("{s}...", .{s.name});
            log.err("Unable to spawn the following command: file not found", .{});
            printCmd(null, argv);
            std.os.exit(@truncate(u8, code));
        },
        error.ExitCodeFailure => {
            if (src_step) |s| log.err("{s}...", .{s.name});
            if (self.prominent_compile_errors) {
                log.err("The step exited with error code {d}", .{code});
            } else {
                log.err("The following command exited with error code {d}:", .{code});
                printCmd(null, argv);
            }

            std.os.exit(@truncate(u8, code));
        },
        error.ProcessTerminated => {
            if (src_step) |s| log.err("{s}...", .{s.name});
            log.err("The following command terminated unexpectedly:", .{});
            printCmd(null, argv);
            std.os.exit(@truncate(u8, code));
        },
        else => |e| return e,
    };
}

pub fn exec(self: *Build, argv: []const []const u8) ![]u8 {
    return self.execFromStep(argv, null);
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

    pub fn artifact(d: *Dependency, name: []const u8) *CompileStep {
        var found: ?*CompileStep = null;
        for (d.builder.install_tls.step.dependencies.items) |dep_step| {
            const inst = dep_step.cast(InstallArtifactStep) orelse continue;
            if (mem.eql(u8, inst.artifact.name, name)) {
                if (found != null) panic("artifact name '{s}' is ambiguous", .{name});
                found = inst.artifact;
            }
        }
        return found orelse {
            for (d.builder.install_tls.step.dependencies.items) |dep_step| {
                const inst = dep_step.cast(InstallArtifactStep) orelse continue;
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
    std.process.exit(1);
}

fn dependencyInner(
    b: *Build,
    name: []const u8,
    build_root: []const u8,
    comptime build_zig: type,
    args: anytype,
) *Dependency {
    const sub_builder = b.createChild(name, build_root, args) catch @panic("unhandled error");
    sub_builder.runBuild(build_zig) catch @panic("unhandled error");

    if (sub_builder.validateUserInputDidItFail()) {
        std.debug.dumpCurrentStackTrace(@returnAddress());
    }

    const dep = b.allocator.create(Dependency) catch @panic("OOM");
    dep.* = .{ .builder = sub_builder };
    return dep;
}

pub fn runBuild(b: *Build, build_zig: anytype) anyerror!void {
    switch (@typeInfo(@typeInfo(@TypeOf(build_zig.build)).Fn.return_type.?)) {
        .Void => build_zig.build(b),
        .ErrorUnion => try build_zig.build(b),
        else => @compileError("expected return type of build to be 'void' or '!void'"),
    }
}

test "builder.findProgram compiles" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const host = try NativeTargetInfo.detect(.{});

    const builder = try Build.create(
        arena.allocator(),
        "zig",
        "zig-cache",
        "zig-cache",
        "zig-cache",
        host,
    );
    defer builder.destroy();
    _ = builder.findProgram(&[_][]const u8{}, &[_][]const u8{}) catch null;
}

pub const Module = struct {
    builder: *Build,
    /// This could either be a generated file, in which case the module
    /// contains exactly one file, or it could be a path to the root source
    /// file of directory of files which constitute the module.
    source_file: FileSource,
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
            "getPath() was called on a GeneratedFile that wasn't build yet. Is there a missing Step dependency on step '{s}'?",
            .{self.step.name},
        );
    }
};

/// A file source is a reference to an existing or future file.
///
pub const FileSource = union(enum) {
    /// A plain file path, relative to build root or absolute.
    path: []const u8,

    /// A file that is generated by an interface. Those files usually are
    /// not available until built by a build step.
    generated: *const GeneratedFile,

    /// Returns a new file source that will have a relative path to the build root guaranteed.
    /// This should be preferred over setting `.path` directly as it documents that the files are in the project directory.
    pub fn relative(path: []const u8) FileSource {
        std.debug.assert(!std.fs.path.isAbsolute(path));
        return FileSource{ .path = path };
    }

    /// Returns a string that can be shown to represent the file source.
    /// Either returns the path or `"generated"`.
    pub fn getDisplayName(self: FileSource) []const u8 {
        return switch (self) {
            .path => self.path,
            .generated => "generated",
        };
    }

    /// Adds dependencies this file source implies to the given step.
    pub fn addStepDependencies(self: FileSource, other_step: *Step) void {
        switch (self) {
            .path => {},
            .generated => |gen| other_step.dependOn(gen.step),
        }
    }

    /// Should only be called during make(), returns a path relative to the build root or absolute.
    pub fn getPath(self: FileSource, builder: *Build) []const u8 {
        const path = switch (self) {
            .path => |p| builder.pathFromRoot(p),
            .generated => |gen| gen.getPath(),
        };
        return path;
    }

    /// Duplicates the file source for a given builder.
    pub fn dupe(self: FileSource, b: *Build) FileSource {
        return switch (self) {
            .path => |p| .{ .path = b.dupePath(p) },
            .generated => |gen| .{ .generated = gen },
        };
    }
};

/// Allocates a new string for assigning a value to a named macro.
/// If the value is omitted, it is set to 1.
/// `name` and `value` need not live longer than the function call.
pub fn constructCMacro(allocator: Allocator, name: []const u8, value: ?[]const u8) []const u8 {
    var macro = allocator.alloc(
        u8,
        name.len + if (value) |value_slice| value_slice.len + 1 else 0,
    ) catch |err| if (err == error.OutOfMemory) @panic("Out of memory") else unreachable;
    mem.copy(u8, macro, name);
    if (value) |value_slice| {
        macro[name.len] = '=';
        mem.copy(u8, macro[name.len + 1 ..], value_slice);
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
            // Written with this temporary to avoid RLS problems
            const duped_path = builder.dupe(self.custom);
            return .{ .custom = duped_path };
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

        for (all_features) |feature, i_usize| {
            const i = @intCast(std.Target.Cpu.Feature.Set.Index, i_usize);
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

test {
    _ = CheckFileStep;
    _ = CheckObjectStep;
    _ = EmulatableRunStep;
    _ = FmtStep;
    _ = InstallArtifactStep;
    _ = InstallDirStep;
    _ = InstallFileStep;
    _ = InstallRawStep;
    _ = CompileStep;
    _ = LogStep;
    _ = OptionsStep;
    _ = RemoveDirStep;
    _ = RunStep;
    _ = TranslateCStep;
    _ = WriteFileStep;
}
