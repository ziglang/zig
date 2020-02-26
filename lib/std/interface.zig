const std = @import("std.zig");
const Allocator = std.mem.Allocator;
const trait = std.meta.trait;
const assert = std.debug.assert;

pub const SelfType = @OpaqueType();

fn makeSelfPtr(ptr: var) *SelfType {
    const t_i = @typeInfo(@TypeOf(ptr));

    if (comptime !trait.isSingleItemPtr(@TypeOf(ptr))) {
        @compileError("SelfType pointer initialization expects pointer parameter.");
    }

    const T = std.meta.Child(@TypeOf(ptr));

    if (@sizeOf(T) > 0) {
        return @ptrCast(*SelfType, ptr);
    } else {
        return undefined;
    }
}

fn selfPtrAs(self: *SelfType, comptime T: type) *T {
    if (@sizeOf(T) > 0) {
        return @alignCast(@alignOf(T), @ptrCast(*align(1) T, self));
    } else {
        return undefined;
    }
}

test "SelfType ptr runtime" {
    var i: usize = 10;
    var erased = makeSelfPtr(&i);

    assert(&i == selfPtrAs(erased, usize));
}

test "SelfType ptr comptime" {
    comptime {
        var b = false;
        var erased = makeSelfPtr(&b);

        assert(&b == selfPtrAs(erased, bool));
    }
}

// TODO: Check if I should pass by Self or *const Self by default.
// TODO: Only allow const declarations + function pointer fields in vtable types.
// TODO: If deinit in vtable, check if it has an errorset (only allow void return) and pass it
// to the interface's deinit.

pub const Storage = struct {
    pub const NonOwning = struct {
        erased_ptr: *SelfType,

        pub fn init(args: var) error{}!NonOwning {
            if (args.len != 1) {
                @compileError("NonOwning storage expected a 1-tuple in initialization.");
            }

            return NonOwning{
                .erased_ptr = makeSelfPtr(args.@"0"),
            };
        }

        pub fn getSelfPtr(self: NonOwning) *SelfType {
            return self.erased_ptr;
        }

        pub fn deinit(self: NonOwning) void {}
    };

    pub const Owning = struct {
        allocator: *Allocator,
        erased_ptr: *SelfType,

        pub fn init(args: var) !Owning {
            if (args.len != 2) {
                @compileError("Owning storage expected a 2-tuple in initialization.");
            }

            const AllocT = @TypeOf(args.@"0");

            var mem = try args.@"1".create(AllocT);
            mem.* = args.@"0";

            return Owning{
                .allocator = args.@"1",
                .erased_ptr = makeSelfPtr(mem),
            };
        }

        pub fn getSelfPtr(self: Owning) *SelfType {
            return self.erased_ptr;
        }

        pub fn deinit(self: Owning) void {
            self.allocator.destroy(selfPtrAs(self.erased_ptr, u8));
        }
    };

    pub fn Inline(comptime size: usize) type {
        return struct {
            const Self = @This();

            mem: [size]u8,

            pub fn init(args: var) error{}!Self {
                if (args.len != 1) {
                    @compileError("Inline storage expected a 1-tuple in initialization.");
                }

                const ImplSize = @sizeOf(@TypeOf(args.@"0"));

                if (ImplSize > size) {
                    @compileError("Type does not fit in inline storage.");
                }

                var self: Self = undefined;

                std.mem.copy(u8, self.mem[0..], @ptrCast([*]const u8, &args.@"0")[0..ImplSize]);
                return self;
            }

            pub fn getSelfPtr(self: Self) *SelfType {
                return makeSelfPtr(&self.mem[0]);
            }

            pub fn deinit(self: Self) void {}
        };
    }

    pub fn InlineOrOwning(comptime size: usize) type {
        return struct {
            const Self = @This();

            // TODO: Pack this tightly with an extern union?
            // Check resulting size of this union.
            data: union {
                Inline: Inline(size),
                Owning: Owning,
            },

            pub fn init(args: var) !Self {
                if (args.len != 2) {
                    @compileError("InlineOrOwning storage expected a 2-tuple in initialization.");
                }

                const ImplSize = @sizeOf(@TypeOf(args.@"0"));

                if (ImpleSize > size) {
                    return .{
                        .data = {
                            .Owning = try Owning.init(args);
                        },
                    };
                } else {
                    return .{
                        .data = {
                            .Inline = Inline(size).init(.{args.@"0"});
                        },
                    };
                }
            }

            pub fn getSelfPtr(self: Self) *SelfType {
                return switch (self.data) {
                    .Inline => |i| i.get_self_ptr(),
                    .Owning => |o| o.get_self_ptr(),
                };
            }

            pub fn deinit(self: Self) void {
                switch (self.data) {
                    .Inline => |i| i.deinit(),
                    .Owning => |o| o.deinit(),
                }
            }
        };
    }
};

