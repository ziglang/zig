from collections import OrderedDict

from rpython.annotator import model as annmodel
from rpython.flowspace.model import Constant
from rpython.rlib import rarithmetic, objectmodel
from rpython.rtyper import raddress, rptr, extregistry, rrange
from rpython.rtyper.error import TyperError
from rpython.rtyper.lltypesystem import lltype, llmemory, rstr
from rpython.rtyper import rclass
from rpython.rtyper.rmodel import Repr
from rpython.tool.pairtype import pairtype


BUILTIN_TYPER = {}

def typer_for(func):
    def wrapped(rtyper_func):
        BUILTIN_TYPER[func] = rtyper_func
        return rtyper_func
    return wrapped


class __extend__(annmodel.SomeBuiltin):
    def rtyper_makerepr(self, rtyper):
        if not self.is_constant():
            raise TyperError("non-constant built-in function!")
        return BuiltinFunctionRepr(self.const)

    def rtyper_makekey(self):
        const = getattr(self, 'const', None)
        if extregistry.is_registered(const):
            const = extregistry.lookup(const)
        return self.__class__, const

class __extend__(annmodel.SomeBuiltinMethod):
    def rtyper_makerepr(self, rtyper):
        assert self.methodname is not None
        result = BuiltinMethodRepr(rtyper, self.s_self, self.methodname)
        return result

    def rtyper_makekey(self):
        # NOTE: we hash by id of self.s_self here.  This appears to be
        # necessary because it ends up in hop.args_s[0] in the method call,
        # and there is no telling what information the called
        # rtype_method_xxx() will read from that hop.args_s[0].
        # See test_method_join in test_rbuiltin.
        # There is no problem with self.s_self being garbage-collected and
        # its id reused, because the BuiltinMethodRepr keeps a reference
        # to it.
        return (self.__class__, self.methodname, id(self.s_self))

def call_args_expand(hop):
    hop = hop.copy()
    from rpython.annotator.argument import ArgumentsForTranslation
    arguments = ArgumentsForTranslation.fromshape(
            hop.args_s[1].const, # shape
            range(hop.nb_args-2))
    assert arguments.w_stararg is None
    keywords = arguments.keywords
    # prefix keyword arguments with 'i_'
    kwds_i = {}
    for key in keywords:
        kwds_i['i_' + key] = keywords[key]
    return hop, kwds_i


class BuiltinFunctionRepr(Repr):
    lowleveltype = lltype.Void

    def __init__(self, builtinfunc):
        self.builtinfunc = builtinfunc

    def findbltintyper(self, rtyper):
        "Find the function to use to specialize calls to this built-in func."
        try:
            return BUILTIN_TYPER[self.builtinfunc]
        except (KeyError, TypeError):
            pass
        if extregistry.is_registered(self.builtinfunc):
            entry = extregistry.lookup(self.builtinfunc)
            return entry.specialize_call
        raise TyperError("don't know about built-in function %r" % (
            self.builtinfunc,))

    def _call(self, hop2, **kwds_i):
        bltintyper = self.findbltintyper(hop2.rtyper)
        hop2.llops._called_exception_is_here_or_cannot_occur = False
        v_result = bltintyper(hop2, **kwds_i)
        if not hop2.llops._called_exception_is_here_or_cannot_occur:
            raise TyperError("missing hop.exception_cannot_occur() or "
                             "hop.exception_is_here() in %s" % bltintyper)
        return v_result

    def rtype_simple_call(self, hop):
        hop2 = hop.copy()
        hop2.r_s_popfirstarg()
        return self._call(hop2)

    def rtype_call_args(self, hop):
        # calling a built-in function with keyword arguments:
        # mostly for rpython.objectmodel.hint()
        hop, kwds_i = call_args_expand(hop)

        hop2 = hop.copy()
        hop2.r_s_popfirstarg()
        hop2.r_s_popfirstarg()
        # the RPython-level keyword args are passed with an 'i_' prefix and
        # the corresponding value is an *index* in the hop2 arguments,
        # to be used with hop.inputarg(arg=..)
        return self._call(hop2, **kwds_i)


