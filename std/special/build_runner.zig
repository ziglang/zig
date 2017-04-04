const root = @import("@build");
const std = @import("std");
const io = std.io;
const os = std.os;
const Builder = std.build.Builder;
const mem = std.mem;

error InvalidArgs;

pub fn main() -> %void {
    if (os.args.count() < 2) {
        %%io.stderr.printf("Expected first argument to be path to zig compiler\n");
        return error.InvalidArgs;
    }
    const zig_exe = os.args.at(1);
    const leftover_arg_index = 2;

    // TODO use a more general purpose allocator here
    var inc_allocator = %%mem.IncrementingAllocator.init(10 * 1024 * 1024);
    defer inc_allocator.deinit();

    var builder = Builder.init(zig_exe, &inc_allocator.allocator);
    root.build(&builder);
    %return builder.make(leftover_arg_index);
}
