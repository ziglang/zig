from rpython.jit.backend.llsupport.test.ztranslation_test import TranslationTestCallAssembler
import sys


# On Windows, this test crashes obscurely, but only if compiled with
# Boehm, not if run with no GC at all.  So for now we'll assume it is
# really a Boehm bug, or maybe a Boehm-on-Windows-specific issue, and
# skip.
if sys.platform == 'win32':
    import py
    py.test.skip("crashes on Windows (Boehm issue?)")


class TestTranslationCallAssemblerAarch64(TranslationTestCallAssembler):
    pass
