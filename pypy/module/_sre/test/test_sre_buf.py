from pypy.module._sre.test import test_app_sre
from pypy.module._sre import interp_sre
from rpython.rlib.rsre import rsre_core
from rpython.rlib.buffer import StringBuffer


def _test_sre_ctx_buf_(self, str, start, end):
    # Test BufMatchContext.
    buf = StringBuffer(str)
    return rsre_core.BufMatchContext(buf, start, end)

def setup_module(mod):
    mod._org_maker = (
        interp_sre.W_SRE_Pattern._make_str_match_context,
        )
    interp_sre.W_SRE_Pattern._make_str_match_context = _test_sre_ctx_buf_

def teardown_module(mod):
    (
        interp_sre.W_SRE_Pattern._make_str_match_context,
    ) = mod._org_maker


class AppTestSreMatchBuf(test_app_sre.AppTestSreMatch):
    pass
