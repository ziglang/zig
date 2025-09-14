const std = @import("std");

const Interner = @import("../backend.zig").Interner;

const Attribute = @import("Attribute.zig");
const CodeGen = @import("CodeGen.zig");
const Compilation = @import("Compilation.zig");
const number_affixes = @import("Tree/number_affixes.zig");
const Source = @import("Source.zig");
const Tokenizer = @import("Tokenizer.zig");
const QualType = @import("TypeStore.zig").QualType;
const Value = @import("Value.zig");

pub const Token = struct {
    id: Id,
    loc: Source.Location,

    pub const List = std.MultiArrayList(Token);
    pub const Id = Tokenizer.Token.Id;
    pub const NumberPrefix = number_affixes.Prefix;
    pub const NumberSuffix = number_affixes.Suffix;
};

pub const TokenWithExpansionLocs = struct {
    id: Token.Id,
    flags: packed struct {
        expansion_disabled: bool = false,
        is_macro_arg: bool = false,
    } = .{},
    /// This location contains the actual token slice which might be generated.
    /// If it is generated then there is guaranteed to be at least one
    /// expansion location.
    loc: Source.Location,
    expansion_locs: ?[*]Source.Location = null,

    pub fn expansionSlice(tok: TokenWithExpansionLocs) []const Source.Location {
        const locs = tok.expansion_locs orelse return &[0]Source.Location{};
        var i: usize = 0;
        while (locs[i].id != .unused) : (i += 1) {}
        return locs[0..i];
    }

    pub fn addExpansionLocation(tok: *TokenWithExpansionLocs, gpa: std.mem.Allocator, new: []const Source.Location) !void {
        if (new.len == 0 or tok.id == .whitespace or tok.id == .macro_ws or tok.id == .placemarker) return;
        var list: std.ArrayList(Source.Location) = .empty;
        defer {
            @memset(list.items.ptr[list.items.len..list.capacity], .{});
            // Add a sentinel to indicate the end of the list since
            // the ArrayList's capacity isn't guaranteed to be exactly
            // what we ask for.
            if (list.capacity > 0) {
                list.items.ptr[list.capacity - 1].byte_offset = 1;
            }
            tok.expansion_locs = list.items.ptr;
        }

        if (tok.expansion_locs) |locs| {
            var i: usize = 0;
            while (locs[i].id != .unused) : (i += 1) {}
            list.items = locs[0..i];
            while (locs[i].byte_offset != 1) : (i += 1) {}
            list.capacity = i + 1;
        }

        const min_len = @max(list.items.len + new.len + 1, 4);
        const wanted_len = std.math.ceilPowerOfTwo(usize, min_len) catch
            return error.OutOfMemory;
        try list.ensureTotalCapacity(gpa, wanted_len);

        for (new) |new_loc| {
            if (new_loc.id == .generated) continue;
            list.appendAssumeCapacity(new_loc);
        }
    }

    pub fn free(expansion_locs: ?[*]Source.Location, gpa: std.mem.Allocator) void {
        const locs = expansion_locs orelse return;
        var i: usize = 0;
        while (locs[i].id != .unused) : (i += 1) {}
        while (locs[i].byte_offset != 1) : (i += 1) {}
        gpa.free(locs[0 .. i + 1]);
    }

    pub fn dupe(tok: TokenWithExpansionLocs, gpa: std.mem.Allocator) !TokenWithExpansionLocs {
        var copy = tok;
        copy.expansion_locs = null;
        try copy.addExpansionLocation(gpa, tok.expansionSlice());
        return copy;
    }

    pub fn checkMsEof(tok: TokenWithExpansionLocs, source: Source, comp: *Compilation) !void {
        std.debug.assert(tok.id == .eof);
        if (source.buf.len > tok.loc.byte_offset and source.buf[tok.loc.byte_offset] == 0x1A) {
            const diagnostic: Compilation.Diagnostic = .ctrl_z_eof;
            try comp.diagnostics.add(.{
                .text = diagnostic.fmt,
                .kind = diagnostic.kind,
                .opt = diagnostic.opt,
                .extension = diagnostic.extension,
                .location = source.lineCol(.{
                    .id = source.id,
                    .byte_offset = tok.loc.byte_offset,
                    .line = tok.loc.line,
                }),
            });
        }
    }
};

pub const TokenIndex = u32;
pub const ValueMap = std.AutoHashMapUnmanaged(Node.Index, Value);

const Tree = @This();

comp: *Compilation,

// Values from Preprocessor.
tokens: Token.List.Slice,

// Values owned by this Tree
nodes: std.MultiArrayList(Node.Repr) = .empty,
extra: std.ArrayList(u32) = .empty,
root_decls: std.ArrayList(Node.Index) = .empty,
value_map: ValueMap = .empty,

pub const genIr = CodeGen.genIr;

pub fn deinit(tree: *Tree) void {
    tree.nodes.deinit(tree.comp.gpa);
    tree.extra.deinit(tree.comp.gpa);
    tree.root_decls.deinit(tree.comp.gpa);
    tree.value_map.deinit(tree.comp.gpa);
    tree.* = undefined;
}

pub const GNUAssemblyQualifiers = struct {
    @"volatile": bool = false,
    @"inline": bool = false,
    goto: bool = false,
};

