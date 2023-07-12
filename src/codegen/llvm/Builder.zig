gpa: Allocator,
use_lib_llvm: bool,

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

source_filename: String = .none,
data_layout: String = .none,
target_triple: String = .none,

string_map: std.AutoArrayHashMapUnmanaged(void, void) = .{},
string_bytes: std.ArrayListUnmanaged(u8) = .{},
string_indices: std.ArrayListUnmanaged(u32) = .{},

types: std.AutoArrayHashMapUnmanaged(String, Type) = .{},
next_unnamed_type: String = @enumFromInt(0),
next_unique_type_id: std.AutoHashMapUnmanaged(String, u32) = .{},
type_map: std.AutoArrayHashMapUnmanaged(void, void) = .{},
type_items: std.ArrayListUnmanaged(Type.Item) = .{},
type_extra: std.ArrayListUnmanaged(u32) = .{},

globals: std.AutoArrayHashMapUnmanaged(String, Global) = .{},
next_unnamed_global: String = @enumFromInt(0),
next_replaced_global: String = .none,
next_unique_global_id: std.AutoHashMapUnmanaged(String, u32) = .{},
aliases: std.ArrayListUnmanaged(Alias) = .{},
variables: std.ArrayListUnmanaged(Variable) = .{},
functions: std.ArrayListUnmanaged(Function) = .{},

constant_map: std.AutoArrayHashMapUnmanaged(void, void) = .{},
constant_items: std.MultiArrayList(Constant.Item) = .{},
constant_extra: std.ArrayListUnmanaged(u32) = .{},
constant_limbs: std.ArrayListUnmanaged(std.math.big.Limb) = .{},

pub const expected_fields_len = 32;
pub const expected_gep_indices_len = 8;

