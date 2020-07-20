const std = @import("std");
const testing = std.testing;

pub const Tokenizer = struct {
    arena: std.heap.ArenaAllocator,
    index: usize,
    bytes: []const u8,
    error_text: []const u8,
    state: State,

    pub fn init(allocator: *std.mem.Allocator, bytes: []const u8) Tokenizer {
        return Tokenizer{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .index = 0,
            .bytes = bytes,
            .error_text = "",
            .state = State{ .lhs = {} },
        };
    }

    pub fn deinit(self: *Tokenizer) void {
        self.arena.deinit();
    }

    pub fn next(self: *Tokenizer) Error!?Token {
        while (self.index < self.bytes.len) {
            const char = self.bytes[self.index];
            while (true) {
                switch (self.state) {
                    .lhs => switch (char) {
                        '\t', '\n', '\r', ' ' => {
                            // silently ignore whitespace
                            break; // advance
                        },
                        else => {
                            self.state = State{ .target = try std.ArrayListSentineled(u8, 0).initSize(&self.arena.allocator, 0) };
                        },
                    },
                    .target => |*target| switch (char) {
                        '\t', '\n', '\r', ' ' => {
                            return self.errorIllegalChar(self.index, char, "invalid target", .{});
                        },
                        '$' => {
                            self.state = State{ .target_dollar_sign = target.* };
                            break; // advance
                        },
                        '\\' => {
                            self.state = State{ .target_reverse_solidus = target.* };
                            break; // advance
                        },
                        ':' => {
                            self.state = State{ .target_colon = target.* };
                            break; // advance
                        },
                        else => {
                            try target.append(char);
                            break; // advance
                        },
                    },
                    .target_reverse_solidus => |*target| switch (char) {
                        '\t', '\n', '\r' => {
                            return self.errorIllegalChar(self.index, char, "bad target escape", .{});
                        },
                        ' ', '#', '\\' => {
                            try target.append(char);
                            self.state = State{ .target = target.* };
                            break; // advance
                        },
                        '$' => {
                            try target.appendSlice(self.bytes[self.index - 1 .. self.index]);
                            self.state = State{ .target_dollar_sign = target.* };
                            break; // advance
                        },
                        else => {
                            try target.appendSlice(self.bytes[self.index - 1 .. self.index + 1]);
                            self.state = State{ .target = target.* };
                            break; // advance
                        },
                    },
                    .target_dollar_sign => |*target| switch (char) {
                        '$' => {
                            try target.append(char);
                            self.state = State{ .target = target.* };
                            break; // advance
                        },
                        else => {
                            return self.errorIllegalChar(self.index, char, "expecting '$'", .{});
                        },
                    },
                    .target_colon => |*target| switch (char) {
                        '\n', '\r' => {
                            const bytes = target.span();
                            if (bytes.len != 0) {
                                self.state = State{ .lhs = {} };
                                return Token{ .id = .target, .bytes = bytes };
                            }
                            // silently ignore null target
                            self.state = State{ .lhs = {} };
                            continue;
                        },
                        '\\' => {
                            self.state = State{ .target_colon_reverse_solidus = target.* };
                            break; // advance
                        },
                        else => {
                            const bytes = target.span();
                            if (bytes.len != 0) {
                                self.state = State{ .rhs = {} };
                                return Token{ .id = .target, .bytes = bytes };
                            }
                            // silently ignore null target
                            self.state = State{ .lhs = {} };
                            continue;
                        },
                    },
                    .target_colon_reverse_solidus => |*target| switch (char) {
                        '\n', '\r' => {
                            const bytes = target.span();
                            if (bytes.len != 0) {
                                self.state = State{ .lhs = {} };
                                return Token{ .id = .target, .bytes = bytes };
                            }
                            // silently ignore null target
                            self.state = State{ .lhs = {} };
                            continue;
                        },
                        else => {
                            try target.appendSlice(self.bytes[self.index - 2 .. self.index + 1]);
                            self.state = State{ .target = target.* };
                            break;
                        },
                    },
                    .rhs => switch (char) {
                        '\t', ' ' => {
                            // silently ignore horizontal whitespace
                            break; // advance
                        },
                        '\n', '\r' => {
                            self.state = State{ .lhs = {} };
                            continue;
                        },
                        '\\' => {
                            self.state = State{ .rhs_continuation = {} };
                            break; // advance
                        },
                        '"' => {
                            self.state = State{ .prereq_quote = try std.ArrayListSentineled(u8, 0).initSize(&self.arena.allocator, 0) };
                            break; // advance
                        },
                        else => {
                            self.state = State{ .prereq = try std.ArrayListSentineled(u8, 0).initSize(&self.arena.allocator, 0) };
                        },
                    },
                    .rhs_continuation => switch (char) {
                        '\n' => {
                            self.state = State{ .rhs = {} };
                            break; // advance
                        },
                        '\r' => {
                            self.state = State{ .rhs_continuation_linefeed = {} };
                            break; // advance
                        },
                        else => {
                            return self.errorIllegalChar(self.index, char, "continuation expecting end-of-line", .{});
                        },
                    },
                    .rhs_continuation_linefeed => switch (char) {
                        '\n' => {
                            self.state = State{ .rhs = {} };
                            break; // advance
                        },
                        else => {
                            return self.errorIllegalChar(self.index, char, "continuation expecting end-of-line", .{});
                        },
                    },
                    .prereq_quote => |*prereq| switch (char) {
                        '"' => {
                            const bytes = prereq.span();
                            self.index += 1;
                            self.state = State{ .rhs = {} };
                            return Token{ .id = .prereq, .bytes = bytes };
                        },
                        else => {
                            try prereq.append(char);
                            break; // advance
                        },
                    },
                    .prereq => |*prereq| switch (char) {
                        '\t', ' ' => {
                            const bytes = prereq.span();
                            self.state = State{ .rhs = {} };
                            return Token{ .id = .prereq, .bytes = bytes };
                        },
                        '\n', '\r' => {
                            const bytes = prereq.span();
                            self.state = State{ .lhs = {} };
                            return Token{ .id = .prereq, .bytes = bytes };
                        },
                        '\\' => {
                            self.state = State{ .prereq_continuation = prereq.* };
                            break; // advance
                        },
                        else => {
                            try prereq.append(char);
                            break; // advance
                        },
                    },
                    .prereq_continuation => |*prereq| switch (char) {
                        '\n' => {
                            const bytes = prereq.span();
                            self.index += 1;
                            self.state = State{ .rhs = {} };
                            return Token{ .id = .prereq, .bytes = bytes };
                        },
                        '\r' => {
                            self.state = State{ .prereq_continuation_linefeed = prereq.* };
                            break; // advance
                        },
                        else => {
                            // not continuation
                            try prereq.appendSlice(self.bytes[self.index - 1 .. self.index + 1]);
                            self.state = State{ .prereq = prereq.* };
                            break; // advance
                        },
                    },
                    .prereq_continuation_linefeed => |prereq| switch (char) {
                        '\n' => {
                            const bytes = prereq.span();
                            self.index += 1;
                            self.state = State{ .rhs = {} };
                            return Token{ .id = .prereq, .bytes = bytes };
                        },
                        else => {
                            return self.errorIllegalChar(self.index, char, "continuation expecting end-of-line", .{});
                        },
                    },
                }
            }
            self.index += 1;
        }

        // eof, handle maybe incomplete token
        if (self.index == 0) return null;
        const idx = self.index - 1;
        switch (self.state) {
            .lhs,
            .rhs,
            .rhs_continuation,
            .rhs_continuation_linefeed,
            => {},
            .target => |target| {
                return self.errorPosition(idx, target.span(), "incomplete target", .{});
            },
            .target_reverse_solidus,
            .target_dollar_sign,
            => {
                const index = self.index - 1;
                return self.errorIllegalChar(idx, self.bytes[idx], "incomplete escape", .{});
            },
            .target_colon => |target| {
                const bytes = target.span();
                if (bytes.len != 0) {
                    self.index += 1;
                    self.state = State{ .rhs = {} };
                    return Token{ .id = .target, .bytes = bytes };
                }
                // silently ignore null target
                self.state = State{ .lhs = {} };
            },
            .target_colon_reverse_solidus => |target| {
                const bytes = target.span();
                if (bytes.len != 0) {
                    self.index += 1;
                    self.state = State{ .rhs = {} };
                    return Token{ .id = .target, .bytes = bytes };
                }
                // silently ignore null target
                self.state = State{ .lhs = {} };
            },
            .prereq_quote => |prereq| {
                return self.errorPosition(idx, prereq.span(), "incomplete quoted prerequisite", .{});
            },
            .prereq => |prereq| {
                const bytes = prereq.span();
                self.state = State{ .lhs = {} };
                return Token{ .id = .prereq, .bytes = bytes };
            },
            .prereq_continuation => |prereq| {
                const bytes = prereq.span();
                self.state = State{ .lhs = {} };
                return Token{ .id = .prereq, .bytes = bytes };
            },
            .prereq_continuation_linefeed => |prereq| {
                const bytes = prereq.span();
                self.state = State{ .lhs = {} };
                return Token{ .id = .prereq, .bytes = bytes };
            },
        }
        return null;
    }

    fn errorf(self: *Tokenizer, comptime fmt: []const u8, args: anytype) Error {
        self.error_text = try std.fmt.allocPrintZ(&self.arena.allocator, fmt, args);
        return Error.InvalidInput;
    }

    fn errorPosition(self: *Tokenizer, position: usize, bytes: []const u8, comptime fmt: []const u8, args: anytype) Error {
        var buffer = try std.ArrayListSentineled(u8, 0).initSize(&self.arena.allocator, 0);
        try buffer.outStream().print(fmt, args);
        try buffer.appendSlice(" '");
        var out = makeOutput(std.ArrayListSentineled(u8, 0).appendSlice, &buffer);
        try printCharValues(&out, bytes);
        try buffer.appendSlice("'");
        try buffer.outStream().print(" at position {}", .{position - (bytes.len - 1)});
        self.error_text = buffer.span();
        return Error.InvalidInput;
    }

    fn errorIllegalChar(self: *Tokenizer, position: usize, char: u8, comptime fmt: []const u8, args: anytype) Error {
        var buffer = try std.ArrayListSentineled(u8, 0).initSize(&self.arena.allocator, 0);
        try buffer.appendSlice("illegal char ");
        try printUnderstandableChar(&buffer, char);
        try buffer.outStream().print(" at position {}", .{position});
        if (fmt.len != 0) try buffer.outStream().print(": " ++ fmt, args);
        self.error_text = buffer.span();
        return Error.InvalidInput;
    }

    const Error = error{
        OutOfMemory,
        InvalidInput,
    };

    const State = union(enum) {
        lhs: void,
        target: std.ArrayListSentineled(u8, 0),
        target_reverse_solidus: std.ArrayListSentineled(u8, 0),
        target_dollar_sign: std.ArrayListSentineled(u8, 0),
        target_colon: std.ArrayListSentineled(u8, 0),
        target_colon_reverse_solidus: std.ArrayListSentineled(u8, 0),
        rhs: void,
        rhs_continuation: void,
        rhs_continuation_linefeed: void,
        prereq_quote: std.ArrayListSentineled(u8, 0),
        prereq: std.ArrayListSentineled(u8, 0),
        prereq_continuation: std.ArrayListSentineled(u8, 0),
        prereq_continuation_linefeed: std.ArrayListSentineled(u8, 0),
    };

    const Token = struct {
        id: ID,
        bytes: []const u8,

        const ID = enum {
            target,
            prereq,
        };
    };
};

