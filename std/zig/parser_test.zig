// TODO
//if (sr > n_uword_bits - 1)  // d > r
//    return 0;

// TODO switch with no body
// format(&size, error{}, countSize, fmt, args) catch |err| switch (err) {};


//TODO
//test "zig fmt: same-line comptime" {
//    try testCanonical(
//        \\test "" {
//        \\    comptime assert(@typeId(T) == builtin.TypeId.Int); // must pass an integer to absInt
//        \\}
//        \\
//    );
//}


test "zig fmt: float literal with exponent" {
    try testCanonical(
        \\pub const f64_true_min = 4.94065645841246544177e-324;
        \\
    );
}

test "zig fmt: line comments in struct initializer" {
    try testCanonical(
        \\fn foo() void {
        \\    return Self{
        \\        .a = b,
        \\
        \\        // Initialize these two fields to buffer_size so that
        \\        // in `readFn` we treat the state as being able to read
        \\        .start_index = buffer_size,
        \\        .end_index = buffer_size,
        \\
        \\        // middle
        \\
        \\        .a = b,
        \\
        \\        // end
        \\    };
        \\}
        \\
    );
}

test "zig fmt: doc comments before struct field" {
    try testCanonical(
        \\pub const Allocator = struct {
        \\    /// Allocate byte_count bytes and return them in a slice, with the
        \\    /// slice's pointer aligned at least to alignment bytes.
        \\    allocFn: fn() void,
        \\};
        \\
    );
}

test "zig fmt: error set declaration" {
    try testCanonical(
        \\const E = error{
        \\    A,
        \\    B,
        \\
        \\    C,
        \\};
        \\
        \\const Error = error{
        \\    /// no more memory
        \\    OutOfMemory,
        \\};
        \\
        \\const Error = error{
        \\    /// no more memory
        \\    OutOfMemory,
        \\
        \\    /// another
        \\    Another,
        \\
        \\    // end
        \\};
        \\
        \\const Error = error{OutOfMemory};
        \\const Error = error{};
        \\
    );
}

test "zig fmt: union(enum(u32)) with assigned enum values" {
    try testCanonical(
        \\const MultipleChoice = union(enum(u32)) {
        \\    A = 20,
        \\    B = 40,
        \\    C = 60,
        \\    D = 1000,
        \\};
        \\
    );
}

test "zig fmt: labeled suspend" {
    try testCanonical(
        \\fn foo() void {
        \\    s: suspend |p| {
        \\        break :s;
        \\    }
        \\}
        \\
    );
}

test "zig fmt: comments before error set decl" {
    try testCanonical(
        \\const UnexpectedError = error{
        \\    /// The Operating System returned an undocumented error code.
        \\    Unexpected,
        \\    // another
        \\    Another,
        \\
        \\    // in between
        \\
        \\    // at end
        \\};
        \\
    );
}

test "zig fmt: comments before switch prong" {
    try testCanonical(
        \\test "" {
        \\    switch (err) {
        \\        error.PathAlreadyExists => continue,
        \\
        \\        // comment 1
        \\
        \\        // comment 2
        \\        else => return err,
        \\        // at end
        \\    }
        \\}
        \\
    );
}

test "zig fmt: same-line comment after switch prong" {
    try testCanonical(
        \\test "" {
        \\    switch (err) {
        \\        error.PathAlreadyExists => {}, // comment 2
        \\        else => return err, // comment 1
        \\    }
        \\}
        \\
    );
}

test "zig fmt: comments before var decl in struct" {
    try testCanonical(
        \\pub const vfs_cap_data = extern struct {
        \\    // All of these are mandated as little endian
        \\    // when on disk.
        \\    const Data = struct {
        \\        permitted: u32,
        \\        inheritable: u32,
        \\    };
        \\
        \\    // in between
        \\
        \\    /// All of these are mandated as little endian
        \\    /// when on disk.
        \\    const Data = struct {
        \\        permitted: u32,
        \\        inheritable: u32,
        \\    };
        \\
        \\    // at end
        \\};
        \\
    );
}

