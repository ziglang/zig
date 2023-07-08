gpa: Allocator,
use_lib_llvm: bool,

llvm_context: *llvm.Context,
llvm_module: *llvm.Module,
di_builder: ?*llvm.DIBuilder = null,
llvm_types: std.ArrayListUnmanaged(*llvm.Type) = .{},
llvm_globals: std.ArrayListUnmanaged(*llvm.Value) = .{},

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
next_unique_global_id: std.AutoHashMapUnmanaged(String, u32) = .{},
aliases: std.ArrayListUnmanaged(Alias) = .{},
objects: std.ArrayListUnmanaged(Object) = .{},
functions: std.ArrayListUnmanaged(Function) = .{},

pub const String = enum(u32) {
    none = std.math.maxInt(u31),
    empty,
    debugme,
    _,

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
        assert(data.string != .none);
        const slice = data.string.toSlice(data.builder) orelse
            return writer.print("{d}", .{@intFromEnum(data.string)});
        const need_quotes = if (comptime std.mem.eql(u8, fmt_str, ""))
            !isValidIdentifier(slice)
        else if (comptime std.mem.eql(u8, fmt_str, "\""))
            true
        else
            @compileError("invalid format string: '" ++ fmt_str ++ "'");
        if (need_quotes) try writer.writeByte('\"');
        for (slice) |character| switch (character) {
            '\\' => try writer.writeAll("\\\\"),
            ' '...'"' - 1, '"' + 1...'\\' - 1, '\\' + 1...'~' => try writer.writeByte(character),
            else => try writer.print("\\{X:0>2}", .{character}),
        };
        if (need_quotes) try writer.writeByte('\"');
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
        pub fn eql(ctx: Adapter, lhs: []const u8, _: void, rhs_index: usize) bool {
            return std.mem.eql(u8, lhs, String.fromIndex(rhs_index).toSlice(ctx.builder).?);
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
    };

    pub const ExtraIndex = u28;

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
        const type_item = data.builder.type_items.items[@intFromEnum(data.type)];
        switch (type_item.tag) {
            .simple => unreachable,
            .function, .vararg_function => {
                const extra = data.builder.typeExtraDataTrail(Type.Function, type_item.data);
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
                    switch (type_item.tag) {
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
            .integer => try writer.print("i{d}", .{type_item.data}),
            .pointer => try writer.print("ptr{}", .{@as(AddrSpace, @enumFromInt(type_item.data))}),
            .target => {
                const extra = data.builder.typeExtraDataTrail(Type.Target, type_item.data);
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
                const extra = data.builder.typeExtraData(Type.Vector, type_item.data);
                try writer.print("<{d} x {%}>", .{ extra.len, extra.child.fmt(data.builder) });
            },
            .scalable_vector => {
                const extra = data.builder.typeExtraData(Type.Vector, type_item.data);
                try writer.print("<vscale x {d} x {%}>", .{ extra.len, extra.child.fmt(data.builder) });
            },
            .small_array => {
                const extra = data.builder.typeExtraData(Type.Vector, type_item.data);
                try writer.print("[{d} x {%}]", .{ extra.len, extra.child.fmt(data.builder) });
            },
            .array => {
                const extra = data.builder.typeExtraData(Type.Array, type_item.data);
                try writer.print("[{d} x {%}]", .{ extra.len(), extra.child.fmt(data.builder) });
            },
            .structure, .packed_structure => {
                const extra = data.builder.typeExtraDataTrail(Type.Structure, type_item.data);
                const fields: []const Type =
                    @ptrCast(data.builder.type_extra.items[extra.end..][0..extra.data.fields_len]);
                switch (type_item.tag) {
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
                switch (type_item.tag) {
                    .structure => {},
                    .packed_structure => try writer.writeByte('>'),
                    else => unreachable,
                }
            },
            .named_structure => {
                const extra = data.builder.typeExtraData(Type.NamedStructure, type_item.data);
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
        return builder.llvm_types.items[@intFromEnum(self)];
    }
};

pub const Linkage = enum {
    default,
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
    external,

    pub fn format(
        self: Linkage,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .default) try writer.print(" {s}", .{@tagName(self)});
    }
};

pub const Preemption = enum {
    default,
    dso_preemptable,
    dso_local,

    pub fn format(
        self: Preemption,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self != .default) try writer.print(" {s}", .{@tagName(self)});
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
    linkage: Linkage = .default,
    preemption: Preemption = .default,
    visibility: Visibility = .default,
    dll_storage_class: DllStorageClass = .default,
    unnamed_addr: UnnamedAddr = .default,
    addr_space: AddrSpace = .default,
    externally_initialized: ExternallyInitialized = .default,
    type: Type,
    alignment: Alignment = .default,
    kind: union(enum) {
        alias: Alias.Index,
        object: Object.Index,
        function: Function.Index,
    },

    pub const Index = enum(u32) {
        _,

        pub fn ptr(self: Index, builder: *Builder) *Global {
            return &builder.globals.values()[@intFromEnum(self)];
        }

        pub fn ptrConst(self: Index, builder: *const Builder) *const Global {
            return &builder.globals.values()[@intFromEnum(self)];
        }

        pub fn toLlvm(self: Index, builder: *const Builder) *llvm.Value {
            assert(builder.useLibLlvm());
            return builder.llvm_globals.items[@intFromEnum(self)];
        }

        pub fn rename(self: Index, builder: *Builder, name: String) Allocator.Error!void {
            try builder.ensureUnusedCapacityGlobal(name);
            self.renameAssumeCapacity(builder, name);
        }

        pub fn renameAssumeCapacity(self: Index, builder: *Builder, name: String) void {
            const index = @intFromEnum(self);
            if (builder.globals.keys()[index] == name) return;
            if (builder.useLibLlvm()) builder.llvm_globals.appendAssumeCapacity(builder.llvm_globals.items[index]);
            _ = builder.addGlobalAssumeCapacity(name, builder.globals.values()[index]);
            if (builder.useLibLlvm()) _ = builder.llvm_globals.pop();
            builder.globals.swapRemoveAt(index);
            self.updateName(builder);
        }

        pub fn takeName(self: Index, builder: *Builder, other: Index) Allocator.Error!void {
            try builder.ensureUnusedCapacityGlobal(.empty);
            self.takeNameAssumeCapacity(builder, other);
        }

        pub fn takeNameAssumeCapacity(self: Index, builder: *Builder, other: Index) void {
            const other_name = builder.globals.keys()[@intFromEnum(other)];
            other.renameAssumeCapacity(builder, .none);
            self.renameAssumeCapacity(builder, other_name);
        }

        fn updateName(self: Index, builder: *const Builder) void {
            if (!builder.useLibLlvm()) return;
            const index = @intFromEnum(self);
            const slice = builder.globals.keys()[index].toSlice(builder) orelse "";
            builder.llvm_globals.items[index].setValueName2(slice.ptr, slice.len);
        }
    };

    fn deinit(self: *Global, _: Allocator) void {
        self.* = undefined;
    }
};

pub const Alias = struct {
    global: Global.Index,

    pub const Index = enum(u32) {
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

pub const Object = struct {
    global: Global.Index,
    thread_local: ThreadLocal = .default,
    mutability: enum { global, constant } = .global,
    init: void = {},

    pub const Index = enum(u32) {
        _,

        pub fn ptr(self: Index, builder: *Builder) *Object {
            return &builder.objects.items[@intFromEnum(self)];
        }

        pub fn ptrConst(self: Index, builder: *const Builder) *const Object {
            return &builder.objects.items[@intFromEnum(self)];
        }

        pub fn toLlvm(self: Index, builder: *const Builder) *llvm.Value {
            return self.ptrConst(builder).global.toLlvm(builder);
        }
    };
};

pub const Function = struct {
    global: Global.Index,
    body: ?void = null,

    fn deinit(self: *Function, _: Allocator) void {
        self.* = undefined;
    }

    pub const Index = enum(u32) {
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
};

pub fn init(self: *Builder) Allocator.Error!void {
    try self.string_indices.append(self.gpa, 0);
    assert(try self.string("") == .empty);
    assert(try self.string("debugme") == .debugme);

    {
        const static_len = @typeInfo(Type).Enum.fields.len - 1;
        try self.type_map.ensureTotalCapacity(self.gpa, static_len);
        try self.type_items.ensureTotalCapacity(self.gpa, static_len);
        if (self.useLibLlvm()) try self.llvm_types.ensureTotalCapacity(self.gpa, static_len);
        inline for (@typeInfo(Type.Simple).Enum.fields) |simple_field| {
            const result = self.typeNoExtraAssumeCapacity(.{
                .tag = .simple,
                .data = simple_field.value,
            });
            assert(result.new and result.type == @field(Type, simple_field.name));
            if (self.useLibLlvm()) self.llvm_types.appendAssumeCapacity(
                @field(llvm.Context, simple_field.name ++ "Type")(self.llvm_context),
            );
        }
        inline for (.{ 1, 8, 16, 29, 32, 64, 80, 128 }) |bits| assert(self.intTypeAssumeCapacity(bits) ==
            @field(Type, std.fmt.comptimePrint("i{d}", .{bits})));
        inline for (.{0}) |addr_space|
            assert(self.ptrTypeAssumeCapacity(@enumFromInt(addr_space)) == .ptr);
    }
}

pub fn deinit(self: *Builder) void {
    self.llvm_types.deinit(self.gpa);
    self.llvm_globals.deinit(self.gpa);

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
    self.objects.deinit(self.gpa);
    self.functions.deinit(self.gpa);

    self.* = undefined;
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
    try self.ensureUnusedCapacityTypes(1, Type.Function, params.len);
    return switch (kind) {
        inline else => |comptime_kind| self.fnTypeAssumeCapacity(ret, params, comptime_kind),
    };
}

pub fn intType(self: *Builder, bits: u24) Allocator.Error!Type {
    try self.ensureUnusedCapacityTypes(1, null, 0);
    return self.intTypeAssumeCapacity(bits);
}

pub fn ptrType(self: *Builder, addr_space: AddrSpace) Allocator.Error!Type {
    try self.ensureUnusedCapacityTypes(1, null, 0);
    return self.ptrTypeAssumeCapacity(addr_space);
}

pub fn vectorType(
    self: *Builder,
    kind: Type.Vector.Kind,
    len: u32,
    child: Type,
) Allocator.Error!Type {
    try self.ensureUnusedCapacityTypes(1, Type.Vector, 0);
    return switch (kind) {
        inline else => |comptime_kind| self.vectorTypeAssumeCapacity(comptime_kind, len, child),
    };
}

pub fn arrayType(self: *Builder, len: u64, child: Type) Allocator.Error!Type {
    comptime assert(@sizeOf(Type.Array) >= @sizeOf(Type.Vector));
    try self.ensureUnusedCapacityTypes(1, Type.Array, 0);
    return self.arrayTypeAssumeCapacity(len, child);
}

pub fn structType(
    self: *Builder,
    kind: Type.Structure.Kind,
    fields: []const Type,
) Allocator.Error!Type {
    try self.ensureUnusedCapacityTypes(1, Type.Structure, fields.len);
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
    try self.ensureUnusedCapacityTypes(1, Type.NamedStructure, 0);
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
        for (llvm_fields, body_fields) |*llvm_field, body_field|
            llvm_field.* = self.llvm_types.items[@intFromEnum(body_field)];
        self.llvm_types.items[@intFromEnum(named_type)].structSetBody(
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
    try self.ensureUnusedCapacityGlobal(name);
    return self.addGlobalAssumeCapacity(name, global);
}

pub fn addGlobalAssumeCapacity(self: *Builder, name: String, global: Global) Global.Index {
    var id = name;
    if (id == .none) {
        id = self.next_unnamed_global;
        self.next_unnamed_global = @enumFromInt(@intFromEnum(self.next_unnamed_global) + 1);
    }
    while (true) {
        const global_gop = self.globals.getOrPutAssumeCapacity(id);
        if (!global_gop.found_existing) {
            global_gop.value_ptr.* = global;
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

fn ensureUnusedCapacityGlobal(self: *Builder, name: String) Allocator.Error!void {
    if (self.useLibLlvm()) try self.llvm_globals.ensureUnusedCapacity(self.gpa, 1);
    try self.string_map.ensureUnusedCapacity(self.gpa, 1);
    try self.string_bytes.ensureUnusedCapacity(self.gpa, name.toSlice(self).?.len +
        comptime std.fmt.count("{d}" ++ .{0}, .{std.math.maxInt(u32)}));
    try self.string_indices.ensureUnusedCapacity(self.gpa, 1);
    try self.globals.ensureUnusedCapacity(self.gpa, 1);
    try self.next_unique_global_id.ensureUnusedCapacity(self.gpa, 1);
}

fn addTypeExtraAssumeCapacity(self: *Builder, extra: anytype) Type.ExtraIndex {
    const result: Type.ExtraIndex = @intCast(self.type_extra.items.len);
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
    index: Type.ExtraIndex,
) struct { data: T, end: Type.ExtraIndex } {
    var result: T = undefined;
    const fields = @typeInfo(T).Struct.fields;
    inline for (fields, self.type_extra.items[index..][0..fields.len]) |field, data|
        @field(result, field.name) = switch (field.type) {
            u32 => data,
            String, Type => @enumFromInt(data),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        };
    return .{ .data = result, .end = index + @as(Type.ExtraIndex, @intCast(fields.len)) };
}

fn typeExtraData(self: *const Builder, comptime T: type, index: Type.ExtraIndex) T {
    return self.typeExtraDataTrail(T, index).data;
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
        pub fn eql(ctx: @This(), lhs: Key, _: void, rhs_index: usize) bool {
            const rhs_data = ctx.builder.type_items.items[rhs_index];
            const rhs_extra = ctx.builder.typeExtraDataTrail(Type.Function, rhs_data.data);
            const rhs_params: []const Type =
                @ptrCast(ctx.builder.type_extra.items[rhs_extra.end..][0..rhs_extra.data.params_len]);
            return rhs_data.tag == tag and lhs.ret == rhs_extra.data.ret and
                std.mem.eql(Type, lhs.params, rhs_params);
        }
    };
    const data = Key{ .ret = ret, .params = params };
    const gop = self.type_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
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
            self.llvm_types.appendAssumeCapacity(llvm.functionType(
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
    const result = self.typeNoExtraAssumeCapacity(.{ .tag = .integer, .data = bits });
    if (self.useLibLlvm() and result.new)
        self.llvm_types.appendAssumeCapacity(self.llvm_context.intType(bits));
    return result.type;
}

fn ptrTypeAssumeCapacity(self: *Builder, addr_space: AddrSpace) Type {
    const result = self.typeNoExtraAssumeCapacity(.{
        .tag = .pointer,
        .data = @intFromEnum(addr_space),
    });
    if (self.useLibLlvm() and result.new)
        self.llvm_types.appendAssumeCapacity(self.llvm_context.pointerType(@intFromEnum(addr_space)));
    return result.type;
}

fn vectorTypeAssumeCapacity(
    self: *Builder,
    comptime kind: Type.Vector.Kind,
    len: u32,
    child: Type,
) Type {
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
        pub fn eql(ctx: @This(), lhs: Type.Vector, _: void, rhs_index: usize) bool {
            const rhs_data = ctx.builder.type_items.items[rhs_index];
            return rhs_data.tag == tag and
                std.meta.eql(lhs, ctx.builder.typeExtraData(Type.Vector, rhs_data.data));
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
        if (self.useLibLlvm()) self.llvm_types.appendAssumeCapacity(switch (kind) {
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
            pub fn eql(ctx: @This(), lhs: Type.Vector, _: void, rhs_index: usize) bool {
                const rhs_data = ctx.builder.type_items.items[rhs_index];
                return rhs_data.tag == .small_array and
                    std.meta.eql(lhs, ctx.builder.typeExtraData(Type.Vector, rhs_data.data));
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
            if (self.useLibLlvm()) self.llvm_types.appendAssumeCapacity(
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
            pub fn eql(ctx: @This(), lhs: Type.Array, _: void, rhs_index: usize) bool {
                const rhs_data = ctx.builder.type_items.items[rhs_index];
                return rhs_data.tag == .array and
                    std.meta.eql(lhs, ctx.builder.typeExtraData(Type.Array, rhs_data.data));
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
            if (self.useLibLlvm()) self.llvm_types.appendAssumeCapacity(
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
        pub fn eql(ctx: @This(), lhs: []const Type, _: void, rhs_index: usize) bool {
            const rhs_data = ctx.builder.type_items.items[rhs_index];
            const rhs_extra = ctx.builder.typeExtraDataTrail(Type.Structure, rhs_data.data);
            const rhs_fields: []const Type =
                @ptrCast(ctx.builder.type_extra.items[rhs_extra.end..][0..rhs_extra.data.fields_len]);
            return rhs_data.tag == tag and std.mem.eql(Type, lhs, rhs_fields);
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
            const llvm_fields = try self.gpa.alloc(*llvm.Type, fields.len);
            defer self.gpa.free(llvm_fields);
            for (llvm_fields, fields) |*llvm_field, field|
                llvm_field.* = self.llvm_types.items[@intFromEnum(field)];
            self.llvm_types.appendAssumeCapacity(self.llvm_context.structType(
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
        pub fn eql(ctx: @This(), lhs: String, _: void, rhs_index: usize) bool {
            const rhs_data = ctx.builder.type_items.items[rhs_index];
            return rhs_data.tag == .named_structure and
                lhs == ctx.builder.typeExtraData(Type.NamedStructure, rhs_data.data).id;
        }
    };
    var id = name;
    if (name == .none) {
        id = self.next_unnamed_type;
        assert(id != .none);
        self.next_unnamed_type = @enumFromInt(@intFromEnum(id) + 1);
    } else assert(name.toIndex() != null);
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
            if (self.useLibLlvm()) self.llvm_types.appendAssumeCapacity(
                self.llvm_context.structCreateNamed(id.toSlice(self) orelse ""),
            );
            return result;
        }

        const unique_gop = self.next_unique_type_id.getOrPutAssumeCapacity(name);
        if (!unique_gop.found_existing) unique_gop.value_ptr.* = 2;
        id = self.fmtAssumeCapacity("{s}.{d}", .{ name.toSlice(self).?, unique_gop.value_ptr.* });
        unique_gop.value_ptr.* += 1;
    }
}

fn ensureUnusedCapacityTypes(
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
    );
    if (self.useLibLlvm()) try self.llvm_types.ensureUnusedCapacity(self.gpa, count);
}

fn typeNoExtraAssumeCapacity(self: *Builder, item: Type.Item) struct { new: bool, type: Type } {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Type.Item) u32 {
            return @truncate(std.hash.Wyhash.hash(
                comptime std.hash.uint32(@intFromEnum(Type.Tag.simple)),
                std.mem.asBytes(&key),
            ));
        }
        pub fn eql(ctx: @This(), lhs: Type.Item, _: void, rhs_index: usize) bool {
            const lhs_bits: u32 = @bitCast(lhs);
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

fn isValidIdentifier(id: []const u8) bool {
    for (id, 0..) |character, index| switch (character) {
        '$', '-', '.', 'A'...'Z', '_', 'a'...'z' => {},
        '0'...'9' => if (index == 0) return false,
        else => return false,
    };
    return true;
}

pub fn dump(self: *Builder, writer: anytype) @TypeOf(writer).Error!void {
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
    for (self.objects.items) |object| {
        const global = self.globals.entries.get(@intFromEnum(object.global));
        try writer.print(
            \\@{} ={}{}{}{}{}{}{}{} {s} {%}{,}
            \\
        , .{
            global.key.fmt(self),
            global.value.linkage,
            global.value.preemption,
            global.value.visibility,
            global.value.dll_storage_class,
            object.thread_local,
            global.value.unnamed_addr,
            global.value.addr_space,
            global.value.externally_initialized,
            @tagName(object.mutability),
            global.value.type.fmt(self),
            global.value.alignment,
        });
    }
    try writer.writeByte('\n');
    for (self.functions.items) |function| {
        const global = self.globals.entries.get(@intFromEnum(function.global));
        try writer.print(
            \\{s} {}{}{}{}{<}@{}{>} {}{}{{
            \\  ret {%}
            \\}}
            \\
        , .{
            if (function.body) |_| "define" else "declare",
            global.value.linkage,
            global.value.preemption,
            global.value.visibility,
            global.value.dll_storage_class,
            global.value.type.fmt(self),
            global.key.fmt(self),
            global.value.type.fmt(self),
            global.value.unnamed_addr,
            global.value.alignment,
            self.typeExtraData(
                Type.Function,
                self.type_items.items[@intFromEnum(global.value.type)].data,
            ).ret.fmt(self),
        });
    }
    try writer.writeByte('\n');
}

inline fn useLibLlvm(self: *const Builder) bool {
    return build_options.have_llvm and self.use_lib_llvm;
}

const assert = std.debug.assert;
const build_options = @import("build_options");
const llvm = @import("bindings.zig");
const std = @import("std");

const Allocator = std.mem.Allocator;
const Builder = @This();
