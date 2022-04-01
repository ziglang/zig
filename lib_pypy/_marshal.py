"""Internal Python object serialization

This module contains functions that can read and write Python values in a binary format. The format is specific to Python, but independent of machine architecture issues (e.g., you can write a Python value to a file on a PC, transport the file to a Sun, and read it back there). Details of the format may change between Python versions.
"""

# NOTE: This module is used in the Python3 interpreter, but also by
# the "sandboxed" process.  It must work for Python2 as well.

import types

try:
    intern
except NameError:
    from sys import intern

try: from __pypy__ import builtinify
except ImportError: builtinify = lambda f: f


TYPE_NULL     = '0'
TYPE_NONE     = 'N'
TYPE_FALSE    = 'F'
TYPE_TRUE     = 'T'
TYPE_STOPITER = 'S'
TYPE_ELLIPSIS = '.'
TYPE_INT      = 'i'
TYPE_INT64    = 'I'
TYPE_FLOAT    = 'f'
TYPE_COMPLEX  = 'x'
TYPE_LONG     = 'l'
TYPE_STRING   = 's'
TYPE_INTERNED = 't'
TYPE_STRINGREF= 'R'
TYPE_TUPLE    = '('
TYPE_LIST     = '['
TYPE_DICT     = '{'
TYPE_CODE     = 'c'
TYPE_UNICODE  = 'u'
TYPE_UNKNOWN  = '?'
TYPE_SET      = '<'
TYPE_FROZENSET= '>'

class _Marshaller:

    dispatch = {}

    def __init__(self, writefunc):
        self._write = writefunc

    def dump(self, x):
        try:
            self.dispatch[type(x)](self, x)
        except KeyError:
            for tp in type(x).mro():
                func = self.dispatch.get(tp)
                if func:
                    break
            else:
                raise ValueError("unmarshallable object")
            func(self, x)

    def w_long64(self, x):
        self.w_long(x)
        self.w_long(x>>32)

    def w_long(self, x):
        a = chr(x & 0xff)
        x >>= 8
        b = chr(x & 0xff)
        x >>= 8
        c = chr(x & 0xff)
        x >>= 8
        d = chr(x & 0xff)
        self._write(a + b + c + d)

    def w_short(self, x):
        self._write(chr((x)     & 0xff))
        self._write(chr((x>> 8) & 0xff))

    def dump_none(self, x):
        self._write(TYPE_NONE)
    dispatch[type(None)] = dump_none

    def dump_bool(self, x):
        if x:
            self._write(TYPE_TRUE)
        else:
            self._write(TYPE_FALSE)
    dispatch[bool] = dump_bool

    def dump_stopiter(self, x):
        if x is not StopIteration:
            raise ValueError("unmarshallable object")
        self._write(TYPE_STOPITER)
    dispatch[type(StopIteration)] = dump_stopiter

    def dump_ellipsis(self, x):
        self._write(TYPE_ELLIPSIS)
    
    try:
        dispatch[type(Ellipsis)] = dump_ellipsis
    except NameError:
        pass

    # In Python3, this function is not used; see dump_long() below.
    def dump_int(self, x):
        y = x>>31
        if y and y != -1:
            self._write(TYPE_INT64)
            self.w_long64(x)
        else:
            self._write(TYPE_INT)
            self.w_long(x)
    dispatch[int] = dump_int

    def dump_long(self, x):
        self._write(TYPE_LONG)
        sign = 1
        if x < 0:
            sign = -1
            x = -x
        digits = []
        while x:
            digits.append(x & 0x7FFF)
            x = x>>15
        self.w_long(len(digits) * sign)
        for d in digits:
            self.w_short(d)
    try:
        long
    except NameError:
        dispatch[int] = dump_long
    else:
        dispatch[long] = dump_long

    def dump_float(self, x):
        write = self._write
        write(TYPE_FLOAT)
        s = repr(x)
        write(chr(len(s)))
        write(s)
    dispatch[float] = dump_float

    def dump_complex(self, x):
        write = self._write
        write(TYPE_COMPLEX)
        s = repr(x.real)
        write(chr(len(s)))
        write(s)
        s = repr(x.imag)
        write(chr(len(s)))
        write(s)
    try:
        dispatch[complex] = dump_complex
    except NameError:
        pass

    def dump_string(self, x):
        # XXX we can't check for interned strings, yet,
        # so we (for now) never create TYPE_INTERNED or TYPE_STRINGREF
        self._write(TYPE_STRING)
        self.w_long(len(x))
        self._write(x)
    dispatch[bytes] = dump_string

    def dump_unicode(self, x):
        self._write(TYPE_UNICODE)
        s = x.encode('utf8')
        self.w_long(len(s))
        self._write(s)
    try:
        unicode
    except NameError:
        dispatch[str] = dump_unicode
    else:
        dispatch[unicode] = dump_unicode

    def dump_tuple(self, x):
        self._write(TYPE_TUPLE)
        self.w_long(len(x))
        for item in x:
            self.dump(item)
    dispatch[tuple] = dump_tuple

    def dump_list(self, x):
        self._write(TYPE_LIST)
        self.w_long(len(x))
        for item in x:
            self.dump(item)
    dispatch[list] = dump_list

    def dump_dict(self, x):
        self._write(TYPE_DICT)
        for key, value in x.items():
            self.dump(key)
            self.dump(value)
        self._write(TYPE_NULL)
    dispatch[dict] = dump_dict

    def dump_code(self, x):
        self._write(TYPE_CODE)
        self.w_long(x.co_argcount)
        self.w_long(x.co_nlocals)
        self.w_long(x.co_stacksize)
        self.w_long(x.co_flags)
        self.dump(x.co_code)
        self.dump(x.co_consts)
        self.dump(x.co_names)
        self.dump(x.co_varnames)
        self.dump(x.co_freevars)
        self.dump(x.co_cellvars)
        self.dump(x.co_filename)
        self.dump(x.co_name)
        self.w_long(x.co_firstlineno)
        self.dump(x.co_lnotab)
    try:
        dispatch[types.CodeType] = dump_code
    except NameError:
        pass

    def dump_set(self, x):
        self._write(TYPE_SET)
        self.w_long(len(x))
        for each in x:
            self.dump(each)
    try:
        dispatch[set] = dump_set
    except NameError:
        pass

    def dump_frozenset(self, x):
        self._write(TYPE_FROZENSET)
        self.w_long(len(x))
        for each in x:
            self.dump(each)
    try:
        dispatch[frozenset] = dump_frozenset
    except NameError:
        pass

