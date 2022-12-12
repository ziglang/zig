const builtin = @import("builtin");
const std = @import("../std.zig");
const mem = std.mem;
const log = std.log;
const fs = std.fs;
const assert = std.debug.assert;
const panic = std.debug.panic;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Sha256 = std.crypto.hash.sha2.Sha256;
const Allocator = mem.Allocator;
const build = @import("../build.zig");
const Step = build.Step;
const Builder = build.Builder;
const CrossTarget = std.zig.CrossTarget;
const NativeTargetInfo = std.zig.system.NativeTargetInfo;
const FileSource = std.build.FileSource;
const PkgConfigPkg = Builder.PkgConfigPkg;
const PkgConfigError = Builder.PkgConfigError;
const ExecError = Builder.ExecError;
const Pkg = std.build.Pkg;
const VcpkgRoot = std.build.VcpkgRoot;
const InstallDir = std.build.InstallDir;
const InstallArtifactStep = std.build.InstallArtifactStep;
const GeneratedFile = std.build.GeneratedFile;
const InstallRawStep = std.build.InstallRawStep;
const EmulatableRunStep = std.build.EmulatableRunStep;
const CheckObjectStep = std.build.CheckObjectStep;
const RunStep = std.build.RunStep;
const OptionsStep = std.build.OptionsStep;
const LibExeObjStep = @This();

pub const base_id = .lib_exe_obj;

step: Step,
builder: *Builder,
name: []const u8,
target: CrossTarget = CrossTarget{},
target_info: NativeTargetInfo,
linker_script: ?FileSource = null,
version_script: ?[]const u8 = null,
out_filename: []const u8,
linkage: ?Linkage = null,
version: ?std.builtin.Version,
build_mode: std.builtin.Mode,
kind: Kind,
major_only_filename: ?[]const u8,
name_only_filename: ?[]const u8,
strip: ?bool,
unwind_tables: ?bool,
// keep in sync with src/link.zig:CompressDebugSections
compress_debug_sections: enum { none, zlib } = .none,
lib_paths: ArrayList([]const u8),
rpaths: ArrayList([]const u8),
framework_dirs: ArrayList([]const u8),
frameworks: StringHashMap(FrameworkLinkInfo),
verbose_link: bool,
verbose_cc: bool,
emit_analysis: EmitOption = .default,
emit_asm: EmitOption = .default,
emit_bin: EmitOption = .default,
emit_docs: EmitOption = .default,
emit_implib: EmitOption = .default,
emit_llvm_bc: EmitOption = .default,
emit_llvm_ir: EmitOption = .default,
// Lots of things depend on emit_h having a consistent path,
// so it is not an EmitOption for now.
emit_h: bool = false,
bundle_compiler_rt: ?bool = null,
single_threaded: ?bool = null,
stack_protector: ?bool = null,
disable_stack_probing: bool,
disable_sanitize_c: bool,
sanitize_thread: bool,
rdynamic: bool,
import_memory: bool = false,
import_table: bool = false,
export_table: bool = false,
initial_memory: ?u64 = null,
max_memory: ?u64 = null,
shared_memory: bool = false,
global_base: ?u64 = null,
c_std: Builder.CStd,
override_lib_dir: ?[]const u8,
main_pkg_path: ?[]const u8,
exec_cmd_args: ?[]const ?[]const u8,
name_prefix: []const u8,
filter: ?[]const u8,
test_evented_io: bool = false,
test_runner: ?[]const u8,
code_model: std.builtin.CodeModel = .default,
wasi_exec_model: ?std.builtin.WasiExecModel = null,
/// Symbols to be exported when compiling to wasm
export_symbol_names: []const []const u8 = &.{},

root_src: ?FileSource,
out_h_filename: []const u8,
out_lib_filename: []const u8,
out_pdb_filename: []const u8,
packages: ArrayList(Pkg),

object_src: []const u8,

link_objects: ArrayList(LinkObject),
include_dirs: ArrayList(IncludeDir),
c_macros: ArrayList([]const u8),
output_dir: ?[]const u8,
is_linking_libc: bool = false,
is_linking_libcpp: bool = false,
vcpkg_bin_path: ?[]const u8 = null,

/// This may be set in order to override the default install directory
override_dest_dir: ?InstallDir,
installed_path: ?[]const u8,
install_step: ?*InstallArtifactStep,

/// Base address for an executable image.
image_base: ?u64 = null,

libc_file: ?FileSource = null,

valgrind_support: ?bool = null,
each_lib_rpath: ?bool = null,
/// On ELF targets, this will emit a link section called ".note.gnu.build-id"
/// which can be used to coordinate a stripped binary with its debug symbols.
/// As an example, the bloaty project refuses to work unless its inputs have
/// build ids, in order to prevent accidental mismatches.
/// The default is to not include this section because it slows down linking.
build_id: ?bool = null,

/// Create a .eh_frame_hdr section and a PT_GNU_EH_FRAME segment in the ELF
/// file.
link_eh_frame_hdr: bool = false,
link_emit_relocs: bool = false,

/// Place every function in its own section so that unused ones may be
/// safely garbage-collected during the linking phase.
link_function_sections: bool = false,

/// Remove functions and data that are unreachable by the entry point or
/// exported symbols.
link_gc_sections: ?bool = null,

linker_allow_shlib_undefined: ?bool = null,

/// Permit read-only relocations in read-only segments. Disallowed by default.
link_z_notext: bool = false,

/// Force all relocations to be read-only after processing.
link_z_relro: bool = true,

/// Allow relocations to be lazily processed after load.
link_z_lazy: bool = false,

/// (Darwin) Install name for the dylib
install_name: ?[]const u8 = null,

/// (Darwin) Path to entitlements file
entitlements: ?[]const u8 = null,

/// (Darwin) Size of the pagezero segment.
pagezero_size: ?u64 = null,

/// (Darwin) Search strategy for searching system libraries. Either `paths_first` or `dylibs_first`.
/// The former lowers to `-search_paths_first` linker option, while the latter to `-search_dylibs_first`
/// option.
/// By default, if no option is specified, the linker assumes `paths_first` as the default
/// search strategy.
search_strategy: ?enum { paths_first, dylibs_first } = null,

/// (Darwin) Set size of the padding between the end of load commands
/// and start of `__TEXT,__text` section.
headerpad_size: ?u32 = null,

/// (Darwin) Automatically Set size of the padding between the end of load commands
/// and start of `__TEXT,__text` section to a value fitting all paths expanded to MAXPATHLEN.
headerpad_max_install_names: bool = false,

/// (Darwin) Remove dylibs that are unreachable by the entry point or exported symbols.
dead_strip_dylibs: bool = false,

/// Position Independent Code
force_pic: ?bool = null,

/// Position Independent Executable
pie: ?bool = null,

red_zone: ?bool = null,

omit_frame_pointer: ?bool = null,
dll_export_fns: ?bool = null,

subsystem: ?std.Target.SubSystem = null,

entry_symbol_name: ?[]const u8 = null,

/// Overrides the default stack size
stack_size: ?u64 = null,

want_lto: ?bool = null,
use_llvm: ?bool = null,
use_lld: ?bool = null,

output_path_source: GeneratedFile,
output_lib_path_source: GeneratedFile,
output_h_path_source: GeneratedFile,
output_pdb_path_source: GeneratedFile,

pub const CSourceFiles = struct {
    files: []const []const u8,
    flags: []const []const u8,
};

pub const CSourceFile = struct {
    source: FileSource,
    args: []const []const u8,

    pub fn dupe(self: CSourceFile, b: *Builder) CSourceFile {
        return .{
            .source = self.source.dupe(b),
            .args = b.dupeStrings(self.args),
        };
    }
};

pub const LinkObject = union(enum) {
    static_path: FileSource,
    other_step: *LibExeObjStep,
    system_lib: SystemLib,
    assembly_file: FileSource,
    c_source_file: *CSourceFile,
    c_source_files: *CSourceFiles,
};

pub const SystemLib = struct {
    name: []const u8,
    needed: bool,
    weak: bool,
    use_pkg_config: enum {
        /// Don't use pkg-config, just pass -lfoo where foo is name.
        no,
        /// Try to get information on how to link the library from pkg-config.
        /// If that fails, fall back to passing -lfoo where foo is name.
        yes,
        /// Try to get information on how to link the library from pkg-config.
        /// If that fails, error out.
        force,
    },
};

const FrameworkLinkInfo = struct {
    needed: bool = false,
    weak: bool = false,
};

pub const IncludeDir = union(enum) {
    raw_path: []const u8,
    raw_path_system: []const u8,
    other_step: *LibExeObjStep,
};

pub const Kind = enum {
    exe,
    lib,
    obj,
    @"test",
    test_exe,
};

pub const SharedLibKind = union(enum) {
    versioned: std.builtin.Version,
    unversioned: void,
};

pub const Linkage = enum { dynamic, static };

pub const EmitOption = union(enum) {
    default: void,
    no_emit: void,
    emit: void,
    emit_to: []const u8,

    fn getArg(self: @This(), b: *Builder, arg_name: []const u8) ?[]const u8 {
        return switch (self) {
            .no_emit => b.fmt("-fno-{s}", .{arg_name}),
            .default => null,
            .emit => b.fmt("-f{s}", .{arg_name}),
            .emit_to => |path| b.fmt("-f{s}={s}", .{ arg_name, path }),
        };
    }
};

