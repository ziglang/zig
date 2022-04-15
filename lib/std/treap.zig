const std = @import("std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const Order = std.math.Order;

pub fn Treap(comptime Key: type, comptime compareFn: anytype) type {
    return struct {
        const Self = @This();

        // Allow for compareFn to be fn(anytype, anytype) anytype
        // which allows the convenient use of std.math.order. 
        fn compare(a: Key, b: Key) Order {
            return compareFn(a, b);
        }

        root: ?*Node = null,
        prng: Prng = .{},

        /// A customized pseudo random number generator for the treap.
        /// This just helps reducing the memory size of the treap itself
        /// as std.rand.DefaultPrng requires larger state (while producing better entropy for randomness to be fair).
        const Prng = struct {
            xorshift: usize = 0,

            fn random(self: *Prng, seed: usize) usize {
                // Lazily seed the prng state
                if (self.xorshift == 0) {
                    self.xorshift = seed;
                }

                // Since we're using usize, decide the shifts by the integer's bit width.
                const shifts = switch (@bitSizeOf(usize)) {
                    64 => .{13, 7, 17},
                    32 => .{13, 17, 5},
                    16 => .{7, 9, 8},
                    else => @compileError("platform not supported"),
                };

                self.xorshift ^= self.xorshift >> shifts[0];
                self.xorshift ^= self.xorshift << shifts[1];
                self.xorshift ^= self.xorshift >> shifts[2];

                assert(self.xorshift != 0);
                return self.xorshift;
            } 
        };

        /// A Node represents an item or point in the treap with a uniquely associated key.
        pub const Node = struct {
            key: Key,
            priority: usize,
            parent: ?*Node,
            children: [2]?*Node,
        };

        /// Returns the smallest Node by key in the treap if there is one.
        /// Use `getEntryForExisting()` to replace/remove this Node from the treap.
        pub fn getMin(self: Self) ?*Node {
            var node = self.root;
            while (node) |current| {
                node = current.children[0] orelse break;
            }
            return node;
        }

        /// Returns the largest Node by key in the treap if there is one.
        /// Use `getEntryForExisting()` to replace/remove this Node from the treap.
        pub fn getMax(self: Self) ?*Node {
            var node = self.root;
            while (node) |current| {
                node = current.children[1] orelse break;
            }
            return node;
        }

        /// Lookup the Entry for the given key in the treap.
        /// The Entry act's as a slot in the treap to insert/replace/remove the node associated with the key.
        pub fn getEntryFor(self: *Self, key: Key) Entry {
            var parent: ?*Node = undefined;
            const node = self.find(key, &parent);

            return Entry{
                .key = key,
                .treap = self,
                .node = node,
                .context = .{ .inserted_under = parent },
            };
        }

        /// Get an entry for a Node that currently exists in the treap.
        /// It is undefined behavior if the Node is not currently inserted in the treap.
        /// The Entry act's as a slot in the treap to insert/replace/remove the node associated with the key.
        pub fn getEntryForExisting(self: *Self, node: *Node) Entry {
            assert(node.priority != 0);

            return Entry{
                .key = node.key,
                .treap = self,
                .node = node,
                .context = .{ .inserted_under = node.parent },
            };
        }

        /// An Entry represents a slot in the treap associated with a given key.
        pub const Entry = struct {
            key: Key,
            treap: *Self,
            node: ?*Node,
            context: union(enum) {
                /// A find() was called for this entry and the position in the treap is known.
                inserted_under: ?*Node,
                /// The entry's node was removed from the treap and a lookup must occur again for modification.
                removed,
            },

            /// Returns the current Node at this Entry in the treap if there is one.
            pub fn get(self: Entry) ?*Node {
                return self.node;
            }

            /// Update's the Node at this Entry in the treap with the new node.
            pub fn set(self: *Entry, new_node: ?*Node) void {
                // Update the entry's node reference after updating the treap below.
                defer self.node = new_node;

                if (self.node) |old| {
                    if (new_node) |new| {
                        self.treap.replace(old, new);
                        return;
                    }

                    self.treap.remove(old);
                    self.context = .removed;
                    return;
                }

                if (new_node) |new| {
                    // A previous treap.remove() could have rebalanced the nodes
                    // so when inserting after a removal, we have to re-lookup the parent again.
                    // This lookup shouldn't find a node because we're yet to insert it..
                    var parent: ?*Node = undefined;
                    switch (self.context) {
                        .inserted_under => |p| parent = p,
                        .removed => assert(self.treap.find(self.key, &parent) == null),
                    }

                    self.treap.insert(self.key, parent, new);
                    self.context = .{ .inserted_under = parent };
                }
            }
        };

        fn find(self: Self, key: Key, parent_ref: *?*Node) ?*Node {
            var node = self.root;
            parent_ref.* = null;

            // basic binary search while tracking the parent.
            while (node) |current| {
                const order = compare(key, current.key);
                if (order == .eq) break;

                parent_ref.* = current;
                node = current.children[@boolToInt(order == .gt)];
            }

            return node;
        }
        
        fn insert(self: *Self, key: Key, parent: ?*Node, node: *Node) void {
            // generate a random priority & prepare the node to be inserted into the tree
            node.key = key;
            node.priority = self.prng.random(@ptrToInt(node));
            node.parent = parent;
            node.children = [_]?*Node{ null, null };

            // point the parent at the new node
            const link = if (parent) |p| &p.children[@boolToInt(compare(key, p.key) == .gt)] else &self.root;
            assert(link.* == null);
            link.* = node;

            // rotate the node up into the tree to balance it according to its priority
            while (node.parent) |p| {
                if (p.priority <= node.priority) break;

                const is_right = p.children[1] == @as(?*Node, node);
                assert(p.children[@boolToInt(is_right)] == node);

                const rotate_right = !is_right;
                self.rotate(p, rotate_right);
            }
        }

        fn replace(self: *Self, old: *Node, new: *Node) void {
            // copy over the values from the old node
            new.key = old.key;
            new.priority = old.priority;
            new.parent = old.parent;
            new.children = old.children;

            // point the parent at the new node
            const link = if (old.parent) |p| &p.children[@boolToInt(p.children[1] == old)] else &self.root;
            assert(link.* == old);
            link.* = new;

            // point the children's parent at the new node
            for (old.children) |child_node| {
                const child = child_node orelse continue;
                assert(child.parent == old);
                child.parent = new;
            }
        }

        fn remove(self: *Self, node: *Node) void {
            // rotate the node down to be a leaf of the tree for removal, respecting priorities.
            while (node.children[0] orelse node.children[1]) |_| {
                self.rotate(node, rotate_right: {
                    const right = node.children[0] orelse break :rotate_right true;
                    const left = node.children[1] orelse break :rotate_right false;
                    break :rotate_right (left.priority < right.priority);
                });
            }

            // node is a now a leaf; remove by nulling out the parent's reference to it.
            const link = if (node.parent) |p| &p.children[@boolToInt(p.children[1] == node)] else &self.root;
            assert(link.* == node);
            link.* = null;

            // clean up after ourselves
            node.key = undefined;
            node.priority = 0;
            node.parent = null;
            node.children = [_]?*Node{ null, null };
        }

        fn rotate(self: *Self, node: *Node, right: bool) void {
            // if right, converts the following: 
            //      parent -> (node (target YY adjacent) XX)
            //      parent -> (target YY (node adjacent XX))
            //
            // if left (!right), converts the following: 
            //      parent -> (node (target YY adjacent) XX)
            //      parent -> (target YY (node adjacent XX))
            const parent = node.parent;
            const target = node.children[@boolToInt(!right)] orelse unreachable;
            const adjacent = target.children[@boolToInt(right)];

            // do the rotation
            target.children[@boolToInt(right)] = node;
            node.parent = target;
            node.children[@boolToInt(!right)] = adjacent;
            if (adjacent) |adj| adj.parent = node;

            // fix the parent link
            const link = if (parent) |p| &p.children[@boolToInt(p.children[1] == node)] else &self.root;
            assert(link.* == node);
            link.* = target;
        }
    };
}

const TestTreap = Treap(u64, std.math.order);
const TestNode = TestTreap.Node;

test "std.Treap: insert, find, remove" {
    var prng = std.rand.DefaultPrng.init(0xdeadbeef);
    var rng = prng.random();

    var treap = TestTreap{};
    var nodes: [6]TestNode = undefined;

    for (nodes) |*node| {
        const key = rng.int(u64);

        var entry = treap.getEntryFor(key);
        try testing.expectEqual(entry.key, key);
        try testing.expectEqual(entry.get(), null);

        entry.set(node);
        try testing.expectEqual(entry.key, key);
        try testing.expectEqual(node.key, key);
        try testing.expectEqual(entry.get(), node);
    }

    for (nodes) |*node| {
        const key = node.key;

        var entry = treap.getEntryFor(node.key);
        try testing.expectEqual(entry.key, key);
        try testing.expectEqual(entry.get(), node);

        var existingEntry = treap.getEntryForExisting(node);
        try testing.expectEqual(entry, existingEntry);
    }
}
