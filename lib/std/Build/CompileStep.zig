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
const Step = std.Build.Step;
const CrossTarget = std.zig.CrossTarget;
const NativeTargetInfo = std.zig.system.NativeTargetInfo;
const FileSource = std.Build.FileSource;
const PkgConfigPkg = std.Build.PkgConfigPkg;
const PkgConfigError = std.Build.PkgConfigError;
const ExecError = std.Build.ExecError;
const Module = std.Build.Module;
const VcpkgRoot = std.Build.VcpkgRoot;
const InstallDir = std.Build.InstallDir;
const InstallArtifactStep = std.Build.InstallArtifactStep;
const GeneratedFile = std.Build.GeneratedFile;
const ObjCopyStep = std.Build.ObjCopyStep;
const EmulatableRunStep = std.Build.EmulatableRunStep;
const CheckObjectStep = std.Build.CheckObjectStep;
const RunStep = std.Build.RunStep;
const OptionsStep = std.Build.OptionsStep;
const ConfigHeaderStep = std.Build.ConfigHeaderStep;
const CompileStep = @This();

pub const base_id: Step.Id = .compile;

step: Step,
builder: *std.Build,
name: []const u8,
target: CrossTarget,
target_info: NativeTargetInfo,
optimize: std.builtin.Mode,
linker_script: ?FileSource = null,
version_script: ?[]const u8 = null,
out_filename: []const u8,
linkage: ?Linkage = null,
version: ?std.builtin.Version,
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
/// For WebAssembly targets, this will allow for undefined symbols to
/// be imported from the host environment.
import_symbols: bool = false,
import_table: bool = false,
export_table: bool = false,
initial_memory: ?u64 = null,
max_memory: ?u64 = null,
shared_memory: bool = false,
global_base: ?u64 = null,
c_std: std.Build.CStd,
zig_lib_dir: ?[]const u8,
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
modules: std.StringArrayHashMap(*Module),

object_src: []const u8,

link_objects: ArrayList(LinkObject),
include_dirs: ArrayList(IncludeDir),
c_macros: ArrayList([]const u8),
installed_headers: ArrayList(*Step),
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

/// Common page size
link_z_common_page_size: ?u64 = null,

/// Maximum page size
link_z_max_page_size: ?u64 = null,

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

    pub fn dupe(self: CSourceFile, b: *std.Build) CSourceFile {
        return .{
            .source = self.source.dupe(b),
            .args = b.dupeStrings(self.args),
        };
    }
};

pub const LinkObject = union(enum) {
    static_path: FileSource,
    other_step: *CompileStep,
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
    other_step: *CompileStep,
    config_header_step: *ConfigHeaderStep,
};

pub const Options = struct {
    name: []const u8,
    root_source_file: ?FileSource = null,
    target: CrossTarget,
    optimize: std.builtin.Mode,
    kind: Kind,
    linkage: ?Linkage = null,
    version: ?std.builtin.Version = null,
};

pub const Kind = enum {
    exe,
    lib,
    obj,
    @"test",
    test_exe,
};

pub const Linkage = enum { dynamic, static };

pub const EmitOption = union(enum) {
    default: void,
    no_emit: void,
    emit: void,
    emit_to: []const u8,

    fn getArg(self: @This(), b: *std.Build, arg_name: []const u8) ?[]const u8 {
        return switch (self) {
            .no_emit => b.fmt("-fno-{s}", .{arg_name}),
            .default => null,
            .emit => b.fmt("-f{s}", .{arg_name}),
            .emit_to => |path| b.fmt("-f{s}={s}", .{ arg_name, path }),
        };
    }
};

pub fn create(builder: *std.Build, options: Options) *CompileStep {
    const name = builder.dupe(options.name);
    const root_src: ?FileSource = if (options.root_source_file) |rsrc| rsrc.dupe(builder) else null;
    if (mem.indexOf(u8, name, "/") != null or mem.indexOf(u8, name, "\\") != null) {
        panic("invalid name: '{s}'. It looks like a file path, but it is supposed to be the library or application name.", .{name});
    }

    const self = builder.allocator.create(CompileStep) catch @panic("OOM");
    self.* = CompileStep{
        .strip = null,
        .unwind_tables = null,
        .builder = builder,
        .verbose_link = false,
        .verbose_cc = false,
        .optimize = options.optimize,
        .target = options.target,
        .linkage = options.linkage,
        .kind = options.kind,
        .root_src = root_src,
        .name = name,
        .frameworks = StringHashMap(FrameworkLinkInfo).init(builder.allocator),
        .step = Step.init(base_id, name, builder.allocator, make),
        .version = options.version,
        .out_filename = undefined,
        .out_h_filename = builder.fmt("{s}.h", .{name}),
        .out_lib_filename = undefined,
        .out_pdb_filename = builder.fmt("{s}.pdb", .{name}),
        .major_only_filename = null,
        .name_only_filename = null,
        .modules = std.StringArrayHashMap(*Module).init(builder.allocator),
        .include_dirs = ArrayList(IncludeDir).init(builder.allocator),
        .link_objects = ArrayList(LinkObject).init(builder.allocator),
        .c_macros = ArrayList([]const u8).init(builder.allocator),
        .lib_paths = ArrayList([]const u8).init(builder.allocator),
        .rpaths = ArrayList([]const u8).init(builder.allocator),
        .framework_dirs = ArrayList([]const u8).init(builder.allocator),
        .installed_headers = ArrayList(*Step).init(builder.allocator),
        .object_src = undefined,
        .c_std = std.Build.CStd.C99,
        .zig_lib_dir = null,
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

        .target_info = NativeTargetInfo.detect(self.target) catch @panic("unhandled error"),
    };
    self.computeOutFileNames();
    if (root_src) |rs| rs.addStepDependencies(&self.step);
    return self;
}