pub fn createSharedLibrary(builder: *Builder, name: []const u8, root_src: ?FileSource, kind: SharedLibKind) *LibExeObjStep {
    return initExtraArgs(builder, name, root_src, .lib, .dynamic, switch (kind) {
        .versioned => |ver| ver,
        .unversioned => null,
    });
}

pub fn createStaticLibrary(builder: *Builder, name: []const u8, root_src: ?FileSource) *LibExeObjStep {
    return initExtraArgs(builder, name, root_src, .lib, .static, null);
}

pub fn createObject(builder: *Builder, name: []const u8, root_src: ?FileSource) *LibExeObjStep {
    return initExtraArgs(builder, name, root_src, .obj, null, null);
}

pub fn createExecutable(builder: *Builder, name: []const u8, root_src: ?FileSource) *LibExeObjStep {
    return initExtraArgs(builder, name, root_src, .exe, null, null);
}

pub fn createTest(builder: *Builder, name: []const u8, root_src: FileSource) *LibExeObjStep {
    return initExtraArgs(builder, name, root_src, .@"test", null, null);
}

pub fn createTestExe(builder: *Builder, name: []const u8, root_src: FileSource) *LibExeObjStep {
    return initExtraArgs(builder, name, root_src, .test_exe, null, null);
}

fn initExtraArgs(
    builder: *Builder,
    name_raw: []const u8,
    root_src_raw: ?FileSource,
    kind: Kind,
    linkage: ?Linkage,
    ver: ?std.builtin.Version,
) *LibExeObjStep {
    const name = builder.dupe(name_raw);
    const root_src: ?FileSource = if (root_src_raw) |rsrc| rsrc.dupe(builder) else null;
    if (mem.indexOf(u8, name, "/") != null or mem.indexOf(u8, name, "\\") != null) {
        panic("invalid name: '{s}'. It looks like a file path, but it is supposed to be the library or application name.", .{name});
    }

    const self = builder.allocator.create(LibExeObjStep) catch unreachable;
    self.* = LibExeObjStep{
        .strip = null,
        .unwind_tables = null,
        .builder = builder,
        .verbose_link = false,
        .verbose_cc = false,
        .build_mode = std.builtin.Mode.Debug,
        .linkage = linkage,
        .kind = kind,
        .root_src = root_src,
        .name = name,
        .frameworks = StringHashMap(FrameworkLinkInfo).init(builder.allocator),
        .step = Step.init(base_id, name, builder.allocator, make),
        .version = ver,
        .out_filename = undefined,
        .out_h_filename = builder.fmt("{s}.h", .{name}),
        .out_lib_filename = undefined,
        .out_pdb_filename = builder.fmt("{s}.pdb", .{name}),
        .major_only_filename = null,
        .name_only_filename = null,
        .packages = ArrayList(Pkg).init(builder.allocator),
        .include_dirs = ArrayList(IncludeDir).init(builder.allocator),
        .link_objects = ArrayList(LinkObject).init(builder.allocator),
        .c_macros = ArrayList([]const u8).init(builder.allocator),
        .lib_paths = ArrayList([]const u8).init(builder.allocator),
        .rpaths = ArrayList([]const u8).init(builder.allocator),
        .framework_dirs = ArrayList([]const u8).init(builder.allocator),
        .object_src = undefined,
        .c_std = Builder.CStd.C99,
        .override_lib_dir = null,
        .main_pkg_path = null,
        .exec_cmd_args = null,
        .name_prefix = "",
        .filter = null,
        .test_runner = null,
        .disable_stack_probing = false,
        .disable_sanitize_c = false,
        .sanitize_thread = false,
        .rdynamic = false,
        .output_dir = null,
        .override_dest_dir = null,
        .installed_path = null,
        .install_step = null,

        .output_path_source = GeneratedFile{ .step = &self.step },
        .output_lib_path_source = GeneratedFile{ .step = &self.step },
        .output_h_path_source = GeneratedFile{ .step = &self.step },
        .output_pdb_path_source = GeneratedFile{ .step = &self.step },

        .target_info = undefined, // populated in computeOutFileNames
    };
    self.computeOutFileNames();
    if (root_src) |rs| rs.addStepDependencies(&self.step);
    return self;
}

fn computeOutFileNames(self: *LibExeObjStep) void {
    self.target_info = NativeTargetInfo.detect(self.target) catch
        unreachable;

    const target = self.target_info.target;

    self.out_filename = std.zig.binNameAlloc(self.builder.allocator, .{
        .root_name = self.name,
        .target = target,
        .output_mode = switch (self.kind) {
            .lib => .Lib,
            .obj => .Obj,
            .exe, .@"test", .test_exe => .Exe,
        },
        .link_mode = if (self.linkage) |some| @as(std.builtin.LinkMode, switch (some) {
            .dynamic => .Dynamic,
            .static => .Static,
        }) else null,
        .version = self.version,
    }) catch unreachable;

    if (self.kind == .lib) {
        if (self.linkage != null and self.linkage.? == .static) {
            self.out_lib_filename = self.out_filename;
        } else if (self.version) |version| {
            if (target.isDarwin()) {
                self.major_only_filename = self.builder.fmt("lib{s}.{d}.dylib", .{
                    self.name,
                    version.major,
                });
                self.name_only_filename = self.builder.fmt("lib{s}.dylib", .{self.name});
                self.out_lib_filename = self.out_filename;
            } else if (target.os.tag == .windows) {
                self.out_lib_filename = self.builder.fmt("{s}.lib", .{self.name});
            } else {
                self.major_only_filename = self.builder.fmt("lib{s}.so.{d}", .{ self.name, version.major });
                self.name_only_filename = self.builder.fmt("lib{s}.so", .{self.name});
                self.out_lib_filename = self.out_filename;
            }
        } else {
            if (target.isDarwin()) {
                self.out_lib_filename = self.out_filename;
            } else if (target.os.tag == .windows) {
                self.out_lib_filename = self.builder.fmt("{s}.lib", .{self.name});
            } else {
                self.out_lib_filename = self.out_filename;
            }
        }
        if (self.output_dir != null) {
            self.output_lib_path_source.path = self.builder.pathJoin(
                &.{ self.output_dir.?, self.out_lib_filename },
            );
        }
    }
}

pub fn setTarget(self: *LibExeObjStep, target: CrossTarget) void {
    self.target = target;
    self.computeOutFileNames();
}

pub fn setOutputDir(self: *LibExeObjStep, dir: []const u8) void {
    self.output_dir = self.builder.dupePath(dir);
}

pub fn install(self: *LibExeObjStep) void {
    self.builder.installArtifact(self);
}

pub fn installRaw(self: *LibExeObjStep, dest_filename: []const u8, options: InstallRawStep.CreateOptions) *InstallRawStep {
    return self.builder.installRaw(self, dest_filename, options);
}

/// Creates a `RunStep` with an executable built with `addExecutable`.
/// Add command line arguments with `addArg`.
pub fn run(exe: *LibExeObjStep) *RunStep {
    assert(exe.kind == .exe or exe.kind == .test_exe);

    // It doesn't have to be native. We catch that if you actually try to run it.
    // Consider that this is declarative; the run step may not be run unless a user
    // option is supplied.
    const run_step = RunStep.create(exe.builder, exe.builder.fmt("run {s}", .{exe.step.name}));
    run_step.addArtifactArg(exe);

    if (exe.kind == .test_exe) {
        run_step.addArg(exe.builder.zig_exe);
    }

    if (exe.vcpkg_bin_path) |path| {
        run_step.addPathDir(path);
    }

    return run_step;
}

/// Creates an `EmulatableRunStep` with an executable built with `addExecutable`.
/// Allows running foreign binaries through emulation platforms such as Qemu or Rosetta.
/// When a binary cannot be ran through emulation or the option is disabled, a warning
/// will be printed and the binary will *NOT* be ran.
pub fn runEmulatable(exe: *LibExeObjStep) *EmulatableRunStep {
    assert(exe.kind == .exe or exe.kind == .test_exe);

    const run_step = EmulatableRunStep.create(exe.builder, exe.builder.fmt("run {s}", .{exe.step.name}), exe);
    if (exe.vcpkg_bin_path) |path| {
        RunStep.addPathDirInternal(&run_step.step, exe.builder, path);
    }
    return run_step;
}

pub fn checkObject(self: *LibExeObjStep, obj_format: std.Target.ObjectFormat) *CheckObjectStep {
    return CheckObjectStep.create(self.builder, self.getOutputSource(), obj_format);
}

pub fn setLinkerScriptPath(self: *LibExeObjStep, source: FileSource) void {
    self.linker_script = source.dupe(self.builder);
    source.addStepDependencies(&self.step);
}

pub fn linkFramework(self: *LibExeObjStep, framework_name: []const u8) void {
    self.frameworks.put(self.builder.dupe(framework_name), .{}) catch unreachable;
}

pub fn linkFrameworkNeeded(self: *LibExeObjStep, framework_name: []const u8) void {
    self.frameworks.put(self.builder.dupe(framework_name), .{
        .needed = true,
    }) catch unreachable;
}

pub fn linkFrameworkWeak(self: *LibExeObjStep, framework_name: []const u8) void {
    self.frameworks.put(self.builder.dupe(framework_name), .{
        .weak = true,
    }) catch unreachable;
}