test "zig fmt: same-line comment after var decl in struct" {
    try testCanonical(
        \\pub const vfs_cap_data = extern struct {
        \\    const Data = struct {}; // when on disk.
        \\};
        \\
    );
}

test "zig fmt: same-line comment after field decl" {
    try testCanonical(
        \\pub const dirent = extern struct {
        \\    d_name: u8,
        \\    d_name: u8, // comment 1
        \\    d_name: u8,
        \\    d_name: u8, // comment 2
        \\    d_name: u8,
        \\};
        \\
    );
}

test "zig fmt: array literal with 1 item on 1 line" {
    try testCanonical(
        \\var s = []const u64{0} ** 25;
        \\
    );
}

test "zig fmt: same-line comment after a statement" {
    try testCanonical(
        \\test "" {
        \\    a = b;
        \\    debug.assert(H.digest_size <= H.block_size); // HMAC makes this assumption
        \\    a = b;
        \\}
        \\
    );
}

test "zig fmt: comments before global variables" {
    try testCanonical(
        \\/// Foo copies keys and values before they go into the map, and
        \\/// frees them when they get removed.
        \\pub const Foo = struct {};
        \\
    );
}

test "zig fmt: comments in statements" {
    try testCanonical(
        \\test "std" {
        \\    // statement comment
        \\    _ = @import("foo/bar.zig");
        \\
        \\    // middle
        \\    // middle2
        \\
        \\    // end
        \\}
        \\
    );
}

test "zig fmt: comments before test decl" {
    try testCanonical(
        \\/// top level doc comment
        \\test "hi" {}
        \\
        \\// top level normal comment
        \\test "hi" {}
        \\
        \\// middle
        \\
        \\// end
        \\
    );
}

test "zig fmt: preserve spacing" {
    try testCanonical(
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    var stdout_file = try std.io.getStdOut;
        \\    var stdout_file = try std.io.getStdOut;
        \\
        \\    var stdout_file = try std.io.getStdOut;
        \\    var stdout_file = try std.io.getStdOut;
        \\}
        \\
    );
}

test "zig fmt: return types" {
    try testCanonical(
        \\pub fn main() !void {}
        \\pub fn main() var {}
        \\pub fn main() i32 {}
        \\
    );
}

test "zig fmt: imports" {
    try testCanonical(
        \\const std = @import("std");
        \\const std = @import();
        \\
    );
}

test "zig fmt: global declarations" {
    try testCanonical(
        \\const a = b;
        \\pub const a = b;
        \\var a = b;
        \\pub var a = b;
        \\const a: i32 = b;
        \\pub const a: i32 = b;
        \\var a: i32 = b;
        \\pub var a: i32 = b;
        \\extern const a: i32 = b;
        \\pub extern const a: i32 = b;
        \\extern var a: i32 = b;
        \\pub extern var a: i32 = b;
        \\extern "a" const a: i32 = b;
        \\pub extern "a" const a: i32 = b;
        \\extern "a" var a: i32 = b;
        \\pub extern "a" var a: i32 = b;
        \\
    );
}

test "zig fmt: extern declaration" {
    try testCanonical(
        \\extern var foo: c_int;
        \\
    );
}

test "zig fmt: alignment" {
        try testCanonical(
        \\var foo: c_int align(1);
        \\
    );
}

test "zig fmt: C main" {
    try testCanonical(
        \\fn main(argc: c_int, argv: &&u8) c_int {
        \\    const a = b;
        \\}
        \\
    );
}

test "zig fmt: return" {
    try testCanonical(
        \\fn foo(argc: c_int, argv: &&u8) c_int {
        \\    return 0;
        \\}
        \\
        \\fn bar() void {
        \\    return;
        \\}
        \\
    );
}

