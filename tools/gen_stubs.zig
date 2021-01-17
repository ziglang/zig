const std = @import("std");

const mem = std.mem;

const Symbol = struct {
    name: []const u8,
    section: []const u8,
    kind: enum {
        global,
        weak,
    },
    type: enum {
        none,
        function,
        object,
    },
    protected: bool,
};

// Example usage:
// objdump --dynamic-syms /path/to/libc.so | ./gen_stubs > lib/libc/musl/libc.s
pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const ally = &arena.allocator;

    var symbols = std.ArrayList(Symbol).init(ally);
    var sections = std.ArrayList([]const u8).init(ally);

    // This is many times larger than any line objdump produces should ever be
    var buf: [4096]u8 = undefined;

    // Sample input line:
    // 00000000000241b0 g    DF .text	000000000000001b copy_file_range
    while (try stdin.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        // the lines we want all start with a 16 digit hex value
        if (line.len < 16) continue;
        _ = std.fmt.parseInt(u64, line[0..16], 16) catch continue;

        // Ignore non-dynamic symbols
        if (line[22] != 'D') continue;

        const section = line[25 .. 25 + mem.indexOfAny(u8, line[25..], &std.ascii.spaces).?];

        // the last whitespace-separated column is the symbol name
        const name = line[1 + mem.lastIndexOfAny(u8, line, &std.ascii.spaces).? ..];

        const symbol = Symbol{
            .name = try ally.dupe(u8, name),
            .section = try ally.dupe(u8, section),

            .kind = if (line[17] == 'g' and line[18] == ' ')
                .global
            else if (line[17] == ' ' and line[18] == 'w')
                .weak
            else
                unreachable,

            .type = switch (line[23]) {
                'F' => .function,
                'O' => .object,
                ' ' => .none,
                else => unreachable,
            },

            .protected = mem.indexOf(u8, line, ".protected") != null,
        };

        for (sections.items) |s| {
            if (mem.eql(u8, s, symbol.section)) break;
        } else {
            try sections.append(symbol.section);
        }

        try symbols.append(symbol);
    }

    std.sort.sort(Symbol, symbols.items, {}, cmpSymbols);
    std.sort.sort([]const u8, sections.items, {}, alphabetical);

    for (sections.items) |section| {
        try stdout.print("{s}\n", .{section});

        for (symbols.items) |symbol| {
            if (!mem.eql(u8, symbol.section, section)) continue;

            switch (symbol.kind) {
                .global => try stdout.print(".globl {s}\n", .{symbol.name}),
                .weak => try stdout.print(".weak {s}\n", .{symbol.name}),
            }
            switch (symbol.type) {
                .function => try stdout.print(".type {s}, %function;\n", .{symbol.name}),
                .object => try stdout.print(".type {s}, %object;\n", .{symbol.name}),
                .none => {},
            }
            if (symbol.protected)
                try stdout.print(".protected {s}\n", .{symbol.name});
            try stdout.print("{s}:\n", .{symbol.name});
        }
    }
}

fn cmpSymbols(_: void, lhs: Symbol, rhs: Symbol) bool {
    return alphabetical({}, lhs.name, rhs.name);
}

fn alphabetical(_: void, lhs: []const u8, rhs: []const u8) bool {
    var i: usize = 0;
    while (i < lhs.len and i < rhs.len) : (i += 1) {
        if (lhs[i] == rhs[i]) continue;
        return lhs[i] < rhs[i];
    }
    return lhs.len < rhs.len;
}
