const builtin = @import("builtin");
const io = @import("io.zig");
const mem = @import("mem.zig");
const debug = @import("debug.zig");
const assert = debug.assert;
const ArrayList = @import("array_list.zig").ArrayList;
const HashMap = @import("hash_map.zig").HashMap;
const Allocator = @import("mem.zig").Allocator;
const os = @import("os/index.zig");
const StdIo = os.ChildProcess.StdIo;
const Term = os.ChildProcess.Term;
const BufSet = @import("buf_set.zig").BufSet;
const BufMap = @import("buf_map.zig").BufMap;
const fmt_lib = @import("fmt/index.zig");

error ExtraArg;
error UncleanExit;
error InvalidStepName;
error DependencyLoopDetected;
error NoCompilerFound;
error NeedAnObject;

pub const Builder = struct {
    uninstall_tls: TopLevelStep,
    install_tls: TopLevelStep,
    have_uninstall_step: bool,
    have_install_step: bool,
    allocator: &Allocator,
    lib_paths: ArrayList([]const u8),
    include_paths: ArrayList([]const u8),
    rpaths: ArrayList([]const u8),
    user_input_options: UserInputOptionsMap,
    available_options_map: AvailableOptionsMap,
    available_options_list: ArrayList(AvailableOption),
    verbose: bool,
    invalid_user_input: bool,
    zig_exe: []const u8,
    default_step: &Step,
    env_map: BufMap,
    top_level_steps: ArrayList(&TopLevelStep),
    prefix: []const u8,
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

    const UserValue = enum {
        Flag,
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

    pub fn init(allocator: &Allocator, zig_exe: []const u8, build_root: []const u8,
        cache_root: []const u8) -> Builder
    {
        var self = Builder {
            .zig_exe = zig_exe,
            .build_root = build_root,
            .cache_root = %%os.path.relative(allocator, build_root, cache_root),
            .verbose = false,
            .invalid_user_input = false,
            .allocator = allocator,
            .lib_paths = ArrayList([]const u8).init(allocator),
            .include_paths = ArrayList([]const u8).init(allocator),
            .rpaths = ArrayList([]const u8).init(allocator),
            .user_input_options = UserInputOptionsMap.init(allocator),
            .available_options_map = AvailableOptionsMap.init(allocator),
            .available_options_list = ArrayList(AvailableOption).init(allocator),
            .top_level_steps = ArrayList(&TopLevelStep).init(allocator),
            .default_step = undefined,
            .env_map = %%os.getEnvMap(allocator),
            .prefix = undefined,
            .lib_dir = undefined,
            .exe_dir = undefined,
            .installed_files = ArrayList([]const u8).init(allocator),
            .uninstall_tls = TopLevelStep {
                .step = Step.init("uninstall", allocator, makeUninstall),
                .description = "Remove build artifacts from prefix path",
            },
            .have_uninstall_step = false,
            .install_tls = TopLevelStep {
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

    pub fn deinit(self: &Builder) {
        self.lib_paths.deinit();
        self.include_paths.deinit();
        self.rpaths.deinit();
        self.env_map.deinit();
        self.top_level_steps.deinit();
    }

    pub fn setInstallPrefix(self: &Builder, maybe_prefix: ?[]const u8) {
        self.prefix = maybe_prefix ?? "/usr/local"; // TODO better default
        self.lib_dir = %%os.path.join(self.allocator, self.prefix, "lib");
        self.exe_dir = %%os.path.join(self.allocator, self.prefix, "bin");
    }

    pub fn addExecutable(self: &Builder, name: []const u8, root_src: ?[]const u8) -> &LibExeObjStep {
        return LibExeObjStep.createExecutable(self, name, root_src);
    }

    pub fn addObject(self: &Builder, name: []const u8, root_src: []const u8) -> &LibExeObjStep {
        return LibExeObjStep.createObject(self, name, root_src);
    }

    pub fn addSharedLibrary(self: &Builder, name: []const u8, root_src: ?[]const u8,
        ver: &const Version) -> &LibExeObjStep
    {
        return LibExeObjStep.createSharedLibrary(self, name, root_src, ver);
    }

    pub fn addStaticLibrary(self: &Builder, name: []const u8, root_src: ?[]const u8) -> &LibExeObjStep {
        return LibExeObjStep.createStaticLibrary(self, name, root_src);
    }

    pub fn addTest(self: &Builder, root_src: []const u8) -> &TestStep {
        const test_step = %%self.allocator.create(TestStep);
        *test_step = TestStep.init(self, root_src);
        return test_step;
    }

    pub fn addAssemble(self: &Builder, name: []const u8, src: []const u8) -> &LibExeObjStep {
        const obj_step = LibExeObjStep.createObject(self, name, null);
        obj_step.addAssemblyFile(src);
        return obj_step;
    }

    pub fn addCStaticLibrary(self: &Builder, name: []const u8) -> &LibExeObjStep {
        return LibExeObjStep.createCStaticLibrary(self, name);
    }

    pub fn addCSharedLibrary(self: &Builder, name: []const u8, ver: &const Version) -> &LibExeObjStep {
        return LibExeObjStep.createCSharedLibrary(self, name, ver);
    }

    pub fn addCExecutable(self: &Builder, name: []const u8) -> &LibExeObjStep {
        return LibExeObjStep.createCExecutable(self, name);
    }

    pub fn addCObject(self: &Builder, name: []const u8, src: []const u8) -> &LibExeObjStep {
        return LibExeObjStep.createCObject(self, name, src);
    }

    /// ::args are copied.
    pub fn addCommand(self: &Builder, cwd: ?[]const u8, env_map: &const BufMap,
        path: []const u8, args: []const []const u8) -> &CommandStep
    {
        return CommandStep.create(self, cwd, env_map, path, args);
    }

    pub fn addWriteFile(self: &Builder, file_path: []const u8, data: []const u8) -> &WriteFileStep {
        const write_file_step = %%self.allocator.create(WriteFileStep);
        *write_file_step = WriteFileStep.init(self, file_path, data);
        return write_file_step;
    }

    pub fn addLog(self: &Builder, comptime format: []const u8, args: ...) -> &LogStep {
        const data = self.fmt(format, args);
        const log_step = %%self.allocator.create(LogStep);
        *log_step = LogStep.init(self, data);
        return log_step;
    }

    pub fn addRemoveDirTree(self: &Builder, dir_path: []const u8) -> &RemoveDirStep {
        const remove_dir_step = %%self.allocator.create(RemoveDirStep);
        *remove_dir_step = RemoveDirStep.init(self, dir_path);
        return remove_dir_step;
    }

    pub fn version(self: &const Builder, major: u32, minor: u32, patch: u32) -> Version {
        Version {
            .major = major,
            .minor = minor,
            .patch = patch,
        }
    }

    pub fn addCIncludePath(self: &Builder, path: []const u8) {
        %%self.include_paths.append(path);
    }

    pub fn addRPath(self: &Builder, path: []const u8) {
        %%self.rpaths.append(path);
    }

    pub fn addLibPath(self: &Builder, path: []const u8) {
        %%self.lib_paths.append(path);
    }

    pub fn make(self: &Builder, step_names: []const []const u8) -> %void {
        var wanted_steps = ArrayList(&Step).init(self.allocator);
        defer wanted_steps.deinit();

        if (step_names.len == 0) {
            %%wanted_steps.append(&self.default_step);
        } else {
            for (step_names) |step_name| {
                const s = %return self.getTopLevelStepByName(step_name);
                %%wanted_steps.append(s);
            }
        }

        for (wanted_steps.toSliceConst()) |s| {
            %return self.makeOneStep(s);
        }
    }

    pub fn getInstallStep(self: &Builder) -> &Step {
        if (self.have_install_step)
            return &self.install_tls.step;

        %%self.top_level_steps.append(&self.install_tls);
        self.have_install_step = true;
        return &self.install_tls.step;
    }

    pub fn getUninstallStep(self: &Builder) -> &Step {
        if (self.have_uninstall_step)
            return &self.uninstall_tls.step;

        %%self.top_level_steps.append(&self.uninstall_tls);
        self.have_uninstall_step = true;
        return &self.uninstall_tls.step;
    }

    fn makeUninstall(uninstall_step: &Step) -> %void {
        const uninstall_tls = @fieldParentPtr(TopLevelStep, "step", uninstall_step);
        const self = @fieldParentPtr(Builder, "uninstall_tls", uninstall_tls);

        for (self.installed_files.toSliceConst()) |installed_file| {
            if (self.verbose) {
                %%io.stderr.printf("rm {}\n", installed_file);
            }
            _ = os.deleteFile(self.allocator, installed_file);
        }

        // TODO remove empty directories
    }

    fn makeOneStep(self: &Builder, s: &Step) -> %void {
        if (s.loop_flag) {
            %%io.stderr.printf("Dependency loop detected:\n  {}\n", s.name);
            return error.DependencyLoopDetected;
        }
        s.loop_flag = true;

        for (s.dependencies.toSlice()) |dep| {
            self.makeOneStep(dep) %% |err| {
                if (err == error.DependencyLoopDetected) {
                    %%io.stderr.printf("  {}\n", s.name);
                }
                return err;
            };
        }

        s.loop_flag = false;

        %return s.make();
    }

    fn getTopLevelStepByName(self: &Builder, name: []const u8) -> %&Step {
        for (self.top_level_steps.toSliceConst()) |top_level_step| {
            if (mem.eql(u8, top_level_step.step.name, name)) {
                return &top_level_step.step;
            }
        }
        %%io.stderr.printf("Cannot run step '{}' because it does not exist\n", name);
        return error.InvalidStepName;
    }

    fn processNixOSEnvVars(self: &Builder) {
        if (os.getEnv("NIX_CFLAGS_COMPILE")) |nix_cflags_compile| {
            var it = mem.split(nix_cflags_compile, ' ');
            while (true) {
                const word = it.next() ?? break;
                if (mem.eql(u8, word, "-isystem")) {
                    const include_path = it.next() ?? {
                        %%io.stderr.printf("Expected argument after -isystem in NIX_CFLAGS_COMPILE\n");
                        break;
                    };
                    self.addCIncludePath(include_path);
                } else {
                    %%io.stderr.printf("Unrecognized C flag from NIX_CFLAGS_COMPILE: {}\n", word);
                    break;
                }
            }
        }
        if (os.getEnv("NIX_LDFLAGS")) |nix_ldflags| {
            var it = mem.split(nix_ldflags, ' ');
            while (true) {
                const word = it.next() ?? break;
                if (mem.eql(u8, word, "-rpath")) {
                    const rpath = it.next() ?? {
                        %%io.stderr.printf("Expected argument after -rpath in NIX_LDFLAGS\n");
                        break;
                    };
                    self.addRPath(rpath);
                } else if (word.len > 2 and word[0] == '-' and word[1] == 'L') {
                    const lib_path = word[2..];
                    self.addLibPath(lib_path);
                } else {
                    %%io.stderr.printf("Unrecognized C flag from NIX_LDFLAGS: {}\n", word);
                    break;
                }
            }
        }
    }

    pub fn option(self: &Builder, comptime T: type, name: []const u8, description: []const u8) -> ?T {
        const type_id = comptime typeToEnum(T);
        const available_option = AvailableOption {
            .name = name,
            .type_id = type_id,
            .description = description,
        };
        if (%%self.available_options_map.put(name, available_option) != null) {
            debug.panic("Option '{}' declared twice", name);
        }
        %%self.available_options_list.append(available_option);

        const entry = self.user_input_options.get(name) ?? return null;
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
                        %%io.stderr.printf("Expected -D{} to be a boolean, but received '{}'\n", name, s);
                        self.markInvalidUserInput();
                        return null;
                    }
                },
                UserValue.List => {
                    %%io.stderr.printf("Expected -D{} to be a boolean, but received a list.\n", name);
                    self.markInvalidUserInput();
                    return null;
                },
            },
            TypeId.Int => debug.panic("TODO integer options to build script"),
            TypeId.Float => debug.panic("TODO float options to build script"),
            TypeId.String => switch (entry.value.value) {
                UserValue.Flag => {
                    %%io.stderr.printf("Expected -D{} to be a string, but received a boolean.\n", name);
                    self.markInvalidUserInput();
                    return null;
                },
                UserValue.List => {
                    %%io.stderr.printf("Expected -D{} to be a string, but received a list.\n", name);
                    self.markInvalidUserInput();
                    return null;
                },
                UserValue.Scalar => |s| return s,
            },
            TypeId.List => debug.panic("TODO list options to build script"),
        }
    }

    pub fn step(self: &Builder, name: []const u8, description: []const u8) -> &Step {
        const step_info = %%self.allocator.create(TopLevelStep);
        *step_info = TopLevelStep {
            .step = Step.initNoOp(name, self.allocator),
            .description = description,
        };
        %%self.top_level_steps.append(step_info);
        return &step_info.step;
    }

    pub fn standardReleaseOptions(self: &Builder) -> builtin.Mode {
        if (self.release_mode) |mode| return mode;

        const release_safe = self.option(bool, "release-safe", "optimizations on and safety on") ?? false;
        const release_fast = self.option(bool, "release-fast", "optimizations on and safety off") ?? false;

        const mode = if (release_safe and !release_fast) {
            builtin.Mode.ReleaseSafe
        } else if (release_fast and !release_safe) {
            builtin.Mode.ReleaseFast
        } else if (!release_fast and !release_safe) {
            builtin.Mode.Debug
        } else {
            %%io.stderr.printf("Both -Drelease-safe and -Drelease-fast specified");
            self.markInvalidUserInput();
            builtin.Mode.Debug
        };
        self.release_mode = mode;
        return mode;
    }

    pub fn addUserInputOption(self: &Builder, name: []const u8, value: []const u8) -> bool {
        if (%%self.user_input_options.put(name, UserInputOption {
            .name = name,
            .value = UserValue.Scalar { value },
            .used = false,
        })) |*prev_value| {
            // option already exists
            switch (prev_value.value) {
                UserValue.Scalar => |s| {
                    // turn it into a list
                    var list = ArrayList([]const u8).init(self.allocator);
                    %%list.append(s);
                    %%list.append(value);
                    _ = %%self.user_input_options.put(name, UserInputOption {
                        .name = name,
                        .value = UserValue.List { list },
                        .used = false,
                    });
                },
                UserValue.List => |*list| {
                    // append to the list
                    %%list.append(value);
                    _ = %%self.user_input_options.put(name, UserInputOption {
                        .name = name,
                        .value = UserValue.List { *list },
                        .used = false,
                    });
                },
                UserValue.Flag => {
                    %%io.stderr.printf("Option '-D{}={}' conflicts with flag '-D{}'.\n", name, value, name);
                    return true;
                },
            }
        }
        return false;
    }

    pub fn addUserInputFlag(self: &Builder, name: []const u8) -> bool {
        if (%%self.user_input_options.put(name, UserInputOption {
            .name = name,
            .value = UserValue.Flag,
            .used = false,
        })) |*prev_value| {
            switch (prev_value.value) {
                UserValue.Scalar => |s| {
                    %%io.stderr.printf("Flag '-D{}' conflicts with option '-D{}={}'.\n", name, name, s);
                    return true;
                },
                UserValue.List => {
                    %%io.stderr.printf("Flag '-D{}' conflicts with multiple options of the same name.\n", name);
                    return true;
                },
                UserValue.Flag => {},
            }
        }
        return false;
    }

    fn typeToEnum(comptime T: type) -> TypeId {
        switch (@typeId(T)) {
            builtin.TypeId.Int => TypeId.Int,
            builtin.TypeId.Float => TypeId.Float,
            builtin.TypeId.Bool => TypeId.Bool,
            else => switch (T) {
                []const u8 => TypeId.String,
                []const []const u8 => TypeId.List,
                else => @compileError("Unsupported type: " ++ @typeName(T)),
            },
        }
    }

    fn markInvalidUserInput(self: &Builder) {
        self.invalid_user_input = true;
    }

    pub fn typeIdName(id: TypeId) -> []const u8 {
        return switch (id) {
            TypeId.Bool => "bool",
            TypeId.Int => "int",
            TypeId.Float => "float",
            TypeId.String => "string",
            TypeId.List => "list",
        };
    }

    pub fn validateUserInputDidItFail(self: &Builder) -> bool {
        // make sure all args are used
        var it = self.user_input_options.iterator();
        while (true) {
            const entry = it.next() ?? break;
            if (!entry.value.used) {
                %%io.stderr.printf("Invalid option: -D{}\n\n", entry.key);
                self.markInvalidUserInput();
            }
        }

        return self.invalid_user_input;
    }

    fn spawnChild(self: &Builder, exe_path: []const u8, args: []const []const u8) -> %void {
        return self.spawnChildEnvMap(null, &self.env_map, exe_path, args);
    }

    fn spawnChildEnvMap(self: &Builder, cwd: ?[]const u8, env_map: &const BufMap,
        exe_path: []const u8, args: []const []const u8) -> %void
    {
        if (self.verbose) {
            if (cwd) |yes_cwd| %%io.stderr.print("cd {}; ", yes_cwd);
            %%io.stderr.print("{}", exe_path);
            for (args) |arg| {
                %%io.stderr.print(" {}", arg);
            }
            %%io.stderr.printf("\n");
        }

        var child = os.ChildProcess.spawn(exe_path, args, cwd, env_map,
            StdIo.Inherit, StdIo.Inherit, StdIo.Inherit, null, self.allocator) %% |err|
        {
            %%io.stderr.printf("Unable to spawn {}: {}\n", exe_path, @errorName(err));
            return err;
        };

        const term = child.wait() %% |err| {
            %%io.stderr.printf("Unable to spawn {}: {}\n", exe_path, @errorName(err));
            return err;
        };
        switch (term) {
            Term.Exited => |code| {
                if (code != 0) {
                    %%io.stderr.printf("Process {} exited with error code {}\n", exe_path, code);
                    return error.UncleanExit;
                }
            },
            else => {
                %%io.stderr.printf("Process {} terminated unexpectedly\n", exe_path);
                return error.UncleanExit;
            },
        };

    }

    pub fn makePath(self: &Builder, path: []const u8) -> %void {
        os.makePath(self.allocator, self.pathFromRoot(path)) %% |err| {
            %%io.stderr.printf("Unable to create path {}: {}\n", path, @errorName(err));
            return err;
        };
    }

    pub fn installArtifact(self: &Builder, artifact: &LibExeObjStep) {
        self.getInstallStep().dependOn(&self.addInstallArtifact(artifact).step);
    }

    pub fn addInstallArtifact(self: &Builder, artifact: &LibExeObjStep) -> &InstallArtifactStep {
        return InstallArtifactStep.create(self, artifact);
    }

    ///::dest_rel_path is relative to prefix path or it can be an absolute path
    pub fn installFile(self: &Builder, src_path: []const u8, dest_rel_path: []const u8) {
        self.getInstallStep().dependOn(&self.addInstallFile(src_path, dest_rel_path).step);
    }

    ///::dest_rel_path is relative to prefix path or it can be an absolute path
    pub fn addInstallFile(self: &Builder, src_path: []const u8, dest_rel_path: []const u8) -> &InstallFileStep {
        const full_dest_path = %%os.path.resolve(self.allocator, self.prefix, dest_rel_path);
        self.pushInstalledFile(full_dest_path);

        const install_step = %%self.allocator.create(InstallFileStep);
        *install_step = InstallFileStep.init(self, src_path, full_dest_path);
        return install_step;
    }

    pub fn pushInstalledFile(self: &Builder, full_path: []const u8) {
        _ = self.getUninstallStep();
        %%self.installed_files.append(full_path);
    }

    fn copyFile(self: &Builder, source_path: []const u8, dest_path: []const u8) -> %void {
        return self.copyFileMode(source_path, dest_path, 0o666);
    }

    fn copyFileMode(self: &Builder, source_path: []const u8, dest_path: []const u8, mode: usize) -> %void {
        if (self.verbose) {
            %%io.stderr.printf("cp {} {}\n", source_path, dest_path);
        }

        const dirname = os.path.dirname(dest_path);
        const abs_source_path = self.pathFromRoot(source_path);
        os.makePath(self.allocator, dirname) %% |err| {
            %%io.stderr.printf("Unable to create path {}: {}\n", dirname, @errorName(err));
            return err;
        };
        os.copyFileMode(self.allocator, abs_source_path, dest_path, mode) %% |err| {
            %%io.stderr.printf("Unable to copy {} to {}: {}\n", abs_source_path, dest_path, @errorName(err));
            return err;
        };
    }

    fn pathFromRoot(self: &Builder, rel_path: []const u8) -> []u8 {
        return %%os.path.resolve(self.allocator, self.build_root, rel_path);
    }

    pub fn fmt(self: &Builder, comptime format: []const u8, args: ...) -> []u8 {
        return %%fmt_lib.allocPrint(self.allocator, format, args);
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

const Target = enum {
    Native,
    Cross: CrossTarget,

    pub fn oFileExt(self: &const Target) -> []const u8 {
        const environ = switch (*self) {
            Target.Native => builtin.environ,
            Target.Cross => |t| t.environ,
        };
        return switch (environ) {
            builtin.Environ.msvc => ".obj",
            else => ".o",
        };
    }

    pub fn exeFileExt(self: &const Target) -> []const u8 {
        const target_os = switch (*self) {
            Target.Native => builtin.os,
            Target.Cross => |t| t.os,
        };
        return switch (target_os) {
            builtin.Os.windows => ".exe",
            else => "",
        };
    }
};

pub const LibExeObjStep = struct {
    step: Step,
    builder: &Builder,
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
    disable_libc: bool,

    // zig only stuff
    root_src: ?[]const u8,
    verbose: bool,
    output_h_path: ?[]const u8,
    out_h_filename: []const u8,
    assembly_files: ArrayList([]const u8),
    packages: ArrayList(Pkg),

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

    pub fn createSharedLibrary(builder: &Builder, name: []const u8, root_src: ?[]const u8,
        ver: &const Version) -> &LibExeObjStep
    {
        const self = %%builder.allocator.create(LibExeObjStep);
        *self = initExtraArgs(builder, name, root_src, Kind.Lib, false, ver);
        return self;
    }

    pub fn createCSharedLibrary(builder: &Builder, name: []const u8, version: &const Version) -> &LibExeObjStep {
        const self = %%builder.allocator.create(LibExeObjStep);
        *self = initC(builder, name, Kind.Lib, version, false);
        return self;
    }

    pub fn createStaticLibrary(builder: &Builder, name: []const u8, root_src: ?[]const u8) -> &LibExeObjStep {
        const self = %%builder.allocator.create(LibExeObjStep);
        *self = initExtraArgs(builder, name, root_src, Kind.Lib, true, builder.version(0, 0, 0));
        return self;
    }

    pub fn createCStaticLibrary(builder: &Builder, name: []const u8) -> &LibExeObjStep {
        const self = %%builder.allocator.create(LibExeObjStep);
        *self = initC(builder, name, Kind.Lib, builder.version(0, 0, 0), true);
        return self;
    }

    pub fn createObject(builder: &Builder, name: []const u8, root_src: []const u8) -> &LibExeObjStep {
        const self = %%builder.allocator.create(LibExeObjStep);
        *self = initExtraArgs(builder, name, root_src, Kind.Obj, false, builder.version(0, 0, 0));
        return self;
    }

    pub fn createCObject(builder: &Builder, name: []const u8, src: []const u8) -> &LibExeObjStep {
        const self = %%builder.allocator.create(LibExeObjStep);
        *self = initC(builder, name, Kind.Obj, builder.version(0, 0, 0), false);
        self.object_src = src;
        return self;
    }

    pub fn createExecutable(builder: &Builder, name: []const u8, root_src: ?[]const u8) -> &LibExeObjStep {
        const self = %%builder.allocator.create(LibExeObjStep);
        *self = initExtraArgs(builder, name, root_src, Kind.Exe, false, builder.version(0, 0, 0));
        return self;
    }

    pub fn createCExecutable(builder: &Builder, name: []const u8) -> &LibExeObjStep {
        const self = %%builder.allocator.create(LibExeObjStep);
        *self = initC(builder, name, Kind.Exe, builder.version(0, 0, 0), false);
        return self;
    }

    fn initExtraArgs(builder: &Builder, name: []const u8, root_src: ?[]const u8, kind: Kind,
        static: bool, ver: &const Version) -> LibExeObjStep
    {
        var self = LibExeObjStep {
            .strip = false,
            .builder = builder,
            .verbose = false,
            .build_mode = builtin.Mode.Debug,
            .static = static,
            .kind = kind,
            .root_src = root_src,
            .name = name,
            .target = Target.Native,
            .linker_script = null,
            .link_libs = BufSet.init(builder.allocator),
            .step = Step.init(name, builder.allocator, make),
            .output_path = null,
            .output_h_path = null,
            .version = *ver,
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
            .object_src = undefined,
            .disable_libc = true,
        };
        self.computeOutFileNames();
        return self;
    }

    fn initC(builder: &Builder, name: []const u8, kind: Kind, version: &const Version, static: bool) -> LibExeObjStep {
        var self = LibExeObjStep {
            .builder = builder,
            .name = name,
            .kind = kind,
            .version = *version,
            .static = static,
            .target = Target.Native,
            .cflags = ArrayList([]const u8).init(builder.allocator),
            .source_files = ArrayList([]const u8).init(builder.allocator),
            .object_files = ArrayList([]const u8).init(builder.allocator),
            .step = Step.init(name, builder.allocator, make),
            .link_libs = BufSet.init(builder.allocator),
            .full_path_libs = ArrayList([]const u8).init(builder.allocator),
            .include_dirs = ArrayList([]const u8).init(builder.allocator),
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
            .verbose = undefined,
            .output_h_path = undefined,
            .out_h_filename = undefined,
            .assembly_files = undefined,
            .packages = undefined,
        };
        self.computeOutFileNames();
        return self;
    }

    fn computeOutFileNames(self: &LibExeObjStep) {
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
                    const target_os = switch (self.target) {
                        Target.Native => builtin.os,
                        Target.Cross => |t| t.os,
                    };
                    switch (target_os) {
                        builtin.Os.darwin, builtin.Os.ios, builtin.Os.macosx => {
                            self.out_filename = self.builder.fmt("lib{}.dylib.{d}.{d}.{d}",
                                self.name, self.version.major, self.version.minor, self.version.patch);
                            self.major_only_filename = self.builder.fmt("lib{}.dylib.{d}", self.name, self.version.major);
                            self.name_only_filename = self.builder.fmt("lib{}.dylib", self.name);
                        },
                        builtin.Os.windows => {
                            self.out_filename = self.builder.fmt("lib{}.dll", self.name);
                        },
                        else => {
                            self.out_filename = self.builder.fmt("lib{}.so.{d}.{d}.{d}",
                                self.name, self.version.major, self.version.minor, self.version.patch);
                            self.major_only_filename = self.builder.fmt("lib{}.so.{d}", self.name, self.version.major);
                            self.name_only_filename = self.builder.fmt("lib{}.so", self.name);
                        },
                    }
                }
            },
        }
    }

    pub fn setTarget(self: &LibExeObjStep, target_arch: builtin.Arch, target_os: builtin.Os,
        target_environ: builtin.Environ)
    {
        self.target = Target.Cross {
            CrossTarget {
                .arch = target_arch,
                .os = target_os,
                .environ = target_environ,
            }
        };
        self.computeOutFileNames();
    }

    // TODO respect this in the C args
    pub fn setLinkerScriptPath(self: &LibExeObjStep, path: []const u8) {
        self.linker_script = path;
    }

    pub fn linkLibrary(self: &LibExeObjStep, lib: &LibExeObjStep) {
        assert(self.kind != Kind.Obj);
        assert(lib.kind == Kind.Lib);

        self.step.dependOn(&lib.step);

        %%self.full_path_libs.append(lib.getOutputPath());

        // TODO should be some kind of isolated directory that only has this header in it
        %%self.include_dirs.append(self.builder.cache_root);
        self.need_flat_namespace_hack = true;
    }

    pub fn linkSystemLibrary(self: &LibExeObjStep, name: []const u8) {
        assert(self.kind != Kind.Obj);
        %%self.link_libs.put(name);
    }

    pub fn addSourceFile(self: &LibExeObjStep, file: []const u8) {
        assert(self.kind != Kind.Obj);
        assert(!self.is_zig);
        %%self.source_files.append(file);
    }

    pub fn setVerbose(self: &LibExeObjStep, value: bool) {
        self.verbose = value;
    }

    pub fn setBuildMode(self: &LibExeObjStep, mode: builtin.Mode) {
        self.build_mode = mode;
    }

    pub fn setOutputPath(self: &LibExeObjStep, file_path: []const u8) {
        self.output_path = file_path;

        // catch a common mistake
        if (mem.eql(u8, self.builder.pathFromRoot(file_path), self.builder.pathFromRoot("."))) {
            debug.panic("setOutputPath wants a file path, not a directory\n");
        }
    }

    pub fn getOutputPath(self: &LibExeObjStep) -> []const u8 {
        if (self.output_path) |output_path| {
            output_path
        } else {
            %%os.path.join(self.builder.allocator, self.builder.cache_root, self.out_filename)
        }
    }

    pub fn setOutputHPath(self: &LibExeObjStep, file_path: []const u8) {
        self.output_h_path = file_path;

        // catch a common mistake
        if (mem.eql(u8, self.builder.pathFromRoot(file_path), self.builder.pathFromRoot("."))) {
            debug.panic("setOutputHPath wants a file path, not a directory\n");
        }
    }

    pub fn getOutputHPath(self: &LibExeObjStep) -> []const u8 {
        if (self.output_h_path) |output_h_path| {
            output_h_path
        } else {
            %%os.path.join(self.builder.allocator, self.builder.cache_root, self.out_h_filename)
        }
    }

    pub fn addAssemblyFile(self: &LibExeObjStep, path: []const u8) {
        %%self.assembly_files.append(path);
    }

    pub fn addObjectFile(self: &LibExeObjStep, path: []const u8) {
        assert(self.kind != Kind.Obj);

        %%self.object_files.append(path);
    }

    pub fn addObject(self: &LibExeObjStep, obj: &LibExeObjStep) {
        assert(obj.kind == Kind.Obj);
        assert(self.kind != Kind.Obj);

        self.step.dependOn(&obj.step);

        %%self.object_files.append(obj.getOutputPath());

        // TODO make this lazy instead of stateful
        if (!obj.disable_libc) {
            self.disable_libc = false;
        }

        // TODO should be some kind of isolated directory that only has this header in it
        %%self.include_dirs.append(self.builder.cache_root);
    }

    // TODO put include_dirs in zig command line
    pub fn addIncludeDir(self: &LibExeObjStep, path: []const u8) {
        %%self.include_dirs.append(path);
    }

    pub fn addPackagePath(self: &LibExeObjStep, name: []const u8, pkg_index_path: []const u8) {
        assert(self.is_zig);

        %%self.packages.append(Pkg {
            .name = name,
            .path = pkg_index_path,
        });
    }

    pub fn addCompileFlags(self: &LibExeObjStep, flags: []const []const u8) {
        for (flags) |flag| {
            %%self.cflags.append(flag);
        }
    }

    pub fn setNoStdLib(self: &LibExeObjStep, disable: bool) {
        assert(!self.is_zig);
        self.disable_libc = disable;
    }

    fn make(step: &Step) -> %void {
        const self = @fieldParentPtr(LibExeObjStep, "step", step);
        return if (self.is_zig) self.makeZig() else self.makeC();
    }

    fn makeZig(self: &LibExeObjStep) -> %void {
        const builder = self.builder;

        assert(self.is_zig);

        if (self.root_src == null and self.object_files.len == 0 and self.assembly_files.len == 0) {
            %%io.stderr.printf("{}: linker needs 1 or more objects to link\n", self.step.name);
            return error.NeedAnObject;
        }

        var zig_args = ArrayList([]const u8).init(builder.allocator);
        defer zig_args.deinit();

        const cmd = switch (self.kind) {
            Kind.Lib => "build-lib",
            Kind.Exe => "build-exe",
            Kind.Obj => "build-obj",
        };
        %%zig_args.append(cmd);

        if (self.root_src) |root_src| {
            %%zig_args.append(builder.pathFromRoot(root_src));
        }

        for (self.object_files.toSliceConst()) |object_file| {
            %%zig_args.append("--object");
            %%zig_args.append(builder.pathFromRoot(object_file));
        }

        for (self.assembly_files.toSliceConst()) |asm_file| {
            %%zig_args.append("--assembly");
            %%zig_args.append(builder.pathFromRoot(asm_file));
        }

        if (self.verbose) {
            %%zig_args.append("--verbose");
        }

        if (self.strip) {
            %%zig_args.append("--strip");
        }

        switch (self.build_mode) {
            builtin.Mode.Debug => {},
            builtin.Mode.ReleaseSafe => %%zig_args.append("--release-safe"),
            builtin.Mode.ReleaseFast => %%zig_args.append("--release-fast"),
        }

        %%zig_args.append("--cache-dir");
        %%zig_args.append(builder.pathFromRoot(builder.cache_root));

        const output_path = builder.pathFromRoot(self.getOutputPath());
        %%zig_args.append("--output");
        %%zig_args.append(output_path);

        if (self.kind != Kind.Exe) {
            const output_h_path = self.getOutputHPath();
            %%zig_args.append("--output-h");
            %%zig_args.append(builder.pathFromRoot(output_h_path));
        }

        %%zig_args.append("--name");
        %%zig_args.append(self.name);

        if (self.kind == Kind.Lib and !self.static) {
            %%zig_args.append("--ver-major");
            %%zig_args.append(builder.fmt("{}", self.version.major));

            %%zig_args.append("--ver-minor");
            %%zig_args.append(builder.fmt("{}", self.version.minor));

            %%zig_args.append("--ver-patch");
            %%zig_args.append(builder.fmt("{}", self.version.patch));
        }

        switch (self.target) {
            Target.Native => {},
            Target.Cross => |cross_target| {
                %%zig_args.append("--target-arch");
                %%zig_args.append(@enumTagName(cross_target.arch));

                %%zig_args.append("--target-os");
                %%zig_args.append(@enumTagName(cross_target.os));

                %%zig_args.append("--target-environ");
                %%zig_args.append(@enumTagName(cross_target.environ));
            },
        }

        if (self.linker_script) |linker_script| {
            %%zig_args.append("--linker-script");
            %%zig_args.append(linker_script);
        }

        {
            var it = self.link_libs.iterator();
            while (true) {
                const entry = it.next() ?? break;
                %%zig_args.append("--library");
                %%zig_args.append(entry.key);
            }
        }

        if (!self.disable_libc) {
            %%zig_args.append("--library");
            %%zig_args.append("c");
        }

        for (self.packages.toSliceConst()) |pkg| {
            %%zig_args.append("--pkg-begin");
            %%zig_args.append(pkg.name);
            %%zig_args.append(builder.pathFromRoot(pkg.path));
            %%zig_args.append("--pkg-end");
        }

        for (builder.include_paths.toSliceConst()) |include_path| {
            %%zig_args.append("-isystem");
            %%zig_args.append(builder.pathFromRoot(include_path));
        }

        for (builder.rpaths.toSliceConst()) |rpath| {
            %%zig_args.append("-rpath");
            %%zig_args.append(rpath);
        }

        for (builder.lib_paths.toSliceConst()) |lib_path| {
            %%zig_args.append("--library-path");
            %%zig_args.append(lib_path);
        }

        for (self.full_path_libs.toSliceConst()) |full_path_lib| {
            %%zig_args.append("--library");
            %%zig_args.append(builder.pathFromRoot(full_path_lib));
        }

        %return builder.spawnChild(builder.zig_exe, zig_args.toSliceConst());

        if (self.kind == Kind.Lib and !self.static) {
            %return doAtomicSymLinks(builder.allocator, output_path, self.major_only_filename,
                self.name_only_filename);
        }
    }

    fn appendCompileFlags(self: &LibExeObjStep, args: &ArrayList([]const u8)) {
        if (!self.strip) {
            %%args.append("-g");
        }
        switch (self.build_mode) {
            builtin.Mode.Debug => {
                if (self.disable_libc) {
                    %%args.append("-fno-stack-protector");
                } else {
                    %%args.append("-fstack-protector-strong");
                    %%args.append("--param");
                    %%args.append("ssp-buffer-size=4");
                }
            },
            builtin.Mode.ReleaseSafe => {
                %%args.append("-O2");
                if (self.disable_libc) {
                    %%args.append("-fno-stack-protector");
                } else {
                    %%args.append("-D_FORTIFY_SOURCE=2");
                    %%args.append("-fstack-protector-strong");
                    %%args.append("--param");
                    %%args.append("ssp-buffer-size=4");
                }
            },
            builtin.Mode.ReleaseFast => {
                %%args.append("-O2");
                %%args.append("-fno-stack-protector");
            },
        }

        for (self.include_dirs.toSliceConst()) |dir| {
            %%args.append("-I");
            %%args.append(self.builder.pathFromRoot(dir));
        }

        for (self.cflags.toSliceConst()) |cflag| {
            %%args.append(cflag);
        }

        if (self.disable_libc) {
            %%args.append("-nostdlib");
        }
    }

    fn makeC(self: &LibExeObjStep) -> %void {
        const cc = os.getEnv("CC") ?? "cc";
        const builder = self.builder;

        assert(!self.is_zig);

        var cc_args = ArrayList([]const u8).init(builder.allocator);
        defer cc_args.deinit();

        switch (self.kind) {
            Kind.Obj => {
                %%cc_args.append("-c");
                %%cc_args.append(builder.pathFromRoot(self.object_src));

                const output_path = builder.pathFromRoot(self.getOutputPath());
                %%cc_args.append("-o");
                %%cc_args.append(output_path);

                self.appendCompileFlags(&cc_args);

                %return builder.spawnChild(cc, cc_args.toSliceConst());
            },
            Kind.Lib => {
                for (self.source_files.toSliceConst()) |source_file| {
                    %%cc_args.resize(0);

                    if (!self.static) {
                        %%cc_args.append("-fPIC");
                    }

                    const abs_source_file = builder.pathFromRoot(source_file);
                    %%cc_args.append("-c");
                    %%cc_args.append(abs_source_file);

                    const cache_o_src = %%os.path.join(builder.allocator, builder.cache_root, source_file);
                    const cache_o_dir = os.path.dirname(cache_o_src);
                    %return builder.makePath(cache_o_dir);
                    const cache_o_file = builder.fmt("{}{}", cache_o_src, self.target.oFileExt());
                    %%cc_args.append("-o");
                    %%cc_args.append(builder.pathFromRoot(cache_o_file));

                    self.appendCompileFlags(&cc_args);

                    %return builder.spawnChild(cc, cc_args.toSliceConst());

                    %%self.object_files.append(cache_o_file);
                }

                if (self.static) {
                    // ar
                    %%cc_args.resize(0);
                    %%cc_args.append("qc");

                    const output_path = builder.pathFromRoot(self.getOutputPath());
                    %%cc_args.append(output_path);

                    for (self.object_files.toSliceConst()) |object_file| {
                        %%cc_args.append(builder.pathFromRoot(object_file));
                    }

                    %return builder.spawnChild("ar", cc_args.toSliceConst());

                    // ranlib
                    %%cc_args.resize(0);
                    %%cc_args.append(output_path);

                    %return builder.spawnChild("ranlib", cc_args.toSliceConst());
                } else {
                    %%cc_args.resize(0);

                    %%cc_args.append("-fPIC");
                    %%cc_args.append("-shared");

                    const soname_arg = builder.fmt("-Wl,-soname,lib{}.so.{d}", self.name, self.version.major);
                    defer builder.allocator.free(soname_arg);
                    %%cc_args.append(soname_arg);

                    const output_path = builder.pathFromRoot(self.getOutputPath());
                    %%cc_args.append("-o");
                    %%cc_args.append(output_path);

                    for (self.object_files.toSliceConst()) |object_file| {
                        %%cc_args.append(builder.pathFromRoot(object_file));
                    }

                    const rpath_arg = builder.fmt("-Wl,-rpath,{}",
                        %%os.path.real(builder.allocator, builder.pathFromRoot(builder.cache_root)));
                    defer builder.allocator.free(rpath_arg);
                    %%cc_args.append(rpath_arg);

                    %%cc_args.append("-rdynamic");

                    for (self.full_path_libs.toSliceConst()) |full_path_lib| {
                        %%cc_args.append(builder.pathFromRoot(full_path_lib));
                    }

                    %return builder.spawnChild(cc, cc_args.toSliceConst());

                    %return doAtomicSymLinks(builder.allocator, output_path, self.major_only_filename,
                        self.name_only_filename);
                }
            },
            Kind.Exe => {
                for (self.source_files.toSliceConst()) |source_file| {
                    %%cc_args.resize(0);

                    const abs_source_file = builder.pathFromRoot(source_file);
                    %%cc_args.append("-c");
                    %%cc_args.append(abs_source_file);

                    const cache_o_src = %%os.path.join(builder.allocator, builder.cache_root, source_file);
                    const cache_o_dir = os.path.dirname(cache_o_src);
                    %return builder.makePath(cache_o_dir);
                    const cache_o_file = builder.fmt("{}{}", cache_o_src, self.target.oFileExt());
                    %%cc_args.append("-o");
                    %%cc_args.append(builder.pathFromRoot(cache_o_file));

                    for (self.cflags.toSliceConst()) |cflag| {
                        %%cc_args.append(cflag);
                    }

                    for (self.include_dirs.toSliceConst()) |dir| {
                        %%cc_args.append("-I");
                        %%cc_args.append(builder.pathFromRoot(dir));
                    }

                    %return builder.spawnChild(cc, cc_args.toSliceConst());

                    %%self.object_files.append(cache_o_file);
                }

                %%cc_args.resize(0);

                for (self.object_files.toSliceConst()) |object_file| {
                    %%cc_args.append(builder.pathFromRoot(object_file));
                }

                const output_path = builder.pathFromRoot(self.getOutputPath());
                %%cc_args.append("-o");
                %%cc_args.append(output_path);

                const rpath_arg = builder.fmt("-Wl,-rpath,{}",
                    %%os.path.real(builder.allocator, builder.pathFromRoot(builder.cache_root)));
                defer builder.allocator.free(rpath_arg);
                %%cc_args.append(rpath_arg);

                %%cc_args.append("-rdynamic");

                const target_os = switch (self.target) {
                    Target.Native => builtin.os,
                    Target.Cross => |t| t.os,
                };
                switch (target_os) {
                    builtin.Os.darwin, builtin.Os.ios, builtin.Os.macosx => {
                        if (self.need_flat_namespace_hack) {
                            %%cc_args.append("-Wl,-flat_namespace");
                        }
                        %%cc_args.append("-Wl,-search_paths_first");
                    },
                    else => {}
                }

                for (self.full_path_libs.toSliceConst()) |full_path_lib| {
                    %%cc_args.append(builder.pathFromRoot(full_path_lib));
                }

                %return builder.spawnChild(cc, cc_args.toSliceConst());
            },
        }
    }
};