test "zig fmt: pointer attributes" {
    try testCanonical(
        \\extern fn f1(s: &align(&u8) u8) c_int;
        \\extern fn f2(s: &&align(1) &const &volatile u8) c_int;
        \\extern fn f3(s: &align(1) const &align(1) volatile &const volatile u8) c_int;
        \\extern fn f4(s: &align(1) const volatile u8) c_int;
        \\
    );
}

test "zig fmt: slice attributes" {
    try testCanonical(
        \\extern fn f1(s: &align(&u8) u8) c_int;
        \\extern fn f2(s: &&align(1) &const &volatile u8) c_int;
        \\extern fn f3(s: &align(1) const &align(1) volatile &const volatile u8) c_int;
        \\extern fn f4(s: &align(1) const volatile u8) c_int;
        \\
    );
}

test "zig fmt: test declaration" {
     try testCanonical(
        \\test "test name" {
        \\    const a = 1;
        \\    var b = 1;
        \\}
        \\
    );
}

test "zig fmt: infix operators" {
    try testCanonical(
        \\test "infix operators" {
        \\    var i = undefined;
        \\    i = 2;
        \\    i *= 2;
        \\    i |= 2;
        \\    i ^= 2;
        \\    i <<= 2;
        \\    i >>= 2;
        \\    i &= 2;
        \\    i *= 2;
        \\    i *%= 2;
        \\    i -= 2;
        \\    i -%= 2;
        \\    i += 2;
        \\    i +%= 2;
        \\    i /= 2;
        \\    i %= 2;
        \\    _ = i == i;
        \\    _ = i != i;
        \\    _ = i != i;
        \\    _ = i.i;
        \\    _ = i || i;
        \\    _ = i!i;
        \\    _ = i ** i;
        \\    _ = i ++ i;
        \\    _ = i ?? i;
        \\    _ = i % i;
        \\    _ = i / i;
        \\    _ = i *% i;
        \\    _ = i * i;
        \\    _ = i -% i;
        \\    _ = i - i;
        \\    _ = i +% i;
        \\    _ = i + i;
        \\    _ = i << i;
        \\    _ = i >> i;
        \\    _ = i & i;
        \\    _ = i ^ i;
        \\    _ = i | i;
        \\    _ = i >= i;
        \\    _ = i <= i;
        \\    _ = i > i;
        \\    _ = i < i;
        \\    _ = i and i;
        \\    _ = i or i;
        \\}
        \\
    );
}

test "zig fmt: precedence" {
    try testCanonical(
        \\test "precedence" {
        \\    a!b();
        \\    (a!b)();
        \\    !a!b;
        \\    !(a!b);
        \\    !a{};
        \\    !(a{});
        \\    a + b{};
        \\    (a + b){};
        \\    a << b + c;
        \\    (a << b) + c;
        \\    a & b << c;
        \\    (a & b) << c;
        \\    a ^ b & c;
        \\    (a ^ b) & c;
        \\    a | b ^ c;
        \\    (a | b) ^ c;
        \\    a == b | c;
        \\    (a == b) | c;
        \\    a and b == c;
        \\    (a and b) == c;
        \\    a or b and c;
        \\    (a or b) and c;
        \\    (a or b) and c;
        \\}
        \\
    );
}

test "zig fmt: prefix operators" {
    try testCanonical(
        \\test "prefix operators" {
        \\    try return --%~??!*&0;
        \\}
        \\
    );
}

test "zig fmt: call expression" {
    try testCanonical(
        \\test "test calls" {
        \\    a();
        \\    a(1);
        \\    a(1, 2);
        \\    a(1, 2) + a(1, 2);
        \\}
        \\
    );
}

test "zig fmt: var args" {
    try testCanonical(
        \\fn print(args: ...) void {}
        \\
    );
}

test "zig fmt: var type" {
    try testCanonical(
        \\fn print(args: var) var {}
        \\const Var = var;
        \\const i: var = 0;
        \\
    );
}

