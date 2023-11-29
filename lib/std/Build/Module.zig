/// The one responsible for creating this module.
owner: *std.Build,
/// Tracks the set of steps that depend on this `Module`. This ensures that
/// when making this `Module` depend on other `Module` objects and `Step`
/// objects, respective `Step` dependencies can be added.
depending_steps: std.AutoArrayHashMapUnmanaged(*std.Build.Step.Compile, void),
/// This could either be a generated file, in which case the module
/// contains exactly one file, or it could be a path to the root source
/// file of directory of files which constitute the module.
/// If `null`, it means this module is made up of only `link_objects`.
root_source_file: ?LazyPath,
/// The modules that are mapped into this module's import table.
import_table: std.StringArrayHashMap(*Module),

target: std.zig.CrossTarget,
target_info: NativeTargetInfo,
optimize: std.builtin.OptimizeMode,
dwarf_format: ?std.dwarf.Format,

c_macros: std.ArrayList([]const u8),
include_dirs: std.ArrayList(IncludeDir),
lib_paths: std.ArrayList(LazyPath),
rpaths: std.ArrayList(LazyPath),
frameworks: std.StringArrayHashMapUnmanaged(FrameworkLinkInfo),
c_std: std.Build.CStd,
link_objects: std.ArrayList(LinkObject),

strip: ?bool,
unwind_tables: ?bool,
single_threaded: ?bool,
stack_protector: ?bool,
stack_check: ?bool,
sanitize_c: ?bool,
sanitize_thread: ?bool,
code_model: std.builtin.CodeModel,
/// Whether to emit machine code that integrates with Valgrind.
valgrind: ?bool,
/// Position Independent Code
pic: ?bool,
red_zone: ?bool,
/// Whether to omit the stack frame pointer. Frees up a register and makes it
/// more more difficiult to obtain stack traces. Has target-dependent effects.
omit_frame_pointer: ?bool,
/// `true` requires a compilation that includes this Module to link libc.
/// `false` causes a build failure if a compilation that includes this Module would link libc.
/// `null` neither requires nor prevents libc from being linked.
link_libc: ?bool,
/// `true` requires a compilation that includes this Module to link libc++.
/// `false` causes a build failure if a compilation that includes this Module would link libc++.
/// `null` neither requires nor prevents libc++ from being linked.
link_libcpp: ?bool,

/// Symbols to be exported when compiling to WebAssembly.
export_symbol_names: []const []const u8 = &.{},

pub const LinkObject = union(enum) {
    static_path: LazyPath,
    other_step: *std.Build.Step.Compile,
    system_lib: SystemLib,
    assembly_file: LazyPath,
    c_source_file: *CSourceFile,
    c_source_files: *CSourceFiles,
    win32_resource_file: *RcSourceFile,
};

pub const SystemLib = struct {
    name: []const u8,
    needed: bool,
    weak: bool,
    use_pkg_config: UsePkgConfig,
    preferred_link_mode: std.builtin.LinkMode,
    search_strategy: SystemLib.SearchStrategy,

    pub const UsePkgConfig = enum {
        /// Don't use pkg-config, just pass -lfoo where foo is name.
        no,
        /// Try to get information on how to link the library from pkg-config.
        /// If that fails, fall back to passing -lfoo where foo is name.
        yes,
        /// Try to get information on how to link the library from pkg-config.
        /// If that fails, error out.
        force,
    };

    pub const SearchStrategy = enum { paths_first, mode_first, no_fallback };
};

pub const CSourceFiles = struct {
    dependency: ?*std.Build.Dependency,
    /// If `dependency` is not null relative to it,
    /// else relative to the build root.
    files: []const []const u8,
    flags: []const []const u8,
};

pub const CSourceFile = struct {
    file: LazyPath,
    flags: []const []const u8,

    pub fn dupe(self: CSourceFile, b: *std.Build) CSourceFile {
        return .{
            .file = self.file.dupe(b),
            .flags = b.dupeStrings(self.flags),
        };
    }
};

pub const RcSourceFile = struct {
    file: LazyPath,
    /// Any option that rc.exe accepts will work here, with the exception of:
    /// - `/fo`: The output filename is set by the build system
    /// - `/p`: Only running the preprocessor is not supported in this context
    /// - `/:no-preprocess` (non-standard option): Not supported in this context
    /// - Any MUI-related option
    /// https://learn.microsoft.com/en-us/windows/win32/menurc/using-rc-the-rc-command-line-
    ///
    /// Implicitly defined options:
    ///  /x (ignore the INCLUDE environment variable)
    ///  /D_DEBUG or /DNDEBUG depending on the optimization mode
    flags: []const []const u8 = &.{},

    pub fn dupe(self: RcSourceFile, b: *std.Build) RcSourceFile {
        return .{
            .file = self.file.dupe(b),
            .flags = b.dupeStrings(self.flags),
        };
    }
};

