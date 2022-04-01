from rpython.rlib.rarithmetic import LONG_BIT, r_longlong, r_uint
from rpython.rlib.rstring import assert_str0
from rpython.rlib.mutbuffer import MutableStringBuffer
from rpython.rlib.rstruct import ieee
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib import objectmodel

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.special import Ellipsis
from pypy.interpreter.pycode import PyCode
from pypy.interpreter import unicodehelper
from pypy.objspace.std.boolobject import W_BoolObject
from pypy.objspace.std.bytesobject import W_BytesObject
from pypy.objspace.std.complexobject import W_ComplexObject
from pypy.objspace.std.dictmultiobject import W_DictMultiObject
from pypy.objspace.std.intobject import W_IntObject
from pypy.objspace.std.floatobject import W_FloatObject
from pypy.objspace.std.listobject import W_ListObject
from pypy.objspace.std.longobject import W_AbstractLongObject
from pypy.objspace.std.noneobject import W_NoneObject
from pypy.objspace.std.setobject import W_FrozensetObject, W_SetObject
from pypy.objspace.std.tupleobject import W_AbstractTupleObject
from pypy.objspace.std.typeobject import W_TypeObject
from pypy.objspace.std.unicodeobject import W_UnicodeObject


TYPE_NULL      = '0'
TYPE_NONE      = 'N'
TYPE_FALSE     = 'F'
TYPE_TRUE      = 'T'
TYPE_STOPITER  = 'S'
TYPE_ELLIPSIS  = '.'
TYPE_INT       = 'i'
TYPE_FLOAT     = 'f'
TYPE_BINARY_FLOAT = 'g'
TYPE_COMPLEX   = 'x'
TYPE_BINARY_COMPLEX = 'y'
TYPE_LONG      = 'l'
TYPE_STRING    = 's'     # a *byte* string, not unicode
TYPE_INTERNED  = 't'
TYPE_REF       = 'r'
TYPE_TUPLE     = '('
TYPE_LIST      = '['
TYPE_DICT      = '{'
TYPE_CODE      = 'c'
TYPE_UNICODE   = 'u'
TYPE_UNKNOWN   = '?'
TYPE_SET       = '<'
TYPE_FROZENSET = '>'
FLAG_REF       = 0x80    # bit added to mean "add obj to index"
FLAG_DONE      = '\x00'

TYPE_INT64     = 'I'     # no longer generated

# the following typecodes have been added in version 4.
TYPE_ASCII                = 'a'
TYPE_ASCII_INTERNED       = 'A'
TYPE_SMALL_TUPLE          = ')'
TYPE_SHORT_ASCII          = 'z'
TYPE_SHORT_ASCII_INTERNED = 'Z'


_marshallers = []
_unmarshallers = []

def marshaller(type):
    def _decorator(f):
        _marshallers.append((type, f))
        return f
    return _decorator

def unmarshaller(tc, save_ref=False):
    def _decorator(f):
        assert tc < '\x80'
        _unmarshallers.append((tc, f))
        if save_ref:
            tcref = chr(ord(tc) + 0x80)
            _unmarshallers.append((tcref, f))
        return f
    return _decorator

def write_ref(typecode, w_obj, m):
    if m.version < 3:
        return typecode     # not writing object references
    try:
        index = m.all_refs[w_obj]
    except KeyError:
        # we don't support long indices
        index = len(m.all_refs)
        if index >= 0x7fffffff:
            return typecode
        m.all_refs[w_obj] = index
        return chr(ord(typecode) + FLAG_REF)
    else:
        # write the reference index to the stream
        m.atom_int(TYPE_REF, index)
        return FLAG_DONE

def marshal(space, w_obj, m):
    # _marshallers_unroll is defined at the end of the file
    # NOTE that if w_obj is a heap type, like an instance of a
    # user-defined subclass, then we skip that part completely!
    if not space.type(w_obj).is_heaptype():
        for type, func in _marshallers_unroll:
            if isinstance(w_obj, type):
                func(space, w_obj, m)
                return

    # any unknown object implementing the buffer protocol is
    # accepted and encoded as a plain string
    try:
        s = space.readbuf_w(w_obj)
    except OperationError as e:
        if e.match(space, space.w_TypeError):
            raise oefmt(space.w_ValueError, "unmarshallable object")
        raise
    typecode = write_ref(TYPE_STRING, w_obj, m)
    if typecode != FLAG_DONE:
        m.atom_str(typecode, s.as_str())

