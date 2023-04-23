const Module = @This();

builder: *Build,
/// This could either be a generated file, in which case the module
/// contains exactly one file, or it could be a path to the root source
/// file of directory of files which constitute the module.
source_file: ?FileSource,
dependencies: StringArrayHashMap(*Module),
link_objects: ArrayList(LinkObject),
installed_headers: ArrayList(*Step),
frameworks: StringHashMap(FrameworkLinkInfo),
include_dirs: ArrayList(IncludeDir),
lib_paths: ArrayList(FileSource),
rpaths: ArrayList(FileSource),
framework_dirs: ArrayList(FileSource),
c_macros: ArrayList([]const u8),
c_std: std.Build.CStd,

is_linking_libc: bool,
is_linking_libcpp: bool,
linker_script: ?FileSource = null,

/// List of symbols forced as undefined in the symbol table
/// thus forcing their resolution by the linker.
/// Corresponds to `-u <symbol>` for ELF/MachO and `/include:<symbol>` for COFF/PE.
force_undefined_symbols: StringHashMap(void),

pub fn create(owner: *Build, options: CreateModuleOptions) *Module {
    const mod = owner.allocator.create(Module) catch @panic("OOM");
    const arena = owner.allocator;
    mod.* = .{
        .builder = owner,
        .source_file = options.source_file,
        .dependencies = moduleDependenciesToArrayHashMap(arena, options.dependencies),
        .link_objects = ArrayList(LinkObject).init(arena),
        .installed_headers = ArrayList(*Step).init(arena),
        .frameworks = StringHashMap(FrameworkLinkInfo).init(arena),
        .include_dirs = ArrayList(IncludeDir).init(arena),
        .lib_paths = ArrayList(FileSource).init(arena),
        .rpaths = ArrayList(FileSource).init(arena),
        .framework_dirs = ArrayList(FileSource).init(arena),
        .force_undefined_symbols = StringHashMap(void).init(arena),
        .c_macros = ArrayList([]const u8).init(arena),
        .c_std = std.Build.CStd.C99,
        .is_linking_libc = false,
        .is_linking_libcpp = false,
        .linker_script = null,
    };
    if (options.c_source_files) |c_files| {
        mod.addCSourceFiles(c_files.files, c_files.flags);
    }

    return mod;
}

fn moduleDependenciesToArrayHashMap(arena: Allocator, deps: []const ModuleDependency) std.StringArrayHashMap(*Module) {
    var result = std.StringArrayHashMap(*Module).init(arena);
    for (deps) |dep| {
        result.put(dep.name, dep.module) catch @panic("OOM");
    }
    return result;
}

pub fn addOptions(m: *Module, name: []const u8, options: *OptionsStep) void {
    m.dependencies.put(m.builder.dupe(name), options.addModule(name)) catch @panic("OOM");
}

pub const LinkObject = union(enum) {
    static_path: FileSource,
    other_step: *CompileStep,
    system_lib: SystemLib,
    assembly_file: FileSource,
    c_source_file: *CSourceFile,
    c_source_files: *CSourceFiles,
};

pub fn linkLibC(m: *Module) void {
    m.is_linking_libc = true;
}

pub fn linkLibCpp(m: *Module) void {
    m.is_linking_libcpp = true;
}

/// This one has no integration with anything, it just puts -lname on the command line.
/// Prefer to use `linkSystemLibrary` instead.
pub fn linkSystemLibraryName(m: *Module, name: []const u8) void {
    const b = m.builder;
    m.link_objects.append(.{
        .system_lib = .{
            .name = b.dupe(name),
            .needed = false,
            .weak = false,
            .use_pkg_config = .no,
        },
    }) catch @panic("OOM");
}

/// This one has no integration with anything, it just puts -needed-lname on the command line.
/// Prefer to use `linkSystemLibraryNeeded` instead.
pub fn linkSystemLibraryNeededName(m: *Module, name: []const u8) void {
    const b = m.builder;
    m.link_objects.append(.{
        .system_lib = .{
            .name = b.dupe(name),
            .needed = true,
            .weak = false,
            .use_pkg_config = .no,
        },
    }) catch @panic("OOM");
}

/// Darwin-only. This one has no integration with anything, it just puts -weak-lname on the
/// command line. Prefer to use `linkSystemLibraryWeak` instead.
pub fn linkSystemLibraryWeakName(m: *Module, name: []const u8) void {
    const b = m.builder;
    m.link_objects.append(.{
        .system_lib = .{
            .name = b.dupe(name),
            .needed = false,
            .weak = true,
            .use_pkg_config = .no,
        },
    }) catch @panic("OOM");
}