/// Returns whether the library, executable, or object depends on a particular system library.
pub fn dependsOnSystemLibrary(self: LibExeObjStep, name: []const u8) bool {
    if (isLibCLibrary(name)) {
        return self.is_linking_libc;
    }
    if (isLibCppLibrary(name)) {
        return self.is_linking_libcpp;
    }
    for (self.link_objects.items) |link_object| {
        switch (link_object) {
            .system_lib => |lib| if (mem.eql(u8, lib.name, name)) return true,
            else => continue,
        }
    }
    return false;
}

pub fn linkLibrary(self: *LibExeObjStep, lib: *LibExeObjStep) void {
    assert(lib.kind == .lib);
    self.linkLibraryOrObject(lib);
}

pub fn isDynamicLibrary(self: *LibExeObjStep) bool {
    return self.kind == .lib and self.linkage != null and self.linkage.? == .dynamic;
}

pub fn producesPdbFile(self: *LibExeObjStep) bool {
    if (!self.target.isWindows() and !self.target.isUefi()) return false;
    if (self.strip != null and self.strip.?) return false;
    return self.isDynamicLibrary() or self.kind == .exe or self.kind == .test_exe;
}

pub fn linkLibC(self: *LibExeObjStep) void {
    if (!self.is_linking_libc) {
        self.is_linking_libc = true;
        self.link_objects.append(.{
            .system_lib = .{
                .name = "c",
                .needed = false,
                .weak = false,
                .use_pkg_config = .no,
            },
        }) catch unreachable;
    }
}

pub fn linkLibCpp(self: *LibExeObjStep) void {
    if (!self.is_linking_libcpp) {
        self.is_linking_libcpp = true;
        self.link_objects.append(.{
            .system_lib = .{
                .name = "c++",
                .needed = false,
                .weak = false,
                .use_pkg_config = .no,
            },
        }) catch unreachable;
    }
}

/// If the value is omitted, it is set to 1.
/// `name` and `value` need not live longer than the function call.
pub fn defineCMacro(self: *LibExeObjStep, name: []const u8, value: ?[]const u8) void {
    const macro = std.build.constructCMacro(self.builder.allocator, name, value);
    self.c_macros.append(macro) catch unreachable;
}

/// name_and_value looks like [name]=[value]. If the value is omitted, it is set to 1.
pub fn defineCMacroRaw(self: *LibExeObjStep, name_and_value: []const u8) void {
    self.c_macros.append(self.builder.dupe(name_and_value)) catch unreachable;
}

/// This one has no integration with anything, it just puts -lname on the command line.
/// Prefer to use `linkSystemLibrary` instead.
pub fn linkSystemLibraryName(self: *LibExeObjStep, name: []const u8) void {
    self.link_objects.append(.{
        .system_lib = .{
            .name = self.builder.dupe(name),
            .needed = false,
            .weak = false,
            .use_pkg_config = .no,
        },
    }) catch unreachable;
}

/// This one has no integration with anything, it just puts -needed-lname on the command line.
/// Prefer to use `linkSystemLibraryNeeded` instead.
pub fn linkSystemLibraryNeededName(self: *LibExeObjStep, name: []const u8) void {
    self.link_objects.append(.{
        .system_lib = .{
            .name = self.builder.dupe(name),
            .needed = true,
            .weak = false,
            .use_pkg_config = .no,
        },
    }) catch unreachable;
}

/// Darwin-only. This one has no integration with anything, it just puts -weak-lname on the
/// command line. Prefer to use `linkSystemLibraryWeak` instead.
pub fn linkSystemLibraryWeakName(self: *LibExeObjStep, name: []const u8) void {
    self.link_objects.append(.{
        .system_lib = .{
            .name = self.builder.dupe(name),
            .needed = false,
            .weak = true,
            .use_pkg_config = .no,
        },
    }) catch unreachable;
}

/// This links against a system library, exclusively using pkg-config to find the library.
/// Prefer to use `linkSystemLibrary` instead.
pub fn linkSystemLibraryPkgConfigOnly(self: *LibExeObjStep, lib_name: []const u8) void {
    self.link_objects.append(.{
        .system_lib = .{
            .name = self.builder.dupe(lib_name),
            .needed = false,
            .weak = false,
            .use_pkg_config = .force,
        },
    }) catch unreachable;
}

/// This links against a system library, exclusively using pkg-config to find the library.
/// Prefer to use `linkSystemLibraryNeeded` instead.
pub fn linkSystemLibraryNeededPkgConfigOnly(self: *LibExeObjStep, lib_name: []const u8) void {
    self.link_objects.append(.{
        .system_lib = .{
            .name = self.builder.dupe(lib_name),
            .needed = true,
            .weak = false,
            .use_pkg_config = .force,
        },
    }) catch unreachable;
}

/// Run pkg-config for the given library name and parse the output, returning the arguments
/// that should be passed to zig to link the given library.
pub fn runPkgConfig(self: *LibExeObjStep, lib_name: []const u8) ![]const []const u8 {
    const pkg_name = match: {
        // First we have to map the library name to pkg config name. Unfortunately,
        // there are several examples where this is not straightforward:
        // -lSDL2 -> pkg-config sdl2
        // -lgdk-3 -> pkg-config gdk-3.0
        // -latk-1.0 -> pkg-config atk
        const pkgs = try getPkgConfigList(self.builder);

        // Exact match means instant winner.
        for (pkgs) |pkg| {
            if (mem.eql(u8, pkg.name, lib_name)) {
                break :match pkg.name;
            }
        }

        // Next we'll try ignoring case.
        for (pkgs) |pkg| {
            if (std.ascii.eqlIgnoreCase(pkg.name, lib_name)) {
                break :match pkg.name;
            }
        }

        // Now try appending ".0".
        for (pkgs) |pkg| {
            if (std.ascii.indexOfIgnoreCase(pkg.name, lib_name)) |pos| {
                if (pos != 0) continue;
                if (mem.eql(u8, pkg.name[lib_name.len..], ".0")) {
                    break :match pkg.name;
                }
            }
        }

        // Trimming "-1.0".
        if (mem.endsWith(u8, lib_name, "-1.0")) {
            const trimmed_lib_name = lib_name[0 .. lib_name.len - "-1.0".len];
            for (pkgs) |pkg| {
                if (std.ascii.eqlIgnoreCase(pkg.name, trimmed_lib_name)) {
                    break :match pkg.name;
                }
            }
        }

        return error.PackageNotFound;
    };

    var code: u8 = undefined;
    const stdout = if (self.builder.execAllowFail(&[_][]const u8{
        "pkg-config",
        pkg_name,
        "--cflags",
        "--libs",
    }, &code, .Ignore)) |stdout| stdout else |err| switch (err) {
        error.ProcessTerminated => return error.PkgConfigCrashed,
        error.ExecNotSupported => return error.PkgConfigFailed,
        error.ExitCodeFailure => return error.PkgConfigFailed,
        error.FileNotFound => return error.PkgConfigNotInstalled,
        error.ChildExecFailed => return error.PkgConfigFailed,
        else => return err,
    };

    var zig_args = std.ArrayList([]const u8).init(self.builder.allocator);
    defer zig_args.deinit();

    var it = mem.tokenize(u8, stdout, " \r\n\t");
    while (it.next()) |tok| {
        if (mem.eql(u8, tok, "-I")) {
            const dir = it.next() orelse return error.PkgConfigInvalidOutput;
            try zig_args.appendSlice(&[_][]const u8{ "-I", dir });
        } else if (mem.startsWith(u8, tok, "-I")) {
            try zig_args.append(tok);
        } else if (mem.eql(u8, tok, "-L")) {
            const dir = it.next() orelse return error.PkgConfigInvalidOutput;
            try zig_args.appendSlice(&[_][]const u8{ "-L", dir });
        } else if (mem.startsWith(u8, tok, "-L")) {
            try zig_args.append(tok);
        } else if (mem.eql(u8, tok, "-l")) {
            const lib = it.next() orelse return error.PkgConfigInvalidOutput;
            try zig_args.appendSlice(&[_][]const u8{ "-l", lib });
        } else if (mem.startsWith(u8, tok, "-l")) {
            try zig_args.append(tok);
        } else if (mem.eql(u8, tok, "-D")) {
            const macro = it.next() orelse return error.PkgConfigInvalidOutput;
            try zig_args.appendSlice(&[_][]const u8{ "-D", macro });
        } else if (mem.startsWith(u8, tok, "-D")) {
            try zig_args.append(tok);
        } else if (self.builder.verbose) {
            log.warn("Ignoring pkg-config flag '{s}'", .{tok});
        }
    }

    return zig_args.toOwnedSlice();
}

pub fn linkSystemLibrary(self: *LibExeObjStep, name: []const u8) void {
    self.linkSystemLibraryInner(name, .{});
}

pub fn linkSystemLibraryNeeded(self: *LibExeObjStep, name: []const u8) void {
    self.linkSystemLibraryInner(name, .{ .needed = true });
}

pub fn linkSystemLibraryWeak(self: *LibExeObjStep, name: []const u8) void {
    self.linkSystemLibraryInner(name, .{ .weak = true });
}