class BuiltinMethodRepr(Repr):

    def __init__(self, rtyper, s_self, methodname):
        self.s_self = s_self
        self.self_repr = rtyper.getrepr(s_self)
        self.methodname = methodname
        # methods of a known name are implemented as just their 'self'
        self.lowleveltype = self.self_repr.lowleveltype

    def convert_const(self, obj):
        return self.self_repr.convert_const(obj.__self__)

    def rtype_simple_call(self, hop):
        # methods: look up the rtype_method_xxx()
        name = 'rtype_method_' + self.methodname
        try:
            bltintyper = getattr(self.self_repr, name)
        except AttributeError:
            raise TyperError("missing %s.%s" % (
                self.self_repr.__class__.__name__, name))
        # hack based on the fact that 'lowleveltype == self_repr.lowleveltype'
        hop2 = hop.copy()
        assert hop2.args_r[0] is self
        if isinstance(hop2.args_v[0], Constant):
            c = hop2.args_v[0].value    # get object from bound method
            c = c.__self__
            hop2.args_v[0] = Constant(c)
        hop2.args_s[0] = self.s_self
        hop2.args_r[0] = self.self_repr
        return bltintyper(hop2)

class __extend__(pairtype(BuiltinMethodRepr, BuiltinMethodRepr)):
    def convert_from_to((r_from, r_to), v, llops):
        # convert between two MethodReprs only if they are about the same
        # methodname.  (Useful for the case r_from.s_self == r_to.s_self but
        # r_from is not r_to.)  See test_rbuiltin.test_method_repr.
        if r_from.methodname != r_to.methodname:
            return NotImplemented
        return llops.convertvar(v, r_from.self_repr, r_to.self_repr)

def parse_kwds(hop, *argspec_i_r):
    lst = [i for (i, r) in argspec_i_r if i is not None]
    lst.sort()
    if lst != range(hop.nb_args - len(lst), hop.nb_args):
        raise TyperError("keyword args are expected to be at the end of "
                         "the 'hop' arg list")
    result = []
    for i, r in argspec_i_r:
        if i is not None:
            if r is None:
                r = hop.args_r[i]
            result.append(hop.inputarg(r, arg=i))
        else:
            result.append(None)
    del hop.args_v[hop.nb_args - len(lst):]
    return result

# ____________________________________________________________

@typer_for(bool)
def rtype_builtin_bool(hop):
    # not called any more?
    assert hop.nb_args == 1
    return hop.args_r[0].rtype_bool(hop)

@typer_for(int)
def rtype_builtin_int(hop):
    if isinstance(hop.args_s[0], annmodel.SomeString):
        assert 1 <= hop.nb_args <= 2
        return hop.args_r[0].rtype_int(hop)
    assert hop.nb_args == 1
    return hop.args_r[0].rtype_int(hop)

@typer_for(float)
def rtype_builtin_float(hop):
    assert hop.nb_args == 1
    return hop.args_r[0].rtype_float(hop)

@typer_for(chr)
def rtype_builtin_chr(hop):
    assert hop.nb_args == 1
    return hop.args_r[0].rtype_chr(hop)

@typer_for(unichr)
def rtype_builtin_unichr(hop):
    assert hop.nb_args == 1
    return hop.args_r[0].rtype_unichr(hop)

@typer_for(unicode)
def rtype_builtin_unicode(hop):
    return hop.args_r[0].rtype_unicode(hop)

@typer_for(bytearray)
def rtype_builtin_bytearray(hop):
    return hop.args_r[0].rtype_bytearray(hop)

@typer_for(list)
def rtype_builtin_list(hop):
    return hop.args_r[0].rtype_bltn_list(hop)

#def rtype_builtin_range(hop): see rrange.py

#def rtype_builtin_xrange(hop): see rrange.py

#def rtype_builtin_enumerate(hop): see rrange.py

#def rtype_r_dict(hop): see rdict.py

@typer_for(rarithmetic.intmask)
def rtype_intmask(hop):
    hop.exception_cannot_occur()
    vlist = hop.inputargs(lltype.Signed)
    return vlist[0]