pub const IncludeDir = union(enum) {
    path: LazyPath,
    path_system: LazyPath,
    path_after: LazyPath,
    framework_path: LazyPath,
    framework_path_system: LazyPath,
    other_step: *std.Build.Step.Compile,
    config_header_step: *std.Build.Step.ConfigHeader,
};

pub const FrameworkLinkInfo = struct {
    needed: bool = false,
    weak: bool = false,
};

pub const CreateOptions = struct {
    target: std.zig.CrossTarget,
    target_info: ?NativeTargetInfo = null,
    optimize: std.builtin.OptimizeMode,
    root_source_file: ?LazyPath = null,
    import_table: []const Import = &.{},
    link_libc: ?bool = null,
    link_libcpp: ?bool = null,
    single_threaded: ?bool = null,
    strip: ?bool = null,
    unwind_tables: ?bool = null,
    dwarf_format: ?std.dwarf.Format = null,
    c_std: std.Build.CStd = .C99,
    code_model: std.builtin.CodeModel = .default,
    stack_protector: ?bool = null,
    stack_check: ?bool = null,
    sanitize_c: ?bool = null,
    sanitize_thread: ?bool = null,
    valgrind: ?bool = null,
    pic: ?bool = null,
    red_zone: ?bool = null,
    /// Whether to omit the stack frame pointer. Frees up a register and makes it
    /// more more difficiult to obtain stack traces. Has target-dependent effects.
    omit_frame_pointer: ?bool = null,
};

pub const Import = struct {
    name: []const u8,
    module: *Module,
};

pub fn init(owner: *std.Build, options: CreateOptions, compile: ?*std.Build.Step.Compile) Module {
    var m: Module = .{
        .owner = owner,
        .depending_steps = .{},
        .root_source_file = if (options.root_source_file) |lp| lp.dupe(owner) else null,
        .import_table = std.StringArrayHashMap(*Module).init(owner.allocator),
        .target = options.target,
        .target_info = options.target_info orelse
            NativeTargetInfo.detect(options.target) catch @panic("unhandled error"),
        .optimize = options.optimize,
        .link_libc = options.link_libc,
        .link_libcpp = options.link_libcpp,
        .dwarf_format = options.dwarf_format,
        .c_macros = std.ArrayList([]const u8).init(owner.allocator),
        .include_dirs = std.ArrayList(IncludeDir).init(owner.allocator),
        .lib_paths = std.ArrayList(LazyPath).init(owner.allocator),
        .rpaths = std.ArrayList(LazyPath).init(owner.allocator),
        .frameworks = .{},
        .c_std = options.c_std,
        .link_objects = std.ArrayList(LinkObject).init(owner.allocator),
        .strip = options.strip,
        .unwind_tables = options.unwind_tables,
        .single_threaded = options.single_threaded,
        .stack_protector = options.stack_protector,
        .stack_check = options.stack_check,
        .sanitize_c = options.sanitize_c,
        .sanitize_thread = options.sanitize_thread,
        .code_model = options.code_model,
        .valgrind = options.valgrind,
        .pic = options.pic,
        .red_zone = options.red_zone,
        .omit_frame_pointer = options.omit_frame_pointer,
        .export_symbol_names = &.{},
    };

    if (compile) |c| {
        m.depending_steps.put(owner.allocator, c, {}) catch @panic("OOM");
    }

    m.import_table.ensureUnusedCapacity(options.import_table.len) catch @panic("OOM");
    for (options.import_table) |dep| {
        m.import_table.putAssumeCapacity(dep.name, dep.module);
    }

    var it = m.iterateDependencies(null);
    while (it.next()) |item| addShallowDependencies(&m, item.module);

    return m;
}

pub fn create(owner: *std.Build, options: CreateOptions) *Module {
    const m = owner.allocator.create(Module) catch @panic("OOM");
    m.* = init(owner, options, null);
    return m;
}

/// Adds an existing module to be used with `@import`.
pub fn addImport(m: *Module, name: []const u8, module: *Module) void {
    const b = m.owner;
    m.import_table.put(b.dupe(name), module) catch @panic("OOM");

    var it = module.iterateDependencies(null);
    while (it.next()) |item| addShallowDependencies(m, item.module);
}

