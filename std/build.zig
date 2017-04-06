const io = @import("io.zig");
const mem = @import("mem.zig");
const debug = @import("debug.zig");
const List = @import("list.zig").List;
const HashMap = @import("hash_map.zig").HashMap;
const Allocator = @import("mem.zig").Allocator;
const os = @import("os/index.zig");
const StdIo = os.ChildProcess.StdIo;
const Term = os.ChildProcess.Term;
const BufSet = @import("buf_set.zig").BufSet;

error ExtraArg;
error UncleanExit;

pub const Builder = struct {
    allocator: &Allocator,
    exe_list: List(&Exe),
    lib_paths: List([]const u8),
    include_paths: List([]const u8),
    rpaths: List([]const u8),
    user_input_options: UserInputOptionsMap,
    available_options_map: AvailableOptionsMap,
    available_options_list: List(AvailableOption),
    verbose: bool,
    invalid_user_input: bool,

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

    pub fn init(allocator: &Allocator) -> Builder {
        var self = Builder {
            .verbose = false,
            .invalid_user_input = false,
            .allocator = allocator,
            .exe_list = List(&Exe).init(allocator),
            .lib_paths = List([]const u8).init(allocator),
            .include_paths = List([]const u8).init(allocator),
            .rpaths = List([]const u8).init(allocator),
            .user_input_options = UserInputOptionsMap.init(allocator),
            .available_options_map = AvailableOptionsMap.init(allocator),
            .available_options_list = List(AvailableOption).init(allocator),
        };
        self.processNixOSEnvVars();
        return self;
    }

    pub fn deinit(self: &Builder) {
        self.exe_list.deinit();
        self.lib_paths.deinit();
        self.include_paths.deinit();
        self.rpaths.deinit();
    }

    pub fn addExe(self: &Builder, root_src: []const u8, name: []const u8) -> &Exe {
        return self.addExeErr(root_src, name) %% |err| handleErr(err);
    }

    pub fn addExeErr(self: &Builder, root_src: []const u8, name: []const u8) -> %&Exe {
        const exe = %return self.allocator.create(Exe);
        *exe = Exe {
            .verbose = false,
            .release = false,
            .root_src = root_src,
            .name = name,
            .target = Target.Native,
            .linker_script = LinkerScript.None,
            .link_libs = BufSet.init(self.allocator),
        };
        %return self.exe_list.append(exe);
        return exe;
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

    pub fn make(self: &Builder, zig_exe: []const u8, targets: []const []const u8) -> %void {
        if (targets.len != 0) {
            debug.panic("TODO non default targets");
        }

        var env_map = %return os.getEnvMap(self.allocator);

        for (self.exe_list.toSlice()) |exe| {
            var zig_args = List([]const u8).init(self.allocator);
            defer zig_args.deinit();

            %return zig_args.append("build_exe"[0...]); // TODO issue #296
            %return zig_args.append(exe.root_src);

            if (exe.verbose) {
                %return zig_args.append("--verbose"[0...]); // TODO issue #296
            }

            if (exe.release) {
                %return zig_args.append("--release"[0...]); // TODO issue #296
            }

            %return zig_args.append("--name"[0...]); // TODO issue #296
            %return zig_args.append(exe.name);

            switch (exe.target) {
                Target.Native => {},
                Target.Cross => |cross_target| {
                    %return zig_args.append("--target-arch"[0...]); // TODO issue #296
                    %return zig_args.append(targetArchName(cross_target.arch));

                    %return zig_args.append("--target-os"[0...]); // TODO issue #296
                    %return zig_args.append(targetOsName(cross_target.os));

                    %return zig_args.append("--target-environ"[0...]); // TODO issue #296
                    %return zig_args.append(targetEnvironName(cross_target.environ));
                },
            }

            switch (exe.linker_script) {
                LinkerScript.None => {},
                LinkerScript.Embed => |script| {
                    const tmp_file_name = "linker.ld.tmp"; // TODO issue #298
                    io.writeFile(tmp_file_name, script, self.allocator)
                        %% |err| debug.panic("unable to write linker script: {}\n", @errorName(err));
                    %return zig_args.append("--linker-script"[0...]); // TODO issue #296
                    %return zig_args.append(tmp_file_name[0...]); // TODO issue #296
                },
                LinkerScript.Path => |path| {
                    %return zig_args.append("--linker-script"[0...]); // TODO issue #296
                    %return zig_args.append(path);
                },
            }

            {
                var it = exe.link_libs.iterator();
                while (true) {
                    const entry = it.next() ?? break;
                    %return zig_args.append("--library"[0...]); // TODO issue #296
                    %return zig_args.append(entry.key);
                }
            }

            for (self.include_paths.toSliceConst()) |include_path| {
                %return zig_args.append("-isystem"[0...]); // TODO issue #296
                %return zig_args.append(include_path);
            }

            for (self.rpaths.toSliceConst()) |rpath| {
                %return zig_args.append("-rpath"[0...]); // TODO issue #296
                %return zig_args.append(rpath);
            }

            for (self.lib_paths.toSliceConst()) |lib_path| {
                %return zig_args.append("--library-path"[0...]); // TODO issue #296
                %return zig_args.append(lib_path);
            }

            if (self.verbose) {
                printInvocation(zig_exe, zig_args);
            }
            // TODO issue #301
            var child = os.ChildProcess.spawn(zig_exe, zig_args.toSliceConst(), &env_map,
                StdIo.Ignore, StdIo.Inherit, StdIo.Inherit, self.allocator)
                %% |err| debug.panic("Unable to spawn zig compiler: {}\n", @errorName(err));
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

const CrossTarget = struct {
    arch: Arch,
    os: Os,
    environ: Environ,
};

const Target = enum {
    Native,
    Cross: CrossTarget,
};

const LinkerScript = enum {
    None,
    Embed: []const u8,
    Path: []const u8,
};

const Exe = struct {
    root_src: []const u8,
    name: []const u8,
    target: Target,
    linker_script: LinkerScript,
    link_libs: BufSet,
    verbose: bool,
    release: bool,

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
};

fn handleErr(err: error) -> noreturn {
    debug.panic("error: {}\n", @errorName(err));
}

fn printInvocation(exe_name: []const u8, args: &const List([]const u8)) {
    %%io.stderr.printf("{}", exe_name);
    for (args.toSliceConst()) |arg| {
        %%io.stderr.printf(" {}", arg);
    }
    %%io.stderr.printf("\n");
}

// TODO issue #299
fn targetOsName(target_os: Os) -> []const u8 {
    return switch (target_os) {
        Os.freestanding => "freestanding",
        Os.cloudabi => "cloudabi",
        Os.darwin => "darwin",
        Os.dragonfly => "dragonfly",
        Os.freebsd => "freebsd",
        Os.ios => "ios",
        Os.kfreebsd => "kfreebsd",
        Os.linux => "linux",
        Os.lv2 => "lv2",
        Os.macosx => "macosx",
        Os.netbsd => "netbsd",
        Os.openbsd => "openbsd",
        Os.solaris => "solaris",
        Os.windows => "windows",
        Os.haiku => "haiku",
        Os.minix => "minix",
        Os.rtems => "rtems",
        Os.nacl => "nacl",
        Os.cnk => "cnk",
        Os.bitrig => "bitrig",
        Os.aix => "aix",
        Os.cuda => "cuda",
        Os.nvcl => "nvcl",
        Os.amdhsa => "amdhsa",
        Os.ps4 => "ps4",
        Os.elfiamcu => "elfiamcu",
        Os.tvos => "tvos",
        Os.watchos => "watchos",
        Os.mesa3d => "mesa3d",
    };
}

// TODO issue #299
fn targetArchName(target_arch: Arch) -> []const u8 {
    return switch (target_arch) {
        Arch.armv8_2a => "armv8_2a",
        Arch.armv8_1a => "armv8_1a",
        Arch.armv8 => "armv8",
        Arch.armv8m_baseline => "armv8m_baseline",
        Arch.armv8m_mainline => "armv8m_mainline",
        Arch.armv7 => "armv7",
        Arch.armv7em => "armv7em",
        Arch.armv7m => "armv7m",
        Arch.armv7s => "armv7s",
        Arch.armv7k => "armv7k",
        Arch.armv6 => "armv6",
        Arch.armv6m => "armv6m",
        Arch.armv6k => "armv6k",
        Arch.armv6t2 => "armv6t2",
        Arch.armv5 => "armv5",
        Arch.armv5te => "armv5te",
        Arch.armv4t => "armv4t",
        Arch.armeb => "armeb",
        Arch.aarch64 => "aarch64",
        Arch.aarch64_be => "aarch64_be",
        Arch.avr => "avr",
        Arch.bpfel => "bpfel",
        Arch.bpfeb => "bpfeb",
        Arch.hexagon => "hexagon",
        Arch.mips => "mips",
        Arch.mipsel => "mipsel",
        Arch.mips64 => "mips64",
        Arch.mips64el => "mips64el",
        Arch.msp430 => "msp430",
        Arch.powerpc => "powerpc",
        Arch.powerpc64 => "powerpc64",
        Arch.powerpc64le => "powerpc64le",
        Arch.r600 => "r600",
        Arch.amdgcn => "amdgcn",
        Arch.sparc => "sparc",
        Arch.sparcv9 => "sparcv9",
        Arch.sparcel => "sparcel",
        Arch.s390x => "s390x",
        Arch.tce => "tce",
        Arch.thumb => "thumb",
        Arch.thumbeb => "thumbeb",
        Arch.i386 => "i386",
        Arch.x86_64 => "x86_64",
        Arch.xcore => "xcore",
        Arch.nvptx => "nvptx",
        Arch.nvptx64 => "nvptx64",
        Arch.le32 => "le32",
        Arch.le64 => "le64",
        Arch.amdil => "amdil",
        Arch.amdil64 => "amdil64",
        Arch.hsail => "hsail",
        Arch.hsail64 => "hsail64",
        Arch.spir => "spir",
        Arch.spir64 => "spir64",
        Arch.kalimbav3 => "kalimbav3",
        Arch.kalimbav4 => "kalimbav4",
        Arch.kalimbav5 => "kalimbav5",
        Arch.shave => "shave",
        Arch.lanai => "lanai",
        Arch.wasm32 => "wasm32",
        Arch.wasm64 => "wasm64",
        Arch.renderscript32 => "renderscript32",
        Arch.renderscript64 => "renderscript64",
    };
}

// TODO issue #299
fn targetEnvironName(target_environ: Environ) -> []const u8 {
    return switch (target_environ) {
        Environ.gnu => "gnu",
        Environ.gnuabi64 => "gnuabi64",
        Environ.gnueabi => "gnueabi",
        Environ.gnueabihf => "gnueabihf",
        Environ.gnux32 => "gnux32",
        Environ.code16 => "code16",
        Environ.eabi => "eabi",
        Environ.eabihf => "eabihf",
        Environ.android => "android",
        Environ.musl => "musl",
        Environ.musleabi => "musleabi",
        Environ.musleabihf => "musleabihf",
        Environ.msvc => "msvc",
        Environ.itanium => "itanium",
        Environ.cygnus => "cygnus",
        Environ.amdopencl => "amdopencl",
        Environ.coreclr => "coreclr",
    };
}

