//! A doubly-linked list has a pair of pointers to both the head and
//! tail of the list. List elements have pointers to both the previous
//! and next elements in the sequence. The list can be traversed both
//! forward and backward. Some operations that take linear O(n) time
//! with a singly-linked list can be done without traversal in constant
//! O(1) time with a doubly-linked list:
//!
//! * Removing an element.
//! * Inserting a new element before an existing element.
//! * Pushing or popping an element from the end of the list.

const std = @import("std.zig");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const DoublyLinkedList = @This();

first: ?*Node = null,
last: ?*Node = null,

/// This struct contains only the prev and next pointers and not any data
/// payload. The intended usage is to embed it intrusively into another data
/// structure and access the data with `@fieldParentPtr`.
pub const Node = struct {
    prev: ?*Node = null,
    next: ?*Node = null,
};

pub fn insertAfter(list: *DoublyLinkedList, existing_node: *Node, new_node: *Node) void {
    new_node.prev = existing_node;
    if (existing_node.next) |next_node| {
        // Intermediate node.
        new_node.next = next_node;
        next_node.prev = new_node;
    } else {
        // Last element of the list.
        new_node.next = null;
        list.last = new_node;
    }
    existing_node.next = new_node;
}

pub fn insertBefore(list: *DoublyLinkedList, existing_node: *Node, new_node: *Node) void {
    new_node.next = existing_node;
    if (existing_node.prev) |prev_node| {
        // Intermediate node.
        new_node.prev = prev_node;
        prev_node.next = new_node;
    } else {
        // First element of the list.
        new_node.prev = null;
        list.first = new_node;
    }
    existing_node.prev = new_node;
}

/// Concatenate list2 onto the end of list1, removing all entries from the former.
///
/// Arguments:
///     list1: the list to concatenate onto
///     list2: the list to be concatenated
pub fn concatByMoving(list1: *DoublyLinkedList, list2: *DoublyLinkedList) void {
    const l2_first = list2.first orelse return;
    if (list1.last) |l1_last| {
        l1_last.next = list2.first;
        l2_first.prev = list1.last;
    } else {
        // list1 was empty
        list1.first = list2.first;
    }
    list1.last = list2.last;
    list2.first = null;
    list2.last = null;
}

/// Insert a new node at the end of the list.
///
/// Arguments:
///     new_node: Pointer to the new node to insert.
pub fn append(list: *DoublyLinkedList, new_node: *Node) void {
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
pub fn prepend(list: *DoublyLinkedList, new_node: *Node) void {
    if (list.first) |first| {
        // Insert before first.
        list.insertBefore(first, new_node);
    } else {
        // Empty list.
        list.first = new_node;
        list.last = new_node;
        new_node.prev = null;
        new_node.next = null;
    }
}

/// Remove a node from the list.
///
/// Arguments:
///     node: Pointer to the node to be removed.
pub fn remove(list: *DoublyLinkedList, node: *Node) void {
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
}

/// Remove and return the last node in the list.
///
/// Returns:
///     A pointer to the last node in the list.
pub fn pop(list: *DoublyLinkedList) ?*Node {
    const last = list.last orelse return null;
    list.remove(last);
    return last;
}

/// Remove and return the first node in the list.
///
/// Returns:
///     A pointer to the first node in the list.
pub fn popFirst(list: *DoublyLinkedList) ?*Node {
    const first = list.first orelse return null;
    list.remove(first);
    return first;
}

/// Iterate over all nodes, returning the count.
///
/// This operation is O(N). Consider tracking the length separately rather than
/// computing it.
pub fn len(list: DoublyLinkedList) usize {
    var count: usize = 0;
    var it: ?*const Node = list.first;
    while (it) |n| : (it = n.next) count += 1;
    return count;
}

test "basics" {
    const L = struct {
        data: u32,
        node: DoublyLinkedList.Node = .{},
    };
    var list: DoublyLinkedList = .{};

    var one: L = .{ .data = 1 };
    var two: L = .{ .data = 2 };
    var three: L = .{ .data = 3 };
    var four: L = .{ .data = 4 };
    var five: L = .{ .data = 5 };

    list.append(&two.node); // {2}
    list.append(&five.node); // {2, 5}
    list.prepend(&one.node); // {1, 2, 5}
    list.insertBefore(&five.node, &four.node); // {1, 2, 4, 5}
    list.insertAfter(&two.node, &three.node); // {1, 2, 3, 4, 5}

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

    // Traverse backwards.
    {
        var it = list.last;
        var index: u32 = 1;
        while (it) |node| : (it = node.prev) {
            const l: *L = @fieldParentPtr("node", node);
            try testing.expect(l.data == (6 - index));
            index += 1;
        }
    }

    _ = list.popFirst(); // {2, 3, 4, 5}
    _ = list.pop(); // {2, 3, 4}
    list.remove(&three.node); // {2, 4}

    try testing.expect(@as(*L, @fieldParentPtr("node", list.first.?)).data == 2);
    try testing.expect(@as(*L, @fieldParentPtr("node", list.last.?)).data == 4);
    try testing.expect(list.len() == 2);
}

test "concatenation" {
    const L = struct {
        data: u32,
        node: DoublyLinkedList.Node = .{},
    };
    var list1: DoublyLinkedList = .{};
    var list2: DoublyLinkedList = .{};

    var one: L = .{ .data = 1 };
    var two: L = .{ .data = 2 };
    var three: L = .{ .data = 3 };
    var four: L = .{ .data = 4 };
    var five: L = .{ .data = 5 };

    list1.append(&one.node);
    list1.append(&two.node);
    list2.append(&three.node);
    list2.append(&four.node);
    list2.append(&five.node);

    list1.concatByMoving(&list2);

    try testing.expect(list1.last == &five.node);
    try testing.expect(list1.len() == 5);
    try testing.expect(list2.first == null);
    try testing.expect(list2.last == null);
    try testing.expect(list2.len() == 0);

    // Traverse forwards.
    {
        var it = list1.first;
        var index: u32 = 1;
        while (it) |node| : (it = node.next) {
            const l: *L = @fieldParentPtr("node", node);
            try testing.expect(l.data == index);
            index += 1;
        }
    }

    // Traverse backwards.
    {
        var it = list1.last;
        var index: u32 = 1;
        while (it) |node| : (it = node.prev) {
            const l: *L = @fieldParentPtr("node", node);
            try testing.expect(l.data == (6 - index));
            index += 1;
        }
    }

    // Swap them back, this verifies that concatenating to an empty list works.
    list2.concatByMoving(&list1);

    // Traverse forwards.
    {
        var it = list2.first;
        var index: u32 = 1;
        while (it) |node| : (it = node.next) {
            const l: *L = @fieldParentPtr("node", node);
            try testing.expect(l.data == index);
            index += 1;
        }
    }

    // Traverse backwards.
    {
        var it = list2.last;
        var index: u32 = 1;
        while (it) |node| : (it = node.prev) {
            const l: *L = @fieldParentPtr("node", node);
            try testing.expect(l.data == (6 - index));
            index += 1;
        }
    }
}