fn linkSystemLibraryInner(self: *LibExeObjStep, name: []const u8, opts: struct {
    needed: bool = false,
    weak: bool = false,
}) void {
    if (isLibCLibrary(name)) {
        self.linkLibC();
        return;
    }
    if (isLibCppLibrary(name)) {
        self.linkLibCpp();
        return;
    }

    self.link_objects.append(.{
        .system_lib = .{
            .name = self.builder.dupe(name),
            .needed = opts.needed,
            .weak = opts.weak,
            .use_pkg_config = .yes,
        },
    }) catch unreachable;
}

pub fn setNamePrefix(self: *LibExeObjStep, text: []const u8) void {
    assert(self.kind == .@"test" or self.kind == .test_exe);
    self.name_prefix = self.builder.dupe(text);
}

pub fn setFilter(self: *LibExeObjStep, text: ?[]const u8) void {
    assert(self.kind == .@"test" or self.kind == .test_exe);
    self.filter = if (text) |t| self.builder.dupe(t) else null;
}

pub fn setTestRunner(self: *LibExeObjStep, path: ?[]const u8) void {
    assert(self.kind == .@"test" or self.kind == .test_exe);
    self.test_runner = if (path) |p| self.builder.dupePath(p) else null;
}

/// Handy when you have many C/C++ source files and want them all to have the same flags.
pub fn addCSourceFiles(self: *LibExeObjStep, files: []const []const u8, flags: []const []const u8) void {
    const c_source_files = self.builder.allocator.create(CSourceFiles) catch unreachable;

    const files_copy = self.builder.dupeStrings(files);
    const flags_copy = self.builder.dupeStrings(flags);

    c_source_files.* = .{
        .files = files_copy,
        .flags = flags_copy,
    };
    self.link_objects.append(.{ .c_source_files = c_source_files }) catch unreachable;
}

pub fn addCSourceFile(self: *LibExeObjStep, file: []const u8, flags: []const []const u8) void {
    self.addCSourceFileSource(.{
        .args = flags,
        .source = .{ .path = file },
    });
}

pub fn addCSourceFileSource(self: *LibExeObjStep, source: CSourceFile) void {
    const c_source_file = self.builder.allocator.create(CSourceFile) catch unreachable;
    c_source_file.* = source.dupe(self.builder);
    self.link_objects.append(.{ .c_source_file = c_source_file }) catch unreachable;
    source.source.addStepDependencies(&self.step);
}

pub fn setVerboseLink(self: *LibExeObjStep, value: bool) void {
    self.verbose_link = value;
}

pub fn setVerboseCC(self: *LibExeObjStep, value: bool) void {
    self.verbose_cc = value;
}

pub fn setBuildMode(self: *LibExeObjStep, mode: std.builtin.Mode) void {
    self.build_mode = mode;
}

pub fn overrideZigLibDir(self: *LibExeObjStep, dir_path: []const u8) void {
    self.override_lib_dir = self.builder.dupePath(dir_path);
}

pub fn setMainPkgPath(self: *LibExeObjStep, dir_path: []const u8) void {
    self.main_pkg_path = self.builder.dupePath(dir_path);
}

pub fn setLibCFile(self: *LibExeObjStep, libc_file: ?FileSource) void {
    self.libc_file = if (libc_file) |f| f.dupe(self.builder) else null;
}

/// Returns the generated executable, library or object file.
/// To run an executable built with zig build, use `run`, or create an install step and invoke it.
pub fn getOutputSource(self: *LibExeObjStep) FileSource {
    return FileSource{ .generated = &self.output_path_source };
}

/// Returns the generated import library. This function can only be called for libraries.
pub fn getOutputLibSource(self: *LibExeObjStep) FileSource {
    assert(self.kind == .lib);
    return FileSource{ .generated = &self.output_lib_path_source };
}

/// Returns the generated header file.
/// This function can only be called for libraries or object files which have `emit_h` set.
pub fn getOutputHSource(self: *LibExeObjStep) FileSource {
    assert(self.kind != .exe and self.kind != .test_exe and self.kind != .@"test");
    assert(self.emit_h);
    return FileSource{ .generated = &self.output_h_path_source };
}

/// Returns the generated PDB file. This function can only be called for Windows and UEFI.
pub fn getOutputPdbSource(self: *LibExeObjStep) FileSource {
    // TODO: Is this right? Isn't PDB for *any* PE/COFF file?
    assert(self.target.isWindows() or self.target.isUefi());
    return FileSource{ .generated = &self.output_pdb_path_source };
}

pub fn addAssemblyFile(self: *LibExeObjStep, path: []const u8) void {
    self.link_objects.append(.{
        .assembly_file = .{ .path = self.builder.dupe(path) },
    }) catch unreachable;
}

pub fn addAssemblyFileSource(self: *LibExeObjStep, source: FileSource) void {
    const source_duped = source.dupe(self.builder);
    self.link_objects.append(.{ .assembly_file = source_duped }) catch unreachable;
    source_duped.addStepDependencies(&self.step);
}

pub fn addObjectFile(self: *LibExeObjStep, source_file: []const u8) void {
    self.addObjectFileSource(.{ .path = source_file });
}

pub fn addObjectFileSource(self: *LibExeObjStep, source: FileSource) void {
    self.link_objects.append(.{ .static_path = source.dupe(self.builder) }) catch unreachable;
    source.addStepDependencies(&self.step);
}

pub fn addObject(self: *LibExeObjStep, obj: *LibExeObjStep) void {
    assert(obj.kind == .obj);
    self.linkLibraryOrObject(obj);
}

pub const addSystemIncludeDir = @compileError("deprecated; use addSystemIncludePath");
pub const addIncludeDir = @compileError("deprecated; use addIncludePath");
pub const addLibPath = @compileError("deprecated, use addLibraryPath");
pub const addFrameworkDir = @compileError("deprecated, use addFrameworkPath");

pub fn addSystemIncludePath(self: *LibExeObjStep, path: []const u8) void {
    self.include_dirs.append(IncludeDir{ .raw_path_system = self.builder.dupe(path) }) catch unreachable;
}

pub fn addIncludePath(self: *LibExeObjStep, path: []const u8) void {
    self.include_dirs.append(IncludeDir{ .raw_path = self.builder.dupe(path) }) catch unreachable;
}

pub fn addLibraryPath(self: *LibExeObjStep, path: []const u8) void {
    self.lib_paths.append(self.builder.dupe(path)) catch unreachable;
}

pub fn addRPath(self: *LibExeObjStep, path: []const u8) void {
    self.rpaths.append(self.builder.dupe(path)) catch unreachable;
}

pub fn addFrameworkPath(self: *LibExeObjStep, dir_path: []const u8) void {
    self.framework_dirs.append(self.builder.dupe(dir_path)) catch unreachable;
}

pub fn addPackage(self: *LibExeObjStep, package: Pkg) void {
    self.packages.append(self.builder.dupePkg(package)) catch unreachable;
    self.addRecursiveBuildDeps(package);
}

pub fn addOptions(self: *LibExeObjStep, package_name: []const u8, options: *OptionsStep) void {
    self.addPackage(options.getPackage(package_name));
}

fn addRecursiveBuildDeps(self: *LibExeObjStep, package: Pkg) void {
    package.source.addStepDependencies(&self.step);
    if (package.dependencies) |deps| {
        for (deps) |dep| {
            self.addRecursiveBuildDeps(dep);
        }
    }
}

pub fn addPackagePath(self: *LibExeObjStep, name: []const u8, pkg_index_path: []const u8) void {
    self.addPackage(Pkg{
        .name = self.builder.dupe(name),
        .source = .{ .path = self.builder.dupe(pkg_index_path) },
    });
}

/// If Vcpkg was found on the system, it will be added to include and lib
/// paths for the specified target.
pub fn addVcpkgPaths(self: *LibExeObjStep, linkage: LibExeObjStep.Linkage) !void {
    // Ideally in the Unattempted case we would call the function recursively
    // after findVcpkgRoot and have only one switch statement, but the compiler
    // cannot resolve the error set.
    switch (self.builder.vcpkg_root) {
        .unattempted => {
            self.builder.vcpkg_root = if (try findVcpkgRoot(self.builder.allocator)) |root|
                VcpkgRoot{ .found = root }
            else
                .not_found;
        },
        .not_found => return error.VcpkgNotFound,
        .found => {},
    }

    switch (self.builder.vcpkg_root) {
        .unattempted => unreachable,
        .not_found => return error.VcpkgNotFound,
        .found => |root| {
            const allocator = self.builder.allocator;
            const triplet = try self.target.vcpkgTriplet(allocator, if (linkage == .static) .Static else .Dynamic);
            defer self.builder.allocator.free(triplet);

            const include_path = self.builder.pathJoin(&.{ root, "installed", triplet, "include" });
            errdefer allocator.free(include_path);
            try self.include_dirs.append(IncludeDir{ .raw_path = include_path });

            const lib_path = self.builder.pathJoin(&.{ root, "installed", triplet, "lib" });
            try self.lib_paths.append(lib_path);

            self.vcpkg_bin_path = self.builder.pathJoin(&.{ root, "installed", triplet, "bin" });
        },
    }
}

pub fn setExecCmd(self: *LibExeObjStep, args: []const ?[]const u8) void {
    assert(self.kind == .@"test");
    const duped_args = self.builder.allocator.alloc(?[]u8, args.len) catch unreachable;
    for (args) |arg, i| {
        duped_args[i] = if (arg) |a| self.builder.dupe(a) else null;
    }
    self.exec_cmd_args = duped_args;
}

