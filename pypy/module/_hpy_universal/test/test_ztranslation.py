import pytest
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.translator.c.test.test_standalone import StandaloneTests
from rpython.config.translationoption import get_combined_translation_config
from pypy.config.pypyoption import get_pypy_config
from pypy.objspace.std.typeobject import W_TypeObject
from pypy.objspace.fake.checkmodule import checkmodule
from pypy.objspace.fake.objspace import FakeObjSpace
from pypy.module._hpy_universal.state import State
from pypy.module.cpyext.api import cts as cpyts


def attach_dict_strategy(space):
    # this is needed for modules which do e.g. "isinstance(w_obj,
    # W_DictMultiObject)", like _hpy_universal. Make sure that the
    # annotator sees a concrete class, like W_DictObject, else lots of
    # operations are blocked.
    from pypy.objspace.std.dictmultiobject import W_DictObject, ObjectDictStrategy
    strategy = ObjectDictStrategy(space)
    storage = strategy.get_empty_storage()
    w_obj = W_DictObject(space, strategy, storage)

def make_cpyext_struct():
    # create a dummy Sturct which includes the eci from CpyextTypeSpace: this
    # way, we convince the translator to include the proper .h files, which
    # are needed to complete the C compilation because
    # e.g. attach_legacy_slots_to_type needs to dereference PyType_Slot.
    #
    # NOTE: that these are not the headers which are used in the real
    # translation: structs like PyType_Slot are defined by Python.h, which we
    # do NOT include here. By using cts.build_eci() we are including the
    # headers in cpyext/parse/, which are good enough to make C compilation
    # succeeding.
    eci = cpyts.build_eci()
    return lltype.Struct('DUMMY_CPYEXT_STRUCT', hints={'eci': eci})


@pytest.mark.dont_track_allocations()
def test_checkmodule():
    DUMMY_CPYEXT_STRUCT = make_cpyext_struct()
    def extra_func(space):
        from pypy.objspace.std.unicodeobject import W_UnicodeObject
        state = State.get(space)
        state.setup(space)
        attach_dict_strategy(space)
        p = lltype.malloc(DUMMY_CPYEXT_STRUCT, flavor='raw')
        lltype.free(p, flavor='raw')
        W_TypeObject(space, 'foo', [], {}).hasmro = False
        W_UnicodeObject("abc", 3) # unfortunately needed

    rpython_opts = {'translation.gc': 'boehm'}
    # it isn't possible to ztranslate cpyext easily, so we check _hpy_universal
    # WITHOUT the cpyext parts
    pypy_opts = {'objspace.std.withliststrategies': False,
                 'objspace.hpy_cpyext_API': False}
    checkmodule('_hpy_universal',
                extra_func=extra_func,
                c_compile=True,
                rpython_opts=rpython_opts,
                pypy_opts=pypy_opts,
                show_pdbplus=False,
                )
