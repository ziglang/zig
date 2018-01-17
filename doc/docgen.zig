const std = @import("std");
const io = std.io;
const os = std.os;
const warn = std.debug.warn;
const mem = std.mem;

pub const max_doc_file_size = 10 * 1024 * 1024;

pub fn main() -> %void {
    // TODO use a more general purpose allocator here
    var inc_allocator = try std.heap.IncrementingAllocator.init(max_doc_file_size);
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

    const input_file_bytes = try file_in_stream.stream.readAllAlloc(allocator, max_doc_file_size);

    var file_out_stream = io.FileOutStream.init(&out_file);
    var buffered_out_stream = io.BufferedOutStream.init(&file_out_stream.stream);

    const toc = try genToc(allocator, in_file_name, input_file_bytes);

    try genHtml(allocator, toc, &buffered_out_stream.stream);
    try buffered_out_stream.flush();
}

const Token = struct {
    id: Id,
    start: usize,
    end: usize,

    const Id = enum {
        Invalid,
        Content,
        BracketOpen,
        TagContent,
        Separator,
        BracketClose,
        Eof,
    };
};

const Tokenizer = struct {
    buffer: []const u8,
    index: usize,
    state: State,
    source_file_name: []const u8,

    const State = enum {
        Start,
        LBracket,
        Hash,
        TagName,
        Eof,
    };

    fn init(source_file_name: []const u8, buffer: []const u8) -> Tokenizer {
        return Tokenizer {
            .buffer = buffer,
            .index = 0,
            .state = State.Start,
            .source_file_name = source_file_name,
        };
    }

    fn next(self: &Tokenizer) -> Token {
        var result = Token {
            .id = Token.Id.Eof,
            .start = self.index,
            .end = undefined,
        };
        while (self.index < self.buffer.len) : (self.index += 1) {
            const c = self.buffer[self.index];
            switch (self.state) {
                State.Start => switch (c) {
                    '{' => {
                        self.state = State.LBracket;
                    },
                    else => {
                        result.id = Token.Id.Content;
                    },
                },
                State.LBracket => switch (c) {
                    '#' => {
                        if (result.id != Token.Id.Eof) {
                            self.index -= 1;
                            self.state = State.Start;
                            break;
                        } else {
                            result.id = Token.Id.BracketOpen;
                            self.index += 1;
                            self.state = State.TagName;
                            break;
                        }
                    },
                    else => {
                        result.id = Token.Id.Content;
                        self.state = State.Start;
                    },
                },
                State.TagName => switch (c) {
                    '|' => {
                        if (result.id != Token.Id.Eof) {
                            break;
                        } else {
                            result.id = Token.Id.Separator;
                            self.index += 1;
                            break;
                        }
                    },
                    '#' => {
                        self.state = State.Hash;
                    },
                    else => {
                        result.id = Token.Id.TagContent;
                    },
                },
                State.Hash => switch (c) {
                    '}' => {
                        if (result.id != Token.Id.Eof) {
                            self.index -= 1;
                            self.state = State.TagName;
                            break;
                        } else {
                            result.id = Token.Id.BracketClose;
                            self.index += 1;
                            self.state = State.Start;
                            break;
                        }
                    },
                    else => {
                        result.id = Token.Id.TagContent;
                        self.state = State.TagName;
                    },
                },
                State.Eof => unreachable,
            }
        } else {
            switch (self.state) {
                State.Start, State.LBracket, State.Eof => {},
                else => {
                    result.id = Token.Id.Invalid;
                },
            }
            self.state = State.Eof;
        }
        result.end = self.index;
        return result;
    }

    const Location = struct {
        line: usize,
        column: usize,
        line_start: usize,
        line_end: usize,
    };

    fn getTokenLocation(self: &Tokenizer, token: &const Token) -> Location {
        var loc = Location {
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 0,
        };
        for (self.buffer) |c, i| {
            if (i == token.start) {
                loc.line_end = i;
                while (loc.line_end < self.buffer.len and self.buffer[loc.line_end] != '\n') : (loc.line_end += 1) {}
                return loc;
            }
            if (c == '\n') {
                loc.line += 1;
                loc.column = 0;
                loc.line_start = i + 1;
            } else {
                loc.column += 1;
            }
        }
        return loc;
    }
};

error ParseError;

fn parseError(tokenizer: &Tokenizer, token: &const Token, comptime fmt: []const u8, args: ...) -> error {
    const loc = tokenizer.getTokenLocation(token);
    warn("{}:{}:{}: error: " ++ fmt ++ "\n", tokenizer.source_file_name, loc.line + 1, loc.column + 1, args);
    if (loc.line_start <= loc.line_end) {
        warn("{}\n", tokenizer.buffer[loc.line_start..loc.line_end]);
        {
            var i: usize = 0;
            while (i < loc.column) : (i += 1) {
                warn(" ");
            }
        }
        {
            const caret_count = token.end - token.start;
            var i: usize = 0;
            while (i < caret_count) : (i += 1) {
                warn("~");
            }
        }
        warn("\n");
    }
    return error.ParseError;
}

fn assertToken(tokenizer: &Tokenizer, token: &const Token, id: Token.Id) -> %void {
    if (token.id != id) {
        return parseError(tokenizer, token, "expected {}, found {}", @tagName(id), @tagName(token.id));
    }
}

fn eatToken(tokenizer: &Tokenizer, id: Token.Id) -> %Token {
    const token = tokenizer.next();
    try assertToken(tokenizer, token, id);
    return token;
}

const HeaderOpen = struct {
    name: []const u8,
    url: []const u8,
    n: usize,
};

