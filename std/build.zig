const io = @import("io.zig");
const mem = @import("mem.zig");
const debug = @import("debug.zig");
const assert = debug.assert;
const List = @import("list.zig").List;
const HashMap = @import("hash_map.zig").HashMap;
const Allocator = @import("mem.zig").Allocator;
const os = @import("os/index.zig");
const StdIo = os.ChildProcess.StdIo;
const Term = os.ChildProcess.Term;
const BufSet = @import("buf_set.zig").BufSet;
const BufMap = @import("buf_map.zig").BufMap;
const fmt = @import("fmt.zig");

error ExtraArg;
error UncleanExit;
error InvalidStepName;
error DependencyLoopDetected;
error NoCompilerFound;

pub const Builder = struct {
    allocator: &Allocator,
    lib_paths: List([]const u8),
    include_paths: List([]const u8),
    rpaths: List([]const u8),
    user_input_options: UserInputOptionsMap,
    available_options_map: AvailableOptionsMap,
    available_options_list: List(AvailableOption),
    verbose: bool,
    invalid_user_input: bool,
    zig_exe: []const u8,
    default_step: &Step,
    env_map: BufMap,
    top_level_steps: List(&TopLevelStep),
    prefix: []const u8,
    out_dir: []u8,

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
        List: List([]const u8),
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

    pub fn init(allocator: &Allocator) -> Builder {
        var self = Builder {
            .verbose = false,
            .invalid_user_input = false,
            .allocator = allocator,
            .lib_paths = List([]const u8).init(allocator),
            .include_paths = List([]const u8).init(allocator),
            .rpaths = List([]const u8).init(allocator),
            .user_input_options = UserInputOptionsMap.init(allocator),
            .available_options_map = AvailableOptionsMap.init(allocator),
            .available_options_list = List(AvailableOption).init(allocator),
            .top_level_steps = List(&TopLevelStep).init(allocator),
            .zig_exe = undefined,
            .default_step = undefined,
            .env_map = %%os.getEnvMap(allocator),
            .prefix = undefined,
            .out_dir = %%os.getCwd(allocator),
        };
        self.processNixOSEnvVars();
        self.default_step = self.step("default", "Build the project");
        return self;
    }

    pub fn deinit(self: &Builder) {
        self.allocator.free(self.out_dir);
        self.lib_paths.deinit();
        self.include_paths.deinit();
        self.rpaths.deinit();
        self.env_map.deinit();
        self.top_level_steps.deinit();
    }

    pub fn setInstallPrefix(self: &Builder, maybe_prefix: ?[]const u8) {
        if (const prefix ?= maybe_prefix) {
            self.prefix = prefix;
            return;
        }
        // TODO better default
        self.prefix = "/usr/local";
    }

    pub fn addExecutable(self: &Builder, name: []const u8, root_src: []const u8) -> &Exe {
        const exe = %%self.allocator.create(Exe);
        *exe = Exe.init(self, name, root_src);
        return exe;
    }

    pub fn addCStaticLibrary(self: &Builder, name: []const u8) -> &CLibrary {
        const lib = %%self.allocator.create(CLibrary);
        *lib = CLibrary.initStatic(self, name);
        return lib;
    }

    pub fn addCSharedLibrary(self: &Builder, name: []const u8, ver: &const Version) -> &CLibrary {
        const lib = %%self.allocator.create(CLibrary);
        *lib = CLibrary.initShared(self, name, ver);
        return lib;
    }

    pub fn addCExecutable(self: &Builder, name: []const u8) -> &CExecutable {
        const exe = %%self.allocator.create(CExecutable);
        *exe = CExecutable.init(self, name);
        return exe;
    }

    pub fn addCommand(self: &Builder, cwd: []const u8, env_map: &const BufMap,
        path: []const u8, args: []const []const u8) -> &CommandStep
    {
        const cmd = %%self.allocator.create(CommandStep);
        *cmd = CommandStep.init(self, cwd, env_map, path, args);
        return cmd;
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
        var wanted_steps = List(&Step).init(self.allocator);
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
        %%io.stderr.printf("Cannot run step '{}' because it does not exist.", name);
        return error.InvalidStepName;
    }

    fn processNixOSEnvVars(self: &Builder) {
        if (const nix_cflags_compile ?= os.getEnv("NIX_CFLAGS_COMPILE")) {
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
        if (const nix_ldflags ?= os.getEnv("NIX_LDFLAGS")) {
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
                    const lib_path = word[2...];
                    self.addLibPath(lib_path);
                } else {
                    %%io.stderr.printf("Unrecognized C flag from NIX_LDFLAGS: {}\n", word);
                    break;
                }
            }
        }
    }

    pub fn option(self: &Builder, comptime T: type, name: []const u8, description: []const u8) -> ?T {
        const type_id = typeToEnum(T);
        const available_option = AvailableOption {
            .name = name,
            .type_id = type_id,
            .description = description,
        };
        if (const _ ?= %%self.available_options_map.put(name, available_option)) {
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
            TypeId.String => debug.panic("TODO string options to build script"),
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

    pub fn addUserInputOption(self: &Builder, name: []const u8, value: []const u8) -> bool {
        if (var prev_value ?= %%self.user_input_options.put(name, UserInputOption {
            .name = name,
            .value = UserValue.Scalar { value },
            .used = false,
        })) {
            switch (prev_value.value) {
                UserValue.Scalar => |s| {
                    var list = List([]const u8).init(self.allocator);
                    %%list.append(s);
                    %%list.append(value);
                    %%self.user_input_options.put(name, UserInputOption {
                        .name = name,
                        .value = UserValue.List { list },
                        .used = false,
                    });
                },
                UserValue.List => |*list| {
                    %%list.append(value);
                    %%self.user_input_options.put(name, UserInputOption {
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
        if (const prev_value ?= %%self.user_input_options.put(name, UserInputOption {
            .name = name,
            .value = UserValue.Flag,
            .used = false,
        })) {
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
        if (@isInteger(T)) {
            TypeId.Int
        } else if (@isFloat(T)) {
            TypeId.Float
        } else switch (T) {
            bool => TypeId.Bool,
            []const u8 => TypeId.String,
            []const []const u8 => TypeId.List,
            else => @compileError("Unsupported type: " ++ @typeName(T)),
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
};

const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,
};

const CrossTarget = struct {
    arch: Arch,
    os: Os,
    environ: Environ,
};

const Target = enum {
    Native,
    Cross: CrossTarget,

    pub fn oFileExt(self: &const Target) -> []const u8 {
        const environ = switch (*self) {
            Target.Native => @compileVar("environ"),
            Target.Cross => |t| t.environ,
        };
        return switch (environ) {
            Environ.msvc => ".obj",
            else => ".o",
        };
    }
};

const LinkerScript = enum {
    None,
    Embed: []const u8,
    Path: []const u8,
};

const Exe = struct {
    step: Step,
    builder: &Builder,
    root_src: []const u8,
    name: []const u8,
    target: Target,
    linker_script: LinkerScript,
    link_libs: BufSet,
    verbose: bool,
    release: bool,

    pub fn init(builder: &Builder, name: []const u8, root_src: []const u8) -> Exe {
        Exe {
            .builder = builder,
            .verbose = false,
            .release = false,
            .root_src = root_src,
            .name = name,
            .target = Target.Native,
            .linker_script = LinkerScript.None,
            .link_libs = BufSet.init(builder.allocator),
            .step = Step.init(name, builder.allocator, make),
        }
    }

    pub fn deinit(self: &Exe) {
        self.link_libs.deinit();
    }

    pub fn setTarget(self: &Exe, target_arch: Arch, target_os: Os, target_environ: Environ) {
        self.target = Target.Cross {
            CrossTarget {
                .arch = target_arch,
                .os = target_os,
                .environ = target_environ,
            }
        };
    }

    /// Exe keeps a reference to script for its lifetime or until this function
    /// is called again.
    pub fn setLinkerScriptContents(self: &Exe, script: []const u8) {
        self.linker_script = LinkerScript.Embed { script };
    }

    pub fn setLinkerScriptPath(self: &Exe, path: []const u8) {
        self.linker_script = LinkerScript.Path { path };
    }

    pub fn linkLibrary(self: &Exe, name: []const u8) {
        %%self.link_libs.put(name);
    }

    pub fn setVerbose(self: &Exe, value: bool) {
        self.verbose = value;
    }

    pub fn setRelease(self: &Exe, value: bool) {
        self.release = value;
    }

    fn make(step: &Step) -> %void {
        // TODO issue #320
        //const self = @fieldParentPtr(Exe, "step", step);
        const exe = @ptrcast(&Exe, step);
        const builder = exe.builder;

        var zig_args = List([]const u8).init(builder.allocator);
        defer zig_args.deinit();

        %return zig_args.append("build_exe");
        %return zig_args.append(exe.root_src);

        if (exe.verbose) {
            %return zig_args.append("--verbose");
        }

        if (exe.release) {
            %return zig_args.append("--release");
        }

        %return zig_args.append("--name");
        %return zig_args.append(exe.name);

        switch (exe.target) {
            Target.Native => {},
            Target.Cross => |cross_target| {
                %return zig_args.append("--target-arch");
                %return zig_args.append(@enumTagName(cross_target.arch));

                %return zig_args.append("--target-os");
                %return zig_args.append(@enumTagName(cross_target.os));

                %return zig_args.append("--target-environ");
                %return zig_args.append(@enumTagName(cross_target.environ));
            },
        }

        switch (exe.linker_script) {
            LinkerScript.None => {},
            LinkerScript.Embed => |script| {
                const tmp_file_name = "linker.ld.tmp"; // TODO issue #298
                io.writeFile(tmp_file_name, script, builder.allocator)
                    %% |err| debug.panic("unable to write linker script: {}\n", @errorName(err));
                %return zig_args.append("--linker-script");
                %return zig_args.append(tmp_file_name);
            },
            LinkerScript.Path => |path| {
                %return zig_args.append("--linker-script");
                %return zig_args.append(path);
            },
        }

        {
            var it = exe.link_libs.iterator();
            while (true) {
                const entry = it.next() ?? break;
                %return zig_args.append("--library");
                %return zig_args.append(entry.key);
            }
        }

        for (builder.include_paths.toSliceConst()) |include_path| {
            %return zig_args.append("-isystem");
            %return zig_args.append(include_path);
        }

        for (builder.rpaths.toSliceConst()) |rpath| {
            %return zig_args.append("-rpath");
            %return zig_args.append(rpath);
        }

        for (builder.lib_paths.toSliceConst()) |lib_path| {
            %return zig_args.append("--library-path");
            %return zig_args.append(lib_path);
        }

        if (builder.verbose) {
            printInvocation(builder.zig_exe, zig_args);
        }
        // TODO issue #301
        var child = os.ChildProcess.spawn(builder.zig_exe, zig_args.toSliceConst(), &builder.env_map,
            StdIo.Ignore, StdIo.Inherit, StdIo.Inherit, builder.allocator)
            %% |err| debug.panic("Unable to spawn zig compiler: {}\n", @errorName(err));
        %return waitForCleanExit(&child);
    }
};

const CLibrary = struct {
    step: Step,
    name: []const u8,
    out_filename: []const u8,
    static: bool,
    version: Version,
    cflags: List([]const u8),
    source_files: List([]const u8),
    object_files: List([]const u8),
    link_libs: BufSet,
    target: Target,
    builder: &Builder,
    include_dirs: List([]const u8),

    pub fn initShared(builder: &Builder, name: []const u8, version: &const Version) -> CLibrary {
        return init(builder, name, version, false);
    }

    pub fn initStatic(builder: &Builder, name: []const u8) -> CLibrary {
        return init(builder, name, undefined, true);
    }

    fn init(builder: &Builder, name: []const u8, version: &const Version, static: bool) -> CLibrary {
        var clib = CLibrary {
            .builder = builder,
            .name = name,
            .version = *version,
            .static = static,
            .target = Target.Native,
            .cflags = List([]const u8).init(builder.allocator),
            .source_files = List([]const u8).init(builder.allocator),
            .object_files = List([]const u8).init(builder.allocator),
            .step = Step.init(name, builder.allocator, make),
            .link_libs = BufSet.init(builder.allocator),
            .include_dirs = List([]const u8).init(builder.allocator),
            .out_filename = undefined,
        };
        clib.computeOutFileName();
        return clib;
    }

    fn computeOutFileName(self: &CLibrary) {
        if (self.static) {
            self.out_filename = %%fmt.allocPrint(self.builder.allocator, "lib{}.a", self.name);
        } else {
            self.out_filename = %%fmt.allocPrint(self.builder.allocator, "lib{}.so.{d}.{d}.{d}",
                self.name, self.version.major, self.version.minor, self.version.patch);
        }
    }

    pub fn linkLibrary(self: &CLibrary, name: []const u8) {
        %%self.link_libs.put(name);
    }

    pub fn linkCLibrary(self: &CLibrary, other: &CLibrary) {
        self.step.dependOn(&other.step);
        %%self.link_libs.put(other.name);
    }

    pub fn addSourceFile(self: &CLibrary, file: []const u8) {
        %%self.source_files.append(file);
    }

    pub fn addObjectFile(self: &CLibrary, file: []const u8) {
        %%self.object_files.append(file);
    }

    pub fn addIncludeDir(self: &CLibrary, path: []const u8) {
        %%self.include_dirs.append(path);
    }

    pub fn addCompileFlagsForRelease(self: &CLibrary, release: bool) {
        if (release) {
            %%self.cflags.append("-g");
            %%self.cflags.append("-O2");
        } else {
            %%self.cflags.append("-g");
        }
    }

    pub fn addCompileFlags(self: &CLibrary, flags: []const []const u8) {
        for (flags) |flag| {
            %%self.cflags.append(flag);
        }
    }

    fn make(step: &Step) -> %void {
        // TODO issue #320
        //const self = @fieldParentPtr(CLibrary, "step", step);
        const self = @ptrcast(&CLibrary, step);
        const cc = os.getEnv("CC") ?? "cc";
        const builder = self.builder;

        var cc_args = List([]const u8).init(builder.allocator);
        defer cc_args.deinit();

        for (self.source_files.toSliceConst()) |source_file| {
            %%cc_args.resize(0);

            if (!self.static) {
                %%cc_args.append("-fPIC");
            }

            %%cc_args.append("-c");
            %%cc_args.append(source_file);

            // TODO don't dump the .o file in the same place as the source file
            const o_file = %%fmt.allocPrint(builder.allocator, "{}{}", source_file, self.target.oFileExt());
            defer builder.allocator.free(o_file);
            %%cc_args.append("-o");
            %%cc_args.append(o_file);

            for (self.cflags.toSliceConst()) |cflag| {
                %%cc_args.append(cflag);
            }

            for (self.include_dirs.toSliceConst()) |dir| {
                %%cc_args.append("-I");
                %%cc_args.append(dir);
            }

            if (builder.verbose) {
                printInvocation(cc, cc_args);
            }

            var child = os.ChildProcess.spawn(cc, cc_args.toSliceConst(), &builder.env_map,
                StdIo.Ignore, StdIo.Inherit, StdIo.Inherit, builder.allocator)
                %% |err| debug.panic("Unable to spawn compiler: {}\n", @errorName(err));
            %return waitForCleanExit(&child);

            %%self.object_files.append(o_file);
        }

        if (self.static) {
            debug.panic("TODO static library");
        } else {
            %%cc_args.resize(0);

            %%cc_args.append("-fPIC");
            %%cc_args.append("-shared");

            const soname_arg = %%fmt.allocPrint(builder.allocator, "-Wl,-soname,lib{}.so.{d}",
                self.name, self.version.major);
            defer builder.allocator.free(soname_arg);
            %%cc_args.append(soname_arg);

            %%cc_args.append("-o");
            %%cc_args.append(self.out_filename);

            for (self.object_files.toSliceConst()) |object_file| {
                %%cc_args.append(object_file);
            }

            if (builder.verbose) {
                printInvocation(cc, cc_args);
            }

            var child = os.ChildProcess.spawn(cc, cc_args.toSliceConst(), &builder.env_map,
                StdIo.Ignore, StdIo.Inherit, StdIo.Inherit, builder.allocator)
                %% |err| debug.panic("Unable to spawn compiler: {}\n", @errorName(err));
            %return waitForCleanExit(&child);
        }
    }

    pub fn setTarget(self: &CLibrary, target_arch: Arch, target_os: Os, target_environ: Environ) {
        self.target = Target.Cross {
            CrossTarget {
                .arch = target_arch,
                .os = target_os,
                .environ = target_environ,
            }
        };
    }
};

const CExecutable = struct {
    step: Step,
    builder: &Builder,
    name: []const u8,
    cflags: List([]const u8),
    source_files: List([]const u8),
    object_files: List([]const u8),
    full_path_libs: List([]const u8),
    link_libs: BufSet,
    target: Target,
    include_dirs: List([]const u8),

    pub fn init(builder: &Builder, name: []const u8) -> CExecutable {
        CExecutable {
            .builder = builder,
            .name = name,
            .target = Target.Native,
            .cflags = List([]const u8).init(builder.allocator),
            .source_files = List([]const u8).init(builder.allocator),
            .object_files = List([]const u8).init(builder.allocator),
            .full_path_libs = List([]const u8).init(builder.allocator),
            .step = Step.init(name, builder.allocator, make),
            .link_libs = BufSet.init(builder.allocator),
            .include_dirs = List([]const u8).init(builder.allocator),
        }
    }

    pub fn linkLibrary(self: &CExecutable, name: []const u8) {
        %%self.link_libs.put(name);
    }

    pub fn linkCLibrary(self: &CExecutable, clib: &CLibrary) {
        self.step.dependOn(&clib.step);
        %%self.full_path_libs.append(clib.out_filename);
    }

    pub fn addSourceFile(self: &CExecutable, file: []const u8) {
        %%self.source_files.append(file);
    }

    pub fn addObjectFile(self: &CExecutable, file: []const u8) {
        %%self.object_files.append(file);
    }

    pub fn addIncludeDir(self: &CExecutable, path: []const u8) {
        %%self.include_dirs.append(path);
    }

    pub fn addCompileFlagsForRelease(self: &CExecutable, release: bool) {
        if (release) {
            %%self.cflags.append("-g");
            %%self.cflags.append("-O2");
        } else {
            %%self.cflags.append("-g");
        }
    }

    pub fn addCompileFlags(self: &CExecutable, flags: []const []const u8) {
        for (flags) |flag| {
            %%self.cflags.append(flag);
        }
    }

    fn make(step: &Step) -> %void {
        // TODO issue #320
        //const self = @fieldParentPtr(CExecutable, "step", step);
        const self = @ptrcast(&CExecutable, step);
        const cc = os.getEnv("CC") ?? "cc";
        const builder = self.builder;

        var cc_args = List([]const u8).init(builder.allocator);
        defer cc_args.deinit();

        for (self.source_files.toSliceConst()) |source_file| {
            %%cc_args.resize(0);

            %%cc_args.append("-c");
            %%cc_args.append(source_file);

            // TODO don't dump the .o file in the same place as the source file
            const o_file = %%fmt.allocPrint(builder.allocator, "{}{}", source_file, self.target.oFileExt());
            defer builder.allocator.free(o_file);
            %%cc_args.append("-o");
            %%cc_args.append(o_file);

            for (self.cflags.toSliceConst()) |cflag| {
                %%cc_args.append(cflag);
            }

            for (self.include_dirs.toSliceConst()) |dir| {
                %%cc_args.append("-I");
                %%cc_args.append(dir);
            }

            if (builder.verbose) {
                printInvocation(cc, cc_args);
            }

            var child = os.ChildProcess.spawn(cc, cc_args.toSliceConst(), &builder.env_map,
                StdIo.Ignore, StdIo.Inherit, StdIo.Inherit, builder.allocator)
                %% |err| debug.panic("Unable to spawn compiler: {}\n", @errorName(err));
            %return waitForCleanExit(&child);

            %%self.object_files.append(o_file);
        }

        %%cc_args.resize(0);

        for (self.object_files.toSliceConst()) |object_file| {
            %%cc_args.append(object_file);
        }

        %%cc_args.append("-o");
        %%cc_args.append(self.name);

        const rpath_arg = %%fmt.allocPrint(builder.allocator, "-Wl,-rpath,{}", builder.out_dir);
        defer builder.allocator.free(rpath_arg);
        %%cc_args.append(rpath_arg);

        %%cc_args.append("-rdynamic");

        for (self.full_path_libs.toSliceConst()) |full_path_lib| {
            %%cc_args.append(full_path_lib);
        }

        if (builder.verbose) {
            printInvocation(cc, cc_args);
        }

        var child = os.ChildProcess.spawn(cc, cc_args.toSliceConst(), &builder.env_map,
            StdIo.Ignore, StdIo.Inherit, StdIo.Inherit, builder.allocator)
            %% |err| debug.panic("Unable to spawn compiler: {}\n", @errorName(err));
        %return waitForCleanExit(&child);
    }

    pub fn setTarget(self: &CExecutable, target_arch: Arch, target_os: Os, target_environ: Environ) {
        self.target = Target.Cross {
            CrossTarget {
                .arch = target_arch,
                .os = target_os,
                .environ = target_environ,
            }
        };
    }
};

const CommandStep = struct {
    step: Step,
    path: []const u8,
    args: []const []const u8,
    cwd: []const u8,
    env_map: &const BufMap,

    pub fn init(builder: &Builder, cwd: []const u8, env_map: &const BufMap,
        path: []const u8, args: []const []const u8) -> CommandStep
    {
        CommandStep {
            .step = Step.init(path, builder.allocator, make),
            .path = path,
            .args = args,
            .cwd = cwd,
            .env_map = env_map,
        }
    }

    fn make(step: &Step) -> %void {
        // TODO issue #320
        //const self = @fieldParentPtr(CExecutable, "step", step);
        const self = @ptrcast(&CommandStep, step);

        %%io.stderr.printf("TODO: exec command\n");
    }
};

const Step = struct {
    name: []const u8,
    makeFn: fn(self: &Step) -> %void,
    dependencies: List(&Step),
    loop_flag: bool,
    done_flag: bool,

    pub fn init(name: []const u8, allocator: &Allocator, makeFn: fn (&Step)->%void) -> Step {
        Step {
            .name = name,
            .makeFn = makeFn,
            .dependencies = List(&Step).init(allocator),
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

fn printInvocation(exe_name: []const u8, args: &const List([]const u8)) {
    %%io.stderr.printf("{}", exe_name);
    for (args.toSliceConst()) |arg| {
        %%io.stderr.printf(" {}", arg);
    }
    %%io.stderr.printf("\n");
}

fn waitForCleanExit(child: &os.ChildProcess) -> %void {
    const term = %%child.wait();
    switch (term) {
        Term.Clean => |code| {
            if (code != 0) {
                return error.UncleanExit;
            }
        },
        else => {
            return error.UncleanExit;
        },
    };
}
