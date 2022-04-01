import sys
import py
ROOT = py.path.local(__file__).dirpath('..', '..', '..')
sys.path.insert(0, str(ROOT))

import time
from pypy.interpreter.error import OperationError
from pypy.module._pypyjson.interp_decoder import loads, JSONDecoder
from rpython.rlib.objectmodel import specialize, dont_inline

def _create_dict(self, d):
    w_res = W_Dict()
    w_res.dictval = d
    return w_res

JSONDecoder._create_dict = _create_dict

## MSG = open('msg.json').read()

class W_Root(object):
    pass

class W_Dict(W_Root):
    def __init__(self):
        self.dictval = {}

class W_Unicode(W_Root):
    def __init__(self, x):
        self.unival = x

class W_String(W_Root):
    def __init__(self, x):
        self.strval = x

class W_Int(W_Root):
    def __init__(self, x):
        self.intval = x

class W_Float(W_Root):
    def __init__(self, x):
        self.floatval = x

class W_List(W_Root):
    def __init__(self):
        self.listval = []

class W_Singleton(W_Root):
    def __init__(self, name):
        self.name = name

class FakeSpace(object):

    w_None = W_Singleton('None')
    w_True = W_Singleton('True')
    w_False = W_Singleton('False')
    w_ValueError = W_Singleton('ValueError')
    w_UnicodeDecodeError = W_Singleton('UnicodeDecodeError')
    w_unicode = W_Unicode
    w_int = W_Int
    w_float = W_Float

    def newtuple(self, items):
        return None

    def newdict(self):
        return W_Dict()

    def newlist(self, items):
        return W_List()

    def isinstance_w(self, w_x, w_type):
        return isinstance(w_x, w_type)

    def bytes_w(self, w_x):
        assert isinstance(w_x, W_String)
        return w_x.strval

    @dont_inline
    def call_method(self, obj, name, arg):
        assert name == 'append'
        assert isinstance(obj, W_List)
        obj.listval.append(arg)

    def call_function(self, w_func, *args_w):
        return self.w_None # XXX

    def setitem(self, d, key, value):
        assert isinstance(d, W_Dict)
        assert isinstance(key, W_Unicode)
        d.dictval[key.unival] = value

    def newtext(self, x):
        return W_String(x)
    newbytes = newtext

    def newint(self, x):
        return W_Int(x)

    def newfloat(self, x):
        return W_Float(x)

    @specialize.argtype(1)
    def wrap(self, x):
        if isinstance(x, int):
            return W_Int(x)
        elif isinstance(x, float):
            return W_Float(x)
        ## elif isinstance(x, str):
        ##     assert False
        else:
            return W_Unicode(unicode(x))


fakespace = FakeSpace()

def myloads(msg):
    return loads(fakespace, W_String(msg))

def bench(title, N, fn, arg):
    a = time.clock()
    for i in range(N):
        res = fn(arg)
    b = time.clock()
    print title, (b-a) / N * 1000

def entry_point(argv):
    if len(argv) != 3:
        print 'Usage: %s FILE n' % argv[0]
        return 1
    filename = argv[1]
    N = int(argv[2])
    f = open(filename)
    msg = f.read()

    try:
        bench('loads     ', N, myloads,  msg)
    except OperationError as e:
        print 'Error', e._compute_value(fakespace)

    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point, None

if __name__ == '__main__':
    entry_point(sys.argv)
