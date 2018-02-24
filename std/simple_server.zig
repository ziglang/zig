const ev = @import("event/event.zig");
const mp = @import("mem_pool.zig");
const warn = @import("debug.zig").warn;

pub fn SimpleServer(comptime TServerClosure: type,
                comptime TConnClosure: type) -> type {
    struct {
        closure: ServerClosure,

        const Self = this;

        const ConnClosure = struct {
            event: ev.NetworkEvent,
            server: &ServerClosure,
            data: TConnClosure
        };

        const ServerClosure = struct {
            loop: &ev.Loop,
            listener: ev.StreamListener,
            closure_alloc: mp.MemoryPool(ConnClosure),
            data: TServerClosure,
            conn_handler: &const ConnHandler,
            read_handler: &const ReadHandler,
            disconn_handler: &const DisconnHandler
        };

        const ConnHandler = fn(&TServerClosure, &TConnClosure) -> void;
        const ReadHandler =
            fn(&const []const u8, &TServerClosure, &TConnClosure) -> void;
        const DisconnHandler = fn(&TServerClosure, &TConnClosure) -> void;

        fn disconn_handler_wrapper(closure: &ConnClosure) -> void {
            (*closure.server.disconn_handler)(&closure.server.data,
                &closure.data);
            closure.server.closure_alloc.free(closure);
        }

        fn read_handler_wrapper(bytes: &const []const u8, closure: &ConnClosure)
                -> void {
            (*closure.server.read_handler)(bytes, &closure.server.data,
                &closure.data)
        }

        fn conn_handler_wrapper(md: &const ev.EventMd, server: &Self) -> %void {
            var conn_closure = server.closure.closure_alloc.alloc() %% |err| {
                warn("failed to create new connection closure\n");
                return err;
            };
            conn_closure.server = &server.closure;
            conn_closure.event = ev.NetworkEvent.init(md, conn_closure,
                &read_handler_wrapper, &disconn_handler_wrapper) %% |err| {
                warn("failed to create network event for connection {}\n",
                    md.fd);
                return err;
            };

            (*server.closure.conn_handler)(&server.closure.data,
                &conn_closure.data);

            conn_closure.event.register(server.closure.loop) %% |err| {
                warn("failed to register new connection\n");
                return err;
            };
        }

        pub fn init(loop: &ev.Loop,
                    server: &const TServerClosure,
                    max_conn: usize,
                    conn_handler: &const ConnHandler,
                    read_handler: &const ReadHandler,
                    disconn_handler: &const DisconnHandler) -> %Self {
            Self {
                .closure = ServerClosure {
                    .loop = loop,
                    .listener = undefined,
                    .closure_alloc =
                        %return mp.MemoryPool(ConnClosure).init(max_conn),
                    .data = *server,
                    .conn_handler = conn_handler,
                    .read_handler = read_handler,
                    .disconn_handler = disconn_handler
                }
            }
        }

        pub fn start(server: &Self, hostname: []const u8, port: u16) -> %void {
            server.closure.listener =
                ev.StreamListener.init(server, &conn_handler_wrapper);
            %return server.closure.listener.listen_tcp(hostname, port);
            server.closure.listener.register(server.closure.loop)
        }

        pub fn get_event(closure: &TConnClosure) -> &ev.NetworkEvent {
            var wrapper = @fieldParentPtr(ConnClosure, "data", closure);
            &wrapper.event
        }
    }
}
