const std = @import("../index.zig");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const Token = std.zig.Token;
const mem = std.mem;

pub const Node = struct {
    id: Id,

    pub const Id = enum {
        Root,
        VarDecl,
        Identifier,
        FnProto,
        ParamDecl,
        Block,
        InfixOp,
        PrefixOp,
        IntegerLiteral,
        FloatLiteral,
        StringLiteral,
        BuiltinCall,
    };

    pub fn iterate(base: &Node, index: usize) ?&Node {
        return switch (base.id) {
            Id.Root => @fieldParentPtr(NodeRoot, "base", base).iterate(index),
            Id.VarDecl => @fieldParentPtr(NodeVarDecl, "base", base).iterate(index),
            Id.Identifier => @fieldParentPtr(NodeIdentifier, "base", base).iterate(index),
            Id.FnProto => @fieldParentPtr(NodeFnProto, "base", base).iterate(index),
            Id.ParamDecl => @fieldParentPtr(NodeParamDecl, "base", base).iterate(index),
            Id.Block => @fieldParentPtr(NodeBlock, "base", base).iterate(index),
            Id.InfixOp => @fieldParentPtr(NodeInfixOp, "base", base).iterate(index),
            Id.PrefixOp => @fieldParentPtr(NodePrefixOp, "base", base).iterate(index),
            Id.IntegerLiteral => @fieldParentPtr(NodeIntegerLiteral, "base", base).iterate(index),
            Id.FloatLiteral => @fieldParentPtr(NodeFloatLiteral, "base", base).iterate(index),
            Id.StringLiteral => @fieldParentPtr(NodeStringLiteral, "base", base).iterate(index),
            Id.BuiltinCall => @fieldParentPtr(NodeBuiltinCall, "base", base).iterate(index),
        };
    }
};

pub const NodeRoot = struct {
    base: Node,
    decls: ArrayList(&Node),

    pub fn iterate(self: &NodeRoot, index: usize) ?&Node {
        if (index < self.decls.len) {
            return self.decls.items[self.decls.len - index - 1];
        }
        return null;
    }
};

pub const NodeVarDecl = struct {
    base: Node,
    visib_token: ?Token,
    name_token: Token,
    eq_token: Token,
    mut_token: Token,
    comptime_token: ?Token,
    extern_token: ?Token,
    lib_name: ?&Node,
    type_node: ?&Node,
    align_node: ?&Node,
    init_node: ?&Node,

    pub fn iterate(self: &NodeVarDecl, index: usize) ?&Node {
        var i = index;

        if (self.type_node) |type_node| {
            if (i < 1) return type_node;
            i -= 1;
        }

        if (self.align_node) |align_node| {
            if (i < 1) return align_node;
            i -= 1;
        }

        if (self.init_node) |init_node| {
            if (i < 1) return init_node;
            i -= 1;
        }

        return null;
    }
};

pub const NodeIdentifier = struct {
    base: Node,
    name_token: Token,

    pub fn iterate(self: &NodeIdentifier, index: usize) ?&Node {
        return null;
    }
};

pub const NodeFnProto = struct {
    base: Node,
    visib_token: ?Token,
    fn_token: Token,
    name_token: ?Token,
    params: ArrayList(&Node),
    return_type: &Node,
    var_args_token: ?Token,
    extern_token: ?Token,
    inline_token: ?Token,
    cc_token: ?Token,
    body_node: ?&Node,
    lib_name: ?&Node, // populated if this is an extern declaration
    align_expr: ?&Node, // populated if align(A) is present

    pub fn iterate(self: &NodeFnProto, index: usize) ?&Node {
        var i = index;

        if (self.body_node) |body_node| {
            if (i < 1) return body_node;
            i -= 1;
        }

        if (i < 1) return self.return_type;
        i -= 1;

        if (self.align_expr) |align_expr| {
            if (i < 1) return align_expr;
            i -= 1;
        }

        if (i < self.params.len) return self.params.items[self.params.len - i - 1];
        i -= self.params.len;

        if (self.lib_name) |lib_name| {
            if (i < 1) return lib_name;
            i -= 1;
        }

        return null;
    }
};

pub const NodeParamDecl = struct {
    base: Node,
    comptime_token: ?Token,
    noalias_token: ?Token,
    name_token: ?Token,
    type_node: &Node,
    var_args_token: ?Token,

    pub fn iterate(self: &NodeParamDecl, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.type_node;
        i -= 1;

        return null;
    }
};

pub const NodeBlock = struct {
    base: Node,
    begin_token: Token,
    end_token: Token,
    statements: ArrayList(&Node),

    pub fn iterate(self: &NodeBlock, index: usize) ?&Node {
        var i = index;

        if (i < self.statements.len) return self.statements.items[i];
        i -= self.statements.len;

        return null;
    }
};

pub const NodeInfixOp = struct {
    base: Node,
    op_token: Token,
    lhs: &Node,
    op: InfixOp,
    rhs: &Node,

    const InfixOp = enum {
        EqualEqual,
        BangEqual,
    };

    pub fn iterate(self: &NodeInfixOp, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.lhs;
        i -= 1;

        switch (self.op) {
            InfixOp.EqualEqual => {},
            InfixOp.BangEqual => {},
        }

        if (i < 1) return self.rhs;
        i -= 1;

        return null;
    }
};

pub const NodePrefixOp = struct {
    base: Node,
    op_token: Token,
    op: PrefixOp,
    rhs: &Node,

    const PrefixOp = union(enum) {
        Return,
        AddrOf: AddrOfInfo,
    };
    const AddrOfInfo = struct {
        align_expr: ?&Node,
        bit_offset_start_token: ?Token,
        bit_offset_end_token: ?Token,
        const_token: ?Token,
        volatile_token: ?Token,
    };

    pub fn iterate(self: &NodePrefixOp, index: usize) ?&Node {
        var i = index;

        switch (self.op) {
            PrefixOp.Return => {},
            PrefixOp.AddrOf => |addr_of_info| {
                if (addr_of_info.align_expr) |align_expr| {
                    if (i < 1) return align_expr;
                    i -= 1;
                }
            },
        }

        if (i < 1) return self.rhs;
        i -= 1;

        return null;
    }
};

pub const NodeIntegerLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeIntegerLiteral, index: usize) ?&Node {
        return null;
    }
};

pub const NodeFloatLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeFloatLiteral, index: usize) ?&Node {
        return null;
    }
};

pub const NodeBuiltinCall = struct {
    base: Node,
    builtin_token: Token,
    params: ArrayList(&Node),

    pub fn iterate(self: &NodeBuiltinCall, index: usize) ?&Node {
        var i = index;

        if (i < self.params.len) return self.params.at(i);
        i -= self.params.len;

        return null;
    }
};

pub const NodeStringLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeStringLiteral, index: usize) ?&Node {
        return null;
    }
};
