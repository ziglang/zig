from rpython.jit.backend.llsupport.test.ztranslation_test import TranslationTest
from rpython.translator.translator import TranslationContext
from rpython.config.translationoption import DEFL_GC
from rpython.jit.backend.arm.test.support import skip_unless_run_slow_tests
skip_unless_run_slow_tests()


class TestTranslationARM(TranslationTest):
    def _get_TranslationContext(self):
        t = TranslationContext()
        t.config.translation.gc = DEFL_GC   # 'hybrid' or 'minimark'
        t.config.translation.gcrootfinder = 'shadowstack'
        return t
