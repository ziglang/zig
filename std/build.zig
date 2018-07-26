const std = @import("index.zig");
const builtin = @import("builtin");
const io = std.io;
const mem = std.mem;
const debug = std.debug;
const assert = debug.assert;
const warn = std.debug.warn;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const Allocator = mem.Allocator;
const os = std.os;
const StdIo = os.ChildProcess.StdIo;
const Term = os.ChildProcess.Term;
const BufSet = std.BufSet;
const BufMap = std.BufMap;
const fmt_lib = std.fmt;

pub const Builder = struct {
    uninstall_tls: TopLevelStep,
    install_tls: TopLevelStep,
    have_uninstall_step: bool,
    have_install_step: bool,
    allocator: *Allocator,
    lib_paths: ArrayList([]const u8),
    include_paths: ArrayList([]const u8),
    rpaths: ArrayList([]const u8),
    user_input_options: UserInputOptionsMap,
    available_options_map: AvailableOptionsMap,
    available_options_list: ArrayList(AvailableOption),
    verbose: bool,
    verbose_tokenize: bool,
    verbose_ast: bool,
    verbose_link: bool,
    verbose_ir: bool,
    verbose_llvm_ir: bool,
    verbose_cimport: bool,
    invalid_user_input: bool,
    zig_exe: []const u8,
    default_step: *Step,
    env_map: BufMap,
    top_level_steps: ArrayList(*TopLevelStep),
    prefix: []const u8,
    search_prefixes: ArrayList([]const u8),
    lib_dir: []const u8,
    exe_dir: []const u8,
    installed_files: ArrayList([]const u8),
    build_root: []const u8,
    cache_root: []const u8,
    release_mode: ?builtin.Mode,

    const UserInputOptionsMap = HashMap([]const u8, UserInputOption, mem.hash_slice_u8, mem.eql_slice_u8);
    const AvailableOptionsMap = HashMap([]const u8, AvailableOption, mem.hash_slice_u8, mem.eql_slice_u8);

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
        String,
        List,
    };

    const TopLevelStep = struct {
        step: Step,
        description: []const u8,
    };

    pub fn init(allocator: *Allocator, zig_exe: []const u8, build_root: []const u8, cache_root: []const u8) Builder {
        var self = Builder{
            .zig_exe = zig_exe,
            .build_root = build_root,
            .cache_root = os.path.relative(allocator, build_root, cache_root) catch unreachable,
            .verbose = false,
            .verbose_tokenize = false,
            .verbose_ast = false,
            .verbose_link = false,
            .verbose_ir = false,
            .verbose_llvm_ir = false,
            .verbose_cimport = false,
            .invalid_user_input = false,
            .allocator = allocator,
            .lib_paths = ArrayList([]const u8).init(allocator),
            .include_paths = ArrayList([]const u8).init(allocator),
            .rpaths = ArrayList([]const u8).init(allocator),
            .user_input_options = UserInputOptionsMap.init(allocator),
            .available_options_map = AvailableOptionsMap.init(allocator),
            .available_options_list = ArrayList(AvailableOption).init(allocator),
            .top_level_steps = ArrayList(*TopLevelStep).init(allocator),
            .default_step = undefined,
            .env_map = os.getEnvMap(allocator) catch unreachable,
            .prefix = undefined,
            .search_prefixes = ArrayList([]const u8).init(allocator),
            .lib_dir = undefined,
            .exe_dir = undefined,
            .installed_files = ArrayList([]const u8).init(allocator),
            .uninstall_tls = TopLevelStep{
                .step = Step.init("uninstall", allocator, makeUninstall),
                .description = "Remove build artifacts from prefix path",
            },
            .have_uninstall_step = false,
            .install_tls = TopLevelStep{
                .step = Step.initNoOp("install", allocator),
                .description = "Copy build artifacts to prefix path",
            },
            .have_install_step = false,
            .release_mode = null,
        };
        self.processNixOSEnvVars();
        self.default_step = self.step("default", "Build the project");
        return self;
    }

    pub fn deinit(self: *Builder) void {
        self.lib_paths.deinit();
        self.include_paths.deinit();
        self.rpaths.deinit();
        self.env_map.deinit();
        self.top_level_steps.deinit();
    }

    pub fn setInstallPrefix(self: *Builder, maybe_prefix: ?[]const u8) void {
        self.prefix = maybe_prefix orelse "/usr/local"; // TODO better default
        self.lib_dir = os.path.join(self.allocator, self.prefix, "lib") catch unreachable;
        self.exe_dir = os.path.join(self.allocator, self.prefix, "bin") catch unreachable;
    }

    pub fn addExecutable(self: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        return LibExeObjStep.createExecutable(self, name, root_src);
    }

    pub fn addObject(self: *Builder, name: []const u8, root_src: []const u8) *LibExeObjStep {
        return LibExeObjStep.createObject(self, name, root_src);
    }

    pub fn addSharedLibrary(self: *Builder, name: []const u8, root_src: ?[]const u8, ver: *const Version) *LibExeObjStep {
        return LibExeObjStep.createSharedLibrary(self, name, root_src, ver);
    }

    pub fn addStaticLibrary(self: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        return LibExeObjStep.createStaticLibrary(self, name, root_src);
    }

    pub fn addTest(self: *Builder, root_src: []const u8) *TestStep {
        const test_step = self.allocator.create(TestStep.init(self, root_src)) catch unreachable;
        return test_step;
    }

    pub fn addAssemble(self: *Builder, name: []const u8, src: []const u8) *LibExeObjStep {
        const obj_step = LibExeObjStep.createObject(self, name, null);
        obj_step.addAssemblyFile(src);
        return obj_step;
    }

    pub fn addCStaticLibrary(self: *Builder, name: []const u8) *LibExeObjStep {
        return LibExeObjStep.createCStaticLibrary(self, name);
    }

    pub fn addCSharedLibrary(self: *Builder, name: []const u8, ver: *const Version) *LibExeObjStep {
        return LibExeObjStep.createCSharedLibrary(self, name, ver);
    }

    pub fn addCExecutable(self: *Builder, name: []const u8) *LibExeObjStep {
        return LibExeObjStep.createCExecutable(self, name);
    }

    pub fn addCObject(self: *Builder, name: []const u8, src: []const u8) *LibExeObjStep {
        return LibExeObjStep.createCObject(self, name, src);
    }

    /// ::argv is copied.
    pub fn addCommand(self: *Builder, cwd: ?[]const u8, env_map: *const BufMap, argv: []const []const u8) *CommandStep {
        return CommandStep.create(self, cwd, env_map, argv);
    }

    pub fn addWriteFile(self: *Builder, file_path: []const u8, data: []const u8) *WriteFileStep {
        const write_file_step = self.allocator.create(WriteFileStep.init(self, file_path, data)) catch unreachable;
        return write_file_step;
    }

    pub fn addLog(self: *Builder, comptime format: []const u8, args: ...) *LogStep {
        const data = self.fmt(format, args);
        const log_step = self.allocator.create(LogStep.init(self, data)) catch unreachable;
        return log_step;
    }

    pub fn addRemoveDirTree(self: *Builder, dir_path: []const u8) *RemoveDirStep {
        const remove_dir_step = self.allocator.create(RemoveDirStep.init(self, dir_path)) catch unreachable;
        return remove_dir_step;
    }

    pub fn version(self: *const Builder, major: u32, minor: u32, patch: u32) Version {
        return Version{
            .major = major,
            .minor = minor,
            .patch = patch,
        };
    }

    pub fn addCIncludePath(self: *Builder, path: []const u8) void {
        self.include_paths.append(path) catch unreachable;
    }

    pub fn addRPath(self: *Builder, path: []const u8) void {
        self.rpaths.append(path) catch unreachable;
    }

    pub fn addLibPath(self: *Builder, path: []const u8) void {
        self.lib_paths.append(path) catch unreachable;
    }

    pub fn make(self: *Builder, step_names: []const []const u8) !void {
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

        for (wanted_steps.toSliceConst()) |s| {
            try self.makeOneStep(s);
        }
    }

    pub fn getInstallStep(self: *Builder) *Step {
        if (self.have_install_step) return &self.install_tls.step;

        self.top_level_steps.append(&self.install_tls) catch unreachable;
        self.have_install_step = true;
        return &self.install_tls.step;
    }

    pub fn getUninstallStep(self: *Builder) *Step {
        if (self.have_uninstall_step) return &self.uninstall_tls.step;

        self.top_level_steps.append(&self.uninstall_tls) catch unreachable;
        self.have_uninstall_step = true;
        return &self.uninstall_tls.step;
    }

    fn makeUninstall(uninstall_step: *Step) error!void {
        const uninstall_tls = @fieldParentPtr(TopLevelStep, "step", uninstall_step);
        const self = @fieldParentPtr(Builder, "uninstall_tls", uninstall_tls);

        for (self.installed_files.toSliceConst()) |installed_file| {
            if (self.verbose) {
                warn("rm {}\n", installed_file);
            }
            _ = os.deleteFile(self.allocator, installed_file);
        }

        // TODO remove empty directories
    }

    fn makeOneStep(self: *Builder, s: *Step) error!void {
        if (s.loop_flag) {
            warn("Dependency loop detected:\n  {}\n", s.name);
            return error.DependencyLoopDetected;
        }
        s.loop_flag = true;

        for (s.dependencies.toSlice()) |dep| {
            self.makeOneStep(dep) catch |err| {
                if (err == error.DependencyLoopDetected) {
                    warn("  {}\n", s.name);
                }
                return err;
            };
        }

        s.loop_flag = false;

        try s.make();
    }

    fn getTopLevelStepByName(self: *Builder, name: []const u8) !*Step {
        for (self.top_level_steps.toSliceConst()) |top_level_step| {
            if (mem.eql(u8, top_level_step.step.name, name)) {
                return &top_level_step.step;
            }
        }
        warn("Cannot run step '{}' because it does not exist\n", name);
        return error.InvalidStepName;
    }

    fn processNixOSEnvVars(self: *Builder) void {
        if (os.getEnvVarOwned(self.allocator, "NIX_CFLAGS_COMPILE")) |nix_cflags_compile| {
            var it = mem.split(nix_cflags_compile, " ");
            while (true) {
                const word = it.next() orelse break;
                if (mem.eql(u8, word, "-isystem")) {
                    const include_path = it.next() orelse {
                        warn("Expected argument after -isystem in NIX_CFLAGS_COMPILE\n");
                        break;
                    };
                    self.addCIncludePath(include_path);
                } else {
                    warn("Unrecognized C flag from NIX_CFLAGS_COMPILE: {}\n", word);
                    break;
                }
            }
        } else |err| {
            assert(err == error.EnvironmentVariableNotFound);
        }
        if (os.getEnvVarOwned(self.allocator, "NIX_LDFLAGS")) |nix_ldflags| {
            var it = mem.split(nix_ldflags, " ");
            while (true) {
                const word = it.next() orelse break;
                if (mem.eql(u8, word, "-rpath")) {
                    const rpath = it.next() orelse {
                        warn("Expected argument after -rpath in NIX_LDFLAGS\n");
                        break;
                    };
                    self.addRPath(rpath);
                } else if (word.len > 2 and word[0] == '-' and word[1] == 'L') {
                    const lib_path = word[2..];
                    self.addLibPath(lib_path);
                } else {
                    warn("Unrecognized C flag from NIX_LDFLAGS: {}\n", word);
                    break;
                }
            }
        } else |err| {
            assert(err == error.EnvironmentVariableNotFound);
        }
    }

    pub fn option(self: *Builder, comptime T: type, name: []const u8, description: []const u8) ?T {
        const type_id = comptime typeToEnum(T);
        const available_option = AvailableOption{
            .name = name,
            .type_id = type_id,
            .description = description,
        };
        if ((self.available_options_map.put(name, available_option) catch unreachable) != null) {
            debug.panic("Option '{}' declared twice", name);
        }
        self.available_options_list.append(available_option) catch unreachable;

        const entry = self.user_input_options.get(name) orelse return null;
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
                        warn("Expected -D{} to be a boolean, but received '{}'\n", name, s);
                        self.markInvalidUserInput();
                        return null;
                    }
                },
                UserValue.List => {
                    warn("Expected -D{} to be a boolean, but received a list.\n", name);
                    self.markInvalidUserInput();
                    return null;
                },
            },
            TypeId.Int => debug.panic("TODO integer options to build script"),
            TypeId.Float => debug.panic("TODO float options to build script"),
            TypeId.String => switch (entry.value.value) {
                UserValue.Flag => {
                    warn("Expected -D{} to be a string, but received a boolean.\n", name);
                    self.markInvalidUserInput();
                    return null;
                },
                UserValue.List => {
                    warn("Expected -D{} to be a string, but received a list.\n", name);
                    self.markInvalidUserInput();
                    return null;
                },
                UserValue.Scalar => |s| return s,
            },
            TypeId.List => debug.panic("TODO list options to build script"),
        }
    }

    pub fn step(self: *Builder, name: []const u8, description: []const u8) *Step {
        const step_info = self.allocator.create(TopLevelStep{
            .step = Step.initNoOp(name, self.allocator),
            .description = description,
        }) catch unreachable;
        self.top_level_steps.append(step_info) catch unreachable;
        return &step_info.step;
    }

    pub fn standardReleaseOptions(self: *Builder) builtin.Mode {
        if (self.release_mode) |mode| return mode;

        const release_safe = self.option(bool, "release-safe", "optimizations on and safety on") orelse false;
        const release_fast = self.option(bool, "release-fast", "optimizations on and safety off") orelse false;
        const release_small = self.option(bool, "release-small", "size optimizations on and safety off") orelse false;

        const mode = if (release_safe and !release_fast and !release_small) builtin.Mode.ReleaseSafe else if (release_fast and !release_safe and !release_small) builtin.Mode.ReleaseFast else if (release_small and !release_fast and !release_safe) builtin.Mode.ReleaseSmall else if (!release_fast and !release_safe and !release_small) builtin.Mode.Debug else x: {
            warn("Multiple release modes (of -Drelease-safe, -Drelease-fast and -Drelease-small)");
            self.markInvalidUserInput();
            break :x builtin.Mode.Debug;
        };
        self.release_mode = mode;
        return mode;
    }

    pub fn addUserInputOption(self: *Builder, name: []const u8, value: []const u8) bool {
        if (self.user_input_options.put(name, UserInputOption{
            .name = name,
            .value = UserValue{ .Scalar = value },
            .used = false,
        }) catch unreachable) |*prev_value| {
            // option already exists
            switch (prev_value.value) {
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
                    warn("Option '-D{}={}' conflicts with flag '-D{}'.\n", name, value, name);
                    return true;
                },
            }
        }
        return false;
    }

    pub fn addUserInputFlag(self: *Builder, name: []const u8) bool {
        if (self.user_input_options.put(name, UserInputOption{
            .name = name,
            .value = UserValue{ .Flag = {} },
            .used = false,
        }) catch unreachable) |*prev_value| {
            switch (prev_value.value) {
                UserValue.Scalar => |s| {
                    warn("Flag '-D{}' conflicts with option '-D{}={}'.\n", name, name, s);
                    return true;
                },
                UserValue.List => {
                    warn("Flag '-D{}' conflicts with multiple options of the same name.\n", name);
                    return true;
                },
                UserValue.Flag => {},
            }
        }
        return false;
    }

    fn typeToEnum(comptime T: type) TypeId {
        return switch (@typeId(T)) {
            builtin.TypeId.Int => TypeId.Int,
            builtin.TypeId.Float => TypeId.Float,
            builtin.TypeId.Bool => TypeId.Bool,
            else => switch (T) {
                []const u8 => TypeId.String,
                []const []const u8 => TypeId.List,
                else => @compileError("Unsupported type: " ++ @typeName(T)),
            },
        };
    }

    fn markInvalidUserInput(self: *Builder) void {
        self.invalid_user_input = true;
    }

    pub fn typeIdName(id: TypeId) []const u8 {
        return switch (id) {
            TypeId.Bool => "bool",
            TypeId.Int => "int",
            TypeId.Float => "float",
            TypeId.String => "string",
            TypeId.List => "list",
        };
    }

    pub fn validateUserInputDidItFail(self: *Builder) bool {
        // make sure all args are used
        var it = self.user_input_options.iterator();
        while (true) {
            const entry = it.next() orelse break;
            if (!entry.value.used) {
                warn("Invalid option: -D{}\n\n", entry.key);
                self.markInvalidUserInput();
            }
        }

        return self.invalid_user_input;
    }

    fn spawnChild(self: *Builder, argv: []const []const u8) !void {
        return self.spawnChildEnvMap(null, &self.env_map, argv);
    }

    fn printCmd(cwd: ?[]const u8, argv: []const []const u8) void {
        if (cwd) |yes_cwd| warn("cd {} && ", yes_cwd);
        for (argv) |arg| {
            warn("{} ", arg);
        }
        warn("\n");
    }

    fn spawnChildEnvMap(self: *Builder, cwd: ?[]const u8, env_map: *const BufMap, argv: []const []const u8) !void {
        if (self.verbose) {
            printCmd(cwd, argv);
        }

        const child = os.ChildProcess.init(argv, self.allocator) catch unreachable;
        defer child.deinit();

        child.cwd = cwd;
        child.env_map = env_map;

        const term = child.spawnAndWait() catch |err| {
            warn("Unable to spawn {}: {}\n", argv[0], @errorName(err));
            return err;
        };

        switch (term) {
            Term.Exited => |code| {
                if (code != 0) {
                    warn("The following command exited with error code {}:\n", code);
                    printCmd(cwd, argv);
                    return error.UncleanExit;
                }
            },
            else => {
                warn("The following command terminated unexpectedly:\n");
                printCmd(cwd, argv);

                return error.UncleanExit;
            },
        }
    }

    pub fn makePath(self: *Builder, path: []const u8) !void {
        os.makePath(self.allocator, self.pathFromRoot(path)) catch |err| {
            warn("Unable to create path {}: {}\n", path, @errorName(err));
            return err;
        };
    }

    pub fn installArtifact(self: *Builder, artifact: *LibExeObjStep) void {
        self.getInstallStep().dependOn(&self.addInstallArtifact(artifact).step);
    }

    pub fn addInstallArtifact(self: *Builder, artifact: *LibExeObjStep) *InstallArtifactStep {
        return InstallArtifactStep.create(self, artifact);
    }

    ///::dest_rel_path is relative to prefix path or it can be an absolute path
    pub fn installFile(self: *Builder, src_path: []const u8, dest_rel_path: []const u8) void {
        self.getInstallStep().dependOn(&self.addInstallFile(src_path, dest_rel_path).step);
    }

    ///::dest_rel_path is relative to prefix path or it can be an absolute path
    pub fn addInstallFile(self: *Builder, src_path: []const u8, dest_rel_path: []const u8) *InstallFileStep {
        const full_dest_path = os.path.resolve(self.allocator, self.prefix, dest_rel_path) catch unreachable;
        self.pushInstalledFile(full_dest_path);

        const install_step = self.allocator.create(InstallFileStep.init(self, src_path, full_dest_path)) catch unreachable;
        return install_step;
    }

    pub fn pushInstalledFile(self: *Builder, full_path: []const u8) void {
        _ = self.getUninstallStep();
        self.installed_files.append(full_path) catch unreachable;
    }

    fn copyFile(self: *Builder, source_path: []const u8, dest_path: []const u8) !void {
        return self.copyFileMode(source_path, dest_path, os.File.default_mode);
    }

    fn copyFileMode(self: *Builder, source_path: []const u8, dest_path: []const u8, mode: os.File.Mode) !void {
        if (self.verbose) {
            warn("cp {} {}\n", source_path, dest_path);
        }

        const dirname = os.path.dirname(dest_path) orelse ".";
        const abs_source_path = self.pathFromRoot(source_path);
        os.makePath(self.allocator, dirname) catch |err| {
            warn("Unable to create path {}: {}\n", dirname, @errorName(err));
            return err;
        };
        os.copyFileMode(self.allocator, abs_source_path, dest_path, mode) catch |err| {
            warn("Unable to copy {} to {}: {}\n", abs_source_path, dest_path, @errorName(err));
            return err;
        };
    }

    fn pathFromRoot(self: *Builder, rel_path: []const u8) []u8 {
        return os.path.resolve(self.allocator, self.build_root, rel_path) catch unreachable;
    }

    pub fn fmt(self: *Builder, comptime format: []const u8, args: ...) []u8 {
        return fmt_lib.allocPrint(self.allocator, format, args) catch unreachable;
    }

    fn getCCExe(self: *Builder) []const u8 {
        if (builtin.environ == builtin.Environ.msvc) {
            return "cl.exe";
        } else {
            return os.getEnvVarOwned(self.allocator, "CC") catch |err| if (err == error.EnvironmentVariableNotFound) ([]const u8)("cc") else debug.panic("Unable to get environment variable: {}", err);
        }
    }

    pub fn findProgram(self: *Builder, names: []const []const u8, paths: []const []const u8) ![]const u8 {
        // TODO report error for ambiguous situations
        const exe_extension = (Target{ .Native = {} }).exeFileExt();
        for (self.search_prefixes.toSliceConst()) |search_prefix| {
            for (names) |name| {
                if (os.path.isAbsolute(name)) {
                    return name;
                }
                const full_path = try os.path.join(self.allocator, search_prefix, "bin", self.fmt("{}{}", name, exe_extension));
                if (os.path.real(self.allocator, full_path)) |real_path| {
                    return real_path;
                } else |_| {
                    continue;
                }
            }
        }
        if (self.env_map.get("PATH")) |PATH| {
            for (names) |name| {
                if (os.path.isAbsolute(name)) {
                    return name;
                }
                var it = mem.split(PATH, []u8{os.path.delimiter});
                while (it.next()) |path| {
                    const full_path = try os.path.join(self.allocator, path, self.fmt("{}{}", name, exe_extension));
                    if (os.path.real(self.allocator, full_path)) |real_path| {
                        return real_path;
                    } else |_| {
                        continue;
                    }
                }
            }
        }
        for (names) |name| {
            if (os.path.isAbsolute(name)) {
                return name;
            }
            for (paths) |path| {
                const full_path = try os.path.join(self.allocator, path, self.fmt("{}{}", name, exe_extension));
                if (os.path.real(self.allocator, full_path)) |real_path| {
                    return real_path;
                } else |_| {
                    continue;
                }
            }
        }
        return error.FileNotFound;
    }

    pub fn exec(self: *Builder, argv: []const []const u8) ![]u8 {
        const max_output_size = 100 * 1024;
        const result = try os.ChildProcess.exec(self.allocator, argv, null, null, max_output_size);
        switch (result.term) {
            os.ChildProcess.Term.Exited => |code| {
                if (code != 0) {
                    warn("The following command exited with error code {}:\n", code);
                    printCmd(null, argv);
                    warn("stderr:{}\n", result.stderr);
                    std.debug.panic("command failed");
                }
                return result.stdout;
            },
            else => {
                warn("The following command terminated unexpectedly:\n");
                printCmd(null, argv);
                warn("stderr:{}\n", result.stderr);
                std.debug.panic("command failed");
            },
        }
    }

    pub fn addSearchPrefix(self: *Builder, search_prefix: []const u8) void {
        self.search_prefixes.append(search_prefix) catch unreachable;
    }
};