pub const TestStep = struct {
    step: Step,
    builder: &Builder,
    root_src: []const u8,
    build_mode: builtin.Mode,
    verbose: bool,
    link_libs: BufSet,
    name_prefix: []const u8,
    filter: ?[]const u8,
    target: Target,
    exec_cmd_args: ?[]const ?[]const u8,

    pub fn init(builder: &Builder, root_src: []const u8) -> TestStep {
        const step_name = builder.fmt("test {}", root_src);
        TestStep {
            .step = Step.init(step_name, builder.allocator, make),
            .builder = builder,
            .root_src = root_src,
            .build_mode = builtin.Mode.Debug,
            .verbose = false,
            .name_prefix = "",
            .filter = null,
            .link_libs = BufSet.init(builder.allocator),
            .target = Target.Native,
            .exec_cmd_args = null,
        }
    }

    pub fn setVerbose(self: &TestStep, value: bool) {
        self.verbose = value;
    }

    pub fn setBuildMode(self: &TestStep, mode: builtin.Mode) {
        self.build_mode = mode;
    }

    pub fn linkSystemLibrary(self: &TestStep, name: []const u8) {
        %%self.link_libs.put(name);
    }

    pub fn setNamePrefix(self: &TestStep, text: []const u8) {
        self.name_prefix = text;
    }

    pub fn setFilter(self: &TestStep, text: ?[]const u8) {
        self.filter = text;
    }

    pub fn setTarget(self: &TestStep, target_arch: builtin.Arch, target_os: builtin.Os,
        target_environ: builtin.Environ)
    {
        self.target = Target.Cross {
            CrossTarget {
                .arch = target_arch,
                .os = target_os,
                .environ = target_environ,
            }
        };
    }

    pub fn setExecCmd(self: &TestStep, args: []const ?[]const u8) {
        self.exec_cmd_args = args;
    }

    fn make(step: &Step) -> %void {
        const self = @fieldParentPtr(TestStep, "step", step);
        const builder = self.builder;

        var zig_args = ArrayList([]const u8).init(builder.allocator);
        defer zig_args.deinit();

        %%zig_args.append("test");
        %%zig_args.append(builder.pathFromRoot(self.root_src));

        if (self.verbose) {
            %%zig_args.append("--verbose");
        }

        switch (self.build_mode) {
            builtin.Mode.Debug => {},
            builtin.Mode.ReleaseSafe => %%zig_args.append("--release-safe"),
            builtin.Mode.ReleaseFast => %%zig_args.append("--release-fast"),
        }

        switch (self.target) {
            Target.Native => {},
            Target.Cross => |cross_target| {
                %%zig_args.append("--target-arch");
                %%zig_args.append(@enumTagName(cross_target.arch));

                %%zig_args.append("--target-os");
                %%zig_args.append(@enumTagName(cross_target.os));

                %%zig_args.append("--target-environ");
                %%zig_args.append(@enumTagName(cross_target.environ));
            },
        }

        if (self.filter) |filter| {
            %%zig_args.append("--test-filter");
            %%zig_args.append(filter);
        }

        if (self.name_prefix.len != 0) {
            %%zig_args.append("--test-name-prefix");
            %%zig_args.append(self.name_prefix);
        }

        {
            var it = self.link_libs.iterator();
            while (true) {
                const entry = it.next() ?? break;
                %%zig_args.append("--library");
                %%zig_args.append(entry.key);
            }
        }

        if (self.exec_cmd_args) |exec_cmd_args| {
            for (exec_cmd_args) |cmd_arg| {
                if (cmd_arg) |arg| {
                    %%zig_args.append("--test-cmd");
                    %%zig_args.append(arg);
                } else {
                    %%zig_args.append("--test-cmd-bin");
                }
            }
        }

        for (builder.include_paths.toSliceConst()) |include_path| {
            %%zig_args.append("-isystem");
            %%zig_args.append(builder.pathFromRoot(include_path));
        }

        for (builder.rpaths.toSliceConst()) |rpath| {
            %%zig_args.append("-rpath");
            %%zig_args.append(rpath);
        }

        for (builder.lib_paths.toSliceConst()) |lib_path| {
            %%zig_args.append("--library-path");
            %%zig_args.append(lib_path);
        }

        %return builder.spawnChild(builder.zig_exe, zig_args.toSliceConst());
    }
};

