const std = @import("std");
const warn = std.debug.warn;

const MAX_CONN: usize = 128;

const ChatConn = struct {
    id: usize
};

const ChatServer = struct {
    active_conns: [MAX_CONN]&ChatConn,
    n_active: usize,
    id_counter: usize
};

fn conn_handler(server: &ChatServer, closure: &ChatConn) -> void {
    closure.id = server.id_counter;
    server.id_counter += 1;

    server.active_conns[server.n_active] = closure;
    server.n_active += 1;
}

fn read_handler(bytes: &const []const u8, server: &ChatServer, closure: &ChatConn) -> void {
    for (server.active_conns) |*conn| {
        var event = SimpleServer(ChatServer, ChatConn).get_event(closure);
        // XXX: once snprintf or similar is available, prefix messages with
        // "user X said: "

        event.write(bytes) %% |err| {
            warn("failed to send message to session {}\n", conn.id);
        };
    }
}

fn disconn_handler(server: &ChatServer, closure: &ChatConn) -> void {
    // XXX: remove connection from active_conns
}

pub fn main(args: [][]u8) -> %void {
    var loop = %return std.event.Loop.init();
    const conn_undef: ChatConn = undefined;
    var closure = ChatServer {
        .active_conns = []&ChatConn { conn_undef } ** MAX_CONN,
        .n_active = 0,
        .id_counter = 0
    };

    var server = %return std.SimpleServer(ChatServer, ChatConn).init(
        &loop, &closure, MAX_CONN, &read_handler, &disconn_handler);

    loop.run()
}
