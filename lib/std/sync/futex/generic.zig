// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");

const builtin = std.builtin;
const assert = std.debug.assert;
const helgrind: ?type = if (builtin.valgrind_support) std.valgrind.helgrind else null;

pub fn Futex(comptime Event: type) type {
    return struct {
        const WaitLock = Event.Lock;
        const bucket_count = Event.bucket_count;

        const WaitBucket = struct {
            lock: WaitLock = .{},
            waiters: usize = 0,
            tree: WaitTree = .{},

            var array = [_]WaitBucket{WaitBucket{}} ** bucket_count;

            /// Hash a address to a wait-bucket.
            /// This uses the same method as seen in Amanieu's port of WTF::ParkingLot:
            /// https://github.com/Amanieu/parking_lot/blob/master/core/src/parking_lot.rs
            fn from(address: usize) *WaitBucket {
                const seed = @truncate(usize, 0x9E3779B97F4A7C15);
                const max = std.meta.bitCount(usize);
                const bits = @ctz(usize, array.len);
                const index = (address *% seed) >> (max - bits);
                return &array[index];
            }
        };

        const WaitTree = struct {
            root: ?*WaitNode = null,

            const Lookup = struct {
                tree_prev: ?*WaitNode,
                tree_node: ?*WaitNode,
            };

            fn find(self: *WaitTree, address: usize) Lookup {
                var lookup = Lookup{
                    .tree_prev = null,
                    .tree_node = self.root,
                };

                while (lookup.tree_node) |node| {
                    if (node.address == address) {
                        break;
                    }
                    lookup.tree_prev = node;
                    lookup.tree_node = node.tree_next;
                }

                return lookup;
            }

            fn insert(self: *WaitTree, lookup: Lookup) void {
                const node = lookup.tree_node orelse unreachable;
                node.tree_prev = lookup.tree_prev;
                node.tree_next = null;

                if (node.tree_prev) |prev| {
                    prev.tree_next = node;
                } else {
                    self.root = node;
                }
            }

            fn replace(self: *WaitTree, node: *WaitNode, new_node: *WaitNode) void {
                new_node.tree_prev = node.tree_prev;
                new_node.tree_next = node.tree_next;

                if (node.tree_prev) |prev| {
                    prev.tree_next = new_node;
                }
                if (node.tree_next) |next| {
                    next.tree_prev = new_node;
                }
                if (self.root == node) {
                    self.root = new_node;
                }
            }

            fn remove(self: *WaitTree, node: *WaitNode) void {
                if (node.tree_next) |next| {
                    next.tree_prev = node.tree_prev;
                }
                if (node.tree_prev) |prev| {
                    prev.tree_next = node.tree_next;
                }
                if (self.root == node) {
                    self.root = node.tree_next;
                }
            }
        };

        const WaitQueue = struct {
            address: usize,
            tree: *WaitTree,
            head: ?*WaitNode,
            tree_prev: ?*WaitNode,

            fn find(tree: *WaitTree, address: usize) WaitQueue {
                const lookup = tree.find(address);

                return WaitQueue{
                    .address = address,
                    .tree = tree,
                    .head = lookup.tree_node,
                    .tree_prev = lookup.tree_prev,
                };
            }

            fn insert(self: *WaitQueue, node: *WaitNode) void {
                node.next = null;
                node.is_inserted = true;
                node.address = self.address;

                if (self.head) |head| {
                    const tail = head.tail orelse unreachable;
                    tail.next = node;
                    node.prev = tail;
                    head.tail = node;

                } else {
                    node.tail = node;
                    node.prev = null;
                    self.head = node;
                    self.tree.insert(WaitTree.Lookup{
                        .tree_prev = self.tree_prev,
                        .tree_node = node,
                    });
                }
            }

            fn popFirst(self: *WaitQueue) ?*WaitNode {
                const node = self.head orelse return null;
                self.remove(node);
                return node;
            }

            fn remove(self: *WaitQueue, node: *WaitNode) void {
                assert(node.is_inserted);
                defer node.is_inserted = false;

                if (node.next) |next| {
                    next.prev = node.prev;
                }
                if (node.prev) |prev| {
                    prev.next = node.next;
                }

                const head = self.head orelse unreachable;
                if (node == head) {
                    self.head = node.next;
                    if (self.head) |new_head| {
                        new_head.tail = head.tail;
                        self.tree.replace(head, new_head);
                    } else {
                        self.tree.remove(head);
                    }
                } else if (node == head.tail) {
                    head.tail = node.prev;
                }
            }
        };

        const WaitNode = struct {
            address: usize,
            is_inserted: bool,
            tree_prev: ?*WaitNode,
            tree_next: ?*WaitNode,
            prev: ?*WaitNode,
            next: ?*WaitNode,
            tail: ?*WaitNode,
            event: Event,
        };

        pub fn now() u64 {
            return Event.now();
        }

        pub fn wait(ptr: *const u32, expect: u32, deadline: ?u64) error{TimedOut}!void {
            var node: WaitNode = undefined;
            const address = @ptrToInt(ptr);
            const bucket = WaitBucket.from(address);

            {
                _ = atomic.fetchAdd(&bucket.waiters, 1, .SeqCst);

                const held = bucket.lock.acquire();
                defer held.release();

                if (atomic.load(ptr, .SeqCst) != expect) {
                    _ = atomic.fetchSub(&bucket.waiters, 1, .SeqCst);
                    return;
                }

                var queue = WaitQueue.find(&bucket.tree, address);
                queue.insert(&node);
                node.event.init();
            }

            var timed_out = false;
            node.event.wait(deadline) catch {
                timed_out = true;
            };

            if (timed_out) {
                {
                    const held = bucket.lock.acquire();
                    defer held.release();

                    timed_out = node.is_inserted;
                    if (timed_out) {
                        _ = atomic.fetchSub(&bucket.waiters, 1, .SeqCst);
                        var queue = WaitQueue.find(&bucket.tree, address);
                        queue.remove(&node);
                    }
                }

                if (!timed_out) {
                    node.event.wait(null) catch unreachable;
                }
            }

            node.event.deinit();
            if (timed_out) {
                return error.TimedOut;
            }
        }

        pub fn wake(ptr: *const u32, num_waiters: u32) void {
            const address = @ptrToInt(ptr);
            const bucket = WaitBucket.from(address);

            if (atomic.load(&bucket.waiters, .SeqCst) == 0) {
                return;
            }

            var nodes: ?*WaitNode = null;
            {
                const held = bucket.lock.acquire();
                defer held.release();

                var woke_up: u32 = 0;
                defer if (woke_up > 0) {
                    _ = atomic.fetchSub(&bucket.waiters, woke_up, .SeqCst);
                };

                var queue = WaitQueue.find(&bucket.tree, address);
                while (true) {
                    const node = queue.popFirst() orelse break;
                    node.next = nodes;
                    nodes = node;

                    woke_up += 1;
                    if (woke_up >= num_waiters) {
                        break;
                    }
                }
            }

            while (nodes) |node| {
                nodes = node.next;
                node.event.set();
            }
        }
    };
}
