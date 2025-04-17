//! A singly-linked list is headed by a single forward pointer. The elements
//! are singly-linked for minimum space and pointer manipulation overhead at
//! the expense of O(n) removal for arbitrary elements. New elements can be
//! added to the list after an existing element or at the head of the list.
//!
//! A singly-linked list may only be traversed in the forward direction.
//!
//! Singly-linked lists are useful under these conditions:
//! * Ability to preallocate elements / requirement of infallibility for
//!   insertion.
//! * Ability to allocate elements intrusively along with other data.
//! * Homogenous elements.

const std = @import("std.zig");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const SinglyLinkedList = @This();

first: ?*Node = null,

/// This struct contains only a next pointer and not any data payload. The
/// intended usage is to embed it intrusively into another data structure and
/// access the data with `@fieldParentPtr`.
pub const Node = struct {
    next: ?*Node = null,

    pub fn insertAfter(node: *Node, new_node: *Node) void {
        new_node.next = node.next;
        node.next = new_node;
    }

    /// Remove the node after the one provided, returning it.
    pub fn removeNext(node: *Node) ?*Node {
        const next_node = node.next orelse return null;
        node.next = next_node.next;
        return next_node;
    }

    /// Iterate over the singly-linked list from this node, until the final
    /// node is found.
    ///
    /// This operation is O(N). Instead of calling this function, consider
    /// using a different data structure.
    pub fn findLast(node: *Node) *Node {
        var it = node;
        while (true) {
            it = it.next orelse return it;
        }
    }

    /// Iterate over each next node, returning the count of all nodes except
    /// the starting one.
    ///
    /// This operation is O(N). Instead of calling this function, consider
    /// using a different data structure.
    pub fn countChildren(node: *const Node) usize {
        var count: usize = 0;
        var it: ?*const Node = node.next;
        while (it) |n| : (it = n.next) {
            count += 1;
        }
        return count;
    }

    /// Reverse the list starting from this node in-place.
    ///
    /// This operation is O(N). Instead of calling this function, consider
    /// using a different data structure.
    pub fn reverse(indirect: *?*Node) void {
        if (indirect.* == null) {
            return;
        }
        var current: *Node = indirect.*.?;
        while (current.next) |next| {
            current.next = next.next;
            next.next = indirect.*;
            indirect.* = next;
        }
    }
};

pub fn prepend(list: *SinglyLinkedList, new_node: *Node) void {
    new_node.next = list.first;
    list.first = new_node;
}

pub fn remove(list: *SinglyLinkedList, node: *Node) void {
    if (list.first == node) {
        list.first = node.next;
    } else {
        var current_elm = list.first.?;
        while (current_elm.next != node) {
            current_elm = current_elm.next.?;
        }
        current_elm.next = node.next;
    }
}

/// Remove and return the first node in the list.
pub fn popFirst(list: *SinglyLinkedList) ?*Node {
    const first = list.first orelse return null;
    list.first = first.next;
    return first;
}

/// Iterate over all nodes, returning the count.
///
/// This operation is O(N). Consider tracking the length separately rather than
/// computing it.
pub fn len(list: SinglyLinkedList) usize {
    if (list.first) |n| {
        return 1 + n.countChildren();
    } else {
        return 0;
    }
}

test "basics" {
    const L = struct {
        data: u32,
        node: SinglyLinkedList.Node = .{},
    };
    var list: SinglyLinkedList = .{};

    try testing.expect(list.len() == 0);

    var one: L = .{ .data = 1 };
    var two: L = .{ .data = 2 };
    var three: L = .{ .data = 3 };
    var four: L = .{ .data = 4 };
    var five: L = .{ .data = 5 };

    list.prepend(&two.node); // {2}
    two.node.insertAfter(&five.node); // {2, 5}
    list.prepend(&one.node); // {1, 2, 5}
    two.node.insertAfter(&three.node); // {1, 2, 3, 5}
    three.node.insertAfter(&four.node); // {1, 2, 3, 4, 5}

    try testing.expect(list.len() == 5);

    // Traverse forwards.
    {
        var it = list.first;
        var index: u32 = 1;
        while (it) |node| : (it = node.next) {
            const l: *L = @fieldParentPtr("node", node);
            try testing.expect(l.data == index);
            index += 1;
        }
    }

    _ = list.popFirst(); // {2, 3, 4, 5}
    _ = list.remove(&five.node); // {2, 3, 4}
    _ = two.node.removeNext(); // {2, 4}

    try testing.expect(@as(*L, @fieldParentPtr("node", list.first.?)).data == 2);
    try testing.expect(@as(*L, @fieldParentPtr("node", list.first.?.next.?)).data == 4);
    try testing.expect(list.first.?.next.?.next == null);

    SinglyLinkedList.Node.reverse(&list.first);

    try testing.expect(@as(*L, @fieldParentPtr("node", list.first.?)).data == 4);
    try testing.expect(@as(*L, @fieldParentPtr("node", list.first.?.next.?)).data == 2);
    try testing.expect(list.first.?.next.?.next == null);
}