class _NULL:
    pass

class _StringBuffer:
    def __init__(self, value):
        self.bufstr = value
        self.bufpos = 0

    def read(self, n):
        pos = self.bufpos
        newpos = pos + n
        ret = self.bufstr[pos : newpos]
        self.bufpos = newpos
        return ret


class _Unmarshaller:

    dispatch = {}

    def __init__(self, readfunc):
        self._read = readfunc
        self._stringtable = []

    def load(self):
        c = self._read(1)
        if not c:
            raise EOFError
        try:
            return self.dispatch[c](self)
        except KeyError:
            raise ValueError("bad marshal code: %c (%d)" % (c, ord(c)))

    def r_short(self):
        lo = ord(self._read(1))
        hi = ord(self._read(1))
        x = lo | (hi<<8)
        if x & 0x8000:
            x = x - 0x10000
        return x

    def r_long(self):
        s = self._read(4)
        a = ord(s[0])
        b = ord(s[1])
        c = ord(s[2])
        d = ord(s[3])
        x = a | (b<<8) | (c<<16) | (d<<24)
        if d & 0x80 and x > 0:
            x = -((1<<32) - x)
            return int(x)
        else:
            return x

    def r_long64(self):
        a = ord(self._read(1))
        b = ord(self._read(1))
        c = ord(self._read(1))
        d = ord(self._read(1))
        e = ord(self._read(1))
        f = ord(self._read(1))
        g = ord(self._read(1))
        h = ord(self._read(1))
        x = a | (b<<8) | (c<<16) | (d<<24)
        x = x | (e<<32) | (f<<40) | (g<<48) | (h<<56)
        if h & 0x80 and x > 0:
            x = -((1<<64) - x)
        return x

    def load_null(self):
        return _NULL
    dispatch[TYPE_NULL] = load_null

    def load_none(self):
        return None
    dispatch[TYPE_NONE] = load_none

    def load_true(self):
        return True
    dispatch[TYPE_TRUE] = load_true

    def load_false(self):
        return False
    dispatch[TYPE_FALSE] = load_false

    def load_stopiter(self):
        return StopIteration
    dispatch[TYPE_STOPITER] = load_stopiter

    def load_ellipsis(self):
        return Ellipsis
    dispatch[TYPE_ELLIPSIS] = load_ellipsis

    dispatch[TYPE_INT] = r_long

    dispatch[TYPE_INT64] = r_long64

    def load_long(self):
        size = self.r_long()
        sign = 1
        if size < 0:
            sign = -1
            size = -size
        x = 0
        for i in range(size):
            d = self.r_short()
            x = x | (d<<(i*15))
        return x * sign
    dispatch[TYPE_LONG] = load_long

    def load_float(self):
        n = ord(self._read(1))
        s = self._read(n)
        return float(s)
    dispatch[TYPE_FLOAT] = load_float

    def load_complex(self):
        n = ord(self._read(1))
        s = self._read(n)
        real = float(s)
        n = ord(self._read(1))
        s = self._read(n)
        imag = float(s)
        return complex(real, imag)
    dispatch[TYPE_COMPLEX] = load_complex

    def load_string(self):
        n = self.r_long()
        return self._read(n)
    dispatch[TYPE_STRING] = load_string

    def load_interned(self):
        n = self.r_long()
        ret = intern(self._read(n))
        self._stringtable.append(ret)
        return ret
    dispatch[TYPE_INTERNED] = load_interned

    def load_stringref(self):
        n = self.r_long()
        return self._stringtable[n]
    dispatch[TYPE_STRINGREF] = load_stringref

    def load_unicode(self):
        n = self.r_long()
        s = self._read(n)
        ret = s.decode('utf8')
        return ret
    dispatch[TYPE_UNICODE] = load_unicode

    def load_tuple(self):
        return tuple(self.load_list())
    dispatch[TYPE_TUPLE] = load_tuple

    def load_list(self):
        n = self.r_long()
        list = [self.load() for i in range(n)]
        return list
    dispatch[TYPE_LIST] = load_list

    def load_dict(self):
        d = {}
        while 1:
            key = self.load()
            if key is _NULL:
                break
            value = self.load()
            d[key] = value
        return d
    dispatch[TYPE_DICT] = load_dict

    def load_code(self):
        argcount = self.r_long()
        nlocals = self.r_long()
        stacksize = self.r_long()
        flags = self.r_long()
        code = self.load()
        consts = self.load()
        names = self.load()
        varnames = self.load()
        freevars = self.load()
        cellvars = self.load()
        filename = self.load()
        name = self.load()
        firstlineno = self.r_long()
        lnotab = self.load()
        return types.CodeType(argcount, nlocals, stacksize, flags, code, consts,
                              names, varnames, filename, name, firstlineno,
                              lnotab, freevars, cellvars)
    dispatch[TYPE_CODE] = load_code

    def load_set(self):
        n = self.r_long()
        args = [self.load() for i in range(n)]
        return set(args)
    dispatch[TYPE_SET] = load_set

    def load_frozenset(self):
        n = self.r_long()
        args = [self.load() for i in range(n)]
        return frozenset(args)
    dispatch[TYPE_FROZENSET] = load_frozenset

