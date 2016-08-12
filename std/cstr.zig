const List = @import("list.zig").List;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;
const debug = @import("debug.zig");
const assert = debug.assert;

const strlen = len;

// TODO fix https://github.com/andrewrk/zig/issues/140
// and then make this able to run at compile time
#static_eval_enable(false)
pub fn len(ptr: &const u8) -> usize {
    var count: usize = 0;
    while (ptr[count] != 0; count += 1) {}
    return count;
}

// TODO fix https://github.com/andrewrk/zig/issues/140
// and then make this able to run at compile time
#static_eval_enable(false)
pub fn cmp(a: &const u8, b: &const u8) -> i32 {
    var index: usize = 0;
    while (a[index] == b[index] && a[index] != 0; index += 1) {}
    return a[index] - b[index];
}

pub fn to_slice_const(str: &const u8) -> []const u8 {
    return str[0...strlen(str)];
}

pub fn to_slice(str: &u8) -> []u8 {
    return str[0...strlen(str)];
}


/// A buffer that allocates memory and maintains a null byte at the end.
pub struct CBuf {
    list: List(u8),

    /// Must deinitialize with deinit.
    pub fn init(self: &CBuf, allocator: &Allocator) {
        self.list.init(allocator);
        // This resize is guaranteed to not have an error because we use a list
        // with preallocated memory of at least 1 byte.
        %%self.resize(0);
    }

    /// Must deinitialize with deinit.
    pub fn init_from_mem(self: &CBuf, allocator: &Allocator, m: []const u8) -> %void {
        self.init(allocator);
        %return self.resize(m.len);
        mem.copy(u8, self.list.items, m);
    }

    /// Must deinitialize with deinit.
    pub fn init_from_cstr(self: &CBuf, allocator: &Allocator, s: &const u8) -> %void {
        self.init_from_mem(allocator, s[0...strlen(s)])
    }

    /// Must deinitialize with deinit.
    pub fn init_from_cbuf(self: &CBuf, cbuf: &const CBuf) -> %void {
        self.init_from_mem(cbuf.list.allocator, cbuf.list.items[0...cbuf.len()])
    }

    /// Must deinitialize with deinit.
    pub fn init_from_slice(self: &CBuf, other: &const CBuf, start: usize, end: usize) -> %void {
        self.init_from_mem(other.list.allocator, other.list.items[start...end])
    }

    pub fn deinit(self: &CBuf) {
        self.list.deinit();
    }

    pub fn resize(self: &CBuf, new_len: usize) -> %void {
        %return self.list.resize(new_len + 1);
        self.list.items[self.len()] = 0;
    }

    pub fn len(self: &const CBuf) -> usize {
        return self.list.len - 1;
    }

    pub fn append_mem(self: &CBuf, m: []const u8) -> %void {
        const old_len = self.len();
        %return self.resize(old_len + m.len);
        mem.copy(u8, self.list.items[old_len...], m);
    }

    pub fn append_cstr(self: &CBuf, s: &const u8) -> %void {
        self.append_mem(s[0...strlen(s)])
    }

    pub fn append_char(self: &CBuf, c: u8) -> %void {
        %return self.resize(self.len() + 1);
        self.list.items[self.len() - 1] = c;
    }

    pub fn eql_mem(self: &const CBuf, m: []const u8) -> bool {
        if (self.len() != m.len) return false;
        return mem.cmp(u8, self.list.items[0...m.len], m) == mem.Cmp.Equal;
    }

    pub fn eql_cstr(self: &const CBuf, s: &const u8) -> bool {
        self.eql_mem(s[0...strlen(s)])
    }

    pub fn eql_cbuf(self: &const CBuf, other: &const CBuf) -> bool {
        self.eql_mem(other.list.items[0...other.len()])
    }

    pub fn starts_with_mem(self: &const CBuf, m: []const u8) -> bool {
        if (self.len() < m.len) return false;
        return mem.cmp(u8, self.list.items[0...m.len], m) == mem.Cmp.Equal;
    }

    pub fn starts_with_cbuf(self: &const CBuf, other: &const CBuf) -> bool {
        self.starts_with_mem(other.list.items[0...other.len()])
    }

    pub fn starts_with_cstr(self: &const CBuf, s: &const u8) -> bool {
        self.starts_with_mem(s[0...strlen(s)])
    }
}

#attribute("test")
fn test_simple_cbuf() {
    var buf: CBuf = undefined;
    buf.init(&debug.global_allocator);
    assert(buf.len() == 0);
    %%buf.append_cstr(c"hello");
    %%buf.append_char(' ');
    %%buf.append_mem("world");
    assert(buf.eql_cstr(c"hello world"));
    assert(buf.eql_mem("hello world"));

    var buf2: CBuf = undefined;
    %%buf2.init_from_cbuf(&buf);
    assert(buf.eql_cbuf(&buf2));

    assert(buf.starts_with_mem("hell"));
    assert(buf.starts_with_cstr(c"hell"));

    %%buf2.resize(4);
    assert(buf.starts_with_cbuf(&buf2));
}
