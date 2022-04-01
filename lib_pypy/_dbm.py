import os
import sys
import ctypes.util
from ctypes import Structure, c_char, c_char_p, c_int, c_void_p, CDLL, POINTER

class error(IOError):
    def __init__(self, msg, filename=None):
        self.msg = msg
        if filename:
            self.filename = filename 

    def __str__(self):
        return self.msg

class datum(Structure):
    _fields_ = [
    ('dptr', POINTER(c_char)),
    ('dsize', c_int),
    ]

    def __init__(self, text):
        if isinstance(text, str):
            text = text.encode(sys.getdefaultencoding())
        elif not isinstance(text, bytes):
            msg = "dbm mapping keys must be a string or bytes object, not {!r}"
            raise TypeError(msg.format(type(text).__name__))
        Structure.__init__(self, text, len(text))

class dbm(object):
    def __init__(self, dbmobj, flags):
        self._aobj = dbmobj
        self._flags = flags

    def close(self):
        if not self._aobj:
            raise error('DBM object has already been closed')
        getattr(lib, funcs['close'])(self._aobj)
        self._aobj = None

    def __del__(self):
        if self._aobj:
            self.close()

    def keys(self):
        if not self._aobj:
            raise error('DBM object has already been closed')
        allkeys = []
        k = getattr(lib, funcs['firstkey'])(self._aobj)
        while k.dptr:
            allkeys.append(k.dptr[:k.dsize])
            k = getattr(lib, funcs['nextkey'])(self._aobj)
        return allkeys

    def get(self, key, default=None):
        if not self._aobj:
            raise error('DBM object has already been closed')
        dat = datum(key)
        k = getattr(lib, funcs['fetch'])(self._aobj, dat)
        if k.dptr:
            return k.dptr[:k.dsize]
        if getattr(lib, funcs['error'])(self._aobj):
            getattr(lib, funcs['clearerr'])(self._aobj)
            raise error("")
        return default

    def __len__(self):
        return len(self.keys())

    def __getitem__(self, key):
        value = self.get(key)
        if value is None:
            raise KeyError(key)
        return value

    def __setitem__(self, key, value):
        if not self._aobj: 
            raise error('DBM object has already been closed')
        dat = datum(key)
        data = datum(value)
        status = getattr(lib, funcs['store'])(self._aobj, dat, data, lib.DBM_REPLACE)
        err = getattr(lib, funcs['error'])(self._aobj)
        if err == 15:
            getattr(lib, funcs['clearerr'])(self._aobj)
            raise RuntimeError('asdf')
        elif err:
            getattr(lib, funcs['clearerr'])(self._aobj)
            raise error("")
        return status

    def setdefault(self, key, default=''):
        if not self._aobj:
            raise error('DBM object has already been closed')
        dat = datum(key)
        k = getattr(lib, funcs['fetch'])(self._aobj, dat)
        if k.dptr:
            return k.dptr[:k.dsize]
        data = datum(default)
        status = getattr(lib, funcs['store'])(self._aobj, dat, data, lib.DBM_INSERT)
        if status < 0:
            getattr(lib, funcs['clearerr'])(self._aobj)
            raise error("cannot add item to database")
        return default

    def __contains__(self, key):
        if not self._aobj:
            raise error('DBM object has already been closed')
        dat = datum(key)
        k = getattr(lib, funcs['fetch'])(self._aobj, dat)
        if k.dptr:
            return True
        return False
    has_key = __contains__

    def __delitem__(self, key):
        if not self._aobj:
            raise error('DBM object has already been closed')
        dat = datum(key)
        status = getattr(lib, funcs['delete'])(self._aobj, dat)
        if status < 0:
            getattr(lib, funcs['clearerr'])(self._aobj)
            if self._flags & os.O_RDWR:
                raise KeyError(key)
            raise error('cannot delete item from database')

    def __enter__(self):
        return self

    def __exit__(self, *exc_info):
        self.close()


### initialization: Berkeley DB versus normal DB

def _init_func(name, argtypes=None, restype=None):
    try:
        func = getattr(lib, '__db_ndbm_' + name)
        funcs[name] = '__db_ndbm_' + name
    except AttributeError:
        func = getattr(lib, 'dbm_' + name)
        funcs[name] = 'dbm_' + name
    if argtypes is not None:
        func.argtypes = argtypes
    if restype is not None:
        func.restype = restype

if sys.platform != 'darwin':
    libpath = ctypes.util.find_library('db')
    if not libpath:
        # XXX this is hopeless...
        for c in ['5.3', '5.2', '5.1', '5.0', '4.9', '4.8', '4.7', '4.6', '4.5']:
            libpath = ctypes.util.find_library('db-%s' % c)
            if libpath:
                break
        else:
            raise ModuleNotFoundError("Cannot find dbm library", name='_dbm')
    lib = CDLL(libpath) # Linux
    _platform = 'bdb'
else:
    lib = CDLL("/usr/lib/libdbm.dylib") # OS X
    _platform = 'osx'

library = "Berkeley DB"

funcs = {}
_init_func('open', (c_char_p, c_int, c_int), restype=c_void_p)
_init_func('close', (c_void_p,), restype=c_void_p)
_init_func('firstkey', (c_void_p,), restype=datum)
_init_func('nextkey', (c_void_p,), restype=datum)
_init_func('fetch', (c_void_p, datum), restype=datum)
_init_func('store', (c_void_p, datum, datum, c_int), restype=c_int)
_init_func('error', (c_void_p,), restype=c_int)
_init_func('delete', (c_void_p, datum), restype=c_int)
_init_func('clearerr', (c_void_p,), restype=c_int)



lib.DBM_INSERT = 0
lib.DBM_REPLACE = 1
lib.DBM_NOT_FOUND = 15


def open(filename, flag='r', mode=0o666):
    "open a DBM database"
    if not isinstance(filename, str):
        if sys.version_info < (3,) and isinstance(filename, unicode):
            # unlike CPython we'll encode 'filename' with filesystemencoding
            # instead of defaultencoding, because that seems like a far
            # better idea.  But I'm also open for saying that we should
            # rather go for bug-to-bug compatibility instead.
            filename = filename.encode(sys.getfilesystemencoding())
        else:
            raise TypeError("expected string")
    filename = filename.encode(sys.getdefaultencoding())

    openflag = 0
    try:
        openflag = {
            'r': os.O_RDONLY,
            'rw': os.O_RDWR,
            'w': os.O_RDWR | os.O_CREAT,
            'c': os.O_RDWR | os.O_CREAT,
            'n': os.O_RDWR | os.O_CREAT | os.O_TRUNC,
            }[flag]
    except KeyError:
        raise error("arg 2 to open should be 'r', 'w', 'c', or 'n'")

    a_db = getattr(lib, funcs['open'])(filename, openflag, mode)
    if a_db == 0 or a_db is None:
        if isinstance(filename, bytes):
            filename = filename.decode()
        raise error("Could not open file %s.db" % filename, filename)
    
    return dbm(a_db, openflag)

__all__ = ('datum', 'dbm', 'error', 'funcs', 'open', 'library')
