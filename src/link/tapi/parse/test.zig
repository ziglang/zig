const std = @import("std");
const mem = std.mem;
const testing = std.testing;

usingnamespace @import("../parse.zig");

test "explicit doc" {
    const source =
        \\--- !tapi-tbd
        \\tbd-version: 4
        \\abc-version: 5
        \\...
    ;

    var tree = Tree.init(testing.allocator);
    defer tree.deinit();
    try tree.parse(source);

    try testing.expectEqual(tree.docs.items.len, 1);

    const doc = tree.docs.items[0].cast(Node.Doc).?;
    try testing.expectEqual(doc.start.?, 0);
    try testing.expectEqual(doc.end.?, tree.tokens.len - 2);

    const directive = tree.tokens[doc.directive.?];
    try testing.expectEqual(directive.id, .Literal);
    try testing.expect(mem.eql(u8, "tapi-tbd", tree.source[directive.start..directive.end]));

    try testing.expect(doc.value != null);
    try testing.expectEqual(doc.value.?.tag, .map);

    const map = doc.value.?.cast(Node.Map).?;
    try testing.expectEqual(map.start.?, 5);
    try testing.expectEqual(map.end.?, 14);
    try testing.expectEqual(map.values.items.len, 2);

    {
        const entry = map.values.items[0];

        const key = tree.tokens[entry.key];
        try testing.expectEqual(key.id, .Literal);
        try testing.expect(mem.eql(u8, "tbd-version", tree.source[key.start..key.end]));

        const value = entry.value.cast(Node.Value).?;
        const value_tok = tree.tokens[value.start.?];
        try testing.expectEqual(value_tok.id, .Literal);
        try testing.expect(mem.eql(u8, "4", tree.source[value_tok.start..value_tok.end]));
    }

    {
        const entry = map.values.items[1];

        const key = tree.tokens[entry.key];
        try testing.expectEqual(key.id, .Literal);
        try testing.expect(mem.eql(u8, "abc-version", tree.source[key.start..key.end]));

        const value = entry.value.cast(Node.Value).?;
        const value_tok = tree.tokens[value.start.?];
        try testing.expectEqual(value_tok.id, .Literal);
        try testing.expect(mem.eql(u8, "5", tree.source[value_tok.start..value_tok.end]));
    }
}

test "leaf in quotes" {
    const source =
        \\key1: no quotes
        \\key2: 'single quoted'
        \\key3: "double quoted"
    ;

    var tree = Tree.init(testing.allocator);
    defer tree.deinit();
    try tree.parse(source);

    try testing.expectEqual(tree.docs.items.len, 1);

    const doc = tree.docs.items[0].cast(Node.Doc).?;
    try testing.expectEqual(doc.start.?, 0);
    try testing.expectEqual(doc.end.?, tree.tokens.len - 2);
    try testing.expect(doc.directive == null);

    try testing.expect(doc.value != null);
    try testing.expectEqual(doc.value.?.tag, .map);

    const map = doc.value.?.cast(Node.Map).?;
    try testing.expectEqual(map.start.?, 0);
    try testing.expectEqual(map.end.?, tree.tokens.len - 2);
    try testing.expectEqual(map.values.items.len, 3);

    {
        const entry = map.values.items[0];

        const key = tree.tokens[entry.key];
        try testing.expectEqual(key.id, .Literal);
        try testing.expect(mem.eql(
            u8,
            "key1",
            tree.source[key.start..key.end],
        ));

        const value = entry.value.cast(Node.Value).?;
        const start = tree.tokens[value.start.?];
        const end = tree.tokens[value.end.?];
        try testing.expectEqual(start.id, .Literal);
        try testing.expectEqual(end.id, .Literal);
        try testing.expect(mem.eql(
            u8,
            "no quotes",
            tree.source[start.start..end.end],
        ));
    }
}

