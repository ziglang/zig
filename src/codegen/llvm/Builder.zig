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
type_map: std.AutoArrayHashMapUnmanaged(void, void) = .{},
type_data: std.ArrayListUnmanaged(Type.Data) = .{},
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
        for (slice) |c| switch (c) {
            '\\' => try writer.writeAll("\\\\"),
            ' '...'"' - 1, '"' + 1...'\\' - 1, '\\' + 1...'~' => try writer.writeByte(c),
            else => try writer.print("\\{X:0>2}", .{c}),
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
    i32,
    i64,
    i128,
    ptr,

    none = std.math.maxInt(u32),
    _,

    const Tag = enum(u4) {
        simple,
        function,
        integer,
        pointer,
        target,
        vector,
        vscale_vector,
        array,
        structure,
        packed_structure,
        named_structure,
    };

    const Simple = enum {
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

    const NamedStructure = struct {
        id: String,
        child: Type,
    };

    const Data = packed struct(u32) {
        tag: Tag,
        data: ExtraIndex,
    };

    const ExtraIndex = u28;

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
        if (std.enums.tagName(Type, data.type)) |name| return writer.writeAll(name);
        const type_data = data.builder.type_data.items[@intFromEnum(data.type)];
        switch (type_data.tag) {
            .named_structure => {
                const extra = data.builder.typeExtraData(NamedStructure, type_data.data);
                if (comptime std.mem.eql(u8, fmt_str, "")) try writer.print("%{}", .{
                    extra.id.fmt(data.builder),
                }) else if (comptime std.mem.eql(u8, fmt_str, "+")) switch (extra.child) {
                    .none => try writer.writeAll("opaque"),
                    else => try format(.{
                        .type = extra.child,
                        .builder = data.builder,
                    }, fmt_str, fmt_opts, writer),
                } else @compileError("invalid format string: '" ++ fmt_str ++ "'");
            },
            else => try writer.print("<type 0x{X}>", .{@intFromEnum(data.type)}),
        }
    }
    pub fn fmt(self: Type, builder: *const Builder) std.fmt.Formatter(format) {
        return .{ .data = .{ .type = self, .builder = builder } };
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
        if (self == .default) return;
        try writer.writeAll(@tagName(self));
        try writer.writeByte(' ');
    }
};

pub const Preemption = enum {
    none,
    dso_preemptable,
    dso_local,

    pub fn format(
        self: Preemption,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self == .none) return;
        try writer.writeAll(@tagName(self));
        try writer.writeByte(' ');
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
        if (self == .default) return;
        try writer.writeAll(@tagName(self));
        try writer.writeByte(' ');
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
        if (self == .default) return;
        try writer.writeAll(@tagName(self));
        try writer.writeByte(' ');
    }
};

pub const ThreadLocal = enum {
    none,
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
        if (self == .none) return;
        try writer.writeAll("thread_local");
        if (self != .generaldynamic) {
            try writer.writeByte('(');
            try writer.writeAll(@tagName(self));
            try writer.writeByte(')');
        }
        try writer.writeByte(' ');
    }
};

pub const UnnamedAddr = enum {
    none,
    unnamed_addr,
    local_unnamed_addr,

    pub fn format(
        self: UnnamedAddr,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self == .none) return;
        try writer.writeAll(@tagName(self));
        try writer.writeByte(' ');
    }
};

pub const AddrSpace = enum(u24) {
    none,
    _,

    pub fn format(
        self: AddrSpace,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self == .none) return;
        try writer.print("addrspace({d}) ", .{@intFromEnum(self)});
    }
};

pub const ExternallyInitialized = enum {
    none,
    externally_initialized,

    pub fn format(
        self: ExternallyInitialized,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (self == .none) return;
        try writer.writeAll(@tagName(self));
        try writer.writeByte(' ');
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
    preemption: Preemption = .none,
    visibility: Visibility = .default,
    dll_storage_class: DllStorageClass = .default,
    unnamed_addr: UnnamedAddr = .none,
    addr_space: AddrSpace = .none,
    externally_initialized: ExternallyInitialized = .none,
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
    thread_local: ThreadLocal = .none,
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
        try self.type_data.ensureTotalCapacity(self.gpa, static_len);
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
        inline for (.{ 1, 8, 16, 32, 64, 128 }) |bits| assert(self.intTypeAssumeCapacity(bits) ==
            @field(Type, std.fmt.comptimePrint("i{d}", .{bits})));
        inline for (.{0}) |addr_space|
            assert(self.pointerTypeAssumeCapacity(@enumFromInt(addr_space)) == .ptr);
    }
}

pub fn deinit(self: *Builder) void {
    self.llvm_types.deinit(self.gpa);
    self.llvm_globals.deinit(self.gpa);

    self.string_map.deinit(self.gpa);
    self.string_bytes.deinit(self.gpa);
    self.string_indices.deinit(self.gpa);

    self.types.deinit(self.gpa);
    self.type_map.deinit(self.gpa);
    self.type_data.deinit(self.gpa);
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

pub fn opaqueType(self: *Builder, name: String) Allocator.Error!Type {
    try self.types.ensureUnusedCapacity(self.gpa, 1);
    try self.ensureUnusedCapacityTypes(1, Type.NamedStructure);
    return self.opaqueTypeAssumeCapacity(name);
}

pub fn intType(self: *Builder, bits: u24) Allocator.Error!Type {
    try self.ensureUnusedCapacityTypes(1);
    return self.intTypeAssumeCapacity(bits);
}

pub fn pointerType(self: *Builder, addr_space: AddrSpace) Allocator.Error!Type {
    try self.ensureUnusedCapacityTypes(1, null);
    return self.pointerTypeAssumeCapacity(addr_space);
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
            String, Type => @enumFromInt(data),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        };
    return .{ .data = result, .end = index + @as(Type.ExtraIndex, @intCast(fields.len)) };
}

