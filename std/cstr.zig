const List = @import("list.zig").List;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;
const debug = @import("debug.zig");
const assert = debug.assert;

const strlen = len;

pub fn len(ptr: &const u8) -> usize {
    var count: usize = 0;
    while (ptr[count] != 0; count += 1) {}
    return count;
}

pub fn cmp(a: &const u8, b: &const u8) -> i8 {
    var index: usize = 0;
    while (a[index] == b[index] && a[index] != 0; index += 1) {}
    if (a[index] > b[index]) {
        return 1;
    } else if (a[index] < b[index]) {
        return -1;
    } else {
        return 0;
    };
}

pub fn toSliceConst(str: &const u8) -> []const u8 {
    return str[0...strlen(str)];
}

pub fn toSlice(str: &u8) -> []u8 {
    return str[0...strlen(str)];
}


/// A buffer that allocates memory and maintains a null byte at the end.
pub const Buffer0 = struct {
    list: List(u8),

    /// Must deinitialize with deinit.
    pub fn initEmpty(allocator: &Allocator) -> %Buffer0 {
        return initSize(allocator, 0);
    }

    /// Must deinitialize with deinit.
    pub fn initFromMem(allocator: &Allocator, m: []const u8) -> %Buffer0 {
        var self = %return initSize(allocator, m.len);
        mem.copy(u8, self.list.items, m);
        return self;
    }

    /// Must deinitialize with deinit.
    pub fn initFromCStr(allocator: &Allocator, s: &const u8) -> %Buffer0 {
        return Buffer0.initFromMem(allocator, s[0...strlen(s)]);
    }

    /// Must deinitialize with deinit.
    pub fn initFromOther(cbuf: &const Buffer0) -> %Buffer0 {
        return Buffer0.initFromMem(cbuf.list.allocator, cbuf.list.items[0...cbuf.len()]);
    }

    /// Must deinitialize with deinit.
    pub fn initFromSlice(other: &const Buffer0, start: usize, end: usize) -> %Buffer0 {
        return Buffer0.initFromMem(other.list.allocator, other.list.items[start...end]);
    }

    /// Must deinitialize with deinit.
    pub fn initSize(allocator: &Allocator, size: usize) -> %Buffer0 {
        var self = Buffer0 {
            .list = List(u8).init(allocator),
        };
        %return self.resize(size);
        return self;
    }

    pub fn deinit(self: &Buffer0) {
        self.list.deinit();
    }

    pub fn toSlice(self: &Buffer0) -> []u8 {
        return self.list.toSlice()[0...self.len()];
    }

    pub fn toSliceConst(self: &const Buffer0) -> []const u8 {
        return self.list.toSliceConst()[0...self.len()];
    }

    pub fn resize(self: &Buffer0, new_len: usize) -> %void {
        %return self.list.resize(new_len + 1);
        self.list.items[self.len()] = 0;
    }

    pub fn len(self: &const Buffer0) -> usize {
        return self.list.len - 1;
    }

    pub fn appendMem(self: &Buffer0, m: []const u8) -> %void {
        const old_len = self.len();
        %return self.resize(old_len + m.len);
        mem.copy(u8, self.list.toSlice()[old_len...], m);
    }

    pub fn appendOther(self: &Buffer0, other: &const Buffer0) -> %void {
        return self.appendMem(other.toSliceConst());
    }

    pub fn appendCStr(self: &Buffer0, s: &const u8) -> %void {
        self.appendMem(s[0...strlen(s)])
    }

    pub fn appendByte(self: &Buffer0, byte: u8) -> %void {
        %return self.resize(self.len() + 1);
        self.list.items[self.len() - 1] = byte;
    }

    pub fn eqlMem(self: &const Buffer0, m: []const u8) -> bool {
        if (self.len() != m.len) return false;
        return mem.cmp(u8, self.list.items[0...m.len], m) == mem.Cmp.Equal;
    }

    pub fn eqlCStr(self: &const Buffer0, s: &const u8) -> bool {
        self.eqlMem(s[0...strlen(s)])
    }

    pub fn eqlOther(self: &const Buffer0, other: &const Buffer0) -> bool {
        self.eqlMem(other.list.items[0...other.len()])
    }

    pub fn startsWithMem(self: &const Buffer0, m: []const u8) -> bool {
        if (self.len() < m.len) return false;
        return mem.cmp(u8, self.list.items[0...m.len], m) == mem.Cmp.Equal;
    }

    pub fn startsWithOther(self: &const Buffer0, other: &const Buffer0) -> bool {
        self.startsWithMem(other.list.items[0...other.len()])
    }

    pub fn startsWithCStr(self: &const Buffer0, s: &const u8) -> bool {
        self.startsWithMem(s[0...strlen(s)])
    }
};

test "simple Buffer0" {
    var buf = %%Buffer0.initEmpty(&debug.global_allocator);
    assert(buf.len() == 0);
    %%buf.appendCStr(c"hello");
    %%buf.appendByte(' ');
    %%buf.appendMem("world");
    assert(buf.eqlCStr(c"hello world"));
    assert(buf.eqlMem("hello world"));
    assert(mem.eql(u8, buf.toSliceConst(), "hello world"));

    var buf2 = %%Buffer0.initFromOther(&buf);
    assert(buf.eqlOther(&buf2));

    assert(buf.startsWithMem("hell"));
    assert(buf.startsWithCStr(c"hell"));

    %%buf2.resize(4);
    assert(buf.startsWithOther(&buf2));
}

test "cstr fns" {
    comptime testCStrFnsImpl();
    testCStrFnsImpl();
}

fn testCStrFnsImpl() {
    assert(cmp(c"aoeu", c"aoez") == -1);
    assert(len(c"123456789") == 9);
}