def get_unmarshallers():
    return _unmarshallers


@marshaller(W_NoneObject)
def marshal_none(space, w_none, m):
    m.atom(TYPE_NONE)

@unmarshaller(TYPE_NONE)
def unmarshal_none(space, u, tc):
    return space.w_None


@marshaller(W_BoolObject)
def marshal_bool(space, w_bool, m):
    m.atom(TYPE_TRUE if w_bool.intval else TYPE_FALSE)

@unmarshaller(TYPE_TRUE)
def unmarshal_bool(space, u, tc):
    return space.w_True

@unmarshaller(TYPE_FALSE)
def unmarshal_false(space, u, tc):
    return space.w_False


@marshaller(W_TypeObject)
def marshal_stopiter(space, w_type, m):
    if not space.is_w(w_type, space.w_StopIteration):
        raise oefmt(space.w_ValueError, "unmarshallable object")
    m.atom(TYPE_STOPITER)

@unmarshaller(TYPE_STOPITER)
def unmarshal_stopiter(space, u, tc):
    return space.w_StopIteration


@marshaller(Ellipsis)
def marshal_ellipsis(space, w_ellipsis, m):
    m.atom(TYPE_ELLIPSIS)

@unmarshaller(TYPE_ELLIPSIS)
def unmarshal_ellipsis(space, u, tc):
    return space.w_Ellipsis


@marshaller(W_IntObject)
def marshal_int(space, w_int, m):
    y = w_int.intval >> 31
    if y and y != -1:
        marshal_long(space, w_int, m)
    else:
        m.atom_int(TYPE_INT, w_int.intval)

@unmarshaller(TYPE_INT)
def unmarshal_int(space, u, tc):
    return space.newint(u.get_int())

@unmarshaller(TYPE_INT64)
def unmarshal_int64(space, u, tc):
    from rpython.rlib.rbigint import rbigint
    # no longer generated, but we still support unmarshalling
    lo = u.get_int()    # get the first 32 bits
    hi = u.get_int()    # get the next 32 bits
    if LONG_BIT >= 64:
        x = (hi << 32) | (lo & (2**32-1))    # result fits in an int
        return space.newint(x)
    else:
        x = (r_longlong(hi) << 32) | r_longlong(r_uint(lo))  # get a r_longlong
        result = rbigint.fromrarith_int(x)
        return space.newlong_from_rbigint(result)


@marshaller(W_AbstractLongObject)
def marshal_long(space, w_long, m):
    from rpython.rlib.rarithmetic import r_ulonglong
    typecode = write_ref(TYPE_LONG, w_long, m)
    if typecode == FLAG_DONE:
        return
    m.start(typecode)
    SHIFT = 15
    MASK = (1 << SHIFT) - 1
    num = space.bigint_w(w_long)
    sign = num.sign
    num = num.abs()
    total_length = (num.bit_length() + (SHIFT - 1)) / SHIFT
    m.put_int(total_length * sign)
    bigshiftcount = r_ulonglong(0)
    for i in range(total_length):
        next = num.abs_rshift_and_mask(bigshiftcount, MASK)
        m.put_short(next)
        bigshiftcount += SHIFT

@unmarshaller(TYPE_LONG)
def unmarshal_long(space, u, tc):
    from rpython.rlib.rbigint import rbigint
    lng = u.get_int()
    if lng < 0:
        negative = True
        lng = -lng
    else:
        negative = False
    digits = [u.get_short() for i in range(lng)]
    result = rbigint.from_list_n_bits(digits, 15)
    if lng and not result.tobool():
        raise oefmt(space.w_ValueError, "bad marshal data")
    if negative:
        result = result.neg()
    # try to fit it into an int
    try:
        return space.newint(result.toint())
    except OverflowError:
        return space.newlong_from_rbigint(result)


def pack_float(f):
    buf = MutableStringBuffer(8)
    ieee.pack_float(buf, 0, f, 8, False)
    return buf.finish()

def unpack_float(s):
    return ieee.unpack_float(s, False)

@marshaller(W_FloatObject)
def marshal_float(space, w_float, m):
    if m.version > 1:
        m.start(TYPE_BINARY_FLOAT)
        m.put(pack_float(w_float.floatval))
    else:
        m.start(TYPE_FLOAT)
        m.put_pascal(space.text_w(space.repr(w_float)))