const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,
};

const CrossTarget = struct {
    arch: builtin.Arch,
    os: builtin.Os,
    environ: builtin.Environ,
};

pub const Target = union(enum) {
    Native: void,
    Cross: CrossTarget,

    pub fn oFileExt(self: *const Target) []const u8 {
        const environ = switch (self.*) {
            Target.Native => builtin.environ,
            Target.Cross => |t| t.environ,
        };
        return switch (environ) {
            builtin.Environ.msvc => ".obj",
            else => ".o",
        };
    }

    pub fn exeFileExt(self: *const Target) []const u8 {
        return switch (self.getOs()) {
            builtin.Os.windows => ".exe",
            else => "",
        };
    }

    pub fn libFileExt(self: *const Target) []const u8 {
        return switch (self.getOs()) {
            builtin.Os.windows => ".lib",
            else => ".a",
        };
    }

    pub fn getOs(self: *const Target) builtin.Os {
        return switch (self.*) {
            Target.Native => builtin.os,
            Target.Cross => |t| t.os,
        };
    }

    pub fn isDarwin(self: *const Target) bool {
        return switch (self.getOs()) {
            builtin.Os.ios, builtin.Os.macosx => true,
            else => false,
        };
    }

    pub fn isWindows(self: *const Target) bool {
        return switch (self.getOs()) {
            builtin.Os.windows => true,
            else => false,
        };
    }

    pub fn wantSharedLibSymLinks(self: *const Target) bool {
        return !self.isWindows();
    }
};