test "nested maps" {
    const source =
        \\key1:
        \\  key1_1 : value1_1
        \\  key1_2 : value1_2
        \\key2   : value2
    ;

    var tree = Tree.init(testing.allocator);
    defer tree.deinit();
    try tree.parse(source);

    try testing.expectEqual(tree.docs.items.len, 1);

    const doc = tree.docs.items[0].cast(Node.Doc).?;
    try testing.expectEqual(doc.start.?, 0);
    try testing.expectEqual(doc.end.?, tree.tokens.len - 2);
    try testing.expect(doc.directive == null);

    try testing.expect(doc.value != null);
    try testing.expectEqual(doc.value.?.tag, .map);

    const map = doc.value.?.cast(Node.Map).?;
    try testing.expectEqual(map.start.?, 0);
    try testing.expectEqual(map.end.?, tree.tokens.len - 2);
    try testing.expectEqual(map.values.items.len, 2);

    {
        const entry = map.values.items[0];

        const key = tree.tokens[entry.key];
        try testing.expectEqual(key.id, .Literal);
        try testing.expect(mem.eql(u8, "key1", tree.source[key.start..key.end]));

        const nested_map = entry.value.cast(Node.Map).?;
        try testing.expectEqual(nested_map.start.?, 4);
        try testing.expectEqual(nested_map.end.?, 16);
        try testing.expectEqual(nested_map.values.items.len, 2);

        {
            const nested_entry = nested_map.values.items[0];

            const nested_key = tree.tokens[nested_entry.key];
            try testing.expectEqual(nested_key.id, .Literal);
            try testing.expect(mem.eql(
                u8,
                "key1_1",
                tree.source[nested_key.start..nested_key.end],
            ));

            const nested_value = nested_entry.value.cast(Node.Value).?;
            const nested_value_tok = tree.tokens[nested_value.start.?];
            try testing.expectEqual(nested_value_tok.id, .Literal);
            try testing.expect(mem.eql(
                u8,
                "value1_1",
                tree.source[nested_value_tok.start..nested_value_tok.end],
            ));
        }

        {
            const nested_entry = nested_map.values.items[1];

            const nested_key = tree.tokens[nested_entry.key];
            try testing.expectEqual(nested_key.id, .Literal);
            try testing.expect(mem.eql(
                u8,
                "key1_2",
                tree.source[nested_key.start..nested_key.end],
            ));

            const nested_value = nested_entry.value.cast(Node.Value).?;
            const nested_value_tok = tree.tokens[nested_value.start.?];
            try testing.expectEqual(nested_value_tok.id, .Literal);
            try testing.expect(mem.eql(
                u8,
                "value1_2",
                tree.source[nested_value_tok.start..nested_value_tok.end],
            ));
        }
    }

    {
        const entry = map.values.items[1];

        const key = tree.tokens[entry.key];
        try testing.expectEqual(key.id, .Literal);
        try testing.expect(mem.eql(u8, "key2", tree.source[key.start..key.end]));

        const value = entry.value.cast(Node.Value).?;
        const value_tok = tree.tokens[value.start.?];
        try testing.expectEqual(value_tok.id, .Literal);
        try testing.expect(mem.eql(
            u8,
            "value2",
            tree.source[value_tok.start..value_tok.end],
        ));
    }
}

test "map of list of values" {
    const source =
        \\ints:
        \\  - 0
        \\  - 1
        \\  - 2
    ;
    var tree = Tree.init(testing.allocator);
    defer tree.deinit();
    try tree.parse(source);

    try testing.expectEqual(tree.docs.items.len, 1);

    const doc = tree.docs.items[0].cast(Node.Doc).?;
    try testing.expectEqual(doc.start.?, 0);
    try testing.expectEqual(doc.end.?, tree.tokens.len - 2);

    try testing.expect(doc.value != null);
    try testing.expectEqual(doc.value.?.tag, .map);

    const map = doc.value.?.cast(Node.Map).?;
    try testing.expectEqual(map.start.?, 0);
    try testing.expectEqual(map.end.?, tree.tokens.len - 2);
    try testing.expectEqual(map.values.items.len, 1);

    const entry = map.values.items[0];
    const key = tree.tokens[entry.key];
    try testing.expectEqual(key.id, .Literal);
    try testing.expect(mem.eql(u8, "ints", tree.source[key.start..key.end]));

    const value = entry.value.cast(Node.List).?;
    try testing.expectEqual(value.start.?, 4);
    try testing.expectEqual(value.end.?, tree.tokens.len - 2);
    try testing.expectEqual(value.values.items.len, 3);

    {
        const elem = value.values.items[0].cast(Node.Value).?;
        const leaf = tree.tokens[elem.start.?];
        try testing.expectEqual(leaf.id, .Literal);
        try testing.expect(mem.eql(u8, "0", tree.source[leaf.start..leaf.end]));
    }

    {
        const elem = value.values.items[1].cast(Node.Value).?;
        const leaf = tree.tokens[elem.start.?];
        try testing.expectEqual(leaf.id, .Literal);
        try testing.expect(mem.eql(u8, "1", tree.source[leaf.start..leaf.end]));
    }

    {
        const elem = value.values.items[2].cast(Node.Value).?;
        const leaf = tree.tokens[elem.start.?];
        try testing.expectEqual(leaf.id, .Literal);
        try testing.expect(mem.eql(u8, "2", tree.source[leaf.start..leaf.end]));
    }
}

