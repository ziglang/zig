/// Many reader, many writer, non-allocating, thread-safe, lock-free
pub fn Queue(comptime T: type) type {
    return struct {
        head: &Node,
        tail: &Node,
        root: Node,

        pub const Self = this;

        pub const Node = struct {
            next: ?&Node,
            data: T,
        };

        // TODO: well defined copy elision
        pub fn init(self: &Self) void {
            self.root.next = null;
            self.head = &self.root;
            self.tail = &self.root;
        }

        pub fn put(self: &Self, node: &Node) void {
            node.next = null;

            const tail = @atomicRmw(&Node, &self.tail, AtomicRmwOp.Xchg, node, AtomicOrder.SeqCst);
            _ = @atomicRmw(?&Node, &tail.next, AtomicRmwOp.Xchg, node, AtomicOrder.SeqCst);
        }

        pub fn get(self: &Self) ?&Node {
            var head = @atomicLoad(&Node, &self.head, AtomicOrder.Acquire);
            while (true) {
                const node = head.next ?? return null;
                head = @cmpxchgWeak(&Node, &self.head, head, node, AtomicOrder.Release, AtomicOrder.Acquire) ?? return node;
            }
        }
    };
}
