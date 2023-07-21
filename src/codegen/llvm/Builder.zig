gpa: Allocator,
use_lib_llvm: bool,
strip: bool,

llvm: if (build_options.have_llvm) struct {
    context: *llvm.Context,
    module: ?*llvm.Module = null,
    target: ?*llvm.Target = null,
    di_builder: ?*llvm.DIBuilder = null,
    di_compile_unit: ?*llvm.DICompileUnit = null,
    types: std.ArrayListUnmanaged(*llvm.Type) = .{},
    globals: std.ArrayListUnmanaged(*llvm.Value) = .{},
    constants: std.ArrayListUnmanaged(*llvm.Value) = .{},
} else void,

source_filename: String,
data_layout: String,
target_triple: String,

string_map: std.AutoArrayHashMapUnmanaged(void, void),
string_bytes: std.ArrayListUnmanaged(u8),
string_indices: std.ArrayListUnmanaged(u32),

types: std.AutoArrayHashMapUnmanaged(String, Type),
next_unnamed_type: String,
next_unique_type_id: std.AutoHashMapUnmanaged(String, u32),
type_map: std.AutoArrayHashMapUnmanaged(void, void),
type_items: std.ArrayListUnmanaged(Type.Item),
type_extra: std.ArrayListUnmanaged(u32),

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

pub const expected_fields_len = 32;
pub const expected_gep_indices_len = 8;
pub const expected_cases_len = 8;
pub const expected_incoming_len = 8;

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

    pub fn toSlice(self: String, b: *const Builder) ?[:0]const u8 {
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
        const slice = data.string.toSlice(data.builder) orelse
            return writer.print("{d}", .{@intFromEnum(data.string)});
        const full_slice = slice[0 .. slice.len + comptime @intFromBool(
            std.mem.indexOfScalar(u8, fmt_str, '@') != null,
        )];
        const need_quotes = (comptime std.mem.indexOfScalar(u8, fmt_str, '"') != null) or
            !isValidIdentifier(full_slice);
        if (need_quotes) try writer.writeByte('"');
        for (full_slice) |character| switch (character) {
            '\\' => try writer.writeAll("\\\\"),
            ' '...'"' - 1, '"' + 1...'\\' - 1, '\\' + 1...'~' => try writer.writeByte(character),
            else => try writer.print("\\{X:0>2}", .{character}),
        };
        if (need_quotes) try writer.writeByte('"');
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
            return std.mem.eql(u8, lhs_key, String.fromIndex(rhs_index).toSlice(ctx.builder).?);
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

    none = std.math.maxInt(u32),
    _,

    pub const err_int = Type.i16;

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
            .ptr => @panic("TODO: query data layout"),
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
        return self.isSizedVisited(&visited, builder);
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
                    try writer.print("t{s}", .{extra.data.name.toSlice(data.builder).?});
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
                    if (extra.id.toSlice(data.builder)) |id| try writer.writeAll(id);
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
            .pointer => try writer.print("ptr{}", .{@as(AddrSpace, @enumFromInt(item.data))}),
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

pub const Linkage = enum {
    external,
    private,
    internal,
    available_externally,
    linkonce,
    weak,
    common,
    appending,
    extern_weak,
    linkonce_odr,
    weak_odr,

    pub fn format(
        self: Linkage,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .external) try writer.print(" {s}", .{@tagName(self)});
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
};

pub const ThreadLocal = enum {
    default,
    generaldynamic,
    localdynamic,
    initialexec,
    localexec,

    pub fn format(
        self: ThreadLocal,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self == .default) return;
        try writer.writeAll(" thread_local");
        if (self != .generaldynamic) {
            try writer.writeByte('(');
            try writer.writeAll(@tagName(self));
            try writer.writeByte(')');
        }
    }
};

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
        pub const flash: AddrSpace = @enumFromInt(1);
        pub const flash1: AddrSpace = @enumFromInt(2);
        pub const flash2: AddrSpace = @enumFromInt(3);
        pub const flash3: AddrSpace = @enumFromInt(4);
        pub const flash4: AddrSpace = @enumFromInt(5);
        pub const flash5: AddrSpace = @enumFromInt(6);
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

    // See llvm/lib/Target/WebAssembly/Utils/WebAssemblyTypeUtilities.h
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
        if (self != .default) try writer.print("{s} addrspace({d})", .{ prefix, @intFromEnum(self) });
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
        try writer.print("{s} align {d}", .{ prefix, self.toByteUnits() orelse return });
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

        pub fn name(self: Index, builder: *const Builder) String {
            return builder.globals.keys()[@intFromEnum(self.unwrap(builder))];
        }

        pub fn ptr(self: Index, builder: *Builder) *Global {
            return &builder.globals.values()[@intFromEnum(self.unwrap(builder))];
        }

        pub fn ptrConst(self: Index, builder: *const Builder) *const Global {
            return &builder.globals.values()[@intFromEnum(self.unwrap(builder))];
        }

        pub fn typeOf(self: Index, builder: *const Builder) Type {
            return self.ptrConst(builder).type;
        }

        pub fn toConst(self: Index) Constant {
            return @enumFromInt(@intFromEnum(Constant.first_global) + @intFromEnum(self));
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
            self.replaceAssumeCapacity(other, builder);
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
            const name_slice = self.name(builder).toSlice(builder) orelse "";
            builder.llvm.globals.items[index].setValueName2(name_slice.ptr, name_slice.len);
        }

        fn replaceAssumeCapacity(self: Index, other: Index, builder: *Builder) void {
            if (self.eql(other, builder)) return;
            builder.next_replaced_global = @enumFromInt(@intFromEnum(builder.next_replaced_global) - 1);
            self.renameAssumeCapacity(builder.next_replaced_global, builder);
            if (builder.useLibLlvm()) {
                const self_llvm = self.toLlvm(builder);
                self_llvm.replaceAllUsesWith(other.toLlvm(builder));
                switch (self.ptr(builder).kind) {
                    .alias,
                    .variable,
                    => self_llvm.deleteGlobal(),
                    .function => self_llvm.deleteFunction(),
                    .replaced => unreachable,
                }
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

    pub fn updateAttributes(self: *Global) void {
        switch (self.linkage) {
            .private, .internal => {
                self.visibility = .default;
                self.dll_storage_class = .default;
                self.preemption = .implicit_dso_local;
            },
            .extern_weak => if (self.preemption == .implicit_dso_local) {
                self.preemption = .dso_local;
            },
            else => switch (self.visibility) {
                .default => if (self.preemption == .implicit_dso_local) {
                    self.preemption = .dso_local;
                },
                else => self.preemption = .implicit_dso_local,
            },
        }
    }
};

pub const Alias = struct {
    global: Global.Index,
    thread_local: ThreadLocal = .default,
    init: Constant = .no_init,

    pub const Index = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn getAliasee(self: Index, builder: *const Builder) Global.Index {
            const aliasee = self.ptrConst(builder).init.getBase(builder);
            assert(aliasee != .none);
            return aliasee;
        }

        pub fn ptr(self: Index, builder: *Builder) *Alias {
            return &builder.aliases.items[@intFromEnum(self)];
        }

        pub fn ptrConst(self: Index, builder: *const Builder) *const Alias {
            return &builder.aliases.items[@intFromEnum(self)];
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

        pub fn toLlvm(self: Index, builder: *const Builder) *llvm.Value {
            return self.ptrConst(builder).global.toLlvm(builder);
        }
    };
};

pub const Variable = struct {
    global: Global.Index,
    thread_local: ThreadLocal = .default,
    mutability: enum { global, constant } = .global,
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

        pub fn typeOf(self: Index, builder: *const Builder) Type {
            return self.ptrConst(builder).global.typeOf(builder);
        }

        pub fn toConst(self: Index, builder: *const Builder) Constant {
            return self.ptrConst(builder).global.toConst();
        }

        pub fn toValue(self: Index, builder: *const Builder) Value {
            return self.toConst(builder).toValue();
        }

        pub fn toLlvm(self: Index, builder: *const Builder) *llvm.Value {
            return self.ptrConst(builder).global.toLlvm(builder);
        }
    };
};

