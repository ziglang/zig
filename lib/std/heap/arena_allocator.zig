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
        end_index: usize = 0,

        pub fn promote(self: State, child_allocator: *Allocator) ArenaAllocator {
            return .{
                .allocator = Allocator{
                    .reallocFn = realloc,
                    .shrinkFn = shrink,
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

    fn createNode(self: *ArenaAllocator, prev_len: usize, minimum_size: usize) !*BufNode {
        const actual_min_size = minimum_size + @sizeOf(BufNode);
        var len = prev_len;
        while (true) {
            len += len / 2;
            len += mem.page_size - @rem(len, mem.page_size);
            if (len >= actual_min_size) break;
        }
        const buf = try self.child_allocator.alignedAlloc(u8, @alignOf(BufNode), len);
        const buf_node_slice = mem.bytesAsSlice(BufNode, buf[0..@sizeOf(BufNode)]);
        const buf_node = &buf_node_slice[0];
        buf_node.* = BufNode{
            .data = buf,
            .next = null,
        };
        self.state.buffer_list.prepend(buf_node);
        self.state.end_index = 0;
        return buf_node;
    }

    fn alloc(allocator: *Allocator, n: usize, alignment: u29) ![]u8 {
        const self = @fieldParentPtr(ArenaAllocator, "allocator", allocator);

        var cur_node = if (self.state.buffer_list.first) |first_node| first_node else try self.createNode(0, n + alignment);
        while (true) {
            const cur_buf = cur_node.data[@sizeOf(BufNode)..];
            const addr = @ptrToInt(cur_buf.ptr) + self.state.end_index;
            const adjusted_addr = mem.alignForward(addr, alignment);
            const adjusted_index = self.state.end_index + (adjusted_addr - addr);
            const new_end_index = adjusted_index + n;
            if (new_end_index > cur_buf.len) {
                cur_node = try self.createNode(cur_buf.len, n + alignment);
                continue;
            }
            const result = cur_buf[adjusted_index..new_end_index];
            self.state.end_index = new_end_index;
            return result;
        }
    }

    fn realloc(allocator: *Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) ![]u8 {
        if (new_size <= old_mem.len and new_align <= new_size) {
            // We can't do anything with the memory, so tell the client to keep it.
            return error.OutOfMemory;
        } else {
            const result = try alloc(allocator, new_size, new_align);
            @memcpy(result.ptr, old_mem.ptr, std.math.min(old_mem.len, result.len));
            return result;
        }
    }

    fn shrink(allocator: *Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) []u8 {
        return old_mem[0..new_size];
    }
};