@typer_for(rarithmetic.longlongmask)
def rtype_longlongmask(hop):
    hop.exception_cannot_occur()
    vlist = hop.inputargs(lltype.SignedLongLong)
    return vlist[0]


@typer_for(min)
def rtype_builtin_min(hop):
    v1, v2 = hop.inputargs(hop.r_result, hop.r_result)
    hop.exception_cannot_occur()
    return hop.gendirectcall(ll_min, v1, v2)

def ll_min(i1, i2):
    if i1 < i2:
        return i1
    return i2


@typer_for(max)
def rtype_builtin_max(hop):
    v1, v2 = hop.inputargs(hop.r_result, hop.r_result)
    hop.exception_cannot_occur()
    return hop.gendirectcall(ll_max, v1, v2)

def ll_max(i1, i2):
    if i1 > i2:
        return i1
    return i2


@typer_for(reversed)
def rtype_builtin_reversed(hop):
    hop.exception_cannot_occur()
    return hop.r_result.newiter(hop)


@typer_for(getattr(object.__init__, 'im_func', object.__init__))
def rtype_object__init__(hop):
    hop.exception_cannot_occur()


@typer_for(getattr(EnvironmentError.__init__, 'im_func',
                   EnvironmentError.__init__))
def rtype_EnvironmentError__init__(hop):
    hop.exception_cannot_occur()
    v_self = hop.args_v[0]
    r_self = hop.args_r[0]
    if hop.nb_args <= 2:
        v_errno = hop.inputconst(lltype.Signed, 0)
        if hop.nb_args == 2:
            v_strerror = hop.inputarg(rstr.string_repr, arg=1)
            r_self.setfield(v_self, 'strerror', v_strerror, hop.llops)
    else:
        v_errno = hop.inputarg(lltype.Signed, arg=1)
        v_strerror = hop.inputarg(rstr.string_repr, arg=2)
        r_self.setfield(v_self, 'strerror', v_strerror, hop.llops)
        if hop.nb_args >= 4:
            v_filename = hop.inputarg(rstr.string_repr, arg=3)
            r_self.setfield(v_self, 'filename', v_filename, hop.llops)
    r_self.setfield(v_self, 'errno', v_errno, hop.llops)

try:
    WindowsError
except NameError:
    pass
else:
    @typer_for(
        getattr(WindowsError.__init__, 'im_func', WindowsError.__init__))
    def rtype_WindowsError__init__(hop):
        hop.exception_cannot_occur()
        if hop.nb_args == 2:
            raise TyperError("WindowsError() should not be called with "
                            "a single argument")
        if hop.nb_args >= 3:
            v_self = hop.args_v[0]
            r_self = hop.args_r[0]
            v_error = hop.inputarg(lltype.Signed, arg=1)
            r_self.setfield(v_self, 'winerror', v_error, hop.llops)

@typer_for(objectmodel.hlinvoke)
def rtype_hlinvoke(hop):
    _, s_repr = hop.r_s_popfirstarg()
    r_callable = s_repr.const

    r_func, nimplicitarg = r_callable.get_r_implfunc()
    s_callable = r_callable.get_s_callable()

    nbargs = len(hop.args_s) - 1 + nimplicitarg
    s_sigs = r_func.get_s_signatures((nbargs, (), False))
    if len(s_sigs) != 1:
        raise TyperError("cannot hlinvoke callable %r with not uniform"
                         "annotations: %r" % (r_callable,
                                              s_sigs))
    args_s, s_ret = s_sigs[0]
    rinputs = [hop.rtyper.getrepr(s_obj) for s_obj in args_s]
    rresult = hop.rtyper.getrepr(s_ret)

    args_s = args_s[nimplicitarg:]
    rinputs = rinputs[nimplicitarg:]

    new_args_r = [r_callable] + rinputs

    for i in range(len(new_args_r)):
        assert hop.args_r[i].lowleveltype == new_args_r[i].lowleveltype

    hop.args_r = new_args_r
    hop.args_s = [s_callable] + args_s

    hop.s_result = s_ret
    assert hop.r_result.lowleveltype == rresult.lowleveltype
    hop.r_result = rresult

    return hop.dispatch()

