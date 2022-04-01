import os
import errno
import py

from rpython.rlib.rsocket import *
from rpython.rlib.rpoll import *
from rpython.rtyper.test.test_llinterp import interpret

if os.name == 'nt':
    has_poll = False
else:
    has_poll = True


def setup_module(mod):
    rsocket_startup()


def one_in_event(events, fd):
    assert len(events) == 1
    assert events[0][0] == fd
    assert events[0][1] & POLLIN


def one_out_event(events, fd):
    assert len(events) == 1
    assert events[0][0] == fd
    assert events[0][1] & POLLOUT


@py.test.mark.skipif('has_poll')
def test_no_poll():
    try:
        poll
    except NameError:
        pass
    else:
        assert False


@py.test.mark.skipif('not has_poll')
def test_simple():
    serv = RSocket(AF_INET, SOCK_STREAM)
    serv.bind(INETAddress('127.0.0.1', INADDR_ANY))
    serv.listen(1)
    servaddr = serv.getsockname()

    events = poll({serv.fd: POLLIN}, timeout=100)
    assert len(events) == 0

    cli = RSocket(AF_INET, SOCK_STREAM)
    cli.setblocking(False)
    err = cli.connect_ex(servaddr)
    assert err != 0

    events = poll({serv.fd: POLLIN}, timeout=500)
    one_in_event(events, serv.fd)

    servconn_fd, cliaddr = serv.accept()
    servconn = RSocket(AF_INET, fd=servconn_fd)

    events = poll({serv.fd: POLLIN,
                   cli.fd: POLLOUT}, timeout=500)
    one_out_event(events, cli.fd)

    err = cli.connect_ex(servaddr)
    # win32: returns WSAEISCONN when the connection finally succeed.
    # Mac OS/X: returns EISCONN.
    assert (err == 0 or err == 10056 or
            err == getattr(errno, 'EISCONN', '???'))

    events = poll({servconn.fd: POLLIN,
                   cli.fd: POLLIN}, timeout=100)
    assert len(events) == 0

    events = poll({servconn.fd: POLLOUT,
                   cli.fd: POLLOUT}, timeout=100)
    assert len(events) >= 1

    cli.close()
    servconn.close()
    serv.close()


@py.test.mark.skipif('not has_poll')
def test_exchange():
    serv = RSocket(AF_INET, SOCK_STREAM)
    serv.bind(INETAddress('127.0.0.1', INADDR_ANY))
    serv.listen(1)
    servaddr = serv.getsockname()

    events = poll({serv.fd: POLLIN}, timeout=100)
    assert len(events) == 0

    cli = RSocket(AF_INET, SOCK_STREAM)
    cli.setblocking(True)
    err = cli.connect_ex(servaddr)
    assert err == 0

    events = poll({serv.fd: POLLIN}, timeout=500)
    one_in_event(events, serv.fd)

    servconn_fd, cliaddr = serv.accept()
    servconn = RSocket(AF_INET, fd=servconn_fd)

    events = poll({serv.fd: POLLIN,
                   cli.fd: POLLOUT}, timeout=500)
    one_out_event(events, cli.fd)

    #send some data
    events = poll({cli.fd: POLLOUT}, timeout=500)
    one_out_event(events, cli.fd)
    cli.send("g'day, mate")
    events = poll({servconn.fd: POLLIN}, timeout=500)
    one_in_event(events, servconn.fd)
    answer = servconn.recv(1024)
    assert answer == "g'day, mate"

    #send a reply
    events = poll({servconn.fd: POLLOUT}, timeout=500)
    one_out_event(events, servconn.fd)
    servconn.send("you mean hello?")
    events = poll({cli.fd: POLLIN}, timeout=500)
    one_in_event(events, cli.fd)
    answer = cli.recv(1024)
    assert answer == "you mean hello?"

    #send more data
    events = poll({cli.fd: POLLOUT}, timeout=500)
    one_out_event(events, cli.fd)
    cli.send("sorry, wrong channel")
    events = poll({servconn.fd: POLLIN}, timeout=500)
    one_in_event(events, servconn.fd)
    answer = servconn.recv(1024)
    assert answer == "sorry, wrong channel"

    events = poll({servconn.fd: POLLOUT}, timeout=500)
    one_out_event(events, servconn.fd)
    servconn.send("np bye")
    events = poll({cli.fd: POLLIN}, timeout=500)
    one_in_event(events, cli.fd)
    answer = cli.recv(1024)
    assert answer == "np bye"

    cli.close()
    servconn.close()
    serv.close()


def test_select():
    if os.name == 'nt':
        py.test.skip('cannot select on file handles on windows')
    def f():
        readend, writeend = os.pipe()
        try:
            iwtd, owtd, ewtd = select([readend], [], [], 0.0)
            assert iwtd == owtd == ewtd == []
            os.write(writeend, 'X')
            iwtd, owtd, ewtd = select([readend], [], [])
            assert iwtd == [readend]
            assert owtd == ewtd == []

        finally:
            os.close(readend)
            os.close(writeend)
    f()
    interpret(f, [])


def test_select_timeout():
    if os.name == 'nt':
        py.test.skip('cannot select on file handles on windows')
    from time import time
    def f():
        # once there was a bug where the sleeping time was doubled
        a = time()
        iwtd, owtd, ewtd = select([], [], [], 5.0)
        diff = time() - a
        assert 4.8 < diff < 9.0
    interpret(f, [])


def test_translate_select():
    from rpython.translator.c.test.test_genc import compile
    def func():
        select([], [], [], 0.0)
    compile(func, [])


@py.test.mark.skipif('not has_poll')
def test_translate_poll():
    from rpython.translator.c.test.test_genc import compile
    def func():
        poll({})
    compile(func, [])
