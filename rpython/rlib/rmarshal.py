"""A way to serialize data in the same format as the 'marshal' module
but accessible to RPython programs.
"""

from rpython.annotator import model as annmodel
from rpython.annotator.signature import annotation
from rpython.annotator.listdef import ListDef, TooLateForChange
from rpython.tool.pairtype import pair, pairtype
from rpython.rlib.rarithmetic import r_longlong, intmask, LONG_BIT, ovfcheck
from rpython.rlib.rfloat import formatd, rstring_to_float
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.rstring import assert_str0

class CannotMarshal(Exception):
    pass

class CannotUnmarshall(Exception):
    pass

def get_marshaller(type):
    """Return a marshaller function.
    The marshaller takes two arguments: a buffer and an object of
    type 'type'. The buffer is list of characters that gets extended
    with new data when the marshaller is called.
    """
    s_obj = annotation(type, None)
    try:
        # look for a marshaller in the 'dumpers' list
        return find_dumper(s_obj)
    except CannotMarshal:
        # ask the annotation to produce an appropriate dumper
        pair(_tag, s_obj).install_marshaller()
        return find_dumper(s_obj)
get_marshaller._annspecialcase_ = 'specialize:memo'

def get_loader(type):
    s_obj = annotation(type, None)
    try:
        # look for a marshaller in the 'loaders' list
        return find_loader(s_obj)
    except CannotUnmarshall:
        # ask the annotation to produce an appropriate loader
        pair(_tag, s_obj).install_unmarshaller()
        return find_loader(s_obj)

def get_unmarshaller(type):
    """Return an unmarshaller function.
    The unmarshaller takes a string as argument, and return an object
    of type 'type'.  It raises ValueError if the marshalled data is
    invalid or contains an object of a different type.
    """
    loaditem = get_loader(type)
    # wrap the loaditem into a more convenient interface
    try:
        return _unmarshaller_cache[loaditem]
    except KeyError:
        def unmarshaller(buf):
            loader = Loader(buf)
            result = loaditem(loader)
            loader.check_finished()
            return result
        _unmarshaller_cache[loaditem] = unmarshaller
        return unmarshaller
get_unmarshaller._annspecialcase_ = 'specialize:memo'
_unmarshaller_cache = {}

# ____________________________________________________________
#
# Dumpers and loaders

TYPE_NONE     = 'N'
TYPE_FALSE    = 'F'
TYPE_TRUE     = 'T'
TYPE_INT      = 'i'
TYPE_INT64    = 'I'
TYPE_FLOAT    = 'f'
TYPE_STRING   = 's'
TYPE_TUPLE    = '('
TYPE_LIST     = '['
TYPE_DICT     = '{'

dumpers = []
loaders = []
s_list_of_chars = annmodel.SomeList(ListDef(None, annmodel.SomeChar(),
                                            mutated=True, resized=True))

def add_dumper(s_obj, dumper):
    dumpers.append((s_obj, dumper))
    dumper.s_obj = s_obj
    dumper._annenforceargs_ = [s_list_of_chars, s_obj]

def add_loader(s_obj, loader):
    # 's_obj' should be the **least general annotation** that we're
    # interested in, somehow
    loaders.append((s_obj, loader))

def get_dumper_annotation(dumper):
    return dumper.s_obj

def find_dumper(s_obj):
    # select a suitable dumper - the condition is that the dumper must
    # accept an input that is at least as general as the requested s_obj
    for s_cond, dumper in dumpers:
        if weakly_contains(s_cond, s_obj):
            return dumper
    raise CannotMarshal(s_obj)

def find_loader(s_obj):
    # select a suitable loader - note that we need more loaders than
    # dumpers in general, because the condition is that the loader should
    # return something that is contained within the requested s_obj
    for s_cond, loader in loaders[::-1]:
        if s_obj.contains(s_cond):
            return loader
    if s_obj == annmodel.s_None:
        return load_none
    raise CannotUnmarshall(s_obj)

def w_long(buf, x):
    buf.append(chr(x & 0xff))
    x >>= 8
    buf.append(chr(x & 0xff))
    x >>= 8
    buf.append(chr(x & 0xff))
    x >>= 8
    buf.append(chr(x & 0xff))
w_long._annenforceargs_ = [None, int]