fn computeOutFileNames(self: *CompileStep) void {
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
    }) catch @panic("OOM");

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

pub fn setOutputDir(self: *CompileStep, dir: []const u8) void {
    self.output_dir = self.builder.dupePath(dir);
}

pub fn install(self: *CompileStep) void {
    self.builder.installArtifact(self);
}

pub fn installHeader(a: *CompileStep, src_path: []const u8, dest_rel_path: []const u8) void {
    const install_file = a.builder.addInstallHeaderFile(src_path, dest_rel_path);
    a.builder.getInstallStep().dependOn(&install_file.step);
    a.installed_headers.append(&install_file.step) catch @panic("OOM");
}

pub const InstallConfigHeaderOptions = struct {
    install_dir: InstallDir = .header,
    dest_rel_path: ?[]const u8 = null,
};

pub fn installConfigHeader(
    cs: *CompileStep,
    config_header: *ConfigHeaderStep,
    options: InstallConfigHeaderOptions,
) void {
    const dest_rel_path = options.dest_rel_path orelse config_header.include_path;
    const install_file = cs.builder.addInstallFileWithDir(
        .{ .generated = &config_header.output_file },
        options.install_dir,
        dest_rel_path,
    );
    cs.builder.getInstallStep().dependOn(&install_file.step);
    cs.installed_headers.append(&install_file.step) catch @panic("OOM");
}

pub fn installHeadersDirectory(
    a: *CompileStep,
    src_dir_path: []const u8,
    dest_rel_path: []const u8,
) void {
    return installHeadersDirectoryOptions(a, .{
        .source_dir = src_dir_path,
        .install_dir = .header,
        .install_subdir = dest_rel_path,
    });
}

pub fn installHeadersDirectoryOptions(
    a: *CompileStep,
    options: std.Build.InstallDirStep.Options,
) void {
    const install_dir = a.builder.addInstallDirectory(options);
    a.builder.getInstallStep().dependOn(&install_dir.step);
    a.installed_headers.append(&install_dir.step) catch @panic("OOM");
}

pub fn installLibraryHeaders(a: *CompileStep, l: *CompileStep) void {
    assert(l.kind == .lib);
    const install_step = a.builder.getInstallStep();
    // Copy each element from installed_headers, modifying the builder
    // to be the new parent's builder.
    for (l.installed_headers.items) |step| {
        const step_copy = switch (step.id) {
            inline .install_file, .install_dir => |id| blk: {
                const T = id.Type();
                const ptr = a.builder.allocator.create(T) catch @panic("OOM");
                ptr.* = step.cast(T).?.*;
                ptr.override_source_builder = ptr.builder;
                ptr.builder = a.builder;
                break :blk &ptr.step;
            },
            else => unreachable,
        };
        a.installed_headers.append(step_copy) catch @panic("OOM");
        install_step.dependOn(step_copy);
    }
    a.installed_headers.appendSlice(l.installed_headers.items) catch @panic("OOM");
}

pub fn addObjCopy(cs: *CompileStep, options: ObjCopyStep.Options) *ObjCopyStep {
    var copy = options;
    if (copy.basename == null) {
        if (options.format) |f| {
            copy.basename = cs.builder.fmt("{s}.{s}", .{ cs.name, @tagName(f) });
        } else {
            copy.basename = cs.name;
        }
    }
    return cs.builder.addObjCopy(cs.getOutputSource(), copy);
}

/// Deprecated: use `std.Build.addRunArtifact`
/// This function will run in the context of the package that created the executable,
/// which is undesirable when running an executable provided by a dependency package.
pub fn run(exe: *CompileStep) *RunStep {
    return exe.builder.addRunArtifact(exe);
}

/// Creates an `EmulatableRunStep` with an executable built with `addExecutable`.
/// Allows running foreign binaries through emulation platforms such as Qemu or Rosetta.
/// When a binary cannot be ran through emulation or the option is disabled, a warning
/// will be printed and the binary will *NOT* be ran.
pub fn runEmulatable(exe: *CompileStep) *EmulatableRunStep {
    assert(exe.kind == .exe or exe.kind == .test_exe);

    const run_step = EmulatableRunStep.create(exe.builder, exe.builder.fmt("run {s}", .{exe.step.name}), exe);
    if (exe.vcpkg_bin_path) |path| {
        RunStep.addPathDirInternal(&run_step.step, exe.builder, path);
    }
    return run_step;
}

pub fn checkObject(self: *CompileStep, obj_format: std.Target.ObjectFormat) *CheckObjectStep {
    return CheckObjectStep.create(self.builder, self.getOutputSource(), obj_format);
}

pub fn setLinkerScriptPath(self: *CompileStep, source: FileSource) void {
    self.linker_script = source.dupe(self.builder);
    source.addStepDependencies(&self.step);
}

pub fn linkFramework(self: *CompileStep, framework_name: []const u8) void {
    self.frameworks.put(self.builder.dupe(framework_name), .{}) catch @panic("OOM");
}

