const std = @import("std");
const assert = std.debug.assert;
const event = @import("event.zig");
const net = @import("event_net.zig");

const ListenerContext = struct {
    server_id: usize
};

const TestContext = struct {
    value: usize
};

fn read_handler(bytes: &const []u8, context: &TestContext) -> void {
    std.debug.warn("reading {} bytes from context {}\n", bytes.len, context.value);
}

fn conn_handler(context: &ListenerContext) -> TestContext {
    std.debug.warn("received new connection to server {}\n", context.server_id);
    TestContext {
        .value = 42
    }
}

test "listen" {
    var listener_context = ListenerContext {
        .server_id = 1
    };

    var loop = %%event.Loop.init();
    var listener = net.StreamListener.init(&listener_context,
        TestContext, &conn_handler, &read_handler);
    %%listener.listen_tcp("localhost", 12345);

    while (true) {

    }
}