test "zig fmt: functions" {
    try testCanonical(
        \\extern fn puts(s: &const u8) c_int;
        \\extern "c" fn puts(s: &const u8) c_int;
        \\export fn puts(s: &const u8) c_int;
        \\inline fn puts(s: &const u8) c_int;
        \\pub extern fn puts(s: &const u8) c_int;
        \\pub extern "c" fn puts(s: &const u8) c_int;
        \\pub export fn puts(s: &const u8) c_int;
        \\pub inline fn puts(s: &const u8) c_int;
        \\pub extern fn puts(s: &const u8) align(2 + 2) c_int;
        \\pub extern "c" fn puts(s: &const u8) align(2 + 2) c_int;
        \\pub export fn puts(s: &const u8) align(2 + 2) c_int;
        \\pub inline fn puts(s: &const u8) align(2 + 2) c_int;
        \\
    );
}

test "zig fmt: multiline string" {
    try testCanonical(
        \\test "" {
        \\    const s1 =
        \\        \\one
        \\        \\two)
        \\        \\three
        \\    ;
        \\    const s2 =
        \\        c\\one
        \\        c\\two)
        \\        c\\three
        \\    ;
        \\}
        \\
    );
}

test "zig fmt: values" {
    try testCanonical(
        \\test "values" {
        \\    1;
        \\    1.0;
        \\    "string";
        \\    c"cstring";
        \\    'c';
        \\    true;
        \\    false;
        \\    null;
        \\    undefined;
        \\    error;
        \\    this;
        \\    unreachable;
        \\}
        \\
    );
}

test "zig fmt: indexing" {
    try testCanonical(
        \\test "test index" {
        \\    a[0];
        \\    a[0 + 5];
        \\    a[0..];
        \\    a[0..5];
        \\    a[a[0]];
        \\    a[a[0..]];
        \\    a[a[0..5]];
        \\    a[a[0]..];
        \\    a[a[0..5]..];
        \\    a[a[0]..a[0]];
        \\    a[a[0..5]..a[0]];
        \\    a[a[0..5]..a[0..5]];
        \\}
        \\
    );
}

test "zig fmt: struct declaration" {
    try testCanonical(
        \\const S = struct {
        \\    const Self = this;
        \\    f1: u8,
        \\    pub f3: u8,
        \\
        \\    fn method(self: &Self) Self {
        \\        return *self;
        \\    }
        \\
        \\    f2: u8,
        \\};
        \\
        \\const Ps = packed struct {
        \\    a: u8,
        \\    pub b: u8,
        \\
        \\    c: u8,
        \\};
        \\
        \\const Es = extern struct {
        \\    a: u8,
        \\    pub b: u8,
        \\
        \\    c: u8,
        \\};
        \\
    );
}

test "zig fmt: enum declaration" {
      try testCanonical(
        \\const E = enum {
        \\    Ok,
        \\    SomethingElse = 0,
        \\};
        \\
        \\const E2 = enum(u8) {
        \\    Ok,
        \\    SomethingElse = 255,
        \\    SomethingThird,
        \\};
        \\
        \\const Ee = extern enum {
        \\    Ok,
        \\    SomethingElse,
        \\    SomethingThird,
        \\};
        \\
        \\const Ep = packed enum {
        \\    Ok,
        \\    SomethingElse,
        \\    SomethingThird,
        \\};
        \\
    );
}

test "zig fmt: union declaration" {
      try testCanonical(
        \\const U = union {
        \\    Int: u8,
        \\    Float: f32,
        \\    None,
        \\    Bool: bool,
        \\};
        \\
        \\const Ue = union(enum) {
        \\    Int: u8,
        \\    Float: f32,
        \\    None,
        \\    Bool: bool,
        \\};
        \\
        \\const E = enum {
        \\    Int,
        \\    Float,
        \\    None,
        \\    Bool,
        \\};
        \\
        \\const Ue2 = union(E) {
        \\    Int: u8,
        \\    Float: f32,
        \\    None,
        \\    Bool: bool,
        \\};
        \\
        \\const Eu = extern union {
        \\    Int: u8,
        \\    Float: f32,
        \\    None,
        \\    Bool: bool,
        \\};
        \\
    );
}