@unmarshaller(TYPE_FLOAT)
def unmarshal_float(space, u, tc):
    return space.call_function(space.builtin.get('float'),
                               space.newtext(u.get_pascal()))

@unmarshaller(TYPE_BINARY_FLOAT)
def unmarshal_float_bin(space, u, tc):
    return space.newfloat(unpack_float(u.get(8)))


@marshaller(W_ComplexObject)
def marshal_complex(space, w_complex, m):
    if m.version > 1:
        m.start(TYPE_BINARY_COMPLEX)
        m.put(pack_float(w_complex.realval))
        m.put(pack_float(w_complex.imagval))
    else:
        w_real = space.newfloat(w_complex.realval)
        w_imag = space.newfloat(w_complex.imagval)
        m.start(TYPE_COMPLEX)
        m.put_pascal(space.text_w(space.repr(w_real)))
        m.put_pascal(space.text_w(space.repr(w_imag)))

@unmarshaller(TYPE_COMPLEX)
def unmarshal_complex(space, u, tc):
    w_real = space.call_function(space.builtin.get('float'),
                                 space.newtext(u.get_pascal()))
    w_imag = space.call_function(space.builtin.get('float'),
                                 space.newtext(u.get_pascal()))
    w_t = space.builtin.get('complex')
    return space.call_function(w_t, w_real, w_imag)

@unmarshaller(TYPE_BINARY_COMPLEX)
def unmarshal_complex_bin(space, u, tc):
    real = unpack_float(u.get(8))
    imag = unpack_float(u.get(8))
    return space.newcomplex(real, imag)


@marshaller(W_BytesObject)
def marshal_bytes(space, w_str, m):
    typecode = write_ref(TYPE_STRING, w_str, m)
    if typecode != FLAG_DONE:
        s = space.bytes_w(w_str)
        m.atom_str(typecode, s)

@unmarshaller(TYPE_STRING)
def unmarshal_bytes(space, u, tc):
    return space.newbytes(u.get_str())


def _marshal_tuple(space, tuple_w, m):
    if m.version >= 4 and len(tuple_w) < 256:
        typecode = TYPE_SMALL_TUPLE
        single_byte_size = True
    else:
        typecode = TYPE_TUPLE
        single_byte_size = False
    # -- does it make any sense to try to share tuples, based on the
    # -- *identity* of the tuple object?  I'd guess not really
    #typecode = write_ref(typecode, w_tuple, m)
    #if typecode != FLAG_DONE:
    m.put_tuple_w(typecode, tuple_w, single_byte_size=single_byte_size)

@marshaller(W_AbstractTupleObject)
def marshal_tuple(space, w_tuple, m):
    _marshal_tuple(space, w_tuple.tolist(), m)

@unmarshaller(TYPE_TUPLE)
def unmarshal_tuple(space, u, tc):
    items_w = u.get_tuple_w()
    return space.newtuple(items_w)

@unmarshaller(TYPE_SMALL_TUPLE)
def unmarshal_tuple(space, u, tc):
    items_w = u.get_tuple_w(single_byte_size=True)
    return space.newtuple(items_w)


@marshaller(W_ListObject)
def marshal_list(space, w_list, m):
    typecode = write_ref(TYPE_LIST, w_list, m)
    if typecode != FLAG_DONE:
        items = w_list.getitems()[:]
        m.put_tuple_w(typecode, items)

@unmarshaller(TYPE_LIST, save_ref=True)
def unmarshal_list(space, u, tc):
    w_obj = space.newlist([])
    u.save_ref(tc, w_obj)
    for w_item in u.get_tuple_w():
        w_obj.append(w_item)
    return w_obj


@marshaller(W_DictMultiObject)
def marshal_dict(space, w_dict, m):
    typecode = write_ref(TYPE_DICT, w_dict, m)
    if typecode == FLAG_DONE:
        return
    m.start(typecode)
    for w_tuple in w_dict.items():
        w_key, w_value = space.fixedview(w_tuple, 2)
        m.put_w_obj(w_key)
        m.put_w_obj(w_value)
    m.atom(TYPE_NULL)

@unmarshaller(TYPE_DICT, save_ref=True)
def unmarshal_dict(space, u, tc):
    # since primitive lists are not optimized and we don't know
    # the dict size in advance, use the dict's setitem instead
    # of building a list of tuples.
    w_dic = space.newdict()
    u.save_ref(tc, w_dic)
    while 1:
        w_key = u.load_w_obj(allow_null=True)
        if w_key is None:
            break
        w_value = u.load_w_obj()
        space.setitem(w_dic, w_key, w_value)
    return w_dic

