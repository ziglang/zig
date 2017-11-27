const std = @import("std");
const warn = std.debug.warn;

const MAX_CONN: usize = 128;

const ChatConn = struct {
    id: usize
};

const ChatServer = struct {
    active_conns: [MAX_CONN]?&ChatConn,
    id_counter: usize
};

fn conn_handler(server: &ChatServer, closure: &ChatConn) -> void {
    closure.id = server.id_counter;
    server.id_counter += 1;

    var i: usize = 0;
    while (i < MAX_CONN) : (i += 1) {
        if (server.active_conns[i] == null) {
            server.active_conns[i] = closure;
        }
    }
}

fn read_handler(bytes: &const []const u8, server: &ChatServer, closure: &ChatConn) -> void {
    warn("received message \"{}\"\n", bytes);
    for (server.active_conns) |*c| {
        var conn = *c ?? continue;
        var ev = std.SimpleServer(ChatServer, ChatConn).get_event(closure);
        // XXX: once snprintf or similar is available, prefix messages with
        // "user X said: "

        const w = ev.write(bytes) %% |err| {
            warn("failed to send message to session {}\n", conn.id);
            return;
        };
    }
}

fn disconn_handler(server: &ChatServer, closure: &ChatConn) -> void {
    // XXX: remove connection from active_conns
}

pub fn main() -> %void {
    var loop = %return std.event.Loop.init();
    var closure = ChatServer {
        .active_conns = []?&ChatConn { null } ** MAX_CONN,
        .id_counter = 0
    };

    var server = %return std.SimpleServer(ChatServer, ChatConn).init(
        &loop, &closure, MAX_CONN, &conn_handler, &read_handler,
        &disconn_handler);

    %return server.start("localhost", 12345);

    loop.run()
}