typer_for(range)(rrange.rtype_builtin_range)
typer_for(xrange)(rrange.rtype_builtin_xrange)
typer_for(enumerate)(rrange.rtype_builtin_enumerate)


# annotation of low-level types

@typer_for(lltype.malloc)
def rtype_malloc(hop, i_flavor=None, i_immortal=None, i_zero=None,
        i_track_allocation=None, i_add_memory_pressure=None, i_nonmovable=None):
    assert hop.args_s[0].is_constant()
    vlist = [hop.inputarg(lltype.Void, arg=0)]
    opname = 'malloc'
    kwds_v = parse_kwds(
        hop,
        (i_flavor, lltype.Void),
        (i_immortal, None),
        (i_zero, None),
        (i_track_allocation, None),
        (i_add_memory_pressure, None),
        (i_nonmovable, None))
    (v_flavor, v_immortal, v_zero, v_track_allocation,
     v_add_memory_pressure, v_nonmovable) = kwds_v
    flags = {'flavor': 'gc'}
    if v_flavor is not None:
        flags['flavor'] = v_flavor.value
    if i_zero is not None:
        flags['zero'] = v_zero.value
    if i_track_allocation is not None:
        flags['track_allocation'] = v_track_allocation.value
    if i_add_memory_pressure is not None:
        flags['add_memory_pressure'] = v_add_memory_pressure.value
    if i_nonmovable is not None:
        flags['nonmovable'] = v_nonmovable
    vlist.append(hop.inputconst(lltype.Void, flags))

    assert 1 <= hop.nb_args <= 2
    if hop.nb_args == 2:
        vlist.append(hop.inputarg(lltype.Signed, arg=1))
        opname += '_varsize'

    hop.has_implicit_exception(MemoryError)   # record that we know about it
    hop.exception_is_here()
    return hop.genop(opname, vlist, resulttype=hop.r_result.lowleveltype)

@typer_for(lltype.free)
def rtype_free(hop, i_flavor, i_track_allocation=None):
    vlist = [hop.inputarg(hop.args_r[0], arg=0)]
    v_flavor, v_track_allocation = parse_kwds(hop,
        (i_flavor, lltype.Void),
        (i_track_allocation, None))
    #
    assert v_flavor is not None and v_flavor.value == 'raw'
    flags = {'flavor': 'raw'}
    if i_track_allocation is not None:
        flags['track_allocation'] = v_track_allocation.value
    vlist.append(hop.inputconst(lltype.Void, flags))
    #
    hop.exception_cannot_occur()
    hop.genop('free', vlist)

@typer_for(lltype.render_immortal)
def rtype_render_immortal(hop, i_track_allocation=None):
    vlist = [hop.inputarg(hop.args_r[0], arg=0)]
    v_track_allocation = parse_kwds(hop,
        (i_track_allocation, None))
    hop.exception_cannot_occur()
    if i_track_allocation is None or v_track_allocation.value:
        hop.genop('track_alloc_stop', vlist)

@typer_for(lltype.typeOf)
@typer_for(lltype.nullptr)
@typer_for(lltype.getRuntimeTypeInfo)
@typer_for(lltype.Ptr)
def rtype_const_result(hop):
    hop.exception_cannot_occur()
    return hop.inputconst(hop.r_result.lowleveltype, hop.s_result.const)

@typer_for(lltype.cast_pointer)
def rtype_cast_pointer(hop):
    assert hop.args_s[0].is_constant()
    assert isinstance(hop.args_r[1], rptr.PtrRepr)
    v_type, v_input = hop.inputargs(lltype.Void, hop.args_r[1])
    hop.exception_cannot_occur()
    return hop.genop('cast_pointer', [v_input],    # v_type implicit in r_result
                     resulttype = hop.r_result.lowleveltype)

@typer_for(lltype.cast_opaque_ptr)
def rtype_cast_opaque_ptr(hop):
    assert hop.args_s[0].is_constant()
    assert isinstance(hop.args_r[1], rptr.PtrRepr)
    v_type, v_input = hop.inputargs(lltype.Void, hop.args_r[1])
    hop.exception_cannot_occur()
    return hop.genop('cast_opaque_ptr', [v_input], # v_type implicit in r_result
                     resulttype = hop.r_result.lowleveltype)

