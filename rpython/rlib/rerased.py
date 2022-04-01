""" Contains a mechanism for turning any class instance and any integer into a
pointer-like thing. Gives full control over pointer tagging, i.e. there won't
be tag checks everywhere in the C code.

Usage:  erasestuff, unerasestuff = new_erasing_pair('stuff')

An erasestuff(x) object contains a reference to 'x'.  Nothing can be done with
this object, except calling unerasestuff(), which returns 'x' again.  The point
is that all erased objects can be mixed together, whether they are instances,
lists, strings, etc.  As a special case, an erased object can also be an
integer fitting into 31/63 bits, with erase_int() and unerase_int().

Warning: some care is needed to make sure that you call the unerase function
corresponding to the original creator's erase function.  Otherwise, segfault.
"""

import sys
from collections import defaultdict

from rpython.annotator import model as annmodel
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.rtyper.llannotation import lltype_to_annotation
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib.rarithmetic import is_valid_int
from rpython.rlib.debug import ll_assert


def erase_int(x):
    assert is_valid_int(x)
    res = 2 * x + 1
    if res > sys.maxint or res < -sys.maxint - 1:
        raise OverflowError
    return Erased(x, _identity_for_ints)

def unerase_int(y):
    assert y._identity is _identity_for_ints
    assert is_valid_int(y._x)
    return y._x


class ErasingPairIdentity(object):

    def __init__(self, name):
        self.name = name

    def __repr__(self):
        return 'ErasingPairIdentity(%r)' % self.name

    def __deepcopy__(self, memo):
        return self

class IdentityDesc(object):
    def __init__(self, bookkeeper):
        self.bookkeeper = bookkeeper
        self.s_input = annmodel.s_ImpossibleValue
        self.reflowpositions = {}

    def enter_tunnel(self, s_obj):
        s_obj = annmodel.unionof(self.s_input, s_obj)
        if s_obj != self.s_input:
            self.s_input = s_obj
            for position in self.reflowpositions:
                self.bookkeeper.annotator.reflowfromposition(position)

    def leave_tunnel(self):
        self.reflowpositions[self.bookkeeper.position_key] = True
        return self.s_input

def _get_desc(bk, identity):
    try:
        descs = bk._erasing_pairs_descs
    except AttributeError:
        descs = bk._erasing_pairs_descs = defaultdict(lambda: IdentityDesc(bk))
    return descs[identity]

_identity_for_ints = ErasingPairIdentity("int")


def new_erasing_pair(name):
    identity = ErasingPairIdentity(name)

    def erase(x):
        assert not isinstance(x, Erased)
        return Erased(x, identity)

    def unerase(y):
        assert y._identity is identity
        return y._x

    class Entry(ExtRegistryEntry):
        _about_ = erase

        def compute_result_annotation(self, s_obj):
            desc = _get_desc(self.bookkeeper, identity)
            desc.enter_tunnel(s_obj)
            return _some_erased()

        def specialize_call(self, hop):
            bk = hop.rtyper.annotator.bookkeeper
            desc = _get_desc(bk, identity)
            hop.exception_cannot_occur()
            return _rtype_erase(hop, desc.s_input)

    class Entry(ExtRegistryEntry):
        _about_ = unerase

        def compute_result_annotation(self, s_obj):
            assert _some_erased().contains(s_obj)
            desc = _get_desc(self.bookkeeper, identity)
            return desc.leave_tunnel()

        def specialize_call(self, hop):
            hop.exception_cannot_occur()
            if hop.r_result.lowleveltype is lltype.Void:
                return hop.inputconst(lltype.Void, None)
            [v] = hop.inputargs(hop.args_r[0])
            return _rtype_unerase(hop, v)

    return erase, unerase

def new_static_erasing_pair(name):
    erase, unerase = new_erasing_pair(name)
    return staticmethod(erase), staticmethod(unerase)


# ---------- implementation-specific ----------

class Erased(object):
    def __init__(self, x, identity):
        self._x = x
        self._identity = identity

    def __repr__(self):
        return "Erased(%r, %r)" % (self._x, self._identity)

    def _convert_const_ptr(self, r_self):
        value = self
        if value._identity is _identity_for_ints:
            config = r_self.rtyper.annotator.translator.config
            assert config.translation.taggedpointers, "need to enable tagged pointers to use erase_int"
            return lltype.cast_int_to_ptr(r_self.lowleveltype, value._x * 2 + 1)
        bk = r_self.rtyper.annotator.bookkeeper
        s_obj = _get_desc(bk, value._identity).s_input
        r_obj = r_self.rtyper.getrepr(s_obj)
        if r_obj.lowleveltype is lltype.Void:
            return lltype.nullptr(r_self.lowleveltype.TO)
        v = r_obj.convert_const(value._x)
        return lltype.cast_opaque_ptr(r_self.lowleveltype, v)


class Entry(ExtRegistryEntry):
    _about_ = erase_int

    def compute_result_annotation(self, s_obj):
        config = self.bookkeeper.annotator.translator.config
        assert config.translation.taggedpointers, "need to enable tagged pointers to use erase_int"
        assert annmodel.SomeInteger().contains(s_obj)
        return _some_erased()

    def specialize_call(self, hop):
        return _rtype_erase_int(hop)

class Entry(ExtRegistryEntry):
    _about_ = unerase_int

    def compute_result_annotation(self, s_obj):
        assert _some_erased().contains(s_obj)
        return annmodel.SomeInteger()

    def specialize_call(self, hop):
        [v] = hop.inputargs(hop.args_r[0])
        assert isinstance(hop.s_result, annmodel.SomeInteger)
        return _rtype_unerase_int(hop, v)

def ll_unerase_int(gcref):
    x = llop.cast_ptr_to_int(lltype.Signed, gcref)
    ll_assert((x&1) != 0, "unerased_int(): not an integer")
    return x >> 1


class Entry(ExtRegistryEntry):
    _type_ = Erased

    def compute_annotation(self):
        desc = _get_desc(self.bookkeeper, self.instance._identity)
        s_obj = self.bookkeeper.immutablevalue(self.instance._x)
        desc.enter_tunnel(s_obj)
        return _some_erased()

# annotation and rtyping support

def _some_erased():
    return lltype_to_annotation(llmemory.GCREF)

def _rtype_erase(hop, s_obj):
    hop.exception_cannot_occur()
    r_obj = hop.rtyper.getrepr(s_obj)
    if r_obj.lowleveltype is lltype.Void:
        return hop.inputconst(llmemory.GCREF,
                              lltype.nullptr(llmemory.GCREF.TO))
    [v_obj] = hop.inputargs(r_obj)
    return hop.genop('cast_opaque_ptr', [v_obj],
                     resulttype=llmemory.GCREF)

def _rtype_unerase(hop, s_obj):
    [v] = hop.inputargs(hop.args_r[0])
    return hop.genop('cast_opaque_ptr', [v], resulttype=hop.r_result)

def _rtype_unerase_int(hop, v):
    hop.exception_cannot_occur()
    return hop.gendirectcall(ll_unerase_int, v)

def _rtype_erase_int(hop):
    [v_value] = hop.inputargs(lltype.Signed)
    c_one = hop.inputconst(lltype.Signed, 1)
    hop.exception_is_here()
    v2 = hop.genop('int_add_ovf', [v_value, v_value],
                   resulttype = lltype.Signed)
    v2p1 = hop.genop('int_add', [v2, c_one],
                     resulttype = lltype.Signed)
    v_instance = hop.genop('cast_int_to_ptr', [v2p1],
                           resulttype=llmemory.GCREF)
    return v_instance
