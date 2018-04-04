const std = @import("../index.zig");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const Token = std.zig.Token;
const mem = std.mem;

pub const Node = struct {
    id: Id,
    comment: ?&NodeLineComment,

    pub const Id = enum {
        Root,
        VarDecl,
        ContainerDecl,
        StructField,
        UnionTag,
        EnumTag,
        Identifier,
        FnProto,
        ParamDecl,
        Block,
        InfixOp,
        PrefixOp,
        SuffixOp,
        GroupedExpression,
        FieldInitializer,
        IntegerLiteral,
        FloatLiteral,
        StringLiteral,
        MultilineStringLiteral,
        CharLiteral,
        BoolLiteral,
        NullLiteral,
        UndefinedLiteral,
        ThisLiteral,
        Unreachable,
        ErrorType,
        BuiltinCall,
        LineComment,
        TestDecl,
    };

    pub fn iterate(base: &Node, index: usize) ?&Node {
        return switch (base.id) {
            Id.Root => @fieldParentPtr(NodeRoot, "base", base).iterate(index),
            Id.VarDecl => @fieldParentPtr(NodeVarDecl, "base", base).iterate(index),
            Id.ContainerDecl => @fieldParentPtr(NodeContainerDecl, "base", base).iterate(index),
            Id.StructField => @fieldParentPtr(NodeStructField, "base", base).iterate(index),
            Id.UnionTag => @fieldParentPtr(NodeUnionTag, "base", base).iterate(index),
            Id.EnumTag => @fieldParentPtr(NodeEnumTag, "base", base).iterate(index),
            Id.Identifier => @fieldParentPtr(NodeIdentifier, "base", base).iterate(index),
            Id.FnProto => @fieldParentPtr(NodeFnProto, "base", base).iterate(index),
            Id.ParamDecl => @fieldParentPtr(NodeParamDecl, "base", base).iterate(index),
            Id.Block => @fieldParentPtr(NodeBlock, "base", base).iterate(index),
            Id.InfixOp => @fieldParentPtr(NodeInfixOp, "base", base).iterate(index),
            Id.PrefixOp => @fieldParentPtr(NodePrefixOp, "base", base).iterate(index),
            Id.SuffixOp => @fieldParentPtr(NodeSuffixOp, "base", base).iterate(index),
            Id.GroupedExpression => @fieldParentPtr(NodeGroupedExpression, "base", base).iterate(index),
            Id.FieldInitializer => @fieldParentPtr(NodeFieldInitializer, "base", base).iterate(index),
            Id.IntegerLiteral => @fieldParentPtr(NodeIntegerLiteral, "base", base).iterate(index),
            Id.FloatLiteral => @fieldParentPtr(NodeFloatLiteral, "base", base).iterate(index),
            Id.StringLiteral => @fieldParentPtr(NodeStringLiteral, "base", base).iterate(index),
            Id.MultilineStringLiteral => @fieldParentPtr(NodeMultilineStringLiteral, "base", base).iterate(index),
            Id.CharLiteral => @fieldParentPtr(NodeCharLiteral, "base", base).iterate(index),
            Id.BoolLiteral => @fieldParentPtr(NodeBoolLiteral, "base", base).iterate(index),
            Id.NullLiteral => @fieldParentPtr(NodeNullLiteral, "base", base).iterate(index),
            Id.UndefinedLiteral => @fieldParentPtr(NodeUndefinedLiteral, "base", base).iterate(index),
            Id.ThisLiteral => @fieldParentPtr(NodeThisLiteral, "base", base).iterate(index),
            Id.Unreachable => @fieldParentPtr(NodeUnreachable, "base", base).iterate(index),
            Id.ErrorType => @fieldParentPtr(NodeErrorType, "base", base).iterate(index),
            Id.BuiltinCall => @fieldParentPtr(NodeBuiltinCall, "base", base).iterate(index),
            Id.LineComment => @fieldParentPtr(NodeLineComment, "base", base).iterate(index),
            Id.TestDecl => @fieldParentPtr(NodeTestDecl, "base", base).iterate(index),
        };
    }

    pub fn firstToken(base: &Node) Token {
        return switch (base.id) {
            Id.Root => @fieldParentPtr(NodeRoot, "base", base).firstToken(),
            Id.VarDecl => @fieldParentPtr(NodeVarDecl, "base", base).firstToken(),
            Id.ContainerDecl => @fieldParentPtr(NodeContainerDecl, "base", base).firstToken(),
            Id.StructField => @fieldParentPtr(NodeStructField, "base", base).firstToken(),
            Id.UnionTag => @fieldParentPtr(NodeUnionTag, "base", base).firstToken(),
            Id.EnumTag => @fieldParentPtr(NodeEnumTag, "base", base).firstToken(),
            Id.Identifier => @fieldParentPtr(NodeIdentifier, "base", base).firstToken(),
            Id.FnProto => @fieldParentPtr(NodeFnProto, "base", base).firstToken(),
            Id.ParamDecl => @fieldParentPtr(NodeParamDecl, "base", base).firstToken(),
            Id.Block => @fieldParentPtr(NodeBlock, "base", base).firstToken(),
            Id.InfixOp => @fieldParentPtr(NodeInfixOp, "base", base).firstToken(),
            Id.PrefixOp => @fieldParentPtr(NodePrefixOp, "base", base).firstToken(),
            Id.SuffixOp => @fieldParentPtr(NodeSuffixOp, "base", base).firstToken(),
            Id.GroupedExpression => @fieldParentPtr(NodeGroupedExpression, "base", base).firstToken(),
            Id.FieldInitializer => @fieldParentPtr(NodeFieldInitializer, "base", base).firstToken(),
            Id.IntegerLiteral => @fieldParentPtr(NodeIntegerLiteral, "base", base).firstToken(),
            Id.FloatLiteral => @fieldParentPtr(NodeFloatLiteral, "base", base).firstToken(),
            Id.StringLiteral => @fieldParentPtr(NodeStringLiteral, "base", base).firstToken(),
            Id.MultilineStringLiteral => @fieldParentPtr(NodeMultilineStringLiteral, "base", base).firstToken(),
            Id.CharLiteral => @fieldParentPtr(NodeCharLiteral, "base", base).firstToken(),
            Id.BoolLiteral => @fieldParentPtr(NodeBoolLiteral, "base", base).firstToken(),
            Id.NullLiteral => @fieldParentPtr(NodeNullLiteral, "base", base).firstToken(),
            Id.UndefinedLiteral => @fieldParentPtr(NodeUndefinedLiteral, "base", base).firstToken(),
            Id.Unreachable => @fieldParentPtr(NodeUnreachable, "base", base).firstToken(),
            Id.ThisLiteral => @fieldParentPtr(NodeThisLiteral, "base", base).firstToken(),
            Id.ErrorType => @fieldParentPtr(NodeErrorType, "base", base).firstToken(),
            Id.BuiltinCall => @fieldParentPtr(NodeBuiltinCall, "base", base).firstToken(),
            Id.LineComment => @fieldParentPtr(NodeLineComment, "base", base).firstToken(),
            Id.TestDecl => @fieldParentPtr(NodeTestDecl, "base", base).firstToken(),
        };
    }

    pub fn lastToken(base: &Node) Token {
        return switch (base.id) {
            Id.Root => @fieldParentPtr(NodeRoot, "base", base).lastToken(),
            Id.VarDecl => @fieldParentPtr(NodeVarDecl, "base", base).lastToken(),
            Id.ContainerDecl => @fieldParentPtr(NodeContainerDecl, "base", base).lastToken(),
            Id.StructField => @fieldParentPtr(NodeStructField, "base", base).lastToken(),
            Id.UnionTag => @fieldParentPtr(NodeUnionTag, "base", base).lastToken(),
            Id.EnumTag => @fieldParentPtr(NodeEnumTag, "base", base).lastToken(),
            Id.Identifier => @fieldParentPtr(NodeIdentifier, "base", base).lastToken(),
            Id.FnProto => @fieldParentPtr(NodeFnProto, "base", base).lastToken(),
            Id.ParamDecl => @fieldParentPtr(NodeParamDecl, "base", base).lastToken(),
            Id.Block => @fieldParentPtr(NodeBlock, "base", base).lastToken(),
            Id.InfixOp => @fieldParentPtr(NodeInfixOp, "base", base).lastToken(),
            Id.PrefixOp => @fieldParentPtr(NodePrefixOp, "base", base).lastToken(),
            Id.SuffixOp => @fieldParentPtr(NodeSuffixOp, "base", base).lastToken(),
            Id.GroupedExpression => @fieldParentPtr(NodeGroupedExpression, "base", base).lastToken(),
            Id.FieldInitializer => @fieldParentPtr(NodeFieldInitializer, "base", base).lastToken(),
            Id.IntegerLiteral => @fieldParentPtr(NodeIntegerLiteral, "base", base).lastToken(),
            Id.FloatLiteral => @fieldParentPtr(NodeFloatLiteral, "base", base).lastToken(),
            Id.StringLiteral => @fieldParentPtr(NodeStringLiteral, "base", base).lastToken(),
            Id.MultilineStringLiteral => @fieldParentPtr(NodeMultilineStringLiteral, "base", base).lastToken(),
            Id.CharLiteral => @fieldParentPtr(NodeCharLiteral, "base", base).lastToken(),
            Id.BoolLiteral => @fieldParentPtr(NodeBoolLiteral, "base", base).lastToken(),
            Id.NullLiteral => @fieldParentPtr(NodeNullLiteral, "base", base).lastToken(),
            Id.UndefinedLiteral => @fieldParentPtr(NodeUndefinedLiteral, "base", base).lastToken(),
            Id.ThisLiteral => @fieldParentPtr(NodeThisLiteral, "base", base).lastToken(),
            Id.Unreachable => @fieldParentPtr(NodeUnreachable, "base", base).lastToken(),
            Id.ErrorType => @fieldParentPtr(NodeErrorType, "base", base).lastToken(),
            Id.BuiltinCall => @fieldParentPtr(NodeBuiltinCall, "base", base).lastToken(),
            Id.LineComment => @fieldParentPtr(NodeLineComment, "base", base).lastToken(),
            Id.TestDecl => @fieldParentPtr(NodeTestDecl, "base", base).lastToken(),
        };
    }
};