@unmarshaller(TYPE_NULL)
def unmarshal_NULL(self, u, tc):
    return None


@marshaller(PyCode)
def marshal_pycode(space, w_pycode, m):
    # (no attempt at using write_ref here, there is little point imho)
    m.start(TYPE_CODE)
    # see pypy.interpreter.pycode for the layout
    x = space.interp_w(PyCode, w_pycode)
    m.put_int(x.co_argcount)
    m.put_int(x.co_posonlyargcount)
    m.put_int(x.co_kwonlyargcount)
    m.put_int(x.co_nlocals)
    m.put_int(x.co_stacksize)
    m.put_int(x.co_flags)
    m.atom_str(TYPE_STRING, x.co_code)
    _marshal_tuple(space, x.co_consts_w, m)
    _marshal_tuple(space, x.co_names_w, m)   # list of w_unicodes
    co_varnames_w = [space.newtext(*_decode_utf8(space, s)) for s in x.co_varnames]
    co_freevars_w = [space.newtext(*_decode_utf8(space, s)) for s in x.co_freevars]
    co_cellvars_w = [space.newtext(*_decode_utf8(space, s)) for s in x.co_cellvars]
    _marshal_tuple(space, co_varnames_w, m)  # more lists, now of w_unicodes
    _marshal_tuple(space, co_freevars_w, m)
    _marshal_tuple(space, co_cellvars_w, m)
    marshal(space, x.w_filename, m)
    _marshal_unicode(space, x.co_name, m)
    m.put_int(x.co_firstlineno)
    m.atom_str(TYPE_STRING, x.co_lnotab)

# helper for unmarshalling "tuple of string" objects
# into rpython-level lists of strings.  Only for code objects.

def _unmarshal_strlist(u):
    items_w = _unmarshal_tuple_w(u)
    return [u.space.utf8_w(w_item) for w_item in items_w]

def _unmarshal_tuple_w(u):
    w_obj = u.load_w_obj()
    try:
        return u.space.fixedview(w_obj)
    except OperationError as e:
        if e.match(u.space, u.space.w_TypeError):
            u.raise_exc('invalid marshal data for code object')
        raise

@unmarshaller(TYPE_CODE, save_ref=True)
def unmarshal_pycode(space, u, tc):
    w_codeobj = objectmodel.instantiate(PyCode)
    u.save_ref(tc, w_codeobj)
    argcount    = u.get_int()
    posonlyargcount = u.get_int()
    kwonlyargcount = u.get_int()
    nlocals     = u.get_int()
    stacksize   = u.get_int()
    flags       = u.get_int()
    code        = space.bytes_w(u.load_w_obj())
    consts_w    = _unmarshal_tuple_w(u)
    names       = _unmarshal_strlist(u)
    varnames    = _unmarshal_strlist(u)
    freevars    = _unmarshal_strlist(u)
    cellvars    = _unmarshal_strlist(u)
    w_fn = u.load_w_obj()
    filename    = space.bytes0_w(space.fsencode(w_fn))

    name        = space.utf8_w(u.load_w_obj())
    firstlineno = u.get_int()
    lnotab      = space.bytes_w(u.load_w_obj())
    filename = assert_str0(filename)
    PyCode.__init__(w_codeobj,
                  space, argcount, posonlyargcount, kwonlyargcount, nlocals, stacksize, flags,
                  code, consts_w[:], names, varnames, filename,
                  name, firstlineno, lnotab, freevars, cellvars,
                  hidden_applevel=u.hidden_applevel)
    return w_codeobj

def _marshal_ascii_unicode(space, s, m, w_unicode, w_interned):
    # determine typecode
    if len(s) < 256:
        is_short = True
        if w_interned is not None:
            typecode = TYPE_SHORT_ASCII_INTERNED
        else:
            typecode = TYPE_SHORT_ASCII
    else:
        is_short = False
        if w_interned is not None:
            typecode = TYPE_ASCII_INTERNED
        else:
            typecode = TYPE_ASCII
    # use ref
    if w_unicode is not None:
        typecode = write_ref(typecode, w_unicode, m)
        if typecode == FLAG_DONE:
            return
    # write
    m.start(typecode)
    if is_short:
        m.put(chr(len(s)))
    else:
        m.put_int(len(s))
    m.put(s)

