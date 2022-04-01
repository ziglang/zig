import socket
import selectors
import telnetlib
import threading
import contextlib

from test import support
from test.support import socket_helper
import unittest

HOST = socket_helper.HOST

def server(evt, serv):
    serv.listen()
    evt.set()
    try:
        conn, addr = serv.accept()
        conn.close()
    except socket.timeout:
        pass
    finally:
        serv.close()

class GeneralTests(unittest.TestCase):

    def setUp(self):
        self.evt = threading.Event()
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(60)  # Safety net. Look issue 11812
        self.port = socket_helper.bind_port(self.sock)
        self.thread = threading.Thread(target=server, args=(self.evt,self.sock))
        self.thread.setDaemon(True)
        self.thread.start()
        self.evt.wait()

    def tearDown(self):
        self.thread.join()
        del self.thread  # Clear out any dangling Thread objects.

    def testBasic(self):
        # connects
        telnet = telnetlib.Telnet(HOST, self.port)
        telnet.sock.close()

    def testContextManager(self):
        with telnetlib.Telnet(HOST, self.port) as tn:
            self.assertIsNotNone(tn.get_socket())
        self.assertIsNone(tn.get_socket())

    def testTimeoutDefault(self):
        self.assertTrue(socket.getdefaulttimeout() is None)
        socket.setdefaulttimeout(30)
        try:
            telnet = telnetlib.Telnet(HOST, self.port)
        finally:
            socket.setdefaulttimeout(None)
        self.assertEqual(telnet.sock.gettimeout(), 30)
        telnet.sock.close()

    def testTimeoutNone(self):
        # None, having other default
        self.assertTrue(socket.getdefaulttimeout() is None)
        socket.setdefaulttimeout(30)
        try:
            telnet = telnetlib.Telnet(HOST, self.port, timeout=None)
        finally:
            socket.setdefaulttimeout(None)
        self.assertTrue(telnet.sock.gettimeout() is None)
        telnet.sock.close()

    def testTimeoutValue(self):
        telnet = telnetlib.Telnet(HOST, self.port, timeout=30)
        self.assertEqual(telnet.sock.gettimeout(), 30)
        telnet.sock.close()

    def testTimeoutOpen(self):
        telnet = telnetlib.Telnet()
        telnet.open(HOST, self.port, timeout=30)
        self.assertEqual(telnet.sock.gettimeout(), 30)
        telnet.sock.close()

    def testGetters(self):
        # Test telnet getter methods
        telnet = telnetlib.Telnet(HOST, self.port, timeout=30)
        t_sock = telnet.sock
        self.assertEqual(telnet.get_socket(), t_sock)
        self.assertEqual(telnet.fileno(), t_sock.fileno())
        telnet.sock.close()

class SocketStub(object):
    ''' a socket proxy that re-defines sendall() '''
    def __init__(self, reads=()):
        self.reads = list(reads)  # Intentionally make a copy.
        self.writes = []
        self.block = False
    def sendall(self, data):
        self.writes.append(data)
    def recv(self, size):
        out = b''
        while self.reads and len(out) < size:
            out += self.reads.pop(0)
        if len(out) > size:
            self.reads.insert(0, out[size:])
            out = out[:size]
        return out

class TelnetAlike(telnetlib.Telnet):
    def fileno(self):
        raise NotImplementedError()
    def close(self): pass
    def sock_avail(self):
        return (not self.sock.block)
    def msg(self, msg, *args):
        with support.captured_stdout() as out:
            telnetlib.Telnet.msg(self, msg, *args)
        self._messages += out.getvalue()
        return

class MockSelector(selectors.BaseSelector):

    def __init__(self):
        self.keys = {}

    @property
    def resolution(self):
        return 1e-3

    def register(self, fileobj, events, data=None):
        key = selectors.SelectorKey(fileobj, 0, events, data)
        self.keys[fileobj] = key
        return key

    def unregister(self, fileobj):
        return self.keys.pop(fileobj)

    def select(self, timeout=None):
        block = False
        for fileobj in self.keys:
            if isinstance(fileobj, TelnetAlike):
                block = fileobj.sock.block
                break
        if block:
            return []
        else:
            return [(key, key.events) for key in self.keys.values()]

    def get_map(self):
        return self.keys


@contextlib.contextmanager
def test_socket(reads):
    def new_conn(*ignored):
        return SocketStub(reads)
    try:
        old_conn = socket.create_connection
        socket.create_connection = new_conn
        yield None
    finally:
        socket.create_connection = old_conn
    return