pub const LibExeObjStep = struct {
    step: Step,
    builder: *Builder,
    name: []const u8,
    target: Target,
    link_libs: BufSet,
    linker_script: ?[]const u8,
    out_filename: []const u8,
    output_path: ?[]const u8,
    static: bool,
    version: Version,
    object_files: ArrayList([]const u8),
    build_mode: builtin.Mode,
    kind: Kind,
    major_only_filename: []const u8,
    name_only_filename: []const u8,
    strip: bool,
    full_path_libs: ArrayList([]const u8),
    need_flat_namespace_hack: bool,
    is_zig: bool,
    cflags: ArrayList([]const u8),
    include_dirs: ArrayList([]const u8),
    lib_paths: ArrayList([]const u8),
    disable_libc: bool,
    frameworks: BufSet,
    verbose_link: bool,
    no_rosegment: bool,

    // zig only stuff
    root_src: ?[]const u8,
    output_h_path: ?[]const u8,
    out_h_filename: []const u8,
    assembly_files: ArrayList([]const u8),
    packages: ArrayList(Pkg),
    build_options_contents: std.Buffer,

    // C only stuff
    source_files: ArrayList([]const u8),
    object_src: []const u8,

    const Pkg = struct {
        name: []const u8,
        path: []const u8,
    };

    const Kind = enum {
        Exe,
        Lib,
        Obj,
    };

    pub fn createSharedLibrary(builder: *Builder, name: []const u8, root_src: ?[]const u8, ver: *const Version) *LibExeObjStep {
        const self = builder.allocator.create(initExtraArgs(builder, name, root_src, Kind.Lib, false, ver)) catch unreachable;
        return self;
    }

    pub fn createCSharedLibrary(builder: *Builder, name: []const u8, version: *const Version) *LibExeObjStep {
        const self = builder.allocator.create(initC(builder, name, Kind.Lib, version, false)) catch unreachable;
        return self;
    }

    pub fn createStaticLibrary(builder: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        const self = builder.allocator.create(initExtraArgs(builder, name, root_src, Kind.Lib, true, builder.version(0, 0, 0))) catch unreachable;
        return self;
    }

    pub fn createCStaticLibrary(builder: *Builder, name: []const u8) *LibExeObjStep {
        const self = builder.allocator.create(initC(builder, name, Kind.Lib, builder.version(0, 0, 0), true)) catch unreachable;
        return self;
    }

    pub fn createObject(builder: *Builder, name: []const u8, root_src: []const u8) *LibExeObjStep {
        const self = builder.allocator.create(initExtraArgs(builder, name, root_src, Kind.Obj, false, builder.version(0, 0, 0))) catch unreachable;
        return self;
    }

    pub fn createCObject(builder: *Builder, name: []const u8, src: []const u8) *LibExeObjStep {
        const self = builder.allocator.create(initC(builder, name, Kind.Obj, builder.version(0, 0, 0), false)) catch unreachable;
        self.object_src = src;
        return self;
    }

    pub fn createExecutable(builder: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        const self = builder.allocator.create(initExtraArgs(builder, name, root_src, Kind.Exe, false, builder.version(0, 0, 0))) catch unreachable;
        return self;
    }

    pub fn createCExecutable(builder: *Builder, name: []const u8) *LibExeObjStep {
        const self = builder.allocator.create(initC(builder, name, Kind.Exe, builder.version(0, 0, 0), false)) catch unreachable;
        return self;
    }

    fn initExtraArgs(builder: *Builder, name: []const u8, root_src: ?[]const u8, kind: Kind, static: bool, ver: *const Version) LibExeObjStep {
        var self = LibExeObjStep{
            .no_rosegment = false,
            .strip = false,
            .builder = builder,
            .verbose_link = false,
            .build_mode = builtin.Mode.Debug,
            .static = static,
            .kind = kind,
            .root_src = root_src,
            .name = name,
            .target = Target.Native,
            .linker_script = null,
            .link_libs = BufSet.init(builder.allocator),
            .frameworks = BufSet.init(builder.allocator),
            .step = Step.init(name, builder.allocator, make),
            .output_path = null,
            .output_h_path = null,
            .version = ver.*,
            .out_filename = undefined,
            .out_h_filename = builder.fmt("{}.h", name),
            .major_only_filename = undefined,
            .name_only_filename = undefined,
            .object_files = ArrayList([]const u8).init(builder.allocator),
            .assembly_files = ArrayList([]const u8).init(builder.allocator),
            .packages = ArrayList(Pkg).init(builder.allocator),
            .is_zig = true,
            .full_path_libs = ArrayList([]const u8).init(builder.allocator),
            .need_flat_namespace_hack = false,
            .cflags = ArrayList([]const u8).init(builder.allocator),
            .source_files = undefined,
            .include_dirs = ArrayList([]const u8).init(builder.allocator),
            .lib_paths = ArrayList([]const u8).init(builder.allocator),
            .object_src = undefined,
            .disable_libc = true,
            .build_options_contents = std.Buffer.initSize(builder.allocator, 0) catch unreachable,
        };
        self.computeOutFileNames();
        return self;
    }

    fn initC(builder: *Builder, name: []const u8, kind: Kind, version: *const Version, static: bool) LibExeObjStep {
        var self = LibExeObjStep{
            .no_rosegment = false,
            .builder = builder,
            .name = name,
            .kind = kind,
            .version = version.*,
            .static = static,
            .target = Target.Native,
            .cflags = ArrayList([]const u8).init(builder.allocator),
            .source_files = ArrayList([]const u8).init(builder.allocator),
            .object_files = ArrayList([]const u8).init(builder.allocator),
            .step = Step.init(name, builder.allocator, make),
            .link_libs = BufSet.init(builder.allocator),
            .frameworks = BufSet.init(builder.allocator),
            .full_path_libs = ArrayList([]const u8).init(builder.allocator),
            .include_dirs = ArrayList([]const u8).init(builder.allocator),
            .lib_paths = ArrayList([]const u8).init(builder.allocator),
            .output_path = null,
            .out_filename = undefined,
            .major_only_filename = undefined,
            .name_only_filename = undefined,
            .object_src = undefined,
            .build_mode = builtin.Mode.Debug,
            .strip = false,
            .need_flat_namespace_hack = false,
            .disable_libc = false,
            .is_zig = false,
            .linker_script = null,

            .root_src = undefined,
            .verbose_link = false,
            .output_h_path = undefined,
            .out_h_filename = undefined,
            .assembly_files = undefined,
            .packages = undefined,
            .build_options_contents = undefined,
        };
        self.computeOutFileNames();
        return self;
    }

    pub fn setNoRoSegment(self: *LibExeObjStep, value: bool) void {
        self.no_rosegment = value;
    }

    fn computeOutFileNames(self: *LibExeObjStep) void {
        switch (self.kind) {
            Kind.Obj => {
                self.out_filename = self.builder.fmt("{}{}", self.name, self.target.oFileExt());
            },
            Kind.Exe => {
                self.out_filename = self.builder.fmt("{}{}", self.name, self.target.exeFileExt());
            },
            Kind.Lib => {
                if (self.static) {
                    self.out_filename = self.builder.fmt("lib{}.a", self.name);
                } else {
                    switch (self.target.getOs()) {
                        builtin.Os.ios, builtin.Os.macosx => {
                            self.out_filename = self.builder.fmt("lib{}.{d}.{d}.{d}.dylib", self.name, self.version.major, self.version.minor, self.version.patch);
                            self.major_only_filename = self.builder.fmt("lib{}.{d}.dylib", self.name, self.version.major);
                            self.name_only_filename = self.builder.fmt("lib{}.dylib", self.name);
                        },
                        builtin.Os.windows => {
                            self.out_filename = self.builder.fmt("{}.dll", self.name);
                        },
                        else => {
                            self.out_filename = self.builder.fmt("lib{}.so.{d}.{d}.{d}", self.name, self.version.major, self.version.minor, self.version.patch);
                            self.major_only_filename = self.builder.fmt("lib{}.so.{d}", self.name, self.version.major);
                            self.name_only_filename = self.builder.fmt("lib{}.so", self.name);
                        },
                    }
                }
            },
        }
    }

    pub fn setTarget(self: *LibExeObjStep, target_arch: builtin.Arch, target_os: builtin.Os, target_environ: builtin.Environ) void {
        self.target = Target{
            .Cross = CrossTarget{
                .arch = target_arch,
                .os = target_os,
                .environ = target_environ,
            },
        };
        self.computeOutFileNames();
    }

    // TODO respect this in the C args
    pub fn setLinkerScriptPath(self: *LibExeObjStep, path: []const u8) void {
        self.linker_script = path;
    }

    pub fn linkFramework(self: *LibExeObjStep, framework_name: []const u8) void {
        assert(self.target.isDarwin());
        self.frameworks.put(framework_name) catch unreachable;
    }

    pub fn linkLibrary(self: *LibExeObjStep, lib: *LibExeObjStep) void {
        assert(self.kind != Kind.Obj);
        assert(lib.kind == Kind.Lib);

        self.step.dependOn(&lib.step);

        self.full_path_libs.append(lib.getOutputPath()) catch unreachable;

        // TODO should be some kind of isolated directory that only has this header in it
        self.include_dirs.append(self.builder.cache_root) catch unreachable;
        self.need_flat_namespace_hack = true;

        // inherit the object's frameworks
        if (self.target.isDarwin() and lib.static) {
            var it = lib.frameworks.iterator();
            while (it.next()) |entry| {
                self.frameworks.put(entry.key) catch unreachable;
            }
        }
    }

    pub fn linkSystemLibrary(self: *LibExeObjStep, name: []const u8) void {
        assert(self.kind != Kind.Obj);
        self.link_libs.put(name) catch unreachable;
    }

    pub fn addSourceFile(self: *LibExeObjStep, file: []const u8) void {
        assert(self.kind != Kind.Obj);
        assert(!self.is_zig);
        self.source_files.append(file) catch unreachable;
    }

    pub fn setVerboseLink(self: *LibExeObjStep, value: bool) void {
        self.verbose_link = value;
    }

    pub fn setBuildMode(self: *LibExeObjStep, mode: builtin.Mode) void {
        self.build_mode = mode;
    }

    pub fn setOutputPath(self: *LibExeObjStep, file_path: []const u8) void {
        self.output_path = file_path;

        // catch a common mistake
        if (mem.eql(u8, self.builder.pathFromRoot(file_path), self.builder.pathFromRoot("."))) {
            debug.panic("setOutputPath wants a file path, not a directory\n");
        }
    }

    pub fn getOutputPath(self: *LibExeObjStep) []const u8 {
        return if (self.output_path) |output_path| output_path else os.path.join(self.builder.allocator, self.builder.cache_root, self.out_filename) catch unreachable;
    }

    pub fn setOutputHPath(self: *LibExeObjStep, file_path: []const u8) void {
        self.output_h_path = file_path;

        // catch a common mistake
        if (mem.eql(u8, self.builder.pathFromRoot(file_path), self.builder.pathFromRoot("."))) {
            debug.panic("setOutputHPath wants a file path, not a directory\n");
        }
    }

    pub fn getOutputHPath(self: *LibExeObjStep) []const u8 {
        return if (self.output_h_path) |output_h_path| output_h_path else os.path.join(self.builder.allocator, self.builder.cache_root, self.out_h_filename) catch unreachable;
    }

    pub fn addAssemblyFile(self: *LibExeObjStep, path: []const u8) void {
        self.assembly_files.append(path) catch unreachable;
    }

    pub fn addObjectFile(self: *LibExeObjStep, path: []const u8) void {
        assert(self.kind != Kind.Obj);

        self.object_files.append(path) catch unreachable;
    }

    pub fn addObject(self: *LibExeObjStep, obj: *LibExeObjStep) void {
        assert(obj.kind == Kind.Obj);
        assert(self.kind != Kind.Obj);

        self.step.dependOn(&obj.step);

        self.object_files.append(obj.getOutputPath()) catch unreachable;

        // TODO make this lazy instead of stateful
        if (!obj.disable_libc) {
            self.disable_libc = false;
        }

        // TODO should be some kind of isolated directory that only has this header in it
        self.include_dirs.append(self.builder.cache_root) catch unreachable;
    }

    pub fn addBuildOption(self: *LibExeObjStep, comptime T: type, name: []const u8, value: T) void {
        assert(self.is_zig);
        const out = &std.io.BufferOutStream.init(&self.build_options_contents).stream;
        out.print("pub const {} = {};\n", name, value) catch unreachable;
    }

    pub fn addIncludeDir(self: *LibExeObjStep, path: []const u8) void {
        self.include_dirs.append(path) catch unreachable;
    }

    pub fn addLibPath(self: *LibExeObjStep, path: []const u8) void {
        self.lib_paths.append(path) catch unreachable;
    }

    pub fn addPackagePath(self: *LibExeObjStep, name: []const u8, pkg_index_path: []const u8) void {
        assert(self.is_zig);

        self.packages.append(Pkg{
            .name = name,
            .path = pkg_index_path,
        }) catch unreachable;
    }

    pub fn addCompileFlags(self: *LibExeObjStep, flags: []const []const u8) void {
        for (flags) |flag| {
            self.cflags.append(flag) catch unreachable;
        }
    }

    pub fn setNoStdLib(self: *LibExeObjStep, disable: bool) void {
        assert(!self.is_zig);
        self.disable_libc = disable;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(LibExeObjStep, "step", step);
        return if (self.is_zig) self.makeZig() else self.makeC();
    }

    fn makeZig(self: *LibExeObjStep) !void {
        const builder = self.builder;

        assert(self.is_zig);

        if (self.root_src == null and self.object_files.len == 0 and self.assembly_files.len == 0) {
            warn("{}: linker needs 1 or more objects to link\n", self.step.name);
            return error.NeedAnObject;
        }

        var zig_args = ArrayList([]const u8).init(builder.allocator);
        defer zig_args.deinit();

        zig_args.append(builder.zig_exe) catch unreachable;

        const cmd = switch (self.kind) {
            Kind.Lib => "build-lib",
            Kind.Exe => "build-exe",
            Kind.Obj => "build-obj",
        };
        zig_args.append(cmd) catch unreachable;

        if (self.root_src) |root_src| {
            zig_args.append(builder.pathFromRoot(root_src)) catch unreachable;
        }

        if (self.build_options_contents.len() > 0) {
            const build_options_file = try os.path.join(builder.allocator, builder.cache_root, builder.fmt("{}_build_options.zig", self.name));
            try std.io.writeFile(builder.allocator, build_options_file, self.build_options_contents.toSliceConst());
            try zig_args.append("--pkg-begin");
            try zig_args.append("build_options");
            try zig_args.append(builder.pathFromRoot(build_options_file));
            try zig_args.append("--pkg-end");
        }

        for (self.object_files.toSliceConst()) |object_file| {
            zig_args.append("--object") catch unreachable;
            zig_args.append(builder.pathFromRoot(object_file)) catch unreachable;
        }

        for (self.assembly_files.toSliceConst()) |asm_file| {
            zig_args.append("--assembly") catch unreachable;
            zig_args.append(builder.pathFromRoot(asm_file)) catch unreachable;
        }

        if (builder.verbose_tokenize) zig_args.append("--verbose-tokenize") catch unreachable;
        if (builder.verbose_ast) zig_args.append("--verbose-ast") catch unreachable;
        if (builder.verbose_cimport) zig_args.append("--verbose-cimport") catch unreachable;
        if (builder.verbose_ir) zig_args.append("--verbose-ir") catch unreachable;
        if (builder.verbose_llvm_ir) zig_args.append("--verbose-llvm-ir") catch unreachable;
        if (builder.verbose_link or self.verbose_link) zig_args.append("--verbose-link") catch unreachable;

        if (self.strip) {
            zig_args.append("--strip") catch unreachable;
        }

        switch (self.build_mode) {
            builtin.Mode.Debug => {},
            builtin.Mode.ReleaseSafe => zig_args.append("--release-safe") catch unreachable,
            builtin.Mode.ReleaseFast => zig_args.append("--release-fast") catch unreachable,
            builtin.Mode.ReleaseSmall => zig_args.append("--release-small") catch unreachable,
        }

        zig_args.append("--cache-dir") catch unreachable;
        zig_args.append(builder.pathFromRoot(builder.cache_root)) catch unreachable;

        const output_path = builder.pathFromRoot(self.getOutputPath());
        zig_args.append("--output") catch unreachable;
        zig_args.append(output_path) catch unreachable;

        if (self.kind != Kind.Exe) {
            const output_h_path = self.getOutputHPath();
            zig_args.append("--output-h") catch unreachable;
            zig_args.append(builder.pathFromRoot(output_h_path)) catch unreachable;
        }

        zig_args.append("--name") catch unreachable;
        zig_args.append(self.name) catch unreachable;

        if (self.kind == Kind.Lib and !self.static) {
            zig_args.append("--ver-major") catch unreachable;
            zig_args.append(builder.fmt("{}", self.version.major)) catch unreachable;

            zig_args.append("--ver-minor") catch unreachable;
            zig_args.append(builder.fmt("{}", self.version.minor)) catch unreachable;

            zig_args.append("--ver-patch") catch unreachable;
            zig_args.append(builder.fmt("{}", self.version.patch)) catch unreachable;
        }

        switch (self.target) {
            Target.Native => {},
            Target.Cross => |cross_target| {
                zig_args.append("--target-arch") catch unreachable;
                zig_args.append(@tagName(cross_target.arch)) catch unreachable;

                zig_args.append("--target-os") catch unreachable;
                zig_args.append(@tagName(cross_target.os)) catch unreachable;

                zig_args.append("--target-environ") catch unreachable;
                zig_args.append(@tagName(cross_target.environ)) catch unreachable;
            },
        }

        if (self.linker_script) |linker_script| {
            zig_args.append("--linker-script") catch unreachable;
            zig_args.append(linker_script) catch unreachable;
        }

        {
            var it = self.link_libs.iterator();
            while (true) {
                const entry = it.next() orelse break;
                zig_args.append("--library") catch unreachable;
                zig_args.append(entry.key) catch unreachable;
            }
        }

        if (!self.disable_libc) {
            zig_args.append("--library") catch unreachable;
            zig_args.append("c") catch unreachable;
        }

        for (self.packages.toSliceConst()) |pkg| {
            zig_args.append("--pkg-begin") catch unreachable;
            zig_args.append(pkg.name) catch unreachable;
            zig_args.append(builder.pathFromRoot(pkg.path)) catch unreachable;
            zig_args.append("--pkg-end") catch unreachable;
        }

        for (self.include_dirs.toSliceConst()) |include_path| {
            zig_args.append("-isystem") catch unreachable;
            zig_args.append(self.builder.pathFromRoot(include_path)) catch unreachable;
        }

        for (builder.include_paths.toSliceConst()) |include_path| {
            zig_args.append("-isystem") catch unreachable;
            zig_args.append(builder.pathFromRoot(include_path)) catch unreachable;
        }

        for (builder.rpaths.toSliceConst()) |rpath| {
            zig_args.append("-rpath") catch unreachable;
            zig_args.append(rpath) catch unreachable;
        }

        for (self.lib_paths.toSliceConst()) |lib_path| {
            zig_args.append("--library-path") catch unreachable;
            zig_args.append(lib_path) catch unreachable;
        }

        for (builder.lib_paths.toSliceConst()) |lib_path| {
            zig_args.append("--library-path") catch unreachable;
            zig_args.append(lib_path) catch unreachable;
        }

        for (self.full_path_libs.toSliceConst()) |full_path_lib| {
            zig_args.append("--library") catch unreachable;
            zig_args.append(builder.pathFromRoot(full_path_lib)) catch unreachable;
        }

        if (self.target.isDarwin()) {
            var it = self.frameworks.iterator();
            while (it.next()) |entry| {
                zig_args.append("-framework") catch unreachable;
                zig_args.append(entry.key) catch unreachable;
            }
        }

        if (self.no_rosegment) {
            try zig_args.append("--no-rosegment");
        }

        try builder.spawnChild(zig_args.toSliceConst());

        if (self.kind == Kind.Lib and !self.static and self.target.wantSharedLibSymLinks()) {
            try doAtomicSymLinks(builder.allocator, output_path, self.major_only_filename, self.name_only_filename);
        }
    }

    fn appendCompileFlags(self: *LibExeObjStep, args: *ArrayList([]const u8)) void {
        if (!self.strip) {
            args.append("-g") catch unreachable;
        }
        switch (self.build_mode) {
            builtin.Mode.Debug => {
                if (self.disable_libc) {
                    args.append("-fno-stack-protector") catch unreachable;
                } else {
                    args.append("-fstack-protector-strong") catch unreachable;
                    args.append("--param") catch unreachable;
                    args.append("ssp-buffer-size=4") catch unreachable;
                }
            },
            builtin.Mode.ReleaseSafe => {
                args.append("-O2") catch unreachable;
                if (self.disable_libc) {
                    args.append("-fno-stack-protector") catch unreachable;
                } else {
                    args.append("-D_FORTIFY_SOURCE=2") catch unreachable;
                    args.append("-fstack-protector-strong") catch unreachable;
                    args.append("--param") catch unreachable;
                    args.append("ssp-buffer-size=4") catch unreachable;
                }
            },
            builtin.Mode.ReleaseFast, builtin.Mode.ReleaseSmall => {
                args.append("-O2") catch unreachable;
                args.append("-fno-stack-protector") catch unreachable;
            },
        }

        for (self.include_dirs.toSliceConst()) |dir| {
            args.append("-I") catch unreachable;
            args.append(self.builder.pathFromRoot(dir)) catch unreachable;
        }

        for (self.cflags.toSliceConst()) |cflag| {
            args.append(cflag) catch unreachable;
        }

        if (self.disable_libc) {
            args.append("-nostdlib") catch unreachable;
        }
    }

    fn makeC(self: *LibExeObjStep) !void {
        const builder = self.builder;

        const cc = builder.getCCExe();

        assert(!self.is_zig);

        var cc_args = ArrayList([]const u8).init(builder.allocator);
        defer cc_args.deinit();

        cc_args.append(cc) catch unreachable;

        const is_darwin = self.target.isDarwin();

        switch (self.kind) {
            Kind.Obj => {
                cc_args.append("-c") catch unreachable;
                cc_args.append(builder.pathFromRoot(self.object_src)) catch unreachable;

                const output_path = builder.pathFromRoot(self.getOutputPath());
                cc_args.append("-o") catch unreachable;
                cc_args.append(output_path) catch unreachable;

                self.appendCompileFlags(&cc_args);

                try builder.spawnChild(cc_args.toSliceConst());
            },
            Kind.Lib => {
                for (self.source_files.toSliceConst()) |source_file| {
                    cc_args.resize(0) catch unreachable;
                    cc_args.append(cc) catch unreachable;

                    if (!self.static) {
                        cc_args.append("-fPIC") catch unreachable;
                    }

                    const abs_source_file = builder.pathFromRoot(source_file);
                    cc_args.append("-c") catch unreachable;
                    cc_args.append(abs_source_file) catch unreachable;

                    const cache_o_src = os.path.join(builder.allocator, builder.cache_root, source_file) catch unreachable;
                    if (os.path.dirname(cache_o_src)) |cache_o_dir| {
                        try builder.makePath(cache_o_dir);
                    }
                    const cache_o_file = builder.fmt("{}{}", cache_o_src, self.target.oFileExt());
                    cc_args.append("-o") catch unreachable;
                    cc_args.append(builder.pathFromRoot(cache_o_file)) catch unreachable;

                    self.appendCompileFlags(&cc_args);

                    try builder.spawnChild(cc_args.toSliceConst());

                    self.object_files.append(cache_o_file) catch unreachable;
                }

                if (self.static) {
                    // ar
                    cc_args.resize(0) catch unreachable;
                    cc_args.append("ar") catch unreachable;

                    cc_args.append("qc") catch unreachable;

                    const output_path = builder.pathFromRoot(self.getOutputPath());
                    cc_args.append(output_path) catch unreachable;

                    for (self.object_files.toSliceConst()) |object_file| {
                        cc_args.append(builder.pathFromRoot(object_file)) catch unreachable;
                    }

                    try builder.spawnChild(cc_args.toSliceConst());

                    // ranlib
                    cc_args.resize(0) catch unreachable;
                    cc_args.append("ranlib") catch unreachable;
                    cc_args.append(output_path) catch unreachable;

                    try builder.spawnChild(cc_args.toSliceConst());
                } else {
                    cc_args.resize(0) catch unreachable;
                    cc_args.append(cc) catch unreachable;

                    if (is_darwin) {
                        cc_args.append("-dynamiclib") catch unreachable;

                        cc_args.append("-Wl,-headerpad_max_install_names") catch unreachable;

                        cc_args.append("-compatibility_version") catch unreachable;
                        cc_args.append(builder.fmt("{}.0.0", self.version.major)) catch unreachable;

                        cc_args.append("-current_version") catch unreachable;
                        cc_args.append(builder.fmt("{}.{}.{}", self.version.major, self.version.minor, self.version.patch)) catch unreachable;

                        const install_name = builder.pathFromRoot(os.path.join(builder.allocator, builder.cache_root, self.major_only_filename) catch unreachable);
                        cc_args.append("-install_name") catch unreachable;
                        cc_args.append(install_name) catch unreachable;
                    } else {
                        cc_args.append("-fPIC") catch unreachable;
                        cc_args.append("-shared") catch unreachable;

                        const soname_arg = builder.fmt("-Wl,-soname,lib{}.so.{d}", self.name, self.version.major);
                        defer builder.allocator.free(soname_arg);
                        cc_args.append(soname_arg) catch unreachable;
                    }

                    const output_path = builder.pathFromRoot(self.getOutputPath());
                    cc_args.append("-o") catch unreachable;
                    cc_args.append(output_path) catch unreachable;

                    for (self.object_files.toSliceConst()) |object_file| {
                        cc_args.append(builder.pathFromRoot(object_file)) catch unreachable;
                    }

                    if (!is_darwin) {
                        const rpath_arg = builder.fmt("-Wl,-rpath,{}", os.path.real(builder.allocator, builder.pathFromRoot(builder.cache_root)) catch unreachable);
                        defer builder.allocator.free(rpath_arg);
                        cc_args.append(rpath_arg) catch unreachable;

                        cc_args.append("-rdynamic") catch unreachable;
                    }

                    for (self.full_path_libs.toSliceConst()) |full_path_lib| {
                        cc_args.append(builder.pathFromRoot(full_path_lib)) catch unreachable;
                    }

                    {
                        var it = self.link_libs.iterator();
                        while (it.next()) |entry| {
                            cc_args.append(builder.fmt("-l{}", entry.key)) catch unreachable;
                        }
                    }

                    if (is_darwin and !self.static) {
                        var it = self.frameworks.iterator();
                        while (it.next()) |entry| {
                            cc_args.append("-framework") catch unreachable;
                            cc_args.append(entry.key) catch unreachable;
                        }
                    }

                    try builder.spawnChild(cc_args.toSliceConst());

                    if (self.target.wantSharedLibSymLinks()) {
                        try doAtomicSymLinks(builder.allocator, output_path, self.major_only_filename, self.name_only_filename);
                    }
                }
            },
            Kind.Exe => {
                for (self.source_files.toSliceConst()) |source_file| {
                    cc_args.resize(0) catch unreachable;
                    cc_args.append(cc) catch unreachable;

                    const abs_source_file = builder.pathFromRoot(source_file);
                    cc_args.append("-c") catch unreachable;
                    cc_args.append(abs_source_file) catch unreachable;

                    const cache_o_src = os.path.join(builder.allocator, builder.cache_root, source_file) catch unreachable;
                    if (os.path.dirname(cache_o_src)) |cache_o_dir| {
                        try builder.makePath(cache_o_dir);
                    }
                    const cache_o_file = builder.fmt("{}{}", cache_o_src, self.target.oFileExt());
                    cc_args.append("-o") catch unreachable;
                    cc_args.append(builder.pathFromRoot(cache_o_file)) catch unreachable;

                    for (self.cflags.toSliceConst()) |cflag| {
                        cc_args.append(cflag) catch unreachable;
                    }

                    for (self.include_dirs.toSliceConst()) |dir| {
                        cc_args.append("-I") catch unreachable;
                        cc_args.append(builder.pathFromRoot(dir)) catch unreachable;
                    }

                    try builder.spawnChild(cc_args.toSliceConst());

                    self.object_files.append(cache_o_file) catch unreachable;
                }

                cc_args.resize(0) catch unreachable;
                cc_args.append(cc) catch unreachable;

                for (self.object_files.toSliceConst()) |object_file| {
                    cc_args.append(builder.pathFromRoot(object_file)) catch unreachable;
                }

                const output_path = builder.pathFromRoot(self.getOutputPath());
                cc_args.append("-o") catch unreachable;
                cc_args.append(output_path) catch unreachable;

                const rpath_arg = builder.fmt("-Wl,-rpath,{}", os.path.real(builder.allocator, builder.pathFromRoot(builder.cache_root)) catch unreachable);
                defer builder.allocator.free(rpath_arg);
                cc_args.append(rpath_arg) catch unreachable;

                cc_args.append("-rdynamic") catch unreachable;

                {
                    var it = self.link_libs.iterator();
                    while (it.next()) |entry| {
                        cc_args.append(builder.fmt("-l{}", entry.key)) catch unreachable;
                    }
                }

                if (is_darwin) {
                    if (self.need_flat_namespace_hack) {
                        cc_args.append("-Wl,-flat_namespace") catch unreachable;
                    }
                    cc_args.append("-Wl,-search_paths_first") catch unreachable;
                }

                for (self.full_path_libs.toSliceConst()) |full_path_lib| {
                    cc_args.append(builder.pathFromRoot(full_path_lib)) catch unreachable;
                }

                if (is_darwin) {
                    var it = self.frameworks.iterator();
                    while (it.next()) |entry| {
                        cc_args.append("-framework") catch unreachable;
                        cc_args.append(entry.key) catch unreachable;
                    }
                }

                try builder.spawnChild(cc_args.toSliceConst());
            },
        }
    }
};

