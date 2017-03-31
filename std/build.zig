const io = @import("io.zig");
const mem = @import("mem.zig");
const debug = @import("debug.zig");
const List = @import("list.zig").List;
const Allocator = @import("mem.zig").Allocator;

error ExtraArg;

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

    pub fn make(self: &Builder, args: []const []const u8) -> %void {
        var verbose = false;
        for (args) |arg| {
            if (mem.eql(u8, arg, "--verbose")) {
                verbose = true;
            } else {
                %%io.stderr.printf("Unrecognized argument: '{}'\n", arg);
                return error.ExtraArg;
            }
        }
        for (self.exe_list.toSlice()) |exe| {
            %%io.stderr.printf("TODO: invoke this command:\nzig build_exe {} --name {}\n", exe.root_src, exe.name);
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