def test_telnet(reads=(), cls=TelnetAlike):
    ''' return a telnetlib.Telnet object that uses a SocketStub with
        reads queued up to be read '''
    for x in reads:
        assert type(x) is bytes, x
    with test_socket(reads):
        telnet = cls('dummy', 0)
        telnet._messages = '' # debuglevel output
    return telnet

class ExpectAndReadTestCase(unittest.TestCase):
    def setUp(self):
        self.old_selector = telnetlib._TelnetSelector
        telnetlib._TelnetSelector = MockSelector
    def tearDown(self):
        telnetlib._TelnetSelector = self.old_selector

class ReadTests(ExpectAndReadTestCase):
    def test_read_until(self):
        """
        read_until(expected, timeout=None)
        test the blocking version of read_util
        """
        want = [b'xxxmatchyyy']
        telnet = test_telnet(want)
        data = telnet.read_until(b'match')
        self.assertEqual(data, b'xxxmatch', msg=(telnet.cookedq, telnet.rawq, telnet.sock.reads))

        reads = [b'x' * 50, b'match', b'y' * 50]
        expect = b''.join(reads[:-1])
        telnet = test_telnet(reads)
        data = telnet.read_until(b'match')
        self.assertEqual(data, expect)


    def test_read_all(self):
        """
        read_all()
          Read all data until EOF; may block.
        """
        reads = [b'x' * 500, b'y' * 500, b'z' * 500]
        expect = b''.join(reads)
        telnet = test_telnet(reads)
        data = telnet.read_all()
        self.assertEqual(data, expect)
        return

    def test_read_some(self):
        """
        read_some()
          Read at least one byte or EOF; may block.
        """
        # test 'at least one byte'
        telnet = test_telnet([b'x' * 500])
        data = telnet.read_some()
        self.assertTrue(len(data) >= 1)
        # test EOF
        telnet = test_telnet()
        data = telnet.read_some()
        self.assertEqual(b'', data)

    def _read_eager(self, func_name):
        """
        read_*_eager()
          Read all data available already queued or on the socket,
          without blocking.
        """
        want = b'x' * 100
        telnet = test_telnet([want])
        func = getattr(telnet, func_name)
        telnet.sock.block = True
        self.assertEqual(b'', func())
        telnet.sock.block = False
        data = b''
        while True:
            try:
                data += func()
            except EOFError:
                break
        self.assertEqual(data, want)

    def test_read_eager(self):
        # read_eager and read_very_eager make the same guarantees
        # (they behave differently but we only test the guarantees)
        self._read_eager('read_eager')
        self._read_eager('read_very_eager')
        # NB -- we need to test the IAC block which is mentioned in the
        # docstring but not in the module docs

    def read_very_lazy(self):
        want = b'x' * 100
        telnet = test_telnet([want])
        self.assertEqual(b'', telnet.read_very_lazy())
        while telnet.sock.reads:
            telnet.fill_rawq()
        data = telnet.read_very_lazy()
        self.assertEqual(want, data)
        self.assertRaises(EOFError, telnet.read_very_lazy)

    def test_read_lazy(self):
        want = b'x' * 100
        telnet = test_telnet([want])
        self.assertEqual(b'', telnet.read_lazy())
        data = b''
        while True:
            try:
                read_data = telnet.read_lazy()
                data += read_data
                if not read_data:
                    telnet.fill_rawq()
            except EOFError:
                break
            self.assertTrue(want.startswith(data))
        self.assertEqual(data, want)

class nego_collector(object):
    def __init__(self, sb_getter=None):
        self.seen = b''
        self.sb_getter = sb_getter
        self.sb_seen = b''

    def do_nego(self, sock, cmd, opt):
        self.seen += cmd + opt
        if cmd == tl.SE and self.sb_getter:
            sb_data = self.sb_getter()
            self.sb_seen += sb_data

tl = telnetlib

class WriteTests(unittest.TestCase):
    '''The only thing that write does is replace each tl.IAC for
    tl.IAC+tl.IAC'''

    def test_write(self):
        data_sample = [b'data sample without IAC',
                       b'data sample with' + tl.IAC + b' one IAC',
                       b'a few' + tl.IAC + tl.IAC + b' iacs' + tl.IAC,
                       tl.IAC,
                       b'']
        for data in data_sample:
            telnet = test_telnet()
            telnet.write(data)
            written = b''.join(telnet.sock.writes)
            self.assertEqual(data.replace(tl.IAC,tl.IAC+tl.IAC), written)