fn PtrChildOrSelf(comptime T: type) type {
    if (comptime trait.isSingleItemPtr(T)) {
        return std.meta.Child(T);
    }

    return T;
}

fn make_vtable(comptime VTableT: type, comptime ImplT: type) VTableT {
    var vtable: VTableT = undefined;
    // TODO: Implementation
    return vtable;
}

// TODO: https://github.com/ziglang/zig/issues/4564
fn _workaround() error{WORKAROUND}!void {}

fn ReplaceSelfTypeWith(comptime Base: type, comptime With: type) type {}

fn checkVtableType(comptime VTableT: type) void {
    if (comptime !trait.is(.Struct)(VTableT)) {
        @compileError("VTable type " ++ @typeName(VTableT) ++ " must be a struct.");
    }

    for (std.meta.declarations(VTableT)) |decl| {
        switch (decl.data) {
            .Fn => @compileError("VTable type defines method '" ++ decl.name ++ "'."),
            .Type, .Var => {},
        }
    }

    for (std.meta.fields(VTableT)) |field| {
        // @compileLog(field.name);
        var field_type = field.field_type;

        if (trait.is(.Optional)(field_type)) {
            field_type = std.meta.Child(field_type);
        }

        if (!trait.is(.Fn)(field_type)) {
            @compileError("VTable type defines non function field '" ++ field.name ++ "'.");
        }

        const type_info = @typeInfo(field_type);

        if (type_info.Fn.is_generic) {
            @compileError("Virtual function '" ++ field.name ++ "' cannot be generic.");
        }

        // TODO: What calling conventions should be allowed?
        switch (type_info.Fn.calling_convention) {
            .Unspecified, .Async => {},
            else => @compileError("Virtual function's  '" ++ field.name ++ "' calling convention is not default or async."),
        }

        if (type_info.Fn.args.len == 0) {
            @compileError("Virtual function '" ++ field.name ++ "' must have at least one argument.");
        }

        const arg_type = type_info.Fn.args[0].arg_type.?;
        if (arg_type != SelfType and arg_type != *SelfType and arg_type != *const SelfType) {
            @compileError("Virtual function's '" ++ field.name ++ "' must be SelfType, *SelfType or *const SelfType");
        }
    }
}

pub fn Interface(comptime VTableT: type, comptime StorageT: type) type {
    comptime checkVtableType(VTableT);

    return struct {
        vtable_ptr: *const VTableT,
        storage: StorageT,

        const Self = @This();

        pub fn init(args: var) !Self {
            const ImplType = PtrChildOrSelf(@TypeOf(args.@"0"));
            // TODO: https://github.com/ziglang/zig/issues/4564
            try _workaround();

            return Self{
                .vtable_ptr = &comptime make_vtable(VTableT, ImplType),
                .storage = try StorageT.init(args),
            };
        }

        pub fn initWithVTable(vtable_ptr: *const VTableT, args: var) !Self {
            // TODO: https://github.com/ziglang/zig/issues/4564
            try _workaround();

            return .{
                .vtable_ptr = vtable_ptr,
                .storage = try StorageT.init(args),
            };
        }

        pub fn call(self: Self, comptime name: []u8, args: var) VTableReturnType(VTableT, name) {
            comptime var is_optional = true;
            comptime assert(vtableHasMethod(VTableT, name, &is_optional));

            const fn_ptr = if (is_optional) blk: {
                const val = @field(self.vtable_ptr, name);
                if (val) |v| break :blk v;
                return null;
            } else @field(slef.vtable, name);

            const self_ptr = self.storage.getSelfPtr();
            return @call(.{}, fn_ptr, args);
        }

        pub fn deinit(self: Self) void {
            self.storage.deinit();
        }
    };
}
