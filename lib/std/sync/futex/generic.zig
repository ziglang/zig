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
        const WaitLock = switch (@hasDecl(Event, "Lock") and Event.Lock != void) {
            true => Event.Lock,
            else => WordLock(Event),
        };

        const bucket_count = switch (@hasDecl(Event, "bucket_count")) {
            true => Event.bucket_count,
            else => std.meta.bitCount(usize) << 2,
        };

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
            tree_head: ?*WaitNode = null,

            const Lookup = struct {
                tree_prev: ?*WaitNode,
                tree_node: ?*WaitNode,
            };

            fn find(self: *WaitTree, address: usize) Lookup {
                var lookup = Lookup{
                    .tree_prev = null,
                    .tree_node = self.tree_head,
                };

                while (lookup.tree_node) |tree_node| {
                    if (tree_node.address == address) {
                        break;
                    } else {
                        lookup.tree_prev = tree_node;
                        lookup.tree_node = tree_node.tree_next;
                    }
                }

                return lookup;
            }

            fn insert(self: *WaitTree, lookup: Lookup, node: *WaitNode) void {
                assert(node != self.tree_head);
                node.tree_next = null;
                node.tree_prev = lookup.tree_prev;

                if (node.tree_prev) |prev| {
                    assert(prev.tree_next == null);
                    prev.tree_next = node;
                } else {
                    assert(self.tree_head == null);
                    self.tree_head = node;
                }
            }

            fn replace(self: *WaitTree, node: *WaitNode, new_node: *WaitNode) void {
                assert(node != new_node);
                assert(node.address == new_node.address);
                assert((node == self.tree_head) or ((node.tree_prev orelse node.tree_next) != null));

                if (node.tree_next) |next| {
                    next.tree_prev = new_node;
                }
                if (node.tree_prev) |prev| {
                    prev.tree_next = new_node;
                }
                if (self.tree_head == node) {
                    self.tree_head = new_node;
                }
            }

            fn remove(self: *WaitTree, node: *WaitNode) void {
                assert((node == self.tree_head) or ((node.tree_prev orelse node.tree_next) != null));

                if (node.tree_next) |next| {
                    next.tree_prev = node.tree_prev;
                }
                if (node.tree_prev) |prev| {
                    prev.tree_next = node.tree_next;
                }
                if (self.tree_head == node) {
                    self.tree_head = null;
                }
            }
        };

        const WaitQueue = struct {
            tree: *WaitTree,
            head: ?*WaitNode,
            address: usize,
            lookup: WaitTree.Lookup,

            fn find(tree: *WaitTree, address: usize) WaitQueue {
                const lookup = tree.find(address);

                return WaitQueue{
                    .tree = tree,
                    .head = lookup.tree_node,
                    .address = address,
                    .lookup = lookup,
                };
            }

            fn insert(self: *WaitQueue, node: *WaitNode) void {
                node.prev = null;
                node.next = null;
                node.tail = node;
                node.address = self.address;

                const head = self.head orelse {
                    self.head = node;
                    self.tree.insert(self.lookup, node);
                    return;
                };

                const tail = head.tail orelse unreachable;
                head.tail = node;
                node.prev = tail;
                tail.next = node;
            }

            fn isInserted(node: *WaitNode) bool {
                return node.tail != null;
            }

            fn popFirst(self: *WaitQueue) ?*WaitNode {
                const node = self.head orelse return null;
                self.remove(node);
                return node;
            }

            fn remove(self: *WaitQueue, node: *WaitNode) void {
                assert(isInserted(node));
                defer node.tail = null;

                if (node.prev) |prev| {
                    prev.next = node.next;
                }
                if (node.next) |next| {
                    next.prev = node.prev;
                }

                const head = self.head orelse unreachable;
                if (node == head) {
                    self.head = node.next;
                    if (self.head) |new_head| {
                        new_head.tail = head.tail;
                        self.tree.replace(head, new_head);
                    } else {
                        self.tree.remove(node);
                    }
                } else if (node == head.tail) {
                    assert(node.prev != null);
                    head.tail = node.prev;
                }
            }
        };

        const WaitNode = struct {
            tree_prev: ?*WaitNode,
            tree_next: ?*WaitNode,
            prev: ?*WaitNode,
            next: ?*WaitNode,
            tail: ?*WaitNode,
            address: usize,
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
                    held.release();
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
                const held = bucket.lock.acquire();
                defer held.release();

                timed_out = WaitQueue.isInserted(&node);
                if (timed_out) {
                    _ = atomic.fetchSub(&bucket.waiters, 1, .SeqCst);
                    var queue = WaitQueue.find(&bucket.tree, address);
                    queue.remove(&node);
                }
            }

            if (!timed_out) {
                node.event.wait(null) catch unreachable;
            }

            node.event.deinit();
            if (timed_out) {
                return error.TimedOut;
            }
        }

        pub fn notifyOne(ptr: *const u32) void {
            const address = @ptrToInt(ptr);
            const bucket = WaitBucket.from(address);

            if (atomic.load(&bucket.waiters, .SeqCst) == 0) {
                return;
            }

            const node = blk: {
                const held = bucket.lock.acquire();
                defer held.release();

                var queue = WaitQueue.find(&bucket.tree, address);
                const node = queue.popFirst() orelse return;
                _ = atomic.fetchSub(&bucket.waiters, 1, .SeqCst);
                break :blk node;
            };

            node.event.set();
        }

        pub fn notifyAll(ptr: *const u32) void {
            const address = @ptrToInt(ptr);
            const bucket = WaitBucket.from(address);

            if (atomic.load(&bucket.waiters, .SeqCst) == 0) {
                return;
            }

            var nodes = blk: {
                const held = bucket.lock.acquire();
                defer held.release();

                var dequeued: usize = 0;
                var nodes: ?*WaitNode = null;
                var queue = WaitQueue.find(&bucket.tree, address);

                while (queue.popFirst()) |node| {
                    node.next = nodes;
                    nodes = node;
                    dequeued += 1;
                }

                if (dequeued > 0) {
                    _ = atomic.fetchSub(&bucket.waiters, dequeued, .SeqCst);
                }
                break :blk nodes;
            };

            while (nodes) |node| {
                nodes = node.next;
                node.event.set();
            }
        }
    };
}