pub const Options = struct {
    allocator: Allocator,
    use_lib_llvm: bool = false,
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

        pub const Kind = enum { normal, vararg };
    };

    pub const Target = extern struct {
        name: String,
        types_len: u32,
        ints_len: u32,
    };

    pub const Vector = extern struct {
        len: u32,
        child: Type,

        pub const Kind = enum { normal, scalable };
    };

    pub const Array = extern struct {
        len_lo: u32,
        len_hi: u32,
        child: Type,

        fn len(self: Array) u64 {
            return @as(u64, self.len_hi) << 32 | self.len_lo;
        }
    };

    pub const Structure = struct {
        fields_len: u32,

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

    pub fn vectorLen(self: Type, builder: *const Builder) u32 {
        const item = builder.type_items.items[@intFromEnum(self)];
        return switch (item.tag) {
            .vector,
            .scalable_vector,
            => builder.typeExtraData(Type.Vector, item.data).len,
            else => unreachable,
        };
    }

    pub fn aggregateLen(self: Type, builder: *const Builder) u64 {
        const item = builder.type_items.items[@intFromEnum(self)];
        return switch (item.tag) {
            .vector,
            .scalable_vector,
            .small_array,
            => builder.typeExtraData(Type.Vector, item.data).len,
            .array => builder.typeExtraData(Type.Array, item.data).len(),
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
                const extra = builder.typeExtraDataTrail(Type.Structure, item.data);
                return @ptrCast(builder.type_extra.items[extra.end..][0..extra.data.fields_len]);
            },
            .named_structure => return builder.typeExtraData(Type.NamedStructure, item.data).body
                .structFields(builder),
            else => unreachable,
        }
    }

    pub const FormatData = struct {
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
        if (std.enums.tagName(Type, data.type)) |name| return writer.writeAll(name);
        const item = data.builder.type_items.items[@intFromEnum(data.type)];
        switch (item.tag) {
            .simple => unreachable,
            .function, .vararg_function => {
                const extra = data.builder.typeExtraDataTrail(Type.Function, item.data);
                const params: []const Type =
                    @ptrCast(data.builder.type_extra.items[extra.end..][0..extra.data.params_len]);
                if (!comptime std.mem.eql(u8, fmt_str, ">"))
                    try writer.print("{%} ", .{extra.data.ret.fmt(data.builder)});
                if (!comptime std.mem.eql(u8, fmt_str, "<")) {
                    try writer.writeByte('(');
                    for (params, 0..) |param, index| {
                        if (index > 0) try writer.writeAll(", ");
                        try writer.print("{%}", .{param.fmt(data.builder)});
                    }
                    switch (item.tag) {
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
                const extra = data.builder.typeExtraDataTrail(Type.Target, item.data);
                const types: []const Type =
                    @ptrCast(data.builder.type_extra.items[extra.end..][0..extra.data.types_len]);
                const ints: []const u32 = @ptrCast(data.builder.type_extra.items[extra.end +
                    extra.data.types_len ..][0..extra.data.ints_len]);
                try writer.print(
                    \\target({"}
                , .{extra.data.name.fmt(data.builder)});
                for (types) |ty| try writer.print(", {%}", .{ty.fmt(data.builder)});
                for (ints) |int| try writer.print(", {d}", .{int});
                try writer.writeByte(')');
            },
            .vector => {
                const extra = data.builder.typeExtraData(Type.Vector, item.data);
                try writer.print("<{d} x {%}>", .{ extra.len, extra.child.fmt(data.builder) });
            },
            .scalable_vector => {
                const extra = data.builder.typeExtraData(Type.Vector, item.data);
                try writer.print("<vscale x {d} x {%}>", .{ extra.len, extra.child.fmt(data.builder) });
            },
            .small_array => {
                const extra = data.builder.typeExtraData(Type.Vector, item.data);
                try writer.print("[{d} x {%}]", .{ extra.len, extra.child.fmt(data.builder) });
            },
            .array => {
                const extra = data.builder.typeExtraData(Type.Array, item.data);
                try writer.print("[{d} x {%}]", .{ extra.len(), extra.child.fmt(data.builder) });
            },
            .structure,
            .packed_structure,
            => {
                const extra = data.builder.typeExtraDataTrail(Type.Structure, item.data);
                const fields: []const Type =
                    @ptrCast(data.builder.type_extra.items[extra.end..][0..extra.data.fields_len]);
                switch (item.tag) {
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
                switch (item.tag) {
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
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .default) try writer.print(" addrspace({d})", .{@intFromEnum(self)});
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
    section: String = .none,
    partition: String = .none,
    alignment: Alignment = .default,
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

    pub const Index = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn ptr(self: Index, builder: *Builder) *Alias {
            return &builder.aliases.items[@intFromEnum(self)];
        }

        pub fn ptrConst(self: Index, builder: *const Builder) *const Alias {
            return &builder.aliases.items[@intFromEnum(self)];
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

    pub const Index = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn ptr(self: Index, builder: *Builder) *Variable {
            return &builder.variables.items[@intFromEnum(self)];
        }

        pub fn ptrConst(self: Index, builder: *const Builder) *const Variable {
            return &builder.variables.items[@intFromEnum(self)];
        }

        pub fn toLlvm(self: Index, builder: *const Builder) *llvm.Value {
            return self.ptrConst(builder).global.toLlvm(builder);
        }
    };
};

pub const Function = struct {
    global: Global.Index,
    body: ?void = null,
    instructions: std.ArrayListUnmanaged(Instruction) = .{},
    blocks: std.ArrayListUnmanaged(Block) = .{},

    pub const Index = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn ptr(self: Index, builder: *Builder) *Function {
            return &builder.functions.items[@intFromEnum(self)];
        }

        pub fn ptrConst(self: Index, builder: *const Builder) *const Function {
            return &builder.functions.items[@intFromEnum(self)];
        }

        pub fn toLlvm(self: Index, builder: *const Builder) *llvm.Value {
            return self.ptrConst(builder).global.toLlvm(builder);
        }
    };

    pub const Instruction = struct {
        tag: Tag,

        pub const Tag = enum {
            arg,
            block,
        };

        pub const Index = enum(u32) { _ };
    };

    pub const Block = struct {
        body: std.ArrayListUnmanaged(Instruction.Index) = .{},

        pub const Index = enum(u32) { _ };
    };

    pub fn deinit(self: *Function, gpa: Allocator) void {
        self.instructions.deinit(gpa);
        self.blocks.deinit(gpa);
        self.* = undefined;
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
    };

    pub const Splat = extern struct {
        type: Type,
        value: Constant,
    };

    pub const BlockAddress = extern struct {
        function: Function.Index,
        block: Function.Block.Index,
    };

    pub const FunctionReference = struct {
        function: Function.Index,
    };

    pub const Cast = extern struct {
        arg: Constant,
        type: Type,

        pub const Signedness = enum { unsigned, signed, unneeded };
    };

    pub const GetElementPtr = struct {
        type: Type,
        base: Constant,
        indices_len: u32,

        pub const Kind = enum { normal, inbounds };
    };

    pub const Compare = extern struct {
        cond: u32,
        lhs: Constant,
        rhs: Constant,
    };

    pub const ExtractElement = extern struct {
        arg: Constant,
        index: Constant,
    };

    pub const InsertElement = extern struct {
        arg: Constant,
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
                    => builder.ptrTypeAssumeCapacity(
                        builder.constantExtraData(FunctionReference, item.data)
                            .function.ptrConst(builder).global.ptrConst(builder).addr_space,
                    ),
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
                        const extra = builder.constantExtraDataTrail(GetElementPtr, item.data);
                        const indices: []const Constant = @ptrCast(builder.constant_extra
                            .items[extra.end..][0..extra.data.indices_len]);
                        const base_ty = extra.data.base.typeOf(builder);
                        if (!base_ty.isVector(builder)) for (indices) |index| {
                            const index_ty = index.typeOf(builder);
                            if (!index_ty.isVector(builder)) continue;
                            switch (index_ty.vectorKind(builder)) {
                                inline else => |kind| return builder.vectorTypeAssumeCapacity(
                                    kind,
                                    index_ty.vectorLen(builder),
                                    base_ty,
                                ),
                            }
                        };
                        return base_ty;
                    },
                    .icmp, .fcmp => {
                        const ty = builder.constantExtraData(Compare, item.data).lhs.typeOf(builder);
                        return if (ty.isVector(builder)) switch (ty.vectorKind(builder)) {
                            inline else => |kind| builder
                                .vectorTypeAssumeCapacity(kind, ty.vectorLen(builder), .i1),
                        } else ty;
                    },
                    .extractelement => builder.constantExtraData(ExtractElement, item.data)
                        .arg.typeOf(builder).childType(builder),
                    .insertelement => builder.constantExtraData(InsertElement, item.data)
                        .arg.typeOf(builder),
                    .shufflevector => {
                        const extra = builder.constantExtraData(ShuffleVector, item.data);
                        const ty = extra.lhs.typeOf(builder);
                        return switch (ty.vectorKind(builder)) {
                            inline else => |kind| builder.vectorTypeAssumeCapacity(
                                kind,
                                extra.mask.typeOf(builder).vectorLen(builder),
                                ty.childType(builder),
                            ),
                        };
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
                        const extra = builder.constantExtraDataTrail(Aggregate, item.data);
                        const len = extra.data.type.aggregateLen(builder);
                        const vals: []const Constant =
                            @ptrCast(builder.constant_extra.items[extra.end..][0..len]);
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

    pub const FormatData = struct {
        constant: Constant,
        builder: *Builder,
    };
    fn format(
        data: FormatData,
        comptime fmt_str: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (comptime std.mem.eql(u8, fmt_str, "%")) {
            try writer.print("{%} ", .{data.constant.typeOf(data.builder).fmt(data.builder)});
        } else if (comptime std.mem.eql(u8, fmt_str, " ")) {
            if (data.constant == .no_init) return;
            try writer.writeByte(' ');
        }
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
                        const extra = data.builder.constantExtraDataTrail(Aggregate, item.data);
                        const len = extra.data.type.aggregateLen(data.builder);
                        const vals: []const Constant =
                            @ptrCast(data.builder.constant_extra.items[extra.end..][0..len]);
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
                        const extra = data.builder.constantExtraData(FunctionReference, item.data);
                        try writer.print("{s} {}", .{
                            @tagName(tag),
                            extra.function.ptrConst(data.builder).global.fmt(data.builder),
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
                            extra.arg.fmt(data.builder),
                            extra.type.fmt(data.builder),
                        });
                    },
                    .getelementptr,
                    .@"getelementptr inbounds",
                    => |tag| {
                        const extra = data.builder.constantExtraDataTrail(GetElementPtr, item.data);
                        const indices: []const Constant = @ptrCast(data.builder.constant_extra
                            .items[extra.end..][0..extra.data.indices_len]);
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
                            extra.arg.fmt(data.builder),
                            extra.index.fmt(data.builder),
                        });
                    },
                    .insertelement => |tag| {
                        const extra = data.builder.constantExtraData(InsertElement, item.data);
                        try writer.print("{s} ({%}, {%}, {%})", .{
                            @tagName(tag),
                            extra.arg.fmt(data.builder),
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
    _,

    const first_constant: Value = @enumFromInt(1 << 31);

    pub fn unwrap(self: Value) union(enum) {
        instruction: Function.Instruction.Index,
        constant: Constant,
    } {
        return if (@intFromEnum(self) < @intFromEnum(first_constant))
            .{ .instruction = @intFromEnum(self) }
        else
            .{ .constant = @enumFromInt(@intFromEnum(self) - @intFromEnum(first_constant)) };
    }
};

pub const InitError = error{
    InvalidLlvmTriple,
} || Allocator.Error;

pub fn init(options: Options) InitError!Builder {
    var self = Builder{
        .gpa = options.allocator,
        .use_lib_llvm = options.use_lib_llvm,
        .llvm = undefined,
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
                self.target_triple.toSlice(&self).?.ptr,
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
            self.llvm.module.?.setTarget(self.target_triple.toSlice(&self).?.ptr);
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
    try self.string_bytes.ensureUnusedCapacity(self.gpa, std.fmt.count(fmt_str ++ .{0}, fmt_args));
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
    try self.ensureUnusedTypeCapacity(1, null, 0);
    return self.intTypeAssumeCapacity(bits);
}

pub fn ptrType(self: *Builder, addr_space: AddrSpace) Allocator.Error!Type {
    try self.ensureUnusedTypeCapacity(1, null, 0);
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
    if (name.toSlice(self)) |id| try self.string_bytes.ensureUnusedCapacity(self.gpa, id.len +
        comptime std.fmt.count("{d}" ++ .{0}, .{std.math.maxInt(u32)}));
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
        const body_extra = self.typeExtraDataTrail(Type.Structure, body_item.data);
        const body_fields: []const Type =
            @ptrCast(self.type_extra.items[body_extra.end..][0..body_extra.data.fields_len]);
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
    try self.ensureUnusedTypeCapacity(1, null, 0);
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

pub fn bigIntConst(self: *Builder, ty: Type, value: std.math.big.int.Const) Allocator.Error!Constant {
    try self.constant_map.ensureUnusedCapacity(self.gpa, 1);
    try self.constant_items.ensureUnusedCapacity(self.gpa, 1);
    try self.constant_limbs.ensureUnusedCapacity(self.gpa, Constant.Integer.limbs + value.limbs.len);
    if (self.useLibLlvm()) try self.llvm.constants.ensureUnusedCapacity(self.gpa, 1);
    return self.bigIntConstAssumeCapacity(ty, value);
}

pub fn fpConst(self: *Builder, ty: Type, comptime val: comptime_float) Allocator.Error!Constant {
    return switch (ty) {
        .half => try self.halfConst(val),
        .bfloat => try self.bfloatConst(val),
        .float => try self.floatConst(val),
        .double => try self.doubleConst(val),
        .fp128 => try self.fp128Const(val),
        .x86_fp80 => try self.x86_fp80Const(val),
        .ppc_fp128 => try self.ppc_fp128Const(.{ val, 0 }),
        else => unreachable,
    };
}

pub fn halfConst(self: *Builder, val: f16) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, null, 0);
    return self.halfConstAssumeCapacity(val);
}

pub fn bfloatConst(self: *Builder, val: f32) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, null, 0);
    return self.bfloatConstAssumeCapacity(val);
}

pub fn floatConst(self: *Builder, val: f32) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, null, 0);
    return self.floatConstAssumeCapacity(val);
}

pub fn doubleConst(self: *Builder, val: f64) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Double, 0);
    return self.doubleConstAssumeCapacity(val);
}

pub fn fp128Const(self: *Builder, val: f128) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Fp128, 0);
    return self.fp128ConstAssumeCapacity(val);
}

