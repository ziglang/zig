import pytest, sys

from rpython.jit.codewriter.effectinfo import (effectinfo_from_writeanalyze,
    EffectInfo, VirtualizableAnalyzer, compute_bitstrings)
from rpython.rlib import jit
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.rclass import OBJECT
from rpython.translator.translator import TranslationContext, graphof
from rpython.tool.algo.bitstring import bitcheck


class FakeCPU(object):
    def fielddescrof(self, T, fieldname):
        return ('fielddescr', T, fieldname)

    def arraydescrof(self, A):
        return ('arraydescr', A)


def test_no_oopspec_duplicate():
    # check that all the various EffectInfo.OS_* have unique values
    oopspecs = set()
    for name, value in EffectInfo.__dict__.iteritems():
        if name.startswith('OS_'):
            assert value not in oopspecs
            oopspecs.add(value)


def test_include_read_field():
    S = lltype.GcStruct("S", ("a", lltype.Signed))
    effects = frozenset([("readstruct", lltype.Ptr(S), "a")])
    effectinfo = effectinfo_from_writeanalyze(effects, FakeCPU())
    assert list(effectinfo._readonly_descrs_fields) == [('fielddescr', S, "a")]
    assert not effectinfo._write_descrs_fields
    assert not effectinfo._write_descrs_arrays
    assert effectinfo.single_write_descr_array is None


def test_include_write_field():
    S = lltype.GcStruct("S", ("a", lltype.Signed))
    effects = frozenset([("struct", lltype.Ptr(S), "a")])
    effectinfo = effectinfo_from_writeanalyze(effects, FakeCPU())
    assert list(effectinfo._write_descrs_fields) == [('fielddescr', S, "a")]
    assert not effectinfo._readonly_descrs_fields
    assert not effectinfo._write_descrs_arrays


def test_include_read_array():
    A = lltype.GcArray(lltype.Signed)
    effects = frozenset([("readarray", lltype.Ptr(A))])
    effectinfo = effectinfo_from_writeanalyze(effects, FakeCPU())
    assert not effectinfo._readonly_descrs_fields
    assert list(effectinfo._readonly_descrs_arrays) == [('arraydescr', A)]
    assert not effectinfo._write_descrs_fields
    assert not effectinfo._write_descrs_arrays


def test_include_write_array():
    A = lltype.GcArray(lltype.Signed)
    effects = frozenset([("array", lltype.Ptr(A))])
    effectinfo = effectinfo_from_writeanalyze(effects, FakeCPU())
    assert not effectinfo._readonly_descrs_fields
    assert not effectinfo._write_descrs_fields
    assert list(effectinfo._write_descrs_arrays) == [('arraydescr', A)]
    assert effectinfo.single_write_descr_array == ('arraydescr', A)


def test_dont_include_read_and_write_field():
    S = lltype.GcStruct("S", ("a", lltype.Signed))
    effects = frozenset([("readstruct", lltype.Ptr(S), "a"),
                         ("struct", lltype.Ptr(S), "a")])
    effectinfo = effectinfo_from_writeanalyze(effects, FakeCPU())
    assert not effectinfo._readonly_descrs_fields
    assert list(effectinfo._write_descrs_fields) == [('fielddescr', S, "a")]
    assert not effectinfo._write_descrs_arrays


def test_dont_include_read_and_write_array():
    A = lltype.GcArray(lltype.Signed)
    effects = frozenset([("readarray", lltype.Ptr(A)),
                         ("array", lltype.Ptr(A))])
    effectinfo = effectinfo_from_writeanalyze(effects, FakeCPU())
    assert not effectinfo._readonly_descrs_fields
    assert not effectinfo._readonly_descrs_arrays
    assert not effectinfo._write_descrs_fields
    assert list(effectinfo._write_descrs_arrays) == [('arraydescr', A)]


def test_filter_out_typeptr():
    effects = frozenset([("struct", lltype.Ptr(OBJECT), "typeptr")])
    effectinfo = effectinfo_from_writeanalyze(effects, None)
    assert not effectinfo._readonly_descrs_fields
    assert not effectinfo._write_descrs_fields
    assert not effectinfo._write_descrs_arrays


