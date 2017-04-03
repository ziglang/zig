const root = @import("@build");
const std = @import("std");
const io = std.io;
const Builder = std.build.Builder;
const mem = std.mem;

error InvalidArgs;

pub fn main(args: [][]u8) -> %void {
    if (args.len < 2) {
        %%io.stderr.printf("Expected first argument to be path to zig compiler\n");
        return error.InvalidArgs;
    }
    const zig_exe = args[1];
    const leftover_args = args[2...];

    // TODO use a more general purpose allocator here
    var inc_allocator = %%mem.IncrementingAllocator.init(10 * 1024 * 1024);
    defer inc_allocator.deinit();

    var builder = Builder.init(zig_exe, &inc_allocator.allocator);
    root.build(&builder);
    %return builder.make(leftover_args);
}
