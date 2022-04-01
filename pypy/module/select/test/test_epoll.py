import py
import sys

# add a larger timeout for slow ARM machines
import platform


class AppTestEpoll(object):
    spaceconfig = {
        "usemodules": ["select", "_socket", "posix", "time"],
    }

    def setup_class(cls):
        # NB. we should ideally py.test.skip() if running on an old linux
        # where the kernel doesn't support epoll()
        if not sys.platform.startswith('linux'):
            py.test.skip("test requires linux (assumed >= 2.6)")

    def setup_method(self, meth):
        self.w_sockets = self.space.wrap([])
        if platform.machine().startswith('arm'):
            self.w_timeout = self.space.wrap(0.06)
        if platform.machine().startswith('s390x'):
            # s390x is not slow, but it seems there is one case when epoll
            # modify method is called that takes longer on s390x
            self.w_timeout = self.space.wrap(0.06)
        else:
            self.w_timeout = self.space.wrap(0.02)

    def teardown_method(self, meth):
        for socket in self.space.unpackiterable(self.w_sockets):
            self.space.call_method(socket, "close")

    def w_socket_pair(self):
        import _socket as socket

        server_socket = socket.socket()
        server_socket.bind(('127.0.0.1', 0))
        server_socket.listen(1)
        client = socket.socket()
        client.setblocking(False)
        raises(socket.error,
            client.connect, ('127.0.0.1', server_socket.getsockname()[1])
        )
        fd, addr = server_socket._accept()
        server = socket.socket(server_socket.family, server_socket.type,
                      server_socket.proto, fileno=fd)

        self.sockets.extend([server_socket, client, server])
        return client, server

    def test_create(self):
        import select

        ep = select.epoll(16)
        assert ep.fileno() > 0
        assert not ep.closed
        ep.close()
        assert ep.closed
        raises(ValueError, ep.fileno)

    def test_with(self):
        import select

        ep = select.epoll(16)
        assert ep.fileno() > 0
        with ep:
            assert not ep.closed
        assert ep.closed
        raises(ValueError, ep.__enter__)

    def test_badcreate(self):
        import select

        raises(TypeError, select.epoll, 1, 2, 3)
        raises(TypeError, select.epoll, 'foo')
        raises(TypeError, select.epoll, None)
        raises(TypeError, select.epoll, ())
        raises(TypeError, select.epoll, ['foo'])
        raises(TypeError, select.epoll, {})

    def test_add(self):
        import select

        client, server = self.socket_pair()

        ep = select.epoll(2)
        ep.register(server, select.EPOLLIN | select.EPOLLOUT)
        ep.register(client, select.EPOLLIN | select.EPOLLOUT)
        ep.close()

        # adding by object w/ fileno works, too.
        ep = select.epoll(2)
        ep.register(server.fileno(), select.EPOLLIN | select.EPOLLOUT)
        ep.register(client.fileno(), select.EPOLLIN | select.EPOLLOUT)
        ep.close()

        ep = select.epoll(2)
        # TypeError: argument must be an int, or have a fileno() method.
        raises(TypeError, ep.register, object(), select.EPOLLIN | select.EPOLLOUT)
        raises(TypeError, ep.register, None, select.EPOLLIN | select.EPOLLOUT)
        # ValueError: file descriptor cannot be a negative integer (-1)
        raises(ValueError, ep.register, -1, select.EPOLLIN | select.EPOLLOUT)
        # IOError: [Errno 9] Bad file descriptor
        raises(IOError, ep.register, 10000, select.EPOLLIN | select.EPOLLOUT)
        # registering twice also raises an exception
        ep.register(server, select.EPOLLIN | select.EPOLLOUT)
        raises(IOError, ep.register, server, select.EPOLLIN | select.EPOLLOUT)
        ep.close()

    def test_fromfd(self):
        import errno
        import select

        client, server = self.socket_pair()

        ep1 = select.epoll(2)
        ep2 = select.epoll.fromfd(ep1.fileno())

        ep2.register(server.fileno(), select.EPOLLIN | select.EPOLLOUT)
        ep2.register(client.fileno(), select.EPOLLIN | select.EPOLLOUT)

        events1 = ep1.poll(1, 4)
        events2 = ep2.poll(0.9, 4)
        assert len(events1) == 2
        assert len(events2) == 2
        ep1.close()

        exc_info = raises(IOError, ep2.poll, 1, 4)
        assert exc_info.value.args[0] == errno.EBADF

    def test_control_and_wait(self):
        import select
        import time

        client, server = self.socket_pair()

        ep = select.epoll(16)
        ep.register(server.fileno(),
            select.EPOLLIN | select.EPOLLOUT | select.EPOLLET
        )
        ep.register(client.fileno(),
            select.EPOLLIN | select.EPOLLOUT | select.EPOLLET
        )

        now = time.time()
        events = ep.poll(1, 4)
        then = time.time()
        assert then - now < 0.1

        events.sort()
        expected = [
            (client.fileno(), select.EPOLLOUT),
            (server.fileno(), select.EPOLLOUT)
        ]
        expected.sort()

        assert events == expected
        assert then - now < self.timeout

        now = time.time()
        events = ep.poll(timeout=2.1, maxevents=4)
        then = time.time()
        assert not events

        client.send(b"Hello!")
        server.send(b"world!!!")

        now = time.time()
        events = ep.poll(1, 4)
        then = time.time()
        assert then - now < self.timeout

        events.sort()
        expected = [
            (client.fileno(), select.EPOLLIN | select.EPOLLOUT),
            (server.fileno(), select.EPOLLIN | select.EPOLLOUT)
        ]
        expected.sort()

        assert events == expected

        ep.unregister(client.fileno())
        ep.modify(server.fileno(), select.EPOLLOUT)

        now = time.time()
        events = ep.poll(1, 4)
        then = time.time()
        assert then - now < self.timeout

        expected = [(server.fileno(), select.EPOLLOUT)]
        assert events == expected

    def test_errors(self):
        import select

        raises(ValueError, select.epoll, -2)
        raises(ValueError, select.epoll().register, -1, select.EPOLLIN)

    def test_unregister_closed(self):
        import select
        import time
        import errno

        client, server = self.socket_pair()

        fd = server.fileno()
        ep = select.epoll(16)
        ep.register(server)

        now = time.time()
        ep.poll(1, 4)
        then = time.time()
        assert then - now < self.timeout

        server.close()
        with raises(OSError) as cm:
            ep.unregister(fd)
        assert cm.value.errno == errno.EBADF

    def test_close_twice(self):
        import select

        ep = select.epoll()
        ep.close()
        ep.close()

    def test_non_inheritable(self):
        import select, posix

        ep = select.epoll()
        assert posix.get_inheritable(ep.fileno()) == False
        ep.close()