def dump_none(buf, x):
    buf.append(TYPE_NONE)
add_dumper(annmodel.s_None, dump_none)

def load_none(loader):
    if readchr(loader) != TYPE_NONE:
        raise ValueError("expected a None")
    return None
#add_loader(annmodel.s_None, load_none) -- cannot install it as a regular
# loader, because it will also match any annotation that can be None

def dump_bool(buf, x):
    if x:
        buf.append(TYPE_TRUE)
    else:
        buf.append(TYPE_FALSE)
add_dumper(annmodel.s_Bool, dump_bool)

def load_bool(loader):
    t = readchr(loader)
    if t == TYPE_TRUE:
        return True
    elif t == TYPE_FALSE:
        return False
    else:
        raise ValueError("expected a bool")
add_loader(annmodel.s_Bool, load_bool)

def dump_int(buf, x):
    # only use TYPE_INT on 32-bit platforms
    if LONG_BIT > 32:
        dump_longlong(buf, r_longlong(x))
    else:
        buf.append(TYPE_INT)
        w_long(buf, x)
add_dumper(annmodel.SomeInteger(), dump_int)

def load_int_nonneg(loader):
    x = load_int(loader)
    if x < 0:
        raise ValueError("expected a non-negative int")
    return x
add_loader(annmodel.SomeInteger(nonneg=True), load_int_nonneg)

def load_int(loader):
    r = readchr(loader)
    if LONG_BIT > 32 and r == TYPE_INT64:
        x = readlong(loader) & 0xFFFFFFFF
        x |= readlong(loader) << 32
        return x
    if r == TYPE_INT:
        return readlong(loader)
    raise ValueError("expected an int")
add_loader(annmodel.SomeInteger(), load_int)

def dump_longlong(buf, x):
    buf.append(TYPE_INT64)
    w_long(buf, intmask(x))
    w_long(buf, intmask(x>>32))
add_dumper(annotation(r_longlong), dump_longlong)

r_32bits_mask = r_longlong(0xFFFFFFFF)

def load_longlong_nonneg(loader):
    x = load_longlong(loader)
    if x < 0:
        raise ValueError("expected a non-negative longlong")
    return x
add_loader(annmodel.SomeInteger(knowntype=r_longlong, nonneg=True),
           load_longlong_nonneg)

def load_longlong(loader):
    if readchr(loader) != TYPE_INT64:
        raise ValueError("expected a longlong")
    x = r_longlong(readlong(loader)) & r_32bits_mask
    x |= (r_longlong(readlong(loader)) << 32)
    return x
add_loader(annotation(r_longlong), load_longlong)

def dump_float(buf, x):
    buf.append(TYPE_FLOAT)
    s = formatd(x, 'g', 17)
    buf.append(chr(len(s)))
    buf += s
add_dumper(annmodel.SomeFloat(), dump_float)

def load_float(loader):
    if readchr(loader) != TYPE_FLOAT:
        raise ValueError("expected a float")
    length = ord(readchr(loader))
    s = readstr(loader, length)
    return rstring_to_float(s)
add_loader(annmodel.SomeFloat(), load_float)

def dump_string_or_none(buf, x):
    if x is None:
        dump_none(buf, x)
    else:
        buf.append(TYPE_STRING)
        w_long(buf, len(x))
        buf += x
add_dumper(annmodel.SomeString(can_be_None=True), dump_string_or_none)

def load_single_char(loader):
    if readchr(loader) != TYPE_STRING or readlong(loader) != 1:
        raise ValueError("expected a character")
    return readchr(loader)
add_loader(annmodel.SomeChar(), load_single_char)

def load_string_nonul(loader):
    if readchr(loader) != TYPE_STRING:
        raise ValueError("expected a string")
    length = readlong(loader)
    return assert_str0(readstr(loader, length))
add_loader(annmodel.SomeString(can_be_None=False, no_nul=True),
           load_string_nonul)

def load_string(loader):
    if readchr(loader) != TYPE_STRING:
        raise ValueError("expected a string")
    length = readlong(loader)
    return readstr(loader, length)
add_loader(annmodel.SomeString(can_be_None=False, no_nul=False),
           load_string)

