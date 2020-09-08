// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
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
                    .allocFn = alloc,
                    .resizeFn = resize,
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
        const actual_min_size = minimum_size + (@sizeOf(BufNode) + 16);
        const big_enough_len = prev_len + actual_min_size;
        const len = big_enough_len + big_enough_len / 2;
        const buf = try self.child_allocator.allocFn(self.child_allocator, len, @alignOf(BufNode), 1, @returnAddress());
        const buf_node = @ptrCast(*BufNode, @alignCast(@alignOf(BufNode), buf.ptr));
        buf_node.* = BufNode{
            .data = buf,
            .next = null,
        };
        self.state.buffer_list.prepend(buf_node);
        self.state.end_index = 0;
        return buf_node;
    }

    fn alloc(allocator: *Allocator, n: usize, ptr_align: u29, len_align: u29, ra: usize) ![]u8 {
        const self = @fieldParentPtr(ArenaAllocator, "allocator", allocator);

        var cur_node = if (self.state.buffer_list.first) |first_node| first_node else try self.createNode(0, n + ptr_align);
        while (true) {
            const cur_buf = cur_node.data[@sizeOf(BufNode)..];
            const addr = @ptrToInt(cur_buf.ptr) + self.state.end_index;
            const adjusted_addr = mem.alignForward(addr, ptr_align);
            const adjusted_index = self.state.end_index + (adjusted_addr - addr);
            const new_end_index = adjusted_index + n;
            if (new_end_index > cur_buf.len) {
                cur_node = try self.createNode(cur_buf.len, n + ptr_align);
                continue;
            }
            const result = cur_buf[adjusted_index..new_end_index];
            self.state.end_index = new_end_index;
            return result;
        }
    }

    fn resize(allocator: *Allocator, buf: []u8, buf_align: u29, new_len: usize, len_align: u29, ret_addr: usize) Allocator.Error!usize {
        const self = @fieldParentPtr(ArenaAllocator, "allocator", allocator);

        const cur_node = self.state.buffer_list.first orelse return error.OutOfMemory;
        const cur_buf = cur_node.data[@sizeOf(BufNode)..];
        if (@ptrToInt(cur_buf.ptr) + self.state.end_index != @ptrToInt(buf.ptr) + buf.len) {
            if (new_len > buf.len)
                return error.OutOfMemory;
            return new_len;
        }

        if (buf.len >= new_len) {
            self.state.end_index -= buf.len - new_len;
            return new_len;
        } else if (cur_buf.len - self.state.end_index >= new_len - buf.len) {
            self.state.end_index += new_len - buf.len;
            return new_len;
        } else {
            return error.OutOfMemory;
        }
    }
};