pub const CommandStep = struct {
    step: Step,
    builder: &Builder,
    exe_path: []const u8,
    args: [][]const u8,
    cwd: ?[]const u8,
    env_map: &const BufMap,

    /// ::args are copied.
    pub fn create(builder: &Builder, cwd: ?[]const u8, env_map: &const BufMap,
        exe_path: []const u8, args: []const []const u8) -> &CommandStep
    {
        const self = %%builder.allocator.create(CommandStep);
        *self = CommandStep {
            .builder = builder,
            .step = Step.init(exe_path, builder.allocator, make),
            .exe_path = exe_path,
            .args = %%builder.allocator.alloc([]u8, args.len),
            .cwd = cwd,
            .env_map = env_map,
        };
        mem.copy([]const u8, self.args, args);
        return self;
    }

    fn make(step: &Step) -> %void {
        const self = @fieldParentPtr(CommandStep, "step", step);

        const cwd = if (self.cwd) |cwd| self.builder.pathFromRoot(cwd) else null;
        return self.builder.spawnChildEnvMap(cwd, self.env_map, self.exe_path, self.args);
    }
};

const InstallArtifactStep = struct {
    step: Step,
    builder: &Builder,
    artifact: &LibExeObjStep,
    dest_file: []const u8,

    const Self = this;

    pub fn create(builder: &Builder, artifact: &LibExeObjStep) -> &Self {
        const self = %%builder.allocator.create(Self);
        const dest_dir = switch (artifact.kind) {
            LibExeObjStep.Kind.Obj => unreachable,
            LibExeObjStep.Kind.Exe => builder.exe_dir,
            LibExeObjStep.Kind.Lib => builder.lib_dir,
        };
        *self = Self {
            .builder = builder,
            .step = Step.init(builder.fmt("install {}", artifact.step.name), builder.allocator, make),
            .artifact = artifact,
            .dest_file = %%os.path.join(builder.allocator, dest_dir, artifact.out_filename),
        };
        self.step.dependOn(&artifact.step);
        builder.pushInstalledFile(self.dest_file);
        if (self.artifact.kind == LibExeObjStep.Kind.Lib and !self.artifact.static) {
            builder.pushInstalledFile(%%os.path.join(builder.allocator, builder.lib_dir,
                artifact.major_only_filename));
            builder.pushInstalledFile(%%os.path.join(builder.allocator, builder.lib_dir,
                artifact.name_only_filename));
        }
        return self;
    }

    fn make(step: &Step) -> %void {
        const self = @fieldParentPtr(Self, "step", step);
        const builder = self.builder;

        const mode = switch (self.artifact.kind) {
            LibExeObjStep.Kind.Obj => unreachable,
            LibExeObjStep.Kind.Exe => usize(0o755),
            LibExeObjStep.Kind.Lib => if (self.artifact.static) usize(0o666) else usize(0o755),
        };
        %return builder.copyFileMode(self.artifact.getOutputPath(), self.dest_file, mode);
        if (self.artifact.kind == LibExeObjStep.Kind.Lib and !self.artifact.static) {
            %return doAtomicSymLinks(builder.allocator, self.dest_file,
                self.artifact.major_only_filename, self.artifact.name_only_filename);
        }
    }
};

