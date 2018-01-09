const std = @import("index.zig");
const debug = std.debug;
const assert = debug.assert;
const mem = std.mem;
const Allocator = mem.Allocator;

/// Generic doubly linked list.
pub fn LinkedList(comptime T: type) -> type {
    return struct {
        const Self = this;

        /// Node inside the linked list wrapping the actual data.
        pub const Node = struct {
            prev: ?&Node,
            next: ?&Node,
            data: T,

            pub fn init(data: &const T) -> Node {
                return Node {
                    .prev = null,
                    .next = null,
                    .data = *data,
                };
            }
        };

        first: ?&Node,
        last:  ?&Node,
        len:   usize,

        /// Initialize a linked list.
        ///
        /// Returns:
        ///     An empty linked list.
        pub fn init() -> Self {
            return Self {
                .first = null,
                .last  = null,
                .len   = 0,
            };
        }

        /// Insert a new node after an existing one.
        ///
        /// Arguments:
        ///     node: Pointer to a node in the list.
        ///     new_node: Pointer to the new node to insert.
        pub fn insertAfter(list: &Self, node: &Node, new_node: &Node) {
            new_node.prev = node;
            if (node.next) |next_node| {
                // Intermediate node.
                new_node.next = next_node;
                next_node.prev = new_node;
            } else {
                // Last element of the list.
                new_node.next = null;
                list.last = new_node;
            }
            node.next = new_node;

            list.len += 1;
        }

        /// Insert a new node before an existing one.
        ///
        /// Arguments:
        ///     node: Pointer to a node in the list.
        ///     new_node: Pointer to the new node to insert.
        pub fn insertBefore(list: &Self, node: &Node, new_node: &Node) {
            new_node.next = node;
            if (node.prev) |prev_node| {
                // Intermediate node.
                new_node.prev = prev_node;
                prev_node.next = new_node;
            } else {
                // First element of the list.
                new_node.prev = null;
                list.first = new_node;
            }
            node.prev = new_node;

            list.len += 1;
        }

        /// Insert a new node at the end of the list.
        ///
        /// Arguments:
        ///     new_node: Pointer to the new node to insert.
        pub fn append(list: &Self, new_node: &Node) {
            if (list.last) |last| {
                // Insert after last.
                list.insertAfter(last, new_node);
            } else {
                // Empty list.
                list.prepend(new_node);
            }
        }

        /// Insert a new node at the beginning of the list.
        ///
        /// Arguments:
        ///     new_node: Pointer to the new node to insert.
        pub fn prepend(list: &Self, new_node: &Node) {
            if (list.first) |first| {
                // Insert before first.
                list.insertBefore(first, new_node);
            } else {
                // Empty list.
                list.first = new_node;
                list.last  = new_node;
                new_node.prev = null;
                new_node.next = null;

                list.len = 1;
            }
        }

        /// Remove a node from the list.
        ///
        /// Arguments:
        ///     node: Pointer to the node to be removed.
        pub fn remove(list: &Self, node: &Node) {
            if (node.prev) |prev_node| {
                // Intermediate node.
                prev_node.next = node.next;
            } else {
                // First element of the list.
                list.first = node.next;
            }

            if (node.next) |next_node| {
                // Intermediate node.
                next_node.prev = node.prev;
            } else {
                // Last element of the list.
                list.last = node.prev;
            }

            list.len -= 1;
        }

        /// Remove and return the last node in the list.
        ///
        /// Returns:
        ///     A pointer to the last node in the list.
        pub fn pop(list: &Self) -> ?&Node {
            const last = list.last ?? return null;
            list.remove(last);
            return last;
        }

        /// Remove and return the first node in the list.
        ///
        /// Returns:
        ///     A pointer to the first node in the list.
        pub fn popFirst(list: &Self) -> ?&Node {
            const first = list.first ?? return null;
            list.remove(first);
            return first;
        }

        /// Allocate a new node.
        ///
        /// Arguments:
        ///     allocator: Dynamic memory allocator.
        ///
        /// Returns:
        ///     A pointer to the new node.
        pub fn allocateNode(list: &Self, allocator: &Allocator) -> %&Node {
            return allocator.create(Node);
        }

        /// Deallocate a node.
        ///
        /// Arguments:
        ///     node: Pointer to the node to deallocate.
        ///     allocator: Dynamic memory allocator.
        pub fn destroyNode(list: &Self, node: &Node, allocator: &Allocator) {
            allocator.destroy(node);
        }

        /// Allocate and initialize a node and its data.
        ///
        /// Arguments:
        ///     data: The data to put inside the node.
        ///     allocator: Dynamic memory allocator.
        ///
        /// Returns:
        ///     A pointer to the new node.
        pub fn createNode(list: &Self, data: &const T, allocator: &Allocator) -> %&Node {
            var node = try list.allocateNode(allocator);
            *node = Node.init(data);
            return node;
        }
    };
}

test "basic linked list test" {
    const allocator = debug.global_allocator;
    var list = LinkedList(u32).init();

    var one   = list.createNode(1, allocator) catch unreachable;
    var two   = list.createNode(2, allocator) catch unreachable;
    var three = list.createNode(3, allocator) catch unreachable;
    var four  = list.createNode(4, allocator) catch unreachable;
    var five  = list.createNode(5, allocator) catch unreachable;
    defer {
        list.destroyNode(one, allocator);
        list.destroyNode(two, allocator);
        list.destroyNode(three, allocator);
        list.destroyNode(four, allocator);
        list.destroyNode(five, allocator);
    }

    list.append(two);               // {2}
    list.append(five);              // {2, 5}
    list.prepend(one);              // {1, 2, 5}
    list.insertBefore(five, four);  // {1, 2, 4, 5}
    list.insertAfter(two, three);   // {1, 2, 3, 4, 5}

    // Traverse forwards.
    {
        var it = list.first;
        var index: u32 = 1;
        while (it) |node| : (it = node.next) {
            assert(node.data == index);
            index += 1;
        }
    }

    // Traverse backwards.
    {
        var it = list.last;
        var index: u32 = 1;
        while (it) |node| : (it = node.prev) {
            assert(node.data == (6 - index));
            index += 1;
        }
    }

    var first = list.popFirst();    // {2, 3, 4, 5}
    var last  = list.pop();         // {2, 3, 4}
    list.remove(three);             // {2, 4}

    assert ((??list.first).data == 2);
    assert ((??list.last ).data == 4);
    assert (list.len == 2);
}
