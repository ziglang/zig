gpa: Allocator,
use_lib_llvm: bool,
strip: bool,

llvm: if (build_options.have_llvm) struct {
    context: *llvm.Context,
    module: ?*llvm.Module,
    target: ?*llvm.Target,
    di_builder: ?*llvm.DIBuilder,
    di_compile_unit: ?*llvm.DICompileUnit,
    attribute_kind_ids: ?*[Attribute.Kind.len]c_uint,
    attributes: std.ArrayListUnmanaged(*llvm.Attribute),
    types: std.ArrayListUnmanaged(*llvm.Type),
    globals: std.ArrayListUnmanaged(*llvm.Value),
    constants: std.ArrayListUnmanaged(*llvm.Value),
    replacements: std.AutoHashMapUnmanaged(*llvm.Value, Global.Index),
} else void,

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

globals: std.AutoArrayHashMapUnmanaged(String, Global),
next_unnamed_global: String,
next_replaced_global: String,
next_unique_global_id: std.AutoHashMapUnmanaged(String, u32),
aliases: std.ArrayListUnmanaged(Alias),
variables: std.ArrayListUnmanaged(Variable),
functions: std.ArrayListUnmanaged(Function),

constant_map: std.AutoArrayHashMapUnmanaged(void, void),
constant_items: std.MultiArrayList(Constant.Item),
constant_extra: std.ArrayListUnmanaged(u32),
constant_limbs: std.ArrayListUnmanaged(std.math.big.Limb),

pub const expected_args_len = 16;
pub const expected_attrs_len = 16;
pub const expected_fields_len = 32;
pub const expected_gep_indices_len = 8;
pub const expected_cases_len = 8;
pub const expected_incoming_len = 8;
pub const expected_intrinsic_name_len = 64;

