const std = @import("std");
const mem = std.mem;
const builtin = @import("builtin");
const io = std.io;
const os = std.os;
const heap = std.heap;
const warn = std.debug.warn;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;
const Parser = @import("parser.zig").Parser;

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


var fixed_buffer_mem: [100 * 1024]u8 = undefined;

fn testCanonical(source: []const u8) {
    var fixed_allocator = mem.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
    const allocator = &fixed_allocator.allocator;

    var tokenizer = Tokenizer.init(source);
    var parser = Parser.init(&tokenizer, allocator, "(memory buffer)");
    defer parser.deinit();

    const root_node = parser.parse() %% unreachable;
    defer parser.freeAst(root_node);

    var buffer = std.Buffer.initSize(allocator, 0) %% unreachable;
    var buffer_out_stream = io.BufferOutStream.init(&buffer);
    parser.renderSource(&buffer_out_stream.stream, root_node) %% unreachable;

    if (!mem.eql(u8, buffer.toSliceConst(), source)) {
        warn("\n====== expected this output: =========\n");
        warn("{}", source);
        warn("\n======== instead found this: =========\n");
        warn("{}", buffer.toSliceConst());
        warn("\n======================================\n");
        @panic("test failed");
    }
}

test "zig fmt" {
    if (builtin.os == builtin.Os.windows and builtin.arch == builtin.Arch.i386) {
        // TODO get this test passing
        // https://github.com/zig-lang/zig/issues/537
        return;
    }

    testCanonical(
        \\extern fn puts(s: &const u8) -> c_int;
        \\
    );

    testCanonical(
        \\const a = b;
        \\pub const a = b;
        \\var a = b;
        \\pub var a = b;
        \\const a: i32 = b;
        \\pub const a: i32 = b;
        \\var a: i32 = b;
        \\pub var a: i32 = b;
        \\
    );

    testCanonical(
        \\extern var foo: c_int;
        \\
    );

    testCanonical(
        \\fn main(argc: c_int, argv: &&u8) -> c_int {
        \\    const a = b;
        \\}
        \\
    );

    testCanonical(
        \\fn foo(argc: c_int, argv: &&u8) -> c_int {
        \\    return 0;
        \\}
        \\
    );
}
