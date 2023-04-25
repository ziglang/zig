const Module = @This();

step: Step,
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

pub fn create(owner: *Build, name: ?[]const u8, options: CreateModuleOptions) *Module {
    const arena = owner.allocator;
    const mod = owner.allocator.create(Module) catch @panic("OOM");
    mod.* = .{
        .step = Step.init(.{
            .id = .module,
            .name = if (name) |n|
                std.fmt.allocPrint(arena, "module {s}", .{n}) catch @panic("OOM")
            else
                "module",
            .owner = owner,
        }),
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

    if (options.source_file) |rs| {
        rs.addStepDependencies(&mod.step);
    }

    if (options.c_source_files) |c_files| {
        mod.addCSourceFiles(c_files.files, c_files.flags);
    }

    for (options.dependencies) |dep| {
        mod.step.dependOn(&dep.module.step);
    }

    return mod;
}

pub fn appendArgs(
    m: *Module,
    compile_step: *CompileStep,
    name: []const u8,
    zig_args: *ArrayList([]const u8),
) !void {
    try zig_args.append("--mod");
    try zig_args.append(name);

    var num_source_files: usize = 0;

    if (m.source_file) |rs| {
        try zig_args.append(rs.getPath2(m.step.owner, &m.step));
        num_source_files += 1;
    }

    for (m.link_objects.items) |obj| {
        switch (obj) {
            .c_source_file => |_| {
                // try zig_args.append(c.source.getPath2(m.step.owner, &m.step));
                num_source_files +|= 1;
            },
            .c_source_files => |c_files| {
                for (c_files.files) |_| {
                    // try zig_args.append(file_path);
                    num_source_files +|= 1;
                }
            },
            // TODO: Should ASM files be included here?
            .assembly_file => |_| {
                // try zig_args.append(asm_file.getPath2(m.step.owner, &m.step));
                num_source_files +|= 1;
            },
            else => {},
        }
    }

    if (num_source_files == 0) {
        return m.step.fail("Module '{s}' must have at least one source file", .{name});
    }

    try zig_args.append("--args");

    // We will add link objects from transitive dependencies, but we want to keep
    // all link objects in the same order provided.
    // This array is used to keep m.link_objects immutable.
    const b = m.step.owner;
    var transitive_deps: TransitiveDeps = .{
        .link_objects = ArrayList(LinkObject).init(b.allocator),
        .include_dirs = ArrayList(IncludeDir).init(b.allocator),
        .seen_system_libs = StringHashMap(void).init(b.allocator),
        .seen_steps = std.AutoHashMap(*const Step, void).init(b.allocator),
        .is_linking_libcpp = m.is_linking_libcpp,
        .is_linking_libc = m.is_linking_libc,
        .frameworks = &m.frameworks,
    };

    try transitive_deps.seen_steps.put(&m.step, {});
    try transitive_deps.add(m);

    var prev_has_extra_flags = false;

    for (transitive_deps.link_objects.items) |link_object| {
        switch (link_object) {
            .static_path => |static_path| try zig_args.append(static_path.getPath(b)),

            .other_step => |other| switch (other.kind) {
                .exe => @panic("Cannot link with an executable build artifact"),
                .@"test" => @panic("Cannot link with a test"),
                .obj => {
                    try zig_args.append(other.getOutputSource().getPath(b));
                },
                .lib => l: {
                    if (compile_step.isStaticLibrary() and other.isStaticLibrary()) {
                        // Avoid putting a static library inside a static library.
                        break :l;
                    }

                    const full_path_lib = other.getOutputLibSource().getPath(b);
                    try zig_args.append(full_path_lib);

                    if (other.linkage == Linkage.dynamic and !compile_step.target.isWindows()) {
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
                    if (system_lib.weak) break :prefix "-weak-l";
                    break :prefix "-l";
                };
                switch (system_lib.use_pkg_config) {
                    .no => try zig_args.append(b.fmt("{s}{s}", .{ prefix, system_lib.name })),
                    .yes, .force => {
                        if (compile_step.runPkgConfig(system_lib.name)) |args| {
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
                                    try zig_args.append(b.fmt("{s}{s}", .{
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
                try zig_args.append(asm_file.getPath(b));
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
                try zig_args.append(c_source_file.source.getPath(b));
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
                    try zig_args.append(b.pathFromRoot(file));
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

    for (transitive_deps.include_dirs.items) |include_dir| {
        switch (include_dir) {
            .raw_path => |include_path| {
                try zig_args.append("-I");
                try zig_args.append(b.pathFromRoot(include_path));
            },
            .raw_path_system => |include_path| {
                if (b.sysroot != null) {
                    try zig_args.append("-iwithsysroot");
                } else {
                    try zig_args.append("-isystem");
                }

                const resolved_include_path = b.pathFromRoot(include_path);

                const common_include_path = if (builtin.os.tag == .windows and b.sysroot != null and fs.path.isAbsolute(resolved_include_path)) blk: {
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
                    const h_path = other.getOutputHSource().getPath(b);
                    try zig_args.append("-isystem");
                    try zig_args.append(fs.path.dirname(h_path).?);
                }
                if (other.main_module.installed_headers.items.len > 0) {
                    try zig_args.append("-I");
                    try zig_args.append(b.pathJoin(&.{
                        other.step.owner.install_prefix, "include",
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
}

fn moduleDependenciesToArrayHashMap(arena: Allocator, deps: []const ModuleDependency) std.StringArrayHashMap(*Module) {
    var result = std.StringArrayHashMap(*Module).init(arena);
    for (deps) |dep| {
        result.put(dep.name, dep.module) catch @panic("OOM");
    }
    return result;
}

pub fn addOptions(m: *Module, name: []const u8, options: *OptionsStep) void {
    m.dependencies.put(m.step.owner.dupe(name), options.addModule(name)) catch @panic("OOM");
    m.step.dependOn(&options.step);
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
    const b = m.step.owner;
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
    const b = m.step.owner;
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
    const b = m.step.owner;
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
    const b = m.step.owner;
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
    const b = m.step.owner;
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
    const b = m.step.owner;
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
    const b = m.step.owner;
    const c_source_file = b.allocator.create(CSourceFile) catch @panic("OOM");
    c_source_file.* = source.dupe(b);
    m.link_objects.append(.{ .c_source_file = c_source_file }) catch @panic("OOM");
    source.source.addStepDependencies(&m.step);
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
    const b = m.step.owner;
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
    const b = m.step.owner;
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
    const b = m.step.owner;
    const install_dir = b.addInstallDirectory(options);
    b.getInstallStep().dependOn(&install_dir.step);
    m.installed_headers.append(&install_dir.step) catch @panic("OOM");
}

pub fn installLibraryHeaders(m: *Module, l: *CompileStep) void {
    assert(l.kind == .lib);
    const b = m.step.owner;
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
    const b = m.step.owner;
    const macro = std.Build.constructCMacro(b.allocator, name, value);
    m.c_macros.append(macro) catch @panic("OOM");
}

/// name_and_value looks like [name]=[value]. If the value is omitted, it is set to 1.
pub fn defineCMacroRaw(m: *Module, name_and_value: []const u8) void {
    const b = m.step.owner;
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

    for (other.main_module.installed_headers.items) |install_step| {
        m.step.dependOn(install_step);
    }
}

pub fn addAssemblyFile(m: *Module, path: []const u8) void {
    const b = m.step.owner;
    m.link_objects.append(.{
        .assembly_file = .{ .path = b.dupe(path) },
    }) catch @panic("OOM");
}

pub fn addAssemblyFileSource(m: *Module, source: FileSource) void {
    const b = m.step.owner;
    const source_duped = source.dupe(b);
    m.link_objects.append(.{ .assembly_file = source_duped }) catch @panic("OOM");
    source_duped.addStepDependencies(&m.step);
}

pub fn addObjectFile(m: *Module, source_file: []const u8) void {
    m.addObjectFileSource(.{ .path = source_file });
}

pub fn addObjectFileSource(m: *Module, source: FileSource) void {
    const b = m.step.owner;
    m.link_objects.append(.{ .static_path = source.dupe(b) }) catch @panic("OOM");
    source.addStepDependencies(&m.step);
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
    const b = m.step.owner;
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
    const b = m.step.owner;
    m.frameworks.put(b.dupe(framework_name), .{}) catch @panic("OOM");
}

pub fn linkFrameworkNeeded(m: *Module, framework_name: []const u8) void {
    const b = m.step.owner;
    m.frameworks.put(b.dupe(framework_name), .{
        .needed = true,
    }) catch @panic("OOM");
}

pub fn linkFrameworkWeak(m: *Module, framework_name: []const u8) void {
    const b = m.step.owner;
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
    const b = m.step.owner;
    m.include_dirs.append(IncludeDir{ .raw_path_system = b.dupe(path) }) catch @panic("OOM");
}

pub fn addIncludePath(m: *Module, path: []const u8) void {
    const b = m.step.owner;
    m.include_dirs.append(IncludeDir{ .raw_path = b.dupe(path) }) catch @panic("OOM");
}

pub fn addConfigHeader(m: *Module, config_header: *ConfigHeaderStep) void {
    m.step.dependOn(&config_header.step);
    m.include_dirs.append(.{ .config_header_step = config_header }) catch @panic("OOM");
}

pub fn addLibraryPath(m: *Module, path: []const u8) void {
    const b = m.step.owner;
    m.lib_paths.append(.{ .path = b.dupe(path) }) catch @panic("OOM");
}

pub fn addLibraryPathDirectorySource(m: *Module, directory_source: FileSource) void {
    m.lib_paths.append(directory_source) catch @panic("OOM");
    directory_source.addStepDependencies(&m.step);
}

pub fn addRPath(m: *Module, path: []const u8) void {
    const b = m.step.owner;
    m.rpaths.append(.{ .path = b.dupe(path) }) catch @panic("OOM");
}

pub fn addRPathDirectorySource(m: *Module, directory_source: FileSource) void {
    m.rpaths.append(directory_source) catch @panic("OOM");
    directory_source.addStepDependencies(&m.step);
}

pub fn addFrameworkPath(m: *Module, dir_path: []const u8) void {
    const b = m.step.owner;
    m.framework_dirs.append(.{ .path = b.dupe(dir_path) }) catch @panic("OOM");
}

pub fn addFrameworkPathDirectorySource(m: *Module, directory_source: FileSource) void {
    m.framework_dirs.append(directory_source) catch @panic("OOM");
    directory_source.addStepDependencies(&m.step);
}

pub fn forceUndefinedSymbol(m: *Module, symbol_name: []const u8) void {
    const b = m.step.owner;
    m.force_undefined_symbols.put(b.dupe(symbol_name), {}) catch @panic("OOM");
}

pub fn setLinkerScriptPath(m: *Module, source: FileSource) void {
    const b = m.step.owner;
    m.linker_script = source.dupe(b);
    source.addStepDependencies(&m.step);
}

const TransitiveDeps = struct {
    link_objects: ArrayList(LinkObject),
    include_dirs: ArrayList(IncludeDir),
    seen_system_libs: StringHashMap(void),
    seen_steps: std.AutoHashMap(*const Step, void),
    is_linking_libcpp: bool,
    is_linking_libc: bool,
    frameworks: *StringHashMap(FrameworkLinkInfo),

    fn add(td: *TransitiveDeps, module: *Module) !void {
        td.is_linking_libcpp = td.is_linking_libcpp or module.is_linking_libcpp;
        td.is_linking_libc = td.is_linking_libc or module.is_linking_libc;

        try td.link_objects.ensureUnusedCapacity(module.link_objects.items.len);

        for (module.link_objects.items) |link_object| {
            try td.link_objects.append(link_object);
            switch (link_object) {
                .other_step => |other| try td.addInner(other.main_module, other.isDynamicLibrary()),
                else => {},
            }
        }

        for (module.include_dirs.items) |include_dir| {
            try td.include_dirs.append(include_dir);
        }

        {
            var it = module.dependencies.iterator();
            while (it.next()) |kv| {
                try td.add(kv.value_ptr.*);
            }
        }
    }

    fn addInner(td: *TransitiveDeps, other: *Module, dyn: bool) !void {
        // Inherit dependency on libc and libc++
        td.is_linking_libcpp = td.is_linking_libcpp or other.is_linking_libcpp;
        td.is_linking_libc = td.is_linking_libc or other.is_linking_libc;

        {
            var it = other.dependencies.iterator();
            while (it.next()) |kv| {
                try td.addInner(kv.value_ptr.*, dyn);
            }
        }

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

                    try addInner(td, inner_other.main_module, dyn or inner_other.isDynamicLibrary());
                },
                else => continue,
            }
        }
    }
};

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
const Linkage = CompileStep.Linkage;

const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const StringArrayHashMap = std.StringArrayHashMap;
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;
const mem = std.mem;
const fs = std.fs;
const panic = std.debug.panic;
const builtin = @import("builtin");

pub const addSystemIncludeDir = @compileError("deprecated; use addSystemIncludePath");
pub const addIncludeDir = @compileError("deprecated; use addIncludePath");
pub const addLibPath = @compileError("deprecated, use addLibraryPath");
pub const addFrameworkDir = @compileError("deprecated, use addFrameworkPath");