/// Creates step dependencies and updates `depending_steps` of `dependee` so that
/// subsequent calls to `addImport` on `dependee` will additionally create step
/// dependencies on `m`'s `depending_steps`.
fn addShallowDependencies(m: *Module, dependee: *Module) void {
    if (dependee.root_source_file) |lazy_path| addLazyPathDependencies(m, dependee, lazy_path);
    for (dependee.lib_paths.items) |lib_path| addLazyPathDependencies(m, dependee, lib_path);
    for (dependee.rpaths.items) |rpath| addLazyPathDependencies(m, dependee, rpath);

    for (dependee.link_objects.items) |link_object| switch (link_object) {
        .other_step => |compile| addStepDependencies(m, dependee, &compile.step),

        .static_path,
        .assembly_file,
        => |lp| addLazyPathDependencies(m, dependee, lp),

        .c_source_file => |x| addLazyPathDependencies(m, dependee, x.file),
        .win32_resource_file => |x| addLazyPathDependencies(m, dependee, x.file),

        .c_source_files,
        .system_lib,
        => {},
    };
}

fn addLazyPathDependencies(m: *Module, module: *Module, lazy_path: LazyPath) void {
    addLazyPathDependenciesOnly(m, lazy_path);
    if (m != module) {
        for (m.depending_steps.keys()) |compile| {
            module.depending_steps.put(m.owner.allocator, compile, {}) catch @panic("OOM");
        }
    }
}

fn addLazyPathDependenciesOnly(m: *Module, lazy_path: LazyPath) void {
    for (m.depending_steps.keys()) |compile| {
        lazy_path.addStepDependencies(&compile.step);
    }
}

fn addStepDependencies(m: *Module, module: *Module, dependee: *std.Build.Step) void {
    addStepDependenciesOnly(m, dependee);
    if (m != module) {
        for (m.depending_steps.keys()) |compile| {
            module.depending_steps.put(m.owner.allocator, compile, {}) catch @panic("OOM");
        }
    }
}

fn addStepDependenciesOnly(m: *Module, dependee: *std.Build.Step) void {
    for (m.depending_steps.keys()) |compile| {
        compile.step.dependOn(dependee);
    }
}

/// Creates a new module and adds it to be used with `@import`.
pub fn addAnonymousImport(m: *Module, name: []const u8, options: std.Build.CreateModuleOptions) void {
    const b = m.step.owner;
    const module = b.createModule(options);
    return addImport(m, name, module);
}

pub fn addOptions(m: *Module, module_name: []const u8, options: *std.Build.Step.Options) void {
    addImport(m, module_name, options.createModule());
}

pub const DependencyIterator = struct {
    allocator: std.mem.Allocator,
    index: usize,
    set: std.AutoArrayHashMapUnmanaged(Key, []const u8),

    pub const Key = struct {
        /// The compilation that contains the `Module`. Note that a `Module` might be
        /// used by more than one compilation.
        compile: ?*std.Build.Step.Compile,
        module: *Module,
    };

    pub const Item = struct {
        /// The compilation that contains the `Module`. Note that a `Module` might be
        /// used by more than one compilation.
        compile: ?*std.Build.Step.Compile,
        module: *Module,
        name: []const u8,
    };

    pub fn deinit(it: *DependencyIterator) void {
        it.set.deinit(it.allocator);
        it.* = undefined;
    }

    pub fn next(it: *DependencyIterator) ?Item {
        if (it.index >= it.set.count()) {
            it.set.clearAndFree(it.allocator);
            return null;
        }
        const key = it.set.keys()[it.index];
        const name = it.set.values()[it.index];
        it.index += 1;
        const module = key.module;
        it.set.ensureUnusedCapacity(it.allocator, module.import_table.count()) catch
            @panic("OOM");
        for (module.import_table.keys(), module.import_table.values()) |dep_name, dep| {
            it.set.putAssumeCapacity(.{
                .module = dep,
                .compile = key.compile,
            }, dep_name);
        }

        if (key.compile != null) {
            for (module.link_objects.items) |link_object| switch (link_object) {
                .other_step => |compile| {
                    it.set.put(it.allocator, .{
                        .module = &compile.root_module,
                        .compile = compile,
                    }, "root") catch @panic("OOM");
                },
                else => {},
            };
        }

        return .{
            .compile = key.compile,
            .module = key.module,
            .name = name,
        };
    }
};

