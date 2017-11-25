const ev = @import("event.zig");
const mp = @import("../memory_pool.zig");

pub fn SimpleServer(comptime TServerClosure: type,
                comptime TConnClosure: type) -> type {

    const ConnClosure = struct {
        event: ev.NetworkEvent,
        server: &SimpleServer,
        data: TConnClosure
    };

    const ConnHandler = &const fn(&TServerClosure, &TConnClosure) -> void;
    const ReadHandler = &const fn(&const []const u8, &TServerClosure, &TConnClosure) -> void;
    const DisconnHandler = &const fn(&TServerClosure, &TConnClosure) -> void;

    struct {
        loop: &ev.Loop,
        listener: ev.StreamListener,
        closure_alloc: mp.MemoryPool(ConnClosure),
        data: TServerClosure,
        conn_handler: &ConnHandler,
        read_handler: &ReadHandler,
        disconn_handler: &DisconnHandler,

        const Self = this;

        fn disconn_handler(closure: &ConnClosure) -> void {
            (*closure.server.disconn_handler)(&closure.server.data,
                &closure.data);
            closure.server.closure_alloc.free(closure);
        }

        fn read_handler_wrapper(bytes: &const []const u8, closure: &ConnClosure)
                -> void {
            (*closure.server.read_handler)(bytes, &closure.server.data,
                &closure.data)
        }

        fn conn_handler(md: &const ev.EventMd, server: &Self) -> %void {
            var conn_closure = %return server.closure_alloc.alloc();
            conn_closure.server = server;
            conn_closure.event = %return ev.NetworkEvent.init(md, conn_closure,
                &read_handler_wrapper, &disconn_handler);

            (*server.conn_handler)(&server.data, &conn_closure.data);

            conn_closure.event.register(server.loop)
        }

        pub fn init(loop: &ev.Loop,
                    server: &const TServerClosure,
                    max_conn: usize,
                    conn_handler: &ConnHandler,
                    read_handler: &ReadHandler,
                    disconn_handler: &DisconnHandler) -> %Self {
            Self {
                .loop = loop,
                .listener = ev.StreamListener.init(&res, &conn_handler),
                .closure_alloc =
                    %return mp.MemoryPool(ConnClosure).init(max_conn),
                .data = *server,
                .conn_handler = conn_handler,
                .read_handler = read_handler,
                .disconn_handler = disconn_handler
            }
        }

        pub fn start(server: &Self, hostname: []const u8, port: u16) -> %void {
            %return server.listener.listen_tcp(hostname, port);
            server.listener.register(server.loop)
        }

        pub fn get_event(closure: &TConnClosure) -> &ev.NetworkEvent {
            var wrapper = @fieldParentPtr(ConnClosure, "data", closure);
            &wrapper.event
        }
    }
}