fn linkLibraryOrObject(self: *LibExeObjStep, other: *LibExeObjStep) void {
    self.step.dependOn(&other.step);
    self.link_objects.append(.{ .other_step = other }) catch unreachable;
    self.include_dirs.append(.{ .other_step = other }) catch unreachable;
}

fn makePackageCmd(self: *LibExeObjStep, pkg: Pkg, zig_args: *ArrayList([]const u8)) error{OutOfMemory}!void {
    const builder = self.builder;

    try zig_args.append("--pkg-begin");
    try zig_args.append(pkg.name);
    try zig_args.append(builder.pathFromRoot(pkg.source.getPath(self.builder)));

    if (pkg.dependencies) |dependencies| {
        for (dependencies) |sub_pkg| {
            try self.makePackageCmd(sub_pkg, zig_args);
        }
    }

    try zig_args.append("--pkg-end");
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(LibExeObjStep, "step", step);
    const builder = self.builder;

    if (self.root_src == null and self.link_objects.items.len == 0) {
        log.err("{s}: linker needs 1 or more objects to link", .{self.step.name});
        return error.NeedAnObject;
    }

    var zig_args = ArrayList([]const u8).init(builder.allocator);
    defer zig_args.deinit();

    zig_args.append(builder.zig_exe) catch unreachable;

    const cmd = switch (self.kind) {
        .lib => "build-lib",
        .exe => "build-exe",
        .obj => "build-obj",
        .@"test" => "test",
        .test_exe => "test",
    };
    zig_args.append(cmd) catch unreachable;

    if (builder.color != .auto) {
        try zig_args.append("--color");
        try zig_args.append(@tagName(builder.color));
    }

    if (builder.reference_trace) |some| {
        try zig_args.append(try std.fmt.allocPrint(builder.allocator, "-freference-trace={d}", .{some}));
    }

    if (self.use_llvm) |use_llvm| {
        if (use_llvm) {
            try zig_args.append("-fLLVM");
        } else {
            try zig_args.append("-fno-LLVM");
        }
    }

    if (self.use_lld) |use_lld| {
        if (use_lld) {
            try zig_args.append("-fLLD");
        } else {
            try zig_args.append("-fno-LLD");
        }
    }

    if (self.target.ofmt) |ofmt| {
        try zig_args.append(try std.fmt.allocPrint(builder.allocator, "-ofmt={s}", .{@tagName(ofmt)}));
    }

    if (self.entry_symbol_name) |entry| {
        try zig_args.append("--entry");
        try zig_args.append(entry);
    }

    if (self.stack_size) |stack_size| {
        try zig_args.append("--stack");
        try zig_args.append(try std.fmt.allocPrint(builder.allocator, "{}", .{stack_size}));
    }

    if (self.root_src) |root_src| try zig_args.append(root_src.getPath(builder));

    var prev_has_extra_flags = false;

    // Resolve transitive dependencies
    {
        var transitive_dependencies = std.ArrayList(LinkObject).init(builder.allocator);
        defer transitive_dependencies.deinit();

        for (self.link_objects.items) |link_object| {
            switch (link_object) {
                .other_step => |other| {
                    // Inherit dependency on system libraries
                    for (other.link_objects.items) |other_link_object| {
                        switch (other_link_object) {
                            .system_lib => try transitive_dependencies.append(other_link_object),
                            else => continue,
                        }
                    }

                    // Inherit dependencies on darwin frameworks
                    if (!other.isDynamicLibrary()) {
                        var it = other.frameworks.iterator();
                        while (it.next()) |framework| {
                            self.frameworks.put(framework.key_ptr.*, framework.value_ptr.*) catch unreachable;
                        }
                    }
                },
                else => continue,
            }
        }

        try self.link_objects.appendSlice(transitive_dependencies.items);
    }

    for (self.link_objects.items) |link_object| {
        switch (link_object) {
            .static_path => |static_path| try zig_args.append(static_path.getPath(builder)),

            .other_step => |other| switch (other.kind) {
                .exe => @panic("Cannot link with an executable build artifact"),
                .test_exe => @panic("Cannot link with an executable build artifact"),
                .@"test" => @panic("Cannot link with a test"),
                .obj => {
                    try zig_args.append(other.getOutputSource().getPath(builder));
                },
                .lib => {
                    const full_path_lib = other.getOutputLibSource().getPath(builder);
                    try zig_args.append(full_path_lib);

                    if (other.linkage != null and other.linkage.? == .dynamic and !self.target.isWindows()) {
                        if (fs.path.dirname(full_path_lib)) |dirname| {
                            try zig_args.append("-rpath");
                            try zig_args.append(dirname);
                        }
                    }
                },
            },

            .system_lib => |system_lib| {
                const prefix: []const u8 = prefix: {
                    if (system_lib.needed) break :prefix "-needed-l";
                    if (system_lib.weak) {
                        if (self.target.isDarwin()) break :prefix "-weak-l";
                        log.warn("Weak library import used for a non-darwin target, this will be converted to normally library import `-lname`", .{});
                    }
                    break :prefix "-l";
                };
                switch (system_lib.use_pkg_config) {
                    .no => try zig_args.append(builder.fmt("{s}{s}", .{ prefix, system_lib.name })),
                    .yes, .force => {
                        if (self.runPkgConfig(system_lib.name)) |args| {
                            try zig_args.appendSlice(args);
                        } else |err| switch (err) {
                            error.PkgConfigInvalidOutput,
                            error.PkgConfigCrashed,
                            error.PkgConfigFailed,
                            error.PkgConfigNotInstalled,
                            error.PackageNotFound,
                            => switch (system_lib.use_pkg_config) {
                                .yes => {
                                    // pkg-config failed, so fall back to linking the library
                                    // by name directly.
                                    try zig_args.append(builder.fmt("{s}{s}", .{
                                        prefix,
                                        system_lib.name,
                                    }));
                                },
                                .force => {
                                    panic("pkg-config failed for library {s}", .{system_lib.name});
                                },
                                .no => unreachable,
                            },

                            else => |e| return e,
                        }
                    },
                }
            },

            .assembly_file => |asm_file| {
                if (prev_has_extra_flags) {
                    try zig_args.append("-extra-cflags");
                    try zig_args.append("--");
                    prev_has_extra_flags = false;
                }
                try zig_args.append(asm_file.getPath(builder));
            },

            .c_source_file => |c_source_file| {
                if (c_source_file.args.len == 0) {
                    if (prev_has_extra_flags) {
                        try zig_args.append("-cflags");
                        try zig_args.append("--");
                        prev_has_extra_flags = false;
                    }
                } else {
                    try zig_args.append("-cflags");
                    for (c_source_file.args) |arg| {
                        try zig_args.append(arg);
                    }
                    try zig_args.append("--");
                }
                try zig_args.append(c_source_file.source.getPath(builder));
            },

            .c_source_files => |c_source_files| {
                if (c_source_files.flags.len == 0) {
                    if (prev_has_extra_flags) {
                        try zig_args.append("-cflags");
                        try zig_args.append("--");
                        prev_has_extra_flags = false;
                    }
                } else {
                    try zig_args.append("-cflags");
                    for (c_source_files.flags) |flag| {
                        try zig_args.append(flag);
                    }
                    try zig_args.append("--");
                }
                for (c_source_files.files) |file| {
                    try zig_args.append(builder.pathFromRoot(file));
                }
            },
        }
    }

    if (self.image_base) |image_base| {
        try zig_args.append("--image-base");
        try zig_args.append(builder.fmt("0x{x}", .{image_base}));
    }

    if (self.filter) |filter| {
        try zig_args.append("--test-filter");
        try zig_args.append(filter);
    }

    if (self.test_evented_io) {
        try zig_args.append("--test-evented-io");
    }

    if (self.name_prefix.len != 0) {
        try zig_args.append("--test-name-prefix");
        try zig_args.append(self.name_prefix);
    }

    if (self.test_runner) |test_runner| {
        try zig_args.append("--test-runner");
        try zig_args.append(builder.pathFromRoot(test_runner));
    }

    for (builder.debug_log_scopes) |log_scope| {
        try zig_args.append("--debug-log");
        try zig_args.append(log_scope);
    }

    if (builder.debug_compile_errors) {
        try zig_args.append("--debug-compile-errors");
    }

    if (builder.verbose_cimport) zig_args.append("--verbose-cimport") catch unreachable;
    if (builder.verbose_air) zig_args.append("--verbose-air") catch unreachable;
    if (builder.verbose_llvm_ir) zig_args.append("--verbose-llvm-ir") catch unreachable;
    if (builder.verbose_link or self.verbose_link) zig_args.append("--verbose-link") catch unreachable;
    if (builder.verbose_cc or self.verbose_cc) zig_args.append("--verbose-cc") catch unreachable;
    if (builder.verbose_llvm_cpu_features) zig_args.append("--verbose-llvm-cpu-features") catch unreachable;

    if (self.emit_analysis.getArg(builder, "emit-analysis")) |arg| try zig_args.append(arg);
    if (self.emit_asm.getArg(builder, "emit-asm")) |arg| try zig_args.append(arg);
    if (self.emit_bin.getArg(builder, "emit-bin")) |arg| try zig_args.append(arg);
    if (self.emit_docs.getArg(builder, "emit-docs")) |arg| try zig_args.append(arg);
    if (self.emit_implib.getArg(builder, "emit-implib")) |arg| try zig_args.append(arg);
    if (self.emit_llvm_bc.getArg(builder, "emit-llvm-bc")) |arg| try zig_args.append(arg);
    if (self.emit_llvm_ir.getArg(builder, "emit-llvm-ir")) |arg| try zig_args.append(arg);

    if (self.emit_h) try zig_args.append("-femit-h");

    if (self.strip) |strip| {
        if (strip) {
            try zig_args.append("-fstrip");
        } else {
            try zig_args.append("-fno-strip");
        }
    }

    if (self.unwind_tables) |unwind_tables| {
        if (unwind_tables) {
            try zig_args.append("-funwind-tables");
        } else {
            try zig_args.append("-fno-unwind-tables");
        }
    }

    switch (self.compress_debug_sections) {
        .none => {},
        .zlib => try zig_args.append("--compress-debug-sections=zlib"),
    }

    if (self.link_eh_frame_hdr) {
        try zig_args.append("--eh-frame-hdr");
    }
    if (self.link_emit_relocs) {
        try zig_args.append("--emit-relocs");
    }
    if (self.link_function_sections) {
        try zig_args.append("-ffunction-sections");
    }
    if (self.link_gc_sections) |x| {
        try zig_args.append(if (x) "--gc-sections" else "--no-gc-sections");
    }
    if (self.linker_allow_shlib_undefined) |x| {
        try zig_args.append(if (x) "-fallow-shlib-undefined" else "-fno-allow-shlib-undefined");
    }
    if (self.link_z_notext) {
        try zig_args.append("-z");
        try zig_args.append("notext");
    }
    if (!self.link_z_relro) {
        try zig_args.append("-z");
        try zig_args.append("norelro");
    }
    if (self.link_z_lazy) {
        try zig_args.append("-z");
        try zig_args.append("lazy");
    }

    if (self.libc_file) |libc_file| {
        try zig_args.append("--libc");
        try zig_args.append(libc_file.getPath(self.builder));
    } else if (builder.libc_file) |libc_file| {
        try zig_args.append("--libc");
        try zig_args.append(libc_file);
    }

    switch (self.build_mode) {
        .Debug => {}, // Skip since it's the default.
        else => zig_args.append(builder.fmt("-O{s}", .{@tagName(self.build_mode)})) catch unreachable,
    }

    try zig_args.append("--cache-dir");
    try zig_args.append(builder.pathFromRoot(builder.cache_root));

    try zig_args.append("--global-cache-dir");
    try zig_args.append(builder.pathFromRoot(builder.global_cache_root));

    zig_args.append("--name") catch unreachable;
    zig_args.append(self.name) catch unreachable;

    if (self.linkage) |some| switch (some) {
        .dynamic => try zig_args.append("-dynamic"),
        .static => try zig_args.append("-static"),
    };
    if (self.kind == .lib and self.linkage != null and self.linkage.? == .dynamic) {
        if (self.version) |version| {
            zig_args.append("--version") catch unreachable;
            zig_args.append(builder.fmt("{}", .{version})) catch unreachable;
        }

        if (self.target.isDarwin()) {
            const install_name = self.install_name orelse builder.fmt("@rpath/{s}{s}{s}", .{
                self.target.libPrefix(),
                self.name,
                self.target.dynamicLibSuffix(),
            });
            try zig_args.append("-install_name");
            try zig_args.append(install_name);
        }
    }

    if (self.entitlements) |entitlements| {
        try zig_args.appendSlice(&[_][]const u8{ "--entitlements", entitlements });
    }
    if (self.pagezero_size) |pagezero_size| {
        const size = try std.fmt.allocPrint(builder.allocator, "{x}", .{pagezero_size});
        try zig_args.appendSlice(&[_][]const u8{ "-pagezero_size", size });
    }
    if (self.search_strategy) |strat| switch (strat) {
        .paths_first => try zig_args.append("-search_paths_first"),
        .dylibs_first => try zig_args.append("-search_dylibs_first"),
    };
    if (self.headerpad_size) |headerpad_size| {
        const size = try std.fmt.allocPrint(builder.allocator, "{x}", .{headerpad_size});
        try zig_args.appendSlice(&[_][]const u8{ "-headerpad", size });
    }
    if (self.headerpad_max_install_names) {
        try zig_args.append("-headerpad_max_install_names");
    }
    if (self.dead_strip_dylibs) {
        try zig_args.append("-dead_strip_dylibs");
    }

    if (self.bundle_compiler_rt) |x| {
        if (x) {
            try zig_args.append("-fcompiler-rt");
        } else {
            try zig_args.append("-fno-compiler-rt");
        }
    }
    if (self.single_threaded) |single_threaded| {
        if (single_threaded) {
            try zig_args.append("-fsingle-threaded");
        } else {
            try zig_args.append("-fno-single-threaded");
        }
    }
    if (self.disable_stack_probing) {
        try zig_args.append("-fno-stack-check");
    }
    if (self.stack_protector) |stack_protector| {
        if (stack_protector) {
            try zig_args.append("-fstack-protector");
        } else {
            try zig_args.append("-fno-stack-protector");
        }
    }
    if (self.red_zone) |red_zone| {
        if (red_zone) {
            try zig_args.append("-mred-zone");
        } else {
            try zig_args.append("-mno-red-zone");
        }
    }
    if (self.omit_frame_pointer) |omit_frame_pointer| {
        if (omit_frame_pointer) {
            try zig_args.append("-fomit-frame-pointer");
        } else {
            try zig_args.append("-fno-omit-frame-pointer");
        }
    }
    if (self.dll_export_fns) |dll_export_fns| {
        if (dll_export_fns) {
            try zig_args.append("-fdll-export-fns");
        } else {
            try zig_args.append("-fno-dll-export-fns");
        }
    }
    if (self.disable_sanitize_c) {
        try zig_args.append("-fno-sanitize-c");
    }
    if (self.sanitize_thread) {
        try zig_args.append("-fsanitize-thread");
    }
    if (self.rdynamic) {
        try zig_args.append("-rdynamic");
    }
    if (self.import_memory) {
        try zig_args.append("--import-memory");
    }
    if (self.import_table) {
        try zig_args.append("--import-table");
    }
    if (self.export_table) {
        try zig_args.append("--export-table");
    }
    if (self.initial_memory) |initial_memory| {
        try zig_args.append(builder.fmt("--initial-memory={d}", .{initial_memory}));
    }
    if (self.max_memory) |max_memory| {
        try zig_args.append(builder.fmt("--max-memory={d}", .{max_memory}));
    }
    if (self.shared_memory) {
        try zig_args.append("--shared-memory");
    }
    if (self.global_base) |global_base| {
        try zig_args.append(builder.fmt("--global-base={d}", .{global_base}));
    }

    if (self.code_model != .default) {
        try zig_args.append("-mcmodel");
        try zig_args.append(@tagName(self.code_model));
    }
    if (self.wasi_exec_model) |model| {
        try zig_args.append(builder.fmt("-mexec-model={s}", .{@tagName(model)}));
    }
    for (self.export_symbol_names) |symbol_name| {
        try zig_args.append(builder.fmt("--export={s}", .{symbol_name}));
    }

    if (!self.target.isNative()) {
        try zig_args.append("-target");
        try zig_args.append(try self.target.zigTriple(builder.allocator));

        // TODO this logic can disappear if cpu model + features becomes part of the target triple
        const cross = self.target.toTarget();
        const all_features = cross.cpu.arch.allFeaturesList();
        var populated_cpu_features = cross.cpu.model.features;
        populated_cpu_features.populateDependencies(all_features);

        if (populated_cpu_features.eql(cross.cpu.features)) {
            // The CPU name alone is sufficient.
            try zig_args.append("-mcpu");
            try zig_args.append(cross.cpu.model.name);
        } else {
            var mcpu_buffer = std.ArrayList(u8).init(builder.allocator);

            try mcpu_buffer.writer().print("-mcpu={s}", .{cross.cpu.model.name});

            for (all_features) |feature, i_usize| {
                const i = @intCast(std.Target.Cpu.Feature.Set.Index, i_usize);
                const in_cpu_set = populated_cpu_features.isEnabled(i);
                const in_actual_set = cross.cpu.features.isEnabled(i);
                if (in_cpu_set and !in_actual_set) {
                    try mcpu_buffer.writer().print("-{s}", .{feature.name});
                } else if (!in_cpu_set and in_actual_set) {
                    try mcpu_buffer.writer().print("+{s}", .{feature.name});
                }
            }

            try zig_args.append(try mcpu_buffer.toOwnedSlice());
        }

        if (self.target.dynamic_linker.get()) |dynamic_linker| {
            try zig_args.append("--dynamic-linker");
            try zig_args.append(dynamic_linker);
        }
    }

    if (self.linker_script) |linker_script| {
        try zig_args.append("--script");
        try zig_args.append(linker_script.getPath(builder));
    }

    if (self.version_script) |version_script| {
        try zig_args.append("--version-script");
        try zig_args.append(builder.pathFromRoot(version_script));
    }

    if (self.kind == .@"test") {
        if (self.exec_cmd_args) |exec_cmd_args| {
            for (exec_cmd_args) |cmd_arg| {
                if (cmd_arg) |arg| {
                    try zig_args.append("--test-cmd");
                    try zig_args.append(arg);
                } else {
                    try zig_args.append("--test-cmd-bin");
                }
            }
        } else {
            const need_cross_glibc = self.target.isGnuLibC() and self.is_linking_libc;

            switch (self.builder.host.getExternalExecutor(self.target_info, .{
                .qemu_fixes_dl = need_cross_glibc and builder.glibc_runtimes_dir != null,
                .link_libc = self.is_linking_libc,
            })) {
                .native => {},
                .bad_dl, .bad_os_or_cpu => {
                    try zig_args.append("--test-no-exec");
                },
                .rosetta => if (builder.enable_rosetta) {
                    try zig_args.append("--test-cmd-bin");
                } else {
                    try zig_args.append("--test-no-exec");
                },
                .qemu => |bin_name| ok: {
                    if (builder.enable_qemu) qemu: {
                        const glibc_dir_arg = if (need_cross_glibc)
                            builder.glibc_runtimes_dir orelse break :qemu
                        else
                            null;
                        try zig_args.append("--test-cmd");
                        try zig_args.append(bin_name);
                        if (glibc_dir_arg) |dir| {
                            // TODO look into making this a call to `linuxTriple`. This
                            // needs the directory to be called "i686" rather than
                            // "x86" which is why we do it manually here.
                            const fmt_str = "{s}" ++ fs.path.sep_str ++ "{s}-{s}-{s}";
                            const cpu_arch = self.target.getCpuArch();
                            const os_tag = self.target.getOsTag();
                            const abi = self.target.getAbi();
                            const cpu_arch_name: []const u8 = if (cpu_arch == .x86)
                                "i686"
                            else
                                @tagName(cpu_arch);
                            const full_dir = try std.fmt.allocPrint(builder.allocator, fmt_str, .{
                                dir, cpu_arch_name, @tagName(os_tag), @tagName(abi),
                            });

                            try zig_args.append("--test-cmd");
                            try zig_args.append("-L");
                            try zig_args.append("--test-cmd");
                            try zig_args.append(full_dir);
                        }
                        try zig_args.append("--test-cmd-bin");
                        break :ok;
                    }
                    try zig_args.append("--test-no-exec");
                },
                .wine => |bin_name| if (builder.enable_wine) {
                    try zig_args.append("--test-cmd");
                    try zig_args.append(bin_name);
                    try zig_args.append("--test-cmd-bin");
                } else {
                    try zig_args.append("--test-no-exec");
                },
                .wasmtime => |bin_name| if (builder.enable_wasmtime) {
                    try zig_args.append("--test-cmd");
                    try zig_args.append(bin_name);
                    try zig_args.append("--test-cmd");
                    try zig_args.append("--dir=.");
                    try zig_args.append("--test-cmd");
                    try zig_args.append("--allow-unknown-exports"); // TODO: Remove when stage2 is default compiler
                    try zig_args.append("--test-cmd-bin");
                } else {
                    try zig_args.append("--test-no-exec");
                },
                .darling => |bin_name| if (builder.enable_darling) {
                    try zig_args.append("--test-cmd");
                    try zig_args.append(bin_name);
                    try zig_args.append("--test-cmd-bin");
                } else {
                    try zig_args.append("--test-no-exec");
                },
            }
        }
    } else if (self.kind == .test_exe) {
        try zig_args.append("--test-no-exec");
    }

    for (self.packages.items) |pkg| {
        try self.makePackageCmd(pkg, &zig_args);
    }

    for (self.include_dirs.items) |include_dir| {
        switch (include_dir) {
            .raw_path => |include_path| {
                try zig_args.append("-I");
                try zig_args.append(self.builder.pathFromRoot(include_path));
            },
            .raw_path_system => |include_path| {
                if (builder.sysroot != null) {
                    try zig_args.append("-iwithsysroot");
                } else {
                    try zig_args.append("-isystem");
                }

                const resolved_include_path = self.builder.pathFromRoot(include_path);

                const common_include_path = if (builtin.os.tag == .windows and builder.sysroot != null and fs.path.isAbsolute(resolved_include_path)) blk: {
                    // We need to check for disk designator and strip it out from dir path so
                    // that zig/clang can concat resolved_include_path with sysroot.
                    const disk_designator = fs.path.diskDesignatorWindows(resolved_include_path);

                    if (mem.indexOf(u8, resolved_include_path, disk_designator)) |where| {
                        break :blk resolved_include_path[where + disk_designator.len ..];
                    }

                    break :blk resolved_include_path;
                } else resolved_include_path;

                try zig_args.append(common_include_path);
            },
            .other_step => |other| if (other.emit_h) {
                const h_path = other.getOutputHSource().getPath(self.builder);
                try zig_args.append("-isystem");
                try zig_args.append(fs.path.dirname(h_path).?);
            },
        }
    }

    for (self.lib_paths.items) |lib_path| {
        try zig_args.append("-L");
        try zig_args.append(lib_path);
    }

    for (self.rpaths.items) |rpath| {
        try zig_args.append("-rpath");
        try zig_args.append(rpath);
    }

    for (self.c_macros.items) |c_macro| {
        try zig_args.append("-D");
        try zig_args.append(c_macro);
    }

    if (self.target.isDarwin()) {
        for (self.framework_dirs.items) |dir| {
            if (builder.sysroot != null) {
                try zig_args.append("-iframeworkwithsysroot");
            } else {
                try zig_args.append("-iframework");
            }
            try zig_args.append(dir);
            try zig_args.append("-F");
            try zig_args.append(dir);
        }

        var it = self.frameworks.iterator();
        while (it.next()) |entry| {
            const name = entry.key_ptr.*;
            const info = entry.value_ptr.*;
            if (info.needed) {
                zig_args.append("-needed_framework") catch unreachable;
            } else if (info.weak) {
                zig_args.append("-weak_framework") catch unreachable;
            } else {
                zig_args.append("-framework") catch unreachable;
            }
            zig_args.append(name) catch unreachable;
        }
    } else {
        if (self.framework_dirs.items.len > 0) {
            log.info("Framework directories have been added for a non-darwin target, this will have no affect on the build", .{});
        }

        if (self.frameworks.count() > 0) {
            log.info("Frameworks have been added for a non-darwin target, this will have no affect on the build", .{});
        }
    }

    if (builder.sysroot) |sysroot| {
        try zig_args.appendSlice(&[_][]const u8{ "--sysroot", sysroot });
    }

    for (builder.search_prefixes.items) |search_prefix| {
        try zig_args.append("-L");
        try zig_args.append(builder.pathJoin(&.{
            search_prefix, "lib",
        }));
        try zig_args.append("-I");
        try zig_args.append(builder.pathJoin(&.{
            search_prefix, "include",
        }));
    }

    if (self.valgrind_support) |valgrind_support| {
        if (valgrind_support) {
            try zig_args.append("-fvalgrind");
        } else {
            try zig_args.append("-fno-valgrind");
        }
    }

    if (self.each_lib_rpath) |each_lib_rpath| {
        if (each_lib_rpath) {
            try zig_args.append("-feach-lib-rpath");
        } else {
            try zig_args.append("-fno-each-lib-rpath");
        }
    }

    if (self.build_id) |build_id| {
        if (build_id) {
            try zig_args.append("-fbuild-id");
        } else {
            try zig_args.append("-fno-build-id");
        }
    }

    if (self.override_lib_dir) |dir| {
        try zig_args.append("--zig-lib-dir");
        try zig_args.append(builder.pathFromRoot(dir));
    } else if (self.builder.override_lib_dir) |dir| {
        try zig_args.append("--zig-lib-dir");
        try zig_args.append(builder.pathFromRoot(dir));
    }

    if (self.main_pkg_path) |dir| {
        try zig_args.append("--main-pkg-path");
        try zig_args.append(builder.pathFromRoot(dir));
    }

    if (self.force_pic) |pic| {
        if (pic) {
            try zig_args.append("-fPIC");
        } else {
            try zig_args.append("-fno-PIC");
        }
    }

    if (self.pie) |pie| {
        if (pie) {
            try zig_args.append("-fPIE");
        } else {
            try zig_args.append("-fno-PIE");
        }
    }

    if (self.want_lto) |lto| {
        if (lto) {
            try zig_args.append("-flto");
        } else {
            try zig_args.append("-fno-lto");
        }
    }

    if (self.subsystem) |subsystem| {
        try zig_args.append("--subsystem");
        try zig_args.append(switch (subsystem) {
            .Console => "console",
            .Windows => "windows",
            .Posix => "posix",
            .Native => "native",
            .EfiApplication => "efi_application",
            .EfiBootServiceDriver => "efi_boot_service_driver",
            .EfiRom => "efi_rom",
            .EfiRuntimeDriver => "efi_runtime_driver",
        });
    }

    try zig_args.append("--enable-cache");

    // Windows has an argument length limit of 32,766 characters, macOS 262,144 and Linux
    // 2,097,152. If our args exceed 30 KiB, we instead write them to a "response file" and
    // pass that to zig, e.g. via 'zig build-lib @args.rsp'
    // See @file syntax here: https://gcc.gnu.org/onlinedocs/gcc/Overall-Options.html
    var args_length: usize = 0;
    for (zig_args.items) |arg| {
        args_length += arg.len + 1; // +1 to account for null terminator
    }
    if (args_length >= 30 * 1024) {
        const args_dir = try fs.path.join(
            builder.allocator,
            &[_][]const u8{ builder.pathFromRoot("zig-cache"), "args" },
        );
        try std.fs.cwd().makePath(args_dir);

        var args_arena = std.heap.ArenaAllocator.init(builder.allocator);
        defer args_arena.deinit();

        const args_to_escape = zig_args.items[2..];
        var escaped_args = try ArrayList([]const u8).initCapacity(args_arena.allocator(), args_to_escape.len);

        arg_blk: for (args_to_escape) |arg| {
            for (arg) |c, arg_idx| {
                if (c == '\\' or c == '"') {
                    // Slow path for arguments that need to be escaped. We'll need to allocate and copy
                    var escaped = try ArrayList(u8).initCapacity(args_arena.allocator(), arg.len + 1);
                    const writer = escaped.writer();
                    writer.writeAll(arg[0..arg_idx]) catch unreachable;
                    for (arg[arg_idx..]) |to_escape| {
                        if (to_escape == '\\' or to_escape == '"') try writer.writeByte('\\');
                        try writer.writeByte(to_escape);
                    }
                    escaped_args.appendAssumeCapacity(escaped.items);
                    continue :arg_blk;
                }
            }
            escaped_args.appendAssumeCapacity(arg); // no escaping needed so just use original argument
        }

        // Write the args to zig-cache/args/<SHA256 hash of args> to avoid conflicts with
        // other zig build commands running in parallel.
        const partially_quoted = try std.mem.join(builder.allocator, "\" \"", escaped_args.items);
        const args = try std.mem.concat(builder.allocator, u8, &[_][]const u8{ "\"", partially_quoted, "\"" });

        var args_hash: [Sha256.digest_length]u8 = undefined;
        Sha256.hash(args, &args_hash, .{});
        var args_hex_hash: [Sha256.digest_length * 2]u8 = undefined;
        _ = try std.fmt.bufPrint(
            &args_hex_hash,
            "{s}",
            .{std.fmt.fmtSliceHexLower(&args_hash)},
        );

        const args_file = try fs.path.join(builder.allocator, &[_][]const u8{ args_dir, args_hex_hash[0..] });
        try std.fs.cwd().writeFile(args_file, args);

        zig_args.shrinkRetainingCapacity(2);
        try zig_args.append(try std.mem.concat(builder.allocator, u8, &[_][]const u8{ "@", args_file }));
    }

    const output_dir_nl = try builder.execFromStep(zig_args.items, &self.step);
    const build_output_dir = mem.trimRight(u8, output_dir_nl, "\r\n");

    if (self.output_dir) |output_dir| {
        var src_dir = try std.fs.cwd().openIterableDir(build_output_dir, .{});
        defer src_dir.close();

        // Create the output directory if it doesn't exist.
        try std.fs.cwd().makePath(output_dir);

        var dest_dir = try std.fs.cwd().openDir(output_dir, .{});
        defer dest_dir.close();

        var it = src_dir.iterate();
        while (try it.next()) |entry| {
            // The compiler can put these files into the same directory, but we don't
            // want to copy them over.
            if (mem.eql(u8, entry.name, "llvm-ar.id") or
                mem.eql(u8, entry.name, "libs.txt") or
                mem.eql(u8, entry.name, "builtin.zig") or
                mem.eql(u8, entry.name, "zld.id") or
                mem.eql(u8, entry.name, "lld.id")) continue;

            _ = try src_dir.dir.updateFile(entry.name, dest_dir, entry.name, .{});
        }
    } else {
        self.output_dir = build_output_dir;
    }

    // This will ensure all output filenames will now have the output_dir available!
    self.computeOutFileNames();

    // Update generated files
    if (self.output_dir != null) {
        self.output_path_source.path = builder.pathJoin(
            &.{ self.output_dir.?, self.out_filename },
        );

        if (self.emit_h) {
            self.output_h_path_source.path = builder.pathJoin(
                &.{ self.output_dir.?, self.out_h_filename },
            );
        }

        if (self.target.isWindows() or self.target.isUefi()) {
            self.output_pdb_path_source.path = builder.pathJoin(
                &.{ self.output_dir.?, self.out_pdb_filename },
            );
        }
    }

    if (self.kind == .lib and self.linkage != null and self.linkage.? == .dynamic and self.version != null and self.target.wantSharedLibSymLinks()) {
        try doAtomicSymLinks(builder.allocator, self.getOutputSource().getPath(builder), self.major_only_filename.?, self.name_only_filename.?);
    }
}