pub const TestStep = struct {
    step: Step,
    builder: *Builder,
    root_src: []const u8,
    build_mode: builtin.Mode,
    verbose: bool,
    link_libs: BufSet,
    name_prefix: []const u8,
    filter: ?[]const u8,
    target: Target,
    exec_cmd_args: ?[]const ?[]const u8,
    include_dirs: ArrayList([]const u8),
    lib_paths: ArrayList([]const u8),
    object_files: ArrayList([]const u8),
    no_rosegment: bool,

    pub fn init(builder: *Builder, root_src: []const u8) TestStep {
        const step_name = builder.fmt("test {}", root_src);
        return TestStep{
            .step = Step.init(step_name, builder.allocator, make),
            .builder = builder,
            .root_src = root_src,
            .build_mode = builtin.Mode.Debug,
            .verbose = false,
            .name_prefix = "",
            .filter = null,
            .link_libs = BufSet.init(builder.allocator),
            .target = Target{ .Native = {} },
            .exec_cmd_args = null,
            .include_dirs = ArrayList([]const u8).init(builder.allocator),
            .lib_paths = ArrayList([]const u8).init(builder.allocator),
            .object_files = ArrayList([]const u8).init(builder.allocator),
            .no_rosegment = false,
        };
    }

    pub fn setNoRoSegment(self: *TestStep, value: bool) void {
        self.no_rosegment = value;
    }

    pub fn addLibPath(self: *TestStep, path: []const u8) void {
        self.lib_paths.append(path) catch unreachable;
    }

    pub fn setVerbose(self: *TestStep, value: bool) void {
        self.verbose = value;
    }

    pub fn addIncludeDir(self: *TestStep, path: []const u8) void {
        self.include_dirs.append(path) catch unreachable;
    }

    pub fn setBuildMode(self: *TestStep, mode: builtin.Mode) void {
        self.build_mode = mode;
    }

    pub fn linkSystemLibrary(self: *TestStep, name: []const u8) void {
        self.link_libs.put(name) catch unreachable;
    }

    pub fn setNamePrefix(self: *TestStep, text: []const u8) void {
        self.name_prefix = text;
    }

    pub fn setFilter(self: *TestStep, text: ?[]const u8) void {
        self.filter = text;
    }

    pub fn addObjectFile(self: *TestStep, path: []const u8) void {
        self.object_files.append(path) catch unreachable;
    }

    pub fn setTarget(self: *TestStep, target_arch: builtin.Arch, target_os: builtin.Os, target_environ: builtin.Environ) void {
        self.target = Target{
            .Cross = CrossTarget{
                .arch = target_arch,
                .os = target_os,
                .environ = target_environ,
            },
        };
    }

    pub fn setExecCmd(self: *TestStep, args: []const ?[]const u8) void {
        self.exec_cmd_args = args;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(TestStep, "step", step);
        const builder = self.builder;

        var zig_args = ArrayList([]const u8).init(builder.allocator);
        defer zig_args.deinit();

        try zig_args.append(builder.zig_exe);

        try zig_args.append("test");
        try zig_args.append(builder.pathFromRoot(self.root_src));

        if (self.verbose) {
            try zig_args.append("--verbose");
        }

        switch (self.build_mode) {
            builtin.Mode.Debug => {},
            builtin.Mode.ReleaseSafe => try zig_args.append("--release-safe"),
            builtin.Mode.ReleaseFast => try zig_args.append("--release-fast"),
            builtin.Mode.ReleaseSmall => try zig_args.append("--release-small"),
        }

        switch (self.target) {
            Target.Native => {},
            Target.Cross => |cross_target| {
                try zig_args.append("--target-arch");
                try zig_args.append(@tagName(cross_target.arch));

                try zig_args.append("--target-os");
                try zig_args.append(@tagName(cross_target.os));

                try zig_args.append("--target-environ");
                try zig_args.append(@tagName(cross_target.environ));
            },
        }

        if (self.filter) |filter| {
            try zig_args.append("--test-filter");
            try zig_args.append(filter);
        }

        if (self.name_prefix.len != 0) {
            try zig_args.append("--test-name-prefix");
            try zig_args.append(self.name_prefix);
        }

        for (self.object_files.toSliceConst()) |object_file| {
            try zig_args.append("--object");
            try zig_args.append(builder.pathFromRoot(object_file));
        }

        {
            var it = self.link_libs.iterator();
            while (true) {
                const entry = it.next() orelse break;
                try zig_args.append("--library");
                try zig_args.append(entry.key);
            }
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
        }

        for (self.include_dirs.toSliceConst()) |include_path| {
            try zig_args.append("-isystem");
            try zig_args.append(builder.pathFromRoot(include_path));
        }

        for (builder.include_paths.toSliceConst()) |include_path| {
            try zig_args.append("-isystem");
            try zig_args.append(builder.pathFromRoot(include_path));
        }

        for (builder.rpaths.toSliceConst()) |rpath| {
            try zig_args.append("-rpath");
            try zig_args.append(rpath);
        }

        for (self.lib_paths.toSliceConst()) |lib_path| {
            try zig_args.append("--library-path");
            try zig_args.append(lib_path);
        }

        for (builder.lib_paths.toSliceConst()) |lib_path| {
            try zig_args.append("--library-path");
            try zig_args.append(lib_path);
        }

        if (self.no_rosegment) {
            try zig_args.append("--no-rosegment");
        }

        try builder.spawnChild(zig_args.toSliceConst());
    }
};

