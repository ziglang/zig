const io = @import("io.zig");
const mem = @import("mem.zig");
const debug = @import("debug.zig");
const List = @import("list.zig").List;
const Allocator = @import("mem.zig").Allocator;
const os = @import("os/index.zig");
const StdIo = os.ChildProcess.StdIo;
const Term = os.ChildProcess.Term;

error ExtraArg;
error UncleanExit;

pub const Builder = struct {
    zig_exe: []const u8,
    allocator: &Allocator,
    exe_list: List(&Exe),

    pub fn init(zig_exe: []const u8, allocator: &Allocator) -> Builder {
        Builder {
            .zig_exe = zig_exe,
            .allocator = allocator,
            .exe_list = List(&Exe).init(allocator),
        }
    }

    pub fn addExe(self: &Builder, root_src: []const u8, name: []const u8) -> &Exe {
        return self.addExeErr(root_src, name) %% |err| handleErr(err);
    }

    pub fn addExeErr(self: &Builder, root_src: []const u8, name: []const u8) -> %&Exe {
        const exe = %return self.allocator.create(Exe);
        *exe = Exe {
            .root_src = root_src,
            .name = name,
        };
        %return self.exe_list.append(exe);
        return exe;
    }

    pub fn make(self: &Builder, cli_args: []const []const u8) -> %void {
        var verbose = false;
        for (cli_args) |arg| {
            if (mem.eql(u8, arg, "--verbose")) {
                verbose = true;
            } else {
                %%io.stderr.printf("Unrecognized argument: '{}'\n", arg);
                return error.ExtraArg;
            }
        }
        for (self.exe_list.toSlice()) |exe| {
            var zig_args = List([]const u8).init(self.allocator);
            defer zig_args.deinit();

            %return zig_args.append("build_exe"[0...]); // TODO issue #296
            %return zig_args.append(exe.root_src);
            %return zig_args.append("--name"[0...]); // TODO issue #296
            %return zig_args.append(exe.name);

            printInvocation(self.zig_exe, zig_args);
            var child = %return os.ChildProcess.spawn(self.zig_exe, zig_args.toSliceConst(), os.environ,
                StdIo.Ignore, StdIo.Inherit, StdIo.Inherit, self.allocator);
            const term = %return child.wait();
            switch (term) {
                Term.Clean => |code| {
                    if (code != 0) {
                        return error.UncleanExit;
                    }
                },
                else => return error.UncleanExit,
            }
        }
    }
};

const Exe = struct {
    root_src: []const u8,
    name: []const u8,
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
