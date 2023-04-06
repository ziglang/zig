const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const yaml_mod = @import("../yaml.zig");
const Yaml = yaml_mod.Yaml;

test "simple list" {
    const source =
        \\- a
        \\- b
        \\- c
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectEqual(yaml.docs.items.len, 1);

    const list = yaml.docs.items[0].list;
    try testing.expectEqual(list.len, 3);

    try testing.expectEqualStrings("a", list[0].string);
    try testing.expectEqualStrings("b", list[1].string);
    try testing.expectEqualStrings("c", list[2].string);
}

test "simple list typed as array of strings" {
    const source =
        \\- a
        \\- b
        \\- c
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectEqual(yaml.docs.items.len, 1);

    const arr = try yaml.parse([3][]const u8);
    try testing.expectEqual(3, arr.len);
    try testing.expectEqualStrings("a", arr[0]);
    try testing.expectEqualStrings("b", arr[1]);
    try testing.expectEqualStrings("c", arr[2]);
}

test "simple list typed as array of ints" {
    const source =
        \\- 0
        \\- 1
        \\- 2
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectEqual(yaml.docs.items.len, 1);

    const arr = try yaml.parse([3]u8);
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 1, 2 }, &arr);
}

test "list of mixed sign integer" {
    const source =
        \\- 0
        \\- -1
        \\- 2
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectEqual(yaml.docs.items.len, 1);

    const arr = try yaml.parse([3]i8);
    try testing.expectEqualSlices(i8, &[_]i8{ 0, -1, 2 }, &arr);
}

test "simple map untyped" {
    const source =
        \\a: 0
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expectEqual(@as(i64, 0), map.get("a").?.int);
}

test "simple map untyped with a list of maps" {
    const source =
        \\a: 0
        \\b:
        \\  - foo: 1
        \\    bar: 2
        \\  - foo: 3
        \\    bar: 4
        \\c: 1
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqual(@as(i64, 0), map.get("a").?.int);
    try testing.expectEqual(@as(i64, 1), map.get("c").?.int);
    try testing.expectEqual(@as(i64, 1), map.get("b").?.list[0].map.get("foo").?.int);
    try testing.expectEqual(@as(i64, 2), map.get("b").?.list[0].map.get("bar").?.int);
    try testing.expectEqual(@as(i64, 3), map.get("b").?.list[1].map.get("foo").?.int);
    try testing.expectEqual(@as(i64, 4), map.get("b").?.list[1].map.get("bar").?.int);
}

test "simple map untyped with a list of maps. no indent" {
    const source =
        \\b:
        \\- foo: 1
        \\c: 1
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqual(@as(i64, 1), map.get("c").?.int);
    try testing.expectEqual(@as(i64, 1), map.get("b").?.list[0].map.get("foo").?.int);
}

test "simple map untyped with a list of maps. no indent 2" {
    const source =
        \\a: 0
        \\b:
        \\- foo: 1
        \\  bar: 2
        \\- foo: 3
        \\  bar: 4
        \\c: 1
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqual(@as(i64, 0), map.get("a").?.int);
    try testing.expectEqual(@as(i64, 1), map.get("c").?.int);
    try testing.expectEqual(@as(i64, 1), map.get("b").?.list[0].map.get("foo").?.int);
    try testing.expectEqual(@as(i64, 2), map.get("b").?.list[0].map.get("bar").?.int);
    try testing.expectEqual(@as(i64, 3), map.get("b").?.list[1].map.get("foo").?.int);
    try testing.expectEqual(@as(i64, 4), map.get("b").?.list[1].map.get("bar").?.int);
}

test "simple map typed" {
    const source =
        \\a: 0
        \\b: hello there
        \\c: 'wait, what?'
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    const simple = try yaml.parse(struct { a: usize, b: []const u8, c: []const u8 });
    try testing.expectEqual(@as(usize, 0), simple.a);
    try testing.expectEqualStrings("hello there", simple.b);
    try testing.expectEqualStrings("wait, what?", simple.c);
}

test "typed nested structs" {
    const source =
        \\a:
        \\  b: hello there
        \\  c: 'wait, what?'
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    const simple = try yaml.parse(struct {
        a: struct {
            b: []const u8,
            c: []const u8,
        },
    });
    try testing.expectEqualStrings("hello there", simple.a.b);
    try testing.expectEqualStrings("wait, what?", simple.a.c);
}

test "single quoted string" {
    const source =
        \\- 'hello'
        \\- 'here''s an escaped quote'
        \\- 'newlines and tabs\nare not\tsupported'
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    const arr = try yaml.parse([3][]const u8);
    try testing.expectEqual(arr.len, 3);
    try testing.expectEqualStrings("hello", arr[0]);
    try testing.expectEqualStrings("here's an escaped quote", arr[1]);
    try testing.expectEqualStrings("newlines and tabs\\nare not\\tsupported", arr[2]);
}

test "double quoted string" {
    const source =
        \\- "hello"
        \\- "\"here\" are some escaped quotes"
        \\- "newlines and tabs\nare\tsupported"
        \\- "let's have
        \\some fun!"
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    const arr = try yaml.parse([4][]const u8);
    try testing.expectEqual(arr.len, 4);
    try testing.expectEqualStrings("hello", arr[0]);
    try testing.expectEqualStrings(
        \\"here" are some escaped quotes
    , arr[1]);
    try testing.expectEqualStrings(
        \\newlines and tabs
        \\are	supported
    , arr[2]);
    try testing.expectEqualStrings(
        \\let's have
        \\some fun!
    , arr[3]);
}

