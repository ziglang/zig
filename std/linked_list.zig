const debug = @import("debug.zig");
const assert = debug.assert;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;

/// Generic doubly linked list.
pub fn LinkedList(comptime T: type) -> type {
    struct {
        const List = this;

        /// Node inside the linked list wrapping the actual data.
        pub const Node = struct {
            prev: ?&Node,
            next: ?&Node,
            data: T,
        };

        first: ?&Node,
        last:  ?&Node,
        len:   usize,
        allocator: &Allocator,

        /// Initialize a linked list.
        ///
        /// Arguments:
        ///     allocator: Dynamic memory allocator.
        ///
        /// Returns:
        ///     An empty linked list.
        pub fn init(allocator: &Allocator) -> List {
            List {
                .first = null,
                .last  = null,
                .len   = 0,
                .allocator = allocator,
            }
        }

        /// Insert a new node after an existing one.
        ///
        /// Arguments:
        ///     node: Pointer to a node in the list.
        ///     new_node: Pointer to the new node to insert.
        pub fn insertAfter(list: &List, node: &Node, new_node: &Node) {
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
        pub fn insertBefore(list: &List, node: &Node, new_node: &Node) {
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
        pub fn append(list: &List, new_node: &Node) {
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
        pub fn prepend(list: &List, new_node: &Node) {
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
        pub fn remove(list: &List, node: &Node) {
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
        pub fn pop(list: &List) -> ?&Node {
            const last = list.last ?? return null;
            list.remove(last);
            return last;
        }

        /// Remove and return the first node in the list.
        ///
        /// Returns:
        ///     A pointer to the first node in the list.
        pub fn popFirst(list: &List) -> ?&Node {
            const first = list.first ?? return null;
            list.remove(first);
            return first;
        }

        /// Allocate a new node.
        ///
        /// Returns:
        ///     A pointer to the new node.
        pub fn allocateNode(list: &List) -> %&Node {
            list.allocator.create(Node)
        }

        /// Deallocate a node.
        ///
        /// Arguments:
        ///     node: Pointer to the node to deallocate.
        pub fn destroyNode(list: &List, node: &Node) {
            list.allocator.destroy(node);
        }

        /// Allocate and initialize a node and its data.
        ///
        /// Arguments:
        ///     data: The data to put inside the node.
        ///
        /// Returns:
        ///     A pointer to the new node.
        pub fn createNode(list: &List, data: &const T) -> %&Node {
            var node = %return list.allocateNode();
            *node = Node {
                .prev = null,
                .next = null,
                .data = *data,
            };
            return node;
        }
    }
}

test "basic linked list test" {
    var list = LinkedList(u32).init(&debug.global_allocator);

    var one   = %%list.createNode(1);
    var two   = %%list.createNode(2);
    var three = %%list.createNode(3);
    var four  = %%list.createNode(4);
    var five  = %%list.createNode(5);
    defer {
        list.destroyNode(one);
        list.destroyNode(two);
        list.destroyNode(three);
        list.destroyNode(four);
        list.destroyNode(five);
    }

    list.append(two);               // {2}
    list.append(five);              // {2, 5}
    list.prepend(one);              // {1, 2, 5}
    list.insertBefore(five, four);  // {1, 2, 4, 5}
    list.insertAfter(two, three);   // {1, 2, 3, 4, 5}

    // traverse forwards
    {
        var it = list.first;
        var index: u32 = 1;
        while (it) |node| : (it = node.next) {
            assert(node.data == index);
            index += 1;
        }
    }

    // traverse backwards
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
