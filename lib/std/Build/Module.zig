/// The one responsible for creating this module.
owner: *std.Build,
/// Tracks the set of steps that depend on this `Module`. This ensures that
/// when making this `Module` depend on other `Module` objects and `Step`
/// objects, respective `Step` dependencies can be added.
depending_steps: std.AutoArrayHashMapUnmanaged(*Step.Compile, void),
root_source_file: ?LazyPath,
/// The modules that are mapped into this module's import table.
/// Use `addImport` rather than modifying this field directly in order to
/// maintain step dependency edges.
import_table: std.StringArrayHashMapUnmanaged(*Module),

resolved_target: ?std.Build.ResolvedTarget = null,
optimize: ?std.builtin.OptimizeMode = null,
dwarf_format: ?std.dwarf.Format,

c_macros: std.ArrayListUnmanaged([]const u8),
include_dirs: std.ArrayListUnmanaged(IncludeDir),
lib_paths: std.ArrayListUnmanaged(LazyPath),
rpaths: std.ArrayListUnmanaged(RPath),
frameworks: std.StringArrayHashMapUnmanaged(LinkFrameworkOptions),
link_objects: std.ArrayListUnmanaged(LinkObject),

strip: ?bool,
unwind_tables: ?bool,
single_threaded: ?bool,
stack_protector: ?bool,
stack_check: ?bool,
sanitize_c: ?bool,
sanitize_thread: ?bool,
code_model: std.builtin.CodeModel,
valgrind: ?bool,
pic: ?bool,
red_zone: ?bool,
omit_frame_pointer: ?bool,
error_tracing: ?bool,
link_libc: ?bool,
link_libcpp: ?bool,

/// Symbols to be exported when compiling to WebAssembly.
export_symbol_names: []const []const u8 = &.{},

pub const RPath = union(enum) {
    lazy_path: LazyPath,
    special: []const u8,
};

pub const LinkObject = union(enum) {
    static_path: LazyPath,
    other_step: *Step.Compile,
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
    root: LazyPath,
    /// `files` is relative to `root`, which is
    /// the build root by default
    files: []const []const u8,
    flags: []const []const u8,
};

