from rpython.jit.backend.llsupport.test.zrpy_gc_test import compile
from rpython.rlib.jit import JitDriver, set_param


def compile(f, gc, **kwds):
    from rpython.annotator.listdef import s_list_of_strings
    from rpython.translator.translator import TranslationContext
    from rpython.jit.metainterp.warmspot import apply_jit
    from rpython.translator.c import genc
    #
    t = TranslationContext()
    t.config.translation.gc = 'boehm'
    for name, value in kwds.items():
        setattr(t.config.translation, name, value)
    ann = t.buildannotator()
    ann.build_types(f, [s_list_of_strings], main_entry_point=True)
    t.buildrtyper().specialize()

    if kwds['jit']:
        apply_jit(t, vec=True)

class TestVecOptX86(object):
    def test_translate(self):
        jd = JitDriver(greens = [], reds = 'auto', vectorize=True)
        def f(x):
            pass
            i = 0
            while i < 100:
                jd.jit_merge_point()
                i += 1
        compile(f, 'boehm', jit=True)