# ________________________________________________________________

def _read(self, n):
    pos = self.bufpos
    newpos = pos + n
    if newpos > len(self.bufstr): raise EOFError
    ret = self.bufstr[pos : newpos]
    self.bufpos = newpos
    return ret

def _read1(self):
    ret = self.bufstr[self.bufpos]
    self.bufpos += 1
    return ret

def _r_short(self):
    lo = ord(_read1(self))
    hi = ord(_read1(self))
    x = lo | (hi<<8)
    if x & 0x8000:
        x = x - 0x10000
    return x

def _r_long(self):
    # inlined this most common case
    p = self.bufpos
    s = self.bufstr
    a = ord(s[p])
    b = ord(s[p+1])
    c = ord(s[p+2])
    d = ord(s[p+3])
    self.bufpos += 4
    x = a | (b<<8) | (c<<16) | (d<<24)
    if d & 0x80 and x > 0:
        x = -((1<<32) - x)
        return int(x)
    else:
        return x

def _r_long64(self):
    a = ord(_read1(self))
    b = ord(_read1(self))
    c = ord(_read1(self))
    d = ord(_read1(self))
    e = ord(_read1(self))
    f = ord(_read1(self))
    g = ord(_read1(self))
    h = ord(_read1(self))
    x = a | (b<<8) | (c<<16) | (d<<24)
    x = x | (e<<32) | (f<<40) | (g<<48) | (h<<56)
    if h & 0x80 and x > 0:
        x = -((1<<64) - x)
    return x

_load_dispatch = {}

