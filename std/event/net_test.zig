const std = @import("std");
const assert = std.debug.assert;
const event = @import("event.zig");
//const net = @import("event_net.zig");

const TestContext = struct {
    value: usize
};

const ContextAllocator = struct {
    contexts: [16]TestContext,
    index: usize,

    const Self = this;

    fn init() -> ContextAllocator {
        const read_context = TestContext { .value = 42 };
        ContextAllocator {
            .contexts = []TestContext { read_context } ** 16,
            .index = 0
        }
    }

    fn alloc(allocator: &Self) -> %&TestContext {
        if (allocator.index >=allocator.contexts.len) {
            return error.OutOfMemory;
        }

        const res = &allocator.contexts[allocator.index];
        allocator.index += 1;
        res
    }
};

const ListenerContext = struct {
    server_id: usize,
    context_alloc: ContextAllocator
};

fn read_handler(bytes: &const []u8, context: &TestContext) -> void {
    std.debug.warn("reading {} bytes from context {}\n", bytes.len, context.value);
}

fn conn_handler(context: &ListenerContext) -> %&TestContext {
    context.context_alloc.alloc()
}

test "listen" {
    var listener_context = ListenerContext {
        .server_id = 1,
        .context_alloc = ContextAllocator.init()
    };

    var loop = %%event.Loop.init();
    var listener = event.StreamListener.init(&listener_context,
        TestContext, &conn_handler, &read_handler);
    %%listener.listen_tcp("localhost", 12345);
    %%listener.register(&loop);

    %%loop.run();
}
