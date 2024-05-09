gpa: Allocator,
strip: bool,

source_filename: String,
data_layout: String,
target_triple: String,
module_asm: std.ArrayListUnmanaged(u8),

string_map: std.AutoArrayHashMapUnmanaged(void, void),
string_indices: std.ArrayListUnmanaged(u32),
string_bytes: std.ArrayListUnmanaged(u8),

types: std.AutoArrayHashMapUnmanaged(String, Type),
next_unnamed_type: String,
next_unique_type_id: std.AutoHashMapUnmanaged(String, u32),
type_map: std.AutoArrayHashMapUnmanaged(void, void),
type_items: std.ArrayListUnmanaged(Type.Item),
type_extra: std.ArrayListUnmanaged(u32),

attributes: std.AutoArrayHashMapUnmanaged(Attribute.Storage, void),
attributes_map: std.AutoArrayHashMapUnmanaged(void, void),
attributes_indices: std.ArrayListUnmanaged(u32),
attributes_extra: std.ArrayListUnmanaged(u32),

function_attributes_set: std.AutoArrayHashMapUnmanaged(FunctionAttributes, void),

globals: std.AutoArrayHashMapUnmanaged(StrtabString, Global),
next_unnamed_global: StrtabString,
next_replaced_global: StrtabString,
next_unique_global_id: std.AutoHashMapUnmanaged(StrtabString, u32),
aliases: std.ArrayListUnmanaged(Alias),
variables: std.ArrayListUnmanaged(Variable),
functions: std.ArrayListUnmanaged(Function),

strtab_string_map: std.AutoArrayHashMapUnmanaged(void, void),
strtab_string_indices: std.ArrayListUnmanaged(u32),
strtab_string_bytes: std.ArrayListUnmanaged(u8),

constant_map: std.AutoArrayHashMapUnmanaged(void, void),
constant_items: std.MultiArrayList(Constant.Item),
constant_extra: std.ArrayListUnmanaged(u32),
constant_limbs: std.ArrayListUnmanaged(std.math.big.Limb),

metadata_map: std.AutoArrayHashMapUnmanaged(void, void),
metadata_items: std.MultiArrayList(Metadata.Item),
metadata_extra: std.ArrayListUnmanaged(u32),
metadata_limbs: std.ArrayListUnmanaged(std.math.big.Limb),
metadata_forward_references: std.ArrayListUnmanaged(Metadata),
metadata_named: std.AutoArrayHashMapUnmanaged(MetadataString, struct {
    len: u32,
    index: Metadata.Item.ExtraIndex,
}),

metadata_string_map: std.AutoArrayHashMapUnmanaged(void, void),
metadata_string_indices: std.ArrayListUnmanaged(u32),
metadata_string_bytes: std.ArrayListUnmanaged(u8),

pub const expected_args_len = 16;
pub const expected_attrs_len = 16;
pub const expected_fields_len = 32;
pub const expected_gep_indices_len = 8;
pub const expected_cases_len = 8;
pub const expected_incoming_len = 8;

pub const Options = struct {
    allocator: Allocator,
    strip: bool = true,
    name: []const u8 = &.{},
    target: std.Target = builtin.target,
    triple: []const u8 = &.{},
};

pub const String = enum(u32) {
    none = std.math.maxInt(u31),
    empty,
    _,

    pub fn isAnon(self: String) bool {
        assert(self != .none);
        return self.toIndex() == null;
    }

    pub fn slice(self: String, builder: *const Builder) ?[]const u8 {
        const index = self.toIndex() orelse return null;
        const start = builder.string_indices.items[index];
        const end = builder.string_indices.items[index + 1];
        return builder.string_bytes.items[start..end];
    }

    const FormatData = struct {
        string: String,
        builder: *const Builder,
    };
    fn format(
        data: FormatData,
        comptime fmt_str: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (comptime std.mem.indexOfNone(u8, fmt_str, "\"r")) |_|
            @compileError("invalid format string: '" ++ fmt_str ++ "'");
        assert(data.string != .none);
        const string_slice = data.string.slice(data.builder) orelse
            return writer.print("{d}", .{@intFromEnum(data.string)});
        if (comptime std.mem.indexOfScalar(u8, fmt_str, 'r')) |_|
            return writer.writeAll(string_slice);
        try printEscapedString(
            string_slice,
            if (comptime std.mem.indexOfScalar(u8, fmt_str, '"')) |_|
                .always_quote
            else
                .quote_unless_valid_identifier,
            writer,
        );
    }
    pub fn fmt(self: String, builder: *const Builder) std.fmt.Formatter(format) {
        return .{ .data = .{ .string = self, .builder = builder } };
    }

    fn fromIndex(index: ?usize) String {
        return @enumFromInt(@as(u32, @intCast((index orelse return .none) +
            @intFromEnum(String.empty))));
    }

    fn toIndex(self: String) ?usize {
        return std.math.sub(u32, @intFromEnum(self), @intFromEnum(String.empty)) catch null;
    }

    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: Adapter, key: []const u8) u32 {
            return @truncate(std.hash.Wyhash.hash(0, key));
        }
        pub fn eql(ctx: Adapter, lhs_key: []const u8, _: void, rhs_index: usize) bool {
            return std.mem.eql(u8, lhs_key, String.fromIndex(rhs_index).slice(ctx.builder).?);
        }
    };
};

pub const BinaryOpcode = enum(u4) {
    add = 0,
    sub = 1,
    mul = 2,
    udiv = 3,
    sdiv = 4,
    urem = 5,
    srem = 6,
    shl = 7,
    lshr = 8,
    ashr = 9,
    @"and" = 10,
    @"or" = 11,
    xor = 12,
};

pub const CastOpcode = enum(u4) {
    trunc = 0,
    zext = 1,
    sext = 2,
    fptoui = 3,
    fptosi = 4,
    uitofp = 5,
    sitofp = 6,
    fptrunc = 7,
    fpext = 8,
    ptrtoint = 9,
    inttoptr = 10,
    bitcast = 11,
    addrspacecast = 12,
};

pub const CmpPredicate = enum(u6) {
    fcmp_false = 0,
    fcmp_oeq = 1,
    fcmp_ogt = 2,
    fcmp_oge = 3,
    fcmp_olt = 4,
    fcmp_ole = 5,
    fcmp_one = 6,
    fcmp_ord = 7,
    fcmp_uno = 8,
    fcmp_ueq = 9,
    fcmp_ugt = 10,
    fcmp_uge = 11,
    fcmp_ult = 12,
    fcmp_ule = 13,
    fcmp_une = 14,
    fcmp_true = 15,
    icmp_eq = 32,
    icmp_ne = 33,
    icmp_ugt = 34,
    icmp_uge = 35,
    icmp_ult = 36,
    icmp_ule = 37,
    icmp_sgt = 38,
    icmp_sge = 39,
    icmp_slt = 40,
    icmp_sle = 41,
};

pub const Type = enum(u32) {
    void,
    half,
    bfloat,
    float,
    double,
    fp128,
    x86_fp80,
    ppc_fp128,
    x86_amx,
    x86_mmx,
    label,
    token,
    metadata,

    i1,
    i8,
    i16,
    i29,
    i32,
    i64,
    i80,
    i128,
    ptr,
    @"ptr addrspace(4)",

    none = std.math.maxInt(u32),
    _,

    pub const ptr_amdgpu_constant =
        @field(Type, std.fmt.comptimePrint("ptr{ }", .{AddrSpace.amdgpu.constant}));

    pub const Tag = enum(u4) {
        simple,
        function,
        vararg_function,
        integer,
        pointer,
        target,
        vector,
        scalable_vector,
        small_array,
        array,
        structure,
        packed_structure,
        named_structure,
    };

    pub const Simple = enum(u5) {
        void = 2,
        half = 10,
        bfloat = 23,
        float = 3,
        double = 4,
        fp128 = 14,
        x86_fp80 = 13,
        ppc_fp128 = 15,
        x86_amx = 24,
        x86_mmx = 17,
        label = 5,
        token = 22,
        metadata = 16,
    };

    pub const Function = struct {
        ret: Type,
        params_len: u32,
        //params: [params_len]Value,

        pub const Kind = enum { normal, vararg };
    };

    pub const Target = extern struct {
        name: String,
        types_len: u32,
        ints_len: u32,
        //types: [types_len]Type,
        //ints: [ints_len]u32,
    };

    pub const Vector = extern struct {
        len: u32,
        child: Type,

        fn length(self: Vector) u32 {
            return self.len;
        }

        pub const Kind = enum { normal, scalable };
    };

    pub const Array = extern struct {
        len_lo: u32,
        len_hi: u32,
        child: Type,

        fn length(self: Array) u64 {
            return @as(u64, self.len_hi) << 32 | self.len_lo;
        }
    };

    pub const Structure = struct {
        fields_len: u32,
        //fields: [fields_len]Type,

        pub const Kind = enum { normal, @"packed" };
    };

    pub const NamedStructure = struct {
        id: String,
        body: Type,
    };

    pub const Item = packed struct(u32) {
        tag: Tag,
        data: ExtraIndex,

        pub const ExtraIndex = u28;
    };

    pub fn tag(self: Type, builder: *const Builder) Tag {
        return builder.type_items.items[@intFromEnum(self)].tag;
    }

    pub fn unnamedTag(self: Type, builder: *const Builder) Tag {
        const item = builder.type_items.items[@intFromEnum(self)];
        return switch (item.tag) {
            .named_structure => builder.typeExtraData(Type.NamedStructure, item.data).body
                .unnamedTag(builder),
            else => item.tag,
        };
    }

    pub fn scalarTag(self: Type, builder: *const Builder) Tag {
        const item = builder.type_items.items[@intFromEnum(self)];
        return switch (item.tag) {
            .vector, .scalable_vector => builder.typeExtraData(Type.Vector, item.data)
                .child.tag(builder),
            else => item.tag,
        };
    }

    pub fn isFloatingPoint(self: Type) bool {
        return switch (self) {
            .half, .bfloat, .float, .double, .fp128, .x86_fp80, .ppc_fp128 => true,
            else => false,
        };
    }

    pub fn isInteger(self: Type, builder: *const Builder) bool {
        return switch (self) {
            .i1, .i8, .i16, .i29, .i32, .i64, .i80, .i128 => true,
            else => switch (self.tag(builder)) {
                .integer => true,
                else => false,
            },
        };
    }

    pub fn isPointer(self: Type, builder: *const Builder) bool {
        return switch (self) {
            .ptr => true,
            else => switch (self.tag(builder)) {
                .pointer => true,
                else => false,
            },
        };
    }

    pub fn pointerAddrSpace(self: Type, builder: *const Builder) AddrSpace {
        switch (self) {
            .ptr => return .default,
            else => {
                const item = builder.type_items.items[@intFromEnum(self)];
                assert(item.tag == .pointer);
                return @enumFromInt(item.data);
            },
        }
    }

    pub fn isFunction(self: Type, builder: *const Builder) bool {
        return switch (self.tag(builder)) {
            .function, .vararg_function => true,
            else => false,
        };
    }

    pub fn functionKind(self: Type, builder: *const Builder) Type.Function.Kind {
        return switch (self.tag(builder)) {
            .function => .normal,
            .vararg_function => .vararg,
            else => unreachable,
        };
    }

    pub fn functionParameters(self: Type, builder: *const Builder) []const Type {
        const item = builder.type_items.items[@intFromEnum(self)];
        switch (item.tag) {
            .function,
            .vararg_function,
            => {
                var extra = builder.typeExtraDataTrail(Type.Function, item.data);
                return extra.trail.next(extra.data.params_len, Type, builder);
            },
            else => unreachable,
        }
    }

    pub fn functionReturn(self: Type, builder: *const Builder) Type {
        const item = builder.type_items.items[@intFromEnum(self)];
        switch (item.tag) {
            .function,
            .vararg_function,
            => return builder.typeExtraData(Type.Function, item.data).ret,
            else => unreachable,
        }
    }

    pub fn isVector(self: Type, builder: *const Builder) bool {
        return switch (self.tag(builder)) {
            .vector, .scalable_vector => true,
            else => false,
        };
    }

    pub fn vectorKind(self: Type, builder: *const Builder) Type.Vector.Kind {
        return switch (self.tag(builder)) {
            .vector => .normal,
            .scalable_vector => .scalable,
            else => unreachable,
        };
    }

    pub fn isStruct(self: Type, builder: *const Builder) bool {
        return switch (self.tag(builder)) {
            .structure, .packed_structure, .named_structure => true,
            else => false,
        };
    }

    pub fn structKind(self: Type, builder: *const Builder) Type.Structure.Kind {
        return switch (self.unnamedTag(builder)) {
            .structure => .normal,
            .packed_structure => .@"packed",
            else => unreachable,
        };
    }

    pub fn isAggregate(self: Type, builder: *const Builder) bool {
        return switch (self.tag(builder)) {
            .small_array, .array, .structure, .packed_structure, .named_structure => true,
            else => false,
        };
    }

    pub fn scalarBits(self: Type, builder: *const Builder) u24 {
        return switch (self) {
            .void, .label, .token, .metadata, .none, .x86_amx => unreachable,
            .i1 => 1,
            .i8 => 8,
            .half, .bfloat, .i16 => 16,
            .i29 => 29,
            .float, .i32 => 32,
            .double, .i64, .x86_mmx => 64,
            .x86_fp80, .i80 => 80,
            .fp128, .ppc_fp128, .i128 => 128,
            .ptr, .@"ptr addrspace(4)" => @panic("TODO: query data layout"),
            _ => {
                const item = builder.type_items.items[@intFromEnum(self)];
                return switch (item.tag) {
                    .simple,
                    .function,
                    .vararg_function,
                    => unreachable,
                    .integer => @intCast(item.data),
                    .pointer => @panic("TODO: query data layout"),
                    .target => unreachable,
                    .vector,
                    .scalable_vector,
                    => builder.typeExtraData(Type.Vector, item.data).child.scalarBits(builder),
                    .small_array,
                    .array,
                    .structure,
                    .packed_structure,
                    .named_structure,
                    => unreachable,
                };
            },
        };
    }

    pub fn childType(self: Type, builder: *const Builder) Type {
        const item = builder.type_items.items[@intFromEnum(self)];
        return switch (item.tag) {
            .vector,
            .scalable_vector,
            .small_array,
            => builder.typeExtraData(Type.Vector, item.data).child,
            .array => builder.typeExtraData(Type.Array, item.data).child,
            .named_structure => builder.typeExtraData(Type.NamedStructure, item.data).body,
            else => unreachable,
        };
    }

    pub fn scalarType(self: Type, builder: *const Builder) Type {
        if (self.isFloatingPoint()) return self;
        const item = builder.type_items.items[@intFromEnum(self)];
        return switch (item.tag) {
            .integer,
            .pointer,
            => self,
            .vector,
            .scalable_vector,
            => builder.typeExtraData(Type.Vector, item.data).child,
            else => unreachable,
        };
    }

    pub fn changeScalar(self: Type, scalar: Type, builder: *Builder) Allocator.Error!Type {
        try builder.ensureUnusedTypeCapacity(1, Type.Vector, 0);
        return self.changeScalarAssumeCapacity(scalar, builder);
    }

    pub fn changeScalarAssumeCapacity(self: Type, scalar: Type, builder: *Builder) Type {
        if (self.isFloatingPoint()) return scalar;
        const item = builder.type_items.items[@intFromEnum(self)];
        return switch (item.tag) {
            .integer,
            .pointer,
            => scalar,
            inline .vector,
            .scalable_vector,
            => |kind| builder.vectorTypeAssumeCapacity(
                switch (kind) {
                    .vector => .normal,
                    .scalable_vector => .scalable,
                    else => unreachable,
                },
                builder.typeExtraData(Type.Vector, item.data).len,
                scalar,
            ),
            else => unreachable,
        };
    }

    pub fn vectorLen(self: Type, builder: *const Builder) u32 {
        const item = builder.type_items.items[@intFromEnum(self)];
        return switch (item.tag) {
            .vector,
            .scalable_vector,
            => builder.typeExtraData(Type.Vector, item.data).len,
            else => unreachable,
        };
    }

    pub fn changeLength(self: Type, len: u32, builder: *Builder) Allocator.Error!Type {
        try builder.ensureUnusedTypeCapacity(1, Type.Array, 0);
        return self.changeLengthAssumeCapacity(len, builder);
    }

    pub fn changeLengthAssumeCapacity(self: Type, len: u32, builder: *Builder) Type {
        const item = builder.type_items.items[@intFromEnum(self)];
        return switch (item.tag) {
            inline .vector,
            .scalable_vector,
            => |kind| builder.vectorTypeAssumeCapacity(
                switch (kind) {
                    .vector => .normal,
                    .scalable_vector => .scalable,
                    else => unreachable,
                },
                len,
                builder.typeExtraData(Type.Vector, item.data).child,
            ),
            .small_array => builder.arrayTypeAssumeCapacity(
                len,
                builder.typeExtraData(Type.Vector, item.data).child,
            ),
            .array => builder.arrayTypeAssumeCapacity(
                len,
                builder.typeExtraData(Type.Array, item.data).child,
            ),
            else => unreachable,
        };
    }

    pub fn aggregateLen(self: Type, builder: *const Builder) usize {
        const item = builder.type_items.items[@intFromEnum(self)];
        return switch (item.tag) {
            .vector,
            .scalable_vector,
            .small_array,
            => builder.typeExtraData(Type.Vector, item.data).len,
            .array => @intCast(builder.typeExtraData(Type.Array, item.data).length()),
            .structure,
            .packed_structure,
            => builder.typeExtraData(Type.Structure, item.data).fields_len,
            .named_structure => builder.typeExtraData(Type.NamedStructure, item.data).body
                .aggregateLen(builder),
            else => unreachable,
        };
    }

    pub fn structFields(self: Type, builder: *const Builder) []const Type {
        const item = builder.type_items.items[@intFromEnum(self)];
        switch (item.tag) {
            .structure,
            .packed_structure,
            => {
                var extra = builder.typeExtraDataTrail(Type.Structure, item.data);
                return extra.trail.next(extra.data.fields_len, Type, builder);
            },
            .named_structure => return builder.typeExtraData(Type.NamedStructure, item.data).body
                .structFields(builder),
            else => unreachable,
        }
    }

    pub fn childTypeAt(self: Type, indices: []const u32, builder: *const Builder) Type {
        if (indices.len == 0) return self;
        const item = builder.type_items.items[@intFromEnum(self)];
        return switch (item.tag) {
            .small_array => builder.typeExtraData(Type.Vector, item.data).child
                .childTypeAt(indices[1..], builder),
            .array => builder.typeExtraData(Type.Array, item.data).child
                .childTypeAt(indices[1..], builder),
            .structure,
            .packed_structure,
            => {
                var extra = builder.typeExtraDataTrail(Type.Structure, item.data);
                const fields = extra.trail.next(extra.data.fields_len, Type, builder);
                return fields[indices[0]].childTypeAt(indices[1..], builder);
            },
            .named_structure => builder.typeExtraData(Type.NamedStructure, item.data).body
                .childTypeAt(indices, builder),
            else => unreachable,
        };
    }

    pub fn targetLayoutType(self: Type, builder: *const Builder) Type {
        _ = self;
        _ = builder;
        @panic("TODO: implement targetLayoutType");
    }

    pub fn isSized(self: Type, builder: *const Builder) Allocator.Error!bool {
        var visited: IsSizedVisited = .{};
        defer visited.deinit(builder.gpa);
        const result = try self.isSizedVisited(&visited, builder);
        return result;
    }

    const FormatData = struct {
        type: Type,
        builder: *const Builder,
    };
    fn format(
        data: FormatData,
        comptime fmt_str: []const u8,
        fmt_opts: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        assert(data.type != .none);
        if (comptime std.mem.eql(u8, fmt_str, "m")) {
            const item = data.builder.type_items.items[@intFromEnum(data.type)];
            switch (item.tag) {
                .simple => try writer.writeAll(switch (@as(Simple, @enumFromInt(item.data))) {
                    .void => "isVoid",
                    .half => "f16",
                    .bfloat => "bf16",
                    .float => "f32",
                    .double => "f64",
                    .fp128 => "f128",
                    .x86_fp80 => "f80",
                    .ppc_fp128 => "ppcf128",
                    .x86_amx => "x86amx",
                    .x86_mmx => "x86mmx",
                    .label, .token => unreachable,
                    .metadata => "Metadata",
                }),
                .function, .vararg_function => |kind| {
                    var extra = data.builder.typeExtraDataTrail(Type.Function, item.data);
                    const params = extra.trail.next(extra.data.params_len, Type, data.builder);
                    try writer.print("f_{m}", .{extra.data.ret.fmt(data.builder)});
                    for (params) |param| try writer.print("{m}", .{param.fmt(data.builder)});
                    switch (kind) {
                        .function => {},
                        .vararg_function => try writer.writeAll("vararg"),
                        else => unreachable,
                    }
                    try writer.writeByte('f');
                },
                .integer => try writer.print("i{d}", .{item.data}),
                .pointer => try writer.print("p{d}", .{item.data}),
                .target => {
                    var extra = data.builder.typeExtraDataTrail(Type.Target, item.data);
                    const types = extra.trail.next(extra.data.types_len, Type, data.builder);
                    const ints = extra.trail.next(extra.data.ints_len, u32, data.builder);
                    try writer.print("t{s}", .{extra.data.name.slice(data.builder).?});
                    for (types) |ty| try writer.print("_{m}", .{ty.fmt(data.builder)});
                    for (ints) |int| try writer.print("_{d}", .{int});
                    try writer.writeByte('t');
                },
                .vector, .scalable_vector => |kind| {
                    const extra = data.builder.typeExtraData(Type.Vector, item.data);
                    try writer.print("{s}v{d}{m}", .{
                        switch (kind) {
                            .vector => "",
                            .scalable_vector => "nx",
                            else => unreachable,
                        },
                        extra.len,
                        extra.child.fmt(data.builder),
                    });
                },
                inline .small_array, .array => |kind| {
                    const extra = data.builder.typeExtraData(switch (kind) {
                        .small_array => Type.Vector,
                        .array => Type.Array,
                        else => unreachable,
                    }, item.data);
                    try writer.print("a{d}{m}", .{ extra.length(), extra.child.fmt(data.builder) });
                },
                .structure, .packed_structure => {
                    var extra = data.builder.typeExtraDataTrail(Type.Structure, item.data);
                    const fields = extra.trail.next(extra.data.fields_len, Type, data.builder);
                    try writer.writeAll("sl_");
                    for (fields) |field| try writer.print("{m}", .{field.fmt(data.builder)});
                    try writer.writeByte('s');
                },
                .named_structure => {
                    const extra = data.builder.typeExtraData(Type.NamedStructure, item.data);
                    try writer.writeAll("s_");
                    if (extra.id.slice(data.builder)) |id| try writer.writeAll(id);
                },
            }
            return;
        }
        if (std.enums.tagName(Type, data.type)) |name| return writer.writeAll(name);
        const item = data.builder.type_items.items[@intFromEnum(data.type)];
        switch (item.tag) {
            .simple => unreachable,
            .function, .vararg_function => |kind| {
                var extra = data.builder.typeExtraDataTrail(Type.Function, item.data);
                const params = extra.trail.next(extra.data.params_len, Type, data.builder);
                if (!comptime std.mem.eql(u8, fmt_str, ">"))
                    try writer.print("{%} ", .{extra.data.ret.fmt(data.builder)});
                if (!comptime std.mem.eql(u8, fmt_str, "<")) {
                    try writer.writeByte('(');
                    for (params, 0..) |param, index| {
                        if (index > 0) try writer.writeAll(", ");
                        try writer.print("{%}", .{param.fmt(data.builder)});
                    }
                    switch (kind) {
                        .function => {},
                        .vararg_function => {
                            if (params.len > 0) try writer.writeAll(", ");
                            try writer.writeAll("...");
                        },
                        else => unreachable,
                    }
                    try writer.writeByte(')');
                }
            },
            .integer => try writer.print("i{d}", .{item.data}),
            .pointer => try writer.print("ptr{ }", .{@as(AddrSpace, @enumFromInt(item.data))}),
            .target => {
                var extra = data.builder.typeExtraDataTrail(Type.Target, item.data);
                const types = extra.trail.next(extra.data.types_len, Type, data.builder);
                const ints = extra.trail.next(extra.data.ints_len, u32, data.builder);
                try writer.print(
                    \\target({"}
                , .{extra.data.name.fmt(data.builder)});
                for (types) |ty| try writer.print(", {%}", .{ty.fmt(data.builder)});
                for (ints) |int| try writer.print(", {d}", .{int});
                try writer.writeByte(')');
            },
            .vector, .scalable_vector => |kind| {
                const extra = data.builder.typeExtraData(Type.Vector, item.data);
                try writer.print("<{s}{d} x {%}>", .{
                    switch (kind) {
                        .vector => "",
                        .scalable_vector => "vscale x ",
                        else => unreachable,
                    },
                    extra.len,
                    extra.child.fmt(data.builder),
                });
            },
            inline .small_array, .array => |kind| {
                const extra = data.builder.typeExtraData(switch (kind) {
                    .small_array => Type.Vector,
                    .array => Type.Array,
                    else => unreachable,
                }, item.data);
                try writer.print("[{d} x {%}]", .{ extra.length(), extra.child.fmt(data.builder) });
            },
            .structure, .packed_structure => |kind| {
                var extra = data.builder.typeExtraDataTrail(Type.Structure, item.data);
                const fields = extra.trail.next(extra.data.fields_len, Type, data.builder);
                switch (kind) {
                    .structure => {},
                    .packed_structure => try writer.writeByte('<'),
                    else => unreachable,
                }
                try writer.writeAll("{ ");
                for (fields, 0..) |field, index| {
                    if (index > 0) try writer.writeAll(", ");
                    try writer.print("{%}", .{field.fmt(data.builder)});
                }
                try writer.writeAll(" }");
                switch (kind) {
                    .structure => {},
                    .packed_structure => try writer.writeByte('>'),
                    else => unreachable,
                }
            },
            .named_structure => {
                const extra = data.builder.typeExtraData(Type.NamedStructure, item.data);
                if (comptime std.mem.eql(u8, fmt_str, "%")) try writer.print("%{}", .{
                    extra.id.fmt(data.builder),
                }) else switch (extra.body) {
                    .none => try writer.writeAll("opaque"),
                    else => try format(.{
                        .type = extra.body,
                        .builder = data.builder,
                    }, fmt_str, fmt_opts, writer),
                }
            },
        }
    }
    pub fn fmt(self: Type, builder: *const Builder) std.fmt.Formatter(format) {
        return .{ .data = .{ .type = self, .builder = builder } };
    }

    const IsSizedVisited = std.AutoHashMapUnmanaged(Type, void);
    fn isSizedVisited(
        self: Type,
        visited: *IsSizedVisited,
        builder: *const Builder,
    ) Allocator.Error!bool {
        return switch (self) {
            .void,
            .label,
            .token,
            .metadata,
            => false,
            .half,
            .bfloat,
            .float,
            .double,
            .fp128,
            .x86_fp80,
            .ppc_fp128,
            .x86_amx,
            .x86_mmx,
            .i1,
            .i8,
            .i16,
            .i29,
            .i32,
            .i64,
            .i80,
            .i128,
            .ptr,
            .@"ptr addrspace(4)",
            => true,
            .none => unreachable,
            _ => {
                const item = builder.type_items.items[@intFromEnum(self)];
                return switch (item.tag) {
                    .simple => unreachable,
                    .function,
                    .vararg_function,
                    => false,
                    .integer,
                    .pointer,
                    => true,
                    .target => self.targetLayoutType(builder).isSizedVisited(visited, builder),
                    .vector,
                    .scalable_vector,
                    .small_array,
                    => builder.typeExtraData(Type.Vector, item.data)
                        .child.isSizedVisited(visited, builder),
                    .array => builder.typeExtraData(Type.Array, item.data)
                        .child.isSizedVisited(visited, builder),
                    .structure,
                    .packed_structure,
                    => {
                        if (try visited.fetchPut(builder.gpa, self, {})) |_| return false;

                        var extra = builder.typeExtraDataTrail(Type.Structure, item.data);
                        const fields = extra.trail.next(extra.data.fields_len, Type, builder);
                        for (fields) |field| {
                            if (field.isVector(builder) and field.vectorKind(builder) == .scalable)
                                return false;
                            if (!try field.isSizedVisited(visited, builder))
                                return false;
                        }
                        return true;
                    },
                    .named_structure => {
                        const body = builder.typeExtraData(Type.NamedStructure, item.data).body;
                        return body != .none and try body.isSizedVisited(visited, builder);
                    },
                };
            },
        };
    }
};

pub const Attribute = union(Kind) {
    // Parameter Attributes
    zeroext,
    signext,
    inreg,
    byval: Type,
    byref: Type,
    preallocated: Type,
    inalloca: Type,
    sret: Type,
    elementtype: Type,
    @"align": Alignment,
    @"noalias",
    nocapture,
    nofree,
    nest,
    returned,
    nonnull,
    dereferenceable: u32,
    dereferenceable_or_null: u32,
    swiftself,
    swiftasync,
    swifterror,
    immarg,
    noundef,
    nofpclass: FpClass,
    alignstack: Alignment,
    allocalign,
    allocptr,
    readnone,
    readonly,
    writeonly,

    // Function Attributes
    //alignstack: Alignment,
    allockind: AllocKind,
    allocsize: AllocSize,
    alwaysinline,
    builtin,
    cold,
    convergent,
    disable_sanitizer_information,
    fn_ret_thunk_extern,
    hot,
    inlinehint,
    jumptable,
    memory: Memory,
    minsize,
    naked,
    nobuiltin,
    nocallback,
    noduplicate,
    //nofree,
    noimplicitfloat,
    @"noinline",
    nomerge,
    nonlazybind,
    noprofile,
    skipprofile,
    noredzone,
    noreturn,
    norecurse,
    willreturn,
    nosync,
    nounwind,
    nosanitize_bounds,
    nosanitize_coverage,
    null_pointer_is_valid,
    optforfuzzing,
    optnone,
    optsize,
    //preallocated: Type,
    returns_twice,
    safestack,
    sanitize_address,
    sanitize_memory,
    sanitize_thread,
    sanitize_hwaddress,
    sanitize_memtag,
    speculative_load_hardening,
    speculatable,
    ssp,
    sspstrong,
    sspreq,
    strictfp,
    uwtable: UwTable,
    nocf_check,
    shadowcallstack,
    mustprogress,
    vscale_range: VScaleRange,

    // Global Attributes
    no_sanitize_address,
    no_sanitize_hwaddress,
    //sanitize_memtag,
    sanitize_address_dyninit,

    string: struct { kind: String, value: String },
    none: noreturn,

    pub const Index = enum(u32) {
        _,

        pub fn getKind(self: Index, builder: *const Builder) Kind {
            return self.toStorage(builder).kind;
        }

        pub fn toAttribute(self: Index, builder: *const Builder) Attribute {
            @setEvalBranchQuota(2_000);
            const storage = self.toStorage(builder);
            if (storage.kind.toString()) |kind| return .{ .string = .{
                .kind = kind,
                .value = @enumFromInt(storage.value),
            } } else return switch (storage.kind) {
                inline .zeroext,
                .signext,
                .inreg,
                .byval,
                .byref,
                .preallocated,
                .inalloca,
                .sret,
                .elementtype,
                .@"align",
                .@"noalias",
                .nocapture,
                .nofree,
                .nest,
                .returned,
                .nonnull,
                .dereferenceable,
                .dereferenceable_or_null,
                .swiftself,
                .swiftasync,
                .swifterror,
                .immarg,
                .noundef,
                .nofpclass,
                .alignstack,
                .allocalign,
                .allocptr,
                .readnone,
                .readonly,
                .writeonly,
                //.alignstack,
                .allockind,
                .allocsize,
                .alwaysinline,
                .builtin,
                .cold,
                .convergent,
                .disable_sanitizer_information,
                .fn_ret_thunk_extern,
                .hot,
                .inlinehint,
                .jumptable,
                .memory,
                .minsize,
                .naked,
                .nobuiltin,
                .nocallback,
                .noduplicate,
                //.nofree,
                .noimplicitfloat,
                .@"noinline",
                .nomerge,
                .nonlazybind,
                .noprofile,
                .skipprofile,
                .noredzone,
                .noreturn,
                .norecurse,
                .willreturn,
                .nosync,
                .nounwind,
                .nosanitize_bounds,
                .nosanitize_coverage,
                .null_pointer_is_valid,
                .optforfuzzing,
                .optnone,
                .optsize,
                //.preallocated,
                .returns_twice,
                .safestack,
                .sanitize_address,
                .sanitize_memory,
                .sanitize_thread,
                .sanitize_hwaddress,
                .sanitize_memtag,
                .speculative_load_hardening,
                .speculatable,
                .ssp,
                .sspstrong,
                .sspreq,
                .strictfp,
                .uwtable,
                .nocf_check,
                .shadowcallstack,
                .mustprogress,
                .vscale_range,
                .no_sanitize_address,
                .no_sanitize_hwaddress,
                .sanitize_address_dyninit,
                => |kind| {
                    const field = comptime blk: {
                        @setEvalBranchQuota(10_000);
                        for (@typeInfo(Attribute).Union.fields) |field| {
                            if (std.mem.eql(u8, field.name, @tagName(kind))) break :blk field;
                        }
                        unreachable;
                    };
                    comptime assert(std.mem.eql(u8, @tagName(kind), field.name));
                    return @unionInit(Attribute, field.name, switch (field.type) {
                        void => {},
                        u32 => storage.value,
                        Alignment, String, Type, UwTable => @enumFromInt(storage.value),
                        AllocKind, AllocSize, FpClass, Memory, VScaleRange => @bitCast(storage.value),
                        else => @compileError("bad payload type: " ++ field.name ++ ": " ++
                            @typeName(field.type)),
                    });
                },
                .string, .none => unreachable,
                _ => unreachable,
            };
        }

        const FormatData = struct {
            attribute_index: Index,
            builder: *const Builder,
        };
        fn format(
            data: FormatData,
            comptime fmt_str: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            if (comptime std.mem.indexOfNone(u8, fmt_str, "\"#")) |_|
                @compileError("invalid format string: '" ++ fmt_str ++ "'");
            const attribute = data.attribute_index.toAttribute(data.builder);
            switch (attribute) {
                .zeroext,
                .signext,
                .inreg,
                .@"noalias",
                .nocapture,
                .nofree,
                .nest,
                .returned,
                .nonnull,
                .swiftself,
                .swiftasync,
                .swifterror,
                .immarg,
                .noundef,
                .allocalign,
                .allocptr,
                .readnone,
                .readonly,
                .writeonly,
                .alwaysinline,
                .builtin,
                .cold,
                .convergent,
                .disable_sanitizer_information,
                .fn_ret_thunk_extern,
                .hot,
                .inlinehint,
                .jumptable,
                .minsize,
                .naked,
                .nobuiltin,
                .nocallback,
                .noduplicate,
                .noimplicitfloat,
                .@"noinline",
                .nomerge,
                .nonlazybind,
                .noprofile,
                .skipprofile,
                .noredzone,
                .noreturn,
                .norecurse,
                .willreturn,
                .nosync,
                .nounwind,
                .nosanitize_bounds,
                .nosanitize_coverage,
                .null_pointer_is_valid,
                .optforfuzzing,
                .optnone,
                .optsize,
                .returns_twice,
                .safestack,
                .sanitize_address,
                .sanitize_memory,
                .sanitize_thread,
                .sanitize_hwaddress,
                .sanitize_memtag,
                .speculative_load_hardening,
                .speculatable,
                .ssp,
                .sspstrong,
                .sspreq,
                .strictfp,
                .nocf_check,
                .shadowcallstack,
                .mustprogress,
                .no_sanitize_address,
                .no_sanitize_hwaddress,
                .sanitize_address_dyninit,
                => try writer.print(" {s}", .{@tagName(attribute)}),
                .byval,
                .byref,
                .preallocated,
                .inalloca,
                .sret,
                .elementtype,
                => |ty| try writer.print(" {s}({%})", .{ @tagName(attribute), ty.fmt(data.builder) }),
                .@"align" => |alignment| try writer.print("{ }", .{alignment}),
                .dereferenceable,
                .dereferenceable_or_null,
                => |size| try writer.print(" {s}({d})", .{ @tagName(attribute), size }),
                .nofpclass => |fpclass| {
                    const Int = @typeInfo(FpClass).Struct.backing_integer.?;
                    try writer.print(" {s}(", .{@tagName(attribute)});
                    var any = false;
                    var remaining: Int = @bitCast(fpclass);
                    inline for (@typeInfo(FpClass).Struct.decls) |decl| {
                        const pattern: Int = @bitCast(@field(FpClass, decl.name));
                        if (remaining & pattern == pattern) {
                            if (!any) {
                                try writer.writeByte(' ');
                                any = true;
                            }
                            try writer.writeAll(decl.name);
                            remaining &= ~pattern;
                        }
                    }
                    try writer.writeByte(')');
                },
                .alignstack => |alignment| try writer.print(
                    if (comptime std.mem.indexOfScalar(u8, fmt_str, '#') != null)
                        " {s}={d}"
                    else
                        " {s}({d})",
                    .{ @tagName(attribute), alignment.toByteUnits() orelse return },
                ),
                .allockind => |allockind| {
                    try writer.print(" {s}(\"", .{@tagName(attribute)});
                    var any = false;
                    inline for (@typeInfo(AllocKind).Struct.fields) |field| {
                        if (comptime std.mem.eql(u8, field.name, "_")) continue;
                        if (@field(allockind, field.name)) {
                            if (!any) {
                                try writer.writeByte(',');
                                any = true;
                            }
                            try writer.writeAll(field.name);
                        }
                    }
                    try writer.writeAll("\")");
                },
                .allocsize => |allocsize| {
                    try writer.print(" {s}({d}", .{ @tagName(attribute), allocsize.elem_size });
                    if (allocsize.num_elems != AllocSize.none)
                        try writer.print(",{d}", .{allocsize.num_elems});
                    try writer.writeByte(')');
                },
                .memory => |memory| {
                    try writer.print(" {s}(", .{@tagName(attribute)});
                    var any = memory.other != .none or
                        (memory.argmem == .none and memory.inaccessiblemem == .none);
                    if (any) try writer.writeAll(@tagName(memory.other));
                    inline for (.{ "argmem", "inaccessiblemem" }) |kind| {
                        if (@field(memory, kind) != memory.other) {
                            if (any) try writer.writeAll(", ");
                            try writer.print("{s}: {s}", .{ kind, @tagName(@field(memory, kind)) });
                            any = true;
                        }
                    }
                    try writer.writeByte(')');
                },
                .uwtable => |uwtable| if (uwtable != .none) {
                    try writer.print(" {s}", .{@tagName(attribute)});
                    if (uwtable != UwTable.default) try writer.print("({s})", .{@tagName(uwtable)});
                },
                .vscale_range => |vscale_range| try writer.print(" {s}({d},{d})", .{
                    @tagName(attribute),
                    vscale_range.min.toByteUnits().?,
                    vscale_range.max.toByteUnits() orelse 0,
                }),
                .string => |string_attr| if (comptime std.mem.indexOfScalar(u8, fmt_str, '"') != null) {
                    try writer.print(" {\"}", .{string_attr.kind.fmt(data.builder)});
                    if (string_attr.value != .empty)
                        try writer.print("={\"}", .{string_attr.value.fmt(data.builder)});
                },
                .none => unreachable,
            }
        }
        pub fn fmt(self: Index, builder: *const Builder) std.fmt.Formatter(format) {
            return .{ .data = .{ .attribute_index = self, .builder = builder } };
        }

        fn toStorage(self: Index, builder: *const Builder) Storage {
            return builder.attributes.keys()[@intFromEnum(self)];
        }
    };

    pub const Kind = enum(u32) {
        // Parameter Attributes
        zeroext = 34,
        signext = 24,
        inreg = 5,
        byval = 3,
        byref = 69,
        preallocated = 65,
        inalloca = 38,
        sret = 29, // TODO: ?
        elementtype = 77,
        @"align" = 1,
        @"noalias" = 9,
        nocapture = 11,
        nofree = 62,
        nest = 8,
        returned = 22,
        nonnull = 39,
        dereferenceable = 41,
        dereferenceable_or_null = 42,
        swiftself = 46,
        swiftasync = 75,
        swifterror = 47,
        immarg = 60,
        noundef = 68,
        nofpclass = 87,
        alignstack = 25,
        allocalign = 80,
        allocptr = 81,
        readnone = 20,
        readonly = 21,
        writeonly = 52,

        // Function Attributes
        //alignstack,
        allockind = 82,
        allocsize = 51,
        alwaysinline = 2,
        builtin = 35,
        cold = 36,
        convergent = 43,
        disable_sanitizer_information = 78,
        fn_ret_thunk_extern = 84,
        hot = 72,
        inlinehint = 4,
        jumptable = 40,
        memory = 86,
        minsize = 6,
        naked = 7,
        nobuiltin = 10,
        nocallback = 71,
        noduplicate = 12,
        //nofree,
        noimplicitfloat = 13,
        @"noinline" = 14,
        nomerge = 66,
        nonlazybind = 15,
        noprofile = 73,
        skipprofile = 85,
        noredzone = 16,
        noreturn = 17,
        norecurse = 48,
        willreturn = 61,
        nosync = 63,
        nounwind = 18,
        nosanitize_bounds = 79,
        nosanitize_coverage = 76,
        null_pointer_is_valid = 67,
        optforfuzzing = 57,
        optnone = 37,
        optsize = 19,
        //preallocated,
        returns_twice = 23,
        safestack = 44,
        sanitize_address = 30,
        sanitize_memory = 32,
        sanitize_thread = 31,
        sanitize_hwaddress = 55,
        sanitize_memtag = 64,
        speculative_load_hardening = 59,
        speculatable = 53,
        ssp = 26,
        sspstrong = 28,
        sspreq = 27,
        strictfp = 54,
        uwtable = 33,
        nocf_check = 56,
        shadowcallstack = 58,
        mustprogress = 70,
        vscale_range = 74,

        // Global Attributes
        no_sanitize_address = 100,
        no_sanitize_hwaddress = 101,
        //sanitize_memtag,
        sanitize_address_dyninit = 102,

        string = std.math.maxInt(u31),
        none = std.math.maxInt(u32),
        _,

        pub const len = @typeInfo(Kind).Enum.fields.len - 2;

        pub fn fromString(str: String) Kind {
            assert(!str.isAnon());
            const kind: Kind = @enumFromInt(@intFromEnum(str));
            assert(kind != .none);
            return kind;
        }

        fn toString(self: Kind) ?String {
            assert(self != .none);
            const str: String = @enumFromInt(@intFromEnum(self));
            return if (str.isAnon()) null else str;
        }
    };

    pub const FpClass = packed struct(u32) {
        signaling_nan: bool = false,
        quiet_nan: bool = false,
        negative_infinity: bool = false,
        negative_normal: bool = false,
        negative_subnormal: bool = false,
        negative_zero: bool = false,
        positive_zero: bool = false,
        positive_subnormal: bool = false,
        positive_normal: bool = false,
        positive_infinity: bool = false,
        _: u22 = 0,

        pub const all = FpClass{
            .signaling_nan = true,
            .quiet_nan = true,
            .negative_infinity = true,
            .negative_normal = true,
            .negative_subnormal = true,
            .negative_zero = true,
            .positive_zero = true,
            .positive_subnormal = true,
            .positive_normal = true,
            .positive_infinity = true,
        };

        pub const nan = FpClass{ .signaling_nan = true, .quiet_nan = true };
        pub const snan = FpClass{ .signaling_nan = true };
        pub const qnan = FpClass{ .quiet_nan = true };

        pub const inf = FpClass{ .negative_infinity = true, .positive_infinity = true };
        pub const ninf = FpClass{ .negative_infinity = true };
        pub const pinf = FpClass{ .positive_infinity = true };

        pub const zero = FpClass{ .positive_zero = true, .negative_zero = true };
        pub const nzero = FpClass{ .negative_zero = true };
        pub const pzero = FpClass{ .positive_zero = true };

        pub const sub = FpClass{ .positive_subnormal = true, .negative_subnormal = true };
        pub const nsub = FpClass{ .negative_subnormal = true };
        pub const psub = FpClass{ .positive_subnormal = true };

        pub const norm = FpClass{ .positive_normal = true, .negative_normal = true };
        pub const nnorm = FpClass{ .negative_normal = true };
        pub const pnorm = FpClass{ .positive_normal = true };
    };

    pub const AllocKind = packed struct(u32) {
        alloc: bool,
        realloc: bool,
        free: bool,
        uninitialized: bool,
        zeroed: bool,
        aligned: bool,
        _: u26 = 0,
    };

    pub const AllocSize = packed struct(u32) {
        elem_size: u16,
        num_elems: u16,

        pub const none = std.math.maxInt(u16);

        fn toLlvm(self: AllocSize) packed struct(u64) { num_elems: u32, elem_size: u32 } {
            return .{ .num_elems = switch (self.num_elems) {
                else => self.num_elems,
                none => std.math.maxInt(u32),
            }, .elem_size = self.elem_size };
        }
    };

    pub const Memory = packed struct(u32) {
        argmem: Effect = .none,
        inaccessiblemem: Effect = .none,
        other: Effect = .none,
        _: u26 = 0,

        pub const Effect = enum(u2) { none, read, write, readwrite };

        fn all(effect: Effect) Memory {
            return .{ .argmem = effect, .inaccessiblemem = effect, .other = effect };
        }
    };

    pub const UwTable = enum(u32) {
        none,
        sync,
        @"async",

        pub const default = UwTable.@"async";
    };

    pub const VScaleRange = packed struct(u32) {
        min: Alignment,
        max: Alignment,
        _: u20 = 0,

        fn toLlvm(self: VScaleRange) packed struct(u64) { max: u32, min: u32 } {
            return .{
                .max = @intCast(self.max.toByteUnits() orelse 0),
                .min = @intCast(self.min.toByteUnits().?),
            };
        }
    };

    pub fn getKind(self: Attribute) Kind {
        return switch (self) {
            else => self,
            .string => |string_attr| Kind.fromString(string_attr.kind),
        };
    }

    const Storage = extern struct {
        kind: Kind,
        value: u32,
    };

    fn toStorage(self: Attribute) Storage {
        return switch (self) {
            inline else => |value, tag| .{ .kind = @as(Kind, self), .value = switch (@TypeOf(value)) {
                void => 0,
                u32 => value,
                Alignment, String, Type, UwTable => @intFromEnum(value),
                AllocKind, AllocSize, FpClass, Memory, VScaleRange => @bitCast(value),
                else => @compileError("bad payload type: " ++ @tagName(tag) ++ @typeName(@TypeOf(value))),
            } },
            .string => |string_attr| .{
                .kind = Kind.fromString(string_attr.kind),
                .value = @intFromEnum(string_attr.value),
            },
            .none => unreachable,
        };
    }
};

pub const Attributes = enum(u32) {
    none,
    _,

    pub fn slice(self: Attributes, builder: *const Builder) []const Attribute.Index {
        const start = builder.attributes_indices.items[@intFromEnum(self)];
        const end = builder.attributes_indices.items[@intFromEnum(self) + 1];
        return @ptrCast(builder.attributes_extra.items[start..end]);
    }

    const FormatData = struct {
        attributes: Attributes,
        builder: *const Builder,
    };
    fn format(
        data: FormatData,
        comptime fmt_str: []const u8,
        fmt_opts: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        for (data.attributes.slice(data.builder)) |attribute_index| try Attribute.Index.format(.{
            .attribute_index = attribute_index,
            .builder = data.builder,
        }, fmt_str, fmt_opts, writer);
    }
    pub fn fmt(self: Attributes, builder: *const Builder) std.fmt.Formatter(format) {
        return .{ .data = .{ .attributes = self, .builder = builder } };
    }
};

pub const FunctionAttributes = enum(u32) {
    none,
    _,

    const function_index = 0;
    const return_index = 1;
    const params_index = 2;

    pub const Wip = struct {
        maps: Maps = .{},

        const Map = std.AutoArrayHashMapUnmanaged(Attribute.Kind, Attribute.Index);
        const Maps = std.ArrayListUnmanaged(Map);

        pub fn deinit(self: *Wip, builder: *const Builder) void {
            for (self.maps.items) |*map| map.deinit(builder.gpa);
            self.maps.deinit(builder.gpa);
            self.* = undefined;
        }

        pub fn addFnAttr(self: *Wip, attribute: Attribute, builder: *Builder) Allocator.Error!void {
            try self.addAttr(function_index, attribute, builder);
        }

        pub fn addFnAttrIndex(
            self: *Wip,
            attribute_index: Attribute.Index,
            builder: *const Builder,
        ) Allocator.Error!void {
            try self.addAttrIndex(function_index, attribute_index, builder);
        }

        pub fn removeFnAttr(self: *Wip, attribute_kind: Attribute.Kind) Allocator.Error!bool {
            return self.removeAttr(function_index, attribute_kind);
        }

        pub fn addRetAttr(self: *Wip, attribute: Attribute, builder: *Builder) Allocator.Error!void {
            try self.addAttr(return_index, attribute, builder);
        }

        pub fn addRetAttrIndex(
            self: *Wip,
            attribute_index: Attribute.Index,
            builder: *const Builder,
        ) Allocator.Error!void {
            try self.addAttrIndex(return_index, attribute_index, builder);
        }

        pub fn removeRetAttr(self: *Wip, attribute_kind: Attribute.Kind) Allocator.Error!bool {
            return self.removeAttr(return_index, attribute_kind);
        }

        pub fn addParamAttr(
            self: *Wip,
            param_index: usize,
            attribute: Attribute,
            builder: *Builder,
        ) Allocator.Error!void {
            try self.addAttr(params_index + param_index, attribute, builder);
        }

        pub fn addParamAttrIndex(
            self: *Wip,
            param_index: usize,
            attribute_index: Attribute.Index,
            builder: *const Builder,
        ) Allocator.Error!void {
            try self.addAttrIndex(params_index + param_index, attribute_index, builder);
        }

        pub fn removeParamAttr(
            self: *Wip,
            param_index: usize,
            attribute_kind: Attribute.Kind,
        ) Allocator.Error!bool {
            return self.removeAttr(params_index + param_index, attribute_kind);
        }

        pub fn finish(self: *const Wip, builder: *Builder) Allocator.Error!FunctionAttributes {
            const attributes = try builder.gpa.alloc(Attributes, self.maps.items.len);
            defer builder.gpa.free(attributes);
            for (attributes, self.maps.items) |*attribute, map|
                attribute.* = try builder.attrs(map.values());
            return builder.fnAttrs(attributes);
        }

        fn addAttr(
            self: *Wip,
            index: usize,
            attribute: Attribute,
            builder: *Builder,
        ) Allocator.Error!void {
            const map = try self.getOrPutMap(builder.gpa, index);
            try map.put(builder.gpa, attribute.getKind(), try builder.attr(attribute));
        }

        fn addAttrIndex(
            self: *Wip,
            index: usize,
            attribute_index: Attribute.Index,
            builder: *const Builder,
        ) Allocator.Error!void {
            const map = try self.getOrPutMap(builder.gpa, index);
            try map.put(builder.gpa, attribute_index.getKind(builder), attribute_index);
        }

        fn removeAttr(self: *Wip, index: usize, attribute_kind: Attribute.Kind) Allocator.Error!bool {
            const map = self.getMap(index) orelse return false;
            return map.swapRemove(attribute_kind);
        }

        fn getOrPutMap(self: *Wip, allocator: Allocator, index: usize) Allocator.Error!*Map {
            if (index >= self.maps.items.len)
                try self.maps.appendNTimes(allocator, .{}, index + 1 - self.maps.items.len);
            return &self.maps.items[index];
        }

        fn getMap(self: *Wip, index: usize) ?*Map {
            return if (index >= self.maps.items.len) null else &self.maps.items[index];
        }

        fn ensureTotalLength(self: *Wip, new_len: usize) Allocator.Error!void {
            try self.maps.appendNTimes(
                .{},
                std.math.sub(usize, new_len, self.maps.items.len) catch return,
            );
        }
    };

    pub fn func(self: FunctionAttributes, builder: *const Builder) Attributes {
        return self.get(function_index, builder);
    }

    pub fn ret(self: FunctionAttributes, builder: *const Builder) Attributes {
        return self.get(return_index, builder);
    }

    pub fn param(self: FunctionAttributes, param_index: usize, builder: *const Builder) Attributes {
        return self.get(params_index + param_index, builder);
    }

    pub fn toWip(self: FunctionAttributes, builder: *const Builder) Allocator.Error!Wip {
        var wip: Wip = .{};
        errdefer wip.deinit(builder);
        const attributes_slice = self.slice(builder);
        try wip.maps.ensureTotalCapacityPrecise(builder.gpa, attributes_slice.len);
        for (attributes_slice) |attributes| {
            const map = wip.maps.addOneAssumeCapacity();
            map.* = .{};
            const attribute_slice = attributes.slice(builder);
            try map.ensureTotalCapacity(builder.gpa, attribute_slice.len);
            for (attributes.slice(builder)) |attribute|
                map.putAssumeCapacityNoClobber(attribute.getKind(builder), attribute);
        }
        return wip;
    }

    fn get(self: FunctionAttributes, index: usize, builder: *const Builder) Attributes {
        const attribute_slice = self.slice(builder);
        return if (index < attribute_slice.len) attribute_slice[index] else .none;
    }

    fn slice(self: FunctionAttributes, builder: *const Builder) []const Attributes {
        const start = builder.attributes_indices.items[@intFromEnum(self)];
        const end = builder.attributes_indices.items[@intFromEnum(self) + 1];
        return @ptrCast(builder.attributes_extra.items[start..end]);
    }
};

pub const Linkage = enum(u4) {
    private = 9,
    internal = 3,
    weak = 1,
    weak_odr = 10,
    linkonce = 4,
    linkonce_odr = 11,
    available_externally = 12,
    appending = 2,
    common = 8,
    extern_weak = 7,
    external = 0,

    pub fn format(
        self: Linkage,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .external) try writer.print(" {s}", .{@tagName(self)});
    }

    fn formatOptional(
        data: ?Linkage,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (data) |linkage| try writer.print(" {s}", .{@tagName(linkage)});
    }
    pub fn fmtOptional(self: ?Linkage) std.fmt.Formatter(formatOptional) {
        return .{ .data = self };
    }
};

pub const Preemption = enum {
    dso_preemptable,
    dso_local,
    implicit_dso_local,

    pub fn format(
        self: Preemption,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self == .dso_local) try writer.print(" {s}", .{@tagName(self)});
    }
};

pub const Visibility = enum(u2) {
    default = 0,
    hidden = 1,
    protected = 2,

    pub fn format(
        self: Visibility,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .default) try writer.print(" {s}", .{@tagName(self)});
    }
};

pub const DllStorageClass = enum(u2) {
    default = 0,
    dllimport = 1,
    dllexport = 2,

    pub fn format(
        self: DllStorageClass,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .default) try writer.print(" {s}", .{@tagName(self)});
    }
};

pub const ThreadLocal = enum(u3) {
    default = 0,
    generaldynamic = 1,
    localdynamic = 2,
    initialexec = 3,
    localexec = 4,

    pub fn format(
        self: ThreadLocal,
        comptime prefix: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self == .default) return;
        try writer.print("{s}thread_local", .{prefix});
        if (self != .generaldynamic) try writer.print("({s})", .{@tagName(self)});
    }
};

pub const Mutability = enum { global, constant };

pub const UnnamedAddr = enum(u2) {
    default = 0,
    unnamed_addr = 1,
    local_unnamed_addr = 2,

    pub fn format(
        self: UnnamedAddr,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .default) try writer.print(" {s}", .{@tagName(self)});
    }
};

pub const AddrSpace = enum(u24) {
    default,
    _,

    // See llvm/lib/Target/X86/X86.h
    pub const x86 = struct {
        pub const gs: AddrSpace = @enumFromInt(256);
        pub const fs: AddrSpace = @enumFromInt(257);
        pub const ss: AddrSpace = @enumFromInt(258);

        pub const ptr32_sptr: AddrSpace = @enumFromInt(270);
        pub const ptr32_uptr: AddrSpace = @enumFromInt(271);
        pub const ptr64: AddrSpace = @enumFromInt(272);
    };
    pub const x86_64 = x86;

    // See llvm/lib/Target/AVR/AVR.h
    pub const avr = struct {
        pub const data: AddrSpace = @enumFromInt(0);
        pub const program: AddrSpace = @enumFromInt(1);
        pub const program1: AddrSpace = @enumFromInt(2);
        pub const program2: AddrSpace = @enumFromInt(3);
        pub const program3: AddrSpace = @enumFromInt(4);
        pub const program4: AddrSpace = @enumFromInt(5);
        pub const program5: AddrSpace = @enumFromInt(6);
    };

    // See llvm/lib/Target/NVPTX/NVPTX.h
    pub const nvptx = struct {
        pub const generic: AddrSpace = @enumFromInt(0);
        pub const global: AddrSpace = @enumFromInt(1);
        pub const constant: AddrSpace = @enumFromInt(2);
        pub const shared: AddrSpace = @enumFromInt(3);
        pub const param: AddrSpace = @enumFromInt(4);
        pub const local: AddrSpace = @enumFromInt(5);
    };

    // See llvm/lib/Target/AMDGPU/AMDGPU.h
    pub const amdgpu = struct {
        pub const flat: AddrSpace = @enumFromInt(0);
        pub const global: AddrSpace = @enumFromInt(1);
        pub const region: AddrSpace = @enumFromInt(2);
        pub const local: AddrSpace = @enumFromInt(3);
        pub const constant: AddrSpace = @enumFromInt(4);
        pub const private: AddrSpace = @enumFromInt(5);
        pub const constant_32bit: AddrSpace = @enumFromInt(6);
        pub const buffer_fat_pointer: AddrSpace = @enumFromInt(7);
        pub const buffer_resource: AddrSpace = @enumFromInt(8);
        pub const param_d: AddrSpace = @enumFromInt(6);
        pub const param_i: AddrSpace = @enumFromInt(7);
        pub const constant_buffer_0: AddrSpace = @enumFromInt(8);
        pub const constant_buffer_1: AddrSpace = @enumFromInt(9);
        pub const constant_buffer_2: AddrSpace = @enumFromInt(10);
        pub const constant_buffer_3: AddrSpace = @enumFromInt(11);
        pub const constant_buffer_4: AddrSpace = @enumFromInt(12);
        pub const constant_buffer_5: AddrSpace = @enumFromInt(13);
        pub const constant_buffer_6: AddrSpace = @enumFromInt(14);
        pub const constant_buffer_7: AddrSpace = @enumFromInt(15);
        pub const constant_buffer_8: AddrSpace = @enumFromInt(16);
        pub const constant_buffer_9: AddrSpace = @enumFromInt(17);
        pub const constant_buffer_10: AddrSpace = @enumFromInt(18);
        pub const constant_buffer_11: AddrSpace = @enumFromInt(19);
        pub const constant_buffer_12: AddrSpace = @enumFromInt(20);
        pub const constant_buffer_13: AddrSpace = @enumFromInt(21);
        pub const constant_buffer_14: AddrSpace = @enumFromInt(22);
        pub const constant_buffer_15: AddrSpace = @enumFromInt(23);
    };

    // See llvm/include/llvm/CodeGen/WasmAddressSpaces.h
    pub const wasm = struct {
        pub const variable: AddrSpace = @enumFromInt(1);
        pub const externref: AddrSpace = @enumFromInt(10);
        pub const funcref: AddrSpace = @enumFromInt(20);
    };

    pub fn format(
        self: AddrSpace,
        comptime prefix: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .default) try writer.print("{s}addrspace({d})", .{ prefix, @intFromEnum(self) });
    }
};

pub const ExternallyInitialized = enum {
    default,
    externally_initialized,

    pub fn format(
        self: ExternallyInitialized,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self == .default) return;
        try writer.writeByte(' ');
        try writer.writeAll(@tagName(self));
    }
};

pub const Alignment = enum(u6) {
    default = std.math.maxInt(u6),
    _,

    pub fn fromByteUnits(bytes: u64) Alignment {
        if (bytes == 0) return .default;
        assert(std.math.isPowerOfTwo(bytes));
        assert(bytes <= 1 << 32);
        return @enumFromInt(@ctz(bytes));
    }

    pub fn toByteUnits(self: Alignment) ?u64 {
        return if (self == .default) null else @as(u64, 1) << @intFromEnum(self);
    }

    pub fn toLlvm(self: Alignment) u6 {
        return if (self == .default) 0 else (@intFromEnum(self) + 1);
    }

    pub fn format(
        self: Alignment,
        comptime prefix: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        try writer.print("{s}align {d}", .{ prefix, self.toByteUnits() orelse return });
    }
};

pub const CallConv = enum(u10) {
    ccc,

    fastcc = 8,
    coldcc,
    ghccc,

    webkit_jscc = 12,
    anyregcc,
    preserve_mostcc,
    preserve_allcc,
    swiftcc,
    cxx_fast_tlscc,
    tailcc,
    cfguard_checkcc,
    swifttailcc,

    x86_stdcallcc = 64,
    x86_fastcallcc,
    arm_apcscc,
    arm_aapcscc,
    arm_aapcs_vfpcc,
    msp430_intrcc,
    x86_thiscallcc,
    ptx_kernel,
    ptx_device,

    spir_func = 75,
    spir_kernel,
    intel_ocl_bicc,
    x86_64_sysvcc,
    win64cc,
    x86_vectorcallcc,
    hhvmcc,
    hhvm_ccc,
    x86_intrcc,
    avr_intrcc,
    avr_signalcc,

    amdgpu_vs = 87,
    amdgpu_gs,
    amdgpu_ps,
    amdgpu_cs,
    amdgpu_kernel,
    x86_regcallcc,
    amdgpu_hs,

    amdgpu_ls = 95,
    amdgpu_es,
    aarch64_vector_pcs,
    aarch64_sve_vector_pcs,

    amdgpu_gfx = 100,

    aarch64_sme_preservemost_from_x0 = 102,
    aarch64_sme_preservemost_from_x2,

    _,

    pub const default = CallConv.ccc;

    pub fn format(
        self: CallConv,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        switch (self) {
            default => {},
            .fastcc,
            .coldcc,
            .ghccc,
            .webkit_jscc,
            .anyregcc,
            .preserve_mostcc,
            .preserve_allcc,
            .swiftcc,
            .cxx_fast_tlscc,
            .tailcc,
            .cfguard_checkcc,
            .swifttailcc,
            .x86_stdcallcc,
            .x86_fastcallcc,
            .arm_apcscc,
            .arm_aapcscc,
            .arm_aapcs_vfpcc,
            .msp430_intrcc,
            .x86_thiscallcc,
            .ptx_kernel,
            .ptx_device,
            .spir_func,
            .spir_kernel,
            .intel_ocl_bicc,
            .x86_64_sysvcc,
            .win64cc,
            .x86_vectorcallcc,
            .hhvmcc,
            .hhvm_ccc,
            .x86_intrcc,
            .avr_intrcc,
            .avr_signalcc,
            .amdgpu_vs,
            .amdgpu_gs,
            .amdgpu_ps,
            .amdgpu_cs,
            .amdgpu_kernel,
            .x86_regcallcc,
            .amdgpu_hs,
            .amdgpu_ls,
            .amdgpu_es,
            .aarch64_vector_pcs,
            .aarch64_sve_vector_pcs,
            .amdgpu_gfx,
            .aarch64_sme_preservemost_from_x0,
            .aarch64_sme_preservemost_from_x2,
            => try writer.print(" {s}", .{@tagName(self)}),
            _ => try writer.print(" cc{d}", .{@intFromEnum(self)}),
        }
    }
};

pub const StrtabString = enum(u32) {
    none = std.math.maxInt(u31),
    empty,
    _,

    pub fn isAnon(self: StrtabString) bool {
        assert(self != .none);
        return self.toIndex() == null;
    }

    pub fn slice(self: StrtabString, builder: *const Builder) ?[]const u8 {
        const index = self.toIndex() orelse return null;
        const start = builder.strtab_string_indices.items[index];
        const end = builder.strtab_string_indices.items[index + 1];
        return builder.strtab_string_bytes.items[start..end];
    }

    const FormatData = struct {
        string: StrtabString,
        builder: *const Builder,
    };
    fn format(
        data: FormatData,
        comptime fmt_str: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (comptime std.mem.indexOfNone(u8, fmt_str, "\"r")) |_|
            @compileError("invalid format string: '" ++ fmt_str ++ "'");
        assert(data.string != .none);
        const string_slice = data.string.slice(data.builder) orelse
            return writer.print("{d}", .{@intFromEnum(data.string)});
        if (comptime std.mem.indexOfScalar(u8, fmt_str, 'r')) |_|
            return writer.writeAll(string_slice);
        try printEscapedString(
            string_slice,
            if (comptime std.mem.indexOfScalar(u8, fmt_str, '"')) |_|
                .always_quote
            else
                .quote_unless_valid_identifier,
            writer,
        );
    }
    pub fn fmt(self: StrtabString, builder: *const Builder) std.fmt.Formatter(format) {
        return .{ .data = .{ .string = self, .builder = builder } };
    }

    fn fromIndex(index: ?usize) StrtabString {
        return @enumFromInt(@as(u32, @intCast((index orelse return .none) +
            @intFromEnum(StrtabString.empty))));
    }

    fn toIndex(self: StrtabString) ?usize {
        return std.math.sub(u32, @intFromEnum(self), @intFromEnum(StrtabString.empty)) catch null;
    }

    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: Adapter, key: []const u8) u32 {
            return @truncate(std.hash.Wyhash.hash(0, key));
        }
        pub fn eql(ctx: Adapter, lhs_key: []const u8, _: void, rhs_index: usize) bool {
            return std.mem.eql(u8, lhs_key, StrtabString.fromIndex(rhs_index).slice(ctx.builder).?);
        }
    };
};

pub fn strtabString(self: *Builder, bytes: []const u8) Allocator.Error!StrtabString {
    try self.strtab_string_bytes.ensureUnusedCapacity(self.gpa, bytes.len);
    try self.strtab_string_indices.ensureUnusedCapacity(self.gpa, 1);
    try self.strtab_string_map.ensureUnusedCapacity(self.gpa, 1);

    const gop = self.strtab_string_map.getOrPutAssumeCapacityAdapted(bytes, StrtabString.Adapter{ .builder = self });
    if (!gop.found_existing) {
        self.strtab_string_bytes.appendSliceAssumeCapacity(bytes);
        self.strtab_string_indices.appendAssumeCapacity(@intCast(self.strtab_string_bytes.items.len));
    }
    return StrtabString.fromIndex(gop.index);
}

pub fn strtabStringIfExists(self: *const Builder, bytes: []const u8) ?StrtabString {
    return StrtabString.fromIndex(
        self.strtab_string_map.getIndexAdapted(bytes, StrtabString.Adapter{ .builder = self }) orelse return null,
    );
}

pub fn strtabStringFmt(self: *Builder, comptime fmt_str: []const u8, fmt_args: anytype) Allocator.Error!StrtabString {
    try self.strtab_string_map.ensureUnusedCapacity(self.gpa, 1);
    try self.strtab_string_bytes.ensureUnusedCapacity(self.gpa, @intCast(std.fmt.count(fmt_str, fmt_args)));
    try self.strtab_string_indices.ensureUnusedCapacity(self.gpa, 1);
    return self.strtabStringFmtAssumeCapacity(fmt_str, fmt_args);
}

pub fn strtabStringFmtAssumeCapacity(self: *Builder, comptime fmt_str: []const u8, fmt_args: anytype) StrtabString {
    self.strtab_string_bytes.writer(undefined).print(fmt_str, fmt_args) catch unreachable;
    return self.trailingStrtabStringAssumeCapacity();
}

pub fn trailingStrtabString(self: *Builder) Allocator.Error!StrtabString {
    try self.strtab_string_indices.ensureUnusedCapacity(self.gpa, 1);
    try self.strtab_string_map.ensureUnusedCapacity(self.gpa, 1);
    return self.trailingStrtabStringAssumeCapacity();
}

pub fn trailingStrtabStringAssumeCapacity(self: *Builder) StrtabString {
    const start = self.strtab_string_indices.getLast();
    const bytes: []const u8 = self.strtab_string_bytes.items[start..];
    const gop = self.strtab_string_map.getOrPutAssumeCapacityAdapted(bytes, StrtabString.Adapter{ .builder = self });
    if (gop.found_existing) {
        self.strtab_string_bytes.shrinkRetainingCapacity(start);
    } else {
        self.strtab_string_indices.appendAssumeCapacity(@intCast(self.strtab_string_bytes.items.len));
    }
    return StrtabString.fromIndex(gop.index);
}

pub const Global = struct {
    linkage: Linkage = .external,
    preemption: Preemption = .dso_preemptable,
    visibility: Visibility = .default,
    dll_storage_class: DllStorageClass = .default,
    unnamed_addr: UnnamedAddr = .default,
    addr_space: AddrSpace = .default,
    externally_initialized: ExternallyInitialized = .default,
    type: Type,
    partition: String = .none,
    dbg: Metadata = .none,
    kind: union(enum) {
        alias: Alias.Index,
        variable: Variable.Index,
        function: Function.Index,
        replaced: Global.Index,
    },

    pub const Index = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn unwrap(self: Index, builder: *const Builder) Index {
            var cur = self;
            while (true) {
                const replacement = cur.getReplacement(builder);
                if (replacement == .none) return cur;
                cur = replacement;
            }
        }

        pub fn eql(self: Index, other: Index, builder: *const Builder) bool {
            return self.unwrap(builder) == other.unwrap(builder);
        }

        pub fn ptr(self: Index, builder: *Builder) *Global {
            return &builder.globals.values()[@intFromEnum(self.unwrap(builder))];
        }

        pub fn ptrConst(self: Index, builder: *const Builder) *const Global {
            return &builder.globals.values()[@intFromEnum(self.unwrap(builder))];
        }

        pub fn name(self: Index, builder: *const Builder) StrtabString {
            return builder.globals.keys()[@intFromEnum(self.unwrap(builder))];
        }

        pub fn strtab(self: Index, builder: *const Builder) struct {
            offset: u32,
            size: u32,
        } {
            const name_index = self.name(builder).toIndex() orelse return .{
                .offset = 0,
                .size = 0,
            };

            return .{
                .offset = builder.strtab_string_indices.items[name_index],
                .size = builder.strtab_string_indices.items[name_index + 1] -
                    builder.strtab_string_indices.items[name_index],
            };
        }

        pub fn typeOf(self: Index, builder: *const Builder) Type {
            return self.ptrConst(builder).type;
        }

        pub fn toConst(self: Index) Constant {
            return @enumFromInt(@intFromEnum(Constant.first_global) + @intFromEnum(self));
        }

        pub fn setLinkage(self: Index, linkage: Linkage, builder: *Builder) void {
            self.ptr(builder).linkage = linkage;
            self.updateDsoLocal(builder);
        }

        pub fn setVisibility(self: Index, visibility: Visibility, builder: *Builder) void {
            self.ptr(builder).visibility = visibility;
            self.updateDsoLocal(builder);
        }

        pub fn setDllStorageClass(self: Index, class: DllStorageClass, builder: *Builder) void {
            self.ptr(builder).dll_storage_class = class;
        }

        pub fn setUnnamedAddr(self: Index, unnamed_addr: UnnamedAddr, builder: *Builder) void {
            self.ptr(builder).unnamed_addr = unnamed_addr;
        }

        pub fn setDebugMetadata(self: Index, dbg: Metadata, builder: *Builder) void {
            self.ptr(builder).dbg = dbg;
        }

        const FormatData = struct {
            global: Index,
            builder: *const Builder,
        };
        fn format(
            data: FormatData,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            try writer.print("@{}", .{
                data.global.unwrap(data.builder).name(data.builder).fmt(data.builder),
            });
        }
        pub fn fmt(self: Index, builder: *const Builder) std.fmt.Formatter(format) {
            return .{ .data = .{ .global = self, .builder = builder } };
        }

        pub fn rename(self: Index, new_name: StrtabString, builder: *Builder) Allocator.Error!void {
            try builder.ensureUnusedGlobalCapacity(new_name);
            self.renameAssumeCapacity(new_name, builder);
        }

        pub fn takeName(self: Index, other: Index, builder: *Builder) Allocator.Error!void {
            try builder.ensureUnusedGlobalCapacity(.empty);
            self.takeNameAssumeCapacity(other, builder);
        }

        pub fn replace(self: Index, other: Index, builder: *Builder) Allocator.Error!void {
            try builder.ensureUnusedGlobalCapacity(.empty);
            self.replaceAssumeCapacity(other, builder);
        }

        pub fn delete(self: Index, builder: *Builder) void {
            self.ptr(builder).kind = .{ .replaced = .none };
        }

        fn updateDsoLocal(self: Index, builder: *Builder) void {
            const self_ptr = self.ptr(builder);
            switch (self_ptr.linkage) {
                .private, .internal => {
                    self_ptr.visibility = .default;
                    self_ptr.dll_storage_class = .default;
                    self_ptr.preemption = .implicit_dso_local;
                },
                .extern_weak => if (self_ptr.preemption == .implicit_dso_local) {
                    self_ptr.preemption = .dso_local;
                },
                else => switch (self_ptr.visibility) {
                    .default => if (self_ptr.preemption == .implicit_dso_local) {
                        self_ptr.preemption = .dso_local;
                    },
                    else => self_ptr.preemption = .implicit_dso_local,
                },
            }
        }

        fn renameAssumeCapacity(self: Index, new_name: StrtabString, builder: *Builder) void {
            const old_name = self.name(builder);
            if (new_name == old_name) return;
            const index = @intFromEnum(self.unwrap(builder));
            _ = builder.addGlobalAssumeCapacity(new_name, builder.globals.values()[index]);
            builder.globals.swapRemoveAt(index);
            if (!old_name.isAnon()) return;
            builder.next_unnamed_global = @enumFromInt(@intFromEnum(builder.next_unnamed_global) - 1);
            if (builder.next_unnamed_global == old_name) return;
            builder.getGlobal(builder.next_unnamed_global).?.renameAssumeCapacity(old_name, builder);
        }

        fn takeNameAssumeCapacity(self: Index, other: Index, builder: *Builder) void {
            const other_name = other.name(builder);
            other.renameAssumeCapacity(.empty, builder);
            self.renameAssumeCapacity(other_name, builder);
        }

        fn replaceAssumeCapacity(self: Index, other: Index, builder: *Builder) void {
            if (self.eql(other, builder)) return;
            builder.next_replaced_global = @enumFromInt(@intFromEnum(builder.next_replaced_global) - 1);
            self.renameAssumeCapacity(builder.next_replaced_global, builder);
            self.ptr(builder).kind = .{ .replaced = other.unwrap(builder) };
        }

        fn getReplacement(self: Index, builder: *const Builder) Index {
            return switch (builder.globals.values()[@intFromEnum(self)].kind) {
                .replaced => |replacement| replacement,
                else => .none,
            };
        }
    };
};

pub const Alias = struct {
    global: Global.Index,
    thread_local: ThreadLocal = .default,
    aliasee: Constant = .no_init,

    pub const Index = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn ptr(self: Index, builder: *Builder) *Alias {
            return &builder.aliases.items[@intFromEnum(self)];
        }

        pub fn ptrConst(self: Index, builder: *const Builder) *const Alias {
            return &builder.aliases.items[@intFromEnum(self)];
        }

        pub fn name(self: Index, builder: *const Builder) StrtabString {
            return self.ptrConst(builder).global.name(builder);
        }

        pub fn rename(self: Index, new_name: StrtabString, builder: *Builder) Allocator.Error!void {
            return self.ptrConst(builder).global.rename(new_name, builder);
        }

        pub fn typeOf(self: Index, builder: *const Builder) Type {
            return self.ptrConst(builder).global.typeOf(builder);
        }

        pub fn toConst(self: Index, builder: *const Builder) Constant {
            return self.ptrConst(builder).global.toConst();
        }

        pub fn toValue(self: Index, builder: *const Builder) Value {
            return self.toConst(builder).toValue();
        }

        pub fn getAliasee(self: Index, builder: *const Builder) Global.Index {
            const aliasee = self.ptrConst(builder).aliasee.getBase(builder);
            assert(aliasee != .none);
            return aliasee;
        }

        pub fn setAliasee(self: Index, aliasee: Constant, builder: *Builder) void {
            self.ptr(builder).aliasee = aliasee;
        }
    };
};

pub const Variable = struct {
    global: Global.Index,
    thread_local: ThreadLocal = .default,
    mutability: Mutability = .global,
    init: Constant = .no_init,
    section: String = .none,
    alignment: Alignment = .default,

    pub const Index = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn ptr(self: Index, builder: *Builder) *Variable {
            return &builder.variables.items[@intFromEnum(self)];
        }

        pub fn ptrConst(self: Index, builder: *const Builder) *const Variable {
            return &builder.variables.items[@intFromEnum(self)];
        }

        pub fn name(self: Index, builder: *const Builder) StrtabString {
            return self.ptrConst(builder).global.name(builder);
        }

        pub fn rename(self: Index, new_name: StrtabString, builder: *Builder) Allocator.Error!void {
            return self.ptrConst(builder).global.rename(new_name, builder);
        }

        pub fn typeOf(self: Index, builder: *const Builder) Type {
            return self.ptrConst(builder).global.typeOf(builder);
        }

        pub fn toConst(self: Index, builder: *const Builder) Constant {
            return self.ptrConst(builder).global.toConst();
        }

        pub fn toValue(self: Index, builder: *const Builder) Value {
            return self.toConst(builder).toValue();
        }

        pub fn setLinkage(self: Index, linkage: Linkage, builder: *Builder) void {
            return self.ptrConst(builder).global.setLinkage(linkage, builder);
        }

        pub fn setUnnamedAddr(self: Index, unnamed_addr: UnnamedAddr, builder: *Builder) void {
            return self.ptrConst(builder).global.setUnnamedAddr(unnamed_addr, builder);
        }

        pub fn setThreadLocal(self: Index, thread_local: ThreadLocal, builder: *Builder) void {
            self.ptr(builder).thread_local = thread_local;
        }

        pub fn setMutability(self: Index, mutability: Mutability, builder: *Builder) void {
            self.ptr(builder).mutability = mutability;
        }

        pub fn setInitializer(
            self: Index,
            initializer: Constant,
            builder: *Builder,
        ) Allocator.Error!void {
            if (initializer != .no_init) {
                const variable = self.ptrConst(builder);
                const global = variable.global.ptr(builder);
                const initializer_type = initializer.typeOf(builder);
                global.type = initializer_type;
            }
            self.ptr(builder).init = initializer;
        }

        pub fn setSection(self: Index, section: String, builder: *Builder) void {
            self.ptr(builder).section = section;
        }

        pub fn setAlignment(self: Index, alignment: Alignment, builder: *Builder) void {
            self.ptr(builder).alignment = alignment;
        }

        pub fn getAlignment(self: Index, builder: *Builder) Alignment {
            return self.ptr(builder).alignment;
        }

        pub fn setGlobalVariableExpression(self: Index, expression: Metadata, builder: *Builder) void {
            self.ptrConst(builder).global.setDebugMetadata(expression, builder);
        }
    };
};

pub const Intrinsic = enum {
    // Variable Argument Handling
    va_start,
    va_end,
    va_copy,

    // Code Generator
    returnaddress,
    addressofreturnaddress,
    sponentry,
    frameaddress,
    prefetch,
    @"thread.pointer",

    // Standard C/C++ Library
    abs,
    smax,
    smin,
    umax,
    umin,
    memcpy,
    @"memcpy.inline",
    memmove,
    memset,
    @"memset.inline",
    sqrt,
    powi,
    sin,
    cos,
    pow,
    exp,
    exp2,
    ldexp,
    frexp,
    log,
    log10,
    log2,
    fma,
    fabs,
    minnum,
    maxnum,
    minimum,
    maximum,
    copysign,
    floor,
    ceil,
    trunc,
    rint,
    nearbyint,
    round,
    roundeven,
    lround,
    llround,
    lrint,
    llrint,

    // Bit Manipulation
    bitreverse,
    bswap,
    ctpop,
    ctlz,
    cttz,
    fshl,
    fshr,

    // Arithmetic with Overflow
    @"sadd.with.overflow",
    @"uadd.with.overflow",
    @"ssub.with.overflow",
    @"usub.with.overflow",
    @"smul.with.overflow",
    @"umul.with.overflow",

    // Saturation Arithmetic
    @"sadd.sat",
    @"uadd.sat",
    @"ssub.sat",
    @"usub.sat",
    @"sshl.sat",
    @"ushl.sat",

    // Fixed Point Arithmetic
    @"smul.fix",
    @"umul.fix",
    @"smul.fix.sat",
    @"umul.fix.sat",
    @"sdiv.fix",
    @"udiv.fix",
    @"sdiv.fix.sat",
    @"udiv.fix.sat",

    // Specialised Arithmetic
    canonicalize,
    fmuladd,

    // Vector Reduction
    @"vector.reduce.add",
    @"vector.reduce.fadd",
    @"vector.reduce.mul",
    @"vector.reduce.fmul",
    @"vector.reduce.and",
    @"vector.reduce.or",
    @"vector.reduce.xor",
    @"vector.reduce.smax",
    @"vector.reduce.smin",
    @"vector.reduce.umax",
    @"vector.reduce.umin",
    @"vector.reduce.fmax",
    @"vector.reduce.fmin",
    @"vector.reduce.fmaximum",
    @"vector.reduce.fminimum",
    @"vector.insert",
    @"vector.extract",

    // Floating-Point Test
    @"is.fpclass",

    // General
    @"var.annotation",
    @"ptr.annotation",
    annotation,
    @"codeview.annotation",
    trap,
    debugtrap,
    ubsantrap,
    stackprotector,
    stackguard,
    objectsize,
    expect,
    @"expect.with.probability",
    assume,
    @"ssa.copy",
    @"type.test",
    @"type.checked.load",
    @"type.checked.load.relative",
    @"arithmetic.fence",
    donothing,
    @"load.relative",
    sideeffect,
    @"is.constant",
    ptrmask,
    @"threadlocal.address",
    vscale,

    // Debug
    @"dbg.declare",
    @"dbg.value",

    // AMDGPU
    @"amdgcn.workitem.id.x",
    @"amdgcn.workitem.id.y",
    @"amdgcn.workitem.id.z",
    @"amdgcn.workgroup.id.x",
    @"amdgcn.workgroup.id.y",
    @"amdgcn.workgroup.id.z",
    @"amdgcn.dispatch.ptr",

    // WebAssembly
    @"wasm.memory.size",
    @"wasm.memory.grow",

    const Signature = struct {
        ret_len: u8,
        params: []const Parameter,
        attrs: []const Attribute = &.{},

        const Parameter = struct {
            kind: Kind,
            attrs: []const Attribute = &.{},

            const Kind = union(enum) {
                type: Type,
                overloaded,
                matches: u8,
                matches_scalar: u8,
                matches_changed_scalar: struct {
                    index: u8,
                    scalar: Type,
                },
            };
        };
    };

    const signatures = std.enums.EnumArray(Intrinsic, Signature).init(.{
        .va_start = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .{ .type = .ptr } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn },
        },
        .va_end = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .{ .type = .ptr } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn },
        },
        .va_copy = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .{ .type = .ptr } },
                .{ .kind = .{ .type = .ptr } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn },
        },

        .returnaddress = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .type = .ptr } },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .addressofreturnaddress = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .sponentry = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .frameaddress = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .prefetch = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .overloaded, .attrs = &.{ .nocapture, .readonly } },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.readwrite) } },
        },
        .@"thread.pointer" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .type = .ptr } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },

        .abs = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .type = .i1 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .smax = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .smin = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .umax = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .umin = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .memcpy = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .overloaded, .attrs = &.{ .@"noalias", .nocapture, .writeonly } },
                .{ .kind = .overloaded, .attrs = &.{ .@"noalias", .nocapture, .readonly } },
                .{ .kind = .overloaded },
                .{ .kind = .{ .type = .i1 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nounwind, .willreturn, .{ .memory = .{ .argmem = .readwrite } } },
        },
        .@"memcpy.inline" = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .overloaded, .attrs = &.{ .@"noalias", .nocapture, .writeonly } },
                .{ .kind = .overloaded, .attrs = &.{ .@"noalias", .nocapture, .readonly } },
                .{ .kind = .overloaded, .attrs = &.{.immarg} },
                .{ .kind = .{ .type = .i1 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nounwind, .willreturn, .{ .memory = .{ .argmem = .readwrite } } },
        },
        .memmove = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .overloaded, .attrs = &.{ .nocapture, .writeonly } },
                .{ .kind = .overloaded, .attrs = &.{ .nocapture, .readonly } },
                .{ .kind = .overloaded },
                .{ .kind = .{ .type = .i1 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nounwind, .willreturn, .{ .memory = .{ .argmem = .readwrite } } },
        },
        .memset = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .overloaded, .attrs = &.{ .nocapture, .writeonly } },
                .{ .kind = .{ .type = .i8 } },
                .{ .kind = .overloaded },
                .{ .kind = .{ .type = .i1 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nounwind, .willreturn, .{ .memory = .{ .argmem = .write } } },
        },
        .@"memset.inline" = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .overloaded, .attrs = &.{ .nocapture, .writeonly } },
                .{ .kind = .{ .type = .i8 } },
                .{ .kind = .overloaded, .attrs = &.{.immarg} },
                .{ .kind = .{ .type = .i1 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nounwind, .willreturn, .{ .memory = .{ .argmem = .write } } },
        },
        .sqrt = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .powi = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .sin = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .cos = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .pow = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .exp = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .exp2 = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .ldexp = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .frexp = .{
            .ret_len = 2,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .log = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .log10 = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .log2 = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .fma = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .fabs = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .minnum = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .maxnum = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .minimum = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .maximum = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .copysign = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .floor = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .ceil = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .trunc = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .rint = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .nearbyint = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .round = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .roundeven = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .lround = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .llround = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .lrint = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .llrint = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },

        .bitreverse = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .bswap = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .ctpop = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .ctlz = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .type = .i1 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .cttz = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .type = .i1 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .fshl = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .fshr = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },

        .@"sadd.with.overflow" = .{
            .ret_len = 2,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches_changed_scalar = .{ .index = 0, .scalar = .i1 } } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"uadd.with.overflow" = .{
            .ret_len = 2,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches_changed_scalar = .{ .index = 0, .scalar = .i1 } } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"ssub.with.overflow" = .{
            .ret_len = 2,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches_changed_scalar = .{ .index = 0, .scalar = .i1 } } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"usub.with.overflow" = .{
            .ret_len = 2,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches_changed_scalar = .{ .index = 0, .scalar = .i1 } } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"smul.with.overflow" = .{
            .ret_len = 2,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches_changed_scalar = .{ .index = 0, .scalar = .i1 } } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"umul.with.overflow" = .{
            .ret_len = 2,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches_changed_scalar = .{ .index = 0, .scalar = .i1 } } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },

        .@"sadd.sat" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"uadd.sat" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"ssub.sat" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"usub.sat" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"sshl.sat" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"ushl.sat" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },

        .@"smul.fix" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"umul.fix" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"smul.fix.sat" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"umul.fix.sat" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"sdiv.fix" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"udiv.fix" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"sdiv.fix.sat" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"udiv.fix.sat" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },

        .canonicalize = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .fmuladd = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },

        .@"vector.reduce.add" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.fadd" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 2 } },
                .{ .kind = .{ .matches_scalar = 2 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.mul" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.fmul" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 2 } },
                .{ .kind = .{ .matches_scalar = 2 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.and" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.or" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.xor" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.smax" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.smin" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.umax" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.umin" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.fmax" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.fmin" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.fmaximum" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.reduce.fminimum" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_scalar = 1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.insert" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .overloaded },
                .{ .kind = .{ .type = .i64 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"vector.extract" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .overloaded },
                .{ .kind = .{ .type = .i64 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },

        .@"is.fpclass" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .matches_changed_scalar = .{ .index = 1, .scalar = .i1 } } },
                .{ .kind = .overloaded },
                .{ .kind = .{ .type = .i32 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },

        .@"var.annotation" = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 1 } },
                .{ .kind = .{ .type = .i32 } },
                .{ .kind = .{ .matches = 1 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = .{ .inaccessiblemem = .readwrite } } },
        },
        .@"ptr.annotation" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 2 } },
                .{ .kind = .{ .type = .i32 } },
                .{ .kind = .{ .matches = 2 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = .{ .inaccessiblemem = .readwrite } } },
        },
        .annotation = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 2 } },
                .{ .kind = .{ .type = .i32 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = .{ .inaccessiblemem = .readwrite } } },
        },
        .@"codeview.annotation" = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .{ .type = .metadata } },
            },
            .attrs = &.{ .nocallback, .noduplicate, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = .{ .inaccessiblemem = .readwrite } } },
        },
        .trap = .{
            .ret_len = 0,
            .params = &.{},
            .attrs = &.{ .cold, .noreturn, .nounwind, .{ .memory = .{ .inaccessiblemem = .write } } },
        },
        .debugtrap = .{
            .ret_len = 0,
            .params = &.{},
            .attrs = &.{.nounwind},
        },
        .ubsantrap = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .{ .type = .i8 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .cold, .noreturn, .nounwind },
        },
        .stackprotector = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .{ .type = .ptr } },
                .{ .kind = .{ .type = .ptr } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn },
        },
        .stackguard = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .type = .ptr } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn },
        },
        .objectsize = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .overloaded },
                .{ .kind = .{ .type = .i1 }, .attrs = &.{.immarg} },
                .{ .kind = .{ .type = .i1 }, .attrs = &.{.immarg} },
                .{ .kind = .{ .type = .i1 }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .expect = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"expect.with.probability" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .{ .type = .double }, .attrs = &.{.immarg} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .assume = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .{ .type = .i1 }, .attrs = &.{.noundef} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = .{ .inaccessiblemem = .write } } },
        },
        .@"ssa.copy" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 }, .attrs = &.{.returned} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"type.test" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .type = .i1 } },
                .{ .kind = .{ .type = .ptr } },
                .{ .kind = .{ .type = .metadata } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"type.checked.load" = .{
            .ret_len = 2,
            .params = &.{
                .{ .kind = .{ .type = .ptr } },
                .{ .kind = .{ .type = .i1 } },
                .{ .kind = .{ .type = .ptr } },
                .{ .kind = .{ .type = .i32 } },
                .{ .kind = .{ .type = .metadata } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"type.checked.load.relative" = .{
            .ret_len = 2,
            .params = &.{
                .{ .kind = .{ .type = .ptr } },
                .{ .kind = .{ .type = .i1 } },
                .{ .kind = .{ .type = .ptr } },
                .{ .kind = .{ .type = .i32 } },
                .{ .kind = .{ .type = .metadata } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"arithmetic.fence" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .donothing = .{
            .ret_len = 0,
            .params = &.{},
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"load.relative" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .type = .ptr } },
                .{ .kind = .{ .type = .ptr } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = .{ .argmem = .read } } },
        },
        .sideeffect = .{
            .ret_len = 0,
            .params = &.{},
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = .{ .inaccessiblemem = .readwrite } } },
        },
        .@"is.constant" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .type = .i1 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .convergent, .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .ptrmask = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .matches = 0 } },
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"threadlocal.address" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded, .attrs = &.{.nonnull} },
                .{ .kind = .{ .matches = 0 }, .attrs = &.{.nonnull} },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .vscale = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },

        .@"dbg.declare" = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .{ .type = .metadata } },
                .{ .kind = .{ .type = .metadata } },
                .{ .kind = .{ .type = .metadata } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"dbg.value" = .{
            .ret_len = 0,
            .params = &.{
                .{ .kind = .{ .type = .metadata } },
                .{ .kind = .{ .type = .metadata } },
                .{ .kind = .{ .type = .metadata } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },

        .@"amdgcn.workitem.id.x" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .type = .i32 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"amdgcn.workitem.id.y" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .type = .i32 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"amdgcn.workitem.id.z" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .type = .i32 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"amdgcn.workgroup.id.x" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .type = .i32 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"amdgcn.workgroup.id.y" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .type = .i32 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"amdgcn.workgroup.id.z" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .{ .type = .i32 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"amdgcn.dispatch.ptr" = .{
            .ret_len = 1,
            .params = &.{
                .{
                    .kind = .{ .type = Type.ptr_amdgpu_constant },
                    .attrs = &.{.{ .@"align" = Builder.Alignment.fromByteUnits(4) }},
                },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .speculatable, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },

        .@"wasm.memory.size" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .type = .i32 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn, .{ .memory = Attribute.Memory.all(.none) } },
        },
        .@"wasm.memory.grow" = .{
            .ret_len = 1,
            .params = &.{
                .{ .kind = .overloaded },
                .{ .kind = .{ .type = .i32 } },
                .{ .kind = .{ .matches = 0 } },
            },
            .attrs = &.{ .nocallback, .nofree, .nosync, .nounwind, .willreturn },
        },
    });
};

pub const Function = struct {
    global: Global.Index,
    call_conv: CallConv = CallConv.default,
    attributes: FunctionAttributes = .none,
    section: String = .none,
    alignment: Alignment = .default,
    blocks: []const Block = &.{},
    instructions: std.MultiArrayList(Instruction) = .{},
    names: [*]const String = &[0]String{},
    value_indices: [*]const u32 = &[0]u32{},
    strip: bool,
    debug_locations: std.AutoHashMapUnmanaged(Instruction.Index, DebugLocation) = .{},
    debug_values: []const Instruction.Index = &.{},
    extra: []const u32 = &.{},

    pub const Index = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn ptr(self: Index, builder: *Builder) *Function {
            return &builder.functions.items[@intFromEnum(self)];
        }

        pub fn ptrConst(self: Index, builder: *const Builder) *const Function {
            return &builder.functions.items[@intFromEnum(self)];
        }

        pub fn name(self: Index, builder: *const Builder) StrtabString {
            return self.ptrConst(builder).global.name(builder);
        }

        pub fn rename(self: Index, new_name: StrtabString, builder: *Builder) Allocator.Error!void {
            return self.ptrConst(builder).global.rename(new_name, builder);
        }

        pub fn typeOf(self: Index, builder: *const Builder) Type {
            return self.ptrConst(builder).global.typeOf(builder);
        }

        pub fn toConst(self: Index, builder: *const Builder) Constant {
            return self.ptrConst(builder).global.toConst();
        }

        pub fn toValue(self: Index, builder: *const Builder) Value {
            return self.toConst(builder).toValue();
        }

        pub fn setLinkage(self: Index, linkage: Linkage, builder: *Builder) void {
            return self.ptrConst(builder).global.setLinkage(linkage, builder);
        }

        pub fn setUnnamedAddr(self: Index, unnamed_addr: UnnamedAddr, builder: *Builder) void {
            return self.ptrConst(builder).global.setUnnamedAddr(unnamed_addr, builder);
        }

        pub fn setCallConv(self: Index, call_conv: CallConv, builder: *Builder) void {
            self.ptr(builder).call_conv = call_conv;
        }

        pub fn setAttributes(
            self: Index,
            new_function_attributes: FunctionAttributes,
            builder: *Builder,
        ) void {
            self.ptr(builder).attributes = new_function_attributes;
        }

        pub fn setSection(self: Index, section: String, builder: *Builder) void {
            self.ptr(builder).section = section;
        }

        pub fn setAlignment(self: Index, alignment: Alignment, builder: *Builder) void {
            self.ptr(builder).alignment = alignment;
        }

        pub fn setSubprogram(self: Index, subprogram: Metadata, builder: *Builder) void {
            self.ptrConst(builder).global.setDebugMetadata(subprogram, builder);
        }
    };

    pub const Block = struct {
        instruction: Instruction.Index,

        pub const Index = WipFunction.Block.Index;
    };

    pub const Instruction = struct {
        tag: Tag,
        data: u32,

        pub const Tag = enum(u8) {
            add,
            @"add nsw",
            @"add nuw",
            @"add nuw nsw",
            addrspacecast,
            alloca,
            @"alloca inalloca",
            @"and",
            arg,
            ashr,
            @"ashr exact",
            atomicrmw,
            bitcast,
            block,
            br,
            br_cond,
            call,
            @"call fast",
            cmpxchg,
            @"cmpxchg weak",
            extractelement,
            extractvalue,
            fadd,
            @"fadd fast",
            @"fcmp false",
            @"fcmp fast false",
            @"fcmp fast oeq",
            @"fcmp fast oge",
            @"fcmp fast ogt",
            @"fcmp fast ole",
            @"fcmp fast olt",
            @"fcmp fast one",
            @"fcmp fast ord",
            @"fcmp fast true",
            @"fcmp fast ueq",
            @"fcmp fast uge",
            @"fcmp fast ugt",
            @"fcmp fast ule",
            @"fcmp fast ult",
            @"fcmp fast une",
            @"fcmp fast uno",
            @"fcmp oeq",
            @"fcmp oge",
            @"fcmp ogt",
            @"fcmp ole",
            @"fcmp olt",
            @"fcmp one",
            @"fcmp ord",
            @"fcmp true",
            @"fcmp ueq",
            @"fcmp uge",
            @"fcmp ugt",
            @"fcmp ule",
            @"fcmp ult",
            @"fcmp une",
            @"fcmp uno",
            fdiv,
            @"fdiv fast",
            fence,
            fmul,
            @"fmul fast",
            fneg,
            @"fneg fast",
            fpext,
            fptosi,
            fptoui,
            fptrunc,
            frem,
            @"frem fast",
            fsub,
            @"fsub fast",
            getelementptr,
            @"getelementptr inbounds",
            @"icmp eq",
            @"icmp ne",
            @"icmp sge",
            @"icmp sgt",
            @"icmp sle",
            @"icmp slt",
            @"icmp uge",
            @"icmp ugt",
            @"icmp ule",
            @"icmp ult",
            insertelement,
            insertvalue,
            inttoptr,
            load,
            @"load atomic",
            lshr,
            @"lshr exact",
            mul,
            @"mul nsw",
            @"mul nuw",
            @"mul nuw nsw",
            @"musttail call",
            @"musttail call fast",
            @"notail call",
            @"notail call fast",
            @"or",
            phi,
            @"phi fast",
            ptrtoint,
            ret,
            @"ret void",
            sdiv,
            @"sdiv exact",
            select,
            @"select fast",
            sext,
            shl,
            @"shl nsw",
            @"shl nuw",
            @"shl nuw nsw",
            shufflevector,
            sitofp,
            srem,
            store,
            @"store atomic",
            sub,
            @"sub nsw",
            @"sub nuw",
            @"sub nuw nsw",
            @"switch",
            @"tail call",
            @"tail call fast",
            trunc,
            udiv,
            @"udiv exact",
            urem,
            uitofp,
            @"unreachable",
            va_arg,
            xor,
            zext,

            pub fn toBinaryOpcode(self: Tag) BinaryOpcode {
                return switch (self) {
                    .add,
                    .@"add nsw",
                    .@"add nuw",
                    .@"add nuw nsw",
                    .fadd,
                    .@"fadd fast",
                    => .add,
                    .sub,
                    .@"sub nsw",
                    .@"sub nuw",
                    .@"sub nuw nsw",
                    .fsub,
                    .@"fsub fast",
                    => .sub,
                    .sdiv,
                    .@"sdiv exact",
                    .fdiv,
                    .@"fdiv fast",
                    => .sdiv,
                    .fmul,
                    .@"fmul fast",
                    .mul,
                    .@"mul nsw",
                    .@"mul nuw",
                    .@"mul nuw nsw",
                    => .mul,
                    .srem,
                    .frem,
                    .@"frem fast",
                    => .srem,
                    .udiv,
                    .@"udiv exact",
                    => .udiv,
                    .shl,
                    .@"shl nsw",
                    .@"shl nuw",
                    .@"shl nuw nsw",
                    => .shl,
                    .lshr,
                    .@"lshr exact",
                    => .lshr,
                    .ashr,
                    .@"ashr exact",
                    => .ashr,
                    .@"and" => .@"and",
                    .@"or" => .@"or",
                    .xor => .xor,
                    .urem => .urem,
                    else => unreachable,
                };
            }

            pub fn toCastOpcode(self: Tag) CastOpcode {
                return switch (self) {
                    .trunc => .trunc,
                    .zext => .zext,
                    .sext => .sext,
                    .fptoui => .fptoui,
                    .fptosi => .fptosi,
                    .uitofp => .uitofp,
                    .sitofp => .sitofp,
                    .fptrunc => .fptrunc,
                    .fpext => .fpext,
                    .ptrtoint => .ptrtoint,
                    .inttoptr => .inttoptr,
                    .bitcast => .bitcast,
                    .addrspacecast => .addrspacecast,
                    else => unreachable,
                };
            }

            pub fn toCmpPredicate(self: Tag) CmpPredicate {
                return switch (self) {
                    .@"fcmp false",
                    .@"fcmp fast false",
                    => .fcmp_false,
                    .@"fcmp oeq",
                    .@"fcmp fast oeq",
                    => .fcmp_oeq,
                    .@"fcmp oge",
                    .@"fcmp fast oge",
                    => .fcmp_oge,
                    .@"fcmp ogt",
                    .@"fcmp fast ogt",
                    => .fcmp_ogt,
                    .@"fcmp ole",
                    .@"fcmp fast ole",
                    => .fcmp_ole,
                    .@"fcmp olt",
                    .@"fcmp fast olt",
                    => .fcmp_olt,
                    .@"fcmp one",
                    .@"fcmp fast one",
                    => .fcmp_one,
                    .@"fcmp ord",
                    .@"fcmp fast ord",
                    => .fcmp_ord,
                    .@"fcmp true",
                    .@"fcmp fast true",
                    => .fcmp_true,
                    .@"fcmp ueq",
                    .@"fcmp fast ueq",
                    => .fcmp_ueq,
                    .@"fcmp uge",
                    .@"fcmp fast uge",
                    => .fcmp_uge,
                    .@"fcmp ugt",
                    .@"fcmp fast ugt",
                    => .fcmp_ugt,
                    .@"fcmp ule",
                    .@"fcmp fast ule",
                    => .fcmp_ule,
                    .@"fcmp ult",
                    .@"fcmp fast ult",
                    => .fcmp_ult,
                    .@"fcmp une",
                    .@"fcmp fast une",
                    => .fcmp_une,
                    .@"fcmp uno",
                    .@"fcmp fast uno",
                    => .fcmp_uno,
                    .@"icmp eq" => .icmp_eq,
                    .@"icmp ne" => .icmp_ne,
                    .@"icmp sge" => .icmp_sge,
                    .@"icmp sgt" => .icmp_sgt,
                    .@"icmp sle" => .icmp_sle,
                    .@"icmp slt" => .icmp_slt,
                    .@"icmp uge" => .icmp_uge,
                    .@"icmp ugt" => .icmp_ugt,
                    .@"icmp ule" => .icmp_ule,
                    .@"icmp ult" => .icmp_ult,
                    else => unreachable,
                };
            }
        };

        pub const Index = enum(u32) {
            none = std.math.maxInt(u31),
            _,

            pub fn name(self: Instruction.Index, function: *const Function) String {
                return function.names[@intFromEnum(self)];
            }

            pub fn valueIndex(self: Instruction.Index, function: *const Function) u32 {
                return function.value_indices[@intFromEnum(self)];
            }

            pub fn toValue(self: Instruction.Index) Value {
                return @enumFromInt(@intFromEnum(self));
            }

            pub fn isTerminatorWip(self: Instruction.Index, wip: *const WipFunction) bool {
                return switch (wip.instructions.items(.tag)[@intFromEnum(self)]) {
                    .br,
                    .br_cond,
                    .ret,
                    .@"ret void",
                    .@"switch",
                    .@"unreachable",
                    => true,
                    else => false,
                };
            }

            pub fn hasResultWip(self: Instruction.Index, wip: *const WipFunction) bool {
                return switch (wip.instructions.items(.tag)[@intFromEnum(self)]) {
                    .br,
                    .br_cond,
                    .fence,
                    .ret,
                    .@"ret void",
                    .store,
                    .@"store atomic",
                    .@"switch",
                    .@"unreachable",
                    .block,
                    => false,
                    .call,
                    .@"call fast",
                    .@"musttail call",
                    .@"musttail call fast",
                    .@"notail call",
                    .@"notail call fast",
                    .@"tail call",
                    .@"tail call fast",
                    => self.typeOfWip(wip) != .void,
                    else => true,
                };
            }

            pub fn typeOfWip(self: Instruction.Index, wip: *const WipFunction) Type {
                const instruction = wip.instructions.get(@intFromEnum(self));
                return switch (instruction.tag) {
                    .add,
                    .@"add nsw",
                    .@"add nuw",
                    .@"add nuw nsw",
                    .@"and",
                    .ashr,
                    .@"ashr exact",
                    .fadd,
                    .@"fadd fast",
                    .fdiv,
                    .@"fdiv fast",
                    .fmul,
                    .@"fmul fast",
                    .frem,
                    .@"frem fast",
                    .fsub,
                    .@"fsub fast",
                    .lshr,
                    .@"lshr exact",
                    .mul,
                    .@"mul nsw",
                    .@"mul nuw",
                    .@"mul nuw nsw",
                    .@"or",
                    .sdiv,
                    .@"sdiv exact",
                    .shl,
                    .@"shl nsw",
                    .@"shl nuw",
                    .@"shl nuw nsw",
                    .srem,
                    .sub,
                    .@"sub nsw",
                    .@"sub nuw",
                    .@"sub nuw nsw",
                    .udiv,
                    .@"udiv exact",
                    .urem,
                    .xor,
                    => wip.extraData(Binary, instruction.data).lhs.typeOfWip(wip),
                    .addrspacecast,
                    .bitcast,
                    .fpext,
                    .fptosi,
                    .fptoui,
                    .fptrunc,
                    .inttoptr,
                    .ptrtoint,
                    .sext,
                    .sitofp,
                    .trunc,
                    .uitofp,
                    .zext,
                    => wip.extraData(Cast, instruction.data).type,
                    .alloca,
                    .@"alloca inalloca",
                    => wip.builder.ptrTypeAssumeCapacity(
                        wip.extraData(Alloca, instruction.data).info.addr_space,
                    ),
                    .arg => wip.function.typeOf(wip.builder)
                        .functionParameters(wip.builder)[instruction.data],
                    .atomicrmw => wip.extraData(AtomicRmw, instruction.data).val.typeOfWip(wip),
                    .block => .label,
                    .br,
                    .br_cond,
                    .fence,
                    .ret,
                    .@"ret void",
                    .store,
                    .@"store atomic",
                    .@"switch",
                    .@"unreachable",
                    => .none,
                    .call,
                    .@"call fast",
                    .@"musttail call",
                    .@"musttail call fast",
                    .@"notail call",
                    .@"notail call fast",
                    .@"tail call",
                    .@"tail call fast",
                    => wip.extraData(Call, instruction.data).ty.functionReturn(wip.builder),
                    .cmpxchg,
                    .@"cmpxchg weak",
                    => wip.builder.structTypeAssumeCapacity(.normal, &.{
                        wip.extraData(CmpXchg, instruction.data).cmp.typeOfWip(wip),
                        .i1,
                    }),
                    .extractelement => wip.extraData(ExtractElement, instruction.data)
                        .val.typeOfWip(wip).childType(wip.builder),
                    .extractvalue => {
                        var extra = wip.extraDataTrail(ExtractValue, instruction.data);
                        const indices = extra.trail.next(extra.data.indices_len, u32, wip);
                        return extra.data.val.typeOfWip(wip).childTypeAt(indices, wip.builder);
                    },
                    .@"fcmp false",
                    .@"fcmp fast false",
                    .@"fcmp fast oeq",
                    .@"fcmp fast oge",
                    .@"fcmp fast ogt",
                    .@"fcmp fast ole",
                    .@"fcmp fast olt",
                    .@"fcmp fast one",
                    .@"fcmp fast ord",
                    .@"fcmp fast true",
                    .@"fcmp fast ueq",
                    .@"fcmp fast uge",
                    .@"fcmp fast ugt",
                    .@"fcmp fast ule",
                    .@"fcmp fast ult",
                    .@"fcmp fast une",
                    .@"fcmp fast uno",
                    .@"fcmp oeq",
                    .@"fcmp oge",
                    .@"fcmp ogt",
                    .@"fcmp ole",
                    .@"fcmp olt",
                    .@"fcmp one",
                    .@"fcmp ord",
                    .@"fcmp true",
                    .@"fcmp ueq",
                    .@"fcmp uge",
                    .@"fcmp ugt",
                    .@"fcmp ule",
                    .@"fcmp ult",
                    .@"fcmp une",
                    .@"fcmp uno",
                    .@"icmp eq",
                    .@"icmp ne",
                    .@"icmp sge",
                    .@"icmp sgt",
                    .@"icmp sle",
                    .@"icmp slt",
                    .@"icmp uge",
                    .@"icmp ugt",
                    .@"icmp ule",
                    .@"icmp ult",
                    => wip.extraData(Binary, instruction.data).lhs.typeOfWip(wip)
                        .changeScalarAssumeCapacity(.i1, wip.builder),
                    .fneg,
                    .@"fneg fast",
                    => @as(Value, @enumFromInt(instruction.data)).typeOfWip(wip),
                    .getelementptr,
                    .@"getelementptr inbounds",
                    => {
                        var extra = wip.extraDataTrail(GetElementPtr, instruction.data);
                        const indices = extra.trail.next(extra.data.indices_len, Value, wip);
                        const base_ty = extra.data.base.typeOfWip(wip);
                        if (!base_ty.isVector(wip.builder)) for (indices) |index| {
                            const index_ty = index.typeOfWip(wip);
                            if (!index_ty.isVector(wip.builder)) continue;
                            return index_ty.changeScalarAssumeCapacity(base_ty, wip.builder);
                        };
                        return base_ty;
                    },
                    .insertelement => wip.extraData(InsertElement, instruction.data).val.typeOfWip(wip),
                    .insertvalue => wip.extraData(InsertValue, instruction.data).val.typeOfWip(wip),
                    .load,
                    .@"load atomic",
                    => wip.extraData(Load, instruction.data).type,
                    .phi,
                    .@"phi fast",
                    => wip.extraData(Phi, instruction.data).type,
                    .select,
                    .@"select fast",
                    => wip.extraData(Select, instruction.data).lhs.typeOfWip(wip),
                    .shufflevector => {
                        const extra = wip.extraData(ShuffleVector, instruction.data);
                        return extra.lhs.typeOfWip(wip).changeLengthAssumeCapacity(
                            extra.mask.typeOfWip(wip).vectorLen(wip.builder),
                            wip.builder,
                        );
                    },
                    .va_arg => wip.extraData(VaArg, instruction.data).type,
                };
            }

            pub fn typeOf(
                self: Instruction.Index,
                function_index: Function.Index,
                builder: *Builder,
            ) Type {
                const function = function_index.ptrConst(builder);
                const instruction = function.instructions.get(@intFromEnum(self));
                return switch (instruction.tag) {
                    .add,
                    .@"add nsw",
                    .@"add nuw",
                    .@"add nuw nsw",
                    .@"and",
                    .ashr,
                    .@"ashr exact",
                    .fadd,
                    .@"fadd fast",
                    .fdiv,
                    .@"fdiv fast",
                    .fmul,
                    .@"fmul fast",
                    .frem,
                    .@"frem fast",
                    .fsub,
                    .@"fsub fast",
                    .lshr,
                    .@"lshr exact",
                    .mul,
                    .@"mul nsw",
                    .@"mul nuw",
                    .@"mul nuw nsw",
                    .@"or",
                    .sdiv,
                    .@"sdiv exact",
                    .shl,
                    .@"shl nsw",
                    .@"shl nuw",
                    .@"shl nuw nsw",
                    .srem,
                    .sub,
                    .@"sub nsw",
                    .@"sub nuw",
                    .@"sub nuw nsw",
                    .udiv,
                    .@"udiv exact",
                    .urem,
                    .xor,
                    => function.extraData(Binary, instruction.data).lhs.typeOf(function_index, builder),
                    .addrspacecast,
                    .bitcast,
                    .fpext,
                    .fptosi,
                    .fptoui,
                    .fptrunc,
                    .inttoptr,
                    .ptrtoint,
                    .sext,
                    .sitofp,
                    .trunc,
                    .uitofp,
                    .zext,
                    => function.extraData(Cast, instruction.data).type,
                    .alloca,
                    .@"alloca inalloca",
                    => builder.ptrTypeAssumeCapacity(
                        function.extraData(Alloca, instruction.data).info.addr_space,
                    ),
                    .arg => function.global.typeOf(builder)
                        .functionParameters(builder)[instruction.data],
                    .atomicrmw => function.extraData(AtomicRmw, instruction.data)
                        .val.typeOf(function_index, builder),
                    .block => .label,
                    .br,
                    .br_cond,
                    .fence,
                    .ret,
                    .@"ret void",
                    .store,
                    .@"store atomic",
                    .@"switch",
                    .@"unreachable",
                    => .none,
                    .call,
                    .@"call fast",
                    .@"musttail call",
                    .@"musttail call fast",
                    .@"notail call",
                    .@"notail call fast",
                    .@"tail call",
                    .@"tail call fast",
                    => function.extraData(Call, instruction.data).ty.functionReturn(builder),
                    .cmpxchg,
                    .@"cmpxchg weak",
                    => builder.structTypeAssumeCapacity(.normal, &.{
                        function.extraData(CmpXchg, instruction.data)
                            .cmp.typeOf(function_index, builder),
                        .i1,
                    }),
                    .extractelement => function.extraData(ExtractElement, instruction.data)
                        .val.typeOf(function_index, builder).childType(builder),
                    .extractvalue => {
                        var extra = function.extraDataTrail(ExtractValue, instruction.data);
                        const indices = extra.trail.next(extra.data.indices_len, u32, function);
                        return extra.data.val.typeOf(function_index, builder)
                            .childTypeAt(indices, builder);
                    },
                    .@"fcmp false",
                    .@"fcmp fast false",
                    .@"fcmp fast oeq",
                    .@"fcmp fast oge",
                    .@"fcmp fast ogt",
                    .@"fcmp fast ole",
                    .@"fcmp fast olt",
                    .@"fcmp fast one",
                    .@"fcmp fast ord",
                    .@"fcmp fast true",
                    .@"fcmp fast ueq",
                    .@"fcmp fast uge",
                    .@"fcmp fast ugt",
                    .@"fcmp fast ule",
                    .@"fcmp fast ult",
                    .@"fcmp fast une",
                    .@"fcmp fast uno",
                    .@"fcmp oeq",
                    .@"fcmp oge",
                    .@"fcmp ogt",
                    .@"fcmp ole",
                    .@"fcmp olt",
                    .@"fcmp one",
                    .@"fcmp ord",
                    .@"fcmp true",
                    .@"fcmp ueq",
                    .@"fcmp uge",
                    .@"fcmp ugt",
                    .@"fcmp ule",
                    .@"fcmp ult",
                    .@"fcmp une",
                    .@"fcmp uno",
                    .@"icmp eq",
                    .@"icmp ne",
                    .@"icmp sge",
                    .@"icmp sgt",
                    .@"icmp sle",
                    .@"icmp slt",
                    .@"icmp uge",
                    .@"icmp ugt",
                    .@"icmp ule",
                    .@"icmp ult",
                    => function.extraData(Binary, instruction.data).lhs.typeOf(function_index, builder)
                        .changeScalarAssumeCapacity(.i1, builder),
                    .fneg,
                    .@"fneg fast",
                    => @as(Value, @enumFromInt(instruction.data)).typeOf(function_index, builder),
                    .getelementptr,
                    .@"getelementptr inbounds",
                    => {
                        var extra = function.extraDataTrail(GetElementPtr, instruction.data);
                        const indices = extra.trail.next(extra.data.indices_len, Value, function);
                        const base_ty = extra.data.base.typeOf(function_index, builder);
                        if (!base_ty.isVector(builder)) for (indices) |index| {
                            const index_ty = index.typeOf(function_index, builder);
                            if (!index_ty.isVector(builder)) continue;
                            return index_ty.changeScalarAssumeCapacity(base_ty, builder);
                        };
                        return base_ty;
                    },
                    .insertelement => function.extraData(InsertElement, instruction.data)
                        .val.typeOf(function_index, builder),
                    .insertvalue => function.extraData(InsertValue, instruction.data)
                        .val.typeOf(function_index, builder),
                    .load,
                    .@"load atomic",
                    => function.extraData(Load, instruction.data).type,
                    .phi,
                    .@"phi fast",
                    => function.extraData(Phi, instruction.data).type,
                    .select,
                    .@"select fast",
                    => function.extraData(Select, instruction.data).lhs.typeOf(function_index, builder),
                    .shufflevector => {
                        const extra = function.extraData(ShuffleVector, instruction.data);
                        return extra.lhs.typeOf(function_index, builder).changeLengthAssumeCapacity(
                            extra.mask.typeOf(function_index, builder).vectorLen(builder),
                            builder,
                        );
                    },
                    .va_arg => function.extraData(VaArg, instruction.data).type,
                };
            }

            const FormatData = struct {
                instruction: Instruction.Index,
                function: Function.Index,
                builder: *Builder,
            };
            fn format(
                data: FormatData,
                comptime fmt_str: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) @TypeOf(writer).Error!void {
                if (comptime std.mem.indexOfNone(u8, fmt_str, ", %")) |_|
                    @compileError("invalid format string: '" ++ fmt_str ++ "'");
                if (comptime std.mem.indexOfScalar(u8, fmt_str, ',') != null) {
                    if (data.instruction == .none) return;
                    try writer.writeByte(',');
                }
                if (comptime std.mem.indexOfScalar(u8, fmt_str, ' ') != null) {
                    if (data.instruction == .none) return;
                    try writer.writeByte(' ');
                }
                if (comptime std.mem.indexOfScalar(u8, fmt_str, '%') != null) try writer.print(
                    "{%} ",
                    .{data.instruction.typeOf(data.function, data.builder).fmt(data.builder)},
                );
                assert(data.instruction != .none);
                try writer.print("%{}", .{
                    data.instruction.name(data.function.ptrConst(data.builder)).fmt(data.builder),
                });
            }
            pub fn fmt(
                self: Instruction.Index,
                function: Function.Index,
                builder: *Builder,
            ) std.fmt.Formatter(format) {
                return .{ .data = .{ .instruction = self, .function = function, .builder = builder } };
            }
        };

        pub const ExtraIndex = u32;

        pub const BrCond = struct {
            cond: Value,
            then: Block.Index,
            @"else": Block.Index,
        };

        pub const Switch = struct {
            val: Value,
            default: Block.Index,
            cases_len: u32,
            //case_vals: [cases_len]Constant,
            //case_blocks: [cases_len]Block.Index,
        };

        pub const Binary = struct {
            lhs: Value,
            rhs: Value,
        };

        pub const ExtractElement = struct {
            val: Value,
            index: Value,
        };

        pub const InsertElement = struct {
            val: Value,
            elem: Value,
            index: Value,
        };

        pub const ShuffleVector = struct {
            lhs: Value,
            rhs: Value,
            mask: Value,
        };

        pub const ExtractValue = struct {
            val: Value,
            indices_len: u32,
            //indices: [indices_len]u32,
        };

        pub const InsertValue = struct {
            val: Value,
            elem: Value,
            indices_len: u32,
            //indices: [indices_len]u32,
        };

        pub const Alloca = struct {
            type: Type,
            len: Value,
            info: Info,

            pub const Kind = enum { normal, inalloca };
            pub const Info = packed struct(u32) {
                alignment: Alignment,
                addr_space: AddrSpace,
                _: u2 = undefined,
            };
        };

        pub const Load = struct {
            info: MemoryAccessInfo,
            type: Type,
            ptr: Value,
        };

        pub const Store = struct {
            info: MemoryAccessInfo,
            val: Value,
            ptr: Value,
        };

        pub const CmpXchg = struct {
            info: MemoryAccessInfo,
            ptr: Value,
            cmp: Value,
            new: Value,

            pub const Kind = enum { strong, weak };
        };

        pub const AtomicRmw = struct {
            info: MemoryAccessInfo,
            ptr: Value,
            val: Value,

            pub const Operation = enum(u5) {
                xchg = 0,
                add = 1,
                sub = 2,
                @"and" = 3,
                nand = 4,
                @"or" = 5,
                xor = 6,
                max = 7,
                min = 8,
                umax = 9,
                umin = 10,
                fadd = 11,
                fsub = 12,
                fmax = 13,
                fmin = 14,
                none = std.math.maxInt(u5),
            };
        };

        pub const GetElementPtr = struct {
            type: Type,
            base: Value,
            indices_len: u32,
            //indices: [indices_len]Value,

            pub const Kind = Constant.GetElementPtr.Kind;
        };

        pub const Cast = struct {
            val: Value,
            type: Type,

            pub const Signedness = Constant.Cast.Signedness;
        };

        pub const Phi = struct {
            type: Type,
            //incoming_vals: [block.incoming]Value,
            //incoming_blocks: [block.incoming]Block.Index,
        };

        pub const Select = struct {
            cond: Value,
            lhs: Value,
            rhs: Value,
        };

        pub const Call = struct {
            info: Info,
            attributes: FunctionAttributes,
            ty: Type,
            callee: Value,
            args_len: u32,
            //args: [args_len]Value,

            pub const Kind = enum {
                normal,
                fast,
                musttail,
                musttail_fast,
                notail,
                notail_fast,
                tail,
                tail_fast,
            };
            pub const Info = packed struct(u32) {
                call_conv: CallConv,
                _: u22 = undefined,
            };
        };

        pub const VaArg = struct {
            list: Value,
            type: Type,
        };
    };

    pub fn deinit(self: *Function, gpa: Allocator) void {
        gpa.free(self.extra);
        gpa.free(self.debug_values);
        self.debug_locations.deinit(gpa);
        gpa.free(self.value_indices[0..self.instructions.len]);
        gpa.free(self.names[0..self.instructions.len]);
        self.instructions.deinit(gpa);
        gpa.free(self.blocks);
        self.* = undefined;
    }

    pub fn arg(self: *const Function, index: u32) Value {
        const argument = self.instructions.get(index);
        assert(argument.tag == .arg);
        assert(argument.data == index);

        const argument_index: Instruction.Index = @enumFromInt(index);
        return argument_index.toValue();
    }

    const ExtraDataTrail = struct {
        index: Instruction.ExtraIndex,

        fn nextMut(self: *ExtraDataTrail, len: u32, comptime Item: type, function: *Function) []Item {
            const items: []Item = @ptrCast(function.extra[self.index..][0..len]);
            self.index += @intCast(len);
            return items;
        }

        fn next(
            self: *ExtraDataTrail,
            len: u32,
            comptime Item: type,
            function: *const Function,
        ) []const Item {
            const items: []const Item = @ptrCast(function.extra[self.index..][0..len]);
            self.index += @intCast(len);
            return items;
        }
    };

    fn extraDataTrail(
        self: *const Function,
        comptime T: type,
        index: Instruction.ExtraIndex,
    ) struct { data: T, trail: ExtraDataTrail } {
        var result: T = undefined;
        const fields = @typeInfo(T).Struct.fields;
        inline for (fields, self.extra[index..][0..fields.len]) |field, value|
            @field(result, field.name) = switch (field.type) {
                u32 => value,
                Alignment,
                AtomicOrdering,
                Block.Index,
                FunctionAttributes,
                Type,
                Value,
                => @enumFromInt(value),
                MemoryAccessInfo,
                Instruction.Alloca.Info,
                Instruction.Call.Info,
                => @bitCast(value),
                else => @compileError("bad field type: " ++ field.name ++ ": " ++ @typeName(field.type)),
            };
        return .{
            .data = result,
            .trail = .{ .index = index + @as(Type.Item.ExtraIndex, @intCast(fields.len)) },
        };
    }

    fn extraData(self: *const Function, comptime T: type, index: Instruction.ExtraIndex) T {
        return self.extraDataTrail(T, index).data;
    }
};

pub const DebugLocation = union(enum) {
    no_location: void,
    location: Location,

    pub const Location = struct {
        line: u32,
        column: u32,
        scope: Builder.Metadata,
        inlined_at: Builder.Metadata,
    };

    pub fn toMetadata(self: DebugLocation, builder: *Builder) Allocator.Error!Metadata {
        return switch (self) {
            .no_location => .none,
            .location => |location| try builder.debugLocation(
                location.line,
                location.column,
                location.scope,
                location.inlined_at,
            ),
        };
    }
};

pub const WipFunction = struct {
    builder: *Builder,
    function: Function.Index,
    prev_debug_location: DebugLocation,
    debug_location: DebugLocation,
    cursor: Cursor,
    blocks: std.ArrayListUnmanaged(Block),
    instructions: std.MultiArrayList(Instruction),
    names: std.ArrayListUnmanaged(String),
    strip: bool,
    debug_locations: std.AutoArrayHashMapUnmanaged(Instruction.Index, DebugLocation),
    debug_values: std.AutoArrayHashMapUnmanaged(Instruction.Index, void),
    extra: std.ArrayListUnmanaged(u32),

    pub const Cursor = struct { block: Block.Index, instruction: u32 = 0 };

    pub const Block = struct {
        name: String,
        incoming: u32,
        branches: u32 = 0,
        instructions: std.ArrayListUnmanaged(Instruction.Index),

        const Index = enum(u32) {
            entry,
            _,

            pub fn ptr(self: Index, wip: *WipFunction) *Block {
                return &wip.blocks.items[@intFromEnum(self)];
            }

            pub fn ptrConst(self: Index, wip: *const WipFunction) *const Block {
                return &wip.blocks.items[@intFromEnum(self)];
            }

            pub fn toInst(self: Index, function: *const Function) Instruction.Index {
                return function.blocks[@intFromEnum(self)].instruction;
            }
        };
    };

    pub const Instruction = Function.Instruction;

    pub fn init(builder: *Builder, options: struct {
        function: Function.Index,
        strip: bool,
    }) Allocator.Error!WipFunction {
        var self: WipFunction = .{
            .builder = builder,
            .function = options.function,
            .prev_debug_location = .no_location,
            .debug_location = .no_location,
            .cursor = undefined,
            .blocks = .{},
            .instructions = .{},
            .names = .{},
            .strip = options.strip,
            .debug_locations = .{},
            .debug_values = .{},
            .extra = .{},
        };
        errdefer self.deinit();

        const params_len = options.function.typeOf(self.builder).functionParameters(self.builder).len;
        try self.ensureUnusedExtraCapacity(params_len, NoExtra, 0);
        try self.instructions.ensureUnusedCapacity(self.builder.gpa, params_len);
        if (!self.strip) {
            try self.names.ensureUnusedCapacity(self.builder.gpa, params_len);
        }
        for (0..params_len) |param_index| {
            self.instructions.appendAssumeCapacity(.{ .tag = .arg, .data = @intCast(param_index) });
            if (!self.strip) {
                self.names.appendAssumeCapacity(.empty); // TODO: param names
            }
        }

        return self;
    }

    pub fn arg(self: *const WipFunction, index: u32) Value {
        const argument = self.instructions.get(index);
        assert(argument.tag == .arg);
        assert(argument.data == index);

        const argument_index: Instruction.Index = @enumFromInt(index);
        return argument_index.toValue();
    }

    pub fn block(self: *WipFunction, incoming: u32, name: []const u8) Allocator.Error!Block.Index {
        try self.blocks.ensureUnusedCapacity(self.builder.gpa, 1);

        const index: Block.Index = @enumFromInt(self.blocks.items.len);
        const final_name = if (self.strip) .empty else try self.builder.string(name);
        self.blocks.appendAssumeCapacity(.{
            .name = final_name,
            .incoming = incoming,
            .instructions = .{},
        });
        return index;
    }

    pub fn ret(self: *WipFunction, val: Value) Allocator.Error!Instruction.Index {
        assert(val.typeOfWip(self) == self.function.typeOf(self.builder).functionReturn(self.builder));
        try self.ensureUnusedExtraCapacity(1, NoExtra, 0);
        return try self.addInst(null, .{ .tag = .ret, .data = @intFromEnum(val) });
    }

    pub fn retVoid(self: *WipFunction) Allocator.Error!Instruction.Index {
        try self.ensureUnusedExtraCapacity(1, NoExtra, 0);
        return try self.addInst(null, .{ .tag = .@"ret void", .data = undefined });
    }

    pub fn br(self: *WipFunction, dest: Block.Index) Allocator.Error!Instruction.Index {
        try self.ensureUnusedExtraCapacity(1, NoExtra, 0);
        const instruction = try self.addInst(null, .{ .tag = .br, .data = @intFromEnum(dest) });
        dest.ptr(self).branches += 1;
        return instruction;
    }

    pub fn brCond(
        self: *WipFunction,
        cond: Value,
        then: Block.Index,
        @"else": Block.Index,
    ) Allocator.Error!Instruction.Index {
        assert(cond.typeOfWip(self) == .i1);
        try self.ensureUnusedExtraCapacity(1, Instruction.BrCond, 0);
        const instruction = try self.addInst(null, .{
            .tag = .br_cond,
            .data = self.addExtraAssumeCapacity(Instruction.BrCond{
                .cond = cond,
                .then = then,
                .@"else" = @"else",
            }),
        });
        then.ptr(self).branches += 1;
        @"else".ptr(self).branches += 1;
        return instruction;
    }

    pub const WipSwitch = struct {
        index: u32,
        instruction: Instruction.Index,

        pub fn addCase(
            self: *WipSwitch,
            val: Constant,
            dest: Block.Index,
            wip: *WipFunction,
        ) Allocator.Error!void {
            const instruction = wip.instructions.get(@intFromEnum(self.instruction));
            var extra = wip.extraDataTrail(Instruction.Switch, instruction.data);
            assert(val.typeOf(wip.builder) == extra.data.val.typeOfWip(wip));
            extra.trail.nextMut(extra.data.cases_len, Constant, wip)[self.index] = val;
            extra.trail.nextMut(extra.data.cases_len, Block.Index, wip)[self.index] = dest;
            self.index += 1;
            dest.ptr(wip).branches += 1;
        }

        pub fn finish(self: WipSwitch, wip: *WipFunction) void {
            const instruction = wip.instructions.get(@intFromEnum(self.instruction));
            const extra = wip.extraData(Instruction.Switch, instruction.data);
            assert(self.index == extra.cases_len);
        }
    };

    pub fn @"switch"(
        self: *WipFunction,
        val: Value,
        default: Block.Index,
        cases_len: u32,
    ) Allocator.Error!WipSwitch {
        try self.ensureUnusedExtraCapacity(1, Instruction.Switch, cases_len * 2);
        const instruction = try self.addInst(null, .{
            .tag = .@"switch",
            .data = self.addExtraAssumeCapacity(Instruction.Switch{
                .val = val,
                .default = default,
                .cases_len = cases_len,
            }),
        });
        _ = self.extra.addManyAsSliceAssumeCapacity(cases_len * 2);
        default.ptr(self).branches += 1;
        return .{ .index = 0, .instruction = instruction };
    }

    pub fn @"unreachable"(self: *WipFunction) Allocator.Error!Instruction.Index {
        try self.ensureUnusedExtraCapacity(1, NoExtra, 0);
        const instruction = try self.addInst(null, .{ .tag = .@"unreachable", .data = undefined });
        return instruction;
    }

    pub fn un(
        self: *WipFunction,
        tag: Instruction.Tag,
        val: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        switch (tag) {
            .fneg,
            .@"fneg fast",
            => assert(val.typeOfWip(self).scalarType(self.builder).isFloatingPoint()),
            else => unreachable,
        }
        try self.ensureUnusedExtraCapacity(1, NoExtra, 0);
        const instruction = try self.addInst(name, .{ .tag = tag, .data = @intFromEnum(val) });
        return instruction.toValue();
    }

    pub fn not(self: *WipFunction, val: Value, name: []const u8) Allocator.Error!Value {
        const ty = val.typeOfWip(self);
        const all_ones = try self.builder.splatValue(
            ty,
            try self.builder.intConst(ty.scalarType(self.builder), -1),
        );
        return self.bin(.xor, val, all_ones, name);
    }

    pub fn neg(self: *WipFunction, val: Value, name: []const u8) Allocator.Error!Value {
        return self.bin(.sub, try self.builder.zeroInitValue(val.typeOfWip(self)), val, name);
    }

    pub fn bin(
        self: *WipFunction,
        tag: Instruction.Tag,
        lhs: Value,
        rhs: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        switch (tag) {
            .add,
            .@"add nsw",
            .@"add nuw",
            .@"and",
            .ashr,
            .@"ashr exact",
            .fadd,
            .@"fadd fast",
            .fdiv,
            .@"fdiv fast",
            .fmul,
            .@"fmul fast",
            .frem,
            .@"frem fast",
            .fsub,
            .@"fsub fast",
            .lshr,
            .@"lshr exact",
            .mul,
            .@"mul nsw",
            .@"mul nuw",
            .@"or",
            .sdiv,
            .@"sdiv exact",
            .shl,
            .@"shl nsw",
            .@"shl nuw",
            .srem,
            .sub,
            .@"sub nsw",
            .@"sub nuw",
            .udiv,
            .@"udiv exact",
            .urem,
            .xor,
            => assert(lhs.typeOfWip(self) == rhs.typeOfWip(self)),
            else => unreachable,
        }
        try self.ensureUnusedExtraCapacity(1, Instruction.Binary, 0);
        const instruction = try self.addInst(name, .{
            .tag = tag,
            .data = self.addExtraAssumeCapacity(Instruction.Binary{ .lhs = lhs, .rhs = rhs }),
        });
        return instruction.toValue();
    }

    pub fn extractElement(
        self: *WipFunction,
        val: Value,
        index: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        assert(val.typeOfWip(self).isVector(self.builder));
        assert(index.typeOfWip(self).isInteger(self.builder));
        try self.ensureUnusedExtraCapacity(1, Instruction.ExtractElement, 0);
        const instruction = try self.addInst(name, .{
            .tag = .extractelement,
            .data = self.addExtraAssumeCapacity(Instruction.ExtractElement{
                .val = val,
                .index = index,
            }),
        });
        return instruction.toValue();
    }

    pub fn insertElement(
        self: *WipFunction,
        val: Value,
        elem: Value,
        index: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        assert(val.typeOfWip(self).scalarType(self.builder) == elem.typeOfWip(self));
        assert(index.typeOfWip(self).isInteger(self.builder));
        try self.ensureUnusedExtraCapacity(1, Instruction.InsertElement, 0);
        const instruction = try self.addInst(name, .{
            .tag = .insertelement,
            .data = self.addExtraAssumeCapacity(Instruction.InsertElement{
                .val = val,
                .elem = elem,
                .index = index,
            }),
        });
        return instruction.toValue();
    }

    pub fn shuffleVector(
        self: *WipFunction,
        lhs: Value,
        rhs: Value,
        mask: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        assert(lhs.typeOfWip(self).isVector(self.builder));
        assert(lhs.typeOfWip(self) == rhs.typeOfWip(self));
        assert(mask.typeOfWip(self).scalarType(self.builder).isInteger(self.builder));
        _ = try self.ensureUnusedExtraCapacity(1, Instruction.ShuffleVector, 0);
        const instruction = try self.addInst(name, .{
            .tag = .shufflevector,
            .data = self.addExtraAssumeCapacity(Instruction.ShuffleVector{
                .lhs = lhs,
                .rhs = rhs,
                .mask = mask,
            }),
        });
        return instruction.toValue();
    }

    pub fn splatVector(
        self: *WipFunction,
        ty: Type,
        elem: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        const scalar_ty = try ty.changeLength(1, self.builder);
        const mask_ty = try ty.changeScalar(.i32, self.builder);
        const poison = try self.builder.poisonValue(scalar_ty);
        const mask = try self.builder.splatValue(mask_ty, .@"0");
        const scalar = try self.insertElement(poison, elem, .@"0", name);
        return self.shuffleVector(scalar, poison, mask, name);
    }

    pub fn extractValue(
        self: *WipFunction,
        val: Value,
        indices: []const u32,
        name: []const u8,
    ) Allocator.Error!Value {
        assert(indices.len > 0);
        _ = val.typeOfWip(self).childTypeAt(indices, self.builder);
        try self.ensureUnusedExtraCapacity(1, Instruction.ExtractValue, indices.len);
        const instruction = try self.addInst(name, .{
            .tag = .extractvalue,
            .data = self.addExtraAssumeCapacity(Instruction.ExtractValue{
                .val = val,
                .indices_len = @intCast(indices.len),
            }),
        });
        self.extra.appendSliceAssumeCapacity(indices);
        return instruction.toValue();
    }

    pub fn insertValue(
        self: *WipFunction,
        val: Value,
        elem: Value,
        indices: []const u32,
        name: []const u8,
    ) Allocator.Error!Value {
        assert(indices.len > 0);
        assert(val.typeOfWip(self).childTypeAt(indices, self.builder) == elem.typeOfWip(self));
        try self.ensureUnusedExtraCapacity(1, Instruction.InsertValue, indices.len);
        const instruction = try self.addInst(name, .{
            .tag = .insertvalue,
            .data = self.addExtraAssumeCapacity(Instruction.InsertValue{
                .val = val,
                .elem = elem,
                .indices_len = @intCast(indices.len),
            }),
        });
        self.extra.appendSliceAssumeCapacity(indices);
        return instruction.toValue();
    }

    pub fn buildAggregate(
        self: *WipFunction,
        ty: Type,
        elems: []const Value,
        name: []const u8,
    ) Allocator.Error!Value {
        assert(ty.aggregateLen(self.builder) == elems.len);
        var cur = try self.builder.poisonValue(ty);
        for (elems, 0..) |elem, index|
            cur = try self.insertValue(cur, elem, &[_]u32{@intCast(index)}, name);
        return cur;
    }

    pub fn alloca(
        self: *WipFunction,
        kind: Instruction.Alloca.Kind,
        ty: Type,
        len: Value,
        alignment: Alignment,
        addr_space: AddrSpace,
        name: []const u8,
    ) Allocator.Error!Value {
        assert(len == .none or len.typeOfWip(self).isInteger(self.builder));
        _ = try self.builder.ptrType(addr_space);
        try self.ensureUnusedExtraCapacity(1, Instruction.Alloca, 0);
        const instruction = try self.addInst(name, .{
            .tag = switch (kind) {
                .normal => .alloca,
                .inalloca => .@"alloca inalloca",
            },
            .data = self.addExtraAssumeCapacity(Instruction.Alloca{
                .type = ty,
                .len = switch (len) {
                    .none => .@"1",
                    else => len,
                },
                .info = .{ .alignment = alignment, .addr_space = addr_space },
            }),
        });
        return instruction.toValue();
    }

    pub fn load(
        self: *WipFunction,
        access_kind: MemoryAccessKind,
        ty: Type,
        ptr: Value,
        alignment: Alignment,
        name: []const u8,
    ) Allocator.Error!Value {
        return self.loadAtomic(access_kind, ty, ptr, .system, .none, alignment, name);
    }

    pub fn loadAtomic(
        self: *WipFunction,
        access_kind: MemoryAccessKind,
        ty: Type,
        ptr: Value,
        sync_scope: SyncScope,
        ordering: AtomicOrdering,
        alignment: Alignment,
        name: []const u8,
    ) Allocator.Error!Value {
        assert(ptr.typeOfWip(self).isPointer(self.builder));
        try self.ensureUnusedExtraCapacity(1, Instruction.Load, 0);
        const instruction = try self.addInst(name, .{
            .tag = switch (ordering) {
                .none => .load,
                else => .@"load atomic",
            },
            .data = self.addExtraAssumeCapacity(Instruction.Load{
                .info = .{
                    .access_kind = access_kind,
                    .sync_scope = switch (ordering) {
                        .none => .system,
                        else => sync_scope,
                    },
                    .success_ordering = ordering,
                    .alignment = alignment,
                },
                .type = ty,
                .ptr = ptr,
            }),
        });
        return instruction.toValue();
    }

    pub fn store(
        self: *WipFunction,
        kind: MemoryAccessKind,
        val: Value,
        ptr: Value,
        alignment: Alignment,
    ) Allocator.Error!Instruction.Index {
        return self.storeAtomic(kind, val, ptr, .system, .none, alignment);
    }

    pub fn storeAtomic(
        self: *WipFunction,
        access_kind: MemoryAccessKind,
        val: Value,
        ptr: Value,
        sync_scope: SyncScope,
        ordering: AtomicOrdering,
        alignment: Alignment,
    ) Allocator.Error!Instruction.Index {
        assert(ptr.typeOfWip(self).isPointer(self.builder));
        try self.ensureUnusedExtraCapacity(1, Instruction.Store, 0);
        const instruction = try self.addInst(null, .{
            .tag = switch (ordering) {
                .none => .store,
                else => .@"store atomic",
            },
            .data = self.addExtraAssumeCapacity(Instruction.Store{
                .info = .{
                    .access_kind = access_kind,
                    .sync_scope = switch (ordering) {
                        .none => .system,
                        else => sync_scope,
                    },
                    .success_ordering = ordering,
                    .alignment = alignment,
                },
                .val = val,
                .ptr = ptr,
            }),
        });
        return instruction;
    }

    pub fn fence(
        self: *WipFunction,
        sync_scope: SyncScope,
        ordering: AtomicOrdering,
    ) Allocator.Error!Instruction.Index {
        assert(ordering != .none);
        try self.ensureUnusedExtraCapacity(1, NoExtra, 0);
        const instruction = try self.addInst(null, .{
            .tag = .fence,
            .data = @bitCast(MemoryAccessInfo{
                .sync_scope = sync_scope,
                .success_ordering = ordering,
            }),
        });
        return instruction;
    }

    pub fn cmpxchg(
        self: *WipFunction,
        kind: Instruction.CmpXchg.Kind,
        access_kind: MemoryAccessKind,
        ptr: Value,
        cmp: Value,
        new: Value,
        sync_scope: SyncScope,
        success_ordering: AtomicOrdering,
        failure_ordering: AtomicOrdering,
        alignment: Alignment,
        name: []const u8,
    ) Allocator.Error!Value {
        assert(ptr.typeOfWip(self).isPointer(self.builder));
        const ty = cmp.typeOfWip(self);
        assert(ty == new.typeOfWip(self));
        assert(success_ordering != .none);
        assert(failure_ordering != .none);

        _ = try self.builder.structType(.normal, &.{ ty, .i1 });
        try self.ensureUnusedExtraCapacity(1, Instruction.CmpXchg, 0);
        const instruction = try self.addInst(name, .{
            .tag = switch (kind) {
                .strong => .cmpxchg,
                .weak => .@"cmpxchg weak",
            },
            .data = self.addExtraAssumeCapacity(Instruction.CmpXchg{
                .info = .{
                    .access_kind = access_kind,
                    .sync_scope = sync_scope,
                    .success_ordering = success_ordering,
                    .failure_ordering = failure_ordering,
                    .alignment = alignment,
                },
                .ptr = ptr,
                .cmp = cmp,
                .new = new,
            }),
        });
        return instruction.toValue();
    }

    pub fn atomicrmw(
        self: *WipFunction,
        access_kind: MemoryAccessKind,
        operation: Instruction.AtomicRmw.Operation,
        ptr: Value,
        val: Value,
        sync_scope: SyncScope,
        ordering: AtomicOrdering,
        alignment: Alignment,
        name: []const u8,
    ) Allocator.Error!Value {
        assert(ptr.typeOfWip(self).isPointer(self.builder));
        assert(ordering != .none);

        try self.ensureUnusedExtraCapacity(1, Instruction.AtomicRmw, 0);
        const instruction = try self.addInst(name, .{
            .tag = .atomicrmw,
            .data = self.addExtraAssumeCapacity(Instruction.AtomicRmw{
                .info = .{
                    .access_kind = access_kind,
                    .atomic_rmw_operation = operation,
                    .sync_scope = sync_scope,
                    .success_ordering = ordering,
                    .alignment = alignment,
                },
                .ptr = ptr,
                .val = val,
            }),
        });
        return instruction.toValue();
    }

    pub fn gep(
        self: *WipFunction,
        kind: Instruction.GetElementPtr.Kind,
        ty: Type,
        base: Value,
        indices: []const Value,
        name: []const u8,
    ) Allocator.Error!Value {
        const base_ty = base.typeOfWip(self);
        const base_is_vector = base_ty.isVector(self.builder);

        const VectorInfo = struct {
            kind: Type.Vector.Kind,
            len: u32,

            fn init(vector_ty: Type, builder: *const Builder) @This() {
                return .{ .kind = vector_ty.vectorKind(builder), .len = vector_ty.vectorLen(builder) };
            }
        };
        var vector_info: ?VectorInfo =
            if (base_is_vector) VectorInfo.init(base_ty, self.builder) else null;
        for (indices) |index| {
            const index_ty = index.typeOfWip(self);
            switch (index_ty.tag(self.builder)) {
                .integer => {},
                .vector, .scalable_vector => {
                    const index_info = VectorInfo.init(index_ty, self.builder);
                    if (vector_info) |info|
                        assert(std.meta.eql(info, index_info))
                    else
                        vector_info = index_info;
                },
                else => unreachable,
            }
        }
        if (!base_is_vector) if (vector_info) |info| switch (info.kind) {
            inline else => |vector_kind| _ = try self.builder.vectorType(
                vector_kind,
                info.len,
                base_ty,
            ),
        };

        try self.ensureUnusedExtraCapacity(1, Instruction.GetElementPtr, indices.len);
        const instruction = try self.addInst(name, .{
            .tag = switch (kind) {
                .normal => .getelementptr,
                .inbounds => .@"getelementptr inbounds",
            },
            .data = self.addExtraAssumeCapacity(Instruction.GetElementPtr{
                .type = ty,
                .base = base,
                .indices_len = @intCast(indices.len),
            }),
        });
        self.extra.appendSliceAssumeCapacity(@ptrCast(indices));
        return instruction.toValue();
    }

    pub fn gepStruct(
        self: *WipFunction,
        ty: Type,
        base: Value,
        index: usize,
        name: []const u8,
    ) Allocator.Error!Value {
        assert(ty.isStruct(self.builder));
        return self.gep(.inbounds, ty, base, &.{ .@"0", try self.builder.intValue(.i32, index) }, name);
    }

    pub fn conv(
        self: *WipFunction,
        signedness: Instruction.Cast.Signedness,
        val: Value,
        ty: Type,
        name: []const u8,
    ) Allocator.Error!Value {
        const val_ty = val.typeOfWip(self);
        if (val_ty == ty) return val;
        return self.cast(self.builder.convTag(signedness, val_ty, ty), val, ty, name);
    }

    pub fn cast(
        self: *WipFunction,
        tag: Instruction.Tag,
        val: Value,
        ty: Type,
        name: []const u8,
    ) Allocator.Error!Value {
        switch (tag) {
            .addrspacecast,
            .bitcast,
            .fpext,
            .fptosi,
            .fptoui,
            .fptrunc,
            .inttoptr,
            .ptrtoint,
            .sext,
            .sitofp,
            .trunc,
            .uitofp,
            .zext,
            => {},
            else => unreachable,
        }
        if (val.typeOfWip(self) == ty) return val;
        try self.ensureUnusedExtraCapacity(1, Instruction.Cast, 0);
        const instruction = try self.addInst(name, .{
            .tag = tag,
            .data = self.addExtraAssumeCapacity(Instruction.Cast{
                .val = val,
                .type = ty,
            }),
        });
        return instruction.toValue();
    }

    pub fn icmp(
        self: *WipFunction,
        cond: IntegerCondition,
        lhs: Value,
        rhs: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        return self.cmpTag(switch (cond) {
            inline else => |tag| @field(Instruction.Tag, "icmp " ++ @tagName(tag)),
        }, lhs, rhs, name);
    }

    pub fn fcmp(
        self: *WipFunction,
        fast: FastMathKind,
        cond: FloatCondition,
        lhs: Value,
        rhs: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        return self.cmpTag(switch (fast) {
            inline else => |fast_tag| switch (cond) {
                inline else => |cond_tag| @field(Instruction.Tag, "fcmp " ++ switch (fast_tag) {
                    .normal => "",
                    .fast => "fast ",
                } ++ @tagName(cond_tag)),
            },
        }, lhs, rhs, name);
    }

    pub const WipPhi = struct {
        block: Block.Index,
        instruction: Instruction.Index,

        pub fn toValue(self: WipPhi) Value {
            return self.instruction.toValue();
        }

        pub fn finish(
            self: WipPhi,
            vals: []const Value,
            blocks: []const Block.Index,
            wip: *WipFunction,
        ) void {
            const incoming_len = self.block.ptrConst(wip).incoming;
            assert(vals.len == incoming_len and blocks.len == incoming_len);
            const instruction = wip.instructions.get(@intFromEnum(self.instruction));
            var extra = wip.extraDataTrail(Instruction.Phi, instruction.data);
            for (vals) |val| assert(val.typeOfWip(wip) == extra.data.type);
            @memcpy(extra.trail.nextMut(incoming_len, Value, wip), vals);
            @memcpy(extra.trail.nextMut(incoming_len, Block.Index, wip), blocks);
        }
    };

    pub fn phi(self: *WipFunction, ty: Type, name: []const u8) Allocator.Error!WipPhi {
        return self.phiTag(.phi, ty, name);
    }

    pub fn phiFast(self: *WipFunction, ty: Type, name: []const u8) Allocator.Error!WipPhi {
        return self.phiTag(.@"phi fast", ty, name);
    }

    pub fn select(
        self: *WipFunction,
        fast: FastMathKind,
        cond: Value,
        lhs: Value,
        rhs: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        return self.selectTag(switch (fast) {
            .normal => .select,
            .fast => .@"select fast",
        }, cond, lhs, rhs, name);
    }

    pub fn call(
        self: *WipFunction,
        kind: Instruction.Call.Kind,
        call_conv: CallConv,
        function_attributes: FunctionAttributes,
        ty: Type,
        callee: Value,
        args: []const Value,
        name: []const u8,
    ) Allocator.Error!Value {
        const ret_ty = ty.functionReturn(self.builder);
        assert(ty.isFunction(self.builder));
        assert(callee.typeOfWip(self).isPointer(self.builder));
        const params = ty.functionParameters(self.builder);
        for (params, args[0..params.len]) |param, arg_val| assert(param == arg_val.typeOfWip(self));

        try self.ensureUnusedExtraCapacity(1, Instruction.Call, args.len);
        const instruction = try self.addInst(switch (ret_ty) {
            .void => null,
            else => name,
        }, .{
            .tag = switch (kind) {
                .normal => .call,
                .fast => .@"call fast",
                .musttail => .@"musttail call",
                .musttail_fast => .@"musttail call fast",
                .notail => .@"notail call",
                .notail_fast => .@"notail call fast",
                .tail => .@"tail call",
                .tail_fast => .@"tail call fast",
            },
            .data = self.addExtraAssumeCapacity(Instruction.Call{
                .info = .{ .call_conv = call_conv },
                .attributes = function_attributes,
                .ty = ty,
                .callee = callee,
                .args_len = @intCast(args.len),
            }),
        });
        self.extra.appendSliceAssumeCapacity(@ptrCast(args));
        return instruction.toValue();
    }

    pub fn callAsm(
        self: *WipFunction,
        function_attributes: FunctionAttributes,
        ty: Type,
        kind: Constant.Assembly.Info,
        assembly: String,
        constraints: String,
        args: []const Value,
        name: []const u8,
    ) Allocator.Error!Value {
        const callee = try self.builder.asmValue(ty, kind, assembly, constraints);
        return self.call(.normal, CallConv.default, function_attributes, ty, callee, args, name);
    }

    pub fn callIntrinsic(
        self: *WipFunction,
        fast: FastMathKind,
        function_attributes: FunctionAttributes,
        id: Intrinsic,
        overload: []const Type,
        args: []const Value,
        name: []const u8,
    ) Allocator.Error!Value {
        const intrinsic = try self.builder.getIntrinsic(id, overload);
        return self.call(
            fast.toCallKind(),
            CallConv.default,
            function_attributes,
            intrinsic.typeOf(self.builder),
            intrinsic.toValue(self.builder),
            args,
            name,
        );
    }

    pub fn callMemCpy(
        self: *WipFunction,
        dst: Value,
        dst_align: Alignment,
        src: Value,
        src_align: Alignment,
        len: Value,
        kind: MemoryAccessKind,
    ) Allocator.Error!Instruction.Index {
        var dst_attrs = [_]Attribute.Index{try self.builder.attr(.{ .@"align" = dst_align })};
        var src_attrs = [_]Attribute.Index{try self.builder.attr(.{ .@"align" = src_align })};
        const value = try self.callIntrinsic(
            .normal,
            try self.builder.fnAttrs(&.{
                .none,
                .none,
                try self.builder.attrs(&dst_attrs),
                try self.builder.attrs(&src_attrs),
            }),
            .memcpy,
            &.{ dst.typeOfWip(self), src.typeOfWip(self), len.typeOfWip(self) },
            &.{ dst, src, len, switch (kind) {
                .normal => Value.false,
                .@"volatile" => Value.true,
            } },
            undefined,
        );
        return value.unwrap().instruction;
    }

    pub fn callMemSet(
        self: *WipFunction,
        dst: Value,
        dst_align: Alignment,
        val: Value,
        len: Value,
        kind: MemoryAccessKind,
    ) Allocator.Error!Instruction.Index {
        var dst_attrs = [_]Attribute.Index{try self.builder.attr(.{ .@"align" = dst_align })};
        const value = try self.callIntrinsic(
            .normal,
            try self.builder.fnAttrs(&.{ .none, .none, try self.builder.attrs(&dst_attrs) }),
            .memset,
            &.{ dst.typeOfWip(self), len.typeOfWip(self) },
            &.{ dst, val, len, switch (kind) {
                .normal => Value.false,
                .@"volatile" => Value.true,
            } },
            undefined,
        );
        return value.unwrap().instruction;
    }

    pub fn vaArg(self: *WipFunction, list: Value, ty: Type, name: []const u8) Allocator.Error!Value {
        try self.ensureUnusedExtraCapacity(1, Instruction.VaArg, 0);
        const instruction = try self.addInst(name, .{
            .tag = .va_arg,
            .data = self.addExtraAssumeCapacity(Instruction.VaArg{
                .list = list,
                .type = ty,
            }),
        });
        return instruction.toValue();
    }

    pub fn debugValue(self: *WipFunction, value: Value) Allocator.Error!Metadata {
        if (self.strip) return .none;
        return switch (value.unwrap()) {
            .instruction => |instr_index| blk: {
                const gop = try self.debug_values.getOrPut(self.builder.gpa, instr_index);

                const metadata: Metadata = @enumFromInt(Metadata.first_local_metadata + gop.index);
                if (!gop.found_existing) gop.key_ptr.* = instr_index;

                break :blk metadata;
            },
            .constant => |constant| try self.builder.debugConstant(constant),
            .metadata => |metadata| metadata,
        };
    }

    pub fn finish(self: *WipFunction) Allocator.Error!void {
        const gpa = self.builder.gpa;
        const function = self.function.ptr(self.builder);
        const params_len = self.function.typeOf(self.builder).functionParameters(self.builder).len;
        const final_instructions_len = self.blocks.items.len + self.instructions.len;

        const blocks = try gpa.alloc(Function.Block, self.blocks.items.len);
        errdefer gpa.free(blocks);

        const instructions: struct {
            items: []Instruction.Index,

            fn map(instructions: @This(), val: Value) Value {
                if (val == .none) return .none;
                return switch (val.unwrap()) {
                    .instruction => |instruction| instructions.items[
                        @intFromEnum(instruction)
                    ].toValue(),
                    .constant => |constant| constant.toValue(),
                    .metadata => |metadata| metadata.toValue(),
                };
            }
        } = .{ .items = try gpa.alloc(Instruction.Index, self.instructions.len) };
        defer gpa.free(instructions.items);

        const names = try gpa.alloc(String, final_instructions_len);
        errdefer gpa.free(names);

        const value_indices = try gpa.alloc(u32, final_instructions_len);
        errdefer gpa.free(value_indices);

        var debug_locations: std.AutoHashMapUnmanaged(Instruction.Index, DebugLocation) = .{};
        errdefer debug_locations.deinit(gpa);
        try debug_locations.ensureUnusedCapacity(gpa, @intCast(self.debug_locations.count()));

        const debug_values = try gpa.alloc(Instruction.Index, self.debug_values.count());
        errdefer gpa.free(debug_values);

        var wip_extra: struct {
            index: Instruction.ExtraIndex = 0,
            items: []u32,

            fn addExtra(wip_extra: *@This(), extra: anytype) Instruction.ExtraIndex {
                const result = wip_extra.index;
                inline for (@typeInfo(@TypeOf(extra)).Struct.fields) |field| {
                    const value = @field(extra, field.name);
                    wip_extra.items[wip_extra.index] = switch (field.type) {
                        u32 => value,
                        Alignment,
                        AtomicOrdering,
                        Block.Index,
                        FunctionAttributes,
                        Type,
                        Value,
                        => @intFromEnum(value),
                        MemoryAccessInfo,
                        Instruction.Alloca.Info,
                        Instruction.Call.Info,
                        => @bitCast(value),
                        else => @compileError("bad field type: " ++ field.name ++ ": " ++ @typeName(field.type)),
                    };
                    wip_extra.index += 1;
                }
                return result;
            }

            fn appendSlice(wip_extra: *@This(), slice: anytype) void {
                if (@typeInfo(@TypeOf(slice)).Pointer.child == Value)
                    @compileError("use appendMappedValues");
                const data: []const u32 = @ptrCast(slice);
                @memcpy(wip_extra.items[wip_extra.index..][0..data.len], data);
                wip_extra.index += @intCast(data.len);
            }

            fn appendMappedValues(wip_extra: *@This(), vals: []const Value, ctx: anytype) void {
                for (wip_extra.items[wip_extra.index..][0..vals.len], vals) |*extra, val|
                    extra.* = @intFromEnum(ctx.map(val));
                wip_extra.index += @intCast(vals.len);
            }

            fn finish(wip_extra: *const @This()) []const u32 {
                assert(wip_extra.index == wip_extra.items.len);
                return wip_extra.items;
            }
        } = .{ .items = try gpa.alloc(u32, self.extra.items.len) };
        errdefer gpa.free(wip_extra.items);

        gpa.free(function.blocks);
        function.blocks = &.{};
        gpa.free(function.names[0..function.instructions.len]);
        function.debug_locations.deinit(gpa);
        function.debug_locations = .{};
        gpa.free(function.debug_values);
        function.debug_values = &.{};
        gpa.free(function.extra);
        function.extra = &.{};

        function.instructions.shrinkRetainingCapacity(0);
        try function.instructions.setCapacity(gpa, final_instructions_len);
        errdefer function.instructions.shrinkRetainingCapacity(0);

        {
            var final_instruction_index: Instruction.Index = @enumFromInt(0);
            for (0..params_len) |param_index| {
                instructions.items[param_index] = final_instruction_index;
                final_instruction_index = @enumFromInt(@intFromEnum(final_instruction_index) + 1);
            }
            for (blocks, self.blocks.items) |*final_block, current_block| {
                assert(current_block.incoming == current_block.branches);
                final_block.instruction = final_instruction_index;
                final_instruction_index = @enumFromInt(@intFromEnum(final_instruction_index) + 1);
                for (current_block.instructions.items) |instruction| {
                    instructions.items[@intFromEnum(instruction)] = final_instruction_index;
                    final_instruction_index = @enumFromInt(@intFromEnum(final_instruction_index) + 1);
                }
            }
        }

        var wip_name: struct {
            next_name: String = @enumFromInt(0),
            next_unique_name: std.AutoHashMap(String, String),
            builder: *Builder,

            fn map(wip_name: *@This(), name: String, sep: []const u8) Allocator.Error!String {
                switch (name) {
                    .none => return .none,
                    .empty => {
                        assert(wip_name.next_name != .none);
                        defer wip_name.next_name = @enumFromInt(@intFromEnum(wip_name.next_name) + 1);
                        return wip_name.next_name;
                    },
                    _ => {
                        assert(!name.isAnon());
                        const gop = try wip_name.next_unique_name.getOrPut(name);
                        if (!gop.found_existing) {
                            gop.value_ptr.* = @enumFromInt(0);
                            return name;
                        }

                        while (true) {
                            gop.value_ptr.* = @enumFromInt(@intFromEnum(gop.value_ptr.*) + 1);
                            const unique_name = try wip_name.builder.fmt("{r}{s}{r}", .{
                                name.fmt(wip_name.builder),
                                sep,
                                gop.value_ptr.fmt(wip_name.builder),
                            });
                            const unique_gop = try wip_name.next_unique_name.getOrPut(unique_name);
                            if (!unique_gop.found_existing) {
                                unique_gop.value_ptr.* = @enumFromInt(0);
                                return unique_name;
                            }
                        }
                    },
                }
            }
        } = .{
            .next_unique_name = std.AutoHashMap(String, String).init(gpa),
            .builder = self.builder,
        };
        defer wip_name.next_unique_name.deinit();

        var value_index: u32 = 0;
        for (0..params_len) |param_index| {
            const old_argument_index: Instruction.Index = @enumFromInt(param_index);
            const new_argument_index: Instruction.Index = @enumFromInt(function.instructions.len);
            const argument = self.instructions.get(@intFromEnum(old_argument_index));
            assert(argument.tag == .arg);
            assert(argument.data == param_index);
            value_indices[function.instructions.len] = value_index;
            value_index += 1;
            function.instructions.appendAssumeCapacity(argument);
            names[@intFromEnum(new_argument_index)] = try wip_name.map(
                if (self.strip) .empty else self.names.items[@intFromEnum(old_argument_index)],
                ".",
            );
            if (self.debug_locations.get(old_argument_index)) |location| {
                debug_locations.putAssumeCapacity(new_argument_index, location);
            }
            if (self.debug_values.getIndex(old_argument_index)) |index| {
                debug_values[index] = new_argument_index;
            }
        }
        for (self.blocks.items) |current_block| {
            const new_block_index: Instruction.Index = @enumFromInt(function.instructions.len);
            value_indices[function.instructions.len] = value_index;
            function.instructions.appendAssumeCapacity(.{
                .tag = .block,
                .data = current_block.incoming,
            });
            names[@intFromEnum(new_block_index)] = try wip_name.map(current_block.name, "");
            for (current_block.instructions.items) |old_instruction_index| {
                const new_instruction_index: Instruction.Index =
                    @enumFromInt(function.instructions.len);
                var instruction = self.instructions.get(@intFromEnum(old_instruction_index));
                switch (instruction.tag) {
                    .add,
                    .@"add nsw",
                    .@"add nuw",
                    .@"add nuw nsw",
                    .@"and",
                    .ashr,
                    .@"ashr exact",
                    .fadd,
                    .@"fadd fast",
                    .@"fcmp false",
                    .@"fcmp fast false",
                    .@"fcmp fast oeq",
                    .@"fcmp fast oge",
                    .@"fcmp fast ogt",
                    .@"fcmp fast ole",
                    .@"fcmp fast olt",
                    .@"fcmp fast one",
                    .@"fcmp fast ord",
                    .@"fcmp fast true",
                    .@"fcmp fast ueq",
                    .@"fcmp fast uge",
                    .@"fcmp fast ugt",
                    .@"fcmp fast ule",
                    .@"fcmp fast ult",
                    .@"fcmp fast une",
                    .@"fcmp fast uno",
                    .@"fcmp oeq",
                    .@"fcmp oge",
                    .@"fcmp ogt",
                    .@"fcmp ole",
                    .@"fcmp olt",
                    .@"fcmp one",
                    .@"fcmp ord",
                    .@"fcmp true",
                    .@"fcmp ueq",
                    .@"fcmp uge",
                    .@"fcmp ugt",
                    .@"fcmp ule",
                    .@"fcmp ult",
                    .@"fcmp une",
                    .@"fcmp uno",
                    .fdiv,
                    .@"fdiv fast",
                    .fmul,
                    .@"fmul fast",
                    .frem,
                    .@"frem fast",
                    .fsub,
                    .@"fsub fast",
                    .@"icmp eq",
                    .@"icmp ne",
                    .@"icmp sge",
                    .@"icmp sgt",
                    .@"icmp sle",
                    .@"icmp slt",
                    .@"icmp uge",
                    .@"icmp ugt",
                    .@"icmp ule",
                    .@"icmp ult",
                    .lshr,
                    .@"lshr exact",
                    .mul,
                    .@"mul nsw",
                    .@"mul nuw",
                    .@"mul nuw nsw",
                    .@"or",
                    .sdiv,
                    .@"sdiv exact",
                    .shl,
                    .@"shl nsw",
                    .@"shl nuw",
                    .@"shl nuw nsw",
                    .srem,
                    .sub,
                    .@"sub nsw",
                    .@"sub nuw",
                    .@"sub nuw nsw",
                    .udiv,
                    .@"udiv exact",
                    .urem,
                    .xor,
                    => {
                        const extra = self.extraData(Instruction.Binary, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.Binary{
                            .lhs = instructions.map(extra.lhs),
                            .rhs = instructions.map(extra.rhs),
                        });
                    },
                    .addrspacecast,
                    .bitcast,
                    .fpext,
                    .fptosi,
                    .fptoui,
                    .fptrunc,
                    .inttoptr,
                    .ptrtoint,
                    .sext,
                    .sitofp,
                    .trunc,
                    .uitofp,
                    .zext,
                    => {
                        const extra = self.extraData(Instruction.Cast, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.Cast{
                            .val = instructions.map(extra.val),
                            .type = extra.type,
                        });
                    },
                    .alloca,
                    .@"alloca inalloca",
                    => {
                        const extra = self.extraData(Instruction.Alloca, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.Alloca{
                            .type = extra.type,
                            .len = instructions.map(extra.len),
                            .info = extra.info,
                        });
                    },
                    .arg,
                    .block,
                    => unreachable,
                    .atomicrmw => {
                        const extra = self.extraData(Instruction.AtomicRmw, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.AtomicRmw{
                            .info = extra.info,
                            .ptr = instructions.map(extra.ptr),
                            .val = instructions.map(extra.val),
                        });
                    },
                    .br,
                    .fence,
                    .@"ret void",
                    .@"unreachable",
                    => {},
                    .br_cond => {
                        const extra = self.extraData(Instruction.BrCond, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.BrCond{
                            .cond = instructions.map(extra.cond),
                            .then = extra.then,
                            .@"else" = extra.@"else",
                        });
                    },
                    .call,
                    .@"call fast",
                    .@"musttail call",
                    .@"musttail call fast",
                    .@"notail call",
                    .@"notail call fast",
                    .@"tail call",
                    .@"tail call fast",
                    => {
                        var extra = self.extraDataTrail(Instruction.Call, instruction.data);
                        const args = extra.trail.next(extra.data.args_len, Value, self);
                        instruction.data = wip_extra.addExtra(Instruction.Call{
                            .info = extra.data.info,
                            .attributes = extra.data.attributes,
                            .ty = extra.data.ty,
                            .callee = instructions.map(extra.data.callee),
                            .args_len = extra.data.args_len,
                        });
                        wip_extra.appendMappedValues(args, instructions);
                    },
                    .cmpxchg,
                    .@"cmpxchg weak",
                    => {
                        const extra = self.extraData(Instruction.CmpXchg, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.CmpXchg{
                            .info = extra.info,
                            .ptr = instructions.map(extra.ptr),
                            .cmp = instructions.map(extra.cmp),
                            .new = instructions.map(extra.new),
                        });
                    },
                    .extractelement => {
                        const extra = self.extraData(Instruction.ExtractElement, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.ExtractElement{
                            .val = instructions.map(extra.val),
                            .index = instructions.map(extra.index),
                        });
                    },
                    .extractvalue => {
                        var extra = self.extraDataTrail(Instruction.ExtractValue, instruction.data);
                        const indices = extra.trail.next(extra.data.indices_len, u32, self);
                        instruction.data = wip_extra.addExtra(Instruction.ExtractValue{
                            .val = instructions.map(extra.data.val),
                            .indices_len = extra.data.indices_len,
                        });
                        wip_extra.appendSlice(indices);
                    },
                    .fneg,
                    .@"fneg fast",
                    .ret,
                    => instruction.data = @intFromEnum(instructions.map(@enumFromInt(instruction.data))),
                    .getelementptr,
                    .@"getelementptr inbounds",
                    => {
                        var extra = self.extraDataTrail(Instruction.GetElementPtr, instruction.data);
                        const indices = extra.trail.next(extra.data.indices_len, Value, self);
                        instruction.data = wip_extra.addExtra(Instruction.GetElementPtr{
                            .type = extra.data.type,
                            .base = instructions.map(extra.data.base),
                            .indices_len = extra.data.indices_len,
                        });
                        wip_extra.appendMappedValues(indices, instructions);
                    },
                    .insertelement => {
                        const extra = self.extraData(Instruction.InsertElement, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.InsertElement{
                            .val = instructions.map(extra.val),
                            .elem = instructions.map(extra.elem),
                            .index = instructions.map(extra.index),
                        });
                    },
                    .insertvalue => {
                        var extra = self.extraDataTrail(Instruction.InsertValue, instruction.data);
                        const indices = extra.trail.next(extra.data.indices_len, u32, self);
                        instruction.data = wip_extra.addExtra(Instruction.InsertValue{
                            .val = instructions.map(extra.data.val),
                            .elem = instructions.map(extra.data.elem),
                            .indices_len = extra.data.indices_len,
                        });
                        wip_extra.appendSlice(indices);
                    },
                    .load,
                    .@"load atomic",
                    => {
                        const extra = self.extraData(Instruction.Load, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.Load{
                            .type = extra.type,
                            .ptr = instructions.map(extra.ptr),
                            .info = extra.info,
                        });
                    },
                    .phi,
                    .@"phi fast",
                    => {
                        const incoming_len = current_block.incoming;
                        var extra = self.extraDataTrail(Instruction.Phi, instruction.data);
                        const incoming_vals = extra.trail.next(incoming_len, Value, self);
                        const incoming_blocks = extra.trail.next(incoming_len, Block.Index, self);
                        instruction.data = wip_extra.addExtra(Instruction.Phi{
                            .type = extra.data.type,
                        });
                        wip_extra.appendMappedValues(incoming_vals, instructions);
                        wip_extra.appendSlice(incoming_blocks);
                    },
                    .select,
                    .@"select fast",
                    => {
                        const extra = self.extraData(Instruction.Select, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.Select{
                            .cond = instructions.map(extra.cond),
                            .lhs = instructions.map(extra.lhs),
                            .rhs = instructions.map(extra.rhs),
                        });
                    },
                    .shufflevector => {
                        const extra = self.extraData(Instruction.ShuffleVector, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.ShuffleVector{
                            .lhs = instructions.map(extra.lhs),
                            .rhs = instructions.map(extra.rhs),
                            .mask = instructions.map(extra.mask),
                        });
                    },
                    .store,
                    .@"store atomic",
                    => {
                        const extra = self.extraData(Instruction.Store, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.Store{
                            .val = instructions.map(extra.val),
                            .ptr = instructions.map(extra.ptr),
                            .info = extra.info,
                        });
                    },
                    .@"switch" => {
                        var extra = self.extraDataTrail(Instruction.Switch, instruction.data);
                        const case_vals = extra.trail.next(extra.data.cases_len, Constant, self);
                        const case_blocks = extra.trail.next(extra.data.cases_len, Block.Index, self);
                        instruction.data = wip_extra.addExtra(Instruction.Switch{
                            .val = instructions.map(extra.data.val),
                            .default = extra.data.default,
                            .cases_len = extra.data.cases_len,
                        });
                        wip_extra.appendSlice(case_vals);
                        wip_extra.appendSlice(case_blocks);
                    },
                    .va_arg => {
                        const extra = self.extraData(Instruction.VaArg, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.VaArg{
                            .list = instructions.map(extra.list),
                            .type = extra.type,
                        });
                    },
                }
                function.instructions.appendAssumeCapacity(instruction);
                names[@intFromEnum(new_instruction_index)] = try wip_name.map(if (self.strip)
                    if (old_instruction_index.hasResultWip(self)) .empty else .none
                else
                    self.names.items[@intFromEnum(old_instruction_index)], ".");

                if (self.debug_locations.get(old_instruction_index)) |location| {
                    debug_locations.putAssumeCapacity(new_instruction_index, location);
                }

                if (self.debug_values.getIndex(old_instruction_index)) |index| {
                    debug_values[index] = new_instruction_index;
                }

                value_indices[@intFromEnum(new_instruction_index)] = value_index;
                if (old_instruction_index.hasResultWip(self)) value_index += 1;
            }
        }

        assert(function.instructions.len == final_instructions_len);
        function.extra = wip_extra.finish();
        function.blocks = blocks;
        function.names = names.ptr;
        function.value_indices = value_indices.ptr;
        function.strip = self.strip;
        function.debug_locations = debug_locations;
        function.debug_values = debug_values;
    }

    pub fn deinit(self: *WipFunction) void {
        self.extra.deinit(self.builder.gpa);
        self.debug_values.deinit(self.builder.gpa);
        self.debug_locations.deinit(self.builder.gpa);
        self.names.deinit(self.builder.gpa);
        self.instructions.deinit(self.builder.gpa);
        for (self.blocks.items) |*b| b.instructions.deinit(self.builder.gpa);
        self.blocks.deinit(self.builder.gpa);
        self.* = undefined;
    }

    fn cmpTag(
        self: *WipFunction,
        tag: Instruction.Tag,
        lhs: Value,
        rhs: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        switch (tag) {
            .@"fcmp false",
            .@"fcmp fast false",
            .@"fcmp fast oeq",
            .@"fcmp fast oge",
            .@"fcmp fast ogt",
            .@"fcmp fast ole",
            .@"fcmp fast olt",
            .@"fcmp fast one",
            .@"fcmp fast ord",
            .@"fcmp fast true",
            .@"fcmp fast ueq",
            .@"fcmp fast uge",
            .@"fcmp fast ugt",
            .@"fcmp fast ule",
            .@"fcmp fast ult",
            .@"fcmp fast une",
            .@"fcmp fast uno",
            .@"fcmp oeq",
            .@"fcmp oge",
            .@"fcmp ogt",
            .@"fcmp ole",
            .@"fcmp olt",
            .@"fcmp one",
            .@"fcmp ord",
            .@"fcmp true",
            .@"fcmp ueq",
            .@"fcmp uge",
            .@"fcmp ugt",
            .@"fcmp ule",
            .@"fcmp ult",
            .@"fcmp une",
            .@"fcmp uno",
            .@"icmp eq",
            .@"icmp ne",
            .@"icmp sge",
            .@"icmp sgt",
            .@"icmp sle",
            .@"icmp slt",
            .@"icmp uge",
            .@"icmp ugt",
            .@"icmp ule",
            .@"icmp ult",
            => assert(lhs.typeOfWip(self) == rhs.typeOfWip(self)),
            else => unreachable,
        }
        _ = try lhs.typeOfWip(self).changeScalar(.i1, self.builder);
        try self.ensureUnusedExtraCapacity(1, Instruction.Binary, 0);
        const instruction = try self.addInst(name, .{
            .tag = tag,
            .data = self.addExtraAssumeCapacity(Instruction.Binary{
                .lhs = lhs,
                .rhs = rhs,
            }),
        });
        return instruction.toValue();
    }

    fn phiTag(
        self: *WipFunction,
        tag: Instruction.Tag,
        ty: Type,
        name: []const u8,
    ) Allocator.Error!WipPhi {
        switch (tag) {
            .phi, .@"phi fast" => assert(try ty.isSized(self.builder)),
            else => unreachable,
        }
        const incoming = self.cursor.block.ptrConst(self).incoming;
        assert(incoming > 0);
        try self.ensureUnusedExtraCapacity(1, Instruction.Phi, incoming * 2);
        const instruction = try self.addInst(name, .{
            .tag = tag,
            .data = self.addExtraAssumeCapacity(Instruction.Phi{ .type = ty }),
        });
        _ = self.extra.addManyAsSliceAssumeCapacity(incoming * 2);
        return .{ .block = self.cursor.block, .instruction = instruction };
    }

    fn selectTag(
        self: *WipFunction,
        tag: Instruction.Tag,
        cond: Value,
        lhs: Value,
        rhs: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        switch (tag) {
            .select, .@"select fast" => {
                assert(cond.typeOfWip(self).scalarType(self.builder) == .i1);
                assert(lhs.typeOfWip(self) == rhs.typeOfWip(self));
            },
            else => unreachable,
        }
        try self.ensureUnusedExtraCapacity(1, Instruction.Select, 0);
        const instruction = try self.addInst(name, .{
            .tag = tag,
            .data = self.addExtraAssumeCapacity(Instruction.Select{
                .cond = cond,
                .lhs = lhs,
                .rhs = rhs,
            }),
        });
        return instruction.toValue();
    }

    fn ensureUnusedExtraCapacity(
        self: *WipFunction,
        count: usize,
        comptime Extra: type,
        trail_len: usize,
    ) Allocator.Error!void {
        try self.extra.ensureUnusedCapacity(
            self.builder.gpa,
            count * (@typeInfo(Extra).Struct.fields.len + trail_len),
        );
    }

    fn addInst(
        self: *WipFunction,
        name: ?[]const u8,
        instruction: Instruction,
    ) Allocator.Error!Instruction.Index {
        const block_instructions = &self.cursor.block.ptr(self).instructions;
        try self.instructions.ensureUnusedCapacity(self.builder.gpa, 1);
        if (!self.strip) {
            try self.names.ensureUnusedCapacity(self.builder.gpa, 1);
            try self.debug_locations.ensureUnusedCapacity(self.builder.gpa, 1);
        }
        try block_instructions.ensureUnusedCapacity(self.builder.gpa, 1);
        const final_name = if (name) |n|
            if (self.strip) .empty else try self.builder.string(n)
        else
            .none;

        const index: Instruction.Index = @enumFromInt(self.instructions.len);
        self.instructions.appendAssumeCapacity(instruction);
        if (!self.strip) {
            self.names.appendAssumeCapacity(final_name);
            if (block_instructions.items.len == 0 or
                !std.meta.eql(self.debug_location, self.prev_debug_location))
            {
                self.debug_locations.putAssumeCapacity(index, self.debug_location);
                self.prev_debug_location = self.debug_location;
            }
        }
        block_instructions.insertAssumeCapacity(self.cursor.instruction, index);
        self.cursor.instruction += 1;
        return index;
    }

    fn addExtraAssumeCapacity(self: *WipFunction, extra: anytype) Instruction.ExtraIndex {
        const result: Instruction.ExtraIndex = @intCast(self.extra.items.len);
        inline for (@typeInfo(@TypeOf(extra)).Struct.fields) |field| {
            const value = @field(extra, field.name);
            self.extra.appendAssumeCapacity(switch (field.type) {
                u32 => value,
                Alignment,
                AtomicOrdering,
                Block.Index,
                FunctionAttributes,
                Type,
                Value,
                => @intFromEnum(value),
                MemoryAccessInfo,
                Instruction.Alloca.Info,
                Instruction.Call.Info,
                => @bitCast(value),
                else => @compileError("bad field type: " ++ field.name ++ ": " ++ @typeName(field.type)),
            });
        }
        return result;
    }

    const ExtraDataTrail = struct {
        index: Instruction.ExtraIndex,

        fn nextMut(self: *ExtraDataTrail, len: u32, comptime Item: type, wip: *WipFunction) []Item {
            const items: []Item = @ptrCast(wip.extra.items[self.index..][0..len]);
            self.index += @intCast(len);
            return items;
        }

        fn next(
            self: *ExtraDataTrail,
            len: u32,
            comptime Item: type,
            wip: *const WipFunction,
        ) []const Item {
            const items: []const Item = @ptrCast(wip.extra.items[self.index..][0..len]);
            self.index += @intCast(len);
            return items;
        }
    };

    fn extraDataTrail(
        self: *const WipFunction,
        comptime T: type,
        index: Instruction.ExtraIndex,
    ) struct { data: T, trail: ExtraDataTrail } {
        var result: T = undefined;
        const fields = @typeInfo(T).Struct.fields;
        inline for (fields, self.extra.items[index..][0..fields.len]) |field, value|
            @field(result, field.name) = switch (field.type) {
                u32 => value,
                Alignment,
                AtomicOrdering,
                Block.Index,
                FunctionAttributes,
                Type,
                Value,
                => @enumFromInt(value),
                MemoryAccessInfo,
                Instruction.Alloca.Info,
                Instruction.Call.Info,
                => @bitCast(value),
                else => @compileError("bad field type: " ++ field.name ++ ": " ++ @typeName(field.type)),
            };
        return .{
            .data = result,
            .trail = .{ .index = index + @as(Type.Item.ExtraIndex, @intCast(fields.len)) },
        };
    }

    fn extraData(self: *const WipFunction, comptime T: type, index: Instruction.ExtraIndex) T {
        return self.extraDataTrail(T, index).data;
    }
};

pub const FloatCondition = enum(u4) {
    oeq = 1,
    ogt = 2,
    oge = 3,
    olt = 4,
    ole = 5,
    one = 6,
    ord = 7,
    uno = 8,
    ueq = 9,
    ugt = 10,
    uge = 11,
    ult = 12,
    ule = 13,
    une = 14,
};

pub const IntegerCondition = enum(u6) {
    eq = 32,
    ne = 33,
    ugt = 34,
    uge = 35,
    ult = 36,
    ule = 37,
    sgt = 38,
    sge = 39,
    slt = 40,
    sle = 41,
};

pub const MemoryAccessKind = enum(u1) {
    normal,
    @"volatile",

    pub fn format(
        self: MemoryAccessKind,
        comptime prefix: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .normal) try writer.print("{s}{s}", .{ prefix, @tagName(self) });
    }
};

pub const SyncScope = enum(u1) {
    singlethread,
    system,

    pub fn format(
        self: SyncScope,
        comptime prefix: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .system) try writer.print(
            \\{s}syncscope("{s}")
        , .{ prefix, @tagName(self) });
    }
};

pub const AtomicOrdering = enum(u3) {
    none = 0,
    unordered = 1,
    monotonic = 2,
    acquire = 3,
    release = 4,
    acq_rel = 5,
    seq_cst = 6,

    pub fn format(
        self: AtomicOrdering,
        comptime prefix: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .none) try writer.print("{s}{s}", .{ prefix, @tagName(self) });
    }
};

const MemoryAccessInfo = packed struct(u32) {
    access_kind: MemoryAccessKind = .normal,
    atomic_rmw_operation: Function.Instruction.AtomicRmw.Operation = .none,
    sync_scope: SyncScope,
    success_ordering: AtomicOrdering,
    failure_ordering: AtomicOrdering = .none,
    alignment: Alignment = .default,
    _: u13 = undefined,
};

pub const FastMath = packed struct(u8) {
    unsafe_algebra: bool = false, // Legacy
    nnan: bool = false,
    ninf: bool = false,
    nsz: bool = false,
    arcp: bool = false,
    contract: bool = false,
    afn: bool = false,
    reassoc: bool = false,

    pub const fast = FastMath{
        .nnan = true,
        .ninf = true,
        .nsz = true,
        .arcp = true,
        .contract = true,
        .afn = true,
        .reassoc = true,
    };
};

pub const FastMathKind = enum {
    normal,
    fast,

    pub fn toCallKind(self: FastMathKind) Function.Instruction.Call.Kind {
        return switch (self) {
            .normal => .normal,
            .fast => .fast,
        };
    }
};

pub const Constant = enum(u32) {
    false,
    true,
    @"0",
    @"1",
    none,
    no_init = (1 << 30) - 1,
    _,

    const first_global: Constant = @enumFromInt(1 << 29);

    pub const Tag = enum(u7) {
        positive_integer,
        negative_integer,
        half,
        bfloat,
        float,
        double,
        fp128,
        x86_fp80,
        ppc_fp128,
        null,
        none,
        structure,
        packed_structure,
        array,
        string,
        vector,
        splat,
        zeroinitializer,
        undef,
        poison,
        blockaddress,
        dso_local_equivalent,
        no_cfi,
        trunc,
        ptrtoint,
        inttoptr,
        bitcast,
        addrspacecast,
        getelementptr,
        @"getelementptr inbounds",
        add,
        @"add nsw",
        @"add nuw",
        sub,
        @"sub nsw",
        @"sub nuw",
        shl,
        xor,
        @"asm",
        @"asm sideeffect",
        @"asm alignstack",
        @"asm sideeffect alignstack",
        @"asm inteldialect",
        @"asm sideeffect inteldialect",
        @"asm alignstack inteldialect",
        @"asm sideeffect alignstack inteldialect",
        @"asm unwind",
        @"asm sideeffect unwind",
        @"asm alignstack unwind",
        @"asm sideeffect alignstack unwind",
        @"asm inteldialect unwind",
        @"asm sideeffect inteldialect unwind",
        @"asm alignstack inteldialect unwind",
        @"asm sideeffect alignstack inteldialect unwind",

        pub fn toBinaryOpcode(self: Tag) BinaryOpcode {
            return switch (self) {
                .add,
                .@"add nsw",
                .@"add nuw",
                => .add,
                .sub,
                .@"sub nsw",
                .@"sub nuw",
                => .sub,
                .shl => .shl,
                .xor => .xor,
                else => unreachable,
            };
        }

        pub fn toCastOpcode(self: Tag) CastOpcode {
            return switch (self) {
                .trunc => .trunc,
                .ptrtoint => .ptrtoint,
                .inttoptr => .inttoptr,
                .bitcast => .bitcast,
                .addrspacecast => .addrspacecast,
                else => unreachable,
            };
        }
    };

    pub const Item = struct {
        tag: Tag,
        data: ExtraIndex,

        const ExtraIndex = u32;
    };

    pub const Integer = packed struct(u64) {
        type: Type,
        limbs_len: u32,

        pub const limbs = @divExact(@bitSizeOf(Integer), @bitSizeOf(std.math.big.Limb));
    };

    pub const Double = struct {
        lo: u32,
        hi: u32,
    };

    pub const Fp80 = struct {
        lo_lo: u32,
        lo_hi: u32,
        hi: u32,
    };

    pub const Fp128 = struct {
        lo_lo: u32,
        lo_hi: u32,
        hi_lo: u32,
        hi_hi: u32,
    };

    pub const Aggregate = struct {
        type: Type,
        //fields: [type.aggregateLen(builder)]Constant,
    };

    pub const Splat = extern struct {
        type: Type,
        value: Constant,
    };

    pub const BlockAddress = extern struct {
        function: Function.Index,
        block: Function.Block.Index,
    };

    pub const Cast = extern struct {
        val: Constant,
        type: Type,

        pub const Signedness = enum { unsigned, signed, unneeded };
    };

    pub const GetElementPtr = struct {
        type: Type,
        base: Constant,
        info: Info,
        //indices: [info.indices_len]Constant,

        pub const Kind = enum { normal, inbounds };
        pub const InRangeIndex = enum(u16) { none = std.math.maxInt(u16), _ };
        pub const Info = packed struct(u32) { indices_len: u16, inrange: InRangeIndex };
    };

    pub const Binary = extern struct {
        lhs: Constant,
        rhs: Constant,
    };

    pub const Assembly = extern struct {
        type: Type,
        assembly: String,
        constraints: String,

        pub const Info = packed struct {
            sideeffect: bool = false,
            alignstack: bool = false,
            inteldialect: bool = false,
            unwind: bool = false,
        };
    };

    pub fn unwrap(self: Constant) union(enum) {
        constant: u30,
        global: Global.Index,
    } {
        return if (@intFromEnum(self) < @intFromEnum(first_global))
            .{ .constant = @intCast(@intFromEnum(self)) }
        else
            .{ .global = @enumFromInt(@intFromEnum(self) - @intFromEnum(first_global)) };
    }

    pub fn toValue(self: Constant) Value {
        return @enumFromInt(Value.first_constant + @intFromEnum(self));
    }

    pub fn typeOf(self: Constant, builder: *Builder) Type {
        switch (self.unwrap()) {
            .constant => |constant| {
                const item = builder.constant_items.get(constant);
                return switch (item.tag) {
                    .positive_integer,
                    .negative_integer,
                    => @as(
                        *align(@alignOf(std.math.big.Limb)) Integer,
                        @ptrCast(builder.constant_limbs.items[item.data..][0..Integer.limbs]),
                    ).type,
                    .half => .half,
                    .bfloat => .bfloat,
                    .float => .float,
                    .double => .double,
                    .fp128 => .fp128,
                    .x86_fp80 => .x86_fp80,
                    .ppc_fp128 => .ppc_fp128,
                    .null,
                    .none,
                    .zeroinitializer,
                    .undef,
                    .poison,
                    => @enumFromInt(item.data),
                    .structure,
                    .packed_structure,
                    .array,
                    .vector,
                    => builder.constantExtraData(Aggregate, item.data).type,
                    .splat => builder.constantExtraData(Splat, item.data).type,
                    .string => builder.arrayTypeAssumeCapacity(
                        @as(String, @enumFromInt(item.data)).slice(builder).?.len,
                        .i8,
                    ),
                    .blockaddress => builder.ptrTypeAssumeCapacity(
                        builder.constantExtraData(BlockAddress, item.data)
                            .function.ptrConst(builder).global.ptrConst(builder).addr_space,
                    ),
                    .dso_local_equivalent,
                    .no_cfi,
                    => builder.ptrTypeAssumeCapacity(@as(Function.Index, @enumFromInt(item.data))
                        .ptrConst(builder).global.ptrConst(builder).addr_space),
                    .trunc,
                    .ptrtoint,
                    .inttoptr,
                    .bitcast,
                    .addrspacecast,
                    => builder.constantExtraData(Cast, item.data).type,
                    .getelementptr,
                    .@"getelementptr inbounds",
                    => {
                        var extra = builder.constantExtraDataTrail(GetElementPtr, item.data);
                        const indices =
                            extra.trail.next(extra.data.info.indices_len, Constant, builder);
                        const base_ty = extra.data.base.typeOf(builder);
                        if (!base_ty.isVector(builder)) for (indices) |index| {
                            const index_ty = index.typeOf(builder);
                            if (!index_ty.isVector(builder)) continue;
                            return index_ty.changeScalarAssumeCapacity(base_ty, builder);
                        };
                        return base_ty;
                    },
                    .add,
                    .@"add nsw",
                    .@"add nuw",
                    .sub,
                    .@"sub nsw",
                    .@"sub nuw",
                    .shl,
                    .xor,
                    => builder.constantExtraData(Binary, item.data).lhs.typeOf(builder),
                    .@"asm",
                    .@"asm sideeffect",
                    .@"asm alignstack",
                    .@"asm sideeffect alignstack",
                    .@"asm inteldialect",
                    .@"asm sideeffect inteldialect",
                    .@"asm alignstack inteldialect",
                    .@"asm sideeffect alignstack inteldialect",
                    .@"asm unwind",
                    .@"asm sideeffect unwind",
                    .@"asm alignstack unwind",
                    .@"asm sideeffect alignstack unwind",
                    .@"asm inteldialect unwind",
                    .@"asm sideeffect inteldialect unwind",
                    .@"asm alignstack inteldialect unwind",
                    .@"asm sideeffect alignstack inteldialect unwind",
                    => .ptr,
                };
            },
            .global => |global| return builder.ptrTypeAssumeCapacity(
                global.ptrConst(builder).addr_space,
            ),
        }
    }

    pub fn isZeroInit(self: Constant, builder: *const Builder) bool {
        switch (self.unwrap()) {
            .constant => |constant| {
                const item = builder.constant_items.get(constant);
                return switch (item.tag) {
                    .positive_integer => {
                        const extra: *align(@alignOf(std.math.big.Limb)) Integer =
                            @ptrCast(builder.constant_limbs.items[item.data..][0..Integer.limbs]);
                        const limbs = builder.constant_limbs
                            .items[item.data + Integer.limbs ..][0..extra.limbs_len];
                        return std.mem.eql(std.math.big.Limb, limbs, &.{0});
                    },
                    .half, .bfloat, .float => item.data == 0,
                    .double => {
                        const extra = builder.constantExtraData(Constant.Double, item.data);
                        return extra.lo == 0 and extra.hi == 0;
                    },
                    .fp128, .ppc_fp128 => {
                        const extra = builder.constantExtraData(Constant.Fp128, item.data);
                        return extra.lo_lo == 0 and extra.lo_hi == 0 and
                            extra.hi_lo == 0 and extra.hi_hi == 0;
                    },
                    .x86_fp80 => {
                        const extra = builder.constantExtraData(Constant.Fp80, item.data);
                        return extra.lo_lo == 0 and extra.lo_hi == 0 and extra.hi == 0;
                    },
                    .vector => {
                        var extra = builder.constantExtraDataTrail(Aggregate, item.data);
                        const len: u32 = @intCast(extra.data.type.aggregateLen(builder));
                        const vals = extra.trail.next(len, Constant, builder);
                        for (vals) |val| if (!val.isZeroInit(builder)) return false;
                        return true;
                    },
                    .null, .zeroinitializer => true,
                    else => false,
                };
            },
            .global => return false,
        }
    }

    pub fn getBase(self: Constant, builder: *const Builder) Global.Index {
        var cur = self;
        while (true) switch (cur.unwrap()) {
            .constant => |constant| {
                const item = builder.constant_items.get(constant);
                switch (item.tag) {
                    .ptrtoint,
                    .inttoptr,
                    .bitcast,
                    => cur = builder.constantExtraData(Cast, item.data).val,
                    .getelementptr => cur = builder.constantExtraData(GetElementPtr, item.data).base,
                    .add => {
                        const extra = builder.constantExtraData(Binary, item.data);
                        const lhs_base = extra.lhs.getBase(builder);
                        const rhs_base = extra.rhs.getBase(builder);
                        return if (lhs_base != .none and rhs_base != .none)
                            .none
                        else if (lhs_base != .none) lhs_base else rhs_base;
                    },
                    .sub => {
                        const extra = builder.constantExtraData(Binary, item.data);
                        if (extra.rhs.getBase(builder) != .none) return .none;
                        cur = extra.lhs;
                    },
                    else => return .none,
                }
            },
            .global => |global| switch (global.ptrConst(builder).kind) {
                .alias => |alias| cur = alias.ptrConst(builder).aliasee,
                .variable, .function => return global,
                .replaced => unreachable,
            },
        };
    }

    const FormatData = struct {
        constant: Constant,
        builder: *Builder,
    };
    fn format(
        data: FormatData,
        comptime fmt_str: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (comptime std.mem.indexOfNone(u8, fmt_str, ", %")) |_|
            @compileError("invalid format string: '" ++ fmt_str ++ "'");
        if (comptime std.mem.indexOfScalar(u8, fmt_str, ',') != null) {
            if (data.constant == .no_init) return;
            try writer.writeByte(',');
        }
        if (comptime std.mem.indexOfScalar(u8, fmt_str, ' ') != null) {
            if (data.constant == .no_init) return;
            try writer.writeByte(' ');
        }
        if (comptime std.mem.indexOfScalar(u8, fmt_str, '%') != null)
            try writer.print("{%} ", .{data.constant.typeOf(data.builder).fmt(data.builder)});
        assert(data.constant != .no_init);
        if (std.enums.tagName(Constant, data.constant)) |name| return writer.writeAll(name);
        switch (data.constant.unwrap()) {
            .constant => |constant| {
                const item = data.builder.constant_items.get(constant);
                switch (item.tag) {
                    .positive_integer,
                    .negative_integer,
                    => |tag| {
                        const extra: *align(@alignOf(std.math.big.Limb)) const Integer =
                            @ptrCast(data.builder.constant_limbs.items[item.data..][0..Integer.limbs]);
                        const limbs = data.builder.constant_limbs
                            .items[item.data + Integer.limbs ..][0..extra.limbs_len];
                        const bigint: std.math.big.int.Const = .{
                            .limbs = limbs,
                            .positive = switch (tag) {
                                .positive_integer => true,
                                .negative_integer => false,
                                else => unreachable,
                            },
                        };
                        const ExpectedContents = extern struct {
                            const expected_limbs = @divExact(512, @bitSizeOf(std.math.big.Limb));
                            string: [
                                (std.math.big.int.Const{
                                    .limbs = &([1]std.math.big.Limb{
                                        std.math.maxInt(std.math.big.Limb),
                                    } ** expected_limbs),
                                    .positive = false,
                                }).sizeInBaseUpperBound(10)
                            ]u8,
                            limbs: [
                                std.math.big.int.calcToStringLimbsBufferLen(expected_limbs, 10)
                            ]std.math.big.Limb,
                        };
                        var stack align(@alignOf(ExpectedContents)) =
                            std.heap.stackFallback(@sizeOf(ExpectedContents), data.builder.gpa);
                        const allocator = stack.get();
                        const str = try bigint.toStringAlloc(allocator, 10, undefined);
                        defer allocator.free(str);
                        try writer.writeAll(str);
                    },
                    .half,
                    .bfloat,
                    => |tag| try writer.print("0x{c}{X:0>4}", .{ @as(u8, switch (tag) {
                        .half => 'H',
                        .bfloat => 'R',
                        else => unreachable,
                    }), item.data >> switch (tag) {
                        .half => 0,
                        .bfloat => 16,
                        else => unreachable,
                    } }),
                    .float => {
                        const Float = struct {
                            fn Repr(comptime T: type) type {
                                return packed struct(std.meta.Int(.unsigned, @bitSizeOf(T))) {
                                    mantissa: std.meta.Int(.unsigned, std.math.floatMantissaBits(T)),
                                    exponent: std.meta.Int(.unsigned, std.math.floatExponentBits(T)),
                                    sign: u1,
                                };
                            }
                        };
                        const Mantissa64 = std.meta.FieldType(Float.Repr(f64), .mantissa);
                        const Exponent32 = std.meta.FieldType(Float.Repr(f32), .exponent);
                        const Exponent64 = std.meta.FieldType(Float.Repr(f64), .exponent);

                        const repr: Float.Repr(f32) = @bitCast(item.data);
                        const denormal_shift = switch (repr.exponent) {
                            std.math.minInt(Exponent32) => @as(
                                std.math.Log2Int(Mantissa64),
                                @clz(repr.mantissa),
                            ) + 1,
                            else => 0,
                        };
                        try writer.print("0x{X:0>16}", .{@as(u64, @bitCast(Float.Repr(f64){
                            .mantissa = std.math.shl(
                                Mantissa64,
                                repr.mantissa,
                                std.math.floatMantissaBits(f64) - std.math.floatMantissaBits(f32) +
                                    denormal_shift,
                            ),
                            .exponent = switch (repr.exponent) {
                                std.math.minInt(Exponent32) => if (repr.mantissa > 0)
                                    @as(Exponent64, std.math.floatExponentMin(f32) +
                                        std.math.floatExponentMax(f64)) - denormal_shift
                                else
                                    std.math.minInt(Exponent64),
                                else => @as(Exponent64, repr.exponent) +
                                    (std.math.floatExponentMax(f64) - std.math.floatExponentMax(f32)),
                                std.math.maxInt(Exponent32) => std.math.maxInt(Exponent64),
                            },
                            .sign = repr.sign,
                        }))});
                    },
                    .double => {
                        const extra = data.builder.constantExtraData(Double, item.data);
                        try writer.print("0x{X:0>8}{X:0>8}", .{ extra.hi, extra.lo });
                    },
                    .fp128,
                    .ppc_fp128,
                    => |tag| {
                        const extra = data.builder.constantExtraData(Fp128, item.data);
                        try writer.print("0x{c}{X:0>8}{X:0>8}{X:0>8}{X:0>8}", .{
                            @as(u8, switch (tag) {
                                .fp128 => 'L',
                                .ppc_fp128 => 'M',
                                else => unreachable,
                            }),
                            extra.lo_hi,
                            extra.lo_lo,
                            extra.hi_hi,
                            extra.hi_lo,
                        });
                    },
                    .x86_fp80 => {
                        const extra = data.builder.constantExtraData(Fp80, item.data);
                        try writer.print("0xK{X:0>4}{X:0>8}{X:0>8}", .{
                            extra.hi, extra.lo_hi, extra.lo_lo,
                        });
                    },
                    .null,
                    .none,
                    .zeroinitializer,
                    .undef,
                    .poison,
                    => |tag| try writer.writeAll(@tagName(tag)),
                    .structure,
                    .packed_structure,
                    .array,
                    .vector,
                    => |tag| {
                        var extra = data.builder.constantExtraDataTrail(Aggregate, item.data);
                        const len: u32 = @intCast(extra.data.type.aggregateLen(data.builder));
                        const vals = extra.trail.next(len, Constant, data.builder);
                        try writer.writeAll(switch (tag) {
                            .structure => "{ ",
                            .packed_structure => "<{ ",
                            .array => "[",
                            .vector => "<",
                            else => unreachable,
                        });
                        for (vals, 0..) |val, index| {
                            if (index > 0) try writer.writeAll(", ");
                            try writer.print("{%}", .{val.fmt(data.builder)});
                        }
                        try writer.writeAll(switch (tag) {
                            .structure => " }",
                            .packed_structure => " }>",
                            .array => "]",
                            .vector => ">",
                            else => unreachable,
                        });
                    },
                    .splat => {
                        const extra = data.builder.constantExtraData(Splat, item.data);
                        const len = extra.type.vectorLen(data.builder);
                        try writer.writeByte('<');
                        for (0..len) |index| {
                            if (index > 0) try writer.writeAll(", ");
                            try writer.print("{%}", .{extra.value.fmt(data.builder)});
                        }
                        try writer.writeByte('>');
                    },
                    .string => try writer.print("c{\"}", .{
                        @as(String, @enumFromInt(item.data)).fmt(data.builder),
                    }),
                    .blockaddress => |tag| {
                        const extra = data.builder.constantExtraData(BlockAddress, item.data);
                        const function = extra.function.ptrConst(data.builder);
                        try writer.print("{s}({}, %{d})", .{
                            @tagName(tag),
                            function.global.fmt(data.builder),
                            @intFromEnum(extra.block), // TODO
                        });
                    },
                    .dso_local_equivalent,
                    .no_cfi,
                    => |tag| {
                        const function: Function.Index = @enumFromInt(item.data);
                        try writer.print("{s} {}", .{
                            @tagName(tag),
                            function.ptrConst(data.builder).global.fmt(data.builder),
                        });
                    },
                    .trunc,
                    .ptrtoint,
                    .inttoptr,
                    .bitcast,
                    .addrspacecast,
                    => |tag| {
                        const extra = data.builder.constantExtraData(Cast, item.data);
                        try writer.print("{s} ({%} to {%})", .{
                            @tagName(tag),
                            extra.val.fmt(data.builder),
                            extra.type.fmt(data.builder),
                        });
                    },
                    .getelementptr,
                    .@"getelementptr inbounds",
                    => |tag| {
                        var extra = data.builder.constantExtraDataTrail(GetElementPtr, item.data);
                        const indices =
                            extra.trail.next(extra.data.info.indices_len, Constant, data.builder);
                        try writer.print("{s} ({%}, {%}", .{
                            @tagName(tag),
                            extra.data.type.fmt(data.builder),
                            extra.data.base.fmt(data.builder),
                        });
                        for (indices) |index| try writer.print(", {%}", .{index.fmt(data.builder)});
                        try writer.writeByte(')');
                    },
                    .add,
                    .@"add nsw",
                    .@"add nuw",
                    .sub,
                    .@"sub nsw",
                    .@"sub nuw",
                    .shl,
                    .xor,
                    => |tag| {
                        const extra = data.builder.constantExtraData(Binary, item.data);
                        try writer.print("{s} ({%}, {%})", .{
                            @tagName(tag),
                            extra.lhs.fmt(data.builder),
                            extra.rhs.fmt(data.builder),
                        });
                    },
                    .@"asm",
                    .@"asm sideeffect",
                    .@"asm alignstack",
                    .@"asm sideeffect alignstack",
                    .@"asm inteldialect",
                    .@"asm sideeffect inteldialect",
                    .@"asm alignstack inteldialect",
                    .@"asm sideeffect alignstack inteldialect",
                    .@"asm unwind",
                    .@"asm sideeffect unwind",
                    .@"asm alignstack unwind",
                    .@"asm sideeffect alignstack unwind",
                    .@"asm inteldialect unwind",
                    .@"asm sideeffect inteldialect unwind",
                    .@"asm alignstack inteldialect unwind",
                    .@"asm sideeffect alignstack inteldialect unwind",
                    => |tag| {
                        const extra = data.builder.constantExtraData(Assembly, item.data);
                        try writer.print("{s} {\"}, {\"}", .{
                            @tagName(tag),
                            extra.assembly.fmt(data.builder),
                            extra.constraints.fmt(data.builder),
                        });
                    },
                }
            },
            .global => |global| try writer.print("{}", .{global.fmt(data.builder)}),
        }
    }
    pub fn fmt(self: Constant, builder: *Builder) std.fmt.Formatter(format) {
        return .{ .data = .{ .constant = self, .builder = builder } };
    }
};

pub const Value = enum(u32) {
    none = std.math.maxInt(u31),
    false = first_constant + @intFromEnum(Constant.false),
    true = first_constant + @intFromEnum(Constant.true),
    @"0" = first_constant + @intFromEnum(Constant.@"0"),
    @"1" = first_constant + @intFromEnum(Constant.@"1"),
    _,

    const first_constant = 1 << 30;
    const first_metadata = 1 << 31;

    pub fn unwrap(self: Value) union(enum) {
        instruction: Function.Instruction.Index,
        constant: Constant,
        metadata: Metadata,
    } {
        return if (@intFromEnum(self) < first_constant)
            .{ .instruction = @enumFromInt(@intFromEnum(self)) }
        else if (@intFromEnum(self) < first_metadata)
            .{ .constant = @enumFromInt(@intFromEnum(self) - first_constant) }
        else
            .{ .metadata = @enumFromInt(@intFromEnum(self) - first_metadata) };
    }

    pub fn typeOfWip(self: Value, wip: *const WipFunction) Type {
        return switch (self.unwrap()) {
            .instruction => |instruction| instruction.typeOfWip(wip),
            .constant => |constant| constant.typeOf(wip.builder),
            .metadata => .metadata,
        };
    }

    pub fn typeOf(self: Value, function: Function.Index, builder: *Builder) Type {
        return switch (self.unwrap()) {
            .instruction => |instruction| instruction.typeOf(function, builder),
            .constant => |constant| constant.typeOf(builder),
            .metadata => .metadata,
        };
    }

    pub fn toConst(self: Value) ?Constant {
        return switch (self.unwrap()) {
            .instruction, .metadata => null,
            .constant => |constant| constant,
        };
    }

    const FormatData = struct {
        value: Value,
        function: Function.Index,
        builder: *Builder,
    };
    fn format(
        data: FormatData,
        comptime fmt_str: []const u8,
        fmt_opts: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        switch (data.value.unwrap()) {
            .instruction => |instruction| try Function.Instruction.Index.format(.{
                .instruction = instruction,
                .function = data.function,
                .builder = data.builder,
            }, fmt_str, fmt_opts, writer),
            .constant => |constant| try Constant.format(.{
                .constant = constant,
                .builder = data.builder,
            }, fmt_str, fmt_opts, writer),
            .metadata => unreachable,
        }
    }
    pub fn fmt(self: Value, function: Function.Index, builder: *Builder) std.fmt.Formatter(format) {
        return .{ .data = .{ .value = self, .function = function, .builder = builder } };
    }
};

pub const MetadataString = enum(u32) {
    none = 0,
    _,

    pub fn slice(self: MetadataString, builder: *const Builder) []const u8 {
        const index = @intFromEnum(self);
        const start = builder.metadata_string_indices.items[index];
        const end = builder.metadata_string_indices.items[index + 1];
        return builder.metadata_string_bytes.items[start..end];
    }

    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: Adapter, key: []const u8) u32 {
            return @truncate(std.hash.Wyhash.hash(0, key));
        }
        pub fn eql(ctx: Adapter, lhs_key: []const u8, _: void, rhs_index: usize) bool {
            const rhs_metadata_string: MetadataString = @enumFromInt(rhs_index);
            return std.mem.eql(u8, lhs_key, rhs_metadata_string.slice(ctx.builder));
        }
    };

    const FormatData = struct {
        metadata_string: MetadataString,
        builder: *const Builder,
    };
    fn format(
        data: FormatData,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        try printEscapedString(data.metadata_string.slice(data.builder), .always_quote, writer);
    }
    fn fmt(self: MetadataString, builder: *const Builder) std.fmt.Formatter(format) {
        return .{ .data = .{ .metadata_string = self, .builder = builder } };
    }
};

pub const Metadata = enum(u32) {
    none = 0,
    _,

    const first_forward_reference = 1 << 29;
    const first_local_metadata = 1 << 30;

    pub const Tag = enum(u6) {
        none,
        file,
        compile_unit,
        @"compile_unit optimized",
        subprogram,
        @"subprogram local",
        @"subprogram definition",
        @"subprogram local definition",
        @"subprogram optimized",
        @"subprogram optimized local",
        @"subprogram optimized definition",
        @"subprogram optimized local definition",
        lexical_block,
        location,
        basic_bool_type,
        basic_unsigned_type,
        basic_signed_type,
        basic_float_type,
        composite_struct_type,
        composite_union_type,
        composite_enumeration_type,
        composite_array_type,
        composite_vector_type,
        derived_pointer_type,
        derived_member_type,
        subroutine_type,
        enumerator_unsigned,
        enumerator_signed_positive,
        enumerator_signed_negative,
        subrange,
        tuple,
        module_flag,
        expression,
        local_var,
        parameter,
        global_var,
        @"global_var local",
        global_var_expression,
        constant,

        pub fn isInline(tag: Tag) bool {
            return switch (tag) {
                .none,
                .expression,
                .constant,
                => true,
                .file,
                .compile_unit,
                .@"compile_unit optimized",
                .subprogram,
                .@"subprogram local",
                .@"subprogram definition",
                .@"subprogram local definition",
                .@"subprogram optimized",
                .@"subprogram optimized local",
                .@"subprogram optimized definition",
                .@"subprogram optimized local definition",
                .lexical_block,
                .location,
                .basic_bool_type,
                .basic_unsigned_type,
                .basic_signed_type,
                .basic_float_type,
                .composite_struct_type,
                .composite_union_type,
                .composite_enumeration_type,
                .composite_array_type,
                .composite_vector_type,
                .derived_pointer_type,
                .derived_member_type,
                .subroutine_type,
                .enumerator_unsigned,
                .enumerator_signed_positive,
                .enumerator_signed_negative,
                .subrange,
                .tuple,
                .module_flag,
                .local_var,
                .parameter,
                .global_var,
                .@"global_var local",
                .global_var_expression,
                => false,
            };
        }
    };

    pub fn isInline(self: Metadata, builder: *const Builder) bool {
        return builder.metadata_items.items(.tag)[@intFromEnum(self)].isInline();
    }

    pub fn unwrap(self: Metadata, builder: *const Builder) Metadata {
        var metadata = self;
        while (@intFromEnum(metadata) >= Metadata.first_forward_reference and
            @intFromEnum(metadata) < Metadata.first_local_metadata)
        {
            const index = @intFromEnum(metadata) - Metadata.first_forward_reference;
            metadata = builder.metadata_forward_references.items[index];
            assert(metadata != .none);
        }
        return metadata;
    }

    pub const Item = struct {
        tag: Tag,
        data: ExtraIndex,

        const ExtraIndex = u32;
    };

    pub const DIFlags = packed struct(u32) {
        Visibility: enum(u2) { Zero, Private, Protected, Public } = .Zero,
        FwdDecl: bool = false,
        AppleBlock: bool = false,
        ReservedBit4: u1 = 0,
        Virtual: bool = false,
        Artificial: bool = false,
        Explicit: bool = false,
        Prototyped: bool = false,
        ObjcClassComplete: bool = false,
        ObjectPointer: bool = false,
        Vector: bool = false,
        StaticMember: bool = false,
        LValueReference: bool = false,
        RValueReference: bool = false,
        ExportSymbols: bool = false,
        Inheritance: enum(u2) {
            Zero,
            SingleInheritance,
            MultipleInheritance,
            VirtualInheritance,
        } = .Zero,
        IntroducedVirtual: bool = false,
        BitField: bool = false,
        NoReturn: bool = false,
        ReservedBit21: u1 = 0,
        TypePassbyValue: bool = false,
        TypePassbyReference: bool = false,
        EnumClass: bool = false,
        Thunk: bool = false,
        NonTrivial: bool = false,
        BigEndian: bool = false,
        LittleEndian: bool = false,
        AllCallsDescribed: bool = false,
        Unused: u2 = 0,

        pub fn format(
            self: DIFlags,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            var need_pipe = false;
            inline for (@typeInfo(DIFlags).Struct.fields) |field| {
                switch (@typeInfo(field.type)) {
                    .Bool => if (@field(self, field.name)) {
                        if (need_pipe) try writer.writeAll(" | ") else need_pipe = true;
                        try writer.print("DIFlag{s}", .{field.name});
                    },
                    .Enum => if (@field(self, field.name) != .Zero) {
                        if (need_pipe) try writer.writeAll(" | ") else need_pipe = true;
                        try writer.print("DIFlag{s}", .{@tagName(@field(self, field.name))});
                    },
                    .Int => assert(@field(self, field.name) == 0),
                    else => @compileError("bad field type: " ++ field.name ++ ": " ++
                        @typeName(field.type)),
                }
            }
            if (!need_pipe) try writer.writeByte('0');
        }
    };

    pub const File = struct {
        filename: MetadataString,
        directory: MetadataString,
    };

    pub const CompileUnit = struct {
        pub const Options = struct {
            optimized: bool,
        };

        file: Metadata,
        producer: MetadataString,
        enums: Metadata,
        globals: Metadata,
    };

    pub const Subprogram = struct {
        pub const Options = struct {
            di_flags: DIFlags,
            sp_flags: DISPFlags,
        };

        pub const DISPFlags = packed struct(u32) {
            Virtuality: enum(u2) { Zero, Virtual, PureVirtual } = .Zero,
            LocalToUnit: bool = false,
            Definition: bool = false,
            Optimized: bool = false,
            Pure: bool = false,
            Elemental: bool = false,
            Recursive: bool = false,
            MainSubprogram: bool = false,
            Deleted: bool = false,
            ReservedBit10: u1 = 0,
            ObjCDirect: bool = false,
            Unused: u20 = 0,

            pub fn format(
                self: DISPFlags,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) @TypeOf(writer).Error!void {
                var need_pipe = false;
                inline for (@typeInfo(DISPFlags).Struct.fields) |field| {
                    switch (@typeInfo(field.type)) {
                        .Bool => if (@field(self, field.name)) {
                            if (need_pipe) try writer.writeAll(" | ") else need_pipe = true;
                            try writer.print("DISPFlag{s}", .{field.name});
                        },
                        .Enum => if (@field(self, field.name) != .Zero) {
                            if (need_pipe) try writer.writeAll(" | ") else need_pipe = true;
                            try writer.print("DISPFlag{s}", .{@tagName(@field(self, field.name))});
                        },
                        .Int => assert(@field(self, field.name) == 0),
                        else => @compileError("bad field type: " ++ field.name ++ ": " ++
                            @typeName(field.type)),
                    }
                }
                if (!need_pipe) try writer.writeByte('0');
            }
        };

        file: Metadata,
        name: MetadataString,
        linkage_name: MetadataString,
        line: u32,
        scope_line: u32,
        ty: Metadata,
        di_flags: DIFlags,
        compile_unit: Metadata,
    };

    pub const LexicalBlock = struct {
        scope: Metadata,
        file: Metadata,
        line: u32,
        column: u32,
    };

    pub const Location = struct {
        line: u32,
        column: u32,
        scope: Metadata,
        inlined_at: Metadata,
    };

    pub const BasicType = struct {
        name: MetadataString,
        size_in_bits_lo: u32,
        size_in_bits_hi: u32,

        pub fn bitSize(self: BasicType) u64 {
            return @as(u64, self.size_in_bits_hi) << 32 | self.size_in_bits_lo;
        }
    };

    pub const CompositeType = struct {
        name: MetadataString,
        file: Metadata,
        scope: Metadata,
        line: u32,
        underlying_type: Metadata,
        size_in_bits_lo: u32,
        size_in_bits_hi: u32,
        align_in_bits_lo: u32,
        align_in_bits_hi: u32,
        fields_tuple: Metadata,

        pub fn bitSize(self: CompositeType) u64 {
            return @as(u64, self.size_in_bits_hi) << 32 | self.size_in_bits_lo;
        }
        pub fn bitAlign(self: CompositeType) u64 {
            return @as(u64, self.align_in_bits_hi) << 32 | self.align_in_bits_lo;
        }
    };

    pub const DerivedType = struct {
        name: MetadataString,
        file: Metadata,
        scope: Metadata,
        line: u32,
        underlying_type: Metadata,
        size_in_bits_lo: u32,
        size_in_bits_hi: u32,
        align_in_bits_lo: u32,
        align_in_bits_hi: u32,
        offset_in_bits_lo: u32,
        offset_in_bits_hi: u32,

        pub fn bitSize(self: DerivedType) u64 {
            return @as(u64, self.size_in_bits_hi) << 32 | self.size_in_bits_lo;
        }
        pub fn bitAlign(self: DerivedType) u64 {
            return @as(u64, self.align_in_bits_hi) << 32 | self.align_in_bits_lo;
        }
        pub fn bitOffset(self: DerivedType) u64 {
            return @as(u64, self.offset_in_bits_hi) << 32 | self.offset_in_bits_lo;
        }
    };

    pub const SubroutineType = struct {
        types_tuple: Metadata,
    };

    pub const Enumerator = struct {
        name: MetadataString,
        bit_width: u32,
        limbs_index: u32,
        limbs_len: u32,
    };

    pub const Subrange = struct {
        lower_bound: Metadata,
        count: Metadata,
    };

    pub const Expression = struct {
        elements_len: u32,

        // elements: [elements_len]u32
    };

    pub const Tuple = struct {
        elements_len: u32,

        // elements: [elements_len]Metadata
    };

    pub const ModuleFlag = struct {
        behavior: Metadata,
        name: MetadataString,
        constant: Metadata,
    };

    pub const LocalVar = struct {
        name: MetadataString,
        file: Metadata,
        scope: Metadata,
        line: u32,
        ty: Metadata,
    };

    pub const Parameter = struct {
        name: MetadataString,
        file: Metadata,
        scope: Metadata,
        line: u32,
        ty: Metadata,
        arg_no: u32,
    };

    pub const GlobalVar = struct {
        pub const Options = struct {
            local: bool,
        };

        name: MetadataString,
        linkage_name: MetadataString,
        file: Metadata,
        scope: Metadata,
        line: u32,
        ty: Metadata,
        variable: Variable.Index,
    };

    pub const GlobalVarExpression = struct {
        variable: Metadata,
        expression: Metadata,
    };

    pub fn toValue(self: Metadata) Value {
        return @enumFromInt(Value.first_metadata + @intFromEnum(self));
    }

    const Formatter = struct {
        builder: *Builder,
        need_comma: bool,
        map: std.AutoArrayHashMapUnmanaged(union(enum) {
            metadata: Metadata,
            debug_location: DebugLocation.Location,
        }, void) = .{},

        const FormatData = struct {
            formatter: *Formatter,
            prefix: []const u8 = "",
            node: Node,

            const Node = union(enum) {
                none,
                @"inline": Metadata,
                index: u32,

                local_value: ValueData,
                local_metadata: ValueData,
                local_inline: Metadata,
                local_index: u32,

                string: MetadataString,
                bool: bool,
                u32: u32,
                u64: u64,
                di_flags: DIFlags,
                sp_flags: Subprogram.DISPFlags,
                raw: []const u8,

                const ValueData = struct {
                    value: Value,
                    function: Function.Index,
                };
            };
        };
        fn format(
            data: FormatData,
            comptime fmt_str: []const u8,
            fmt_opts: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            if (data.node == .none) return;

            const is_specialized = fmt_str.len > 0 and fmt_str[0] == 'S';
            const recurse_fmt_str = if (is_specialized) fmt_str[1..] else fmt_str;

            if (data.formatter.need_comma) try writer.writeAll(", ");
            defer data.formatter.need_comma = true;
            try writer.writeAll(data.prefix);

            const builder = data.formatter.builder;
            switch (data.node) {
                .none => unreachable,
                .@"inline" => |node| {
                    const needed_comma = data.formatter.need_comma;
                    defer data.formatter.need_comma = needed_comma;
                    data.formatter.need_comma = false;

                    const item = builder.metadata_items.get(@intFromEnum(node));
                    switch (item.tag) {
                        .expression => {
                            var extra = builder.metadataExtraDataTrail(Expression, item.data);
                            const elements = extra.trail.next(extra.data.elements_len, u32, builder);
                            try writer.writeAll("!DIExpression(");
                            for (elements) |element| try format(.{
                                .formatter = data.formatter,
                                .node = .{ .u64 = element },
                            }, "%", fmt_opts, writer);
                            try writer.writeByte(')');
                        },
                        .constant => try Constant.format(.{
                            .constant = @enumFromInt(item.data),
                            .builder = builder,
                        }, recurse_fmt_str, fmt_opts, writer),
                        else => unreachable,
                    }
                },
                .index => |node| try writer.print("!{d}", .{node}),
                inline .local_value, .local_metadata => |node, tag| try Value.format(.{
                    .value = node.value,
                    .function = node.function,
                    .builder = builder,
                }, switch (tag) {
                    .local_value => recurse_fmt_str,
                    .local_metadata => "%",
                    else => unreachable,
                }, fmt_opts, writer),
                inline .local_inline, .local_index => |node, tag| {
                    if (comptime std.mem.eql(u8, recurse_fmt_str, "%"))
                        try writer.print("{%} ", .{Type.metadata.fmt(builder)});
                    try format(.{
                        .formatter = data.formatter,
                        .node = @unionInit(FormatData.Node, @tagName(tag)["local_".len..], node),
                    }, "%", fmt_opts, writer);
                },
                .string => |node| try writer.print((if (is_specialized) "" else "!") ++ "{}", .{
                    node.fmt(builder),
                }),
                inline .bool,
                .u32,
                .u64,
                .di_flags,
                .sp_flags,
                => |node| try writer.print("{}", .{node}),
                .raw => |node| try writer.writeAll(node),
            }
        }
        inline fn fmt(formatter: *Formatter, prefix: []const u8, node: anytype) switch (@TypeOf(node)) {
            Metadata => Allocator.Error,
            else => error{},
        }!std.fmt.Formatter(format) {
            const Node = @TypeOf(node);
            const MaybeNode = switch (@typeInfo(Node)) {
                .Optional => Node,
                .Null => ?noreturn,
                else => ?Node,
            };
            const Some = @typeInfo(MaybeNode).Optional.child;
            return .{ .data = .{
                .formatter = formatter,
                .prefix = prefix,
                .node = if (@as(MaybeNode, node)) |some| switch (@typeInfo(Some)) {
                    .Enum => |enum_info| switch (Some) {
                        Metadata => switch (some) {
                            .none => .none,
                            else => try formatter.refUnwrapped(some.unwrap(formatter.builder)),
                        },
                        MetadataString => .{ .string = some },
                        else => if (enum_info.is_exhaustive)
                            .{ .raw = @tagName(some) }
                        else
                            @compileError("unknown type to format: " ++ @typeName(Node)),
                    },
                    .EnumLiteral => .{ .raw = @tagName(some) },
                    .Bool => .{ .bool = some },
                    .Struct => switch (Some) {
                        DIFlags => .{ .di_flags = some },
                        Subprogram.DISPFlags => .{ .sp_flags = some },
                        else => @compileError("unknown type to format: " ++ @typeName(Node)),
                    },
                    .Int, .ComptimeInt => .{ .u64 = some },
                    .Pointer => .{ .raw = some },
                    else => @compileError("unknown type to format: " ++ @typeName(Node)),
                } else switch (@typeInfo(Node)) {
                    .Optional, .Null => .none,
                    else => unreachable,
                },
            } };
        }
        inline fn fmtLocal(
            formatter: *Formatter,
            prefix: []const u8,
            value: Value,
            function: Function.Index,
        ) Allocator.Error!std.fmt.Formatter(format) {
            return .{ .data = .{
                .formatter = formatter,
                .prefix = prefix,
                .node = switch (value.unwrap()) {
                    .instruction, .constant => .{ .local_value = .{
                        .value = value,
                        .function = function,
                    } },
                    .metadata => |metadata| if (value == .none) .none else node: {
                        const unwrapped = metadata.unwrap(formatter.builder);
                        break :node if (@intFromEnum(unwrapped) >= first_local_metadata)
                            .{ .local_metadata = .{
                                .value = function.ptrConst(formatter.builder).debug_values[
                                    @intFromEnum(unwrapped) - first_local_metadata
                                ].toValue(),
                                .function = function,
                            } }
                        else switch (try formatter.refUnwrapped(unwrapped)) {
                            .@"inline" => |node| .{ .local_inline = node },
                            .index => |node| .{ .local_index = node },
                            else => unreachable,
                        };
                    },
                },
            } };
        }
        fn refUnwrapped(formatter: *Formatter, node: Metadata) Allocator.Error!FormatData.Node {
            assert(node != .none);
            assert(@intFromEnum(node) < first_forward_reference);
            const builder = formatter.builder;
            const unwrapped_metadata = node.unwrap(builder);
            const tag = formatter.builder.metadata_items.items(.tag)[@intFromEnum(unwrapped_metadata)];
            switch (tag) {
                .none => unreachable,
                .expression, .constant => return .{ .@"inline" = unwrapped_metadata },
                else => {
                    assert(!tag.isInline());
                    const gop = try formatter.map.getOrPut(builder.gpa, .{ .metadata = unwrapped_metadata });
                    return .{ .index = @intCast(gop.index) };
                },
            }
        }

        inline fn specialized(
            formatter: *Formatter,
            distinct: enum { @"!", @"distinct !" },
            node: enum {
                DIFile,
                DICompileUnit,
                DISubprogram,
                DILexicalBlock,
                DILocation,
                DIBasicType,
                DICompositeType,
                DIDerivedType,
                DISubroutineType,
                DIEnumerator,
                DISubrange,
                DILocalVariable,
                DIGlobalVariable,
                DIGlobalVariableExpression,
            },
            nodes: anytype,
            writer: anytype,
        ) !void {
            comptime var fmt_str: []const u8 = "";
            const names = comptime std.meta.fieldNames(@TypeOf(nodes));
            comptime var fields: [2 + names.len]std.builtin.Type.StructField = undefined;
            inline for (fields[0..2], .{ "distinct", "node" }) |*field, name| {
                fmt_str = fmt_str ++ "{[" ++ name ++ "]s}";
                field.* = .{
                    .name = name,
                    .type = []const u8,
                    .default_value = null,
                    .is_comptime = false,
                    .alignment = 0,
                };
            }
            fmt_str = fmt_str ++ "(";
            inline for (fields[2..], names) |*field, name| {
                fmt_str = fmt_str ++ "{[" ++ name ++ "]S}";
                field.* = .{
                    .name = name,
                    .type = std.fmt.Formatter(format),
                    .default_value = null,
                    .is_comptime = false,
                    .alignment = 0,
                };
            }
            fmt_str = fmt_str ++ ")\n";

            var fmt_args: @Type(.{ .Struct = .{
                .layout = .auto,
                .fields = &fields,
                .decls = &.{},
                .is_tuple = false,
            } }) = undefined;
            fmt_args.distinct = @tagName(distinct);
            fmt_args.node = @tagName(node);
            inline for (names) |name| @field(fmt_args, name) = try formatter.fmt(
                name ++ ": ",
                @field(nodes, name),
            );
            try writer.print(fmt_str, fmt_args);
        }
    };
};

pub fn init(options: Options) Allocator.Error!Builder {
    var self = Builder{
        .gpa = options.allocator,
        .strip = options.strip,

        .source_filename = .none,
        .data_layout = .none,
        .target_triple = .none,
        .module_asm = .{},

        .string_map = .{},
        .string_indices = .{},
        .string_bytes = .{},

        .types = .{},
        .next_unnamed_type = @enumFromInt(0),
        .next_unique_type_id = .{},
        .type_map = .{},
        .type_items = .{},
        .type_extra = .{},

        .attributes = .{},
        .attributes_map = .{},
        .attributes_indices = .{},
        .attributes_extra = .{},

        .function_attributes_set = .{},

        .globals = .{},
        .next_unnamed_global = @enumFromInt(0),
        .next_replaced_global = .none,
        .next_unique_global_id = .{},
        .aliases = .{},
        .variables = .{},
        .functions = .{},

        .strtab_string_map = .{},
        .strtab_string_indices = .{},
        .strtab_string_bytes = .{},

        .constant_map = .{},
        .constant_items = .{},
        .constant_extra = .{},
        .constant_limbs = .{},

        .metadata_map = .{},
        .metadata_items = .{},
        .metadata_extra = .{},
        .metadata_limbs = .{},
        .metadata_forward_references = .{},
        .metadata_named = .{},
        .metadata_string_map = .{},
        .metadata_string_indices = .{},
        .metadata_string_bytes = .{},
    };
    errdefer self.deinit();

    try self.string_indices.append(self.gpa, 0);
    assert(try self.string("") == .empty);

    try self.strtab_string_indices.append(self.gpa, 0);
    assert(try self.strtabString("") == .empty);

    if (options.name.len > 0) self.source_filename = try self.string(options.name);

    if (options.triple.len > 0) {
        self.target_triple = try self.string(options.triple);
    }

    {
        const static_len = @typeInfo(Type).Enum.fields.len - 1;
        try self.type_map.ensureTotalCapacity(self.gpa, static_len);
        try self.type_items.ensureTotalCapacity(self.gpa, static_len);
        inline for (@typeInfo(Type.Simple).Enum.fields) |simple_field| {
            const result = self.getOrPutTypeNoExtraAssumeCapacity(
                .{ .tag = .simple, .data = simple_field.value },
            );
            assert(result.new and result.type == @field(Type, simple_field.name));
        }
        inline for (.{ 1, 8, 16, 29, 32, 64, 80, 128 }) |bits|
            assert(self.intTypeAssumeCapacity(bits) ==
                @field(Type, std.fmt.comptimePrint("i{d}", .{bits})));
        inline for (.{ 0, 4 }) |addr_space_index| {
            const addr_space: AddrSpace = @enumFromInt(addr_space_index);
            assert(self.ptrTypeAssumeCapacity(addr_space) ==
                @field(Type, std.fmt.comptimePrint("ptr{ }", .{addr_space})));
        }
    }

    {
        try self.attributes_indices.append(self.gpa, 0);
        assert(try self.attrs(&.{}) == .none);
        assert(try self.fnAttrs(&.{}) == .none);
    }

    assert(try self.intConst(.i1, 0) == .false);
    assert(try self.intConst(.i1, 1) == .true);
    assert(try self.intConst(.i32, 0) == .@"0");
    assert(try self.intConst(.i32, 1) == .@"1");
    assert(try self.noneConst(.token) == .none);
    if (!self.strip) assert(try self.debugNone() == .none);

    try self.metadata_string_indices.append(self.gpa, 0);
    assert(try self.metadataString("") == .none);

    return self;
}

pub fn clearAndFree(self: *Builder) void {
    self.module_asm.clearAndFree(self.gpa);

    self.string_map.clearAndFree(self.gpa);
    self.string_indices.clearAndFree(self.gpa);
    self.string_bytes.clearAndFree(self.gpa);

    self.types.clearAndFree(self.gpa);
    self.next_unique_type_id.clearAndFree(self.gpa);
    self.type_map.clearAndFree(self.gpa);
    self.type_items.clearAndFree(self.gpa);
    self.type_extra.clearAndFree(self.gpa);

    self.attributes.clearAndFree(self.gpa);
    self.attributes_map.clearAndFree(self.gpa);
    self.attributes_indices.clearAndFree(self.gpa);
    self.attributes_extra.clearAndFree(self.gpa);

    self.function_attributes_set.clearAndFree(self.gpa);

    self.globals.clearAndFree(self.gpa);
    self.next_unique_global_id.clearAndFree(self.gpa);
    self.aliases.clearAndFree(self.gpa);
    self.variables.clearAndFree(self.gpa);
    for (self.functions.items) |*function| function.deinit(self.gpa);
    self.functions.clearAndFree(self.gpa);

    self.strtab_string_map.clearAndFree(self.gpa);
    self.strtab_string_indices.clearAndFree(self.gpa);
    self.strtab_string_bytes.clearAndFree(self.gpa);

    self.constant_map.clearAndFree(self.gpa);
    self.constant_items.shrinkAndFree(self.gpa, 0);
    self.constant_extra.clearAndFree(self.gpa);
    self.constant_limbs.clearAndFree(self.gpa);

    self.metadata_map.clearAndFree(self.gpa);
    self.metadata_items.shrinkAndFree(self.gpa, 0);
    self.metadata_extra.clearAndFree(self.gpa);
    self.metadata_limbs.clearAndFree(self.gpa);
    self.metadata_forward_references.clearAndFree(self.gpa);
    self.metadata_named.clearAndFree(self.gpa);

    self.metadata_string_map.clearAndFree(self.gpa);
    self.metadata_string_indices.clearAndFree(self.gpa);
    self.metadata_string_bytes.clearAndFree(self.gpa);
}

pub fn deinit(self: *Builder) void {
    self.module_asm.deinit(self.gpa);

    self.string_map.deinit(self.gpa);
    self.string_indices.deinit(self.gpa);
    self.string_bytes.deinit(self.gpa);

    self.types.deinit(self.gpa);
    self.next_unique_type_id.deinit(self.gpa);
    self.type_map.deinit(self.gpa);
    self.type_items.deinit(self.gpa);
    self.type_extra.deinit(self.gpa);

    self.attributes.deinit(self.gpa);
    self.attributes_map.deinit(self.gpa);
    self.attributes_indices.deinit(self.gpa);
    self.attributes_extra.deinit(self.gpa);

    self.function_attributes_set.deinit(self.gpa);

    self.globals.deinit(self.gpa);
    self.next_unique_global_id.deinit(self.gpa);
    self.aliases.deinit(self.gpa);
    self.variables.deinit(self.gpa);
    for (self.functions.items) |*function| function.deinit(self.gpa);
    self.functions.deinit(self.gpa);

    self.strtab_string_map.deinit(self.gpa);
    self.strtab_string_indices.deinit(self.gpa);
    self.strtab_string_bytes.deinit(self.gpa);

    self.constant_map.deinit(self.gpa);
    self.constant_items.deinit(self.gpa);
    self.constant_extra.deinit(self.gpa);
    self.constant_limbs.deinit(self.gpa);

    self.metadata_map.deinit(self.gpa);
    self.metadata_items.deinit(self.gpa);
    self.metadata_extra.deinit(self.gpa);
    self.metadata_limbs.deinit(self.gpa);
    self.metadata_forward_references.deinit(self.gpa);
    self.metadata_named.deinit(self.gpa);

    self.metadata_string_map.deinit(self.gpa);
    self.metadata_string_indices.deinit(self.gpa);
    self.metadata_string_bytes.deinit(self.gpa);

    self.* = undefined;
}

pub fn setModuleAsm(self: *Builder) std.ArrayListUnmanaged(u8).Writer {
    self.module_asm.clearRetainingCapacity();
    return self.appendModuleAsm();
}

pub fn appendModuleAsm(self: *Builder) std.ArrayListUnmanaged(u8).Writer {
    return self.module_asm.writer(self.gpa);
}

pub fn finishModuleAsm(self: *Builder) Allocator.Error!void {
    if (self.module_asm.getLastOrNull()) |last| if (last != '\n')
        try self.module_asm.append(self.gpa, '\n');
}

pub fn string(self: *Builder, bytes: []const u8) Allocator.Error!String {
    try self.string_bytes.ensureUnusedCapacity(self.gpa, bytes.len);
    try self.string_indices.ensureUnusedCapacity(self.gpa, 1);
    try self.string_map.ensureUnusedCapacity(self.gpa, 1);

    const gop = self.string_map.getOrPutAssumeCapacityAdapted(bytes, String.Adapter{ .builder = self });
    if (!gop.found_existing) {
        self.string_bytes.appendSliceAssumeCapacity(bytes);
        self.string_indices.appendAssumeCapacity(@intCast(self.string_bytes.items.len));
    }
    return String.fromIndex(gop.index);
}

pub fn stringNull(self: *Builder, bytes: [:0]const u8) Allocator.Error!String {
    return self.string(bytes[0 .. bytes.len + 1]);
}

pub fn stringIfExists(self: *const Builder, bytes: []const u8) ?String {
    return String.fromIndex(
        self.string_map.getIndexAdapted(bytes, String.Adapter{ .builder = self }) orelse return null,
    );
}

pub fn fmt(self: *Builder, comptime fmt_str: []const u8, fmt_args: anytype) Allocator.Error!String {
    try self.string_map.ensureUnusedCapacity(self.gpa, 1);
    try self.string_bytes.ensureUnusedCapacity(self.gpa, @intCast(std.fmt.count(fmt_str, fmt_args)));
    try self.string_indices.ensureUnusedCapacity(self.gpa, 1);
    return self.fmtAssumeCapacity(fmt_str, fmt_args);
}

pub fn fmtAssumeCapacity(self: *Builder, comptime fmt_str: []const u8, fmt_args: anytype) String {
    self.string_bytes.writer(undefined).print(fmt_str, fmt_args) catch unreachable;
    return self.trailingStringAssumeCapacity();
}

pub fn trailingString(self: *Builder) Allocator.Error!String {
    try self.string_indices.ensureUnusedCapacity(self.gpa, 1);
    try self.string_map.ensureUnusedCapacity(self.gpa, 1);
    return self.trailingStringAssumeCapacity();
}

pub fn trailingStringAssumeCapacity(self: *Builder) String {
    const start = self.string_indices.getLast();
    const bytes: []const u8 = self.string_bytes.items[start..];
    const gop = self.string_map.getOrPutAssumeCapacityAdapted(bytes, String.Adapter{ .builder = self });
    if (gop.found_existing) {
        self.string_bytes.shrinkRetainingCapacity(start);
    } else {
        self.string_indices.appendAssumeCapacity(@intCast(self.string_bytes.items.len));
    }
    return String.fromIndex(gop.index);
}

pub fn fnType(
    self: *Builder,
    ret: Type,
    params: []const Type,
    kind: Type.Function.Kind,
) Allocator.Error!Type {
    try self.ensureUnusedTypeCapacity(1, Type.Function, params.len);
    switch (kind) {
        inline else => |comptime_kind| return self.fnTypeAssumeCapacity(ret, params, comptime_kind),
    }
}

pub fn intType(self: *Builder, bits: u24) Allocator.Error!Type {
    try self.ensureUnusedTypeCapacity(1, NoExtra, 0);
    return self.intTypeAssumeCapacity(bits);
}

pub fn ptrType(self: *Builder, addr_space: AddrSpace) Allocator.Error!Type {
    try self.ensureUnusedTypeCapacity(1, NoExtra, 0);
    return self.ptrTypeAssumeCapacity(addr_space);
}

pub fn vectorType(
    self: *Builder,
    kind: Type.Vector.Kind,
    len: u32,
    child: Type,
) Allocator.Error!Type {
    try self.ensureUnusedTypeCapacity(1, Type.Vector, 0);
    switch (kind) {
        inline else => |comptime_kind| return self.vectorTypeAssumeCapacity(comptime_kind, len, child),
    }
}

pub fn arrayType(self: *Builder, len: u64, child: Type) Allocator.Error!Type {
    comptime assert(@sizeOf(Type.Array) >= @sizeOf(Type.Vector));
    try self.ensureUnusedTypeCapacity(1, Type.Array, 0);
    return self.arrayTypeAssumeCapacity(len, child);
}

pub fn structType(
    self: *Builder,
    kind: Type.Structure.Kind,
    fields: []const Type,
) Allocator.Error!Type {
    try self.ensureUnusedTypeCapacity(1, Type.Structure, fields.len);
    switch (kind) {
        inline else => |comptime_kind| return self.structTypeAssumeCapacity(comptime_kind, fields),
    }
}

pub fn opaqueType(self: *Builder, name: String) Allocator.Error!Type {
    try self.string_map.ensureUnusedCapacity(self.gpa, 1);
    if (name.slice(self)) |id| {
        const count: usize = comptime std.fmt.count("{d}", .{std.math.maxInt(u32)});
        try self.string_bytes.ensureUnusedCapacity(self.gpa, id.len + count);
    }
    try self.string_indices.ensureUnusedCapacity(self.gpa, 1);
    try self.types.ensureUnusedCapacity(self.gpa, 1);
    try self.next_unique_type_id.ensureUnusedCapacity(self.gpa, 1);
    try self.ensureUnusedTypeCapacity(1, Type.NamedStructure, 0);
    return self.opaqueTypeAssumeCapacity(name);
}

pub fn namedTypeSetBody(
    self: *Builder,
    named_type: Type,
    body_type: Type,
) void {
    const named_item = self.type_items.items[@intFromEnum(named_type)];
    self.type_extra.items[named_item.data + std.meta.fieldIndex(Type.NamedStructure, "body").?] =
        @intFromEnum(body_type);
}

pub fn attr(self: *Builder, attribute: Attribute) Allocator.Error!Attribute.Index {
    try self.attributes.ensureUnusedCapacity(self.gpa, 1);

    const gop = self.attributes.getOrPutAssumeCapacity(attribute.toStorage());
    if (!gop.found_existing) gop.value_ptr.* = {};
    return @enumFromInt(gop.index);
}

pub fn attrs(self: *Builder, attributes: []Attribute.Index) Allocator.Error!Attributes {
    std.sort.heap(Attribute.Index, attributes, self, struct {
        pub fn lessThan(builder: *const Builder, lhs: Attribute.Index, rhs: Attribute.Index) bool {
            const lhs_kind = lhs.getKind(builder);
            const rhs_kind = rhs.getKind(builder);
            assert(lhs_kind != rhs_kind);
            return @intFromEnum(lhs_kind) < @intFromEnum(rhs_kind);
        }
    }.lessThan);
    return @enumFromInt(try self.attrGeneric(@ptrCast(attributes)));
}

pub fn fnAttrs(self: *Builder, fn_attributes: []const Attributes) Allocator.Error!FunctionAttributes {
    try self.function_attributes_set.ensureUnusedCapacity(self.gpa, 1);
    const function_attributes: FunctionAttributes = @enumFromInt(try self.attrGeneric(@ptrCast(
        fn_attributes[0..if (std.mem.lastIndexOfNone(Attributes, fn_attributes, &.{.none})) |last|
            last + 1
        else
            0],
    )));

    _ = self.function_attributes_set.getOrPutAssumeCapacity(function_attributes);
    return function_attributes;
}

pub fn addGlobal(self: *Builder, name: StrtabString, global: Global) Allocator.Error!Global.Index {
    assert(!name.isAnon());
    try self.ensureUnusedTypeCapacity(1, NoExtra, 0);
    try self.ensureUnusedGlobalCapacity(name);
    return self.addGlobalAssumeCapacity(name, global);
}

pub fn addGlobalAssumeCapacity(self: *Builder, name: StrtabString, global: Global) Global.Index {
    _ = self.ptrTypeAssumeCapacity(global.addr_space);
    var id = name;
    if (name == .empty) {
        id = self.next_unnamed_global;
        assert(id != self.next_replaced_global);
        self.next_unnamed_global = @enumFromInt(@intFromEnum(id) + 1);
    }
    while (true) {
        const global_gop = self.globals.getOrPutAssumeCapacity(id);
        if (!global_gop.found_existing) {
            global_gop.value_ptr.* = global;
            const global_index: Global.Index = @enumFromInt(global_gop.index);
            global_index.updateDsoLocal(self);
            return global_index;
        }

        const unique_gop = self.next_unique_global_id.getOrPutAssumeCapacity(name);
        if (!unique_gop.found_existing) unique_gop.value_ptr.* = 2;
        id = self.strtabStringFmtAssumeCapacity("{s}.{d}", .{ name.slice(self).?, unique_gop.value_ptr.* });
        unique_gop.value_ptr.* += 1;
    }
}

pub fn getGlobal(self: *const Builder, name: StrtabString) ?Global.Index {
    return @enumFromInt(self.globals.getIndex(name) orelse return null);
}

pub fn addAlias(
    self: *Builder,
    name: StrtabString,
    ty: Type,
    addr_space: AddrSpace,
    aliasee: Constant,
) Allocator.Error!Alias.Index {
    assert(!name.isAnon());
    try self.ensureUnusedTypeCapacity(1, NoExtra, 0);
    try self.ensureUnusedGlobalCapacity(name);
    try self.aliases.ensureUnusedCapacity(self.gpa, 1);
    return self.addAliasAssumeCapacity(name, ty, addr_space, aliasee);
}

pub fn addAliasAssumeCapacity(
    self: *Builder,
    name: StrtabString,
    ty: Type,
    addr_space: AddrSpace,
    aliasee: Constant,
) Alias.Index {
    const alias_index: Alias.Index = @enumFromInt(self.aliases.items.len);
    self.aliases.appendAssumeCapacity(.{ .global = self.addGlobalAssumeCapacity(name, .{
        .addr_space = addr_space,
        .type = ty,
        .kind = .{ .alias = alias_index },
    }), .aliasee = aliasee });
    return alias_index;
}

pub fn addVariable(
    self: *Builder,
    name: StrtabString,
    ty: Type,
    addr_space: AddrSpace,
) Allocator.Error!Variable.Index {
    assert(!name.isAnon());
    try self.ensureUnusedTypeCapacity(1, NoExtra, 0);
    try self.ensureUnusedGlobalCapacity(name);
    try self.variables.ensureUnusedCapacity(self.gpa, 1);
    return self.addVariableAssumeCapacity(ty, name, addr_space);
}

pub fn addVariableAssumeCapacity(
    self: *Builder,
    ty: Type,
    name: StrtabString,
    addr_space: AddrSpace,
) Variable.Index {
    const variable_index: Variable.Index = @enumFromInt(self.variables.items.len);
    self.variables.appendAssumeCapacity(.{ .global = self.addGlobalAssumeCapacity(name, .{
        .addr_space = addr_space,
        .type = ty,
        .kind = .{ .variable = variable_index },
    }) });
    return variable_index;
}

pub fn addFunction(
    self: *Builder,
    ty: Type,
    name: StrtabString,
    addr_space: AddrSpace,
) Allocator.Error!Function.Index {
    assert(!name.isAnon());
    try self.ensureUnusedTypeCapacity(1, NoExtra, 0);
    try self.ensureUnusedGlobalCapacity(name);
    try self.functions.ensureUnusedCapacity(self.gpa, 1);
    return self.addFunctionAssumeCapacity(ty, name, addr_space);
}

pub fn addFunctionAssumeCapacity(
    self: *Builder,
    ty: Type,
    name: StrtabString,
    addr_space: AddrSpace,
) Function.Index {
    assert(ty.isFunction(self));
    const function_index: Function.Index = @enumFromInt(self.functions.items.len);
    self.functions.appendAssumeCapacity(.{
        .global = self.addGlobalAssumeCapacity(name, .{
            .addr_space = addr_space,
            .type = ty,
            .kind = .{ .function = function_index },
        }),
        .strip = undefined,
    });
    return function_index;
}

pub fn getIntrinsic(
    self: *Builder,
    id: Intrinsic,
    overload: []const Type,
) Allocator.Error!Function.Index {
    const ExpectedContents = extern union {
        attrs: extern struct {
            params: [expected_args_len]Type,
            fn_attrs: [FunctionAttributes.params_index + expected_args_len]Attributes,
            attrs: [expected_attrs_len]Attribute.Index,
            fields: [expected_fields_len]Type,
        },
    };
    var stack align(@max(@alignOf(std.heap.StackFallbackAllocator(0)), @alignOf(ExpectedContents))) =
        std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
    const allocator = stack.get();

    const name = name: {
        const writer = self.strtab_string_bytes.writer(self.gpa);
        try writer.print("llvm.{s}", .{@tagName(id)});
        for (overload) |ty| try writer.print(".{m}", .{ty.fmt(self)});
        break :name try self.trailingStrtabString();
    };
    if (self.getGlobal(name)) |global| return global.ptrConst(self).kind.function;

    const signature = Intrinsic.signatures.get(id);
    const param_types = try allocator.alloc(Type, signature.params.len);
    defer allocator.free(param_types);
    const function_attributes = try allocator.alloc(
        Attributes,
        FunctionAttributes.params_index + (signature.params.len - signature.ret_len),
    );
    defer allocator.free(function_attributes);

    var attributes: struct {
        builder: *Builder,
        list: std.ArrayList(Attribute.Index),

        fn deinit(state: *@This()) void {
            state.list.deinit();
            state.* = undefined;
        }

        fn get(state: *@This(), attributes: []const Attribute) Allocator.Error!Attributes {
            try state.list.resize(attributes.len);
            for (state.list.items, attributes) |*item, attribute|
                item.* = try state.builder.attr(attribute);
            return state.builder.attrs(state.list.items);
        }
    } = .{ .builder = self, .list = std.ArrayList(Attribute.Index).init(allocator) };
    defer attributes.deinit();

    var overload_index: usize = 0;
    function_attributes[FunctionAttributes.function_index] = try attributes.get(signature.attrs);
    function_attributes[FunctionAttributes.return_index] = .none; // needed for void return
    for (0.., param_types, signature.params) |param_index, *param_type, signature_param| {
        switch (signature_param.kind) {
            .type => |ty| param_type.* = ty,
            .overloaded => {
                param_type.* = overload[overload_index];
                overload_index += 1;
            },
            .matches, .matches_scalar, .matches_changed_scalar => {},
        }
        function_attributes[
            if (param_index < signature.ret_len)
                FunctionAttributes.return_index
            else
                FunctionAttributes.params_index + (param_index - signature.ret_len)
        ] = try attributes.get(signature_param.attrs);
    }
    assert(overload_index == overload.len);
    for (param_types, signature.params) |*param_type, signature_param| {
        param_type.* = switch (signature_param.kind) {
            .type, .overloaded => continue,
            .matches => |param_index| param_types[param_index],
            .matches_scalar => |param_index| param_types[param_index].scalarType(self),
            .matches_changed_scalar => |info| try param_types[info.index]
                .changeScalar(info.scalar, self),
        };
    }

    const function_index = try self.addFunction(try self.fnType(switch (signature.ret_len) {
        0 => .void,
        1 => param_types[0],
        else => try self.structType(.normal, param_types[0..signature.ret_len]),
    }, param_types[signature.ret_len..], .normal), name, .default);
    function_index.ptr(self).attributes = try self.fnAttrs(function_attributes);
    return function_index;
}

pub fn intConst(self: *Builder, ty: Type, value: anytype) Allocator.Error!Constant {
    const int_value = switch (@typeInfo(@TypeOf(value))) {
        .Int, .ComptimeInt => value,
        .Enum => @intFromEnum(value),
        else => @compileError("intConst expected an integral value, got " ++ @typeName(@TypeOf(value))),
    };
    var limbs: [
        switch (@typeInfo(@TypeOf(int_value))) {
            .Int => |info| std.math.big.int.calcTwosCompLimbCount(info.bits),
            .ComptimeInt => std.math.big.int.calcLimbLen(int_value),
            else => unreachable,
        }
    ]std.math.big.Limb = undefined;
    return self.bigIntConst(ty, std.math.big.int.Mutable.init(&limbs, int_value).toConst());
}

pub fn intValue(self: *Builder, ty: Type, value: anytype) Allocator.Error!Value {
    return (try self.intConst(ty, value)).toValue();
}

pub fn bigIntConst(self: *Builder, ty: Type, value: std.math.big.int.Const) Allocator.Error!Constant {
    try self.constant_map.ensureUnusedCapacity(self.gpa, 1);
    try self.constant_items.ensureUnusedCapacity(self.gpa, 1);
    try self.constant_limbs.ensureUnusedCapacity(self.gpa, Constant.Integer.limbs + value.limbs.len);
    return self.bigIntConstAssumeCapacity(ty, value);
}

pub fn bigIntValue(self: *Builder, ty: Type, value: std.math.big.int.Const) Allocator.Error!Value {
    return (try self.bigIntConst(ty, value)).toValue();
}

pub fn fpConst(self: *Builder, ty: Type, comptime val: comptime_float) Allocator.Error!Constant {
    return switch (ty) {
        .half => try self.halfConst(val),
        .bfloat => try self.bfloatConst(val),
        .float => try self.floatConst(val),
        .double => try self.doubleConst(val),
        .fp128 => try self.fp128Const(val),
        .x86_fp80 => try self.x86_fp80Const(val),
        .ppc_fp128 => try self.ppc_fp128Const(.{ val, -0.0 }),
        else => unreachable,
    };
}

pub fn fpValue(self: *Builder, ty: Type, comptime value: comptime_float) Allocator.Error!Value {
    return (try self.fpConst(ty, value)).toValue();
}

pub fn nanConst(self: *Builder, ty: Type) Allocator.Error!Constant {
    return switch (ty) {
        .half => try self.halfConst(std.math.nan(f16)),
        .bfloat => try self.bfloatConst(std.math.nan(f32)),
        .float => try self.floatConst(std.math.nan(f32)),
        .double => try self.doubleConst(std.math.nan(f64)),
        .fp128 => try self.fp128Const(std.math.nan(f128)),
        .x86_fp80 => try self.x86_fp80Const(std.math.nan(f80)),
        .ppc_fp128 => try self.ppc_fp128Const(.{std.math.nan(f64)} ** 2),
        else => unreachable,
    };
}

pub fn nanValue(self: *Builder, ty: Type) Allocator.Error!Value {
    return (try self.nanConst(ty)).toValue();
}

pub fn halfConst(self: *Builder, val: f16) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, NoExtra, 0);
    return self.halfConstAssumeCapacity(val);
}

pub fn halfValue(self: *Builder, ty: Type, value: f16) Allocator.Error!Value {
    return (try self.halfConst(ty, value)).toValue();
}

pub fn bfloatConst(self: *Builder, val: f32) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, NoExtra, 0);
    return self.bfloatConstAssumeCapacity(val);
}

pub fn bfloatValue(self: *Builder, ty: Type, value: f32) Allocator.Error!Value {
    return (try self.bfloatConst(ty, value)).toValue();
}

pub fn floatConst(self: *Builder, val: f32) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, NoExtra, 0);
    return self.floatConstAssumeCapacity(val);
}

pub fn floatValue(self: *Builder, ty: Type, value: f32) Allocator.Error!Value {
    return (try self.floatConst(ty, value)).toValue();
}

pub fn doubleConst(self: *Builder, val: f64) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Double, 0);
    return self.doubleConstAssumeCapacity(val);
}

pub fn doubleValue(self: *Builder, ty: Type, value: f64) Allocator.Error!Value {
    return (try self.doubleConst(ty, value)).toValue();
}

pub fn fp128Const(self: *Builder, val: f128) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Fp128, 0);
    return self.fp128ConstAssumeCapacity(val);
}

pub fn fp128Value(self: *Builder, ty: Type, value: f128) Allocator.Error!Value {
    return (try self.fp128Const(ty, value)).toValue();
}

pub fn x86_fp80Const(self: *Builder, val: f80) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Fp80, 0);
    return self.x86_fp80ConstAssumeCapacity(val);
}

pub fn x86_fp80Value(self: *Builder, ty: Type, value: f80) Allocator.Error!Value {
    return (try self.x86_fp80Const(ty, value)).toValue();
}

pub fn ppc_fp128Const(self: *Builder, val: [2]f64) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Fp128, 0);
    return self.ppc_fp128ConstAssumeCapacity(val);
}

pub fn ppc_fp128Value(self: *Builder, ty: Type, value: [2]f64) Allocator.Error!Value {
    return (try self.ppc_fp128Const(ty, value)).toValue();
}

pub fn nullConst(self: *Builder, ty: Type) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, NoExtra, 0);
    return self.nullConstAssumeCapacity(ty);
}

pub fn nullValue(self: *Builder, ty: Type) Allocator.Error!Value {
    return (try self.nullConst(ty)).toValue();
}

pub fn noneConst(self: *Builder, ty: Type) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, NoExtra, 0);
    return self.noneConstAssumeCapacity(ty);
}

pub fn noneValue(self: *Builder, ty: Type) Allocator.Error!Value {
    return (try self.noneConst(ty)).toValue();
}

pub fn structConst(self: *Builder, ty: Type, vals: []const Constant) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Aggregate, vals.len);
    return self.structConstAssumeCapacity(ty, vals);
}

pub fn structValue(self: *Builder, ty: Type, vals: []const Constant) Allocator.Error!Value {
    return (try self.structConst(ty, vals)).toValue();
}

pub fn arrayConst(self: *Builder, ty: Type, vals: []const Constant) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Aggregate, vals.len);
    return self.arrayConstAssumeCapacity(ty, vals);
}

pub fn arrayValue(self: *Builder, ty: Type, vals: []const Constant) Allocator.Error!Value {
    return (try self.arrayConst(ty, vals)).toValue();
}

pub fn stringConst(self: *Builder, val: String) Allocator.Error!Constant {
    try self.ensureUnusedTypeCapacity(1, Type.Array, 0);
    try self.ensureUnusedConstantCapacity(1, NoExtra, 0);
    return self.stringConstAssumeCapacity(val);
}

pub fn stringValue(self: *Builder, val: String) Allocator.Error!Value {
    return (try self.stringConst(val)).toValue();
}

pub fn vectorConst(self: *Builder, ty: Type, vals: []const Constant) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Aggregate, vals.len);
    return self.vectorConstAssumeCapacity(ty, vals);
}

pub fn vectorValue(self: *Builder, ty: Type, vals: []const Constant) Allocator.Error!Value {
    return (try self.vectorConst(ty, vals)).toValue();
}

pub fn splatConst(self: *Builder, ty: Type, val: Constant) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Splat, 0);
    return self.splatConstAssumeCapacity(ty, val);
}

pub fn splatValue(self: *Builder, ty: Type, val: Constant) Allocator.Error!Value {
    return (try self.splatConst(ty, val)).toValue();
}

pub fn zeroInitConst(self: *Builder, ty: Type) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Fp128, 0);
    try self.constant_limbs.ensureUnusedCapacity(
        self.gpa,
        Constant.Integer.limbs + comptime std.math.big.int.calcLimbLen(0),
    );
    return self.zeroInitConstAssumeCapacity(ty);
}

pub fn zeroInitValue(self: *Builder, ty: Type) Allocator.Error!Value {
    return (try self.zeroInitConst(ty)).toValue();
}

pub fn undefConst(self: *Builder, ty: Type) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, NoExtra, 0);
    return self.undefConstAssumeCapacity(ty);
}

pub fn undefValue(self: *Builder, ty: Type) Allocator.Error!Value {
    return (try self.undefConst(ty)).toValue();
}

pub fn poisonConst(self: *Builder, ty: Type) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, NoExtra, 0);
    return self.poisonConstAssumeCapacity(ty);
}

pub fn poisonValue(self: *Builder, ty: Type) Allocator.Error!Value {
    return (try self.poisonConst(ty)).toValue();
}

pub fn blockAddrConst(
    self: *Builder,
    function: Function.Index,
    block: Function.Block.Index,
) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.BlockAddress, 0);
    return self.blockAddrConstAssumeCapacity(function, block);
}

pub fn blockAddrValue(
    self: *Builder,
    function: Function.Index,
    block: Function.Block.Index,
) Allocator.Error!Value {
    return (try self.blockAddrConst(function, block)).toValue();
}

pub fn dsoLocalEquivalentConst(self: *Builder, function: Function.Index) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, NoExtra, 0);
    return self.dsoLocalEquivalentConstAssumeCapacity(function);
}

pub fn dsoLocalEquivalentValue(self: *Builder, function: Function.Index) Allocator.Error!Value {
    return (try self.dsoLocalEquivalentConst(function)).toValue();
}

pub fn noCfiConst(self: *Builder, function: Function.Index) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, NoExtra, 0);
    return self.noCfiConstAssumeCapacity(function);
}

pub fn noCfiValue(self: *Builder, function: Function.Index) Allocator.Error!Value {
    return (try self.noCfiConst(function)).toValue();
}

pub fn convConst(
    self: *Builder,
    val: Constant,
    ty: Type,
) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Cast, 0);
    return self.convConstAssumeCapacity(val, ty);
}

pub fn convValue(
    self: *Builder,
    val: Constant,
    ty: Type,
) Allocator.Error!Value {
    return (try self.convConst(val, ty)).toValue();
}

pub fn castConst(self: *Builder, tag: Constant.Tag, val: Constant, ty: Type) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Cast, 0);
    return self.castConstAssumeCapacity(tag, val, ty);
}

pub fn castValue(self: *Builder, tag: Constant.Tag, val: Constant, ty: Type) Allocator.Error!Value {
    return (try self.castConst(tag, val, ty)).toValue();
}

pub fn gepConst(
    self: *Builder,
    comptime kind: Constant.GetElementPtr.Kind,
    ty: Type,
    base: Constant,
    inrange: ?u16,
    indices: []const Constant,
) Allocator.Error!Constant {
    try self.ensureUnusedTypeCapacity(1, Type.Vector, 0);
    try self.ensureUnusedConstantCapacity(1, Constant.GetElementPtr, indices.len);
    return self.gepConstAssumeCapacity(kind, ty, base, inrange, indices);
}

pub fn gepValue(
    self: *Builder,
    comptime kind: Constant.GetElementPtr.Kind,
    ty: Type,
    base: Constant,
    inrange: ?u16,
    indices: []const Constant,
) Allocator.Error!Value {
    return (try self.gepConst(kind, ty, base, inrange, indices)).toValue();
}

pub fn binConst(
    self: *Builder,
    tag: Constant.Tag,
    lhs: Constant,
    rhs: Constant,
) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Binary, 0);
    return self.binConstAssumeCapacity(tag, lhs, rhs);
}

pub fn binValue(self: *Builder, tag: Constant.Tag, lhs: Constant, rhs: Constant) Allocator.Error!Value {
    return (try self.binConst(tag, lhs, rhs)).toValue();
}

pub fn asmConst(
    self: *Builder,
    ty: Type,
    info: Constant.Assembly.Info,
    assembly: String,
    constraints: String,
) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Assembly, 0);
    return self.asmConstAssumeCapacity(ty, info, assembly, constraints);
}

pub fn asmValue(
    self: *Builder,
    ty: Type,
    info: Constant.Assembly.Info,
    assembly: String,
    constraints: String,
) Allocator.Error!Value {
    return (try self.asmConst(ty, info, assembly, constraints)).toValue();
}

pub fn dump(self: *Builder) void {
    self.print(std.io.getStdErr().writer()) catch {};
}

pub fn printToFile(self: *Builder, path: []const u8) Allocator.Error!bool {
    var file = std.fs.cwd().createFile(path, .{}) catch |err| {
        log.err("failed printing LLVM module to \"{s}\": {s}", .{ path, @errorName(err) });
        return false;
    };
    defer file.close();
    self.print(file.writer()) catch |err| {
        log.err("failed printing LLVM module to \"{s}\": {s}", .{ path, @errorName(err) });
        return false;
    };
    return true;
}

pub fn print(self: *Builder, writer: anytype) (@TypeOf(writer).Error || Allocator.Error)!void {
    var bw = std.io.bufferedWriter(writer);
    try self.printUnbuffered(bw.writer());
    try bw.flush();
}

fn WriterWithErrors(comptime BackingWriter: type, comptime ExtraErrors: type) type {
    return struct {
        backing_writer: BackingWriter,

        pub const Error = BackingWriter.Error || ExtraErrors;
        pub const Writer = std.io.Writer(*const Self, Error, write);

        const Self = @This();

        pub fn writer(self: *const Self) Writer {
            return .{ .context = self };
        }

        pub fn write(self: *const Self, bytes: []const u8) Error!usize {
            return self.backing_writer.write(bytes);
        }
    };
}
fn writerWithErrors(
    backing_writer: anytype,
    comptime ExtraErrors: type,
) WriterWithErrors(@TypeOf(backing_writer), ExtraErrors) {
    return .{ .backing_writer = backing_writer };
}

pub fn printUnbuffered(
    self: *Builder,
    backing_writer: anytype,
) (@TypeOf(backing_writer).Error || Allocator.Error)!void {
    const writer_with_errors = writerWithErrors(backing_writer, Allocator.Error);
    const writer = writer_with_errors.writer();

    var need_newline = false;
    var metadata_formatter: Metadata.Formatter = .{ .builder = self, .need_comma = undefined };
    defer metadata_formatter.map.deinit(self.gpa);

    if (self.source_filename != .none or self.data_layout != .none or self.target_triple != .none) {
        if (need_newline) try writer.writeByte('\n') else need_newline = true;
        if (self.source_filename != .none) try writer.print(
            \\; ModuleID = '{s}'
            \\source_filename = {"}
            \\
        , .{ self.source_filename.slice(self).?, self.source_filename.fmt(self) });
        if (self.data_layout != .none) try writer.print(
            \\target datalayout = {"}
            \\
        , .{self.data_layout.fmt(self)});
        if (self.target_triple != .none) try writer.print(
            \\target triple = {"}
            \\
        , .{self.target_triple.fmt(self)});
    }

    if (self.module_asm.items.len > 0) {
        if (need_newline) try writer.writeByte('\n') else need_newline = true;
        var line_it = std.mem.tokenizeScalar(u8, self.module_asm.items, '\n');
        while (line_it.next()) |line| {
            try writer.writeAll("module asm ");
            try printEscapedString(line, .always_quote, writer);
            try writer.writeByte('\n');
        }
    }

    if (self.types.count() > 0) {
        if (need_newline) try writer.writeByte('\n') else need_newline = true;
        for (self.types.keys(), self.types.values()) |id, ty| try writer.print(
            \\%{} = type {}
            \\
        , .{ id.fmt(self), ty.fmt(self) });
    }

    if (self.variables.items.len > 0) {
        if (need_newline) try writer.writeByte('\n') else need_newline = true;
        for (self.variables.items) |variable| {
            if (variable.global.getReplacement(self) != .none) continue;
            const global = variable.global.ptrConst(self);
            metadata_formatter.need_comma = true;
            defer metadata_formatter.need_comma = undefined;
            try writer.print(
                \\{} ={}{}{}{}{ }{}{ }{} {s} {%}{ }{, }{}
                \\
            , .{
                variable.global.fmt(self),
                Linkage.fmtOptional(if (global.linkage == .external and
                    variable.init != .no_init) null else global.linkage),
                global.preemption,
                global.visibility,
                global.dll_storage_class,
                variable.thread_local,
                global.unnamed_addr,
                global.addr_space,
                global.externally_initialized,
                @tagName(variable.mutability),
                global.type.fmt(self),
                variable.init.fmt(self),
                variable.alignment,
                try metadata_formatter.fmt("!dbg ", global.dbg),
            });
        }
    }

    if (self.aliases.items.len > 0) {
        if (need_newline) try writer.writeByte('\n') else need_newline = true;
        for (self.aliases.items) |alias| {
            if (alias.global.getReplacement(self) != .none) continue;
            const global = alias.global.ptrConst(self);
            metadata_formatter.need_comma = true;
            defer metadata_formatter.need_comma = undefined;
            try writer.print(
                \\{} ={}{}{}{}{ }{} alias {%}, {%}{}
                \\
            , .{
                alias.global.fmt(self),
                global.linkage,
                global.preemption,
                global.visibility,
                global.dll_storage_class,
                alias.thread_local,
                global.unnamed_addr,
                global.type.fmt(self),
                alias.aliasee.fmt(self),
                try metadata_formatter.fmt("!dbg ", global.dbg),
            });
        }
    }

    var attribute_groups: std.AutoArrayHashMapUnmanaged(Attributes, void) = .{};
    defer attribute_groups.deinit(self.gpa);

    for (0.., self.functions.items) |function_i, function| {
        if (function.global.getReplacement(self) != .none) continue;
        if (need_newline) try writer.writeByte('\n') else need_newline = true;
        const function_index: Function.Index = @enumFromInt(function_i);
        const global = function.global.ptrConst(self);
        const params_len = global.type.functionParameters(self).len;
        const function_attributes = function.attributes.func(self);
        if (function_attributes != .none) try writer.print(
            \\; Function Attrs:{}
            \\
        , .{function_attributes.fmt(self)});
        try writer.print(
            \\{s}{}{}{}{}{}{"} {} {}(
        , .{
            if (function.instructions.len > 0) "define" else "declare",
            global.linkage,
            global.preemption,
            global.visibility,
            global.dll_storage_class,
            function.call_conv,
            function.attributes.ret(self).fmt(self),
            global.type.functionReturn(self).fmt(self),
            function.global.fmt(self),
        });
        for (0..params_len) |arg| {
            if (arg > 0) try writer.writeAll(", ");
            try writer.print(
                \\{%}{"}
            , .{
                global.type.functionParameters(self)[arg].fmt(self),
                function.attributes.param(arg, self).fmt(self),
            });
            if (function.instructions.len > 0)
                try writer.print(" {}", .{function.arg(@intCast(arg)).fmt(function_index, self)})
            else
                try writer.print(" %{d}", .{arg});
        }
        switch (global.type.functionKind(self)) {
            .normal => {},
            .vararg => {
                if (params_len > 0) try writer.writeAll(", ");
                try writer.writeAll("...");
            },
        }
        try writer.print("){}{ }", .{ global.unnamed_addr, global.addr_space });
        if (function_attributes != .none) try writer.print(" #{d}", .{
            (try attribute_groups.getOrPutValue(self.gpa, function_attributes, {})).index,
        });
        {
            metadata_formatter.need_comma = false;
            defer metadata_formatter.need_comma = undefined;
            try writer.print("{ }{}", .{
                function.alignment,
                try metadata_formatter.fmt(" !dbg ", global.dbg),
            });
        }
        if (function.instructions.len > 0) {
            var block_incoming_len: u32 = undefined;
            try writer.writeAll(" {\n");
            var maybe_dbg_index: ?u32 = null;
            for (params_len..function.instructions.len) |instruction_i| {
                const instruction_index: Function.Instruction.Index = @enumFromInt(instruction_i);
                const instruction = function.instructions.get(@intFromEnum(instruction_index));
                if (function.debug_locations.get(instruction_index)) |debug_location| switch (debug_location) {
                    .no_location => maybe_dbg_index = null,
                    .location => |location| {
                        const gop = try metadata_formatter.map.getOrPut(self.gpa, .{
                            .debug_location = location,
                        });
                        maybe_dbg_index = @intCast(gop.index);
                    },
                };
                switch (instruction.tag) {
                    .add,
                    .@"add nsw",
                    .@"add nuw",
                    .@"add nuw nsw",
                    .@"and",
                    .ashr,
                    .@"ashr exact",
                    .fadd,
                    .@"fadd fast",
                    .@"fcmp false",
                    .@"fcmp fast false",
                    .@"fcmp fast oeq",
                    .@"fcmp fast oge",
                    .@"fcmp fast ogt",
                    .@"fcmp fast ole",
                    .@"fcmp fast olt",
                    .@"fcmp fast one",
                    .@"fcmp fast ord",
                    .@"fcmp fast true",
                    .@"fcmp fast ueq",
                    .@"fcmp fast uge",
                    .@"fcmp fast ugt",
                    .@"fcmp fast ule",
                    .@"fcmp fast ult",
                    .@"fcmp fast une",
                    .@"fcmp fast uno",
                    .@"fcmp oeq",
                    .@"fcmp oge",
                    .@"fcmp ogt",
                    .@"fcmp ole",
                    .@"fcmp olt",
                    .@"fcmp one",
                    .@"fcmp ord",
                    .@"fcmp true",
                    .@"fcmp ueq",
                    .@"fcmp uge",
                    .@"fcmp ugt",
                    .@"fcmp ule",
                    .@"fcmp ult",
                    .@"fcmp une",
                    .@"fcmp uno",
                    .fdiv,
                    .@"fdiv fast",
                    .fmul,
                    .@"fmul fast",
                    .frem,
                    .@"frem fast",
                    .fsub,
                    .@"fsub fast",
                    .@"icmp eq",
                    .@"icmp ne",
                    .@"icmp sge",
                    .@"icmp sgt",
                    .@"icmp sle",
                    .@"icmp slt",
                    .@"icmp uge",
                    .@"icmp ugt",
                    .@"icmp ule",
                    .@"icmp ult",
                    .lshr,
                    .@"lshr exact",
                    .mul,
                    .@"mul nsw",
                    .@"mul nuw",
                    .@"mul nuw nsw",
                    .@"or",
                    .sdiv,
                    .@"sdiv exact",
                    .srem,
                    .shl,
                    .@"shl nsw",
                    .@"shl nuw",
                    .@"shl nuw nsw",
                    .sub,
                    .@"sub nsw",
                    .@"sub nuw",
                    .@"sub nuw nsw",
                    .udiv,
                    .@"udiv exact",
                    .urem,
                    .xor,
                    => |tag| {
                        const extra = function.extraData(Function.Instruction.Binary, instruction.data);
                        try writer.print("  %{} = {s} {%}, {}", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.lhs.fmt(function_index, self),
                            extra.rhs.fmt(function_index, self),
                        });
                    },
                    .addrspacecast,
                    .bitcast,
                    .fpext,
                    .fptosi,
                    .fptoui,
                    .fptrunc,
                    .inttoptr,
                    .ptrtoint,
                    .sext,
                    .sitofp,
                    .trunc,
                    .uitofp,
                    .zext,
                    => |tag| {
                        const extra = function.extraData(Function.Instruction.Cast, instruction.data);
                        try writer.print("  %{} = {s} {%} to {%}", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.val.fmt(function_index, self),
                            extra.type.fmt(self),
                        });
                    },
                    .alloca,
                    .@"alloca inalloca",
                    => |tag| {
                        const extra = function.extraData(Function.Instruction.Alloca, instruction.data);
                        try writer.print("  %{} = {s} {%}{,%}{, }{, }", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.type.fmt(self),
                            Value.fmt(switch (extra.len) {
                                .@"1" => .none,
                                else => extra.len,
                            }, function_index, self),
                            extra.info.alignment,
                            extra.info.addr_space,
                        });
                    },
                    .arg => unreachable,
                    .atomicrmw => |tag| {
                        const extra =
                            function.extraData(Function.Instruction.AtomicRmw, instruction.data);
                        try writer.print("  %{} = {s}{ } {s} {%}, {%}{ }{ }{, }", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.info.access_kind,
                            @tagName(extra.info.atomic_rmw_operation),
                            extra.ptr.fmt(function_index, self),
                            extra.val.fmt(function_index, self),
                            extra.info.sync_scope,
                            extra.info.success_ordering,
                            extra.info.alignment,
                        });
                    },
                    .block => {
                        block_incoming_len = instruction.data;
                        const name = instruction_index.name(&function);
                        if (@intFromEnum(instruction_index) > params_len)
                            try writer.writeByte('\n');
                        try writer.print("{}:\n", .{name.fmt(self)});
                        continue;
                    },
                    .br => |tag| {
                        const target: Function.Block.Index = @enumFromInt(instruction.data);
                        try writer.print("  {s} {%}", .{
                            @tagName(tag), target.toInst(&function).fmt(function_index, self),
                        });
                    },
                    .br_cond => {
                        const extra = function.extraData(Function.Instruction.BrCond, instruction.data);
                        try writer.print("  br {%}, {%}, {%}", .{
                            extra.cond.fmt(function_index, self),
                            extra.then.toInst(&function).fmt(function_index, self),
                            extra.@"else".toInst(&function).fmt(function_index, self),
                        });
                    },
                    .call,
                    .@"call fast",
                    .@"musttail call",
                    .@"musttail call fast",
                    .@"notail call",
                    .@"notail call fast",
                    .@"tail call",
                    .@"tail call fast",
                    => |tag| {
                        var extra =
                            function.extraDataTrail(Function.Instruction.Call, instruction.data);
                        const args = extra.trail.next(extra.data.args_len, Value, &function);
                        try writer.writeAll("  ");
                        const ret_ty = extra.data.ty.functionReturn(self);
                        switch (ret_ty) {
                            .void => {},
                            else => try writer.print("%{} = ", .{
                                instruction_index.name(&function).fmt(self),
                            }),
                            .none => unreachable,
                        }
                        try writer.print("{s}{}{}{} {%} {}(", .{
                            @tagName(tag),
                            extra.data.info.call_conv,
                            extra.data.attributes.ret(self).fmt(self),
                            extra.data.callee.typeOf(function_index, self).pointerAddrSpace(self),
                            switch (extra.data.ty.functionKind(self)) {
                                .normal => ret_ty,
                                .vararg => extra.data.ty,
                            }.fmt(self),
                            extra.data.callee.fmt(function_index, self),
                        });
                        for (0.., args) |arg_index, arg| {
                            if (arg_index > 0) try writer.writeAll(", ");
                            metadata_formatter.need_comma = false;
                            defer metadata_formatter.need_comma = undefined;
                            try writer.print("{%}{}{}", .{
                                arg.typeOf(function_index, self).fmt(self),
                                extra.data.attributes.param(arg_index, self).fmt(self),
                                try metadata_formatter.fmtLocal(" ", arg, function_index),
                            });
                        }
                        try writer.writeByte(')');
                        const call_function_attributes = extra.data.attributes.func(self);
                        if (call_function_attributes != .none) try writer.print(" #{d}", .{
                            (try attribute_groups.getOrPutValue(
                                self.gpa,
                                call_function_attributes,
                                {},
                            )).index,
                        });
                    },
                    .cmpxchg,
                    .@"cmpxchg weak",
                    => |tag| {
                        const extra =
                            function.extraData(Function.Instruction.CmpXchg, instruction.data);
                        try writer.print("  %{} = {s}{ } {%}, {%}, {%}{ }{ }{ }{, }", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.info.access_kind,
                            extra.ptr.fmt(function_index, self),
                            extra.cmp.fmt(function_index, self),
                            extra.new.fmt(function_index, self),
                            extra.info.sync_scope,
                            extra.info.success_ordering,
                            extra.info.failure_ordering,
                            extra.info.alignment,
                        });
                    },
                    .extractelement => |tag| {
                        const extra =
                            function.extraData(Function.Instruction.ExtractElement, instruction.data);
                        try writer.print("  %{} = {s} {%}, {%}", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.val.fmt(function_index, self),
                            extra.index.fmt(function_index, self),
                        });
                    },
                    .extractvalue => |tag| {
                        var extra = function.extraDataTrail(
                            Function.Instruction.ExtractValue,
                            instruction.data,
                        );
                        const indices = extra.trail.next(extra.data.indices_len, u32, &function);
                        try writer.print("  %{} = {s} {%}", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.data.val.fmt(function_index, self),
                        });
                        for (indices) |index| try writer.print(", {d}", .{index});
                    },
                    .fence => |tag| {
                        const info: MemoryAccessInfo = @bitCast(instruction.data);
                        try writer.print("  {s}{ }{ }", .{
                            @tagName(tag),
                            info.sync_scope,
                            info.success_ordering,
                        });
                    },
                    .fneg,
                    .@"fneg fast",
                    => |tag| {
                        const val: Value = @enumFromInt(instruction.data);
                        try writer.print("  %{} = {s} {%}", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            val.fmt(function_index, self),
                        });
                    },
                    .getelementptr,
                    .@"getelementptr inbounds",
                    => |tag| {
                        var extra = function.extraDataTrail(
                            Function.Instruction.GetElementPtr,
                            instruction.data,
                        );
                        const indices = extra.trail.next(extra.data.indices_len, Value, &function);
                        try writer.print("  %{} = {s} {%}, {%}", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.data.type.fmt(self),
                            extra.data.base.fmt(function_index, self),
                        });
                        for (indices) |index| try writer.print(", {%}", .{
                            index.fmt(function_index, self),
                        });
                    },
                    .insertelement => |tag| {
                        const extra =
                            function.extraData(Function.Instruction.InsertElement, instruction.data);
                        try writer.print("  %{} = {s} {%}, {%}, {%}", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.val.fmt(function_index, self),
                            extra.elem.fmt(function_index, self),
                            extra.index.fmt(function_index, self),
                        });
                    },
                    .insertvalue => |tag| {
                        var extra =
                            function.extraDataTrail(Function.Instruction.InsertValue, instruction.data);
                        const indices = extra.trail.next(extra.data.indices_len, u32, &function);
                        try writer.print("  %{} = {s} {%}, {%}", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.data.val.fmt(function_index, self),
                            extra.data.elem.fmt(function_index, self),
                        });
                        for (indices) |index| try writer.print(", {d}", .{index});
                    },
                    .load,
                    .@"load atomic",
                    => |tag| {
                        const extra = function.extraData(Function.Instruction.Load, instruction.data);
                        try writer.print("  %{} = {s}{ } {%}, {%}{ }{ }{, }", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.info.access_kind,
                            extra.type.fmt(self),
                            extra.ptr.fmt(function_index, self),
                            extra.info.sync_scope,
                            extra.info.success_ordering,
                            extra.info.alignment,
                        });
                    },
                    .phi,
                    .@"phi fast",
                    => |tag| {
                        var extra = function.extraDataTrail(Function.Instruction.Phi, instruction.data);
                        const vals = extra.trail.next(block_incoming_len, Value, &function);
                        const blocks =
                            extra.trail.next(block_incoming_len, Function.Block.Index, &function);
                        try writer.print("  %{} = {s} {%} ", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            vals[0].typeOf(function_index, self).fmt(self),
                        });
                        for (0.., vals, blocks) |incoming_index, incoming_val, incoming_block| {
                            if (incoming_index > 0) try writer.writeAll(", ");
                            try writer.print("[ {}, {} ]", .{
                                incoming_val.fmt(function_index, self),
                                incoming_block.toInst(&function).fmt(function_index, self),
                            });
                        }
                    },
                    .ret => |tag| {
                        const val: Value = @enumFromInt(instruction.data);
                        try writer.print("  {s} {%}", .{
                            @tagName(tag),
                            val.fmt(function_index, self),
                        });
                    },
                    .@"ret void",
                    .@"unreachable",
                    => |tag| try writer.print("  {s}", .{@tagName(tag)}),
                    .select,
                    .@"select fast",
                    => |tag| {
                        const extra = function.extraData(Function.Instruction.Select, instruction.data);
                        try writer.print("  %{} = {s} {%}, {%}, {%}", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.cond.fmt(function_index, self),
                            extra.lhs.fmt(function_index, self),
                            extra.rhs.fmt(function_index, self),
                        });
                    },
                    .shufflevector => |tag| {
                        const extra =
                            function.extraData(Function.Instruction.ShuffleVector, instruction.data);
                        try writer.print("  %{} = {s} {%}, {%}, {%}", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.lhs.fmt(function_index, self),
                            extra.rhs.fmt(function_index, self),
                            extra.mask.fmt(function_index, self),
                        });
                    },
                    .store,
                    .@"store atomic",
                    => |tag| {
                        const extra = function.extraData(Function.Instruction.Store, instruction.data);
                        try writer.print("  {s}{ } {%}, {%}{ }{ }{, }", .{
                            @tagName(tag),
                            extra.info.access_kind,
                            extra.val.fmt(function_index, self),
                            extra.ptr.fmt(function_index, self),
                            extra.info.sync_scope,
                            extra.info.success_ordering,
                            extra.info.alignment,
                        });
                    },
                    .@"switch" => |tag| {
                        var extra =
                            function.extraDataTrail(Function.Instruction.Switch, instruction.data);
                        const vals = extra.trail.next(extra.data.cases_len, Constant, &function);
                        const blocks =
                            extra.trail.next(extra.data.cases_len, Function.Block.Index, &function);
                        try writer.print("  {s} {%}, {%} [\n", .{
                            @tagName(tag),
                            extra.data.val.fmt(function_index, self),
                            extra.data.default.toInst(&function).fmt(function_index, self),
                        });
                        for (vals, blocks) |case_val, case_block| try writer.print(
                            "    {%}, {%}\n",
                            .{
                                case_val.fmt(self),
                                case_block.toInst(&function).fmt(function_index, self),
                            },
                        );
                        try writer.writeAll("  ]");
                    },
                    .va_arg => |tag| {
                        const extra = function.extraData(Function.Instruction.VaArg, instruction.data);
                        try writer.print("  %{} = {s} {%}, {%}", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.list.fmt(function_index, self),
                            extra.type.fmt(self),
                        });
                    },
                }

                if (maybe_dbg_index) |dbg_index| {
                    try writer.print(", !dbg !{}\n", .{dbg_index});
                } else try writer.writeByte('\n');
            }
            try writer.writeByte('}');
        }
        try writer.writeByte('\n');
    }

    if (attribute_groups.count() > 0) {
        if (need_newline) try writer.writeByte('\n') else need_newline = true;
        for (0.., attribute_groups.keys()) |attribute_group_index, attribute_group|
            try writer.print(
                \\attributes #{d} = {{{#"} }}
                \\
            , .{ attribute_group_index, attribute_group.fmt(self) });
    }

    if (self.metadata_named.count() > 0) {
        if (need_newline) try writer.writeByte('\n') else need_newline = true;
        for (self.metadata_named.keys(), self.metadata_named.values()) |name, data| {
            const elements: []const Metadata =
                @ptrCast(self.metadata_extra.items[data.index..][0..data.len]);
            try writer.writeByte('!');
            try printEscapedString(name.slice(self), .quote_unless_valid_identifier, writer);
            try writer.writeAll(" = !{");
            metadata_formatter.need_comma = false;
            defer metadata_formatter.need_comma = undefined;
            for (elements) |element| try writer.print("{}", .{try metadata_formatter.fmt("", element)});
            try writer.writeAll("}\n");
        }
    }

    if (metadata_formatter.map.count() > 0) {
        if (need_newline) try writer.writeByte('\n') else need_newline = true;
        var metadata_index: usize = 0;
        while (metadata_index < metadata_formatter.map.count()) : (metadata_index += 1) {
            @setEvalBranchQuota(10_000);
            try writer.print("!{} = ", .{metadata_index});
            metadata_formatter.need_comma = false;
            defer metadata_formatter.need_comma = undefined;

            const key = metadata_formatter.map.keys()[metadata_index];
            const metadata_item = switch (key) {
                .debug_location => |location| {
                    try metadata_formatter.specialized(.@"!", .DILocation, .{
                        .line = location.line,
                        .column = location.column,
                        .scope = location.scope,
                        .inlinedAt = location.inlined_at,
                        .isImplicitCode = false,
                    }, writer);
                    continue;
                },
                .metadata => |metadata| self.metadata_items.get(@intFromEnum(metadata)),
            };

            switch (metadata_item.tag) {
                .none, .expression, .constant => unreachable,
                .file => {
                    const extra = self.metadataExtraData(Metadata.File, metadata_item.data);
                    try metadata_formatter.specialized(.@"!", .DIFile, .{
                        .filename = extra.filename,
                        .directory = extra.directory,
                        .checksumkind = null,
                        .checksum = null,
                        .source = null,
                    }, writer);
                },
                .compile_unit,
                .@"compile_unit optimized",
                => |kind| {
                    const extra = self.metadataExtraData(Metadata.CompileUnit, metadata_item.data);
                    try metadata_formatter.specialized(.@"distinct !", .DICompileUnit, .{
                        .language = .DW_LANG_C99,
                        .file = extra.file,
                        .producer = extra.producer,
                        .isOptimized = switch (kind) {
                            .compile_unit => false,
                            .@"compile_unit optimized" => true,
                            else => unreachable,
                        },
                        .flags = null,
                        .runtimeVersion = 0,
                        .splitDebugFilename = null,
                        .emissionKind = .FullDebug,
                        .enums = extra.enums,
                        .retainedTypes = null,
                        .globals = extra.globals,
                        .imports = null,
                        .macros = null,
                        .dwoId = null,
                        .splitDebugInlining = false,
                        .debugInfoForProfiling = null,
                        .nameTableKind = null,
                        .rangesBaseAddress = null,
                        .sysroot = null,
                        .sdk = null,
                    }, writer);
                },
                .subprogram,
                .@"subprogram local",
                .@"subprogram definition",
                .@"subprogram local definition",
                .@"subprogram optimized",
                .@"subprogram optimized local",
                .@"subprogram optimized definition",
                .@"subprogram optimized local definition",
                => |kind| {
                    const extra = self.metadataExtraData(Metadata.Subprogram, metadata_item.data);
                    try metadata_formatter.specialized(.@"distinct !", .DISubprogram, .{
                        .name = extra.name,
                        .linkageName = extra.linkage_name,
                        .scope = extra.file,
                        .file = extra.file,
                        .line = extra.line,
                        .type = extra.ty,
                        .scopeLine = extra.scope_line,
                        .containingType = null,
                        .virtualIndex = null,
                        .thisAdjustment = null,
                        .flags = extra.di_flags,
                        .spFlags = @as(Metadata.Subprogram.DISPFlags, @bitCast(@as(u32, @as(u3, @intCast(
                            @intFromEnum(kind) - @intFromEnum(Metadata.Tag.subprogram),
                        ))) << 2)),
                        .unit = extra.compile_unit,
                        .templateParams = null,
                        .declaration = null,
                        .retainedNodes = null,
                        .thrownTypes = null,
                        .annotations = null,
                        .targetFuncName = null,
                    }, writer);
                },
                .lexical_block => {
                    const extra = self.metadataExtraData(Metadata.LexicalBlock, metadata_item.data);
                    try metadata_formatter.specialized(.@"distinct !", .DILexicalBlock, .{
                        .scope = extra.scope,
                        .file = extra.file,
                        .line = extra.line,
                        .column = extra.column,
                    }, writer);
                },
                .location => {
                    const extra = self.metadataExtraData(Metadata.Location, metadata_item.data);
                    try metadata_formatter.specialized(.@"!", .DILocation, .{
                        .line = extra.line,
                        .column = extra.column,
                        .scope = extra.scope,
                        .inlinedAt = extra.inlined_at,
                        .isImplicitCode = false,
                    }, writer);
                },
                .basic_bool_type,
                .basic_unsigned_type,
                .basic_signed_type,
                .basic_float_type,
                => |kind| {
                    const extra = self.metadataExtraData(Metadata.BasicType, metadata_item.data);
                    try metadata_formatter.specialized(.@"!", .DIBasicType, .{
                        .tag = null,
                        .name = switch (extra.name) {
                            .none => null,
                            else => extra.name,
                        },
                        .size = extra.bitSize(),
                        .@"align" = null,
                        .encoding = @as(enum {
                            DW_ATE_boolean,
                            DW_ATE_unsigned,
                            DW_ATE_signed,
                            DW_ATE_float,
                        }, switch (kind) {
                            .basic_bool_type => .DW_ATE_boolean,
                            .basic_unsigned_type => .DW_ATE_unsigned,
                            .basic_signed_type => .DW_ATE_signed,
                            .basic_float_type => .DW_ATE_float,
                            else => unreachable,
                        }),
                        .flags = null,
                    }, writer);
                },
                .composite_struct_type,
                .composite_union_type,
                .composite_enumeration_type,
                .composite_array_type,
                .composite_vector_type,
                => |kind| {
                    const extra = self.metadataExtraData(Metadata.CompositeType, metadata_item.data);
                    try metadata_formatter.specialized(.@"!", .DICompositeType, .{
                        .tag = @as(enum {
                            DW_TAG_structure_type,
                            DW_TAG_union_type,
                            DW_TAG_enumeration_type,
                            DW_TAG_array_type,
                        }, switch (kind) {
                            .composite_struct_type => .DW_TAG_structure_type,
                            .composite_union_type => .DW_TAG_union_type,
                            .composite_enumeration_type => .DW_TAG_enumeration_type,
                            .composite_array_type, .composite_vector_type => .DW_TAG_array_type,
                            else => unreachable,
                        }),
                        .name = switch (extra.name) {
                            .none => null,
                            else => extra.name,
                        },
                        .scope = extra.scope,
                        .file = null,
                        .line = null,
                        .baseType = extra.underlying_type,
                        .size = extra.bitSize(),
                        .@"align" = extra.bitAlign(),
                        .offset = null,
                        .flags = null,
                        .elements = extra.fields_tuple,
                        .runtimeLang = null,
                        .vtableHolder = null,
                        .templateParams = null,
                        .identifier = null,
                        .discriminator = null,
                        .dataLocation = null,
                        .associated = null,
                        .allocated = null,
                        .rank = null,
                        .annotations = null,
                    }, writer);
                },
                .derived_pointer_type,
                .derived_member_type,
                => |kind| {
                    const extra = self.metadataExtraData(Metadata.DerivedType, metadata_item.data);
                    try metadata_formatter.specialized(.@"!", .DIDerivedType, .{
                        .tag = @as(enum {
                            DW_TAG_pointer_type,
                            DW_TAG_member,
                        }, switch (kind) {
                            .derived_pointer_type => .DW_TAG_pointer_type,
                            .derived_member_type => .DW_TAG_member,
                            else => unreachable,
                        }),
                        .name = switch (extra.name) {
                            .none => null,
                            else => extra.name,
                        },
                        .scope = extra.scope,
                        .file = null,
                        .line = null,
                        .baseType = extra.underlying_type,
                        .size = extra.bitSize(),
                        .@"align" = extra.bitAlign(),
                        .offset = switch (extra.bitOffset()) {
                            0 => null,
                            else => |bit_offset| bit_offset,
                        },
                        .flags = null,
                        .extraData = null,
                        .dwarfAddressSpace = null,
                        .annotations = null,
                    }, writer);
                },
                .subroutine_type => {
                    const extra = self.metadataExtraData(Metadata.SubroutineType, metadata_item.data);
                    try metadata_formatter.specialized(.@"!", .DISubroutineType, .{
                        .flags = null,
                        .cc = null,
                        .types = extra.types_tuple,
                    }, writer);
                },
                .enumerator_unsigned,
                .enumerator_signed_positive,
                .enumerator_signed_negative,
                => |kind| {
                    const extra = self.metadataExtraData(Metadata.Enumerator, metadata_item.data);

                    const ExpectedContents = extern struct {
                        const expected_limbs = @divExact(512, @bitSizeOf(std.math.big.Limb));
                        string: [
                            (std.math.big.int.Const{
                                .limbs = &([1]std.math.big.Limb{
                                    std.math.maxInt(std.math.big.Limb),
                                } ** expected_limbs),
                                .positive = false,
                            }).sizeInBaseUpperBound(10)
                        ]u8,
                        limbs: [
                            std.math.big.int.calcToStringLimbsBufferLen(expected_limbs, 10)
                        ]std.math.big.Limb,
                    };
                    var stack align(@alignOf(ExpectedContents)) =
                        std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
                    const allocator = stack.get();

                    const limbs = self.metadata_limbs.items[extra.limbs_index..][0..extra.limbs_len];
                    const bigint: std.math.big.int.Const = .{
                        .limbs = limbs,
                        .positive = switch (kind) {
                            .enumerator_unsigned,
                            .enumerator_signed_positive,
                            => true,
                            .enumerator_signed_negative => false,
                            else => unreachable,
                        },
                    };
                    const str = try bigint.toStringAlloc(allocator, 10, undefined);
                    defer allocator.free(str);

                    try metadata_formatter.specialized(.@"!", .DIEnumerator, .{
                        .name = extra.name,
                        .value = str,
                        .isUnsigned = switch (kind) {
                            .enumerator_unsigned => true,
                            .enumerator_signed_positive,
                            .enumerator_signed_negative,
                            => false,
                            else => unreachable,
                        },
                    }, writer);
                },
                .subrange => {
                    const extra = self.metadataExtraData(Metadata.Subrange, metadata_item.data);
                    try metadata_formatter.specialized(.@"!", .DISubrange, .{
                        .count = extra.count,
                        .lowerBound = extra.lower_bound,
                        .upperBound = null,
                        .stride = null,
                    }, writer);
                },
                .tuple => {
                    var extra = self.metadataExtraDataTrail(Metadata.Tuple, metadata_item.data);
                    const elements = extra.trail.next(extra.data.elements_len, Metadata, self);
                    try writer.writeAll("!{");
                    for (elements) |element| try writer.print("{[element]%}", .{
                        .element = try metadata_formatter.fmt("", element),
                    });
                    try writer.writeAll("}\n");
                },
                .module_flag => {
                    const extra = self.metadataExtraData(Metadata.ModuleFlag, metadata_item.data);
                    try writer.print("!{{{[behavior]%}{[name]%}{[constant]%}}}\n", .{
                        .behavior = try metadata_formatter.fmt("", extra.behavior),
                        .name = try metadata_formatter.fmt("", extra.name),
                        .constant = try metadata_formatter.fmt("", extra.constant),
                    });
                },
                .local_var => {
                    const extra = self.metadataExtraData(Metadata.LocalVar, metadata_item.data);
                    try metadata_formatter.specialized(.@"!", .DILocalVariable, .{
                        .name = extra.name,
                        .arg = null,
                        .scope = extra.scope,
                        .file = extra.file,
                        .line = extra.line,
                        .type = extra.ty,
                        .flags = null,
                        .@"align" = null,
                        .annotations = null,
                    }, writer);
                },
                .parameter => {
                    const extra = self.metadataExtraData(Metadata.Parameter, metadata_item.data);
                    try metadata_formatter.specialized(.@"!", .DILocalVariable, .{
                        .name = extra.name,
                        .arg = extra.arg_no,
                        .scope = extra.scope,
                        .file = extra.file,
                        .line = extra.line,
                        .type = extra.ty,
                        .flags = null,
                        .@"align" = null,
                        .annotations = null,
                    }, writer);
                },
                .global_var,
                .@"global_var local",
                => |kind| {
                    const extra = self.metadataExtraData(Metadata.GlobalVar, metadata_item.data);
                    try metadata_formatter.specialized(.@"distinct !", .DIGlobalVariable, .{
                        .name = extra.name,
                        .linkageName = extra.linkage_name,
                        .scope = extra.scope,
                        .file = extra.file,
                        .line = extra.line,
                        .type = extra.ty,
                        .isLocal = switch (kind) {
                            .global_var => false,
                            .@"global_var local" => true,
                            else => unreachable,
                        },
                        .isDefinition = true,
                        .declaration = null,
                        .templateParams = null,
                        .@"align" = null,
                        .annotations = null,
                    }, writer);
                },
                .global_var_expression => {
                    const extra =
                        self.metadataExtraData(Metadata.GlobalVarExpression, metadata_item.data);
                    try metadata_formatter.specialized(.@"!", .DIGlobalVariableExpression, .{
                        .@"var" = extra.variable,
                        .expr = extra.expression,
                    }, writer);
                },
            }
        }
    }
}

const NoExtra = struct {};

fn isValidIdentifier(id: []const u8) bool {
    for (id, 0..) |byte, index| switch (byte) {
        '$', '-', '.', 'A'...'Z', '_', 'a'...'z' => {},
        '0'...'9' => if (index == 0) return false,
        else => return false,
    };
    return true;
}

const QuoteBehavior = enum { always_quote, quote_unless_valid_identifier };
fn printEscapedString(
    slice: []const u8,
    quotes: QuoteBehavior,
    writer: anytype,
) @TypeOf(writer).Error!void {
    const need_quotes = switch (quotes) {
        .always_quote => true,
        .quote_unless_valid_identifier => !isValidIdentifier(slice),
    };
    if (need_quotes) try writer.writeByte('"');
    for (slice) |byte| switch (byte) {
        '\\' => try writer.writeAll("\\\\"),
        ' '...'"' - 1, '"' + 1...'\\' - 1, '\\' + 1...'~' => try writer.writeByte(byte),
        else => try writer.print("\\{X:0>2}", .{byte}),
    };
    if (need_quotes) try writer.writeByte('"');
}

fn ensureUnusedGlobalCapacity(self: *Builder, name: StrtabString) Allocator.Error!void {
    try self.strtab_string_map.ensureUnusedCapacity(self.gpa, 1);
    if (name.slice(self)) |id| {
        const count: usize = comptime std.fmt.count("{d}", .{std.math.maxInt(u32)});
        try self.strtab_string_bytes.ensureUnusedCapacity(self.gpa, id.len + count);
    }
    try self.strtab_string_indices.ensureUnusedCapacity(self.gpa, 1);
    try self.globals.ensureUnusedCapacity(self.gpa, 1);
    try self.next_unique_global_id.ensureUnusedCapacity(self.gpa, 1);
}

fn fnTypeAssumeCapacity(
    self: *Builder,
    ret: Type,
    params: []const Type,
    comptime kind: Type.Function.Kind,
) Type {
    const tag: Type.Tag = switch (kind) {
        .normal => .function,
        .vararg => .vararg_function,
    };
    const Key = struct { ret: Type, params: []const Type };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Key) u32 {
            var hasher = std.hash.Wyhash.init(comptime std.hash.uint32(@intFromEnum(tag)));
            hasher.update(std.mem.asBytes(&key.ret));
            hasher.update(std.mem.sliceAsBytes(key.params));
            return @truncate(hasher.final());
        }
        pub fn eql(ctx: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            const rhs_data = ctx.builder.type_items.items[rhs_index];
            if (rhs_data.tag != tag) return false;
            var rhs_extra = ctx.builder.typeExtraDataTrail(Type.Function, rhs_data.data);
            const rhs_params = rhs_extra.trail.next(rhs_extra.data.params_len, Type, ctx.builder);
            return lhs_key.ret == rhs_extra.data.ret and std.mem.eql(Type, lhs_key.params, rhs_params);
        }
    };
    const gop = self.type_map.getOrPutAssumeCapacityAdapted(
        Key{ .ret = ret, .params = params },
        Adapter{ .builder = self },
    );
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.type_items.appendAssumeCapacity(.{
            .tag = tag,
            .data = self.addTypeExtraAssumeCapacity(Type.Function{
                .ret = ret,
                .params_len = @intCast(params.len),
            }),
        });
        self.type_extra.appendSliceAssumeCapacity(@ptrCast(params));
    }
    return @enumFromInt(gop.index);
}

fn intTypeAssumeCapacity(self: *Builder, bits: u24) Type {
    assert(bits > 0);
    const result = self.getOrPutTypeNoExtraAssumeCapacity(.{ .tag = .integer, .data = bits });
    return result.type;
}

fn ptrTypeAssumeCapacity(self: *Builder, addr_space: AddrSpace) Type {
    const result = self.getOrPutTypeNoExtraAssumeCapacity(
        .{ .tag = .pointer, .data = @intFromEnum(addr_space) },
    );
    return result.type;
}

fn vectorTypeAssumeCapacity(
    self: *Builder,
    comptime kind: Type.Vector.Kind,
    len: u32,
    child: Type,
) Type {
    assert(child.isFloatingPoint() or child.isInteger(self) or child.isPointer(self));
    const tag: Type.Tag = switch (kind) {
        .normal => .vector,
        .scalable => .scalable_vector,
    };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Type.Vector) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(tag)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Type.Vector, _: void, rhs_index: usize) bool {
            const rhs_data = ctx.builder.type_items.items[rhs_index];
            return rhs_data.tag == tag and
                std.meta.eql(lhs_key, ctx.builder.typeExtraData(Type.Vector, rhs_data.data));
        }
    };
    const data = Type.Vector{ .len = len, .child = child };
    const gop = self.type_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.type_items.appendAssumeCapacity(.{
            .tag = tag,
            .data = self.addTypeExtraAssumeCapacity(data),
        });
    }
    return @enumFromInt(gop.index);
}

fn arrayTypeAssumeCapacity(self: *Builder, len: u64, child: Type) Type {
    if (std.math.cast(u32, len)) |small_len| {
        const Adapter = struct {
            builder: *const Builder,
            pub fn hash(_: @This(), key: Type.Vector) u32 {
                return @truncate(std.hash.Wyhash.hash(
                    comptime std.hash.uint32(@intFromEnum(Type.Tag.small_array)),
                    std.mem.asBytes(&key),
                ));
            }
            pub fn eql(ctx: @This(), lhs_key: Type.Vector, _: void, rhs_index: usize) bool {
                const rhs_data = ctx.builder.type_items.items[rhs_index];
                return rhs_data.tag == .small_array and
                    std.meta.eql(lhs_key, ctx.builder.typeExtraData(Type.Vector, rhs_data.data));
            }
        };
        const data = Type.Vector{ .len = small_len, .child = child };
        const gop = self.type_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
        if (!gop.found_existing) {
            gop.key_ptr.* = {};
            gop.value_ptr.* = {};
            self.type_items.appendAssumeCapacity(.{
                .tag = .small_array,
                .data = self.addTypeExtraAssumeCapacity(data),
            });
        }
        return @enumFromInt(gop.index);
    } else {
        const Adapter = struct {
            builder: *const Builder,
            pub fn hash(_: @This(), key: Type.Array) u32 {
                return @truncate(std.hash.Wyhash.hash(
                    comptime std.hash.uint32(@intFromEnum(Type.Tag.array)),
                    std.mem.asBytes(&key),
                ));
            }
            pub fn eql(ctx: @This(), lhs_key: Type.Array, _: void, rhs_index: usize) bool {
                const rhs_data = ctx.builder.type_items.items[rhs_index];
                return rhs_data.tag == .array and
                    std.meta.eql(lhs_key, ctx.builder.typeExtraData(Type.Array, rhs_data.data));
            }
        };
        const data = Type.Array{
            .len_lo = @truncate(len),
            .len_hi = @intCast(len >> 32),
            .child = child,
        };
        const gop = self.type_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
        if (!gop.found_existing) {
            gop.key_ptr.* = {};
            gop.value_ptr.* = {};
            self.type_items.appendAssumeCapacity(.{
                .tag = .array,
                .data = self.addTypeExtraAssumeCapacity(data),
            });
        }
        return @enumFromInt(gop.index);
    }
}

fn structTypeAssumeCapacity(
    self: *Builder,
    comptime kind: Type.Structure.Kind,
    fields: []const Type,
) Type {
    const tag: Type.Tag = switch (kind) {
        .normal => .structure,
        .@"packed" => .packed_structure,
    };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: []const Type) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(tag)),
                std.mem.sliceAsBytes(key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: []const Type, _: void, rhs_index: usize) bool {
            const rhs_data = ctx.builder.type_items.items[rhs_index];
            if (rhs_data.tag != tag) return false;
            var rhs_extra = ctx.builder.typeExtraDataTrail(Type.Structure, rhs_data.data);
            const rhs_fields = rhs_extra.trail.next(rhs_extra.data.fields_len, Type, ctx.builder);
            return std.mem.eql(Type, lhs_key, rhs_fields);
        }
    };
    const gop = self.type_map.getOrPutAssumeCapacityAdapted(fields, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.type_items.appendAssumeCapacity(.{
            .tag = tag,
            .data = self.addTypeExtraAssumeCapacity(Type.Structure{
                .fields_len = @intCast(fields.len),
            }),
        });
        self.type_extra.appendSliceAssumeCapacity(@ptrCast(fields));
    }
    return @enumFromInt(gop.index);
}

fn opaqueTypeAssumeCapacity(self: *Builder, name: String) Type {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: String) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(Type.Tag.named_structure)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: String, _: void, rhs_index: usize) bool {
            const rhs_data = ctx.builder.type_items.items[rhs_index];
            return rhs_data.tag == .named_structure and
                lhs_key == ctx.builder.typeExtraData(Type.NamedStructure, rhs_data.data).id;
        }
    };
    var id = name;
    if (name == .empty) {
        id = self.next_unnamed_type;
        assert(id != .none);
        self.next_unnamed_type = @enumFromInt(@intFromEnum(id) + 1);
    } else assert(!name.isAnon());
    while (true) {
        const type_gop = self.types.getOrPutAssumeCapacity(id);
        if (!type_gop.found_existing) {
            const gop = self.type_map.getOrPutAssumeCapacityAdapted(id, Adapter{ .builder = self });
            assert(!gop.found_existing);
            gop.key_ptr.* = {};
            gop.value_ptr.* = {};
            self.type_items.appendAssumeCapacity(.{
                .tag = .named_structure,
                .data = self.addTypeExtraAssumeCapacity(Type.NamedStructure{
                    .id = id,
                    .body = .none,
                }),
            });
            const result: Type = @enumFromInt(gop.index);
            type_gop.value_ptr.* = result;
            return result;
        }

        const unique_gop = self.next_unique_type_id.getOrPutAssumeCapacity(name);
        if (!unique_gop.found_existing) unique_gop.value_ptr.* = 2;
        id = self.fmtAssumeCapacity("{s}.{d}", .{ name.slice(self).?, unique_gop.value_ptr.* });
        unique_gop.value_ptr.* += 1;
    }
}

fn ensureUnusedTypeCapacity(
    self: *Builder,
    count: usize,
    comptime Extra: type,
    trail_len: usize,
) Allocator.Error!void {
    try self.type_map.ensureUnusedCapacity(self.gpa, count);
    try self.type_items.ensureUnusedCapacity(self.gpa, count);
    try self.type_extra.ensureUnusedCapacity(
        self.gpa,
        count * (@typeInfo(Extra).Struct.fields.len + trail_len),
    );
}

fn getOrPutTypeNoExtraAssumeCapacity(self: *Builder, item: Type.Item) struct { new: bool, type: Type } {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Type.Item) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(Type.Tag.simple)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Type.Item, _: void, rhs_index: usize) bool {
            const lhs_bits: u32 = @bitCast(lhs_key);
            const rhs_bits: u32 = @bitCast(ctx.builder.type_items.items[rhs_index]);
            return lhs_bits == rhs_bits;
        }
    };
    const gop = self.type_map.getOrPutAssumeCapacityAdapted(item, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.type_items.appendAssumeCapacity(item);
    }
    return .{ .new = !gop.found_existing, .type = @enumFromInt(gop.index) };
}

fn addTypeExtraAssumeCapacity(self: *Builder, extra: anytype) Type.Item.ExtraIndex {
    const result: Type.Item.ExtraIndex = @intCast(self.type_extra.items.len);
    inline for (@typeInfo(@TypeOf(extra)).Struct.fields) |field| {
        const value = @field(extra, field.name);
        self.type_extra.appendAssumeCapacity(switch (field.type) {
            u32 => value,
            String, Type => @intFromEnum(value),
            else => @compileError("bad field type: " ++ field.name ++ ": " ++ @typeName(field.type)),
        });
    }
    return result;
}

const TypeExtraDataTrail = struct {
    index: Type.Item.ExtraIndex,

    fn nextMut(self: *TypeExtraDataTrail, len: u32, comptime Item: type, builder: *Builder) []Item {
        const items: []Item = @ptrCast(builder.type_extra.items[self.index..][0..len]);
        self.index += @intCast(len);
        return items;
    }

    fn next(
        self: *TypeExtraDataTrail,
        len: u32,
        comptime Item: type,
        builder: *const Builder,
    ) []const Item {
        const items: []const Item = @ptrCast(builder.type_extra.items[self.index..][0..len]);
        self.index += @intCast(len);
        return items;
    }
};

fn typeExtraDataTrail(
    self: *const Builder,
    comptime T: type,
    index: Type.Item.ExtraIndex,
) struct { data: T, trail: TypeExtraDataTrail } {
    var result: T = undefined;
    const fields = @typeInfo(T).Struct.fields;
    inline for (fields, self.type_extra.items[index..][0..fields.len]) |field, value|
        @field(result, field.name) = switch (field.type) {
            u32 => value,
            String, Type => @enumFromInt(value),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        };
    return .{
        .data = result,
        .trail = .{ .index = index + @as(Type.Item.ExtraIndex, @intCast(fields.len)) },
    };
}

fn typeExtraData(self: *const Builder, comptime T: type, index: Type.Item.ExtraIndex) T {
    return self.typeExtraDataTrail(T, index).data;
}

fn attrGeneric(self: *Builder, data: []const u32) Allocator.Error!u32 {
    try self.attributes_map.ensureUnusedCapacity(self.gpa, 1);
    try self.attributes_indices.ensureUnusedCapacity(self.gpa, 1);
    try self.attributes_extra.ensureUnusedCapacity(self.gpa, data.len);

    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: []const u32) u32 {
            return @truncate(std.hash.Wyhash.hash(1, std.mem.sliceAsBytes(key)));
        }
        pub fn eql(ctx: @This(), lhs_key: []const u32, _: void, rhs_index: usize) bool {
            const start = ctx.builder.attributes_indices.items[rhs_index];
            const end = ctx.builder.attributes_indices.items[rhs_index + 1];
            return std.mem.eql(u32, lhs_key, ctx.builder.attributes_extra.items[start..end]);
        }
    };
    const gop = self.attributes_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        self.attributes_extra.appendSliceAssumeCapacity(data);
        self.attributes_indices.appendAssumeCapacity(@intCast(self.attributes_extra.items.len));
    }
    return @intCast(gop.index);
}

fn bigIntConstAssumeCapacity(
    self: *Builder,
    ty: Type,
    value: std.math.big.int.Const,
) Allocator.Error!Constant {
    const type_item = self.type_items.items[@intFromEnum(ty)];
    assert(type_item.tag == .integer);
    const bits = type_item.data;

    const ExpectedContents = [64 / @sizeOf(std.math.big.Limb)]std.math.big.Limb;
    var stack align(@alignOf(ExpectedContents)) =
        std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
    const allocator = stack.get();

    var limbs: []std.math.big.Limb = &.{};
    defer allocator.free(limbs);
    const canonical_value = if (value.fitsInTwosComp(.signed, bits)) value else canon: {
        assert(value.fitsInTwosComp(.unsigned, bits));
        limbs = try allocator.alloc(std.math.big.Limb, std.math.big.int.calcTwosCompLimbCount(bits));
        var temp_value = std.math.big.int.Mutable.init(limbs, 0);
        temp_value.truncate(value, .signed, bits);
        break :canon temp_value.toConst();
    };
    assert(canonical_value.fitsInTwosComp(.signed, bits));

    const ExtraPtr = *align(@alignOf(std.math.big.Limb)) Constant.Integer;
    const Key = struct { tag: Constant.Tag, type: Type, limbs: []const std.math.big.Limb };
    const tag: Constant.Tag = switch (canonical_value.positive) {
        true => .positive_integer,
        false => .negative_integer,
    };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Key) u32 {
            var hasher = std.hash.Wyhash.init(std.hash.uint32(@intFromEnum(key.tag)));
            hasher.update(std.mem.asBytes(&key.type));
            hasher.update(std.mem.sliceAsBytes(key.limbs));
            return @truncate(hasher.final());
        }
        pub fn eql(ctx: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            if (lhs_key.tag != ctx.builder.constant_items.items(.tag)[rhs_index]) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra: ExtraPtr =
                @ptrCast(ctx.builder.constant_limbs.items[rhs_data..][0..Constant.Integer.limbs]);
            const rhs_limbs = ctx.builder.constant_limbs
                .items[rhs_data + Constant.Integer.limbs ..][0..rhs_extra.limbs_len];
            return lhs_key.type == rhs_extra.type and
                std.mem.eql(std.math.big.Limb, lhs_key.limbs, rhs_limbs);
        }
    };

    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(
        Key{ .tag = tag, .type = ty, .limbs = canonical_value.limbs },
        Adapter{ .builder = self },
    );
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = tag,
            .data = @intCast(self.constant_limbs.items.len),
        });
        const extra: ExtraPtr =
            @ptrCast(self.constant_limbs.addManyAsArrayAssumeCapacity(Constant.Integer.limbs));
        extra.* = .{ .type = ty, .limbs_len = @intCast(canonical_value.limbs.len) };
        self.constant_limbs.appendSliceAssumeCapacity(canonical_value.limbs);
    }
    return @enumFromInt(gop.index);
}

fn halfConstAssumeCapacity(self: *Builder, val: f16) Constant {
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .half, .data = @as(u16, @bitCast(val)) },
    );
    return result.constant;
}

fn bfloatConstAssumeCapacity(self: *Builder, val: f32) Constant {
    assert(@as(u16, @truncate(@as(u32, @bitCast(val)))) == 0);
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .bfloat, .data = @bitCast(val) },
    );
    return result.constant;
}

fn floatConstAssumeCapacity(self: *Builder, val: f32) Constant {
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .float, .data = @bitCast(val) },
    );
    return result.constant;
}

fn doubleConstAssumeCapacity(self: *Builder, val: f64) Constant {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: f64) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(Constant.Tag.double)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: f64, _: void, rhs_index: usize) bool {
            if (ctx.builder.constant_items.items(.tag)[rhs_index] != .double) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.Double, rhs_data);
            return @as(u64, @bitCast(lhs_key)) == @as(u64, rhs_extra.hi) << 32 | rhs_extra.lo;
        }
    };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(val, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = .double,
            .data = self.addConstantExtraAssumeCapacity(Constant.Double{
                .lo = @truncate(@as(u64, @bitCast(val))),
                .hi = @intCast(@as(u64, @bitCast(val)) >> 32),
            }),
        });
    }
    return @enumFromInt(gop.index);
}

fn fp128ConstAssumeCapacity(self: *Builder, val: f128) Constant {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: f128) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(Constant.Tag.fp128)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: f128, _: void, rhs_index: usize) bool {
            if (ctx.builder.constant_items.items(.tag)[rhs_index] != .fp128) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.Fp128, rhs_data);
            return @as(u128, @bitCast(lhs_key)) == @as(u128, rhs_extra.hi_hi) << 96 |
                @as(u128, rhs_extra.hi_lo) << 64 | @as(u128, rhs_extra.lo_hi) << 32 | rhs_extra.lo_lo;
        }
    };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(val, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = .fp128,
            .data = self.addConstantExtraAssumeCapacity(Constant.Fp128{
                .lo_lo = @truncate(@as(u128, @bitCast(val))),
                .lo_hi = @truncate(@as(u128, @bitCast(val)) >> 32),
                .hi_lo = @truncate(@as(u128, @bitCast(val)) >> 64),
                .hi_hi = @intCast(@as(u128, @bitCast(val)) >> 96),
            }),
        });
    }
    return @enumFromInt(gop.index);
}

fn x86_fp80ConstAssumeCapacity(self: *Builder, val: f80) Constant {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: f80) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(Constant.Tag.x86_fp80)),
                std.mem.asBytes(&key)[0..10],
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: f80, _: void, rhs_index: usize) bool {
            if (ctx.builder.constant_items.items(.tag)[rhs_index] != .x86_fp80) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.Fp80, rhs_data);
            return @as(u80, @bitCast(lhs_key)) == @as(u80, rhs_extra.hi) << 64 |
                @as(u80, rhs_extra.lo_hi) << 32 | rhs_extra.lo_lo;
        }
    };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(val, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = .x86_fp80,
            .data = self.addConstantExtraAssumeCapacity(Constant.Fp80{
                .lo_lo = @truncate(@as(u80, @bitCast(val))),
                .lo_hi = @truncate(@as(u80, @bitCast(val)) >> 32),
                .hi = @intCast(@as(u80, @bitCast(val)) >> 64),
            }),
        });
    }
    return @enumFromInt(gop.index);
}

fn ppc_fp128ConstAssumeCapacity(self: *Builder, val: [2]f64) Constant {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: [2]f64) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(Constant.Tag.ppc_fp128)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: [2]f64, _: void, rhs_index: usize) bool {
            if (ctx.builder.constant_items.items(.tag)[rhs_index] != .ppc_fp128) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.Fp128, rhs_data);
            return @as(u64, @bitCast(lhs_key[0])) == @as(u64, rhs_extra.lo_hi) << 32 | rhs_extra.lo_lo and
                @as(u64, @bitCast(lhs_key[1])) == @as(u64, rhs_extra.hi_hi) << 32 | rhs_extra.hi_lo;
        }
    };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(val, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = .ppc_fp128,
            .data = self.addConstantExtraAssumeCapacity(Constant.Fp128{
                .lo_lo = @truncate(@as(u64, @bitCast(val[0]))),
                .lo_hi = @intCast(@as(u64, @bitCast(val[0])) >> 32),
                .hi_lo = @truncate(@as(u64, @bitCast(val[1]))),
                .hi_hi = @intCast(@as(u64, @bitCast(val[1])) >> 32),
            }),
        });
    }
    return @enumFromInt(gop.index);
}

fn nullConstAssumeCapacity(self: *Builder, ty: Type) Constant {
    assert(self.type_items.items[@intFromEnum(ty)].tag == .pointer);
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .null, .data = @intFromEnum(ty) },
    );
    return result.constant;
}

fn noneConstAssumeCapacity(self: *Builder, ty: Type) Constant {
    assert(ty == .token);
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .none, .data = @intFromEnum(ty) },
    );
    return result.constant;
}

fn structConstAssumeCapacity(self: *Builder, ty: Type, vals: []const Constant) Constant {
    const type_item = self.type_items.items[@intFromEnum(ty)];
    var extra = self.typeExtraDataTrail(Type.Structure, switch (type_item.tag) {
        .structure, .packed_structure => type_item.data,
        .named_structure => data: {
            const body_ty = self.typeExtraData(Type.NamedStructure, type_item.data).body;
            const body_item = self.type_items.items[@intFromEnum(body_ty)];
            switch (body_item.tag) {
                .structure, .packed_structure => break :data body_item.data,
                else => unreachable,
            }
        },
        else => unreachable,
    });
    const fields = extra.trail.next(extra.data.fields_len, Type, self);
    for (fields, vals) |field, val| assert(field == val.typeOf(self));

    for (vals) |val| {
        if (!val.isZeroInit(self)) break;
    } else return self.zeroInitConstAssumeCapacity(ty);

    const tag: Constant.Tag = switch (ty.unnamedTag(self)) {
        .structure => .structure,
        .packed_structure => .packed_structure,
        else => unreachable,
    };
    const result = self.getOrPutConstantAggregateAssumeCapacity(tag, ty, vals);
    return result.constant;
}

fn arrayConstAssumeCapacity(self: *Builder, ty: Type, vals: []const Constant) Constant {
    const type_item = self.type_items.items[@intFromEnum(ty)];
    const type_extra: struct { len: u64, child: Type } = switch (type_item.tag) {
        inline .small_array, .array => |kind| extra: {
            const extra = self.typeExtraData(switch (kind) {
                .small_array => Type.Vector,
                .array => Type.Array,
                else => unreachable,
            }, type_item.data);
            break :extra .{ .len = extra.length(), .child = extra.child };
        },
        else => unreachable,
    };
    assert(type_extra.len == vals.len);
    for (vals) |val| assert(type_extra.child == val.typeOf(self));

    for (vals) |val| {
        if (!val.isZeroInit(self)) break;
    } else return self.zeroInitConstAssumeCapacity(ty);

    const result = self.getOrPutConstantAggregateAssumeCapacity(.array, ty, vals);
    return result.constant;
}

fn stringConstAssumeCapacity(self: *Builder, val: String) Constant {
    const slice = val.slice(self).?;
    const ty = self.arrayTypeAssumeCapacity(slice.len, .i8);
    if (std.mem.allEqual(u8, slice, 0)) return self.zeroInitConstAssumeCapacity(ty);
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .string, .data = @intFromEnum(val) },
    );
    return result.constant;
}

fn vectorConstAssumeCapacity(self: *Builder, ty: Type, vals: []const Constant) Constant {
    assert(ty.isVector(self));
    assert(ty.vectorLen(self) == vals.len);
    for (vals) |val| assert(ty.childType(self) == val.typeOf(self));

    for (vals[1..]) |val| {
        if (vals[0] != val) break;
    } else return self.splatConstAssumeCapacity(ty, vals[0]);
    for (vals) |val| {
        if (!val.isZeroInit(self)) break;
    } else return self.zeroInitConstAssumeCapacity(ty);

    const result = self.getOrPutConstantAggregateAssumeCapacity(.vector, ty, vals);
    return result.constant;
}

fn splatConstAssumeCapacity(self: *Builder, ty: Type, val: Constant) Constant {
    assert(ty.scalarType(self) == val.typeOf(self));

    if (!ty.isVector(self)) return val;
    if (val.isZeroInit(self)) return self.zeroInitConstAssumeCapacity(ty);

    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Constant.Splat) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(Constant.Tag.splat)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Constant.Splat, _: void, rhs_index: usize) bool {
            if (ctx.builder.constant_items.items(.tag)[rhs_index] != .splat) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.Splat, rhs_data);
            return std.meta.eql(lhs_key, rhs_extra);
        }
    };
    const data = Constant.Splat{ .type = ty, .value = val };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = .splat,
            .data = self.addConstantExtraAssumeCapacity(data),
        });
    }
    return @enumFromInt(gop.index);
}

fn zeroInitConstAssumeCapacity(self: *Builder, ty: Type) Constant {
    switch (ty) {
        inline .half,
        .bfloat,
        .float,
        .double,
        .fp128,
        .x86_fp80,
        => |tag| return @field(Builder, @tagName(tag) ++ "ConstAssumeCapacity")(self, 0.0),
        .ppc_fp128 => return self.ppc_fp128ConstAssumeCapacity(.{ 0.0, 0.0 }),
        .token => return .none,
        .i1 => return .false,
        else => switch (self.type_items.items[@intFromEnum(ty)].tag) {
            .simple,
            .function,
            .vararg_function,
            => unreachable,
            .integer => {
                var limbs: [std.math.big.int.calcLimbLen(0)]std.math.big.Limb = undefined;
                const bigint = std.math.big.int.Mutable.init(&limbs, 0);
                return self.bigIntConstAssumeCapacity(ty, bigint.toConst()) catch unreachable;
            },
            .pointer => return self.nullConstAssumeCapacity(ty),
            .target,
            .vector,
            .scalable_vector,
            .small_array,
            .array,
            .structure,
            .packed_structure,
            .named_structure,
            => {},
        },
    }
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .zeroinitializer, .data = @intFromEnum(ty) },
    );
    return result.constant;
}

fn undefConstAssumeCapacity(self: *Builder, ty: Type) Constant {
    switch (self.type_items.items[@intFromEnum(ty)].tag) {
        .simple => switch (ty) {
            .void, .label => unreachable,
            else => {},
        },
        .function, .vararg_function => unreachable,
        else => {},
    }
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .undef, .data = @intFromEnum(ty) },
    );
    return result.constant;
}

fn poisonConstAssumeCapacity(self: *Builder, ty: Type) Constant {
    switch (self.type_items.items[@intFromEnum(ty)].tag) {
        .simple => switch (ty) {
            .void, .label => unreachable,
            else => {},
        },
        .function, .vararg_function => unreachable,
        else => {},
    }
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .poison, .data = @intFromEnum(ty) },
    );
    return result.constant;
}

fn blockAddrConstAssumeCapacity(
    self: *Builder,
    function: Function.Index,
    block: Function.Block.Index,
) Constant {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Constant.BlockAddress) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(Constant.Tag.blockaddress)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Constant.BlockAddress, _: void, rhs_index: usize) bool {
            if (ctx.builder.constant_items.items(.tag)[rhs_index] != .blockaddress) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.BlockAddress, rhs_data);
            return std.meta.eql(lhs_key, rhs_extra);
        }
    };
    const data = Constant.BlockAddress{ .function = function, .block = block };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = .blockaddress,
            .data = self.addConstantExtraAssumeCapacity(data),
        });
    }
    return @enumFromInt(gop.index);
}

fn dsoLocalEquivalentConstAssumeCapacity(self: *Builder, function: Function.Index) Constant {
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .dso_local_equivalent, .data = @intFromEnum(function) },
    );
    return result.constant;
}

fn noCfiConstAssumeCapacity(self: *Builder, function: Function.Index) Constant {
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .no_cfi, .data = @intFromEnum(function) },
    );
    return result.constant;
}

fn convTag(
    self: *Builder,
    signedness: Constant.Cast.Signedness,
    val_ty: Type,
    ty: Type,
) Function.Instruction.Tag {
    assert(val_ty != ty);
    return switch (val_ty.scalarTag(self)) {
        .simple => switch (ty.scalarTag(self)) {
            .simple => switch (std.math.order(val_ty.scalarBits(self), ty.scalarBits(self))) {
                .lt => .fpext,
                .eq => unreachable,
                .gt => .fptrunc,
            },
            .integer => switch (signedness) {
                .unsigned => .fptoui,
                .signed => .fptosi,
                .unneeded => unreachable,
            },
            else => unreachable,
        },
        .integer => switch (ty.scalarTag(self)) {
            .simple => switch (signedness) {
                .unsigned => .uitofp,
                .signed => .sitofp,
                .unneeded => unreachable,
            },
            .integer => switch (std.math.order(val_ty.scalarBits(self), ty.scalarBits(self))) {
                .lt => switch (signedness) {
                    .unsigned => .zext,
                    .signed => .sext,
                    .unneeded => unreachable,
                },
                .eq => unreachable,
                .gt => .trunc,
            },
            .pointer => .inttoptr,
            else => unreachable,
        },
        .pointer => switch (ty.scalarTag(self)) {
            .integer => .ptrtoint,
            .pointer => .addrspacecast,
            else => unreachable,
        },
        else => unreachable,
    };
}

fn convConstTag(
    self: *Builder,
    val_ty: Type,
    ty: Type,
) Constant.Tag {
    assert(val_ty != ty);
    return switch (val_ty.scalarTag(self)) {
        .integer => switch (ty.scalarTag(self)) {
            .integer => switch (std.math.order(val_ty.scalarBits(self), ty.scalarBits(self))) {
                .gt => .trunc,
                else => unreachable,
            },
            .pointer => .inttoptr,
            else => unreachable,
        },
        .pointer => switch (ty.scalarTag(self)) {
            .integer => .ptrtoint,
            .pointer => .addrspacecast,
            else => unreachable,
        },
        else => unreachable,
    };
}

fn convConstAssumeCapacity(
    self: *Builder,
    val: Constant,
    ty: Type,
) Constant {
    const val_ty = val.typeOf(self);
    if (val_ty == ty) return val;
    return self.castConstAssumeCapacity(self.convConstTag(val_ty, ty), val, ty);
}

fn castConstAssumeCapacity(self: *Builder, tag: Constant.Tag, val: Constant, ty: Type) Constant {
    const Key = struct { tag: Constant.Tag, cast: Constant.Cast };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Key) u32 {
            return @truncate(std.hash.Wyhash.hash(
                std.hash.uint32(@intFromEnum(key.tag)),
                std.mem.asBytes(&key.cast),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            if (lhs_key.tag != ctx.builder.constant_items.items(.tag)[rhs_index]) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.Cast, rhs_data);
            return std.meta.eql(lhs_key.cast, rhs_extra);
        }
    };
    const data = Key{ .tag = tag, .cast = .{ .val = val, .type = ty } };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = tag,
            .data = self.addConstantExtraAssumeCapacity(data.cast),
        });
    }
    return @enumFromInt(gop.index);
}

fn gepConstAssumeCapacity(
    self: *Builder,
    comptime kind: Constant.GetElementPtr.Kind,
    ty: Type,
    base: Constant,
    inrange: ?u16,
    indices: []const Constant,
) Constant {
    const tag: Constant.Tag = switch (kind) {
        .normal => .getelementptr,
        .inbounds => .@"getelementptr inbounds",
    };
    const base_ty = base.typeOf(self);
    const base_is_vector = base_ty.isVector(self);

    const VectorInfo = struct {
        kind: Type.Vector.Kind,
        len: u32,

        fn init(vector_ty: Type, builder: *const Builder) @This() {
            return .{ .kind = vector_ty.vectorKind(builder), .len = vector_ty.vectorLen(builder) };
        }
    };
    var vector_info: ?VectorInfo = if (base_is_vector) VectorInfo.init(base_ty, self) else null;
    for (indices) |index| {
        const index_ty = index.typeOf(self);
        switch (index_ty.tag(self)) {
            .integer => {},
            .vector, .scalable_vector => {
                const index_info = VectorInfo.init(index_ty, self);
                if (vector_info) |info|
                    assert(std.meta.eql(info, index_info))
                else
                    vector_info = index_info;
            },
            else => unreachable,
        }
    }
    if (!base_is_vector) if (vector_info) |info| switch (info.kind) {
        inline else => |vector_kind| _ = self.vectorTypeAssumeCapacity(vector_kind, info.len, base_ty),
    };

    const Key = struct {
        type: Type,
        base: Constant,
        inrange: Constant.GetElementPtr.InRangeIndex,
        indices: []const Constant,
    };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Key) u32 {
            var hasher = std.hash.Wyhash.init(comptime std.hash.uint32(@intFromEnum(tag)));
            hasher.update(std.mem.asBytes(&key.type));
            hasher.update(std.mem.asBytes(&key.base));
            hasher.update(std.mem.asBytes(&key.inrange));
            hasher.update(std.mem.sliceAsBytes(key.indices));
            return @truncate(hasher.final());
        }
        pub fn eql(ctx: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            if (ctx.builder.constant_items.items(.tag)[rhs_index] != tag) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            var rhs_extra = ctx.builder.constantExtraDataTrail(Constant.GetElementPtr, rhs_data);
            const rhs_indices =
                rhs_extra.trail.next(rhs_extra.data.info.indices_len, Constant, ctx.builder);
            return lhs_key.type == rhs_extra.data.type and lhs_key.base == rhs_extra.data.base and
                lhs_key.inrange == rhs_extra.data.info.inrange and
                std.mem.eql(Constant, lhs_key.indices, rhs_indices);
        }
    };
    const data = Key{
        .type = ty,
        .base = base,
        .inrange = if (inrange) |index| @enumFromInt(index) else .none,
        .indices = indices,
    };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = tag,
            .data = self.addConstantExtraAssumeCapacity(Constant.GetElementPtr{
                .type = ty,
                .base = base,
                .info = .{ .indices_len = @intCast(indices.len), .inrange = data.inrange },
            }),
        });
        self.constant_extra.appendSliceAssumeCapacity(@ptrCast(indices));
    }
    return @enumFromInt(gop.index);
}

fn binConstAssumeCapacity(
    self: *Builder,
    tag: Constant.Tag,
    lhs: Constant,
    rhs: Constant,
) Constant {
    switch (tag) {
        .add,
        .@"add nsw",
        .@"add nuw",
        .sub,
        .@"sub nsw",
        .@"sub nuw",
        .shl,
        .xor,
        => {},
        else => unreachable,
    }
    const Key = struct { tag: Constant.Tag, extra: Constant.Binary };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Key) u32 {
            return @truncate(std.hash.Wyhash.hash(
                std.hash.uint32(@intFromEnum(key.tag)),
                std.mem.asBytes(&key.extra),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            if (lhs_key.tag != ctx.builder.constant_items.items(.tag)[rhs_index]) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.Binary, rhs_data);
            return std.meta.eql(lhs_key.extra, rhs_extra);
        }
    };
    const data = Key{ .tag = tag, .extra = .{ .lhs = lhs, .rhs = rhs } };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = tag,
            .data = self.addConstantExtraAssumeCapacity(data.extra),
        });
    }
    return @enumFromInt(gop.index);
}

fn asmConstAssumeCapacity(
    self: *Builder,
    ty: Type,
    info: Constant.Assembly.Info,
    assembly: String,
    constraints: String,
) Constant {
    assert(ty.functionKind(self) == .normal);

    const Key = struct { tag: Constant.Tag, extra: Constant.Assembly };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Key) u32 {
            return @truncate(std.hash.Wyhash.hash(
                std.hash.uint32(@intFromEnum(key.tag)),
                std.mem.asBytes(&key.extra),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            if (lhs_key.tag != ctx.builder.constant_items.items(.tag)[rhs_index]) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.Assembly, rhs_data);
            return std.meta.eql(lhs_key.extra, rhs_extra);
        }
    };

    const data = Key{
        .tag = @enumFromInt(@intFromEnum(Constant.Tag.@"asm") + @as(u4, @bitCast(info))),
        .extra = .{ .type = ty, .assembly = assembly, .constraints = constraints },
    };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = data.tag,
            .data = self.addConstantExtraAssumeCapacity(data.extra),
        });
    }
    return @enumFromInt(gop.index);
}

fn ensureUnusedConstantCapacity(
    self: *Builder,
    count: usize,
    comptime Extra: type,
    trail_len: usize,
) Allocator.Error!void {
    try self.constant_map.ensureUnusedCapacity(self.gpa, count);
    try self.constant_items.ensureUnusedCapacity(self.gpa, count);
    try self.constant_extra.ensureUnusedCapacity(
        self.gpa,
        count * (@typeInfo(Extra).Struct.fields.len + trail_len),
    );
}

fn getOrPutConstantNoExtraAssumeCapacity(
    self: *Builder,
    item: Constant.Item,
) struct { new: bool, constant: Constant } {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Constant.Item) u32 {
            return @truncate(std.hash.Wyhash.hash(
                std.hash.uint32(@intFromEnum(key.tag)),
                std.mem.asBytes(&key.data),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Constant.Item, _: void, rhs_index: usize) bool {
            return std.meta.eql(lhs_key, ctx.builder.constant_items.get(rhs_index));
        }
    };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(item, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(item);
    }
    return .{ .new = !gop.found_existing, .constant = @enumFromInt(gop.index) };
}

fn getOrPutConstantAggregateAssumeCapacity(
    self: *Builder,
    tag: Constant.Tag,
    ty: Type,
    vals: []const Constant,
) struct { new: bool, constant: Constant } {
    switch (tag) {
        .structure, .packed_structure, .array, .vector => {},
        else => unreachable,
    }
    const Key = struct { tag: Constant.Tag, type: Type, vals: []const Constant };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Key) u32 {
            var hasher = std.hash.Wyhash.init(std.hash.uint32(@intFromEnum(key.tag)));
            hasher.update(std.mem.asBytes(&key.type));
            hasher.update(std.mem.sliceAsBytes(key.vals));
            return @truncate(hasher.final());
        }
        pub fn eql(ctx: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            if (lhs_key.tag != ctx.builder.constant_items.items(.tag)[rhs_index]) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            var rhs_extra = ctx.builder.constantExtraDataTrail(Constant.Aggregate, rhs_data);
            if (lhs_key.type != rhs_extra.data.type) return false;
            const rhs_vals = rhs_extra.trail.next(@intCast(lhs_key.vals.len), Constant, ctx.builder);
            return std.mem.eql(Constant, lhs_key.vals, rhs_vals);
        }
    };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(
        Key{ .tag = tag, .type = ty, .vals = vals },
        Adapter{ .builder = self },
    );
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = tag,
            .data = self.addConstantExtraAssumeCapacity(Constant.Aggregate{ .type = ty }),
        });
        self.constant_extra.appendSliceAssumeCapacity(@ptrCast(vals));
    }
    return .{ .new = !gop.found_existing, .constant = @enumFromInt(gop.index) };
}

fn addConstantExtraAssumeCapacity(self: *Builder, extra: anytype) Constant.Item.ExtraIndex {
    const result: Constant.Item.ExtraIndex = @intCast(self.constant_extra.items.len);
    inline for (@typeInfo(@TypeOf(extra)).Struct.fields) |field| {
        const value = @field(extra, field.name);
        self.constant_extra.appendAssumeCapacity(switch (field.type) {
            u32 => value,
            String, Type, Constant, Function.Index, Function.Block.Index => @intFromEnum(value),
            Constant.GetElementPtr.Info => @bitCast(value),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        });
    }
    return result;
}

const ConstantExtraDataTrail = struct {
    index: Constant.Item.ExtraIndex,

    fn nextMut(self: *ConstantExtraDataTrail, len: u32, comptime Item: type, builder: *Builder) []Item {
        const items: []Item = @ptrCast(builder.constant_extra.items[self.index..][0..len]);
        self.index += @intCast(len);
        return items;
    }

    fn next(
        self: *ConstantExtraDataTrail,
        len: u32,
        comptime Item: type,
        builder: *const Builder,
    ) []const Item {
        const items: []const Item = @ptrCast(builder.constant_extra.items[self.index..][0..len]);
        self.index += @intCast(len);
        return items;
    }
};

fn constantExtraDataTrail(
    self: *const Builder,
    comptime T: type,
    index: Constant.Item.ExtraIndex,
) struct { data: T, trail: ConstantExtraDataTrail } {
    var result: T = undefined;
    const fields = @typeInfo(T).Struct.fields;
    inline for (fields, self.constant_extra.items[index..][0..fields.len]) |field, value|
        @field(result, field.name) = switch (field.type) {
            u32 => value,
            String, Type, Constant, Function.Index, Function.Block.Index => @enumFromInt(value),
            Constant.GetElementPtr.Info => @bitCast(value),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        };
    return .{
        .data = result,
        .trail = .{ .index = index + @as(Constant.Item.ExtraIndex, @intCast(fields.len)) },
    };
}

fn constantExtraData(self: *const Builder, comptime T: type, index: Constant.Item.ExtraIndex) T {
    return self.constantExtraDataTrail(T, index).data;
}

fn ensureUnusedMetadataCapacity(
    self: *Builder,
    count: usize,
    comptime Extra: type,
    trail_len: usize,
) Allocator.Error!void {
    try self.metadata_map.ensureUnusedCapacity(self.gpa, count);
    try self.metadata_items.ensureUnusedCapacity(self.gpa, count);
    try self.metadata_extra.ensureUnusedCapacity(
        self.gpa,
        count * (@typeInfo(Extra).Struct.fields.len + trail_len),
    );
}

fn addMetadataExtraAssumeCapacity(self: *Builder, extra: anytype) Metadata.Item.ExtraIndex {
    const result: Metadata.Item.ExtraIndex = @intCast(self.metadata_extra.items.len);
    inline for (@typeInfo(@TypeOf(extra)).Struct.fields) |field| {
        const value = @field(extra, field.name);
        self.metadata_extra.appendAssumeCapacity(switch (field.type) {
            u32 => value,
            MetadataString, Metadata, Variable.Index, Value => @intFromEnum(value),
            Metadata.DIFlags => @bitCast(value),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        });
    }
    return result;
}

const MetadataExtraDataTrail = struct {
    index: Metadata.Item.ExtraIndex,

    fn nextMut(self: *MetadataExtraDataTrail, len: u32, comptime Item: type, builder: *Builder) []Item {
        const items: []Item = @ptrCast(builder.metadata_extra.items[self.index..][0..len]);
        self.index += @intCast(len);
        return items;
    }

    fn next(
        self: *MetadataExtraDataTrail,
        len: u32,
        comptime Item: type,
        builder: *const Builder,
    ) []const Item {
        const items: []const Item = @ptrCast(builder.metadata_extra.items[self.index..][0..len]);
        self.index += @intCast(len);
        return items;
    }
};

fn metadataExtraDataTrail(
    self: *const Builder,
    comptime T: type,
    index: Metadata.Item.ExtraIndex,
) struct { data: T, trail: MetadataExtraDataTrail } {
    var result: T = undefined;
    const fields = @typeInfo(T).Struct.fields;
    inline for (fields, self.metadata_extra.items[index..][0..fields.len]) |field, value|
        @field(result, field.name) = switch (field.type) {
            u32 => value,
            MetadataString, Metadata, Variable.Index, Value => @enumFromInt(value),
            Metadata.DIFlags => @bitCast(value),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        };
    return .{
        .data = result,
        .trail = .{ .index = index + @as(Metadata.Item.ExtraIndex, @intCast(fields.len)) },
    };
}

fn metadataExtraData(self: *const Builder, comptime T: type, index: Metadata.Item.ExtraIndex) T {
    return self.metadataExtraDataTrail(T, index).data;
}

pub fn metadataString(self: *Builder, bytes: []const u8) Allocator.Error!MetadataString {
    try self.metadata_string_bytes.ensureUnusedCapacity(self.gpa, bytes.len);
    try self.metadata_string_indices.ensureUnusedCapacity(self.gpa, 1);
    try self.metadata_string_map.ensureUnusedCapacity(self.gpa, 1);

    const gop = self.metadata_string_map.getOrPutAssumeCapacityAdapted(
        bytes,
        MetadataString.Adapter{ .builder = self },
    );
    if (!gop.found_existing) {
        self.metadata_string_bytes.appendSliceAssumeCapacity(bytes);
        self.metadata_string_indices.appendAssumeCapacity(@intCast(self.metadata_string_bytes.items.len));
    }
    return @enumFromInt(gop.index);
}

pub fn metadataStringFromStrtabString(self: *Builder, str: StrtabString) Allocator.Error!MetadataString {
    if (str == .none or str == .empty) return MetadataString.none;
    return try self.metadataString(str.slice(self).?);
}

pub fn metadataStringFmt(self: *Builder, comptime fmt_str: []const u8, fmt_args: anytype) Allocator.Error!MetadataString {
    try self.metadata_string_map.ensureUnusedCapacity(self.gpa, 1);
    try self.metadata_string_bytes.ensureUnusedCapacity(self.gpa, @intCast(std.fmt.count(fmt_str, fmt_args)));
    try self.metadata_string_indices.ensureUnusedCapacity(self.gpa, 1);
    return self.metadataStringFmtAssumeCapacity(fmt_str, fmt_args);
}

pub fn metadataStringFmtAssumeCapacity(self: *Builder, comptime fmt_str: []const u8, fmt_args: anytype) MetadataString {
    self.metadata_string_bytes.writer(undefined).print(fmt_str, fmt_args) catch unreachable;
    return self.trailingMetadataStringAssumeCapacity();
}

pub fn trailingMetadataString(self: *Builder) Allocator.Error!MetadataString {
    try self.metadata_string_indices.ensureUnusedCapacity(self.gpa, 1);
    try self.metadata_string_map.ensureUnusedCapacity(self.gpa, 1);
    return self.trailingMetadataStringAssumeCapacity();
}

pub fn trailingMetadataStringAssumeCapacity(self: *Builder) MetadataString {
    const start = self.metadata_string_indices.getLast();
    const bytes: []const u8 = self.metadata_string_bytes.items[start..];
    const gop = self.metadata_string_map.getOrPutAssumeCapacityAdapted(bytes, String.Adapter{ .builder = self });
    if (gop.found_existing) {
        self.metadata_string_bytes.shrinkRetainingCapacity(start);
    } else {
        self.metadata_string_indices.appendAssumeCapacity(@intCast(self.metadata_string_bytes.items.len));
    }
    return @enumFromInt(gop.index);
}

pub fn debugNamed(self: *Builder, name: MetadataString, operands: []const Metadata) Allocator.Error!void {
    try self.metadata_extra.ensureUnusedCapacity(self.gpa, operands.len);
    try self.metadata_named.ensureUnusedCapacity(self.gpa, 1);
    self.debugNamedAssumeCapacity(name, operands);
}

fn debugNone(self: *Builder) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, NoExtra, 0);
    return self.debugNoneAssumeCapacity();
}

pub fn debugFile(
    self: *Builder,
    filename: MetadataString,
    directory: MetadataString,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.File, 0);
    return self.debugFileAssumeCapacity(filename, directory);
}

pub fn debugCompileUnit(
    self: *Builder,
    file: Metadata,
    producer: MetadataString,
    enums: Metadata,
    globals: Metadata,
    options: Metadata.CompileUnit.Options,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.CompileUnit, 0);
    return self.debugCompileUnitAssumeCapacity(file, producer, enums, globals, options);
}

pub fn debugSubprogram(
    self: *Builder,
    file: Metadata,
    name: MetadataString,
    linkage_name: MetadataString,
    line: u32,
    scope_line: u32,
    ty: Metadata,
    options: Metadata.Subprogram.Options,
    compile_unit: Metadata,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.Subprogram, 0);
    return self.debugSubprogramAssumeCapacity(
        file,
        name,
        linkage_name,
        line,
        scope_line,
        ty,
        options,
        compile_unit,
    );
}

pub fn debugLexicalBlock(self: *Builder, scope: Metadata, file: Metadata, line: u32, column: u32) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.LexicalBlock, 0);
    return self.debugLexicalBlockAssumeCapacity(scope, file, line, column);
}

pub fn debugLocation(self: *Builder, line: u32, column: u32, scope: Metadata, inlined_at: Metadata) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.Location, 0);
    return self.debugLocationAssumeCapacity(line, column, scope, inlined_at);
}

pub fn debugBoolType(self: *Builder, name: MetadataString, size_in_bits: u64) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.BasicType, 0);
    return self.debugBoolTypeAssumeCapacity(name, size_in_bits);
}

pub fn debugUnsignedType(self: *Builder, name: MetadataString, size_in_bits: u64) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.BasicType, 0);
    return self.debugUnsignedTypeAssumeCapacity(name, size_in_bits);
}

pub fn debugSignedType(self: *Builder, name: MetadataString, size_in_bits: u64) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.BasicType, 0);
    return self.debugSignedTypeAssumeCapacity(name, size_in_bits);
}

pub fn debugFloatType(self: *Builder, name: MetadataString, size_in_bits: u64) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.BasicType, 0);
    return self.debugFloatTypeAssumeCapacity(name, size_in_bits);
}

pub fn debugForwardReference(self: *Builder) Allocator.Error!Metadata {
    try self.metadata_forward_references.ensureUnusedCapacity(self.gpa, 1);
    return self.debugForwardReferenceAssumeCapacity();
}

pub fn debugStructType(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    fields_tuple: Metadata,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.CompositeType, 0);
    return self.debugStructTypeAssumeCapacity(
        name,
        file,
        scope,
        line,
        underlying_type,
        size_in_bits,
        align_in_bits,
        fields_tuple,
    );
}

pub fn debugUnionType(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    fields_tuple: Metadata,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.CompositeType, 0);
    return self.debugUnionTypeAssumeCapacity(
        name,
        file,
        scope,
        line,
        underlying_type,
        size_in_bits,
        align_in_bits,
        fields_tuple,
    );
}

pub fn debugEnumerationType(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    fields_tuple: Metadata,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.CompositeType, 0);
    return self.debugEnumerationTypeAssumeCapacity(
        name,
        file,
        scope,
        line,
        underlying_type,
        size_in_bits,
        align_in_bits,
        fields_tuple,
    );
}

pub fn debugArrayType(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    fields_tuple: Metadata,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.CompositeType, 0);
    return self.debugArrayTypeAssumeCapacity(
        name,
        file,
        scope,
        line,
        underlying_type,
        size_in_bits,
        align_in_bits,
        fields_tuple,
    );
}

pub fn debugVectorType(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    fields_tuple: Metadata,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.CompositeType, 0);
    return self.debugVectorTypeAssumeCapacity(
        name,
        file,
        scope,
        line,
        underlying_type,
        size_in_bits,
        align_in_bits,
        fields_tuple,
    );
}

pub fn debugPointerType(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    offset_in_bits: u64,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.DerivedType, 0);
    return self.debugPointerTypeAssumeCapacity(
        name,
        file,
        scope,
        line,
        underlying_type,
        size_in_bits,
        align_in_bits,
        offset_in_bits,
    );
}

pub fn debugMemberType(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    offset_in_bits: u64,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.DerivedType, 0);
    return self.debugMemberTypeAssumeCapacity(
        name,
        file,
        scope,
        line,
        underlying_type,
        size_in_bits,
        align_in_bits,
        offset_in_bits,
    );
}

pub fn debugSubroutineType(
    self: *Builder,
    types_tuple: Metadata,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.SubroutineType, 0);
    return self.debugSubroutineTypeAssumeCapacity(types_tuple);
}

pub fn debugEnumerator(
    self: *Builder,
    name: MetadataString,
    unsigned: bool,
    bit_width: u32,
    value: std.math.big.int.Const,
) Allocator.Error!Metadata {
    assert(!(unsigned and !value.positive));
    try self.ensureUnusedMetadataCapacity(1, Metadata.Enumerator, 0);
    try self.metadata_limbs.ensureUnusedCapacity(self.gpa, value.limbs.len);
    return self.debugEnumeratorAssumeCapacity(name, unsigned, bit_width, value);
}

pub fn debugSubrange(
    self: *Builder,
    lower_bound: Metadata,
    count: Metadata,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.Subrange, 0);
    return self.debugSubrangeAssumeCapacity(lower_bound, count);
}

pub fn debugExpression(
    self: *Builder,
    elements: []const u32,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.Expression, elements.len * @sizeOf(u32));
    return self.debugExpressionAssumeCapacity(elements);
}

pub fn debugTuple(
    self: *Builder,
    elements: []const Metadata,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.Tuple, elements.len * @sizeOf(Metadata));
    return self.debugTupleAssumeCapacity(elements);
}

pub fn debugModuleFlag(
    self: *Builder,
    behavior: Metadata,
    name: MetadataString,
    constant: Metadata,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.ModuleFlag, 0);
    return self.debugModuleFlagAssumeCapacity(behavior, name, constant);
}

pub fn debugLocalVar(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    ty: Metadata,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.LocalVar, 0);
    return self.debugLocalVarAssumeCapacity(name, file, scope, line, ty);
}

pub fn debugParameter(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    ty: Metadata,
    arg_no: u32,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.Parameter, 0);
    return self.debugParameterAssumeCapacity(name, file, scope, line, ty, arg_no);
}

pub fn debugGlobalVar(
    self: *Builder,
    name: MetadataString,
    linkage_name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    ty: Metadata,
    variable: Variable.Index,
    options: Metadata.GlobalVar.Options,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.GlobalVar, 0);
    return self.debugGlobalVarAssumeCapacity(
        name,
        linkage_name,
        file,
        scope,
        line,
        ty,
        variable,
        options,
    );
}

pub fn debugGlobalVarExpression(
    self: *Builder,
    variable: Metadata,
    expression: Metadata,
) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, Metadata.GlobalVarExpression, 0);
    return self.debugGlobalVarExpressionAssumeCapacity(variable, expression);
}

pub fn debugConstant(self: *Builder, value: Constant) Allocator.Error!Metadata {
    try self.ensureUnusedMetadataCapacity(1, NoExtra, 0);
    return self.debugConstantAssumeCapacity(value);
}

pub fn debugForwardReferenceSetType(self: *Builder, fwd_ref: Metadata, ty: Metadata) void {
    assert(
        @intFromEnum(fwd_ref) >= Metadata.first_forward_reference and
            @intFromEnum(fwd_ref) <= Metadata.first_local_metadata,
    );
    const index = @intFromEnum(fwd_ref) - Metadata.first_forward_reference;
    self.metadata_forward_references.items[index] = ty;
}

fn metadataSimpleAssumeCapacity(self: *Builder, tag: Metadata.Tag, value: anytype) Metadata {
    const Key = struct {
        tag: Metadata.Tag,
        value: @TypeOf(value),
    };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Key) u32 {
            var hasher = std.hash.Wyhash.init(std.hash.uint32(@intFromEnum(key.tag)));
            inline for (std.meta.fields(@TypeOf(value))) |field| {
                hasher.update(std.mem.asBytes(&@field(key.value, field.name)));
            }
            return @truncate(hasher.final());
        }

        pub fn eql(ctx: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            if (lhs_key.tag != ctx.builder.metadata_items.items(.tag)[rhs_index]) return false;
            const rhs_data = ctx.builder.metadata_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.metadataExtraData(@TypeOf(value), rhs_data);
            return std.meta.eql(lhs_key.value, rhs_extra);
        }
    };

    const gop = self.metadata_map.getOrPutAssumeCapacityAdapted(
        Key{ .tag = tag, .value = value },
        Adapter{ .builder = self },
    );

    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.metadata_items.appendAssumeCapacity(.{
            .tag = tag,
            .data = self.addMetadataExtraAssumeCapacity(value),
        });
    }
    return @enumFromInt(gop.index);
}

fn metadataDistinctAssumeCapacity(self: *Builder, tag: Metadata.Tag, value: anytype) Metadata {
    const Key = struct { tag: Metadata.Tag, index: Metadata };
    const Adapter = struct {
        pub fn hash(_: @This(), key: Key) u32 {
            return @truncate(std.hash.Wyhash.hash(
                std.hash.uint32(@intFromEnum(key.tag)),
                std.mem.asBytes(&key.index),
            ));
        }

        pub fn eql(_: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            return @intFromEnum(lhs_key.index) == rhs_index;
        }
    };

    const gop = self.metadata_map.getOrPutAssumeCapacityAdapted(
        Key{ .tag = tag, .index = @enumFromInt(self.metadata_map.count()) },
        Adapter{},
    );

    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.metadata_items.appendAssumeCapacity(.{
            .tag = tag,
            .data = self.addMetadataExtraAssumeCapacity(value),
        });
    }
    return @enumFromInt(gop.index);
}

fn debugNamedAssumeCapacity(self: *Builder, name: MetadataString, operands: []const Metadata) void {
    assert(!self.strip);
    assert(name != .none);
    const extra_index: u32 = @intCast(self.metadata_extra.items.len);
    self.metadata_extra.appendSliceAssumeCapacity(@ptrCast(operands));

    const gop = self.metadata_named.getOrPutAssumeCapacity(name);
    gop.value_ptr.* = .{
        .index = extra_index,
        .len = @intCast(operands.len),
    };
}

pub fn debugNoneAssumeCapacity(self: *Builder) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.none, .{});
}

fn debugFileAssumeCapacity(
    self: *Builder,
    filename: MetadataString,
    directory: MetadataString,
) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.file, Metadata.File{
        .filename = filename,
        .directory = directory,
    });
}

pub fn debugCompileUnitAssumeCapacity(
    self: *Builder,
    file: Metadata,
    producer: MetadataString,
    enums: Metadata,
    globals: Metadata,
    options: Metadata.CompileUnit.Options,
) Metadata {
    assert(!self.strip);
    return self.metadataDistinctAssumeCapacity(
        if (options.optimized) .@"compile_unit optimized" else .compile_unit,
        Metadata.CompileUnit{
            .file = file,
            .producer = producer,
            .enums = enums,
            .globals = globals,
        },
    );
}

fn debugSubprogramAssumeCapacity(
    self: *Builder,
    file: Metadata,
    name: MetadataString,
    linkage_name: MetadataString,
    line: u32,
    scope_line: u32,
    ty: Metadata,
    options: Metadata.Subprogram.Options,
    compile_unit: Metadata,
) Metadata {
    assert(!self.strip);
    const tag: Metadata.Tag = @enumFromInt(@intFromEnum(Metadata.Tag.subprogram) +
        @as(u3, @truncate(@as(u32, @bitCast(options.sp_flags)) >> 2)));
    return self.metadataDistinctAssumeCapacity(tag, Metadata.Subprogram{
        .file = file,
        .name = name,
        .linkage_name = linkage_name,
        .line = line,
        .scope_line = scope_line,
        .ty = ty,
        .di_flags = options.di_flags,
        .compile_unit = compile_unit,
    });
}

fn debugLexicalBlockAssumeCapacity(self: *Builder, scope: Metadata, file: Metadata, line: u32, column: u32) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.lexical_block, Metadata.LexicalBlock{
        .scope = scope,
        .file = file,
        .line = line,
        .column = column,
    });
}

fn debugLocationAssumeCapacity(self: *Builder, line: u32, column: u32, scope: Metadata, inlined_at: Metadata) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.location, Metadata.Location{
        .line = line,
        .column = column,
        .scope = scope,
        .inlined_at = inlined_at,
    });
}

fn debugBoolTypeAssumeCapacity(self: *Builder, name: MetadataString, size_in_bits: u64) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.basic_bool_type, Metadata.BasicType{
        .name = name,
        .size_in_bits_lo = @truncate(size_in_bits),
        .size_in_bits_hi = @truncate(size_in_bits >> 32),
    });
}

fn debugUnsignedTypeAssumeCapacity(self: *Builder, name: MetadataString, size_in_bits: u64) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.basic_unsigned_type, Metadata.BasicType{
        .name = name,
        .size_in_bits_lo = @truncate(size_in_bits),
        .size_in_bits_hi = @truncate(size_in_bits >> 32),
    });
}

fn debugSignedTypeAssumeCapacity(self: *Builder, name: MetadataString, size_in_bits: u64) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.basic_signed_type, Metadata.BasicType{
        .name = name,
        .size_in_bits_lo = @truncate(size_in_bits),
        .size_in_bits_hi = @truncate(size_in_bits >> 32),
    });
}

fn debugFloatTypeAssumeCapacity(self: *Builder, name: MetadataString, size_in_bits: u64) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.basic_float_type, Metadata.BasicType{
        .name = name,
        .size_in_bits_lo = @truncate(size_in_bits),
        .size_in_bits_hi = @truncate(size_in_bits >> 32),
    });
}

fn debugForwardReferenceAssumeCapacity(self: *Builder) Metadata {
    assert(!self.strip);
    const index = Metadata.first_forward_reference + self.metadata_forward_references.items.len;
    self.metadata_forward_references.appendAssumeCapacity(.none);
    return @enumFromInt(index);
}

fn debugStructTypeAssumeCapacity(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    fields_tuple: Metadata,
) Metadata {
    assert(!self.strip);
    return self.debugCompositeTypeAssumeCapacity(
        .composite_struct_type,
        name,
        file,
        scope,
        line,
        underlying_type,
        size_in_bits,
        align_in_bits,
        fields_tuple,
    );
}

fn debugUnionTypeAssumeCapacity(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    fields_tuple: Metadata,
) Metadata {
    assert(!self.strip);
    return self.debugCompositeTypeAssumeCapacity(
        .composite_union_type,
        name,
        file,
        scope,
        line,
        underlying_type,
        size_in_bits,
        align_in_bits,
        fields_tuple,
    );
}

fn debugEnumerationTypeAssumeCapacity(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    fields_tuple: Metadata,
) Metadata {
    assert(!self.strip);
    return self.debugCompositeTypeAssumeCapacity(
        .composite_enumeration_type,
        name,
        file,
        scope,
        line,
        underlying_type,
        size_in_bits,
        align_in_bits,
        fields_tuple,
    );
}

fn debugArrayTypeAssumeCapacity(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    fields_tuple: Metadata,
) Metadata {
    assert(!self.strip);
    return self.debugCompositeTypeAssumeCapacity(
        .composite_array_type,
        name,
        file,
        scope,
        line,
        underlying_type,
        size_in_bits,
        align_in_bits,
        fields_tuple,
    );
}

fn debugVectorTypeAssumeCapacity(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    fields_tuple: Metadata,
) Metadata {
    assert(!self.strip);
    return self.debugCompositeTypeAssumeCapacity(
        .composite_vector_type,
        name,
        file,
        scope,
        line,
        underlying_type,
        size_in_bits,
        align_in_bits,
        fields_tuple,
    );
}

fn debugCompositeTypeAssumeCapacity(
    self: *Builder,
    tag: Metadata.Tag,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    fields_tuple: Metadata,
) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(tag, Metadata.CompositeType{
        .name = name,
        .file = file,
        .scope = scope,
        .line = line,
        .underlying_type = underlying_type,
        .size_in_bits_lo = @truncate(size_in_bits),
        .size_in_bits_hi = @truncate(size_in_bits >> 32),
        .align_in_bits_lo = @truncate(align_in_bits),
        .align_in_bits_hi = @truncate(align_in_bits >> 32),
        .fields_tuple = fields_tuple,
    });
}

fn debugPointerTypeAssumeCapacity(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    offset_in_bits: u64,
) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.derived_pointer_type, Metadata.DerivedType{
        .name = name,
        .file = file,
        .scope = scope,
        .line = line,
        .underlying_type = underlying_type,
        .size_in_bits_lo = @truncate(size_in_bits),
        .size_in_bits_hi = @truncate(size_in_bits >> 32),
        .align_in_bits_lo = @truncate(align_in_bits),
        .align_in_bits_hi = @truncate(align_in_bits >> 32),
        .offset_in_bits_lo = @truncate(offset_in_bits),
        .offset_in_bits_hi = @truncate(offset_in_bits >> 32),
    });
}

fn debugMemberTypeAssumeCapacity(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    underlying_type: Metadata,
    size_in_bits: u64,
    align_in_bits: u64,
    offset_in_bits: u64,
) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.derived_member_type, Metadata.DerivedType{
        .name = name,
        .file = file,
        .scope = scope,
        .line = line,
        .underlying_type = underlying_type,
        .size_in_bits_lo = @truncate(size_in_bits),
        .size_in_bits_hi = @truncate(size_in_bits >> 32),
        .align_in_bits_lo = @truncate(align_in_bits),
        .align_in_bits_hi = @truncate(align_in_bits >> 32),
        .offset_in_bits_lo = @truncate(offset_in_bits),
        .offset_in_bits_hi = @truncate(offset_in_bits >> 32),
    });
}

fn debugSubroutineTypeAssumeCapacity(
    self: *Builder,
    types_tuple: Metadata,
) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.subroutine_type, Metadata.SubroutineType{
        .types_tuple = types_tuple,
    });
}

fn debugEnumeratorAssumeCapacity(
    self: *Builder,
    name: MetadataString,
    unsigned: bool,
    bit_width: u32,
    value: std.math.big.int.Const,
) Metadata {
    assert(!self.strip);
    const Key = struct {
        tag: Metadata.Tag,
        name: MetadataString,
        bit_width: u32,
        value: std.math.big.int.Const,
    };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Key) u32 {
            var hasher = std.hash.Wyhash.init(std.hash.uint32(@intFromEnum(key.tag)));
            hasher.update(std.mem.asBytes(&key.name));
            hasher.update(std.mem.asBytes(&key.bit_width));
            hasher.update(std.mem.sliceAsBytes(key.value.limbs));
            return @truncate(hasher.final());
        }

        pub fn eql(ctx: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            if (lhs_key.tag != ctx.builder.metadata_items.items(.tag)[rhs_index]) return false;
            const rhs_data = ctx.builder.metadata_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.metadataExtraData(Metadata.Enumerator, rhs_data);
            const limbs = ctx.builder.metadata_limbs
                .items[rhs_extra.limbs_index..][0..rhs_extra.limbs_len];
            const rhs_value = std.math.big.int.Const{
                .limbs = limbs,
                .positive = lhs_key.value.positive,
            };
            return lhs_key.name == rhs_extra.name and
                lhs_key.bit_width == rhs_extra.bit_width and
                lhs_key.value.eql(rhs_value);
        }
    };

    const tag: Metadata.Tag = if (unsigned)
        .enumerator_unsigned
    else if (value.positive)
        .enumerator_signed_positive
    else
        .enumerator_signed_negative;

    assert(!(tag == .enumerator_unsigned and !value.positive));

    const gop = self.metadata_map.getOrPutAssumeCapacityAdapted(
        Key{
            .tag = tag,
            .name = name,
            .bit_width = bit_width,
            .value = value,
        },
        Adapter{ .builder = self },
    );

    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.metadata_items.appendAssumeCapacity(.{
            .tag = tag,
            .data = self.addMetadataExtraAssumeCapacity(Metadata.Enumerator{
                .name = name,
                .bit_width = bit_width,
                .limbs_index = @intCast(self.metadata_limbs.items.len),
                .limbs_len = @intCast(value.limbs.len),
            }),
        });
        self.metadata_limbs.appendSliceAssumeCapacity(value.limbs);
    }
    return @enumFromInt(gop.index);
}

fn debugSubrangeAssumeCapacity(
    self: *Builder,
    lower_bound: Metadata,
    count: Metadata,
) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.subrange, Metadata.Subrange{
        .lower_bound = lower_bound,
        .count = count,
    });
}

fn debugExpressionAssumeCapacity(
    self: *Builder,
    elements: []const u32,
) Metadata {
    assert(!self.strip);
    const Key = struct {
        elements: []const u32,
    };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Key) u32 {
            var hasher = comptime std.hash.Wyhash.init(std.hash.uint32(@intFromEnum(Metadata.Tag.expression)));
            hasher.update(std.mem.sliceAsBytes(key.elements));
            return @truncate(hasher.final());
        }

        pub fn eql(ctx: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            if (Metadata.Tag.expression != ctx.builder.metadata_items.items(.tag)[rhs_index]) return false;
            const rhs_data = ctx.builder.metadata_items.items(.data)[rhs_index];
            var rhs_extra = ctx.builder.metadataExtraDataTrail(Metadata.Expression, rhs_data);
            return std.mem.eql(
                u32,
                lhs_key.elements,
                rhs_extra.trail.next(rhs_extra.data.elements_len, u32, ctx.builder),
            );
        }
    };

    const gop = self.metadata_map.getOrPutAssumeCapacityAdapted(
        Key{ .elements = elements },
        Adapter{ .builder = self },
    );

    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.metadata_items.appendAssumeCapacity(.{
            .tag = .expression,
            .data = self.addMetadataExtraAssumeCapacity(Metadata.Expression{
                .elements_len = @intCast(elements.len),
            }),
        });
        self.metadata_extra.appendSliceAssumeCapacity(@ptrCast(elements));
    }
    return @enumFromInt(gop.index);
}

fn debugTupleAssumeCapacity(
    self: *Builder,
    elements: []const Metadata,
) Metadata {
    assert(!self.strip);
    const Key = struct {
        elements: []const Metadata,
    };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Key) u32 {
            var hasher = comptime std.hash.Wyhash.init(std.hash.uint32(@intFromEnum(Metadata.Tag.tuple)));
            hasher.update(std.mem.sliceAsBytes(key.elements));
            return @truncate(hasher.final());
        }

        pub fn eql(ctx: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            if (Metadata.Tag.tuple != ctx.builder.metadata_items.items(.tag)[rhs_index]) return false;
            const rhs_data = ctx.builder.metadata_items.items(.data)[rhs_index];
            var rhs_extra = ctx.builder.metadataExtraDataTrail(Metadata.Tuple, rhs_data);
            return std.mem.eql(
                Metadata,
                lhs_key.elements,
                rhs_extra.trail.next(rhs_extra.data.elements_len, Metadata, ctx.builder),
            );
        }
    };

    const gop = self.metadata_map.getOrPutAssumeCapacityAdapted(
        Key{ .elements = elements },
        Adapter{ .builder = self },
    );

    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.metadata_items.appendAssumeCapacity(.{
            .tag = .tuple,
            .data = self.addMetadataExtraAssumeCapacity(Metadata.Tuple{
                .elements_len = @intCast(elements.len),
            }),
        });
        self.metadata_extra.appendSliceAssumeCapacity(@ptrCast(elements));
    }
    return @enumFromInt(gop.index);
}

fn debugModuleFlagAssumeCapacity(
    self: *Builder,
    behavior: Metadata,
    name: MetadataString,
    constant: Metadata,
) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.module_flag, Metadata.ModuleFlag{
        .behavior = behavior,
        .name = name,
        .constant = constant,
    });
}

fn debugLocalVarAssumeCapacity(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    ty: Metadata,
) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.local_var, Metadata.LocalVar{
        .name = name,
        .file = file,
        .scope = scope,
        .line = line,
        .ty = ty,
    });
}

fn debugParameterAssumeCapacity(
    self: *Builder,
    name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    ty: Metadata,
    arg_no: u32,
) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.parameter, Metadata.Parameter{
        .name = name,
        .file = file,
        .scope = scope,
        .line = line,
        .ty = ty,
        .arg_no = arg_no,
    });
}

fn debugGlobalVarAssumeCapacity(
    self: *Builder,
    name: MetadataString,
    linkage_name: MetadataString,
    file: Metadata,
    scope: Metadata,
    line: u32,
    ty: Metadata,
    variable: Variable.Index,
    options: Metadata.GlobalVar.Options,
) Metadata {
    assert(!self.strip);
    return self.metadataDistinctAssumeCapacity(
        if (options.local) .@"global_var local" else .global_var,
        Metadata.GlobalVar{
            .name = name,
            .linkage_name = linkage_name,
            .file = file,
            .scope = scope,
            .line = line,
            .ty = ty,
            .variable = variable,
        },
    );
}

fn debugGlobalVarExpressionAssumeCapacity(
    self: *Builder,
    variable: Metadata,
    expression: Metadata,
) Metadata {
    assert(!self.strip);
    return self.metadataSimpleAssumeCapacity(.global_var_expression, Metadata.GlobalVarExpression{
        .variable = variable,
        .expression = expression,
    });
}

fn debugConstantAssumeCapacity(self: *Builder, constant: Constant) Metadata {
    assert(!self.strip);
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Constant) u32 {
            var hasher = comptime std.hash.Wyhash.init(std.hash.uint32(@intFromEnum(Metadata.Tag.constant)));
            hasher.update(std.mem.asBytes(&key));
            return @truncate(hasher.final());
        }

        pub fn eql(ctx: @This(), lhs_key: Constant, _: void, rhs_index: usize) bool {
            if (Metadata.Tag.constant != ctx.builder.metadata_items.items(.tag)[rhs_index]) return false;
            const rhs_data: Constant = @enumFromInt(ctx.builder.metadata_items.items(.data)[rhs_index]);
            return rhs_data == lhs_key;
        }
    };

    const gop = self.metadata_map.getOrPutAssumeCapacityAdapted(
        constant,
        Adapter{ .builder = self },
    );

    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.metadata_items.appendAssumeCapacity(.{
            .tag = .constant,
            .data = @intFromEnum(constant),
        });
    }
    return @enumFromInt(gop.index);
}

pub fn toBitcode(self: *Builder, allocator: Allocator) bitcode_writer.Error![]const u32 {
    const BitcodeWriter = bitcode_writer.BitcodeWriter(&.{ Type, FunctionAttributes });
    var bitcode = BitcodeWriter.init(allocator, .{
        std.math.log2_int_ceil(usize, self.type_items.items.len),
        std.math.log2_int_ceil(usize, 1 + self.function_attributes_set.count()),
    });
    errdefer bitcode.deinit();

    // Write LLVM IR magic
    try bitcode.writeBits(ir.MAGIC, 32);

    var record: std.ArrayListUnmanaged(u64) = .{};
    defer record.deinit(self.gpa);

    // IDENTIFICATION_BLOCK
    {
        const Identification = ir.Identification;
        var identification_block = try bitcode.enterTopBlock(Identification);

        const producer = try std.fmt.allocPrint(self.gpa, "zig {d}.{d}.{d}", .{
            build_options.semver.major,
            build_options.semver.minor,
            build_options.semver.patch,
        });
        defer self.gpa.free(producer);

        try identification_block.writeAbbrev(Identification.Version{ .string = producer });
        try identification_block.writeAbbrev(Identification.Epoch{ .epoch = 0 });

        try identification_block.end();
    }

    // MODULE_BLOCK
    {
        const Module = ir.Module;
        var module_block = try bitcode.enterTopBlock(Module);

        try module_block.writeAbbrev(Module.Version{});

        if (self.target_triple.slice(self)) |triple| {
            try module_block.writeAbbrev(Module.String{
                .code = 2,
                .string = triple,
            });
        }

        if (self.data_layout.slice(self)) |data_layout| {
            try module_block.writeAbbrev(Module.String{
                .code = 3,
                .string = data_layout,
            });
        }

        if (self.source_filename.slice(self)) |source_filename| {
            try module_block.writeAbbrev(Module.String{
                .code = 16,
                .string = source_filename,
            });
        }

        if (self.module_asm.items.len != 0) {
            try module_block.writeAbbrev(Module.String{
                .code = 4,
                .string = self.module_asm.items,
            });
        }

        // TYPE_BLOCK
        {
            var type_block = try module_block.enterSubBlock(ir.Type, true);

            try type_block.writeAbbrev(ir.Type.NumEntry{ .num = @intCast(self.type_items.items.len) });

            for (self.type_items.items, 0..) |item, i| {
                const ty: Type = @enumFromInt(i);

                switch (item.tag) {
                    .simple => try type_block.writeAbbrev(ir.Type.Simple{ .code = @truncate(item.data) }),
                    .integer => try type_block.writeAbbrev(ir.Type.Integer{ .width = item.data }),
                    .structure,
                    .packed_structure,
                    => |kind| {
                        const is_packed = switch (kind) {
                            .structure => false,
                            .packed_structure => true,
                            else => unreachable,
                        };
                        var extra = self.typeExtraDataTrail(Type.Structure, item.data);
                        try type_block.writeAbbrev(ir.Type.StructAnon{
                            .is_packed = is_packed,
                            .types = extra.trail.next(extra.data.fields_len, Type, self),
                        });
                    },
                    .named_structure => {
                        const extra = self.typeExtraData(Type.NamedStructure, item.data);
                        try type_block.writeAbbrev(ir.Type.StructName{
                            .string = extra.id.slice(self).?,
                        });

                        switch (extra.body) {
                            .none => try type_block.writeAbbrev(ir.Type.Opaque{}),
                            else => {
                                const real_struct = self.type_items.items[@intFromEnum(extra.body)];
                                const is_packed: bool = switch (real_struct.tag) {
                                    .structure => false,
                                    .packed_structure => true,
                                    else => unreachable,
                                };

                                var real_extra = self.typeExtraDataTrail(Type.Structure, real_struct.data);
                                try type_block.writeAbbrev(ir.Type.StructNamed{
                                    .is_packed = is_packed,
                                    .types = real_extra.trail.next(real_extra.data.fields_len, Type, self),
                                });
                            },
                        }
                    },
                    .array,
                    .small_array,
                    => try type_block.writeAbbrev(ir.Type.Array{
                        .len = ty.aggregateLen(self),
                        .child = ty.childType(self),
                    }),
                    .vector,
                    .scalable_vector,
                    => try type_block.writeAbbrev(ir.Type.Vector{
                        .len = ty.aggregateLen(self),
                        .child = ty.childType(self),
                    }),
                    .pointer => try type_block.writeAbbrev(ir.Type.Pointer{
                        .addr_space = ty.pointerAddrSpace(self),
                    }),
                    .target => {
                        var extra = self.typeExtraDataTrail(Type.Target, item.data);
                        try type_block.writeAbbrev(ir.Type.StructName{
                            .string = extra.data.name.slice(self).?,
                        });

                        const types = extra.trail.next(extra.data.types_len, Type, self);
                        const ints = extra.trail.next(extra.data.ints_len, u32, self);

                        try type_block.writeAbbrev(ir.Type.Target{
                            .num_types = extra.data.types_len,
                            .types = types,
                            .ints = ints,
                        });
                    },
                    .function, .vararg_function => |kind| {
                        const is_vararg = switch (kind) {
                            .function => false,
                            .vararg_function => true,
                            else => unreachable,
                        };
                        var extra = self.typeExtraDataTrail(Type.Function, item.data);
                        try type_block.writeAbbrev(ir.Type.Function{
                            .is_vararg = is_vararg,
                            .return_type = extra.data.ret,
                            .param_types = extra.trail.next(extra.data.params_len, Type, self),
                        });
                    },
                }
            }

            try type_block.end();
        }

        var attributes_set: std.AutoArrayHashMapUnmanaged(struct {
            attributes: Attributes,
            index: u32,
        }, void) = .{};
        defer attributes_set.deinit(self.gpa);

        // PARAMATTR_GROUP_BLOCK
        {
            const ParamattrGroup = ir.ParamattrGroup;

            var paramattr_group_block = try module_block.enterSubBlock(ParamattrGroup, true);

            for (self.function_attributes_set.keys()) |func_attributes| {
                for (func_attributes.slice(self), 0..) |attributes, i| {
                    const attributes_slice = attributes.slice(self);
                    if (attributes_slice.len == 0) continue;

                    const attr_gop = try attributes_set.getOrPut(self.gpa, .{
                        .attributes = attributes,
                        .index = @intCast(i),
                    });

                    if (attr_gop.found_existing) continue;

                    record.clearRetainingCapacity();
                    try record.ensureUnusedCapacity(self.gpa, 2);

                    record.appendAssumeCapacity(attr_gop.index);
                    record.appendAssumeCapacity(switch (i) {
                        0 => 0xffffffff,
                        else => i - 1,
                    });

                    for (attributes_slice) |attr_index| {
                        const kind = attr_index.getKind(self);
                        switch (attr_index.toAttribute(self)) {
                            .zeroext,
                            .signext,
                            .inreg,
                            .@"noalias",
                            .nocapture,
                            .nofree,
                            .nest,
                            .returned,
                            .nonnull,
                            .swiftself,
                            .swiftasync,
                            .swifterror,
                            .immarg,
                            .noundef,
                            .allocalign,
                            .allocptr,
                            .readnone,
                            .readonly,
                            .writeonly,
                            .alwaysinline,
                            .builtin,
                            .cold,
                            .convergent,
                            .disable_sanitizer_information,
                            .fn_ret_thunk_extern,
                            .hot,
                            .inlinehint,
                            .jumptable,
                            .minsize,
                            .naked,
                            .nobuiltin,
                            .nocallback,
                            .noduplicate,
                            .noimplicitfloat,
                            .@"noinline",
                            .nomerge,
                            .nonlazybind,
                            .noprofile,
                            .skipprofile,
                            .noredzone,
                            .noreturn,
                            .norecurse,
                            .willreturn,
                            .nosync,
                            .nounwind,
                            .nosanitize_bounds,
                            .nosanitize_coverage,
                            .null_pointer_is_valid,
                            .optforfuzzing,
                            .optnone,
                            .optsize,
                            .returns_twice,
                            .safestack,
                            .sanitize_address,
                            .sanitize_memory,
                            .sanitize_thread,
                            .sanitize_hwaddress,
                            .sanitize_memtag,
                            .speculative_load_hardening,
                            .speculatable,
                            .ssp,
                            .sspstrong,
                            .sspreq,
                            .strictfp,
                            .nocf_check,
                            .shadowcallstack,
                            .mustprogress,
                            .no_sanitize_address,
                            .no_sanitize_hwaddress,
                            .sanitize_address_dyninit,
                            => {
                                try record.ensureUnusedCapacity(self.gpa, 2);
                                record.appendAssumeCapacity(0);
                                record.appendAssumeCapacity(@intFromEnum(kind));
                            },
                            .byval,
                            .byref,
                            .preallocated,
                            .inalloca,
                            .sret,
                            .elementtype,
                            => |ty| {
                                try record.ensureUnusedCapacity(self.gpa, 3);
                                record.appendAssumeCapacity(6);
                                record.appendAssumeCapacity(@intFromEnum(kind));
                                record.appendAssumeCapacity(@intFromEnum(ty));
                            },
                            .@"align",
                            .alignstack,
                            => |alignment| {
                                try record.ensureUnusedCapacity(self.gpa, 3);
                                record.appendAssumeCapacity(1);
                                record.appendAssumeCapacity(@intFromEnum(kind));
                                record.appendAssumeCapacity(alignment.toByteUnits() orelse 0);
                            },
                            .dereferenceable,
                            .dereferenceable_or_null,
                            => |size| {
                                try record.ensureUnusedCapacity(self.gpa, 3);
                                record.appendAssumeCapacity(1);
                                record.appendAssumeCapacity(@intFromEnum(kind));
                                record.appendAssumeCapacity(size);
                            },
                            .nofpclass => |fpclass| {
                                try record.ensureUnusedCapacity(self.gpa, 3);
                                record.appendAssumeCapacity(1);
                                record.appendAssumeCapacity(@intFromEnum(kind));
                                record.appendAssumeCapacity(@as(u32, @bitCast(fpclass)));
                            },
                            .allockind => |allockind| {
                                try record.ensureUnusedCapacity(self.gpa, 3);
                                record.appendAssumeCapacity(1);
                                record.appendAssumeCapacity(@intFromEnum(kind));
                                record.appendAssumeCapacity(@as(u32, @bitCast(allockind)));
                            },

                            .allocsize => |allocsize| {
                                try record.ensureUnusedCapacity(self.gpa, 3);
                                record.appendAssumeCapacity(1);
                                record.appendAssumeCapacity(@intFromEnum(kind));
                                record.appendAssumeCapacity(@bitCast(allocsize.toLlvm()));
                            },
                            .memory => |memory| {
                                try record.ensureUnusedCapacity(self.gpa, 3);
                                record.appendAssumeCapacity(1);
                                record.appendAssumeCapacity(@intFromEnum(kind));
                                record.appendAssumeCapacity(@as(u32, @bitCast(memory)));
                            },
                            .uwtable => |uwtable| if (uwtable != .none) {
                                try record.ensureUnusedCapacity(self.gpa, 3);
                                record.appendAssumeCapacity(1);
                                record.appendAssumeCapacity(@intFromEnum(kind));
                                record.appendAssumeCapacity(@intFromEnum(uwtable));
                            },
                            .vscale_range => |vscale_range| {
                                try record.ensureUnusedCapacity(self.gpa, 3);
                                record.appendAssumeCapacity(1);
                                record.appendAssumeCapacity(@intFromEnum(kind));
                                record.appendAssumeCapacity(@bitCast(vscale_range.toLlvm()));
                            },
                            .string => |string_attr| {
                                const string_attr_kind_slice = string_attr.kind.slice(self).?;
                                const string_attr_value_slice = if (string_attr.value != .none)
                                    string_attr.value.slice(self).?
                                else
                                    null;

                                try record.ensureUnusedCapacity(
                                    self.gpa,
                                    2 + string_attr_kind_slice.len + if (string_attr_value_slice) |slice| slice.len + 1 else 0,
                                );
                                record.appendAssumeCapacity(if (string_attr.value == .none) 3 else 4);
                                for (string_attr.kind.slice(self).?) |c| {
                                    record.appendAssumeCapacity(c);
                                }
                                record.appendAssumeCapacity(0);
                                if (string_attr_value_slice) |slice| {
                                    for (slice) |c| {
                                        record.appendAssumeCapacity(c);
                                    }
                                    record.appendAssumeCapacity(0);
                                }
                            },
                            .none => unreachable,
                        }
                    }

                    try paramattr_group_block.writeUnabbrev(3, record.items);
                }
            }

            try paramattr_group_block.end();
        }

        // PARAMATTR_BLOCK
        {
            const Paramattr = ir.Paramattr;
            var paramattr_block = try module_block.enterSubBlock(Paramattr, true);

            for (self.function_attributes_set.keys()) |func_attributes| {
                const func_attributes_slice = func_attributes.slice(self);
                record.clearRetainingCapacity();
                try record.ensureUnusedCapacity(self.gpa, func_attributes_slice.len);
                for (func_attributes_slice, 0..) |attributes, i| {
                    const attributes_slice = attributes.slice(self);
                    if (attributes_slice.len == 0) continue;

                    const group_index = attributes_set.getIndex(.{
                        .attributes = attributes,
                        .index = @intCast(i),
                    }).?;
                    record.appendAssumeCapacity(@intCast(group_index));
                }

                try paramattr_block.writeAbbrev(Paramattr.Entry{ .group_indices = record.items });
            }

            try paramattr_block.end();
        }

        var globals: std.AutoArrayHashMapUnmanaged(Global.Index, void) = .{};
        defer globals.deinit(self.gpa);
        try globals.ensureUnusedCapacity(
            self.gpa,
            self.variables.items.len +
                self.functions.items.len +
                self.aliases.items.len,
        );

        for (self.variables.items) |variable| {
            if (variable.global.getReplacement(self) != .none) continue;

            globals.putAssumeCapacity(variable.global, {});
        }

        for (self.functions.items) |function| {
            if (function.global.getReplacement(self) != .none) continue;

            globals.putAssumeCapacity(function.global, {});
        }

        for (self.aliases.items) |alias| {
            if (alias.global.getReplacement(self) != .none) continue;

            globals.putAssumeCapacity(alias.global, {});
        }

        const ConstantAdapter = struct {
            const ConstantAdapter = @This();
            builder: *const Builder,
            globals: *const std.AutoArrayHashMapUnmanaged(Global.Index, void),

            pub fn get(adapter: @This(), param: anytype, comptime field_name: []const u8) @TypeOf(param) {
                _ = field_name;
                return switch (@TypeOf(param)) {
                    Constant => @enumFromInt(adapter.getConstantIndex(param)),
                    else => param,
                };
            }

            pub fn getConstantIndex(adapter: ConstantAdapter, constant: Constant) u32 {
                return switch (constant.unwrap()) {
                    .constant => |c| c + adapter.numGlobals(),
                    .global => |global| @intCast(adapter.globals.getIndex(global.unwrap(adapter.builder)).?),
                };
            }

            pub fn numConstants(adapter: ConstantAdapter) u32 {
                return @intCast(adapter.globals.count() + adapter.builder.constant_items.len);
            }

            pub fn numGlobals(adapter: ConstantAdapter) u32 {
                return @intCast(adapter.globals.count());
            }
        };

        const constant_adapter = ConstantAdapter{
            .builder = self,
            .globals = &globals,
        };

        // Globals
        {
            var section_map: std.AutoArrayHashMapUnmanaged(String, void) = .{};
            defer section_map.deinit(self.gpa);
            try section_map.ensureUnusedCapacity(self.gpa, globals.count());

            for (self.variables.items) |variable| {
                if (variable.global.getReplacement(self) != .none) continue;

                const section = blk: {
                    if (variable.section == .none) break :blk 0;
                    const gop = section_map.getOrPutAssumeCapacity(variable.section);
                    if (!gop.found_existing) {
                        try module_block.writeAbbrev(Module.String{
                            .code = 5,
                            .string = variable.section.slice(self).?,
                        });
                    }
                    break :blk gop.index + 1;
                };

                const initid = if (variable.init == .no_init)
                    0
                else
                    (constant_adapter.getConstantIndex(variable.init) + 1);

                const strtab = variable.global.strtab(self);

                const global = variable.global.ptrConst(self);
                try module_block.writeAbbrev(Module.Variable{
                    .strtab_offset = strtab.offset,
                    .strtab_size = strtab.size,
                    .type_index = global.type,
                    .is_const = .{
                        .is_const = switch (variable.mutability) {
                            .global => false,
                            .constant => true,
                        },
                        .addr_space = global.addr_space,
                    },
                    .initid = initid,
                    .linkage = global.linkage,
                    .alignment = variable.alignment.toLlvm(),
                    .section = section,
                    .visibility = global.visibility,
                    .thread_local = variable.thread_local,
                    .unnamed_addr = global.unnamed_addr,
                    .externally_initialized = global.externally_initialized,
                    .dllstorageclass = global.dll_storage_class,
                    .preemption = global.preemption,
                });
            }

            for (self.functions.items) |func| {
                if (func.global.getReplacement(self) != .none) continue;

                const section = blk: {
                    if (func.section == .none) break :blk 0;
                    const gop = section_map.getOrPutAssumeCapacity(func.section);
                    if (!gop.found_existing) {
                        try module_block.writeAbbrev(Module.String{
                            .code = 5,
                            .string = func.section.slice(self).?,
                        });
                    }
                    break :blk gop.index + 1;
                };

                const paramattr_index = if (self.function_attributes_set.getIndex(func.attributes)) |index|
                    index + 1
                else
                    0;

                const strtab = func.global.strtab(self);

                const global = func.global.ptrConst(self);
                try module_block.writeAbbrev(Module.Function{
                    .strtab_offset = strtab.offset,
                    .strtab_size = strtab.size,
                    .type_index = global.type,
                    .call_conv = func.call_conv,
                    .is_proto = func.instructions.len == 0,
                    .linkage = global.linkage,
                    .paramattr = paramattr_index,
                    .alignment = func.alignment.toLlvm(),
                    .section = section,
                    .visibility = global.visibility,
                    .unnamed_addr = global.unnamed_addr,
                    .dllstorageclass = global.dll_storage_class,
                    .preemption = global.preemption,
                    .addr_space = global.addr_space,
                });
            }

            for (self.aliases.items) |alias| {
                if (alias.global.getReplacement(self) != .none) continue;

                const strtab = alias.global.strtab(self);

                const global = alias.global.ptrConst(self);
                try module_block.writeAbbrev(Module.Alias{
                    .strtab_offset = strtab.offset,
                    .strtab_size = strtab.size,
                    .type_index = global.type,
                    .addr_space = global.addr_space,
                    .aliasee = constant_adapter.getConstantIndex(alias.aliasee),
                    .linkage = global.linkage,
                    .visibility = global.visibility,
                    .thread_local = alias.thread_local,
                    .unnamed_addr = global.unnamed_addr,
                    .dllstorageclass = global.dll_storage_class,
                    .preemption = global.preemption,
                });
            }
        }

        // CONSTANTS_BLOCK
        {
            const Constants = ir.Constants;
            var constants_block = try module_block.enterSubBlock(Constants, true);

            var current_type: Type = .none;
            const tags = self.constant_items.items(.tag);
            const datas = self.constant_items.items(.data);
            for (0..self.constant_items.len) |index| {
                record.clearRetainingCapacity();
                const constant: Constant = @enumFromInt(index);
                const constant_type = constant.typeOf(self);
                if (constant_type != current_type) {
                    try constants_block.writeAbbrev(Constants.SetType{ .type_id = constant_type });
                    current_type = constant_type;
                }
                const data = datas[index];
                switch (tags[index]) {
                    .null,
                    .zeroinitializer,
                    .none,
                    => try constants_block.writeAbbrev(Constants.Null{}),
                    .undef => try constants_block.writeAbbrev(Constants.Undef{}),
                    .poison => try constants_block.writeAbbrev(Constants.Poison{}),
                    .positive_integer,
                    .negative_integer,
                    => |tag| {
                        const extra: *align(@alignOf(std.math.big.Limb)) Constant.Integer =
                            @ptrCast(self.constant_limbs.items[data..][0..Constant.Integer.limbs]);
                        const bigint: std.math.big.int.Const = .{
                            .limbs = self.constant_limbs
                                .items[data + Constant.Integer.limbs ..][0..extra.limbs_len],
                            .positive = switch (tag) {
                                .positive_integer => true,
                                .negative_integer => false,
                                else => unreachable,
                            },
                        };
                        const bit_count = extra.type.scalarBits(self);
                        const val: i64 = if (bit_count <= 64)
                            bigint.to(i64) catch unreachable
                        else if (bigint.to(u64)) |val|
                            @bitCast(val)
                        else |_| {
                            const limbs = try record.addManyAsSlice(
                                self.gpa,
                                std.math.divCeil(u24, bit_count, 64) catch unreachable,
                            );
                            bigint.writeTwosComplement(std.mem.sliceAsBytes(limbs), .little);
                            for (limbs) |*limb| {
                                const val = std.mem.littleToNative(i64, @bitCast(limb.*));
                                limb.* = @bitCast(if (val >= 0)
                                    val << 1 | 0
                                else
                                    -%val << 1 | 1);
                            }
                            try constants_block.writeUnabbrev(5, record.items);
                            continue;
                        };
                        try constants_block.writeAbbrev(Constants.Integer{
                            .value = @bitCast(if (val >= 0)
                                val << 1 | 0
                            else
                                -%val << 1 | 1),
                        });
                    },
                    .half,
                    .bfloat,
                    => try constants_block.writeAbbrev(Constants.Half{ .value = @truncate(data) }),
                    .float => try constants_block.writeAbbrev(Constants.Float{ .value = data }),
                    .double => {
                        const extra = self.constantExtraData(Constant.Double, data);
                        try constants_block.writeAbbrev(Constants.Double{
                            .value = (@as(u64, extra.hi) << 32) | extra.lo,
                        });
                    },
                    .x86_fp80 => {
                        const extra = self.constantExtraData(Constant.Fp80, data);
                        try constants_block.writeAbbrev(Constants.Fp80{
                            .hi = @as(u64, extra.hi) << 48 | @as(u64, extra.lo_hi) << 16 |
                                extra.lo_lo >> 16,
                            .lo = @truncate(extra.lo_lo),
                        });
                    },
                    .fp128,
                    .ppc_fp128,
                    => {
                        const extra = self.constantExtraData(Constant.Fp128, data);
                        try constants_block.writeAbbrev(Constants.Fp128{
                            .lo = @as(u64, extra.lo_hi) << 32 | @as(u64, extra.lo_lo),
                            .hi = @as(u64, extra.hi_hi) << 32 | @as(u64, extra.hi_lo),
                        });
                    },
                    .array,
                    .vector,
                    .structure,
                    .packed_structure,
                    => {
                        var extra = self.constantExtraDataTrail(Constant.Aggregate, data);
                        const len: u32 = @intCast(extra.data.type.aggregateLen(self));
                        const values = extra.trail.next(len, Constant, self);

                        try constants_block.writeAbbrevAdapted(
                            Constants.Aggregate{ .values = values },
                            constant_adapter,
                        );
                    },
                    .splat => {
                        const ConstantsWriter = @TypeOf(constants_block);
                        const extra = self.constantExtraData(Constant.Splat, data);
                        const vector_len = extra.type.vectorLen(self);
                        const c = constant_adapter.getConstantIndex(extra.value);

                        try bitcode.writeBits(
                            ConstantsWriter.abbrevId(Constants.Aggregate),
                            ConstantsWriter.abbrev_len,
                        );
                        try bitcode.writeVBR(vector_len, 6);
                        for (0..vector_len) |_| {
                            try bitcode.writeBits(c, Constants.Aggregate.ops[1].array_fixed);
                        }
                    },
                    .string => {
                        const str: String = @enumFromInt(data);
                        if (str == .none) {
                            try constants_block.writeAbbrev(Constants.Null{});
                        } else {
                            const slice = str.slice(self).?;
                            if (slice.len > 0 and slice[slice.len - 1] == 0)
                                try constants_block.writeAbbrev(Constants.CString{ .string = slice[0 .. slice.len - 1] })
                            else
                                try constants_block.writeAbbrev(Constants.String{ .string = slice });
                        }
                    },
                    .bitcast,
                    .inttoptr,
                    .ptrtoint,
                    .addrspacecast,
                    .trunc,
                    => |tag| {
                        const extra = self.constantExtraData(Constant.Cast, data);
                        try constants_block.writeAbbrevAdapted(Constants.Cast{
                            .type_index = extra.type,
                            .val = extra.val,
                            .opcode = tag.toCastOpcode(),
                        }, constant_adapter);
                    },
                    .add,
                    .@"add nsw",
                    .@"add nuw",
                    .sub,
                    .@"sub nsw",
                    .@"sub nuw",
                    .shl,
                    .xor,
                    => |tag| {
                        const extra = self.constantExtraData(Constant.Binary, data);
                        try constants_block.writeAbbrevAdapted(Constants.Binary{
                            .opcode = tag.toBinaryOpcode(),
                            .lhs = extra.lhs,
                            .rhs = extra.rhs,
                        }, constant_adapter);
                    },
                    .getelementptr,
                    .@"getelementptr inbounds",
                    => |tag| {
                        var extra = self.constantExtraDataTrail(Constant.GetElementPtr, data);
                        const indices = extra.trail.next(extra.data.info.indices_len, Constant, self);
                        try record.ensureUnusedCapacity(self.gpa, 1 + 2 + 2 * indices.len);

                        record.appendAssumeCapacity(@intFromEnum(extra.data.type));

                        record.appendAssumeCapacity(@intFromEnum(extra.data.base.typeOf(self)));
                        record.appendAssumeCapacity(constant_adapter.getConstantIndex(extra.data.base));

                        for (indices) |i| {
                            record.appendAssumeCapacity(@intFromEnum(i.typeOf(self)));
                            record.appendAssumeCapacity(constant_adapter.getConstantIndex(i));
                        }

                        try constants_block.writeUnabbrev(switch (tag) {
                            .getelementptr => 12,
                            .@"getelementptr inbounds" => 20,
                            else => unreachable,
                        }, record.items);
                    },
                    .@"asm",
                    .@"asm sideeffect",
                    .@"asm alignstack",
                    .@"asm sideeffect alignstack",
                    .@"asm inteldialect",
                    .@"asm sideeffect inteldialect",
                    .@"asm alignstack inteldialect",
                    .@"asm sideeffect alignstack inteldialect",
                    .@"asm unwind",
                    .@"asm sideeffect unwind",
                    .@"asm alignstack unwind",
                    .@"asm sideeffect alignstack unwind",
                    .@"asm inteldialect unwind",
                    .@"asm sideeffect inteldialect unwind",
                    .@"asm alignstack inteldialect unwind",
                    .@"asm sideeffect alignstack inteldialect unwind",
                    => |tag| {
                        const extra = self.constantExtraData(Constant.Assembly, data);

                        const assembly_slice = extra.assembly.slice(self).?;
                        const constraints_slice = extra.constraints.slice(self).?;

                        try record.ensureUnusedCapacity(self.gpa, 4 + assembly_slice.len + constraints_slice.len);

                        record.appendAssumeCapacity(@intFromEnum(extra.type));
                        record.appendAssumeCapacity(switch (tag) {
                            .@"asm" => 0,
                            .@"asm sideeffect" => 0b0001,
                            .@"asm sideeffect alignstack" => 0b0011,
                            .@"asm sideeffect inteldialect" => 0b0101,
                            .@"asm sideeffect alignstack inteldialect" => 0b0111,
                            .@"asm sideeffect unwind" => 0b1001,
                            .@"asm sideeffect alignstack unwind" => 0b1011,
                            .@"asm sideeffect inteldialect unwind" => 0b1101,
                            .@"asm sideeffect alignstack inteldialect unwind" => 0b1111,
                            .@"asm alignstack" => 0b0010,
                            .@"asm inteldialect" => 0b0100,
                            .@"asm alignstack inteldialect" => 0b0110,
                            .@"asm unwind" => 0b1000,
                            .@"asm alignstack unwind" => 0b1010,
                            .@"asm inteldialect unwind" => 0b1100,
                            .@"asm alignstack inteldialect unwind" => 0b1110,
                            else => unreachable,
                        });

                        record.appendAssumeCapacity(assembly_slice.len);
                        for (assembly_slice) |c| record.appendAssumeCapacity(c);

                        record.appendAssumeCapacity(constraints_slice.len);
                        for (constraints_slice) |c| record.appendAssumeCapacity(c);

                        try constants_block.writeUnabbrev(30, record.items);
                    },
                    .blockaddress => {
                        const extra = self.constantExtraData(Constant.BlockAddress, data);
                        try constants_block.writeAbbrev(Constants.BlockAddress{
                            .type_id = extra.function.typeOf(self),
                            .function = constant_adapter.getConstantIndex(extra.function.toConst(self)),
                            .block = @intFromEnum(extra.block),
                        });
                    },
                    .dso_local_equivalent,
                    .no_cfi,
                    => |tag| {
                        const function: Function.Index = @enumFromInt(data);
                        try constants_block.writeAbbrev(Constants.DsoLocalEquivalentOrNoCfi{
                            .code = switch (tag) {
                                .dso_local_equivalent => 27,
                                .no_cfi => 29,
                                else => unreachable,
                            },
                            .type_id = function.typeOf(self),
                            .function = constant_adapter.getConstantIndex(function.toConst(self)),
                        });
                    },
                }
            }

            try constants_block.end();
        }

        // METADATA_KIND_BLOCK
        if (!self.strip) {
            const MetadataKindBlock = ir.MetadataKindBlock;
            var metadata_kind_block = try module_block.enterSubBlock(MetadataKindBlock, true);

            inline for (@typeInfo(ir.MetadataKind).Enum.fields) |field| {
                try metadata_kind_block.writeAbbrev(MetadataKindBlock.Kind{
                    .id = field.value,
                    .name = field.name,
                });
            }

            try metadata_kind_block.end();
        }

        const MetadataAdapter = struct {
            builder: *const Builder,
            constant_adapter: ConstantAdapter,

            pub fn init(
                builder: *const Builder,
                const_adapter: ConstantAdapter,
            ) @This() {
                return .{
                    .builder = builder,
                    .constant_adapter = const_adapter,
                };
            }

            pub fn get(adapter: @This(), value: anytype, comptime field_name: []const u8) @TypeOf(value) {
                _ = field_name;
                const Ty = @TypeOf(value);
                return switch (Ty) {
                    Metadata => @enumFromInt(adapter.getMetadataIndex(value)),
                    MetadataString => @enumFromInt(adapter.getMetadataStringIndex(value)),
                    Constant => @enumFromInt(adapter.constant_adapter.getConstantIndex(value)),
                    else => value,
                };
            }

            pub fn getMetadataIndex(adapter: @This(), metadata: Metadata) u32 {
                if (metadata == .none) return 0;
                return @intCast(adapter.builder.metadata_string_map.count() +
                    @intFromEnum(metadata.unwrap(adapter.builder)) - 1);
            }

            pub fn getMetadataStringIndex(_: @This(), metadata_string: MetadataString) u32 {
                return @intFromEnum(metadata_string);
            }
        };

        const metadata_adapter = MetadataAdapter.init(self, constant_adapter);

        // METADATA_BLOCK
        if (!self.strip) {
            const MetadataBlock = ir.MetadataBlock;
            var metadata_block = try module_block.enterSubBlock(MetadataBlock, true);

            const MetadataBlockWriter = @TypeOf(metadata_block);

            // Emit all MetadataStrings
            {
                const strings_offset, const strings_size = blk: {
                    var strings_offset: u32 = 0;
                    var strings_size: u32 = 0;
                    for (1..self.metadata_string_map.count()) |metadata_string_index| {
                        const metadata_string: MetadataString = @enumFromInt(metadata_string_index);
                        const slice = metadata_string.slice(self);
                        strings_offset += bitcode.bitsVBR(@as(u32, @intCast(slice.len)), 6);
                        strings_size += @intCast(slice.len * 8);
                    }
                    break :blk .{
                        std.mem.alignForward(u32, strings_offset, 32) / 8,
                        std.mem.alignForward(u32, strings_size, 32) / 8,
                    };
                };

                try bitcode.writeBits(
                    comptime MetadataBlockWriter.abbrevId(MetadataBlock.Strings),
                    MetadataBlockWriter.abbrev_len,
                );

                try bitcode.writeVBR(@as(u32, @intCast(self.metadata_string_map.count() - 1)), 6);
                try bitcode.writeVBR(strings_offset, 6);

                try bitcode.writeVBR(strings_size + strings_offset, 6);

                try bitcode.alignTo32();

                for (1..self.metadata_string_map.count()) |metadata_string_index| {
                    const metadata_string: MetadataString = @enumFromInt(metadata_string_index);
                    const slice = metadata_string.slice(self);
                    try bitcode.writeVBR(@as(u32, @intCast(slice.len)), 6);
                }

                try bitcode.writeBlob(self.metadata_string_bytes.items);
            }

            for (
                self.metadata_items.items(.tag)[1..],
                self.metadata_items.items(.data)[1..],
            ) |tag, data| {
                record.clearRetainingCapacity();
                switch (tag) {
                    .none => unreachable,
                    .file => {
                        const extra = self.metadataExtraData(Metadata.File, data);

                        try metadata_block.writeAbbrevAdapted(MetadataBlock.File{
                            .filename = extra.filename,
                            .directory = extra.directory,
                        }, metadata_adapter);
                    },
                    .compile_unit,
                    .@"compile_unit optimized",
                    => |kind| {
                        const extra = self.metadataExtraData(Metadata.CompileUnit, data);
                        try metadata_block.writeAbbrevAdapted(MetadataBlock.CompileUnit{
                            .file = extra.file,
                            .producer = extra.producer,
                            .is_optimized = switch (kind) {
                                .compile_unit => false,
                                .@"compile_unit optimized" => true,
                                else => unreachable,
                            },
                            .enums = extra.enums,
                            .globals = extra.globals,
                        }, metadata_adapter);
                    },
                    .subprogram,
                    .@"subprogram local",
                    .@"subprogram definition",
                    .@"subprogram local definition",
                    .@"subprogram optimized",
                    .@"subprogram optimized local",
                    .@"subprogram optimized definition",
                    .@"subprogram optimized local definition",
                    => |kind| {
                        const extra = self.metadataExtraData(Metadata.Subprogram, data);

                        try metadata_block.writeAbbrevAdapted(MetadataBlock.Subprogram{
                            .scope = extra.file,
                            .name = extra.name,
                            .linkage_name = extra.linkage_name,
                            .file = extra.file,
                            .line = extra.line,
                            .ty = extra.ty,
                            .scope_line = extra.scope_line,
                            .sp_flags = @bitCast(@as(u32, @as(u3, @intCast(
                                @intFromEnum(kind) - @intFromEnum(Metadata.Tag.subprogram),
                            ))) << 2),
                            .flags = extra.di_flags,
                            .compile_unit = extra.compile_unit,
                        }, metadata_adapter);
                    },
                    .lexical_block => {
                        const extra = self.metadataExtraData(Metadata.LexicalBlock, data);
                        try metadata_block.writeAbbrevAdapted(MetadataBlock.LexicalBlock{
                            .scope = extra.scope,
                            .file = extra.file,
                            .line = extra.line,
                            .column = extra.column,
                        }, metadata_adapter);
                    },
                    .location => {
                        const extra = self.metadataExtraData(Metadata.Location, data);
                        assert(extra.scope != .none);
                        try metadata_block.writeAbbrev(MetadataBlock.Location{
                            .line = extra.line,
                            .column = extra.column,
                            .scope = metadata_adapter.getMetadataIndex(extra.scope) - 1,
                            .inlined_at = @enumFromInt(metadata_adapter.getMetadataIndex(extra.inlined_at)),
                        });
                    },
                    .basic_bool_type,
                    .basic_unsigned_type,
                    .basic_signed_type,
                    .basic_float_type,
                    => |kind| {
                        const extra = self.metadataExtraData(Metadata.BasicType, data);
                        try metadata_block.writeAbbrevAdapted(MetadataBlock.BasicType{
                            .name = extra.name,
                            .size_in_bits = extra.bitSize(),
                            .encoding = switch (kind) {
                                .basic_bool_type => DW.ATE.boolean,
                                .basic_unsigned_type => DW.ATE.unsigned,
                                .basic_signed_type => DW.ATE.signed,
                                .basic_float_type => DW.ATE.float,
                                else => unreachable,
                            },
                        }, metadata_adapter);
                    },
                    .composite_struct_type,
                    .composite_union_type,
                    .composite_enumeration_type,
                    .composite_array_type,
                    .composite_vector_type,
                    => |kind| {
                        const extra = self.metadataExtraData(Metadata.CompositeType, data);

                        try metadata_block.writeAbbrevAdapted(MetadataBlock.CompositeType{
                            .tag = switch (kind) {
                                .composite_struct_type => DW.TAG.structure_type,
                                .composite_union_type => DW.TAG.union_type,
                                .composite_enumeration_type => DW.TAG.enumeration_type,
                                .composite_array_type, .composite_vector_type => DW.TAG.array_type,
                                else => unreachable,
                            },
                            .name = extra.name,
                            .file = extra.file,
                            .line = extra.line,
                            .scope = extra.scope,
                            .underlying_type = extra.underlying_type,
                            .size_in_bits = extra.bitSize(),
                            .align_in_bits = extra.bitAlign(),
                            .flags = if (kind == .composite_vector_type) .{ .Vector = true } else .{},
                            .elements = extra.fields_tuple,
                        }, metadata_adapter);
                    },
                    .derived_pointer_type,
                    .derived_member_type,
                    => |kind| {
                        const extra = self.metadataExtraData(Metadata.DerivedType, data);
                        try metadata_block.writeAbbrevAdapted(MetadataBlock.DerivedType{
                            .tag = switch (kind) {
                                .derived_pointer_type => DW.TAG.pointer_type,
                                .derived_member_type => DW.TAG.member,
                                else => unreachable,
                            },
                            .name = extra.name,
                            .file = extra.file,
                            .line = extra.line,
                            .scope = extra.scope,
                            .underlying_type = extra.underlying_type,
                            .size_in_bits = extra.bitSize(),
                            .align_in_bits = extra.bitAlign(),
                            .offset_in_bits = extra.bitOffset(),
                        }, metadata_adapter);
                    },
                    .subroutine_type => {
                        const extra = self.metadataExtraData(Metadata.SubroutineType, data);

                        try metadata_block.writeAbbrevAdapted(MetadataBlock.SubroutineType{
                            .types = extra.types_tuple,
                        }, metadata_adapter);
                    },
                    .enumerator_unsigned,
                    .enumerator_signed_positive,
                    .enumerator_signed_negative,
                    => |kind| {
                        const extra = self.metadataExtraData(Metadata.Enumerator, data);
                        const bigint: std.math.big.int.Const = .{
                            .limbs = self.metadata_limbs.items[extra.limbs_index..][0..extra.limbs_len],
                            .positive = switch (kind) {
                                .enumerator_unsigned,
                                .enumerator_signed_positive,
                                => true,
                                .enumerator_signed_negative => false,
                                else => unreachable,
                            },
                        };
                        const flags: MetadataBlock.Enumerator.Flags = .{
                            .unsigned = switch (kind) {
                                .enumerator_unsigned => true,
                                .enumerator_signed_positive,
                                .enumerator_signed_negative,
                                => false,
                                else => unreachable,
                            },
                        };
                        const val: i64 = if (bigint.to(i64)) |val|
                            val
                        else |_| if (bigint.to(u64)) |val|
                            @bitCast(val)
                        else |_| {
                            const limbs_len = std.math.divCeil(u32, extra.bit_width, 64) catch unreachable;
                            try record.ensureTotalCapacity(self.gpa, 3 + limbs_len);
                            record.appendAssumeCapacity(@as(
                                @typeInfo(MetadataBlock.Enumerator.Flags).Struct.backing_integer.?,
                                @bitCast(flags),
                            ));
                            record.appendAssumeCapacity(extra.bit_width);
                            record.appendAssumeCapacity(metadata_adapter.getMetadataStringIndex(extra.name));
                            const limbs = record.addManyAsSliceAssumeCapacity(limbs_len);
                            bigint.writeTwosComplement(std.mem.sliceAsBytes(limbs), .little);
                            for (limbs) |*limb| {
                                const val = std.mem.littleToNative(i64, @bitCast(limb.*));
                                limb.* = @bitCast(if (val >= 0)
                                    val << 1 | 0
                                else
                                    -%val << 1 | 1);
                            }
                            try metadata_block.writeUnabbrev(MetadataBlock.Enumerator.id, record.items);
                            continue;
                        };
                        try metadata_block.writeAbbrevAdapted(MetadataBlock.Enumerator{
                            .flags = flags,
                            .bit_width = extra.bit_width,
                            .name = extra.name,
                            .value = @bitCast(if (val >= 0)
                                val << 1 | 0
                            else
                                -%val << 1 | 1),
                        }, metadata_adapter);
                    },
                    .subrange => {
                        const extra = self.metadataExtraData(Metadata.Subrange, data);

                        try metadata_block.writeAbbrevAdapted(MetadataBlock.Subrange{
                            .count = extra.count,
                            .lower_bound = extra.lower_bound,
                        }, metadata_adapter);
                    },
                    .expression => {
                        var extra = self.metadataExtraDataTrail(Metadata.Expression, data);

                        const elements = extra.trail.next(extra.data.elements_len, u32, self);

                        try metadata_block.writeAbbrevAdapted(MetadataBlock.Expression{
                            .elements = elements,
                        }, metadata_adapter);
                    },
                    .tuple => {
                        var extra = self.metadataExtraDataTrail(Metadata.Tuple, data);

                        const elements = extra.trail.next(extra.data.elements_len, Metadata, self);

                        try metadata_block.writeAbbrevAdapted(MetadataBlock.Node{
                            .elements = elements,
                        }, metadata_adapter);
                    },
                    .module_flag => {
                        const extra = self.metadataExtraData(Metadata.ModuleFlag, data);
                        try metadata_block.writeAbbrev(MetadataBlock.Node{
                            .elements = &.{
                                @enumFromInt(metadata_adapter.getMetadataIndex(extra.behavior)),
                                @enumFromInt(metadata_adapter.getMetadataStringIndex(extra.name)),
                                @enumFromInt(metadata_adapter.getMetadataIndex(extra.constant)),
                            },
                        });
                    },
                    .local_var => {
                        const extra = self.metadataExtraData(Metadata.LocalVar, data);
                        try metadata_block.writeAbbrevAdapted(MetadataBlock.LocalVar{
                            .scope = extra.scope,
                            .name = extra.name,
                            .file = extra.file,
                            .line = extra.line,
                            .ty = extra.ty,
                        }, metadata_adapter);
                    },
                    .parameter => {
                        const extra = self.metadataExtraData(Metadata.Parameter, data);
                        try metadata_block.writeAbbrevAdapted(MetadataBlock.Parameter{
                            .scope = extra.scope,
                            .name = extra.name,
                            .file = extra.file,
                            .line = extra.line,
                            .ty = extra.ty,
                            .arg = extra.arg_no,
                        }, metadata_adapter);
                    },
                    .global_var,
                    .@"global_var local",
                    => |kind| {
                        const extra = self.metadataExtraData(Metadata.GlobalVar, data);
                        try metadata_block.writeAbbrevAdapted(MetadataBlock.GlobalVar{
                            .scope = extra.scope,
                            .name = extra.name,
                            .linkage_name = extra.linkage_name,
                            .file = extra.file,
                            .line = extra.line,
                            .ty = extra.ty,
                            .local = kind == .@"global_var local",
                        }, metadata_adapter);
                    },
                    .global_var_expression => {
                        const extra = self.metadataExtraData(Metadata.GlobalVarExpression, data);
                        try metadata_block.writeAbbrevAdapted(MetadataBlock.GlobalVarExpression{
                            .variable = extra.variable,
                            .expression = extra.expression,
                        }, metadata_adapter);
                    },
                    .constant => {
                        const constant: Constant = @enumFromInt(data);
                        try metadata_block.writeAbbrevAdapted(MetadataBlock.Constant{
                            .ty = constant.typeOf(self),
                            .constant = constant,
                        }, metadata_adapter);
                    },
                }
            }

            // Write named metadata
            for (self.metadata_named.keys(), self.metadata_named.values()) |name, operands| {
                const slice = name.slice(self);
                try metadata_block.writeAbbrev(MetadataBlock.Name{
                    .name = slice,
                });

                const elements = self.metadata_extra.items[operands.index..][0..operands.len];
                for (elements) |*e| {
                    e.* = metadata_adapter.getMetadataIndex(@enumFromInt(e.*)) - 1;
                }

                try metadata_block.writeAbbrev(MetadataBlock.NamedNode{
                    .elements = @ptrCast(elements),
                });
            }

            // Write global attached metadata
            {
                for (globals.keys()) |global| {
                    const global_ptr = global.ptrConst(self);
                    if (global_ptr.dbg == .none) continue;

                    switch (global_ptr.kind) {
                        .function => |f| if (f.ptrConst(self).instructions.len != 0) continue,
                        else => {},
                    }

                    try metadata_block.writeAbbrev(MetadataBlock.GlobalDeclAttachment{
                        .value = @enumFromInt(constant_adapter.getConstantIndex(global.toConst())),
                        .kind = ir.MetadataKind.dbg,
                        .metadata = @enumFromInt(metadata_adapter.getMetadataIndex(global_ptr.dbg) - 1),
                    });
                }
            }

            try metadata_block.end();
        }

        // Block info
        {
            const BlockInfo = ir.BlockInfo;
            var block_info_block = try module_block.enterSubBlock(BlockInfo, true);

            try block_info_block.writeUnabbrev(BlockInfo.set_block_id, &.{ir.FunctionBlock.id});
            inline for (ir.FunctionBlock.abbrevs) |abbrev| {
                try block_info_block.defineAbbrev(&abbrev.ops);
            }

            try block_info_block.writeUnabbrev(BlockInfo.set_block_id, &.{ir.FunctionValueSymbolTable.id});
            inline for (ir.FunctionValueSymbolTable.abbrevs) |abbrev| {
                try block_info_block.defineAbbrev(&abbrev.ops);
            }

            try block_info_block.writeUnabbrev(BlockInfo.set_block_id, &.{ir.FunctionMetadataBlock.id});
            inline for (ir.FunctionMetadataBlock.abbrevs) |abbrev| {
                try block_info_block.defineAbbrev(&abbrev.ops);
            }

            try block_info_block.writeUnabbrev(BlockInfo.set_block_id, &.{ir.MetadataAttachmentBlock.id});
            inline for (ir.MetadataAttachmentBlock.abbrevs) |abbrev| {
                try block_info_block.defineAbbrev(&abbrev.ops);
            }

            try block_info_block.end();
        }

        // FUNCTION_BLOCKS
        {
            const FunctionAdapter = struct {
                constant_adapter: ConstantAdapter,
                metadata_adapter: MetadataAdapter,
                func: *const Function,
                instruction_index: u32 = 0,

                pub fn init(
                    const_adapter: ConstantAdapter,
                    meta_adapter: MetadataAdapter,
                    func: *const Function,
                ) @This() {
                    return .{
                        .constant_adapter = const_adapter,
                        .metadata_adapter = meta_adapter,
                        .func = func,
                        .instruction_index = 0,
                    };
                }

                pub fn get(adapter: @This(), value: anytype, comptime field_name: []const u8) @TypeOf(value) {
                    _ = field_name;
                    const Ty = @TypeOf(value);
                    return switch (Ty) {
                        Value => @enumFromInt(adapter.getOffsetValueIndex(value)),
                        Constant => @enumFromInt(adapter.getOffsetConstantIndex(value)),
                        FunctionAttributes => @enumFromInt(switch (value) {
                            .none => 0,
                            else => 1 + adapter.constant_adapter.builder.function_attributes_set.getIndex(value).?,
                        }),
                        else => value,
                    };
                }

                pub fn getValueIndex(adapter: @This(), value: Value) u32 {
                    return @intCast(switch (value.unwrap()) {
                        .instruction => |instruction| instruction.valueIndex(adapter.func) + adapter.firstInstr(),
                        .constant => |constant| adapter.constant_adapter.getConstantIndex(constant),
                        .metadata => |metadata| {
                            assert(!adapter.func.strip);
                            const real_metadata = metadata.unwrap(adapter.metadata_adapter.builder);
                            if (@intFromEnum(real_metadata) < Metadata.first_local_metadata)
                                return adapter.metadata_adapter.getMetadataIndex(real_metadata) - 1;

                            return @intCast(@intFromEnum(metadata) -
                                Metadata.first_local_metadata +
                                adapter.metadata_adapter.builder.metadata_string_map.count() - 1 +
                                adapter.metadata_adapter.builder.metadata_map.count() - 1);
                        },
                    });
                }

                pub fn getOffsetValueIndex(adapter: @This(), value: Value) u32 {
                    return adapter.offset() -% adapter.getValueIndex(value);
                }

                pub fn getOffsetValueSignedIndex(adapter: @This(), value: Value) i32 {
                    const signed_offset: i32 = @intCast(adapter.offset());
                    const signed_value: i32 = @intCast(adapter.getValueIndex(value));
                    return signed_offset - signed_value;
                }

                pub fn getOffsetConstantIndex(adapter: @This(), constant: Constant) u32 {
                    return adapter.offset() - adapter.constant_adapter.getConstantIndex(constant);
                }

                pub fn offset(adapter: @This()) u32 {
                    return @as(
                        Function.Instruction.Index,
                        @enumFromInt(adapter.instruction_index),
                    ).valueIndex(adapter.func) + adapter.firstInstr();
                }

                fn firstInstr(adapter: @This()) u32 {
                    return adapter.constant_adapter.numConstants();
                }

                pub fn next(adapter: *@This()) void {
                    adapter.instruction_index += 1;
                }
            };

            for (self.functions.items, 0..) |func, func_index| {
                const FunctionBlock = ir.FunctionBlock;
                if (func.global.getReplacement(self) != .none) continue;

                if (func.instructions.len == 0) continue;

                var function_block = try module_block.enterSubBlock(FunctionBlock, false);

                try function_block.writeAbbrev(FunctionBlock.DeclareBlocks{ .num_blocks = func.blocks.len });

                var adapter = FunctionAdapter.init(constant_adapter, metadata_adapter, &func);

                // Emit function level metadata block
                if (!func.strip and func.debug_values.len > 0) {
                    const MetadataBlock = ir.FunctionMetadataBlock;
                    var metadata_block = try function_block.enterSubBlock(MetadataBlock, false);

                    for (func.debug_values) |value| {
                        try metadata_block.writeAbbrev(MetadataBlock.Value{
                            .ty = value.typeOf(@enumFromInt(func_index), self),
                            .value = @enumFromInt(adapter.getValueIndex(value.toValue())),
                        });
                    }

                    try metadata_block.end();
                }

                const tags = func.instructions.items(.tag);
                const datas = func.instructions.items(.data);

                var has_location = false;

                var block_incoming_len: u32 = undefined;
                for (0..func.instructions.len) |instr_index| {
                    const tag = tags[instr_index];

                    record.clearRetainingCapacity();

                    switch (tag) {
                        .block => block_incoming_len = datas[instr_index],
                        .arg => {},
                        .@"unreachable" => try function_block.writeAbbrev(FunctionBlock.Unreachable{}),
                        .call,
                        .@"musttail call",
                        .@"notail call",
                        .@"tail call",
                        => |kind| {
                            var extra = func.extraDataTrail(Function.Instruction.Call, datas[instr_index]);

                            const call_conv = extra.data.info.call_conv;
                            const args = extra.trail.next(extra.data.args_len, Value, &func);
                            try function_block.writeAbbrevAdapted(FunctionBlock.Call{
                                .attributes = extra.data.attributes,
                                .call_type = switch (kind) {
                                    .call => .{ .call_conv = call_conv },
                                    .@"tail call" => .{ .tail = true, .call_conv = call_conv },
                                    .@"musttail call" => .{ .must_tail = true, .call_conv = call_conv },
                                    .@"notail call" => .{ .no_tail = true, .call_conv = call_conv },
                                    else => unreachable,
                                },
                                .type_id = extra.data.ty,
                                .callee = extra.data.callee,
                                .args = args,
                            }, adapter);
                        },
                        .@"call fast",
                        .@"musttail call fast",
                        .@"notail call fast",
                        .@"tail call fast",
                        => |kind| {
                            var extra = func.extraDataTrail(Function.Instruction.Call, datas[instr_index]);

                            const call_conv = extra.data.info.call_conv;
                            const args = extra.trail.next(extra.data.args_len, Value, &func);
                            try function_block.writeAbbrevAdapted(FunctionBlock.CallFast{
                                .attributes = extra.data.attributes,
                                .call_type = switch (kind) {
                                    .@"call fast" => .{ .call_conv = call_conv },
                                    .@"tail call fast" => .{ .tail = true, .call_conv = call_conv },
                                    .@"musttail call fast" => .{ .must_tail = true, .call_conv = call_conv },
                                    .@"notail call fast" => .{ .no_tail = true, .call_conv = call_conv },
                                    else => unreachable,
                                },
                                .fast_math = FastMath.fast,
                                .type_id = extra.data.ty,
                                .callee = extra.data.callee,
                                .args = args,
                            }, adapter);
                        },
                        .add,
                        .@"and",
                        .fadd,
                        .fdiv,
                        .fmul,
                        .mul,
                        .frem,
                        .fsub,
                        .sdiv,
                        .sub,
                        .udiv,
                        .xor,
                        .shl,
                        .lshr,
                        .@"or",
                        .urem,
                        .srem,
                        .ashr,
                        => |kind| {
                            const extra = func.extraData(Function.Instruction.Binary, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.Binary{
                                .opcode = kind.toBinaryOpcode(),
                                .lhs = adapter.getOffsetValueIndex(extra.lhs),
                                .rhs = adapter.getOffsetValueIndex(extra.rhs),
                            });
                        },
                        .@"sdiv exact",
                        .@"udiv exact",
                        .@"lshr exact",
                        .@"ashr exact",
                        => |kind| {
                            const extra = func.extraData(Function.Instruction.Binary, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.BinaryExact{
                                .opcode = kind.toBinaryOpcode(),
                                .lhs = adapter.getOffsetValueIndex(extra.lhs),
                                .rhs = adapter.getOffsetValueIndex(extra.rhs),
                            });
                        },
                        .@"add nsw",
                        .@"add nuw",
                        .@"add nuw nsw",
                        .@"mul nsw",
                        .@"mul nuw",
                        .@"mul nuw nsw",
                        .@"sub nsw",
                        .@"sub nuw",
                        .@"sub nuw nsw",
                        .@"shl nsw",
                        .@"shl nuw",
                        .@"shl nuw nsw",
                        => |kind| {
                            const extra = func.extraData(Function.Instruction.Binary, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.BinaryNoWrap{
                                .opcode = kind.toBinaryOpcode(),
                                .lhs = adapter.getOffsetValueIndex(extra.lhs),
                                .rhs = adapter.getOffsetValueIndex(extra.rhs),
                                .flags = switch (kind) {
                                    .@"add nsw",
                                    .@"mul nsw",
                                    .@"sub nsw",
                                    .@"shl nsw",
                                    => .{ .no_unsigned_wrap = false, .no_signed_wrap = true },
                                    .@"add nuw",
                                    .@"mul nuw",
                                    .@"sub nuw",
                                    .@"shl nuw",
                                    => .{ .no_unsigned_wrap = true, .no_signed_wrap = false },
                                    .@"add nuw nsw",
                                    .@"mul nuw nsw",
                                    .@"sub nuw nsw",
                                    .@"shl nuw nsw",
                                    => .{ .no_unsigned_wrap = true, .no_signed_wrap = true },
                                    else => unreachable,
                                },
                            });
                        },
                        .@"fadd fast",
                        .@"fdiv fast",
                        .@"fmul fast",
                        .@"frem fast",
                        .@"fsub fast",
                        => |kind| {
                            const extra = func.extraData(Function.Instruction.Binary, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.BinaryFast{
                                .opcode = kind.toBinaryOpcode(),
                                .lhs = adapter.getOffsetValueIndex(extra.lhs),
                                .rhs = adapter.getOffsetValueIndex(extra.rhs),
                                .fast_math = FastMath.fast,
                            });
                        },
                        .alloca,
                        .@"alloca inalloca",
                        => |kind| {
                            const extra = func.extraData(Function.Instruction.Alloca, datas[instr_index]);
                            const alignment = extra.info.alignment.toLlvm();
                            try function_block.writeAbbrev(FunctionBlock.Alloca{
                                .inst_type = extra.type,
                                .len_type = extra.len.typeOf(@enumFromInt(func_index), self),
                                .len_value = adapter.getValueIndex(extra.len),
                                .flags = .{
                                    .align_lower = @truncate(alignment),
                                    .inalloca = kind == .@"alloca inalloca",
                                    .explicit_type = true,
                                    .swift_error = false,
                                    .align_upper = @truncate(alignment << 5),
                                },
                            });
                        },
                        .bitcast,
                        .inttoptr,
                        .ptrtoint,
                        .fptosi,
                        .fptoui,
                        .sitofp,
                        .uitofp,
                        .addrspacecast,
                        .fptrunc,
                        .trunc,
                        .fpext,
                        .sext,
                        .zext,
                        => |kind| {
                            const extra = func.extraData(Function.Instruction.Cast, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.Cast{
                                .val = adapter.getOffsetValueIndex(extra.val),
                                .type_index = extra.type,
                                .opcode = kind.toCastOpcode(),
                            });
                        },
                        .@"fcmp false",
                        .@"fcmp oeq",
                        .@"fcmp oge",
                        .@"fcmp ogt",
                        .@"fcmp ole",
                        .@"fcmp olt",
                        .@"fcmp one",
                        .@"fcmp ord",
                        .@"fcmp true",
                        .@"fcmp ueq",
                        .@"fcmp uge",
                        .@"fcmp ugt",
                        .@"fcmp ule",
                        .@"fcmp ult",
                        .@"fcmp une",
                        .@"fcmp uno",
                        .@"icmp eq",
                        .@"icmp ne",
                        .@"icmp sge",
                        .@"icmp sgt",
                        .@"icmp sle",
                        .@"icmp slt",
                        .@"icmp uge",
                        .@"icmp ugt",
                        .@"icmp ule",
                        .@"icmp ult",
                        => |kind| {
                            const extra = func.extraData(Function.Instruction.Binary, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.Cmp{
                                .lhs = adapter.getOffsetValueIndex(extra.lhs),
                                .rhs = adapter.getOffsetValueIndex(extra.rhs),
                                .pred = kind.toCmpPredicate(),
                            });
                        },
                        .@"fcmp fast false",
                        .@"fcmp fast oeq",
                        .@"fcmp fast oge",
                        .@"fcmp fast ogt",
                        .@"fcmp fast ole",
                        .@"fcmp fast olt",
                        .@"fcmp fast one",
                        .@"fcmp fast ord",
                        .@"fcmp fast true",
                        .@"fcmp fast ueq",
                        .@"fcmp fast uge",
                        .@"fcmp fast ugt",
                        .@"fcmp fast ule",
                        .@"fcmp fast ult",
                        .@"fcmp fast une",
                        .@"fcmp fast uno",
                        => |kind| {
                            const extra = func.extraData(Function.Instruction.Binary, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.CmpFast{
                                .lhs = adapter.getOffsetValueIndex(extra.lhs),
                                .rhs = adapter.getOffsetValueIndex(extra.rhs),
                                .pred = kind.toCmpPredicate(),
                                .fast_math = FastMath.fast,
                            });
                        },
                        .fneg => try function_block.writeAbbrev(FunctionBlock.FNeg{
                            .val = adapter.getOffsetValueIndex(@enumFromInt(datas[instr_index])),
                        }),
                        .@"fneg fast" => try function_block.writeAbbrev(FunctionBlock.FNegFast{
                            .val = adapter.getOffsetValueIndex(@enumFromInt(datas[instr_index])),
                            .fast_math = FastMath.fast,
                        }),
                        .extractvalue => {
                            var extra = func.extraDataTrail(Function.Instruction.ExtractValue, datas[instr_index]);
                            const indices = extra.trail.next(extra.data.indices_len, u32, &func);
                            try function_block.writeAbbrev(FunctionBlock.ExtractValue{
                                .val = adapter.getOffsetValueIndex(extra.data.val),
                                .indices = indices,
                            });
                        },
                        .insertvalue => {
                            var extra = func.extraDataTrail(Function.Instruction.InsertValue, datas[instr_index]);
                            const indices = extra.trail.next(extra.data.indices_len, u32, &func);
                            try function_block.writeAbbrev(FunctionBlock.InsertValue{
                                .val = adapter.getOffsetValueIndex(extra.data.val),
                                .elem = adapter.getOffsetValueIndex(extra.data.elem),
                                .indices = indices,
                            });
                        },
                        .extractelement => {
                            const extra = func.extraData(Function.Instruction.ExtractElement, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.ExtractElement{
                                .val = adapter.getOffsetValueIndex(extra.val),
                                .index = adapter.getOffsetValueIndex(extra.index),
                            });
                        },
                        .insertelement => {
                            const extra = func.extraData(Function.Instruction.InsertElement, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.InsertElement{
                                .val = adapter.getOffsetValueIndex(extra.val),
                                .elem = adapter.getOffsetValueIndex(extra.elem),
                                .index = adapter.getOffsetValueIndex(extra.index),
                            });
                        },
                        .select => {
                            const extra = func.extraData(Function.Instruction.Select, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.Select{
                                .lhs = adapter.getOffsetValueIndex(extra.lhs),
                                .rhs = adapter.getOffsetValueIndex(extra.rhs),
                                .cond = adapter.getOffsetValueIndex(extra.cond),
                            });
                        },
                        .@"select fast" => {
                            const extra = func.extraData(Function.Instruction.Select, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.SelectFast{
                                .lhs = adapter.getOffsetValueIndex(extra.lhs),
                                .rhs = adapter.getOffsetValueIndex(extra.rhs),
                                .cond = adapter.getOffsetValueIndex(extra.cond),
                                .fast_math = FastMath.fast,
                            });
                        },
                        .shufflevector => {
                            const extra = func.extraData(Function.Instruction.ShuffleVector, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.ShuffleVector{
                                .lhs = adapter.getOffsetValueIndex(extra.lhs),
                                .rhs = adapter.getOffsetValueIndex(extra.rhs),
                                .mask = adapter.getOffsetValueIndex(extra.mask),
                            });
                        },
                        .getelementptr,
                        .@"getelementptr inbounds",
                        => |kind| {
                            var extra = func.extraDataTrail(Function.Instruction.GetElementPtr, datas[instr_index]);
                            const indices = extra.trail.next(extra.data.indices_len, Value, &func);
                            try function_block.writeAbbrevAdapted(
                                FunctionBlock.GetElementPtr{
                                    .is_inbounds = kind == .@"getelementptr inbounds",
                                    .type_index = extra.data.type,
                                    .base = extra.data.base,
                                    .indices = indices,
                                },
                                adapter,
                            );
                        },
                        .load => {
                            const extra = func.extraData(Function.Instruction.Load, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.Load{
                                .ptr = adapter.getOffsetValueIndex(extra.ptr),
                                .ty = extra.type,
                                .alignment = extra.info.alignment.toLlvm(),
                                .is_volatile = extra.info.access_kind == .@"volatile",
                            });
                        },
                        .@"load atomic" => {
                            const extra = func.extraData(Function.Instruction.Load, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.LoadAtomic{
                                .ptr = adapter.getOffsetValueIndex(extra.ptr),
                                .ty = extra.type,
                                .alignment = extra.info.alignment.toLlvm(),
                                .is_volatile = extra.info.access_kind == .@"volatile",
                                .success_ordering = extra.info.success_ordering,
                                .sync_scope = extra.info.sync_scope,
                            });
                        },
                        .store => {
                            const extra = func.extraData(Function.Instruction.Store, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.Store{
                                .ptr = adapter.getOffsetValueIndex(extra.ptr),
                                .val = adapter.getOffsetValueIndex(extra.val),
                                .alignment = extra.info.alignment.toLlvm(),
                                .is_volatile = extra.info.access_kind == .@"volatile",
                            });
                        },
                        .@"store atomic" => {
                            const extra = func.extraData(Function.Instruction.Store, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.StoreAtomic{
                                .ptr = adapter.getOffsetValueIndex(extra.ptr),
                                .val = adapter.getOffsetValueIndex(extra.val),
                                .alignment = extra.info.alignment.toLlvm(),
                                .is_volatile = extra.info.access_kind == .@"volatile",
                                .success_ordering = extra.info.success_ordering,
                                .sync_scope = extra.info.sync_scope,
                            });
                        },
                        .br => {
                            try function_block.writeAbbrev(FunctionBlock.BrUnconditional{
                                .block = datas[instr_index],
                            });
                        },
                        .br_cond => {
                            const extra = func.extraData(Function.Instruction.BrCond, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.BrConditional{
                                .then_block = @intFromEnum(extra.then),
                                .else_block = @intFromEnum(extra.@"else"),
                                .condition = adapter.getOffsetValueIndex(extra.cond),
                            });
                        },
                        .@"switch" => {
                            var extra = func.extraDataTrail(Function.Instruction.Switch, datas[instr_index]);

                            try record.ensureUnusedCapacity(self.gpa, 3 + extra.data.cases_len * 2);

                            // Conditional type
                            record.appendAssumeCapacity(@intFromEnum(extra.data.val.typeOf(@enumFromInt(func_index), self)));

                            // Conditional
                            record.appendAssumeCapacity(adapter.getOffsetValueIndex(extra.data.val));

                            // Default block
                            record.appendAssumeCapacity(@intFromEnum(extra.data.default));

                            const vals = extra.trail.next(extra.data.cases_len, Constant, &func);
                            const blocks = extra.trail.next(extra.data.cases_len, Function.Block.Index, &func);
                            for (vals, blocks) |val, block| {
                                record.appendAssumeCapacity(adapter.constant_adapter.getConstantIndex(val));
                                record.appendAssumeCapacity(@intFromEnum(block));
                            }

                            try function_block.writeUnabbrev(12, record.items);
                        },
                        .va_arg => {
                            const extra = func.extraData(Function.Instruction.VaArg, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.VaArg{
                                .list_type = extra.list.typeOf(@enumFromInt(func_index), self),
                                .list = adapter.getOffsetValueIndex(extra.list),
                                .type = extra.type,
                            });
                        },
                        .phi,
                        .@"phi fast",
                        => |kind| {
                            var extra = func.extraDataTrail(Function.Instruction.Phi, datas[instr_index]);
                            const vals = extra.trail.next(block_incoming_len, Value, &func);
                            const blocks = extra.trail.next(block_incoming_len, Function.Block.Index, &func);

                            try record.ensureUnusedCapacity(
                                self.gpa,
                                1 + block_incoming_len * 2 + @intFromBool(kind == .@"phi fast"),
                            );

                            record.appendAssumeCapacity(@intFromEnum(extra.data.type));

                            for (vals, blocks) |val, block| {
                                const offset_value = adapter.getOffsetValueSignedIndex(val);
                                const abs_value: u32 = @intCast(@abs(offset_value));
                                const signed_vbr = if (offset_value > 0) abs_value << 1 else ((abs_value << 1) | 1);
                                record.appendAssumeCapacity(signed_vbr);
                                record.appendAssumeCapacity(@intFromEnum(block));
                            }

                            if (kind == .@"phi fast") record.appendAssumeCapacity(@as(u8, @bitCast(FastMath{})));

                            try function_block.writeUnabbrev(16, record.items);
                        },
                        .ret => try function_block.writeAbbrev(FunctionBlock.Ret{
                            .val = adapter.getOffsetValueIndex(@enumFromInt(datas[instr_index])),
                        }),
                        .@"ret void" => try function_block.writeAbbrev(FunctionBlock.RetVoid{}),
                        .atomicrmw => {
                            const extra = func.extraData(Function.Instruction.AtomicRmw, datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.AtomicRmw{
                                .ptr = adapter.getOffsetValueIndex(extra.ptr),
                                .val = adapter.getOffsetValueIndex(extra.val),
                                .operation = extra.info.atomic_rmw_operation,
                                .is_volatile = extra.info.access_kind == .@"volatile",
                                .success_ordering = extra.info.success_ordering,
                                .sync_scope = extra.info.sync_scope,
                                .alignment = extra.info.alignment.toLlvm(),
                            });
                        },
                        .cmpxchg,
                        .@"cmpxchg weak",
                        => |kind| {
                            const extra = func.extraData(Function.Instruction.CmpXchg, datas[instr_index]);

                            try function_block.writeAbbrev(FunctionBlock.CmpXchg{
                                .ptr = adapter.getOffsetValueIndex(extra.ptr),
                                .cmp = adapter.getOffsetValueIndex(extra.cmp),
                                .new = adapter.getOffsetValueIndex(extra.new),
                                .is_volatile = extra.info.access_kind == .@"volatile",
                                .success_ordering = extra.info.success_ordering,
                                .sync_scope = extra.info.sync_scope,
                                .failure_ordering = extra.info.failure_ordering,
                                .is_weak = kind == .@"cmpxchg weak",
                                .alignment = extra.info.alignment.toLlvm(),
                            });
                        },
                        .fence => {
                            const info: MemoryAccessInfo = @bitCast(datas[instr_index]);
                            try function_block.writeAbbrev(FunctionBlock.Fence{
                                .ordering = info.success_ordering,
                                .sync_scope = info.sync_scope,
                            });
                        },
                    }

                    if (!func.strip) {
                        if (func.debug_locations.get(@enumFromInt(instr_index))) |debug_location| {
                            switch (debug_location) {
                                .no_location => has_location = false,
                                .location => |location| {
                                    try function_block.writeAbbrev(FunctionBlock.DebugLoc{
                                        .line = location.line,
                                        .column = location.column,
                                        .scope = @enumFromInt(metadata_adapter.getMetadataIndex(location.scope)),
                                        .inlined_at = @enumFromInt(metadata_adapter.getMetadataIndex(location.inlined_at)),
                                    });
                                    has_location = true;
                                },
                            }
                        } else if (has_location) {
                            try function_block.writeAbbrev(FunctionBlock.DebugLocAgain{});
                        }
                    }

                    adapter.next();
                }

                // VALUE_SYMTAB
                if (!func.strip) {
                    const ValueSymbolTable = ir.FunctionValueSymbolTable;

                    var value_symtab_block = try function_block.enterSubBlock(ValueSymbolTable, false);

                    for (func.blocks, 0..) |block, block_index| {
                        const name = block.instruction.name(&func);

                        if (name == .none or name == .empty) continue;

                        try value_symtab_block.writeAbbrev(ValueSymbolTable.BlockEntry{
                            .value_id = @intCast(block_index),
                            .string = name.slice(self).?,
                        });
                    }

                    // TODO: Emit non block entries if the builder ever starts assigning names to non blocks

                    try value_symtab_block.end();
                }

                // METADATA_ATTACHMENT_BLOCK
                if (!func.strip) blk: {
                    const dbg = func.global.ptrConst(self).dbg;

                    if (dbg == .none) break :blk;

                    const MetadataAttachmentBlock = ir.MetadataAttachmentBlock;
                    var metadata_attach_block = try function_block.enterSubBlock(MetadataAttachmentBlock, false);

                    try metadata_attach_block.writeAbbrev(MetadataAttachmentBlock.AttachmentSingle{
                        .kind = ir.MetadataKind.dbg,
                        .metadata = @enumFromInt(metadata_adapter.getMetadataIndex(dbg) - 1),
                    });

                    try metadata_attach_block.end();
                }

                try function_block.end();
            }
        }

        try module_block.end();
    }

    // STRTAB_BLOCK
    {
        const Strtab = ir.Strtab;
        var strtab_block = try bitcode.enterTopBlock(Strtab);

        try strtab_block.writeAbbrev(Strtab.Blob{ .blob = self.strtab_string_bytes.items });

        try strtab_block.end();
    }

    return bitcode.toOwnedSlice();
}

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const bitcode_writer = @import("bitcode_writer.zig");
const build_options = @import("build_options");
const Builder = @This();
const builtin = @import("builtin");
const DW = std.dwarf;
const ir = @import("ir.zig");
const log = std.log.scoped(.llvm);
const std = @import("std");