pub const NodeRoot = struct {
    base: Node,
    decls: ArrayList(&Node),
    eof_token: Token,

    pub fn iterate(self: &NodeRoot, index: usize) ?&Node {
        if (index < self.decls.len) {
            return self.decls.items[self.decls.len - index - 1];
        }
        return null;
    }

    pub fn firstToken(self: &NodeRoot) Token {
        return if (self.decls.len == 0) self.eof_token else self.decls.at(0).firstToken();
    }

    pub fn lastToken(self: &NodeRoot) Token {
        return if (self.decls.len == 0) self.eof_token else self.decls.at(self.decls.len - 1).lastToken();
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
    semicolon_token: Token,

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

    pub fn firstToken(self: &NodeVarDecl) Token {
        if (self.visib_token) |visib_token| return visib_token;
        if (self.comptime_token) |comptime_token| return comptime_token;
        if (self.extern_token) |extern_token| return extern_token;
        assert(self.lib_name == null);
        return self.mut_token;
    }

    pub fn lastToken(self: &NodeVarDecl) Token {
        return self.semicolon_token;
    }
};

pub const NodeContainerDecl = struct {
    base: Node,
    ltoken: Token,
    layout: Layout,
    kind: Kind,
    init_arg_expr: InitArg,
    fields_and_decls: ArrayList(&Node),
    rbrace_token: Token,

    const Layout = enum {
        Auto,
        Extern,
        Packed,
    };

    const Kind = enum {
        Struct,
        Enum,
        Union,
    };

    const InitArg = union(enum) {
        None,
        Enum,
        Type: &Node,
    };

    pub fn iterate(self: &NodeContainerDecl, index: usize) ?&Node {
        var i = index;

        switch (self.init_arg_expr) {
            InitArg.Type => |t| {
                if (i < 1) return t;
                i -= 1;
            },
            InitArg.None,
            InitArg.Enum => { }
        }

        if (i < self.decls.len) return self.decls.at(i);
        i -= self.decls.len;

        switch (self.kind) {
            Kind.Struct => |fields| {
                if (i < fields.len) return fields.at(i);
                i -= fields.len;
            },
            Kind.Enum => |tags| {
                if (i < tags.len) return tags.at(i);
                i -= tags.len;
            },
            Kind.Union => |tags| {
                if (i < tags.len) return tags.at(i);
                i -= tags.len;
            },
        }

        return null;
    }

    pub fn firstToken(self: &NodeContainerDecl) Token {
        return self.ltoken;
    }

    pub fn lastToken(self: &NodeContainerDecl) Token {
        return self.rbrace_token;
    }
};

pub const NodeStructField = struct {
    base: Node,
    name_token: Token,
    type_expr: &Node,

    pub fn iterate(self: &NodeStructField, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.type_expr;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeStructField) Token {
        return self.name_token;
    }

    pub fn lastToken(self: &NodeStructField) Token {
        return self.type_expr.lastToken();
    }
};

pub const NodeUnionTag = struct {
    base: Node,
    name_token: Token,
    type_expr: ?&Node,

    pub fn iterate(self: &NodeUnionTag, index: usize) ?&Node {
        var i = index;

        if (self.type_expr) |type_expr| {
            if (i < 1) return type_expr;
            i -= 1;
        }

        return null;
    }

    pub fn firstToken(self: &NodeUnionTag) Token {
        return self.name_token;
    }

    pub fn lastToken(self: &NodeUnionTag) Token {
        if (self.type_expr) |type_expr| {
            return type_expr.lastToken();
        }

        return self.name_token;
    }
};

pub const NodeEnumTag = struct {
    base: Node,
    name_token: Token,
    value: ?&Node,

    pub fn iterate(self: &NodeEnumTag, index: usize) ?&Node {
        var i = index;

        if (self.value) |value| {
            if (i < 1) return value;
            i -= 1;
        }

        return null;
    }

    pub fn firstToken(self: &NodeEnumTag) Token {
        return self.name_token;
    }

    pub fn lastToken(self: &NodeEnumTag) Token {
        if (self.value) |value| {
            return value.lastToken();
        }

        return self.name_token;
    }
};

pub const NodeIdentifier = struct {
    base: Node,
    name_token: Token,

    pub fn iterate(self: &NodeIdentifier, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeIdentifier) Token {
        return self.name_token;
    }

    pub fn lastToken(self: &NodeIdentifier) Token {
        return self.name_token;
    }
};

pub const NodeFnProto = struct {
    base: Node,
    visib_token: ?Token,
    fn_token: Token,
    name_token: ?Token,
    params: ArrayList(&Node),
    return_type: ReturnType,
    var_args_token: ?Token,
    extern_token: ?Token,
    inline_token: ?Token,
    cc_token: ?Token,
    body_node: ?&Node,
    lib_name: ?&Node, // populated if this is an extern declaration
    align_expr: ?&Node, // populated if align(A) is present

    pub const ReturnType = union(enum) {
        Explicit: &Node,
        Infer: Token,
        InferErrorSet: &Node,
    };

    pub fn iterate(self: &NodeFnProto, index: usize) ?&Node {
        var i = index;

        if (self.body_node) |body_node| {
            if (i < 1) return body_node;
            i -= 1;
        }

        switch (self.return_type) {
            // TODO allow this and next prong to share bodies since the types are the same
            ReturnType.Explicit => |node| {
                if (i < 1) return node;
                i -= 1;
            },
            ReturnType.InferErrorSet => |node| {
                if (i < 1) return node;
                i -= 1;
            },
            ReturnType.Infer => {},
        }

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

    pub fn firstToken(self: &NodeFnProto) Token {
        if (self.visib_token) |visib_token| return visib_token;
        if (self.extern_token) |extern_token| return extern_token;
        assert(self.lib_name == null);
        if (self.inline_token) |inline_token| return inline_token;
        if (self.cc_token) |cc_token| return cc_token;
        return self.fn_token;
    }

    pub fn lastToken(self: &NodeFnProto) Token {
        if (self.body_node) |body_node| return body_node.lastToken();
        switch (self.return_type) {
            // TODO allow this and next prong to share bodies since the types are the same
            ReturnType.Explicit => |node| return node.lastToken(),
            ReturnType.InferErrorSet => |node| return node.lastToken(),
            ReturnType.Infer => |token| return token,
        }
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

    pub fn firstToken(self: &NodeParamDecl) Token {
        if (self.comptime_token) |comptime_token| return comptime_token;
        if (self.noalias_token) |noalias_token| return noalias_token;
        if (self.name_token) |name_token| return name_token;
        return self.type_node.firstToken();
    }

    pub fn lastToken(self: &NodeParamDecl) Token {
        if (self.var_args_token) |var_args_token| return var_args_token;
        return self.type_node.lastToken();
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

    pub fn firstToken(self: &NodeBlock) Token {
        return self.begin_token;
    }

    pub fn lastToken(self: &NodeBlock) Token {
        return self.end_token;
    }
};

pub const NodeInfixOp = struct {
    base: Node,
    op_token: Token,
    lhs: &Node,
    op: InfixOp,
    rhs: &Node,

    const InfixOp = enum {
        Add,
        AddWrap,
        ArrayCat,
        ArrayMult,
        Assign,
        AssignBitAnd,
        AssignBitOr,
        AssignBitShiftLeft,
        AssignBitShiftRight,
        AssignBitXor,
        AssignDiv,
        AssignMinus,
        AssignMinusWrap,
        AssignMod,
        AssignPlus,
        AssignPlusWrap,
        AssignTimes,
        AssignTimesWarp,
        BangEqual,
        BitAnd,
        BitOr,
        BitShiftLeft,
        BitShiftRight,
        BitXor,
        BoolAnd,
        BoolOr,
        Div,
        EqualEqual,
        ErrorUnion,
        GreaterOrEqual,
        GreaterThan,
        LessOrEqual,
        LessThan,
        MergeErrorSets,
        Mod,
        Mult,
        MultWrap,
        Period,
        Sub,
        SubWrap,
        UnwrapMaybe,
    };

    pub fn iterate(self: &NodeInfixOp, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.lhs;
        i -= 1;

        switch (self.op) {
            InfixOp.Add,
            InfixOp.AddWrap,
            InfixOp.ArrayCat,
            InfixOp.ArrayMult,
            InfixOp.Assign,
            InfixOp.AssignBitAnd,
            InfixOp.AssignBitOr,
            InfixOp.AssignBitShiftLeft,
            InfixOp.AssignBitShiftRight,
            InfixOp.AssignBitXor,
            InfixOp.AssignDiv,
            InfixOp.AssignMinus,
            InfixOp.AssignMinusWrap,
            InfixOp.AssignMod,
            InfixOp.AssignPlus,
            InfixOp.AssignPlusWrap,
            InfixOp.AssignTimes,
            InfixOp.AssignTimesWarp,
            InfixOp.BangEqual,
            InfixOp.BitAnd,
            InfixOp.BitOr,
            InfixOp.BitShiftLeft,
            InfixOp.BitShiftRight,
            InfixOp.BitXor,
            InfixOp.BoolAnd,
            InfixOp.BoolOr,
            InfixOp.Div,
            InfixOp.EqualEqual,
            InfixOp.ErrorUnion,
            InfixOp.GreaterOrEqual,
            InfixOp.GreaterThan,
            InfixOp.LessOrEqual,
            InfixOp.LessThan,
            InfixOp.MergeErrorSets,
            InfixOp.Mod,
            InfixOp.Mult,
            InfixOp.MultWrap,
            InfixOp.Period,
            InfixOp.Sub,
            InfixOp.SubWrap,
            InfixOp.UnwrapMaybe => {},
        }

        if (i < 1) return self.rhs;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeInfixOp) Token {
        return self.lhs.firstToken();
    }

    pub fn lastToken(self: &NodeInfixOp) Token {
        return self.rhs.lastToken();
    }
};

pub const NodePrefixOp = struct {
    base: Node,
    op_token: Token,
    op: PrefixOp,
    rhs: &Node,

    const PrefixOp = union(enum) {
        AddrOf: AddrOfInfo,
        BitNot,
        BoolNot,
        Deref,
        Negation,
        NegationWrap,
        Return,
        ArrayType: &Node,
        SliceType: AddrOfInfo,
        Try,
        UnwrapMaybe,
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
            PrefixOp.SliceType => |addr_of_info| {
                if (addr_of_info.align_expr) |align_expr| {
                    if (i < 1) return align_expr;
                    i -= 1;
                }
            },
            PrefixOp.AddrOf => |addr_of_info| {
                if (addr_of_info.align_expr) |align_expr| {
                    if (i < 1) return align_expr;
                    i -= 1;
                }
            },
            PrefixOp.ArrayType => |size_expr| {
                if (i < 1) return size_expr;
                i -= 1;
            },
            PrefixOp.BitNot,
            PrefixOp.BoolNot,
            PrefixOp.Deref,
            PrefixOp.Negation,
            PrefixOp.NegationWrap,
            PrefixOp.Return,
            PrefixOp.Try,
            PrefixOp.UnwrapMaybe => {},
        }

        if (i < 1) return self.rhs;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodePrefixOp) Token {
        return self.op_token;
    }

    pub fn lastToken(self: &NodePrefixOp) Token {
        return self.rhs.lastToken();
    }
};

pub const NodeFieldInitializer = struct {
    base: Node,
    period_token: Token,
    name_token: Token,
    expr: &Node,

    pub fn iterate(self: &NodeFieldInitializer, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.expr;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeFieldInitializer) Token {
        return self.period_token;
    }

    pub fn lastToken(self: &NodeFieldInitializer) Token {
        return self.expr.lastToken();
    }
};

pub const NodeSuffixOp = struct {
    base: Node,
    lhs: &Node,
    op: SuffixOp,
    rtoken: Token,

    const SuffixOp = union(enum) {
        Call: CallInfo,
        ArrayAccess: &Node,
        Slice: SliceRange,
        ArrayInitializer: ArrayList(&Node),
        StructInitializer: ArrayList(&NodeFieldInitializer),
    };

    const CallInfo = struct {
        params: ArrayList(&Node),
        is_async: bool,
    };

    const SliceRange = struct {
        start: &Node,
        end: ?&Node,
    };

    pub fn iterate(self: &NodeSuffixOp, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.lhs;
        i -= 1;

        switch (self.op) {
            SuffixOp.Call => |call_info| {
                if (i < call_info.params.len) return call_info.params.at(i);
                i -= call_info.params.len;
            },
            SuffixOp.ArrayAccess => |index_expr| {
                if (i < 1) return index_expr;
                i -= 1;
            },
            SuffixOp.Slice => |range| {
                if (i < 1) return range.start;
                i -= 1;

                if (range.end) |end| {
                    if (i < 1) return end;
                    i -= 1;
                }
            },
            SuffixOp.ArrayInitializer => |exprs| {
                if (i < exprs.len) return exprs.at(i);
                i -= exprs.len;
            },
            SuffixOp.StructInitializer => |fields| {
                if (i < fields.len) return &fields.at(i).base;
                i -= fields.len;
            },
        }

        return null;
    }

    pub fn firstToken(self: &NodeSuffixOp) Token {
        return self.lhs.firstToken();
    }

    pub fn lastToken(self: &NodeSuffixOp) Token {
        return self.rtoken;
    }
};

pub const NodeGroupedExpression = struct {
    base: Node,
    lparen: Token,
    expr: &Node,
    rparen: Token,

    pub fn iterate(self: &NodeGroupedExpression, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.expr;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeGroupedExpression) Token {
        return self.lparen;
    }

    pub fn lastToken(self: &NodeGroupedExpression) Token {
        return self.rparen;
    }
};

pub const NodeIntegerLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeIntegerLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeIntegerLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeIntegerLiteral) Token {
        return self.token;
    }
};

pub const NodeFloatLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeFloatLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeFloatLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeFloatLiteral) Token {
        return self.token;
    }
};