pub const CommandStep = struct {
    step: Step,
    builder: *Builder,
    argv: [][]const u8,
    cwd: ?[]const u8,
    env_map: *const BufMap,

    /// ::argv is copied.
    pub fn create(builder: *Builder, cwd: ?[]const u8, env_map: *const BufMap, argv: []const []const u8) *CommandStep {
        const self = builder.allocator.create(CommandStep{
            .builder = builder,
            .step = Step.init(argv[0], builder.allocator, make),
            .argv = builder.allocator.alloc([]u8, argv.len) catch unreachable,
            .cwd = cwd,
            .env_map = env_map,
        }) catch unreachable;

        mem.copy([]const u8, self.argv, argv);
        self.step.name = self.argv[0];
        return self;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(CommandStep, "step", step);

        const cwd = if (self.cwd) |cwd| self.builder.pathFromRoot(cwd) else self.builder.build_root;
        return self.builder.spawnChildEnvMap(cwd, self.env_map, self.argv);
    }
};

const InstallArtifactStep = struct {
    step: Step,
    builder: *Builder,
    artifact: *LibExeObjStep,
    dest_file: []const u8,

    const Self = this;

    pub fn create(builder: *Builder, artifact: *LibExeObjStep) *Self {
        const dest_dir = switch (artifact.kind) {
            LibExeObjStep.Kind.Obj => unreachable,
            LibExeObjStep.Kind.Exe => builder.exe_dir,
            LibExeObjStep.Kind.Lib => builder.lib_dir,
        };
        const self = builder.allocator.create(Self{
            .builder = builder,
            .step = Step.init(builder.fmt("install {}", artifact.step.name), builder.allocator, make),
            .artifact = artifact,
            .dest_file = os.path.join(builder.allocator, dest_dir, artifact.out_filename) catch unreachable,
        }) catch unreachable;
        self.step.dependOn(&artifact.step);
        builder.pushInstalledFile(self.dest_file);
        if (self.artifact.kind == LibExeObjStep.Kind.Lib and !self.artifact.static) {
            builder.pushInstalledFile(os.path.join(builder.allocator, builder.lib_dir, artifact.major_only_filename) catch unreachable);
            builder.pushInstalledFile(os.path.join(builder.allocator, builder.lib_dir, artifact.name_only_filename) catch unreachable);
        }
        return self;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(Self, "step", step);
        const builder = self.builder;

        const mode = switch (builtin.os) {
            builtin.Os.windows => {},
            else => switch (self.artifact.kind) {
                LibExeObjStep.Kind.Obj => unreachable,
                LibExeObjStep.Kind.Exe => u32(0o755),
                LibExeObjStep.Kind.Lib => if (self.artifact.static) u32(0o666) else u32(0o755),
            },
        };
        try builder.copyFileMode(self.artifact.getOutputPath(), self.dest_file, mode);
        if (self.artifact.kind == LibExeObjStep.Kind.Lib and !self.artifact.static) {
            try doAtomicSymLinks(builder.allocator, self.dest_file, self.artifact.major_only_filename, self.artifact.name_only_filename);
        }
    }
};