def load_string_or_none_nonul(loader):
    t = readchr(loader)
    if t == TYPE_STRING:
        length = readlong(loader)
        return assert_str0(readstr(loader, length))
    elif t == TYPE_NONE:
        return None
    else:
        raise ValueError("expected a string or None")
add_loader(annmodel.SomeString(can_be_None=True, no_nul=True),
           load_string_or_none_nonul)

def load_string_or_none(loader):
    t = readchr(loader)
    if t == TYPE_STRING:
        length = readlong(loader)
        return readstr(loader, length)
    elif t == TYPE_NONE:
        return None
    else:
        raise ValueError("expected a string or None")
add_loader(annmodel.SomeString(can_be_None=True, no_nul=False),
           load_string_or_none)

# ____________________________________________________________
#
# Loader support class

class Loader(object):

    def __init__(self, buf):
        self.buf = buf
        self.pos = 0

    def check_finished(self):
        if self.pos != len(self.buf):
            raise ValueError("not all data consumed")

    def need_more_data(self):
        raise ValueError("not enough data")    # can be overridden

# the rest are not method on the Loader class, because it causes troubles
# in rpython.translator.rsandbox if new methods are discovered after some
# sandboxed-enabled graphs are produced
def readstr(loader, count):
    if count < 0:
        raise ValueError("negative count")
    pos = loader.pos
    try:
        end = ovfcheck(pos + count)
    except OverflowError:
        raise ValueError("cannot decode count: value too big")
    while end > len(loader.buf):
        loader.need_more_data()
    loader.pos = end
    return loader.buf[pos:end]
readstr._annenforceargs_ = [None, int]

def readchr(loader):
    pos = loader.pos
    while pos >= len(loader.buf):
        loader.need_more_data()
    loader.pos = pos + 1
    return loader.buf[pos]

def peekchr(loader):
    pos = loader.pos
    while pos >= len(loader.buf):
        loader.need_more_data()
    return loader.buf[pos]

def readlong(loader):
    a = ord(readchr(loader))
    b = ord(readchr(loader))
    c = ord(readchr(loader))
    d = ord(readchr(loader))
    if d >= 0x80:
        d -= 0x100
    return a | (b<<8) | (c<<16) | (d<<24)

# ____________________________________________________________
#
# Annotations => dumpers and loaders

class MTag(object):
    """Tag for pairtype(), for the purpose of making the get_marshaller()
    and get_unmarshaller() methods of SomeObject only locally visible."""
_tag = MTag()

def weakly_contains(s_bigger, s_smaller):
    # a special version of s_bigger.contains(s_smaller).  Warning, to
    # support ListDefs properly, this works by trying to produce a side-effect
    # on s_bigger.  It relies on the fact that s_bigger was created with
    # an expression like 'annotation([s_item])' which returns a ListDef with
    # no bookkeeper, on which side-effects are not allowed.
    saved = annmodel.TLS.allow_int_to_float
    try:
        annmodel.TLS.allow_int_to_float = False
        s_union = annmodel.unionof(s_bigger, s_smaller)
        return s_bigger.contains(s_union)
    except (annmodel.UnionError, TooLateForChange):
        return False
    finally:
        annmodel.TLS.allow_int_to_float = saved


class __extend__(pairtype(MTag, annmodel.SomeObject)):

    def install_marshaller((tag, s_obj)):
        if not hasattr(s_obj, '_get_rmarshall_support_'):
            raise CannotMarshal(s_obj)
        # special support for custom annotation like SomeStatResult:
        # the annotation tells us how to turn an object into something
        # else that can be marshalled
        def dump_with_custom_reduce(buf, x):
            reduced_obj = fn_reduce(x)
            reduceddumper(buf, reduced_obj)
        s_reduced_obj, fn_reduce, fn_recreate = s_obj._get_rmarshall_support_()
        reduceddumper = get_marshaller(s_reduced_obj)
        add_dumper(s_obj, dump_with_custom_reduce)

    def install_unmarshaller((tag, s_obj)):
        if not hasattr(s_obj, '_get_rmarshall_support_'):
            raise CannotUnmarshall(s_obj)
        # special support for custom annotation like SomeStatResult
        def load_with_custom_recreate(loader):
            reduced_obj = reducedloader(loader)
            return fn_recreate(reduced_obj)
        s_reduced_obj, fn_reduce, fn_recreate = s_obj._get_rmarshall_support_()
        reducedloader = get_loader(s_reduced_obj)
        add_loader(s_obj, load_with_custom_recreate)