test "empty file" {
    try depTokenizer("", "");
}

test "empty whitespace" {
    try depTokenizer("\n", "");
    try depTokenizer("\r", "");
    try depTokenizer("\r\n", "");
    try depTokenizer(" ", "");
}

test "empty colon" {
    try depTokenizer(":", "");
    try depTokenizer("\n:", "");
    try depTokenizer("\r:", "");
    try depTokenizer("\r\n:", "");
    try depTokenizer(" :", "");
}

test "empty target" {
    try depTokenizer("foo.o:", "target = {foo.o}");
    try depTokenizer(
        \\foo.o:
        \\bar.o:
        \\abcd.o:
    ,
        \\target = {foo.o}
        \\target = {bar.o}
        \\target = {abcd.o}
    );
}

test "whitespace empty target" {
    try depTokenizer("\nfoo.o:", "target = {foo.o}");
    try depTokenizer("\rfoo.o:", "target = {foo.o}");
    try depTokenizer("\r\nfoo.o:", "target = {foo.o}");
    try depTokenizer(" foo.o:", "target = {foo.o}");
}

test "escape empty target" {
    try depTokenizer("\\ foo.o:", "target = { foo.o}");
    try depTokenizer("\\#foo.o:", "target = {#foo.o}");
    try depTokenizer("\\\\foo.o:", "target = {\\foo.o}");
    try depTokenizer("$$foo.o:", "target = {$foo.o}");
}

