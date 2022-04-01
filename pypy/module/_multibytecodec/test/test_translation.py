from pypy.module._multibytecodec import c_codecs
from rpython.translator.c.test import test_standalone
from rpython.config.translationoption import get_combined_translation_config
from rpython.rlib import rutf8


class TestTranslation(test_standalone.StandaloneTests):
    config = get_combined_translation_config(translating=True)
    config.translation.gc = 'boehm'

    def test_translation(self):
        #
        def entry_point(argv):
            codecname, string = argv[1], argv[2]
            c = c_codecs.getcodec(codecname)
            u = c_codecs.decode(c, string)
            lgt = rutf8.codepoints_in_utf8(u)
            r = c_codecs.encode(c, u, lgt)
            print r
            return 0
        #
        t, cbuilder = self.compile(entry_point)
        cmd = 'hz "~{abc}"'
        data = cbuilder.cmdexec(cmd)
        assert data == '~{abc}~}\n'