pub fn x86_fp80Const(self: *Builder, val: f80) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Fp80, 0);
    return self.x86_fp80ConstAssumeCapacity(val);
}

pub fn ppc_fp128Const(self: *Builder, val: [2]f64) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Fp128, 0);
    return self.ppc_fp128ConstAssumeCapacity(val);
}

pub fn nullConst(self: *Builder, ty: Type) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, null, 0);
    return self.nullConstAssumeCapacity(ty);
}

pub fn noneConst(self: *Builder, ty: Type) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, null, 0);
    return self.noneConstAssumeCapacity(ty);
}

pub fn structConst(self: *Builder, ty: Type, vals: []const Constant) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Aggregate, vals.len);
    return self.structConstAssumeCapacity(ty, vals);
}

pub fn arrayConst(self: *Builder, ty: Type, vals: []const Constant) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Aggregate, vals.len);
    return self.arrayConstAssumeCapacity(ty, vals);
}

pub fn stringConst(self: *Builder, val: String) Allocator.Error!Constant {
    try self.ensureUnusedTypeCapacity(1, Type.Array, 0);
    try self.ensureUnusedConstantCapacity(1, null, 0);
    return self.stringConstAssumeCapacity(val);
}

pub fn stringNullConst(self: *Builder, val: String) Allocator.Error!Constant {
    try self.ensureUnusedTypeCapacity(1, Type.Array, 0);
    try self.ensureUnusedConstantCapacity(1, null, 0);
    return self.stringNullConstAssumeCapacity(val);
}

