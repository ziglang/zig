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

pub const FmtStep = @import("build/FmtStep.zig");
pub const TranslateCStep = @import("build/TranslateCStep.zig");
pub const WriteFileStep = @import("build/WriteFileStep.zig");
pub const RunStep = @import("build/RunStep.zig");
pub const CheckFileStep = @import("build/CheckFileStep.zig");
pub const CheckObjectStep = @import("build/CheckObjectStep.zig");
pub const InstallRawStep = @import("build/InstallRawStep.zig");
pub const OptionsStep = @import("build/OptionsStep.zig");
pub const EmulatableRunStep = @import("build/EmulatableRunStep.zig");

pub const Builder = struct {
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
    use_stage1: ?bool = null,
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
    build_root: []const u8,
    cache_root: []const u8,
    global_cache_root: []const u8,
    release_mode: ?std.builtin.Mode,
    is_release: bool,
    override_lib_dir: ?[]const u8,
    vcpkg_root: VcpkgRoot,
    pkg_config_pkg_list: ?(PkgConfigError![]const PkgConfigPkg) = null,
    args: ?[][]const u8 = null,
    debug_log_scopes: []const []const u8 = &.{},

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
    ) !*Builder {
        const env_map = try allocator.create(EnvMap);
        env_map.* = try process.getEnvMap(allocator);

        const host = try NativeTargetInfo.detect(.{});

        const self = try allocator.create(Builder);
        self.* = Builder{
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
            .release_mode = null,
            .is_release = false,
            .override_lib_dir = null,
            .install_path = undefined,
            .vcpkg_root = VcpkgRoot{ .unattempted = {} },
            .args = null,
            .host = host,
        };
        try self.top_level_steps.append(&self.install_tls);
        try self.top_level_steps.append(&self.uninstall_tls);
        self.default_step = &self.install_tls.step;
        return self;
    }

    pub fn destroy(self: *Builder) void {
        self.env_map.deinit();
        self.top_level_steps.deinit();
        self.allocator.destroy(self);
    }

    /// This function is intended to be called by lib/build_runner.zig, not a build.zig file.
    pub fn resolveInstallPrefix(self: *Builder, install_prefix: ?[]const u8, dir_list: DirList) void {
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

    fn convertOptionalPathToFileSource(path: ?[]const u8) ?FileSource {
        return if (path) |p|
            FileSource{ .path = p }
        else
            null;
    }

    pub fn addExecutable(self: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        return addExecutableSource(self, name, convertOptionalPathToFileSource(root_src));
    }

    pub fn addExecutableSource(builder: *Builder, name: []const u8, root_src: ?FileSource) *LibExeObjStep {
        return LibExeObjStep.createExecutable(builder, name, root_src);
    }

    pub fn addOptions(self: *Builder) *OptionsStep {
        return OptionsStep.create(self);
    }

    pub fn addObject(self: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        return addObjectSource(self, name, convertOptionalPathToFileSource(root_src));
    }

    pub fn addObjectSource(builder: *Builder, name: []const u8, root_src: ?FileSource) *LibExeObjStep {
        return LibExeObjStep.createObject(builder, name, root_src);
    }

    pub fn addSharedLibrary(
        self: *Builder,
        name: []const u8,
        root_src: ?[]const u8,
        kind: LibExeObjStep.SharedLibKind,
    ) *LibExeObjStep {
        return addSharedLibrarySource(self, name, convertOptionalPathToFileSource(root_src), kind);
    }

    pub fn addSharedLibrarySource(
        self: *Builder,
        name: []const u8,
        root_src: ?FileSource,
        kind: LibExeObjStep.SharedLibKind,
    ) *LibExeObjStep {
        return LibExeObjStep.createSharedLibrary(self, name, root_src, kind);
    }

    pub fn addStaticLibrary(self: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        return addStaticLibrarySource(self, name, convertOptionalPathToFileSource(root_src));
    }

    pub fn addStaticLibrarySource(self: *Builder, name: []const u8, root_src: ?FileSource) *LibExeObjStep {
        return LibExeObjStep.createStaticLibrary(self, name, root_src);
    }

    pub fn addTest(self: *Builder, root_src: []const u8) *LibExeObjStep {
        return LibExeObjStep.createTest(self, "test", .{ .path = root_src });
    }

    pub fn addTestSource(self: *Builder, root_src: FileSource) *LibExeObjStep {
        return LibExeObjStep.createTest(self, "test", root_src.dupe(self));
    }

    pub fn addTestExe(self: *Builder, name: []const u8, root_src: []const u8) *LibExeObjStep {
        return LibExeObjStep.createTestExe(self, name, .{ .path = root_src });
    }

    pub fn addTestExeSource(self: *Builder, name: []const u8, root_src: FileSource) *LibExeObjStep {
        return LibExeObjStep.createTestExe(self, name, root_src.dupe(self));
    }

    pub fn addAssemble(self: *Builder, name: []const u8, src: []const u8) *LibExeObjStep {
        return addAssembleSource(self, name, .{ .path = src });
    }

    pub fn addAssembleSource(self: *Builder, name: []const u8, src: FileSource) *LibExeObjStep {
        const obj_step = LibExeObjStep.createObject(self, name, null);
        obj_step.addAssemblyFileSource(src.dupe(self));
        return obj_step;
    }

    /// Initializes a RunStep with argv, which must at least have the path to the
    /// executable. More command line arguments can be added with `addArg`,
    /// `addArgs`, and `addArtifactArg`.
    /// Be careful using this function, as it introduces a system dependency.
    /// To run an executable built with zig build, see `LibExeObjStep.run`.
    pub fn addSystemCommand(self: *Builder, argv: []const []const u8) *RunStep {
        assert(argv.len >= 1);
        const run_step = RunStep.create(self, self.fmt("run {s}", .{argv[0]}));
        run_step.addArgs(argv);
        return run_step;
    }

    /// Allocator.dupe without the need to handle out of memory.
    pub fn dupe(self: *Builder, bytes: []const u8) []u8 {
        return self.allocator.dupe(u8, bytes) catch unreachable;
    }

    /// Duplicates an array of strings without the need to handle out of memory.
    pub fn dupeStrings(self: *Builder, strings: []const []const u8) [][]u8 {
        const array = self.allocator.alloc([]u8, strings.len) catch unreachable;
        for (strings) |s, i| {
            array[i] = self.dupe(s);
        }
        return array;
    }

    /// Duplicates a path and converts all slashes to the OS's canonical path separator.
    pub fn dupePath(self: *Builder, bytes: []const u8) []u8 {
        const the_copy = self.dupe(bytes);
        for (the_copy) |*byte| {
            switch (byte.*) {
                '/', '\\' => byte.* = fs.path.sep,
                else => {},
            }
        }
        return the_copy;
    }

    /// Duplicates a package recursively.
    pub fn dupePkg(self: *Builder, package: Pkg) Pkg {
        var the_copy = Pkg{
            .name = self.dupe(package.name),
            .source = package.source.dupe(self),
        };

        if (package.dependencies) |dependencies| {
            const new_dependencies = self.allocator.alloc(Pkg, dependencies.len) catch unreachable;
            the_copy.dependencies = new_dependencies;

            for (dependencies) |dep_package, i| {
                new_dependencies[i] = self.dupePkg(dep_package);
            }
        }
        return the_copy;
    }

    pub fn addWriteFile(self: *Builder, file_path: []const u8, data: []const u8) *WriteFileStep {
        const write_file_step = self.addWriteFiles();
        write_file_step.add(file_path, data);
        return write_file_step;
    }

    pub fn addWriteFiles(self: *Builder) *WriteFileStep {
        const write_file_step = self.allocator.create(WriteFileStep) catch unreachable;
        write_file_step.* = WriteFileStep.init(self);
        return write_file_step;
    }

    pub fn addLog(self: *Builder, comptime format: []const u8, args: anytype) *LogStep {
        const data = self.fmt(format, args);
        const log_step = self.allocator.create(LogStep) catch unreachable;
        log_step.* = LogStep.init(self, data);
        return log_step;
    }

    pub fn addRemoveDirTree(self: *Builder, dir_path: []const u8) *RemoveDirStep {
        const remove_dir_step = self.allocator.create(RemoveDirStep) catch unreachable;
        remove_dir_step.* = RemoveDirStep.init(self, dir_path);
        return remove_dir_step;
    }

    pub fn addFmt(self: *Builder, paths: []const []const u8) *FmtStep {
        return FmtStep.create(self, paths);
    }

    pub fn addTranslateC(self: *Builder, source: FileSource) *TranslateCStep {
        return TranslateCStep.create(self, source.dupe(self));
    }

    pub fn version(self: *const Builder, major: u32, minor: u32, patch: u32) LibExeObjStep.SharedLibKind {
        _ = self;
        return .{
            .versioned = .{
                .major = major,
                .minor = minor,
                .patch = patch,
            },
        };
    }

    pub fn make(self: *Builder, step_names: []const []const u8) !void {
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

    pub fn getInstallStep(self: *Builder) *Step {
        return &self.install_tls.step;
    }

    pub fn getUninstallStep(self: *Builder) *Step {
        return &self.uninstall_tls.step;
    }

    fn makeUninstall(uninstall_step: *Step) anyerror!void {
        const uninstall_tls = @fieldParentPtr(TopLevelStep, "step", uninstall_step);
        const self = @fieldParentPtr(Builder, "uninstall_tls", uninstall_tls);

        for (self.installed_files.items) |installed_file| {
            const full_path = self.getInstallPath(installed_file.dir, installed_file.path);
            if (self.verbose) {
                log.info("rm {s}", .{full_path});
            }
            fs.cwd().deleteTree(full_path) catch {};
        }

        // TODO remove empty directories
    }

    fn makeOneStep(self: *Builder, s: *Step) anyerror!void {
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

    fn getTopLevelStepByName(self: *Builder, name: []const u8) !*Step {
        for (self.top_level_steps.items) |top_level_step| {
            if (mem.eql(u8, top_level_step.step.name, name)) {
                return &top_level_step.step;
            }
        }
        log.err("Cannot run step '{s}' because it does not exist", .{name});
        return error.InvalidStepName;
    }

    pub fn option(self: *Builder, comptime T: type, name_raw: []const u8, description_raw: []const u8) ?T {
        const name = self.dupe(name_raw);
        const description = self.dupe(description_raw);
        const type_id = comptime typeToEnum(T);
        const enum_options = if (type_id == .@"enum") blk: {
            const fields = comptime std.meta.fields(T);
            var options = ArrayList([]const u8).initCapacity(self.allocator, fields.len) catch unreachable;

            inline for (fields) |field| {
                options.appendAssumeCapacity(field.name);
            }

            break :blk options.toOwnedSlice();
        } else null;
        const available_option = AvailableOption{
            .name = name,
            .type_id = type_id,
            .description = description,
            .enum_options = enum_options,
        };
        if ((self.available_options_map.fetchPut(name, available_option) catch unreachable) != null) {
            panic("Option '{s}' declared twice", .{name});
        }
        self.available_options_list.append(available_option) catch unreachable;

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
                .list => {
                    log.err("Expected -D{s} to be a boolean, but received a list.\n", .{name});
                    self.markInvalidUserInput();
                    return null;
                },
            },
            .int => switch (option_ptr.value) {
                .flag => {
                    log.err("Expected -D{s} to be an integer, but received a boolean.\n", .{name});
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
                .list => {
                    log.err("Expected -D{s} to be an integer, but received a list.\n", .{name});
                    self.markInvalidUserInput();
                    return null;
                },
            },
            .float => switch (option_ptr.value) {
                .flag => {
                    log.err("Expected -D{s} to be a float, but received a boolean.\n", .{name});
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
                .list => {
                    log.err("Expected -D{s} to be a float, but received a list.\n", .{name});
                    self.markInvalidUserInput();
                    return null;
                },
            },
            .@"enum" => switch (option_ptr.value) {
                .flag => {
                    log.err("Expected -D{s} to be a string, but received a boolean.\n", .{name});
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
                .list => {
                    log.err("Expected -D{s} to be a string, but received a list.\n", .{name});
                    self.markInvalidUserInput();
                    return null;
                },
            },
            .string => switch (option_ptr.value) {
                .flag => {
                    log.err("Expected -D{s} to be a string, but received a boolean.\n", .{name});
                    self.markInvalidUserInput();
                    return null;
                },
                .list => {
                    log.err("Expected -D{s} to be a string, but received a list.\n", .{name});
                    self.markInvalidUserInput();
                    return null;
                },
                .scalar => |s| return s,
            },
            .list => switch (option_ptr.value) {
                .flag => {
                    log.err("Expected -D{s} to be a list, but received a boolean.\n", .{name});
                    self.markInvalidUserInput();
                    return null;
                },
                .scalar => |s| {
                    return self.allocator.dupe([]const u8, &[_][]const u8{s}) catch unreachable;
                },
                .list => |lst| return lst.items,
            },
        }
    }

    pub fn step(self: *Builder, name: []const u8, description: []const u8) *Step {
        const step_info = self.allocator.create(TopLevelStep) catch unreachable;
        step_info.* = TopLevelStep{
            .step = Step.initNoOp(.top_level, name, self.allocator),
            .description = self.dupe(description),
        };
        self.top_level_steps.append(step_info) catch unreachable;
        return &step_info.step;
    }

    /// This provides the -Drelease option to the build user and does not give them the choice.
    pub fn setPreferredReleaseMode(self: *Builder, mode: std.builtin.Mode) void {
        if (self.release_mode != null) {
            @panic("setPreferredReleaseMode must be called before standardReleaseOptions and may not be called twice");
        }
        const description = self.fmt("Create a release build ({s})", .{@tagName(mode)});
        self.is_release = self.option(bool, "release", description) orelse false;
        self.release_mode = if (self.is_release) mode else std.builtin.Mode.Debug;
    }

    /// If you call this without first calling `setPreferredReleaseMode` then it gives the build user
    /// the choice of what kind of release.
    pub fn standardReleaseOptions(self: *Builder) std.builtin.Mode {
        if (self.release_mode) |mode| return mode;

        const release_safe = self.option(bool, "release-safe", "Optimizations on and safety on") orelse false;
        const release_fast = self.option(bool, "release-fast", "Optimizations on and safety off") orelse false;
        const release_small = self.option(bool, "release-small", "Size optimizations on and safety off") orelse false;

        const mode = if (release_safe and !release_fast and !release_small)
            std.builtin.Mode.ReleaseSafe
        else if (release_fast and !release_safe and !release_small)
            std.builtin.Mode.ReleaseFast
        else if (release_small and !release_fast and !release_safe)
            std.builtin.Mode.ReleaseSmall
        else if (!release_fast and !release_safe and !release_small)
            std.builtin.Mode.Debug
        else x: {
            log.err("Multiple release modes (of -Drelease-safe, -Drelease-fast and -Drelease-small)\n", .{});
            self.markInvalidUserInput();
            break :x std.builtin.Mode.Debug;
        };
        self.is_release = mode != .Debug;
        self.release_mode = mode;
        return mode;
    }

    pub const StandardTargetOptionsArgs = struct {
        whitelist: ?[]const CrossTarget = null,

        default_target: CrossTarget = CrossTarget{},
    };

    /// Exposes standard `zig build` options for choosing a target.
    pub fn standardTargetOptions(self: *Builder, args: StandardTargetOptionsArgs) CrossTarget {
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

        const selected_canonicalized_triple = selected_target.zigTriple(self.allocator) catch unreachable;

        if (args.whitelist) |list| whitelist_check: {
            // Make sure it's a match of one of the list.
            var mismatch_triple = true;
            var mismatch_cpu_features = true;
            var whitelist_item = CrossTarget{};
            for (list) |t| {
                mismatch_cpu_features = true;
                mismatch_triple = true;

                const t_triple = t.zigTriple(self.allocator) catch unreachable;
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
                    const t_triple = t.zigTriple(self.allocator) catch unreachable;
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

    pub fn addUserInputOption(self: *Builder, name_raw: []const u8, value_raw: []const u8) !bool {
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
                list.append(s) catch unreachable;
                list.append(value) catch unreachable;
                self.user_input_options.put(name, .{
                    .name = name,
                    .value = .{ .list = list },
                    .used = false,
                }) catch unreachable;
            },
            .list => |*list| {
                // append to the list
                list.append(value) catch unreachable;
                self.user_input_options.put(name, .{
                    .name = name,
                    .value = .{ .list = list.* },
                    .used = false,
                }) catch unreachable;
            },
            .flag => {
                log.warn("Option '-D{s}={s}' conflicts with flag '-D{s}'.", .{ name, value, name });
                return true;
            },
        }
        return false;
    }

    pub fn addUserInputFlag(self: *Builder, name_raw: []const u8) !bool {
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
            .list => {
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

    fn markInvalidUserInput(self: *Builder) void {
        self.invalid_user_input = true;
    }

    pub fn validateUserInputDidItFail(self: *Builder) bool {
        // make sure all args are used
        var it = self.user_input_options.iterator();
        while (it.next()) |entry| {
            if (!entry.value_ptr.used) {
                log.err("Invalid option: -D{s}\n", .{entry.key_ptr.*});
                self.markInvalidUserInput();
            }
        }

        return self.invalid_user_input;
    }

    pub fn spawnChild(self: *Builder, argv: []const []const u8) !void {
        return self.spawnChildEnvMap(null, self.env_map, argv);
    }

    fn printCmd(cwd: ?[]const u8, argv: []const []const u8) void {
        if (cwd) |yes_cwd| std.debug.print("cd {s} && ", .{yes_cwd});
        for (argv) |arg| {
            std.debug.print("{s} ", .{arg});
        }
        std.debug.print("\n", .{});
    }

    pub fn spawnChildEnvMap(self: *Builder, cwd: ?[]const u8, env_map: *const EnvMap, argv: []const []const u8) !void {
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

    pub fn makePath(self: *Builder, path: []const u8) !void {
        fs.cwd().makePath(self.pathFromRoot(path)) catch |err| {
            log.err("Unable to create path {s}: {s}", .{ path, @errorName(err) });
            return err;
        };
    }

    pub fn installArtifact(self: *Builder, artifact: *LibExeObjStep) void {
        self.getInstallStep().dependOn(&self.addInstallArtifact(artifact).step);
    }

    pub fn addInstallArtifact(self: *Builder, artifact: *LibExeObjStep) *InstallArtifactStep {
        return InstallArtifactStep.create(self, artifact);
    }

    ///`dest_rel_path` is relative to prefix path
    pub fn installFile(self: *Builder, src_path: []const u8, dest_rel_path: []const u8) void {
        self.getInstallStep().dependOn(&self.addInstallFileWithDir(.{ .path = src_path }, .prefix, dest_rel_path).step);
    }

    pub fn installDirectory(self: *Builder, options: InstallDirectoryOptions) void {
        self.getInstallStep().dependOn(&self.addInstallDirectory(options).step);
    }

    ///`dest_rel_path` is relative to bin path
    pub fn installBinFile(self: *Builder, src_path: []const u8, dest_rel_path: []const u8) void {
        self.getInstallStep().dependOn(&self.addInstallFileWithDir(.{ .path = src_path }, .bin, dest_rel_path).step);
    }

    ///`dest_rel_path` is relative to lib path
    pub fn installLibFile(self: *Builder, src_path: []const u8, dest_rel_path: []const u8) void {
        self.getInstallStep().dependOn(&self.addInstallFileWithDir(.{ .path = src_path }, .lib, dest_rel_path).step);
    }

    /// Output format (BIN vs Intel HEX) determined by filename
    pub fn installRaw(self: *Builder, artifact: *LibExeObjStep, dest_filename: []const u8, options: InstallRawStep.CreateOptions) *InstallRawStep {
        const raw = self.addInstallRaw(artifact, dest_filename, options);
        self.getInstallStep().dependOn(&raw.step);
        return raw;
    }

    ///`dest_rel_path` is relative to install prefix path
    pub fn addInstallFile(self: *Builder, source: FileSource, dest_rel_path: []const u8) *InstallFileStep {
        return self.addInstallFileWithDir(source.dupe(self), .prefix, dest_rel_path);
    }

    ///`dest_rel_path` is relative to bin path
    pub fn addInstallBinFile(self: *Builder, source: FileSource, dest_rel_path: []const u8) *InstallFileStep {
        return self.addInstallFileWithDir(source.dupe(self), .bin, dest_rel_path);
    }

    ///`dest_rel_path` is relative to lib path
    pub fn addInstallLibFile(self: *Builder, source: FileSource, dest_rel_path: []const u8) *InstallFileStep {
        return self.addInstallFileWithDir(source.dupe(self), .lib, dest_rel_path);
    }

    pub fn addInstallRaw(self: *Builder, artifact: *LibExeObjStep, dest_filename: []const u8, options: InstallRawStep.CreateOptions) *InstallRawStep {
        return InstallRawStep.create(self, artifact, dest_filename, options);
    }

    pub fn addInstallFileWithDir(
        self: *Builder,
        source: FileSource,
        install_dir: InstallDir,
        dest_rel_path: []const u8,
    ) *InstallFileStep {
        if (dest_rel_path.len == 0) {
            panic("dest_rel_path must be non-empty", .{});
        }
        const install_step = self.allocator.create(InstallFileStep) catch unreachable;
        install_step.* = InstallFileStep.init(self, source.dupe(self), install_dir, dest_rel_path);
        return install_step;
    }

    pub fn addInstallDirectory(self: *Builder, options: InstallDirectoryOptions) *InstallDirStep {
        const install_step = self.allocator.create(InstallDirStep) catch unreachable;
        install_step.* = InstallDirStep.init(self, options);
        return install_step;
    }

    pub fn pushInstalledFile(self: *Builder, dir: InstallDir, dest_rel_path: []const u8) void {
        const file = InstalledFile{
            .dir = dir,
            .path = dest_rel_path,
        };
        self.installed_files.append(file.dupe(self)) catch unreachable;
    }

    pub fn updateFile(self: *Builder, source_path: []const u8, dest_path: []const u8) !void {
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

    pub fn truncateFile(self: *Builder, dest_path: []const u8) !void {
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

    pub fn pathFromRoot(self: *Builder, rel_path: []const u8) []u8 {
        return fs.path.resolve(self.allocator, &[_][]const u8{ self.build_root, rel_path }) catch unreachable;
    }

    /// Shorthand for `std.fs.path.join(builder.allocator, paths) catch unreachable`
    pub fn pathJoin(self: *Builder, paths: []const []const u8) []u8 {
        return fs.path.join(self.allocator, paths) catch unreachable;
    }

    pub fn fmt(self: *Builder, comptime format: []const u8, args: anytype) []u8 {
        return fmt_lib.allocPrint(self.allocator, format, args) catch unreachable;
    }

    pub fn findProgram(self: *Builder, names: []const []const u8, paths: []const []const u8) ![]const u8 {
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
        self: *Builder,
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

    pub fn execFromStep(self: *Builder, argv: []const []const u8, src_step: ?*Step) ![]u8 {
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

    pub fn exec(self: *Builder, argv: []const []const u8) ![]u8 {
        return self.execFromStep(argv, null);
    }

    pub fn addSearchPrefix(self: *Builder, search_prefix: []const u8) void {
        self.search_prefixes.append(self.dupePath(search_prefix)) catch unreachable;
    }

    pub fn getInstallPath(self: *Builder, dir: InstallDir, dest_rel_path: []const u8) []const u8 {
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
        ) catch unreachable;
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
        if (self.execPkgConfigList(&code)) |list| {
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
};

test "builder.findProgram compiles" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const builder = try Builder.create(
        arena.allocator(),
        "zig",
        "zig-cache",
        "zig-cache",
        "zig-cache",
    );
    defer builder.destroy();
    _ = builder.findProgram(&[_][]const u8{}, &[_][]const u8{}) catch null;
}

pub const Pkg = struct {
    name: []const u8,
    source: FileSource,
    dependencies: ?[]const Pkg = null,
};

pub const CSourceFile = struct {
    source: FileSource,
    args: []const []const u8,

    fn dupe(self: CSourceFile, b: *Builder) CSourceFile {
        return .{
            .source = self.source.dupe(b),
            .args = b.dupeStrings(self.args),
        };
    }
};

const CSourceFiles = struct {
    files: []const []const u8,
    flags: []const []const u8,
};

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
    pub fn addStepDependencies(self: FileSource, step: *Step) void {
        switch (self) {
            .path => {},
            .generated => |gen| step.dependOn(gen.step),
        }
    }

    /// Should only be called during make(), returns a path relative to the build root or absolute.
    pub fn getPath(self: FileSource, builder: *Builder) []const u8 {
        const path = switch (self) {
            .path => |p| builder.pathFromRoot(p),
            .generated => |gen| gen.getPath(),
        };
        return path;
    }

    /// Duplicates the file source for a given builder.
    pub fn dupe(self: FileSource, b: *Builder) FileSource {
        return switch (self) {
            .path => |p| .{ .path = b.dupePath(p) },
            .generated => |gen| .{ .generated = gen },
        };
    }
};

pub const LibExeObjStep = struct {
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
    use_stage1: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    ofmt: ?std.Target.ObjectFormat = null,

    output_path_source: GeneratedFile,
    output_lib_path_source: GeneratedFile,
    output_h_path_source: GeneratedFile,
    output_pdb_path_source: GeneratedFile,

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
        const macro = constructCMacro(self.builder.allocator, name, value);
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
            const pkgs = try self.builder.getPkgConfigList();

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

        if (self.use_stage1) |stage1| {
            if (stage1) {
                try zig_args.append("-fstage1");
            } else {
                try zig_args.append("-fno-stage1");
            }
        } else if (builder.use_stage1) |stage1| {
            if (stage1) {
                try zig_args.append("-fstage1");
            } else {
                try zig_args.append("-fno-stage1");
            }
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

        if (self.ofmt) |ofmt| {
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

        for (builder.debug_log_scopes) |log_scope| {
            try zig_args.append("--debug-log");
            try zig_args.append(log_scope);
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

                try zig_args.append(mcpu_buffer.toOwnedSlice());
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
                                // "i386" which is why we do it manually here.
                                const fmt_str = "{s}" ++ fs.path.sep_str ++ "{s}-{s}-{s}";
                                const cpu_arch = self.target.getCpuArch();
                                const os_tag = self.target.getOsTag();
                                const abi = self.target.getAbi();
                                const cpu_arch_name: []const u8 = if (cpu_arch == .i386)
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
                if (mem.eql(u8, entry.name, "stage1.id") or
                    mem.eql(u8, entry.name, "llvm-ar.id") or
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

pub const InstallArtifactStep = struct {
    pub const base_id = .install_artifact;

    step: Step,
    builder: *Builder,
    artifact: *LibExeObjStep,
    dest_dir: InstallDir,
    pdb_dir: ?InstallDir,
    h_dir: ?InstallDir,

    const Self = @This();

    pub fn create(builder: *Builder, artifact: *LibExeObjStep) *Self {
        if (artifact.install_step) |s| return s;

        const self = builder.allocator.create(Self) catch unreachable;
        self.* = Self{
            .builder = builder,
            .step = Step.init(.install_artifact, builder.fmt("install {s}", .{artifact.step.name}), builder.allocator, make),
            .artifact = artifact,
            .dest_dir = artifact.override_dest_dir orelse switch (artifact.kind) {
                .obj => @panic("Cannot install a .obj build artifact."),
                .@"test" => @panic("Cannot install a test build artifact, use addTestExe instead."),
                .exe, .test_exe => InstallDir{ .bin = {} },
                .lib => InstallDir{ .lib = {} },
            },
            .pdb_dir = if (artifact.producesPdbFile()) blk: {
                if (artifact.kind == .exe or artifact.kind == .test_exe) {
                    break :blk InstallDir{ .bin = {} };
                } else {
                    break :blk InstallDir{ .lib = {} };
                }
            } else null,
            .h_dir = if (artifact.kind == .lib and artifact.emit_h) .header else null,
        };
        self.step.dependOn(&artifact.step);
        artifact.install_step = self;

        builder.pushInstalledFile(self.dest_dir, artifact.out_filename);
        if (self.artifact.isDynamicLibrary()) {
            if (artifact.major_only_filename) |name| {
                builder.pushInstalledFile(.lib, name);
            }
            if (artifact.name_only_filename) |name| {
                builder.pushInstalledFile(.lib, name);
            }
            if (self.artifact.target.isWindows()) {
                builder.pushInstalledFile(.lib, artifact.out_lib_filename);
            }
        }
        if (self.pdb_dir) |pdb_dir| {
            builder.pushInstalledFile(pdb_dir, artifact.out_pdb_filename);
        }
        if (self.h_dir) |h_dir| {
            builder.pushInstalledFile(h_dir, artifact.out_h_filename);
        }
        return self;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(Self, "step", step);
        const builder = self.builder;

        const full_dest_path = builder.getInstallPath(self.dest_dir, self.artifact.out_filename);
        try builder.updateFile(self.artifact.getOutputSource().getPath(builder), full_dest_path);
        if (self.artifact.isDynamicLibrary() and self.artifact.version != null and self.artifact.target.wantSharedLibSymLinks()) {
            try doAtomicSymLinks(builder.allocator, full_dest_path, self.artifact.major_only_filename.?, self.artifact.name_only_filename.?);
        }
        if (self.artifact.isDynamicLibrary() and self.artifact.target.isWindows() and self.artifact.emit_implib != .no_emit) {
            const full_implib_path = builder.getInstallPath(self.dest_dir, self.artifact.out_lib_filename);
            try builder.updateFile(self.artifact.getOutputLibSource().getPath(builder), full_implib_path);
        }
        if (self.pdb_dir) |pdb_dir| {
            const full_pdb_path = builder.getInstallPath(pdb_dir, self.artifact.out_pdb_filename);
            try builder.updateFile(self.artifact.getOutputPdbSource().getPath(builder), full_pdb_path);
        }
        if (self.h_dir) |h_dir| {
            const full_pdb_path = builder.getInstallPath(h_dir, self.artifact.out_h_filename);
            try builder.updateFile(self.artifact.getOutputHSource().getPath(builder), full_pdb_path);
        }
        self.artifact.installed_path = full_dest_path;
    }
};

pub const InstallFileStep = struct {
    pub const base_id = .install_file;

    step: Step,
    builder: *Builder,
    source: FileSource,
    dir: InstallDir,
    dest_rel_path: []const u8,

    pub fn init(
        builder: *Builder,
        source: FileSource,
        dir: InstallDir,
        dest_rel_path: []const u8,
    ) InstallFileStep {
        builder.pushInstalledFile(dir, dest_rel_path);
        return InstallFileStep{
            .builder = builder,
            .step = Step.init(.install_file, builder.fmt("install {s} to {s}", .{ source.getDisplayName(), dest_rel_path }), builder.allocator, make),
            .source = source.dupe(builder),
            .dir = dir.dupe(builder),
            .dest_rel_path = builder.dupePath(dest_rel_path),
        };
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(InstallFileStep, "step", step);
        const full_dest_path = self.builder.getInstallPath(self.dir, self.dest_rel_path);
        const full_src_path = self.source.getPath(self.builder);
        try self.builder.updateFile(full_src_path, full_dest_path);
    }
};

pub const InstallDirectoryOptions = struct {
    source_dir: []const u8,
    install_dir: InstallDir,
    install_subdir: []const u8,
    /// File paths which end in any of these suffixes will be excluded
    /// from being installed.
    exclude_extensions: []const []const u8 = &.{},
    /// File paths which end in any of these suffixes will result in
    /// empty files being installed. This is mainly intended for large
    /// test.zig files in order to prevent needless installation bloat.
    /// However if the files were not present at all, then
    /// `@import("test.zig")` would be a compile error.
    blank_extensions: []const []const u8 = &.{},

    fn dupe(self: InstallDirectoryOptions, b: *Builder) InstallDirectoryOptions {
        return .{
            .source_dir = b.dupe(self.source_dir),
            .install_dir = self.install_dir.dupe(b),
            .install_subdir = b.dupe(self.install_subdir),
            .exclude_extensions = b.dupeStrings(self.exclude_extensions),
            .blank_extensions = b.dupeStrings(self.blank_extensions),
        };
    }
};

pub const InstallDirStep = struct {
    pub const base_id = .install_dir;

    step: Step,
    builder: *Builder,
    options: InstallDirectoryOptions,

    pub fn init(
        builder: *Builder,
        options: InstallDirectoryOptions,
    ) InstallDirStep {
        builder.pushInstalledFile(options.install_dir, options.install_subdir);
        return InstallDirStep{
            .builder = builder,
            .step = Step.init(.install_dir, builder.fmt("install {s}/", .{options.source_dir}), builder.allocator, make),
            .options = options.dupe(builder),
        };
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(InstallDirStep, "step", step);
        const dest_prefix = self.builder.getInstallPath(self.options.install_dir, self.options.install_subdir);
        const full_src_dir = self.builder.pathFromRoot(self.options.source_dir);
        var src_dir = try std.fs.cwd().openIterableDir(full_src_dir, .{});
        defer src_dir.close();
        var it = try src_dir.walk(self.builder.allocator);
        next_entry: while (try it.next()) |entry| {
            for (self.options.exclude_extensions) |ext| {
                if (mem.endsWith(u8, entry.path, ext)) {
                    continue :next_entry;
                }
            }

            const full_path = self.builder.pathJoin(&.{
                full_src_dir, entry.path,
            });

            const dest_path = self.builder.pathJoin(&.{
                dest_prefix, entry.path,
            });

            switch (entry.kind) {
                .Directory => try fs.cwd().makePath(dest_path),
                .File => {
                    for (self.options.blank_extensions) |ext| {
                        if (mem.endsWith(u8, entry.path, ext)) {
                            try self.builder.truncateFile(dest_path);
                            continue :next_entry;
                        }
                    }

                    try self.builder.updateFile(full_path, dest_path);
                },
                else => continue,
            }
        }
    }
};

pub const LogStep = struct {
    pub const base_id = .log;

    step: Step,
    builder: *Builder,
    data: []const u8,

    pub fn init(builder: *Builder, data: []const u8) LogStep {
        return LogStep{
            .builder = builder,
            .step = Step.init(.log, builder.fmt("log {s}", .{data}), builder.allocator, make),
            .data = builder.dupe(data),
        };
    }

    fn make(step: *Step) anyerror!void {
        const self = @fieldParentPtr(LogStep, "step", step);
        log.info("{s}", .{self.data});
    }
};

pub const RemoveDirStep = struct {
    pub const base_id = .remove_dir;

    step: Step,
    builder: *Builder,
    dir_path: []const u8,

    pub fn init(builder: *Builder, dir_path: []const u8) RemoveDirStep {
        return RemoveDirStep{
            .builder = builder,
            .step = Step.init(.remove_dir, builder.fmt("RemoveDir {s}", .{dir_path}), builder.allocator, make),
            .dir_path = builder.dupePath(dir_path),
        };
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(RemoveDirStep, "step", step);

        const full_path = self.builder.pathFromRoot(self.dir_path);
        fs.cwd().deleteTree(full_path) catch |err| {
            log.err("Unable to remove {s}: {s}", .{ full_path, @errorName(err) });
            return err;
        };
    }
};

const ThisModule = @This();
pub const Step = struct {
    id: Id,
    name: []const u8,
    makeFn: MakeFn,
    dependencies: ArrayList(*Step),
    loop_flag: bool,
    done_flag: bool,

    const MakeFn = std.meta.FnPtr(fn (self: *Step) anyerror!void);

    pub const Id = enum {
        top_level,
        lib_exe_obj,
        install_artifact,
        install_file,
        install_dir,
        log,
        remove_dir,
        fmt,
        translate_c,
        write_file,
        run,
        emulatable_run,
        check_file,
        check_object,
        install_raw,
        options,
        custom,
    };

    pub fn init(id: Id, name: []const u8, allocator: Allocator, makeFn: MakeFn) Step {
        return Step{
            .id = id,
            .name = allocator.dupe(u8, name) catch unreachable,
            .makeFn = makeFn,
            .dependencies = ArrayList(*Step).init(allocator),
            .loop_flag = false,
            .done_flag = false,
        };
    }
    pub fn initNoOp(id: Id, name: []const u8, allocator: Allocator) Step {
        return init(id, name, allocator, makeNoOp);
    }

    pub fn make(self: *Step) !void {
        if (self.done_flag) return;

        try self.makeFn(self);
        self.done_flag = true;
    }

    pub fn dependOn(self: *Step, other: *Step) void {
        self.dependencies.append(other) catch unreachable;
    }

    fn makeNoOp(self: *Step) anyerror!void {
        _ = self;
    }

    pub fn cast(step: *Step, comptime T: type) ?*T {
        if (step.id == T.base_id) {
            return @fieldParentPtr(T, "step", step);
        }
        return null;
    }
};

fn doAtomicSymLinks(allocator: Allocator, output_path: []const u8, filename_major_only: []const u8, filename_name_only: []const u8) !void {
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

const VcpkgRoot = union(VcpkgRootStatus) {
    unattempted: void,
    not_found: void,
    found: []const u8,
};

const VcpkgRootStatus = enum {
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
    pub fn dupe(self: InstallDir, builder: *Builder) InstallDir {
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
    pub fn dupe(self: InstalledFile, builder: *Builder) InstalledFile {
        return .{
            .dir = self.dir.dupe(builder),
            .path = builder.dupe(self.path),
        };
    }
};

test "Builder.dupePkg()" {
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

    var pkg_dep = Pkg{
        .name = "pkg_dep",
        .source = .{ .path = "/not/a/pkg_dep.zig" },
    };
    var pkg_top = Pkg{
        .name = "pkg_top",
        .source = .{ .path = "/not/a/pkg_top.zig" },
        .dependencies = &[_]Pkg{pkg_dep},
    };
    const dupe = builder.dupePkg(pkg_top);

    const original_deps = pkg_top.dependencies.?;
    const dupe_deps = dupe.dependencies.?;

    // probably the same top level package details
    try std.testing.expectEqualStrings(pkg_top.name, dupe.name);

    // probably the same dependencies
    try std.testing.expectEqual(original_deps.len, dupe_deps.len);
    try std.testing.expectEqual(original_deps[0].name, pkg_dep.name);

    // could segfault otherwise if pointers in duplicated package's fields are
    // the same as those in stack allocated package's fields
    try std.testing.expect(dupe_deps.ptr != original_deps.ptr);
    try std.testing.expect(dupe.name.ptr != pkg_top.name.ptr);
    try std.testing.expect(dupe.source.path.ptr != pkg_top.source.path.ptr);
    try std.testing.expect(dupe_deps[0].name.ptr != pkg_dep.name.ptr);
    try std.testing.expect(dupe_deps[0].source.path.ptr != pkg_dep.source.path.ptr);
}

test "LibExeObjStep.addPackage" {
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