fn isLibCLibrary(name: []const u8) bool {
    const libc_libraries = [_][]const u8{ "c", "m", "dl", "rt", "pthread" };
    for (libc_libraries) |libc_lib_name| {
        if (mem.eql(u8, name, libc_lib_name))
            return true;
    }
    return false;
}

fn isLibCppLibrary(name: []const u8) bool {
    const libcpp_libraries = [_][]const u8{ "c++", "stdc++" };
    for (libcpp_libraries) |libcpp_lib_name| {
        if (mem.eql(u8, name, libcpp_lib_name))
            return true;
    }
    return false;
}

/// Returned slice must be freed by the caller.
fn findVcpkgRoot(allocator: Allocator) !?[]const u8 {
    const appdata_path = try fs.getAppDataDir(allocator, "vcpkg");
    defer allocator.free(appdata_path);

    const path_file = try fs.path.join(allocator, &[_][]const u8{ appdata_path, "vcpkg.path.txt" });
    defer allocator.free(path_file);

    const file = fs.cwd().openFile(path_file, .{}) catch return null;
    defer file.close();

    const size = @intCast(usize, try file.getEndPos());
    const vcpkg_path = try allocator.alloc(u8, size);
    const size_read = try file.read(vcpkg_path);
    std.debug.assert(size == size_read);

    return vcpkg_path;
}

