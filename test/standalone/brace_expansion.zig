const std = @import("std");
const io = std.io;
const mem = std.mem;
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const ArrayList = std.ArrayList;
const maxInt = std.math.maxInt;

const Token = union(enum) {
    Word: []const u8,
    OpenBrace,
    CloseBrace,
    Comma,
    Eof,
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var global_allocator = gpa.allocator();

fn tokenize(input: []const u8) !ArrayList(Token) {
    const State = enum {
        Start,
        Word,
    };

    var token_list = ArrayList(Token).init(global_allocator);
    errdefer token_list.deinit();
    var tok_begin: usize = undefined;
    var state = State.Start;

    for (input, 0..) |b, i| {
        switch (state) {
            .Start => switch (b) {
                'a'...'z', 'A'...'Z' => {
                    state = State.Word;
                    tok_begin = i;
                },
                '{' => try token_list.append(Token.OpenBrace),
                '}' => try token_list.append(Token.CloseBrace),
                ',' => try token_list.append(Token.Comma),
                else => return error.InvalidInput,
            },
            .Word => switch (b) {
                'a'...'z', 'A'...'Z' => {},
                '{', '}', ',' => {
                    try token_list.append(Token{ .Word = input[tok_begin..i] });
                    switch (b) {
                        '{' => try token_list.append(Token.OpenBrace),
                        '}' => try token_list.append(Token.CloseBrace),
                        ',' => try token_list.append(Token.Comma),
                        else => unreachable,
                    }
                    state = State.Start;
                },
                else => return error.InvalidInput,
            },
        }
    }
    switch (state) {
        State.Start => {},
        State.Word => try token_list.append(Token{ .Word = input[tok_begin..] }),
    }
    try token_list.append(Token.Eof);
    return token_list;
}

const Node = union(enum) {
    Scalar: []const u8,
    List: ArrayList(Node),
    Combine: []Node,

    fn deinit(self: Node) void {
        switch (self) {
            .Scalar => {},
            .Combine => |pair| {
                pair[0].deinit();
                pair[1].deinit();
                global_allocator.free(pair);
            },
            .List => |list| {
                for (list.items) |item| {
                    item.deinit();
                }
                list.deinit();
            },
        }
    }
};

const ParseError = error{
    InvalidInput,
    OutOfMemory,
};

fn parse(tokens: *const ArrayList(Token), token_index: *usize) ParseError!Node {
    const first_token = tokens.items[token_index.*];
    token_index.* += 1;

    const result_node = switch (first_token) {
        .Word => |word| Node{ .Scalar = word },
        .OpenBrace => blk: {
            var list = ArrayList(Node).init(global_allocator);
            errdefer {
                for (list.items) |node| node.deinit();
                list.deinit();
            }
            while (true) {
                try list.append(try parse(tokens, token_index));

                const token = tokens.items[token_index.*];
                token_index.* += 1;

                switch (token) {
                    .CloseBrace => break,
                    .Comma => continue,
                    else => return error.InvalidInput,
                }
            }
            break :blk Node{ .List = list };
        },
        else => return error.InvalidInput,
    };

    switch (tokens.items[token_index.*]) {
        .Word, .OpenBrace => {
            const pair = try global_allocator.alloc(Node, 2);
            errdefer global_allocator.free(pair);
            pair[0] = result_node;
            pair[1] = try parse(tokens, token_index);
            return Node{ .Combine = pair };
        },
        else => return result_node,
    }
}

fn expandString(input: []const u8, output: *ArrayList(u8)) !void {
    const tokens = try tokenize(input);
    defer tokens.deinit();
    if (tokens.items.len == 1) {
        return output.resize(0);
    }

    var token_index: usize = 0;
    const root = try parse(&tokens, &token_index);
    defer root.deinit();
    const last_token = tokens.items[token_index];
    switch (last_token) {
        Token.Eof => {},
        else => return error.InvalidInput,
    }

    var result_list = ArrayList(ArrayList(u8)).init(global_allocator);
    defer {
        for (result_list.items) |*buf| buf.deinit();
        result_list.deinit();
    }

    try expandNode(root, &result_list);

    try output.resize(0);
    for (result_list.items, 0..) |buf, i| {
        if (i != 0) {
            try output.append(' ');
        }
        try output.appendSlice(buf.items);
    }
}

const ExpandNodeError = error{OutOfMemory};

fn expandNode(node: Node, output: *ArrayList(ArrayList(u8))) ExpandNodeError!void {
    assert(output.items.len == 0);
    switch (node) {
        .Scalar => |scalar| {
            var list = ArrayList(u8).init(global_allocator);
            errdefer list.deinit();
            try list.appendSlice(scalar);
            try output.append(list);
        },
        .Combine => |pair| {
            const a_node = pair[0];
            const b_node = pair[1];

            var child_list_a = ArrayList(ArrayList(u8)).init(global_allocator);
            defer {
                for (child_list_a.items) |*buf| buf.deinit();
                child_list_a.deinit();
            }
            try expandNode(a_node, &child_list_a);

            var child_list_b = ArrayList(ArrayList(u8)).init(global_allocator);
            defer {
                for (child_list_b.items) |*buf| buf.deinit();
                child_list_b.deinit();
            }
            try expandNode(b_node, &child_list_b);

            for (child_list_a.items) |buf_a| {
                for (child_list_b.items) |buf_b| {
                    var combined_buf = ArrayList(u8).init(global_allocator);
                    errdefer combined_buf.deinit();

                    try combined_buf.appendSlice(buf_a.items);
                    try combined_buf.appendSlice(buf_b.items);
                    try output.append(combined_buf);
                }
            }
        },
        .List => |list| {
            for (list.items) |child_node| {
                var child_list = ArrayList(ArrayList(u8)).init(global_allocator);
                errdefer for (child_list.items) |*buf| buf.deinit();
                defer child_list.deinit();

                try expandNode(child_node, &child_list);

                for (child_list.items) |buf| {
                    try output.append(buf);
                }
            }
        },
    }
}

pub fn main() !void {
    defer _ = gpa.deinit();
    const stdin_file = io.getStdIn();
    const stdout_file = io.getStdOut();

    const stdin = try stdin_file.reader().readAllAlloc(global_allocator, std.math.maxInt(usize));
    defer global_allocator.free(stdin);

    var result_buf = ArrayList(u8).init(global_allocator);
    defer result_buf.deinit();

    try expandString(stdin, &result_buf);
    try stdout_file.writeAll(result_buf.items);
}

test "invalid inputs" {
    global_allocator = std.testing.allocator;

    try expectError("}ABC", error.InvalidInput);
    try expectError("{ABC", error.InvalidInput);
    try expectError("}{", error.InvalidInput);
    try expectError("{}", error.InvalidInput);
    try expectError("A,B,C", error.InvalidInput);
    try expectError("{A{B,C}", error.InvalidInput);
    try expectError("{A,}", error.InvalidInput);

    try expectError("\n", error.InvalidInput);
}

fn expectError(test_input: []const u8, expected_err: anyerror) !void {
    var output_buf = ArrayList(u8).init(global_allocator);
    defer output_buf.deinit();

    try testing.expectError(expected_err, expandString(test_input, &output_buf));
}

test "valid inputs" {
    global_allocator = std.testing.allocator;

    try expectExpansion("{x,y,z}", "x y z");
    try expectExpansion("{A,B}{x,y}", "Ax Ay Bx By");
    try expectExpansion("{A,B{x,y}}", "A Bx By");

    try expectExpansion("{ABC}", "ABC");
    try expectExpansion("{A,B,C}", "A B C");
    try expectExpansion("ABC", "ABC");

    try expectExpansion("", "");
    try expectExpansion("{A,B}{C,{x,y}}{g,h}", "ACg ACh Axg Axh Ayg Ayh BCg BCh Bxg Bxh Byg Byh");
    try expectExpansion("{A,B}{C,C{x,y}}{g,h}", "ACg ACh ACxg ACxh ACyg ACyh BCg BCh BCxg BCxh BCyg BCyh");
    try expectExpansion("{A,B}a", "Aa Ba");
    try expectExpansion("{C,{x,y}}", "C x y");
    try expectExpansion("z{C,{x,y}}", "zC zx zy");
    try expectExpansion("a{b,c{d,e{f,g}}}", "ab acd acef aceg");
    try expectExpansion("a{x,y}b", "axb ayb");
    try expectExpansion("z{{a,b}}", "za zb");
    try expectExpansion("a{b}", "ab");
}

fn expectExpansion(test_input: []const u8, expected_result: []const u8) !void {
    var result = ArrayList(u8).init(global_allocator);
    defer result.deinit();

    expandString(test_input, &result) catch unreachable;

    try testing.expectEqualSlices(u8, expected_result, result.items);
}