pub const InstallFileStep = struct {
    step: Step,
    builder: *Builder,
    src_path: []const u8,
    dest_path: []const u8,

    pub fn init(builder: *Builder, src_path: []const u8, dest_path: []const u8) InstallFileStep {
        return InstallFileStep{
            .builder = builder,
            .step = Step.init(builder.fmt("install {}", src_path), builder.allocator, make),
            .src_path = src_path,
            .dest_path = dest_path,
        };
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(InstallFileStep, "step", step);
        try self.builder.copyFile(self.src_path, self.dest_path);
    }
};

pub const WriteFileStep = struct {
    step: Step,
    builder: *Builder,
    file_path: []const u8,
    data: []const u8,

    pub fn init(builder: *Builder, file_path: []const u8, data: []const u8) WriteFileStep {
        return WriteFileStep{
            .builder = builder,
            .step = Step.init(builder.fmt("writefile {}", file_path), builder.allocator, make),
            .file_path = file_path,
            .data = data,
        };
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(WriteFileStep, "step", step);
        const full_path = self.builder.pathFromRoot(self.file_path);
        const full_path_dir = os.path.dirname(full_path) orelse ".";
        os.makePath(self.builder.allocator, full_path_dir) catch |err| {
            warn("unable to make path {}: {}\n", full_path_dir, @errorName(err));
            return err;
        };
        io.writeFile(self.builder.allocator, full_path, self.data) catch |err| {
            warn("unable to write {}: {}\n", full_path, @errorName(err));
            return err;
        };
    }
};