test "zig fmt: arrays" {
    try testCanonical(
        \\test "test array" {
        \\    const a: [2]u8 = [2]u8{
        \\        1,
        \\        2,
        \\    };
        \\    const a: [2]u8 = []u8{
        \\        1,
        \\        2,
        \\    };
        \\    const a: [0]u8 = []u8{};
        \\}
        \\
    );
}

test "zig fmt: container initializers" {
    try testCanonical(
        \\const a0 = []u8{};
        \\const a1 = []u8{1};
        \\const a2 = []u8{
        \\    1,
        \\    2,
        \\    3,
        \\    4,
        \\};
        \\const s0 = S{};
        \\const s1 = S{ .a = 1 };
        \\const s2 = S{
        \\    .a = 1,
        \\    .b = 2,
        \\};
        \\
    );
}

test "zig fmt: catch" {
    try testCanonical(
        \\test "catch" {
        \\    const a: error!u8 = 0;
        \\    _ = a catch return;
        \\    _ = a catch |err| return;
        \\}
        \\
    );
}

test "zig fmt: blocks" {
    try testCanonical(
        \\test "blocks" {
        \\    {
        \\        const a = 0;
        \\        const b = 0;
        \\    }
        \\
        \\    blk: {
        \\        const a = 0;
        \\        const b = 0;
        \\    }
        \\
        \\    const r = blk: {
        \\        const a = 0;
        \\        const b = 0;
        \\    };
        \\}
        \\
    );
}

test "zig fmt: switch" {
    try testCanonical(
        \\test "switch" {
        \\    switch (0) {
        \\        0 => {},
        \\        1 => unreachable,
        \\        2,
        \\        3 => {},
        \\        4 ... 7 => {},
        \\        1 + 4 * 3 + 22 => {},
        \\        else => {
        \\            const a = 1;
        \\            const b = a;
        \\        },
        \\    }
        \\
        \\    const res = switch (0) {
        \\        0 => 0,
        \\        1 => 2,
        \\        1 => a = 4,
        \\        else => 4,
        \\    };
        \\
        \\    const Union = union(enum) {
        \\        Int: i64,
        \\        Float: f64,
        \\    };
        \\
        \\    switch (u) {
        \\        Union.Int => |int| {},
        \\        Union.Float => |*float| unreachable,
        \\    }
        \\}
        \\
    );
}

test "zig fmt: while" {
    try testCanonical(
        \\test "while" {
        \\    while (10 < 1) {
        \\        unreachable;
        \\    }
        \\
        \\    while (10 < 1)
        \\        unreachable;
        \\
        \\    var i: usize = 0;
        \\    while (i < 10) : (i += 1) {
        \\        continue;
        \\    }
        \\
        \\    i = 0;
        \\    while (i < 10) : (i += 1)
        \\        continue;
        \\
        \\    i = 0;
        \\    var j: usize = 0;
        \\    while (i < 10) : ({
        \\        i += 1;
        \\        j += 1;
        \\    }) {
        \\        continue;
        \\    }
        \\
        \\    var a: ?u8 = 2;
        \\    while (a) |v| : (a = null) {
        \\        continue;
        \\    }
        \\
        \\    while (a) |v| : (a = null)
        \\        unreachable;
        \\
        \\    label: while (10 < 0) {
        \\        unreachable;
        \\    }
        \\
        \\    const res = while (0 < 10) {
        \\        break 7;
        \\    } else {
        \\        unreachable;
        \\    };
        \\
        \\    const res = while (0 < 10)
        \\        break 7
        \\    else
        \\        unreachable;
        \\
        \\    var a: error!u8 = 0;
        \\    while (a) |v| {
        \\        a = error.Err;
        \\    } else |err| {
        \\        i = 1;
        \\    }
        \\
        \\    comptime var k: usize = 0;
        \\    inline while (i < 10) : (i += 1)
        \\        j += 2;
        \\}
        \\
    );
}