pub const Options = struct {
    allocator: Allocator,
    use_lib_llvm: bool = false,
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

    pub fn slice(self: String, b: *const Builder) ?[:0]const u8 {
        const index = self.toIndex() orelse return null;
        const start = b.string_indices.items[index];
        const end = b.string_indices.items[index + 1];
        return b.string_bytes.items[start .. end - 1 :0];
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
        if (comptime std.mem.indexOfNone(u8, fmt_str, "@\"")) |_|
            @compileError("invalid format string: '" ++ fmt_str ++ "'");
        assert(data.string != .none);
        const sentinel_slice = data.string.slice(data.builder) orelse
            return writer.print("{d}", .{@intFromEnum(data.string)});
        try printEscapedString(sentinel_slice[0 .. sentinel_slice.len + comptime @intFromBool(
            std.mem.indexOfScalar(u8, fmt_str, '@') != null,
        )], if (comptime std.mem.indexOfScalar(u8, fmt_str, '"')) |_|
            .always_quote
        else
            .quote_unless_valid_identifier, writer);
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

    pub const err_int = Type.i16;
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

    pub const Simple = enum {
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
        const result = try self.isSizedVisited(&visited, builder);
        if (builder.useLibLlvm()) assert(result == self.toLlvm(builder).isSized().toBool());
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

    pub fn toLlvm(self: Type, builder: *const Builder) *llvm.Type {
        assert(builder.useLibLlvm());
        return builder.llvm.types.items[@intFromEnum(self)];
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
                    const field = @typeInfo(Attribute).Union.fields[@intFromEnum(kind)];
                    comptime assert(std.mem.eql(u8, @tagName(kind), field.name));
                    return @unionInit(Attribute, field.name, switch (field.type) {
                        void => {},
                        u32 => storage.value,
                        Alignment, String, Type, UwTable => @enumFromInt(storage.value),
                        AllocKind, AllocSize, FpClass, Memory, VScaleRange => @bitCast(storage.value),
                        else => @compileError("bad payload type: " ++ @typeName(field.type)),
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

        fn toLlvm(self: Index, builder: *const Builder) *llvm.Attribute {
            assert(builder.useLibLlvm());
            return builder.llvm.attributes.items[@intFromEnum(self)];
        }
    };

    pub const Kind = enum(u32) {
        // Parameter Attributes
        zeroext,
        signext,
        inreg,
        byval,
        byref,
        preallocated,
        inalloca,
        sret,
        elementtype,
        @"align",
        @"noalias",
        nocapture,
        nofree,
        nest,
        returned,
        nonnull,
        dereferenceable,
        dereferenceable_or_null,
        swiftself,
        swiftasync,
        swifterror,
        immarg,
        noundef,
        nofpclass,
        alignstack,
        allocalign,
        allocptr,
        readnone,
        readonly,
        writeonly,

        // Function Attributes
        //alignstack,
        allockind,
        allocsize,
        alwaysinline,
        builtin,
        cold,
        convergent,
        disable_sanitizer_information,
        fn_ret_thunk_extern,
        hot,
        inlinehint,
        jumptable,
        memory,
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
        //preallocated,
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
        uwtable,
        nocf_check,
        shadowcallstack,
        mustprogress,
        vscale_range,

        // Global Attributes
        no_sanitize_address,
        no_sanitize_hwaddress,
        //sanitize_memtag,
        sanitize_address_dyninit,

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

        fn toLlvm(self: Kind, builder: *const Builder) *c_uint {
            assert(builder.useLibLlvm());
            return &builder.llvm.attribute_kind_ids.?[@intFromEnum(self)];
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
            inline else => |value| .{ .kind = @as(Kind, self), .value = switch (@TypeOf(value)) {
                void => 0,
                u32 => value,
                Alignment, String, Type, UwTable => @intFromEnum(value),
                AllocKind, AllocSize, FpClass, Memory, VScaleRange => @bitCast(value),
                else => @compileError("bad payload type: " ++ @typeName(@TypeOf(value))),
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

pub const Linkage = enum {
    private,
    internal,
    weak,
    weak_odr,
    linkonce,
    linkonce_odr,
    available_externally,
    appending,
    common,
    extern_weak,
    external,

    pub fn format(
        self: Linkage,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .external) try writer.print(" {s}", .{@tagName(self)});
    }

    fn toLlvm(self: Linkage) llvm.Linkage {
        return switch (self) {
            .private => .Private,
            .internal => .Internal,
            .weak => .WeakAny,
            .weak_odr => .WeakODR,
            .linkonce => .LinkOnceAny,
            .linkonce_odr => .LinkOnceODR,
            .available_externally => .AvailableExternally,
            .appending => .Appending,
            .common => .Common,
            .extern_weak => .ExternalWeak,
            .external => .External,
        };
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

pub const Visibility = enum {
    default,
    hidden,
    protected,

    pub fn format(
        self: Visibility,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .default) try writer.print(" {s}", .{@tagName(self)});
    }

    fn toLlvm(self: Visibility) llvm.Visibility {
        return switch (self) {
            .default => .Default,
            .hidden => .Hidden,
            .protected => .Protected,
        };
    }
};

pub const DllStorageClass = enum {
    default,
    dllimport,
    dllexport,

    pub fn format(
        self: DllStorageClass,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .default) try writer.print(" {s}", .{@tagName(self)});
    }

    fn toLlvm(self: DllStorageClass) llvm.DLLStorageClass {
        return switch (self) {
            .default => .Default,
            .dllimport => .DLLImport,
            .dllexport => .DLLExport,
        };
    }
};

pub const ThreadLocal = enum {
    default,
    generaldynamic,
    localdynamic,
    initialexec,
    localexec,

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

    fn toLlvm(self: ThreadLocal) llvm.ThreadLocalMode {
        return switch (self) {
            .default => .NotThreadLocal,
            .generaldynamic => .GeneralDynamicTLSModel,
            .localdynamic => .LocalDynamicTLSModel,
            .initialexec => .InitialExecTLSModel,
            .localexec => .LocalExecTLSModel,
        };
    }
};

pub const Mutability = enum { global, constant };

pub const UnnamedAddr = enum {
    default,
    unnamed_addr,
    local_unnamed_addr,

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

    fn toLlvm(self: CallConv) llvm.CallConv {
        // These enum values appear in LLVM IR, and so are guaranteed to be stable.
        return @enumFromInt(@intFromEnum(self));
    }
};

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

        pub fn name(self: Index, builder: *const Builder) String {
            return builder.globals.keys()[@intFromEnum(self.unwrap(builder))];
        }

        pub fn typeOf(self: Index, builder: *const Builder) Type {
            return self.ptrConst(builder).type;
        }

        pub fn toConst(self: Index) Constant {
            return @enumFromInt(@intFromEnum(Constant.first_global) + @intFromEnum(self));
        }

        pub fn setLinkage(self: Index, linkage: Linkage, builder: *Builder) void {
            if (builder.useLibLlvm()) self.toLlvm(builder).setLinkage(linkage.toLlvm());
            self.ptr(builder).linkage = linkage;
            self.updateDsoLocal(builder);
        }

        pub fn setVisibility(self: Index, visibility: Visibility, builder: *Builder) void {
            if (builder.useLibLlvm()) self.toLlvm(builder).setVisibility(visibility.toLlvm());
            self.ptr(builder).visibility = visibility;
            self.updateDsoLocal(builder);
        }

        pub fn setDllStorageClass(self: Index, class: DllStorageClass, builder: *Builder) void {
            if (builder.useLibLlvm()) self.toLlvm(builder).setDLLStorageClass(class.toLlvm());
            self.ptr(builder).dll_storage_class = class;
        }

        pub fn setUnnamedAddr(self: Index, unnamed_addr: UnnamedAddr, builder: *Builder) void {
            if (builder.useLibLlvm()) self.toLlvm(builder).setUnnamedAddr(
                llvm.Bool.fromBool(unnamed_addr != .default),
            );
            self.ptr(builder).unnamed_addr = unnamed_addr;
        }

        pub fn toLlvm(self: Index, builder: *const Builder) *llvm.Value {
            assert(builder.useLibLlvm());
            return builder.llvm.globals.items[@intFromEnum(self.unwrap(builder))];
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

        pub fn rename(self: Index, new_name: String, builder: *Builder) Allocator.Error!void {
            try builder.ensureUnusedGlobalCapacity(new_name);
            self.renameAssumeCapacity(new_name, builder);
        }

        pub fn takeName(self: Index, other: Index, builder: *Builder) Allocator.Error!void {
            try builder.ensureUnusedGlobalCapacity(.empty);
            self.takeNameAssumeCapacity(other, builder);
        }

        pub fn replace(self: Index, other: Index, builder: *Builder) Allocator.Error!void {
            try builder.ensureUnusedGlobalCapacity(.empty);
            if (builder.useLibLlvm())
                try builder.llvm.replacements.ensureUnusedCapacity(builder.gpa, 1);
            self.replaceAssumeCapacity(other, builder);
        }

        pub fn delete(self: Index, builder: *Builder) void {
            if (builder.useLibLlvm()) self.toLlvm(builder).eraseGlobalValue();
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

        fn renameAssumeCapacity(self: Index, new_name: String, builder: *Builder) void {
            const old_name = self.name(builder);
            if (new_name == old_name) return;
            const index = @intFromEnum(self.unwrap(builder));
            if (builder.useLibLlvm())
                builder.llvm.globals.appendAssumeCapacity(builder.llvm.globals.items[index]);
            _ = builder.addGlobalAssumeCapacity(new_name, builder.globals.values()[index]);
            if (builder.useLibLlvm()) _ = builder.llvm.globals.pop();
            builder.globals.swapRemoveAt(index);
            self.updateName(builder);
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

        fn updateName(self: Index, builder: *const Builder) void {
            if (!builder.useLibLlvm()) return;
            const index = @intFromEnum(self.unwrap(builder));
            const name_slice = self.name(builder).slice(builder) orelse "";
            builder.llvm.globals.items[index].setValueName(name_slice.ptr, name_slice.len);
        }

        fn replaceAssumeCapacity(self: Index, other: Index, builder: *Builder) void {
            if (self.eql(other, builder)) return;
            builder.next_replaced_global = @enumFromInt(@intFromEnum(builder.next_replaced_global) - 1);
            self.renameAssumeCapacity(builder.next_replaced_global, builder);
            if (builder.useLibLlvm()) {
                const self_llvm = self.toLlvm(builder);
                self_llvm.replaceAllUsesWith(other.toLlvm(builder));
                self_llvm.removeGlobalValue();
                builder.llvm.replacements.putAssumeCapacityNoClobber(self_llvm, other);
            }
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

        pub fn name(self: Index, builder: *const Builder) String {
            return self.ptrConst(builder).global.name(builder);
        }

        pub fn rename(self: Index, new_name: String, builder: *Builder) Allocator.Error!void {
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
            if (builder.useLibLlvm()) self.toLlvm(builder).setAliasee(aliasee.toLlvm(builder));
            self.ptr(builder).aliasee = aliasee;
        }

        fn toLlvm(self: Index, builder: *const Builder) *llvm.Value {
            return self.ptrConst(builder).global.toLlvm(builder);
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

        pub fn name(self: Index, builder: *const Builder) String {
            return self.ptrConst(builder).global.name(builder);
        }

        pub fn rename(self: Index, new_name: String, builder: *Builder) Allocator.Error!void {
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
            if (builder.useLibLlvm()) self.toLlvm(builder).setThreadLocalMode(thread_local.toLlvm());
            self.ptr(builder).thread_local = thread_local;
        }

        pub fn setMutability(self: Index, mutability: Mutability, builder: *Builder) void {
            if (builder.useLibLlvm()) self.toLlvm(builder).setGlobalConstant(
                llvm.Bool.fromBool(mutability == .constant),
            );
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
                if (builder.useLibLlvm() and global.type != initializer_type) {
                    try builder.llvm.replacements.ensureUnusedCapacity(builder.gpa, 1);
                    // LLVM does not allow us to change the type of globals. So we must
                    // create a new global with the correct type, copy all its attributes,
                    // and then update all references to point to the new global,
                    // delete the original, and rename the new one to the old one's name.
                    // This is necessary because LLVM does not support const bitcasting
                    // a struct with padding bytes, which is needed to lower a const union value
                    // to LLVM, when a field other than the most-aligned is active. Instead,
                    // we must lower to an unnamed struct, and pointer cast at usage sites
                    // of the global. Such an unnamed struct is the cause of the global type
                    // mismatch, because we don't have the LLVM type until the *value* is created,
                    // whereas the global needs to be created based on the type alone, because
                    // lowering the value may reference the global as a pointer.
                    // Related: https://github.com/ziglang/zig/issues/13265
                    const old_global = &builder.llvm.globals.items[@intFromEnum(variable.global)];
                    const new_global = builder.llvm.module.?.addGlobalInAddressSpace(
                        initializer_type.toLlvm(builder),
                        "",
                        @intFromEnum(global.addr_space),
                    );
                    new_global.setLinkage(global.linkage.toLlvm());
                    new_global.setUnnamedAddr(llvm.Bool.fromBool(global.unnamed_addr != .default));
                    new_global.setAlignment(@intCast(variable.alignment.toByteUnits() orelse 0));
                    if (variable.section != .none)
                        new_global.setSection(variable.section.slice(builder).?);
                    old_global.*.replaceAllUsesWith(new_global);
                    builder.llvm.replacements.putAssumeCapacityNoClobber(old_global.*, variable.global);
                    new_global.takeName(old_global.*);
                    old_global.*.removeGlobalValue();
                    old_global.* = new_global;
                    self.ptr(builder).mutability = .global;
                }
                global.type = initializer_type;
            }
            if (builder.useLibLlvm()) self.toLlvm(builder).setInitializer(switch (initializer) {
                .no_init => null,
                else => initializer.toLlvm(builder),
            });
            self.ptr(builder).init = initializer;
        }

        pub fn setSection(self: Index, section: String, builder: *Builder) void {
            if (builder.useLibLlvm()) self.toLlvm(builder).setSection(section.slice(builder).?);
            self.ptr(builder).section = section;
        }

        pub fn setAlignment(self: Index, alignment: Alignment, builder: *Builder) void {
            if (builder.useLibLlvm())
                self.toLlvm(builder).setAlignment(@intCast(alignment.toByteUnits() orelse 0));
            self.ptr(builder).alignment = alignment;
        }

        pub fn toLlvm(self: Index, builder: *const Builder) *llvm.Value {
            return self.ptrConst(builder).global.toLlvm(builder);
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
    metadata: ?[*]const Metadata = null,
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

        pub fn name(self: Index, builder: *const Builder) String {
            return self.ptrConst(builder).global.name(builder);
        }

        pub fn rename(self: Index, new_name: String, builder: *Builder) Allocator.Error!void {
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
            if (builder.useLibLlvm()) self.toLlvm(builder).setFunctionCallConv(call_conv.toLlvm());
            self.ptr(builder).call_conv = call_conv;
        }

        pub fn setAttributes(
            self: Index,
            new_function_attributes: FunctionAttributes,
            builder: *Builder,
        ) void {
            if (builder.useLibLlvm()) {
                const llvm_function = self.toLlvm(builder);
                const old_function_attributes = self.ptrConst(builder).attributes;
                for (0..@max(
                    old_function_attributes.slice(builder).len,
                    new_function_attributes.slice(builder).len,
                )) |function_attribute_index| {
                    const llvm_attribute_index =
                        @as(llvm.AttributeIndex, @intCast(function_attribute_index)) -% 1;
                    const old_attributes_slice =
                        old_function_attributes.get(function_attribute_index, builder).slice(builder);
                    const new_attributes_slice =
                        new_function_attributes.get(function_attribute_index, builder).slice(builder);
                    var old_attribute_index: usize = 0;
                    var new_attribute_index: usize = 0;
                    while (true) {
                        const old_attribute_kind = if (old_attribute_index < old_attributes_slice.len)
                            old_attributes_slice[old_attribute_index].getKind(builder)
                        else
                            .none;
                        const new_attribute_kind = if (new_attribute_index < new_attributes_slice.len)
                            new_attributes_slice[new_attribute_index].getKind(builder)
                        else
                            .none;
                        switch (std.math.order(
                            @intFromEnum(old_attribute_kind),
                            @intFromEnum(new_attribute_kind),
                        )) {
                            .lt => {
                                // Removed
                                if (old_attribute_kind.toString()) |attribute_name| {
                                    const attribute_name_slice = attribute_name.slice(builder).?;
                                    llvm_function.removeStringAttributeAtIndex(
                                        llvm_attribute_index,
                                        attribute_name_slice.ptr,
                                        @intCast(attribute_name_slice.len),
                                    );
                                } else {
                                    const llvm_kind_id = old_attribute_kind.toLlvm(builder).*;
                                    assert(llvm_kind_id != 0);
                                    llvm_function.removeEnumAttributeAtIndex(
                                        llvm_attribute_index,
                                        llvm_kind_id,
                                    );
                                }
                                old_attribute_index += 1;
                                continue;
                            },
                            .eq => {
                                // Iteration finished
                                if (old_attribute_kind == .none) break;
                                // No change
                                if (old_attributes_slice[old_attribute_index] ==
                                    new_attributes_slice[new_attribute_index])
                                {
                                    old_attribute_index += 1;
                                    new_attribute_index += 1;
                                    continue;
                                }
                                old_attribute_index += 1;
                            },
                            .gt => {},
                        }
                        // New or changed
                        llvm_function.addAttributeAtIndex(
                            llvm_attribute_index,
                            new_attributes_slice[new_attribute_index].toLlvm(builder),
                        );
                        new_attribute_index += 1;
                    }
                }
            }
            self.ptr(builder).attributes = new_function_attributes;
        }

        pub fn setSection(self: Index, section: String, builder: *Builder) void {
            if (builder.useLibLlvm()) self.toLlvm(builder).setSection(section.slice(builder).?);
            self.ptr(builder).section = section;
        }

        pub fn setAlignment(self: Index, alignment: Alignment, builder: *Builder) void {
            if (builder.useLibLlvm())
                self.toLlvm(builder).setAlignment(@intCast(alignment.toByteUnits() orelse 0));
            self.ptr(builder).alignment = alignment;
        }

        pub fn toLlvm(self: Index, builder: *const Builder) *llvm.Value {
            return self.ptrConst(builder).global.toLlvm(builder);
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
        };

        pub const Index = enum(u32) {
            none = std.math.maxInt(u31),
            _,

            pub fn name(self: Instruction.Index, function: *const Function) String {
                return function.names[@intFromEnum(self)];
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
                    }) catch unreachable,
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
                    }) catch unreachable,
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

            fn toLlvm(self: Instruction.Index, wip: *const WipFunction) *llvm.Value {
                assert(wip.builder.useLibLlvm());
                const llvm_value = wip.llvm.instructions.items[@intFromEnum(self)];
                const global = wip.builder.llvm.replacements.get(llvm_value) orelse return llvm_value;
                return global.toLlvm(wip.builder);
            }

            fn llvmName(self: Instruction.Index, wip: *const WipFunction) [:0]const u8 {
                return if (wip.builder.strip)
                    ""
                else
                    wip.names.items[@intFromEnum(self)].slice(wip.builder).?;
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
                xchg,
                add,
                sub,
                @"and",
                nand,
                @"or",
                xor,
                max,
                min,
                umax,
                umin,
                fadd,
                fsub,
                fmax,
                fmin,
                none = std.math.maxInt(u5),

                fn toLlvm(self: Operation) llvm.AtomicRMWBinOp {
                    return switch (self) {
                        .xchg => .Xchg,
                        .add => .Add,
                        .sub => .Sub,
                        .@"and" => .And,
                        .nand => .Nand,
                        .@"or" => .Or,
                        .xor => .Xor,
                        .max => .Max,
                        .min => .Min,
                        .umax => .UMax,
                        .umin => .UMin,
                        .fadd => .FAdd,
                        .fsub => .FSub,
                        .fmax => .FMax,
                        .fmin => .FMin,
                        .none => unreachable,
                    };
                }
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
        if (self.metadata) |metadata| gpa.free(metadata[0..self.instructions.len]);
        gpa.free(self.names[0..self.instructions.len]);
        self.instructions.deinit(gpa);
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
                else => @compileError("bad field type: " ++ @typeName(field.type)),
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

pub const WipFunction = struct {
    builder: *Builder,
    function: Function.Index,
    llvm: if (build_options.have_llvm) struct {
        builder: *llvm.Builder,
        blocks: std.ArrayListUnmanaged(*llvm.BasicBlock),
        instructions: std.ArrayListUnmanaged(*llvm.Value),
    } else void,
    cursor: Cursor,
    blocks: std.ArrayListUnmanaged(Block),
    instructions: std.MultiArrayList(Instruction),
    names: std.ArrayListUnmanaged(String),
    metadata: std.ArrayListUnmanaged(Metadata),
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

            pub fn toLlvm(self: Index, wip: *const WipFunction) *llvm.BasicBlock {
                assert(wip.builder.useLibLlvm());
                return wip.llvm.blocks.items[@intFromEnum(self)];
            }
        };
    };

    pub const Instruction = Function.Instruction;

    pub fn init(builder: *Builder, function: Function.Index) Allocator.Error!WipFunction {
        if (builder.useLibLlvm()) {
            const llvm_function = function.toLlvm(builder);
            while (llvm_function.getFirstBasicBlock()) |bb| bb.deleteBasicBlock();
        }

        var self = WipFunction{
            .builder = builder,
            .function = function,
            .llvm = if (builder.useLibLlvm()) .{
                .builder = builder.llvm.context.createBuilder(),
                .blocks = .{},
                .instructions = .{},
            } else undefined,
            .cursor = undefined,
            .blocks = .{},
            .instructions = .{},
            .names = .{},
            .metadata = .{},
            .extra = .{},
        };
        errdefer self.deinit();

        const params_len = function.typeOf(self.builder).functionParameters(self.builder).len;
        try self.ensureUnusedExtraCapacity(params_len, NoExtra, 0);
        try self.instructions.ensureUnusedCapacity(self.builder.gpa, params_len);
        if (!self.builder.strip) try self.names.ensureUnusedCapacity(self.builder.gpa, params_len);
        if (self.builder.useLibLlvm())
            try self.llvm.instructions.ensureUnusedCapacity(self.builder.gpa, params_len);
        for (0..params_len) |param_index| {
            self.instructions.appendAssumeCapacity(.{ .tag = .arg, .data = @intCast(param_index) });
            if (!self.builder.strip) self.names.appendAssumeCapacity(.empty); // TODO: param names
            if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(
                function.toLlvm(self.builder).getParam(@intCast(param_index)),
            );
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
        if (self.builder.useLibLlvm()) try self.llvm.blocks.ensureUnusedCapacity(self.builder.gpa, 1);

        const index: Block.Index = @enumFromInt(self.blocks.items.len);
        const final_name = if (self.builder.strip) .empty else try self.builder.string(name);
        self.blocks.appendAssumeCapacity(.{
            .name = final_name,
            .incoming = incoming,
            .instructions = .{},
        });
        if (self.builder.useLibLlvm()) self.llvm.blocks.appendAssumeCapacity(
            self.builder.llvm.context.appendBasicBlock(
                self.function.toLlvm(self.builder),
                final_name.slice(self.builder).?,
            ),
        );
        return index;
    }

    pub fn ret(self: *WipFunction, val: Value) Allocator.Error!Instruction.Index {
        assert(val.typeOfWip(self) == self.function.typeOf(self.builder).functionReturn(self.builder));
        try self.ensureUnusedExtraCapacity(1, NoExtra, 0);
        const instruction = try self.addInst(null, .{ .tag = .ret, .data = @intFromEnum(val) });
        if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(
            self.llvm.builder.buildRet(val.toLlvm(self)),
        );
        return instruction;
    }

    pub fn retVoid(self: *WipFunction) Allocator.Error!Instruction.Index {
        try self.ensureUnusedExtraCapacity(1, NoExtra, 0);
        const instruction = try self.addInst(null, .{ .tag = .@"ret void", .data = undefined });
        if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(
            self.llvm.builder.buildRetVoid(),
        );
        return instruction;
    }

    pub fn br(self: *WipFunction, dest: Block.Index) Allocator.Error!Instruction.Index {
        try self.ensureUnusedExtraCapacity(1, NoExtra, 0);
        const instruction = try self.addInst(null, .{ .tag = .br, .data = @intFromEnum(dest) });
        dest.ptr(self).branches += 1;
        if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(
            self.llvm.builder.buildBr(dest.toLlvm(self)),
        );
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
        if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(
            self.llvm.builder.buildCondBr(cond.toLlvm(self), then.toLlvm(self), @"else".toLlvm(self)),
        );
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
            if (wip.builder.useLibLlvm())
                self.instruction.toLlvm(wip).addCase(val.toLlvm(wip.builder), dest.toLlvm(wip));
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
        if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(
            self.llvm.builder.buildSwitch(val.toLlvm(self), default.toLlvm(self), @intCast(cases_len)),
        );
        return .{ .index = 0, .instruction = instruction };
    }

    pub fn @"unreachable"(self: *WipFunction) Allocator.Error!Instruction.Index {
        try self.ensureUnusedExtraCapacity(1, NoExtra, 0);
        const instruction = try self.addInst(null, .{ .tag = .@"unreachable", .data = undefined });
        if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(
            self.llvm.builder.buildUnreachable(),
        );
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
        if (self.builder.useLibLlvm()) {
            switch (tag) {
                .fneg => self.llvm.builder.setFastMath(false),
                .@"fneg fast" => self.llvm.builder.setFastMath(true),
                else => unreachable,
            }
            self.llvm.instructions.appendAssumeCapacity(switch (tag) {
                .fneg, .@"fneg fast" => &llvm.Builder.buildFNeg,
                else => unreachable,
            }(self.llvm.builder, val.toLlvm(self), instruction.llvmName(self)));
        }
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
        if (self.builder.useLibLlvm()) {
            switch (tag) {
                .fadd,
                .fdiv,
                .fmul,
                .frem,
                .fsub,
                => self.llvm.builder.setFastMath(false),
                .@"fadd fast",
                .@"fdiv fast",
                .@"fmul fast",
                .@"frem fast",
                .@"fsub fast",
                => self.llvm.builder.setFastMath(true),
                else => {},
            }
            self.llvm.instructions.appendAssumeCapacity(switch (tag) {
                .add => &llvm.Builder.buildAdd,
                .@"add nsw" => &llvm.Builder.buildNSWAdd,
                .@"add nuw" => &llvm.Builder.buildNUWAdd,
                .@"and" => &llvm.Builder.buildAnd,
                .ashr => &llvm.Builder.buildAShr,
                .@"ashr exact" => &llvm.Builder.buildAShrExact,
                .fadd, .@"fadd fast" => &llvm.Builder.buildFAdd,
                .fdiv, .@"fdiv fast" => &llvm.Builder.buildFDiv,
                .fmul, .@"fmul fast" => &llvm.Builder.buildFMul,
                .frem, .@"frem fast" => &llvm.Builder.buildFRem,
                .fsub, .@"fsub fast" => &llvm.Builder.buildFSub,
                .lshr => &llvm.Builder.buildLShr,
                .@"lshr exact" => &llvm.Builder.buildLShrExact,
                .mul => &llvm.Builder.buildMul,
                .@"mul nsw" => &llvm.Builder.buildNSWMul,
                .@"mul nuw" => &llvm.Builder.buildNUWMul,
                .@"or" => &llvm.Builder.buildOr,
                .sdiv => &llvm.Builder.buildSDiv,
                .@"sdiv exact" => &llvm.Builder.buildExactSDiv,
                .shl => &llvm.Builder.buildShl,
                .@"shl nsw" => &llvm.Builder.buildNSWShl,
                .@"shl nuw" => &llvm.Builder.buildNUWShl,
                .srem => &llvm.Builder.buildSRem,
                .sub => &llvm.Builder.buildSub,
                .@"sub nsw" => &llvm.Builder.buildNSWSub,
                .@"sub nuw" => &llvm.Builder.buildNUWSub,
                .udiv => &llvm.Builder.buildUDiv,
                .@"udiv exact" => &llvm.Builder.buildExactUDiv,
                .urem => &llvm.Builder.buildURem,
                .xor => &llvm.Builder.buildXor,
                else => unreachable,
            }(self.llvm.builder, lhs.toLlvm(self), rhs.toLlvm(self), instruction.llvmName(self)));
        }
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
        if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(
            self.llvm.builder.buildExtractElement(
                val.toLlvm(self),
                index.toLlvm(self),
                instruction.llvmName(self),
            ),
        );
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
        if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(
            self.llvm.builder.buildInsertElement(
                val.toLlvm(self),
                elem.toLlvm(self),
                index.toLlvm(self),
                instruction.llvmName(self),
            ),
        );
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
        if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(
            self.llvm.builder.buildShuffleVector(
                lhs.toLlvm(self),
                rhs.toLlvm(self),
                mask.toLlvm(self),
                instruction.llvmName(self),
            ),
        );
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
        const zero = try self.builder.intConst(.i32, 0);
        const poison = try self.builder.poisonValue(scalar_ty);
        const mask = try self.builder.splatValue(mask_ty, zero);
        const scalar = try self.insertElement(poison, elem, zero.toValue(), name);
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
        if (self.builder.useLibLlvm()) {
            const llvm_name = instruction.llvmName(self);
            var cur = val.toLlvm(self);
            for (indices) |index|
                cur = self.llvm.builder.buildExtractValue(cur, @intCast(index), llvm_name);
            self.llvm.instructions.appendAssumeCapacity(cur);
        }
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
        if (self.builder.useLibLlvm()) {
            const ExpectedContents = [expected_gep_indices_len]*llvm.Value;
            var stack align(@alignOf(ExpectedContents)) =
                std.heap.stackFallback(@sizeOf(ExpectedContents), self.builder.gpa);
            const allocator = stack.get();

            const llvm_name = instruction.llvmName(self);
            const llvm_vals = try allocator.alloc(*llvm.Value, indices.len);
            defer allocator.free(llvm_vals);
            llvm_vals[0] = val.toLlvm(self);
            for (llvm_vals[1..], llvm_vals[0 .. llvm_vals.len - 1], indices[0 .. indices.len - 1]) |
                *cur_val,
                prev_val,
                index,
            | cur_val.* = self.llvm.builder.buildExtractValue(prev_val, @intCast(index), llvm_name);

            var depth: usize = llvm_vals.len;
            var cur = elem.toLlvm(self);
            while (depth > 0) {
                depth -= 1;
                cur = self.llvm.builder.buildInsertValue(
                    llvm_vals[depth],
                    cur,
                    @intCast(indices[depth]),
                    llvm_name,
                );
            }
            self.llvm.instructions.appendAssumeCapacity(cur);
        }
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
                .len = len,
                .info = .{ .alignment = alignment, .addr_space = addr_space },
            }),
        });
        if (self.builder.useLibLlvm()) {
            const llvm_instruction = self.llvm.builder.buildAllocaInAddressSpace(
                ty.toLlvm(self.builder),
                @intFromEnum(addr_space),
                instruction.llvmName(self),
            );
            if (alignment.toByteUnits()) |bytes| llvm_instruction.setAlignment(@intCast(bytes));
            self.llvm.instructions.appendAssumeCapacity(llvm_instruction);
        }
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
        if (self.builder.useLibLlvm()) {
            const llvm_instruction = self.llvm.builder.buildLoad(
                ty.toLlvm(self.builder),
                ptr.toLlvm(self),
                instruction.llvmName(self),
            );
            if (access_kind == .@"volatile") llvm_instruction.setVolatile(.True);
            if (ordering != .none) llvm_instruction.setOrdering(ordering.toLlvm());
            if (alignment.toByteUnits()) |bytes| llvm_instruction.setAlignment(@intCast(bytes));
            self.llvm.instructions.appendAssumeCapacity(llvm_instruction);
        }
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
        if (self.builder.useLibLlvm()) {
            const llvm_instruction = self.llvm.builder.buildStore(val.toLlvm(self), ptr.toLlvm(self));
            if (access_kind == .@"volatile") llvm_instruction.setVolatile(.True);
            if (ordering != .none) llvm_instruction.setOrdering(ordering.toLlvm());
            if (alignment.toByteUnits()) |bytes| llvm_instruction.setAlignment(@intCast(bytes));
            self.llvm.instructions.appendAssumeCapacity(llvm_instruction);
        }
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
        if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(
            self.llvm.builder.buildFence(
                ordering.toLlvm(),
                llvm.Bool.fromBool(sync_scope == .singlethread),
                "",
            ),
        );
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
        if (self.builder.useLibLlvm()) {
            const llvm_instruction = self.llvm.builder.buildAtomicCmpXchg(
                ptr.toLlvm(self),
                cmp.toLlvm(self),
                new.toLlvm(self),
                success_ordering.toLlvm(),
                failure_ordering.toLlvm(),
                llvm.Bool.fromBool(sync_scope == .singlethread),
            );
            if (kind == .weak) llvm_instruction.setWeak(.True);
            if (access_kind == .@"volatile") llvm_instruction.setVolatile(.True);
            if (alignment.toByteUnits()) |bytes| llvm_instruction.setAlignment(@intCast(bytes));
            const llvm_name = instruction.llvmName(self);
            if (llvm_name.len > 0) llvm_instruction.setValueName(
                llvm_name.ptr,
                @intCast(llvm_name.len),
            );
            self.llvm.instructions.appendAssumeCapacity(llvm_instruction);
        }
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
        if (self.builder.useLibLlvm()) {
            const llvm_instruction = self.llvm.builder.buildAtomicRmw(
                operation.toLlvm(),
                ptr.toLlvm(self),
                val.toLlvm(self),
                ordering.toLlvm(),
                llvm.Bool.fromBool(sync_scope == .singlethread),
            );
            if (access_kind == .@"volatile") llvm_instruction.setVolatile(.True);
            if (alignment.toByteUnits()) |bytes| llvm_instruction.setAlignment(@intCast(bytes));
            const llvm_name = instruction.llvmName(self);
            if (llvm_name.len > 0) llvm_instruction.setValueName(
                llvm_name.ptr,
                @intCast(llvm_name.len),
            );
            self.llvm.instructions.appendAssumeCapacity(llvm_instruction);
        }
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
        if (self.builder.useLibLlvm()) {
            const ExpectedContents = [expected_gep_indices_len]*llvm.Value;
            var stack align(@alignOf(ExpectedContents)) =
                std.heap.stackFallback(@sizeOf(ExpectedContents), self.builder.gpa);
            const allocator = stack.get();

            const llvm_indices = try allocator.alloc(*llvm.Value, indices.len);
            defer allocator.free(llvm_indices);
            for (llvm_indices, indices) |*llvm_index, index| llvm_index.* = index.toLlvm(self);

            self.llvm.instructions.appendAssumeCapacity(switch (kind) {
                .normal => &llvm.Builder.buildGEP,
                .inbounds => &llvm.Builder.buildInBoundsGEP,
            }(
                self.llvm.builder,
                ty.toLlvm(self.builder),
                base.toLlvm(self),
                llvm_indices.ptr,
                @intCast(llvm_indices.len),
                instruction.llvmName(self),
            ));
        }
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
        return self.gep(.inbounds, ty, base, &.{
            try self.builder.intValue(.i32, 0), try self.builder.intValue(.i32, index),
        }, name);
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
        return self.cast(self.builder.convTag(Instruction.Tag, signedness, val_ty, ty), val, ty, name);
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
        if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(switch (tag) {
            .addrspacecast => &llvm.Builder.buildAddrSpaceCast,
            .bitcast => &llvm.Builder.buildBitCast,
            .fpext => &llvm.Builder.buildFPExt,
            .fptosi => &llvm.Builder.buildFPToSI,
            .fptoui => &llvm.Builder.buildFPToUI,
            .fptrunc => &llvm.Builder.buildFPTrunc,
            .inttoptr => &llvm.Builder.buildIntToPtr,
            .ptrtoint => &llvm.Builder.buildPtrToInt,
            .sext => &llvm.Builder.buildSExt,
            .sitofp => &llvm.Builder.buildSIToFP,
            .trunc => &llvm.Builder.buildTrunc,
            .uitofp => &llvm.Builder.buildUIToFP,
            .zext => &llvm.Builder.buildZExt,
            else => unreachable,
        }(self.llvm.builder, val.toLlvm(self), ty.toLlvm(self.builder), instruction.llvmName(self)));
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
        }, @intFromEnum(cond), lhs, rhs, name);
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
        }, @intFromEnum(cond), lhs, rhs, name);
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
        ) (if (build_options.have_llvm) Allocator.Error else error{})!void {
            const incoming_len = self.block.ptrConst(wip).incoming;
            assert(vals.len == incoming_len and blocks.len == incoming_len);
            const instruction = wip.instructions.get(@intFromEnum(self.instruction));
            var extra = wip.extraDataTrail(Instruction.Phi, instruction.data);
            for (vals) |val| assert(val.typeOfWip(wip) == extra.data.type);
            @memcpy(extra.trail.nextMut(incoming_len, Value, wip), vals);
            @memcpy(extra.trail.nextMut(incoming_len, Block.Index, wip), blocks);
            if (wip.builder.useLibLlvm()) {
                const ExpectedContents = extern struct {
                    values: [expected_incoming_len]*llvm.Value,
                    blocks: [expected_incoming_len]*llvm.BasicBlock,
                };
                var stack align(@alignOf(ExpectedContents)) =
                    std.heap.stackFallback(@sizeOf(ExpectedContents), wip.builder.gpa);
                const allocator = stack.get();

                const llvm_vals = try allocator.alloc(*llvm.Value, incoming_len);
                defer allocator.free(llvm_vals);
                const llvm_blocks = try allocator.alloc(*llvm.BasicBlock, incoming_len);
                defer allocator.free(llvm_blocks);

                for (llvm_vals, vals) |*llvm_val, incoming_val| llvm_val.* = incoming_val.toLlvm(wip);
                for (llvm_blocks, blocks) |*llvm_block, incoming_block|
                    llvm_block.* = incoming_block.toLlvm(wip);
                self.instruction.toLlvm(wip)
                    .addIncoming(llvm_vals.ptr, llvm_blocks.ptr, @intCast(incoming_len));
            }
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
        if (self.builder.useLibLlvm()) {
            const ExpectedContents = [expected_args_len]*llvm.Value;
            var stack align(@alignOf(ExpectedContents)) =
                std.heap.stackFallback(@sizeOf(ExpectedContents), self.builder.gpa);
            const allocator = stack.get();

            const llvm_args = try allocator.alloc(*llvm.Value, args.len);
            defer allocator.free(llvm_args);
            for (llvm_args, args) |*llvm_arg, arg_val| llvm_arg.* = arg_val.toLlvm(self);

            switch (kind) {
                .normal,
                .musttail,
                .notail,
                .tail,
                => self.llvm.builder.setFastMath(false),
                .fast,
                .musttail_fast,
                .notail_fast,
                .tail_fast,
                => self.llvm.builder.setFastMath(true),
            }
            const llvm_instruction = self.llvm.builder.buildCall(
                ty.toLlvm(self.builder),
                callee.toLlvm(self),
                llvm_args.ptr,
                @intCast(llvm_args.len),
                switch (ret_ty) {
                    .void => "",
                    else => instruction.llvmName(self),
                },
            );
            llvm_instruction.setInstructionCallConv(call_conv.toLlvm());
            llvm_instruction.setTailCallKind(switch (kind) {
                .normal, .fast => .None,
                .musttail, .musttail_fast => .MustTail,
                .notail, .notail_fast => .NoTail,
                .tail, .tail_fast => .Tail,
            });
            for (0.., function_attributes.slice(self.builder)) |index, attributes| {
                for (attributes.slice(self.builder)) |attribute| llvm_instruction.addCallSiteAttribute(
                    @as(llvm.AttributeIndex, @intCast(index)) -% 1,
                    attribute.toLlvm(self.builder),
                );
            }
            self.llvm.instructions.appendAssumeCapacity(llvm_instruction);
        }
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
        if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(
            self.llvm.builder.buildVAArg(
                list.toLlvm(self),
                ty.toLlvm(self.builder),
                instruction.llvmName(self),
            ),
        );
        return instruction.toValue();
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
                };
            }
        } = .{ .items = try gpa.alloc(Instruction.Index, self.instructions.len) };
        defer gpa.free(instructions.items);

        const names = try gpa.alloc(String, final_instructions_len);
        errdefer gpa.free(names);

        const metadata =
            if (self.builder.strip) null else try gpa.alloc(Metadata, final_instructions_len);
        errdefer if (metadata) |new_metadata| gpa.free(new_metadata);

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
                        else => @compileError("bad field type: " ++ @typeName(field.type)),
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
        if (function.metadata) |old_metadata| gpa.free(old_metadata[0..function.instructions.len]);
        function.metadata = null;
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

            fn map(wip_name: *@This(), old_name: String) String {
                if (old_name != .empty) return old_name;

                const new_name = wip_name.next_name;
                wip_name.next_name = @enumFromInt(@intFromEnum(new_name) + 1);
                return new_name;
            }
        } = .{};
        for (0..params_len) |param_index| {
            const old_argument_index: Instruction.Index = @enumFromInt(param_index);
            const new_argument_index: Instruction.Index = @enumFromInt(function.instructions.len);
            const argument = self.instructions.get(@intFromEnum(old_argument_index));
            assert(argument.tag == .arg);
            assert(argument.data == param_index);
            function.instructions.appendAssumeCapacity(argument);
            names[@intFromEnum(new_argument_index)] = wip_name.map(
                if (self.builder.strip) .empty else self.names.items[@intFromEnum(old_argument_index)],
            );
        }
        for (self.blocks.items) |current_block| {
            const new_block_index: Instruction.Index = @enumFromInt(function.instructions.len);
            function.instructions.appendAssumeCapacity(.{
                .tag = .block,
                .data = current_block.incoming,
            });
            names[@intFromEnum(new_block_index)] = wip_name.map(current_block.name);
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
                names[@intFromEnum(new_instruction_index)] = wip_name.map(if (self.builder.strip)
                    if (old_instruction_index.hasResultWip(self)) .empty else .none
                else
                    self.names.items[@intFromEnum(old_instruction_index)]);
            }
        }

        assert(function.instructions.len == final_instructions_len);
        function.extra = wip_extra.finish();
        function.blocks = blocks;
        function.names = names.ptr;
        function.metadata = if (metadata) |new_metadata| new_metadata.ptr else null;
    }

    pub fn deinit(self: *WipFunction) void {
        self.extra.deinit(self.builder.gpa);
        self.instructions.deinit(self.builder.gpa);
        for (self.blocks.items) |*b| b.instructions.deinit(self.builder.gpa);
        self.blocks.deinit(self.builder.gpa);
        if (self.builder.useLibLlvm()) self.llvm.builder.dispose();
        self.* = undefined;
    }

    fn cmpTag(
        self: *WipFunction,
        tag: Instruction.Tag,
        cond: u32,
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
        if (self.builder.useLibLlvm()) {
            switch (tag) {
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
                => self.llvm.builder.setFastMath(false),
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
                => self.llvm.builder.setFastMath(true),
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
                => {},
                else => unreachable,
            }
            self.llvm.instructions.appendAssumeCapacity(switch (tag) {
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
                => self.llvm.builder.buildFCmp(
                    @enumFromInt(cond),
                    lhs.toLlvm(self),
                    rhs.toLlvm(self),
                    instruction.llvmName(self),
                ),
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
                => self.llvm.builder.buildICmp(
                    @enumFromInt(cond),
                    lhs.toLlvm(self),
                    rhs.toLlvm(self),
                    instruction.llvmName(self),
                ),
                else => unreachable,
            });
        }
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
        if (self.builder.useLibLlvm()) {
            switch (tag) {
                .phi => self.llvm.builder.setFastMath(false),
                .@"phi fast" => self.llvm.builder.setFastMath(true),
                else => unreachable,
            }
            self.llvm.instructions.appendAssumeCapacity(
                self.llvm.builder.buildPhi(ty.toLlvm(self.builder), instruction.llvmName(self)),
            );
        }
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
        if (self.builder.useLibLlvm()) {
            switch (tag) {
                .select => self.llvm.builder.setFastMath(false),
                .@"select fast" => self.llvm.builder.setFastMath(true),
                else => unreachable,
            }
            self.llvm.instructions.appendAssumeCapacity(self.llvm.builder.buildSelect(
                cond.toLlvm(self),
                lhs.toLlvm(self),
                rhs.toLlvm(self),
                instruction.llvmName(self),
            ));
        }
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
        if (!self.builder.strip) try self.names.ensureUnusedCapacity(self.builder.gpa, 1);
        try block_instructions.ensureUnusedCapacity(self.builder.gpa, 1);
        if (self.builder.useLibLlvm())
            try self.llvm.instructions.ensureUnusedCapacity(self.builder.gpa, 1);
        const final_name = if (name) |n|
            if (self.builder.strip) .empty else try self.builder.string(n)
        else
            .none;

        if (self.builder.useLibLlvm()) self.llvm.builder.positionBuilder(
            self.cursor.block.toLlvm(self),
            for (block_instructions.items[self.cursor.instruction..]) |instruction_index| {
                const llvm_instruction =
                    self.llvm.instructions.items[@intFromEnum(instruction_index)];
                // TODO: remove when constant propagation is implemented
                if (!llvm_instruction.isConstant().toBool()) break llvm_instruction;
            } else null,
        );

        const index: Instruction.Index = @enumFromInt(self.instructions.len);
        self.instructions.appendAssumeCapacity(instruction);
        if (!self.builder.strip) self.names.appendAssumeCapacity(final_name);
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
                else => @compileError("bad field type: " ++ @typeName(field.type)),
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
                else => @compileError("bad field type: " ++ @typeName(field.type)),
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

    fn toLlvm(self: FloatCondition) llvm.RealPredicate {
        return switch (self) {
            .oeq => .OEQ,
            .ogt => .OGT,
            .oge => .OGE,
            .olt => .OLT,
            .ole => .OLE,
            .one => .ONE,
            .ord => .ORD,
            .uno => .UNO,
            .ueq => .UEQ,
            .ugt => .UGT,
            .uge => .UGE,
            .ult => .ULT,
            .uno => .UNE,
        };
    }
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

    fn toLlvm(self: IntegerCondition) llvm.IntPredicate {
        return switch (self) {
            .eq => .EQ,
            .ne => .NE,
            .ugt => .UGT,
            .uge => .UGE,
            .ult => .ULT,
            .sgt => .SGT,
            .sge => .SGE,
            .slt => .SLT,
            .sle => .SLE,
        };
    }
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
    acquire = 4,
    release = 5,
    acq_rel = 6,
    seq_cst = 7,

    pub fn format(
        self: AtomicOrdering,
        comptime prefix: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .none) try writer.print("{s}{s}", .{ prefix, @tagName(self) });
    }

    fn toLlvm(self: AtomicOrdering) llvm.AtomicOrdering {
        return switch (self) {
            .none => .NotAtomic,
            .unordered => .Unordered,
            .monotonic => .Monotonic,
            .acquire => .Acquire,
            .release => .Release,
            .acq_rel => .AcquireRelease,
            .seq_cst => .SequentiallyConsistent,
        };
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

pub const FastMath = packed struct(u32) {
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
        .realloc = true,
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
    none,
    no_init = 1 << 31,
    _,

    const first_global: Constant = @enumFromInt(1 << 30);

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
        string_null,
        vector,
        splat,
        zeroinitializer,
        undef,
        poison,
        blockaddress,
        dso_local_equivalent,
        no_cfi,
        trunc,
        zext,
        sext,
        fptrunc,
        fpext,
        fptoui,
        fptosi,
        uitofp,
        sitofp,
        ptrtoint,
        inttoptr,
        bitcast,
        addrspacecast,
        getelementptr,
        @"getelementptr inbounds",
        icmp,
        fcmp,
        extractelement,
        insertelement,
        shufflevector,
        add,
        @"add nsw",
        @"add nuw",
        sub,
        @"sub nsw",
        @"sub nuw",
        mul,
        @"mul nsw",
        @"mul nuw",
        shl,
        lshr,
        ashr,
        @"and",
        @"or",
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

    pub const Compare = extern struct {
        cond: u32,
        lhs: Constant,
        rhs: Constant,
    };

    pub const ExtractElement = extern struct {
        val: Constant,
        index: Constant,
    };

    pub const InsertElement = extern struct {
        val: Constant,
        elem: Constant,
        index: Constant,
    };

    pub const ShuffleVector = extern struct {
        lhs: Constant,
        rhs: Constant,
        mask: Constant,
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
                    .string,
                    .string_null,
                    => builder.arrayTypeAssumeCapacity(
                        @as(String, @enumFromInt(item.data)).slice(builder).?.len +
                            @intFromBool(item.tag == .string_null),
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
                    .zext,
                    .sext,
                    .fptrunc,
                    .fpext,
                    .fptoui,
                    .fptosi,
                    .uitofp,
                    .sitofp,
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
                    .icmp,
                    .fcmp,
                    => builder.constantExtraData(Compare, item.data).lhs.typeOf(builder)
                        .changeScalarAssumeCapacity(.i1, builder),
                    .extractelement => builder.constantExtraData(ExtractElement, item.data)
                        .val.typeOf(builder).childType(builder),
                    .insertelement => builder.constantExtraData(InsertElement, item.data)
                        .val.typeOf(builder),
                    .shufflevector => {
                        const extra = builder.constantExtraData(ShuffleVector, item.data);
                        return extra.lhs.typeOf(builder).changeLengthAssumeCapacity(
                            extra.mask.typeOf(builder).vectorLen(builder),
                            builder,
                        );
                    },
                    .add,
                    .@"add nsw",
                    .@"add nuw",
                    .sub,
                    .@"sub nsw",
                    .@"sub nuw",
                    .mul,
                    .@"mul nsw",
                    .@"mul nuw",
                    .shl,
                    .lshr,
                    .ashr,
                    .@"and",
                    .@"or",
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
                        const extra: *align(@alignOf(std.math.big.Limb)) Integer =
                            @ptrCast(data.builder.constant_limbs.items[item.data..][0..Integer.limbs]);
                        const limbs = data.builder.constant_limbs
                            .items[item.data + Integer.limbs ..][0..extra.limbs_len];
                        const bigint = std.math.big.int.Const{
                            .limbs = limbs,
                            .positive = tag == .positive_integer,
                        };
                        const ExpectedContents = extern struct {
                            string: [(64 * 8 / std.math.log2(10)) + 2]u8,
                            limbs: [
                                std.math.big.int.calcToStringLimbsBufferLen(
                                    64 / @sizeOf(std.math.big.Limb),
                                    10,
                                )
                            ]std.math.big.Limb,
                        };
                        var stack align(@alignOf(ExpectedContents)) =
                            std.heap.stackFallback(@sizeOf(ExpectedContents), data.builder.gpa);
                        const allocator = stack.get();
                        const str = bigint.toStringAlloc(allocator, 10, undefined) catch
                            return writer.writeAll("...");
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
                        const Exponent32 = std.meta.FieldType(Float.Repr(f32), .exponent);
                        const Exponent64 = std.meta.FieldType(Float.Repr(f64), .exponent);
                        const repr: Float.Repr(f32) = @bitCast(item.data);
                        try writer.print("0x{X:0>16}", .{@as(u64, @bitCast(Float.Repr(f64){
                            .mantissa = std.math.shl(
                                std.meta.FieldType(Float.Repr(f64), .mantissa),
                                repr.mantissa,
                                std.math.floatMantissaBits(f64) - std.math.floatMantissaBits(f32),
                            ),
                            .exponent = switch (repr.exponent) {
                                std.math.minInt(Exponent32) => std.math.minInt(Exponent64),
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
                    inline .string,
                    .string_null,
                    => |tag| try writer.print("c{\"" ++ switch (tag) {
                        .string => "",
                        .string_null => "@",
                        else => unreachable,
                    } ++ "}", .{@as(String, @enumFromInt(item.data)).fmt(data.builder)}),
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
                    .zext,
                    .sext,
                    .fptrunc,
                    .fpext,
                    .fptoui,
                    .fptosi,
                    .uitofp,
                    .sitofp,
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
                    inline .icmp,
                    .fcmp,
                    => |tag| {
                        const extra = data.builder.constantExtraData(Compare, item.data);
                        try writer.print("{s} {s} ({%}, {%})", .{
                            @tagName(tag),
                            @tagName(@as(switch (tag) {
                                .icmp => IntegerCondition,
                                .fcmp => FloatCondition,
                                else => unreachable,
                            }, @enumFromInt(extra.cond))),
                            extra.lhs.fmt(data.builder),
                            extra.rhs.fmt(data.builder),
                        });
                    },
                    .extractelement => |tag| {
                        const extra = data.builder.constantExtraData(ExtractElement, item.data);
                        try writer.print("{s} ({%}, {%})", .{
                            @tagName(tag),
                            extra.val.fmt(data.builder),
                            extra.index.fmt(data.builder),
                        });
                    },
                    .insertelement => |tag| {
                        const extra = data.builder.constantExtraData(InsertElement, item.data);
                        try writer.print("{s} ({%}, {%}, {%})", .{
                            @tagName(tag),
                            extra.val.fmt(data.builder),
                            extra.elem.fmt(data.builder),
                            extra.index.fmt(data.builder),
                        });
                    },
                    .shufflevector => |tag| {
                        const extra = data.builder.constantExtraData(ShuffleVector, item.data);
                        try writer.print("{s} ({%}, {%}, {%})", .{
                            @tagName(tag),
                            extra.lhs.fmt(data.builder),
                            extra.rhs.fmt(data.builder),
                            extra.mask.fmt(data.builder),
                        });
                    },
                    .add,
                    .@"add nsw",
                    .@"add nuw",
                    .sub,
                    .@"sub nsw",
                    .@"sub nuw",
                    .mul,
                    .@"mul nsw",
                    .@"mul nuw",
                    .shl,
                    .lshr,
                    .ashr,
                    .@"and",
                    .@"or",
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

    pub fn toLlvm(self: Constant, builder: *const Builder) *llvm.Value {
        assert(builder.useLibLlvm());
        const llvm_value = switch (self.unwrap()) {
            .constant => |constant| builder.llvm.constants.items[constant],
            .global => |global| return global.toLlvm(builder),
        };
        const global = builder.llvm.replacements.get(llvm_value) orelse return llvm_value;
        return global.toLlvm(builder);
    }
};

pub const Value = enum(u32) {
    none = std.math.maxInt(u31),
    false = first_constant + @intFromEnum(Constant.false),
    true = first_constant + @intFromEnum(Constant.true),
    _,

    const first_constant = 1 << 31;

    pub fn unwrap(self: Value) union(enum) {
        instruction: Function.Instruction.Index,
        constant: Constant,
    } {
        return if (@intFromEnum(self) < first_constant)
            .{ .instruction = @enumFromInt(@intFromEnum(self)) }
        else
            .{ .constant = @enumFromInt(@intFromEnum(self) - first_constant) };
    }

    pub fn typeOfWip(self: Value, wip: *const WipFunction) Type {
        return switch (self.unwrap()) {
            .instruction => |instruction| instruction.typeOfWip(wip),
            .constant => |constant| constant.typeOf(wip.builder),
        };
    }

    pub fn typeOf(self: Value, function: Function.Index, builder: *Builder) Type {
        return switch (self.unwrap()) {
            .instruction => |instruction| instruction.typeOf(function, builder),
            .constant => |constant| constant.typeOf(builder),
        };
    }

    pub fn toConst(self: Value) ?Constant {
        return switch (self.unwrap()) {
            .instruction => null,
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
        }
    }
    pub fn fmt(self: Value, function: Function.Index, builder: *Builder) std.fmt.Formatter(format) {
        return .{ .data = .{ .value = self, .function = function, .builder = builder } };
    }

    pub fn toLlvm(self: Value, wip: *const WipFunction) *llvm.Value {
        return switch (self.unwrap()) {
            .instruction => |instruction| instruction.toLlvm(wip),
            .constant => |constant| constant.toLlvm(wip.builder),
        };
    }
};

pub const Metadata = enum(u32) { _ };

pub const InitError = error{
    InvalidLlvmTriple,
} || Allocator.Error;

pub fn init(options: Options) InitError!Builder {
    var self = Builder{
        .gpa = options.allocator,
        .use_lib_llvm = options.use_lib_llvm,
        .strip = options.strip,

        .llvm = undefined,

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

        .globals = .{},
        .next_unnamed_global = @enumFromInt(0),
        .next_replaced_global = .none,
        .next_unique_global_id = .{},
        .aliases = .{},
        .variables = .{},
        .functions = .{},

        .constant_map = .{},
        .constant_items = .{},
        .constant_extra = .{},
        .constant_limbs = .{},
    };
    if (self.useLibLlvm()) self.llvm = .{
        .context = llvm.Context.create(),
        .module = null,
        .target = null,
        .di_builder = null,
        .di_compile_unit = null,
        .attribute_kind_ids = null,
        .attributes = .{},
        .types = .{},
        .globals = .{},
        .constants = .{},
        .replacements = .{},
    };
    errdefer self.deinit();

    try self.string_indices.append(self.gpa, 0);
    assert(try self.string("") == .empty);

    if (options.name.len > 0) self.source_filename = try self.string(options.name);
    self.initializeLLVMTarget(options.target.cpu.arch);
    if (self.useLibLlvm()) self.llvm.module = llvm.Module.createWithName(
        (self.source_filename.slice(&self) orelse ""),
        self.llvm.context,
    );

    if (options.triple.len > 0) {
        self.target_triple = try self.string(options.triple);

        if (self.useLibLlvm()) {
            var error_message: [*:0]const u8 = undefined;
            var target: *llvm.Target = undefined;
            if (llvm.Target.getFromTriple(
                self.target_triple.slice(&self).?,
                &target,
                &error_message,
            ).toBool()) {
                defer llvm.disposeMessage(error_message);

                log.err("LLVM failed to parse '{s}': {s}", .{
                    self.target_triple.slice(&self).?,
                    error_message,
                });
                return InitError.InvalidLlvmTriple;
            }
            self.llvm.target = target;
            self.llvm.module.?.setTarget(self.target_triple.slice(&self).?);
        }
    }

    {
        const static_len = @typeInfo(Type).Enum.fields.len - 1;
        try self.type_map.ensureTotalCapacity(self.gpa, static_len);
        try self.type_items.ensureTotalCapacity(self.gpa, static_len);
        if (self.useLibLlvm()) try self.llvm.types.ensureTotalCapacity(self.gpa, static_len);
        inline for (@typeInfo(Type.Simple).Enum.fields) |simple_field| {
            const result = self.getOrPutTypeNoExtraAssumeCapacity(
                .{ .tag = .simple, .data = simple_field.value },
            );
            assert(result.new and result.type == @field(Type, simple_field.name));
            if (self.useLibLlvm()) self.llvm.types.appendAssumeCapacity(
                @field(llvm.Context, simple_field.name ++ "Type")(self.llvm.context),
            );
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
        if (self.useLibLlvm()) {
            self.llvm.attribute_kind_ids = try self.gpa.create([Attribute.Kind.len]c_uint);
            @memset(self.llvm.attribute_kind_ids.?, 0);
        }
        try self.attributes_indices.append(self.gpa, 0);
        assert(try self.attrs(&.{}) == .none);
        assert(try self.fnAttrs(&.{}) == .none);
    }

    assert(try self.intConst(.i1, 0) == .false);
    assert(try self.intConst(.i1, 1) == .true);
    assert(try self.noneConst(.token) == .none);

    return self;
}

pub fn deinit(self: *Builder) void {
    if (self.useLibLlvm()) {
        var replacement_it = self.llvm.replacements.keyIterator();
        while (replacement_it.next()) |replacement| replacement.*.deleteGlobalValue();
        self.llvm.replacements.deinit(self.gpa);
        self.llvm.constants.deinit(self.gpa);
        self.llvm.globals.deinit(self.gpa);
        self.llvm.types.deinit(self.gpa);
        self.llvm.attributes.deinit(self.gpa);
        if (self.llvm.attribute_kind_ids) |attribute_kind_ids| self.gpa.destroy(attribute_kind_ids);
        if (self.llvm.di_builder) |di_builder| di_builder.dispose();
        if (self.llvm.module) |module| module.dispose();
        self.llvm.context.dispose();
    }

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

    self.globals.deinit(self.gpa);
    self.next_unique_global_id.deinit(self.gpa);
    self.aliases.deinit(self.gpa);
    self.variables.deinit(self.gpa);
    for (self.functions.items) |*function| function.deinit(self.gpa);
    self.functions.deinit(self.gpa);

    self.constant_map.deinit(self.gpa);
    self.constant_items.deinit(self.gpa);
    self.constant_extra.deinit(self.gpa);
    self.constant_limbs.deinit(self.gpa);

    self.* = undefined;
}

pub fn initializeLLVMTarget(self: *const Builder, arch: std.Target.Cpu.Arch) void {
    if (!self.useLibLlvm()) return;
    switch (arch) {
        .aarch64, .aarch64_be, .aarch64_32 => {
            llvm.LLVMInitializeAArch64Target();
            llvm.LLVMInitializeAArch64TargetInfo();
            llvm.LLVMInitializeAArch64TargetMC();
            llvm.LLVMInitializeAArch64AsmPrinter();
            llvm.LLVMInitializeAArch64AsmParser();
        },
        .amdgcn => {
            llvm.LLVMInitializeAMDGPUTarget();
            llvm.LLVMInitializeAMDGPUTargetInfo();
            llvm.LLVMInitializeAMDGPUTargetMC();
            llvm.LLVMInitializeAMDGPUAsmPrinter();
            llvm.LLVMInitializeAMDGPUAsmParser();
        },
        .thumb, .thumbeb, .arm, .armeb => {
            llvm.LLVMInitializeARMTarget();
            llvm.LLVMInitializeARMTargetInfo();
            llvm.LLVMInitializeARMTargetMC();
            llvm.LLVMInitializeARMAsmPrinter();
            llvm.LLVMInitializeARMAsmParser();
        },
        .avr => {
            llvm.LLVMInitializeAVRTarget();
            llvm.LLVMInitializeAVRTargetInfo();
            llvm.LLVMInitializeAVRTargetMC();
            llvm.LLVMInitializeAVRAsmPrinter();
            llvm.LLVMInitializeAVRAsmParser();
        },
        .bpfel, .bpfeb => {
            llvm.LLVMInitializeBPFTarget();
            llvm.LLVMInitializeBPFTargetInfo();
            llvm.LLVMInitializeBPFTargetMC();
            llvm.LLVMInitializeBPFAsmPrinter();
            llvm.LLVMInitializeBPFAsmParser();
        },
        .hexagon => {
            llvm.LLVMInitializeHexagonTarget();
            llvm.LLVMInitializeHexagonTargetInfo();
            llvm.LLVMInitializeHexagonTargetMC();
            llvm.LLVMInitializeHexagonAsmPrinter();
            llvm.LLVMInitializeHexagonAsmParser();
        },
        .lanai => {
            llvm.LLVMInitializeLanaiTarget();
            llvm.LLVMInitializeLanaiTargetInfo();
            llvm.LLVMInitializeLanaiTargetMC();
            llvm.LLVMInitializeLanaiAsmPrinter();
            llvm.LLVMInitializeLanaiAsmParser();
        },
        .mips, .mipsel, .mips64, .mips64el => {
            llvm.LLVMInitializeMipsTarget();
            llvm.LLVMInitializeMipsTargetInfo();
            llvm.LLVMInitializeMipsTargetMC();
            llvm.LLVMInitializeMipsAsmPrinter();
            llvm.LLVMInitializeMipsAsmParser();
        },
        .msp430 => {
            llvm.LLVMInitializeMSP430Target();
            llvm.LLVMInitializeMSP430TargetInfo();
            llvm.LLVMInitializeMSP430TargetMC();
            llvm.LLVMInitializeMSP430AsmPrinter();
            llvm.LLVMInitializeMSP430AsmParser();
        },
        .nvptx, .nvptx64 => {
            llvm.LLVMInitializeNVPTXTarget();
            llvm.LLVMInitializeNVPTXTargetInfo();
            llvm.LLVMInitializeNVPTXTargetMC();
            llvm.LLVMInitializeNVPTXAsmPrinter();
            // There is no LLVMInitializeNVPTXAsmParser function available.
        },
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => {
            llvm.LLVMInitializePowerPCTarget();
            llvm.LLVMInitializePowerPCTargetInfo();
            llvm.LLVMInitializePowerPCTargetMC();
            llvm.LLVMInitializePowerPCAsmPrinter();
            llvm.LLVMInitializePowerPCAsmParser();
        },
        .riscv32, .riscv64 => {
            llvm.LLVMInitializeRISCVTarget();
            llvm.LLVMInitializeRISCVTargetInfo();
            llvm.LLVMInitializeRISCVTargetMC();
            llvm.LLVMInitializeRISCVAsmPrinter();
            llvm.LLVMInitializeRISCVAsmParser();
        },
        .sparc, .sparc64, .sparcel => {
            llvm.LLVMInitializeSparcTarget();
            llvm.LLVMInitializeSparcTargetInfo();
            llvm.LLVMInitializeSparcTargetMC();
            llvm.LLVMInitializeSparcAsmPrinter();
            llvm.LLVMInitializeSparcAsmParser();
        },
        .s390x => {
            llvm.LLVMInitializeSystemZTarget();
            llvm.LLVMInitializeSystemZTargetInfo();
            llvm.LLVMInitializeSystemZTargetMC();
            llvm.LLVMInitializeSystemZAsmPrinter();
            llvm.LLVMInitializeSystemZAsmParser();
        },
        .wasm32, .wasm64 => {
            llvm.LLVMInitializeWebAssemblyTarget();
            llvm.LLVMInitializeWebAssemblyTargetInfo();
            llvm.LLVMInitializeWebAssemblyTargetMC();
            llvm.LLVMInitializeWebAssemblyAsmPrinter();
            llvm.LLVMInitializeWebAssemblyAsmParser();
        },
        .x86, .x86_64 => {
            llvm.LLVMInitializeX86Target();
            llvm.LLVMInitializeX86TargetInfo();
            llvm.LLVMInitializeX86TargetMC();
            llvm.LLVMInitializeX86AsmPrinter();
            llvm.LLVMInitializeX86AsmParser();
        },
        .xtensa => {
            if (build_options.llvm_has_xtensa) {
                llvm.LLVMInitializeXtensaTarget();
                llvm.LLVMInitializeXtensaTargetInfo();
                llvm.LLVMInitializeXtensaTargetMC();
                // There is no LLVMInitializeXtensaAsmPrinter function.
                llvm.LLVMInitializeXtensaAsmParser();
            }
        },
        .xcore => {
            llvm.LLVMInitializeXCoreTarget();
            llvm.LLVMInitializeXCoreTargetInfo();
            llvm.LLVMInitializeXCoreTargetMC();
            llvm.LLVMInitializeXCoreAsmPrinter();
            // There is no LLVMInitializeXCoreAsmParser function.
        },
        .m68k => {
            if (build_options.llvm_has_m68k) {
                llvm.LLVMInitializeM68kTarget();
                llvm.LLVMInitializeM68kTargetInfo();
                llvm.LLVMInitializeM68kTargetMC();
                llvm.LLVMInitializeM68kAsmPrinter();
                llvm.LLVMInitializeM68kAsmParser();
            }
        },
        .csky => {
            if (build_options.llvm_has_csky) {
                llvm.LLVMInitializeCSKYTarget();
                llvm.LLVMInitializeCSKYTargetInfo();
                llvm.LLVMInitializeCSKYTargetMC();
                // There is no LLVMInitializeCSKYAsmPrinter function.
                llvm.LLVMInitializeCSKYAsmParser();
            }
        },
        .ve => {
            llvm.LLVMInitializeVETarget();
            llvm.LLVMInitializeVETargetInfo();
            llvm.LLVMInitializeVETargetMC();
            llvm.LLVMInitializeVEAsmPrinter();
            llvm.LLVMInitializeVEAsmParser();
        },
        .arc => {
            if (build_options.llvm_has_arc) {
                llvm.LLVMInitializeARCTarget();
                llvm.LLVMInitializeARCTargetInfo();
                llvm.LLVMInitializeARCTargetMC();
                llvm.LLVMInitializeARCAsmPrinter();
                // There is no LLVMInitializeARCAsmParser function.
            }
        },

        // LLVM backends that have no initialization functions.
        .tce,
        .tcele,
        .r600,
        .le32,
        .le64,
        .amdil,
        .amdil64,
        .hsail,
        .hsail64,
        .shave,
        .spir,
        .spir64,
        .kalimba,
        .renderscript32,
        .renderscript64,
        .dxil,
        .loongarch32,
        .loongarch64,
        => {},

        .spu_2 => unreachable, // LLVM does not support this backend
        .spirv32 => unreachable, // LLVM does not support this backend
        .spirv64 => unreachable, // LLVM does not support this backend
    }
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
    if (self.useLibLlvm())
        self.llvm.module.?.setModuleInlineAsm(self.module_asm.items.ptr, self.module_asm.items.len);
}

pub fn string(self: *Builder, bytes: []const u8) Allocator.Error!String {
    try self.string_bytes.ensureUnusedCapacity(self.gpa, bytes.len + 1);
    try self.string_indices.ensureUnusedCapacity(self.gpa, 1);
    try self.string_map.ensureUnusedCapacity(self.gpa, 1);

    const gop = self.string_map.getOrPutAssumeCapacityAdapted(bytes, String.Adapter{ .builder = self });
    if (!gop.found_existing) {
        self.string_bytes.appendSliceAssumeCapacity(bytes);
        self.string_bytes.appendAssumeCapacity(0);
        self.string_indices.appendAssumeCapacity(@intCast(self.string_bytes.items.len));
    }
    return String.fromIndex(gop.index);
}

pub fn stringIfExists(self: *const Builder, bytes: []const u8) ?String {
    return String.fromIndex(
        self.string_map.getIndexAdapted(bytes, String.Adapter{ .builder = self }) orelse return null,
    );
}

pub fn fmt(self: *Builder, comptime fmt_str: []const u8, fmt_args: anytype) Allocator.Error!String {
    try self.string_map.ensureUnusedCapacity(self.gpa, 1);
    try self.string_bytes.ensureUnusedCapacity(self.gpa, @intCast(std.fmt.count(fmt_str ++ .{0}, fmt_args)));
    try self.string_indices.ensureUnusedCapacity(self.gpa, 1);
    return self.fmtAssumeCapacity(fmt_str, fmt_args);
}

pub fn fmtAssumeCapacity(self: *Builder, comptime fmt_str: []const u8, fmt_args: anytype) String {
    const start = self.string_bytes.items.len;
    self.string_bytes.writer(self.gpa).print(fmt_str ++ .{0}, fmt_args) catch unreachable;
    const bytes: []const u8 = self.string_bytes.items[start .. self.string_bytes.items.len - 1];

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
        const count: usize = comptime std.fmt.count("{d}" ++ .{0}, .{std.math.maxInt(u32)});
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
) (if (build_options.have_llvm) Allocator.Error else error{})!void {
    const named_item = self.type_items.items[@intFromEnum(named_type)];
    self.type_extra.items[named_item.data + std.meta.fieldIndex(Type.NamedStructure, "body").?] =
        @intFromEnum(body_type);
    if (self.useLibLlvm()) {
        const body_item = self.type_items.items[@intFromEnum(body_type)];
        var body_extra = self.typeExtraDataTrail(Type.Structure, body_item.data);
        const body_fields = body_extra.trail.next(body_extra.data.fields_len, Type, self);
        const llvm_fields = try self.gpa.alloc(*llvm.Type, body_fields.len);
        defer self.gpa.free(llvm_fields);
        for (llvm_fields, body_fields) |*llvm_field, body_field| llvm_field.* = body_field.toLlvm(self);
        self.llvm.types.items[@intFromEnum(named_type)].structSetBody(
            llvm_fields.ptr,
            @intCast(llvm_fields.len),
            switch (body_item.tag) {
                .structure => .False,
                .packed_structure => .True,
                else => unreachable,
            },
        );
    }
}

pub fn attr(self: *Builder, attribute: Attribute) Allocator.Error!Attribute.Index {
    try self.attributes.ensureUnusedCapacity(self.gpa, 1);
    if (self.useLibLlvm()) try self.llvm.attributes.ensureUnusedCapacity(self.gpa, 1);

    const gop = self.attributes.getOrPutAssumeCapacity(attribute.toStorage());
    if (!gop.found_existing) {
        gop.value_ptr.* = {};
        if (self.useLibLlvm()) self.llvm.attributes.appendAssumeCapacity(switch (attribute) {
            else => llvm_attr: {
                const llvm_kind_id = attribute.getKind().toLlvm(self);
                if (llvm_kind_id.* == 0) {
                    const name = @tagName(attribute);
                    llvm_kind_id.* = llvm.getEnumAttributeKindForName(name.ptr, name.len);
                    assert(llvm_kind_id.* != 0);
                }
                break :llvm_attr switch (attribute) {
                    else => switch (attribute) {
                        inline else => |value| self.llvm.context.createEnumAttribute(
                            llvm_kind_id.*,
                            switch (@TypeOf(value)) {
                                void => 0,
                                u32 => value,
                                Attribute.FpClass,
                                Attribute.AllocKind,
                                Attribute.Memory,
                                => @as(u32, @bitCast(value)),
                                Alignment => value.toByteUnits() orelse 0,
                                Attribute.AllocSize,
                                Attribute.VScaleRange,
                                => @bitCast(value.toLlvm()),
                                Attribute.UwTable => @intFromEnum(value),
                                else => @compileError(
                                    "bad payload type: " ++ @typeName(@TypeOf(value)),
                                ),
                            },
                        ),
                        .byval,
                        .byref,
                        .preallocated,
                        .inalloca,
                        .sret,
                        .elementtype,
                        .string,
                        .none,
                        => unreachable,
                    },
                    .byval,
                    .byref,
                    .preallocated,
                    .inalloca,
                    .sret,
                    .elementtype,
                    => |ty| self.llvm.context.createTypeAttribute(llvm_kind_id.*, ty.toLlvm(self)),
                    .string, .none => unreachable,
                };
            },
            .string => |string_attr| llvm_attr: {
                const kind = string_attr.kind.slice(self).?;
                const value = string_attr.value.slice(self).?;
                break :llvm_attr self.llvm.context.createStringAttribute(
                    kind.ptr,
                    @intCast(kind.len),
                    value.ptr,
                    @intCast(value.len),
                );
            },
            .none => unreachable,
        });
    }
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
    return @enumFromInt(try self.attrGeneric(@ptrCast(
        fn_attributes[0..if (std.mem.lastIndexOfNone(Attributes, fn_attributes, &.{.none})) |last|
            last + 1
        else
            0],
    )));
}

pub fn addGlobal(self: *Builder, name: String, global: Global) Allocator.Error!Global.Index {
    assert(!name.isAnon());
    try self.ensureUnusedTypeCapacity(1, NoExtra, 0);
    try self.ensureUnusedGlobalCapacity(name);
    return self.addGlobalAssumeCapacity(name, global);
}

pub fn addGlobalAssumeCapacity(self: *Builder, name: String, global: Global) Global.Index {
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
            global_index.updateName(self);
            return global_index;
        }

        const unique_gop = self.next_unique_global_id.getOrPutAssumeCapacity(name);
        if (!unique_gop.found_existing) unique_gop.value_ptr.* = 2;
        id = self.fmtAssumeCapacity("{s}.{d}", .{ name.slice(self).?, unique_gop.value_ptr.* });
        unique_gop.value_ptr.* += 1;
    }
}

pub fn getGlobal(self: *const Builder, name: String) ?Global.Index {
    return @enumFromInt(self.globals.getIndex(name) orelse return null);
}

pub fn addAlias(
    self: *Builder,
    name: String,
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
    name: String,
    ty: Type,
    addr_space: AddrSpace,
    aliasee: Constant,
) Alias.Index {
    if (self.useLibLlvm()) self.llvm.globals.appendAssumeCapacity(self.llvm.module.?.addAlias(
        ty.toLlvm(self),
        @intFromEnum(addr_space),
        aliasee.toLlvm(self),
        name.slice(self).?,
    ));
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
    name: String,
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
    name: String,
    addr_space: AddrSpace,
) Variable.Index {
    if (self.useLibLlvm()) self.llvm.globals.appendAssumeCapacity(
        self.llvm.module.?.addGlobalInAddressSpace(
            ty.toLlvm(self),
            name.slice(self).?,
            @intFromEnum(addr_space),
        ),
    );
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
    name: String,
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
    name: String,
    addr_space: AddrSpace,
) Function.Index {
    assert(ty.isFunction(self));
    if (self.useLibLlvm()) self.llvm.globals.appendAssumeCapacity(
        self.llvm.module.?.addFunctionInAddressSpace(
            name.slice(self).?,
            ty.toLlvm(self),
            @intFromEnum(addr_space),
        ),
    );
    const function_index: Function.Index = @enumFromInt(self.functions.items.len);
    self.functions.appendAssumeCapacity(.{ .global = self.addGlobalAssumeCapacity(name, .{
        .addr_space = addr_space,
        .type = ty,
        .kind = .{ .function = function_index },
    }) });
    return function_index;
}

pub fn getIntrinsic(
    self: *Builder,
    id: Intrinsic,
    overload: []const Type,
) Allocator.Error!Function.Index {
    const ExpectedContents = extern union {
        name: [expected_intrinsic_name_len]u8,
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
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        try buffer.writer().print("llvm.{s}", .{@tagName(id)});
        for (overload) |ty| try buffer.writer().print(".{m}", .{ty.fmt(self)});
        break :name try self.string(buffer.items);
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
    if (self.useLibLlvm()) try self.llvm.constants.ensureUnusedCapacity(self.gpa, 1);
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

pub fn stringNullConst(self: *Builder, val: String) Allocator.Error!Constant {
    try self.ensureUnusedTypeCapacity(1, Type.Array, 0);
    try self.ensureUnusedConstantCapacity(1, NoExtra, 0);
    return self.stringNullConstAssumeCapacity(val);
}

pub fn stringNullValue(self: *Builder, val: String) Allocator.Error!Value {
    return (try self.stringNullConst(val)).toValue();
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
    signedness: Constant.Cast.Signedness,
    val: Constant,
    ty: Type,
) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Cast, 0);
    return self.convConstAssumeCapacity(signedness, val, ty);
}

pub fn convValue(
    self: *Builder,
    signedness: Constant.Cast.Signedness,
    val: Constant,
    ty: Type,
) Allocator.Error!Value {
    return (try self.convConst(signedness, val, ty)).toValue();
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

pub fn icmpConst(
    self: *Builder,
    cond: IntegerCondition,
    lhs: Constant,
    rhs: Constant,
) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Compare, 0);
    return self.icmpConstAssumeCapacity(cond, lhs, rhs);
}

pub fn icmpValue(
    self: *Builder,
    cond: IntegerCondition,
    lhs: Constant,
    rhs: Constant,
) Allocator.Error!Value {
    return (try self.icmpConst(cond, lhs, rhs)).toValue();
}

pub fn fcmpConst(
    self: *Builder,
    cond: FloatCondition,
    lhs: Constant,
    rhs: Constant,
) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Compare, 0);
    return self.icmpConstAssumeCapacity(cond, lhs, rhs);
}

pub fn fcmpValue(
    self: *Builder,
    cond: FloatCondition,
    lhs: Constant,
    rhs: Constant,
) Allocator.Error!Value {
    return (try self.fcmpConst(cond, lhs, rhs)).toValue();
}

pub fn extractElementConst(self: *Builder, val: Constant, index: Constant) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.ExtractElement, 0);
    return self.extractElementConstAssumeCapacity(val, index);
}

pub fn extractElementValue(self: *Builder, val: Constant, index: Constant) Allocator.Error!Value {
    return (try self.extractElementConst(val, index)).toValue();
}

pub fn insertElementConst(
    self: *Builder,
    val: Constant,
    elem: Constant,
    index: Constant,
) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.InsertElement, 0);
    return self.insertElementConstAssumeCapacity(val, elem, index);
}

pub fn insertElementValue(
    self: *Builder,
    val: Constant,
    elem: Constant,
    index: Constant,
) Allocator.Error!Value {
    return (try self.insertElementConst(val, elem, index)).toValue();
}

pub fn shuffleVectorConst(
    self: *Builder,
    lhs: Constant,
    rhs: Constant,
    mask: Constant,
) Allocator.Error!Constant {
    try self.ensureUnusedTypeCapacity(1, Type.Array, 0);
    try self.ensureUnusedConstantCapacity(1, Constant.ShuffleVector, 0);
    return self.shuffleVectorConstAssumeCapacity(lhs, rhs, mask);
}

pub fn shuffleVectorValue(
    self: *Builder,
    lhs: Constant,
    rhs: Constant,
    mask: Constant,
) Allocator.Error!Value {
    return (try self.shuffleVectorConst(lhs, rhs, mask)).toValue();
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

pub fn verify(self: *Builder) error{}!bool {
    if (self.useLibLlvm()) {
        var error_message: [*:0]const u8 = undefined;
        // verifyModule always allocs the error_message even if there is no error
        defer llvm.disposeMessage(error_message);

        if (self.llvm.module.?.verify(.ReturnStatus, &error_message).toBool()) {
            log.err("failed verification of LLVM module:\n{s}\n", .{error_message});
            return false;
        }
    }
    return true;
}

pub fn writeBitcodeToFile(self: *Builder, path: []const u8) Allocator.Error!bool {
    const path_z = try self.gpa.dupeZ(u8, path);
    defer self.gpa.free(path_z);
    return self.writeBitcodeToFileZ(path_z);
}

pub fn writeBitcodeToFileZ(self: *Builder, path: [*:0]const u8) bool {
    if (self.useLibLlvm()) {
        const error_code = self.llvm.module.?.writeBitcodeToFile(path);
        if (error_code != 0) {
            log.err("failed dumping LLVM module to \"{s}\": {d}", .{ path, error_code });
            return false;
        }
    } else {
        log.err("writing bitcode without libllvm not implemented", .{});
        return false;
    }
    return true;
}

pub fn dump(self: *Builder) void {
    if (self.useLibLlvm())
        self.llvm.module.?.dump()
    else
        self.print(std.io.getStdErr().writer()) catch {};
}

pub fn printToFile(self: *Builder, path: []const u8) Allocator.Error!bool {
    const path_z = try self.gpa.dupeZ(u8, path);
    defer self.gpa.free(path_z);
    return self.printToFileZ(path_z);
}

pub fn printToFileZ(self: *Builder, path: [*:0]const u8) bool {
    if (self.useLibLlvm()) {
        var error_message: [*:0]const u8 = undefined;
        if (self.llvm.module.?.printModuleToFile(path, &error_message).toBool()) {
            defer llvm.disposeMessage(error_message);
            log.err("failed printing LLVM module to \"{s}\": {s}", .{ path, error_message });
            return false;
        }
    } else {
        var file = std.fs.cwd().createFileZ(path, .{}) catch |err| {
            log.err("failed printing LLVM module to \"{s}\": {s}", .{ path, @errorName(err) });
            return false;
        };
        defer file.close();
        self.print(file.writer()) catch |err| {
            log.err("failed printing LLVM module to \"{s}\": {s}", .{ path, @errorName(err) });
            return false;
        };
    }
    return true;
}

pub fn print(self: *Builder, writer: anytype) (@TypeOf(writer).Error || Allocator.Error)!void {
    var bw = std.io.bufferedWriter(writer);
    try self.printUnbuffered(bw.writer());
    try bw.flush();
}

pub fn printUnbuffered(
    self: *Builder,
    writer: anytype,
) (@TypeOf(writer).Error || Allocator.Error)!void {
    var need_newline = false;

    if (self.source_filename != .none or self.data_layout != .none or self.target_triple != .none) {
        if (need_newline) try writer.writeByte('\n');
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
        need_newline = true;
    }

    if (self.module_asm.items.len > 0) {
        if (need_newline) try writer.writeByte('\n');
        var line_it = std.mem.tokenizeScalar(u8, self.module_asm.items, '\n');
        while (line_it.next()) |line| {
            try writer.writeAll("module asm ");
            try printEscapedString(line, .always_quote, writer);
            try writer.writeByte('\n');
        }
        need_newline = true;
    }

    if (self.types.count() > 0) {
        if (need_newline) try writer.writeByte('\n');
        for (self.types.keys(), self.types.values()) |id, ty| try writer.print(
            \\%{} = type {}
            \\
        , .{ id.fmt(self), ty.fmt(self) });
        need_newline = true;
    }

    if (self.variables.items.len > 0) {
        if (need_newline) try writer.writeByte('\n');
        for (self.variables.items) |variable| {
            if (variable.global.getReplacement(self) != .none) continue;
            const global = variable.global.ptrConst(self);
            try writer.print(
                \\{} ={}{}{}{}{ }{}{ }{} {s} {%}{ }{, }
                \\
            , .{
                variable.global.fmt(self),
                global.linkage,
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
            });
        }
        need_newline = true;
    }

    if (self.aliases.items.len > 0) {
        if (need_newline) try writer.writeByte('\n');
        for (self.aliases.items) |alias| {
            if (alias.global.getReplacement(self) != .none) continue;
            const global = alias.global.ptrConst(self);
            try writer.print(
                \\{} ={}{}{}{}{ }{} alias {%}, {%}
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
            });
        }
        need_newline = true;
    }

    var attribute_groups: std.AutoArrayHashMapUnmanaged(Attributes, void) = .{};
    defer attribute_groups.deinit(self.gpa);

    for (0.., self.functions.items) |function_i, function| {
        if (function.global.getReplacement(self) != .none) continue;
        if (need_newline) try writer.writeByte('\n');
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
        try writer.print("{ }", .{function.alignment});
        if (function.instructions.len > 0) {
            var block_incoming_len: u32 = undefined;
            try writer.writeAll(" {\n");
            for (params_len..function.instructions.len) |instruction_i| {
                const instruction_index: Function.Instruction.Index = @enumFromInt(instruction_i);
                const instruction = function.instructions.get(@intFromEnum(instruction_index));
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
                        try writer.print("  %{} = {s} {%}, {}\n", .{
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
                        try writer.print("  %{} = {s} {%} to {%}\n", .{
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
                        try writer.print("  %{} = {s} {%}{,%}{, }{, }\n", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.type.fmt(self),
                            extra.len.fmt(function_index, self),
                            extra.info.alignment,
                            extra.info.addr_space,
                        });
                    },
                    .arg => unreachable,
                    .atomicrmw => |tag| {
                        const extra =
                            function.extraData(Function.Instruction.AtomicRmw, instruction.data);
                        try writer.print("  %{} = {s}{ } {s} {%}, {%}{ }{ }{, }\n", .{
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
                    },
                    .br => |tag| {
                        const target: Function.Block.Index = @enumFromInt(instruction.data);
                        try writer.print("  {s} {%}\n", .{
                            @tagName(tag), target.toInst(&function).fmt(function_index, self),
                        });
                    },
                    .br_cond => {
                        const extra = function.extraData(Function.Instruction.BrCond, instruction.data);
                        try writer.print("  br {%}, {%}, {%}\n", .{
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
                            try writer.print("{%}{} {}", .{
                                arg.typeOf(function_index, self).fmt(self),
                                extra.data.attributes.param(arg_index, self).fmt(self),
                                arg.fmt(function_index, self),
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
                        try writer.writeByte('\n');
                    },
                    .cmpxchg,
                    .@"cmpxchg weak",
                    => |tag| {
                        const extra =
                            function.extraData(Function.Instruction.CmpXchg, instruction.data);
                        try writer.print("  %{} = {s}{ } {%}, {%}, {%}{ }{ }{ }{, }\n", .{
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
                        try writer.print("  %{} = {s} {%}, {%}\n", .{
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
                        try writer.writeByte('\n');
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
                        try writer.print("  %{} = {s} {%}\n", .{
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
                        try writer.writeByte('\n');
                    },
                    .insertelement => |tag| {
                        const extra =
                            function.extraData(Function.Instruction.InsertElement, instruction.data);
                        try writer.print("  %{} = {s} {%}, {%}, {%}\n", .{
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
                        try writer.writeByte('\n');
                    },
                    .load,
                    .@"load atomic",
                    => |tag| {
                        const extra = function.extraData(Function.Instruction.Load, instruction.data);
                        try writer.print("  %{} = {s}{ } {%}, {%}{ }{ }{, }\n", .{
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
                        try writer.writeByte('\n');
                    },
                    .ret => |tag| {
                        const val: Value = @enumFromInt(instruction.data);
                        try writer.print("  {s} {%}\n", .{
                            @tagName(tag),
                            val.fmt(function_index, self),
                        });
                    },
                    .@"ret void",
                    .@"unreachable",
                    => |tag| try writer.print("  {s}\n", .{@tagName(tag)}),
                    .select,
                    .@"select fast",
                    => |tag| {
                        const extra = function.extraData(Function.Instruction.Select, instruction.data);
                        try writer.print("  %{} = {s} {%}, {%}, {%}\n", .{
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
                        try writer.print("  %{} = {s} {%}, {%}, {%}\n", .{
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
                        try writer.print("  {s}{ } {%}, {%}{ }{ }{, }\n", .{
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
                        try writer.writeAll("  ]\n");
                    },
                    .va_arg => |tag| {
                        const extra = function.extraData(Function.Instruction.VaArg, instruction.data);
                        try writer.print("  %{} = {s} {%}, {%}\n", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.list.fmt(function_index, self),
                            extra.type.fmt(self),
                        });
                    },
                }
            }
            try writer.writeByte('}');
        }
        try writer.writeByte('\n');
        need_newline = true;
    }

    if (attribute_groups.count() > 0) {
        if (need_newline) try writer.writeByte('\n') else need_newline = true;
        for (0.., attribute_groups.keys()) |attribute_group_index, attribute_group|
            try writer.print(
                \\attributes #{d} = {{{#"} }}
                \\
            , .{ attribute_group_index, attribute_group.fmt(self) });
        need_newline = true;
    }
}

pub inline fn useLibLlvm(self: *const Builder) bool {
    return build_options.have_llvm and self.use_lib_llvm;
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

fn ensureUnusedGlobalCapacity(self: *Builder, name: String) Allocator.Error!void {
    if (self.useLibLlvm()) try self.llvm.globals.ensureUnusedCapacity(self.gpa, 1);
    try self.string_map.ensureUnusedCapacity(self.gpa, 1);
    if (name.slice(self)) |id| {
        const count: usize = comptime std.fmt.count("{d}" ++ .{0}, .{std.math.maxInt(u32)});
        try self.string_bytes.ensureUnusedCapacity(self.gpa, id.len + count);
    }
    try self.string_indices.ensureUnusedCapacity(self.gpa, 1);
    try self.globals.ensureUnusedCapacity(self.gpa, 1);
    try self.next_unique_global_id.ensureUnusedCapacity(self.gpa, 1);
}

fn fnTypeAssumeCapacity(
    self: *Builder,
    ret: Type,
    params: []const Type,
    comptime kind: Type.Function.Kind,
) (if (build_options.have_llvm) Allocator.Error else error{})!Type {
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
            var rhs_extra = ctx.builder.typeExtraDataTrail(Type.Function, rhs_data.data);
            const rhs_params = rhs_extra.trail.next(rhs_extra.data.params_len, Type, ctx.builder);
            return rhs_data.tag == tag and lhs_key.ret == rhs_extra.data.ret and
                std.mem.eql(Type, lhs_key.params, rhs_params);
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
        if (self.useLibLlvm()) {
            const llvm_params = try self.gpa.alloc(*llvm.Type, params.len);
            defer self.gpa.free(llvm_params);
            for (llvm_params, params) |*llvm_param, param| llvm_param.* = param.toLlvm(self);
            self.llvm.types.appendAssumeCapacity(llvm.functionType(
                ret.toLlvm(self),
                llvm_params.ptr,
                @intCast(llvm_params.len),
                switch (kind) {
                    .normal => .False,
                    .vararg => .True,
                },
            ));
        }
    }
    return @enumFromInt(gop.index);
}

fn intTypeAssumeCapacity(self: *Builder, bits: u24) Type {
    assert(bits > 0);
    const result = self.getOrPutTypeNoExtraAssumeCapacity(.{ .tag = .integer, .data = bits });
    if (self.useLibLlvm() and result.new)
        self.llvm.types.appendAssumeCapacity(self.llvm.context.intType(bits));
    return result.type;
}

fn ptrTypeAssumeCapacity(self: *Builder, addr_space: AddrSpace) Type {
    const result = self.getOrPutTypeNoExtraAssumeCapacity(
        .{ .tag = .pointer, .data = @intFromEnum(addr_space) },
    );
    if (self.useLibLlvm() and result.new)
        self.llvm.types.appendAssumeCapacity(self.llvm.context.pointerType(@intFromEnum(addr_space)));
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
        if (self.useLibLlvm()) self.llvm.types.appendAssumeCapacity(switch (kind) {
            .normal => &llvm.Type.vectorType,
            .scalable => &llvm.Type.scalableVectorType,
        }(child.toLlvm(self), @intCast(len)));
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
            if (self.useLibLlvm()) self.llvm.types.appendAssumeCapacity(
                child.toLlvm(self).arrayType2(len),
            );
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
            if (self.useLibLlvm()) self.llvm.types.appendAssumeCapacity(
                child.toLlvm(self).arrayType2(len),
            );
        }
        return @enumFromInt(gop.index);
    }
}

fn structTypeAssumeCapacity(
    self: *Builder,
    comptime kind: Type.Structure.Kind,
    fields: []const Type,
) (if (build_options.have_llvm) Allocator.Error else error{})!Type {
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
            var rhs_extra = ctx.builder.typeExtraDataTrail(Type.Structure, rhs_data.data);
            const rhs_fields = rhs_extra.trail.next(rhs_extra.data.fields_len, Type, ctx.builder);
            return rhs_data.tag == tag and std.mem.eql(Type, lhs_key, rhs_fields);
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
        if (self.useLibLlvm()) {
            const ExpectedContents = [expected_fields_len]*llvm.Type;
            var stack align(@alignOf(ExpectedContents)) =
                std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
            const allocator = stack.get();

            const llvm_fields = try allocator.alloc(*llvm.Type, fields.len);
            defer allocator.free(llvm_fields);
            for (llvm_fields, fields) |*llvm_field, field| llvm_field.* = field.toLlvm(self);

            self.llvm.types.appendAssumeCapacity(self.llvm.context.structType(
                llvm_fields.ptr,
                @intCast(llvm_fields.len),
                switch (kind) {
                    .normal => .False,
                    .@"packed" => .True,
                },
            ));
        }
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
            if (self.useLibLlvm()) self.llvm.types.appendAssumeCapacity(
                self.llvm.context.structCreateNamed(id.slice(self) orelse ""),
            );
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
    if (self.useLibLlvm()) try self.llvm.types.ensureUnusedCapacity(self.gpa, count);
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
            else => @compileError("bad field type: " ++ @typeName(field.type)),
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

    const ExpectedContents = extern struct {
        limbs: [64 / @sizeOf(std.math.big.Limb)]std.math.big.Limb,
        llvm_limbs: if (build_options.have_llvm) [64 / @sizeOf(u64)]u64 else void,
    };
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
        if (self.useLibLlvm()) {
            const llvm_type = ty.toLlvm(self);
            if (canonical_value.to(c_longlong)) |small| {
                self.llvm.constants.appendAssumeCapacity(llvm_type.constInt(@bitCast(small), .True));
            } else |_| if (canonical_value.to(c_ulonglong)) |small| {
                self.llvm.constants.appendAssumeCapacity(llvm_type.constInt(small, .False));
            } else |_| {
                const llvm_limbs = try allocator.alloc(u64, std.math.divCeil(
                    usize,
                    if (canonical_value.positive) canonical_value.bitCountAbs() else bits,
                    @bitSizeOf(u64),
                ) catch unreachable);
                defer allocator.free(llvm_limbs);
                var limb_index: usize = 0;
                var borrow: std.math.big.Limb = 0;
                for (llvm_limbs) |*result_limb| {
                    var llvm_limb: u64 = 0;
                    inline for (0..Constant.Integer.limbs) |shift| {
                        const limb = if (limb_index < canonical_value.limbs.len)
                            canonical_value.limbs[limb_index]
                        else
                            0;
                        limb_index += 1;
                        llvm_limb |= @as(u64, limb) << shift * @bitSizeOf(std.math.big.Limb);
                    }
                    if (!canonical_value.positive) {
                        const overflow = @subWithOverflow(borrow, llvm_limb);
                        llvm_limb = overflow[0];
                        borrow -%= overflow[1];
                        assert(borrow == 0 or borrow == std.math.maxInt(u64));
                    }
                    result_limb.* = llvm_limb;
                }
                self.llvm.constants.appendAssumeCapacity(
                    llvm_type.constIntOfArbitraryPrecision(@intCast(llvm_limbs.len), llvm_limbs.ptr),
                );
            }
        }
    }
    return @enumFromInt(gop.index);
}

fn halfConstAssumeCapacity(self: *Builder, val: f16) Constant {
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .half, .data = @as(u16, @bitCast(val)) },
    );
    if (self.useLibLlvm() and result.new) self.llvm.constants.appendAssumeCapacity(
        if (std.math.isSignalNan(val))
            Type.i16.toLlvm(self).constInt(@as(u16, @bitCast(val)), .False)
                .constBitCast(Type.half.toLlvm(self))
        else
            Type.half.toLlvm(self).constReal(val),
    );
    return result.constant;
}

fn bfloatConstAssumeCapacity(self: *Builder, val: f32) Constant {
    assert(@as(u16, @truncate(@as(u32, @bitCast(val)))) == 0);
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .bfloat, .data = @bitCast(val) },
    );
    if (self.useLibLlvm() and result.new) self.llvm.constants.appendAssumeCapacity(
        if (std.math.isSignalNan(val))
            Type.i16.toLlvm(self).constInt(@as(u32, @bitCast(val)) >> 16, .False)
                .constBitCast(Type.bfloat.toLlvm(self))
        else
            Type.bfloat.toLlvm(self).constReal(val),
    );

    if (self.useLibLlvm() and result.new)
        self.llvm.constants.appendAssumeCapacity(Type.bfloat.toLlvm(self).constReal(val));
    return result.constant;
}

fn floatConstAssumeCapacity(self: *Builder, val: f32) Constant {
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .float, .data = @bitCast(val) },
    );
    if (self.useLibLlvm() and result.new) self.llvm.constants.appendAssumeCapacity(
        if (std.math.isSignalNan(val))
            Type.i32.toLlvm(self).constInt(@as(u32, @bitCast(val)), .False)
                .constBitCast(Type.float.toLlvm(self))
        else
            Type.float.toLlvm(self).constReal(val),
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
        if (self.useLibLlvm()) self.llvm.constants.appendAssumeCapacity(
            if (std.math.isSignalNan(val))
                Type.i64.toLlvm(self).constInt(@as(u64, @bitCast(val)), .False)
                    .constBitCast(Type.double.toLlvm(self))
            else
                Type.double.toLlvm(self).constReal(val),
        );
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
        if (self.useLibLlvm()) {
            const llvm_limbs = [_]u64{
                @truncate(@as(u128, @bitCast(val))),
                @intCast(@as(u128, @bitCast(val)) >> 64),
            };
            self.llvm.constants.appendAssumeCapacity(
                Type.i128.toLlvm(self)
                    .constIntOfArbitraryPrecision(@intCast(llvm_limbs.len), &llvm_limbs)
                    .constBitCast(Type.fp128.toLlvm(self)),
            );
        }
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
        if (self.useLibLlvm()) {
            const llvm_limbs = [_]u64{
                @truncate(@as(u80, @bitCast(val))),
                @intCast(@as(u80, @bitCast(val)) >> 64),
            };
            self.llvm.constants.appendAssumeCapacity(
                Type.i80.toLlvm(self)
                    .constIntOfArbitraryPrecision(@intCast(llvm_limbs.len), &llvm_limbs)
                    .constBitCast(Type.x86_fp80.toLlvm(self)),
            );
        }
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
        if (self.useLibLlvm()) {
            const llvm_limbs: [2]u64 = @bitCast(val);
            self.llvm.constants.appendAssumeCapacity(
                Type.i128.toLlvm(self)
                    .constIntOfArbitraryPrecision(@intCast(llvm_limbs.len), &llvm_limbs)
                    .constBitCast(Type.ppc_fp128.toLlvm(self)),
            );
        }
    }
    return @enumFromInt(gop.index);
}

fn nullConstAssumeCapacity(self: *Builder, ty: Type) Constant {
    assert(self.type_items.items[@intFromEnum(ty)].tag == .pointer);
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .null, .data = @intFromEnum(ty) },
    );
    if (self.useLibLlvm() and result.new)
        self.llvm.constants.appendAssumeCapacity(ty.toLlvm(self).constNull());
    return result.constant;
}

fn noneConstAssumeCapacity(self: *Builder, ty: Type) Constant {
    assert(ty == .token);
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .none, .data = @intFromEnum(ty) },
    );
    if (self.useLibLlvm() and result.new)
        self.llvm.constants.appendAssumeCapacity(ty.toLlvm(self).constNull());
    return result.constant;
}

fn structConstAssumeCapacity(
    self: *Builder,
    ty: Type,
    vals: []const Constant,
) (if (build_options.have_llvm) Allocator.Error else error{})!Constant {
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
    if (self.useLibLlvm() and result.new) {
        const ExpectedContents = [expected_fields_len]*llvm.Value;
        var stack align(@alignOf(ExpectedContents)) =
            std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
        const allocator = stack.get();

        const llvm_vals = try allocator.alloc(*llvm.Value, vals.len);
        defer allocator.free(llvm_vals);
        for (llvm_vals, vals) |*llvm_val, val| llvm_val.* = val.toLlvm(self);

        self.llvm.constants.appendAssumeCapacity(
            ty.toLlvm(self).constNamedStruct(llvm_vals.ptr, @intCast(llvm_vals.len)),
        );
    }
    return result.constant;
}

fn arrayConstAssumeCapacity(
    self: *Builder,
    ty: Type,
    vals: []const Constant,
) (if (build_options.have_llvm) Allocator.Error else error{})!Constant {
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
    if (self.useLibLlvm() and result.new) {
        const ExpectedContents = [expected_fields_len]*llvm.Value;
        var stack align(@alignOf(ExpectedContents)) =
            std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
        const allocator = stack.get();

        const llvm_vals = try allocator.alloc(*llvm.Value, vals.len);
        defer allocator.free(llvm_vals);
        for (llvm_vals, vals) |*llvm_val, val| llvm_val.* = val.toLlvm(self);

        self.llvm.constants.appendAssumeCapacity(
            type_extra.child.toLlvm(self).constArray2(llvm_vals.ptr, llvm_vals.len),
        );
    }
    return result.constant;
}

fn stringConstAssumeCapacity(self: *Builder, val: String) Constant {
    const slice = val.slice(self).?;
    const ty = self.arrayTypeAssumeCapacity(slice.len, .i8);
    if (std.mem.allEqual(u8, slice, 0)) return self.zeroInitConstAssumeCapacity(ty);
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .string, .data = @intFromEnum(val) },
    );
    if (self.useLibLlvm() and result.new) self.llvm.constants.appendAssumeCapacity(
        self.llvm.context.constString(slice.ptr, @intCast(slice.len), .True),
    );
    return result.constant;
}

fn stringNullConstAssumeCapacity(self: *Builder, val: String) Constant {
    const slice = val.slice(self).?;
    const ty = self.arrayTypeAssumeCapacity(slice.len + 1, .i8);
    if (std.mem.allEqual(u8, slice, 0)) return self.zeroInitConstAssumeCapacity(ty);
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .string_null, .data = @intFromEnum(val) },
    );
    if (self.useLibLlvm() and result.new) self.llvm.constants.appendAssumeCapacity(
        self.llvm.context.constString(slice.ptr, @intCast(slice.len + 1), .True),
    );
    return result.constant;
}

fn vectorConstAssumeCapacity(
    self: *Builder,
    ty: Type,
    vals: []const Constant,
) (if (build_options.have_llvm) Allocator.Error else error{})!Constant {
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
    if (self.useLibLlvm() and result.new) {
        const ExpectedContents = [expected_fields_len]*llvm.Value;
        var stack align(@alignOf(ExpectedContents)) =
            std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
        const allocator = stack.get();

        const llvm_vals = try allocator.alloc(*llvm.Value, vals.len);
        defer allocator.free(llvm_vals);
        for (llvm_vals, vals) |*llvm_val, val| llvm_val.* = val.toLlvm(self);

        self.llvm.constants.appendAssumeCapacity(
            llvm.constVector(llvm_vals.ptr, @intCast(llvm_vals.len)),
        );
    }
    return result.constant;
}

fn splatConstAssumeCapacity(
    self: *Builder,
    ty: Type,
    val: Constant,
) (if (build_options.have_llvm) Allocator.Error else error{})!Constant {
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
        if (self.useLibLlvm()) {
            const ExpectedContents = [expected_fields_len]*llvm.Value;
            var stack align(@alignOf(ExpectedContents)) =
                std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
            const allocator = stack.get();

            const llvm_vals = try allocator.alloc(*llvm.Value, ty.vectorLen(self));
            defer allocator.free(llvm_vals);
            @memset(llvm_vals, val.toLlvm(self));

            self.llvm.constants.appendAssumeCapacity(
                llvm.constVector(llvm_vals.ptr, @intCast(llvm_vals.len)),
            );
        }
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
    if (self.useLibLlvm() and result.new)
        self.llvm.constants.appendAssumeCapacity(ty.toLlvm(self).constNull());
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
    if (self.useLibLlvm() and result.new)
        self.llvm.constants.appendAssumeCapacity(ty.toLlvm(self).getUndef());
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
    if (self.useLibLlvm() and result.new)
        self.llvm.constants.appendAssumeCapacity(ty.toLlvm(self).getPoison());
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
        if (self.useLibLlvm()) self.llvm.constants.appendAssumeCapacity(
            function.toLlvm(self).blockAddress(block.toValue(self, function).toLlvm(self, function)),
        );
    }
    return @enumFromInt(gop.index);
}

fn dsoLocalEquivalentConstAssumeCapacity(self: *Builder, function: Function.Index) Constant {
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .dso_local_equivalent, .data = @intFromEnum(function) },
    );
    if (self.useLibLlvm() and result.new) self.llvm.constants.appendAssumeCapacity(undefined);
    return result.constant;
}

fn noCfiConstAssumeCapacity(self: *Builder, function: Function.Index) Constant {
    const result = self.getOrPutConstantNoExtraAssumeCapacity(
        .{ .tag = .no_cfi, .data = @intFromEnum(function) },
    );
    if (self.useLibLlvm() and result.new) self.llvm.constants.appendAssumeCapacity(undefined);
    return result.constant;
}

fn convTag(
    self: *Builder,
    comptime Tag: type,
    signedness: Constant.Cast.Signedness,
    val_ty: Type,
    ty: Type,
) Tag {
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

fn convConstAssumeCapacity(
    self: *Builder,
    signedness: Constant.Cast.Signedness,
    val: Constant,
    ty: Type,
) Constant {
    const val_ty = val.typeOf(self);
    if (val_ty == ty) return val;
    return self.castConstAssumeCapacity(self.convTag(Constant.Tag, signedness, val_ty, ty), val, ty);
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
        if (self.useLibLlvm()) self.llvm.constants.appendAssumeCapacity(switch (tag) {
            .trunc => &llvm.Value.constTrunc,
            .zext => &llvm.Value.constZExt,
            .sext => &llvm.Value.constSExt,
            .fptrunc => &llvm.Value.constFPTrunc,
            .fpext => &llvm.Value.constFPExt,
            .fptoui => &llvm.Value.constFPToUI,
            .fptosi => &llvm.Value.constFPToSI,
            .uitofp => &llvm.Value.constUIToFP,
            .sitofp => &llvm.Value.constSIToFP,
            .ptrtoint => &llvm.Value.constPtrToInt,
            .inttoptr => &llvm.Value.constIntToPtr,
            .bitcast => &llvm.Value.constBitCast,
            .addrspacecast => &llvm.Value.constAddrSpaceCast,
            else => unreachable,
        }(val.toLlvm(self), ty.toLlvm(self)));
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
) (if (build_options.have_llvm) Allocator.Error else error{})!Constant {
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
        if (self.useLibLlvm()) {
            const ExpectedContents = [expected_gep_indices_len]*llvm.Value;
            var stack align(@alignOf(ExpectedContents)) =
                std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
            const allocator = stack.get();

            const llvm_indices = try allocator.alloc(*llvm.Value, indices.len);
            defer allocator.free(llvm_indices);
            for (llvm_indices, indices) |*llvm_index, index| llvm_index.* = index.toLlvm(self);

            self.llvm.constants.appendAssumeCapacity(switch (kind) {
                .normal => &llvm.Type.constGEP,
                .inbounds => &llvm.Type.constInBoundsGEP,
            }(ty.toLlvm(self), base.toLlvm(self), llvm_indices.ptr, @intCast(llvm_indices.len)));
        }
    }
    return @enumFromInt(gop.index);
}

fn icmpConstAssumeCapacity(
    self: *Builder,
    cond: IntegerCondition,
    lhs: Constant,
    rhs: Constant,
) Constant {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Constant.Compare) u32 {
            return @truncate(std.hash.Wyhash.hash(
                std.hash.uint32(@intFromEnum(Constant.tag.icmp)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Constant.Compare, _: void, rhs_index: usize) bool {
            if (ctx.builder.constant_items.items(.tag)[rhs_index] != .icmp) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.Compare, rhs_data);
            return std.meta.eql(lhs_key, rhs_extra);
        }
    };
    const data = Constant.Compare{ .cond = @intFromEnum(cond), .lhs = lhs, .rhs = rhs };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = .icmp,
            .data = self.addConstantExtraAssumeCapacity(data),
        });
        if (self.useLibLlvm()) self.llvm.constants.appendAssumeCapacity(
            llvm.constICmp(cond.toLlvm(), lhs.toLlvm(self), rhs.toLlvm(self)),
        );
    }
    return @enumFromInt(gop.index);
}

