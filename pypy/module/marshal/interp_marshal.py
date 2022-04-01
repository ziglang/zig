from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import WrappedDefault, unwrap_spec
from rpython.rlib.rarithmetic import intmask
from rpython.rlib import rstackovf
from pypy.objspace.std.marshal_impl import marshal, get_unmarshallers

#
# Write Python objects to files and read them back.  This is primarily
# intended for writing and reading compiled Python code, even though
# dicts, lists, sets and frozensets, not commonly seen in code
# objects, are supported.  Version 3 of this protocol properly
# supports circular links and sharing.  The previous version is called
# "2", like in Python 2.7, although it is not always compatible
# between CPython 2.7 and CPython 3.4.  Version 4 adds small
# optimizations in compactness.
#
# XXX: before py3k, there was logic to do efficiently dump()/load() on
# a file object.  The corresponding logic is gone from CPython 3.x, so
# I don't feel bad about killing it here too.
#

Py_MARSHAL_VERSION = 4


@unwrap_spec(version=int)
def dump(space, w_data, w_f, version=Py_MARSHAL_VERSION):
    """Write the 'data' object into the open file 'f'."""
    # same implementation as CPython 3.x.
    w_string = dumps(space, w_data, version)
    space.call_method(w_f, 'write', w_string)

@unwrap_spec(version=int)
def dumps(space, w_data, version=Py_MARSHAL_VERSION):
    """Return the string that would have been written to a file
by dump(data, file)."""
    m = StringMarshaller(space, version)
    m.dump_w_obj(w_data)
    return space.newbytes(m.get_value())

def load(space, w_f):
    """Read one value from the file 'f' and return it."""
    reader = FileReader(space, w_f)
    try:
        u = Unmarshaller(space, reader)
        return u.load_w_obj()
    finally:
        reader.finished()

def loads(space, w_str):
    """Convert a string back to a value.  Extra characters in the string are
ignored."""
    return _loads(space, w_str)

def _loads(space, w_str, hidden_applevel=False):
    u = StringUnmarshaller(space, w_str, hidden_applevel=hidden_applevel)
    obj = u.load_w_obj()
    return obj


class AbstractReaderWriter(object):
    def __init__(self, space):
        self.space = space

    def raise_eof(self):
        space = self.space
        raise oefmt(space.w_EOFError, "EOF read where object expected")

    def finished(self):
        pass

    def read(self, n):
        raise NotImplementedError("Purely abstract method")

    def write(self, data):
        raise NotImplementedError("Purely abstract method")


class FileReader(AbstractReaderWriter):
    def __init__(self, space, w_f):
        AbstractReaderWriter.__init__(self, space)
        try:
            self.func = space.getattr(w_f, space.newtext('read'))
            # XXX how to check if it is callable?
        except OperationError as e:
            if not e.match(space, space.w_AttributeError):
                raise
            raise oefmt(space.w_TypeError,
                        "marshal.load() arg must be file-like object")

    def read(self, n):
        space = self.space
        w_ret = space.call_function(self.func, space.newint(n))
        ret = space.bytes_w(w_ret)
        if len(ret) < n:
            self.raise_eof()
        if len(ret) > n:
            raise oefmt(space.w_ValueError,
                        "read() returned too much data: "
                        "%d bytes requested, %d returned",
                        n, len(ret))
        return ret


class _Base(object):
    def raise_exc(self, msg):
        space = self.space
        raise OperationError(space.w_ValueError, space.newtext(msg))

