const std = @import("std.zig");
const builtin = @import("builtin");
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const debug = std.debug;
const assert = debug.assert;
const warn = std.debug.warn;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const Allocator = mem.Allocator;
const process = std.process;
const BufSet = std.BufSet;
const BufMap = std.BufMap;
const fmt_lib = std.fmt;
const File = std.fs.File;

pub const FmtStep = @import("build/fmt.zig").FmtStep;

pub const Builder = struct {
    uninstall_tls: TopLevelStep,
    install_tls: TopLevelStep,
    have_uninstall_step: bool,
    have_install_step: bool,
    allocator: *Allocator,
    native_system_lib_paths: ArrayList([]const u8),
    native_system_include_dirs: ArrayList([]const u8),
    native_system_rpaths: ArrayList([]const u8),
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
    invalid_user_input: bool,
    zig_exe: []const u8,
    default_step: *Step,
    env_map: *BufMap,
    top_level_steps: ArrayList(*TopLevelStep),
    prefix: []const u8,
    search_prefixes: ArrayList([]const u8),
    lib_dir: []const u8,
    exe_dir: []const u8,
    installed_files: ArrayList([]const u8),
    build_root: []const u8,
    cache_root: []const u8,
    release_mode: ?builtin.Mode,
    override_std_dir: ?[]const u8,
    override_lib_dir: ?[]const u8,

    pub const CStd = enum {
        C89,
        C99,
        C11,
    };

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
        const env_map = allocator.create(BufMap) catch unreachable;
        env_map.* = process.getEnvMap(allocator) catch unreachable;
        var self = Builder{
            .zig_exe = zig_exe,
            .build_root = build_root,
            .cache_root = fs.path.relative(allocator, build_root, cache_root) catch unreachable,
            .verbose = false,
            .verbose_tokenize = false,
            .verbose_ast = false,
            .verbose_link = false,
            .verbose_cc = false,
            .verbose_ir = false,
            .verbose_llvm_ir = false,
            .verbose_cimport = false,
            .invalid_user_input = false,
            .allocator = allocator,
            .native_system_lib_paths = ArrayList([]const u8).init(allocator),
            .native_system_include_dirs = ArrayList([]const u8).init(allocator),
            .native_system_rpaths = ArrayList([]const u8).init(allocator),
            .user_input_options = UserInputOptionsMap.init(allocator),
            .available_options_map = AvailableOptionsMap.init(allocator),
            .available_options_list = ArrayList(AvailableOption).init(allocator),
            .top_level_steps = ArrayList(*TopLevelStep).init(allocator),
            .default_step = undefined,
            .env_map = env_map,
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
            .override_std_dir = null,
            .override_lib_dir = null,
        };
        self.detectNativeSystemPaths();
        self.default_step = self.step("default", "Build the project");
        return self;
    }

    pub fn deinit(self: *Builder) void {
        self.native_system_lib_paths.deinit();
        self.native_system_include_dirs.deinit();
        self.native_system_rpaths.deinit();
        self.env_map.deinit();
        self.top_level_steps.deinit();
    }

    pub fn setInstallPrefix(self: *Builder, maybe_prefix: ?[]const u8) void {
        self.prefix = maybe_prefix orelse "/usr/local"; // TODO better default
        self.lib_dir = fs.path.join(self.allocator, [][]const u8{ self.prefix, "lib" }) catch unreachable;
        self.exe_dir = fs.path.join(self.allocator, [][]const u8{ self.prefix, "bin" }) catch unreachable;
    }

    pub fn addExecutable(self: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        return LibExeObjStep.createExecutable(self, name, root_src, false);
    }

    pub fn addObject(self: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        return LibExeObjStep.createObject(self, name, root_src);
    }

    pub fn addSharedLibrary(self: *Builder, name: []const u8, root_src: ?[]const u8, ver: Version) *LibExeObjStep {
        return LibExeObjStep.createSharedLibrary(self, name, root_src, ver);
    }

    pub fn addStaticLibrary(self: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        return LibExeObjStep.createStaticLibrary(self, name, root_src);
    }

    pub fn addTest(self: *Builder, root_src: []const u8) *LibExeObjStep {
        return LibExeObjStep.createTest(self, "test", root_src);
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
        const run_step = RunStep.create(self, self.fmt("run {}", argv[0]));
        run_step.addArgs(argv);
        return run_step;
    }

    fn dupe(self: *Builder, bytes: []const u8) []u8 {
        return mem.dupe(self.allocator, u8, bytes) catch unreachable;
    }

    pub fn addWriteFile(self: *Builder, file_path: []const u8, data: []const u8) *WriteFileStep {
        const write_file_step = self.allocator.create(WriteFileStep) catch unreachable;
        write_file_step.* = WriteFileStep.init(self, file_path, data);
        return write_file_step;
    }

    pub fn addLog(self: *Builder, comptime format: []const u8, args: ...) *LogStep {
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

    pub fn version(self: *const Builder, major: u32, minor: u32, patch: u32) Version {
        return Version{
            .major = major,
            .minor = minor,
            .patch = patch,
        };
    }

    pub fn addNativeSystemIncludeDir(self: *Builder, path: []const u8) void {
        self.native_system_include_dirs.append(path) catch unreachable;
    }

    pub fn addNativeSystemRPath(self: *Builder, path: []const u8) void {
        self.native_system_rpaths.append(path) catch unreachable;
    }

    pub fn addNativeSystemLibPath(self: *Builder, path: []const u8) void {
        self.native_system_lib_paths.append(path) catch unreachable;
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

    fn makeUninstall(uninstall_step: *Step) anyerror!void {
        const uninstall_tls = @fieldParentPtr(TopLevelStep, "step", uninstall_step);
        const self = @fieldParentPtr(Builder, "uninstall_tls", uninstall_tls);

        for (self.installed_files.toSliceConst()) |installed_file| {
            if (self.verbose) {
                warn("rm {}\n", installed_file);
            }
            fs.deleteFile(installed_file) catch {};
        }

        // TODO remove empty directories
    }

    fn makeOneStep(self: *Builder, s: *Step) anyerror!void {
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

    fn detectNativeSystemPaths(self: *Builder) void {
        var is_nixos = false;
        if (process.getEnvVarOwned(self.allocator, "NIX_CFLAGS_COMPILE")) |nix_cflags_compile| {
            is_nixos = true;
            var it = mem.tokenize(nix_cflags_compile, " ");
            while (true) {
                const word = it.next() orelse break;
                if (mem.eql(u8, word, "-isystem")) {
                    const include_path = it.next() orelse {
                        warn("Expected argument after -isystem in NIX_CFLAGS_COMPILE\n");
                        break;
                    };
                    self.addNativeSystemIncludeDir(include_path);
                } else {
                    warn("Unrecognized C flag from NIX_CFLAGS_COMPILE: {}\n", word);
                    break;
                }
            }
        } else |err| {
            assert(err == error.EnvironmentVariableNotFound);
        }
        if (process.getEnvVarOwned(self.allocator, "NIX_LDFLAGS")) |nix_ldflags| {
            is_nixos = true;
            var it = mem.tokenize(nix_ldflags, " ");
            while (true) {
                const word = it.next() orelse break;
                if (mem.eql(u8, word, "-rpath")) {
                    const rpath = it.next() orelse {
                        warn("Expected argument after -rpath in NIX_LDFLAGS\n");
                        break;
                    };
                    self.addNativeSystemRPath(rpath);
                } else if (word.len > 2 and word[0] == '-' and word[1] == 'L') {
                    const lib_path = word[2..];
                    self.addNativeSystemLibPath(lib_path);
                } else {
                    warn("Unrecognized C flag from NIX_LDFLAGS: {}\n", word);
                    break;
                }
            }
        } else |err| {
            assert(err == error.EnvironmentVariableNotFound);
        }
        if (is_nixos) return;
        switch (builtin.os) {
            .windows => {},
            else => {
                const triple = (CrossTarget{
                    .arch = builtin.arch,
                    .os = builtin.os,
                    .abi = builtin.abi,
                }).linuxTriple(self.allocator);

                // TODO: $ ld --verbose | grep SEARCH_DIR
                // the output contains some paths that end with lib64, maybe include them too?
                // also, what is the best possible order of things?

                self.addNativeSystemIncludeDir("/usr/local/include");
                self.addNativeSystemLibPath("/usr/local/lib");

                self.addNativeSystemIncludeDir(self.fmt("/usr/include/{}", triple));
                self.addNativeSystemLibPath(self.fmt("/usr/lib/{}", triple));

                self.addNativeSystemIncludeDir("/usr/include");
                self.addNativeSystemLibPath("/usr/lib");

                // example: on a 64-bit debian-based linux distro, with zlib installed from apt:
                // zlib.h is in /usr/include (added above)
                // libz.so.1 is in /lib/x86_64-linux-gnu (added here)
                self.addNativeSystemLibPath(self.fmt("/lib/{}", triple));
            },
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
        const step_info = self.allocator.create(TopLevelStep) catch unreachable;
        step_info.* = TopLevelStep{
            .step = Step.initNoOp(name, self.allocator),
            .description = description,
        };
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

    pub fn addUserInputOption(self: *Builder, name: []const u8, value: []const u8) !bool {
        const gop = try self.user_input_options.getOrPut(name);
        if (!gop.found_existing) {
            gop.kv.value = UserInputOption{
                .name = name,
                .value = UserValue{ .Scalar = value },
                .used = false,
            };
            return false;
        }

        // option already exists
        switch (gop.kv.value.value) {
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
        return false;
    }

    pub fn addUserInputFlag(self: *Builder, name: []const u8) !bool {
        const gop = try self.user_input_options.getOrPut(name);
        if (!gop.found_existing) {
            gop.kv.value = UserInputOption{
                .name = name,
                .value = UserValue{ .Flag = {} },
                .used = false,
            };
            return false;
        }

        // option already exists
        switch (gop.kv.value.value) {
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
        return self.spawnChildEnvMap(null, self.env_map, argv);
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

        const child = std.ChildProcess.init(argv, self.allocator) catch unreachable;
        defer child.deinit();

        child.cwd = cwd;
        child.env_map = env_map;

        const term = child.spawnAndWait() catch |err| {
            warn("Unable to spawn {}: {}\n", argv[0], @errorName(err));
            return err;
        };

        switch (term) {
            .Exited => |code| {
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
        fs.makePath(self.allocator, self.pathFromRoot(path)) catch |err| {
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
        const full_dest_path = fs.path.resolve(
            self.allocator,
            [][]const u8{ self.prefix, dest_rel_path },
        ) catch unreachable;
        self.pushInstalledFile(full_dest_path);

        const install_step = self.allocator.create(InstallFileStep) catch unreachable;
        install_step.* = InstallFileStep.init(self, src_path, full_dest_path);
        return install_step;
    }

    pub fn pushInstalledFile(self: *Builder, full_path: []const u8) void {
        _ = self.getUninstallStep();
        self.installed_files.append(full_path) catch unreachable;
    }

    fn copyFile(self: *Builder, source_path: []const u8, dest_path: []const u8) !void {
        return self.copyFileMode(source_path, dest_path, File.default_mode);
    }

    fn copyFileMode(self: *Builder, source_path: []const u8, dest_path: []const u8, mode: File.Mode) !void {
        if (self.verbose) {
            warn("cp {} {}\n", source_path, dest_path);
        }

        const dirname = fs.path.dirname(dest_path) orelse ".";
        const abs_source_path = self.pathFromRoot(source_path);
        fs.makePath(self.allocator, dirname) catch |err| {
            warn("Unable to create path {}: {}\n", dirname, @errorName(err));
            return err;
        };
        fs.copyFileMode(abs_source_path, dest_path, mode) catch |err| {
            warn("Unable to copy {} to {}: {}\n", abs_source_path, dest_path, @errorName(err));
            return err;
        };
    }

    fn pathFromRoot(self: *Builder, rel_path: []const u8) []u8 {
        return fs.path.resolve(self.allocator, [][]const u8{ self.build_root, rel_path }) catch unreachable;
    }

    pub fn fmt(self: *Builder, comptime format: []const u8, args: ...) []u8 {
        return fmt_lib.allocPrint(self.allocator, format, args) catch unreachable;
    }

    pub fn findProgram(self: *Builder, names: []const []const u8, paths: []const []const u8) ![]const u8 {
        // TODO report error for ambiguous situations
        const exe_extension = (Target{ .Native = {} }).exeFileExt();
        for (self.search_prefixes.toSliceConst()) |search_prefix| {
            for (names) |name| {
                if (fs.path.isAbsolute(name)) {
                    return name;
                }
                const full_path = try fs.path.join(self.allocator, [][]const u8{ search_prefix, "bin", self.fmt("{}{}", name, exe_extension) });
                if (fs.path.real(self.allocator, full_path)) |real_path| {
                    return real_path;
                } else |_| {
                    continue;
                }
            }
        }
        if (self.env_map.get("PATH")) |PATH| {
            for (names) |name| {
                if (fs.path.isAbsolute(name)) {
                    return name;
                }
                var it = mem.tokenize(PATH, []u8{fs.path.delimiter});
                while (it.next()) |path| {
                    const full_path = try fs.path.join(self.allocator, [][]const u8{ path, self.fmt("{}{}", name, exe_extension) });
                    if (fs.path.real(self.allocator, full_path)) |real_path| {
                        return real_path;
                    } else |_| {
                        continue;
                    }
                }
            }
        }
        for (names) |name| {
            if (fs.path.isAbsolute(name)) {
                return name;
            }
            for (paths) |path| {
                const full_path = try fs.path.join(self.allocator, [][]const u8{ path, self.fmt("{}{}", name, exe_extension) });
                if (fs.path.real(self.allocator, full_path)) |real_path| {
                    return real_path;
                } else |_| {
                    continue;
                }
            }
        }
        return error.FileNotFound;
    }

    pub fn exec(self: *Builder, argv: []const []const u8) ![]u8 {
        assert(argv.len != 0);

        const max_output_size = 100 * 1024;
        const child = try std.ChildProcess.init(argv, self.allocator);
        defer child.deinit();

        child.stdin_behavior = .Ignore;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Inherit;

        try child.spawn();

        var stdout = std.Buffer.initNull(self.allocator);
        defer std.Buffer.deinit(&stdout);

        var stdout_file_in_stream = child.stdout.?.inStream();
        try stdout_file_in_stream.stream.readAllBuffer(&stdout, max_output_size);

        const term = child.wait() catch |err| std.debug.panic("unable to spawn {}: {}", argv[0], err);
        switch (term) {
            .Exited => |code| {
                if (code != 0) {
                    warn("The following command exited with error code {}:\n", code);
                    printCmd(null, argv);
                    std.debug.panic("exec failed");
                }
                return stdout.toOwnedSlice();
            },
            else => {
                warn("The following command terminated unexpectedly:\n");
                printCmd(null, argv);
                std.debug.panic("exec failed");
            },
        }

        return stdout.toOwnedSlice();
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
    abi: builtin.Abi,

    pub fn zigTriple(cross_target: CrossTarget, allocator: *Allocator) []u8 {
        return std.fmt.allocPrint(
            allocator,
            "{}{}-{}-{}",
            @tagName(cross_target.arch),
            Target.archSubArchName(cross_target.arch),
            @tagName(cross_target.os),
            @tagName(cross_target.abi),
        ) catch unreachable;
    }

    pub fn linuxTriple(cross_target: CrossTarget, allocator: *Allocator) []u8 {
        return std.fmt.allocPrint(
            allocator,
            "{}-{}-{}",
            @tagName(cross_target.arch),
            @tagName(cross_target.os),
            @tagName(cross_target.abi),
        ) catch unreachable;
    }
};

pub const Target = union(enum) {
    Native: void,
    Cross: CrossTarget,

    fn archSubArchName(arch: builtin.Arch) []const u8 {
        return switch (arch) {
            builtin.Arch.arm => |sub| @tagName(sub),
            builtin.Arch.armeb => |sub| @tagName(sub),
            builtin.Arch.thumb => |sub| @tagName(sub),
            builtin.Arch.thumbeb => |sub| @tagName(sub),
            builtin.Arch.aarch64 => |sub| @tagName(sub),
            builtin.Arch.aarch64_be => |sub| @tagName(sub),
            builtin.Arch.kalimba => |sub| @tagName(sub),
            else => "",
        };
    }

    pub fn subArchName(self: Target) []const u8 {
        switch (self) {
            Target.Native => return archSubArchName(builtin.arch),
            Target.Cross => |cross| return archSubArchName(cross.arch),
        }
    }

    pub fn oFileExt(self: Target) []const u8 {
        const abi = switch (self) {
            Target.Native => builtin.abi,
            Target.Cross => |t| t.abi,
        };
        return switch (abi) {
            builtin.Abi.msvc => ".obj",
            else => ".o",
        };
    }

    pub fn exeFileExt(self: Target) []const u8 {
        return switch (self.getOs()) {
            .windows => ".exe",
            else => "",
        };
    }

    pub fn libFileExt(self: Target) []const u8 {
        return switch (self.getOs()) {
            .windows => ".lib",
            else => ".a",
        };
    }

    pub fn getOs(self: Target) builtin.Os {
        return switch (self) {
            Target.Native => builtin.os,
            Target.Cross => |t| t.os,
        };
    }

    pub fn getArch(self: Target) builtin.Arch {
        switch (self) {
            Target.Native => return builtin.arch,
            Target.Cross => |t| return t.arch,
        }
    }

    pub fn isDarwin(self: Target) bool {
        return switch (self.getOs()) {
            .ios, .macosx, .watchos, .tvos => true,
            else => false,
        };
    }

    pub fn isWindows(self: Target) bool {
        return switch (self.getOs()) {
            .windows => true,
            else => false,
        };
    }

    pub fn isWasm(self: Target) bool {
        return switch (self.getArch()) {
            .wasm32, .wasm64 => true,
            else => false,
        };
    }

    pub fn isFreeBSD(self: Target) bool {
        return switch (self.getOs()) {
            .freebsd => true,
            else => false,
        };
    }

    pub fn wantSharedLibSymLinks(self: Target) bool {
        return !self.isWindows();
    }
};

const Pkg = struct {
    name: []const u8,
    path: []const u8,
};

const CSourceFile = struct {
    source_path: []const u8,
    args: []const []const u8,
};

fn isLibCLibrary(name: []const u8) bool {
    const libc_libraries = [][]const u8{ "c", "m", "dl", "rt", "pthread" };
    for (libc_libraries) |libc_lib_name| {
        if (mem.eql(u8, name, libc_lib_name))
            return true;
    }
    return false;
}

pub const LibExeObjStep = struct {
    step: Step,
    builder: *Builder,
    name: []const u8,
    target: Target,
    linker_script: ?[]const u8,
    out_filename: []const u8,
    is_dynamic: bool,
    version: Version,
    build_mode: builtin.Mode,
    kind: Kind,
    major_only_filename: []const u8,
    name_only_filename: []const u8,
    strip: bool,
    lib_paths: ArrayList([]const u8),
    frameworks: BufSet,
    verbose_link: bool,
    verbose_cc: bool,
    disable_gen_h: bool,
    bundle_compiler_rt: bool,
    disable_stack_probing: bool,
    c_std: Builder.CStd,
    override_std_dir: ?[]const u8,
    override_lib_dir: ?[]const u8,
    main_pkg_path: ?[]const u8,
    exec_cmd_args: ?[]const ?[]const u8,
    name_prefix: []const u8,
    filter: ?[]const u8,
    single_threaded: bool,

    root_src: ?[]const u8,
    out_h_filename: []const u8,
    out_lib_filename: []const u8,
    packages: ArrayList(Pkg),
    build_options_contents: std.Buffer,
    system_linker_hack: bool,

    object_src: []const u8,

    link_objects: ArrayList(LinkObject),
    include_dirs: ArrayList(IncludeDir),
    output_dir: ?[]const u8,
    need_system_paths: bool,

    const LinkObject = union(enum) {
        StaticPath: []const u8,
        OtherStep: *LibExeObjStep,
        SystemLib: []const u8,
        AssemblyFile: []const u8,
        CSourceFile: *CSourceFile,
    };

    const IncludeDir = union(enum) {
        RawPath: []const u8,
        OtherStep: *LibExeObjStep,
    };

    const Kind = enum {
        Exe,
        Lib,
        Obj,
        Test,
    };

    pub fn createSharedLibrary(builder: *Builder, name: []const u8, root_src: ?[]const u8, ver: Version) *LibExeObjStep {
        const self = builder.allocator.create(LibExeObjStep) catch unreachable;
        self.* = initExtraArgs(builder, name, root_src, Kind.Lib, true, ver);
        return self;
    }

    pub fn createStaticLibrary(builder: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        const self = builder.allocator.create(LibExeObjStep) catch unreachable;
        self.* = initExtraArgs(builder, name, root_src, Kind.Lib, false, builder.version(0, 0, 0));
        return self;
    }

    pub fn createObject(builder: *Builder, name: []const u8, root_src: ?[]const u8) *LibExeObjStep {
        const self = builder.allocator.create(LibExeObjStep) catch unreachable;
        self.* = initExtraArgs(builder, name, root_src, Kind.Obj, false, builder.version(0, 0, 0));
        return self;
    }

    pub fn createExecutable(builder: *Builder, name: []const u8, root_src: ?[]const u8, is_dynamic: bool) *LibExeObjStep {
        const self = builder.allocator.create(LibExeObjStep) catch unreachable;
        self.* = initExtraArgs(builder, name, root_src, Kind.Exe, is_dynamic, builder.version(0, 0, 0));
        return self;
    }

    pub fn createTest(builder: *Builder, name: []const u8, root_src: []const u8) *LibExeObjStep {
        const self = builder.allocator.create(LibExeObjStep) catch unreachable;
        self.* = initExtraArgs(builder, name, root_src, Kind.Test, false, builder.version(0, 0, 0));
        return self;
    }

    fn initExtraArgs(builder: *Builder, name: []const u8, root_src: ?[]const u8, kind: Kind, is_dynamic: bool, ver: Version) LibExeObjStep {
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
            .target = Target.Native,
            .linker_script = null,
            .frameworks = BufSet.init(builder.allocator),
            .step = Step.init(name, builder.allocator, make),
            .version = ver,
            .out_filename = undefined,
            .out_h_filename = builder.fmt("{}.h", name),
            .out_lib_filename = undefined,
            .major_only_filename = undefined,
            .name_only_filename = undefined,
            .packages = ArrayList(Pkg).init(builder.allocator),
            .include_dirs = ArrayList(IncludeDir).init(builder.allocator),
            .link_objects = ArrayList(LinkObject).init(builder.allocator),
            .lib_paths = ArrayList([]const u8).init(builder.allocator),
            .object_src = undefined,
            .build_options_contents = std.Buffer.initSize(builder.allocator, 0) catch unreachable,
            .c_std = Builder.CStd.C99,
            .system_linker_hack = false,
            .override_std_dir = null,
            .override_lib_dir = null,
            .main_pkg_path = null,
            .exec_cmd_args = null,
            .name_prefix = "",
            .filter = null,
            .disable_gen_h = false,
            .bundle_compiler_rt = false,
            .disable_stack_probing = false,
            .output_dir = null,
            .need_system_paths = false,
            .single_threaded = false,
        };
        self.computeOutFileNames();
        return self;
    }

    fn computeOutFileNames(self: *LibExeObjStep) void {
        switch (self.kind) {
            .Obj => {
                self.out_filename = self.builder.fmt("{}{}", self.name, self.target.oFileExt());
            },
            .Exe => {
                self.out_filename = self.builder.fmt("{}{}", self.name, self.target.exeFileExt());
            },
            .Test => {
                self.out_filename = self.builder.fmt("test{}", self.target.exeFileExt());
            },
            .Lib => {
                if (!self.is_dynamic) {
                    switch (self.target.getOs()) {
                        .windows => {
                            self.out_filename = self.builder.fmt("{}.lib", self.name);
                        },
                        else => {
                            if (self.target.isWasm()) {
                                self.out_filename = self.builder.fmt("{}.wasm", self.name);
                            } else {
                                self.out_filename = self.builder.fmt("lib{}.a", self.name);
                            }
                        },
                    }
                    self.out_lib_filename = self.out_filename;
                } else {
                    switch (self.target.getOs()) {
                        .ios, .macosx => {
                            self.out_filename = self.builder.fmt("lib{}.{d}.{d}.{d}.dylib", self.name, self.version.major, self.version.minor, self.version.patch);
                            self.major_only_filename = self.builder.fmt("lib{}.{d}.dylib", self.name, self.version.major);
                            self.name_only_filename = self.builder.fmt("lib{}.dylib", self.name);
                            self.out_lib_filename = self.out_filename;
                        },
                        .windows => {
                            self.out_filename = self.builder.fmt("{}.dll", self.name);
                            self.out_lib_filename = self.builder.fmt("{}.lib", self.name);
                        },
                        else => {
                            self.out_filename = self.builder.fmt("lib{}.so.{d}.{d}.{d}", self.name, self.version.major, self.version.minor, self.version.patch);
                            self.major_only_filename = self.builder.fmt("lib{}.so.{d}", self.name, self.version.major);
                            self.name_only_filename = self.builder.fmt("lib{}.so", self.name);
                            self.out_lib_filename = self.out_filename;
                        },
                    }
                }
            },
        }
    }

    pub fn setTarget(
        self: *LibExeObjStep,
        target_arch: builtin.Arch,
        target_os: builtin.Os,
        target_abi: builtin.Abi,
    ) void {
        self.target = Target{
            .Cross = CrossTarget{
                .arch = target_arch,
                .os = target_os,
                .abi = target_abi,
            },
        };
        self.computeOutFileNames();
    }

    pub fn setOutputDir(self: *LibExeObjStep, dir: []const u8) void {
        self.output_dir = self.builder.dupe(dir);
    }

    /// Creates a `RunStep` with an executable built with `addExecutable`.
    /// Add command line arguments with `addArg`.
    pub fn run(exe: *LibExeObjStep) *RunStep {
        assert(exe.kind == Kind.Exe);
        // It doesn't have to be native. We catch that if you actually try to run it.
        // Consider that this is declarative; the run step may not be run unless a user
        // option is supplied.
        const run_step = RunStep.create(exe.builder, exe.builder.fmt("run {}", exe.step.name));
        run_step.addArtifactArg(exe);
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
        for (self.link_objects.toSliceConst()) |link_object| {
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

    pub fn linkSystemLibrary(self: *LibExeObjStep, name: []const u8) void {
        self.link_objects.append(LinkObject{ .SystemLib = self.builder.dupe(name) }) catch unreachable;
        if (!isLibCLibrary(name)) {
            self.need_system_paths = true;
        }
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
        const c_source_file = self.builder.allocator.create(CSourceFile) catch unreachable;
        const args_copy = self.builder.allocator.alloc([]u8, args.len) catch unreachable;
        for (args) |arg, i| {
            args_copy[i] = self.builder.dupe(arg);
        }
        c_source_file.* = CSourceFile{
            .source_path = self.builder.dupe(file),
            .args = args_copy,
        };
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

    pub fn overrideStdDir(self: *LibExeObjStep, dir_path: []const u8) void {
        self.override_std_dir = dir_path;
    }

    pub fn setMainPkgPath(self: *LibExeObjStep, dir_path: []const u8) void {
        self.main_pkg_path = dir_path;
    }

    pub fn setDisableGenH(self: *LibExeObjStep, value: bool) void {
        self.disable_gen_h = value;
    }

    /// Unless setOutputDir was called, this function must be called only in
    /// the make step, from a step that has declared a dependency on this one.
    /// To run an executable built with zig build, use `run`, or create an install step and invoke it.
    pub fn getOutputPath(self: *LibExeObjStep) []const u8 {
        return fs.path.join(
            self.builder.allocator,
            [][]const u8{ self.output_dir.?, self.out_filename },
        ) catch unreachable;
    }

    /// Unless setOutputDir was called, this function must be called only in
    /// the make step, from a step that has declared a dependency on this one.
    pub fn getOutputLibPath(self: *LibExeObjStep) []const u8 {
        assert(self.kind == Kind.Lib);
        return fs.path.join(
            self.builder.allocator,
            [][]const u8{ self.output_dir.?, self.out_lib_filename },
        ) catch unreachable;
    }

    /// Unless setOutputDir was called, this function must be called only in
    /// the make step, from a step that has declared a dependency on this one.
    pub fn getOutputHPath(self: *LibExeObjStep) []const u8 {
        assert(self.kind != Kind.Exe);
        assert(!self.disable_gen_h);
        return fs.path.join(
            self.builder.allocator,
            [][]const u8{ self.output_dir.?, self.out_h_filename },
        ) catch unreachable;
    }

    pub fn addAssemblyFile(self: *LibExeObjStep, path: []const u8) void {
        self.link_objects.append(LinkObject{ .AssemblyFile = self.builder.dupe(path) }) catch unreachable;
    }

    pub fn addObjectFile(self: *LibExeObjStep, path: []const u8) void {
        self.link_objects.append(LinkObject{ .StaticPath = self.builder.dupe(path) }) catch unreachable;
    }

    pub fn addObject(self: *LibExeObjStep, obj: *LibExeObjStep) void {
        assert(obj.kind == Kind.Obj);
        self.linkLibraryOrObject(obj);
    }

    pub fn addBuildOption(self: *LibExeObjStep, comptime T: type, name: []const u8, value: T) void {
        const out = &std.io.BufferOutStream.init(&self.build_options_contents).stream;
        out.print("pub const {} = {};\n", name, value) catch unreachable;
    }

    pub fn addIncludeDir(self: *LibExeObjStep, path: []const u8) void {
        self.include_dirs.append(IncludeDir{ .RawPath = self.builder.dupe(path) }) catch unreachable;
    }

    pub fn addLibPath(self: *LibExeObjStep, path: []const u8) void {
        self.lib_paths.append(path) catch unreachable;
    }

    pub fn addPackagePath(self: *LibExeObjStep, name: []const u8, pkg_index_path: []const u8) void {
        self.packages.append(Pkg{
            .name = name,
            .path = pkg_index_path,
        }) catch unreachable;
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

        // Inherit dependency on libc
        if (other.dependsOnSystemLibrary("c")) {
            self.linkSystemLibrary("c");
        }

        // Inherit dependencies on darwin frameworks
        if (self.target.isDarwin() and !other.isDynamicLibrary()) {
            var it = other.frameworks.iterator();
            while (it.next()) |entry| {
                self.frameworks.put(entry.key) catch unreachable;
            }
        }
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(LibExeObjStep, "step", step);
        const builder = self.builder;

        if (self.root_src == null and self.link_objects.len == 0) {
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
            Kind.Test => "test",
        };
        zig_args.append(cmd) catch unreachable;

        if (self.root_src) |root_src| {
            zig_args.append(builder.pathFromRoot(root_src)) catch unreachable;
        }

        for (self.link_objects.toSlice()) |link_object| {
            switch (link_object) {
                LinkObject.StaticPath => |static_path| {
                    try zig_args.append("--object");
                    try zig_args.append(builder.pathFromRoot(static_path));
                },

                LinkObject.OtherStep => |other| switch (other.kind) {
                    LibExeObjStep.Kind.Exe => unreachable,
                    LibExeObjStep.Kind.Test => unreachable,
                    LibExeObjStep.Kind.Obj => {
                        try zig_args.append("--object");
                        try zig_args.append(other.getOutputPath());
                    },
                    LibExeObjStep.Kind.Lib => {
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
                LinkObject.SystemLib => |name| {
                    try zig_args.append("--library");
                    try zig_args.append(name);
                },
                LinkObject.AssemblyFile => |asm_file| {
                    try zig_args.append("--c-source");
                    try zig_args.append(builder.pathFromRoot(asm_file));
                },
                LinkObject.CSourceFile => |c_source_file| {
                    try zig_args.append("--c-source");
                    for (c_source_file.args) |arg| {
                        try zig_args.append(arg);
                    }
                    try zig_args.append(self.builder.pathFromRoot(c_source_file.source_path));
                },
            }
        }

        if (self.build_options_contents.len() > 0) {
            const build_options_file = try fs.path.join(
                builder.allocator,
                [][]const u8{ builder.cache_root, builder.fmt("{}_build_options.zig", self.name) },
            );
            try std.io.writeFile(build_options_file, self.build_options_contents.toSliceConst());
            try zig_args.append("--pkg-begin");
            try zig_args.append("build_options");
            try zig_args.append(builder.pathFromRoot(build_options_file));
            try zig_args.append("--pkg-end");
        }

        if (self.filter) |filter| {
            try zig_args.append("--test-filter");
            try zig_args.append(filter);
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

        if (self.strip) {
            zig_args.append("--strip") catch unreachable;
        }

        if (self.single_threaded) {
            try zig_args.append("--single-threaded");
        }

        switch (self.build_mode) {
            builtin.Mode.Debug => {},
            builtin.Mode.ReleaseSafe => zig_args.append("--release-safe") catch unreachable,
            builtin.Mode.ReleaseFast => zig_args.append("--release-fast") catch unreachable,
            builtin.Mode.ReleaseSmall => zig_args.append("--release-small") catch unreachable,
        }

        try zig_args.append("--cache-dir");
        try zig_args.append(builder.pathFromRoot(builder.cache_root));

        zig_args.append("--name") catch unreachable;
        zig_args.append(self.name) catch unreachable;

        if (self.kind == Kind.Lib and self.is_dynamic) {
            zig_args.append("--ver-major") catch unreachable;
            zig_args.append(builder.fmt("{}", self.version.major)) catch unreachable;

            zig_args.append("--ver-minor") catch unreachable;
            zig_args.append(builder.fmt("{}", self.version.minor)) catch unreachable;

            zig_args.append("--ver-patch") catch unreachable;
            zig_args.append(builder.fmt("{}", self.version.patch)) catch unreachable;
        }
        if (self.is_dynamic) {
            try zig_args.append("-dynamic");
        }
        if (self.disable_gen_h) {
            try zig_args.append("--disable-gen-h");
        }
        if (self.bundle_compiler_rt) {
            try zig_args.append("--bundle-compiler-rt");
        }
        if (self.disable_stack_probing) {
            try zig_args.append("--disable-stack-probing");
        }

        switch (self.target) {
            Target.Native => {},
            Target.Cross => |cross_target| {
                try zig_args.append("-target");
                try zig_args.append(cross_target.zigTriple(builder.allocator));
            },
        }

        if (self.linker_script) |linker_script| {
            zig_args.append("--linker-script") catch unreachable;
            zig_args.append(linker_script) catch unreachable;
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
        for (self.packages.toSliceConst()) |pkg| {
            zig_args.append("--pkg-begin") catch unreachable;
            zig_args.append(pkg.name) catch unreachable;
            zig_args.append(builder.pathFromRoot(pkg.path)) catch unreachable;
            zig_args.append("--pkg-end") catch unreachable;
        }

        for (self.include_dirs.toSliceConst()) |include_dir| {
            switch (include_dir) {
                IncludeDir.RawPath => |include_path| {
                    try zig_args.append("-isystem");
                    try zig_args.append(self.builder.pathFromRoot(include_path));
                },
                IncludeDir.OtherStep => |other| {
                    const h_path = other.getOutputHPath();
                    try zig_args.append("-isystem");
                    try zig_args.append(fs.path.dirname(h_path).?);
                },
            }
        }

        for (self.lib_paths.toSliceConst()) |lib_path| {
            zig_args.append("--library-path") catch unreachable;
            zig_args.append(lib_path) catch unreachable;
        }

        if (self.need_system_paths and self.target == Target.Native) {
            for (builder.native_system_include_dirs.toSliceConst()) |include_path| {
                zig_args.append("-isystem") catch unreachable;
                zig_args.append(builder.pathFromRoot(include_path)) catch unreachable;
            }

            for (builder.native_system_rpaths.toSliceConst()) |rpath| {
                zig_args.append("-rpath") catch unreachable;
                zig_args.append(rpath) catch unreachable;
            }

            for (builder.native_system_lib_paths.toSliceConst()) |lib_path| {
                zig_args.append("--library-path") catch unreachable;
                zig_args.append(lib_path) catch unreachable;
            }
        }

        if (self.target.isDarwin()) {
            var it = self.frameworks.iterator();
            while (it.next()) |entry| {
                zig_args.append("-framework") catch unreachable;
                zig_args.append(entry.key) catch unreachable;
            }
        }

        if (self.system_linker_hack) {
            try zig_args.append("--system-linker-hack");
        }

        if (self.override_std_dir) |dir| {
            try zig_args.append("--override-std-dir");
            try zig_args.append(builder.pathFromRoot(dir));
        } else if (self.builder.override_std_dir) |dir| {
            try zig_args.append("--override-std-dir");
            try zig_args.append(builder.pathFromRoot(dir));
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

        if (self.output_dir) |output_dir| {
            try zig_args.append("--output-dir");
            try zig_args.append(output_dir);

            try builder.spawnChild(zig_args.toSliceConst());
        } else if (self.kind == Kind.Test) {
            try builder.spawnChild(zig_args.toSliceConst());
        } else {
            try zig_args.append("--cache");
            try zig_args.append("on");

            const output_path_nl = try builder.exec(zig_args.toSliceConst());
            const output_path = mem.trimRight(u8, output_path_nl, "\r\n");
            self.output_dir = fs.path.dirname(output_path).?;
        }

        if (self.kind == Kind.Lib and self.is_dynamic and self.target.wantSharedLibSymLinks()) {
            try doAtomicSymLinks(builder.allocator, self.getOutputPath(), self.major_only_filename, self.name_only_filename);
        }
    }
};

pub const RunStep = struct {
    step: Step,
    builder: *Builder,

    /// See also addArg and addArgs to modifying this directly
    argv: ArrayList(Arg),

    /// Set this to modify the current working directory
    cwd: ?[]const u8,

    /// Override this field to modify the environment, or use setEnvironmentVariable
    env_map: ?*BufMap,

    pub const Arg = union(enum) {
        Artifact: *LibExeObjStep,
        Bytes: []u8,
    };

    pub fn create(builder: *Builder, name: []const u8) *RunStep {
        const self = builder.allocator.create(RunStep) catch unreachable;
        self.* = RunStep{
            .builder = builder,
            .step = Step.init(name, builder.allocator, make),
            .argv = ArrayList(Arg).init(builder.allocator),
            .cwd = null,
            .env_map = null,
        };
        return self;
    }

    pub fn addArtifactArg(self: *RunStep, artifact: *LibExeObjStep) void {
        self.argv.append(Arg{ .Artifact = artifact }) catch unreachable;
        self.step.dependOn(&artifact.step);
    }

    pub fn addArg(self: *RunStep, arg: []const u8) void {
        self.argv.append(Arg{ .Bytes = self.builder.dupe(arg) }) catch unreachable;
    }

    pub fn addArgs(self: *RunStep, args: []const []const u8) void {
        for (args) |arg| {
            self.addArg(arg);
        }
    }

    pub fn clearEnvironment(self: *RunStep) void {
        const new_env_map = self.builder.allocator.create(BufMap) catch unreachable;
        new_env_map.* = BufMap.init(self.builder.allocator);
        self.env_map = new_env_map;
    }

    pub fn addPathDir(self: *RunStep, search_path: []const u8) void {
        const PATH = if (std.os.windows.is_the_target) "Path" else "PATH";
        const env_map = self.getEnvMap();
        const prev_path = env_map.get(PATH) orelse {
            env_map.set(PATH, search_path) catch unreachable;
            return;
        };
        const new_path = self.builder.fmt("{}" ++ [1]u8{fs.path.delimiter} ++ "{}", prev_path, search_path);
        env_map.set(PATH, new_path) catch unreachable;
    }

    pub fn getEnvMap(self: *RunStep) *BufMap {
        return self.env_map orelse {
            const env_map = self.builder.allocator.create(BufMap) catch unreachable;
            env_map.* = process.getEnvMap(self.builder.allocator) catch unreachable;
            self.env_map = env_map;
            return env_map;
        };
    }

    pub fn setEnvironmentVariable(self: *RunStep, key: []const u8, value: []const u8) void {
        const env_map = self.getEnvMap();
        env_map.set(key, value) catch unreachable;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(RunStep, "step", step);

        const cwd = if (self.cwd) |cwd| self.builder.pathFromRoot(cwd) else self.builder.build_root;

        var argv = ArrayList([]const u8).init(self.builder.allocator);
        for (self.argv.toSlice()) |arg| {
            switch (arg) {
                Arg.Bytes => |bytes| try argv.append(bytes),
                Arg.Artifact => |artifact| {
                    if (artifact.target.isWindows()) {
                        // On Windows we don't have rpaths so we have to add .dll search paths to PATH
                        self.addPathForDynLibs(artifact);
                    }
                    try argv.append(artifact.getOutputPath());
                },
            }
        }

        return self.builder.spawnChildEnvMap(cwd, self.env_map orelse self.builder.env_map, argv.toSliceConst());
    }

    fn addPathForDynLibs(self: *RunStep, artifact: *LibExeObjStep) void {
        for (artifact.link_objects.toSliceConst()) |link_object| {
            switch (link_object) {
                LibExeObjStep.LinkObject.OtherStep => |other| {
                    if (other.target.isWindows() and other.isDynamicLibrary()) {
                        self.addPathDir(fs.path.dirname(other.getOutputPath()).?);
                        self.addPathForDynLibs(other);
                    }
                },
                else => {},
            }
        }
    }
};

const InstallArtifactStep = struct {
    step: Step,
    builder: *Builder,
    artifact: *LibExeObjStep,
    dest_file: []const u8,

    const Self = @This();

    pub fn create(builder: *Builder, artifact: *LibExeObjStep) *Self {
        const dest_dir = switch (artifact.kind) {
            LibExeObjStep.Kind.Obj => unreachable,
            LibExeObjStep.Kind.Test => unreachable,
            LibExeObjStep.Kind.Exe => builder.exe_dir,
            LibExeObjStep.Kind.Lib => builder.lib_dir,
        };
        const self = builder.allocator.create(Self) catch unreachable;
        self.* = Self{
            .builder = builder,
            .step = Step.init(builder.fmt("install {}", artifact.step.name), builder.allocator, make),
            .artifact = artifact,
            .dest_file = fs.path.join(
                builder.allocator,
                [][]const u8{ dest_dir, artifact.out_filename },
            ) catch unreachable,
        };
        self.step.dependOn(&artifact.step);
        builder.pushInstalledFile(self.dest_file);
        if (self.artifact.kind == LibExeObjStep.Kind.Lib and self.artifact.is_dynamic) {
            builder.pushInstalledFile(fs.path.join(
                builder.allocator,
                [][]const u8{ builder.lib_dir, artifact.major_only_filename },
            ) catch unreachable);
            builder.pushInstalledFile(fs.path.join(
                builder.allocator,
                [][]const u8{ builder.lib_dir, artifact.name_only_filename },
            ) catch unreachable);
        }
        return self;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(Self, "step", step);
        const builder = self.builder;

        const mode = switch (builtin.os) {
            .windows => {},
            else => switch (self.artifact.kind) {
                .Obj => unreachable,
                .Test => unreachable,
                .Exe => u32(0o755),
                .Lib => if (!self.artifact.is_dynamic) u32(0o666) else u32(0o755),
            },
        };
        try builder.copyFileMode(self.artifact.getOutputPath(), self.dest_file, mode);
        if (self.artifact.isDynamicLibrary()) {
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
        const full_path_dir = fs.path.dirname(full_path) orelse ".";
        fs.makePath(self.builder.allocator, full_path_dir) catch |err| {
            warn("unable to make path {}: {}\n", full_path_dir, @errorName(err));
            return err;
        };
        io.writeFile(full_path, self.data) catch |err| {
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

    fn make(step: *Step) anyerror!void {
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
        fs.deleteTree(self.builder.allocator, full_path) catch |err| {
            warn("Unable to remove {}: {}\n", full_path, @errorName(err));
            return err;
        };
    }
};

pub const Step = struct {
    name: []const u8,
    makeFn: fn (self: *Step) anyerror!void,
    dependencies: ArrayList(*Step),
    loop_flag: bool,
    done_flag: bool,

    pub fn init(name: []const u8, allocator: *Allocator, makeFn: fn (*Step) anyerror!void) Step {
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

    fn makeNoOp(self: *Step) anyerror!void {}
};

fn doAtomicSymLinks(allocator: *Allocator, output_path: []const u8, filename_major_only: []const u8, filename_name_only: []const u8) !void {
    const out_dir = fs.path.dirname(output_path) orelse ".";
    const out_basename = fs.path.basename(output_path);
    // sym link for libfoo.so.1 to libfoo.so.1.2.3
    const major_only_path = fs.path.join(
        allocator,
        [][]const u8{ out_dir, filename_major_only },
    ) catch unreachable;
    fs.atomicSymLink(allocator, out_basename, major_only_path) catch |err| {
        warn("Unable to symlink {} -> {}\n", major_only_path, out_basename);
        return err;
    };
    // sym link for libfoo.so to libfoo.so.1
    const name_only_path = fs.path.join(
        allocator,
        [][]const u8{ out_dir, filename_name_only },
    ) catch unreachable;
    fs.atomicSymLink(allocator, filename_major_only, name_only_path) catch |err| {
        warn("Unable to symlink {} -> {}\n", name_only_path, filename_major_only);
        return err;
    };
}