pub fn iterateDependencies(
    m: *Module,
    chase_steps: ?*std.Build.Step.Compile,
) DependencyIterator {
    var it: DependencyIterator = .{
        .allocator = m.owner.allocator,
        .index = 0,
        .set = .{},
    };
    it.set.ensureUnusedCapacity(m.owner.allocator, m.import_table.count() + 1) catch @panic("OOM");
    it.set.putAssumeCapacity(.{
        .module = m,
        .compile = chase_steps,
    }, "root");
    return it;
}

pub const LinkSystemLibraryOptions = struct {
    needed: bool = false,
    weak: bool = false,
    use_pkg_config: SystemLib.UsePkgConfig = .yes,
    preferred_link_mode: std.builtin.LinkMode = .Dynamic,
    search_strategy: SystemLib.SearchStrategy = .paths_first,
};

pub fn linkSystemLibrary(
    m: *Module,
    name: []const u8,
    options: LinkSystemLibraryOptions,
) void {
    const b = m.owner;
    if (m.target_info.target.is_libc_lib_name(name)) {
        m.link_libc = true;
        return;
    }
    if (m.target_info.target.is_libcpp_lib_name(name)) {
        m.link_libcpp = true;
        return;
    }

    m.link_objects.append(.{
        .system_lib = .{
            .name = b.dupe(name),
            .needed = options.needed,
            .weak = options.weak,
            .use_pkg_config = options.use_pkg_config,
            .preferred_link_mode = options.preferred_link_mode,
            .search_strategy = options.search_strategy,
        },
    }) catch @panic("OOM");
}

pub const AddCSourceFilesOptions = struct {
    /// When provided, `files` are relative to `dependency` rather than the
    /// package that owns the `Compile` step.
    dependency: ?*std.Build.Dependency = null,
    files: []const []const u8,
    flags: []const []const u8 = &.{},
};

/// Handy when you have many C/C++ source files and want them all to have the same flags.
pub fn addCSourceFiles(m: *Module, options: AddCSourceFilesOptions) void {
    const c_source_files = m.owner.allocator.create(CSourceFiles) catch @panic("OOM");
    c_source_files.* = .{
        .dependency = options.dependency,
        .files = m.owner.dupeStrings(options.files),
        .flags = m.owner.dupeStrings(options.flags),
    };
    m.link_objects.append(.{ .c_source_files = c_source_files }) catch @panic("OOM");
}

pub fn addCSourceFile(m: *Module, source: CSourceFile) void {
    const c_source_file = m.owner.allocator.create(CSourceFile) catch @panic("OOM");
    c_source_file.* = source.dupe(m.owner);
    m.link_objects.append(.{ .c_source_file = c_source_file }) catch @panic("OOM");
    addLazyPathDependenciesOnly(m, source.file);
}

/// Resource files must have the extension `.rc`.
/// Can be called regardless of target. The .rc file will be ignored
/// if the target object format does not support embedded resources.
pub fn addWin32ResourceFile(m: *Module, source: RcSourceFile) void {
    // Only the PE/COFF format has a Resource Table, so for any other target
    // the resource file is ignored.
    if (m.target_info.target.ofmt != .coff) return;

    const rc_source_file = m.owner.allocator.create(RcSourceFile) catch @panic("OOM");
    rc_source_file.* = source.dupe(m.owner);
    m.link_objects.append(.{ .win32_resource_file = rc_source_file }) catch @panic("OOM");
    addLazyPathDependenciesOnly(m, source.file);
}

pub fn addAssemblyFile(m: *Module, source: LazyPath) void {
    m.link_objects.append(.{ .assembly_file = source.dupe(m.owner) }) catch @panic("OOM");
    addLazyPathDependenciesOnly(m, source);
}

pub fn addObjectFile(m: *Module, source: LazyPath) void {
    m.link_objects.append(.{ .static_path = source.dupe(m.owner) }) catch @panic("OOM");
    addLazyPathDependencies(m, source);
}