pub fn doAtomicSymLinks(allocator: Allocator, output_path: []const u8, filename_major_only: []const u8, filename_name_only: []const u8) !void {
    const out_dir = fs.path.dirname(output_path) orelse ".";
    const out_basename = fs.path.basename(output_path);
    // sym link for libfoo.so.1 to libfoo.so.1.2.3
    const major_only_path = fs.path.join(
        allocator,
        &[_][]const u8{ out_dir, filename_major_only },
    ) catch unreachable;
    fs.atomicSymLink(allocator, out_basename, major_only_path) catch |err| {
        log.err("Unable to symlink {s} -> {s}", .{ major_only_path, out_basename });
        return err;
    };
    // sym link for libfoo.so to libfoo.so.1
    const name_only_path = fs.path.join(
        allocator,
        &[_][]const u8{ out_dir, filename_name_only },
    ) catch unreachable;
    fs.atomicSymLink(allocator, filename_major_only, name_only_path) catch |err| {
        log.err("Unable to symlink {s} -> {s}", .{ name_only_path, filename_major_only });
        return err;
    };
}

fn execPkgConfigList(self: *Builder, out_code: *u8) (PkgConfigError || ExecError)![]const PkgConfigPkg {
    const stdout = try self.execAllowFail(&[_][]const u8{ "pkg-config", "--list-all" }, out_code, .Ignore);
    var list = ArrayList(PkgConfigPkg).init(self.allocator);
    errdefer list.deinit();
    var line_it = mem.tokenize(u8, stdout, "\r\n");
    while (line_it.next()) |line| {
        if (mem.trim(u8, line, " \t").len == 0) continue;
        var tok_it = mem.tokenize(u8, line, " \t");
        try list.append(PkgConfigPkg{
            .name = tok_it.next() orelse return error.PkgConfigInvalidOutput,
            .desc = tok_it.rest(),
        });
    }
    return list.toOwnedSlice();
}

