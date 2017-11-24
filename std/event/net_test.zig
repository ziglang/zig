const std = @import("std");
const assert = std.debug.assert;
const event = @import("event.zig");
//const net = @import("event_net.zig");

const TestContext = struct {
    value: usize,
    event: event.NetworkEvent
};

const ContextAllocator = struct {
    contexts: [16]TestContext,
    index: usize,

    const Self = this;

    fn init() -> ContextAllocator {
        const read_context = TestContext {
            .value = 42,
            .event = undefined
        };
        ContextAllocator {
            .contexts = []TestContext { read_context } ** 16,
            .index = 0
        }
    }

    fn alloc(allocator: &Self) -> %&TestContext {
        if (allocator.index >= allocator.contexts.len) {
            return error.OutOfMemory;
        }

        const res = &allocator.contexts[allocator.index];
        allocator.index += 1;
        res
    }
};

const ListenerContext = struct {
    server_id: usize,
    loop: &event.Loop,
    context_alloc: &ContextAllocator
};

fn read_handler(bytes: &const []const u8, context: &TestContext) -> void {
    std.debug.warn("reading {} bytes from context {}\n", bytes.len, context.value);
    std.debug.warn("client sent message \"{}\"\n", *bytes);

    const res = context.event.write(bytes) %% |err| {
        std.debug.warn("failed to write response: {}\n", err);
        return;
    };

    std.debug.warn("wrote response of {} bytes\n", res);
}

fn conn_handler(md: &const event.EventMd, context: &ListenerContext) -> %void {
    var event_closure = %return context.context_alloc.alloc();
    event_closure.event = %return event.NetworkEvent.init(md, event_closure, &read_handler);
    event_closure.event.register(context.loop)
}

test "listen" {
    var loop = %%event.Loop.init();

    var allocator = ContextAllocator.init();

    var listener_context = ListenerContext {
        .server_id = 1,
        .loop = &loop,
        .context_alloc = &allocator
    };

    var listener = event.StreamListener.init(&listener_context, &conn_handler);
    %%listener.listen_tcp("localhost", 12345);
    %%listener.register(&loop);

    %%loop.run();
}