pub fn appendZigProcessFlags(
    m: *Module,
    zig_args: *std.ArrayList([]const u8),
    asking_step: ?*std.Build.Step,
) !void {
    const b = m.owner;

    try addFlag(zig_args, m.strip, "-fstrip", "-fno-strip");
    try addFlag(zig_args, m.unwind_tables, "-funwind-tables", "-fno-unwind-tables");
    try addFlag(zig_args, m.single_threaded, "-fsingle-threaded", "-fno-single-threaded");
    try addFlag(zig_args, m.stack_check, "-fstack-check", "-fno-stack-check");
    try addFlag(zig_args, m.stack_protector, "-fstack-protector", "-fno-stack-protector");
    try addFlag(zig_args, m.omit_frame_pointer, "-fomit-frame-pointer", "-fno-omit-frame-pointer");
    try addFlag(zig_args, m.sanitize_c, "-fsanitize-c", "-fno-sanitize-c");
    try addFlag(zig_args, m.sanitize_thread, "-fsanitize-thread", "-fno-sanitize-thread");
    try addFlag(zig_args, m.valgrind, "-fvalgrind", "-fno-valgrind");
    try addFlag(zig_args, m.pic, "-fPIC", "-fno-PIC");
    try addFlag(zig_args, m.red_zone, "-mred-zone", "-mno-red-zone");

    if (m.dwarf_format) |dwarf_format| {
        try zig_args.append(switch (dwarf_format) {
            .@"32" => "-gdwarf32",
            .@"64" => "-gdwarf64",
        });
    }

    try zig_args.ensureUnusedCapacity(1);
    switch (m.optimize) {
        .Debug => {}, // Skip since it's the default.
        .ReleaseSmall => zig_args.appendAssumeCapacity("-OReleaseSmall"),
        .ReleaseFast => zig_args.appendAssumeCapacity("-OReleaseFast"),
        .ReleaseSafe => zig_args.appendAssumeCapacity("-OReleaseSafe"),
    }

    if (m.code_model != .default) {
        try zig_args.append("-mcmodel");
        try zig_args.append(@tagName(m.code_model));
    }

    if (!m.target.isNative()) {
        try zig_args.appendSlice(&.{
            "-target", try m.target.zigTriple(b.allocator),
            "-mcpu",   try std.Build.serializeCpu(b.allocator, m.target.getCpu()),
        });

        if (m.target.dynamic_linker.get()) |dynamic_linker| {
            try zig_args.append("--dynamic-linker");
            try zig_args.append(dynamic_linker);
        }
    }

    for (m.export_symbol_names) |symbol_name| {
        try zig_args.append(b.fmt("--export={s}", .{symbol_name}));
    }

    for (m.include_dirs.items) |include_dir| {
        switch (include_dir) {
            .path => |include_path| {
                try zig_args.append("-I");
                try zig_args.append(include_path.getPath(b));
            },
            .path_system => |include_path| {
                try zig_args.append("-isystem");
                try zig_args.append(include_path.getPath(b));
            },
            .path_after => |include_path| {
                try zig_args.append("-idirafter");
                try zig_args.append(include_path.getPath(b));
            },
            .framework_path => |include_path| {
                try zig_args.append("-F");
                try zig_args.append(include_path.getPath2(b, asking_step));
            },
            .framework_path_system => |include_path| {
                try zig_args.append("-iframework");
                try zig_args.append(include_path.getPath2(b, asking_step));
            },
            .other_step => |other| {
                if (other.generated_h) |header| {
                    try zig_args.append("-isystem");
                    try zig_args.append(std.fs.path.dirname(header.path.?).?);
                }
                if (other.installed_headers.items.len > 0) {
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

    for (m.c_macros.items) |c_macro| {
        try zig_args.append("-D");
        try zig_args.append(c_macro);
    }

    try zig_args.ensureUnusedCapacity(2 * m.lib_paths.items.len);
    for (m.lib_paths.items) |lib_path| {
        zig_args.appendAssumeCapacity("-L");
        zig_args.appendAssumeCapacity(lib_path.getPath2(b, asking_step));
    }

    try zig_args.ensureUnusedCapacity(2 * m.rpaths.items.len);
    for (m.rpaths.items) |rpath| {
        zig_args.appendAssumeCapacity("-rpath");

        if (m.target_info.target.isDarwin()) switch (rpath) {
            .path, .cwd_relative => |path| {
                // On Darwin, we should not try to expand special runtime paths such as
                // * @executable_path
                // * @loader_path
                if (std.mem.startsWith(u8, path, "@executable_path") or
                    std.mem.startsWith(u8, path, "@loader_path"))
                {
                    zig_args.appendAssumeCapacity(path);
                    continue;
                }
            },
            .generated, .dependency => {},
        };

        zig_args.appendAssumeCapacity(rpath.getPath2(b, asking_step));
    }
}

fn addFlag(
    args: *std.ArrayList([]const u8),
    opt: ?bool,
    then_name: []const u8,
    else_name: []const u8,
) !void {
    const cond = opt orelse return;
    return args.append(if (cond) then_name else else_name);
}

const Module = @This();
const std = @import("std");
const assert = std.debug.assert;
const LazyPath = std.Build.LazyPath;
const NativeTargetInfo = std.zig.system.NativeTargetInfo;