pub const CSourceFile = struct {
    file: LazyPath,
    flags: []const []const u8 = &.{},

    pub fn dupe(file: CSourceFile, b: *std.Build) CSourceFile {
        return .{
            .file = file.file.dupe(b),
            .flags = b.dupeStrings(file.flags),
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
    /// Include paths that may or may not exist yet and therefore need to be
    /// specified as a LazyPath. Each path will be appended to the flags
    /// as `/I <resolved path>`.
    include_paths: []const LazyPath = &.{},

    pub fn dupe(file: RcSourceFile, b: *std.Build) RcSourceFile {
        const include_paths = b.allocator.alloc(LazyPath, file.include_paths.len) catch @panic("OOM");
        for (include_paths, file.include_paths) |*dest, lazy_path| dest.* = lazy_path.dupe(b);
        return .{
            .file = file.file.dupe(b),
            .flags = b.dupeStrings(file.flags),
            .include_paths = include_paths,
        };
    }
};

pub const IncludeDir = union(enum) {
    path: LazyPath,
    path_system: LazyPath,
    path_after: LazyPath,
    framework_path: LazyPath,
    framework_path_system: LazyPath,
    other_step: *Step.Compile,
    config_header_step: *Step.ConfigHeader,
};

pub const LinkFrameworkOptions = struct {
    needed: bool = false,
    weak: bool = false,
};

/// Unspecified options here will be inherited from parent `Module` when
/// inserted into an import table.
pub const CreateOptions = struct {
    /// This could either be a generated file, in which case the module
    /// contains exactly one file, or it could be a path to the root source
    /// file of directory of files which constitute the module.
    /// If `null`, it means this module is made up of only `link_objects`.
    root_source_file: ?LazyPath = null,

    /// The table of other modules that this module can access via `@import`.
    /// Imports are allowed to be cyclical, so this table can be added to after
    /// the `Module` is created via `addImport`.
    imports: []const Import = &.{},

    target: ?std.Build.ResolvedTarget = null,
    optimize: ?std.builtin.OptimizeMode = null,

    /// `true` requires a compilation that includes this Module to link libc.
    /// `false` causes a build failure if a compilation that includes this Module would link libc.
    /// `null` neither requires nor prevents libc from being linked.
    link_libc: ?bool = null,
    /// `true` requires a compilation that includes this Module to link libc++.
    /// `false` causes a build failure if a compilation that includes this Module would link libc++.
    /// `null` neither requires nor prevents libc++ from being linked.
    link_libcpp: ?bool = null,
    single_threaded: ?bool = null,
    strip: ?bool = null,
    unwind_tables: ?bool = null,
    dwarf_format: ?std.dwarf.Format = null,
    code_model: std.builtin.CodeModel = .default,
    stack_protector: ?bool = null,
    stack_check: ?bool = null,
    sanitize_c: ?bool = null,
    sanitize_thread: ?bool = null,
    /// Whether to emit machine code that integrates with Valgrind.
    valgrind: ?bool = null,
    /// Position Independent Code
    pic: ?bool = null,
    red_zone: ?bool = null,
    /// Whether to omit the stack frame pointer. Frees up a register and makes it
    /// more difficult to obtain stack traces. Has target-dependent effects.
    omit_frame_pointer: ?bool = null,
    error_tracing: ?bool = null,
};

pub const Import = struct {
    name: []const u8,
    module: *Module,
};

pub fn init(m: *Module, owner: *std.Build, options: CreateOptions, compile: ?*Step.Compile) void {
    const allocator = owner.allocator;

    m.* = .{
        .owner = owner,
        .depending_steps = .{},
        .root_source_file = if (options.root_source_file) |lp| lp.dupe(owner) else null,
        .import_table = .{},
        .resolved_target = options.target,
        .optimize = options.optimize,
        .link_libc = options.link_libc,
        .link_libcpp = options.link_libcpp,
        .dwarf_format = options.dwarf_format,
        .c_macros = .{},
        .include_dirs = .{},
        .lib_paths = .{},
        .rpaths = .{},
        .frameworks = .{},
        .link_objects = .{},
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
        .error_tracing = options.error_tracing,
        .export_symbol_names = &.{},
    };

    m.import_table.ensureUnusedCapacity(allocator, options.imports.len) catch @panic("OOM");
    for (options.imports) |dep| {
        m.import_table.putAssumeCapacity(dep.name, dep.module);
    }

    if (compile) |c| {
        m.depending_steps.put(allocator, c, {}) catch @panic("OOM");
    }

    // This logic accesses `depending_steps` which was just modified above.
    var it = m.iterateDependencies(null, false);
    while (it.next()) |item| addShallowDependencies(m, item.module);
}

pub fn create(owner: *std.Build, options: CreateOptions) *Module {
    const m = owner.allocator.create(Module) catch @panic("OOM");
    m.init(owner, options, null);
    return m;
}

/// Adds an existing module to be used with `@import`.
pub fn addImport(m: *Module, name: []const u8, module: *Module) void {
    const b = m.owner;
    m.import_table.put(b.allocator, b.dupe(name), module) catch @panic("OOM");

    var it = module.iterateDependencies(null, false);
    while (it.next()) |item| addShallowDependencies(m, item.module);
}

/// Creates step dependencies and updates `depending_steps` of `dependee` so that
/// subsequent calls to `addImport` on `dependee` will additionally create step
/// dependencies on `m`'s `depending_steps`.
fn addShallowDependencies(m: *Module, dependee: *Module) void {
    if (dependee.root_source_file) |lazy_path| addLazyPathDependencies(m, dependee, lazy_path);
    for (dependee.lib_paths.items) |lib_path| addLazyPathDependencies(m, dependee, lib_path);
    for (dependee.rpaths.items) |rpath| switch (rpath) {
        .lazy_path => |lp| addLazyPathDependencies(m, dependee, lp),
        .special => {},
    };

    for (dependee.link_objects.items) |link_object| switch (link_object) {
        .other_step => |compile| {
            addStepDependencies(m, dependee, &compile.step);
            addLazyPathDependenciesOnly(m, compile.getEmittedIncludeTree());
        },

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

fn addStepDependencies(m: *Module, module: *Module, dependee: *Step) void {
    addStepDependenciesOnly(m, dependee);
    if (m != module) {
        for (m.depending_steps.keys()) |compile| {
            module.depending_steps.put(m.owner.allocator, compile, {}) catch @panic("OOM");
        }
    }
}

fn addStepDependenciesOnly(m: *Module, dependee: *Step) void {
    for (m.depending_steps.keys()) |compile| {
        compile.step.dependOn(dependee);
    }
}

/// Creates a new module and adds it to be used with `@import`.
pub fn addAnonymousImport(m: *Module, name: []const u8, options: CreateOptions) void {
    const module = create(m.owner, options);
    return addImport(m, name, module);
}

/// Converts a set of key-value pairs into a Zig source file, and then inserts it into
/// the Module's import table with the specified name. This makes the options importable
/// via `@import("module_name")`.
pub fn addOptions(m: *Module, module_name: []const u8, options: *Step.Options) void {
    addImport(m, module_name, options.createModule());
}

pub const DependencyIterator = struct {
    allocator: std.mem.Allocator,
    index: usize,
    set: std.AutoArrayHashMapUnmanaged(Key, []const u8),
    chase_dyn_libs: bool,

    pub const Key = struct {
        /// The compilation that contains the `Module`. Note that a `Module` might be
        /// used by more than one compilation.
        compile: ?*Step.Compile,
        module: *Module,
    };

    pub const Item = struct {
        /// The compilation that contains the `Module`. Note that a `Module` might be
        /// used by more than one compilation.
        compile: ?*Step.Compile,
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
                    if (!it.chase_dyn_libs and compile.isDynamicLibrary()) continue;

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
    chase_steps: ?*Step.Compile,
    chase_dyn_libs: bool,
) DependencyIterator {
    var it: DependencyIterator = .{
        .allocator = m.owner.allocator,
        .index = 0,
        .set = .{},
        .chase_dyn_libs = chase_dyn_libs,
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
    preferred_link_mode: std.builtin.LinkMode = .dynamic,
    search_strategy: SystemLib.SearchStrategy = .paths_first,
};

pub fn linkSystemLibrary(
    m: *Module,
    name: []const u8,
    options: LinkSystemLibraryOptions,
) void {
    const b = m.owner;

    const target = m.requireKnownTarget();
    if (target.is_libc_lib_name(name)) {
        m.link_libc = true;
        return;
    }
    if (target.is_libcpp_lib_name(name)) {
        m.link_libcpp = true;
        return;
    }

    m.link_objects.append(b.allocator, .{
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

pub fn linkFramework(m: *Module, name: []const u8, options: LinkFrameworkOptions) void {
    const b = m.owner;
    m.frameworks.put(b.allocator, b.dupe(name), options) catch @panic("OOM");
}

pub const AddCSourceFilesOptions = struct {
    /// When provided, `files` are relative to `root` rather than the
    /// package that owns the `Compile` step.
    root: ?LazyPath = null,
    files: []const []const u8,
    flags: []const []const u8 = &.{},
};

/// Handy when you have many C/C++ source files and want them all to have the same flags.
pub fn addCSourceFiles(m: *Module, options: AddCSourceFilesOptions) void {
    const b = m.owner;
    const allocator = b.allocator;

    for (options.files) |path| {
        if (std.fs.path.isAbsolute(path)) {
            std.debug.panic(
                "file paths added with 'addCSourceFiles' must be relative, found absolute path '{s}'",
                .{path},
            );
        }
    }

    const c_source_files = allocator.create(CSourceFiles) catch @panic("OOM");
    c_source_files.* = .{
        .root = options.root orelse b.path(""),
        .files = b.dupeStrings(options.files),
        .flags = b.dupeStrings(options.flags),
    };
    m.link_objects.append(allocator, .{ .c_source_files = c_source_files }) catch @panic("OOM");
}

pub fn addCSourceFile(m: *Module, source: CSourceFile) void {
    const b = m.owner;
    const allocator = b.allocator;
    const c_source_file = allocator.create(CSourceFile) catch @panic("OOM");
    c_source_file.* = source.dupe(b);
    m.link_objects.append(allocator, .{ .c_source_file = c_source_file }) catch @panic("OOM");
    addLazyPathDependenciesOnly(m, source.file);
}

/// Resource files must have the extension `.rc`.
/// Can be called regardless of target. The .rc file will be ignored
/// if the target object format does not support embedded resources.
pub fn addWin32ResourceFile(m: *Module, source: RcSourceFile) void {
    const b = m.owner;
    const allocator = b.allocator;
    const target = m.requireKnownTarget();
    // Only the PE/COFF format has a Resource Table, so for any other target
    // the resource file is ignored.
    if (target.ofmt != .coff) return;

    const rc_source_file = allocator.create(RcSourceFile) catch @panic("OOM");
    rc_source_file.* = source.dupe(b);
    m.link_objects.append(allocator, .{ .win32_resource_file = rc_source_file }) catch @panic("OOM");
    addLazyPathDependenciesOnly(m, source.file);
    for (source.include_paths) |include_path| {
        addLazyPathDependenciesOnly(m, include_path);
    }
}

pub fn addAssemblyFile(m: *Module, source: LazyPath) void {
    const b = m.owner;
    m.link_objects.append(b.allocator, .{ .assembly_file = source.dupe(b) }) catch @panic("OOM");
    addLazyPathDependenciesOnly(m, source);
}

pub fn addObjectFile(m: *Module, object: LazyPath) void {
    const b = m.owner;
    m.link_objects.append(b.allocator, .{ .static_path = object.dupe(b) }) catch @panic("OOM");
    addLazyPathDependenciesOnly(m, object);
}

pub fn addObject(m: *Module, object: *Step.Compile) void {
    assert(object.kind == .obj);
    m.linkLibraryOrObject(object);
}

pub fn linkLibrary(m: *Module, library: *Step.Compile) void {
    assert(library.kind == .lib);
    m.linkLibraryOrObject(library);
}

pub fn addAfterIncludePath(m: *Module, lazy_path: LazyPath) void {
    const b = m.owner;
    m.include_dirs.append(b.allocator, .{ .path_after = lazy_path.dupe(b) }) catch @panic("OOM");
    addLazyPathDependenciesOnly(m, lazy_path);
}

pub fn addSystemIncludePath(m: *Module, lazy_path: LazyPath) void {
    const b = m.owner;
    m.include_dirs.append(b.allocator, .{ .path_system = lazy_path.dupe(b) }) catch @panic("OOM");
    addLazyPathDependenciesOnly(m, lazy_path);
}

pub fn addIncludePath(m: *Module, lazy_path: LazyPath) void {
    const b = m.owner;
    m.include_dirs.append(b.allocator, .{ .path = lazy_path.dupe(b) }) catch @panic("OOM");
    addLazyPathDependenciesOnly(m, lazy_path);
}

pub fn addConfigHeader(m: *Module, config_header: *Step.ConfigHeader) void {
    const allocator = m.owner.allocator;
    m.include_dirs.append(allocator, .{ .config_header_step = config_header }) catch @panic("OOM");
    addStepDependenciesOnly(m, &config_header.step);
}

pub fn addSystemFrameworkPath(m: *Module, directory_path: LazyPath) void {
    const b = m.owner;
    m.include_dirs.append(b.allocator, .{ .framework_path_system = directory_path.dupe(b) }) catch
        @panic("OOM");
    addLazyPathDependenciesOnly(m, directory_path);
}

pub fn addFrameworkPath(m: *Module, directory_path: LazyPath) void {
    const b = m.owner;
    m.include_dirs.append(b.allocator, .{ .framework_path = directory_path.dupe(b) }) catch
        @panic("OOM");
    addLazyPathDependenciesOnly(m, directory_path);
}

pub fn addLibraryPath(m: *Module, directory_path: LazyPath) void {
    const b = m.owner;
    m.lib_paths.append(b.allocator, directory_path.dupe(b)) catch @panic("OOM");
    addLazyPathDependenciesOnly(m, directory_path);
}

pub fn addRPath(m: *Module, directory_path: LazyPath) void {
    const b = m.owner;
    m.rpaths.append(b.allocator, .{ .lazy_path = directory_path.dupe(b) }) catch @panic("OOM");
    addLazyPathDependenciesOnly(m, directory_path);
}

pub fn addRPathSpecial(m: *Module, bytes: []const u8) void {
    const b = m.owner;
    m.rpaths.append(b.allocator, .{ .special = b.dupe(bytes) }) catch @panic("OOM");
}

/// Equvialent to the following C code, applied to all C source files owned by
/// this `Module`:
/// ```c
/// #define name value
/// ```
/// `name` and `value` need not live longer than the function call.
pub fn addCMacro(m: *Module, name: []const u8, value: []const u8) void {
    const b = m.owner;
    m.c_macros.append(b.allocator, b.fmt("-D{s}={s}", .{ name, value })) catch @panic("OOM");
}

pub fn appendZigProcessFlags(
    m: *Module,
    zig_args: *std.ArrayList([]const u8),
    asking_step: ?*Step,
) !void {
    const b = m.owner;

    try addFlag(zig_args, m.strip, "-fstrip", "-fno-strip");
    try addFlag(zig_args, m.unwind_tables, "-funwind-tables", "-fno-unwind-tables");
    try addFlag(zig_args, m.single_threaded, "-fsingle-threaded", "-fno-single-threaded");
    try addFlag(zig_args, m.stack_check, "-fstack-check", "-fno-stack-check");
    try addFlag(zig_args, m.stack_protector, "-fstack-protector", "-fno-stack-protector");
    try addFlag(zig_args, m.omit_frame_pointer, "-fomit-frame-pointer", "-fno-omit-frame-pointer");
    try addFlag(zig_args, m.error_tracing, "-ferror-tracing", "-fno-error-tracing");
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
    if (m.optimize) |optimize| switch (optimize) {
        .Debug => zig_args.appendAssumeCapacity("-ODebug"),
        .ReleaseSmall => zig_args.appendAssumeCapacity("-OReleaseSmall"),
        .ReleaseFast => zig_args.appendAssumeCapacity("-OReleaseFast"),
        .ReleaseSafe => zig_args.appendAssumeCapacity("-OReleaseSafe"),
    };

    if (m.code_model != .default) {
        try zig_args.append("-mcmodel");
        try zig_args.append(@tagName(m.code_model));
    }

    if (m.resolved_target) |*target| {
        // Communicate the query via CLI since it's more compact.
        if (!target.query.isNative()) {
            try zig_args.appendSlice(&.{
                "-target", try target.query.zigTriple(b.allocator),
                "-mcpu",   try target.query.serializeCpuAlloc(b.allocator),
            });

            if (target.query.dynamic_linker.get()) |dynamic_linker| {
                try zig_args.append("--dynamic-linker");
                try zig_args.append(dynamic_linker);
            }
        }
    }

    for (m.export_symbol_names) |symbol_name| {
        try zig_args.append(b.fmt("--export={s}", .{symbol_name}));
    }

    for (m.include_dirs.items) |include_dir| {
        switch (include_dir) {
            .path => |include_path| {
                try zig_args.appendSlice(&.{ "-I", include_path.getPath2(b, asking_step) });
            },
            .path_system => |include_path| {
                try zig_args.appendSlice(&.{ "-isystem", include_path.getPath2(b, asking_step) });
            },
            .path_after => |include_path| {
                try zig_args.appendSlice(&.{ "-idirafter", include_path.getPath2(b, asking_step) });
            },
            .framework_path => |include_path| {
                try zig_args.appendSlice(&.{ "-F", include_path.getPath2(b, asking_step) });
            },
            .framework_path_system => |include_path| {
                try zig_args.appendSlice(&.{ "-iframework", include_path.getPath2(b, asking_step) });
            },
            .other_step => |other| {
                if (other.generated_h) |header| {
                    try zig_args.appendSlice(&.{ "-isystem", std.fs.path.dirname(header.getPath()).? });
                }
                if (other.installed_headers_include_tree) |include_tree| {
                    try zig_args.appendSlice(&.{ "-I", include_tree.generated_directory.getPath() });
                }
            },
            .config_header_step => |config_header| {
                const full_file_path = config_header.output_file.getPath();
                const header_dir_path = full_file_path[0 .. full_file_path.len - config_header.include_path.len];
                try zig_args.appendSlice(&.{ "-I", header_dir_path });
            },
        }
    }

    try zig_args.appendSlice(m.c_macros.items);

    try zig_args.ensureUnusedCapacity(2 * m.lib_paths.items.len);
    for (m.lib_paths.items) |lib_path| {
        zig_args.appendAssumeCapacity("-L");
        zig_args.appendAssumeCapacity(lib_path.getPath2(b, asking_step));
    }

    try zig_args.ensureUnusedCapacity(2 * m.rpaths.items.len);
    for (m.rpaths.items) |rpath| switch (rpath) {
        .lazy_path => |lp| {
            zig_args.appendAssumeCapacity("-rpath");
            zig_args.appendAssumeCapacity(lp.getPath2(b, asking_step));
        },
        .special => |bytes| {
            zig_args.appendAssumeCapacity("-rpath");
            zig_args.appendAssumeCapacity(bytes);
        },
    };
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

fn linkLibraryOrObject(m: *Module, other: *Step.Compile) void {
    const allocator = m.owner.allocator;
    _ = other.getEmittedBin(); // Indicate there is a dependency on the outputted binary.
    addStepDependenciesOnly(m, &other.step);

    if (other.rootModuleTarget().os.tag == .windows and other.isDynamicLibrary()) {
        _ = other.getEmittedImplib(); // Indicate dependency on the outputted implib.
    }

    m.link_objects.append(allocator, .{ .other_step = other }) catch @panic("OOM");
    m.include_dirs.append(allocator, .{ .other_step = other }) catch @panic("OOM");

    addLazyPathDependenciesOnly(m, other.getEmittedIncludeTree());
}

fn requireKnownTarget(m: *Module) std.Target {
    const resolved_target = m.resolved_target orelse
        @panic("this API requires the Module to be created with a known 'target' field");
    return resolved_target.result;
}

const Module = @This();
const std = @import("std");
const assert = std.debug.assert;
const LazyPath = std.Build.LazyPath;
const Step = std.Build.Step;