class __extend__(pairtype(MTag, annmodel.SomeList)):

    def install_marshaller((tag, s_list)):
        def dump_list_or_none(buf, x):
            if x is None:
                dump_none(buf, x)
            else:
                buf.append(TYPE_LIST)
                w_long(buf, len(x))
                for item in x:
                    itemdumper(buf, item)

        itemdumper = get_marshaller(s_list.listdef.listitem.s_value)
        if s_list.listdef.listitem.dont_change_any_more:
            s_general_list = s_list
        else:
            s_item = get_dumper_annotation(itemdumper)
            s_general_list = annotation([s_item])
        add_dumper(s_general_list, dump_list_or_none)

    def install_unmarshaller((tag, s_list)):
        def load_list_or_none(loader):
            t = readchr(loader)
            if t == TYPE_LIST:
                length = readlong(loader)
                result = []
                for i in range(length):
                    result.append(itemloader(loader))
                return result
            elif t == TYPE_NONE:
                return None
            else:
                raise ValueError("expected a list or None")

        itemloader = get_loader(s_list.listdef.listitem.s_value)
        add_loader(s_list, load_list_or_none)


class __extend__(pairtype(MTag, annmodel.SomeDict)):

    def install_marshaller((tag, s_dict)):
        def dump_dict_or_none(buf, x):
            if x is None:
                dump_none(buf, x)
            else:
                buf.append(TYPE_DICT)
                for key, value in x.items():
                    keydumper(buf, key)
                    valuedumper(buf, value)
                buf.append('0')    # end of dict

        keydumper = get_marshaller(s_dict.dictdef.dictkey.s_value)
        valuedumper = get_marshaller(s_dict.dictdef.dictvalue.s_value)
        if (s_dict.dictdef.dictkey.dont_change_any_more or
            s_dict.dictdef.dictvalue.dont_change_any_more):
            s_general_dict = s_dict
        else:
            s_key = get_dumper_annotation(keydumper)
            s_value = get_dumper_annotation(valuedumper)
            s_general_dict = annotation({s_key: s_value})
        add_dumper(s_general_dict, dump_dict_or_none)

    def install_unmarshaller((tag, s_dict)):
        def load_dict_or_none(loader):
            t = readchr(loader)
            if t == TYPE_DICT:
                result = {}
                while peekchr(loader) != '0':
                    key = keyloader(loader)
                    value = valueloader(loader)
                    result[key] = value
                readchr(loader)   # consume the final '0'
                return result
            elif t == TYPE_NONE:
                return None
            else:
                raise ValueError("expected a dict or None")

        keyloader = get_loader(s_dict.dictdef.dictkey.s_value)
        valueloader = get_loader(s_dict.dictdef.dictvalue.s_value)
        add_loader(s_dict, load_dict_or_none)


class __extend__(pairtype(MTag, annmodel.SomeTuple)):

    def install_marshaller((tag, s_tuple)):
        def dump_tuple(buf, x):
            buf.append(TYPE_TUPLE)
            w_long(buf, len(x))
            for i, itemdumper in unroll_item_dumpers:
                itemdumper(buf, x[i])

        itemdumpers = [get_marshaller(s_item) for s_item in s_tuple.items]
        unroll_item_dumpers = unrolling_iterable(enumerate(itemdumpers))
        dumper_annotations = [get_dumper_annotation(itemdumper)
                              for itemdumper in itemdumpers]
        s_general_tuple = annmodel.SomeTuple(dumper_annotations)
        add_dumper(s_general_tuple, dump_tuple)

    def install_unmarshaller((tag, s_tuple)):
        def load_tuple(loader):
            if readchr(loader) != TYPE_TUPLE:
                raise ValueError("expected a tuple")
            if readlong(loader) != expected_length:
                raise ValueError("wrong tuple length")
            result = ()
            for i, itemloader in unroll_item_loaders:
                result += (itemloader(loader),)
            return result

        itemloaders = [get_loader(s_item) for s_item in s_tuple.items]
        expected_length = len(itemloaders)
        unroll_item_loaders = unrolling_iterable(enumerate(itemloaders))
        add_loader(s_tuple, load_tuple)