@typer_for(lltype.length_of_simple_gcarray_from_opaque)
def rtype_length_of_simple_gcarray_from_opaque(hop):
    assert isinstance(hop.args_r[0], rptr.PtrRepr)
    v_opaque_ptr, = hop.inputargs(hop.args_r[0])
    hop.exception_cannot_occur()
    return hop.genop('length_of_simple_gcarray_from_opaque', [v_opaque_ptr],
                     resulttype = hop.r_result.lowleveltype)

@typer_for(lltype.direct_fieldptr)
def rtype_direct_fieldptr(hop):
    assert isinstance(hop.args_r[0], rptr.PtrRepr)
    assert hop.args_s[1].is_constant()
    vlist = hop.inputargs(hop.args_r[0], lltype.Void)
    hop.exception_cannot_occur()
    return hop.genop('direct_fieldptr', vlist,
                     resulttype=hop.r_result.lowleveltype)

@typer_for(lltype.direct_arrayitems)
def rtype_direct_arrayitems(hop):
    assert isinstance(hop.args_r[0], rptr.PtrRepr)
    vlist = hop.inputargs(hop.args_r[0])
    hop.exception_cannot_occur()
    return hop.genop('direct_arrayitems', vlist,
                     resulttype=hop.r_result.lowleveltype)

@typer_for(lltype.direct_ptradd)
def rtype_direct_ptradd(hop):
    assert isinstance(hop.args_r[0], rptr.PtrRepr)
    vlist = hop.inputargs(hop.args_r[0], lltype.Signed)
    hop.exception_cannot_occur()
    return hop.genop('direct_ptradd', vlist,
                     resulttype=hop.r_result.lowleveltype)

@typer_for(lltype.cast_primitive)
def rtype_cast_primitive(hop):
    assert hop.args_s[0].is_constant()
    TGT = hop.args_s[0].const
    v_type, v_value = hop.inputargs(lltype.Void, hop.args_r[1])
    hop.exception_cannot_occur()
    return gen_cast(hop.llops, TGT, v_value)

_cast_to_Signed = {
    lltype.Signed:         None,
    lltype.Bool:           'cast_bool_to_int',
    lltype.Char:           'cast_char_to_int',
    lltype.UniChar:        'cast_unichar_to_int',
    lltype.Float:          'cast_float_to_int',
    lltype.Unsigned:       'cast_uint_to_int',
    lltype.SignedLongLong: 'truncate_longlong_to_int',
    }
_cast_from_Signed = {
    lltype.Signed:         None,
    lltype.Char:           'cast_int_to_char',
    lltype.UniChar:        'cast_int_to_unichar',
    lltype.Float:          'cast_int_to_float',
    lltype.Unsigned:       'cast_int_to_uint',
    lltype.SignedLongLong: 'cast_int_to_longlong',
    }