test "empty target linefeeds" {
    try depTokenizer("\n", "");
    try depTokenizer("\r\n", "");

    const expect = "target = {foo.o}";
    try depTokenizer(
        \\foo.o:
    , expect);
    try depTokenizer(
        \\foo.o:
        \\
    , expect);
    try depTokenizer(
        \\foo.o:
    , expect);
    try depTokenizer(
        \\foo.o:
        \\
    , expect);
}

test "empty target linefeeds + continuations" {
    const expect = "target = {foo.o}";
    try depTokenizer(
        \\foo.o:\
    , expect);
    try depTokenizer(
        \\foo.o:\
        \\
    , expect);
    try depTokenizer(
        \\foo.o:\
    , expect);
    try depTokenizer(
        \\foo.o:\
        \\
    , expect);
}

test "empty target linefeeds + hspace + continuations" {
    const expect = "target = {foo.o}";
    try depTokenizer(
        \\foo.o: \
    , expect);
    try depTokenizer(
        \\foo.o: \
        \\
    , expect);
    try depTokenizer(
        \\foo.o: \
    , expect);
    try depTokenizer(
        \\foo.o: \
        \\
    , expect);
}

test "prereq" {
    const expect =
        \\target = {foo.o}
        \\prereq = {foo.c}
    ;
    try depTokenizer("foo.o: foo.c", expect);
    try depTokenizer(
        \\foo.o: \
        \\foo.c
    , expect);
    try depTokenizer(
        \\foo.o: \
        \\ foo.c
    , expect);
    try depTokenizer(
        \\foo.o:    \
        \\    foo.c
    , expect);
}

