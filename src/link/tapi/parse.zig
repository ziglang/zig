const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.tapi);
const mem = std.mem;
const testing = std.testing;

const Allocator = mem.Allocator;
const Tokenizer = @import("Tokenizer.zig");
const Token = Tokenizer.Token;
const TokenIndex = Tokenizer.TokenIndex;
const TokenIterator = Tokenizer.TokenIterator;

pub const ParseError = error{
    MalformedYaml,
    NestedDocuments,
    UnexpectedTag,
    UnexpectedEof,
    UnexpectedToken,
    Unhandled,
} || Allocator.Error;

pub const Node = struct {
    tag: Tag,
    tree: *const Tree,

    pub const Tag = enum {
        doc,
        map,
        list,
        value,
    };

    pub fn cast(self: *const Node, comptime T: type) ?*const T {
        if (self.tag != T.base_tag) {
            return null;
        }
        return @fieldParentPtr(T, "base", self);
    }

    pub fn deinit(self: *Node, allocator: *Allocator) void {
        switch (self.tag) {
            .doc => @fieldParentPtr(Node.Doc, "base", self).deinit(allocator),
            .map => @fieldParentPtr(Node.Map, "base", self).deinit(allocator),
            .list => @fieldParentPtr(Node.List, "base", self).deinit(allocator),
            .value => {},
        }
    }

    pub fn format(
        self: *const Node,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        return switch (self.tag) {
            .doc => @fieldParentPtr(Node.Doc, "base", self).format(fmt, options, writer),
            .map => @fieldParentPtr(Node.Map, "base", self).format(fmt, options, writer),
            .list => @fieldParentPtr(Node.List, "base", self).format(fmt, options, writer),
            .value => @fieldParentPtr(Node.Value, "base", self).format(fmt, options, writer),
        };
    }

    pub const Doc = struct {
        base: Node = Node{ .tag = Tag.doc, .tree = undefined },
        start: ?TokenIndex = null,
        end: ?TokenIndex = null,
        directive: ?TokenIndex = null,
        value: ?*Node = null,

        pub const base_tag: Node.Tag = .doc;

        pub fn deinit(self: *Doc, allocator: *Allocator) void {
            if (self.value) |node| {
                node.deinit(allocator);
                allocator.destroy(node);
            }
        }

        pub fn format(
            self: *const Doc,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            if (self.directive) |id| {
                try std.fmt.format(writer, "{{ ", .{});
                const directive = self.base.tree.tokens[id];
                try std.fmt.format(writer, ".directive = {s}, ", .{
                    self.base.tree.source[directive.start..directive.end],
                });
            }
            if (self.value) |node| {
                try std.fmt.format(writer, "{}", .{node});
            }
            if (self.directive != null) {
                try std.fmt.format(writer, " }}", .{});
            }
        }
    };

    pub const Map = struct {
        base: Node = Node{ .tag = Tag.map, .tree = undefined },
        start: ?TokenIndex = null,
        end: ?TokenIndex = null,
        values: std.ArrayListUnmanaged(Entry) = .{},

        pub const base_tag: Node.Tag = .map;

        pub const Entry = struct {
            key: TokenIndex,
            value: *Node,
        };

        pub fn deinit(self: *Map, allocator: *Allocator) void {
            for (self.values.items) |entry| {
                entry.value.deinit(allocator);
                allocator.destroy(entry.value);
            }
            self.values.deinit(allocator);
        }

        pub fn format(
            self: *const Map,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            try std.fmt.format(writer, "{{ ", .{});
            for (self.values.items) |entry| {
                const key = self.base.tree.tokens[entry.key];
                try std.fmt.format(writer, "{s} => {}, ", .{
                    self.base.tree.source[key.start..key.end],
                    entry.value,
                });
            }
            return std.fmt.format(writer, " }}", .{});
        }
    };

    pub const List = struct {
        base: Node = Node{ .tag = Tag.list, .tree = undefined },
        start: ?TokenIndex = null,
        end: ?TokenIndex = null,
        values: std.ArrayListUnmanaged(*Node) = .{},

        pub const base_tag: Node.Tag = .list;

        pub fn deinit(self: *List, allocator: *Allocator) void {
            for (self.values.items) |node| {
                node.deinit(allocator);
                allocator.destroy(node);
            }
            self.values.deinit(allocator);
        }

        pub fn format(
            self: *const List,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            try std.fmt.format(writer, "[ ", .{});
            for (self.values.items) |node| {
                try std.fmt.format(writer, "{}, ", .{node});
            }
            return std.fmt.format(writer, " ]", .{});
        }
    };

    pub const Value = struct {
        base: Node = Node{ .tag = Tag.value, .tree = undefined },
        start: ?TokenIndex = null,
        end: ?TokenIndex = null,

        pub const base_tag: Node.Tag = .value;

        pub fn format(
            self: *const Value,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            const start = self.base.tree.tokens[self.start.?];
            const end = self.base.tree.tokens[self.end.?];
            return std.fmt.format(writer, "{s}", .{
                self.base.tree.source[start.start..end.end],
            });
        }
    };
};

