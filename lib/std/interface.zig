const std = @import("std.zig");
const Allocator = std.mem.Allocator;
const trait = std.meta.trait;
const assert = std.debug.assert;

pub const SelfType = @OpaqueType();

fn makeSelfPtr(ptr: var) *SelfType {
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

fn constSelfPtrAs(self: *const SelfType, comptime T: type) *const T {
    if (@sizeOf(T) > 0) {
        return @alignCast(@alignOf(T), @ptrCast(*align(1) const T, self));
    } else {
        return undefined;
    }
}

pub const Storage = struct {
    pub const NonOwning = struct {
        erased_ptr: *SelfType,

        pub fn init(args: var) !NonOwning {
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

            pub fn init(args: var) !Self {
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
                            .Inline = try Inline(size).init(.{args.@"0"});
                        },
                    };
                }
            }

            pub fn getSelfPtr(self: Self) *SelfType {
                return switch (self.data) {
                    .Inline => |i| i.getSelfPtr(),
                    .Owning => |o| o.getSelfPtr(),
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

fn getFunctionFromImpl(comptime name: []const u8, comptime FnT: type, comptime ImplT: type) ?FnT {
    const our_cc = @typeInfo(FnT).Fn.calling_convention;

    // Find the candidate in the implementation type.
    for (std.meta.declarations(ImplT)) |decl| {
        if (std.mem.eql(u8, name, decl.name)) {
            switch (decl.data) {
                .Fn => |fn_decl| {
                    const args = @typeInfo(fn_decl.fn_type).Fn.args;

                    if (args.len == 0) {
                        return null;
                    }

                    const arg0_type = args[0].arg_type.?;
                    if (arg0_type != ImplT and arg0_type != *ImplT and arg0_type != *const ImplT) {
                        return null;
                    }

                    const candidate_cc = @typeInfo(fn_decl.fn_type).Fn.calling_convention;
                    switch (candidate_cc) {
                        .Async, .Unspecified => {},
                        else => return null,
                    }

                    const Return = @typeInfo(FnT).Fn.return_type orelse noreturn;
                    const CurrSelfType = @typeInfo(FnT).Fn.args[0].arg_type.?;
                    const is_const = CurrSelfType == *const SelfType;

                    // If our virtual function is async and the candidate is not, it's ok.
                    // However, if the virutal function is not async and the candidate is, it's not ok.
                    switch (our_cc) {
                        .Unspecified => if (candidate_cc == .Async) return null,
                        else => {},
                    }

                    // TODO: Is there some way to not make a different closure for every argument length?
                    // Ideally, we would somehow pass 1-tuple with the argument pack from Interface.call and
                    // use arg[0] in @call.
                    return switch (args.len) {
                        1 => struct {
                            fn impl(self_ptr: CurrSelfType) Return {
                                const self = if (is_const) constSelfPtrAs(self_ptr, ImplT) else selfPtrAs(self_ptr, ImplT);
                                const f = @field(self, name);

                                return @call(if (our_cc == .Async) .{ .modifier = .async_kw } else .{ .modifier = .always_inline }, f, .{});
                            }
                        }.impl,
                        2 => struct {
                            fn impl(self_ptr: CurrSelfType, arg: args[1].arg_type.?) Return {
                                const self = if (is_const) constSelfPtrAs(self_ptr, ImplT) else selfPtrAs(self_ptr, ImplT);
                                const f = @field(self, name);

                                return @call(if (our_cc == .Async) .{ .modifier = .async_kw } else .{ .modifier = .always_inline }, f, .{arg});
                            }
                        }.impl,
                        3 => struct {
                            fn impl(self_ptr: CurrSelfType, arg1: args[1].arg_type.?, arg2: args[2].arg_type.?) Return {
                                const self = if (is_const) constSelfPtrAs(self_ptr, ImplT) else selfPtrAs(self_ptr, ImplT);
                                const f = @field(self, name);

                                return @call(if (our_cc == .Async) .{ .modifier = .async_kw } else .{ .modifier = .always_inline }, f, .{ arg1, arg2 });
                            }
                        }.impl,
                        4 => struct {
                            fn impl(self_ptr: CurrSelfType, arg1: args[1].arg_type.?, arg2: args[2].arg_type.?, arg3: args[3].arg_type.?) Return {
                                const self = if (is_const) constSelfPtrAs(self_ptr, ImplT) else selfPtrAs(self_ptr, ImplT);
                                const f = @field(self, name);

                                return @call(if (our_cc == .Async) .{ .modifier = .async_kw } else .{ .modifier = .always_inline }, f, .{ arg1, arg2, arg3 });
                            }
                        }.impl,
                        5 => struct {
                            fn impl(self_ptr: CurrSelfType, arg1: args[1].arg_type.?, arg2: args[2].arg_type.?, arg3: args[3].arg_type.?, arg4: args[4].arg_type.?) Return {
                                const self = if (is_const) constSelfPtrAs(self_ptr, ImplT) else selfPtrAs(self_ptr, ImplT);
                                const f = @field(self, name);

                                return @call(if (our_cc == .Async) .{ .modifier = .async_kw } else .{ .modifier = .always_inline }, f, .{ arg1, arg2, arg3, arg4 });
                            }
                        }.impl,
                        6 => struct {
                            fn impl(self_ptr: CurrSelfType, arg1: args[1].arg_type.?, arg2: args[2].arg_type.?, arg3: args[3].arg_type.?, arg4: args[4].arg_type.?, arg5: args[5].arg_type.?) Return {
                                const self = if (is_const) constSelfPtrAs(self_ptr, ImplT) else selfPtrAs(self_ptr, ImplT);
                                const f = @field(self, name);

                                return @call(if (our_cc == .Async) .{ .modifier = .async_kw } else .{ .modifier = .always_inline }, f, .{ arg1, arg2, arg3, arg4, arg5 });
                            }
                        }.impl,
                        else => @compileError("Unsupported number of arguments, please provide a manually written vtable."),
                    };

                    // return struct {
                    //     fn impl(self_ptr: *SelfType, args: var) Return {
                    //         const self = if (is_const) constSelfPtrAs(self_ptr, ImplT) else selfPtrAs(self_ptr, ImplT);
                    //         const f = @field(self, name);

                    //         return @call(if (our_cc == .Async) .{ .modifier = .async_kw } else .{ .modifier = .always_inline }, f, args);
                    //     }
                    // }.impl;
                },
                else => return null,
            }
        }
    }

    return null;
}

fn makeVTable(comptime VTableT: type, comptime ImplT: type) VTableT {
    if (comptime !trait.isContainer(ImplT)) {
        @compileError("Type '" ++ @typeName(ImplT) ++ "' must be a container to implement interface.");
    }
    var vtable: VTableT = undefined;

    for (std.meta.fields(VTableT)) |field| {
        var fn_type = field.field_type;
        const is_optional = trait.is(.Optional)(fn_type);
        if (is_optional) {
            fn_type = std.meta.Child(fn_type);
        }

        const candidate = comptime getFunctionFromImpl(field.name, fn_type, ImplT);
        if (candidate == null and !is_optional) {
            @compileError("Type '" ++ @typeName(ImplT) ++ "' does not implement non optional function '" ++ field.name ++ "'.");
        } else if (!is_optional) {
            @field(vtable, field.name) = candidate.?;
        } else {
            @field(vtable, field.name) = candidate;
        }
    }

    return vtable;
}

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

        switch (type_info.Fn.calling_convention) {
            .Unspecified, .Async => {},
            else => @compileError("Virtual function's  '" ++ field.name ++ "' calling convention is not default or async."),
        }

        if (type_info.Fn.args.len == 0) {
            @compileError("Virtual function '" ++ field.name ++ "' must have at least one argument.");
        }

        const arg_type = type_info.Fn.args[0].arg_type.?;
        if (arg_type != *SelfType and arg_type != *const SelfType) {
            @compileError("Virtual function's '" ++ field.name ++ "' first argument must be *SelfType or *const SelfType");
        }
    }
}

fn vtableHasMethod(comptime VTableT: type, comptime name: []const u8, is_optional: *bool) bool {
    for (std.meta.fields(VTableT)) |field| {
        if (std.mem.eql(u8, name, field.name)) {
            is_optional.* = trait.is(.Optional)(field.field_type);
            return true;
        }
    }

    return false;
}

fn VTableReturnType(comptime VTableT: type, comptime name: []const u8) type {
    for (std.meta.fields(VTableT)) |field| {
        if (std.mem.eql(u8, name, field.name)) {
            const is_optional = trait.is(.Optional)(field.field_type);
            // TODO: Do I need to do smth different for async?
            if (is_optional) {
                return ?@typeInfo(std.meta.Child(field.field_type)).Fn.return_type.?;
            }

            return @typeInfo(field.field_type).Fn.return_type orelse noreturn;
        }
    }

    @compileError("VTable type '" ++ @typeName(VTableT) ++ "' has no virtual function '" ++ name ++ "'.");
}

pub fn Interface(comptime VTableT: type, comptime StorageT: type) type {
    comptime checkVtableType(VTableT);

    return struct {
        vtable_ptr: *const VTableT,
        storage: StorageT,

        const Self = @This();

        pub fn init(args: var) !Self {
            const ImplType = PtrChildOrSelf(@TypeOf(args.@"0"));

            return Self{
                .vtable_ptr = &comptime makeVTable(VTableT, ImplType),
                .storage = try StorageT.init(args),
            };
        }

        pub fn initWithVTable(vtable_ptr: *const VTableT, args: var) !Self {
            return .{
                .vtable_ptr = vtable_ptr,
                .storage = try StorageT.init(args),
            };
        }

        pub fn call(self: Self, comptime name: []const u8, args: var) VTableReturnType(VTableT, name) {
            comptime var is_optional = true;
            comptime assert(vtableHasMethod(VTableT, name, &is_optional));

            const fn_ptr = if (is_optional) blk: {
                const val = @field(self.vtable_ptr, name);
                if (val) |v| break :blk v;
                return null;
            } else @field(self.vtable_ptr, name);

            const self_ptr = self.storage.getSelfPtr();
            const new_args = .{self_ptr};

            return @call(.{}, fn_ptr, new_args ++ args);
        }

        pub fn deinit(self: Self) void {
            self.storage.deinit();
        }
    };
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

const Fooer = Interface(struct {
    foo: fn (*SelfType) usize,
}, Storage.NonOwning);

const TestFooer = struct {
    state: usize,

    fn foo(self: *TestFooer) usize {
        const tmp = self.state;
        self.state += 1;
        return tmp;
    }
};

test "Runtime non owning simple interface" {
    var f = TestFooer{ .state = 42 };
    var fooer = try Fooer.init(.{&f});
    defer fooer.deinit();

    assert(fooer.call("foo", .{}) == 42);
    assert(fooer.call("foo", .{}) == 43);
}

test "Comptime non owning simple interface" {
    comptime {
        var f = TestFooer{ .state = 101 };
        var fooer = try Fooer.init(.{&f});
        defer fooer.deinit();

        assert(fooer.call("foo", .{}) == 101);
        assert(fooer.call("foo", .{}) == 102);
    }
}
