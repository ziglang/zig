#ifndef __wasi_sockets_utils_h
#define __wasi_sockets_utils_h

#include <netinet/in.h>

#include <wasi/descriptor_table.h>

typedef struct {
	enum {
		OUTPUT_SOCKADDR_NULL,
		OUTPUT_SOCKADDR_V4,
		OUTPUT_SOCKADDR_V6,
	} tag;
	union {
		struct {
			int dummy;
		} null;
		struct {
			struct sockaddr_in *addr;
			socklen_t *addrlen;
		} v4;
		struct {
			struct sockaddr_in6 *addr;
			socklen_t *addrlen;
		} v6;
	};
} output_sockaddr_t;

network_borrow_network_t __wasi_sockets_utils__borrow_network();
int __wasi_sockets_utils__map_error(network_error_code_t wasi_error);
bool __wasi_sockets_utils__parse_address(
	network_ip_address_family_t expected_family,
	const struct sockaddr *address, socklen_t len,
	network_ip_socket_address_t *result, int *error);
bool __wasi_sockets_utils__output_addr_validate(
	network_ip_address_family_t expected_family, struct sockaddr *addr,
	socklen_t *addrlen, output_sockaddr_t *result);
void __wasi_sockets_utils__output_addr_write(
	const network_ip_socket_address_t input, output_sockaddr_t *output);
int __wasi_sockets_utils__posix_family(network_ip_address_family_t wasi_family);
network_ip_socket_address_t
__wasi_sockets_utils__any_addr(network_ip_address_family_t family);
int __wasi_sockets_utils__tcp_bind(tcp_socket_t *socket,
				   network_ip_socket_address_t *address);
int __wasi_sockets_utils__udp_bind(udp_socket_t *socket,
				   network_ip_socket_address_t *address);
bool __wasi_sockets_utils__stream(udp_socket_t *socket,
				  network_ip_socket_address_t *remote_address,
				  udp_socket_streams_t *result,
				  network_error_code_t *error);
void __wasi_sockets_utils__drop_streams(udp_socket_streams_t streams);

#endif
