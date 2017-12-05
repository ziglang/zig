const builtin = @import("builtin");
const io = @import("std").io;
const os = @import("std").os;
const heap = @import("std").heap;
const warn = @import("std").debug.warn;


const Token = struct {

};

const Tokenizer = struct {

    pub fn next() -> Token {

    }

};


pub fn main() -> %void {
    main2() %% |err| {
        warn("{}\n", @errorName(err));
        return err;
    };
}

pub fn main2() -> %void {
    var incrementing_allocator = %return heap.IncrementingAllocator.init(10 * 1024 * 1024);
    defer incrementing_allocator.deinit();

    const allocator = &incrementing_allocator.allocator;

    const target_file = "input.zig"; // TODO

    const target_file_buf = %return io.readFileAlloc(target_file, allocator);

    warn("{}", target_file_buf);
}