test "map of list of maps" {
    const source =
        \\key1:
        \\- key2 : value2
        \\- key3 : value3
        \\- key4 : value4
    ;

    var tree = Tree.init(testing.allocator);
    defer tree.deinit();
    try tree.parse(source);

    try testing.expectEqual(tree.docs.items.len, 1);

    const doc = tree.docs.items[0].cast(Node.Doc).?;
    try testing.expectEqual(doc.start.?, 0);
    try testing.expectEqual(doc.end.?, tree.tokens.len - 2);

    try testing.expect(doc.value != null);
    try testing.expectEqual(doc.value.?.tag, .map);

    const map = doc.value.?.cast(Node.Map).?;
    try testing.expectEqual(map.start.?, 0);
    try testing.expectEqual(map.end.?, tree.tokens.len - 2);
    try testing.expectEqual(map.values.items.len, 1);

    const entry = map.values.items[0];
    const key = tree.tokens[entry.key];
    try testing.expectEqual(key.id, .Literal);
    try testing.expect(mem.eql(u8, "key1", tree.source[key.start..key.end]));

    const value = entry.value.cast(Node.List).?;
    try testing.expectEqual(value.start.?, 3);
    try testing.expectEqual(value.end.?, tree.tokens.len - 2);
    try testing.expectEqual(value.values.items.len, 3);

    {
        const elem = value.values.items[0].cast(Node.Map).?;
        const nested = elem.values.items[0];
        const nested_key = tree.tokens[nested.key];
        try testing.expectEqual(nested_key.id, .Literal);
        try testing.expect(mem.eql(u8, "key2", tree.source[nested_key.start..nested_key.end]));

        const nested_v = nested.value.cast(Node.Value).?;
        const leaf = tree.tokens[nested_v.start.?];
        try testing.expectEqual(leaf.id, .Literal);
        try testing.expect(mem.eql(u8, "value2", tree.source[leaf.start..leaf.end]));
    }

    {
        const elem = value.values.items[1].cast(Node.Map).?;
        const nested = elem.values.items[0];
        const nested_key = tree.tokens[nested.key];
        try testing.expectEqual(nested_key.id, .Literal);
        try testing.expect(mem.eql(u8, "key3", tree.source[nested_key.start..nested_key.end]));

        const nested_v = nested.value.cast(Node.Value).?;
        const leaf = tree.tokens[nested_v.start.?];
        try testing.expectEqual(leaf.id, .Literal);
        try testing.expect(mem.eql(u8, "value3", tree.source[leaf.start..leaf.end]));
    }

    {
        const elem = value.values.items[2].cast(Node.Map).?;
        const nested = elem.values.items[0];
        const nested_key = tree.tokens[nested.key];
        try testing.expectEqual(nested_key.id, .Literal);
        try testing.expect(mem.eql(u8, "key4", tree.source[nested_key.start..nested_key.end]));

        const nested_v = nested.value.cast(Node.Value).?;
        const leaf = tree.tokens[nested_v.start.?];
        try testing.expectEqual(leaf.id, .Literal);
        try testing.expect(mem.eql(u8, "value4", tree.source[leaf.start..leaf.end]));
    }
}