class Marshaller(_Base):
    """
    atomic types including typecode:

    atom(tc)                    puts single typecode
    atom_int(tc, int)           puts code and int
    atom_int64(tc, int64)       puts code and int64
    atom_str(tc, str)           puts code, len and string

    building blocks for compound types:

    start(typecode)             sets the type character
    put(s)                      puts a string with fixed length
    put_short(int)              puts a short integer
    put_int(int)                puts an integer
    put_pascal(s)               puts a short string
    put_w_obj(w_obj)            puts a wrapped object
    put_tuple_w(TYPE, tuple_w)  puts tuple_w, an unwrapped list of wrapped objects
    """

    def __init__(self, space, writer, version):
        self.space = space
        ## self.put = putfunc
        self.writer = writer
        self.version = version
        self.all_refs = {}
        # all_refs = {w_obj: index} for all w_obj that are of a
        # "reasonably sharable" type.  CPython checks the refcount of
        # any object to know if it is sharable, independently of its
        # type.  We can't do that.  We could do a two-pass marshaller.
        # For now we simply add to this list all objects that marshal to
        # more than a few fixed-sized bytes, minus ones like code
        # objects that never appear more than once except in complete
        # corner cases.

    ## currently we cannot use a put that is a bound method
    ## from outside. Same holds for get.
    def put(self, s):
        self.writer.write(s)

    def put1(self, c):
        self.writer.write(c)

    def atom(self, typecode):
        #assert type(typecode) is str and len(typecode) == 1
        # type(char) not supported
        self.put1(typecode)

    def atom_int(self, typecode, x):
        a = chr(x & 0xff)
        x >>= 8
        b = chr(x & 0xff)
        x >>= 8
        c = chr(x & 0xff)
        x >>= 8
        d = chr(x & 0xff)
        self.put(typecode + a + b + c + d)

    def atom_int64(self, typecode, x):
        self.atom_int(typecode, x)
        self.put_int(x>>32)

    def atom_str(self, typecode, x):
        self.atom_int(typecode, len(x))
        self.put(x)

    def start(self, typecode):
        # type(char) not supported
        self.put(typecode)

    def put_short(self, x):
        a = chr(x & 0xff)
        x >>= 8
        b = chr(x & 0xff)
        self.put(a + b)

    def put_int(self, x):
        a = chr(x & 0xff)
        x >>= 8
        b = chr(x & 0xff)
        x >>= 8
        c = chr(x & 0xff)
        x >>= 8
        d = chr(x & 0xff)
        self.put(a + b + c + d)

    def put_pascal(self, x):
        lng = len(x)
        if lng > 255:
            self.raise_exc('not a pascal string')
        self.put(chr(lng))
        self.put(x)

    def put_w_obj(self, w_obj):
        marshal(self.space, w_obj, self)

    def dump_w_obj(self, w_obj):
        space = self.space
        try:
            self.put_w_obj(w_obj)
        except rstackovf.StackOverflow:
            rstackovf.check_stack_overflow()
            self._overflow()

    def put_tuple_w(self, typecode, lst_w, single_byte_size=False):
        self.start(typecode)
        lng = len(lst_w)
        if single_byte_size:
            self.put(chr(lng))
        else:
            self.put_int(lng)
        idx = 0
        while idx < lng:
            w_obj = lst_w[idx]
            marshal(self.space, w_obj, self)
            idx += 1

    def _overflow(self):
        self.raise_exc('object too deeply nested to marshal')


class StringMarshaller(Marshaller):
    def __init__(self, space, version):
        Marshaller.__init__(self, space, None, version)
        self.buflis = [chr(0)] * 128
        self.bufpos = 0

    def put(self, s):
        pos = self.bufpos
        lng = len(s)
        newpos = pos + lng
        while len(self.buflis) < newpos:
            self.buflis *= 2
        idx = 0
        while idx < lng:
            self.buflis[pos + idx] = s[idx]
            idx += 1
        self.bufpos = newpos

    def put1(self, c):
        pos = self.bufpos
        newpos = pos + 1
        if len(self.buflis) < newpos:
            self.buflis *= 2
        self.buflis[pos] = c
        self.bufpos = newpos

    def atom_int(self, typecode, x):
        a = chr(x & 0xff)
        x >>= 8
        b = chr(x & 0xff)
        x >>= 8
        c = chr(x & 0xff)
        x >>= 8
        d = chr(x & 0xff)
        pos = self.bufpos
        newpos = pos + 5
        if len(self.buflis) < newpos:
            self.buflis *= 2
        self.buflis[pos] = typecode
        self.buflis[pos+1] = a
        self.buflis[pos+2] = b
        self.buflis[pos+3] = c
        self.buflis[pos+4] = d
        self.bufpos = newpos

    def put_short(self, x):
        a = chr(x & 0xff)
        x >>= 8
        b = chr(x & 0xff)
        pos = self.bufpos
        newpos = pos + 2
        if len(self.buflis) < newpos:
            self.buflis *= 2
        self.buflis[pos]   = a
        self.buflis[pos+1] = b
        self.bufpos = newpos

    def put_int(self, x):
        a = chr(x & 0xff)
        x >>= 8
        b = chr(x & 0xff)
        x >>= 8
        c = chr(x & 0xff)
        x >>= 8
        d = chr(x & 0xff)
        pos = self.bufpos
        newpos = pos + 4
        if len(self.buflis) < newpos:
            self.buflis *= 2
        self.buflis[pos]   = a
        self.buflis[pos+1] = b
        self.buflis[pos+2] = c
        self.buflis[pos+3] = d
        self.bufpos = newpos

    def get_value(self):
        return ''.join(self.buflis[:self.bufpos])


def invalid_typecode(space, u, tc):
    u.raise_exc("bad marshal data (unknown type code %d)" % (ord(tc),))


def _make_unmarshall_and_save_ref(func):
    def unmarshall_save_ref(space, u, tc):
        index = len(u.refs_w)
        u.refs_w.append(None)
        w_obj = func(space, u, tc)
        u.refs_w[index] = w_obj
        return w_obj
    return unmarshall_save_ref

def _make_unmarshaller_dispatch():
    _dispatch = [invalid_typecode] * 256
    for tc, func in get_unmarshallers():
        _dispatch[ord(tc)] = func
    for tc, func in get_unmarshallers():
        if tc < '\x80' and _dispatch[ord(tc) + 0x80] is invalid_typecode:
            _dispatch[ord(tc) + 0x80] = _make_unmarshall_and_save_ref(func)
    return _dispatch


