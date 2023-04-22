const Module = @This();

builder: *Build,
/// This could either be a generated file, in which case the module
/// contains exactly one file, or it could be a path to the root source
/// file of directory of files which constitute the module.
source_file: FileSource,
dependencies: std.StringArrayHashMap(*Module),
include_dirs: std.ArrayListUnmanaged(CompileStep.IncludeDir) = .{},
lib_paths: std.ArrayListUnmanaged([]const u8) = .{},
rpaths: std.ArrayListUnmanaged([]const u8) = .{},
framework_dirs: std.ArrayListUnmanaged([]const u8) = .{},
system_libs: std.ArrayListUnmanaged(CompileStep.SystemLib) = .{},
libs: std.ArrayListUnmanaged(*CompileStep) = .{},
config_headers: std.ArrayListUnmanaged(*ConfigHeaderStep) = .{},
installed_headers: std.ArrayListUnmanaged(InstalledHeader) = .{},
frameworks: std.StringArrayHashMapUnmanaged(CompileStep.FrameworkLinkInfo) = .{},

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

pub fn addIncludePath(m: *Module, path: []const u8) void {
    m.include_dirs.append(
        m.builder.allocator,
        CompileStep.IncludeDir{ .raw_path = m.builder.dupe(path) },
    ) catch @panic("OOM");
}

pub fn addSystemIncludePath(m: *Module, path: []const u8) void {
    m.include_dirs.append(
        m.builder.allocator,
        CompileStep.IncludeDir{ .raw_path_system = m.builder.dupe(path) },
    ) catch @panic("OOM");
}

pub fn addRPath(m: *Module, path: []const u8) void {
    m.rpaths.append(m.builder.allocator, m.builder.dupe(path)) catch @panic("OOM");
}

pub fn addFrameworkPath(m: *Module, dir_path: []const u8) void {
    m.framework_dirs.append(m.builder.allocator, m.builder.dupe(dir_path)) catch @panic("OOM");
}

pub fn addLibraryPath(m: *Module, library_path: []const u8) void {
    m.lib_paths.append(m.builder.allocator, m.builder.dupe(library_path)) catch @panic("OOM");
}

pub fn addConfigHeader(m: *Module, config_header: *Build.ConfigHeaderStep) void {
    m.config_headers.append(m.builder.allocator, config_header) catch @panic("OOM");
}

pub fn linkLibC(m: *Module) void {
    m.linkSystemLibrary("c");
}

pub fn linkLibCpp(m: *Module) void {
    m.linkSystemLibrary("c++");
}

pub fn linkLibrary(m: *Module, lib: *CompileStep) void {
    m.libs.append(m.builder.allocator, lib) catch @panic("OOM");
}

pub fn linkSystemLibrary(m: *Module, name: []const u8) void {
    m.system_libs.append(m.builder.allocator, .{
        .name = m.builder.dupe(name),
        .needed = false,
        .weak = false,
        .use_pkg_config = .yes,
    }) catch @panic("OOM");
}

pub fn linkSystemLibraryNeeded(m: *Module, name: []const u8) void {
    m.system_libs.append(m.builder.allocator, .{
        .name = m.builder.dupe(name),
        .needed = true,
        .weak = false,
        .use_pkg_config = .yes,
    }) catch @panic("OOM");
}

pub fn linkSystemLibraryWeak(m: *Module, name: []const u8) void {
    m.system_libs.append(m.builder.allocator, .{
        .name = m.builder.dupe(name),
        .needed = false,
        .weak = true,
        .use_pkg_config = .yes,
    }) catch @panic("OOM");
}

pub fn linkSystemLibraryName(m: *Module, name: []const u8) void {
    m.system_libs.append(m.builder.allocator, .{
        .name = m.builder.dupe(name),
        .needed = false,
        .weak = false,
        .use_pkg_config = .no,
    }) catch @panic("OOM");
}

