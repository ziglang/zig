#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <stdint.h>
#include <string.h>
#include <poll.h>
#include <time.h>
#include <ctype.h>
#include <unistd.h>
#include <errno.h>
#include <pthread.h>
#include "stdio_impl.h"
#include "syscall.h"
#include "lookup.h"

static void cleanup(void *p)
{
	struct pollfd *pfd = p;
	for (int i=0; pfd[i].fd >= -1; i++)
		if (pfd[i].fd >= 0) __syscall(SYS_close, pfd[i].fd);
}

static unsigned long mtime()
{
	struct timespec ts;
	if (clock_gettime(CLOCK_MONOTONIC, &ts) < 0 && errno == ENOSYS)
		clock_gettime(CLOCK_REALTIME, &ts);
	return (unsigned long)ts.tv_sec * 1000
		+ ts.tv_nsec / 1000000;
}

static int start_tcp(struct pollfd *pfd, int family, const void *sa, socklen_t sl, const unsigned char *q, int ql)
{
	struct msghdr mh = {
		.msg_name = (void *)sa,
		.msg_namelen = sl,
		.msg_iovlen = 2,
		.msg_iov = (struct iovec [2]){
			{ .iov_base = (uint8_t[]){ ql>>8, ql }, .iov_len = 2 },
			{ .iov_base = (void *)q, .iov_len = ql } }
	};
	int r;
	int fd = socket(family, SOCK_STREAM|SOCK_CLOEXEC|SOCK_NONBLOCK, 0);
	pfd->fd = fd;
	pfd->events = POLLOUT;
	if (!setsockopt(fd, IPPROTO_TCP, TCP_FASTOPEN_CONNECT,
	    &(int){1}, sizeof(int))) {
		r = sendmsg(fd, &mh, MSG_FASTOPEN|MSG_NOSIGNAL);
		if (r == ql+2) pfd->events = POLLIN;
		if (r >= 0) return r;
		if (errno == EINPROGRESS) return 0;
	}
	r = connect(fd, sa, sl);
	if (!r || errno == EINPROGRESS) return 0;
	close(fd);
	pfd->fd = -1;
	return -1;
}

static void step_mh(struct msghdr *mh, size_t n)
{
	/* Adjust iovec in msghdr to skip first n bytes. */
	while (mh->msg_iovlen && n >= mh->msg_iov->iov_len) {
		n -= mh->msg_iov->iov_len;
		mh->msg_iov++;
		mh->msg_iovlen--;
	}
	if (!mh->msg_iovlen) return;
	mh->msg_iov->iov_base = (char *)mh->msg_iov->iov_base + n;
	mh->msg_iov->iov_len -= n;
}

/* Internal contract for __res_msend[_rc]: asize must be >=512, nqueries
 * must be sufficiently small to be safe as VLA size. In practice it's
 * either 1 or 2, anyway. */