pub const Function = struct {
    global: Global.Index,
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

        pub fn typeOf(self: Index, builder: *const Builder) Type {
            return self.ptrConst(builder).global.typeOf(builder);
        }

        pub fn toConst(self: Index, builder: *const Builder) Constant {
            return self.ptrConst(builder).global.toConst();
        }

        pub fn toValue(self: Index, builder: *const Builder) Value {
            return self.toConst(builder).toValue();
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
            bitcast,
            block,
            br,
            br_cond,
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
            @"llvm.maxnum.",
            @"llvm.minnum.",
            @"llvm.sadd.sat.",
            @"llvm.smax.",
            @"llvm.smin.",
            @"llvm.smul.fix.sat.",
            @"llvm.sshl.sat.",
            @"llvm.ssub.sat.",
            @"llvm.uadd.sat.",
            @"llvm.umax.",
            @"llvm.umin.",
            @"llvm.umul.fix.sat.",
            @"llvm.ushl.sat.",
            @"llvm.usub.sat.",
            load,
            @"load atomic",
            @"load atomic volatile",
            @"load volatile",
            lshr,
            @"lshr exact",
            mul,
            @"mul nsw",
            @"mul nuw",
            @"mul nuw nsw",
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
            @"store atomic volatile",
            @"store volatile",
            sub,
            @"sub nsw",
            @"sub nuw",
            @"sub nuw nsw",
            @"switch",
            trunc,
            udiv,
            @"udiv exact",
            urem,
            uitofp,
            unimplemented,
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
                    .@"store atomic volatile",
                    .@"store volatile",
                    .@"unreachable",
                    => false,
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
                    .@"llvm.maxnum.",
                    .@"llvm.minnum.",
                    .@"llvm.sadd.sat.",
                    .@"llvm.smax.",
                    .@"llvm.smin.",
                    .@"llvm.smul.fix.sat.",
                    .@"llvm.sshl.sat.",
                    .@"llvm.ssub.sat.",
                    .@"llvm.uadd.sat.",
                    .@"llvm.umax.",
                    .@"llvm.umin.",
                    .@"llvm.umul.fix.sat.",
                    .@"llvm.ushl.sat.",
                    .@"llvm.usub.sat.",
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
                    .block => .label,
                    .br,
                    .br_cond,
                    .fence,
                    .ret,
                    .@"ret void",
                    .store,
                    .@"store atomic",
                    .@"store atomic volatile",
                    .@"store volatile",
                    .@"switch",
                    .@"unreachable",
                    => .none,
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
                    .@"load atomic volatile",
                    .@"load volatile",
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
                    .unimplemented => @enumFromInt(instruction.data),
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
                    .@"llvm.maxnum.",
                    .@"llvm.minnum.",
                    .@"llvm.sadd.sat.",
                    .@"llvm.smax.",
                    .@"llvm.smin.",
                    .@"llvm.smul.fix.sat.",
                    .@"llvm.sshl.sat.",
                    .@"llvm.ssub.sat.",
                    .@"llvm.uadd.sat.",
                    .@"llvm.umax.",
                    .@"llvm.umin.",
                    .@"llvm.umul.fix.sat.",
                    .@"llvm.ushl.sat.",
                    .@"llvm.usub.sat.",
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
                    .block => .label,
                    .br,
                    .br_cond,
                    .fence,
                    .ret,
                    .@"ret void",
                    .store,
                    .@"store atomic",
                    .@"store atomic volatile",
                    .@"store volatile",
                    .@"switch",
                    .@"unreachable",
                    => .none,
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
                    .@"load atomic volatile",
                    .@"load volatile",
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
                    .unimplemented => @enumFromInt(instruction.data),
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

            pub fn toLlvm(self: Instruction.Index, wip: *const WipFunction) *llvm.Value {
                assert(wip.builder.useLibLlvm());
                return wip.llvm.instructions.items[@intFromEnum(self)];
            }

            fn llvmName(self: Instruction.Index, wip: *const WipFunction) [*:0]const u8 {
                return if (wip.builder.strip)
                    ""
                else
                    wip.names.items[@intFromEnum(self)].toSlice(wip.builder).?;
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
            type: Type,
            ptr: Value,
            info: MemoryAccessInfo,
        };

        pub const Store = struct {
            val: Value,
            ptr: Value,
            info: MemoryAccessInfo,
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
                Alignment, AtomicOrdering, Block.Index, Type, Value => @enumFromInt(value),
                MemoryAccessInfo, Instruction.Alloca.Info => @bitCast(value),
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
                final_name.toSlice(self.builder).?,
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
            .@"llvm.maxnum.",
            .@"llvm.minnum.",
            .@"llvm.sadd.sat.",
            .@"llvm.smax.",
            .@"llvm.smin.",
            .@"llvm.smul.fix.sat.",
            .@"llvm.sshl.sat.",
            .@"llvm.ssub.sat.",
            .@"llvm.uadd.sat.",
            .@"llvm.umax.",
            .@"llvm.umin.",
            .@"llvm.umul.fix.sat.",
            .@"llvm.ushl.sat.",
            .@"llvm.usub.sat.",
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
                .@"llvm.maxnum." => &llvm.Builder.buildMaxNum,
                .@"llvm.minnum." => &llvm.Builder.buildMinNum,
                .@"llvm.sadd.sat." => &llvm.Builder.buildSAddSat,
                .@"llvm.smax." => &llvm.Builder.buildSMax,
                .@"llvm.smin." => &llvm.Builder.buildSMin,
                .@"llvm.smul.fix.sat." => &llvm.Builder.buildSMulFixSat,
                .@"llvm.sshl.sat." => &llvm.Builder.buildSShlSat,
                .@"llvm.ssub.sat." => &llvm.Builder.buildSSubSat,
                .@"llvm.uadd.sat." => &llvm.Builder.buildUAddSat,
                .@"llvm.umax." => &llvm.Builder.buildUMax,
                .@"llvm.umin." => &llvm.Builder.buildUMin,
                .@"llvm.umul.fix.sat." => &llvm.Builder.buildUMulFixSat,
                .@"llvm.ushl.sat." => &llvm.Builder.buildUShlSat,
                .@"llvm.usub.sat." => &llvm.Builder.buildUSubSat,
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
            if (alignment.toByteUnits()) |a| llvm_instruction.setAlignment(@intCast(a));
            self.llvm.instructions.appendAssumeCapacity(llvm_instruction);
        }
        return instruction.toValue();
    }

    pub fn load(
        self: *WipFunction,
        kind: MemoryAccessKind,
        ty: Type,
        ptr: Value,
        alignment: Alignment,
        name: []const u8,
    ) Allocator.Error!Value {
        return self.loadAtomic(kind, ty, ptr, .system, .none, alignment, name);
    }

    pub fn loadAtomic(
        self: *WipFunction,
        kind: MemoryAccessKind,
        ty: Type,
        ptr: Value,
        scope: SyncScope,
        ordering: AtomicOrdering,
        alignment: Alignment,
        name: []const u8,
    ) Allocator.Error!Value {
        assert(ptr.typeOfWip(self).isPointer(self.builder));
        try self.ensureUnusedExtraCapacity(1, Instruction.Load, 0);
        const instruction = try self.addInst(name, .{
            .tag = switch (ordering) {
                .none => switch (kind) {
                    .normal => .load,
                    .@"volatile" => .@"load volatile",
                },
                else => switch (kind) {
                    .normal => .@"load atomic",
                    .@"volatile" => .@"load atomic volatile",
                },
            },
            .data = self.addExtraAssumeCapacity(Instruction.Load{
                .type = ty,
                .ptr = ptr,
                .info = .{ .scope = switch (ordering) {
                    .none => .system,
                    else => scope,
                }, .ordering = ordering, .alignment = alignment },
            }),
        });
        if (self.builder.useLibLlvm()) {
            const llvm_instruction = self.llvm.builder.buildLoad(
                ty.toLlvm(self.builder),
                ptr.toLlvm(self),
                instruction.llvmName(self),
            );
            if (ordering != .none) llvm_instruction.setOrdering(@enumFromInt(@intFromEnum(ordering)));
            if (alignment.toByteUnits()) |a| llvm_instruction.setAlignment(@intCast(a));
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
        kind: MemoryAccessKind,
        val: Value,
        ptr: Value,
        scope: SyncScope,
        ordering: AtomicOrdering,
        alignment: Alignment,
    ) Allocator.Error!Instruction.Index {
        assert(ptr.typeOfWip(self).isPointer(self.builder));
        try self.ensureUnusedExtraCapacity(1, Instruction.Store, 0);
        const instruction = try self.addInst(null, .{
            .tag = switch (ordering) {
                .none => switch (kind) {
                    .normal => .store,
                    .@"volatile" => .@"store volatile",
                },
                else => switch (kind) {
                    .normal => .@"store atomic",
                    .@"volatile" => .@"store atomic volatile",
                },
            },
            .data = self.addExtraAssumeCapacity(Instruction.Store{
                .val = val,
                .ptr = ptr,
                .info = .{ .scope = switch (ordering) {
                    .none => .system,
                    else => scope,
                }, .ordering = ordering, .alignment = alignment },
            }),
        });
        if (self.builder.useLibLlvm()) {
            const llvm_instruction = self.llvm.builder.buildStore(val.toLlvm(self), ptr.toLlvm(self));
            switch (kind) {
                .normal => {},
                .@"volatile" => llvm_instruction.setVolatile(.True),
            }
            if (ordering != .none) llvm_instruction.setOrdering(@enumFromInt(@intFromEnum(ordering)));
            if (alignment.toByteUnits()) |a| llvm_instruction.setAlignment(@intCast(a));
            self.llvm.instructions.appendAssumeCapacity(llvm_instruction);
        }
        return instruction;
    }

    pub fn fence(
        self: *WipFunction,
        scope: SyncScope,
        ordering: AtomicOrdering,
    ) Allocator.Error!Instruction.Index {
        assert(ordering != .none);
        try self.ensureUnusedExtraCapacity(1, NoExtra, 0);
        const instruction = try self.addInst(null, .{
            .tag = .fence,
            .data = @bitCast(MemoryAccessInfo{
                .scope = scope,
                .ordering = ordering,
                .alignment = undefined,
            }),
        });
        if (self.builder.useLibLlvm()) self.llvm.instructions.appendAssumeCapacity(
            self.llvm.builder.buildFence(
                @enumFromInt(@intFromEnum(ordering)),
                llvm.Bool.fromBool(scope == .singlethread),
                "",
            ),
        );
        return instruction;
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
        cond: FloatCondition,
        lhs: Value,
        rhs: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        return self.cmpTag(switch (cond) {
            inline else => |tag| @field(Instruction.Tag, "fcmp " ++ @tagName(tag)),
        }, @intFromEnum(cond), lhs, rhs, name);
    }

    pub fn fcmpFast(
        self: *WipFunction,
        cond: FloatCondition,
        lhs: Value,
        rhs: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        return self.cmpTag(switch (cond) {
            inline else => |tag| @field(Instruction.Tag, "fcmp fast " ++ @tagName(tag)),
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
        ) if (build_options.have_llvm) Allocator.Error!void else void {
            const incoming_len = self.block.ptrConst(wip).incoming;
            assert(vals.len == incoming_len and blocks.len == incoming_len);
            const instruction = wip.instructions.get(@intFromEnum(self.instruction));
            var extra = wip.extraDataTrail(Instruction.Phi, instruction.data);
            for (vals) |val| assert(val.typeOfWip(wip) == extra.data.type);
            @memcpy(extra.trail.nextMut(incoming_len, Value, wip), vals);
            @memcpy(extra.trail.nextMut(incoming_len, Block.Index, wip), blocks);
            if (wip.builder.useLibLlvm()) {
                const ExpectedContents = extern struct {
                    [expected_incoming_len]*llvm.Value,
                    [expected_incoming_len]*llvm.BasicBlock,
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
        cond: Value,
        lhs: Value,
        rhs: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        return self.selectTag(.select, cond, lhs, rhs, name);
    }

    pub fn selectFast(
        self: *WipFunction,
        cond: Value,
        lhs: Value,
        rhs: Value,
        name: []const u8,
    ) Allocator.Error!Value {
        return self.selectTag(.@"select fast", cond, lhs, rhs, name);
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

    pub const WipUnimplemented = struct {
        instruction: Instruction.Index,

        pub fn finish(self: WipUnimplemented, val: *llvm.Value, wip: *WipFunction) Value {
            assert(wip.builder.useLibLlvm());
            wip.llvm.instructions.items[@intFromEnum(self.instruction)] = val;
            return self.instruction.toValue();
        }
    };

    pub fn unimplemented(
        self: *WipFunction,
        ty: Type,
        name: []const u8,
    ) Allocator.Error!WipUnimplemented {
        try self.ensureUnusedExtraCapacity(1, NoExtra, 0);
        const instruction = try self.addInst(name, .{
            .tag = .unimplemented,
            .data = @intFromEnum(ty),
        });
        if (self.builder.useLibLlvm()) _ = self.llvm.instructions.addOneAssumeCapacity();
        return .{ .instruction = instruction };
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
                        Alignment, AtomicOrdering, Block.Index, Type, Value => @intFromEnum(value),
                        MemoryAccessInfo, Instruction.Alloca.Info => @bitCast(value),
                        else => @compileError("bad field type: " ++ @typeName(field.type)),
                    };
                    wip_extra.index += 1;
                }
                return result;
            }

            fn appendSlice(wip_extra: *@This(), slice: anytype) void {
                if (@typeInfo(@TypeOf(slice)).Pointer.child == Value) @compileError("use appendValues");
                const data: []const u32 = @ptrCast(slice);
                @memcpy(wip_extra.items[wip_extra.index..][0..data.len], data);
                wip_extra.index += @intCast(data.len);
            }

            fn appendValues(wip_extra: *@This(), vals: []const Value, ctx: anytype) void {
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
                    .@"llvm.maxnum.",
                    .@"llvm.minnum.",
                    .@"llvm.sadd.sat.",
                    .@"llvm.smax.",
                    .@"llvm.smin.",
                    .@"llvm.smul.fix.sat.",
                    .@"llvm.sshl.sat.",
                    .@"llvm.ssub.sat.",
                    .@"llvm.uadd.sat.",
                    .@"llvm.umax.",
                    .@"llvm.umin.",
                    .@"llvm.umul.fix.sat.",
                    .@"llvm.ushl.sat.",
                    .@"llvm.usub.sat.",
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
                    .br,
                    .fence,
                    .@"ret void",
                    .unimplemented,
                    .@"unreachable",
                    => {},
                    .extractelement => {
                        const extra = self.extraData(Instruction.ExtractElement, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.ExtractElement{
                            .val = instructions.map(extra.val),
                            .index = instructions.map(extra.index),
                        });
                    },
                    .br_cond => {
                        const extra = self.extraData(Instruction.BrCond, instruction.data);
                        instruction.data = wip_extra.addExtra(Instruction.BrCond{
                            .cond = instructions.map(extra.cond),
                            .then = extra.then,
                            .@"else" = extra.@"else",
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
                        wip_extra.appendValues(indices, instructions);
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
                    .@"load atomic volatile",
                    .@"load volatile",
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
                        wip_extra.appendValues(incoming_vals, instructions);
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
                    .@"store atomic volatile",
                    .@"store volatile",
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
                Alignment, AtomicOrdering, Block.Index, Type, Value => @intFromEnum(value),
                MemoryAccessInfo, Instruction.Alloca.Info => @bitCast(value),
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
                Alignment, AtomicOrdering, Block.Index, Type, Value => @enumFromInt(value),
                MemoryAccessInfo, Instruction.Alloca.Info => @bitCast(value),
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
            \\{s} syncscope("{s}")
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
        if (self != .none) try writer.print("{s} {s}", .{ prefix, @tagName(self) });
    }
};

const MemoryAccessInfo = packed struct(u32) {
    scope: SyncScope,
    ordering: AtomicOrdering,
    alignment: Alignment,
    _: u22 = undefined,
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

pub const Constant = enum(u32) {
    false,
    true,
    none,
    no_init = 1 << 31,
    _,

    const first_global: Constant = @enumFromInt(1 << 30);

    pub const Tag = enum(u6) {
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
        return @enumFromInt(@intFromEnum(Value.first_constant) + @intFromEnum(self));
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
                        @as(String, @enumFromInt(item.data)).toSlice(builder).?.len +
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
                .alias => |alias| cur = alias.ptrConst(builder).init,
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
                    .float => try writer.print("0x{X:0>16}", .{
                        @as(u64, @bitCast(@as(f64, @as(f32, @bitCast(item.data))))),
                    }),
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
        return switch (self.unwrap()) {
            .constant => |constant| builder.llvm.constants.items[constant],
            .global => |global| global.toLlvm(builder),
        };
    }
};

pub const Value = enum(u32) {
    none = std.math.maxInt(u31),
    _,

    const first_constant: Value = @enumFromInt(1 << 31);

    pub fn unwrap(self: Value) union(enum) {
        instruction: Function.Instruction.Index,
        constant: Constant,
    } {
        return if (@intFromEnum(self) < @intFromEnum(first_constant))
            .{ .instruction = @enumFromInt(@intFromEnum(self)) }
        else
            .{ .constant = @enumFromInt(@intFromEnum(self) - @intFromEnum(first_constant)) };
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

        .string_map = .{},
        .string_bytes = .{},
        .string_indices = .{},

        .types = .{},
        .next_unnamed_type = @enumFromInt(0),
        .next_unique_type_id = .{},
        .type_map = .{},
        .type_items = .{},
        .type_extra = .{},

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
    if (self.useLibLlvm()) self.llvm = .{ .context = llvm.Context.create() };
    errdefer self.deinit();

    try self.string_indices.append(self.gpa, 0);
    assert(try self.string("") == .empty);

    if (options.name.len > 0) self.source_filename = try self.string(options.name);
    self.initializeLLVMTarget(options.target.cpu.arch);
    if (self.useLibLlvm()) self.llvm.module = llvm.Module.createWithName(
        (self.source_filename.toSlice(&self) orelse "").ptr,
        self.llvm.context,
    );

    if (options.triple.len > 0) {
        self.target_triple = try self.string(options.triple);

        if (self.useLibLlvm()) {
            var error_message: [*:0]const u8 = undefined;
            var target: *llvm.Target = undefined;
            if (llvm.Target.getFromTriple(
                self.target_triple.toSlice(&self).?,
                &target,
                &error_message,
            ).toBool()) {
                defer llvm.disposeMessage(error_message);

                log.err("LLVM failed to parse '{s}': {s}", .{
                    self.target_triple.toSlice(&self).?,
                    error_message,
                });
                return InitError.InvalidLlvmTriple;
            }
            self.llvm.target = target;
            self.llvm.module.?.setTarget(self.target_triple.toSlice(&self).?);
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
        inline for (.{0}) |addr_space|
            assert(self.ptrTypeAssumeCapacity(@enumFromInt(addr_space)) == .ptr);
    }

    assert(try self.intConst(.i1, 0) == .false);
    assert(try self.intConst(.i1, 1) == .true);
    assert(try self.noneConst(.token) == .none);

    return self;
}

pub fn deinit(self: *Builder) void {
    self.string_map.deinit(self.gpa);
    self.string_bytes.deinit(self.gpa);
    self.string_indices.deinit(self.gpa);

    self.types.deinit(self.gpa);
    self.next_unique_type_id.deinit(self.gpa);
    self.type_map.deinit(self.gpa);
    self.type_items.deinit(self.gpa);
    self.type_extra.deinit(self.gpa);

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

    if (self.useLibLlvm()) {
        self.llvm.constants.deinit(self.gpa);
        self.llvm.globals.deinit(self.gpa);
        self.llvm.types.deinit(self.gpa);
        if (self.llvm.di_builder) |di_builder| di_builder.dispose();
        if (self.llvm.module) |module| module.dispose();
        self.llvm.context.dispose();
    }
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
                llvm.LLVMInitializeXtensaAsmPrinter();
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
    return switch (kind) {
        inline else => |comptime_kind| self.fnTypeAssumeCapacity(ret, params, comptime_kind),
    };
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
    return switch (kind) {
        inline else => |comptime_kind| self.vectorTypeAssumeCapacity(comptime_kind, len, child),
    };
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
    return switch (kind) {
        inline else => |comptime_kind| self.structTypeAssumeCapacity(comptime_kind, fields),
    };
}

pub fn opaqueType(self: *Builder, name: String) Allocator.Error!Type {
    try self.string_map.ensureUnusedCapacity(self.gpa, 1);
    if (name.toSlice(self)) |id| {
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
) if (build_options.have_llvm) Allocator.Error!void else void {
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
            global_gop.value_ptr.updateAttributes();
            const index: Global.Index = @enumFromInt(global_gop.index);
            index.updateName(self);
            return index;
        }

        const unique_gop = self.next_unique_global_id.getOrPutAssumeCapacity(name);
        if (!unique_gop.found_existing) unique_gop.value_ptr.* = 2;
        id = self.fmtAssumeCapacity("{s}.{d}", .{ name.toSlice(self).?, unique_gop.value_ptr.* });
        unique_gop.value_ptr.* += 1;
    }
}

pub fn getGlobal(self: *const Builder, name: String) ?Global.Index {
    return @enumFromInt(self.globals.getIndex(name) orelse return null);
}

pub fn intConst(self: *Builder, ty: Type, value: anytype) Allocator.Error!Constant {
    var limbs: [
        switch (@typeInfo(@TypeOf(value))) {
            .Int => |info| std.math.big.int.calcTwosCompLimbCount(info.bits),
            .ComptimeInt => std.math.big.int.calcLimbLen(value),
            else => @compileError("intConst expected an integral value, got " ++
                @typeName(@TypeOf(value))),
        }
    ]std.math.big.Limb = undefined;
    return self.bigIntConst(ty, std.math.big.int.Mutable.init(&limbs, value).toConst());
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
    if (self.source_filename != .none) try writer.print(
        \\; ModuleID = '{s}'
        \\source_filename = {"}
        \\
    , .{ self.source_filename.toSlice(self).?, self.source_filename.fmt(self) });
    if (self.data_layout != .none) try writer.print(
        \\target datalayout = {"}
        \\
    , .{self.data_layout.fmt(self)});
    if (self.target_triple != .none) try writer.print(
        \\target triple = {"}
        \\
    , .{self.target_triple.fmt(self)});
    try writer.writeByte('\n');
    for (self.types.keys(), self.types.values()) |id, ty| try writer.print(
        \\%{} = type {}
        \\
    , .{ id.fmt(self), ty.fmt(self) });
    try writer.writeByte('\n');
    for (self.variables.items) |variable| {
        if (variable.global.getReplacement(self) != .none) continue;
        const global = variable.global.ptrConst(self);
        try writer.print(
            \\{} ={}{}{}{}{}{}{}{} {s} {%}{ }{,}
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
    try writer.writeByte('\n');
    for (0.., self.functions.items) |function_i, function| {
        const function_index: Function.Index = @enumFromInt(function_i);
        if (function.global.getReplacement(self) != .none) continue;
        const global = function.global.ptrConst(self);
        const params_len = global.type.functionParameters(self).len;
        try writer.print(
            \\{s}{}{}{}{} {} {}(
        , .{
            if (function.instructions.len > 0) "define" else "declare",
            global.linkage,
            global.preemption,
            global.visibility,
            global.dll_storage_class,
            global.type.functionReturn(self).fmt(self),
            function.global.fmt(self),
        });
        for (0..params_len) |arg| {
            if (arg > 0) try writer.writeAll(", ");
            if (function.instructions.len > 0)
                try writer.print("{%}", .{function.arg(@intCast(arg)).fmt(function_index, self)})
            else
                try writer.print("{%}", .{global.type.functionParameters(self)[arg].fmt(self)});
        }
        switch (global.type.functionKind(self)) {
            .normal => {},
            .vararg => {
                if (params_len > 0) try writer.writeAll(", ");
                try writer.writeAll("...");
            },
        }
        try writer.print("){}{}", .{ global.unnamed_addr, function.alignment });
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
                        try writer.print("  %{} = {s} {%}{,%}{,}{,}\n", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.type.fmt(self),
                            extra.len.fmt(function_index, self),
                            extra.info.alignment,
                            extra.info.addr_space,
                        });
                    },
                    .arg => unreachable,
                    .block => {
                        block_incoming_len = instruction.data;
                        const name = instruction_index.name(&function);
                        if (@intFromEnum(instruction_index) > params_len) try writer.writeByte('\n');
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
                        var extra =
                            function.extraDataTrail(Function.Instruction.ExtractValue, instruction.data);
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
                        try writer.print("  {s}{}{}", .{ @tagName(tag), info.scope, info.ordering });
                    },
                    .fneg,
                    .@"fneg fast",
                    .ret,
                    => |tag| {
                        const val: Value = @enumFromInt(instruction.data);
                        try writer.print("  {s} {%}\n", .{
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
                    .@"llvm.maxnum.",
                    .@"llvm.minnum.",
                    .@"llvm.sadd.sat.",
                    .@"llvm.smax.",
                    .@"llvm.smin.",
                    .@"llvm.smul.fix.sat.",
                    .@"llvm.sshl.sat.",
                    .@"llvm.ssub.sat.",
                    .@"llvm.uadd.sat.",
                    .@"llvm.umax.",
                    .@"llvm.umin.",
                    .@"llvm.umul.fix.sat.",
                    .@"llvm.ushl.sat.",
                    .@"llvm.usub.sat.",
                    => |tag| {
                        const extra = function.extraData(Function.Instruction.Binary, instruction.data);
                        const ty = instruction_index.typeOf(function_index, self);
                        try writer.print("  %{} = call {%} @{s}{m}({%}, {%})\n", .{
                            instruction_index.name(&function).fmt(self),
                            ty.fmt(self),
                            @tagName(tag),
                            ty.fmt(self),
                            extra.lhs.fmt(function_index, self),
                            extra.rhs.fmt(function_index, self),
                        });
                    },
                    .load,
                    .@"load atomic",
                    .@"load atomic volatile",
                    .@"load volatile",
                    => |tag| {
                        const extra = function.extraData(Function.Instruction.Load, instruction.data);
                        try writer.print("  %{} = {s} {%}, {%}{}{}{,}\n", .{
                            instruction_index.name(&function).fmt(self),
                            @tagName(tag),
                            extra.type.fmt(self),
                            extra.ptr.fmt(function_index, self),
                            extra.info.scope,
                            extra.info.ordering,
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
                    .@"store atomic volatile",
                    .@"store volatile",
                    => |tag| {
                        const extra = function.extraData(Function.Instruction.Store, instruction.data);
                        try writer.print("  {s} {%}, {%}{}{}{,}\n", .{
                            @tagName(tag),
                            extra.val.fmt(function_index, self),
                            extra.ptr.fmt(function_index, self),
                            extra.info.scope,
                            extra.info.ordering,
                            extra.info.alignment,
                        });
                    },
                    .@"switch" => |tag| {
                        var extra =
                            function.extraDataTrail(Function.Instruction.Switch, instruction.data);
                        const vals = extra.trail.next(extra.data.cases_len, Constant, &function);
                        const blocks =
                            extra.trail.next(extra.data.cases_len, Function.Block.Index, &function);
                        try writer.print("  {s} {%}, {%} [", .{
                            @tagName(tag),
                            extra.data.val.fmt(function_index, self),
                            extra.data.default.toInst(&function).fmt(function_index, self),
                        });
                        for (vals, blocks) |case_val, case_block| try writer.print("    {%}, {%}\n", .{
                            case_val.fmt(self),
                            case_block.toInst(&function).fmt(function_index, self),
                        });
                        try writer.writeAll("  ]\n");
                    },
                    .unimplemented => |tag| {
                        const ty: Type = @enumFromInt(instruction.data);
                        try writer.writeAll("  ");
                        switch (ty) {
                            .none, .void => {},
                            else => try writer.print("%{} = ", .{
                                instruction_index.name(&function).fmt(self),
                            }),
                        }
                        try writer.print("{s} {%}\n", .{ @tagName(tag), ty.fmt(self) });
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
        try writer.writeAll("\n\n");
    }
}

pub inline fn useLibLlvm(self: *const Builder) bool {
    return build_options.have_llvm and self.use_lib_llvm;
}

const NoExtra = struct {};

fn isValidIdentifier(id: []const u8) bool {
    for (id, 0..) |character, index| switch (character) {
        '$', '-', '.', 'A'...'Z', '_', 'a'...'z' => {},
        '0'...'9' => if (index == 0) return false,
        else => return false,
    };
    return true;
}

fn ensureUnusedGlobalCapacity(self: *Builder, name: String) Allocator.Error!void {
    if (self.useLibLlvm()) try self.llvm.globals.ensureUnusedCapacity(self.gpa, 1);
    try self.string_map.ensureUnusedCapacity(self.gpa, 1);
    if (name.toSlice(self)) |id| {
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
) if (build_options.have_llvm) Allocator.Error!Type else Type {
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
            .tag = .function,
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
            .normal => llvm.Type.vectorType,
            .scalable => llvm.Type.scalableVectorType,
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
                child.toLlvm(self).arrayType(@intCast(len)),
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
                child.toLlvm(self).arrayType(@intCast(len)),
            );
        }
        return @enumFromInt(gop.index);
    }
}

fn structTypeAssumeCapacity(
    self: *Builder,
    comptime kind: Type.Structure.Kind,
    fields: []const Type,
) if (build_options.have_llvm) Allocator.Error!Type else Type {
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
                self.llvm.context.structCreateNamed(id.toSlice(self) orelse ""),
            );
            return result;
        }

        const unique_gop = self.next_unique_type_id.getOrPutAssumeCapacity(name);
        if (!unique_gop.found_existing) unique_gop.value_ptr.* = 2;
        id = self.fmtAssumeCapacity("{s}.{d}", .{ name.toSlice(self).?, unique_gop.value_ptr.* });
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

fn bigIntConstAssumeCapacity(
    self: *Builder,
    ty: Type,
    value: std.math.big.int.Const,
) if (build_options.have_llvm) Allocator.Error!Constant else Constant {
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
            const llvm_limbs: *const [2]u64 = @ptrCast(&val);
            self.llvm.constants.appendAssumeCapacity(
                Type.i128.toLlvm(self)
                    .constIntOfArbitraryPrecision(@intCast(llvm_limbs.len), llvm_limbs)
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
) if (build_options.have_llvm) Allocator.Error!Constant else Constant {
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
) if (build_options.have_llvm) Allocator.Error!Constant else Constant {
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
            type_extra.child.toLlvm(self).constArray(llvm_vals.ptr, @intCast(llvm_vals.len)),
        );
    }
    return result.constant;
}

fn stringConstAssumeCapacity(self: *Builder, val: String) Constant {
    const slice = val.toSlice(self).?;
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
    const slice = val.toSlice(self).?;
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
) if (build_options.have_llvm) Allocator.Error!Constant else Constant {
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
) if (build_options.have_llvm) Allocator.Error!Constant else Constant {
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
) if (build_options.have_llvm) Allocator.Error!Constant else Constant {
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
                .normal => llvm.Type.constGEP,
                .inbounds => llvm.Type.constInBoundsGEP,
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
            llvm.constICmp(@enumFromInt(@intFromEnum(cond)), lhs.toLlvm(self), rhs.toLlvm(self)),
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
            llvm.constFCmp(@enumFromInt(@intFromEnum(cond)), lhs.toLlvm(self), rhs.toLlvm(self)),
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
    const Key = struct { tag: Constant.Tag, bin: Constant.Binary };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Key) u32 {
            return @truncate(std.hash.Wyhash.hash(
                std.hash.uint32(@intFromEnum(key.tag)),
                std.mem.asBytes(&key.bin),
            ));
        }
        pub fn eql(ctx: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            if (lhs_key.tag != ctx.builder.constant_items.items(.tag)[rhs_index]) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraData(Constant.Binary, rhs_data);
            return std.meta.eql(lhs_key.bin, rhs_extra);
        }
    };
    const data = Key{ .tag = tag, .bin = .{ .lhs = lhs, .rhs = rhs } };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = tag,
            .data = self.addConstantExtraAssumeCapacity(data.bin),
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
            Type, Constant, Function.Index, Function.Block.Index => @intFromEnum(value),
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
            Type, Constant, Function.Index, Function.Block.Index => @enumFromInt(value),
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