pub fn vectorConst(self: *Builder, ty: Type, vals: []const Constant) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Aggregate, vals.len);
    return self.vectorConstAssumeCapacity(ty, vals);
}

pub fn splatConst(self: *Builder, ty: Type, val: Constant) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Splat, 0);
    return self.splatConstAssumeCapacity(ty, val);
}

pub fn zeroInitConst(self: *Builder, ty: Type) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Fp128, 0);
    try self.constant_limbs.ensureUnusedCapacity(
        self.gpa,
        Constant.Integer.limbs + comptime std.math.big.int.calcLimbLen(0),
    );
    return self.zeroInitConstAssumeCapacity(ty);
}

pub fn undefConst(self: *Builder, ty: Type) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, null, 0);
    return self.undefConstAssumeCapacity(ty);
}

pub fn poisonConst(self: *Builder, ty: Type) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, null, 0);
    return self.poisonConstAssumeCapacity(ty);
}

pub fn blockAddrConst(
    self: *Builder,
    function: Function.Index,
    block: Function.Block.Index,
) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.BlockAddress, 0);
    return self.blockAddrConstAssumeCapacity(function, block);
}

pub fn dsoLocalEquivalentConst(self: *Builder, function: Function.Index) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.FunctionReference, 0);
    return self.dsoLocalEquivalentConstAssumeCapacity(function);
}

