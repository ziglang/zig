const std = @import("std");
const io = std.io;
const os = std.os;

pub fn main() -> %void {
    // TODO use a more general purpose allocator here
    var inc_allocator = try std.heap.IncrementingAllocator.init(5 * 1024 * 1024);
    defer inc_allocator.deinit();
    const allocator = &inc_allocator.allocator;

    var args_it = os.args();

    if (!args_it.skip()) @panic("expected self arg");

    const in_file_name = try (args_it.next(allocator) ?? @panic("expected input arg"));
    defer allocator.free(in_file_name);

    const out_file_name = try (args_it.next(allocator) ?? @panic("expected output arg"));
    defer allocator.free(out_file_name);

    var in_file = try io.File.openRead(in_file_name, allocator);
    defer in_file.close();

    var out_file = try io.File.openWrite(out_file_name, allocator);
    defer out_file.close();

    var file_in_stream = io.FileInStream.init(&in_file);
    var buffered_in_stream = io.BufferedInStream.init(&file_in_stream.stream);

    var file_out_stream = io.FileOutStream.init(&out_file);
    var buffered_out_stream = io.BufferedOutStream.init(&file_out_stream.stream);

    gen(&buffered_in_stream.stream, &buffered_out_stream.stream);
    try buffered_out_stream.flush();

}

const State = enum {
    Start,
    Derp,
};

// TODO look for code segments

fn gen(in: &io.InStream, out: &io.OutStream) {
    var state = State.Start;
    while (true) {
        const byte = in.readByte() catch |err| {
            if (err == error.EndOfStream) {
                return;
            }
            std.debug.panic("{}", err);
        };
        switch (state) {
            State.Start => switch (byte) {
                else => {
                    out.writeByte(byte) catch unreachable;
                },
            },
            State.Derp => unreachable,
        }
    }
}
