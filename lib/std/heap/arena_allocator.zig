const std = @import("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const Allocator = std.mem.Allocator;

/// This allocator takes an existing allocator, wraps it, and provides an interface
/// where you can allocate without freeing, and then free it all together.
pub const ArenaAllocator = struct {
    allocator: Allocator,

    child_allocator: *Allocator,
    state: State,

    /// Inner state of ArenaAllocator. Can be stored rather than the entire ArenaAllocator
    /// as a memory-saving optimization.
    pub const State = struct {
        buffer_list: std.SinglyLinkedList([]u8) = @as(std.SinglyLinkedList([]u8), .{}),
        /// The first available index in the front buffer of `buffer_list`
        end_index: usize = 0,

        pub fn promote(self: State, child_allocator: *Allocator) ArenaAllocator {
            return .{
                .allocator = Allocator{
                    .allocFn = alloc,
                    .resizeFn = Allocator.noResize,
                },
                .child_allocator = child_allocator,
                .state = self,
            };
        }
    };

    const BufNode = std.SinglyLinkedList([]u8).Node;

    pub fn init(child_allocator: *Allocator) ArenaAllocator {
        return (State{}).promote(child_allocator);
    }

    pub fn deinit(self: ArenaAllocator) void {
        var it = self.state.buffer_list.first;
        while (it) |node| {
            // this has to occur before the free because the free frees node
            const next_it = node.next;
            self.child_allocator.free(node.data);
            it = next_it;
        }
    }

    fn getBufNodeAddr(buf: []u8) usize {
        return mem.alignBackward(@ptrToInt(buf.ptr) + buf.len - @sizeOf(BufNode), @alignOf(BufNode));
    }

    fn allocBuf(self: *ArenaAllocator, len: usize, ptr_align: u29) ![]u8 {
        const alloc_len = len + @sizeOf(BufNode) + @alignOf(BufNode) - 1;
        const buf = try self.child_allocator.callAllocFn(alloc_len, ptr_align, 1);
        const buf_node = @intToPtr(*BufNode, getBufNodeAddr(buf));
        buf_node.* = .{ .data = buf, .next = null };
        assert(@ptrToInt(buf_node) - @ptrToInt(buf.ptr) >= len);
        self.state.buffer_list.prepend(buf_node);
        self.state.end_index = len;
        return buf[0..len];
    }

    fn alloc(allocator: *Allocator, n: usize, ptr_align: u29, len_align: u29) ![]u8 {
        const self = @fieldParentPtr(ArenaAllocator, "allocator", allocator);

        if (self.state.buffer_list.first) |node_full_buf| {
            assert(self.state.end_index > 0);
            const cur_buf = node_full_buf.data[0..
                getBufNodeAddr(node_full_buf.data) - @ptrToInt(node_full_buf.data.ptr)];
            const addr = @ptrToInt(cur_buf.ptr) + self.state.end_index;
            const aligned_index = self.state.end_index + (mem.alignForward(addr, ptr_align) - addr);
            const aligned_end_index = aligned_index + n;
            if (aligned_end_index <= cur_buf.len) {
                self.state.end_index = aligned_end_index;
                return cur_buf[aligned_index..aligned_end_index];
            }
        }
        return try self.allocBuf(n, ptr_align);
    }
};