fn WordLock(comptime Event: type) type {
    return struct {
        state: usize = UNLOCKED,

        const UNLOCKED = 0;
        const LOCKED = 1;
        const WAKING = 1 << 1;
        const WAITING = ~@as(usize, (WAKING << 1) - 1);

        const Self = @This();
        const Waiter = struct {
            prev: ?*Waiter align(std.math.max(~WAITING + 1, @alignOf(usize))),
            next: ?*Waiter,
            tail: ?*Waiter,
            event: Event,
        };

        inline fn tryAcquireFast(self: *Self, state: usize) bool {
            return switch (builtin.arch) {
                .i386, .x86_64 => atomic.bitSet(
                    &self.state,
                    @ctz(u1, LOCKED),
                    .Acquire,
                ) == 0,
                else => atomic.tryCompareAndSwap(
                    &self.state,
                    state,
                    state | LOCKED,
                    .Acquire,
                    .Relaxed,
                ) == null,
            };
        }

        pub fn acquire(self: *Self) Held {
            if (!self.tryAcquireFast(UNLOCKED)) {
                self.acquireSlow();
            }

            if (helgrind) |hg| {
                hg.annotateHappensAfter(@ptrToInt(self));
            }

            return Held{ .lock = self };
        }

        fn acquireSlow(self: *Self) void {
            @setCold(true);

            var waiter: Waiter = undefined;
            var event_initialized = false;
            defer if (event_initialized) {
                if (helgrind) |hg| {
                    hg.annotateHappensBeforeForgetAll(@ptrToInt(&waiter));
                }
                waiter.event.deinit();
            };

            var adaptive_spin: usize = 0;
            var state = atomic.load(&self.state, .Relaxed);

            while (true) {
                if (state & LOCKED == 0) {
                    if (self.tryAcquireFast(state)) {
                        break;
                    }

                    var spin: usize = 32;
                    while (spin > 0) : (spin -= 1) {
                        atomic.spinLoopHint();
                    }

                    state = atomic.load(&self.state, .Relaxed);
                    continue;
                }

                const head = @intToPtr(?*Waiter, state & WAITING);
                if (head == null and adaptive_spin < 100) {
                    var spin = std.math.min(32, std.math.max(8, adaptive_spin));
                    while (spin > 0) : (spin -= 1) {
                        atomic.spinLoopHint();
                    }

                    adaptive_spin += 1;
                    state = atomic.load(&self.state, .Relaxed);
                    continue;
                }

                waiter.prev = null;
                waiter.next = head;
                waiter.tail = if (head == null) &waiter else null;

                if (!event_initialized) {
                    waiter.event.init();
                    event_initialized = true;
                }

                if (helgrind) |hg| {
                    hg.annotateHappensBefore(@ptrToInt(&waiter));
                }

                if (atomic.tryCompareAndSwap(
                    &self.state,
                    state,
                    (state & ~WAITING) | @ptrToInt(&waiter),
                    .Release,
                    .Relaxed,
                )) |updated| {
                    state = updated;
                    continue;
                }

                waiter.event.wait(null) catch unreachable;

                if (helgrind) |hg| {
                    hg.annotateHappensAfter(@ptrToInt(&waiter));
                }

                adaptive_spin = 0;
                waiter.event.reset();
                state = atomic.load(&self.state, .Relaxed);
            }
        }

        pub const Held = struct {
            lock: *Self,

            pub fn release(self: Held) void {
                self.lock.release();
            }
        };

        fn release(self: *Self) void {
            if (helgrind) |hg| {
                hg.annotateHappensBefore(@ptrToInt(self));
            }

            const state = switch (builtin.arch) {
                .i386, .x86_64 => atomic.fetchSub(&self.state, LOCKED, .Release),
                else => atomic.fetchAnd(&self.state, ~@as(usize, LOCKED), .Release),
            };

            if ((state & WAITING != 0) and (state & WAKING == 0)) {
                self.releaseSlow();
            }
        }

        fn releaseSlow(self: *Self) void {
            @setCold(true);

            var state = atomic.load(&self.state, .Relaxed);
            while (true) {
                if ((state & WAITING == 0) or (state & (LOCKED | WAKING) != 0)) {
                    return;
                }

                state = atomic.tryCompareAndSwap(
                    &self.state,
                    state,
                    state | WAKING,
                    .Acquire,
                    .Relaxed,
                ) orelse {
                    state |= WAKING;
                    break;
                };
            }

            dequeue: while (true) {
                const head = @intToPtr(*Waiter, state & WAITING);
                const tail = head.tail orelse blk: {
                    var current = head;
                    while (true) {
                        const next = current.next orelse unreachable;
                        next.prev = current;
                        current = next;
                        if (current.tail) |tail| {
                            head.tail = tail;
                            break :blk tail;
                        }
                    }
                };

                if (state & LOCKED != 0) {
                    state = atomic.tryCompareAndSwap(
                        &self.state,
                        state,
                        state & ~@as(usize, WAKING),
                        .Release,
                        .Acquire,
                    ) orelse return;
                    continue;
                }

                if (tail.prev) |new_tail| {
                    head.tail = new_tail;
                    _ = atomic.fetchAnd(&self.state, ~@as(usize, WAKING), .Release);
                } else {
                    while (true) {
                        state = atomic.tryCompareAndSwap(
                            &self.state,
                            state,
                            state & ~@as(usize, WAITING),
                            .Relaxed,
                            .Relaxed,
                        ) orelse break;

                        if (state & WAITING != 0) {
                            atomic.fence(.Acquire);
                            continue :dequeue;
                        }
                    }
                }

                if (helgrind) |hg| {
                    hg.annotateHappensBefore(@ptrToInt(tail));
                }

                tail.event.set();
                return;
            }
        }
    };
}