pub const Node = union(enum) {
    empty_decl: EmptyDecl,
    static_assert: StaticAssert,
    function: Function,
    param: Param,
    variable: Variable,
    typedef: Typedef,
    global_asm: SimpleAsm,

    struct_decl: ContainerDecl,
    union_decl: ContainerDecl,
    enum_decl: ContainerDecl,
    struct_forward_decl: ContainerForwardDecl,
    union_forward_decl: ContainerForwardDecl,
    enum_forward_decl: ContainerForwardDecl,

    enum_field: EnumField,
    record_field: RecordField,

    labeled_stmt: LabeledStmt,
    compound_stmt: CompoundStmt,
    if_stmt: IfStmt,
    switch_stmt: SwitchStmt,
    case_stmt: CaseStmt,
    default_stmt: DefaultStmt,
    while_stmt: WhileStmt,
    do_while_stmt: DoWhileStmt,
    for_stmt: ForStmt,
    goto_stmt: GotoStmt,
    computed_goto_stmt: ComputedGotoStmt,
    continue_stmt: ContinueStmt,
    break_stmt: BreakStmt,
    null_stmt: NullStmt,
    return_stmt: ReturnStmt,
    gnu_asm_simple: SimpleAsm,

    assign_expr: Binary,
    mul_assign_expr: Binary,
    div_assign_expr: Binary,
    mod_assign_expr: Binary,
    add_assign_expr: Binary,
    sub_assign_expr: Binary,
    shl_assign_expr: Binary,
    shr_assign_expr: Binary,
    bit_and_assign_expr: Binary,
    bit_xor_assign_expr: Binary,
    bit_or_assign_expr: Binary,
    compound_assign_dummy_expr: Unary,

    comma_expr: Binary,
    bool_or_expr: Binary,
    bool_and_expr: Binary,
    bit_or_expr: Binary,
    bit_xor_expr: Binary,
    bit_and_expr: Binary,
    equal_expr: Binary,
    not_equal_expr: Binary,
    less_than_expr: Binary,
    less_than_equal_expr: Binary,
    greater_than_expr: Binary,
    greater_than_equal_expr: Binary,
    shl_expr: Binary,
    shr_expr: Binary,
    add_expr: Binary,
    sub_expr: Binary,
    mul_expr: Binary,
    div_expr: Binary,
    mod_expr: Binary,

    cast: Cast,

    addr_of_expr: Unary,
    deref_expr: Unary,
    plus_expr: Unary,
    negate_expr: Unary,
    bit_not_expr: Unary,
    bool_not_expr: Unary,
    pre_inc_expr: Unary,
    pre_dec_expr: Unary,
    imag_expr: Unary,
    real_expr: Unary,
    post_inc_expr: Unary,
    post_dec_expr: Unary,
    paren_expr: Unary,
    stmt_expr: Unary,

    addr_of_label: AddrOfLabel,

    array_access_expr: ArrayAccess,
    member_access_expr: MemberAccess,
    member_access_ptr_expr: MemberAccess,

    call_expr: Call,

    decl_ref_expr: DeclRef,
    enumeration_ref: DeclRef,

    builtin_call_expr: BuiltinCall,
    builtin_ref: BuiltinRef,
    builtin_types_compatible_p: TypesCompatible,
    builtin_choose_expr: Conditional,
    builtin_convertvector: Convertvector,
    builtin_shufflevector: Shufflevector,

    /// C23 bool literal `true` / `false`
    bool_literal: Literal,
    /// C23 nullptr literal
    nullptr_literal: Literal,
    /// integer literal, always unsigned
    int_literal: Literal,
    /// Same as int_literal, but originates from a char literal
    char_literal: CharLiteral,
    /// a floating point literal
    float_literal: Literal,
    string_literal_expr: CharLiteral,
    /// wraps a float or double literal
    imaginary_literal: Unary,
    /// A compound literal (type){ init }
    compound_literal_expr: CompoundLiteral,

    sizeof_expr: TypeInfo,
    alignof_expr: TypeInfo,

    generic_expr: Generic,
    generic_association_expr: Generic.Association,
    generic_default_expr: Generic.Default,

    binary_cond_expr: Conditional,
    /// Used as the base for casts of the lhs in `binary_cond_expr`.
    cond_dummy_expr: Unary,
    cond_expr: Conditional,

    array_init_expr: ContainerInit,
    struct_init_expr: ContainerInit,
    union_init_expr: UnionInit,
    /// Inserted in array_init_expr to represent unspecified elements.
    /// data.int contains the amount of elements.
    array_filler_expr: ArrayFiller,
    /// Inserted in record and scalar initializers for unspecified elements.
    default_init_expr: DefaultInit,

    pub const EmptyDecl = struct {
        semicolon: TokenIndex,
    };

    pub const StaticAssert = struct {
        assert_tok: TokenIndex,
        cond: Node.Index,
        message: ?Node.Index,
    };

    pub const Function = struct {
        name_tok: TokenIndex,
        qt: QualType,
        static: bool,
        @"inline": bool,
        body: ?Node.Index,
        /// Actual, non-tentative definition of this function.
        definition: ?Node.Index,
    };

    pub const Param = struct {
        name_tok: TokenIndex,
        qt: QualType,
        storage_class: enum {
            auto,
            register,
        },
    };

    pub const Variable = struct {
        name_tok: TokenIndex,
        qt: QualType,
        storage_class: enum {
            auto,
            static,
            @"extern",
            register,
        },
        thread_local: bool,
        /// From predefined macro  __func__, __FUNCTION__ or __PRETTY_FUNCTION__.
        /// Implies `static == true`.
        implicit: bool,
        initializer: ?Node.Index,
        /// Actual, non-tentative definition of this variable.
        definition: ?Node.Index,
    };

    pub const Typedef = struct {
        name_tok: TokenIndex,
        qt: QualType,
        implicit: bool,
    };

    pub const SimpleAsm = struct {
        asm_tok: TokenIndex,
        asm_str: Node.Index,
    };

    pub const ContainerDecl = struct {
        name_or_kind_tok: TokenIndex,
        container_qt: QualType,
        fields: []const Node.Index,
    };

    pub const ContainerForwardDecl = struct {
        name_or_kind_tok: TokenIndex,
        container_qt: QualType,
        /// The definition for this forward declaration if one exists.
        definition: ?Node.Index,
    };

    pub const EnumField = struct {
        name_tok: TokenIndex,
        qt: QualType,
        init: ?Node.Index,
    };

    pub const RecordField = struct {
        name_or_first_tok: TokenIndex,
        qt: QualType,
        bit_width: ?Node.Index,
    };

    pub const LabeledStmt = struct {
        label_tok: TokenIndex,
        body: Node.Index,
        qt: QualType,
    };

    pub const CompoundStmt = struct {
        l_brace_tok: TokenIndex,
        body: []const Node.Index,
    };

    pub const IfStmt = struct {
        if_tok: TokenIndex,
        cond: Node.Index,
        then_body: Node.Index,
        else_body: ?Node.Index,
    };

    pub const SwitchStmt = struct {
        switch_tok: TokenIndex,
        cond: Node.Index,
        body: Node.Index,
    };

    pub const CaseStmt = struct {
        case_tok: TokenIndex,
        start: Node.Index,
        end: ?Node.Index,
        body: Node.Index,
    };

    pub const DefaultStmt = struct {
        default_tok: TokenIndex,
        body: Node.Index,
    };

    pub const WhileStmt = struct {
        while_tok: TokenIndex,
        cond: Node.Index,
        body: Node.Index,
    };

    pub const DoWhileStmt = struct {
        do_tok: TokenIndex,
        cond: Node.Index,
        body: Node.Index,
    };

    pub const ForStmt = struct {
        for_tok: TokenIndex,
        init: union(enum) {
            decls: []const Node.Index,
            expr: ?Node.Index,
        },
        cond: ?Node.Index,
        incr: ?Node.Index,
        body: Node.Index,
    };

    pub const GotoStmt = struct {
        label_tok: TokenIndex,
    };

    pub const ComputedGotoStmt = struct {
        goto_tok: TokenIndex,
        expr: Node.Index,
    };

    pub const ContinueStmt = struct {
        continue_tok: TokenIndex,
    };

    pub const BreakStmt = struct {
        break_tok: TokenIndex,
    };

    pub const NullStmt = struct {
        semicolon_or_r_brace_tok: TokenIndex,
        qt: QualType,
    };

    pub const ReturnStmt = struct {
        return_tok: TokenIndex,
        return_qt: QualType,
        operand: union(enum) {
            expr: Node.Index,
            /// True if the function is called "main" and return_qt is compatible with int
            implicit: bool,
            none,
        },
    };

    pub const Binary = struct {
        qt: QualType,
        lhs: Node.Index,
        op_tok: TokenIndex,
        rhs: Node.Index,
    };

    pub const Cast = struct {
        qt: QualType,
        l_paren: TokenIndex,
        kind: Kind,
        operand: Node.Index,
        implicit: bool,

        pub const Kind = enum {
            /// Does nothing except possibly add qualifiers
            no_op,
            /// Interpret one bit pattern as another. Used for operands which have the same
            /// size and unrelated types, e.g. casting one pointer type to another
            bitcast,
            /// Convert T[] to T *
            array_to_pointer,
            /// Converts an lvalue to an rvalue
            lval_to_rval,
            /// Convert a function type to a pointer to a function
            function_to_pointer,
            /// Convert a pointer type to a _Bool
            pointer_to_bool,
            /// Convert a pointer type to an integer type
            pointer_to_int,
            /// Convert _Bool to an integer type
            bool_to_int,
            /// Convert _Bool to a floating type
            bool_to_float,
            /// Convert a _Bool to a pointer; will cause a  warning
            bool_to_pointer,
            /// Convert an integer type to _Bool
            int_to_bool,
            /// Convert an integer to a floating type
            int_to_float,
            /// Convert a complex integer to a complex floating type
            complex_int_to_complex_float,
            /// Convert an integer type to a pointer type
            int_to_pointer,
            /// Convert a floating type to a _Bool
            float_to_bool,
            /// Convert a floating type to an integer
            float_to_int,
            /// Convert a complex floating type to a complex integer
            complex_float_to_complex_int,
            /// Convert one integer type to another
            int_cast,
            /// Convert one complex integer type to another
            complex_int_cast,
            /// Convert real part of complex integer to a integer
            complex_int_to_real,
            /// Create a complex integer type using operand as the real part
            real_to_complex_int,
            /// Convert one floating type to another
            float_cast,
            /// Convert one complex floating type to another
            complex_float_cast,
            /// Convert real part of complex float to a float
            complex_float_to_real,
            /// Create a complex floating type using operand as the real part
            real_to_complex_float,
            /// Convert type to void
            to_void,
            /// Convert a literal 0 to a null pointer
            null_to_pointer,
            /// GNU cast-to-union extension
            union_cast,
            /// Create vector where each value is same as the input scalar.
            vector_splat,
            /// Convert an atomic type to its non atomic base type.
            atomic_to_non_atomic,
            /// Convert a non atomic type to an atomic type.
            non_atomic_to_atomic,
        };
    };

    pub const Unary = struct {
        qt: QualType,
        op_tok: TokenIndex,
        operand: Node.Index,
    };

    pub const AddrOfLabel = struct {
        label_tok: TokenIndex,
        qt: QualType,
    };

    pub const ArrayAccess = struct {
        l_bracket_tok: TokenIndex,
        qt: QualType,
        base: Node.Index,
        index: Node.Index,
    };

    pub const MemberAccess = struct {
        qt: QualType,
        base: Node.Index,
        access_tok: TokenIndex,
        member_index: u32,

        pub fn isBitFieldWidth(access: MemberAccess, tree: *const Tree) ?u32 {
            var qt = access.base.qt(tree);
            if (qt.isInvalid()) return null;
            if (qt.get(tree.comp, .pointer)) |pointer| qt = pointer.child;
            const record_ty = switch (qt.base(tree.comp).type) {
                .@"struct", .@"union" => |record| record,
                else => return null,
            };
            return record_ty.fields[access.member_index].bit_width.unpack();
        }
    };

    pub const Call = struct {
        l_paren_tok: TokenIndex,
        qt: QualType,
        callee: Node.Index,
        args: []const Node.Index,
    };

    pub const DeclRef = struct {
        name_tok: TokenIndex,
        qt: QualType,
        decl: Node.Index,
    };

    pub const BuiltinCall = struct {
        builtin_tok: TokenIndex,
        qt: QualType,
        args: []const Node.Index,
    };

    pub const BuiltinRef = struct {
        name_tok: TokenIndex,
        qt: QualType,
    };

    pub const TypesCompatible = struct {
        builtin_tok: TokenIndex,
        lhs: QualType,
        rhs: QualType,
    };

    pub const Convertvector = struct {
        builtin_tok: TokenIndex,
        dest_qt: QualType,
        operand: Node.Index,
    };

    pub const Shufflevector = struct {
        builtin_tok: TokenIndex,
        qt: QualType,
        lhs: Node.Index,
        rhs: Node.Index,
        indexes: []const Node.Index,
    };

    pub const Literal = struct {
        literal_tok: TokenIndex,
        qt: QualType,
    };

    pub const CharLiteral = struct {
        literal_tok: TokenIndex,
        qt: QualType,
        kind: enum {
            ascii,
            wide,
            utf8,
            utf16,
            utf32,
        },
    };

    pub const CompoundLiteral = struct {
        l_paren_tok: TokenIndex,
        qt: QualType,
        thread_local: bool,
        storage_class: enum {
            auto,
            static,
            register,
        },
        initializer: Node.Index,
    };

    pub const TypeInfo = struct {
        qt: QualType,
        op_tok: TokenIndex,
        expr: ?Node.Index,
        operand_qt: QualType,
    };

    pub const Generic = struct {
        generic_tok: TokenIndex,
        qt: QualType,

        // `Generic` child nodes are either an `Association` a `Default`
        controlling: Node.Index,
        chosen: Node.Index,
        rest: []const Node.Index,

        pub const Association = struct {
            colon_tok: TokenIndex,
            association_qt: QualType,
            expr: Node.Index,
        };

        pub const Default = struct {
            default_tok: TokenIndex,
            expr: Node.Index,
        };
    };

    pub const Conditional = struct {
        cond_tok: TokenIndex,
        qt: QualType,
        cond: Node.Index,
        then_expr: Node.Index,
        else_expr: Node.Index,
    };

    pub const ContainerInit = struct {
        l_brace_tok: TokenIndex,
        container_qt: QualType,
        items: []const Node.Index,
    };

    pub const UnionInit = struct {
        l_brace_tok: TokenIndex,
        union_qt: QualType,
        field_index: u32,
        initializer: ?Node.Index,
    };

    pub const ArrayFiller = struct {
        last_tok: TokenIndex,
        qt: QualType,
        count: u64,
    };

    pub const DefaultInit = struct {
        last_tok: TokenIndex,
        qt: QualType,
    };

    pub const Index = enum(u32) {
        _,

        pub fn get(index: Index, tree: *const Tree) Node {
            const node_tok = tree.nodes.items(.tok)[@intFromEnum(index)];
            const node_data = &tree.nodes.items(.data)[@intFromEnum(index)];
            return switch (tree.nodes.items(.tag)[@intFromEnum(index)]) {
                .empty_decl => .{
                    .empty_decl = .{
                        .semicolon = node_tok,
                    },
                },
                .static_assert => .{
                    .static_assert = .{
                        .assert_tok = node_tok,
                        .cond = @enumFromInt(node_data[0]),
                        .message = unpackOptIndex(node_data[1]),
                    },
                },
                .fn_proto => {
                    const attr: Node.Repr.DeclAttr = @bitCast(node_data[1]);
                    return .{
                        .function = .{
                            .name_tok = node_tok,
                            .qt = @bitCast(node_data[0]),
                            .static = attr.static,
                            .@"inline" = attr.@"inline",
                            .body = null,
                            .definition = unpackOptIndex(node_data[2]),
                        },
                    };
                },
                .fn_def => {
                    const attr: Node.Repr.DeclAttr = @bitCast(node_data[1]);
                    return .{
                        .function = .{
                            .name_tok = node_tok,
                            .qt = @bitCast(node_data[0]),
                            .static = attr.static,
                            .@"inline" = attr.@"inline",
                            .body = @enumFromInt(node_data[2]),
                            .definition = null,
                        },
                    };
                },
                .param => {
                    const attr: Node.Repr.DeclAttr = @bitCast(node_data[1]);
                    return .{
                        .param = .{
                            .name_tok = node_tok,
                            .qt = @bitCast(node_data[0]),
                            .storage_class = if (attr.register)
                                .register
                            else
                                .auto,
                        },
                    };
                },
                .variable => {
                    const attr: Node.Repr.DeclAttr = @bitCast(node_data[1]);
                    return .{
                        .variable = .{
                            .name_tok = node_tok,
                            .qt = @bitCast(node_data[0]),
                            .storage_class = if (attr.static)
                                .static
                            else if (attr.@"extern")
                                .@"extern"
                            else if (attr.register)
                                .register
                            else
                                .auto,
                            .thread_local = attr.thread_local,
                            .implicit = attr.implicit,
                            .initializer = null,
                            .definition = unpackOptIndex(node_data[2]),
                        },
                    };
                },
                .variable_def => {
                    const attr: Node.Repr.DeclAttr = @bitCast(node_data[1]);
                    return .{
                        .variable = .{
                            .name_tok = node_tok,
                            .qt = @bitCast(node_data[0]),
                            .storage_class = if (attr.static)
                                .static
                            else if (attr.@"extern")
                                .@"extern"
                            else if (attr.register)
                                .register
                            else
                                .auto,
                            .thread_local = attr.thread_local,
                            .implicit = attr.implicit,
                            .initializer = unpackOptIndex(node_data[2]),
                            .definition = null,
                        },
                    };
                },
                .typedef => .{
                    .typedef = .{
                        .name_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .implicit = node_data[1] != 0,
                    },
                },
                .global_asm => .{
                    .global_asm = .{
                        .asm_tok = node_tok,
                        .asm_str = @enumFromInt(node_data[0]),
                    },
                },
                .struct_decl => .{
                    .struct_decl = .{
                        .name_or_kind_tok = node_tok,
                        .container_qt = @bitCast(node_data[0]),
                        .fields = @ptrCast(tree.extra.items[node_data[1]..][0..node_data[2]]),
                    },
                },
                .struct_decl_two => .{
                    .struct_decl = .{
                        .name_or_kind_tok = node_tok,
                        .container_qt = @bitCast(node_data[0]),
                        .fields = unPackElems(node_data[1..]),
                    },
                },
                .union_decl => .{
                    .union_decl = .{
                        .name_or_kind_tok = node_tok,
                        .container_qt = @bitCast(node_data[0]),
                        .fields = @ptrCast(tree.extra.items[node_data[1]..][0..node_data[2]]),
                    },
                },
                .union_decl_two => .{
                    .union_decl = .{
                        .name_or_kind_tok = node_tok,
                        .container_qt = @bitCast(node_data[0]),
                        .fields = unPackElems(node_data[1..]),
                    },
                },
                .enum_decl => .{
                    .enum_decl = .{
                        .name_or_kind_tok = node_tok,
                        .container_qt = @bitCast(node_data[0]),
                        .fields = @ptrCast(tree.extra.items[node_data[1]..][0..node_data[2]]),
                    },
                },
                .enum_decl_two => .{
                    .enum_decl = .{
                        .name_or_kind_tok = node_tok,
                        .container_qt = @bitCast(node_data[0]),
                        .fields = unPackElems(node_data[1..]),
                    },
                },
                .struct_forward_decl => .{
                    .struct_forward_decl = .{
                        .name_or_kind_tok = node_tok,
                        .container_qt = @bitCast(node_data[0]),
                        .definition = null,
                    },
                },
                .union_forward_decl => .{
                    .union_forward_decl = .{
                        .name_or_kind_tok = node_tok,
                        .container_qt = @bitCast(node_data[0]),
                        .definition = null,
                    },
                },
                .enum_forward_decl => .{
                    .enum_forward_decl = .{
                        .name_or_kind_tok = node_tok,
                        .container_qt = @bitCast(node_data[0]),
                        .definition = null,
                    },
                },
                .enum_field => .{
                    .enum_field = .{
                        .name_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .init = unpackOptIndex(node_data[1]),
                    },
                },
                .record_field => .{
                    .record_field = .{
                        .name_or_first_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .bit_width = unpackOptIndex(node_data[1]),
                    },
                },
                .labeled_stmt => .{
                    .labeled_stmt = .{
                        .label_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .body = @enumFromInt(node_data[1]),
                    },
                },
                .compound_stmt => .{
                    .compound_stmt = .{
                        .l_brace_tok = node_tok,
                        .body = @ptrCast(tree.extra.items[node_data[0]..][0..node_data[1]]),
                    },
                },
                .compound_stmt_three => .{
                    .compound_stmt = .{
                        .l_brace_tok = node_tok,
                        .body = unPackElems(node_data),
                    },
                },
                .if_stmt => .{
                    .if_stmt = .{
                        .if_tok = node_tok,
                        .cond = @enumFromInt(node_data[0]),
                        .then_body = @enumFromInt(node_data[1]),
                        .else_body = unpackOptIndex(node_data[2]),
                    },
                },
                .switch_stmt => .{
                    .switch_stmt = .{
                        .switch_tok = node_tok,
                        .cond = @enumFromInt(node_data[0]),
                        .body = @enumFromInt(node_data[1]),
                    },
                },
                .case_stmt => .{
                    .case_stmt = .{
                        .case_tok = node_tok,
                        .start = @enumFromInt(node_data[0]),
                        .end = unpackOptIndex(node_data[1]),
                        .body = @enumFromInt(node_data[2]),
                    },
                },
                .default_stmt => .{
                    .default_stmt = .{
                        .default_tok = node_tok,
                        .body = @enumFromInt(node_data[0]),
                    },
                },
                .while_stmt => .{
                    .while_stmt = .{
                        .while_tok = node_tok,
                        .cond = @enumFromInt(node_data[0]),
                        .body = @enumFromInt(node_data[1]),
                    },
                },
                .do_while_stmt => .{
                    .do_while_stmt = .{
                        .do_tok = node_tok,
                        .cond = @enumFromInt(node_data[0]),
                        .body = @enumFromInt(node_data[1]),
                    },
                },
                .for_decl => .{
                    .for_stmt = .{
                        .for_tok = node_tok,
                        .init = .{ .decls = @ptrCast(tree.extra.items[node_data[0]..][0 .. node_data[1] - 2]) },
                        .cond = unpackOptIndex(tree.extra.items[node_data[0] + node_data[1] - 2]),
                        .incr = unpackOptIndex(tree.extra.items[node_data[0] + node_data[1] - 1]),
                        .body = @enumFromInt(node_data[2]),
                    },
                },
                .for_expr => .{
                    .for_stmt = .{
                        .for_tok = node_tok,
                        .init = .{ .expr = unpackOptIndex(node_data[0]) },
                        .cond = unpackOptIndex(tree.extra.items[node_data[1]]),
                        .incr = unpackOptIndex(tree.extra.items[node_data[1] + 1]),
                        .body = @enumFromInt(node_data[2]),
                    },
                },
                .goto_stmt => .{
                    .goto_stmt = .{
                        .label_tok = node_tok,
                    },
                },
                .computed_goto_stmt => .{
                    .computed_goto_stmt = .{
                        .goto_tok = node_tok,
                        .expr = @enumFromInt(node_data[0]),
                    },
                },
                .continue_stmt => .{
                    .continue_stmt = .{
                        .continue_tok = node_tok,
                    },
                },
                .break_stmt => .{
                    .break_stmt = .{
                        .break_tok = node_tok,
                    },
                },
                .null_stmt => .{
                    .null_stmt = .{
                        .semicolon_or_r_brace_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                    },
                },
                .return_stmt => .{
                    .return_stmt = .{
                        .return_tok = node_tok,
                        .return_qt = @bitCast(node_data[0]),
                        .operand = .{
                            .expr = @enumFromInt(node_data[1]),
                        },
                    },
                },
                .return_none_stmt => .{
                    .return_stmt = .{
                        .return_tok = node_tok,
                        .return_qt = @bitCast(node_data[0]),
                        .operand = .none,
                    },
                },
                .implicit_return => .{
                    .return_stmt = .{
                        .return_tok = node_tok,
                        .return_qt = @bitCast(node_data[0]),
                        .operand = .{
                            .implicit = node_data[1] != 0,
                        },
                    },
                },
                .gnu_asm_simple => .{
                    .gnu_asm_simple = .{
                        .asm_tok = node_tok,
                        .asm_str = @enumFromInt(node_data[0]),
                    },
                },
                .assign_expr => .{
                    .assign_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .mul_assign_expr => .{
                    .mul_assign_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .div_assign_expr => .{
                    .div_assign_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .mod_assign_expr => .{
                    .mod_assign_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .add_assign_expr => .{
                    .add_assign_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .sub_assign_expr => .{
                    .sub_assign_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .shl_assign_expr => .{
                    .shl_assign_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .shr_assign_expr => .{
                    .shr_assign_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .bit_and_assign_expr => .{
                    .bit_and_assign_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .bit_xor_assign_expr => .{
                    .bit_xor_assign_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .bit_or_assign_expr => .{
                    .bit_or_assign_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .compound_assign_dummy_expr => .{
                    .compound_assign_dummy_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .comma_expr => .{
                    .comma_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .bool_or_expr => .{
                    .bool_or_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .bool_and_expr => .{
                    .bool_and_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .bit_or_expr => .{
                    .bit_or_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .bit_xor_expr => .{
                    .bit_xor_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .bit_and_expr => .{
                    .bit_and_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .equal_expr => .{
                    .equal_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .not_equal_expr => .{
                    .not_equal_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .less_than_expr => .{
                    .less_than_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .less_than_equal_expr => .{
                    .less_than_equal_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .greater_than_expr => .{
                    .greater_than_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .greater_than_equal_expr => .{
                    .greater_than_equal_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .shl_expr => .{
                    .shl_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .shr_expr => .{
                    .shr_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .add_expr => .{
                    .add_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .sub_expr => .{
                    .sub_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .mul_expr => .{
                    .mul_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .div_expr => .{
                    .div_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .mod_expr => .{
                    .mod_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(node_data[1]),
                        .rhs = @enumFromInt(node_data[2]),
                    },
                },
                .explicit_cast => .{
                    .cast = .{
                        .l_paren = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .kind = @enumFromInt(node_data[1]),
                        .operand = @enumFromInt(node_data[2]),
                        .implicit = false,
                    },
                },
                .implicit_cast => .{
                    .cast = .{
                        .l_paren = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .kind = @enumFromInt(node_data[1]),
                        .operand = @enumFromInt(node_data[2]),
                        .implicit = true,
                    },
                },
                .addr_of_expr => .{
                    .addr_of_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .deref_expr => .{
                    .deref_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .plus_expr => .{
                    .plus_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .negate_expr => .{
                    .negate_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .bit_not_expr => .{
                    .bit_not_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .bool_not_expr => .{
                    .bool_not_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .pre_inc_expr => .{
                    .pre_inc_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .pre_dec_expr => .{
                    .pre_dec_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .imag_expr => .{
                    .imag_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .real_expr => .{
                    .real_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .post_inc_expr => .{
                    .post_inc_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .post_dec_expr => .{
                    .post_dec_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .paren_expr => .{
                    .paren_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .stmt_expr => .{
                    .stmt_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .cond_dummy_expr => .{
                    .cond_dummy_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .addr_of_label => .{
                    .addr_of_label = .{
                        .label_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                    },
                },
                .array_access_expr => .{
                    .array_access_expr = .{
                        .l_bracket_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .base = @enumFromInt(node_data[1]),
                        .index = @enumFromInt(node_data[2]),
                    },
                },
                .call_expr => .{
                    .call_expr = .{
                        .l_paren_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .callee = @enumFromInt(tree.extra.items[node_data[1]]),
                        .args = @ptrCast(tree.extra.items[node_data[1] + 1 ..][0 .. node_data[2] - 1]),
                    },
                },
                .call_expr_one => .{
                    .call_expr = .{
                        .l_paren_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .callee = @enumFromInt(node_data[1]),
                        .args = unPackElems(node_data[2..]),
                    },
                },
                .builtin_call_expr => .{
                    .builtin_call_expr = .{
                        .builtin_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .args = @ptrCast(tree.extra.items[node_data[1]..][0..node_data[2]]),
                    },
                },
                .builtin_call_expr_two => .{
                    .builtin_call_expr = .{
                        .builtin_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .args = unPackElems(node_data[1..]),
                    },
                },
                .member_access_expr => .{
                    .member_access_expr = .{
                        .access_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .base = @enumFromInt(node_data[1]),
                        .member_index = node_data[2],
                    },
                },
                .member_access_ptr_expr => .{
                    .member_access_ptr_expr = .{
                        .access_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .base = @enumFromInt(node_data[1]),
                        .member_index = node_data[2],
                    },
                },
                .decl_ref_expr => .{
                    .decl_ref_expr = .{
                        .name_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .decl = @enumFromInt(node_data[1]),
                    },
                },
                .enumeration_ref => .{
                    .enumeration_ref = .{
                        .name_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .decl = @enumFromInt(node_data[1]),
                    },
                },
                .builtin_ref => .{
                    .builtin_ref = .{
                        .name_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                    },
                },
                .bool_literal => .{
                    .bool_literal = .{
                        .literal_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                    },
                },
                .nullptr_literal => .{
                    .nullptr_literal = .{
                        .literal_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                    },
                },
                .int_literal => .{
                    .int_literal = .{
                        .literal_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                    },
                },
                .char_literal => .{
                    .char_literal = .{
                        .literal_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .kind = @enumFromInt(node_data[1]),
                    },
                },
                .float_literal => .{
                    .float_literal = .{
                        .literal_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                    },
                },
                .string_literal_expr => .{
                    .string_literal_expr = .{
                        .literal_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .kind = @enumFromInt(node_data[1]),
                    },
                },
                .imaginary_literal => .{
                    .imaginary_literal = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .sizeof_expr => .{
                    .sizeof_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .expr = unpackOptIndex(node_data[1]),
                        .operand_qt = @bitCast(node_data[2]),
                    },
                },
                .alignof_expr => .{
                    .alignof_expr = .{
                        .op_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .expr = unpackOptIndex(node_data[1]),
                        .operand_qt = @bitCast(node_data[2]),
                    },
                },

                .generic_expr_zero => .{
                    .generic_expr = .{
                        .generic_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .controlling = @enumFromInt(node_data[1]),
                        .chosen = @enumFromInt(node_data[2]),
                        .rest = &.{},
                    },
                },
                .generic_expr => .{
                    .generic_expr = .{
                        .generic_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .controlling = @enumFromInt(tree.extra.items[node_data[1]]),
                        .chosen = @enumFromInt(tree.extra.items[node_data[1] + 1]),
                        .rest = @ptrCast(tree.extra.items[node_data[1] + 2 ..][0 .. node_data[2] - 2]),
                    },
                },
                .generic_association_expr => .{
                    .generic_association_expr = .{
                        .colon_tok = node_tok,
                        .association_qt = @bitCast(node_data[0]),
                        .expr = @enumFromInt(node_data[1]),
                    },
                },
                .generic_default_expr => .{
                    .generic_default_expr = .{
                        .default_tok = node_tok,
                        .expr = @enumFromInt(node_data[0]),
                    },
                },
                .binary_cond_expr => .{
                    .binary_cond_expr = .{
                        .cond_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .cond = @enumFromInt(node_data[1]),
                        .then_expr = @enumFromInt(tree.extra.items[node_data[2]]),
                        .else_expr = @enumFromInt(tree.extra.items[node_data[2] + 1]),
                    },
                },
                .cond_expr => .{
                    .cond_expr = .{
                        .cond_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .cond = @enumFromInt(node_data[1]),
                        .then_expr = @enumFromInt(tree.extra.items[node_data[2]]),
                        .else_expr = @enumFromInt(tree.extra.items[node_data[2] + 1]),
                    },
                },
                .builtin_choose_expr => .{
                    .builtin_choose_expr = .{
                        .cond_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .cond = @enumFromInt(node_data[1]),
                        .then_expr = @enumFromInt(tree.extra.items[node_data[2]]),
                        .else_expr = @enumFromInt(tree.extra.items[node_data[2] + 1]),
                    },
                },
                .builtin_types_compatible_p => .{
                    .builtin_types_compatible_p = .{
                        .builtin_tok = node_tok,
                        .lhs = @bitCast(node_data[0]),
                        .rhs = @bitCast(node_data[1]),
                    },
                },
                .builtin_convertvector => .{
                    .builtin_convertvector = .{
                        .builtin_tok = node_tok,
                        .dest_qt = @bitCast(node_data[0]),
                        .operand = @enumFromInt(node_data[1]),
                    },
                },
                .builtin_shufflevector => .{
                    .builtin_shufflevector = .{
                        .builtin_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .lhs = @enumFromInt(tree.extra.items[node_data[1]]),
                        .rhs = @enumFromInt(tree.extra.items[node_data[1] + 1]),
                        .indexes = @ptrCast(tree.extra.items[node_data[1] + 2 ..][0..node_data[2]]),
                    },
                },
                .array_init_expr_two => .{
                    .array_init_expr = .{
                        .l_brace_tok = node_tok,
                        .container_qt = @bitCast(node_data[0]),
                        .items = unPackElems(node_data[1..]),
                    },
                },
                .array_init_expr => .{
                    .array_init_expr = .{
                        .l_brace_tok = node_tok,
                        .container_qt = @bitCast(node_data[0]),
                        .items = @ptrCast(tree.extra.items[node_data[1]..][0..node_data[2]]),
                    },
                },
                .struct_init_expr_two => .{
                    .struct_init_expr = .{
                        .l_brace_tok = node_tok,
                        .container_qt = @bitCast(node_data[0]),
                        .items = unPackElems(node_data[1..]),
                    },
                },
                .struct_init_expr => .{
                    .struct_init_expr = .{
                        .l_brace_tok = node_tok,
                        .container_qt = @bitCast(node_data[0]),
                        .items = @ptrCast(tree.extra.items[node_data[1]..][0..node_data[2]]),
                    },
                },
                .union_init_expr => .{
                    .union_init_expr = .{
                        .l_brace_tok = node_tok,
                        .union_qt = @bitCast(node_data[0]),
                        .field_index = node_data[1],
                        .initializer = unpackOptIndex(node_data[2]),
                    },
                },
                .array_filler_expr => .{
                    .array_filler_expr = .{
                        .last_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                        .count = @bitCast(node_data[1..].*),
                    },
                },
                .default_init_expr => .{
                    .default_init_expr = .{
                        .last_tok = node_tok,
                        .qt = @bitCast(node_data[0]),
                    },
                },
                .compound_literal_expr => {
                    const attr: Node.Repr.DeclAttr = @bitCast(node_data[1]);
                    return .{
                        .compound_literal_expr = .{
                            .l_paren_tok = node_tok,
                            .qt = @bitCast(node_data[0]),
                            .storage_class = if (attr.static)
                                .static
                            else if (attr.register)
                                .register
                            else
                                .auto,
                            .thread_local = attr.thread_local,
                            .initializer = @enumFromInt(node_data[2]),
                        },
                    };
                },
            };
        }

        pub fn tok(index: Index, tree: *const Tree) TokenIndex {
            return tree.nodes.items(.tok)[@intFromEnum(index)];
        }

        pub fn loc(index: Index, tree: *const Tree) Source.Location {
            const tok_i = index.tok(tree);
            return tree.tokens.items(.loc)[tok_i];
        }

        pub fn qt(index: Index, tree: *const Tree) QualType {
            return index.qtOrNull(tree) orelse .void;
        }

        pub fn qtOrNull(index: Index, tree: *const Tree) ?QualType {
            return switch (tree.nodes.items(.tag)[@intFromEnum(index)]) {
                .empty_decl,
                .static_assert,
                .compound_stmt,
                .compound_stmt_three,
                .if_stmt,
                .switch_stmt,
                .case_stmt,
                .default_stmt,
                .while_stmt,
                .do_while_stmt,
                .for_decl,
                .for_expr,
                .goto_stmt,
                .computed_goto_stmt,
                .continue_stmt,
                .break_stmt,
                .gnu_asm_simple,
                .global_asm,
                .generic_association_expr,
                .generic_default_expr,
                => null,
                .builtin_types_compatible_p => .int,
                else => {
                    // If a node is typed the type is stored in data[0].
                    return @bitCast(tree.nodes.items(.data)[@intFromEnum(index)][0]);
                },
            };
        }
    };

    pub const OptIndex = enum(u32) {
        null = std.math.maxInt(u32),
        _,

        pub fn unpack(opt: OptIndex) ?Index {
            return if (opt == .null) null else @enumFromInt(@intFromEnum(opt));
        }

        pub fn pack(index: Index) OptIndex {
            return @enumFromInt(@intFromEnum(index));
        }

        pub fn packOpt(optional: ?Index) OptIndex {
            return if (optional) |some| @enumFromInt(@intFromEnum(some)) else .null;
        }
    };

    pub const Repr = struct {
        tag: Tag,
        /// If a node is typed the type is stored in data[0]
        data: [3]u32,
        tok: TokenIndex,

        pub const DeclAttr = packed struct(u32) {
            @"extern": bool = false,
            static: bool = false,
            @"inline": bool = false,
            thread_local: bool = false,
            implicit: bool = false,
            register: bool = false,
            _: u26 = 0,
        };

        pub const Tag = enum(u8) {
            empty_decl,
            static_assert,
            fn_proto,
            fn_def,
            param,
            variable,
            variable_def,
            typedef,
            global_asm,
            struct_decl,
            union_decl,
            enum_decl,
            struct_decl_two,
            union_decl_two,
            enum_decl_two,
            struct_forward_decl,
            union_forward_decl,
            enum_forward_decl,
            enum_field,
            record_field,
            labeled_stmt,
            compound_stmt,
            compound_stmt_three,
            if_stmt,
            switch_stmt,
            case_stmt,
            default_stmt,
            while_stmt,
            do_while_stmt,
            for_expr,
            for_decl,
            goto_stmt,
            computed_goto_stmt,
            continue_stmt,
            break_stmt,
            null_stmt,
            return_stmt,
            return_none_stmt,
            implicit_return,
            gnu_asm_simple,
            comma_expr,
            assign_expr,
            mul_assign_expr,
            div_assign_expr,
            mod_assign_expr,
            add_assign_expr,
            sub_assign_expr,
            shl_assign_expr,
            shr_assign_expr,
            bit_and_assign_expr,
            bit_xor_assign_expr,
            bit_or_assign_expr,
            compound_assign_dummy_expr,
            bool_or_expr,
            bool_and_expr,
            bit_or_expr,
            bit_xor_expr,
            bit_and_expr,
            equal_expr,
            not_equal_expr,
            less_than_expr,
            less_than_equal_expr,
            greater_than_expr,
            greater_than_equal_expr,
            shl_expr,
            shr_expr,
            add_expr,
            sub_expr,
            mul_expr,
            div_expr,
            mod_expr,
            explicit_cast,
            implicit_cast,
            addr_of_expr,
            deref_expr,
            plus_expr,
            negate_expr,
            bit_not_expr,
            bool_not_expr,
            pre_inc_expr,
            pre_dec_expr,
            imag_expr,
            real_expr,
            post_inc_expr,
            post_dec_expr,
            paren_expr,
            stmt_expr,
            addr_of_label,
            array_access_expr,
            call_expr_one,
            call_expr,
            builtin_call_expr,
            builtin_call_expr_two,
            member_access_expr,
            member_access_ptr_expr,
            decl_ref_expr,
            enumeration_ref,
            builtin_ref,
            bool_literal,
            nullptr_literal,
            int_literal,
            char_literal,
            float_literal,
            string_literal_expr,
            imaginary_literal,
            sizeof_expr,
            alignof_expr,
            generic_expr,
            generic_expr_zero,
            generic_association_expr,
            generic_default_expr,
            binary_cond_expr,
            cond_dummy_expr,
            cond_expr,
            builtin_choose_expr,
            builtin_types_compatible_p,
            builtin_convertvector,
            builtin_shufflevector,
            array_init_expr,
            array_init_expr_two,
            struct_init_expr,
            struct_init_expr_two,
            union_init_expr,
            array_filler_expr,
            default_init_expr,
            compound_literal_expr,
        };
    };

    pub fn isImplicit(node: Node) bool {
        return switch (node) {
            .array_filler_expr,
            .default_init_expr,
            .cond_dummy_expr,
            .compound_assign_dummy_expr,
            => true,
            .return_stmt => |ret| ret.operand == .implicit,
            .cast => |cast| cast.implicit,
            .variable => |info| info.implicit,
            .typedef => |info| info.implicit,
            else => false,
        };
    }
};

pub fn addNode(tree: *Tree, node: Node) !Node.Index {
    const index = try tree.nodes.addOne(tree.comp.gpa);
    try tree.setNode(node, index);
    return @enumFromInt(index);
}

pub fn setNode(tree: *Tree, node: Node, index: usize) !void {
    var repr: Node.Repr = undefined;
    switch (node) {
        .empty_decl => |empty| {
            repr.tag = .empty_decl;
            repr.tok = empty.semicolon;
        },
        .static_assert => |assert| {
            repr.tag = .static_assert;
            repr.data[0] = @intFromEnum(assert.cond);
            repr.data[1] = packOptIndex(assert.message);
            repr.tok = assert.assert_tok;
        },
        .function => |function| {
            repr.tag = if (function.body != null) .fn_def else .fn_proto;
            repr.data[0] = @bitCast(function.qt);
            repr.data[1] = @bitCast(Node.Repr.DeclAttr{
                .static = function.static,
                .@"inline" = function.@"inline",
            });
            if (function.body) |some| {
                repr.data[2] = @intFromEnum(some);
            } else {
                repr.data[2] = packOptIndex(function.definition);
            }
            repr.tok = function.name_tok;
        },
        .param => |param| {
            repr.tag = .param;
            repr.data[0] = @bitCast(param.qt);
            repr.data[1] = @bitCast(Node.Repr.DeclAttr{
                .register = param.storage_class == .register,
            });
            repr.tok = param.name_tok;
        },
        .variable => |variable| {
            repr.tag = if (variable.initializer != null) .variable_def else .variable;
            repr.data[0] = @bitCast(variable.qt);
            repr.data[1] = @bitCast(Node.Repr.DeclAttr{
                .@"extern" = variable.storage_class == .@"extern",
                .static = variable.storage_class == .static,
                .thread_local = variable.thread_local,
                .implicit = variable.implicit,
                .register = variable.storage_class == .register,
            });
            if (variable.initializer) |some| {
                repr.data[2] = @intFromEnum(some);
            } else {
                repr.data[2] = packOptIndex(variable.definition);
            }
            repr.tok = variable.name_tok;
        },
        .typedef => |typedef| {
            repr.tag = .typedef;
            repr.data[0] = @bitCast(typedef.qt);
            repr.data[1] = @intFromBool(typedef.implicit);
            repr.tok = typedef.name_tok;
        },
        .global_asm => |global_asm| {
            repr.tag = .global_asm;
            repr.data[0] = @intFromEnum(global_asm.asm_str);
            repr.tok = global_asm.asm_tok;
        },
        .struct_decl => |decl| {
            repr.data[0] = @bitCast(decl.container_qt);
            if (decl.fields.len > 2) {
                repr.tag = .struct_decl;
                repr.data[1], repr.data[2] = try tree.addExtra(decl.fields);
            } else {
                repr.tag = .struct_decl_two;
                repr.data[1] = packElem(decl.fields, 0);
                repr.data[2] = packElem(decl.fields, 1);
            }
            repr.tok = decl.name_or_kind_tok;
        },
        .union_decl => |decl| {
            repr.data[0] = @bitCast(decl.container_qt);
            if (decl.fields.len > 2) {
                repr.tag = .union_decl;
                repr.data[1], repr.data[2] = try tree.addExtra(decl.fields);
            } else {
                repr.tag = .union_decl_two;
                repr.data[1] = packElem(decl.fields, 0);
                repr.data[2] = packElem(decl.fields, 1);
            }
            repr.tok = decl.name_or_kind_tok;
        },
        .enum_decl => |decl| {
            repr.data[0] = @bitCast(decl.container_qt);
            if (decl.fields.len > 2) {
                repr.tag = .enum_decl;
                repr.data[1], repr.data[2] = try tree.addExtra(decl.fields);
            } else {
                repr.tag = .enum_decl_two;
                repr.data[1] = packElem(decl.fields, 0);
                repr.data[2] = packElem(decl.fields, 1);
            }
            repr.tok = decl.name_or_kind_tok;
        },
        .struct_forward_decl => |decl| {
            repr.tag = .struct_forward_decl;
            repr.data[0] = @bitCast(decl.container_qt);
            // TODO decide how to handle definition
            // repr.data[1] = decl.definition;
            repr.tok = decl.name_or_kind_tok;
        },
        .union_forward_decl => |decl| {
            repr.tag = .union_forward_decl;
            repr.data[0] = @bitCast(decl.container_qt);
            // TODO decide how to handle definition
            // repr.data[1] = decl.definition;
            repr.tok = decl.name_or_kind_tok;
        },
        .enum_forward_decl => |decl| {
            repr.tag = .enum_forward_decl;
            repr.data[0] = @bitCast(decl.container_qt);
            // TODO decide how to handle definition
            // repr.data[1] = decl.definition;
            repr.tok = decl.name_or_kind_tok;
        },
        .enum_field => |field| {
            repr.tag = .enum_field;
            repr.data[0] = @bitCast(field.qt);
            repr.data[1] = packOptIndex(field.init);
            repr.tok = field.name_tok;
        },
        .record_field => |field| {
            repr.tag = .record_field;
            repr.data[0] = @bitCast(field.qt);
            repr.data[1] = packOptIndex(field.bit_width);
            repr.tok = field.name_or_first_tok;
        },
        .labeled_stmt => |labeled| {
            repr.tag = .labeled_stmt;
            repr.data[0] = @bitCast(labeled.qt);
            repr.data[1] = @intFromEnum(labeled.body);
            repr.tok = labeled.label_tok;
        },
        .compound_stmt => |compound| {
            if (compound.body.len > 3) {
                repr.tag = .compound_stmt;
                repr.data[0], repr.data[1] = try tree.addExtra(compound.body);
            } else {
                repr.tag = .compound_stmt_three;
                for (&repr.data, 0..) |*data, idx|
                    data.* = packElem(compound.body, idx);
            }
            repr.tok = compound.l_brace_tok;
        },
        .if_stmt => |@"if"| {
            repr.tag = .if_stmt;
            repr.data[0] = @intFromEnum(@"if".cond);
            repr.data[1] = @intFromEnum(@"if".then_body);
            repr.data[2] = packOptIndex(@"if".else_body);
            repr.tok = @"if".if_tok;
        },
        .switch_stmt => |@"switch"| {
            repr.tag = .switch_stmt;
            repr.data[0] = @intFromEnum(@"switch".cond);
            repr.data[1] = @intFromEnum(@"switch".body);
            repr.tok = @"switch".switch_tok;
        },
        .case_stmt => |case| {
            repr.tag = .case_stmt;
            repr.data[0] = @intFromEnum(case.start);
            repr.data[1] = packOptIndex(case.end);
            repr.data[2] = packOptIndex(case.body);
            repr.tok = case.case_tok;
        },
        .default_stmt => |default| {
            repr.tag = .default_stmt;
            repr.data[0] = @intFromEnum(default.body);
            repr.tok = default.default_tok;
        },
        .while_stmt => |@"while"| {
            repr.tag = .while_stmt;
            repr.data[0] = @intFromEnum(@"while".cond);
            repr.data[1] = @intFromEnum(@"while".body);
            repr.tok = @"while".while_tok;
        },
        .do_while_stmt => |do_while| {
            repr.tag = .do_while_stmt;
            repr.data[0] = @intFromEnum(do_while.cond);
            repr.data[1] = @intFromEnum(do_while.body);
            repr.tok = do_while.do_tok;
        },
        .for_stmt => |@"for"| {
            switch (@"for".init) {
                .decls => |decls| {
                    repr.tag = .for_decl;
                    repr.data[0] = @intCast(tree.extra.items.len);
                    const len: u32 = @intCast(decls.len + 2);
                    try tree.extra.ensureUnusedCapacity(tree.comp.gpa, len);
                    repr.data[1] = len;
                    tree.extra.appendSliceAssumeCapacity(@ptrCast(decls));
                    tree.extra.appendAssumeCapacity(packOptIndex(@"for".cond));
                    tree.extra.appendAssumeCapacity(packOptIndex(@"for".incr));
                },
                .expr => |expr| {
                    repr.tag = .for_expr;
                    repr.data[0] = packOptIndex(expr);
                    repr.data[1] = @intCast(tree.extra.items.len);
                    try tree.extra.ensureUnusedCapacity(tree.comp.gpa, 2);
                    tree.extra.appendAssumeCapacity(packOptIndex(@"for".cond));
                    tree.extra.appendAssumeCapacity(packOptIndex(@"for".incr));
                },
            }
            repr.data[2] = @intFromEnum(@"for".body);
            repr.tok = @"for".for_tok;
        },
        .goto_stmt => |goto| {
            repr.tag = .goto_stmt;
            repr.tok = goto.label_tok;
        },
        .computed_goto_stmt => |computed_goto| {
            repr.tag = .computed_goto_stmt;
            repr.data[0] = @intFromEnum(computed_goto.expr);
            repr.tok = computed_goto.goto_tok;
        },
        .continue_stmt => |@"continue"| {
            repr.tag = .continue_stmt;
            repr.tok = @"continue".continue_tok;
        },
        .break_stmt => |@"break"| {
            repr.tag = .break_stmt;
            repr.tok = @"break".break_tok;
        },
        .null_stmt => |@"null"| {
            repr.tag = .null_stmt;
            repr.data[0] = @bitCast(@"null".qt);
            repr.tok = @"null".semicolon_or_r_brace_tok;
        },
        .return_stmt => |@"return"| {
            repr.data[0] = @bitCast(@"return".return_qt);
            switch (@"return".operand) {
                .expr => |expr| {
                    repr.tag = .return_stmt;
                    repr.data[1] = @intFromEnum(expr);
                },
                .none => {
                    repr.tag = .return_none_stmt;
                },
                .implicit => |zeroes| {
                    repr.tag = .implicit_return;
                    repr.data[1] = @intFromBool(zeroes);
                },
            }
            repr.tok = @"return".return_tok;
        },
        .gnu_asm_simple => |gnu_asm_simple| {
            repr.tag = .gnu_asm_simple;
            repr.data[0] = @intFromEnum(gnu_asm_simple.asm_str);
            repr.tok = gnu_asm_simple.asm_tok;
        },
        .assign_expr => |bin| {
            repr.tag = .assign_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .mul_assign_expr => |bin| {
            repr.tag = .mul_assign_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .div_assign_expr => |bin| {
            repr.tag = .div_assign_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .mod_assign_expr => |bin| {
            repr.tag = .mod_assign_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .add_assign_expr => |bin| {
            repr.tag = .add_assign_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .sub_assign_expr => |bin| {
            repr.tag = .sub_assign_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .shl_assign_expr => |bin| {
            repr.tag = .shl_assign_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .shr_assign_expr => |bin| {
            repr.tag = .shr_assign_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .bit_and_assign_expr => |bin| {
            repr.tag = .bit_and_assign_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .bit_xor_assign_expr => |bin| {
            repr.tag = .bit_xor_assign_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .bit_or_assign_expr => |bin| {
            repr.tag = .bit_or_assign_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .compound_assign_dummy_expr => |un| {
            repr.tag = .compound_assign_dummy_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .comma_expr => |bin| {
            repr.tag = .comma_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .bool_or_expr => |bin| {
            repr.tag = .bool_or_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .bool_and_expr => |bin| {
            repr.tag = .bool_and_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .bit_or_expr => |bin| {
            repr.tag = .bit_or_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .bit_xor_expr => |bin| {
            repr.tag = .bit_xor_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .bit_and_expr => |bin| {
            repr.tag = .bit_and_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .equal_expr => |bin| {
            repr.tag = .equal_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .not_equal_expr => |bin| {
            repr.tag = .not_equal_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .less_than_expr => |bin| {
            repr.tag = .less_than_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .less_than_equal_expr => |bin| {
            repr.tag = .less_than_equal_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .greater_than_expr => |bin| {
            repr.tag = .greater_than_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .greater_than_equal_expr => |bin| {
            repr.tag = .greater_than_equal_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .shl_expr => |bin| {
            repr.tag = .shl_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .shr_expr => |bin| {
            repr.tag = .shr_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .add_expr => |bin| {
            repr.tag = .add_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .sub_expr => |bin| {
            repr.tag = .sub_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .mul_expr => |bin| {
            repr.tag = .mul_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .div_expr => |bin| {
            repr.tag = .div_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .mod_expr => |bin| {
            repr.tag = .mod_expr;
            repr.data[0] = @bitCast(bin.qt);
            repr.data[1] = @intFromEnum(bin.lhs);
            repr.data[2] = @intFromEnum(bin.rhs);
            repr.tok = bin.op_tok;
        },
        .cast => |cast| {
            repr.tag = if (cast.implicit) .implicit_cast else .explicit_cast;
            repr.data[0] = @bitCast(cast.qt);
            repr.data[1] = @intFromEnum(cast.kind);
            repr.data[2] = @intFromEnum(cast.operand);
            repr.tok = cast.l_paren;
        },
        .addr_of_expr => |un| {
            repr.tag = .addr_of_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .deref_expr => |un| {
            repr.tag = .deref_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .plus_expr => |un| {
            repr.tag = .plus_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .negate_expr => |un| {
            repr.tag = .negate_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .bit_not_expr => |un| {
            repr.tag = .bit_not_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .bool_not_expr => |un| {
            repr.tag = .bool_not_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .pre_inc_expr => |un| {
            repr.tag = .pre_inc_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .pre_dec_expr => |un| {
            repr.tag = .pre_dec_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .imag_expr => |un| {
            repr.tag = .imag_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .real_expr => |un| {
            repr.tag = .real_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .post_inc_expr => |un| {
            repr.tag = .post_inc_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .post_dec_expr => |un| {
            repr.tag = .post_dec_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .paren_expr => |un| {
            repr.tag = .paren_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .stmt_expr => |un| {
            repr.tag = .stmt_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .cond_dummy_expr => |un| {
            repr.tag = .cond_dummy_expr;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .addr_of_label => |addr_of| {
            repr.tag = .addr_of_label;
            repr.data[0] = @bitCast(addr_of.qt);
            repr.tok = addr_of.label_tok;
        },
        .array_access_expr => |access| {
            repr.tag = .array_access_expr;
            repr.data[0] = @bitCast(access.qt);
            repr.data[1] = @intFromEnum(access.base);
            repr.data[2] = @intFromEnum(access.index);
            repr.tok = access.l_bracket_tok;
        },
        .call_expr => |call| {
            repr.data[0] = @bitCast(call.qt);
            if (call.args.len > 1) {
                repr.tag = .call_expr;
                repr.data[1] = @intCast(tree.extra.items.len);
                const len: u32 = @intCast(call.args.len + 1);
                repr.data[2] = len;
                try tree.extra.ensureUnusedCapacity(tree.comp.gpa, len);
                tree.extra.appendAssumeCapacity(@intFromEnum(call.callee));
                tree.extra.appendSliceAssumeCapacity(@ptrCast(call.args));
            } else {
                repr.tag = .call_expr_one;
                repr.data[1] = @intFromEnum(call.callee);
                repr.data[2] = packElem(call.args, 0);
            }
            repr.tok = call.l_paren_tok;
        },
        .builtin_call_expr => |call| {
            repr.data[0] = @bitCast(call.qt);
            if (call.args.len > 2) {
                repr.tag = .builtin_call_expr;
                repr.data[1], repr.data[2] = try tree.addExtra(call.args);
            } else {
                repr.tag = .builtin_call_expr_two;
                repr.data[1] = packElem(call.args, 0);
                repr.data[2] = packElem(call.args, 1);
            }
            repr.tok = call.builtin_tok;
        },
        .member_access_expr => |access| {
            repr.tag = .member_access_expr;
            repr.data[0] = @bitCast(access.qt);
            repr.data[1] = @intFromEnum(access.base);
            repr.data[2] = access.member_index;
            repr.tok = access.access_tok;
        },
        .member_access_ptr_expr => |access| {
            repr.tag = .member_access_ptr_expr;
            repr.data[0] = @bitCast(access.qt);
            repr.data[1] = @intFromEnum(access.base);
            repr.data[2] = access.member_index;
            repr.tok = access.access_tok;
        },
        .decl_ref_expr => |decl_ref| {
            repr.tag = .decl_ref_expr;
            repr.data[0] = @bitCast(decl_ref.qt);
            repr.data[1] = @intFromEnum(decl_ref.decl);
            repr.tok = decl_ref.name_tok;
        },
        .enumeration_ref => |enumeration_ref| {
            repr.tag = .enumeration_ref;
            repr.data[0] = @bitCast(enumeration_ref.qt);
            repr.data[1] = @intFromEnum(enumeration_ref.decl);
            repr.tok = enumeration_ref.name_tok;
        },
        .builtin_ref => |builtin_ref| {
            repr.tag = .builtin_ref;
            repr.data[0] = @bitCast(builtin_ref.qt);
            repr.tok = builtin_ref.name_tok;
        },
        .bool_literal => |literal| {
            repr.tag = .bool_literal;
            repr.data[0] = @bitCast(literal.qt);
            repr.tok = literal.literal_tok;
        },
        .nullptr_literal => |literal| {
            repr.tag = .nullptr_literal;
            repr.data[0] = @bitCast(literal.qt);
            repr.tok = literal.literal_tok;
        },
        .int_literal => |literal| {
            repr.tag = .int_literal;
            repr.data[0] = @bitCast(literal.qt);
            repr.tok = literal.literal_tok;
        },
        .char_literal => |literal| {
            repr.tag = .char_literal;
            repr.data[0] = @bitCast(literal.qt);
            repr.data[1] = @intFromEnum(literal.kind);
            repr.tok = literal.literal_tok;
        },
        .float_literal => |literal| {
            repr.tag = .float_literal;
            repr.data[0] = @bitCast(literal.qt);
            repr.tok = literal.literal_tok;
        },
        .string_literal_expr => |literal| {
            repr.tag = .string_literal_expr;
            repr.data[0] = @bitCast(literal.qt);
            repr.data[1] = @intFromEnum(literal.kind);
            repr.tok = literal.literal_tok;
        },
        .imaginary_literal => |un| {
            repr.tag = .imaginary_literal;
            repr.data[0] = @bitCast(un.qt);
            repr.data[1] = @intFromEnum(un.operand);
            repr.tok = un.op_tok;
        },
        .sizeof_expr => |type_info| {
            repr.tag = .sizeof_expr;
            repr.data[0] = @bitCast(type_info.qt);
            repr.data[1] = packOptIndex(type_info.expr);
            repr.data[2] = @bitCast(type_info.operand_qt);
            repr.tok = type_info.op_tok;
        },
        .alignof_expr => |type_info| {
            repr.tag = .alignof_expr;
            repr.data[0] = @bitCast(type_info.qt);
            repr.data[1] = packOptIndex(type_info.expr);
            repr.data[2] = @bitCast(type_info.operand_qt);
            repr.tok = type_info.op_tok;
        },
        .generic_expr => |generic| {
            repr.data[0] = @bitCast(generic.qt);
            if (generic.rest.len > 0) {
                repr.tag = .generic_expr;
                repr.data[1] = @intCast(tree.extra.items.len);
                const len: u32 = @intCast(generic.rest.len + 2);
                repr.data[2] = len;
                try tree.extra.ensureUnusedCapacity(tree.comp.gpa, len);
                tree.extra.appendAssumeCapacity(@intFromEnum(generic.controlling));
                tree.extra.appendAssumeCapacity(@intFromEnum(generic.chosen));
                tree.extra.appendSliceAssumeCapacity(@ptrCast(generic.rest));
            } else {
                repr.tag = .generic_expr_zero;
                repr.data[1] = @intFromEnum(generic.controlling);
                repr.data[2] = @intFromEnum(generic.chosen);
            }
            repr.tok = generic.generic_tok;
        },
        .generic_association_expr => |association| {
            repr.tag = .generic_association_expr;
            repr.data[0] = @bitCast(association.association_qt);
            repr.data[1] = @intFromEnum(association.expr);
            repr.tok = association.colon_tok;
        },
        .generic_default_expr => |default| {
            repr.tag = .generic_default_expr;
            repr.data[0] = @intFromEnum(default.expr);
            repr.tok = default.default_tok;
        },
        .binary_cond_expr => |cond| {
            repr.tag = .binary_cond_expr;
            repr.data[0] = @bitCast(cond.qt);
            repr.data[1] = @intFromEnum(cond.cond);
            repr.data[2], _ = try tree.addExtra(&.{ cond.then_expr, cond.else_expr });
            repr.tok = cond.cond_tok;
        },
        .cond_expr => |cond| {
            repr.tag = .cond_expr;
            repr.data[0] = @bitCast(cond.qt);
            repr.data[1] = @intFromEnum(cond.cond);
            repr.data[2], _ = try tree.addExtra(&.{ cond.then_expr, cond.else_expr });
            repr.tok = cond.cond_tok;
        },
        .builtin_choose_expr => |cond| {
            repr.tag = .builtin_choose_expr;
            repr.data[0] = @bitCast(cond.qt);
            repr.data[1] = @intFromEnum(cond.cond);
            repr.data[2], _ = try tree.addExtra(&.{ cond.then_expr, cond.else_expr });
            repr.tok = cond.cond_tok;
        },
        .builtin_types_compatible_p => |builtin| {
            repr.tag = .builtin_types_compatible_p;
            repr.data[0] = @bitCast(builtin.lhs);
            repr.data[1] = @bitCast(builtin.rhs);
            repr.tok = builtin.builtin_tok;
        },
        .builtin_convertvector => |builtin| {
            repr.tag = .builtin_convertvector;
            repr.data[0] = @bitCast(builtin.dest_qt);
            repr.data[1] = @intFromEnum(builtin.operand);
            repr.tok = builtin.builtin_tok;
        },
        .builtin_shufflevector => |builtin| {
            repr.tag = .builtin_shufflevector;
            repr.data[0] = @bitCast(builtin.qt);
            repr.data[1] = @intCast(tree.extra.items.len);
            repr.data[2] = @intCast(builtin.indexes.len);
            repr.tok = builtin.builtin_tok;
            try tree.extra.ensureUnusedCapacity(tree.comp.gpa, builtin.indexes.len + 2);
            tree.extra.appendAssumeCapacity(@intFromEnum(builtin.lhs));
            tree.extra.appendAssumeCapacity(@intFromEnum(builtin.rhs));
            tree.extra.appendSliceAssumeCapacity(@ptrCast(builtin.indexes));
        },
        .array_init_expr => |init| {
            repr.data[0] = @bitCast(init.container_qt);
            if (init.items.len > 2) {
                repr.tag = .array_init_expr;
                repr.data[1], repr.data[2] = try tree.addExtra(init.items);
            } else {
                repr.tag = .array_init_expr_two;
                repr.data[1] = packElem(init.items, 0);
                repr.data[2] = packElem(init.items, 1);
            }
            repr.tok = init.l_brace_tok;
        },
        .struct_init_expr => |init| {
            repr.data[0] = @bitCast(init.container_qt);
            if (init.items.len > 2) {
                repr.tag = .struct_init_expr;
                repr.data[1], repr.data[2] = try tree.addExtra(init.items);
            } else {
                repr.tag = .struct_init_expr_two;
                repr.data[1] = packElem(init.items, 0);
                repr.data[2] = packElem(init.items, 1);
            }
            repr.tok = init.l_brace_tok;
        },
        .union_init_expr => |init| {
            repr.tag = .union_init_expr;
            repr.data[0] = @bitCast(init.union_qt);
            repr.data[1] = init.field_index;
            repr.data[2] = packOptIndex(init.initializer);
            repr.tok = init.l_brace_tok;
        },
        .array_filler_expr => |filler| {
            repr.tag = .array_filler_expr;
            repr.data[0] = @bitCast(filler.qt);
            repr.data[1], repr.data[2] = @as([2]u32, @bitCast(filler.count));
            repr.tok = filler.last_tok;
        },
        .default_init_expr => |default| {
            repr.tag = .default_init_expr;
            repr.data[0] = @bitCast(default.qt);
            repr.tok = default.last_tok;
        },
        .compound_literal_expr => |literal| {
            repr.tag = .compound_literal_expr;
            repr.data[0] = @bitCast(literal.qt);
            repr.data[1] = @bitCast(Node.Repr.DeclAttr{
                .static = literal.storage_class == .static,
                .register = literal.storage_class == .register,
                .thread_local = literal.thread_local,
            });
            repr.data[2] = @intFromEnum(literal.initializer);
            repr.tok = literal.l_paren_tok;
        },
    }
    tree.nodes.set(index, repr);
}

fn packOptIndex(opt: ?Node.Index) u32 {
    return @intFromEnum(Node.OptIndex.packOpt(opt));
}

fn unpackOptIndex(idx: u32) ?Node.Index {
    return @as(Node.OptIndex, @enumFromInt(idx)).unpack();
}

fn packElem(nodes: []const Node.Index, index: usize) u32 {
    return if (nodes.len > index) @intFromEnum(nodes[index]) else @intFromEnum(Node.OptIndex.null);
}

fn unPackElems(data: []const u32) []const Node.Index {
    const sentinel = @intFromEnum(Node.OptIndex.null);
    for (data, 0..) |item, i| {
        if (item == sentinel) return @ptrCast(data[0..i]);
    }
    return @ptrCast(data);
}

/// Returns index to `tree.extra` and length of data
fn addExtra(tree: *Tree, data: []const Node.Index) !struct { u32, u32 } {
    const index: u32 = @intCast(tree.extra.items.len);
    try tree.extra.appendSlice(tree.comp.gpa, @ptrCast(data));
    return .{ index, @intCast(data.len) };
}

pub fn isBitfield(tree: *const Tree, node: Node.Index) bool {
    return tree.bitfieldWidth(node, false) != null;
}

/// Returns null if node is not a bitfield. If inspect_lval is true, this function will
/// recurse into implicit lval_to_rval casts (useful for arithmetic conversions)
pub fn bitfieldWidth(tree: *const Tree, node: Node.Index, inspect_lval: bool) ?u32 {
    switch (node.get(tree)) {
        .member_access_expr, .member_access_ptr_expr => |access| return access.isBitFieldWidth(tree),
        .cast => |cast| {
            if (!inspect_lval) return null;

            return switch (cast.kind) {
                .lval_to_rval => tree.bitfieldWidth(cast.operand, false),
                else => null,
            };
        },
        else => return null,
    }
}

const CallableResultUsage = struct {
    /// name token of the thing being called, for diagnostics
    tok: TokenIndex,
    /// true if `nodiscard` attribute present
    nodiscard: bool,
    /// true if `warn_unused_result` attribute present
    warn_unused_result: bool,
};

pub fn callableResultUsage(tree: *const Tree, node: Node.Index) ?CallableResultUsage {
    var cur_node = node;
    while (true) switch (cur_node.get(tree)) {
        .decl_ref_expr => |decl_ref| return .{
            .tok = decl_ref.name_tok,
            .nodiscard = decl_ref.qt.hasAttribute(tree.comp, .nodiscard),
            .warn_unused_result = decl_ref.qt.hasAttribute(tree.comp, .warn_unused_result),
        },

        .paren_expr, .addr_of_expr, .deref_expr => |un| cur_node = un.operand,
        .comma_expr => |bin| cur_node = bin.rhs,
        .cast => |cast| cur_node = cast.operand,
        .call_expr => |call| cur_node = call.callee,
        .member_access_expr, .member_access_ptr_expr => |access| {
            var qt = access.base.qt(tree);
            if (qt.get(tree.comp, .pointer)) |pointer| qt = pointer.child;
            const record_ty = switch (qt.base(tree.comp).type) {
                .@"struct", .@"union" => |record| record,
                else => return null,
            };

            const field = record_ty.fields[access.member_index];
            const attributes = field.attributes(tree.comp);
            return .{
                .tok = field.name_tok,
                .nodiscard = for (attributes) |attr| {
                    if (attr.tag == .nodiscard) break true;
                } else false,
                .warn_unused_result = for (attributes) |attr| {
                    if (attr.tag == .warn_unused_result) break true;
                } else false,
            };
        },
        else => return null,
    };
}

pub fn isLval(tree: *const Tree, node: Node.Index) bool {
    var is_const: bool = undefined;
    return tree.isLvalExtra(node, &is_const);
}

pub fn isLvalExtra(tree: *const Tree, node: Node.Index, is_const: *bool) bool {
    is_const.* = false;
    var cur_node = node;
    switch (cur_node.get(tree)) {
        .compound_literal_expr => |literal| {
            is_const.* = literal.qt.@"const";
            return true;
        },
        .string_literal_expr => return true,
        .member_access_ptr_expr => |access| {
            const ptr_qt = access.base.qt(tree);
            if (ptr_qt.get(tree.comp, .pointer)) |pointer| is_const.* = pointer.child.@"const";
            return true;
        },
        .member_access_expr => |access| {
            return tree.isLvalExtra(access.base, is_const);
        },
        .array_access_expr => |access| {
            const base_qt = access.base.qt(tree);
            // Array access operand undergoes lval conversions so the base can never
            // be a pure array type.
            if (base_qt.get(tree.comp, .pointer)) |pointer| is_const.* = pointer.child.@"const";
            return true;
        },
        .decl_ref_expr => |decl_ref| {
            is_const.* = decl_ref.qt.@"const";
            return true;
        },
        .deref_expr => |un| {
            const operand_qt = un.operand.qt(tree);
            switch (operand_qt.base(tree.comp).type) {
                .func => return false,
                .pointer => |pointer| is_const.* = pointer.child.@"const",
                else => {},
            }
            return true;
        },
        .paren_expr => |un| {
            return tree.isLvalExtra(un.operand, is_const);
        },
        .builtin_choose_expr => |conditional| {
            if (tree.value_map.get(conditional.cond)) |val| {
                if (!val.isZero(tree.comp)) {
                    return tree.isLvalExtra(conditional.then_expr, is_const);
                } else {
                    return tree.isLvalExtra(conditional.else_expr, is_const);
                }
            }
            return false;
        },
        .compound_assign_dummy_expr => return true,
        else => return false,
    }
}

pub fn tokSlice(tree: *const Tree, tok_i: TokenIndex) []const u8 {
    if (tree.tokens.items(.id)[tok_i].lexeme()) |some| return some;
    const loc = tree.tokens.items(.loc)[tok_i];
    return tree.comp.locSlice(loc);
}

pub fn dump(tree: *const Tree, config: std.Io.tty.Config, w: *std.Io.Writer) std.Io.tty.Config.SetColorError!void {
    for (tree.root_decls.items) |i| {
        try tree.dumpNode(i, 0, config, w);
        try w.writeByte('\n');
    }
    try w.flush();
}

fn dumpFieldAttributes(tree: *const Tree, attributes: []const Attribute, level: u32, w: *std.Io.Writer) !void {
    for (attributes) |attr| {
        try w.splatByteAll(' ', level);
        try w.print("field attr: {s}", .{@tagName(attr.tag)});
        try tree.dumpAttribute(attr, w);
    }
}

fn dumpAttribute(tree: *const Tree, attr: Attribute, w: *std.Io.Writer) !void {
    switch (attr.tag) {
        inline else => |tag| {
            const args = @field(attr.args, @tagName(tag));
            const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
            if (fields.len == 0) {
                try w.writeByte('\n');
                return;
            }
            try w.writeByte(' ');
            inline for (fields, 0..) |f, i| {
                if (comptime std.mem.eql(u8, f.name, "__name_tok")) continue;
                if (i != 0) {
                    try w.writeAll(", ");
                }
                try w.writeAll(f.name);
                try w.writeAll(": ");
                switch (f.type) {
                    Interner.Ref => try w.print("\"{s}\"", .{tree.interner.get(@field(args, f.name)).bytes}),
                    ?Interner.Ref => try w.print("\"{?s}\"", .{if (@field(args, f.name)) |str| tree.interner.get(str).bytes else null}),
                    else => switch (@typeInfo(f.type)) {
                        .@"enum" => try w.writeAll(@tagName(@field(args, f.name))),
                        else => try w.print("{any}", .{@field(args, f.name)}),
                    },
                }
            }
            try w.writeByte('\n');
            return;
        },
    }
}

fn dumpNode(
    tree: *const Tree,
    node_index: Node.Index,
    level: u32,
    config: std.Io.tty.Config,
    w: *std.Io.Writer,
) !void {
    const delta = 2;
    const half = delta / 2;
    const TYPE = std.Io.tty.Color.bright_magenta;
    const TAG = std.Io.tty.Color.bright_cyan;
    const IMPLICIT = std.Io.tty.Color.bright_blue;
    const NAME = std.Io.tty.Color.bright_red;
    const LITERAL = std.Io.tty.Color.bright_green;
    const ATTRIBUTE = std.Io.tty.Color.bright_yellow;

    const node = node_index.get(tree);
    try w.splatByteAll(' ', level);

    if (config == .no_color) {
        if (node.isImplicit()) try w.writeAll("implicit ");
    } else {
        try config.setColor(w, if (node.isImplicit()) IMPLICIT else TAG);
    }
    try w.print("{s}", .{@tagName(node)});

    if (node_index.qtOrNull(tree)) |qt| {
        try w.writeAll(": ");
        switch (node) {
            .cast => |cast| {
                try config.setColor(w, .white);
                try w.print("({s}) ", .{@tagName(cast.kind)});
            },
            else => {},
        }

        try config.setColor(w, TYPE);
        try w.writeByte('\'');
        try qt.dump(tree.comp, w);
        try w.writeByte('\'');
    }

    if (tree.isLval(node_index)) {
        try config.setColor(w, ATTRIBUTE);
        try w.writeAll(" lvalue");
    }
    if (tree.isBitfield(node_index)) {
        try config.setColor(w, ATTRIBUTE);
        try w.writeAll(" bitfield");
    }

    if (tree.value_map.get(node_index)) |val| {
        try config.setColor(w, LITERAL);
        try w.writeAll(" (value: ");
        if (try val.print(node_index.qt(tree), tree.comp, w)) |nested| switch (nested) {
            .pointer => |ptr| {
                switch (tree.nodes.items(.tag)[ptr.node]) {
                    .compound_literal_expr => {
                        try w.writeAll("(compound literal) ");
                        _ = try ptr.offset.print(tree.comp.type_store.ptrdiff, tree.comp, w);
                    },
                    else => {
                        const ptr_node: Node.Index = @enumFromInt(ptr.node);
                        const decl_name = tree.tokSlice(ptr_node.tok(tree));
                        try ptr.offset.printPointer(decl_name, tree.comp, w);
                    },
                }
            },
        };
        try w.writeByte(')');
    }
    if (node == .return_stmt and node.return_stmt.operand == .implicit and node.return_stmt.operand.implicit) {
        try config.setColor(w, IMPLICIT);
        try w.writeAll(" (value: 0)");
        try config.setColor(w, .reset);
    }

    try w.writeAll("\n");
    try config.setColor(w, .reset);

    if (node_index.qtOrNull(tree)) |qt| {
        try config.setColor(w, ATTRIBUTE);
        var it = Attribute.Iterator.initType(qt, tree.comp);
        while (it.next()) |item| {
            const attr, _ = item;
            try w.splatByteAll(' ', level + half);
            try w.print("attr: {s}", .{@tagName(attr.tag)});
            try tree.dumpAttribute(attr, w);
        }
        try config.setColor(w, .reset);
    }

    switch (node) {
        .empty_decl => {},
        .global_asm, .gnu_asm_simple => |@"asm"| {
            try w.splatByteAll(' ', level + 1);
            try tree.dumpNode(@"asm".asm_str, level + delta, config, w);
        },
        .static_assert => |assert| {
            try w.splatByteAll(' ', level + 1);
            try w.writeAll("condition:\n");
            try tree.dumpNode(assert.cond, level + delta, config, w);
            if (assert.message) |some| {
                try w.splatByteAll(' ', level + 1);
                try w.writeAll("diagnostic:\n");
                try tree.dumpNode(some, level + delta, config, w);
            }
        },
        .function => |function| {
            try w.splatByteAll(' ', level + half);

            try config.setColor(w, ATTRIBUTE);
            if (function.static) try w.writeAll("static ");
            if (function.@"inline") try w.writeAll("inline ");

            try config.setColor(w, .reset);
            try w.writeAll("name: ");
            try config.setColor(w, NAME);
            try w.print("{s}\n", .{tree.tokSlice(function.name_tok)});
            try config.setColor(w, .reset);

            if (function.body) |body| {
                try w.splatByteAll(' ', level + half);
                try w.writeAll("body:\n");
                try tree.dumpNode(body, level + delta, config, w);
            }
            if (function.definition) |definition| {
                try w.splatByteAll(' ', level + half);
                try w.writeAll("definition: ");
                try config.setColor(w, NAME);
                try w.print("0x{X}\n", .{@intFromEnum(definition)});
                try config.setColor(w, .reset);
            }
        },
        .typedef => |typedef| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("name: ");
            try config.setColor(w, NAME);
            try w.print("{s}\n", .{tree.tokSlice(typedef.name_tok)});
            try config.setColor(w, .reset);
        },
        .param => |param| {
            try w.splatByteAll(' ', level + half);

            switch (param.storage_class) {
                .auto => {},
                .register => {
                    try config.setColor(w, ATTRIBUTE);
                    try w.writeAll("register ");
                    try config.setColor(w, .reset);
                },
            }

            try w.writeAll("name: ");
            try config.setColor(w, NAME);
            try w.print("{s}\n", .{tree.tokSlice(param.name_tok)});
            try config.setColor(w, .reset);
        },
        .variable => |variable| {
            try w.splatByteAll(' ', level + half);

            try config.setColor(w, ATTRIBUTE);
            switch (variable.storage_class) {
                .auto => {},
                .static => try w.writeAll("static "),
                .@"extern" => try w.writeAll("extern "),
                .register => try w.writeAll("register "),
            }
            if (variable.thread_local) try w.writeAll("thread_local ");
            try config.setColor(w, .reset);

            try w.writeAll("name: ");
            try config.setColor(w, NAME);
            try w.print("{s}\n", .{tree.tokSlice(variable.name_tok)});
            try config.setColor(w, .reset);

            if (variable.initializer) |some| {
                try config.setColor(w, .reset);
                try w.splatByteAll(' ', level + half);
                try w.writeAll("init:\n");
                try tree.dumpNode(some, level + delta, config, w);
            }
            if (variable.definition) |definition| {
                try w.splatByteAll(' ', level + half);
                try w.writeAll("definition: ");
                try config.setColor(w, NAME);
                try w.print("0x{X}\n", .{@intFromEnum(definition)});
                try config.setColor(w, .reset);
            }
        },
        .enum_field => |field| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("name: ");
            try config.setColor(w, NAME);
            try w.print("{s}\n", .{tree.tokSlice(field.name_tok)});
            try config.setColor(w, .reset);
            if (field.init) |some| {
                try w.splatByteAll(' ', level + half);
                try w.writeAll("init:\n");
                try tree.dumpNode(some, level + delta, config, w);
            }
        },
        .record_field => |field| {
            const name_tok_id = tree.tokens.items(.id)[field.name_or_first_tok];
            if (name_tok_id == .identifier or name_tok_id == .extended_identifier) {
                try w.splatByteAll(' ', level + half);
                try w.writeAll("name: ");
                try config.setColor(w, NAME);
                try w.print("{s}\n", .{tree.tokSlice(field.name_or_first_tok)});
                try config.setColor(w, .reset);
            }
            if (field.bit_width) |some| {
                try w.splatByteAll(' ', level + half);
                try w.writeAll("bits:\n");
                try tree.dumpNode(some, level + delta, config, w);
            }
        },
        .compound_stmt => |compound| {
            for (compound.body, 0..) |stmt, i| {
                if (i != 0) try w.writeByte('\n');
                try tree.dumpNode(stmt, level + delta, config, w);
            }
        },
        .enum_decl => |decl| {
            for (decl.fields, 0..) |field, i| {
                if (i != 0) try w.writeByte('\n');
                try tree.dumpNode(field, level + delta, config, w);
            }
        },
        .struct_decl, .union_decl => |decl| {
            const fields = switch (node_index.qt(tree).base(tree.comp).type) {
                .@"struct", .@"union" => |record| record.fields,
                else => unreachable,
            };

            var field_i: u32 = 0;
            for (decl.fields, 0..) |field_node, i| {
                if (i != 0) try w.writeByte('\n');
                try tree.dumpNode(field_node, level + delta, config, w);

                if (field_node.get(tree) != .record_field) continue;
                if (fields.len == 0) continue;

                const field_attributes = fields[field_i].attributes(tree.comp);
                field_i += 1;

                if (field_attributes.len == 0) continue;

                try config.setColor(w, ATTRIBUTE);
                try tree.dumpFieldAttributes(field_attributes, level + delta + half, w);
                try config.setColor(w, .reset);
            }
        },
        .array_init_expr, .struct_init_expr => |init| {
            for (init.items, 0..) |item, i| {
                if (i != 0) try w.writeByte('\n');
                try tree.dumpNode(item, level + delta, config, w);
            }
        },
        .union_init_expr => |init| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("field index: ");
            try config.setColor(w, LITERAL);
            try w.print("{d}\n", .{init.field_index});
            try config.setColor(w, .reset);
            if (init.initializer) |some| {
                try tree.dumpNode(some, level + delta, config, w);
            }
        },
        .compound_literal_expr => |literal| {
            if (literal.storage_class != .auto or literal.thread_local) {
                try w.splatByteAll(' ', level + half - 1);

                try config.setColor(w, ATTRIBUTE);
                switch (literal.storage_class) {
                    .auto => {},
                    .static => try w.writeAll(" static"),
                    .register => try w.writeAll(" register"),
                }
                if (literal.thread_local) try w.writeAll(" thread_local");
                try w.writeByte('\n');
                try config.setColor(w, .reset);
            }

            try tree.dumpNode(literal.initializer, level + half, config, w);
        },
        .labeled_stmt => |labeled| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("label: ");
            try config.setColor(w, LITERAL);
            try w.print("{s}\n", .{tree.tokSlice(labeled.label_tok)});

            try config.setColor(w, .reset);
            try w.splatByteAll(' ', level + half);
            try w.writeAll("stmt:\n");
            try tree.dumpNode(labeled.body, level + delta, config, w);
        },
        .case_stmt => |case| {
            try w.splatByteAll(' ', level + half);

            if (case.end) |some| {
                try w.writeAll("range start:\n");
                try tree.dumpNode(case.start, level + delta, config, w);

                try w.splatByteAll(' ', level + half);
                try w.writeAll("range end:\n");
                try tree.dumpNode(some, level + delta, config, w);
            } else {
                try w.writeAll("value:\n");
                try tree.dumpNode(case.start, level + delta, config, w);
            }

            try w.splatByteAll(' ', level + half);
            try w.writeAll("stmt:\n");
            try tree.dumpNode(case.body, level + delta, config, w);
        },
        .default_stmt => |default| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("stmt:\n");
            try tree.dumpNode(default.body, level + delta, config, w);
        },
        .binary_cond_expr, .cond_expr, .builtin_choose_expr => |conditional| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("cond:\n");
            try tree.dumpNode(conditional.cond, level + delta, config, w);

            try w.splatByteAll(' ', level + half);
            try w.writeAll("then:\n");
            try tree.dumpNode(conditional.then_expr, level + delta, config, w);

            try w.splatByteAll(' ', level + half);
            try w.writeAll("else:\n");
            try tree.dumpNode(conditional.else_expr, level + delta, config, w);
        },
        .builtin_types_compatible_p => |call| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("lhs: ");
            try config.setColor(w, TYPE);
            try call.lhs.dump(tree.comp, w);
            try w.writeByte('\n');
            try config.setColor(w, .reset);

            try w.splatByteAll(' ', level + half);
            try w.writeAll("rhs: ");
            try config.setColor(w, TYPE);
            try call.rhs.dump(tree.comp, w);
            try w.writeByte('\n');
            try config.setColor(w, .reset);
        },
        .builtin_convertvector => |convert| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("operand:\n");
            try tree.dumpNode(convert.operand, level + delta, config, w);
        },
        .builtin_shufflevector => |shuffle| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("lhs:\n");
            try tree.dumpNode(shuffle.lhs, level + delta, config, w);

            try w.splatByteAll(' ', level + half);
            try w.writeAll("rhs:\n");
            try tree.dumpNode(shuffle.rhs, level + delta, config, w);

            if (shuffle.indexes.len > 0) {
                try w.splatByteAll(' ', level + half);
                try w.writeAll("indexes:\n");
                for (shuffle.indexes) |index| {
                    try tree.dumpNode(index, level + delta, config, w);
                }
            }
        },
        .if_stmt => |@"if"| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("cond:\n");
            try tree.dumpNode(@"if".cond, level + delta, config, w);

            try w.splatByteAll(' ', level + half);
            try w.writeAll("then:\n");
            try tree.dumpNode(@"if".then_body, level + delta, config, w);

            if (@"if".else_body) |some| {
                try w.splatByteAll(' ', level + half);
                try w.writeAll("else:\n");
                try tree.dumpNode(some, level + delta, config, w);
            }
        },
        .switch_stmt => |@"switch"| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("cond:\n");
            try tree.dumpNode(@"switch".cond, level + delta, config, w);

            try w.splatByteAll(' ', level + half);
            try w.writeAll("body:\n");
            try tree.dumpNode(@"switch".body, level + delta, config, w);
        },
        .while_stmt => |@"while"| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("cond:\n");
            try tree.dumpNode(@"while".cond, level + delta, config, w);

            try w.splatByteAll(' ', level + half);
            try w.writeAll("body:\n");
            try tree.dumpNode(@"while".body, level + delta, config, w);
        },
        .do_while_stmt => |do| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("cond:\n");
            try tree.dumpNode(do.cond, level + delta, config, w);

            try w.splatByteAll(' ', level + half);
            try w.writeAll("body:\n");
            try tree.dumpNode(do.body, level + delta, config, w);
        },
        .for_stmt => |@"for"| {
            switch (@"for".init) {
                .decls => |decls| {
                    try w.splatByteAll(' ', level + half);
                    try w.writeAll("decl:\n");
                    for (decls) |decl| {
                        try tree.dumpNode(decl, level + delta, config, w);
                        try w.writeByte('\n');
                    }
                },
                .expr => |expr| if (expr) |some| {
                    try w.splatByteAll(' ', level + half);
                    try w.writeAll("init:\n");
                    try tree.dumpNode(some, level + delta, config, w);
                },
            }
            if (@"for".cond) |some| {
                try w.splatByteAll(' ', level + half);
                try w.writeAll("cond:\n");
                try tree.dumpNode(some, level + delta, config, w);
            }
            if (@"for".incr) |some| {
                try w.splatByteAll(' ', level + half);
                try w.writeAll("incr:\n");
                try tree.dumpNode(some, level + delta, config, w);
            }
            try w.splatByteAll(' ', level + half);
            try w.writeAll("body:\n");
            try tree.dumpNode(@"for".body, level + delta, config, w);
        },
        .addr_of_label => |addr| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("label: ");
            try config.setColor(w, LITERAL);
            try w.print("{s}\n", .{tree.tokSlice(addr.label_tok)});
            try config.setColor(w, .reset);
        },
        .goto_stmt => |goto| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("label: ");
            try config.setColor(w, LITERAL);
            try w.print("{s}\n", .{tree.tokSlice(goto.label_tok)});
            try config.setColor(w, .reset);
        },
        .computed_goto_stmt => |goto| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("expr:\n");
            try tree.dumpNode(goto.expr, level + delta, config, w);
        },
        .continue_stmt, .break_stmt, .null_stmt => {},
        .return_stmt => |ret| {
            switch (ret.operand) {
                .expr => |expr| {
                    try w.splatByteAll(' ', level + half);
                    try w.writeAll("expr:\n");
                    try tree.dumpNode(expr, level + delta, config, w);
                },
                .implicit => {},
                .none => {},
            }
        },
        .call_expr => |call| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("callee:\n");
            try tree.dumpNode(call.callee, level + delta, config, w);

            if (call.args.len > 0) {
                try w.splatByteAll(' ', level + half);
                try w.writeAll("args:\n");
                for (call.args) |arg| {
                    try tree.dumpNode(arg, level + delta, config, w);
                }
            }
        },
        .builtin_call_expr => |call| {
            try w.splatByteAll(' ', level + half);
            try w.writeAll("name: ");
            try config.setColor(w, NAME);
            try w.print("{s}\n", .{tree.tokSlice(call.builtin_tok)});
            try config.setColor(w, .reset);

            if (call.args.len > 0) {
                try w.splatByteAll(' ', level + half);
                try w.writeAll("args:\n");
                for (call.args) |arg| {
                    try tree.dumpNode(arg, level + delta, config, w);
                }
            }
        },
        .assign_expr,
        .mul_assign_expr,
        .div_assign_expr,
        .mod_assign_expr,
        .add_assign_expr,
        .sub_assign_expr,
        .shl_assign_expr,
        .shr_assign_expr,
        .bit_and_assign_expr,
        .bit_xor_assign_expr,
        .bit_or_assign_expr,
        .comma_expr,
        .bool_or_expr,
        .bool_and_expr,
        .bit_or_expr,
        .bit_xor_expr,
        .bit_and_expr,
        .equal_expr,
        .not_equal_expr,
        .less_than_expr,
        .less_than_equal_expr,
        .greater_than_expr,
        .greater_than_equal_expr,
        .shl_expr,
        .shr_expr,
        .add_expr,
        .sub_expr,
        .mul_expr,
        .div_expr,
        .mod_expr,
        => |bin| {
            try w.splatByteAll(' ', level + 1);
            try w.writeAll("lhs:\n");
            try tree.dumpNode(bin.lhs, level + delta, config, w);

            try w.splatByteAll(' ', level + 1);
            try w.writeAll("rhs:\n");
            try tree.dumpNode(bin.rhs, level + delta, config, w);
        },
        .cast => |cast| try tree.dumpNode(cast.operand, level + delta, config, w),
        .addr_of_expr,
        .deref_expr,
        .plus_expr,
        .negate_expr,
        .bit_not_expr,
        .bool_not_expr,
        .pre_inc_expr,
        .pre_dec_expr,
        .imag_expr,
        .real_expr,
        .post_inc_expr,
        .post_dec_expr,
        .paren_expr,
        .stmt_expr,
        .imaginary_literal,
        => |un| {
            try w.splatByteAll(' ', level + 1);
            try w.writeAll("operand:\n");
            try tree.dumpNode(un.operand, level + delta, config, w);
        },
        .decl_ref_expr, .enumeration_ref => |dr| {
            try w.splatByteAll(' ', level + 1);
            try w.writeAll("name: ");
            try config.setColor(w, NAME);
            try w.print("{s}\n", .{tree.tokSlice(dr.name_tok)});
            try config.setColor(w, .reset);
        },
        .builtin_ref => |dr| {
            try w.splatByteAll(' ', level + 1);
            try w.writeAll("name: ");
            try config.setColor(w, NAME);
            try w.print("{s}\n", .{tree.tokSlice(dr.name_tok)});
            try config.setColor(w, .reset);
        },
        .bool_literal,
        .nullptr_literal,
        .int_literal,
        .char_literal,
        .float_literal,
        .string_literal_expr,
        => {},
        .member_access_expr, .member_access_ptr_expr => |access| {
            try w.splatByteAll(' ', level + 1);
            try w.writeAll("lhs:\n");
            try tree.dumpNode(access.base, level + delta, config, w);

            var base_qt = access.base.qt(tree);
            if (base_qt.get(tree.comp, .pointer)) |some| base_qt = some.child;
            const fields = (base_qt.getRecord(tree.comp) orelse return).fields;

            try w.splatByteAll(' ', level + 1);
            try w.writeAll("name: ");
            try config.setColor(w, NAME);
            try w.print("{s}\n", .{fields[access.member_index].name.lookup(tree.comp)});
            try config.setColor(w, .reset);
        },
        .array_access_expr => |access| {
            try w.splatByteAll(' ', level + 1);
            try w.writeAll("base:\n");
            try tree.dumpNode(access.base, level + delta, config, w);

            try w.splatByteAll(' ', level + 1);
            try w.writeAll("index:\n");
            try tree.dumpNode(access.index, level + delta, config, w);
        },
        .sizeof_expr, .alignof_expr => |type_info| {
            if (type_info.expr) |some| {
                try w.splatByteAll(' ', level + 1);
                try w.writeAll("expr:\n");
                try tree.dumpNode(some, level + delta, config, w);
            } else {
                try w.splatByteAll(' ', level + half);
                try w.writeAll("operand type: ");
                try config.setColor(w, TYPE);
                try type_info.operand_qt.dump(tree.comp, w);
                try w.writeByte('\n');
                try config.setColor(w, .reset);
            }
        },
        .generic_expr => |generic| {
            try w.splatByteAll(' ', level + 1);
            try w.writeAll("controlling:\n");
            try tree.dumpNode(generic.controlling, level + delta, config, w);
            try w.splatByteAll(' ', level + 1);
            try w.writeAll("chosen:\n");
            try tree.dumpNode(generic.chosen, level + delta, config, w);

            if (generic.rest.len > 0) {
                try w.splatByteAll(' ', level + 1);
                try w.writeAll("rest:\n");
                for (generic.rest) |expr| {
                    try tree.dumpNode(expr, level + delta, config, w);
                }
            }
        },
        .generic_association_expr => |assoc| {
            try tree.dumpNode(assoc.expr, level + delta, config, w);
        },
        .generic_default_expr => |default| {
            try tree.dumpNode(default.expr, level + delta, config, w);
        },
        .array_filler_expr => |filler| {
            try w.splatByteAll(' ', level + 1);
            try w.writeAll("count: ");
            try config.setColor(w, LITERAL);
            try w.print("{d}\n", .{filler.count});
            try config.setColor(w, .reset);
        },
        .struct_forward_decl,
        .union_forward_decl,
        .enum_forward_decl,
        .default_init_expr,
        .cond_dummy_expr,
        .compound_assign_dummy_expr,
        => {},
    }
}
