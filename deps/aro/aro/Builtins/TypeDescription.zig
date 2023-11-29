const std = @import("std");

const TypeDescription = @This();

prefix: []const Prefix,
spec: Spec,
suffix: []const Suffix,

pub const Component = union(enum) {
    prefix: Prefix,
    spec: Spec,
    suffix: Suffix,
};

pub const ComponentIterator = struct {
    str: []const u8,
    idx: usize,

    pub fn init(str: []const u8) ComponentIterator {
        return .{
            .str = str,
            .idx = 0,
        };
    }

    pub fn peek(self: *ComponentIterator) ?Component {
        const idx = self.idx;
        defer self.idx = idx;
        return self.next();
    }

    pub fn next(self: *ComponentIterator) ?Component {
        if (self.idx == self.str.len) return null;
        const c = self.str[self.idx];
        self.idx += 1;
        switch (c) {
            'L' => {
                if (self.str[self.idx] != 'L') return .{ .prefix = .L };
                self.idx += 1;
                if (self.str[self.idx] != 'L') return .{ .prefix = .LL };
                self.idx += 1;
                return .{ .prefix = .LLL };
            },
            'Z' => return .{ .prefix = .Z },
            'W' => return .{ .prefix = .W },
            'N' => return .{ .prefix = .N },
            'O' => return .{ .prefix = .O },
            'S' => {
                if (self.str[self.idx] == 'J') {
                    self.idx += 1;
                    return .{ .spec = .SJ };
                }
                return .{ .prefix = .S };
            },
            'U' => return .{ .prefix = .U },
            'I' => return .{ .prefix = .I },

            'v' => return .{ .spec = .v },
            'b' => return .{ .spec = .b },
            'c' => return .{ .spec = .c },
            's' => return .{ .spec = .s },
            'i' => return .{ .spec = .i },
            'h' => return .{ .spec = .h },
            'x' => return .{ .spec = .x },
            'y' => return .{ .spec = .y },
            'f' => return .{ .spec = .f },
            'd' => return .{ .spec = .d },
            'z' => return .{ .spec = .z },
            'w' => return .{ .spec = .w },
            'F' => return .{ .spec = .F },
            'G' => return .{ .spec = .G },
            'H' => return .{ .spec = .H },
            'M' => return .{ .spec = .M },
            'a' => return .{ .spec = .a },
            'A' => return .{ .spec = .A },
            'V', 'q', 'E' => {
                const start = self.idx;
                while (std.ascii.isDigit(self.str[self.idx])) : (self.idx += 1) {}
                const count = std.fmt.parseUnsigned(u32, self.str[start..self.idx], 10) catch unreachable;
                return switch (c) {
                    'V' => .{ .spec = .{ .V = count } },
                    'q' => .{ .spec = .{ .q = count } },
                    'E' => .{ .spec = .{ .E = count } },
                    else => unreachable,
                };
            },
            'X' => {
                defer self.idx += 1;
                switch (self.str[self.idx]) {
                    'f' => return .{ .spec = .{ .X = .float } },
                    'd' => return .{ .spec = .{ .X = .double } },
                    'L' => {
                        self.idx += 1;
                        return .{ .spec = .{ .X = .longdouble } };
                    },
                    else => unreachable,
                }
            },
            'Y' => return .{ .spec = .Y },
            'P' => return .{ .spec = .P },
            'J' => return .{ .spec = .J },
            'K' => return .{ .spec = .K },
            'p' => return .{ .spec = .p },
            '.' => {
                // can only appear at end of param string; indicates varargs function
                std.debug.assert(self.idx == self.str.len);
                return null;
            },
            '!' => {
                std.debug.assert(self.str.len == 1);
                return .{ .spec = .@"!" };
            },

            '*' => {
                if (self.idx < self.str.len and std.ascii.isDigit(self.str[self.idx])) {
                    defer self.idx += 1;
                    const addr_space = self.str[self.idx] - '0';
                    return .{ .suffix = .{ .@"*" = addr_space } };
                } else {
                    return .{ .suffix = .{ .@"*" = null } };
                }
            },
            'C' => return .{ .suffix = .C },
            'D' => return .{ .suffix = .D },
            'R' => return .{ .suffix = .R },
            else => unreachable,
        }
        return null;
    }
};