test "list of lists" {
    const source =
        \\- [name        , hr, avg  ]
        \\- [Mark McGwire , 65, 0.278]
        \\- [Sammy Sosa   , 63, 0.288]
    ;

    var tree = Tree.init(testing.allocator);
    defer tree.deinit();
    try tree.parse(source);

    try testing.expectEqual(tree.docs.items.len, 1);

    const doc = tree.docs.items[0].cast(Node.Doc).?;
    try testing.expectEqual(doc.start.?, 0);
    try testing.expectEqual(doc.end.?, tree.tokens.len - 2);

    try testing.expect(doc.value != null);
    try testing.expectEqual(doc.value.?.tag, .list);

    const list = doc.value.?.cast(Node.List).?;
    try testing.expectEqual(list.start.?, 0);
    try testing.expectEqual(list.end.?, tree.tokens.len - 2);
    try testing.expectEqual(list.values.items.len, 3);

    {
        try testing.expectEqual(list.values.items[0].tag, .list);
        const nested = list.values.items[0].cast(Node.List).?;
        try testing.expectEqual(nested.values.items.len, 3);

        {
            try testing.expectEqual(nested.values.items[0].tag, .value);
            const value = nested.values.items[0].cast(Node.Value).?;
            const leaf = tree.tokens[value.start.?];
            try testing.expect(mem.eql(u8, "name", tree.source[leaf.start..leaf.end]));
        }

        {
            try testing.expectEqual(nested.values.items[1].tag, .value);
            const value = nested.values.items[1].cast(Node.Value).?;
            const leaf = tree.tokens[value.start.?];
            try testing.expect(mem.eql(u8, "hr", tree.source[leaf.start..leaf.end]));
        }

        {
            try testing.expectEqual(nested.values.items[2].tag, .value);
            const value = nested.values.items[2].cast(Node.Value).?;
            const leaf = tree.tokens[value.start.?];
            try testing.expect(mem.eql(u8, "avg", tree.source[leaf.start..leaf.end]));
        }
    }

    {
        try testing.expectEqual(list.values.items[1].tag, .list);
        const nested = list.values.items[1].cast(Node.List).?;
        try testing.expectEqual(nested.values.items.len, 3);

        {
            try testing.expectEqual(nested.values.items[0].tag, .value);
            const value = nested.values.items[0].cast(Node.Value).?;
            const start = tree.tokens[value.start.?];
            const end = tree.tokens[value.end.?];
            try testing.expect(mem.eql(u8, "Mark McGwire", tree.source[start.start..end.end]));
        }

        {
            try testing.expectEqual(nested.values.items[1].tag, .value);
            const value = nested.values.items[1].cast(Node.Value).?;
            const leaf = tree.tokens[value.start.?];
            try testing.expect(mem.eql(u8, "65", tree.source[leaf.start..leaf.end]));
        }

        {
            try testing.expectEqual(nested.values.items[2].tag, .value);
            const value = nested.values.items[2].cast(Node.Value).?;
            const leaf = tree.tokens[value.start.?];
            try testing.expect(mem.eql(u8, "0.278", tree.source[leaf.start..leaf.end]));
        }
    }

    {
        try testing.expectEqual(list.values.items[2].tag, .list);
        const nested = list.values.items[2].cast(Node.List).?;
        try testing.expectEqual(nested.values.items.len, 3);

        {
            try testing.expectEqual(nested.values.items[0].tag, .value);
            const value = nested.values.items[0].cast(Node.Value).?;
            const start = tree.tokens[value.start.?];
            const end = tree.tokens[value.end.?];
            try testing.expect(mem.eql(u8, "Sammy Sosa", tree.source[start.start..end.end]));
        }

        {
            try testing.expectEqual(nested.values.items[1].tag, .value);
            const value = nested.values.items[1].cast(Node.Value).?;
            const leaf = tree.tokens[value.start.?];
            try testing.expect(mem.eql(u8, "63", tree.source[leaf.start..leaf.end]));
        }

        {
            try testing.expectEqual(nested.values.items[2].tag, .value);
            const value = nested.values.items[2].cast(Node.Value).?;
            const leaf = tree.tokens[value.start.?];
            try testing.expect(mem.eql(u8, "0.288", tree.source[leaf.start..leaf.end]));
        }
    }
}