pub const InstallFileStep = struct {
    step: Step,
    builder: &Builder,
    src_path: []const u8,
    dest_path: []const u8,

    pub fn init(builder: &Builder, src_path: []const u8, dest_path: []const u8) -> InstallFileStep {
        return InstallFileStep {
            .builder = builder,
            .step = Step.init(builder.fmt("install {}", src_path), builder.allocator, make),
            .src_path = src_path,
            .dest_path = dest_path,
        };
    }

    fn make(step: &Step) -> %void {
        const self = @fieldParentPtr(InstallFileStep, "step", step);
        %return self.builder.copyFile(self.src_path, self.dest_path);
    }
};

pub const WriteFileStep = struct {
    step: Step,
    builder: &Builder,
    file_path: []const u8,
    data: []const u8,

    pub fn init(builder: &Builder, file_path: []const u8, data: []const u8) -> WriteFileStep {
        return WriteFileStep {
            .builder = builder,
            .step = Step.init(builder.fmt("writefile {}", file_path), builder.allocator, make),
            .file_path = file_path,
            .data = data,
        };
    }

    fn make(step: &Step) -> %void {
        const self = @fieldParentPtr(WriteFileStep, "step", step);
        const full_path = self.builder.pathFromRoot(self.file_path);
        const full_path_dir = os.path.dirname(full_path);
        os.makePath(self.builder.allocator, full_path_dir) %% |err| {
            %%io.stderr.printf("unable to make path {}: {}\n", full_path_dir, @errorName(err));
            return err;
        };
        io.writeFile(full_path, self.data, self.builder.allocator) %% |err| {
            %%io.stderr.printf("unable to write {}: {}\n", full_path, @errorName(err));
            return err;
        };
    }
};

