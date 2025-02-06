// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <sys/ioctl.h>

#include <errno.h>
#include <stdarg.h>

#include <wasi/api.h>
#ifdef __wasilibc_use_wasip2
#include <wasi/descriptor_table.h>
#endif

int ioctl(int fildes, int request, ...) {
#ifdef __wasilibc_use_wasip2
	descriptor_table_entry_t *entry;
	if (descriptor_table_get_ref(fildes, &entry)) {
		switch (entry->tag) {
		case DESCRIPTOR_TABLE_ENTRY_TCP_SOCKET: {
			tcp_socket_t *socket = &entry->tcp_socket;
			switch (request) {
			case FIONBIO: {
				va_list ap;
				va_start(ap, request);
				socket->blocking = *va_arg(ap, const int *) ==
						   0;
				va_end(ap);

				return 0;
			}

			default:
				// TODO wasi-sockets: anything else we should support?
				errno = EINVAL;
				return -1;
			}
		}

		case DESCRIPTOR_TABLE_ENTRY_UDP_SOCKET: {
			udp_socket_t *socket = &entry->udp_socket;
			switch (request) {
			case FIONBIO: {
				va_list ap;
				va_start(ap, request);
				socket->blocking = *va_arg(ap, const int *) ==
						   0;
				va_end(ap);

				return 0;
			}

			default:
				// TODO wasi-sockets: anything else we should support?
				errno = EINVAL;
				return -1;
			}
		}

		default:
			errno = ENOPROTOOPT;
			return -1;
		}
	}
#endif // __wasilibc_use_wasip2

  switch (request) {
    case FIONREAD: {
      // Poll the file descriptor to determine how many bytes can be read.
      __wasi_subscription_t subscriptions[2] = {
          {
              .u.tag = __WASI_EVENTTYPE_FD_READ,
              .u.u.fd_read.file_descriptor = fildes,
          },
          {
              .u.tag = __WASI_EVENTTYPE_CLOCK,
              .u.u.clock.id = __WASI_CLOCKID_MONOTONIC,
          },
      };
      __wasi_event_t events[__arraycount(subscriptions)];
      size_t nevents;
      __wasi_errno_t error = __wasi_poll_oneoff(
          subscriptions, events, __arraycount(subscriptions), &nevents);
      if (error != 0) {
        errno = error;
        return -1;
      }

      // Location where result should be written.
      va_list ap;
      va_start(ap, request);
      int *result = va_arg(ap, int *);
      va_end(ap);

      // Extract number of bytes for reading from poll results.
      for (size_t i = 0; i < nevents; ++i) {
        __wasi_event_t *event = &events[i];
        if (event->error != 0) {
          errno = event->error;
          return -1;
        }
        if (event->type == __WASI_EVENTTYPE_FD_READ) {
          *result = event->fd_readwrite.nbytes;
          return 0;
        }
      }

      // No data available for reading.
      *result = 0;
      return 0;
    }
    case FIONBIO: {
      // Obtain the current file descriptor flags.
      __wasi_fdstat_t fds;
      __wasi_errno_t error = __wasi_fd_fdstat_get(fildes, &fds);
      if (error != 0) {
        errno = error;
        return -1;
      }

      // Toggle the non-blocking flag based on the argument.
      va_list ap;
      va_start(ap, request);
      if (*va_arg(ap, const int *) != 0)
        fds.fs_flags |= __WASI_FDFLAGS_NONBLOCK;
      else
        fds.fs_flags &= ~__WASI_FDFLAGS_NONBLOCK;
      va_end(ap);

      // Update the file descriptor flags.
      error = __wasi_fd_fdstat_set_flags(fildes, fds.fs_flags);
      if (error != 0) {
        errno = error;
        return -1;
      }
      return 0;
    }
    default:
      // Invalid request.
      errno = EINVAL;
      return -1;
  }
}
