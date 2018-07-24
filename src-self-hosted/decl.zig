const std = @import("std");
const Allocator = mem.Allocator;
const mem = std.mem;
const ast = std.zig.ast;
const Visib = @import("visib.zig").Visib;
const event = std.event;
const Value = @import("value.zig").Value;
const Token = std.zig.Token;
const errmsg = @import("errmsg.zig");
const Scope = @import("scope.zig").Scope;
const Compilation = @import("compilation.zig").Compilation;

pub const Decl = struct {
    id: Id,
    name: []const u8,
    visib: Visib,
    resolution: event.Future(Compilation.BuildError!void),
    parent_scope: *Scope,

    pub const Table = std.HashMap([]const u8, *Decl, mem.hash_slice_u8, mem.eql_slice_u8);

    pub fn isExported(base: *const Decl, tree: *ast.Tree) bool {
        switch (base.id) {
            Id.Fn => {
                const fn_decl = @fieldParentPtr(Fn, "base", base);
                return fn_decl.isExported(tree);
            },
            else => return false,
        }
    }

    pub fn getSpan(base: *const Decl) errmsg.Span {
        switch (base.id) {
            Id.Fn => {
                const fn_decl = @fieldParentPtr(Fn, "base", base);
                const fn_proto = fn_decl.fn_proto;
                const start = fn_proto.fn_token;
                const end = fn_proto.name_token orelse start;
                return errmsg.Span{
                    .first = start,
                    .last = end + 1,
                };
            },
            else => @panic("TODO"),
        }
    }

    pub fn findRootScope(base: *const Decl) *Scope.Root {
        return base.parent_scope.findRoot();
    }

    pub const Id = enum {
        Var,
        Fn,
        CompTime,
    };

    pub const Var = struct {
        base: Decl,
    };

    pub const Fn = struct {
        base: Decl,
        value: Val,
        fn_proto: *ast.Node.FnProto,

        // TODO https://github.com/ziglang/zig/issues/683 and then make this anonymous
        pub const Val = union(enum) {
            Unresolved: void,
            Fn: *Value.Fn,
            FnProto: *Value.FnProto,
        };

        pub fn externLibName(self: Fn, tree: *ast.Tree) ?[]const u8 {
            return if (self.fn_proto.extern_export_inline_token) |tok_index| x: {
                const token = tree.tokens.at(tok_index);
                break :x switch (token.id) {
                    Token.Id.Extern => tree.tokenSlicePtr(token),
                    else => null,
                };
            } else null;
        }

        pub fn isExported(self: Fn, tree: *ast.Tree) bool {
            if (self.fn_proto.extern_export_inline_token) |tok_index| {
                const token = tree.tokens.at(tok_index);
                return token.id == Token.Id.Keyword_export;
            } else {
                return false;
            }
        }
    };

    pub const CompTime = struct {
        base: Decl,
    };
};