def gen_cast(llops, TGT, v_value):
    ORIG = v_value.concretetype
    if ORIG == TGT:
        return v_value
    if (isinstance(TGT, lltype.Primitive) and
            isinstance(ORIG, lltype.Primitive)):
        if ORIG in _cast_to_Signed and TGT in _cast_from_Signed:
            op = _cast_to_Signed[ORIG]
            if op:
                v_value = llops.genop(op, [v_value], resulttype=lltype.Signed)
            op = _cast_from_Signed[TGT]
            if op:
                v_value = llops.genop(op, [v_value], resulttype=TGT)
            return v_value
        elif ORIG is lltype.Signed and TGT is lltype.Bool:
            return llops.genop('int_is_true', [v_value], resulttype=lltype.Bool)
        else:
            # use the generic operation if there is no alternative
            return llops.genop('cast_primitive', [v_value], resulttype=TGT)
    elif isinstance(TGT, lltype.Ptr):
        if isinstance(ORIG, lltype.Ptr):
            if (isinstance(TGT.TO, lltype.OpaqueType) or
                    isinstance(ORIG.TO, lltype.OpaqueType)):
                return llops.genop('cast_opaque_ptr', [v_value], resulttype=TGT)
            else:
                return llops.genop('cast_pointer', [v_value], resulttype=TGT)
        elif ORIG == llmemory.Address:
            return llops.genop('cast_adr_to_ptr', [v_value], resulttype=TGT)
        elif isinstance(ORIG, lltype.Primitive):
            v_value = gen_cast(llops, lltype.Signed, v_value)
            return llops.genop('cast_int_to_ptr', [v_value], resulttype=TGT)
    elif TGT == llmemory.Address and isinstance(ORIG, lltype.Ptr):
        return llops.genop('cast_ptr_to_adr', [v_value], resulttype=TGT)
    elif isinstance(TGT, lltype.Primitive):
        if isinstance(ORIG, lltype.Ptr):
            v_value = llops.genop('cast_ptr_to_int', [v_value],
                                  resulttype=lltype.Signed)
        elif ORIG == llmemory.Address:
            v_value = llops.genop('cast_adr_to_int', [v_value],
                                  resulttype=lltype.Signed)
        else:
            raise TypeError("don't know how to cast from %r to %r" % (ORIG,
                                                                      TGT))
        return gen_cast(llops, TGT, v_value)
    raise TypeError("don't know how to cast from %r to %r" % (ORIG, TGT))

@typer_for(lltype.cast_ptr_to_int)
def rtype_cast_ptr_to_int(hop):
    assert isinstance(hop.args_r[0], rptr.PtrRepr)
    vlist = hop.inputargs(hop.args_r[0])
    hop.exception_cannot_occur()
    return hop.genop('cast_ptr_to_int', vlist,
                     resulttype=lltype.Signed)

@typer_for(lltype.cast_int_to_ptr)
def rtype_cast_int_to_ptr(hop):
    assert hop.args_s[0].is_constant()
    v_type, v_input = hop.inputargs(lltype.Void, lltype.Signed)
    hop.exception_cannot_occur()
    return hop.genop('cast_int_to_ptr', [v_input],
                     resulttype=hop.r_result.lowleveltype)

@typer_for(lltype.identityhash)
def rtype_identity_hash(hop):
    vlist = hop.inputargs(hop.args_r[0])
    hop.exception_cannot_occur()
    return hop.genop('gc_identityhash', vlist, resulttype=lltype.Signed)

@typer_for(lltype.runtime_type_info)
def rtype_runtime_type_info(hop):
    assert isinstance(hop.args_r[0], rptr.PtrRepr)
    vlist = hop.inputargs(hop.args_r[0])
    hop.exception_cannot_occur()
    return hop.genop('runtime_type_info', vlist,
                     resulttype=hop.r_result.lowleveltype)


# _________________________________________________________________
# memory addresses

@typer_for(llmemory.raw_malloc)
def rtype_raw_malloc(hop, i_zero=None):
    v_size = hop.inputarg(lltype.Signed, arg=0)
    v_zero, = parse_kwds(hop, (i_zero, None))
    if v_zero is None:
        v_zero = hop.inputconst(lltype.Bool, False)
    hop.exception_cannot_occur()
    return hop.genop('raw_malloc', [v_size, v_zero],
                     resulttype=llmemory.Address)

@typer_for(llmemory.raw_malloc_usage)
def rtype_raw_malloc_usage(hop):
    v_size, = hop.inputargs(lltype.Signed)
    hop.exception_cannot_occur()
    return hop.genop('raw_malloc_usage', [v_size], resulttype=lltype.Signed)

@typer_for(llmemory.raw_free)
def rtype_raw_free(hop):
    s_addr = hop.args_s[0]
    if s_addr.is_null_address():
        raise TyperError("raw_free(x) where x is the constant NULL")
    v_addr, = hop.inputargs(llmemory.Address)
    hop.exception_cannot_occur()
    return hop.genop('raw_free', [v_addr])