test "prereq continuation" {
    const expect =
        \\target = {foo.o}
        \\prereq = {foo.h}
        \\prereq = {bar.h}
    ;
    try depTokenizer(
        \\foo.o: foo.h\
        \\bar.h
    , expect);
    try depTokenizer(
        \\foo.o: foo.h\
        \\bar.h
    , expect);
}

test "multiple prereqs" {
    const expect =
        \\target = {foo.o}
        \\prereq = {foo.c}
        \\prereq = {foo.h}
        \\prereq = {bar.h}
    ;
    try depTokenizer("foo.o: foo.c foo.h bar.h", expect);
    try depTokenizer(
        \\foo.o: \
        \\foo.c foo.h bar.h
    , expect);
    try depTokenizer(
        \\foo.o: foo.c foo.h bar.h\
    , expect);
    try depTokenizer(
        \\foo.o: foo.c foo.h bar.h\
        \\
    , expect);
    try depTokenizer(
        \\foo.o: \
        \\foo.c       \
        \\     foo.h\
        \\bar.h
        \\
    , expect);
    try depTokenizer(
        \\foo.o: \
        \\foo.c       \
        \\     foo.h\
        \\bar.h\
        \\
    , expect);
    try depTokenizer(
        \\foo.o: \
        \\foo.c       \
        \\     foo.h\
        \\bar.h\
    , expect);
}