pub fn noCfiConst(self: *Builder, function: Function.Index) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.FunctionReference, 0);
    return self.noCfiConstAssumeCapacity(function);
}

pub fn convConst(
    self: *Builder,
    signedness: Constant.Cast.Signedness,
    arg: Constant,
    ty: Type,
) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Cast, 0);
    return self.convConstAssumeCapacity(signedness, arg, ty);
}

pub fn castConst(self: *Builder, tag: Constant.Tag, arg: Constant, ty: Type) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Cast, 0);
    return self.castConstAssumeCapacity(tag, arg, ty);
}

pub fn gepConst(
    self: *Builder,
    comptime kind: Constant.GetElementPtr.Kind,
    ty: Type,
    base: Constant,
    indices: []const Constant,
) Allocator.Error!Constant {
    try self.ensureUnusedTypeCapacity(1, Type.Vector, 0);
    try self.ensureUnusedConstantCapacity(1, Constant.GetElementPtr, indices.len);
    return self.gepConstAssumeCapacity(kind, ty, base, indices);
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

pub fn fcmpConst(
    self: *Builder,
    cond: FloatCondition,
    lhs: Constant,
    rhs: Constant,
) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.Compare, 0);
    return self.icmpConstAssumeCapacity(cond, lhs, rhs);
}

