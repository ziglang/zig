const std = @import("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const Allocator = std.mem.Allocator;

/// This allocator takes an existing allocator, wraps it, and provides an interface
/// where you can allocate without freeing, and then free it all together.
pub const ArenaAllocator = struct {
    child_allocator: Allocator,
    state: State,

    /// Inner state of ArenaAllocator. Can be stored rather than the entire ArenaAllocator
    /// as a memory-saving optimization.
    pub const State = struct {
        buffer_list: std.SinglyLinkedList([]u8) = @as(std.SinglyLinkedList([]u8), .{}),
        end_index: usize = 0,

        pub fn promote(self: State, child_allocator: Allocator) ArenaAllocator {
            return .{
                .child_allocator = child_allocator,
                .state = self,
            };
        }
    };

    pub fn allocator(self: *ArenaAllocator) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    const BufNode = std.SinglyLinkedList([]u8).Node;

    pub fn init(child_allocator: Allocator) ArenaAllocator {
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

    fn createNode(self: *ArenaAllocator, prev_len: usize, minimum_size: usize) ?*BufNode {
        const actual_min_size = minimum_size + (@sizeOf(BufNode) + 16);
        const big_enough_len = prev_len + actual_min_size;
        const len = big_enough_len + big_enough_len / 2;
        const log2_align = comptime std.math.log2_int(usize, @alignOf(BufNode));
        const ptr = self.child_allocator.rawAlloc(len, log2_align, @returnAddress()) orelse
            return null;
        const buf_node = @ptrCast(*BufNode, @alignCast(@alignOf(BufNode), ptr));
        buf_node.* = BufNode{
            .data = ptr[0..len],
            .next = null,
        };
        self.state.buffer_list.prepend(buf_node);
        self.state.end_index = 0;
        return buf_node;
    }

    fn alloc(ctx: *anyopaque, n: usize, log2_ptr_align: u8, ra: usize) ?[*]u8 {
        const self = @ptrCast(*ArenaAllocator, @alignCast(@alignOf(ArenaAllocator), ctx));
        _ = ra;

        const ptr_align = @as(usize, 1) << @intCast(Allocator.Log2Align, log2_ptr_align);
        var cur_node = if (self.state.buffer_list.first) |first_node|
            first_node
        else
            (self.createNode(0, n + ptr_align) orelse return null);
        while (true) {
            const cur_buf = cur_node.data[@sizeOf(BufNode)..];
            const addr = @ptrToInt(cur_buf.ptr) + self.state.end_index;
            const adjusted_addr = mem.alignForward(addr, ptr_align);
            const adjusted_index = self.state.end_index + (adjusted_addr - addr);
            const new_end_index = adjusted_index + n;

            if (new_end_index <= cur_buf.len) {
                const result = cur_buf[adjusted_index..new_end_index];
                self.state.end_index = new_end_index;
                return result.ptr;
            }

            const bigger_buf_size = @sizeOf(BufNode) + new_end_index;
            if (self.child_allocator.resize(cur_node.data, bigger_buf_size)) {
                cur_node.data.len = bigger_buf_size;
            } else {
                // Allocate a new node if that's not possible
                cur_node = self.createNode(cur_buf.len, n + ptr_align) orelse return null;
            }
        }
    }

    fn resize(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool {
        const self = @ptrCast(*ArenaAllocator, @alignCast(@alignOf(ArenaAllocator), ctx));
        _ = log2_buf_align;
        _ = ret_addr;

        const cur_node = self.state.buffer_list.first orelse return false;
        const cur_buf = cur_node.data[@sizeOf(BufNode)..];
        if (@ptrToInt(cur_buf.ptr) + self.state.end_index != @ptrToInt(buf.ptr) + buf.len) {
            // It's not the most recent allocation, so it cannot be expanded,
            // but it's fine if they want to make it smaller.
            return new_len <= buf.len;
        }

        if (buf.len >= new_len) {
            self.state.end_index -= buf.len - new_len;
            return true;
        } else if (cur_buf.len - self.state.end_index >= new_len - buf.len) {
            self.state.end_index += new_len - buf.len;
            return true;
        } else {
            return false;
        }
    }

    fn free(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, ret_addr: usize) void {
        _ = log2_buf_align;
        _ = ret_addr;

        const self = @ptrCast(*ArenaAllocator, @alignCast(@alignOf(ArenaAllocator), ctx));

        const cur_node = self.state.buffer_list.first orelse return;
        const cur_buf = cur_node.data[@sizeOf(BufNode)..];

        if (@ptrToInt(cur_buf.ptr) + self.state.end_index == @ptrToInt(buf.ptr) + buf.len) {
            self.state.end_index -= buf.len;
        }
    }
};
