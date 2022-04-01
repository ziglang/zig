import py
import sys
from rpython.config.config import ConflictConfigError
from pypy.tool.option import make_config, make_objspace
from pypy.tool.pytest import appsupport
from pypy.conftest import option

_SPACECACHE={}
def gettestobjspace(**kwds):
    """ helper for instantiating and caching spaces for testing.
    """
    try:
        config = make_config(option, **kwds)
    except ConflictConfigError as e:
        # this exception is typically only raised if a module is not available.
        # in this case the test should be skipped
        py.test.skip(str(e))
    if getattr(option, 'runappdirect', None):
        return TinyObjSpace()
    key = config.getkey()
    try:
        return _SPACECACHE[key]
    except KeyError:
        space = maketestobjspace(config)
        _SPACECACHE[key] = space
        return space

def maketestobjspace(config=None):
    if config is None:
        config = make_config(option)
    if config.objspace.usemodules.thread:
        config.translation.thread = True
    config.objspace.extmodules = 'pypy.tool.pytest.fake_pytest'
    space = make_objspace(config)
    space.startup() # Initialize all builtin modules
    space.setitem(space.builtin.w_dict, space.wrap('raises'),
                  space.wrap(appsupport.app_raises))
    space.setitem(space.builtin.w_dict, space.wrap('skip'),
                  space.wrap(appsupport.app_skip))
    space.setitem(space.builtin.w_dict, space.wrap('py3k_skip'),
                  space.wrap(appsupport.app_py3k_skip))
    space.raises_w = appsupport.raises_w.__get__(space)
    return space


class TinyObjSpace(object):
    """An object space that delegates everything to the hosting Python."""
    def __init__(self):
        for name in ('int', 'long', 'str', 'unicode', 'list', 'None', 'ValueError',
                'OverflowError'):
            setattr(self, 'w_' + name, eval(name))
        self.w_bytes = bytes
        import __builtin__ as __builtin__
        self.builtin = __builtin__

    def appexec(self, args, body):
        body = body.lstrip()
        assert body.startswith('(')
        src = py.code.Source("def anonymous" + body)
        return (src, args)

    def wrap(self, obj):
        if isinstance(obj, str):
            return obj.decode('utf-8')
        if isinstance(obj, dict):
            return dict((self.wrap(k), self.wrap(v))
                        for k, v in obj.iteritems())
        if isinstance(obj, tuple):
            return tuple(self.wrap(item) for item in obj)
        if isinstance(obj, list):
            return list(self.wrap(item) for item in obj)
        return obj

    def newtext(self, obj):
        assert isinstance(obj, str)
        return obj.decode('utf-8')

    def newbytes(self, obj):
        assert isinstance(obj, str)
        return obj

    def unpackiterable(self, itr):
        return list(itr)

    def is_true(self, obj):
        if isinstance(obj, tuple) and isinstance(obj[0], py.code.Source):
            raise ValueError('bool(appexec object) unknown')
        return bool(obj)

    def is_none(self, obj):
        return obj is None

    def str_w(self, w_str):
        return w_str

    def utf8_w(self, w_utf8):
        return w_utf8

    def bytes_w(self, w_bytes):
        return w_bytes

    def newdict(self, module=None):
        return {}

    def newtuple(self, iterable):
        return tuple(iterable)

    def newlist(self, iterable):
        return list(iterable)

    def newbytes(self, obj):
        return bytes(obj)

    def newutf8(self, obj, lgth):
        return obj

    def call_function(self, func, *args, **kwds):
        return func(*args, **kwds)

    def call_method(self, obj, name, *args, **kwds):
        return getattr(obj, name)(*args, **kwds)

    def getattr(self, obj, name):
        return getattr(obj, name)

    def setattr(self, obj, name, value):
        setattr(obj, name, value)

    def getbuiltinmodule(self, name):
        return __import__(name)

    def delslice(self, obj, *args):
        obj.__delslice__(*args)

    def is_w(self, obj1, obj2):
        return obj1 is obj2

    def setitem(self, obj, key, value):
        obj[key] = value