@typer_for(llmemory.raw_memcopy)
def rtype_raw_memcopy(hop):
    for s_addr in hop.args_s[:2]:
        if s_addr.is_null_address():
            raise TyperError("raw_memcopy() with a constant NULL")
    v_list = hop.inputargs(llmemory.Address, llmemory.Address, lltype.Signed)
    hop.exception_cannot_occur()
    return hop.genop('raw_memcopy', v_list)

@typer_for(llmemory.raw_memclear)
def rtype_raw_memclear(hop):
    s_addr = hop.args_s[0]
    if s_addr.is_null_address():
        raise TyperError("raw_memclear(x, n) where x is the constant NULL")
    v_list = hop.inputargs(llmemory.Address, lltype.Signed)
    hop.exception_cannot_occur()
    return hop.genop('raw_memclear', v_list)


@typer_for(llmemory.offsetof)
def rtype_offsetof(hop):
    TYPE, field = hop.inputargs(lltype.Void, lltype.Void)
    hop.exception_cannot_occur()
    return hop.inputconst(lltype.Signed,
                          llmemory.offsetof(TYPE.value, field.value))


# _________________________________________________________________
# non-gc objects

@typer_for(objectmodel.free_non_gc_object)
def rtype_free_non_gc_object(hop):
    hop.exception_cannot_occur()
    vinst, = hop.inputargs(hop.args_r[0])
    flavor = hop.args_r[0].gcflavor
    assert flavor != 'gc'
    flags = {'flavor': flavor}
    cflags = hop.inputconst(lltype.Void, flags)
    return hop.genop('free', [vinst, cflags])


@typer_for(objectmodel.keepalive_until_here)
def rtype_keepalive_until_here(hop):
    hop.exception_cannot_occur()
    for v in hop.args_v:
        hop.genop('keepalive', [v], resulttype=lltype.Void)
    return hop.inputconst(lltype.Void, None)


@typer_for(llmemory.cast_ptr_to_adr)
def rtype_cast_ptr_to_adr(hop):
    vlist = hop.inputargs(hop.args_r[0])
    assert isinstance(vlist[0].concretetype, lltype.Ptr)
    hop.exception_cannot_occur()
    return hop.genop('cast_ptr_to_adr', vlist,
                     resulttype=llmemory.Address)

@typer_for(llmemory.cast_adr_to_ptr)
def rtype_cast_adr_to_ptr(hop):
    assert isinstance(hop.args_r[0], raddress.AddressRepr)
    adr, TYPE = hop.inputargs(hop.args_r[0], lltype.Void)
    hop.exception_cannot_occur()
    return hop.genop('cast_adr_to_ptr', [adr],
                     resulttype=TYPE.value)

@typer_for(llmemory.cast_adr_to_int)
def rtype_cast_adr_to_int(hop):
    assert isinstance(hop.args_r[0], raddress.AddressRepr)
    adr = hop.inputarg(hop.args_r[0], arg=0)
    if len(hop.args_s) == 1:
        mode = "emulated"
    else:
        mode = hop.args_s[1].const
    hop.exception_cannot_occur()
    return hop.genop('cast_adr_to_int',
                     [adr, hop.inputconst(lltype.Void, mode)],
                     resulttype=lltype.Signed)

@typer_for(llmemory.cast_int_to_adr)
def rtype_cast_int_to_adr(hop):
    v_input, = hop.inputargs(lltype.Signed)
    hop.exception_cannot_occur()
    return hop.genop('cast_int_to_adr', [v_input],
                     resulttype=llmemory.Address)


@typer_for(objectmodel.instantiate)
def rtype_instantiate(hop, i_nonmovable=None):
    hop.exception_cannot_occur()
    s_class = hop.args_s[0]
    assert isinstance(s_class, annmodel.SomePBC)
    v_nonmovable, = parse_kwds(hop, (i_nonmovable, None))
    nonmovable = (i_nonmovable is not None and v_nonmovable.value)
    if len(s_class.descriptions) != 1:
        # instantiate() on a variable class
        if nonmovable:
            raise TyperError("instantiate(x, nonmovable=True) cannot be used "
                             "if x is not a constant class")
        vtypeptr, = hop.inputargs(rclass.get_type_repr(hop.rtyper))
        r_class = hop.args_r[0]
        return r_class._instantiate_runtime_class(hop, vtypeptr,
                                                  hop.r_result.lowleveltype)
    classdef = s_class.any_description().getuniqueclassdef()
    return rclass.rtype_new_instance(hop.rtyper, classdef, hop.llops,
                                     nonmovable=nonmovable)