/// This links against a system library, exclusively using pkg-config to find the library.
/// Prefer to use `linkSystemLibrary` instead.
pub fn linkSystemLibraryPkgConfigOnly(m: *Module, lib_name: []const u8) void {
    const b = m.builder;
    m.link_objects.append(.{
        .system_lib = .{
            .name = b.dupe(lib_name),
            .needed = false,
            .weak = false,
            .use_pkg_config = .force,
        },
    }) catch @panic("OOM");
}

/// This links against a system library, exclusively using pkg-config to find the library.
/// Prefer to use `linkSystemLibraryNeeded` instead.
pub fn linkSystemLibraryNeededPkgConfigOnly(m: *Module, lib_name: []const u8) void {
    const b = m.builder;
    m.link_objects.append(.{
        .system_lib = .{
            .name = b.dupe(lib_name),
            .needed = true,
            .weak = false,
            .use_pkg_config = .force,
        },
    }) catch @panic("OOM");
}

/// Handy when you have many C/C++ source files and want them all to have the same flags.
pub fn addCSourceFiles(m: *Module, files: []const []const u8, flags: []const []const u8) void {
    const b = m.builder;
    const c_source_files = b.allocator.create(CSourceFiles) catch @panic("OOM");

    const files_copy = b.dupeStrings(files);
    const flags_copy = b.dupeStrings(flags);

    c_source_files.* = .{
        .files = files_copy,
        .flags = flags_copy,
    };
    m.link_objects.append(.{ .c_source_files = c_source_files }) catch @panic("OOM");
}

pub fn addCSourceFile(m: *Module, file: []const u8, flags: []const []const u8) void {
    m.addCSourceFileSource(.{
        .args = flags,
        .source = .{ .path = file },
    });
}

pub fn addCSourceFileSource(m: *Module, source: CSourceFile) void {
    const b = m.builder;
    const c_source_file = b.allocator.create(CSourceFile) catch @panic("OOM");
    c_source_file.* = source.dupe(b);
    m.link_objects.append(.{ .c_source_file = c_source_file }) catch @panic("OOM");
    // source.source.addStepDependencies(&self.step);
    // TODO: Add step dependencies to consumers of the module
}

const InstalledHeader = union(enum) {
    header: struct {
        source_path: []const u8,
        dest_rel_path: []const u8,
    },
    header_dir_step: InstallDirStep.Options,
    config_header: struct {
        step: *ConfigHeaderStep,
        options: CompileStep.InstallConfigHeaderOptions,
    },
    lib_step: *CompileStep,
};

pub fn installHeader(m: *Module, src_path: []const u8, dest_rel_path: []const u8) void {
    const b = m.builder;
    const install_file = b.addInstallHeaderFile(src_path, dest_rel_path);
    b.getInstallStep().dependOn(&install_file.step);
    m.installed_headers.append(&install_file.step) catch @panic("OOM");
}

pub const InstallConfigHeaderOptions = struct {
    install_dir: InstallDir = .header,
    dest_rel_path: ?[]const u8 = null,
};

pub fn installConfigHeader(
    m: *Module,
    config_header: *ConfigHeaderStep,
    options: InstallConfigHeaderOptions,
) void {
    const dest_rel_path = options.dest_rel_path orelse config_header.include_path;
    const b = m.builder;
    const install_file = b.addInstallFileWithDir(
        .{ .generated = &config_header.output_file },
        options.install_dir,
        dest_rel_path,
    );
    install_file.step.dependOn(&config_header.step);
    b.getInstallStep().dependOn(&install_file.step);
    m.installed_headers.append(&install_file.step) catch @panic("OOM");
}

pub fn installHeadersDirectory(
    m: *Module,
    src_dir_path: []const u8,
    dest_rel_path: []const u8,
) void {
    return installHeadersDirectoryOptions(m, .{
        .source_dir = src_dir_path,
        .install_dir = .header,
        .install_subdir = dest_rel_path,
    });
}

pub fn installHeadersDirectoryOptions(
    m: *Module,
    options: std.Build.InstallDirStep.Options,
) void {
    const b = m.builder;
    const install_dir = b.addInstallDirectory(options);
    b.getInstallStep().dependOn(&install_dir.step);
    m.installed_headers.append(&install_dir.step) catch @panic("OOM");
}

