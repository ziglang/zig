const ListNode = struct {
    next: ?*const @This() = null,
};

test "copy array of self-referential struct" {
    comptime var nodes = [_]ListNode{ .{}, .{} };
    nodes[0].next = &nodes[1];
    const copy = nodes;
    _ = copy;
}
