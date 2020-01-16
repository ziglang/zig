const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const Token = std.zig.Token;
const ast = std.zig.ast;
const TokenIndex = std.zig.ast.TokenIndex;
const Compilation = @import("compilation.zig").Compilation;
const Scope = @import("scope.zig").Scope;

pub const Color = enum {
    Auto,
    Off,
    On,
};

pub const Span = struct {
    first: ast.TokenIndex,
    last: ast.TokenIndex,

    pub fn token(i: TokenIndex) Span {
        return Span{
            .first = i,
            .last = i,
        };
    }

    pub fn node(n: *ast.Node) Span {
        return Span{
            .first = n.firstToken(),
            .last = n.lastToken(),
        };
    }
};

pub const Msg = struct {
    text: []u8,
    realpath: []u8,
    data: Data,

    const Data = union(enum) {
        Cli: Cli,
        PathAndTree: PathAndTree,
        ScopeAndComp: ScopeAndComp,
    };

    const PathAndTree = struct {
        span: Span,
        tree: *ast.Tree,
        allocator: *mem.Allocator,
    };

    const ScopeAndComp = struct {
        span: Span,
        tree_scope: *Scope.AstTree,
        compilation: *Compilation,
    };

    const Cli = struct {
        allocator: *mem.Allocator,
    };

    pub fn destroy(self: *Msg) void {
        switch (self.data) {
            .Cli => |cli| {
                cli.allocator.free(self.text);
                cli.allocator.free(self.realpath);
                cli.allocator.destroy(self);
            },
            .PathAndTree => |path_and_tree| {
                path_and_tree.allocator.free(self.text);
                path_and_tree.allocator.free(self.realpath);
                path_and_tree.allocator.destroy(self);
            },
            .ScopeAndComp => |scope_and_comp| {
                scope_and_comp.tree_scope.base.deref(scope_and_comp.compilation);
                scope_and_comp.compilation.gpa().free(self.text);
                scope_and_comp.compilation.gpa().free(self.realpath);
                scope_and_comp.compilation.gpa().destroy(self);
            },
        }
    }

    fn getAllocator(self: *const Msg) *mem.Allocator {
        switch (self.data) {
            .Cli => |cli| return cli.allocator,
            .PathAndTree => |path_and_tree| {
                return path_and_tree.allocator;
            },
            .ScopeAndComp => |scope_and_comp| {
                return scope_and_comp.compilation.gpa();
            },
        }
    }

    pub fn getTree(self: *const Msg) *ast.Tree {
        switch (self.data) {
            .Cli => unreachable,
            .PathAndTree => |path_and_tree| {
                return path_and_tree.tree;
            },
            .ScopeAndComp => |scope_and_comp| {
                return scope_and_comp.tree_scope.tree;
            },
        }
    }

    pub fn getSpan(self: *const Msg) Span {
        return switch (self.data) {
            .Cli => unreachable,
            .PathAndTree => |path_and_tree| path_and_tree.span,
            .ScopeAndComp => |scope_and_comp| scope_and_comp.span,
        };
    }

    /// Takes ownership of text
    /// References tree_scope, and derefs when the msg is freed
    pub fn createFromScope(comp: *Compilation, tree_scope: *Scope.AstTree, span: Span, text: []u8) !*Msg {
        const realpath = try mem.dupe(comp.gpa(), u8, tree_scope.root().realpath);
        errdefer comp.gpa().free(realpath);

        const msg = try comp.gpa().create(Msg);
        msg.* = Msg{
            .text = text,
            .realpath = realpath,
            .data = Data{
                .ScopeAndComp = ScopeAndComp{
                    .tree_scope = tree_scope,
                    .compilation = comp,
                    .span = span,
                },
            },
        };
        tree_scope.base.ref();
        return msg;
    }

    /// Caller owns returned Msg and must free with `allocator`
    /// allocator will additionally be used for printing messages later.
    pub fn createFromCli(comp: *Compilation, realpath: []const u8, text: []u8) !*Msg {
        const realpath_copy = try mem.dupe(comp.gpa(), u8, realpath);
        errdefer comp.gpa().free(realpath_copy);

        const msg = try comp.gpa().create(Msg);
        msg.* = Msg{
            .text = text,
            .realpath = realpath_copy,
            .data = Data{
                .Cli = Cli{ .allocator = comp.gpa() },
            },
        };
        return msg;
    }

    pub fn createFromParseErrorAndScope(
        comp: *Compilation,
        tree_scope: *Scope.AstTree,
        parse_error: *const ast.Error,
    ) !*Msg {
        const loc_token = parse_error.loc();
        var text_buf = try std.Buffer.initSize(comp.gpa(), 0);
        defer text_buf.deinit();

        const realpath_copy = try mem.dupe(comp.gpa(), u8, tree_scope.root().realpath);
        errdefer comp.gpa().free(realpath_copy);

        var out_stream = &std.io.BufferOutStream.init(&text_buf).stream;
        try parse_error.render(&tree_scope.tree.tokens, out_stream);

        const msg = try comp.gpa().create(Msg);
        msg.* = Msg{
            .text = undefined,
            .realpath = realpath_copy,
            .data = Data{
                .ScopeAndComp = ScopeAndComp{
                    .tree_scope = tree_scope,
                    .compilation = comp,
                    .span = Span{
                        .first = loc_token,
                        .last = loc_token,
                    },
                },
            },
        };
        tree_scope.base.ref();
        msg.text = text_buf.toOwnedSlice();
        return msg;
    }

    /// `realpath` must outlive the returned Msg
    /// `tree` must outlive the returned Msg
    /// Caller owns returned Msg and must free with `allocator`
    /// allocator will additionally be used for printing messages later.
    pub fn createFromParseError(
        allocator: *mem.Allocator,
        parse_error: *const ast.Error,
        tree: *ast.Tree,
        realpath: []const u8,
    ) !*Msg {
        const loc_token = parse_error.loc();
        var text_buf = try std.Buffer.initSize(allocator, 0);
        defer text_buf.deinit();

        const realpath_copy = try mem.dupe(allocator, u8, realpath);
        errdefer allocator.free(realpath_copy);

        var out_stream = &std.io.BufferOutStream.init(&text_buf).stream;
        try parse_error.render(&tree.tokens, out_stream);

        const msg = try allocator.create(Msg);
        msg.* = Msg{
            .text = undefined,
            .realpath = realpath_copy,
            .data = Data{
                .PathAndTree = PathAndTree{
                    .allocator = allocator,
                    .tree = tree,
                    .span = Span{
                        .first = loc_token,
                        .last = loc_token,
                    },
                },
            },
        };
        msg.text = text_buf.toOwnedSlice();
        errdefer allocator.destroy(msg);

        return msg;
    }

    pub fn printToStream(msg: *const Msg, stream: var, color_on: bool) !void {
        switch (msg.data) {
            .Cli => {
                try stream.print("{}:-:-: error: {}\n", .{ msg.realpath, msg.text });
                return;
            },
            else => {},
        }

        const allocator = msg.getAllocator();
        const tree = msg.getTree();

        const cwd = try process.getCwdAlloc(allocator);
        defer allocator.free(cwd);

        const relpath = try fs.path.relative(allocator, cwd, msg.realpath);
        defer allocator.free(relpath);

        const path = if (relpath.len < msg.realpath.len) relpath else msg.realpath;
        const span = msg.getSpan();

        const first_token = tree.tokens.at(span.first);
        const last_token = tree.tokens.at(span.last);
        const start_loc = tree.tokenLocationPtr(0, first_token);
        const end_loc = tree.tokenLocationPtr(first_token.end, last_token);
        if (!color_on) {
            try stream.print("{}:{}:{}: error: {}\n", .{
                path,
                start_loc.line + 1,
                start_loc.column + 1,
                msg.text,
            });
            return;
        }

        try stream.print("{}:{}:{}: error: {}\n{}\n", .{
            path,
            start_loc.line + 1,
            start_loc.column + 1,
            msg.text,
            tree.source[start_loc.line_start..start_loc.line_end],
        });
        try stream.writeByteNTimes(' ', start_loc.column);
        try stream.writeByteNTimes('~', last_token.end - first_token.start);
        try stream.write("\n");
    }

    pub fn printToFile(msg: *const Msg, file: fs.File, color: Color) !void {
        const color_on = switch (color) {
            .Auto => file.isTty(),
            .On => true,
            .Off => false,
        };
        var stream = &file.outStream().stream;
        return msg.printToStream(stream, color_on);
    }
};
