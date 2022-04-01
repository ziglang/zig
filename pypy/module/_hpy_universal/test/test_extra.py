"""
This file contains extra hpy tests in addition to the ones which are in
test/_vendored.

The idea is that during development, sometimes it is useful to write tests
about certain specific features/code paths/corner cases which are not covered
(yet!) by the official hpy tests, so this is a place to collect them.

Once the development phase is finished, please move these tests to the main
hpy repo, and then copy them back here via ./update_vendored.sh.
"""

from pypy.module._hpy_universal.test._vendored.support import HPyTest

class TestExtra(HPyTest):
    pass

    """
    Additional tests to write:

      - check the .readonly field of HPyDef_MEMBER (and also the corresponding
        flag for the PyMemberDef cpy_compat case)


    ListBuilder:

      - in the C code there is logic to delay the MemoryError until we call
        ListBuilder_Build, but it is not tested

      - ListBuilder_Cancel is not tested

    """
    def test_import_failure(self):
        import pytest
        with pytest.raises(RuntimeError):
            self.make_module("""
                HPy_MODINIT(test)
                static HPy init_test_impl(HPyContext *ctx)
                {
                    HPyErr_SetString(ctx, ctx->h_RuntimeError, "foo");
                    return HPyLong_FromLong(ctx, 42);
                }
            """, name='test')

    def test_import_bad_module(self):
        import pytest
        with pytest.raises(SystemError):
            self.make_module("""
                HPy_MODINIT(test)
                static HPy init_test_impl(HPyContext *ctx)
                {
                    return HPy_NULL;
                }
            """, name='test')

    def test_HPyModule_Create(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                HPyModuleDef def = {
                    .m_name = "foo",
                    .m_doc = "Some doc",
                    .m_size = -1,
                };
                return HPyModule_Create(ctx, &def);
            }
            @EXPORT(f)
            @INIT
        """)
        m = mod.f()
        assert m.__name__ == "foo"
        assert m.__doc__ == "Some doc"
        assert m.__package__ is None
        assert m.__loader__ is None
        assert m.__spec__ is None
        assert set(vars(m).keys()) == {
            '__name__', '__doc__', '__package__', '__loader__', '__spec__'}


class TestExtraCPythonCompatibility(HPyTest):
    # these tests are run with cpyext support, see conftest.py
    USE_CPYEXT = True