pub const LogStep = struct {
    step: Step,
    builder: *Builder,
    data: []const u8,

    pub fn init(builder: *Builder, data: []const u8) LogStep {
        return LogStep{
            .builder = builder,
            .step = Step.init(builder.fmt("log {}", data), builder.allocator, make),
            .data = data,
        };
    }

    fn make(step: *Step) error!void {
        const self = @fieldParentPtr(LogStep, "step", step);
        warn("{}", self.data);
    }
};

pub const RemoveDirStep = struct {
    step: Step,
    builder: *Builder,
    dir_path: []const u8,

    pub fn init(builder: *Builder, dir_path: []const u8) RemoveDirStep {
        return RemoveDirStep{
            .builder = builder,
            .step = Step.init(builder.fmt("RemoveDir {}", dir_path), builder.allocator, make),
            .dir_path = dir_path,
        };
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(RemoveDirStep, "step", step);

        const full_path = self.builder.pathFromRoot(self.dir_path);
        os.deleteTree(self.builder.allocator, full_path) catch |err| {
            warn("Unable to remove {}: {}\n", full_path, @errorName(err));
            return err;
        };
    }
};

pub const Step = struct {
    name: []const u8,
    makeFn: fn (self: *Step) error!void,
    dependencies: ArrayList(*Step),
    loop_flag: bool,
    done_flag: bool,

    pub fn init(name: []const u8, allocator: *Allocator, makeFn: fn (*Step) error!void) Step {
        return Step{
            .name = name,
            .makeFn = makeFn,
            .dependencies = ArrayList(*Step).init(allocator),
            .loop_flag = false,
            .done_flag = false,
        };
    }
    pub fn initNoOp(name: []const u8, allocator: *Allocator) Step {
        return init(name, allocator, makeNoOp);
    }

    pub fn make(self: *Step) !void {
        if (self.done_flag) return;

        try self.makeFn(self);
        self.done_flag = true;
    }

    pub fn dependOn(self: *Step, other: *Step) void {
        self.dependencies.append(other) catch unreachable;
    }

    fn makeNoOp(self: *Step) error!void {}
};

fn doAtomicSymLinks(allocator: *Allocator, output_path: []const u8, filename_major_only: []const u8, filename_name_only: []const u8) !void {
    const out_dir = os.path.dirname(output_path) orelse ".";
    const out_basename = os.path.basename(output_path);
    // sym link for libfoo.so.1 to libfoo.so.1.2.3
    const major_only_path = os.path.join(allocator, out_dir, filename_major_only) catch unreachable;
    os.atomicSymLink(allocator, out_basename, major_only_path) catch |err| {
        warn("Unable to symlink {} -> {}\n", major_only_path, out_basename);
        return err;
    };
    // sym link for libfoo.so to libfoo.so.1
    const name_only_path = os.path.join(allocator, out_dir, filename_name_only) catch unreachable;
    os.atomicSymLink(allocator, filename_major_only, name_only_path) catch |err| {
        warn("Unable to symlink {} -> {}\n", name_only_path, filename_major_only);
        return err;
    };
}