pub const Tree = struct {
    allocator: *Allocator,
    source: []const u8,
    tokens: []Token,
    docs: std.ArrayListUnmanaged(*Node) = .{},

    pub fn init(allocator: *Allocator) Tree {
        return .{
            .allocator = allocator,
            .source = undefined,
            .tokens = undefined,
        };
    }

    pub fn deinit(self: *Tree) void {
        self.allocator.free(self.tokens);
        for (self.docs.items) |doc| {
            doc.deinit(self.allocator);
            self.allocator.destroy(doc);
        }
        self.docs.deinit(self.allocator);
    }

    pub fn parse(self: *Tree, source: []const u8) !void {
        var tokenizer = Tokenizer{ .buffer = source };
        var tokens = std.ArrayList(Token).init(self.allocator);
        errdefer tokens.deinit();

        while (true) {
            const token = tokenizer.next();
            try tokens.append(token);
            if (token.id == .Eof) break;
        }

        self.source = source;
        self.tokens = tokens.toOwnedSlice();

        var it = TokenIterator{ .buffer = self.tokens };
        var parser = Parser{
            .allocator = self.allocator,
            .tree = self,
            .token_it = &it,
        };
        defer parser.deinit();

        try parser.scopes.append(self.allocator, .{
            .indent = 0,
        });

        while (true) {
            if (parser.token_it.peek() == null) return;
            const pos = parser.token_it.pos;
            const token = parser.token_it.next();

            log.debug("Next token: {}, {}", .{ pos, token });

            switch (token.id) {
                .Space, .Comment, .NewLine => {},
                .Eof => break,
                else => {
                    const doc = try parser.doc(pos);
                    try self.docs.append(self.allocator, &doc.base);
                },
            }
        }
    }
};

