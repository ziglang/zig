export fn testVoid() void {
    const f: void = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testInStruct() void {
    const f: struct { f: [*]const u8 } = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testError() void {
    const f: struct { error{foo} } = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testInUnion() void {
    const f: union(enum) { a: void, b: [*c]const u8 } = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testInVector() void {
    const f: @Vector(0, [*c]const u8) = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testInOpt() void {
    const f: *const ?[*c]const u8 = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testComptimeField() void {
    const f: struct { comptime foo: ??u8 = null } = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testEnumLiteral() void {
    const f: @TypeOf(.foo) = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testNestedOpt1() void {
    const f: ??u8 = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testNestedOpt2() void {
    const f: ?*const ?u8 = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testNestedOpt3() void {
    const f: *const ?*const ?*const u8 = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testOpt() void {
    const f: ?u8 = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testNonExhaustiveEnum() void {
    const f: enum(u8) { _ } = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testUntaggedUnion() void {
    const f: union { foo: void } = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testTaggedUnionVoid() void {
    const f: union(enum) { foo: void } = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testVisited() void {
    const V = struct {
        ?f32, // Adds `?f32` to the visited list
        ??f32, // `?f32` is already visited, we need to detect the nested opt anyway
        f32,
    };
    const f: V = @import("zon/neg_inf.zon");
    _ = f;
}

export fn testMutablePointer() void {
    const f: *i32 = @import("zon/neg_inf.zon");
    _ = f;
}

// error
// imports=zon/neg_inf.zon
//
// tmp.zig:2:29: error: type 'void' is not available in ZON
// tmp.zig:7:50: error: type '[*]const u8' is not available in ZON
// tmp.zig:7:50: note: ZON does not allow many-pointers
// tmp.zig:12:46: error: type 'error{foo}' is not available in ZON
// tmp.zig:17:65: error: type '[*c]const u8' is not available in ZON
// tmp.zig:17:65: note: ZON does not allow C pointers
// tmp.zig:22:49: error: type '[*c]const u8' is not available in ZON
// tmp.zig:22:49: note: ZON does not allow C pointers
// tmp.zig:27:45: error: type '[*c]const u8' is not available in ZON
// tmp.zig:27:45: note: ZON does not allow C pointers
// tmp.zig:32:61: error: type '??u8' is not available in ZON
// tmp.zig:32:61: note: ZON does not allow nested optionals
// tmp.zig:42:29: error: type '??u8' is not available in ZON
// tmp.zig:42:29: note: ZON does not allow nested optionals
// tmp.zig:47:36: error: type '?*const ?u8' is not available in ZON
// tmp.zig:47:36: note: ZON does not allow nested optionals
// tmp.zig:52:50: error: type '?*const ?*const u8' is not available in ZON
// tmp.zig:52:50: note: ZON does not allow nested optionals
// tmp.zig:82:26: error: type '??f32' is not available in ZON
// tmp.zig:82:26: note: ZON does not allow nested optionals
// tmp.zig:87:29: error: type '*i32' is not available in ZON
// tmp.zig:87:29: note: ZON does not allow mutable pointers
// neg_inf.zon:1:1: error: expected type '@Type(.enum_literal)'
// tmp.zig:37:38: note: imported here
// neg_inf.zon:1:1: error: expected type '?u8'
// tmp.zig:57:28: note: imported here
// neg_inf.zon:1:1: error: expected type 'tmp.testNonExhaustiveEnum__enum_518'
// tmp.zig:62:39: note: imported here
// neg_inf.zon:1:1: error: expected type 'tmp.testUntaggedUnion__union_520'
// tmp.zig:67:44: note: imported here
// neg_inf.zon:1:1: error: expected type 'tmp.testTaggedUnionVoid__union_523'
// tmp.zig:72:50: note: imported here