pub fn extractElementConst(self: *Builder, arg: Constant, index: Constant) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.ExtractElement, 0);
    return self.extractElementConstAssumeCapacity(arg, index);
}

pub fn insertElementConst(
    self: *Builder,
    arg: Constant,
    elem: Constant,
    index: Constant,
) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.InsertElement, 0);
    return self.insertElementConstAssumeCapacity(arg, elem, index);
}

pub fn shuffleVectorConst(
    self: *Builder,
    lhs: Constant,
    rhs: Constant,
    mask: Constant,
) Allocator.Error!Constant {
    try self.ensureUnusedConstantCapacity(1, Constant.ShuffleVector, 0);
    return self.shuffleVectorConstAssumeCapacity(lhs, rhs, mask);
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

pub fn dump(self: *Builder, writer: anytype) (@TypeOf(writer).Error || Allocator.Error)!void {
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
            global.alignment,
        });
    }
    try writer.writeByte('\n');
    for (self.functions.items) |function| {
        if (function.global.getReplacement(self) != .none) continue;
        const global = function.global.ptrConst(self);
        const item = self.type_items.items[@intFromEnum(global.type)];
        const extra = self.typeExtraDataTrail(Type.Function, item.data);
        const params: []const Type =
            @ptrCast(self.type_extra.items[extra.end..][0..extra.data.params_len]);
        try writer.print(
            \\{s}{}{}{}{} {} {}(
        , .{
            if (function.body) |_| "define" else "declare",
            global.linkage,
            global.preemption,
            global.visibility,
            global.dll_storage_class,
            extra.data.ret.fmt(self),
            function.global.fmt(self),
        });
        for (params, 0..) |param, index| {
            if (index > 0) try writer.writeAll(", ");
            try writer.print("{%} %{d}", .{ param.fmt(self), index });
        }
        switch (item.tag) {
            .function => {},
            .vararg_function => {
                if (params.len > 0) try writer.writeAll(", ");
                try writer.writeAll("...");
            },
            else => unreachable,
        }
        try writer.print("){}{}", .{ global.unnamed_addr, global.alignment });
        if (function.body) |_| {
            try writer.writeAll(" {\n  ret ");
            void: {
                try writer.print("{%}", .{switch (extra.data.ret) {
                    .void => |tag| {
                        try writer.writeAll(@tagName(tag));
                        break :void;
                    },
                    inline .half,
                    .bfloat,
                    .float,
                    .double,
                    .fp128,
                    .x86_fp80,
                    => |tag| try @field(Builder, @tagName(tag) ++ "Const")(self, 0.0),
                    .ppc_fp128 => try self.ppc_fp128Const(.{ 0.0, 0.0 }),
                    .x86_amx,
                    .x86_mmx,
                    .label,
                    .metadata,
                    => unreachable,
                    .token => Constant.none,
                    else => switch (extra.data.ret.tag(self)) {
                        .simple,
                        .function,
                        .vararg_function,
                        => unreachable,
                        .integer => try self.intConst(extra.data.ret, 0),
                        .pointer => try self.nullConst(extra.data.ret),
                        .target,
                        .vector,
                        .scalable_vector,
                        .small_array,
                        .array,
                        .structure,
                        .packed_structure,
                        .named_structure,
                        => try self.zeroInitConst(extra.data.ret),
                    },
                }.fmt(self)});
            }
            try writer.writeAll("\n}");
        }
        try writer.writeAll("\n\n");
    }
}

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
    if (name.toSlice(self)) |id| try self.string_bytes.ensureUnusedCapacity(self.gpa, id.len +
        comptime std.fmt.count("{d}" ++ .{0}, .{std.math.maxInt(u32)}));
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
            const rhs_extra = ctx.builder.typeExtraDataTrail(Type.Function, rhs_data.data);
            const rhs_params: []const Type =
                @ptrCast(ctx.builder.type_extra.items[rhs_extra.end..][0..rhs_extra.data.params_len]);
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
            const rhs_extra = ctx.builder.typeExtraDataTrail(Type.Structure, rhs_data.data);
            const rhs_fields: []const Type =
                @ptrCast(ctx.builder.type_extra.items[rhs_extra.end..][0..rhs_extra.data.fields_len]);
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
    comptime Extra: ?type,
    trail_len: usize,
) Allocator.Error!void {
    try self.type_map.ensureUnusedCapacity(self.gpa, count);
    try self.type_items.ensureUnusedCapacity(self.gpa, count);
    if (Extra) |E| try self.type_extra.ensureUnusedCapacity(
        self.gpa,
        count * (@typeInfo(E).Struct.fields.len + trail_len),
    ) else assert(trail_len == 0);
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

fn typeExtraDataTrail(
    self: *const Builder,
    comptime T: type,
    index: Type.Item.ExtraIndex,
) struct { data: T, end: Type.Item.ExtraIndex } {
    var result: T = undefined;
    const fields = @typeInfo(T).Struct.fields;
    inline for (fields, self.type_extra.items[index..][0..fields.len]) |field, data|
        @field(result, field.name) = switch (field.type) {
            u32 => data,
            String, Type => @enumFromInt(data),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        };
    return .{ .data = result, .end = index + @as(Type.Item.ExtraIndex, @intCast(fields.len)) };
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
                    canonical_value.bitCountTwosComp(),
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
    const extra = self.typeExtraDataTrail(Type.Structure, switch (type_item.tag) {
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
    const fields: []const Type =
        @ptrCast(self.type_extra.items[extra.end..][0..extra.data.fields_len]);
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
        .small_array => extra: {
            const extra = self.typeExtraData(Type.Vector, type_item.data);
            break :extra .{ .len = extra.len, .child = extra.child };
        },
        .array => extra: {
            const extra = self.typeExtraData(Type.Array, type_item.data);
            break :extra .{ .len = extra.len(), .child = extra.child };
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
        self.llvm.constants.appendAssumeCapacity(ty.toLlvm(self).getUndef());
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

fn convConstAssumeCapacity(
    self: *Builder,
    signedness: Constant.Cast.Signedness,
    arg: Constant,
    ty: Type,
) Constant {
    const arg_ty = arg.typeOf(self);
    if (arg_ty == ty) return arg;
    return self.castConstAssumeCapacity(switch (arg_ty.scalarTag(self)) {
        .simple => switch (ty.scalarTag(self)) {
            .simple => switch (std.math.order(arg_ty.scalarBits(self), ty.scalarBits(self))) {
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
        .integer => switch (ty.tag(self)) {
            .simple => switch (signedness) {
                .unsigned => .uitofp,
                .signed => .sitofp,
                .unneeded => unreachable,
            },
            .integer => switch (std.math.order(arg_ty.scalarBits(self), ty.scalarBits(self))) {
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
        .pointer => switch (ty.tag(self)) {
            .integer => .ptrtoint,
            .pointer => .addrspacecast,
            else => unreachable,
        },
        else => unreachable,
    }, arg, ty);
}

fn castConstAssumeCapacity(self: *Builder, tag: Constant.Tag, arg: Constant, ty: Type) Constant {
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
    const data = Key{ .tag = tag, .cast = .{ .arg = arg, .type = ty } };
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
        }(arg.toLlvm(self), ty.toLlvm(self)));
    }
    return @enumFromInt(gop.index);
}

fn gepConstAssumeCapacity(
    self: *Builder,
    comptime kind: Constant.GetElementPtr.Kind,
    ty: Type,
    base: Constant,
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

    const Key = struct { type: Type, base: Constant, indices: []const Constant };
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Key) u32 {
            var hasher = std.hash.Wyhash.init(comptime std.hash.uint32(@intFromEnum(tag)));
            hasher.update(std.mem.asBytes(&key.type));
            hasher.update(std.mem.asBytes(&key.base));
            hasher.update(std.mem.sliceAsBytes(key.indices));
            return @truncate(hasher.final());
        }
        pub fn eql(ctx: @This(), lhs_key: Key, _: void, rhs_index: usize) bool {
            if (ctx.builder.constant_items.items(.tag)[rhs_index] != tag) return false;
            const rhs_data = ctx.builder.constant_items.items(.data)[rhs_index];
            const rhs_extra = ctx.builder.constantExtraDataTrail(Constant.GetElementPtr, rhs_data);
            const rhs_indices: []const Constant = @ptrCast(ctx.builder.constant_extra
                .items[rhs_extra.end..][0..rhs_extra.data.indices_len]);
            return lhs_key.type == rhs_extra.data.type and lhs_key.base == rhs_extra.data.base and
                std.mem.eql(Constant, lhs_key.indices, rhs_indices);
        }
    };
    const data = Key{ .type = ty, .base = base, .indices = indices };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = tag,
            .data = self.addConstantExtraAssumeCapacity(Constant.GetElementPtr{
                .type = ty,
                .base = base,
                .indices_len = @intCast(indices.len),
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
            }(ty.toLlvm(self), base.toLlvm(self), llvm_indices.ptr, @intCast(indices.len)));
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
    arg: Constant,
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
    const data = Constant.ExtractElement{ .arg = arg, .index = index };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = .extractelement,
            .data = self.addConstantExtraAssumeCapacity(data),
        });
        if (self.useLibLlvm()) self.llvm.constants.appendAssumeCapacity(
            arg.toLlvm(self).constExtractElement(index.toLlvm(self)),
        );
    }
    return @enumFromInt(gop.index);
}

fn insertElementConstAssumeCapacity(
    self: *Builder,
    arg: Constant,
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
    const data = Constant.InsertElement{ .arg = arg, .elem = elem, .index = index };
    const gop = self.constant_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.constant_items.appendAssumeCapacity(.{
            .tag = .insertelement,
            .data = self.addConstantExtraAssumeCapacity(data),
        });
        if (self.useLibLlvm()) self.llvm.constants.appendAssumeCapacity(
            arg.toLlvm(self).constInsertElement(elem.toLlvm(self), index.toLlvm(self)),
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
    comptime Extra: ?type,
    trail_len: usize,
) Allocator.Error!void {
    try self.constant_map.ensureUnusedCapacity(self.gpa, count);
    try self.constant_items.ensureUnusedCapacity(self.gpa, count);
    if (Extra) |E| try self.constant_extra.ensureUnusedCapacity(
        self.gpa,
        count * (@typeInfo(E).Struct.fields.len + trail_len),
    ) else assert(trail_len == 0);
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
            const rhs_extra = ctx.builder.constantExtraDataTrail(Constant.Aggregate, rhs_data);
            if (lhs_key.type != rhs_extra.data.type) return false;
            const rhs_vals: []const Constant =
                @ptrCast(ctx.builder.constant_extra.items[rhs_extra.end..][0..lhs_key.vals.len]);
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
            Type,
            Constant,
            Function.Index,
            Function.Block.Index,
            => @intFromEnum(value),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        });
    }
    return result;
}

fn constantExtraDataTrail(
    self: *const Builder,
    comptime T: type,
    index: Constant.Item.ExtraIndex,
) struct { data: T, end: Constant.Item.ExtraIndex } {
    var result: T = undefined;
    const fields = @typeInfo(T).Struct.fields;
    inline for (fields, self.constant_extra.items[index..][0..fields.len]) |field, data|
        @field(result, field.name) = switch (field.type) {
            u32 => data,
            Type,
            Constant,
            Function.Index,
            Function.Block.Index,
            => @enumFromInt(data),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        };
    return .{ .data = result, .end = index + @as(Constant.Item.ExtraIndex, @intCast(fields.len)) };
}

fn constantExtraData(self: *const Builder, comptime T: type, index: Constant.Item.ExtraIndex) T {
    return self.constantExtraDataTrail(T, index).data;
}

pub inline fn useLibLlvm(self: *const Builder) bool {
    return build_options.have_llvm and self.use_lib_llvm;
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