const Parser = struct {
    allocator: *Allocator,
    tree: *Tree,
    token_it: *TokenIterator,
    scopes: std.ArrayListUnmanaged(Scope) = .{},

    const Scope = struct {
        indent: usize,
    };

    fn deinit(self: *Parser) void {
        self.scopes.deinit(self.allocator);
    }

    fn doc(self: *Parser, start: TokenIndex) ParseError!*Node.Doc {
        const node = try self.allocator.create(Node.Doc);
        errdefer self.allocator.destroy(node);
        node.* = .{
            .start = start,
        };
        node.base.tree = self.tree;

        self.token_it.seekTo(start);

        log.debug("Doc start: {}, {}", .{ start, self.tree.tokens[start] });

        const explicit_doc: bool = if (self.eatToken(.DocStart)) |_| explicit_doc: {
            if (self.eatToken(.Tag)) |_| {
                node.directive = try self.expectToken(.Literal);
            }
            _ = try self.expectToken(.NewLine);
            break :explicit_doc true;
        } else false;

        while (true) {
            const pos = self.token_it.pos;
            const token = self.token_it.next();

            log.debug("Next token: {}, {}", .{ pos, token });

            switch (token.id) {
                .Tag => {
                    return error.UnexpectedTag;
                },
                .Literal, .SingleQuote, .DoubleQuote => {
                    _ = try self.expectToken(.MapValueInd);
                    const map_node = try self.map(pos);
                    node.value = &map_node.base;
                },
                .SeqItemInd => {
                    const list_node = try self.list(pos);
                    node.value = &list_node.base;
                },
                .FlowSeqStart => {
                    const list_node = try self.list_bracketed(pos);
                    node.value = &list_node.base;
                },
                .DocEnd => {
                    if (explicit_doc) break;
                    return error.UnexpectedToken;
                },
                .DocStart, .Eof => {
                    self.token_it.seekBy(-1);
                    break;
                },
                else => {
                    return error.UnexpectedToken;
                },
            }
        }

        node.end = self.token_it.pos - 1;

        log.debug("Doc end: {}, {}", .{ node.end.?, self.tree.tokens[node.end.?] });

        return node;
    }

    fn map(self: *Parser, start: TokenIndex) ParseError!*Node.Map {
        const node = try self.allocator.create(Node.Map);
        errdefer self.allocator.destroy(node);
        node.* = .{
            .start = start,
        };
        node.base.tree = self.tree;

        self.token_it.seekTo(start);

        log.debug("Map start: {}, {}", .{ start, self.tree.tokens[start] });
        log.debug("Current scope: {}", .{self.scopes.items[self.scopes.items.len - 1]});

        while (true) {
            // Parse key.
            const key_pos = self.token_it.pos;
            const key = self.token_it.next();
            switch (key.id) {
                .Literal => {},
                else => {
                    self.token_it.seekBy(-1);
                    break;
                },
            }

            log.debug("Map key: {}, '{s}'", .{ key, self.tree.source[key.start..key.end] });

            // Separator
            _ = try self.expectToken(.MapValueInd);
            self.eatCommentsAndSpace();

            // Parse value.
            const value: *Node = value: {
                if (self.eatToken(.NewLine)) |_| {
                    // Explicit, complex value such as list or map.
                    try self.openScope();
                    const value_pos = self.token_it.pos;
                    const value = self.token_it.next();
                    switch (value.id) {
                        .Literal, .SingleQuote, .DoubleQuote => {
                            // Assume nested map.
                            const map_node = try self.map(value_pos);
                            break :value &map_node.base;
                        },
                        .SeqItemInd => {
                            // Assume list of values.
                            const list_node = try self.list(value_pos);
                            break :value &list_node.base;
                        },
                        else => {
                            log.err("{}", .{key});
                            return error.Unhandled;
                        },
                    }
                } else {
                    const value_pos = self.token_it.pos;
                    const value = self.token_it.next();
                    switch (value.id) {
                        .Literal, .SingleQuote, .DoubleQuote => {
                            // Assume leaf value.
                            const leaf_node = try self.leaf_value(value_pos);
                            break :value &leaf_node.base;
                        },
                        .FlowSeqStart => {
                            const list_node = try self.list_bracketed(value_pos);
                            break :value &list_node.base;
                        },
                        else => {
                            log.err("{}", .{key});
                            return error.Unhandled;
                        },
                    }
                }
            };
            log.debug("Map value: {}", .{value});

            try node.values.append(self.allocator, .{
                .key = key_pos,
                .value = value,
            });

            if (self.eatToken(.NewLine)) |_| {
                if (try self.closeScope()) {
                    break;
                }
            }
        }

        node.end = self.token_it.pos - 1;

        log.debug("Map end: {}, {}", .{ node.end.?, self.tree.tokens[node.end.?] });

        return node;
    }

    fn list(self: *Parser, start: TokenIndex) ParseError!*Node.List {
        const node = try self.allocator.create(Node.List);
        errdefer self.allocator.destroy(node);
        node.* = .{
            .start = start,
        };
        node.base.tree = self.tree;

        self.token_it.seekTo(start);

        log.debug("List start: {}, {}", .{ start, self.tree.tokens[start] });
        log.debug("Current scope: {}", .{self.scopes.items[self.scopes.items.len - 1]});

        while (true) {
            _ = self.eatToken(.SeqItemInd) orelse {
                _ = try self.closeScope();
                break;
            };
            self.eatCommentsAndSpace();

            const pos = self.token_it.pos;
            const token = self.token_it.next();
            const value: *Node = value: {
                switch (token.id) {
                    .Literal, .SingleQuote, .DoubleQuote => {
                        if (self.eatToken(.MapValueInd)) |_| {
                            if (self.eatToken(.NewLine)) |_| {
                                try self.openScope();
                            }
                            // nested map
                            const map_node = try self.map(pos);
                            break :value &map_node.base;
                        } else {
                            // standalone (leaf) value
                            const leaf_node = try self.leaf_value(pos);
                            break :value &leaf_node.base;
                        }
                    },
                    .FlowSeqStart => {
                        const list_node = try self.list_bracketed(pos);
                        break :value &list_node.base;
                    },
                    else => {
                        log.err("{}", .{token});
                        return error.Unhandled;
                    },
                }
            };
            try node.values.append(self.allocator, value);

            _ = self.eatToken(.NewLine);
        }

        node.end = self.token_it.pos - 1;

        log.debug("List end: {}, {}", .{ node.end.?, self.tree.tokens[node.end.?] });

        return node;
    }

    fn list_bracketed(self: *Parser, start: TokenIndex) ParseError!*Node.List {
        const node = try self.allocator.create(Node.List);
        errdefer self.allocator.destroy(node);
        node.* = .{
            .start = start,
        };
        node.base.tree = self.tree;

        self.token_it.seekTo(start);

        log.debug("List start: {}, {}", .{ start, self.tree.tokens[start] });
        log.debug("Current scope: {}", .{self.scopes.items[self.scopes.items.len - 1]});

        _ = try self.expectToken(.FlowSeqStart);

        while (true) {
            _ = self.eatToken(.NewLine);
            self.eatCommentsAndSpace();

            const pos = self.token_it.pos;
            const token = self.token_it.next();

            log.debug("Next token: {}, {}", .{ pos, token });

            const value: *Node = value: {
                switch (token.id) {
                    .FlowSeqStart => {
                        const list_node = try self.list_bracketed(pos);
                        break :value &list_node.base;
                    },
                    .FlowSeqEnd => {
                        break;
                    },
                    .Literal, .SingleQuote, .DoubleQuote => {
                        const leaf_node = try self.leaf_value(pos);
                        _ = self.eatToken(.Comma);
                        // TODO newline
                        break :value &leaf_node.base;
                    },
                    else => {
                        log.err("{}", .{token});
                        return error.Unhandled;
                    },
                }
            };
            try node.values.append(self.allocator, value);
        }

        node.end = self.token_it.pos - 1;

        log.debug("List end: {}, {}", .{ node.end.?, self.tree.tokens[node.end.?] });

        return node;
    }

    fn leaf_value(self: *Parser, start: TokenIndex) ParseError!*Node.Value {
        const node = try self.allocator.create(Node.Value);
        errdefer self.allocator.destroy(node);
        node.* = .{
            .start = start,
        };
        node.base.tree = self.tree;

        self.token_it.seekTo(start);

        log.debug("Leaf start: {}, {}", .{ node.start.?, self.tree.tokens[node.start.?] });

        parse: {
            if (self.eatToken(.SingleQuote)) |_| {
                node.start = node.start.? + 1;
                while (true) {
                    const tok = self.token_it.next();
                    switch (tok.id) {
                        .SingleQuote => {
                            node.end = self.token_it.pos - 2;
                            break :parse;
                        },
                        .NewLine => return error.UnexpectedToken,
                        else => {},
                    }
                }
            }

            if (self.eatToken(.DoubleQuote)) |_| {
                node.start = node.start.? + 1;
                while (true) {
                    const tok = self.token_it.next();
                    switch (tok.id) {
                        .DoubleQuote => {
                            node.end = self.token_it.pos - 2;
                            break :parse;
                        },
                        .NewLine => return error.UnexpectedToken,
                        else => {},
                    }
                }
            }

            // TODO handle multiline strings in new block scope
            while (true) {
                const tok = self.token_it.next();
                switch (tok.id) {
                    .Literal => {},
                    .Space => {
                        const trailing = self.token_it.pos - 2;
                        self.eatCommentsAndSpace();
                        if (self.token_it.peek()) |peek| {
                            if (peek.id != .Literal) {
                                node.end = trailing;
                                break;
                            }
                        }
                    },
                    else => {
                        self.token_it.seekBy(-1);
                        node.end = self.token_it.pos - 1;
                        break;
                    },
                }
            }
        }

        log.debug("Leaf end: {}, {}", .{ node.end.?, self.tree.tokens[node.end.?] });

        return node;
    }

    fn openScope(self: *Parser) !void {
        const peek = self.token_it.peek() orelse return error.UnexpectedEof;
        if (peek.id != .Space and peek.id != .Tab) {
            // No need to open scope.
            return;
        }
        const indent = self.token_it.next().count.?;
        const prev_scope = self.scopes.items[self.scopes.items.len - 1];
        if (indent < prev_scope.indent) {
            return error.MalformedYaml;
        }

        log.debug("Opening scope...", .{});

        try self.scopes.append(self.allocator, .{
            .indent = indent,
        });
    }

    fn closeScope(self: *Parser) !bool {
        const indent = indent: {
            const peek = self.token_it.peek() orelse return error.UnexpectedEof;
            switch (peek.id) {
                .Space, .Tab => {
                    break :indent self.token_it.next().count.?;
                },
                else => {
                    break :indent 0;
                },
            }
        };

        const scope = self.scopes.items[self.scopes.items.len - 1];
        if (indent < scope.indent) {
            log.debug("Closing scope...", .{});
            _ = self.scopes.pop();
            return true;
        }

        return false;
    }

    fn eatCommentsAndSpace(self: *Parser) void {
        while (true) {
            _ = self.token_it.peek() orelse return;
            const token = self.token_it.next();
            switch (token.id) {
                .Comment, .Space => {},
                else => {
                    self.token_it.seekBy(-1);
                    break;
                },
            }
        }
    }

    fn eatToken(self: *Parser, id: Token.Id) ?TokenIndex {
        while (true) {
            const pos = self.token_it.pos;
            _ = self.token_it.peek() orelse return null;
            const token = self.token_it.next();
            switch (token.id) {
                .Comment, .Space => continue,
                else => |next_id| if (next_id == id) {
                    return pos;
                } else {
                    self.token_it.seekTo(pos);
                    return null;
                },
            }
        }
    }

    fn expectToken(self: *Parser, id: Token.Id) ParseError!TokenIndex {
        return self.eatToken(id) orelse error.UnexpectedToken;
    }
};

test {
    _ = @import("parse/test.zig");
}
