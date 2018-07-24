const std = @import("std");
const mem = std.mem;
const os = std.os;
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
    span: Span,
    text: []u8,
    data: Data,

    const Data = union(enum) {
        PathAndTree: PathAndTree,
        ScopeAndComp: ScopeAndComp,
    };

    const PathAndTree = struct {
        realpath: []const u8,
        tree: *ast.Tree,
        allocator: *mem.Allocator,
    };

    const ScopeAndComp = struct {
        root_scope: *Scope.Root,
        compilation: *Compilation,
    };

    pub fn destroy(self: *Msg) void {
        switch (self.data) {
            Data.PathAndTree => |path_and_tree| {
                path_and_tree.allocator.free(self.text);
                path_and_tree.allocator.destroy(self);
            },
            Data.ScopeAndComp => |scope_and_comp| {
                scope_and_comp.root_scope.base.deref(scope_and_comp.compilation);
                scope_and_comp.compilation.gpa().free(self.text);
                scope_and_comp.compilation.gpa().destroy(self);
            },
        }
    }

    fn getAllocator(self: *const Msg) *mem.Allocator {
        switch (self.data) {
            Data.PathAndTree => |path_and_tree| {
                return path_and_tree.allocator;
            },
            Data.ScopeAndComp => |scope_and_comp| {
                return scope_and_comp.compilation.gpa();
            },
        }
    }

    pub fn getRealPath(self: *const Msg) []const u8 {
        switch (self.data) {
            Data.PathAndTree => |path_and_tree| {
                return path_and_tree.realpath;
            },
            Data.ScopeAndComp => |scope_and_comp| {
                return scope_and_comp.root_scope.realpath;
            },
        }
    }

    pub fn getTree(self: *const Msg) *ast.Tree {
        switch (self.data) {
            Data.PathAndTree => |path_and_tree| {
                return path_and_tree.tree;
            },
            Data.ScopeAndComp => |scope_and_comp| {
                return scope_and_comp.root_scope.tree;
            },
        }
    }

    /// Takes ownership of text
    /// References root_scope, and derefs when the msg is freed
    pub fn createFromScope(comp: *Compilation, root_scope: *Scope.Root, span: Span, text: []u8) !*Msg {
        const msg = try comp.gpa().create(Msg{
            .text = text,
            .span = span,
            .data = Data{
                .ScopeAndComp = ScopeAndComp{
                    .root_scope = root_scope,
                    .compilation = comp,
                },
            },
        });
        root_scope.base.ref();
        return msg;
    }

    pub fn createFromParseErrorAndScope(
        comp: *Compilation,
        root_scope: *Scope.Root,
        parse_error: *const ast.Error,
    ) !*Msg {
        const loc_token = parse_error.loc();
        var text_buf = try std.Buffer.initSize(comp.gpa(), 0);
        defer text_buf.deinit();

        var out_stream = &std.io.BufferOutStream.init(&text_buf).stream;
        try parse_error.render(&root_scope.tree.tokens, out_stream);

        const msg = try comp.gpa().create(Msg{
            .text = undefined,
            .span = Span{
                .first = loc_token,
                .last = loc_token,
            },
            .data = Data{
                .ScopeAndComp = ScopeAndComp{
                    .root_scope = root_scope,
                    .compilation = comp,
                },
            },
        });
        root_scope.base.ref();
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

        var out_stream = &std.io.BufferOutStream.init(&text_buf).stream;
        try parse_error.render(&tree.tokens, out_stream);

        const msg = try allocator.create(Msg{
            .text = undefined,
            .data = Data{
                .PathAndTree = PathAndTree{
                    .allocator = allocator,
                    .realpath = realpath,
                    .tree = tree,
                },
            },
            .span = Span{
                .first = loc_token,
                .last = loc_token,
            },
        });
        msg.text = text_buf.toOwnedSlice();
        errdefer allocator.destroy(msg);

        return msg;
    }

    pub fn printToStream(msg: *const Msg, stream: var, color_on: bool) !void {
        const allocator = msg.getAllocator();
        const realpath = msg.getRealPath();
        const tree = msg.getTree();

        const cwd = try os.getCwd(allocator);
        defer allocator.free(cwd);

        const relpath = try os.path.relative(allocator, cwd, realpath);
        defer allocator.free(relpath);

        const path = if (relpath.len < realpath.len) relpath else realpath;

        const first_token = tree.tokens.at(msg.span.first);
        const last_token = tree.tokens.at(msg.span.last);
        const start_loc = tree.tokenLocationPtr(0, first_token);
        const end_loc = tree.tokenLocationPtr(first_token.end, last_token);
        if (!color_on) {
            try stream.print(
                "{}:{}:{}: error: {}\n",
                path,
                start_loc.line + 1,
                start_loc.column + 1,
                msg.text,
            );
            return;
        }

        try stream.print(
            "{}:{}:{}: error: {}\n{}\n",
            path,
            start_loc.line + 1,
            start_loc.column + 1,
            msg.text,
            tree.source[start_loc.line_start..start_loc.line_end],
        );
        try stream.writeByteNTimes(' ', start_loc.column);
        try stream.writeByteNTimes('~', last_token.end - first_token.start);
        try stream.write("\n");
    }

    pub fn printToFile(msg: *const Msg, file: *os.File, color: Color) !void {
        const color_on = switch (color) {
            Color.Auto => file.isTty(),
            Color.On => true,
            Color.Off => false,
        };
        var stream = &std.io.FileOutStream.init(file).stream;
        return msg.printToStream(stream, color_on);
    }
};
