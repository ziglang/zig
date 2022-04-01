import exceptions, os
from pypy.tool import slaveproc

class IsolateException(Exception):
    pass

class IsolateInvoker(object):
    # to have a nice repr
    
    def __init__(self, isolate, name):
        self.isolate = isolate
        self.name = name

    def __call__(self, *args):
        return self.isolate._invoke(self.name, args)
        
    def __repr__(self):
        return "<invoker for %r . %r>" % (self.isolate.module, self.name)

    def close_isolate(self):
        self.isolate._close()

class Isolate(object):
    """
    Isolate lets load a module in a different process,
    and support invoking functions from it passing and
    returning simple values

    module: a dotted module name or a tuple (directory, module-name)
    """
    _closed = False

    def __init__(self, module):
        self.module = module
        self.slave = slaveproc.SlaveProcess(os.path.join(os.path.dirname(__file__),
                                                         'isolate_slave.py'))
        res = self.slave.cmd(('load', module))
        assert res == 'loaded'

    def __getattr__(self, name):
        return IsolateInvoker(self, name)

    def _invoke(self, func, args):
        status, value = self.slave.cmd(('invoke', (func, args)))
        print 'OK'
        if status == 'ok':
            return value
        else:
            exc_type_module, exc_type_name = value
            if exc_type_module == 'exceptions':
                raise getattr(exceptions, exc_type_name)
            else:
                raise IsolateException("%s.%s" % value) 

    def _close(self):
        if not self._closed:
            self.slave.close()
            self._closed = True

    def __del__(self):
        self._close()

def close_isolate(isolate):
    assert isinstance(isolate, Isolate)
    isolate._close()