pub const LogStep = struct {
    step: Step,
    builder: &Builder,
    data: []const u8,

    pub fn init(builder: &Builder, data: []const u8) -> LogStep {
        return LogStep {
            .builder = builder,
            .step = Step.init(builder.fmt("log {}", data), builder.allocator, make),
            .data = data,
        };
    }

    fn make(step: &Step) -> %void {
        const self = @fieldParentPtr(LogStep, "step", step);
        %%io.stderr.write(self.data);
        %%io.stderr.flush();
    }
};

pub const RemoveDirStep = struct {
    step: Step,
    builder: &Builder,
    dir_path: []const u8,

    pub fn init(builder: &Builder, dir_path: []const u8) -> RemoveDirStep {
        return RemoveDirStep {
            .builder = builder,
            .step = Step.init(builder.fmt("RemoveDir {}", dir_path), builder.allocator, make),
            .dir_path = dir_path,
        };
    }

    fn make(step: &Step) -> %void {
        const self = @fieldParentPtr(RemoveDirStep, "step", step);

        const full_path = self.builder.pathFromRoot(self.dir_path);
        os.deleteTree(self.builder.allocator, full_path) %% |err| {
            %%io.stderr.printf("Unable to remove {}: {}\n", full_path, @errorName(err));
            return err;
        };
    }
};