fn fcmpConstAssumeCapacity(
    self: *Builder,
    cond: FloatCondition,
    lhs: Constant,
    rhs: Constant,
) Constant {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Constant.Compare) u32 {
            return @truncate(std.hash.Wyhash.hash(
                std.hash.uint32(@intFromEnum(Constant.tag.fcmp)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Constant.Compare, _: void, rhs_index: usize) bool {
            if (ctx.builder.constant_items.items(.tag)[rhs_index] != .fcmp) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.Compare, rhs_data);
            return std.meta.eql(lhs_key, rhs_extra);
        }
    };
    const data = Constant.Compare{ .cond = @intFromEnum(cond), .lhs = lhs, .rhs = rhs };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = .fcmp,
            .data = self.addConstantExtraAssumeCapacity(data),
        });
        if (self.useLibLlvm()) self.llvm.constants.appendAssumeCapacity(
            llvm.constFCmp(cond.toLlvm(), lhs.toLlvm(self), rhs.toLlvm(self)),
        );
    }
    return @enumFromInt(gop.index);
}

fn extractElementConstAssumeCapacity(
    self: *Builder,
    val: Constant,
    index: Constant,
) Constant {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Constant.ExtractElement) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(Constant.Tag.extractelement)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Constant.ExtractElement, _: void, rhs_index: usize) bool {
            if (ctx.builder.constant_items.items(.tag)[rhs_index] != .extractelement) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.ExtractElement, rhs_data);
            return std.meta.eql(lhs_key, rhs_extra);
        }
    };
    const data = Constant.ExtractElement{ .val = val, .index = index };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = .extractelement,
            .data = self.addConstantExtraAssumeCapacity(data),
        });
        if (self.useLibLlvm()) self.llvm.constants.appendAssumeCapacity(
            val.toLlvm(self).constExtractElement(index.toLlvm(self)),
        );
    }
    return @enumFromInt(gop.index);
}