/// implements a "simple" intrusive singly linked list with a "data" field alongside
/// "node" field.  This hides @fieldParentPtr complexity and adds type safety for simple
/// cases.
///
/// note that the signatures on the member functions of the generated datastructure take
/// pointers to the payload, not the node.
pub fn Simple(T: type) type {
    return struct {
        first: ?*Node = null,

        pub const Payload = struct {
            data: T,
            node: Node = .{},

            pub fn next(payload: *@This()) ?*Payload {
                return @fieldParentPtr("node", payload.node.next orelse return null);
            }

            pub fn insertAfter(payload: *@This(), new_payload: *Payload) void {
                payload.node.insertAfter(&new_payload.node);
            }
        };

        pub fn prepend(list: *@This(), new_payload: *Payload) void {
            new_payload.node.next = list.first;
            list.first = &new_payload.node;
        }

        pub fn remove(list: *@This(), payload: *Payload) void {
            if (list.first == &payload.node) {
                list.first = payload.node.next;
            } else {
                var current_elm = list.first.?;
                while (current_elm.next != &payload.node) {
                    current_elm = current_elm.next.?;
                }
                current_elm.next = payload.node.next;
            }
        }

        /// Remove and return the first node in the list.
        pub fn popFirst(list: *@This()) ?*Payload {
            const first = list.first orelse return null;
            list.first = first.next;
            return @fieldParentPtr("node", first);
        }

        /// Given a Simple list, returns the payload at position <index>.
        /// If the list does not have that many elements, returns `null`.
        ///
        /// This is a linear search through the list, consider avoiding this
        /// operation, except for index == 0
        pub fn at(list: *@This(), index: usize) ?*Payload {
            var thisnode = list.first orelse return null;
            var ctr: usize = index;
            while (ctr > 0) : (ctr -= 1) {
                thisnode = thisnode.next orelse return null;
            }
            return @fieldParentPtr("node", thisnode);
        }

        // Iterate over all nodes, returning the count.
        ///
        /// This operation is O(N). Consider tracking the length separately rather than
        /// computing it.
        pub fn len(list: @This()) usize {
            if (list.first) |n| {
                return 1 + n.countChildren();
            } else {
                return 0;
            }
        }
    };
}

test "Simple singly linked list" {
    const SimpleList = Simple(u32);
    const L = SimpleList.Payload;

    var list: SimpleList = .{};

    try testing.expect(list.len() == 0);

    var one: L = .{ .data = 1 };
    var two: L = .{ .data = 2 };
    var three: L = .{ .data = 3 };
    var four: L = .{ .data = 4 };
    var five: L = .{ .data = 5 };

    try testing.expect(list.at(0) == null);

    list.prepend(&two); // {2}
    two.node.insertAfter(&five.node); // {2, 5}
    list.prepend(&one); // {1, 2, 5}
    two.insertAfter(&three); // {1, 2, 3, 5}
    three.node.insertAfter(&four.node); // {1, 2, 3, 4, 5}

    try testing.expect(list.len() == 5);

    try testing.expect(list.at(0).?.data == 1);
    try testing.expect(list.at(3).?.data == 4);
    try testing.expect(list.at(7) == null);

    try testing.expect(one.next().?.data == 2);
    try testing.expect(two.next().?.data == 3);
    try testing.expect(three.next().?.data == 4);
    try testing.expect(four.next().?.data == 5);
    try testing.expect(five.next() == null);

    // Traverse forwards.
    {
        var it = list.first;
        var index: u32 = 1;
        while (it) |node| : (it = node.next) {
            const l: *L = @fieldParentPtr("node", node);
            try testing.expect(l.data == index);
            index += 1;
        }
    }

    _ = list.popFirst(); // {2, 3, 4, 5}
    _ = list.remove(&five); // {2, 3, 4}
    _ = two.node.removeNext(); // {2, 4}

    try testing.expect(@as(*L, @fieldParentPtr("node", list.first.?)).data == 2);
    try testing.expect(@as(*L, @fieldParentPtr("node", list.first.?.next.?)).data == 4);
    try testing.expect(list.first.?.next.?.next == null);

    SinglyLinkedList.Node.reverse(&list.first);

    try testing.expect(@as(*L, @fieldParentPtr("node", list.first.?)).data == 4);
    try testing.expect(@as(*L, @fieldParentPtr("node", list.first.?.next.?)).data == 2);
    try testing.expect(list.first.?.next.?.next == null);
}
