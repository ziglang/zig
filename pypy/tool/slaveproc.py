import os, struct, marshal, sys

class Exchange(object):
    def __init__(self, inp, out):
        self.out = out
        self.inp = inp

    def send(self, data):
        if marshal is None:
            return
        s = marshal.dumps(data)
        h = struct.pack('L', len(s))
        self.out.write(h+s)
        self.out.flush()

    def recv(self):
        if not struct:
            return 'done'
        HSIZE = struct.calcsize('L')
        h = self.inp.read(HSIZE)
        if len(h) < HSIZE:
            raise EOFError
        size = struct.unpack('L', h)[0]
        s = self.inp.read(size)
        if len(s) < size:
            raise EOFError
        return marshal.loads(s)

    def forceclose(self):
        try:
            self.out.close()
        except:
            pass

        try:
            self.inp.close()
        except:
            pass

class SlaveProcess(object):
    _broken = False

    def __init__(self, slave_impl):
        if sys.platform == 'win32':
            unbuffered = ''
        else:
            unbuffered = '-u'
        inp, out = os.popen2('%s %s %s' % (sys.executable, unbuffered, os.path.abspath(slave_impl)))
        self.exchg = Exchange(out, inp)

    def cmd(self, data):
        self.exchg.send(data)
        try:
            return self.exchg.recv()
        except EOFError:
            self._broken = True
            raise

    def close(self):
        if not self._broken:
            assert self.cmd(None) == 'done'
        self.exchg.forceclose()

class Slave(object):

    def do_cmd(self, data):
        raise NotImplementedError

    def do(self):
        exchg = Exchange(sys.stdin, sys.stdout)
        while True:
            try:
                cmd = exchg.recv()
            except EOFError: # master died
                break
            if cmd is None:
                exchg.send('done')
                break
            result = self.do_cmd(cmd)
            exchg.send(result)