pub fn linkFrameworkNeeded(self: *CompileStep, framework_name: []const u8) void {
    self.frameworks.put(self.builder.dupe(framework_name), .{
        .needed = true,
    }) catch @panic("OOM");
}

pub fn linkFrameworkWeak(self: *CompileStep, framework_name: []const u8) void {
    self.frameworks.put(self.builder.dupe(framework_name), .{
        .weak = true,
    }) catch @panic("OOM");
}

/// Returns whether the library, executable, or object depends on a particular system library.
pub fn dependsOnSystemLibrary(self: CompileStep, name: []const u8) bool {
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

pub fn linkLibrary(self: *CompileStep, lib: *CompileStep) void {
    assert(lib.kind == .lib);
    self.linkLibraryOrObject(lib);
}

pub fn isDynamicLibrary(self: *CompileStep) bool {
    return self.kind == .lib and self.linkage == Linkage.dynamic;
}

pub fn isStaticLibrary(self: *CompileStep) bool {
    return self.kind == .lib and self.linkage != Linkage.dynamic;
}

pub fn producesPdbFile(self: *CompileStep) bool {
    if (!self.target.isWindows() and !self.target.isUefi()) return false;
    if (self.target.getObjectFormat() == .c) return false;
    if (self.strip == true) return false;
    return self.isDynamicLibrary() or self.kind == .exe or self.kind == .test_exe;
}

pub fn linkLibC(self: *CompileStep) void {
    self.is_linking_libc = true;
}

pub fn linkLibCpp(self: *CompileStep) void {
    self.is_linking_libcpp = true;
}

/// If the value is omitted, it is set to 1.
/// `name` and `value` need not live longer than the function call.
pub fn defineCMacro(self: *CompileStep, name: []const u8, value: ?[]const u8) void {
    const macro = std.Build.constructCMacro(self.builder.allocator, name, value);
    self.c_macros.append(macro) catch @panic("OOM");
}

/// name_and_value looks like [name]=[value]. If the value is omitted, it is set to 1.
pub fn defineCMacroRaw(self: *CompileStep, name_and_value: []const u8) void {
    self.c_macros.append(self.builder.dupe(name_and_value)) catch @panic("OOM");
}

/// This one has no integration with anything, it just puts -lname on the command line.
/// Prefer to use `linkSystemLibrary` instead.
pub fn linkSystemLibraryName(self: *CompileStep, name: []const u8) void {
    self.link_objects.append(.{
        .system_lib = .{
            .name = self.builder.dupe(name),
            .needed = false,
            .weak = false,
            .use_pkg_config = .no,
        },
    }) catch @panic("OOM");
}

/// This one has no integration with anything, it just puts -needed-lname on the command line.
/// Prefer to use `linkSystemLibraryNeeded` instead.
pub fn linkSystemLibraryNeededName(self: *CompileStep, name: []const u8) void {
    self.link_objects.append(.{
        .system_lib = .{
            .name = self.builder.dupe(name),
            .needed = true,
            .weak = false,
            .use_pkg_config = .no,
        },
    }) catch @panic("OOM");
}

/// Darwin-only. This one has no integration with anything, it just puts -weak-lname on the
/// command line. Prefer to use `linkSystemLibraryWeak` instead.
pub fn linkSystemLibraryWeakName(self: *CompileStep, name: []const u8) void {
    self.link_objects.append(.{
        .system_lib = .{
            .name = self.builder.dupe(name),
            .needed = false,
            .weak = true,
            .use_pkg_config = .no,
        },
    }) catch @panic("OOM");
}

/// This links against a system library, exclusively using pkg-config to find the library.
/// Prefer to use `linkSystemLibrary` instead.
pub fn linkSystemLibraryPkgConfigOnly(self: *CompileStep, lib_name: []const u8) void {
    self.link_objects.append(.{
        .system_lib = .{
            .name = self.builder.dupe(lib_name),
            .needed = false,
            .weak = false,
            .use_pkg_config = .force,
        },
    }) catch @panic("OOM");
}

/// This links against a system library, exclusively using pkg-config to find the library.
/// Prefer to use `linkSystemLibraryNeeded` instead.
pub fn linkSystemLibraryNeededPkgConfigOnly(self: *CompileStep, lib_name: []const u8) void {
    self.link_objects.append(.{
        .system_lib = .{
            .name = self.builder.dupe(lib_name),
            .needed = true,
            .weak = false,
            .use_pkg_config = .force,
        },
    }) catch @panic("OOM");
}

/// Run pkg-config for the given library name and parse the output, returning the arguments
/// that should be passed to zig to link the given library.
pub fn runPkgConfig(self: *CompileStep, lib_name: []const u8) ![]const []const u8 {
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

    var zig_args = ArrayList([]const u8).init(self.builder.allocator);
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

pub fn linkSystemLibrary(self: *CompileStep, name: []const u8) void {
    self.linkSystemLibraryInner(name, .{});
}

pub fn linkSystemLibraryNeeded(self: *CompileStep, name: []const u8) void {
    self.linkSystemLibraryInner(name, .{ .needed = true });
}

pub fn linkSystemLibraryWeak(self: *CompileStep, name: []const u8) void {
    self.linkSystemLibraryInner(name, .{ .weak = true });
}

fn linkSystemLibraryInner(self: *CompileStep, name: []const u8, opts: struct {
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
    }) catch @panic("OOM");
}

pub fn setNamePrefix(self: *CompileStep, text: []const u8) void {
    assert(self.kind == .@"test" or self.kind == .test_exe);
    self.name_prefix = self.builder.dupe(text);
}

pub fn setFilter(self: *CompileStep, text: ?[]const u8) void {
    assert(self.kind == .@"test" or self.kind == .test_exe);
    self.filter = if (text) |t| self.builder.dupe(t) else null;
}

pub fn setTestRunner(self: *CompileStep, path: ?[]const u8) void {
    assert(self.kind == .@"test" or self.kind == .test_exe);
    self.test_runner = if (path) |p| self.builder.dupePath(p) else null;
}

/// Handy when you have many C/C++ source files and want them all to have the same flags.
pub fn addCSourceFiles(self: *CompileStep, files: []const []const u8, flags: []const []const u8) void {
    const c_source_files = self.builder.allocator.create(CSourceFiles) catch @panic("OOM");

    const files_copy = self.builder.dupeStrings(files);
    const flags_copy = self.builder.dupeStrings(flags);

    c_source_files.* = .{
        .files = files_copy,
        .flags = flags_copy,
    };
    self.link_objects.append(.{ .c_source_files = c_source_files }) catch @panic("OOM");
}

pub fn addCSourceFile(self: *CompileStep, file: []const u8, flags: []const []const u8) void {
    self.addCSourceFileSource(.{
        .args = flags,
        .source = .{ .path = file },
    });
}

pub fn addCSourceFileSource(self: *CompileStep, source: CSourceFile) void {
    const c_source_file = self.builder.allocator.create(CSourceFile) catch @panic("OOM");
    c_source_file.* = source.dupe(self.builder);
    self.link_objects.append(.{ .c_source_file = c_source_file }) catch @panic("OOM");
    source.source.addStepDependencies(&self.step);
}

pub fn setVerboseLink(self: *CompileStep, value: bool) void {
    self.verbose_link = value;
}

pub fn setVerboseCC(self: *CompileStep, value: bool) void {
    self.verbose_cc = value;
}

pub fn overrideZigLibDir(self: *CompileStep, dir_path: []const u8) void {
    self.zig_lib_dir = self.builder.dupePath(dir_path);
}

pub fn setMainPkgPath(self: *CompileStep, dir_path: []const u8) void {
    self.main_pkg_path = self.builder.dupePath(dir_path);
}

pub fn setLibCFile(self: *CompileStep, libc_file: ?FileSource) void {
    self.libc_file = if (libc_file) |f| f.dupe(self.builder) else null;
}

/// Returns the generated executable, library or object file.
/// To run an executable built with zig build, use `run`, or create an install step and invoke it.
pub fn getOutputSource(self: *CompileStep) FileSource {
    return FileSource{ .generated = &self.output_path_source };
}

/// Returns the generated import library. This function can only be called for libraries.
pub fn getOutputLibSource(self: *CompileStep) FileSource {
    assert(self.kind == .lib);
    return FileSource{ .generated = &self.output_lib_path_source };
}

/// Returns the generated header file.
/// This function can only be called for libraries or object files which have `emit_h` set.
pub fn getOutputHSource(self: *CompileStep) FileSource {
    assert(self.kind != .exe and self.kind != .test_exe and self.kind != .@"test");
    assert(self.emit_h);
    return FileSource{ .generated = &self.output_h_path_source };
}

/// Returns the generated PDB file. This function can only be called for Windows and UEFI.
pub fn getOutputPdbSource(self: *CompileStep) FileSource {
    // TODO: Is this right? Isn't PDB for *any* PE/COFF file?
    assert(self.target.isWindows() or self.target.isUefi());
    return FileSource{ .generated = &self.output_pdb_path_source };
}

pub fn addAssemblyFile(self: *CompileStep, path: []const u8) void {
    self.link_objects.append(.{
        .assembly_file = .{ .path = self.builder.dupe(path) },
    }) catch @panic("OOM");
}

pub fn addAssemblyFileSource(self: *CompileStep, source: FileSource) void {
    const source_duped = source.dupe(self.builder);
    self.link_objects.append(.{ .assembly_file = source_duped }) catch @panic("OOM");
    source_duped.addStepDependencies(&self.step);
}

pub fn addObjectFile(self: *CompileStep, source_file: []const u8) void {
    self.addObjectFileSource(.{ .path = source_file });
}

pub fn addObjectFileSource(self: *CompileStep, source: FileSource) void {
    self.link_objects.append(.{ .static_path = source.dupe(self.builder) }) catch @panic("OOM");
    source.addStepDependencies(&self.step);
}

pub fn addObject(self: *CompileStep, obj: *CompileStep) void {
    assert(obj.kind == .obj);
    self.linkLibraryOrObject(obj);
}

pub const addSystemIncludeDir = @compileError("deprecated; use addSystemIncludePath");
pub const addIncludeDir = @compileError("deprecated; use addIncludePath");
pub const addLibPath = @compileError("deprecated, use addLibraryPath");
pub const addFrameworkDir = @compileError("deprecated, use addFrameworkPath");

pub fn addSystemIncludePath(self: *CompileStep, path: []const u8) void {
    self.include_dirs.append(IncludeDir{ .raw_path_system = self.builder.dupe(path) }) catch @panic("OOM");
}

pub fn addIncludePath(self: *CompileStep, path: []const u8) void {
    self.include_dirs.append(IncludeDir{ .raw_path = self.builder.dupe(path) }) catch @panic("OOM");
}

pub fn addConfigHeader(self: *CompileStep, config_header: *ConfigHeaderStep) void {
    self.step.dependOn(&config_header.step);
    self.include_dirs.append(.{ .config_header_step = config_header }) catch @panic("OOM");
}

pub fn addLibraryPath(self: *CompileStep, path: []const u8) void {
    self.lib_paths.append(self.builder.dupe(path)) catch @panic("OOM");
}

pub fn addRPath(self: *CompileStep, path: []const u8) void {
    self.rpaths.append(self.builder.dupe(path)) catch @panic("OOM");
}

pub fn addFrameworkPath(self: *CompileStep, dir_path: []const u8) void {
    self.framework_dirs.append(self.builder.dupe(dir_path)) catch @panic("OOM");
}

/// Adds a module to be used with `@import` and exposing it in the current
/// package's module table using `name`.
pub fn addModule(cs: *CompileStep, name: []const u8, module: *Module) void {
    cs.modules.put(cs.builder.dupe(name), module) catch @panic("OOM");

    var done = std.AutoHashMap(*Module, void).init(cs.builder.allocator);
    defer done.deinit();
    cs.addRecursiveBuildDeps(module, &done) catch @panic("OOM");
}

/// Adds a module to be used with `@import` without exposing it in the current
/// package's module table.
pub fn addAnonymousModule(cs: *CompileStep, name: []const u8, options: std.Build.CreateModuleOptions) void {
    const module = cs.builder.createModule(options);
    return addModule(cs, name, module);
}

pub fn addOptions(cs: *CompileStep, module_name: []const u8, options: *OptionsStep) void {
    addModule(cs, module_name, options.createModule());
}

fn addRecursiveBuildDeps(cs: *CompileStep, module: *Module, done: *std.AutoHashMap(*Module, void)) !void {
    if (done.contains(module)) return;
    try done.put(module, {});
    module.source_file.addStepDependencies(&cs.step);
    for (module.dependencies.values()) |dep| {
        try cs.addRecursiveBuildDeps(dep, done);
    }
}

/// If Vcpkg was found on the system, it will be added to include and lib
/// paths for the specified target.
pub fn addVcpkgPaths(self: *CompileStep, linkage: CompileStep.Linkage) !void {
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

pub fn setExecCmd(self: *CompileStep, args: []const ?[]const u8) void {
    assert(self.kind == .@"test");
    const duped_args = self.builder.allocator.alloc(?[]u8, args.len) catch @panic("OOM");
    for (args, 0..) |arg, i| {
        duped_args[i] = if (arg) |a| self.builder.dupe(a) else null;
    }
    self.exec_cmd_args = duped_args;
}

fn linkLibraryOrObject(self: *CompileStep, other: *CompileStep) void {
    self.step.dependOn(&other.step);
    self.link_objects.append(.{ .other_step = other }) catch @panic("OOM");
    self.include_dirs.append(.{ .other_step = other }) catch @panic("OOM");
}

fn appendModuleArgs(
    cs: *CompileStep,
    zig_args: *ArrayList([]const u8),
) error{OutOfMemory}!void {
    // First, traverse the whole dependency graph and give every module a unique name, ideally one
    // named after what it's called somewhere in the graph. It will help here to have both a mapping
    // from module to name and a set of all the currently-used names.
    var mod_names = std.AutoHashMap(*Module, []const u8).init(cs.builder.allocator);
    var names = std.StringHashMap(void).init(cs.builder.allocator);

    var to_name = std.ArrayList(struct {
        name: []const u8,
        mod: *Module,
    }).init(cs.builder.allocator);
    {
        var it = cs.modules.iterator();
        while (it.next()) |kv| {
            // While we're traversing the root dependencies, let's make sure that no module names
            // have colons in them, since the CLI forbids it. We handle this for transitive
            // dependencies further down.
            if (std.mem.indexOfScalar(u8, kv.key_ptr.*, ':') != null) {
                @panic("Module names cannot contain colons");
            }
            try to_name.append(.{
                .name = kv.key_ptr.*,
                .mod = kv.value_ptr.*,
            });
        }
    }

    while (to_name.popOrNull()) |dep| {
        if (mod_names.contains(dep.mod)) continue;

        // We'll use this buffer to store the name we decide on
        var buf = try cs.builder.allocator.alloc(u8, dep.name.len + 32);
        // First, try just the exposed dependency name
        std.mem.copy(u8, buf, dep.name);
        var name = buf[0..dep.name.len];
        var n: usize = 0;
        while (names.contains(name)) {
            // If that failed, append an incrementing number to the end
            name = std.fmt.bufPrint(buf, "{s}{}", .{ dep.name, n }) catch unreachable;
            n += 1;
        }

        try mod_names.put(dep.mod, name);
        try names.put(name, {});

        var it = dep.mod.dependencies.iterator();
        while (it.next()) |kv| {
            // Same colon-in-name check as above, but for transitive dependencies.
            if (std.mem.indexOfScalar(u8, kv.key_ptr.*, ':') != null) {
                @panic("Module names cannot contain colons");
            }
            try to_name.append(.{
                .name = kv.key_ptr.*,
                .mod = kv.value_ptr.*,
            });
        }
    }

    // Since the module names given to the CLI are based off of the exposed names, we already know
    // that none of the CLI names have colons in them, so there's no need to check that explicitly.

    // Every module in the graph is now named; output their definitions
    {
        var it = mod_names.iterator();
        while (it.next()) |kv| {
            const mod = kv.key_ptr.*;
            const name = kv.value_ptr.*;

            const deps_str = try constructDepString(cs.builder.allocator, mod_names, mod.dependencies);
            const src = mod.builder.pathFromRoot(mod.source_file.getPath(mod.builder));
            try zig_args.append("--mod");
            try zig_args.append(try std.fmt.allocPrint(cs.builder.allocator, "{s}:{s}:{s}", .{ name, deps_str, src }));
        }
    }

    // Lastly, output the root dependencies
    const deps_str = try constructDepString(cs.builder.allocator, mod_names, cs.modules);
    if (deps_str.len > 0) {
        try zig_args.append("--deps");
        try zig_args.append(deps_str);
    }
}

fn constructDepString(
    allocator: std.mem.Allocator,
    mod_names: std.AutoHashMap(*Module, []const u8),
    deps: std.StringArrayHashMap(*Module),
) ![]const u8 {
    var deps_str = std.ArrayList(u8).init(allocator);
    var it = deps.iterator();
    while (it.next()) |kv| {
        const expose = kv.key_ptr.*;
        const name = mod_names.get(kv.value_ptr.*).?;
        if (std.mem.eql(u8, expose, name)) {
            try deps_str.writer().print("{s},", .{name});
        } else {
            try deps_str.writer().print("{s}={s},", .{ expose, name });
        }
    }
    if (deps_str.items.len > 0) {
        return deps_str.items[0 .. deps_str.items.len - 1]; // omit trailing comma
    } else {
        return "";
    }
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(CompileStep, "step", step);
    const builder = self.builder;

    if (self.root_src == null and self.link_objects.items.len == 0) {
        log.err("{s}: linker needs 1 or more objects to link", .{self.step.name});
        return error.NeedAnObject;
    }

    var zig_args = ArrayList([]const u8).init(builder.allocator);
    defer zig_args.deinit();

    try zig_args.append(builder.zig_exe);

    const cmd = switch (self.kind) {
        .lib => "build-lib",
        .exe => "build-exe",
        .obj => "build-obj",
        .@"test" => "test",
        .test_exe => "test",
    };
    try zig_args.append(cmd);

    if (builder.color != .auto) {
        try zig_args.append("--color");
        try zig_args.append(@tagName(builder.color));
    }

    if (builder.reference_trace) |some| {
        try zig_args.append(try std.fmt.allocPrint(builder.allocator, "-freference-trace={d}", .{some}));
    }

    try addFlag(&zig_args, "LLVM", self.use_llvm);
    try addFlag(&zig_args, "LLD", self.use_lld);

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

    // We will add link objects from transitive dependencies, but we want to keep
    // all link objects in the same order provided.
    // This array is used to keep self.link_objects immutable.
    var transitive_deps: TransitiveDeps = .{
        .link_objects = ArrayList(LinkObject).init(builder.allocator),
        .seen_system_libs = StringHashMap(void).init(builder.allocator),
        .seen_steps = std.AutoHashMap(*const Step, void).init(builder.allocator),
        .is_linking_libcpp = self.is_linking_libcpp,
        .is_linking_libc = self.is_linking_libc,
        .frameworks = &self.frameworks,
    };

    try transitive_deps.seen_steps.put(&self.step, {});
    try transitive_deps.add(self.link_objects.items);

    var prev_has_extra_flags = false;

    for (transitive_deps.link_objects.items) |link_object| {
        switch (link_object) {
            .static_path => |static_path| try zig_args.append(static_path.getPath(builder)),

            .other_step => |other| switch (other.kind) {
                .exe => @panic("Cannot link with an executable build artifact"),
                .test_exe => @panic("Cannot link with an executable build artifact"),
                .@"test" => @panic("Cannot link with a test"),
                .obj => {
                    try zig_args.append(other.getOutputSource().getPath(builder));
                },
                .lib => l: {
                    if (self.isStaticLibrary() and other.isStaticLibrary()) {
                        // Avoid putting a static library inside a static library.
                        break :l;
                    }

                    const full_path_lib = other.getOutputLibSource().getPath(builder);
                    try zig_args.append(full_path_lib);

                    if (other.linkage == Linkage.dynamic and !self.target.isWindows()) {
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

    if (transitive_deps.is_linking_libcpp) {
        try zig_args.append("-lc++");
    }

    if (transitive_deps.is_linking_libc) {
        try zig_args.append("-lc");
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

    if (builder.verbose_cimport) try zig_args.append("--verbose-cimport");
    if (builder.verbose_air) try zig_args.append("--verbose-air");
    if (builder.verbose_llvm_ir) try zig_args.append("--verbose-llvm-ir");
    if (builder.verbose_link or self.verbose_link) try zig_args.append("--verbose-link");
    if (builder.verbose_cc or self.verbose_cc) try zig_args.append("--verbose-cc");
    if (builder.verbose_llvm_cpu_features) try zig_args.append("--verbose-llvm-cpu-features");

    if (self.emit_analysis.getArg(builder, "emit-analysis")) |arg| try zig_args.append(arg);
    if (self.emit_asm.getArg(builder, "emit-asm")) |arg| try zig_args.append(arg);
    if (self.emit_bin.getArg(builder, "emit-bin")) |arg| try zig_args.append(arg);
    if (self.emit_docs.getArg(builder, "emit-docs")) |arg| try zig_args.append(arg);
    if (self.emit_implib.getArg(builder, "emit-implib")) |arg| try zig_args.append(arg);
    if (self.emit_llvm_bc.getArg(builder, "emit-llvm-bc")) |arg| try zig_args.append(arg);
    if (self.emit_llvm_ir.getArg(builder, "emit-llvm-ir")) |arg| try zig_args.append(arg);

    if (self.emit_h) try zig_args.append("-femit-h");

    try addFlag(&zig_args, "strip", self.strip);
    try addFlag(&zig_args, "unwind-tables", self.unwind_tables);

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
    if (self.link_z_common_page_size) |size| {
        try zig_args.append("-z");
        try zig_args.append(builder.fmt("common-page-size={d}", .{size}));
    }
    if (self.link_z_max_page_size) |size| {
        try zig_args.append("-z");
        try zig_args.append(builder.fmt("max-page-size={d}", .{size}));
    }

    if (self.libc_file) |libc_file| {
        try zig_args.append("--libc");
        try zig_args.append(libc_file.getPath(builder));
    } else if (builder.libc_file) |libc_file| {
        try zig_args.append("--libc");
        try zig_args.append(libc_file);
    }

    switch (self.optimize) {
        .Debug => {}, // Skip since it's the default.
        else => try zig_args.append(builder.fmt("-O{s}", .{@tagName(self.optimize)})),
    }

    try zig_args.append("--cache-dir");
    try zig_args.append(builder.cache_root.path orelse ".");

    try zig_args.append("--global-cache-dir");
    try zig_args.append(builder.global_cache_root.path orelse ".");

    try zig_args.append("--name");
    try zig_args.append(self.name);

    if (self.linkage) |some| switch (some) {
        .dynamic => try zig_args.append("-dynamic"),
        .static => try zig_args.append("-static"),
    };
    if (self.kind == .lib and self.linkage != null and self.linkage.? == .dynamic) {
        if (self.version) |version| {
            try zig_args.append("--version");
            try zig_args.append(builder.fmt("{}", .{version}));
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

    try addFlag(&zig_args, "compiler-rt", self.bundle_compiler_rt);
    try addFlag(&zig_args, "single-threaded", self.single_threaded);
    if (self.disable_stack_probing) {
        try zig_args.append("-fno-stack-check");
    }
    try addFlag(&zig_args, "stack-protector", self.stack_protector);
    if (self.red_zone) |red_zone| {
        if (red_zone) {
            try zig_args.append("-mred-zone");
        } else {
            try zig_args.append("-mno-red-zone");
        }
    }
    try addFlag(&zig_args, "omit-frame-pointer", self.omit_frame_pointer);
    try addFlag(&zig_args, "dll-export-fns", self.dll_export_fns);

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
    if (self.import_symbols) {
        try zig_args.append("--import-symbols");
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
        try zig_args.appendSlice(&.{
            "-target", try self.target.zigTriple(builder.allocator),
            "-mcpu",   try std.Build.serializeCpu(builder.allocator, self.target.getCpu()),
        });

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
            const need_cross_glibc = self.target.isGnuLibC() and transitive_deps.is_linking_libc;

            switch (builder.host.getExternalExecutor(self.target_info, .{
                .qemu_fixes_dl = need_cross_glibc and builder.glibc_runtimes_dir != null,
                .link_libc = transitive_deps.is_linking_libc,
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

    try self.appendModuleArgs(&zig_args);

    for (self.include_dirs.items) |include_dir| {
        switch (include_dir) {
            .raw_path => |include_path| {
                try zig_args.append("-I");
                try zig_args.append(builder.pathFromRoot(include_path));
            },
            .raw_path_system => |include_path| {
                if (builder.sysroot != null) {
                    try zig_args.append("-iwithsysroot");
                } else {
                    try zig_args.append("-isystem");
                }

                const resolved_include_path = builder.pathFromRoot(include_path);

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
            .other_step => |other| {
                if (other.emit_h) {
                    const h_path = other.getOutputHSource().getPath(builder);
                    try zig_args.append("-isystem");
                    try zig_args.append(fs.path.dirname(h_path).?);
                }
                if (other.installed_headers.items.len > 0) {
                    for (other.installed_headers.items) |install_step| {
                        try install_step.make();
                    }
                    try zig_args.append("-I");
                    try zig_args.append(builder.pathJoin(&.{
                        other.builder.install_prefix, "include",
                    }));
                }
            },
            .config_header_step => |config_header| {
                const full_file_path = config_header.output_file.path.?;
                const header_dir_path = full_file_path[0 .. full_file_path.len - config_header.include_path.len];
                try zig_args.appendSlice(&.{ "-I", header_dir_path });
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
                try zig_args.append("-needed_framework");
            } else if (info.weak) {
                try zig_args.append("-weak_framework");
            } else {
                try zig_args.append("-framework");
            }
            try zig_args.append(name);
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

    try addFlag(&zig_args, "valgrind", self.valgrind_support);
    try addFlag(&zig_args, "each-lib-rpath", self.each_lib_rpath);
    try addFlag(&zig_args, "build-id", self.build_id);

    if (self.zig_lib_dir) |dir| {
        try zig_args.append("--zig-lib-dir");
        try zig_args.append(builder.pathFromRoot(dir));
    } else if (builder.zig_lib_dir) |dir| {
        try zig_args.append("--zig-lib-dir");
        try zig_args.append(dir);
    }

    if (self.main_pkg_path) |dir| {
        try zig_args.append("--main-pkg-path");
        try zig_args.append(builder.pathFromRoot(dir));
    }

    try addFlag(&zig_args, "PIC", self.force_pic);
    try addFlag(&zig_args, "PIE", self.pie);
    try addFlag(&zig_args, "lto", self.want_lto);

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
        try builder.cache_root.handle.makePath("args");

        const args_to_escape = zig_args.items[2..];
        var escaped_args = try ArrayList([]const u8).initCapacity(builder.allocator, args_to_escape.len);
        arg_blk: for (args_to_escape) |arg| {
            for (arg, 0..) |c, arg_idx| {
                if (c == '\\' or c == '"') {
                    // Slow path for arguments that need to be escaped. We'll need to allocate and copy
                    var escaped = try ArrayList(u8).initCapacity(builder.allocator, arg.len + 1);
                    const writer = escaped.writer();
                    try writer.writeAll(arg[0..arg_idx]);
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

        const args_file = "args" ++ fs.path.sep_str ++ args_hex_hash;
        try builder.cache_root.handle.writeFile(args_file, args);

        const resolved_args_file = try mem.concat(builder.allocator, u8, &.{
            "@",
            try builder.cache_root.join(builder.allocator, &.{args_file}),
        });

        zig_args.shrinkRetainingCapacity(2);
        try zig_args.append(resolved_args_file);
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

pub fn doAtomicSymLinks(
    allocator: Allocator,
    output_path: []const u8,
    filename_major_only: []const u8,
    filename_name_only: []const u8,
) !void {
    const out_dir = fs.path.dirname(output_path) orelse ".";
    const out_basename = fs.path.basename(output_path);
    // sym link for libfoo.so.1 to libfoo.so.1.2.3
    const major_only_path = try fs.path.join(
        allocator,
        &[_][]const u8{ out_dir, filename_major_only },
    );
    fs.atomicSymLink(allocator, out_basename, major_only_path) catch |err| {
        log.err("Unable to symlink {s} -> {s}", .{ major_only_path, out_basename });
        return err;
    };
    // sym link for libfoo.so to libfoo.so.1
    const name_only_path = try fs.path.join(
        allocator,
        &[_][]const u8{ out_dir, filename_name_only },
    );
    fs.atomicSymLink(allocator, filename_major_only, name_only_path) catch |err| {
        log.err("Unable to symlink {s} -> {s}", .{ name_only_path, filename_major_only });
        return err;
    };
}

fn execPkgConfigList(self: *std.Build, out_code: *u8) (PkgConfigError || ExecError)![]const PkgConfigPkg {
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

fn getPkgConfigList(self: *std.Build) ![]const PkgConfigPkg {
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

fn addFlag(args: *ArrayList([]const u8), comptime name: []const u8, opt: ?bool) !void {
    const cond = opt orelse return;
    try args.ensureUnusedCapacity(1);
    if (cond) {
        args.appendAssumeCapacity("-f" ++ name);
    } else {
        args.appendAssumeCapacity("-fno-" ++ name);
    }
}

const TransitiveDeps = struct {
    link_objects: ArrayList(LinkObject),
    seen_system_libs: StringHashMap(void),
    seen_steps: std.AutoHashMap(*const Step, void),
    is_linking_libcpp: bool,
    is_linking_libc: bool,
    frameworks: *StringHashMap(FrameworkLinkInfo),

    fn add(td: *TransitiveDeps, link_objects: []const LinkObject) !void {
        try td.link_objects.ensureUnusedCapacity(link_objects.len);

        for (link_objects) |link_object| {
            try td.link_objects.append(link_object);
            switch (link_object) {
                .other_step => |other| try addInner(td, other, other.isDynamicLibrary()),
                else => {},
            }
        }
    }

    fn addInner(td: *TransitiveDeps, other: *CompileStep, dyn: bool) !void {
        // Inherit dependency on libc and libc++
        td.is_linking_libcpp = td.is_linking_libcpp or other.is_linking_libcpp;
        td.is_linking_libc = td.is_linking_libc or other.is_linking_libc;

        // Inherit dependencies on darwin frameworks
        if (!dyn) {
            var it = other.frameworks.iterator();
            while (it.next()) |framework| {
                try td.frameworks.put(framework.key_ptr.*, framework.value_ptr.*);
            }
        }

        // Inherit dependencies on system libraries and static libraries.
        for (other.link_objects.items) |other_link_object| {
            switch (other_link_object) {
                .system_lib => |system_lib| {
                    if ((try td.seen_system_libs.fetchPut(system_lib.name, {})) != null)
                        continue;

                    if (dyn)
                        continue;

                    try td.link_objects.append(other_link_object);
                },
                .other_step => |inner_other| {
                    if ((try td.seen_steps.fetchPut(&inner_other.step, {})) != null)
                        continue;

                    if (!dyn)
                        try td.link_objects.append(other_link_object);

                    try addInner(td, inner_other, dyn or inner_other.isDynamicLibrary());
                },
                else => continue,
            }
        }
    }
};