class OptionTests(unittest.TestCase):
    # RFC 854 commands
    cmds = [tl.AO, tl.AYT, tl.BRK, tl.EC, tl.EL, tl.GA, tl.IP, tl.NOP]

    def _test_command(self, data):
        """ helper for testing IAC + cmd """
        telnet = test_telnet(data)
        data_len = len(b''.join(data))
        nego = nego_collector()
        telnet.set_option_negotiation_callback(nego.do_nego)
        txt = telnet.read_all()
        cmd = nego.seen
        self.assertTrue(len(cmd) > 0) # we expect at least one command
        self.assertIn(cmd[:1], self.cmds)
        self.assertEqual(cmd[1:2], tl.NOOPT)
        self.assertEqual(data_len, len(txt + cmd))
        nego.sb_getter = None # break the nego => telnet cycle

    def test_IAC_commands(self):
        for cmd in self.cmds:
            self._test_command([tl.IAC, cmd])
            self._test_command([b'x' * 100, tl.IAC, cmd, b'y'*100])
            self._test_command([b'x' * 10, tl.IAC, cmd, b'y'*10])
        # all at once
        self._test_command([tl.IAC + cmd for (cmd) in self.cmds])

    def test_SB_commands(self):
        # RFC 855, subnegotiations portion
        send = [tl.IAC + tl.SB + tl.IAC + tl.SE,
                tl.IAC + tl.SB + tl.IAC + tl.IAC + tl.IAC + tl.SE,
                tl.IAC + tl.SB + tl.IAC + tl.IAC + b'aa' + tl.IAC + tl.SE,
                tl.IAC + tl.SB + b'bb' + tl.IAC + tl.IAC + tl.IAC + tl.SE,
                tl.IAC + tl.SB + b'cc' + tl.IAC + tl.IAC + b'dd' + tl.IAC + tl.SE,
               ]
        telnet = test_telnet(send)
        nego = nego_collector(telnet.read_sb_data)
        telnet.set_option_negotiation_callback(nego.do_nego)
        txt = telnet.read_all()
        self.assertEqual(txt, b'')
        want_sb_data = tl.IAC + tl.IAC + b'aabb' + tl.IAC + b'cc' + tl.IAC + b'dd'
        self.assertEqual(nego.sb_seen, want_sb_data)
        self.assertEqual(b'', telnet.read_sb_data())
        nego.sb_getter = None # break the nego => telnet cycle

    def test_debuglevel_reads(self):
        # test all the various places that self.msg(...) is called
        given_a_expect_b = [
            # Telnet.fill_rawq
            (b'a', ": recv b''\n"),
            # Telnet.process_rawq
            (tl.IAC + bytes([88]), ": IAC 88 not recognized\n"),
            (tl.IAC + tl.DO + bytes([1]), ": IAC DO 1\n"),
            (tl.IAC + tl.DONT + bytes([1]), ": IAC DONT 1\n"),
            (tl.IAC + tl.WILL + bytes([1]), ": IAC WILL 1\n"),
            (tl.IAC + tl.WONT + bytes([1]), ": IAC WONT 1\n"),
           ]
        for a, b in given_a_expect_b:
            telnet = test_telnet([a])
            telnet.set_debuglevel(1)
            txt = telnet.read_all()
            self.assertIn(b, telnet._messages)
        return

    def test_debuglevel_write(self):
        telnet = test_telnet()
        telnet.set_debuglevel(1)
        telnet.write(b'xxx')
        expected = "send b'xxx'\n"
        self.assertIn(expected, telnet._messages)

    def test_debug_accepts_str_port(self):
        # Issue 10695
        with test_socket([]):
            telnet = TelnetAlike('dummy', '0')
            telnet._messages = ''
        telnet.set_debuglevel(1)
        telnet.msg('test')
        self.assertRegex(telnet._messages, r'0.*test')


class ExpectTests(ExpectAndReadTestCase):
    def test_expect(self):
        """
        expect(expected, [timeout])
          Read until the expected string has been seen, or a timeout is
          hit (default is no timeout); may block.
        """
        want = [b'x' * 10, b'match', b'y' * 10]
        telnet = test_telnet(want)
        (_,_,data) = telnet.expect([b'match'])
        self.assertEqual(data, b''.join(want[:-1]))


if __name__ == '__main__':
    unittest.main()