test "inline list" {
    const source =
        \\[name        , hr, avg  ]
    ;

    var tree = Tree.init(testing.allocator);
    defer tree.deinit();
    try tree.parse(source);

    try testing.expectEqual(tree.docs.items.len, 1);

    const doc = tree.docs.items[0].cast(Node.Doc).?;
    try testing.expectEqual(doc.start.?, 0);
    try testing.expectEqual(doc.end.?, tree.tokens.len - 2);

    try testing.expect(doc.value != null);
    try testing.expectEqual(doc.value.?.tag, .list);

    const list = doc.value.?.cast(Node.List).?;
    try testing.expectEqual(list.start.?, 0);
    try testing.expectEqual(list.end.?, tree.tokens.len - 2);
    try testing.expectEqual(list.values.items.len, 3);

    {
        try testing.expectEqual(list.values.items[0].tag, .value);
        const value = list.values.items[0].cast(Node.Value).?;
        const leaf = tree.tokens[value.start.?];
        try testing.expect(mem.eql(u8, "name", tree.source[leaf.start..leaf.end]));
    }

    {
        try testing.expectEqual(list.values.items[1].tag, .value);
        const value = list.values.items[1].cast(Node.Value).?;
        const leaf = tree.tokens[value.start.?];
        try testing.expect(mem.eql(u8, "hr", tree.source[leaf.start..leaf.end]));
    }

    {
        try testing.expectEqual(list.values.items[2].tag, .value);
        const value = list.values.items[2].cast(Node.Value).?;
        const leaf = tree.tokens[value.start.?];
        try testing.expect(mem.eql(u8, "avg", tree.source[leaf.start..leaf.end]));
    }
}

test "inline list as mapping value" {
    const source =
        \\key : [
        \\        name        ,
        \\        hr, avg  ]
    ;

    var tree = Tree.init(testing.allocator);
    defer tree.deinit();
    try tree.parse(source);

    try testing.expectEqual(tree.docs.items.len, 1);

    const doc = tree.docs.items[0].cast(Node.Doc).?;
    try testing.expectEqual(doc.start.?, 0);
    try testing.expectEqual(doc.end.?, tree.tokens.len - 2);

    try testing.expect(doc.value != null);
    try testing.expectEqual(doc.value.?.tag, .map);

    const map = doc.value.?.cast(Node.Map).?;
    try testing.expectEqual(map.start.?, 0);
    try testing.expectEqual(map.end.?, tree.tokens.len - 2);
    try testing.expectEqual(map.values.items.len, 1);

    const entry = map.values.items[0];
    const key = tree.tokens[entry.key];
    try testing.expectEqual(key.id, .Literal);
    try testing.expect(mem.eql(u8, "key", tree.source[key.start..key.end]));

    const list = entry.value.cast(Node.List).?;
    try testing.expectEqual(list.start.?, 4);
    try testing.expectEqual(list.end.?, tree.tokens.len - 2);
    try testing.expectEqual(list.values.items.len, 3);

    {
        try testing.expectEqual(list.values.items[0].tag, .value);
        const value = list.values.items[0].cast(Node.Value).?;
        const leaf = tree.tokens[value.start.?];
        try testing.expect(mem.eql(u8, "name", tree.source[leaf.start..leaf.end]));
    }

    {
        try testing.expectEqual(list.values.items[1].tag, .value);
        const value = list.values.items[1].cast(Node.Value).?;
        const leaf = tree.tokens[value.start.?];
        try testing.expect(mem.eql(u8, "hr", tree.source[leaf.start..leaf.end]));
    }

    {
        try testing.expectEqual(list.values.items[2].tag, .value);
        const value = list.values.items[2].cast(Node.Value).?;
        const leaf = tree.tokens[value.start.?];
        try testing.expect(mem.eql(u8, "avg", tree.source[leaf.start..leaf.end]));
    }
}
