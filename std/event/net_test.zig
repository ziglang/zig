const std = @import("std");
const assert = std.debug.assert;
const event = @import("event.zig");
//const mem_pool = @import("../mem_pool.zig");

const TestContext = struct {
    server_context: ?&ListenerContext,
    value: usize,
    event: event.NetworkEvent
};

const ContextAllocator = std.MemoryPool(TestContext);

const ListenerContext = struct {
    server_id: usize,
    loop: &event.Loop,
    context_alloc: ContextAllocator
};

fn read_handler(bytes: &const []const u8, context: &TestContext) -> void {
    const res = context.event.write(bytes) %% |err| {
        std.debug.warn("failed to write response: {}\n", err);
        return;
    };
}

fn disconn_handler(context: &TestContext) -> void {
    std.debug.warn("connection closed\n");
    var listener_context = context.server_context ?? unreachable;

    listener_context.context_alloc.free(context);
}

fn conn_handler(md: &const event.EventMd, context: &ListenerContext) -> %void {
    var event_closure = %return context.context_alloc.alloc();
    event_closure.server_context = context;
    event_closure.event = %return event.NetworkEvent.init(md, event_closure,
        &read_handler, &disconn_handler);
    event_closure.event.register(context.loop)
}

test "listen" {
    var loop = %%event.Loop.init();

    var listener_context = ListenerContext {
        .server_id = 1,
        .loop = &loop,
        .context_alloc = %%ContextAllocator.init(2)
    };

    var listener = event.StreamListener.init(&listener_context, &conn_handler);
    %%listener.listen_tcp("localhost", 12345);
    %%listener.register(&loop);

    %%loop.run();
}
