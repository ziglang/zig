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

            return .{
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

            return .{
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

// TODO: See https://github.com/ziglang/zig/issues/4564
fn _workaround() error{WORKAROUND}!void {}

pub fn Interface(comptime VTableT: type, comptime StorageT: type) type {
    return struct {
        vtable_ptr: *const VTableT,
        storage: StorageT,

        const Self = @This();

        pub fn init(args: var) !Self {
            const ImplType = PtrChildOrSelf(@TypeOf(args.@"0"));

            const storage = StorageT.init(args);
            const initCanError = comptime trait.is(.ErrorUnion)(@TypeOf(storage));

            // TODO: See https://github.com/ziglang/zig/issues/4564
            if (!initCanError) try _workaround();

            return Self {
                .vtable_ptr = &comptime make_vtable(VTableT, ImplType),
                .storage = if (initCanError) try storage else storage,
            };
        }

        pub fn initWithVTable(vtable_ptr: *const VTableT, args: var) !Self {
            const storage = StorageT.init(args);
            const initCanError = comptime trait.is(.ErrorUnion)(@TypeOf(storage));

            // TODO: See https://github.com/ziglang/zig/issues/4564
            if (!initCanError) try _workaround();

            return .{
                .vtable_ptr = vtable_ptr,
                .storage = if (initCanError) try storage else storage,
            };
        }

        pub fn call(self: Self, comptime name: []u8, args: var) VTableReturnType(VTableT, name) {

        }
    };
}