@typer_for(hasattr)
def rtype_builtin_hasattr(hop):
    hop.exception_cannot_occur()
    if hop.s_result.is_constant():
        return hop.inputconst(lltype.Bool, hop.s_result.const)

    raise TyperError("hasattr is only suported on a constant")

@typer_for(OrderedDict)
@typer_for(objectmodel.r_dict)
@typer_for(objectmodel.r_ordereddict)
def rtype_dict_constructor(hop, i_force_non_null=None, i_simple_hash_eq=None):
    # 'i_force_non_null' and 'i_simple_hash_eq' are ignored here; if they have any
    # effect, it has already been applied to 'hop.r_result'
    hop.exception_cannot_occur()
    r_dict = hop.r_result
    cDICT = hop.inputconst(lltype.Void, r_dict.DICT)
    v_result = hop.gendirectcall(r_dict.ll_newdict, cDICT)
    if r_dict.custom_eq_hash:
        v_eqfn = hop.inputarg(r_dict.r_rdict_eqfn, arg=0)
        v_hashfn = hop.inputarg(r_dict.r_rdict_hashfn, arg=1)
        if r_dict.r_rdict_eqfn.lowleveltype != lltype.Void:
            cname = hop.inputconst(lltype.Void, 'fnkeyeq')
            hop.genop('setfield', [v_result, cname, v_eqfn])
        if r_dict.r_rdict_hashfn.lowleveltype != lltype.Void:
            cname = hop.inputconst(lltype.Void, 'fnkeyhash')
            hop.genop('setfield', [v_result, cname, v_hashfn])
    return v_result

# _________________________________________________________________
# weakrefs

import weakref
from rpython.rtyper.lltypesystem import llmemory

@typer_for(llmemory.weakref_create)
@typer_for(weakref.ref)
def rtype_weakref_create(hop):
    from rpython.rtyper.rweakref import BaseWeakRefRepr

    v_inst, = hop.inputargs(hop.args_r[0])
    hop.exception_cannot_occur()
    if isinstance(hop.r_result, BaseWeakRefRepr):
        return hop.r_result._weakref_create(hop, v_inst)
    else:
        # low-level <PtrRepr * WeakRef>
        assert hop.rtyper.getconfig().translation.rweakref
        return hop.genop('weakref_create', [v_inst],
                         resulttype=llmemory.WeakRefPtr)

@typer_for(llmemory.weakref_deref)
def rtype_weakref_deref(hop):
    assert hop.rtyper.getconfig().translation.rweakref
    c_ptrtype, v_wref = hop.inputargs(lltype.Void, hop.args_r[1])
    assert v_wref.concretetype == llmemory.WeakRefPtr
    hop.exception_cannot_occur()
    return hop.genop('weakref_deref', [v_wref], resulttype=c_ptrtype.value)

@typer_for(llmemory.cast_ptr_to_weakrefptr)
def rtype_cast_ptr_to_weakrefptr(hop):
    assert hop.rtyper.getconfig().translation.rweakref
    vlist = hop.inputargs(hop.args_r[0])
    hop.exception_cannot_occur()
    return hop.genop('cast_ptr_to_weakrefptr', vlist,
                     resulttype=llmemory.WeakRefPtr)

@typer_for(llmemory.cast_weakrefptr_to_ptr)
def rtype_cast_weakrefptr_to_ptr(hop):
    assert hop.rtyper.getconfig().translation.rweakref
    c_ptrtype, v_wref = hop.inputargs(lltype.Void, hop.args_r[1])
    assert v_wref.concretetype == llmemory.WeakRefPtr
    hop.exception_cannot_occur()
    return hop.genop('cast_weakrefptr_to_ptr', [v_wref],
                     resulttype=c_ptrtype.value)