pub fn installLibraryHeaders(m: *Module, l: *CompileStep) void {
    assert(l.kind == .lib);
    const b = m.builder;
    const install_step = b.getInstallStep();
    // Copy each element from installed_headers, modifying the builder
    // to be the new parent's builder.
    for (l.main_module.installed_headers.items) |step| {
        const step_copy = switch (step.id) {
            inline .install_file, .install_dir => |id| blk: {
                const T = id.Type();
                const ptr = b.allocator.create(T) catch @panic("OOM");
                ptr.* = step.cast(T).?.*;
                ptr.dest_builder = b;
                break :blk &ptr.step;
            },
            else => unreachable,
        };
        m.installed_headers.append(step_copy) catch @panic("OOM");
        install_step.dependOn(step_copy);
    }
    m.installed_headers.appendSlice(l.main_module.installed_headers.items) catch @panic("OOM");
}

/// If the value is omitted, it is set to 1.
/// `name` and `value` need not live longer than the function call.
pub fn defineCMacro(m: *Module, name: []const u8, value: ?[]const u8) void {
    const b = m.builder;
    const macro = std.Build.constructCMacro(b.allocator, name, value);
    m.c_macros.append(macro) catch @panic("OOM");
}

/// name_and_value looks like [name]=[value]. If the value is omitted, it is set to 1.
pub fn defineCMacroRaw(m: *Module, name_and_value: []const u8) void {
    const b = m.builder;
    m.c_macros.append(b.dupe(name_and_value)) catch @panic("OOM");
}

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

pub fn linkLibrary(m: *Module, lib: *CompileStep) void {
    assert(lib.kind == .lib);
    m.linkLibraryOrObject(lib);
}

fn linkLibraryOrObject(m: *Module, other: *CompileStep) void {
    m.link_objects.append(.{ .other_step = other }) catch @panic("OOM");
    m.include_dirs.append(.{ .other_step = other }) catch @panic("OOM");

    // TODO: Need to depend on installed_headers steps
    // for (other.main_module.installed_headers.items) |install_step| {
    //     self.step.dependOn(install_step);
    // }
}

pub fn addAssemblyFile(m: *Module, path: []const u8) void {
    const b = m.builder;
    m.link_objects.append(.{
        .assembly_file = .{ .path = b.dupe(path) },
    }) catch @panic("OOM");
}

pub fn addAssemblyFileSource(m: *Module, source: FileSource) void {
    const b = m.builder;
    const source_duped = source.dupe(b);
    m.link_objects.append(.{ .assembly_file = source_duped }) catch @panic("OOM");
    // source_duped.addStepDependencies(&self.step);
    // TODO
}

pub fn addObjectFile(m: *Module, source_file: []const u8) void {
    m.addObjectFileSource(.{ .path = source_file });
}

pub fn addObjectFileSource(m: *Module, source: FileSource) void {
    const b = m.builder;
    m.link_objects.append(.{ .static_path = source.dupe(b) }) catch @panic("OOM");
    // source.addStepDependencies(&self.step);
    // TODO
}

pub fn addObject(m: *Module, obj: *CompileStep) void {
    assert(obj.kind == .obj);
    m.linkLibraryOrObject(obj);
}

pub fn linkSystemLibrary(m: *Module, name: []const u8) void {
    m.linkSystemLibraryInner(name, .{});
}

pub fn linkSystemLibraryNeeded(m: *Module, name: []const u8) void {
    m.linkSystemLibraryInner(name, .{ .needed = true });
}

pub fn linkSystemLibraryWeak(m: *Module, name: []const u8) void {
    m.linkSystemLibraryInner(name, .{ .weak = true });
}

