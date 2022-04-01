from rpython.jit.backend.llsupport.test.ztranslation_test import TranslationTestCallAssembler
from rpython.translator.translator import TranslationContext
from rpython.config.translationoption import DEFL_GC

class TestTranslationCallAssemblerZARCH(TranslationTestCallAssembler):
    def _get_TranslationContext(self):
        t = TranslationContext()
        t.config.translation.gc = DEFL_GC   # 'hybrid' or 'minimark'
        t.config.translation.list_comprehension_operations = True
        return t