int __res_msend_rc(int nqueries, const unsigned char *const *queries,
	const int *qlens, unsigned char *const *answers, int *alens, int asize,
	const struct resolvconf *conf)
{
	int fd;
	int timeout, attempts, retry_interval, servfail_retry;
	union {
		struct sockaddr_in sin;
		struct sockaddr_in6 sin6;
	} sa = {0}, ns[MAXNS] = {{0}};
	socklen_t sl = sizeof sa.sin;
	int nns = 0;
	int family = AF_INET;
	int rlen;
	int next;
	int i, j;
	int cs;
	struct pollfd pfd[nqueries+2];
	int qpos[nqueries], apos[nqueries];
	unsigned char alen_buf[nqueries][2];
	int r;
	unsigned long t0, t1, t2;

	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);

	timeout = 1000*conf->timeout;
	attempts = conf->attempts;

	for (nns=0; nns<conf->nns; nns++) {
		const struct address *iplit = &conf->ns[nns];
		if (iplit->family == AF_INET) {
			memcpy(&ns[nns].sin.sin_addr, iplit->addr, 4);
			ns[nns].sin.sin_port = htons(53);
			ns[nns].sin.sin_family = AF_INET;
		} else {
			sl = sizeof sa.sin6;
			memcpy(&ns[nns].sin6.sin6_addr, iplit->addr, 16);
			ns[nns].sin6.sin6_port = htons(53);
			ns[nns].sin6.sin6_scope_id = iplit->scopeid;
			ns[nns].sin6.sin6_family = family = AF_INET6;
		}
	}

	/* Get local address and open/bind a socket */
	fd = socket(family, SOCK_DGRAM|SOCK_CLOEXEC|SOCK_NONBLOCK, 0);

	/* Handle case where system lacks IPv6 support */
	if (fd < 0 && family == AF_INET6 && errno == EAFNOSUPPORT) {
		for (i=0; i<nns && conf->ns[nns].family == AF_INET6; i++);
		if (i==nns) {
			pthread_setcancelstate(cs, 0);
			return -1;
		}
		fd = socket(AF_INET, SOCK_DGRAM|SOCK_CLOEXEC|SOCK_NONBLOCK, 0);
		family = AF_INET;
		sl = sizeof sa.sin;
	}

	/* Convert any IPv4 addresses in a mixed environment to v4-mapped */
	if (fd >= 0 && family == AF_INET6) {
		setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, &(int){0}, sizeof 0);
		for (i=0; i<nns; i++) {
			if (ns[i].sin.sin_family != AF_INET) continue;
			memcpy(ns[i].sin6.sin6_addr.s6_addr+12,
				&ns[i].sin.sin_addr, 4);
			memcpy(ns[i].sin6.sin6_addr.s6_addr,
				"\0\0\0\0\0\0\0\0\0\0\xff\xff", 12);
			ns[i].sin6.sin6_family = AF_INET6;
			ns[i].sin6.sin6_flowinfo = 0;
			ns[i].sin6.sin6_scope_id = 0;
		}
	}

	sa.sin.sin_family = family;
	if (fd < 0 || bind(fd, (void *)&sa, sl) < 0) {
		if (fd >= 0) close(fd);
		pthread_setcancelstate(cs, 0);
		return -1;
	}

	/* Past this point, there are no errors. Each individual query will
	 * yield either no reply (indicated by zero length) or an answer
	 * packet which is up to the caller to interpret. */

	for (i=0; i<nqueries; i++) pfd[i].fd = -1;
	pfd[nqueries].fd = fd;
	pfd[nqueries].events = POLLIN;
	pfd[nqueries+1].fd = -2;

	pthread_cleanup_push(cleanup, pfd);
	pthread_setcancelstate(cs, 0);

	memset(alens, 0, sizeof *alens * nqueries);

	retry_interval = timeout / attempts;
	next = 0;
	t0 = t2 = mtime();
	t1 = t2 - retry_interval;

	for (; t2-t0 < timeout; t2=mtime()) {
		/* This is the loop exit condition: that all queries
		 * have an accepted answer. */
		for (i=0; i<nqueries && alens[i]>0; i++);
		if (i==nqueries) break;

		if (t2-t1 >= retry_interval) {
			/* Query all configured namservers in parallel */
			for (i=0; i<nqueries; i++)
				if (!alens[i])
					for (j=0; j<nns; j++)
						sendto(fd, queries[i],
							qlens[i], MSG_NOSIGNAL,
							(void *)&ns[j], sl);
			t1 = t2;
			servfail_retry = 2 * nqueries;
		}

		/* Wait for a response, or until time to retry */
		if (poll(pfd, nqueries+1, t1+retry_interval-t2) <= 0) continue;

		while (next < nqueries) {
			struct msghdr mh = {
				.msg_name = (void *)&sa,
				.msg_namelen = sl,
				.msg_iovlen = 1,
				.msg_iov = (struct iovec []){
					{ .iov_base = (void *)answers[next],
					  .iov_len = asize }
				}
			};
			rlen = recvmsg(fd, &mh, 0);
			if (rlen < 0) break;

			/* Ignore non-identifiable packets */
			if (rlen < 4) continue;

			/* Ignore replies from addresses we didn't send to */
			for (j=0; j<nns && memcmp(ns+j, &sa, sl); j++);
			if (j==nns) continue;

			/* Find which query this answer goes with, if any */
			for (i=next; i<nqueries && (
				answers[next][0] != queries[i][0] ||
				answers[next][1] != queries[i][1] ); i++);
			if (i==nqueries) continue;
			if (alens[i]) continue;

			/* Only accept positive or negative responses;
			 * retry immediately on server failure, and ignore
			 * all other codes such as refusal. */
			switch (answers[next][3] & 15) {
			case 0:
			case 3:
				break;
			case 2:
				if (servfail_retry && servfail_retry--)
					sendto(fd, queries[i],
						qlens[i], MSG_NOSIGNAL,
						(void *)&ns[j], sl);
			default:
				continue;
			}

			/* Store answer in the right slot, or update next
			 * available temp slot if it's already in place. */
			alens[i] = rlen;
			if (i == next)
				for (; next<nqueries && alens[next]; next++);
			else
				memcpy(answers[i], answers[next], rlen);

			/* Ignore further UDP if all slots full or TCP-mode */
			if (next == nqueries) pfd[nqueries].events = 0;

			/* If answer is truncated (TC bit), fallback to TCP */
			if ((answers[i][2] & 2) || (mh.msg_flags & MSG_TRUNC)) {
				alens[i] = -1;
				pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, 0);
				r = start_tcp(pfd+i, family, ns+j, sl, queries[i], qlens[i]);
				pthread_setcancelstate(cs, 0);
				if (r >= 0) {
					qpos[i] = r;
					apos[i] = 0;
				}
				continue;
			}
		}

		for (i=0; i<nqueries; i++) if (pfd[i].revents & POLLOUT) {
			struct msghdr mh = {
				.msg_iovlen = 2,
				.msg_iov = (struct iovec [2]){
					{ .iov_base = (uint8_t[]){ qlens[i]>>8, qlens[i] }, .iov_len = 2 },
					{ .iov_base = (void *)queries[i], .iov_len = qlens[i] } }
			};
			step_mh(&mh, qpos[i]);
			r = sendmsg(pfd[i].fd, &mh, MSG_NOSIGNAL);
			if (r < 0) goto out;
			qpos[i] += r;
			if (qpos[i] == qlens[i]+2)
				pfd[i].events = POLLIN;
		}

		for (i=0; i<nqueries; i++) if (pfd[i].revents & POLLIN) {
			struct msghdr mh = {
				.msg_iovlen = 2,
				.msg_iov = (struct iovec [2]){
					{ .iov_base = alen_buf[i], .iov_len = 2 },
					{ .iov_base = answers[i], .iov_len = asize } }
			};
			step_mh(&mh, apos[i]);
			r = recvmsg(pfd[i].fd, &mh, 0);
			if (r <= 0) goto out;
			apos[i] += r;
			if (apos[i] < 2) continue;
			int alen = alen_buf[i][0]*256 + alen_buf[i][1];
			if (alen < 13) goto out;
			if (apos[i] < alen+2 && apos[i] < asize+2)
				continue;
			int rcode = answers[i][3] & 15;
			if (rcode != 0 && rcode != 3)
				goto out;

			/* Storing the length here commits the accepted answer.
			 * Immediately close TCP socket so as not to consume
			 * resources we no longer need. */
			alens[i] = alen;
			__syscall(SYS_close, pfd[i].fd);
			pfd[i].fd = -1;
		}
	}
out:
	pthread_cleanup_pop(1);

	/* Disregard any incomplete TCP results */
	for (i=0; i<nqueries; i++) if (alens[i]<0) alens[i] = 0;

	return 0;
}

int __res_msend(int nqueries, const unsigned char *const *queries,
	const int *qlens, unsigned char *const *answers, int *alens, int asize)
{
	struct resolvconf conf;
	if (__get_resolv_conf(&conf, 0, 0) < 0) return -1;
	return __res_msend_rc(nqueries, queries, qlens, answers, alens, asize, &conf);
}