class Unmarshaller(_Base):
    _dispatch = _make_unmarshaller_dispatch()
    hidden_applevel = False

    def __init__(self, space, reader):
        self.space = space
        self.reader = reader
        self.refs_w = []

    def get(self, n):
        assert n >= 0
        return self.reader.read(n)

    def get1(self):
        # the [0] is used to convince the annotator to return a char
        return self.get(1)[0]

    def save_ref(self, typecode, w_obj):
        if typecode >= '\x80':
            self.refs_w.append(w_obj)

    def atom_str(self, typecode):
        self.start(typecode)
        lng = self.get_lng()
        return self.get(lng)

    def atom_lng(self, typecode):
        self.start(typecode)
        return self.get_lng()

    def start(self, typecode):
        tc = self.get1()
        if tc != typecode:
            self.raise_exc('invalid marshal data')

    def get_short(self):
        s = self.get(2)
        a = ord(s[0])
        b = ord(s[1])
        x = a | (b << 8)
        if x & 0x8000:
            x = x - 0x10000
        return x

    def get_int(self):
        s = self.get(4)
        a = ord(s[0])
        b = ord(s[1])
        c = ord(s[2])
        d = ord(s[3])
        if d & 0x80:
            d -= 0x100
        x = a | (b<<8) | (c<<16) | (d<<24)
        return intmask(x)

    def get_lng(self):
        s = self.get(4)
        a = ord(s[0])
        b = ord(s[1])
        c = ord(s[2])
        d = ord(s[3])
        x = a | (b<<8) | (c<<16) | (d<<24)
        if x >= 0:
            return x
        else:
            self.raise_exc('bad marshal data')

    def get_pascal(self):
        lng = ord(self.get1())
        return self.get(lng)

    def get_str(self):
        lng = self.get_lng()
        return self.get(lng)

    def _get_w_obj(self, allow_null=False):
        space = self.space
        tc = self.get1()
        w_ret = self._dispatch[ord(tc)](space, self, tc)
        if w_ret is None and not allow_null:
            raise oefmt(space.w_TypeError, "NULL object in marshal data")
        return w_ret

    def load_w_obj(self, allow_null=False):
        try:
            return self._get_w_obj(allow_null)
        except rstackovf.StackOverflow:
            rstackovf.check_stack_overflow()
            self._overflow()
        except OperationError as e:
            if not e.match(self.space, self.space.w_RecursionError):
                raise
            # somebody else has already converted the rpython overflow error to
            # an OperationError (e.g. one of che space.call* calls in
            # marshal_impl), turn it into a ValueError
            self._overflow()

    def get_tuple_w(self, single_byte_size=False):
        if single_byte_size:
            lng = ord(self.get1())
        else:
            lng = self.get_lng()
        res_w = [None] * lng
        idx = 0
        space = self.space
        w_ret = space.w_None # something not
        while idx < lng:
            res_w[idx] = self.load_w_obj()
            idx += 1
        if w_ret is None:
            raise oefmt(space.w_TypeError, "NULL object in marshal data")
        return res_w

    def _overflow(self):
        self.raise_exc('object too deeply nested to unmarshal')


class StringUnmarshaller(Unmarshaller):
    # Unmarshaller with inlined buffer string
    def __init__(self, space, w_str, hidden_applevel=False):
        Unmarshaller.__init__(self, space, None)
        self.buf = space.readbuf_w(w_str)
        self.bufpos = 0
        self.limit = self.buf.getlength()
        self.hidden_applevel = hidden_applevel

    def raise_eof(self):
        space = self.space
        raise oefmt(space.w_EOFError, "EOF read where object expected")

    def get(self, n):
        pos = self.bufpos
        newpos = pos + n
        if newpos > self.limit:
            self.raise_eof()
        self.bufpos = newpos
        return self.buf.getslice(pos, 1, newpos - pos)

    def get1(self):
        pos = self.bufpos
        if pos >= self.limit:
            self.raise_eof()
        self.bufpos = pos + 1
        return self.buf.getitem(pos)

    def get_int(self):
        pos = self.bufpos
        newpos = pos + 4
        if newpos > self.limit:
            self.raise_eof()
        self.bufpos = newpos
        a = ord(self.buf.getitem(pos))
        b = ord(self.buf.getitem(pos+1))
        c = ord(self.buf.getitem(pos+2))
        d = ord(self.buf.getitem(pos+3))
        if d & 0x80:
            d -= 0x100
        x = a | (b<<8) | (c<<16) | (d<<24)
        return intmask(x)

    def get_lng(self):
        pos = self.bufpos
        newpos = pos + 4
        if newpos > self.limit:
            self.raise_eof()
        self.bufpos = newpos
        a = ord(self.buf.getitem(pos))
        b = ord(self.buf.getitem(pos+1))
        c = ord(self.buf.getitem(pos+2))
        d = ord(self.buf.getitem(pos+3))
        x = a | (b<<8) | (c<<16) | (d<<24)
        if x >= 0:
            return x
        else:
            self.raise_exc('bad marshal data')