const Tag = enum {
    Nav,
    HeaderOpen,
    HeaderClose,
};

const Node = union(enum) {
    Content: []const u8,
    Nav,
    HeaderOpen: HeaderOpen,
};

const Toc = struct {
    nodes: []Node,
    toc: []u8,
};

const Action = enum {
    Open,
    Close,
};

fn genToc(allocator: &mem.Allocator, source_file_name: []const u8, input_file_bytes: []const u8) -> %Toc {
    var tokenizer = Tokenizer.init(source_file_name, input_file_bytes);

    var urls = std.HashMap([]const u8, Token, mem.hash_slice_u8, mem.eql_slice_u8).init(allocator);
    defer urls.deinit();

    var header_stack_size: usize = 0;
    var last_action = Action.Open;

    var toc_buf = try std.Buffer.initSize(allocator, 0);
    defer toc_buf.deinit();

    var toc_buf_adapter = io.BufferOutStream.init(&toc_buf);
    var toc = &toc_buf_adapter.stream;

    var nodes = std.ArrayList(Node).init(allocator);
    defer nodes.deinit();

    try toc.writeByte('\n');

    while (true) {
        const token = tokenizer.next();
        switch (token.id) {
            Token.Id.Eof => {
                if (header_stack_size != 0) {
                    return parseError(&tokenizer, token, "unbalanced headers");
                }
                try toc.write("    </ul>\n");
                break;
            },
            Token.Id.Content => {
                try nodes.append(Node {.Content = input_file_bytes[token.start..token.end] });
            },
            Token.Id.BracketOpen => {
                const tag_token = try eatToken(&tokenizer, Token.Id.TagContent);
                const tag_name = input_file_bytes[tag_token.start..tag_token.end];

                var tag: Tag = undefined;
                if (mem.eql(u8, tag_name, "nav")) {
                    tag = Tag.Nav;
                } else if (mem.eql(u8, tag_name, "header_open")) {
                    tag = Tag.HeaderOpen;
                    header_stack_size += 1;
                } else if (mem.eql(u8, tag_name, "header_close")) {
                    if (header_stack_size == 0) {
                        return parseError(&tokenizer, tag_token, "unbalanced close header");
                    }
                    header_stack_size -= 1;
                    tag = Tag.HeaderClose;
                } else {
                    return parseError(&tokenizer, tag_token, "unrecognized tag name: {}", tag_name);
                }

                var tag_content: ?[]const u8 = null;
                const maybe_sep = tokenizer.next();
                if (maybe_sep.id == Token.Id.Separator) {
                    const content_token = try eatToken(&tokenizer, Token.Id.TagContent);
                    tag_content = input_file_bytes[content_token.start..content_token.end];
                    _ = eatToken(&tokenizer, Token.Id.BracketClose);
                } else {
                    try assertToken(&tokenizer, maybe_sep, Token.Id.BracketClose);
                }

                switch (tag) {
                    Tag.HeaderOpen => {
                        const content = tag_content ?? return parseError(&tokenizer, tag_token, "expected header content");
                        const urlized = try urlize(allocator, content);
                        try nodes.append(Node{.HeaderOpen = HeaderOpen {
                            .name = content,
                            .url = urlized,
                            .n = header_stack_size,
                        }});
                        if (try urls.put(urlized, tag_token)) |other_tag_token| {
                            parseError(&tokenizer, tag_token, "duplicate header url: #{}", urlized) catch {};
                            parseError(&tokenizer, other_tag_token, "other tag here") catch {};
                            return error.ParseError;
                        }
                        if (last_action == Action.Open) {
                            try toc.writeByte('\n');
                            try toc.writeByteNTimes(' ', header_stack_size * 4);
                            try toc.write("<ul>\n");
                        } else {
                            last_action = Action.Open;
                        }
                        try toc.writeByteNTimes(' ', 4 + header_stack_size * 4);
                        try toc.print("<li><a href=\"#{}\">{}</a>", urlized, content);
                    },
                    Tag.HeaderClose => {
                        if (last_action == Action.Close) {
                            try toc.writeByteNTimes(' ', 8 + header_stack_size * 4);
                            try toc.write("</ul></li>\n");
                        } else {
                            try toc.write("</li>\n");
                            last_action = Action.Close;
                        }
                    },
                    Tag.Nav => {
                        try nodes.append(Node.Nav);
                    },
                }
            },
            else => return parseError(&tokenizer, token, "invalid token"),
        }
    }

    return Toc {
        .nodes = nodes.toOwnedSlice(),
        .toc = toc_buf.toOwnedSlice(),
    };
}

fn urlize(allocator: &mem.Allocator, input: []const u8) -> %[]u8 {
    var buf = try std.Buffer.initSize(allocator, 0);
    defer buf.deinit();

    var buf_adapter = io.BufferOutStream.init(&buf);
    var out = &buf_adapter.stream;
    for (input) |c| {
        switch (c) {
            'a'...'z', 'A'...'Z', '_', '-' => {
                try out.writeByte(c);
            },
            ' ' => {
                try out.writeByte('-');
            },
            else => {},
        }
    }
    return buf.toOwnedSlice();
}

fn genHtml(allocator: &mem.Allocator, toc: &const Toc, out: &io.OutStream) -> %void {
    for (toc.nodes) |node| {
        switch (node) {
            Node.Content => |data| {
                try out.write(data);
            },
            Node.Nav => {
                try out.write(toc.toc);
            },
            Node.HeaderOpen => |info| {
                try out.print("<h{} id=\"{}\">{}</h{}>\n", info.n, info.url, info.name, info.n);
            },
        }
    }

}