pub const Step = struct {
    name: []const u8,
    makeFn: fn(self: &Step) -> %void,
    dependencies: ArrayList(&Step),
    loop_flag: bool,
    done_flag: bool,

    pub fn init(name: []const u8, allocator: &Allocator, makeFn: fn (&Step)->%void) -> Step {
        Step {
            .name = name,
            .makeFn = makeFn,
            .dependencies = ArrayList(&Step).init(allocator),
            .loop_flag = false,
            .done_flag = false,
        }
    }
    pub fn initNoOp(name: []const u8, allocator: &Allocator) -> Step {
        init(name, allocator, makeNoOp)
    }

    pub fn make(self: &Step) -> %void {
        if (self.done_flag)
            return;

        %return self.makeFn(self);
        self.done_flag = true;
    }

    pub fn dependOn(self: &Step, other: &Step) {
        %%self.dependencies.append(other);
    }

    fn makeNoOp(self: &Step) -> %void {}
};

fn doAtomicSymLinks(allocator: &Allocator, output_path: []const u8, filename_major_only: []const u8,
    filename_name_only: []const u8) -> %void
{
    const out_dir = os.path.dirname(output_path);
    const out_basename = os.path.basename(output_path);
    // sym link for libfoo.so.1 to libfoo.so.1.2.3
    const major_only_path = %%os.path.join(allocator, out_dir, filename_major_only);
    os.atomicSymLink(allocator, out_basename, major_only_path) %% |err| {
        %%io.stderr.printf("Unable to symlink {} -> {}\n", major_only_path, out_basename);
        return err;
    };
    // sym link for libfoo.so to libfoo.so.1
    const name_only_path = %%os.path.join(allocator, out_dir, filename_name_only);
    os.atomicSymLink(allocator, filename_major_only, name_only_path) %% |err| {
        %%io.stderr.printf("Unable to symlink {} -> {}\n", name_only_path, filename_major_only);
        return err;
    };
}