fn typeExtraData(self: *const Builder, comptime T: type, index: Type.ExtraIndex) T {
    return self.typeExtraDataTrail(T, index).data;
}

fn opaqueTypeAssumeCapacity(self: *Builder, name: String) Type {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: String) u32 {
            return std.hash.uint32(@intFromEnum(key));
        }
        pub fn eql(ctx: @This(), lhs: String, _: void, rhs_index: usize) bool {
            const rhs_data = ctx.builder.type_data.items[rhs_index];
            return rhs_data.tag == .named_structure and
                lhs == ctx.builder.typeExtraData(Type.NamedStructure, rhs_data.data).id;
        }
    };
    const id = if (name == .none) name: {
        const next_name = self.next_unnamed_type;
        assert(next_name != .none);
        self.next_unnamed_type = @enumFromInt(@intFromEnum(next_name) + 1);
        break :name next_name;
    } else name: {
        assert(name.toIndex() != null);
        break :name name;
    };
    const gop = self.type_map.getOrPutAssumeCapacityAdapted(id, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.type_data.appendAssumeCapacity(.{
            .tag = .named_structure,
            .data = self.addTypeExtraAssumeCapacity(Type.NamedStructure{ .id = id, .child = .none }),
        });
    }
    const result: Type = @enumFromInt(gop.index);
    self.types.putAssumeCapacityNoClobber(id, result);
    return result;
}

fn intTypeAssumeCapacity(self: *Builder, bits: u24) Type {
    const result = self.typeNoExtraAssumeCapacity(.{ .tag = .integer, .data = bits });
    if (self.useLibLlvm() and result.new)
        self.llvm_types.appendAssumeCapacity(self.llvm_context.intType(bits));
    return result.type;
}

fn pointerTypeAssumeCapacity(self: *Builder, addr_space: AddrSpace) Type {
    const result = self.typeNoExtraAssumeCapacity(.{ .tag = .pointer, .data = @intFromEnum(addr_space) });
    if (self.useLibLlvm() and result.new)
        self.llvm_types.appendAssumeCapacity(self.llvm_context.pointerType(@intFromEnum(addr_space)));
    return result.type;
}

fn ensureUnusedCapacityTypes(self: *Builder, count: usize, comptime Extra: ?type) Allocator.Error!void {
    try self.type_map.ensureUnusedCapacity(self.gpa, count);
    try self.type_data.ensureUnusedCapacity(self.gpa, count);
    if (Extra) |E|
        try self.type_extra.ensureUnusedCapacity(self.gpa, count * @typeInfo(E).Struct.fields.len);
    if (self.useLibLlvm()) try self.llvm_types.ensureUnusedCapacity(self.gpa, count);
}

fn typeNoExtraAssumeCapacity(self: *Builder, data: Type.Data) struct { new: bool, type: Type } {
    const Adapter = struct {
        builder: *const Builder,
        pub fn hash(_: @This(), key: Type.Data) u32 {
            return std.hash.uint32(@bitCast(key));
        }
        pub fn eql(ctx: @This(), lhs: Type.Data, _: void, rhs_index: usize) bool {
            const lhs_bits: u32 = @bitCast(lhs);
            const rhs_bits: u32 = @bitCast(ctx.builder.type_data.items[rhs_index]);
            return lhs_bits == rhs_bits;
        }
    };
    const gop = self.type_map.getOrPutAssumeCapacityAdapted(data, Adapter{ .builder = self });
    if (!gop.found_existing) {
        gop.key_ptr.* = {};
        gop.value_ptr.* = {};
        self.type_data.appendAssumeCapacity(data);
    }
    return .{ .new = !gop.found_existing, .type = @enumFromInt(gop.index) };
}

fn isValidIdentifier(id: []const u8) bool {
    for (id, 0..) |c, i| switch (c) {
        '$', '-', '.', 'A'...'Z', '_', 'a'...'z' => {},
        '0'...'9' => if (i == 0) return false,
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
        \\%{} = type {+}
        \\
    , .{ id.fmt(self), ty.fmt(self) });
    try writer.writeByte('\n');
    for (self.objects.items) |object| {
        const global = self.globals.entries.get(@intFromEnum(object.global));
        try writer.print(
            \\@{} = {}{}{}{}{}{}{}{}{s} {}{,}
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
            \\{s} {}{}{}{}void @{}() {}{}{{
            \\  ret void
            \\}}
            \\
        , .{
            if (function.body) |_| "define" else "declare",
            global.value.linkage,
            global.value.preemption,
            global.value.visibility,
            global.value.dll_storage_class,
            global.key.fmt(self),
            global.value.unnamed_addr,
            global.value.alignment,
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
