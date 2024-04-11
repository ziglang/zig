#include <wasi/api.h>
#include <wasi/libc.h>
#include <errno.h>
#include <unistd.h>

int __wasilibc_fd_renumber(int fd, int newfd) {
    __wasi_errno_t error = __wasi_fd_renumber(fd, newfd);
    if (error != 0) {
        errno = error;
        return -1;
    }
    return 0;
}

#ifdef __wasilibc_use_wasip2
#include <wasi/descriptor_table.h>

void drop_tcp_socket(tcp_socket_t socket) {
    switch (socket.state.tag) {
    case TCP_SOCKET_STATE_UNBOUND:
    case TCP_SOCKET_STATE_BOUND:
    case TCP_SOCKET_STATE_CONNECTING:
    case TCP_SOCKET_STATE_LISTENING:
    case TCP_SOCKET_STATE_CONNECT_FAILED:
        // No additional resources to drop.
        break;
    case TCP_SOCKET_STATE_CONNECTED: {
        tcp_socket_state_connected_t connection = socket.state.connected;

        poll_pollable_drop_own(connection.input_pollable);
        poll_pollable_drop_own(connection.output_pollable);
        streams_input_stream_drop_own(connection.input);
        streams_output_stream_drop_own(connection.output);
        break;
    }
    default: /* unreachable */ abort();
    }

    poll_pollable_drop_own(socket.socket_pollable);
    tcp_tcp_socket_drop_own(socket.socket);
}

void drop_udp_socket_streams(udp_socket_streams_t streams) {
    poll_pollable_drop_own(streams.incoming_pollable);
    poll_pollable_drop_own(streams.outgoing_pollable);
    udp_incoming_datagram_stream_drop_own(streams.incoming);
    udp_outgoing_datagram_stream_drop_own(streams.outgoing);
}

void drop_udp_socket(udp_socket_t socket) {
    switch (socket.state.tag) {
    case UDP_SOCKET_STATE_UNBOUND:
    case UDP_SOCKET_STATE_BOUND_NOSTREAMS:
        // No additional resources to drop.
        break;
    case UDP_SOCKET_STATE_BOUND_STREAMING:
        drop_udp_socket_streams(socket.state.bound_streaming.streams);
        break;
    case UDP_SOCKET_STATE_CONNECTED: {
        drop_udp_socket_streams(socket.state.connected.streams);
        break;
    }
    default: /* unreachable */ abort();
    }

    poll_pollable_drop_own(socket.socket_pollable);
    udp_udp_socket_drop_own(socket.socket);
}
#endif // __wasilibc_use_wasip2

int close(int fd) {
    // Scan the preopen fds before making any changes.
    __wasilibc_populate_preopens();

#ifdef __wasilibc_use_wasip2
    descriptor_table_entry_t entry;
    if (descriptor_table_remove(fd, &entry)) {

        switch (entry.tag)
        {
        case DESCRIPTOR_TABLE_ENTRY_TCP_SOCKET:
            drop_tcp_socket(entry.tcp_socket);
            break;
        case DESCRIPTOR_TABLE_ENTRY_UDP_SOCKET:
            drop_udp_socket(entry.udp_socket);
            break;
        default: /* unreachable */ abort();
        }
        
        return 0;
    }
#endif // __wasilibc_use_wasip2
    
    __wasi_errno_t error = __wasi_fd_close(fd);
    if (error != 0) {
        errno = error;
        return -1;
    }

    return 0;
}

weak void __wasilibc_populate_preopens(void) {
    // This version does nothing. It may be overridden by a version which does
    // something if `__wasilibc_find_abspath` or `__wasilibc_find_relpath` are
    // used.
}