fn linkSystemLibraryInner(m: *Module, name: []const u8, opts: struct {
    needed: bool = false,
    weak: bool = false,
}) void {
    const b = m.builder;
    if (isLibCLibrary(name)) {
        m.linkLibC();
        return;
    }
    if (isLibCppLibrary(name)) {
        m.linkLibCpp();
        return;
    }

    m.link_objects.append(.{
        .system_lib = .{
            .name = b.dupe(name),
            .needed = opts.needed,
            .weak = opts.weak,
            .use_pkg_config = .yes,
        },
    }) catch @panic("OOM");
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

/// Returns whether the module depends on a particular system library.
pub fn dependsOnSystemLibrary(m: Module, name: []const u8) bool {
    if (isLibCLibrary(name)) {
        return m.is_linking_libc;
    }
    if (isLibCppLibrary(name)) {
        return m.is_linking_libcpp;
    }
    for (m.link_objects.items) |link_object| {
        switch (link_object) {
            .system_lib => |lib| if (mem.eql(u8, lib.name, name)) return true,
            else => continue,
        }
    }
    return false;
}

pub const FrameworkLinkInfo = struct {
    needed: bool = false,
    weak: bool = false,
};

pub fn linkFramework(m: *Module, framework_name: []const u8) void {
    const b = m.builder;
    m.frameworks.put(b.dupe(framework_name), .{}) catch @panic("OOM");
}

pub fn linkFrameworkNeeded(m: *Module, framework_name: []const u8) void {
    const b = m.builder;
    m.frameworks.put(b.dupe(framework_name), .{
        .needed = true,
    }) catch @panic("OOM");
}

pub fn linkFrameworkWeak(m: *Module, framework_name: []const u8) void {
    const b = m.builder;
    m.frameworks.put(b.dupe(framework_name), .{
        .weak = true,
    }) catch @panic("OOM");
}

pub const IncludeDir = union(enum) {
    raw_path: []const u8,
    raw_path_system: []const u8,
    other_step: *CompileStep,
    config_header_step: *ConfigHeaderStep,
};

pub fn addSystemIncludePath(m: *Module, path: []const u8) void {
    const b = m.builder;
    m.include_dirs.append(IncludeDir{ .raw_path_system = b.dupe(path) }) catch @panic("OOM");
}

pub fn addIncludePath(m: *Module, path: []const u8) void {
    const b = m.builder;
    m.include_dirs.append(IncludeDir{ .raw_path = b.dupe(path) }) catch @panic("OOM");
}

pub fn addConfigHeader(m: *Module, config_header: *ConfigHeaderStep) void {
    // m.step.dependOn(&config_header.step);
    // TODO
    m.include_dirs.append(.{ .config_header_step = config_header }) catch @panic("OOM");
}

pub fn addLibraryPath(m: *Module, path: []const u8) void {
    const b = m.builder;
    m.lib_paths.append(.{ .path = b.dupe(path) }) catch @panic("OOM");
}

pub fn addLibraryPathDirectorySource(m: *Module, directory_source: FileSource) void {
    m.lib_paths.append(directory_source) catch @panic("OOM");
    // directory_source.addStepDependencies(&self.step);
    // TODO
}

pub fn addRPath(m: *Module, path: []const u8) void {
    const b = m.builder;
    m.rpaths.append(.{ .path = b.dupe(path) }) catch @panic("OOM");
}

pub fn addRPathDirectorySource(m: *Module, directory_source: FileSource) void {
    m.rpaths.append(directory_source) catch @panic("OOM");
    // directory_source.addStepDependencies(&m.step);
    // TODO
}

pub fn addFrameworkPath(m: *Module, dir_path: []const u8) void {
    const b = m.builder;
    m.framework_dirs.append(.{ .path = b.dupe(dir_path) }) catch @panic("OOM");
}

pub fn addFrameworkPathDirectorySource(m: *Module, directory_source: FileSource) void {
    m.framework_dirs.append(directory_source) catch @panic("OOM");
    // directory_source.addStepDependencies(&self.step);
    // TODO
}

pub fn forceUndefinedSymbol(m: *Module, symbol_name: []const u8) void {
    const b = m.builder;
    m.force_undefined_symbols.put(b.dupe(symbol_name), {}) catch @panic("OOM");
}

pub fn setLinkerScriptPath(m: *Module, source: FileSource) void {
    const b = m.builder;
    m.linker_script = source.dupe(b);
    // source.addStepDependencies(&self.step);
    // TODO
}

const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const FileSource = Build.FileSource;
const CompileStep = Build.CompileStep;
const ConfigHeaderStep = Build.ConfigHeaderStep;
const OptionsStep = Build.OptionsStep;
const InstallDirStep = Build.InstallDirStep;
const InstallDir = Build.InstallDir;
const CSourceFile = Build.CSourceFile;
const CSourceFiles = Build.CSourceFiles;
const ModuleDependency = Build.ModuleDependency;
const CreateModuleOptions = Build.CreateModuleOptions;

const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const StringArrayHashMap = std.StringArrayHashMap;
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const mem = std.mem;
const fs = std.fs;

pub const addSystemIncludeDir = @compileError("deprecated; use addSystemIncludePath");
pub const addIncludeDir = @compileError("deprecated; use addIncludePath");
pub const addLibPath = @compileError("deprecated, use addLibraryPath");
pub const addFrameworkDir = @compileError("deprecated, use addFrameworkPath");
