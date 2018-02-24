const std = @import("std");
const warn = std.debug.warn;
const bufPrint = std.fmt.bufPrint;

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
    while (i < server.active_conns.len) : (i += 1) {
        if (server.active_conns[i] == null) {
            server.active_conns[i] = closure;
            return;
        }
    }

    unreachable
}

fn read_handler(bytes: &const []const u8, server: &ChatServer, closure: &ChatConn) -> void {
    const BUF_SIZE: usize = 4096;
    const buf_one = []u8 { 0 };
    var buf: [BUF_SIZE]u8 = buf_one ** BUF_SIZE;
    const msg = bufPrint(buf[0..BUF_SIZE], "{} said: {}", closure.id, *bytes);

    for (server.active_conns) |*c| {
        var conn = *c ?? continue;

        // don't echo message back to user
        if (conn.id == closure.id) {
            continue;
        }

        var ev = std.SimpleServer(ChatServer, ChatConn).get_event(conn);

        const w = ev.write(&msg) %% |err| {
            warn("failed to send message to session {}\n", conn.id);
            continue;
        };
    }
}

fn disconn_handler(server: &ChatServer, closure: &ChatConn) -> void {
    for (server.active_conns) |*c| {
        var conn = *c ?? continue;
        if (conn.id == closure.id) {
            *c = null;
            return;
        }
    }
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

    server.start("localhost", 12345) %% |err| {
        warn("failed to start server: {}\n", err);
        return err;
    };

    loop.run()
}