pub const TypeIterator = struct {
    param_str: []const u8,
    prefix: [4]Prefix,
    spec: Spec,
    suffix: [4]Suffix,
    idx: usize,

    pub fn init(param_str: []const u8) TypeIterator {
        return .{
            .param_str = param_str,
            .prefix = undefined,
            .spec = undefined,
            .suffix = undefined,
            .idx = 0,
        };
    }

    /// Returned `TypeDescription` contains fields which are slices into the underlying `TypeIterator`
    /// The returned value is invalidated when `.next()` is called again or the TypeIterator goes out
    // of scope.
    pub fn next(self: *TypeIterator) ?TypeDescription {
        var it = ComponentIterator.init(self.param_str[self.idx..]);
        defer self.idx += it.idx;

        var prefix_count: usize = 0;
        var maybe_spec: ?Spec = null;
        var suffix_count: usize = 0;
        while (it.peek()) |component| {
            switch (component) {
                .prefix => |prefix| {
                    if (maybe_spec != null) break;
                    self.prefix[prefix_count] = prefix;
                    prefix_count += 1;
                },
                .spec => |spec| {
                    if (maybe_spec != null) break;
                    maybe_spec = spec;
                },
                .suffix => |suffix| {
                    std.debug.assert(maybe_spec != null);
                    self.suffix[suffix_count] = suffix;
                    suffix_count += 1;
                },
            }
            _ = it.next();
        }
        if (maybe_spec) |spec| {
            return TypeDescription{
                .prefix = self.prefix[0..prefix_count],
                .spec = spec,
                .suffix = self.suffix[0..suffix_count],
            };
        }
        return null;
    }
};

const Prefix = enum {
    /// long (e.g. Li for 'long int', Ld for 'long double')
    L,
    /// long long (e.g. LLi for 'long long int', LLd for __float128)
    LL,
    /// __int128_t (e.g. LLLi)
    LLL,
    /// int32_t (require a native 32-bit integer type on the target)
    Z,
    /// int64_t (require a native 64-bit integer type on the target)
    W,
    /// 'int' size if target is LP64, 'L' otherwise.
    N,
    /// long for OpenCL targets, long long otherwise.
    O,
    /// signed
    S,
    /// unsigned
    U,
    /// Required to constant fold to an integer constant expression.
    I,
};

const Spec = union(enum) {
    /// void
    v,
    /// boolean
    b,
    /// char
    c,
    /// short
    s,
    /// int
    i,
    /// half (__fp16, OpenCL)
    h,
    /// half (_Float16)
    x,
    /// half (__bf16)
    y,
    /// float
    f,
    /// double
    d,
    /// size_t
    z,
    /// wchar_t
    w,
    /// constant CFString
    F,
    /// id
    G,
    /// SEL
    H,
    /// struct objc_super
    M,
    /// __builtin_va_list
    a,
    /// "reference" to __builtin_va_list
    A,
    /// Vector, followed by the number of elements and the base type.
    V: u32,
    /// Scalable vector, followed by the number of elements and the base type.
    q: u32,
    /// ext_vector, followed by the number of elements and the base type.
    E: u32,
    /// _Complex, followed by the base type.
    X: enum {
        float,
        double,
        longdouble,
    },
    /// ptrdiff_t
    Y,
    /// FILE
    P,
    /// jmp_buf
    J,
    /// sigjmp_buf
    SJ,
    /// ucontext_t
    K,
    /// pid_t
    p,
    /// Used to indicate a builtin with target-dependent param types. Must appear by itself
    @"!",
};

const Suffix = union(enum) {
    /// pointer (optionally followed by an address space number,if no address space is specified than any address space will be accepted)
    @"*": ?u8,
    /// const
    C,
    /// volatile
    D,
    /// restrict
    R,
};