pub fn linkSystemLibraryNeededName(m: *Module, name: []const u8) void {
    m.system_libs.append(m.builder.allocator, .{
        .name = m.builder.dupe(name),
        .needed = true,
        .weak = false,
        .use_pkg_config = .no,
    }) catch @panic("OOM");
}

pub fn linkSystemLibraryWeakName(m: *Module, name: []const u8) void {
    m.system_libs.append(m.builder.allocator, .{
        .name = m.builder.dupe(name),
        .needed = false,
        .weak = true,
        .use_pkg_config = .no,
    }) catch @panic("OOM");
}

pub fn linkSystemLibraryPkgConfigOnly(m: *Module, lib_name: []const u8) void {
    m.system_libs.append(m.builder.allocator, .{
        .name = m.builder.dupe(lib_name),
        .needed = false,
        .weak = false,
        .use_pkg_config = .force,
    }) catch @panic("OOM");
}

pub fn linkSystemLibraryNeededPkgConfigOnly(m: *Module, lib_name: []const u8) void {
    m.system_libs.append(m.builder.allocator, .{
        .name = m.builder.dupe(lib_name),
        .needed = true,
        .weak = false,
        .use_pkg_config = .force,
    }) catch @panic("OOM");
}

pub fn linkFramework(m: *Module, framework_name: []const u8) void {
    m.frameworks.put(m.builder.allocator, m.builder.dupe(framework_name), .{}) catch @panic("OOM");
}

pub fn linkFrameworkNeeded(m: *Module, framework_name: []const u8) void {
    m.frameworks.put(m.builder.allocator, m.builder.dupe(framework_name), .{
        .needed = true,
    }) catch @panic("OOM");
}

pub fn linkFrameworkWeak(m: *Module, framework_name: []const u8) void {
    m.frameworks.put(m.builder.allocator, m.builder.dupe(framework_name), .{
        .weak = true,
    }) catch @panic("OOM");
}

pub fn installHeader(m: *Module, src_path: []const u8, dest_rel_path: []const u8) void {
    m.installed_headers.append(m.builder.allocator, .{
        .header = .{
            .source_path = m.builder.dupe(src_path),
            .dest_rel_path = dest_rel_path,
        },
    }) catch @panic("OOM");
}

pub fn installConfigHeader(
    m: *Module,
    config_header: *ConfigHeaderStep,
    options: CompileStep.InstallConfigHeaderOptions,
) void {
    m.installed_headers.append(m.builder.allocator, .{
        .config_header = .{
            .config_header = config_header,
            .options = options,
        },
    }) catch @panic("OOM");
}

pub fn installHeadersDirectory(
    m: *Module,
    src_dir_path: []const u8,
    dest_rel_path: []const u8,
) void {
    return m.installHeadersDirectoryOptions(.{
        .source_dir = m.builder.dupe(src_dir_path),
        .install_dir = .header,
        .install_subdir = dest_rel_path,
    });
}

pub fn installHeadersDirectoryOptions(
    m: *Module,
    options: InstallDirStep.Options,
) void {
    m.installed_headers.append(m.builder.allocator, .{
        .header_dir_step = options,
    }) catch @panic("OOM");
}

pub fn installLibraryHeaders(m: *Module, l: *CompileStep) void {
    m.installed_headers.append(m.builder.allocator, .{
        .lib_step = l,
    }) catch @panic("OOM");
}

pub fn addOptions(m: *Module, name: []const u8, options: *OptionsStep) void {
    m.dependencies.put(m.builder.dupe(name), options.addModule(name)) catch @panic("OOM");
}

const std = @import("std");
const Build = std.Build;
const FileSource = Build.FileSource;
const CompileStep = Build.CompileStep;
const ConfigHeaderStep = Build.ConfigHeaderStep;
const OptionsStep = Build.OptionsStep;
const InstallDirStep = Build.InstallDirStep;
