/// Many reader, many writer, non-allocating, thread-safe, lock-free
pub fn Stack(comptime T: type) type {
    return struct {
        root: ?&Node,

        pub const Self = this;

        pub const Node = struct {
            next: ?&Node,
            data: T,
        };

        pub fn init() Self {
            return Self {
                .root = null,
            };
        }

        /// push operation, but only if you are the first item in the stack. if you did not succeed in
        /// being the first item in the stack, returns the other item that was there.
        pub fn pushFirst(self: &Self, node: &Node) ?&Node {
            node.next = null;
            return @cmpxchgStrong(?&Node, &self.root, null, node, AtomicOrder.AcqRel, AtomicOrder.AcqRel);
        }

        pub fn push(self: &Self, node: &Node) void {
            var root = @atomicLoad(?&Node, &self.root, AtomicOrder.Acquire);
            while (true) {
                node.next = root;
                root = @cmpxchgWeak(?&Node, &self.root, root, node, AtomicOrder.Release, AtomicOrder.Acquire) ?? break;
            }
        }

        pub fn pop(self: &Self) ?&Node {
            var root = @atomicLoad(?&Node, &self.root, AtomicOrder.Acquire);
            while (true) {
                root = @cmpxchgWeak(?&Node, &self.root, root, (root ?? return null).next, AtomicOrder.Release, AtomicOrder.Acquire) ?? return root;
            }
        }

        pub fn isEmpty(self: &Self) bool {
            return @atomicLoad(?&Node, &self.root, AtomicOrder.Relaxed) == null;
        }
    };
}
