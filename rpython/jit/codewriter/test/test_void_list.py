from rpython.rtyper.lltypesystem import lltype
from rpython.translator.unsimplify import varoftype
from rpython.flowspace.model import Constant
from rpython.jit.codewriter.jtransform import NotSupported

from rpython.jit.codewriter.test.test_list import builtin_test

# ____________________________________________________________
# XXX support for lists of voids is limited right now

FIXEDLIST = lltype.Ptr(lltype.GcArray(lltype.Void))
VARLIST = lltype.Ptr(lltype.GcStruct('VARLIST',
                                     ('length', lltype.Signed),
                                     ('items', FIXEDLIST),
                                     adtmeths={"ITEM": lltype.Void}))

# ____________________________________________________________
# Fixed lists

def test_newlist():
    builtin_test('newlist', [], FIXEDLIST,
                 NotSupported)
    builtin_test('newlist', [Constant(5, lltype.Signed)], FIXEDLIST,
                 NotSupported)
    builtin_test('newlist', [varoftype(lltype.Signed)], FIXEDLIST,
                 NotSupported)
    builtin_test('newlist', [Constant(5, lltype.Signed),
                             Constant(0, lltype.Signed)], FIXEDLIST,
                 NotSupported)
    builtin_test('newlist', [Constant(5, lltype.Signed),
                             Constant(1, lltype.Signed)], FIXEDLIST,
                 NotSupported)
    builtin_test('newlist', [Constant(5, lltype.Signed),
                             varoftype(lltype.Signed)], FIXEDLIST,
                 NotSupported)

def test_fixed_ll_arraycopy():
    builtin_test('list.ll_arraycopy',
                 [varoftype(FIXEDLIST),
                  varoftype(FIXEDLIST),
                  varoftype(lltype.Signed), 
                  varoftype(lltype.Signed), 
                  varoftype(lltype.Signed)],
                 lltype.Void,
                 NotSupported)

def test_fixed_ll_arraymove():
    builtin_test('list.ll_arraymove',
                 [varoftype(FIXEDLIST),
                  varoftype(lltype.Signed), 
                  varoftype(lltype.Signed), 
                  varoftype(lltype.Signed)],
                 lltype.Void,
                 NotSupported)

def test_fixed_getitem():
    builtin_test('list.getitem/NONNEG',
                 [varoftype(FIXEDLIST), varoftype(lltype.Signed)],
                 lltype.Void, "")
    builtin_test('list.getitem/NEG',
                 [varoftype(FIXEDLIST), varoftype(lltype.Signed)],
                 lltype.Void, "")

def test_fixed_getitem_foldable():
    builtin_test('list.getitem_foldable/NONNEG',
                 [varoftype(FIXEDLIST), varoftype(lltype.Signed)],
                 lltype.Void, "")
    builtin_test('list.getitem_foldable/NEG',
                 [varoftype(FIXEDLIST), varoftype(lltype.Signed)],
                 lltype.Void, "")

def test_fixed_setitem():
    builtin_test('list.setitem/NONNEG', [varoftype(FIXEDLIST),
                                         varoftype(lltype.Signed),
                                         varoftype(lltype.Void)],
                 lltype.Void, "")
    builtin_test('list.setitem/NEG', [varoftype(FIXEDLIST),
                                      varoftype(lltype.Signed),
                                      varoftype(lltype.Void)],
                 lltype.Void, "")

def test_fixed_len():
    builtin_test('list.len', [varoftype(FIXEDLIST)], lltype.Signed,
                 NotSupported)

def test_fixed_len_foldable():
    builtin_test('list.len_foldable', [varoftype(FIXEDLIST)], lltype.Signed,
                 NotSupported)

# ____________________________________________________________
# Resizable lists

def test_resizable_newlist():
    builtin_test('newlist', [], VARLIST,
                 NotSupported)
    builtin_test('newlist', [Constant(5, lltype.Signed)], VARLIST,
                 NotSupported)
    builtin_test('newlist', [varoftype(lltype.Signed)], VARLIST,
                 NotSupported)
    builtin_test('newlist', [Constant(5, lltype.Signed),
                             Constant(0, lltype.Signed)], VARLIST,
                 NotSupported)
    builtin_test('newlist', [Constant(5, lltype.Signed),
                             Constant(1, lltype.Signed)], VARLIST,
                 NotSupported)
    builtin_test('newlist', [Constant(5, lltype.Signed),
                             varoftype(lltype.Signed)], VARLIST,
                 NotSupported)

def test_resizable_getitem():
    builtin_test('list.getitem/NONNEG',
                 [varoftype(VARLIST), varoftype(lltype.Signed)],
                 lltype.Void, "")
    builtin_test('list.getitem/NEG',
                 [varoftype(VARLIST), varoftype(lltype.Signed)],
                 lltype.Void, "")

def test_resizable_setitem():
    builtin_test('list.setitem/NONNEG', [varoftype(VARLIST),
                                         varoftype(lltype.Signed),
                                         varoftype(lltype.Void)],
                 lltype.Void, "")
    builtin_test('list.setitem/NEG', [varoftype(VARLIST),
                                      varoftype(lltype.Signed),
                                      varoftype(lltype.Void)],
                 lltype.Void, "")

def test_resizable_len():
    builtin_test('list.len', [varoftype(VARLIST)], lltype.Signed,
                 NotSupported)

def test_resizable_unsupportedop():
    builtin_test('list.foobar', [varoftype(VARLIST)], lltype.Signed,
                 NotSupported)