pub const NodeBuiltinCall = struct {
    base: Node,
    builtin_token: Token,
    params: ArrayList(&Node),
    rparen_token: Token,

    pub fn iterate(self: &NodeBuiltinCall, index: usize) ?&Node {
        var i = index;

        if (i < self.params.len) return self.params.at(i);
        i -= self.params.len;

        return null;
    }

    pub fn firstToken(self: &NodeBuiltinCall) Token {
        return self.builtin_token;
    }

    pub fn lastToken(self: &NodeBuiltinCall) Token {
        return self.rparen_token;
    }
};

pub const NodeStringLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeStringLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeStringLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeStringLiteral) Token {
        return self.token;
    }
};

pub const NodeMultilineStringLiteral = struct {
    base: Node,
    tokens: ArrayList(Token),

    pub fn iterate(self: &NodeMultilineStringLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeMultilineStringLiteral) Token {
        return self.tokens.at(0);
    }

    pub fn lastToken(self: &NodeMultilineStringLiteral) Token {
        return self.tokens.at(self.tokens.len - 1);
    }
};

pub const NodeCharLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeCharLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeCharLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeCharLiteral) Token {
        return self.token;
    }
};

pub const NodeBoolLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeBoolLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeBoolLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeBoolLiteral) Token {
        return self.token;
    }
};

