const std = @import("std.zig");
const builtin = std.builtin;
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const debug = std.debug;
const panic = std.debug.panic;
const assert = debug.assert;
const warn = std.debug.warn;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Allocator = mem.Allocator;
const process = std.process;
const BufSet = std.BufSet;
const BufMap = std.BufMap;
const fmt_lib = std.fmt;
const File = std.fs.File;
const CrossTarget = std.zig.CrossTarget;

pub const FmtStep = @import("build/fmt.zig").FmtStep;
pub const TranslateCStep = @import("build/translate_c.zig").TranslateCStep;
pub const WriteFileStep = @import("build/write_file.zig").WriteFileStep;
pub const RunStep = @import("build/run.zig").RunStep;
pub const CheckFileStep = @import("build/check_file.zig").CheckFileStep;
pub const InstallRawStep = @import("build/emit_raw.zig").InstallRawStep;

pub const Builder = struct {
    install_tls: TopLevelStep,
    uninstall_tls: TopLevelStep,
    allocator: *Allocator,
    user_input_options: UserInputOptionsMap,
    available_options_map: AvailableOptionsMap,
    available_options_list: ArrayList(AvailableOption),
    verbose: bool,
    verbose_tokenize: bool,
    verbose_ast: bool,
    verbose_link: bool,
    verbose_cc: bool,
    verbose_ir: bool,
    verbose_llvm_ir: bool,
    verbose_cimport: bool,
    verbose_llvm_cpu_features: bool,
    invalid_user_input: bool,
    zig_exe: []const u8,
    default_step: *Step,
    env_map: *BufMap,
    top_level_steps: ArrayList(*TopLevelStep),
    install_prefix: ?[]const u8,
    dest_dir: ?[]const u8,
    lib_dir: []const u8,
    exe_dir: []const u8,
    h_dir: []const u8,
    install_path: []const u8,
    search_prefixes: ArrayList([]const u8),
    installed_files: ArrayList(InstalledFile),
    build_root: []const u8,
    cache_root: []const u8,
    release_mode: ?builtin.Mode,
    is_release: bool,
    override_lib_dir: ?[]const u8,
    vcpkg_root: VcpkgRoot,
    pkg_config_pkg_list: ?(PkgConfigError![]const PkgConfigPkg) = null,
    args: ?[][]const u8 = null,

    const PkgConfigError = error{
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
    };

    const UserInputOption = struct {
        name: []const u8,
        value: UserValue,
        used: bool,
    };

    const UserValue = union(enum) {
        Flag: void,
        Scalar: []const u8,
        List: ArrayList([]const u8),
    };

    const TypeId = enum {
        Bool,
        Int,
        Float,
        Enum,
        String,
        List,
    };

    const TopLevelStep = struct {
        step: Step,
        description: []const u8,
    };

    pub fn create(
        allocator: *Allocator,
        zig_exe: []const u8,
        build_root: []const u8,
        cache_root: []const u8,
    ) !*Builder {
        const env_map = try allocator.create(BufMap);
        env_map.* = try process.getEnvMap(allocator);

        const self = try allocator.create(Builder);
        self.* = Builder{
            .zig_exe = zig_exe,
            .build_root = build_root,
            .cache_root = try fs.path.relative(allocator, build_root, cache_root),
            .verbose = false,
            .verbose_tokenize = false,
            .verbose_ast = false,
            .verbose_link = false,
            .verbose_cc = false,
            .verbose_ir = false,
            .verbose_llvm_ir = false,
            .verbose_cimport = false,
            .verbose_llvm_cpu_features = false,
            .invalid_user_input = false,
            .allocator = allocator,
            .user_input_options = UserInputOptionsMap.init(allocator),
            .available_options_map = AvailableOptionsMap.init(allocator),
            .available_options_list = ArrayList(AvailableOption).init(allocator),
            .top_level_steps = ArrayList(*TopLevelStep).init(allocator),
            .default_step = undefined,
            .env_map = env_map,
            .search_prefixes = ArrayList([]const u8).init(allocator),
            .install_prefix = null,
            .lib_dir = undefined,
            .exe_dir = undefined,
            .h_dir = undefined,
            .dest_dir = env_map.get("DESTDIR"),
            .installed_files = ArrayList(InstalledFile).init(allocator),
            .install_tls = TopLevelStep{
                .step = Step.initNoOp(.TopLevel, "install", allocator),
                .description = "Copy build artifacts to prefix path",
            },
            .uninstall_tls = TopLevelStep{
                .step = Step.init(.TopLevel, "uninstall", allocator, makeUninstall),
                .description = "Remove build artifacts from prefix path",
            },
            .release_mode = null,
            .is_release = false,
            .override_lib_dir = null,
            .install_path = undefined,
            .vcpkg_root = VcpkgRoot{ .Unattempted = {} },
            .args = null,
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

    /// This function is intended to be called by std/special/build_runner.zig, not a build.zig file.
    pub fn setInstallPrefix(self: *Builder, optional_prefix: ?[]const u8) void {
        self.install_prefix = optional_prefix;
    }

    /// This function is intended to be called by std/special/build_runner.zig, not a build.zig file.
    pub fn resolveInstallPrefix(self: *Builder) void {
        if (self.dest_dir) |dest_dir| {
            const install_prefix = self.install_prefix orelse "/usr";
            self.install_path = fs.path.join(self.allocator, &[_][]const u8{ dest_dir, install_prefix }) catch unreachable;
        } else {
            const install_prefix = self.install_prefix orelse blk: {
                const p = self.cache_root;
                self.install_prefix = p;
                break :blk p;
            };
            self.install_path = install_prefix;
        }
        self.lib_dir = fs.path.join(self.allocator, &[_][]const u8{ self.install_path, "lib" }) catch unreachable;
        self.exe_dir = fs.path.join(self.allocator, &[_][]const u8{ self.install_path, "bin" }) catch unreachable;
        self.h_dir = fs.path.join(self.allocator, &[_][]const u8{ self.install_path, "include" }) catch unreachable;
    }

    pub fn addExecutable(self: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        return LibExeObjStep.createExecutable(
            self,
            name,
            if (root_src) |p| FileSource{ .path = p } else null,
            false,
        );
    }

    pub fn addExecutableFromWriteFileStep(
        self: *Builder,
        name: []const u8,
        wfs: *WriteFileStep,
        basename: []const u8,
    ) *LibExeObjStep {
        return LibExeObjStep.createExecutable(self, name, @as(FileSource, .{
            .write_file = .{
                .step = wfs,
                .basename = basename,
            },
        }), false);
    }

    pub fn addExecutableSource(
        self: *Builder,
        name: []const u8,
        root_src: ?FileSource,
    ) *LibExeObjStep {
        return LibExeObjStep.createExecutable(self, name, root_src, false);
    }

    pub fn addObject(self: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        const root_src_param = if (root_src) |p| @as(FileSource, .{ .path = p }) else null;
        return LibExeObjStep.createObject(self, name, root_src_param);
    }

    pub fn addObjectFromWriteFileStep(
        self: *Builder,
        name: []const u8,
        wfs: *WriteFileStep,
        basename: []const u8,
    ) *LibExeObjStep {
        return LibExeObjStep.createObject(self, name, @as(FileSource, .{
            .write_file = .{
                .step = wfs,
                .basename = basename,
            },
        }));
    }

    pub fn addSharedLibrary(self: *Builder, name: []const u8, root_src: ?[]const u8, ver: Version) *LibExeObjStep {
        const root_src_param = if (root_src) |p| @as(FileSource, .{ .path = p }) else null;
        return LibExeObjStep.createSharedLibrary(self, name, root_src_param, ver);
    }

    pub fn addStaticLibrary(self: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        const root_src_param = if (root_src) |p| @as(FileSource, .{ .path = p }) else null;
        return LibExeObjStep.createStaticLibrary(self, name, root_src_param);
    }

    pub fn addTest(self: *Builder, root_src: []const u8) *LibExeObjStep {
        return LibExeObjStep.createTest(self, "test", .{ .path = root_src });
    }

    pub fn addAssemble(self: *Builder, name: []const u8, src: []const u8) *LibExeObjStep {
        const obj_step = LibExeObjStep.createObject(self, name, null);
        obj_step.addAssemblyFile(src);
        return obj_step;
    }

    /// Initializes a RunStep with argv, which must at least have the path to the
    /// executable. More command line arguments can be added with `addArg`,
    /// `addArgs`, and `addArtifactArg`.
    /// Be careful using this function, as it introduces a system dependency.
    /// To run an executable built with zig build, see `LibExeObjStep.run`.
    pub fn addSystemCommand(self: *Builder, argv: []const []const u8) *RunStep {
        assert(argv.len >= 1);
        const run_step = RunStep.create(self, self.fmt("run {}", .{argv[0]}));
        run_step.addArgs(argv);
        return run_step;
    }

    pub fn dupe(self: *Builder, bytes: []const u8) []u8 {
        return self.allocator.dupe(u8, bytes) catch unreachable;
    }

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
        return TranslateCStep.create(self, source);
    }

    pub fn version(self: *const Builder, major: u32, minor: u32, patch: u32) Version {
        return Version{
            .major = major,
            .minor = minor,
            .patch = patch,
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

        for (wanted_steps.span()) |s| {
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

        for (self.installed_files.span()) |installed_file| {
            const full_path = self.getInstallPath(installed_file.dir, installed_file.path);
            if (self.verbose) {
                warn("rm {}\n", .{full_path});
            }
            fs.cwd().deleteTree(full_path) catch {};
        }

        // TODO remove empty directories
    }

    fn makeOneStep(self: *Builder, s: *Step) anyerror!void {
        if (s.loop_flag) {
            warn("Dependency loop detected:\n  {}\n", .{s.name});
            return error.DependencyLoopDetected;
        }
        s.loop_flag = true;

        for (s.dependencies.span()) |dep| {
            self.makeOneStep(dep) catch |err| {
                if (err == error.DependencyLoopDetected) {
                    warn("  {}\n", .{s.name});
                }
                return err;
            };
        }

        s.loop_flag = false;

        try s.make();
    }

    fn getTopLevelStepByName(self: *Builder, name: []const u8) !*Step {
        for (self.top_level_steps.span()) |top_level_step| {
            if (mem.eql(u8, top_level_step.step.name, name)) {
                return &top_level_step.step;
            }
        }
        warn("Cannot run step '{}' because it does not exist\n", .{name});
        return error.InvalidStepName;
    }

    pub fn option(self: *Builder, comptime T: type, name: []const u8, description: []const u8) ?T {
        const type_id = comptime typeToEnum(T);
        const available_option = AvailableOption{
            .name = name,
            .type_id = type_id,
            .description = description,
        };
        if ((self.available_options_map.fetchPut(name, available_option) catch unreachable) != null) {
            panic("Option '{}' declared twice", .{name});
        }
        self.available_options_list.append(available_option) catch unreachable;

        const entry = self.user_input_options.getEntry(name) orelse return null;
        entry.value.used = true;
        switch (type_id) {
            TypeId.Bool => switch (entry.value.value) {
                UserValue.Flag => return true,
                UserValue.Scalar => |s| {
                    if (mem.eql(u8, s, "true")) {
                        return true;
                    } else if (mem.eql(u8, s, "false")) {
                        return false;
                    } else {
                        warn("Expected -D{} to be a boolean, but received '{}'\n", .{ name, s });
                        self.markInvalidUserInput();
                        return null;
                    }
                },
                UserValue.List => {
                    warn("Expected -D{} to be a boolean, but received a list.\n", .{name});
                    self.markInvalidUserInput();
                    return null;
                },
            },
            TypeId.Int => panic("TODO integer options to build script", .{}),
            TypeId.Float => panic("TODO float options to build script", .{}),
            TypeId.Enum => switch (entry.value.value) {
                UserValue.Flag => {
                    warn("Expected -D{} to be a string, but received a boolean.\n", .{name});
                    self.markInvalidUserInput();
                    return null;
                },
                UserValue.Scalar => |s| {
                    if (std.meta.stringToEnum(T, s)) |enum_lit| {
                        return enum_lit;
                    } else {
                        warn("Expected -D{} to be of type {}.\n", .{ name, @typeName(T) });
                        self.markInvalidUserInput();
                        return null;
                    }
                },
                UserValue.List => {
                    warn("Expected -D{} to be a string, but received a list.\n", .{name});
                    self.markInvalidUserInput();
                    return null;
                },
            },
            TypeId.String => switch (entry.value.value) {
                UserValue.Flag => {
                    warn("Expected -D{} to be a string, but received a boolean.\n", .{name});
                    self.markInvalidUserInput();
                    return null;
                },
                UserValue.List => {
                    warn("Expected -D{} to be a string, but received a list.\n", .{name});
                    self.markInvalidUserInput();
                    return null;
                },
                UserValue.Scalar => |s| return s,
            },
            TypeId.List => switch (entry.value.value) {
                UserValue.Flag => {
                    warn("Expected -D{} to be a list, but received a boolean.\n", .{name});
                    self.markInvalidUserInput();
                    return null;
                },
                UserValue.Scalar => |s| return &[_][]const u8{s},
                UserValue.List => |lst| return lst.span(),
            },
        }
    }

    pub fn step(self: *Builder, name: []const u8, description: []const u8) *Step {
        const step_info = self.allocator.create(TopLevelStep) catch unreachable;
        step_info.* = TopLevelStep{
            .step = Step.initNoOp(.TopLevel, name, self.allocator),
            .description = description,
        };
        self.top_level_steps.append(step_info) catch unreachable;
        return &step_info.step;
    }

    /// This provides the -Drelease option to the build user and does not give them the choice.
    pub fn setPreferredReleaseMode(self: *Builder, mode: builtin.Mode) void {
        if (self.release_mode != null) {
            @panic("setPreferredReleaseMode must be called before standardReleaseOptions and may not be called twice");
        }
        const description = self.fmt("Create a release build ({})", .{@tagName(mode)});
        self.is_release = self.option(bool, "release", description) orelse false;
        self.release_mode = if (self.is_release) mode else builtin.Mode.Debug;
    }

    /// If you call this without first calling `setPreferredReleaseMode` then it gives the build user
    /// the choice of what kind of release.
    pub fn standardReleaseOptions(self: *Builder) builtin.Mode {
        if (self.release_mode) |mode| return mode;

        const release_safe = self.option(bool, "release-safe", "Optimizations on and safety on") orelse false;
        const release_fast = self.option(bool, "release-fast", "Optimizations on and safety off") orelse false;
        const release_small = self.option(bool, "release-small", "Size optimizations on and safety off") orelse false;

        const mode = if (release_safe and !release_fast and !release_small)
            builtin.Mode.ReleaseSafe
        else if (release_fast and !release_safe and !release_small)
            builtin.Mode.ReleaseFast
        else if (release_small and !release_fast and !release_safe)
            builtin.Mode.ReleaseSmall
        else if (!release_fast and !release_safe and !release_small)
            builtin.Mode.Debug
        else x: {
            warn("Multiple release modes (of -Drelease-safe, -Drelease-fast and -Drelease-small)", .{});
            self.markInvalidUserInput();
            break :x builtin.Mode.Debug;
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
        const triple = self.option(
            []const u8,
            "target",
            "The CPU architecture, OS, and ABI to build for",
        ) orelse return args.default_target;

        // TODO add cpu and features as part of the target triple

        var diags: CrossTarget.ParseOptions.Diagnostics = .{};
        const selected_target = CrossTarget.parse(.{
            .arch_os_abi = triple,
            .diagnostics = &diags,
        }) catch |err| switch (err) {
            error.UnknownCpuModel => {
                std.debug.warn("Unknown CPU: '{}'\nAvailable CPUs for architecture '{}':\n", .{
                    diags.cpu_name.?,
                    @tagName(diags.arch.?),
                });
                for (diags.arch.?.allCpuModels()) |cpu| {
                    std.debug.warn(" {}\n", .{cpu.name});
                }
                process.exit(1);
            },
            error.UnknownCpuFeature => {
                std.debug.warn(
                    \\Unknown CPU feature: '{}'
                    \\Available CPU features for architecture '{}':
                    \\
                , .{
                    diags.unknown_feature_name,
                    @tagName(diags.arch.?),
                });
                for (diags.arch.?.allFeaturesList()) |feature| {
                    std.debug.warn(" {}: {}\n", .{ feature.name, feature.description });
                }
                process.exit(1);
            },
            error.UnknownOperatingSystem => {
                std.debug.warn(
                    \\Unknown OS: '{}'
                    \\Available operating systems:
                    \\
                , .{diags.os_name});
                inline for (std.meta.fields(std.Target.Os.Tag)) |field| {
                    std.debug.warn(" {}\n", .{field.name});
                }
                process.exit(1);
            },
            else => |e| {
                std.debug.warn("Unable to parse target '{}': {}\n", .{ triple, @errorName(e) });
                process.exit(1);
            },
        };

        const selected_canonicalized_triple = selected_target.zigTriple(self.allocator) catch unreachable;

        if (args.whitelist) |list| whitelist_check: {
            // Make sure it's a match of one of the list.
            for (list) |t| {
                const t_triple = t.zigTriple(self.allocator) catch unreachable;
                if (mem.eql(u8, t_triple, selected_canonicalized_triple)) {
                    break :whitelist_check;
                }
            }
            std.debug.warn("Chosen target '{}' does not match one of the supported targets:\n", .{
                selected_canonicalized_triple,
            });
            for (list) |t| {
                const t_triple = t.zigTriple(self.allocator) catch unreachable;
                std.debug.warn(" {}\n", .{t_triple});
            }
            // TODO instead of process exit, return error and have a zig build flag implemented by
            // the build runner that turns process exits into error return traces
            process.exit(1);
        }

        return selected_target;
    }

    pub fn addUserInputOption(self: *Builder, name: []const u8, value: []const u8) !bool {
        const gop = try self.user_input_options.getOrPut(name);
        if (!gop.found_existing) {
            gop.entry.value = UserInputOption{
                .name = name,
                .value = UserValue{ .Scalar = value },
                .used = false,
            };
            return false;
        }

        // option already exists
        switch (gop.entry.value.value) {
            UserValue.Scalar => |s| {
                // turn it into a list
                var list = ArrayList([]const u8).init(self.allocator);
                list.append(s) catch unreachable;
                list.append(value) catch unreachable;
                _ = self.user_input_options.put(name, UserInputOption{
                    .name = name,
                    .value = UserValue{ .List = list },
                    .used = false,
                }) catch unreachable;
            },
            UserValue.List => |*list| {
                // append to the list
                list.append(value) catch unreachable;
                _ = self.user_input_options.put(name, UserInputOption{
                    .name = name,
                    .value = UserValue{ .List = list.* },
                    .used = false,
                }) catch unreachable;
            },
            UserValue.Flag => {
                warn("Option '-D{}={}' conflicts with flag '-D{}'.\n", .{ name, value, name });
                return true;
            },
        }
        return false;
    }

    pub fn addUserInputFlag(self: *Builder, name: []const u8) !bool {
        const gop = try self.user_input_options.getOrPut(name);
        if (!gop.found_existing) {
            gop.entry.value = UserInputOption{
                .name = name,
                .value = UserValue{ .Flag = {} },
                .used = false,
            };
            return false;
        }

        // option already exists
        switch (gop.entry.value.value) {
            UserValue.Scalar => |s| {
                warn("Flag '-D{}' conflicts with option '-D{}={}'.\n", .{ name, name, s });
                return true;
            },
            UserValue.List => {
                warn("Flag '-D{}' conflicts with multiple options of the same name.\n", .{name});
                return true;
            },
            UserValue.Flag => {},
        }
        return false;
    }

    fn typeToEnum(comptime T: type) TypeId {
        return switch (@typeInfo(T)) {
            .Int => .Int,
            .Float => .Float,
            .Bool => .Bool,
            .Enum => .Enum,
            else => switch (T) {
                []const u8 => .String,
                []const []const u8 => .List,
                else => @compileError("Unsupported type: " ++ @typeName(T)),
            },
        };
    }

    fn markInvalidUserInput(self: *Builder) void {
        self.invalid_user_input = true;
    }

    pub fn typeIdName(id: TypeId) []const u8 {
        return switch (id) {
            .Bool => "bool",
            .Int => "int",
            .Float => "float",
            .Enum => "enum",
            .String => "string",
            .List => "list",
        };
    }

    pub fn validateUserInputDidItFail(self: *Builder) bool {
        // make sure all args are used
        var it = self.user_input_options.iterator();
        while (true) {
            const entry = it.next() orelse break;
            if (!entry.value.used) {
                warn("Invalid option: -D{}\n\n", .{entry.key});
                self.markInvalidUserInput();
            }
        }

        return self.invalid_user_input;
    }

    pub fn spawnChild(self: *Builder, argv: []const []const u8) !void {
        return self.spawnChildEnvMap(null, self.env_map, argv);
    }

    fn printCmd(cwd: ?[]const u8, argv: []const []const u8) void {
        if (cwd) |yes_cwd| warn("cd {} && ", .{yes_cwd});
        for (argv) |arg| {
            warn("{} ", .{arg});
        }
        warn("\n", .{});
    }

    fn spawnChildEnvMap(self: *Builder, cwd: ?[]const u8, env_map: *const BufMap, argv: []const []const u8) !void {
        if (self.verbose) {
            printCmd(cwd, argv);
        }

        const child = std.ChildProcess.init(argv, self.allocator) catch unreachable;
        defer child.deinit();

        child.cwd = cwd;
        child.env_map = env_map;

        const term = child.spawnAndWait() catch |err| {
            warn("Unable to spawn {}: {}\n", .{ argv[0], @errorName(err) });
            return err;
        };

        switch (term) {
            .Exited => |code| {
                if (code != 0) {
                    warn("The following command exited with error code {}:\n", .{code});
                    printCmd(cwd, argv);
                    return error.UncleanExit;
                }
            },
            else => {
                warn("The following command terminated unexpectedly:\n", .{});
                printCmd(cwd, argv);

                return error.UncleanExit;
            },
        }
    }

    pub fn makePath(self: *Builder, path: []const u8) !void {
        fs.cwd().makePath(self.pathFromRoot(path)) catch |err| {
            warn("Unable to create path {}: {}\n", .{ path, @errorName(err) });
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
        self.getInstallStep().dependOn(&self.addInstallFileWithDir(src_path, .Prefix, dest_rel_path).step);
    }

    pub fn installDirectory(self: *Builder, options: InstallDirectoryOptions) void {
        self.getInstallStep().dependOn(&self.addInstallDirectory(options).step);
    }

    ///`dest_rel_path` is relative to bin path
    pub fn installBinFile(self: *Builder, src_path: []const u8, dest_rel_path: []const u8) void {
        self.getInstallStep().dependOn(&self.addInstallFileWithDir(src_path, .Bin, dest_rel_path).step);
    }

    ///`dest_rel_path` is relative to lib path
    pub fn installLibFile(self: *Builder, src_path: []const u8, dest_rel_path: []const u8) void {
        self.getInstallStep().dependOn(&self.addInstallFileWithDir(src_path, .Lib, dest_rel_path).step);
    }

    pub fn installRaw(self: *Builder, artifact: *LibExeObjStep, dest_filename: []const u8) void {
        self.getInstallStep().dependOn(&self.addInstallRaw(artifact, dest_filename).step);
    }

    ///`dest_rel_path` is relative to install prefix path
    pub fn addInstallFile(self: *Builder, src_path: []const u8, dest_rel_path: []const u8) *InstallFileStep {
        return self.addInstallFileWithDir(src_path, .Prefix, dest_rel_path);
    }

    ///`dest_rel_path` is relative to bin path
    pub fn addInstallBinFile(self: *Builder, src_path: []const u8, dest_rel_path: []const u8) *InstallFileStep {
        return self.addInstallFileWithDir(src_path, .Bin, dest_rel_path);
    }

    ///`dest_rel_path` is relative to lib path
    pub fn addInstallLibFile(self: *Builder, src_path: []const u8, dest_rel_path: []const u8) *InstallFileStep {
        return self.addInstallFileWithDir(src_path, .Lib, dest_rel_path);
    }

    pub fn addInstallRaw(self: *Builder, artifact: *LibExeObjStep, dest_filename: []const u8) *InstallRawStep {
        return InstallRawStep.create(self, artifact, dest_filename);
    }

    pub fn addInstallFileWithDir(
        self: *Builder,
        src_path: []const u8,
        install_dir: InstallDir,
        dest_rel_path: []const u8,
    ) *InstallFileStep {
        const install_step = self.allocator.create(InstallFileStep) catch unreachable;
        install_step.* = InstallFileStep.init(self, src_path, install_dir, dest_rel_path);
        return install_step;
    }

    pub fn addInstallDirectory(self: *Builder, options: InstallDirectoryOptions) *InstallDirStep {
        const install_step = self.allocator.create(InstallDirStep) catch unreachable;
        install_step.* = InstallDirStep.init(self, options);
        return install_step;
    }

    pub fn pushInstalledFile(self: *Builder, dir: InstallDir, dest_rel_path: []const u8) void {
        self.installed_files.append(InstalledFile{
            .dir = dir,
            .path = dest_rel_path,
        }) catch unreachable;
    }

    pub fn updateFile(self: *Builder, source_path: []const u8, dest_path: []const u8) !void {
        if (self.verbose) {
            warn("cp {} {} ", .{ source_path, dest_path });
        }
        const cwd = fs.cwd();
        const prev_status = try fs.Dir.updateFile(cwd, source_path, cwd, dest_path, .{});
        if (self.verbose) switch (prev_status) {
            .stale => warn("# installed\n", .{}),
            .fresh => warn("# up-to-date\n", .{}),
        };
    }

    pub fn pathFromRoot(self: *Builder, rel_path: []const u8) []u8 {
        return fs.path.resolve(self.allocator, &[_][]const u8{ self.build_root, rel_path }) catch unreachable;
    }

    pub fn fmt(self: *Builder, comptime format: []const u8, args: anytype) []u8 {
        return fmt_lib.allocPrint(self.allocator, format, args) catch unreachable;
    }

    pub fn findProgram(self: *Builder, names: []const []const u8, paths: []const []const u8) ![]const u8 {
        // TODO report error for ambiguous situations
        const exe_extension = @as(CrossTarget, .{}).exeFileExt();
        for (self.search_prefixes.span()) |search_prefix| {
            for (names) |name| {
                if (fs.path.isAbsolute(name)) {
                    return name;
                }
                const full_path = try fs.path.join(self.allocator, &[_][]const u8{
                    search_prefix,
                    "bin",
                    self.fmt("{}{}", .{ name, exe_extension }),
                });
                return fs.realpathAlloc(self.allocator, full_path) catch continue;
            }
        }
        if (self.env_map.get("PATH")) |PATH| {
            for (names) |name| {
                if (fs.path.isAbsolute(name)) {
                    return name;
                }
                var it = mem.tokenize(PATH, &[_]u8{fs.path.delimiter});
                while (it.next()) |path| {
                    const full_path = try fs.path.join(self.allocator, &[_][]const u8{
                        path,
                        self.fmt("{}{}", .{ name, exe_extension }),
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
                const full_path = try fs.path.join(self.allocator, &[_][]const u8{
                    path,
                    self.fmt("{}{}", .{ name, exe_extension }),
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
    ) ![]u8 {
        assert(argv.len != 0);

        const max_output_size = 400 * 1024;
        const child = try std.ChildProcess.init(argv, self.allocator);
        defer child.deinit();

        child.stdin_behavior = .Ignore;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = stderr_behavior;

        try child.spawn();

        const stdout = try child.stdout.?.inStream().readAllAlloc(self.allocator, max_output_size);
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

        var code: u8 = undefined;
        return self.execAllowFail(argv, &code, .Inherit) catch |err| switch (err) {
            error.FileNotFound => {
                if (src_step) |s| warn("{}...", .{s.name});
                warn("Unable to spawn the following command: file not found\n", .{});
                printCmd(null, argv);
                std.os.exit(@truncate(u8, code));
            },
            error.ExitCodeFailure => {
                if (src_step) |s| warn("{}...", .{s.name});
                warn("The following command exited with error code {}:\n", .{code});
                printCmd(null, argv);
                std.os.exit(@truncate(u8, code));
            },
            error.ProcessTerminated => {
                if (src_step) |s| warn("{}...", .{s.name});
                warn("The following command terminated unexpectedly:\n", .{});
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
        self.search_prefixes.append(search_prefix) catch unreachable;
    }

    pub fn getInstallPath(self: *Builder, dir: InstallDir, dest_rel_path: []const u8) []const u8 {
        const base_dir = switch (dir) {
            .Prefix => self.install_path,
            .Bin => self.exe_dir,
            .Lib => self.lib_dir,
            .Header => self.h_dir,
        };
        return fs.path.resolve(
            self.allocator,
            &[_][]const u8{ base_dir, dest_rel_path },
        ) catch unreachable;
    }

    fn execPkgConfigList(self: *Builder, out_code: *u8) ![]const PkgConfigPkg {
        const stdout = try self.execAllowFail(&[_][]const u8{ "pkg-config", "--list-all" }, out_code, .Ignore);
        var list = ArrayList(PkgConfigPkg).init(self.allocator);
        var line_it = mem.tokenize(stdout, "\r\n");
        while (line_it.next()) |line| {
            if (mem.trim(u8, line, " \t").len == 0) continue;
            var tok_it = mem.tokenize(line, " \t");
            try list.append(PkgConfigPkg{
                .name = tok_it.next() orelse return error.PkgConfigInvalidOutput,
                .desc = tok_it.rest(),
            });
        }
        return list.span();
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
                error.ExitCodeFailure => error.PkgConfigFailed,
                error.FileNotFound => error.PkgConfigNotInstalled,
                error.InvalidName => error.PkgConfigNotInstalled,
                error.PkgConfigInvalidOutput => error.PkgConfigInvalidOutput,
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

    const builder = try Builder.create(&arena.allocator, "zig", "zig-cache", "zig-cache");
    defer builder.destroy();
    _ = builder.findProgram(&[_][]const u8{}, &[_][]const u8{}) catch null;
}

/// Deprecated. Use `std.builtin.Version`.
pub const Version = builtin.Version;

/// Deprecated. Use `std.zig.CrossTarget`.
pub const Target = std.zig.CrossTarget;

pub const Pkg = struct {
    name: []const u8,
    path: []const u8,
    dependencies: ?[]const Pkg = null,
};

const CSourceFile = struct {
    source: FileSource,
    args: []const []const u8,
};

fn isLibCLibrary(name: []const u8) bool {
    const libc_libraries = [_][]const u8{ "c", "m", "dl", "rt", "pthread" };
    for (libc_libraries) |libc_lib_name| {
        if (mem.eql(u8, name, libc_lib_name))
            return true;
    }
    return false;
}

pub const FileSource = union(enum) {
    /// Relative to build root
    path: []const u8,
    write_file: struct {
        step: *WriteFileStep,
        basename: []const u8,
    },
    translate_c: *TranslateCStep,

    pub fn addStepDependencies(self: FileSource, step: *Step) void {
        switch (self) {
            .path => {},
            .write_file => |wf| step.dependOn(&wf.step.step),
            .translate_c => |tc| step.dependOn(&tc.step),
        }
    }

    /// Should only be called during make()
    pub fn getPath(self: FileSource, builder: *Builder) []const u8 {
        return switch (self) {
            .path => |p| builder.pathFromRoot(p),
            .write_file => |wf| wf.step.getOutputPath(wf.basename),
            .translate_c => |tc| tc.getOutputPath(),
        };
    }
};

pub const LibExeObjStep = struct {
    step: Step,
    builder: *Builder,
    name: []const u8,
    target: CrossTarget = CrossTarget{},
    linker_script: ?[]const u8 = null,
    version_script: ?[]const u8 = null,
    out_filename: []const u8,
    is_dynamic: bool,
    version: Version,
    build_mode: builtin.Mode,
    kind: Kind,
    major_only_filename: []const u8,
    name_only_filename: []const u8,
    strip: bool,
    lib_paths: ArrayList([]const u8),
    framework_dirs: ArrayList([]const u8),
    frameworks: BufSet,
    verbose_link: bool,
    verbose_cc: bool,
    emit_llvm_ir: bool = false,
    emit_asm: bool = false,
    emit_bin: bool = true,
    emit_h: bool = false,
    bundle_compiler_rt: bool,
    disable_stack_probing: bool,
    disable_sanitize_c: bool,
    c_std: Builder.CStd,
    override_lib_dir: ?[]const u8,
    main_pkg_path: ?[]const u8,
    exec_cmd_args: ?[]const ?[]const u8,
    name_prefix: []const u8,
    filter: ?[]const u8,
    single_threaded: bool,
    test_evented_io: bool = false,
    code_model: builtin.CodeModel = .default,

    root_src: ?FileSource,
    out_h_filename: []const u8,
    out_lib_filename: []const u8,
    out_pdb_filename: []const u8,
    packages: ArrayList(Pkg),
    build_options_contents: std.ArrayList(u8),
    system_linker_hack: bool = false,

    object_src: []const u8,

    link_objects: ArrayList(LinkObject),
    include_dirs: ArrayList(IncludeDir),
    c_macros: ArrayList([]const u8),
    output_dir: ?[]const u8,
    is_linking_libc: bool = false,
    vcpkg_bin_path: ?[]const u8 = null,

    installed_path: ?[]const u8,
    install_step: ?*InstallArtifactStep,

    libc_file: ?[]const u8 = null,

    valgrind_support: ?bool = null,

    /// Create a .eh_frame_hdr section and a PT_GNU_EH_FRAME segment in the ELF
    /// file.
    link_eh_frame_hdr: bool = false,

    /// Place every function in its own section so that unused ones may be
    /// safely garbage-collected during the linking phase.
    link_function_sections: bool = false,

    /// Uses system Wine installation to run cross compiled Windows build artifacts.
    enable_wine: bool = false,

    /// Uses system QEMU installation to run cross compiled foreign architecture build artifacts.
    enable_qemu: bool = false,

    /// Uses system Wasmtime installation to run cross compiled wasm/wasi build artifacts.
    enable_wasmtime: bool = false,

    /// After following the steps in https://github.com/ziglang/zig/wiki/Updating-libc#glibc,
    /// this will be the directory $glibc-build-dir/install/glibcs
    /// Given the example of the aarch64 target, this is the directory
    /// that contains the path `aarch64-linux-gnu/lib/ld-linux-aarch64.so.1`.
    glibc_multi_install_dir: ?[]const u8 = null,

    /// Position Independent Code
    force_pic: ?bool = null,

    subsystem: ?builtin.SubSystem = null,

    const LinkObject = union(enum) {
        StaticPath: []const u8,
        OtherStep: *LibExeObjStep,
        SystemLib: []const u8,
        AssemblyFile: FileSource,
        CSourceFile: *CSourceFile,
    };

    const IncludeDir = union(enum) {
        RawPath: []const u8,
        RawPathSystem: []const u8,
        OtherStep: *LibExeObjStep,
    };

    const Kind = enum {
        Exe,
        Lib,
        Obj,
        Test,
    };

    pub fn createSharedLibrary(builder: *Builder, name: []const u8, root_src: ?FileSource, ver: Version) *LibExeObjStep {
        const self = builder.allocator.create(LibExeObjStep) catch unreachable;
        self.* = initExtraArgs(builder, name, root_src, Kind.Lib, true, ver);
        return self;
    }

    pub fn createStaticLibrary(builder: *Builder, name: []const u8, root_src: ?FileSource) *LibExeObjStep {
        const self = builder.allocator.create(LibExeObjStep) catch unreachable;
        self.* = initExtraArgs(builder, name, root_src, Kind.Lib, false, builder.version(0, 0, 0));
        return self;
    }

    pub fn createObject(builder: *Builder, name: []const u8, root_src: ?FileSource) *LibExeObjStep {
        const self = builder.allocator.create(LibExeObjStep) catch unreachable;
        self.* = initExtraArgs(builder, name, root_src, Kind.Obj, false, builder.version(0, 0, 0));
        return self;
    }

    pub fn createExecutable(builder: *Builder, name: []const u8, root_src: ?FileSource, is_dynamic: bool) *LibExeObjStep {
        const self = builder.allocator.create(LibExeObjStep) catch unreachable;
        self.* = initExtraArgs(builder, name, root_src, Kind.Exe, is_dynamic, builder.version(0, 0, 0));
        return self;
    }

    pub fn createTest(builder: *Builder, name: []const u8, root_src: FileSource) *LibExeObjStep {
        const self = builder.allocator.create(LibExeObjStep) catch unreachable;
        self.* = initExtraArgs(builder, name, root_src, Kind.Test, false, builder.version(0, 0, 0));
        return self;
    }

    fn initExtraArgs(
        builder: *Builder,
        name: []const u8,
        root_src: ?FileSource,
        kind: Kind,
        is_dynamic: bool,
        ver: Version,
    ) LibExeObjStep {
        if (mem.indexOf(u8, name, "/") != null or mem.indexOf(u8, name, "\\") != null) {
            panic("invalid name: '{}'. It looks like a file path, but it is supposed to be the library or application name.", .{name});
        }
        var self = LibExeObjStep{
            .strip = false,
            .builder = builder,
            .verbose_link = false,
            .verbose_cc = false,
            .build_mode = builtin.Mode.Debug,
            .is_dynamic = is_dynamic,
            .kind = kind,
            .root_src = root_src,
            .name = name,
            .frameworks = BufSet.init(builder.allocator),
            .step = Step.init(.LibExeObj, name, builder.allocator, make),
            .version = ver,
            .out_filename = undefined,
            .out_h_filename = builder.fmt("{}.h", .{name}),
            .out_lib_filename = undefined,
            .out_pdb_filename = builder.fmt("{}.pdb", .{name}),
            .major_only_filename = undefined,
            .name_only_filename = undefined,
            .packages = ArrayList(Pkg).init(builder.allocator),
            .include_dirs = ArrayList(IncludeDir).init(builder.allocator),
            .link_objects = ArrayList(LinkObject).init(builder.allocator),
            .c_macros = ArrayList([]const u8).init(builder.allocator),
            .lib_paths = ArrayList([]const u8).init(builder.allocator),
            .framework_dirs = ArrayList([]const u8).init(builder.allocator),
            .object_src = undefined,
            .build_options_contents = std.ArrayList(u8).init(builder.allocator),
            .c_std = Builder.CStd.C99,
            .override_lib_dir = null,
            .main_pkg_path = null,
            .exec_cmd_args = null,
            .name_prefix = "",
            .filter = null,
            .bundle_compiler_rt = false,
            .disable_stack_probing = false,
            .disable_sanitize_c = false,
            .output_dir = null,
            .single_threaded = false,
            .installed_path = null,
            .install_step = null,
        };
        self.computeOutFileNames();
        if (root_src) |rs| rs.addStepDependencies(&self.step);
        return self;
    }

    fn computeOutFileNames(self: *LibExeObjStep) void {
        switch (self.kind) {
            .Obj => {
                self.out_filename = self.builder.fmt("{}{}", .{ self.name, self.target.oFileExt() });
            },
            .Exe => {
                self.out_filename = self.builder.fmt("{}{}", .{ self.name, self.target.exeFileExt() });
            },
            .Test => {
                self.out_filename = self.builder.fmt("test{}", .{self.target.exeFileExt()});
            },
            .Lib => {
                if (!self.is_dynamic) {
                    self.out_filename = self.builder.fmt("{}{}{}", .{
                        self.target.libPrefix(),
                        self.name,
                        self.target.staticLibSuffix(),
                    });
                    self.out_lib_filename = self.out_filename;
                } else {
                    if (self.target.isDarwin()) {
                        self.out_filename = self.builder.fmt("lib{}.{d}.{d}.{d}.dylib", .{
                            self.name,
                            self.version.major,
                            self.version.minor,
                            self.version.patch,
                        });
                        self.major_only_filename = self.builder.fmt("lib{}.{d}.dylib", .{
                            self.name,
                            self.version.major,
                        });
                        self.name_only_filename = self.builder.fmt("lib{}.dylib", .{self.name});
                        self.out_lib_filename = self.out_filename;
                    } else if (self.target.isWindows()) {
                        self.out_filename = self.builder.fmt("{}.dll", .{self.name});
                        self.out_lib_filename = self.builder.fmt("{}.lib", .{self.name});
                    } else {
                        self.out_filename = self.builder.fmt("lib{}.so.{d}.{d}.{d}", .{
                            self.name,
                            self.version.major,
                            self.version.minor,
                            self.version.patch,
                        });
                        self.major_only_filename = self.builder.fmt("lib{}.so.{d}", .{ self.name, self.version.major });
                        self.name_only_filename = self.builder.fmt("lib{}.so", .{self.name});
                        self.out_lib_filename = self.out_filename;
                    }
                }
            },
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

    pub fn installRaw(self: *LibExeObjStep, dest_filename: []const u8) void {
        self.builder.installRaw(self, dest_filename);
    }

    /// Creates a `RunStep` with an executable built with `addExecutable`.
    /// Add command line arguments with `addArg`.
    pub fn run(exe: *LibExeObjStep) *RunStep {
        assert(exe.kind == Kind.Exe);

        // It doesn't have to be native. We catch that if you actually try to run it.
        // Consider that this is declarative; the run step may not be run unless a user
        // option is supplied.
        const run_step = RunStep.create(exe.builder, exe.builder.fmt("run {}", .{exe.step.name}));
        run_step.addArtifactArg(exe);

        if (exe.vcpkg_bin_path) |path| {
            run_step.addPathDir(path);
        }

        return run_step;
    }

    pub fn setLinkerScriptPath(self: *LibExeObjStep, path: []const u8) void {
        self.linker_script = path;
    }

    pub fn linkFramework(self: *LibExeObjStep, framework_name: []const u8) void {
        assert(self.target.isDarwin());
        self.frameworks.put(framework_name) catch unreachable;
    }

    /// Returns whether the library, executable, or object depends on a particular system library.
    pub fn dependsOnSystemLibrary(self: LibExeObjStep, name: []const u8) bool {
        if (isLibCLibrary(name)) {
            return self.is_linking_libc;
        }
        for (self.link_objects.span()) |link_object| {
            switch (link_object) {
                LinkObject.SystemLib => |n| if (mem.eql(u8, n, name)) return true,
                else => continue,
            }
        }
        return false;
    }

    pub fn linkLibrary(self: *LibExeObjStep, lib: *LibExeObjStep) void {
        assert(lib.kind == Kind.Lib);
        self.linkLibraryOrObject(lib);
    }

    pub fn isDynamicLibrary(self: *LibExeObjStep) bool {
        return self.kind == Kind.Lib and self.is_dynamic;
    }

    pub fn producesPdbFile(self: *LibExeObjStep) bool {
        if (!self.target.isWindows() and !self.target.isUefi()) return false;
        if (self.strip) return false;
        return self.isDynamicLibrary() or self.kind == .Exe;
    }

    pub fn linkLibC(self: *LibExeObjStep) void {
        if (!self.is_linking_libc) {
            self.is_linking_libc = true;
            self.link_objects.append(LinkObject{ .SystemLib = "c" }) catch unreachable;
        }
    }

    /// name_and_value looks like [name]=[value]. If the value is omitted, it is set to 1.
    pub fn defineCMacro(self: *LibExeObjStep, name_and_value: []const u8) void {
        self.c_macros.append(self.builder.dupe(name_and_value)) catch unreachable;
    }

    /// This one has no integration with anything, it just puts -lname on the command line.
    /// Prefer to use `linkSystemLibrary` instead.
    pub fn linkSystemLibraryName(self: *LibExeObjStep, name: []const u8) void {
        self.link_objects.append(LinkObject{ .SystemLib = self.builder.dupe(name) }) catch unreachable;
    }

    /// This links against a system library, exclusively using pkg-config to find the library.
    /// Prefer to use `linkSystemLibrary` instead.
    pub fn linkSystemLibraryPkgConfigOnly(self: *LibExeObjStep, lib_name: []const u8) !void {
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
            error.ExitCodeFailure => return error.PkgConfigFailed,
            error.FileNotFound => return error.PkgConfigNotInstalled,
            else => return err,
        };
        var it = mem.tokenize(stdout, " \r\n\t");
        while (it.next()) |tok| {
            if (mem.eql(u8, tok, "-I")) {
                const dir = it.next() orelse return error.PkgConfigInvalidOutput;
                self.addIncludeDir(dir);
            } else if (mem.startsWith(u8, tok, "-I")) {
                self.addIncludeDir(tok["-I".len..]);
            } else if (mem.eql(u8, tok, "-L")) {
                const dir = it.next() orelse return error.PkgConfigInvalidOutput;
                self.addLibPath(dir);
            } else if (mem.startsWith(u8, tok, "-L")) {
                self.addLibPath(tok["-L".len..]);
            } else if (mem.eql(u8, tok, "-l")) {
                const lib = it.next() orelse return error.PkgConfigInvalidOutput;
                self.linkSystemLibraryName(lib);
            } else if (mem.startsWith(u8, tok, "-l")) {
                self.linkSystemLibraryName(tok["-l".len..]);
            } else if (mem.eql(u8, tok, "-D")) {
                const macro = it.next() orelse return error.PkgConfigInvalidOutput;
                self.defineCMacro(macro);
            } else if (mem.startsWith(u8, tok, "-D")) {
                self.defineCMacro(tok["-D".len..]);
            } else if (mem.eql(u8, tok, "-pthread")) {
                self.linkLibC();
            } else if (self.builder.verbose) {
                warn("Ignoring pkg-config flag '{}'\n", .{tok});
            }
        }
    }

    pub fn linkSystemLibrary(self: *LibExeObjStep, name: []const u8) void {
        if (isLibCLibrary(name)) {
            self.linkLibC();
            return;
        }
        if (self.linkSystemLibraryPkgConfigOnly(name)) |_| {
            // pkg-config worked, so nothing further needed to do.
            return;
        } else |err| switch (err) {
            error.PkgConfigInvalidOutput,
            error.PkgConfigCrashed,
            error.PkgConfigFailed,
            error.PkgConfigNotInstalled,
            error.PackageNotFound,
            => {},

            else => unreachable,
        }

        self.linkSystemLibraryName(name);
    }

    pub fn setNamePrefix(self: *LibExeObjStep, text: []const u8) void {
        assert(self.kind == Kind.Test);
        self.name_prefix = text;
    }

    pub fn setFilter(self: *LibExeObjStep, text: ?[]const u8) void {
        assert(self.kind == Kind.Test);
        self.filter = text;
    }

    pub fn addCSourceFile(self: *LibExeObjStep, file: []const u8, args: []const []const u8) void {
        self.addCSourceFileSource(.{
            .args = args,
            .source = .{ .path = file },
        });
    }

    pub fn addCSourceFileSource(self: *LibExeObjStep, source: CSourceFile) void {
        const c_source_file = self.builder.allocator.create(CSourceFile) catch unreachable;

        const args_copy = self.builder.allocator.alloc([]u8, source.args.len) catch unreachable;
        for (source.args) |arg, i| {
            args_copy[i] = self.builder.dupe(arg);
        }

        c_source_file.* = source;
        c_source_file.args = args_copy;
        self.link_objects.append(LinkObject{ .CSourceFile = c_source_file }) catch unreachable;
    }

    pub fn setVerboseLink(self: *LibExeObjStep, value: bool) void {
        self.verbose_link = value;
    }

    pub fn setVerboseCC(self: *LibExeObjStep, value: bool) void {
        self.verbose_cc = value;
    }

    pub fn setBuildMode(self: *LibExeObjStep, mode: builtin.Mode) void {
        self.build_mode = mode;
    }

    pub fn overrideZigLibDir(self: *LibExeObjStep, dir_path: []const u8) void {
        self.override_lib_dir = self.builder.dupe(dir_path);
    }

    pub fn setMainPkgPath(self: *LibExeObjStep, dir_path: []const u8) void {
        self.main_pkg_path = dir_path;
    }

    pub const setDisableGenH = @compileError("deprecated; set the emit_h field directly");

    pub fn setLibCFile(self: *LibExeObjStep, libc_file: ?[]const u8) void {
        self.libc_file = libc_file;
    }

    /// Unless setOutputDir was called, this function must be called only in
    /// the make step, from a step that has declared a dependency on this one.
    /// To run an executable built with zig build, use `run`, or create an install step and invoke it.
    pub fn getOutputPath(self: *LibExeObjStep) []const u8 {
        return fs.path.join(
            self.builder.allocator,
            &[_][]const u8{ self.output_dir.?, self.out_filename },
        ) catch unreachable;
    }

    /// Unless setOutputDir was called, this function must be called only in
    /// the make step, from a step that has declared a dependency on this one.
    pub fn getOutputLibPath(self: *LibExeObjStep) []const u8 {
        assert(self.kind == Kind.Lib);
        return fs.path.join(
            self.builder.allocator,
            &[_][]const u8{ self.output_dir.?, self.out_lib_filename },
        ) catch unreachable;
    }

    /// Unless setOutputDir was called, this function must be called only in
    /// the make step, from a step that has declared a dependency on this one.
    pub fn getOutputHPath(self: *LibExeObjStep) []const u8 {
        assert(self.kind != Kind.Exe);
        assert(self.emit_h);
        return fs.path.join(
            self.builder.allocator,
            &[_][]const u8{ self.output_dir.?, self.out_h_filename },
        ) catch unreachable;
    }

    /// Unless setOutputDir was called, this function must be called only in
    /// the make step, from a step that has declared a dependency on this one.
    pub fn getOutputPdbPath(self: *LibExeObjStep) []const u8 {
        assert(self.target.isWindows() or self.target.isUefi());
        return fs.path.join(
            self.builder.allocator,
            &[_][]const u8{ self.output_dir.?, self.out_pdb_filename },
        ) catch unreachable;
    }

    pub fn addAssemblyFile(self: *LibExeObjStep, path: []const u8) void {
        self.link_objects.append(LinkObject{
            .AssemblyFile = .{ .path = self.builder.dupe(path) },
        }) catch unreachable;
    }

    pub fn addAssemblyFileFromWriteFileStep(self: *LibExeObjStep, wfs: *WriteFileStep, basename: []const u8) void {
        self.addAssemblyFileSource(.{
            .write_file = .{
                .step = wfs,
                .basename = self.builder.dupe(basename),
            },
        });
    }

    pub fn addAssemblyFileSource(self: *LibExeObjStep, source: FileSource) void {
        self.link_objects.append(LinkObject{ .AssemblyFile = source }) catch unreachable;
        source.addStepDependencies(&self.step);
    }

    pub fn addObjectFile(self: *LibExeObjStep, path: []const u8) void {
        self.link_objects.append(LinkObject{ .StaticPath = self.builder.dupe(path) }) catch unreachable;
    }

    pub fn addObject(self: *LibExeObjStep, obj: *LibExeObjStep) void {
        assert(obj.kind == Kind.Obj);
        self.linkLibraryOrObject(obj);
    }

    pub fn addBuildOption(self: *LibExeObjStep, comptime T: type, name: []const u8, value: T) void {
        const out = self.build_options_contents.outStream();
        switch (@typeInfo(T)) {
            .Enum => |enum_info| {
                out.print("const {} = enum {{\n", .{@typeName(T)}) catch unreachable;
                inline for (enum_info.fields) |field| {
                    out.print("    {},\n", .{field.name}) catch unreachable;
                }
                out.writeAll("};\n") catch unreachable;
            },
            else => {},
        }
        out.print("pub const {} = {};\n", .{ name, value }) catch unreachable;
    }

    pub fn addSystemIncludeDir(self: *LibExeObjStep, path: []const u8) void {
        self.include_dirs.append(IncludeDir{ .RawPathSystem = self.builder.dupe(path) }) catch unreachable;
    }

    pub fn addIncludeDir(self: *LibExeObjStep, path: []const u8) void {
        self.include_dirs.append(IncludeDir{ .RawPath = self.builder.dupe(path) }) catch unreachable;
    }

    pub fn addLibPath(self: *LibExeObjStep, path: []const u8) void {
        self.lib_paths.append(self.builder.dupe(path)) catch unreachable;
    }

    pub fn addFrameworkDir(self: *LibExeObjStep, dir_path: []const u8) void {
        self.framework_dirs.append(self.builder.dupe(dir_path)) catch unreachable;
    }

    pub fn addPackage(self: *LibExeObjStep, package: Pkg) void {
        self.packages.append(package) catch unreachable;
    }

    pub fn addPackagePath(self: *LibExeObjStep, name: []const u8, pkg_index_path: []const u8) void {
        self.packages.append(Pkg{
            .name = self.builder.dupe(name),
            .path = self.builder.dupe(pkg_index_path),
        }) catch unreachable;
    }

    /// If Vcpkg was found on the system, it will be added to include and lib
    /// paths for the specified target.
    pub fn addVcpkgPaths(self: *LibExeObjStep, linkage: VcpkgLinkage) !void {
        // Ideally in the Unattempted case we would call the function recursively
        // after findVcpkgRoot and have only one switch statement, but the compiler
        // cannot resolve the error set.
        switch (self.builder.vcpkg_root) {
            .Unattempted => {
                self.builder.vcpkg_root = if (try findVcpkgRoot(self.builder.allocator)) |root|
                    VcpkgRoot{ .Found = root }
                else
                    .NotFound;
            },
            .NotFound => return error.VcpkgNotFound,
            .Found => {},
        }

        switch (self.builder.vcpkg_root) {
            .Unattempted => unreachable,
            .NotFound => return error.VcpkgNotFound,
            .Found => |root| {
                const allocator = self.builder.allocator;
                const triplet = try self.target.vcpkgTriplet(allocator, linkage);
                defer self.builder.allocator.free(triplet);

                const include_path = try fs.path.join(allocator, &[_][]const u8{ root, "installed", triplet, "include" });
                errdefer allocator.free(include_path);
                try self.include_dirs.append(IncludeDir{ .RawPath = include_path });

                const lib_path = try fs.path.join(allocator, &[_][]const u8{ root, "installed", triplet, "lib" });
                try self.lib_paths.append(lib_path);

                self.vcpkg_bin_path = try fs.path.join(allocator, &[_][]const u8{ root, "installed", triplet, "bin" });
            },
        }
    }

    pub fn setExecCmd(self: *LibExeObjStep, args: []const ?[]const u8) void {
        assert(self.kind == Kind.Test);
        self.exec_cmd_args = args;
    }

    pub fn enableSystemLinkerHack(self: *LibExeObjStep) void {
        self.system_linker_hack = true;
    }

    fn linkLibraryOrObject(self: *LibExeObjStep, other: *LibExeObjStep) void {
        self.step.dependOn(&other.step);
        self.link_objects.append(LinkObject{ .OtherStep = other }) catch unreachable;
        self.include_dirs.append(IncludeDir{ .OtherStep = other }) catch unreachable;

        // Inherit dependency on system libraries
        for (other.link_objects.span()) |link_object| {
            switch (link_object) {
                .SystemLib => |name| self.linkSystemLibrary(name),
                else => continue,
            }
        }

        // Inherit dependencies on darwin frameworks
        if (self.target.isDarwin() and !other.isDynamicLibrary()) {
            var it = other.frameworks.iterator();
            while (it.next()) |entry| {
                self.frameworks.put(entry.key) catch unreachable;
            }
        }
    }

    fn makePackageCmd(self: *LibExeObjStep, pkg: Pkg, zig_args: *ArrayList([]const u8)) error{OutOfMemory}!void {
        const builder = self.builder;

        try zig_args.append("--pkg-begin");
        try zig_args.append(pkg.name);
        try zig_args.append(builder.pathFromRoot(pkg.path));

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
            warn("{}: linker needs 1 or more objects to link\n", .{self.step.name});
            return error.NeedAnObject;
        }

        var zig_args = ArrayList([]const u8).init(builder.allocator);
        defer zig_args.deinit();

        zig_args.append(builder.zig_exe) catch unreachable;

        const cmd = switch (self.kind) {
            Kind.Lib => "build-lib",
            Kind.Exe => "build-exe",
            Kind.Obj => "build-obj",
            Kind.Test => "test",
        };
        zig_args.append(cmd) catch unreachable;

        if (self.root_src) |root_src| try zig_args.append(root_src.getPath(builder));

        for (self.link_objects.span()) |link_object| {
            switch (link_object) {
                .StaticPath => |static_path| {
                    try zig_args.append("--object");
                    try zig_args.append(builder.pathFromRoot(static_path));
                },

                .OtherStep => |other| switch (other.kind) {
                    .Exe => unreachable,
                    .Test => unreachable,
                    .Obj => {
                        try zig_args.append("--object");
                        try zig_args.append(other.getOutputPath());
                    },
                    .Lib => {
                        if (!other.is_dynamic or self.target.isWindows()) {
                            try zig_args.append("--object");
                            try zig_args.append(other.getOutputLibPath());
                        } else {
                            const full_path_lib = other.getOutputPath();
                            try zig_args.append("--library");
                            try zig_args.append(full_path_lib);

                            if (fs.path.dirname(full_path_lib)) |dirname| {
                                try zig_args.append("-rpath");
                                try zig_args.append(dirname);
                            }
                        }
                    },
                },
                .SystemLib => |name| {
                    try zig_args.append("--library");
                    try zig_args.append(name);
                },
                .AssemblyFile => |asm_file| {
                    try zig_args.append("--c-source");
                    try zig_args.append(asm_file.getPath(builder));
                },
                .CSourceFile => |c_source_file| {
                    try zig_args.append("--c-source");
                    for (c_source_file.args) |arg| {
                        try zig_args.append(arg);
                    }
                    try zig_args.append(c_source_file.source.getPath(builder));
                },
            }
        }

        if (self.build_options_contents.items.len > 0) {
            const build_options_file = try fs.path.join(
                builder.allocator,
                &[_][]const u8{ builder.cache_root, builder.fmt("{}_build_options.zig", .{self.name}) },
            );
            const path_from_root = builder.pathFromRoot(build_options_file);
            try fs.cwd().writeFile(path_from_root, self.build_options_contents.span());
            try zig_args.append("--pkg-begin");
            try zig_args.append("build_options");
            try zig_args.append(path_from_root);
            try zig_args.append("--pkg-end");
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

        if (builder.verbose_tokenize) zig_args.append("--verbose-tokenize") catch unreachable;
        if (builder.verbose_ast) zig_args.append("--verbose-ast") catch unreachable;
        if (builder.verbose_cimport) zig_args.append("--verbose-cimport") catch unreachable;
        if (builder.verbose_ir) zig_args.append("--verbose-ir") catch unreachable;
        if (builder.verbose_llvm_ir) zig_args.append("--verbose-llvm-ir") catch unreachable;
        if (builder.verbose_link or self.verbose_link) zig_args.append("--verbose-link") catch unreachable;
        if (builder.verbose_cc or self.verbose_cc) zig_args.append("--verbose-cc") catch unreachable;
        if (builder.verbose_llvm_cpu_features) zig_args.append("--verbose-llvm-cpu-features") catch unreachable;

        if (self.emit_llvm_ir) try zig_args.append("-femit-llvm-ir");
        if (self.emit_asm) try zig_args.append("-femit-asm");
        if (!self.emit_bin) try zig_args.append("-fno-emit-bin");
        if (self.emit_h) try zig_args.append("-femit-h");

        if (self.strip) {
            try zig_args.append("--strip");
        }
        if (self.link_eh_frame_hdr) {
            try zig_args.append("--eh-frame-hdr");
        }
        if (self.link_function_sections) {
            try zig_args.append("-ffunction-sections");
        }
        if (self.single_threaded) {
            try zig_args.append("--single-threaded");
        }

        if (self.libc_file) |libc_file| {
            try zig_args.append("--libc");
            try zig_args.append(builder.pathFromRoot(libc_file));
        }

        switch (self.build_mode) {
            .Debug => {},
            .ReleaseSafe => zig_args.append("--release-safe") catch unreachable,
            .ReleaseFast => zig_args.append("--release-fast") catch unreachable,
            .ReleaseSmall => zig_args.append("--release-small") catch unreachable,
        }

        try zig_args.append("--cache-dir");
        try zig_args.append(builder.pathFromRoot(builder.cache_root));

        zig_args.append("--name") catch unreachable;
        zig_args.append(self.name) catch unreachable;

        if (self.kind == Kind.Lib and self.is_dynamic) {
            zig_args.append("--ver-major") catch unreachable;
            zig_args.append(builder.fmt("{}", .{self.version.major})) catch unreachable;

            zig_args.append("--ver-minor") catch unreachable;
            zig_args.append(builder.fmt("{}", .{self.version.minor})) catch unreachable;

            zig_args.append("--ver-patch") catch unreachable;
            zig_args.append(builder.fmt("{}", .{self.version.patch})) catch unreachable;
        }
        if (self.is_dynamic) {
            try zig_args.append("-dynamic");
        }
        if (self.bundle_compiler_rt) {
            try zig_args.append("--bundle-compiler-rt");
        }
        if (self.disable_stack_probing) {
            try zig_args.append("-fno-stack-check");
        }
        if (self.disable_sanitize_c) {
            try zig_args.append("-fno-sanitize-c");
        }

        if (self.code_model != .default) {
            try zig_args.append("-code-model");
            try zig_args.append(@tagName(self.code_model));
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
                // If it is the baseline CPU, no command line args are required.
                if (cross.cpu.model != std.Target.Cpu.baseline(cross.cpu.arch).model) {
                    try zig_args.append("-mcpu");
                    try zig_args.append(cross.cpu.model.name);
                }
            } else {
                var mcpu_buffer = std.ArrayList(u8).init(builder.allocator);

                try mcpu_buffer.outStream().print("-mcpu={}", .{cross.cpu.model.name});

                for (all_features) |feature, i_usize| {
                    const i = @intCast(std.Target.Cpu.Feature.Set.Index, i_usize);
                    const in_cpu_set = populated_cpu_features.isEnabled(i);
                    const in_actual_set = cross.cpu.features.isEnabled(i);
                    if (in_cpu_set and !in_actual_set) {
                        try mcpu_buffer.outStream().print("-{}", .{feature.name});
                    } else if (!in_cpu_set and in_actual_set) {
                        try mcpu_buffer.outStream().print("+{}", .{feature.name});
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
            zig_args.append("--linker-script") catch unreachable;
            zig_args.append(builder.pathFromRoot(linker_script)) catch unreachable;
        }

        if (self.version_script) |version_script| {
            try zig_args.append("--version-script");
            try zig_args.append(builder.pathFromRoot(version_script));
        }

        if (self.exec_cmd_args) |exec_cmd_args| {
            for (exec_cmd_args) |cmd_arg| {
                if (cmd_arg) |arg| {
                    try zig_args.append("--test-cmd");
                    try zig_args.append(arg);
                } else {
                    try zig_args.append("--test-cmd-bin");
                }
            }
        } else switch (self.target.getExternalExecutor()) {
            .native, .unavailable => {},
            .qemu => |bin_name| if (self.enable_qemu) qemu: {
                const need_cross_glibc = self.target.isGnuLibC() and self.is_linking_libc;
                const glibc_dir_arg = if (need_cross_glibc)
                    self.glibc_multi_install_dir orelse break :qemu
                else
                    null;
                try zig_args.append("--test-cmd");
                try zig_args.append(bin_name);
                if (glibc_dir_arg) |dir| {
                    const full_dir = try fs.path.join(builder.allocator, &[_][]const u8{
                        dir,
                        try self.target.linuxTriple(builder.allocator),
                    });

                    try zig_args.append("--test-cmd");
                    try zig_args.append("-L");
                    try zig_args.append("--test-cmd");
                    try zig_args.append(full_dir);
                }
                try zig_args.append("--test-cmd-bin");
            },
            .wine => |bin_name| if (self.enable_wine) {
                try zig_args.append("--test-cmd");
                try zig_args.append(bin_name);
                try zig_args.append("--test-cmd-bin");
            },
            .wasmtime => |bin_name| if (self.enable_wasmtime) {
                try zig_args.append("--test-cmd");
                try zig_args.append(bin_name);
                try zig_args.append("--test-cmd");
                try zig_args.append("--dir=.");
                try zig_args.append("--test-cmd-bin");
            },
        }

        for (self.packages.span()) |pkg| {
            try self.makePackageCmd(pkg, &zig_args);
        }

        for (self.include_dirs.span()) |include_dir| {
            switch (include_dir) {
                .RawPath => |include_path| {
                    try zig_args.append("-I");
                    try zig_args.append(self.builder.pathFromRoot(include_path));
                },
                .RawPathSystem => |include_path| {
                    try zig_args.append("-isystem");
                    try zig_args.append(self.builder.pathFromRoot(include_path));
                },
                .OtherStep => |other| if (other.emit_h) {
                    const h_path = other.getOutputHPath();
                    try zig_args.append("-isystem");
                    try zig_args.append(fs.path.dirname(h_path).?);
                },
            }
        }

        for (self.lib_paths.span()) |lib_path| {
            try zig_args.append("-L");
            try zig_args.append(lib_path);
        }

        for (self.c_macros.span()) |c_macro| {
            try zig_args.append("-D");
            try zig_args.append(c_macro);
        }

        if (self.target.isDarwin()) {
            for (self.framework_dirs.span()) |dir| {
                try zig_args.append("-F");
                try zig_args.append(dir);
            }

            var it = self.frameworks.iterator();
            while (it.next()) |entry| {
                zig_args.append("-framework") catch unreachable;
                zig_args.append(entry.key) catch unreachable;
            }
        }

        if (self.system_linker_hack) {
            try zig_args.append("--system-linker-hack");
        }

        if (self.valgrind_support) |valgrind_support| {
            if (valgrind_support) {
                try zig_args.append("--enable-valgrind");
            } else {
                try zig_args.append("--disable-valgrind");
            }
        }

        if (self.override_lib_dir) |dir| {
            try zig_args.append("--override-lib-dir");
            try zig_args.append(builder.pathFromRoot(dir));
        } else if (self.builder.override_lib_dir) |dir| {
            try zig_args.append("--override-lib-dir");
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

        if (self.kind == Kind.Test) {
            try builder.spawnChild(zig_args.span());
        } else {
            try zig_args.append("--cache");
            try zig_args.append("on");

            const output_dir_nl = try builder.execFromStep(zig_args.span(), &self.step);
            const build_output_dir = mem.trimRight(u8, output_dir_nl, "\r\n");

            if (self.output_dir) |output_dir| {
                var src_dir = try std.fs.cwd().openDir(build_output_dir, .{ .iterate = true });
                defer src_dir.close();

                // Create the output directory if it doesn't exist.
                try std.fs.cwd().makePath(output_dir);

                var dest_dir = try std.fs.cwd().openDir(output_dir, .{});
                defer dest_dir.close();

                var it = src_dir.iterate();
                while (try it.next()) |entry| {
                    _ = try src_dir.updateFile(entry.name, dest_dir, entry.name, .{});
                }
            } else {
                self.output_dir = build_output_dir;
            }
        }

        if (self.kind == Kind.Lib and self.is_dynamic and self.target.wantSharedLibSymLinks()) {
            try doAtomicSymLinks(builder.allocator, self.getOutputPath(), self.major_only_filename, self.name_only_filename);
        }
    }
};

pub const InstallArtifactStep = struct {
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
            .step = Step.init(.InstallArtifact, builder.fmt("install {}", .{artifact.step.name}), builder.allocator, make),
            .artifact = artifact,
            .dest_dir = switch (artifact.kind) {
                .Obj => unreachable,
                .Test => unreachable,
                .Exe => .Bin,
                .Lib => .Lib,
            },
            .pdb_dir = if (artifact.producesPdbFile()) blk: {
                if (artifact.kind == .Exe) {
                    break :blk InstallDir.Bin;
                } else {
                    break :blk InstallDir.Lib;
                }
            } else null,
            .h_dir = if (artifact.kind == .Lib and artifact.emit_h) .Header else null,
        };
        self.step.dependOn(&artifact.step);
        artifact.install_step = self;

        builder.pushInstalledFile(self.dest_dir, artifact.out_filename);
        if (self.artifact.isDynamicLibrary()) {
            builder.pushInstalledFile(.Lib, artifact.major_only_filename);
            builder.pushInstalledFile(.Lib, artifact.name_only_filename);
            if (self.artifact.target.isWindows()) {
                builder.pushInstalledFile(.Lib, artifact.out_lib_filename);
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
        try builder.updateFile(self.artifact.getOutputPath(), full_dest_path);
        if (self.artifact.isDynamicLibrary() and self.artifact.target.wantSharedLibSymLinks()) {
            try doAtomicSymLinks(builder.allocator, full_dest_path, self.artifact.major_only_filename, self.artifact.name_only_filename);
        }
        if (self.pdb_dir) |pdb_dir| {
            const full_pdb_path = builder.getInstallPath(pdb_dir, self.artifact.out_pdb_filename);
            try builder.updateFile(self.artifact.getOutputPdbPath(), full_pdb_path);
        }
        if (self.h_dir) |h_dir| {
            const full_pdb_path = builder.getInstallPath(h_dir, self.artifact.out_h_filename);
            try builder.updateFile(self.artifact.getOutputHPath(), full_pdb_path);
        }
        self.artifact.installed_path = full_dest_path;
    }
};

pub const InstallFileStep = struct {
    step: Step,
    builder: *Builder,
    src_path: []const u8,
    dir: InstallDir,
    dest_rel_path: []const u8,

    pub fn init(
        builder: *Builder,
        src_path: []const u8,
        dir: InstallDir,
        dest_rel_path: []const u8,
    ) InstallFileStep {
        builder.pushInstalledFile(dir, dest_rel_path);
        return InstallFileStep{
            .builder = builder,
            .step = Step.init(.InstallFile, builder.fmt("install {}", .{src_path}), builder.allocator, make),
            .src_path = src_path,
            .dir = dir,
            .dest_rel_path = dest_rel_path,
        };
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(InstallFileStep, "step", step);
        const full_dest_path = self.builder.getInstallPath(self.dir, self.dest_rel_path);
        const full_src_path = self.builder.pathFromRoot(self.src_path);
        try self.builder.updateFile(full_src_path, full_dest_path);
    }
};

pub const InstallDirectoryOptions = struct {
    source_dir: []const u8,
    install_dir: InstallDir,
    install_subdir: []const u8,
    exclude_extensions: ?[]const []const u8 = null,
};

pub const InstallDirStep = struct {
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
            .step = Step.init(.InstallDir, builder.fmt("install {}/", .{options.source_dir}), builder.allocator, make),
            .options = options,
        };
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(InstallDirStep, "step", step);
        const dest_prefix = self.builder.getInstallPath(self.options.install_dir, self.options.install_subdir);
        const full_src_dir = self.builder.pathFromRoot(self.options.source_dir);
        var it = try fs.walkPath(self.builder.allocator, full_src_dir);
        next_entry: while (try it.next()) |entry| {
            if (self.options.exclude_extensions) |ext_list| for (ext_list) |ext| {
                if (mem.endsWith(u8, entry.path, ext)) {
                    continue :next_entry;
                }
            };

            const rel_path = entry.path[full_src_dir.len + 1 ..];
            const dest_path = try fs.path.join(self.builder.allocator, &[_][]const u8{ dest_prefix, rel_path });
            switch (entry.kind) {
                .Directory => try fs.cwd().makePath(dest_path),
                .File => try self.builder.updateFile(entry.path, dest_path),
                else => continue,
            }
        }
    }
};

pub const LogStep = struct {
    step: Step,
    builder: *Builder,
    data: []const u8,

    pub fn init(builder: *Builder, data: []const u8) LogStep {
        return LogStep{
            .builder = builder,
            .step = Step.init(.Log, builder.fmt("log {}", .{data}), builder.allocator, make),
            .data = data,
        };
    }

    fn make(step: *Step) anyerror!void {
        const self = @fieldParentPtr(LogStep, "step", step);
        warn("{}", .{self.data});
    }
};

pub const RemoveDirStep = struct {
    step: Step,
    builder: *Builder,
    dir_path: []const u8,

    pub fn init(builder: *Builder, dir_path: []const u8) RemoveDirStep {
        return RemoveDirStep{
            .builder = builder,
            .step = Step.init(.RemoveDir, builder.fmt("RemoveDir {}", .{dir_path}), builder.allocator, make),
            .dir_path = dir_path,
        };
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(RemoveDirStep, "step", step);

        const full_path = self.builder.pathFromRoot(self.dir_path);
        fs.cwd().deleteTree(full_path) catch |err| {
            warn("Unable to remove {}: {}\n", .{ full_path, @errorName(err) });
            return err;
        };
    }
};

const ThisModule = @This();
pub const Step = struct {
    id: Id,
    name: []const u8,
    makeFn: fn (self: *Step) anyerror!void,
    dependencies: ArrayList(*Step),
    loop_flag: bool,
    done_flag: bool,

    pub const Id = enum {
        TopLevel,
        LibExeObj,
        InstallArtifact,
        InstallFile,
        InstallDir,
        Log,
        RemoveDir,
        Fmt,
        TranslateC,
        WriteFile,
        Run,
        CheckFile,
        InstallRaw,
        Custom,
    };

    pub fn init(id: Id, name: []const u8, allocator: *Allocator, makeFn: fn (*Step) anyerror!void) Step {
        return Step{
            .id = id,
            .name = name,
            .makeFn = makeFn,
            .dependencies = ArrayList(*Step).init(allocator),
            .loop_flag = false,
            .done_flag = false,
        };
    }
    pub fn initNoOp(id: Id, name: []const u8, allocator: *Allocator) Step {
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

    fn makeNoOp(self: *Step) anyerror!void {}

    pub fn cast(step: *Step, comptime T: type) ?*T {
        if (step.id == comptime typeToId(T)) {
            return @fieldParentPtr(T, "step", step);
        }
        return null;
    }

    fn typeToId(comptime T: type) Id {
        inline for (@typeInfo(Id).Enum.fields) |f| {
            if (std.mem.eql(u8, f.name, "TopLevel") or
                std.mem.eql(u8, f.name, "Custom")) continue;

            if (T == @field(ThisModule, f.name ++ "Step")) {
                return @field(Id, f.name);
            }
        }
        unreachable;
    }
};

fn doAtomicSymLinks(allocator: *Allocator, output_path: []const u8, filename_major_only: []const u8, filename_name_only: []const u8) !void {
    const out_dir = fs.path.dirname(output_path) orelse ".";
    const out_basename = fs.path.basename(output_path);
    // sym link for libfoo.so.1 to libfoo.so.1.2.3
    const major_only_path = fs.path.join(
        allocator,
        &[_][]const u8{ out_dir, filename_major_only },
    ) catch unreachable;
    fs.atomicSymLink(allocator, out_basename, major_only_path) catch |err| {
        warn("Unable to symlink {} -> {}\n", .{ major_only_path, out_basename });
        return err;
    };
    // sym link for libfoo.so to libfoo.so.1
    const name_only_path = fs.path.join(
        allocator,
        &[_][]const u8{ out_dir, filename_name_only },
    ) catch unreachable;
    fs.atomicSymLink(allocator, filename_major_only, name_only_path) catch |err| {
        warn("Unable to symlink {} -> {}\n", .{ name_only_path, filename_major_only });
        return err;
    };
}

/// Returned slice must be freed by the caller.
fn findVcpkgRoot(allocator: *Allocator) !?[]const u8 {
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
    Unattempted: void,
    NotFound: void,
    Found: []const u8,
};

const VcpkgRootStatus = enum {
    Unattempted,
    NotFound,
    Found,
};

pub const VcpkgLinkage = std.builtin.LinkMode;

pub const InstallDir = enum {
    Prefix,
    Lib,
    Bin,
    Header,
};

pub const InstalledFile = struct {
    dir: InstallDir,
    path: []const u8,
};

test "" {
    // The only purpose of this test is to get all these untested functions
    // to be referenced to avoid regression so it is okay to skip some targets.
    if (comptime std.Target.current.cpu.arch.ptrBitWidth() == 64)
        std.meta.refAllDecls(@This());
}
