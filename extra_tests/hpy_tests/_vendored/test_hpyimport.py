from .support import HPyTest

class TestImport(HPyTest):

    def test_ImportModule(self):
        import pytest
        import sys
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy h_name)
            {
                // we use bytes because ATM we don't have HPyUnicode_AsUTF8 or similar
                char *name = HPyBytes_AsString(ctx, h_name);
                if (name == NULL)
                    return HPy_NULL;
                return HPyImport_ImportModule(ctx, name);
            }
            @EXPORT(f)
            @INIT
        """)
        sys2 = mod.f(b'sys')
        assert sys is sys2
        with pytest.raises(ImportError):
            mod.f(b'This is the name of a module which does not exist, hopefully')