pub const NodeNullLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeNullLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeNullLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeNullLiteral) Token {
        return self.token;
    }
};

pub const NodeUndefinedLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeUndefinedLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeUndefinedLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeUndefinedLiteral) Token {
        return self.token;
    }
};

pub const NodeThisLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeThisLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeThisLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeThisLiteral) Token {
        return self.token;
    }
};

pub const NodeUnreachable = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeUnreachable, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeUnreachable) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeUnreachable) Token {
        return self.token;
    }
};

pub const NodeErrorType = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeErrorType, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeErrorType) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeErrorType) Token {
        return self.token;
    }
};

pub const NodeLineComment = struct {
    base: Node,
    lines: ArrayList(Token),

    pub fn iterate(self: &NodeLineComment, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeLineComment) Token {
        return self.lines.at(0);
    }

    pub fn lastToken(self: &NodeLineComment) Token {
        return self.lines.at(self.lines.len - 1);
    }
};

pub const NodeTestDecl = struct {
    base: Node,
    test_token: Token,
    name: &Node,
    body_node: &Node,

    pub fn iterate(self: &NodeTestDecl, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.body_node;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeTestDecl) Token {
        return self.test_token;
    }

    pub fn lastToken(self: &NodeTestDecl) Token {
        return self.body_node.lastToken();
    }
};