def _marshal_unicode(space, s, m, w_unicode=None):
    from rpython.rlib import rutf8
    if m.version >= 3:
        w_interned = space.get_interned_str(s)
    else:
        w_interned = None
    if w_interned is not None:
        w_unicode = w_interned    # use the interned W_UnicodeObject
        typecode = TYPE_INTERNED  #   as a key for u.all_refs
    else:
        typecode = TYPE_UNICODE
    if m.version >= 4:
        # check whether it's ascii
        if w_unicode is not None:
            is_ascii = w_unicode.is_ascii()
        else:
            is_ascii = len(s) == rutf8.check_utf8(s, True)
        if is_ascii:
            _marshal_ascii_unicode(space, s, m, w_unicode, w_interned)
            return
    # general case, write unicode
    if w_unicode is not None:
        typecode = write_ref(typecode, w_unicode, m)
        if typecode == FLAG_DONE:
            return
    m.atom_str(typecode, s)

# surrogate-preserving variants
_decode_utf8 = unicodehelper.decode_utf8sp

@marshaller(W_UnicodeObject)
def marshal_unicode(space, w_unicode, m):
    s = space.utf8_w(w_unicode)
    _marshal_unicode(space, s, m, w_unicode=w_unicode)

@unmarshaller(TYPE_UNICODE)
def unmarshal_unicode(space, u, tc):
    uc = _decode_utf8(space, u.get_str())
    return space.newtext(*uc)

@unmarshaller(TYPE_INTERNED)
def unmarshal_interned(space, u, tc):
    w_ret = unmarshal_unicode(space, u, tc)
    return u.space.new_interned_w_str(w_ret)

def _unmarshal_ascii(u, short_length, interned):
    from rpython.rlib import rutf8
    if short_length:
        lng = ord(u.get1())
    else:
        lng = u.get_lng()
    s = u.get(lng)
    w_u = u.space.newtext(s, len(s)) # ascii is valid utf-8
    return w_u

@unmarshaller(TYPE_ASCII)
def unmarshal_ascii(space, u, tc):
    return _unmarshal_ascii(u, False, False)
@unmarshaller(TYPE_ASCII_INTERNED)
def unmarshal_ascii(space, u, tc):
    return _unmarshal_ascii(u, False, True)
@unmarshaller(TYPE_SHORT_ASCII)
def unmarshal_ascii(space, u, tc):
    return _unmarshal_ascii(u, True, False)
@unmarshaller(TYPE_SHORT_ASCII_INTERNED)
def unmarshal_ascii(space, u, tc):
    return _unmarshal_ascii(u, True, True)


@marshaller(W_SetObject)
def marshal_set(space, w_set, m):
    typecode = write_ref(TYPE_SET, w_set, m)
    if typecode != FLAG_DONE:
        lis_w = space.fixedview(w_set)
        m.put_tuple_w(typecode, lis_w)

@unmarshaller(TYPE_SET, save_ref=True)
def unmarshal_set(space, u, tc):
    w_set = space.call_function(space.w_set)
    u.save_ref(tc, w_set)
    _unmarshal_set_frozenset(space, u, w_set)
    return w_set


@marshaller(W_FrozensetObject)
def marshal_frozenset(space, w_frozenset, m):
    typecode = write_ref(TYPE_FROZENSET, w_frozenset, m)
    if typecode != FLAG_DONE:
        lis_w = space.fixedview(w_frozenset)
        m.put_tuple_w(typecode, lis_w)

def _unmarshal_set_frozenset(space, u, w_set):
    lng = u.get_lng()
    for i in xrange(lng):
        w_obj = u.load_w_obj()
        space.call_method(w_set, "add", w_obj)

@unmarshaller(TYPE_FROZENSET)
def unmarshal_frozenset(space, u, tc):
    w_set = space.call_function(space.w_set)
    _unmarshal_set_frozenset(space, u, w_set)
    return space.call_function(space.w_frozenset, w_set)


@unmarshaller(TYPE_REF)
def unmarshal_ref(space, u, tc):
    index = u.get_lng()
    if 0 <= index < len(u.refs_w):
        w_obj = u.refs_w[index]
    else:
        w_obj = None
    if w_obj is None:
        raise oefmt(space.w_ValueError, "bad marshal data (invalid reference)")
    return w_obj


_marshallers_unroll = unrolling_iterable(_marshallers)
