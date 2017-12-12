const std = @import("std");
const mem = std.mem;
const io = std.io;
const os = std.os;
const heap = std.heap;
const warn = std.debug.warn;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;
const Parser = @import("parser.zig").Parser;
const assert = std.debug.assert;
const target = @import("target.zig");

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

    const args = %return os.argsAlloc(allocator);
    defer os.argsFree(allocator, args);

    target.initializeAll();

    const target_file = args[1];

    const target_file_buf = %return io.readFileAlloc(target_file, allocator);
    defer allocator.free(target_file_buf);

    var stderr_file = %return std.io.getStdErr();
    var stderr_file_out_stream = std.io.FileOutStream.init(&stderr_file);
    const out_stream = &stderr_file_out_stream.stream;

    warn("====input:====\n");

    warn("{}", target_file_buf);

    warn("====tokenization:====\n");
    {
        var tokenizer = Tokenizer.init(target_file_buf);
        while (true) {
            const token = tokenizer.next();
            tokenizer.dump(token);
            if (token.id == Token.Id.Eof) {
                break;
            }
        }
    }

    warn("====parse:====\n");

    var tokenizer = Tokenizer.init(target_file_buf);
    var parser = Parser.init(&tokenizer, allocator, target_file);
    defer parser.deinit();

    const root_node = %return parser.parse();
    defer parser.freeAst(root_node);

    %return parser.renderAst(out_stream, root_node);

    warn("====fmt:====\n");
    %return parser.renderSource(out_stream, root_node);
}

test "import other tests" {
    _ = @import("parser.zig");
    _ = @import("tokenizer.zig");
}