test "multiple targets and prereqs" {
    try depTokenizer(
        \\foo.o: foo.c
        \\bar.o: bar.c a.h b.h c.h
        \\abc.o: abc.c \
        \\  one.h two.h \
        \\  three.h four.h
    ,
        \\target = {foo.o}
        \\prereq = {foo.c}
        \\target = {bar.o}
        \\prereq = {bar.c}
        \\prereq = {a.h}
        \\prereq = {b.h}
        \\prereq = {c.h}
        \\target = {abc.o}
        \\prereq = {abc.c}
        \\prereq = {one.h}
        \\prereq = {two.h}
        \\prereq = {three.h}
        \\prereq = {four.h}
    );
    try depTokenizer(
        \\ascii.o: ascii.c
        \\base64.o: base64.c stdio.h
        \\elf.o: elf.c a.h b.h c.h
        \\macho.o: \
        \\  macho.c\
        \\  a.h b.h c.h
    ,
        \\target = {ascii.o}
        \\prereq = {ascii.c}
        \\target = {base64.o}
        \\prereq = {base64.c}
        \\prereq = {stdio.h}
        \\target = {elf.o}
        \\prereq = {elf.c}
        \\prereq = {a.h}
        \\prereq = {b.h}
        \\prereq = {c.h}
        \\target = {macho.o}
        \\prereq = {macho.c}
        \\prereq = {a.h}
        \\prereq = {b.h}
        \\prereq = {c.h}
    );
    try depTokenizer(
        \\a$$scii.o: ascii.c
        \\\\base64.o: "\base64.c" "s t#dio.h"
        \\e\\lf.o: "e\lf.c" "a.h$$" "$$b.h c.h$$"
        \\macho.o: \
        \\  "macho!.c" \
        \\  a.h b.h c.h
    ,
        \\target = {a$scii.o}
        \\prereq = {ascii.c}
        \\target = {\base64.o}
        \\prereq = {\base64.c}
        \\prereq = {s t#dio.h}
        \\target = {e\lf.o}
        \\prereq = {e\lf.c}
        \\prereq = {a.h$$}
        \\prereq = {$$b.h c.h$$}
        \\target = {macho.o}
        \\prereq = {macho!.c}
        \\prereq = {a.h}
        \\prereq = {b.h}
        \\prereq = {c.h}
    );
}

test "windows quoted prereqs" {
    try depTokenizer(
        \\c:\foo.o: "C:\Program Files (x86)\Microsoft Visual Studio\foo.c"
        \\c:\foo2.o: "C:\Program Files (x86)\Microsoft Visual Studio\foo2.c" \
        \\  "C:\Program Files (x86)\Microsoft Visual Studio\foo1.h" \
        \\  "C:\Program Files (x86)\Microsoft Visual Studio\foo2.h"
    ,
        \\target = {c:\foo.o}
        \\prereq = {C:\Program Files (x86)\Microsoft Visual Studio\foo.c}
        \\target = {c:\foo2.o}
        \\prereq = {C:\Program Files (x86)\Microsoft Visual Studio\foo2.c}
        \\prereq = {C:\Program Files (x86)\Microsoft Visual Studio\foo1.h}
        \\prereq = {C:\Program Files (x86)\Microsoft Visual Studio\foo2.h}
    );
}

test "windows mixed prereqs" {
    try depTokenizer(
        \\cimport.o: \
        \\  C:\msys64\home\anon\project\zig\master\zig-cache\o\qhvhbUo7GU5iKyQ5mpA8TcQpncCYaQu0wwvr3ybiSTj_Dtqi1Nmcb70kfODJ2Qlg\cimport.h \
        \\  "C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\stdio.h" \
        \\  "C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\corecrt.h" \
        \\  "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.21.27702\lib\x64\\..\..\include\vcruntime.h" \
        \\  "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.21.27702\lib\x64\\..\..\include\sal.h" \
        \\  "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.21.27702\lib\x64\\..\..\include\concurrencysal.h" \
        \\  C:\msys64\opt\zig\lib\zig\include\vadefs.h \
        \\  "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.21.27702\lib\x64\\..\..\include\vadefs.h" \
        \\  "C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\corecrt_wstdio.h" \
        \\  "C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\corecrt_stdio_config.h" \
        \\  "C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\string.h" \
        \\  "C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\corecrt_memory.h" \
        \\  "C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\corecrt_memcpy_s.h" \
        \\  "C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\errno.h" \
        \\  "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.21.27702\lib\x64\\..\..\include\vcruntime_string.h" \
        \\  "C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\corecrt_wstring.h"
    ,
        \\target = {cimport.o}
        \\prereq = {C:\msys64\home\anon\project\zig\master\zig-cache\o\qhvhbUo7GU5iKyQ5mpA8TcQpncCYaQu0wwvr3ybiSTj_Dtqi1Nmcb70kfODJ2Qlg\cimport.h}
        \\prereq = {C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\stdio.h}
        \\prereq = {C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\corecrt.h}
        \\prereq = {C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.21.27702\lib\x64\\..\..\include\vcruntime.h}
        \\prereq = {C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.21.27702\lib\x64\\..\..\include\sal.h}
        \\prereq = {C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.21.27702\lib\x64\\..\..\include\concurrencysal.h}
        \\prereq = {C:\msys64\opt\zig\lib\zig\include\vadefs.h}
        \\prereq = {C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.21.27702\lib\x64\\..\..\include\vadefs.h}
        \\prereq = {C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\corecrt_wstdio.h}
        \\prereq = {C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\corecrt_stdio_config.h}
        \\prereq = {C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\string.h}
        \\prereq = {C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\corecrt_memory.h}
        \\prereq = {C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\corecrt_memcpy_s.h}
        \\prereq = {C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\errno.h}
        \\prereq = {C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.21.27702\lib\x64\\..\..\include\vcruntime_string.h}
        \\prereq = {C:\Program Files (x86)\Windows Kits\10\\Include\10.0.17763.0\ucrt\corecrt_wstring.h}
    );
}

test "funky targets" {
    try depTokenizer(
        \\C:\Users\anon\foo.o:
        \\C:\Users\anon\foo\ .o:
        \\C:\Users\anon\foo\#.o:
        \\C:\Users\anon\foo$$.o:
        \\C:\Users\anon\\\ foo.o:
        \\C:\Users\anon\\#foo.o:
        \\C:\Users\anon\$$foo.o:
        \\C:\Users\anon\\\ \ \ \ \ foo.o:
    ,
        \\target = {C:\Users\anon\foo.o}
        \\target = {C:\Users\anon\foo .o}
        \\target = {C:\Users\anon\foo#.o}
        \\target = {C:\Users\anon\foo$.o}
        \\target = {C:\Users\anon\ foo.o}
        \\target = {C:\Users\anon\#foo.o}
        \\target = {C:\Users\anon\$foo.o}
        \\target = {C:\Users\anon\     foo.o}
    );
}

test "error incomplete escape - reverse_solidus" {
    try depTokenizer("\\",
        \\ERROR: illegal char '\' at position 0: incomplete escape
    );
    try depTokenizer("\t\\",
        \\ERROR: illegal char '\' at position 1: incomplete escape
    );
    try depTokenizer("\n\\",
        \\ERROR: illegal char '\' at position 1: incomplete escape
    );
    try depTokenizer("\r\\",
        \\ERROR: illegal char '\' at position 1: incomplete escape
    );
    try depTokenizer("\r\n\\",
        \\ERROR: illegal char '\' at position 2: incomplete escape
    );
    try depTokenizer(" \\",
        \\ERROR: illegal char '\' at position 1: incomplete escape
    );
}

test "error incomplete escape - dollar_sign" {
    try depTokenizer("$",
        \\ERROR: illegal char '$' at position 0: incomplete escape
    );
    try depTokenizer("\t$",
        \\ERROR: illegal char '$' at position 1: incomplete escape
    );
    try depTokenizer("\n$",
        \\ERROR: illegal char '$' at position 1: incomplete escape
    );
    try depTokenizer("\r$",
        \\ERROR: illegal char '$' at position 1: incomplete escape
    );
    try depTokenizer("\r\n$",
        \\ERROR: illegal char '$' at position 2: incomplete escape
    );
    try depTokenizer(" $",
        \\ERROR: illegal char '$' at position 1: incomplete escape
    );
}

test "error incomplete target" {
    try depTokenizer("foo.o",
        \\ERROR: incomplete target 'foo.o' at position 0
    );
    try depTokenizer("\tfoo.o",
        \\ERROR: incomplete target 'foo.o' at position 1
    );
    try depTokenizer("\nfoo.o",
        \\ERROR: incomplete target 'foo.o' at position 1
    );
    try depTokenizer("\rfoo.o",
        \\ERROR: incomplete target 'foo.o' at position 1
    );
    try depTokenizer("\r\nfoo.o",
        \\ERROR: incomplete target 'foo.o' at position 2
    );
    try depTokenizer(" foo.o",
        \\ERROR: incomplete target 'foo.o' at position 1
    );

    try depTokenizer("\\ foo.o",
        \\ERROR: incomplete target ' foo.o' at position 1
    );
    try depTokenizer("\\#foo.o",
        \\ERROR: incomplete target '#foo.o' at position 1
    );
    try depTokenizer("\\\\foo.o",
        \\ERROR: incomplete target '\foo.o' at position 1
    );
    try depTokenizer("$$foo.o",
        \\ERROR: incomplete target '$foo.o' at position 1
    );
}

test "error illegal char at position - bad target escape" {
    try depTokenizer("\\\t",
        \\ERROR: illegal char \x09 at position 1: bad target escape
    );
    try depTokenizer("\\\n",
        \\ERROR: illegal char \x0A at position 1: bad target escape
    );
    try depTokenizer("\\\r",
        \\ERROR: illegal char \x0D at position 1: bad target escape
    );
    try depTokenizer("\\\r\n",
        \\ERROR: illegal char \x0D at position 1: bad target escape
    );
}

test "error illegal char at position - execting dollar_sign" {
    try depTokenizer("$\t",
        \\ERROR: illegal char \x09 at position 1: expecting '$'
    );
    try depTokenizer("$\n",
        \\ERROR: illegal char \x0A at position 1: expecting '$'
    );
    try depTokenizer("$\r",
        \\ERROR: illegal char \x0D at position 1: expecting '$'
    );
    try depTokenizer("$\r\n",
        \\ERROR: illegal char \x0D at position 1: expecting '$'
    );
}

test "error illegal char at position - invalid target" {
    try depTokenizer("foo\t.o",
        \\ERROR: illegal char \x09 at position 3: invalid target
    );
    try depTokenizer("foo\n.o",
        \\ERROR: illegal char \x0A at position 3: invalid target
    );
    try depTokenizer("foo\r.o",
        \\ERROR: illegal char \x0D at position 3: invalid target
    );
    try depTokenizer("foo\r\n.o",
        \\ERROR: illegal char \x0D at position 3: invalid target
    );
}

test "error target - continuation expecting end-of-line" {
    try depTokenizer("foo.o: \\\t",
        \\target = {foo.o}
        \\ERROR: illegal char \x09 at position 8: continuation expecting end-of-line
    );
    try depTokenizer("foo.o: \\ ",
        \\target = {foo.o}
        \\ERROR: illegal char \x20 at position 8: continuation expecting end-of-line
    );
    try depTokenizer("foo.o: \\x",
        \\target = {foo.o}
        \\ERROR: illegal char 'x' at position 8: continuation expecting end-of-line
    );
    try depTokenizer("foo.o: \\\x0dx",
        \\target = {foo.o}
        \\ERROR: illegal char 'x' at position 9: continuation expecting end-of-line
    );
}

test "error prereq - continuation expecting end-of-line" {
    try depTokenizer("foo.o: foo.h\\\x0dx",
        \\target = {foo.o}
        \\ERROR: illegal char 'x' at position 14: continuation expecting end-of-line
    );
}

// - tokenize input, emit textual representation, and compare to expect
fn depTokenizer(input: []const u8, expect: []const u8) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = &arena_allocator.allocator;
    defer arena_allocator.deinit();

    var it = Tokenizer.init(arena, input);
    var buffer = try std.ArrayListSentineled(u8, 0).initSize(arena, 0);
    var i: usize = 0;
    while (true) {
        const r = it.next() catch |err| {
            switch (err) {
                Tokenizer.Error.InvalidInput => {
                    if (i != 0) try buffer.appendSlice("\n");
                    try buffer.appendSlice("ERROR: ");
                    try buffer.appendSlice(it.error_text);
                },
                else => return err,
            }
            break;
        };
        const token = r orelse break;
        if (i != 0) try buffer.appendSlice("\n");
        try buffer.appendSlice(@tagName(token.id));
        try buffer.appendSlice(" = {");
        for (token.bytes) |b| {
            try buffer.append(printable_char_tab[b]);
        }
        try buffer.appendSlice("}");
        i += 1;
    }
    const got: []const u8 = buffer.span();

    if (std.mem.eql(u8, expect, got)) {
        testing.expect(true);
        return;
    }

    var out = makeOutput(std.fs.File.write, try std.io.getStdErr());

    try out.write("\n");
    try printSection(&out, "<<<< input", input);
    try printSection(&out, "==== expect", expect);
    try printSection(&out, ">>>> got", got);
    try printRuler(&out);

    testing.expect(false);
}

fn printSection(out: anytype, label: []const u8, bytes: []const u8) !void {
    try printLabel(out, label, bytes);
    try hexDump(out, bytes);
    try printRuler(out);
    try out.write(bytes);
    try out.write("\n");
}

fn printLabel(out: anytype, label: []const u8, bytes: []const u8) !void {
    var buf: [80]u8 = undefined;
    var text = try std.fmt.bufPrint(buf[0..], "{} {} bytes ", .{ label, bytes.len });
    try out.write(text);
    var i: usize = text.len;
    const end = 79;
    while (i < 79) : (i += 1) {
        try out.write([_]u8{label[0]});
    }
    try out.write("\n");
}

fn printRuler(out: anytype) !void {
    var i: usize = 0;
    const end = 79;
    while (i < 79) : (i += 1) {
        try out.write("-");
    }
    try out.write("\n");
}

fn hexDump(out: anytype, bytes: []const u8) !void {
    const n16 = bytes.len >> 4;
    var line: usize = 0;
    var offset: usize = 0;
    while (line < n16) : (line += 1) {
        try hexDump16(out, offset, bytes[offset .. offset + 16]);
        offset += 16;
    }

    const n = bytes.len & 0x0f;
    if (n > 0) {
        try printDecValue(out, offset, 8);
        try out.write(":");
        try out.write(" ");
        var end1 = std.math.min(offset + n, offset + 8);
        for (bytes[offset..end1]) |b| {
            try out.write(" ");
            try printHexValue(out, b, 2);
        }
        var end2 = offset + n;
        if (end2 > end1) {
            try out.write(" ");
            for (bytes[end1..end2]) |b| {
                try out.write(" ");
                try printHexValue(out, b, 2);
            }
        }
        const short = 16 - n;
        var i: usize = 0;
        while (i < short) : (i += 1) {
            try out.write("   ");
        }
        if (end2 > end1) {
            try out.write("  |");
        } else {
            try out.write("   |");
        }
        try printCharValues(out, bytes[offset..end2]);
        try out.write("|\n");
        offset += n;
    }

    try printDecValue(out, offset, 8);
    try out.write(":");
    try out.write("\n");
}

fn hexDump16(out: anytype, offset: usize, bytes: []const u8) !void {
    try printDecValue(out, offset, 8);
    try out.write(":");
    try out.write(" ");
    for (bytes[0..8]) |b| {
        try out.write(" ");
        try printHexValue(out, b, 2);
    }
    try out.write(" ");
    for (bytes[8..16]) |b| {
        try out.write(" ");
        try printHexValue(out, b, 2);
    }
    try out.write("  |");
    try printCharValues(out, bytes);
    try out.write("|\n");
}

fn printDecValue(out: anytype, value: u64, width: u8) !void {
    var buffer: [20]u8 = undefined;
    const len = std.fmt.formatIntBuf(buffer[0..], value, 10, false, width);
    try out.write(buffer[0..len]);
}

fn printHexValue(out: anytype, value: u64, width: u8) !void {
    var buffer: [16]u8 = undefined;
    const len = std.fmt.formatIntBuf(buffer[0..], value, 16, false, width);
    try out.write(buffer[0..len]);
}

fn printCharValues(out: anytype, bytes: []const u8) !void {
    for (bytes) |b| {
        try out.write(&[_]u8{printable_char_tab[b]});
    }
}

fn printUnderstandableChar(buffer: *std.ArrayListSentineled(u8, 0), char: u8) !void {
    if (!std.ascii.isPrint(char) or char == ' ') {
        try buffer.outStream().print("\\x{X:2}", .{char});
    } else {
        try buffer.appendSlice("'");
        try buffer.append(printable_char_tab[char]);
        try buffer.appendSlice("'");
    }
}

// zig fmt: off
const printable_char_tab: []const u8 =
    "................................ !\"#$%&'()*+,-./0123456789:;<=>?" ++
    "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~." ++
    "................................................................" ++
    "................................................................";
// zig fmt: on
comptime {
    std.debug.assert(printable_char_tab.len == 256);
}

// Make an output var that wraps a context and output function.
// output: must be a function that takes a `self` idiom parameter
// and a bytes parameter
// context: must be that self
fn makeOutput(comptime output: anytype, context: anytype) Output(output, @TypeOf(context)) {
    return Output(output, @TypeOf(context)){
        .context = context,
    };
}

fn Output(comptime output_func: anytype, comptime Context: type) type {
    return struct {
        context: Context,

        pub const output = output_func;

        fn write(self: @This(), bytes: []const u8) !void {
            try output_func(self.context, bytes);
        }
    };
}