fn insertElementConstAssumeCapacity(
    self: *Builder,
    val: Constant,
    elem: Constant,
    index: Constant,
) Constant {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Constant.InsertElement) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(Constant.Tag.insertelement)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Constant.InsertElement, _: void, rhs_index: usize) bool {
            if (ctx.builder.constant_items.items(.tag)[rhs_index] != .insertelement) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.InsertElement, rhs_data);
            return std.meta.eql(lhs_key, rhs_extra);
        }
    };
    const data = Constant.InsertElement{ .val = val, .elem = elem, .index = index };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = .insertelement,
            .data = self.addConstantExtraAssumeCapacity(data),
        });
        if (self.useLibLlvm()) self.llvm.constants.appendAssumeCapacity(
            val.toLlvm(self).constInsertElement(elem.toLlvm(self), index.toLlvm(self)),
        );
    }
    return @enumFromInt(gop.index);
}

fn shuffleVectorConstAssumeCapacity(
    self: *Builder,
    lhs: Constant,
    rhs: Constant,
    mask: Constant,
) Constant {
    assert(lhs.typeOf(self).isVector(self.builder));
    assert(lhs.typeOf(self) == rhs.typeOf(self));
    assert(mask.typeOf(self).scalarType(self).isInteger(self));
    _ = lhs.typeOf(self).changeLengthAssumeCapacity(mask.typeOf(self).vectorLen(self), self);
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Constant.ShuffleVector) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(Constant.Tag.shufflevector)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Constant.ShuffleVector, _: void, rhs_index: usize) bool {
            if (ctx.builder.constant_items.items(.tag)[rhs_index] != .shufflevector) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.ShuffleVector, rhs_data);
            return std.meta.eql(lhs_key, rhs_extra);
        }
    };
    const data = Constant.ShuffleVector{ .lhs = lhs, .rhs = rhs, .mask = mask };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = .shufflevector,
            .data = self.addConstantExtraAssumeCapacity(data),
        });
        if (self.useLibLlvm()) self.llvm.constants.appendAssumeCapacity(
            lhs.toLlvm(self).constShuffleVector(rhs.toLlvm(self), mask.toLlvm(self)),
        );
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
        .mul,
        .@"mul nsw",
        .@"mul nuw",
        .shl,
        .lshr,
        .ashr,
        .@"and",
        .@"or",
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
        if (self.useLibLlvm()) self.llvm.constants.appendAssumeCapacity(switch (tag) {
            .add => &llvm.Value.constAdd,
            .sub => &llvm.Value.constSub,
            .mul => &llvm.Value.constMul,
            .shl => &llvm.Value.constShl,
            .lshr => &llvm.Value.constLShr,
            .ashr => &llvm.Value.constAShr,
            .@"and" => &llvm.Value.constAnd,
            .@"or" => &llvm.Value.constOr,
            .xor => &llvm.Value.constXor,
            else => unreachable,
        }(lhs.toLlvm(self), rhs.toLlvm(self)));
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
        if (self.useLibLlvm()) {
            const assembly_slice = assembly.slice(self).?;
            const constraints_slice = constraints.slice(self).?;
            self.llvm.constants.appendAssumeCapacity(llvm.getInlineAsm(
                ty.toLlvm(self),
                assembly_slice.ptr,
                assembly_slice.len,
                constraints_slice.ptr,
                constraints_slice.len,
                llvm.Bool.fromBool(info.sideeffect),
                llvm.Bool.fromBool(info.alignstack),
                if (info.inteldialect) .Intel else .ATT,
                llvm.Bool.fromBool(info.unwind),
            ));
        }
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
    if (self.useLibLlvm()) try self.llvm.constants.ensureUnusedCapacity(self.gpa, count);
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

const assert = std.debug.assert;
const build_options = @import("build_options");
const builtin = @import("builtin");
const llvm = if (build_options.have_llvm)
    @import("bindings.zig")
else
    @compileError("LLVM unavailable");
const log = std.log.scoped(.llvm);
const std = @import("std");

const Allocator = std.mem.Allocator;
const Builder = @This();