test "zig fmt: for" {
    try testCanonical(
        \\test "for" {
        \\    for (a) |v| {
        \\        continue;
        \\    }
        \\
        \\    for (a) |v|
        \\        continue;
        \\
        \\    for (a) |*v|
        \\        continue;
        \\
        \\    for (a) |v, i| {
        \\        continue;
        \\    }
        \\
        \\    for (a) |v, i|
        \\        continue;
        \\
        \\    const res = for (a) |v, i| {
        \\        break v;
        \\    } else {
        \\        unreachable;
        \\    };
        \\
        \\    var num: usize = 0;
        \\    inline for (a) |v, i| {
        \\        num += v;
        \\        num += i;
        \\    }
        \\}
        \\
    );
}

test "zig fmt: if" {
    try testCanonical(
        \\test "if" {
        \\    if (10 < 0) {
        \\        unreachable;
        \\    }
        \\
        \\    if (10 < 0) unreachable;
        \\
        \\    if (10 < 0) {
        \\        unreachable;
        \\    } else {
        \\        const a = 20;
        \\    }
        \\
        \\    if (10 < 0) {
        \\        unreachable;
        \\    } else if (5 < 0) {
        \\        unreachable;
        \\    } else {
        \\        const a = 20;
        \\    }
        \\
        \\    const is_world_broken = if (10 < 0) true else false;
        \\    const some_number = 1 + if (10 < 0) 2 else 3;
        \\
        \\    const a: ?u8 = 10;
        \\    const b: ?u8 = null;
        \\    if (a) |v| {
        \\        const some = v;
        \\    } else if (b) |*v| {
        \\        unreachable;
        \\    } else {
        \\        const some = 10;
        \\    }
        \\
        \\    const non_null_a = if (a) |v| v else 0;
        \\
        \\    const a_err: error!u8 = 0;
        \\    if (a_err) |v| {
        \\        const p = v;
        \\    } else |err| {
        \\        unreachable;
        \\    }
        \\}
        \\
    );
}

test "zig fmt: defer" {
    try testCanonical(
        \\test "defer" {
        \\    var i: usize = 0;
        \\    defer i = 1;
        \\    defer {
        \\        i += 2;
        \\        i *= i;
        \\    }
        \\
        \\    errdefer i += 3;
        \\    errdefer {
        \\        i += 2;
        \\        i /= i;
        \\    }
        \\}
        \\
    );
}

test "zig fmt: comptime" {
    try testCanonical(
        \\fn a() u8 {
        \\    return 5;
        \\}
        \\
        \\fn b(comptime i: u8) u8 {
        \\    return i;
        \\}
        \\
        \\const av = comptime a();
        \\const av2 = comptime blk: {
        \\    var res = a();
        \\    res *= b(2);
        \\    break :blk res;
        \\};
        \\
        \\comptime {
        \\    _ = a();
        \\}
        \\
        \\test "comptime" {
        \\    const av3 = comptime a();
        \\    const av4 = comptime blk: {
        \\        var res = a();
        \\        res *= a();
        \\        break :blk res;
        \\    };
        \\
        \\    comptime var i = 0;
        \\    comptime {
        \\        i = a();
        \\        i += b(i);
        \\    }
        \\}
        \\
    );
}

test "zig fmt: fn type" {
    try testCanonical(
        \\fn a(i: u8) u8 {
        \\    return i + 1;
        \\}
        \\
        \\const a: fn(u8) u8 = undefined;
        \\const b: extern fn(u8) u8 = undefined;
        \\const c: nakedcc fn(u8) u8 = undefined;
        \\const ap: fn(u8) u8 = a;
        \\
    );
}

test "zig fmt: inline asm" {
    try testCanonical(
        \\pub fn syscall1(number: usize, arg1: usize) usize {
        \\    return asm volatile ("syscall"
        \\        : [ret] "={rax}" (-> usize)
        \\        : [number] "{rax}" (number),
        \\          [arg1] "{rdi}" (arg1)
        \\        : "rcx", "r11");
        \\}
        \\
    );
}