def test_filter_out_array_of_void():
    effects = frozenset([("array", lltype.Ptr(lltype.GcArray(lltype.Void)))])
    effectinfo = effectinfo_from_writeanalyze(effects, None)
    assert not effectinfo._readonly_descrs_fields
    assert not effectinfo._write_descrs_fields
    assert not effectinfo._write_descrs_arrays


def test_filter_out_struct_with_void():
    effects = frozenset([("struct", lltype.Ptr(lltype.GcStruct("x", ("a", lltype.Void))), "a")])
    effectinfo = effectinfo_from_writeanalyze(effects, None)
    assert not effectinfo._readonly_descrs_fields
    assert not effectinfo._write_descrs_fields
    assert not effectinfo._write_descrs_arrays


class TestVirtualizableAnalyzer(object):
    def analyze(self, func, sig):
        t = TranslationContext()
        t.buildannotator().build_types(func, sig)
        t.buildrtyper().specialize()
        fgraph = graphof(t, func)
        return VirtualizableAnalyzer(t).analyze(fgraph.startblock.operations[0])

    def test_constructor(self):
        class A(object):
            x = 1

        class B(A):
            x = 2

        @jit.elidable
        def g(cls):
            return cls()

        def f(x):
            if x:
                cls = A
            else:
                cls = B
            return g(cls).x

        def entry(x):
            return f(x)

        res = self.analyze(entry, [int])
        assert not res


def test_compute_bitstrings():
    class FDescr:
        pass
    class ADescr:
        pass
    class CDescr:
        def __init__(self, ei):
            self._ei = ei
        def get_extra_info(self):
            return self._ei

    f1descr = FDescr()
    f2descr = FDescr()
    f3descr = FDescr()
    a1descr = ADescr()
    a2descr = ADescr()

    ei1 = EffectInfo(None, None, None, None, None, None,
                         EffectInfo.EF_RANDOM_EFFECTS)
    ei2 = EffectInfo([f1descr], [], [], [], [], [])
    ei3 = EffectInfo([f1descr], [a1descr, a2descr], [], [f2descr], [], [])

    compute_bitstrings([CDescr(ei1), CDescr(ei2), CDescr(ei3),
                        f1descr, f2descr, f3descr, a1descr, a2descr])

    assert f1descr.ei_index in (0, 1)
    assert f2descr.ei_index == 1 - f1descr.ei_index
    assert f3descr.ei_index == sys.maxint
    assert a1descr.ei_index == 0
    assert a2descr.ei_index == 0

    assert ei1.bitstring_readonly_descrs_fields is None
    assert ei1.bitstring_readonly_descrs_arrays is None
    assert ei1.bitstring_write_descrs_fields is None

    def expand(bitstr):
        return [n for n in range(10) if bitcheck(bitstr, n)]

    assert expand(ei2.bitstring_readonly_descrs_fields) == [f1descr.ei_index]
    assert expand(ei2.bitstring_write_descrs_fields) == []
    assert expand(ei2.bitstring_readonly_descrs_arrays) == []
    assert expand(ei2.bitstring_write_descrs_arrays) == []

    assert expand(ei3.bitstring_readonly_descrs_fields) == [f1descr.ei_index]
    assert expand(ei3.bitstring_write_descrs_fields) == [f2descr.ei_index]
    assert expand(ei3.bitstring_readonly_descrs_arrays) == [0] #a1descr,a2descr
    assert expand(ei3.bitstring_write_descrs_arrays) == []

    for ei in [ei2, ei3]:
        for fdescr in [f1descr, f2descr]:
            assert ei.check_readonly_descr_field(fdescr) == (
                fdescr in ei._readonly_descrs_fields)
            assert ei.check_write_descr_field(fdescr) == (
                fdescr in ei._write_descrs_fields)
        for adescr in [a1descr, a2descr]:
            assert ei.check_readonly_descr_array(adescr) == (
                adescr in ei._readonly_descrs_arrays)
            assert ei.check_write_descr_array(adescr) == (
                adescr in ei._write_descrs_arrays)