fn getPkgConfigList(self: *Builder) ![]const PkgConfigPkg {
    if (self.pkg_config_pkg_list) |res| {
        return res;
    }
    var code: u8 = undefined;
    if (execPkgConfigList(self, &code)) |list| {
        self.pkg_config_pkg_list = list;
        return list;
    } else |err| {
        const result = switch (err) {
            error.ProcessTerminated => error.PkgConfigCrashed,
            error.ExecNotSupported => error.PkgConfigFailed,
            error.ExitCodeFailure => error.PkgConfigFailed,
            error.FileNotFound => error.PkgConfigNotInstalled,
            error.InvalidName => error.PkgConfigNotInstalled,
            error.PkgConfigInvalidOutput => error.PkgConfigInvalidOutput,
            error.ChildExecFailed => error.PkgConfigFailed,
            else => return err,
        };
        self.pkg_config_pkg_list = result;
        return result;
    }
}

test "addPackage" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var builder = try Builder.create(
        arena.allocator(),
        "test",
        "test",
        "test",
        "test",
    );
    defer builder.destroy();

    const pkg_dep = Pkg{
        .name = "pkg_dep",
        .source = .{ .path = "/not/a/pkg_dep.zig" },
    };
    const pkg_top = Pkg{
        .name = "pkg_dep",
        .source = .{ .path = "/not/a/pkg_top.zig" },
        .dependencies = &[_]Pkg{pkg_dep},
    };

    var exe = builder.addExecutable("not_an_executable", "/not/an/executable.zig");
    exe.addPackage(pkg_top);

    try std.testing.expectEqual(@as(usize, 1), exe.packages.items.len);

    const dupe = exe.packages.items[0];
    try std.testing.expectEqualStrings(pkg_top.name, dupe.name);
}