class _FastUnmarshaller:

    dispatch = {}

    def __init__(self, buffer):
        self.bufstr = buffer
        self.bufpos = 0
        self._stringtable = []

    def load(self):
        # make flow space happy
        c = '?'
        try:
            c = self.bufstr[self.bufpos]
            self.bufpos += 1
            return _load_dispatch[c](self)
        except KeyError:
            raise ValueError("bad marshal code: %c (%d)" % (c, ord(c)))
        except IndexError:
            raise EOFError

    def load_null(self):
        return _NULL
    dispatch[TYPE_NULL] = load_null

    def load_none(self):
        return None
    dispatch[TYPE_NONE] = load_none

    def load_true(self):
        return True
    dispatch[TYPE_TRUE] = load_true

    def load_false(self):
        return False
    dispatch[TYPE_FALSE] = load_false

    def load_stopiter(self):
        return StopIteration
    dispatch[TYPE_STOPITER] = load_stopiter

    def load_ellipsis(self):
        return Ellipsis
    dispatch[TYPE_ELLIPSIS] = load_ellipsis

    def load_int(self):
        return _r_long(self)
    dispatch[TYPE_INT] = load_int

    def load_int64(self):
        return _r_long64(self)
    dispatch[TYPE_INT64] = load_int64

    def load_long(self):
        size = _r_long(self)
        sign = 1
        if size < 0:
            sign = -1
            size = -size
        x = 0
        for i in range(size):
            d = _r_short(self)
            x = x | (d<<(i*15))
        return x * sign
    dispatch[TYPE_LONG] = load_long

    def load_float(self):
        n = ord(_read1(self))
        s = _read(self, n)
        return float(s)
    dispatch[TYPE_FLOAT] = load_float

    def load_complex(self):
        n = ord(_read1(self))
        s = _read(self, n)
        real = float(s)
        n = ord(_read1(self))
        s = _read(self, n)
        imag = float(s)
        return complex(real, imag)
    dispatch[TYPE_COMPLEX] = load_complex

    def load_string(self):
        n = _r_long(self)
        return _read(self, n)
    dispatch[TYPE_STRING] = load_string

    def load_interned(self):
        n = _r_long(self)
        ret = intern(_read(self, n))
        self._stringtable.append(ret)
        return ret
    dispatch[TYPE_INTERNED] = load_interned

    def load_stringref(self):
        n = _r_long(self)
        return self._stringtable[n]
    dispatch[TYPE_STRINGREF] = load_stringref

    def load_unicode(self):
        n = _r_long(self)
        s = _read(self, n)
        ret = s.decode('utf8')
        return ret
    dispatch[TYPE_UNICODE] = load_unicode

    def load_tuple(self):
        return tuple(self.load_list())
    dispatch[TYPE_TUPLE] = load_tuple

    def load_list(self):
        n = _r_long(self)
        list = []
        for i in range(n):
            list.append(self.load())
        return list
    dispatch[TYPE_LIST] = load_list

    def load_dict(self):
        d = {}
        while 1:
            key = self.load()
            if key is _NULL:
                break
            value = self.load()
            d[key] = value
        return d
    dispatch[TYPE_DICT] = load_dict

    def load_code(self):
        argcount = _r_long(self)
        nlocals = _r_long(self)
        stacksize = _r_long(self)
        flags = _r_long(self)
        code = self.load()
        consts = self.load()
        names = self.load()
        varnames = self.load()
        freevars = self.load()
        cellvars = self.load()
        filename = self.load()
        name = self.load()
        firstlineno = _r_long(self)
        lnotab = self.load()
        return types.CodeType(argcount, nlocals, stacksize, flags, code, consts,
                              names, varnames, filename, name, firstlineno,
                              lnotab, freevars, cellvars)
    dispatch[TYPE_CODE] = load_code

    def load_set(self):
        n = _r_long(self)
        args = [self.load() for i in range(n)]
        return set(args)
    dispatch[TYPE_SET] = load_set

    def load_frozenset(self):
        n = _r_long(self)
        args = [self.load() for i in range(n)]
        return frozenset(args)
    dispatch[TYPE_FROZENSET] = load_frozenset

_load_dispatch = _FastUnmarshaller.dispatch

# _________________________________________________________________
#
# user interface

version = 1

@builtinify
def dump(x, f, version=version):
    # XXX 'version' is ignored, we always dump in a version-0-compatible format
    m = _Marshaller(f.write)
    m.dump(x)

@builtinify
def load(f):
    um = _Unmarshaller(f.read)
    return um.load()

@builtinify
def dumps(x, version=version):
    # XXX 'version' is ignored, we always dump in a version-0-compatible format
    buffer = []
    m = _Marshaller(buffer.append)
    m.dump(x)
    return ''.join(buffer)

@builtinify
def loads(s):
    um = _FastUnmarshaller(s)
    return um.load()