test "zig fmt: coroutines" {
    try testCanonical(
        \\async fn simpleAsyncFn() void {
        \\    const a = async a.b();
        \\    x += 1;
        \\    suspend;
        \\    x += 1;
        \\    suspend |p| {}
        \\    const p: promise->void = async simpleAsyncFn() catch unreachable;
        \\    await p;
        \\}
        \\
        \\test "coroutine suspend, resume, cancel" {
        \\    const p: promise = try async<std.debug.global_allocator> testAsyncSeq();
        \\    resume p;
        \\    cancel p;
        \\}
        \\
    );
}

test "zig fmt: Block after if" {
    try testCanonical(
        \\test "Block after if" {
        \\    if (true) {
        \\        const a = 0;
        \\    }
        \\
        \\    {
        \\        const a = 0;
        \\    }
        \\}
        \\
    );
}

test "zig fmt: use" {
    try testCanonical(
        \\use @import("std");
        \\pub use @import("std");
        \\
    );
}

test "zig fmt: string identifier" {
    try testCanonical(
        \\const @"a b" = @"c d".@"e f";
        \\fn @"g h"() void {}
        \\
    );
}

test "zig fmt: error return" {
    try testCanonical(
        \\fn err() error {
        \\    call();
        \\    return error.InvalidArgs;
        \\}
        \\
    );
}

const std = @import("std");
const mem = std.mem;
const warn = std.debug.warn;
const Tokenizer = std.zig.Tokenizer;
const Parser = std.zig.Parser;
const io = std.io;

var fixed_buffer_mem: [100 * 1024]u8 = undefined;

fn testParse(source: []const u8, allocator: &mem.Allocator) ![]u8 {
    var tokenizer = Tokenizer.init(source);
    var parser = Parser.init(&tokenizer, allocator, "(memory buffer)");
    defer parser.deinit();

    var tree = try parser.parse();
    defer tree.deinit();

    var buffer = try std.Buffer.initSize(allocator, 0);
    errdefer buffer.deinit();

    var buffer_out_stream = io.BufferOutStream.init(&buffer);
    try parser.renderSource(&buffer_out_stream.stream, tree.root_node);
    return buffer.toOwnedSlice();
}

fn testCanonical(source: []const u8) !void {
    const needed_alloc_count = x: {
        // Try it once with unlimited memory, make sure it works
        var fixed_allocator = std.heap.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
        var failing_allocator = std.debug.FailingAllocator.init(&fixed_allocator.allocator, @maxValue(usize));
        const result_source = try testParse(source, &failing_allocator.allocator);
        if (!mem.eql(u8, result_source, source)) {
            warn("\n====== expected this output: =========\n");
            warn("{}", source);
            warn("\n======== instead found this: =========\n");
            warn("{}", result_source);
            warn("\n======================================\n");
            return error.TestFailed;
        }
        failing_allocator.allocator.free(result_source);
        break :x failing_allocator.index;
    };

    var fail_index: usize = 0;
    while (fail_index < needed_alloc_count) : (fail_index += 1) {
        var fixed_allocator = std.heap.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
        var failing_allocator = std.debug.FailingAllocator.init(&fixed_allocator.allocator, fail_index);
        if (testParse(source, &failing_allocator.allocator)) |_| {
            return error.NondeterministicMemoryUsage;
        } else |err| switch (err) {
            error.OutOfMemory => {
                if (failing_allocator.allocated_bytes != failing_allocator.freed_bytes) {
                    warn("\nfail_index: {}/{}\nallocated bytes: {}\nfreed bytes: {}\nallocations: {}\ndeallocations: {}\n",
                        fail_index, needed_alloc_count,
                        failing_allocator.allocated_bytes, failing_allocator.freed_bytes,
                        failing_allocator.index, failing_allocator.deallocations);
                    return error.MemoryLeakDetected;
                }
            },
            error.ParseError => @panic("test failed"),
        }
    }
}