test "multidoc typed as a slice of structs" {
    const source =
        \\---
        \\a: 0
        \\---
        \\a: 1
        \\...
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    {
        const result = try yaml.parse([2]struct { a: usize });
        try testing.expectEqual(result.len, 2);
        try testing.expectEqual(result[0].a, 0);
        try testing.expectEqual(result[1].a, 1);
    }

    {
        const result = try yaml.parse([]struct { a: usize });
        try testing.expectEqual(result.len, 2);
        try testing.expectEqual(result[0].a, 0);
        try testing.expectEqual(result[1].a, 1);
    }
}

test "multidoc typed as a struct is an error" {
    const source =
        \\---
        \\a: 0
        \\---
        \\b: 1
        \\...
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(struct { a: usize }));
    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(struct { b: usize }));
    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(struct { a: usize, b: usize }));
}

test "multidoc typed as a slice of structs with optionals" {
    const source =
        \\---
        \\a: 0
        \\c: 1.0
        \\---
        \\a: 1
        \\b: different field
        \\...
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    const result = try yaml.parse([]struct { a: usize, b: ?[]const u8, c: ?f16 });
    try testing.expectEqual(result.len, 2);

    try testing.expectEqual(result[0].a, 0);
    try testing.expect(result[0].b == null);
    try testing.expect(result[0].c != null);
    try testing.expectEqual(result[0].c.?, 1.0);

    try testing.expectEqual(result[1].a, 1);
    try testing.expect(result[1].b != null);
    try testing.expectEqualStrings("different field", result[1].b.?);
    try testing.expect(result[1].c == null);
}

test "empty yaml can be represented as void" {
    const source = "";
    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();
    const result = try yaml.parse(void);
    try testing.expect(@TypeOf(result) == void);
}

test "nonempty yaml cannot be represented as void" {
    const source =
        \\a: b
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(void));
}

test "typed array size mismatch" {
    const source =
        \\- 0
        \\- 0
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectError(Yaml.Error.ArraySizeMismatch, yaml.parse([1]usize));
    try testing.expectError(Yaml.Error.ArraySizeMismatch, yaml.parse([5]usize));
}

test "comments" {
    const source =
        \\
        \\key: # this is the key
        \\# first value
        \\
        \\- val1
        \\
        \\# second value
        \\- val2
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    const simple = try yaml.parse(struct {
        key: []const []const u8,
    });
    try testing.expect(simple.key.len == 2);
    try testing.expectEqualStrings("val1", simple.key[0]);
    try testing.expectEqualStrings("val2", simple.key[1]);
}

test "promote ints to floats in a list mixed numeric types" {
    const source =
        \\a_list: [0, 1.0]
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    const simple = try yaml.parse(struct {
        a_list: []const f64,
    });
    try testing.expectEqualSlices(f64, &[_]f64{ 0.0, 1.0 }, simple.a_list);
}

test "demoting floats to ints in a list is an error" {
    const source =
        \\a_list: [0, 1.0]
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectError(error.TypeMismatch, yaml.parse(struct {
        a_list: []const u64,
    }));
}

test "duplicate map keys" {
    const source =
        \\a: b
        \\a: c
    ;
    try testing.expectError(error.DuplicateMapKey, Yaml.load(testing.allocator, source));
}

fn testStringify(expected: []const u8, input: anytype) !void {
    var output = std.ArrayList(u8).init(testing.allocator);
    defer output.deinit();

    try yaml_mod.stringify(testing.allocator, input, output.writer());
    try testing.expectEqualStrings(expected, output.items);
}

test "stringify an int" {
    try testStringify("128", @as(u32, 128));
}

test "stringify a simple struct" {
    try testStringify(
        \\a: 1
        \\b: 2
        \\c: 2.5
    , struct { a: i64, b: f64, c: f64 }{ .a = 1, .b = 2.0, .c = 2.5 });
}

test "stringify a struct with an optional" {
    try testStringify(
        \\a: 1
        \\b: 2
        \\c: 2.5
    , struct { a: i64, b: ?f64, c: f64 }{ .a = 1, .b = 2.0, .c = 2.5 });

    try testStringify(
        \\a: 1
        \\c: 2.5
    , struct { a: i64, b: ?f64, c: f64 }{ .a = 1, .b = null, .c = 2.5 });
}

test "stringify a struct with all optionals" {
    try testStringify("", struct { a: ?i64, b: ?f64 }{ .a = null, .b = null });
}

test "stringify an optional" {
    try testStringify("", null);
    try testStringify("", @as(?u64, null));
}

test "stringify a union" {
    const Dummy = union(enum) {
        x: u64,
        y: f64,
    };
    try testStringify("a: 1", struct { a: Dummy }{ .a = .{ .x = 1 } });
    try testStringify("a: 2.1", struct { a: Dummy }{ .a = .{ .y = 2.1 } });
}

test "stringify a string" {
    try testStringify("a: name", struct { a: []const u8 }{ .a = "name" });
    try testStringify("name", "name");
}

test "stringify a list" {
    try testStringify("[ 1, 2, 3 ]", @as([]const u64, &.{ 1, 2, 3 }));
    try testStringify("[ 1, 2, 3 ]", .{ @as(i64, 1), 2, 3 });
    try testStringify("[ 1, name, 3 ]", .{ 1, "name", 3 });

    const arr: [3]i64 = .{ 1, 2, 3 };
    try testStringify("[ 1, 2, 3 ]", arr);
}
