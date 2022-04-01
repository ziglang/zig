import pytest
@pytest.fixture
def hpy_abi():
    return "debug"

def make_leak_module(compiler):
    # for convenience
    return compiler.make_module("""
        HPyDef_METH(leak, "leak", leak_impl, HPyFunc_O)
        static HPy leak_impl(HPyContext *ctx, HPy self, HPy arg)
        {
            HPy_Dup(ctx, arg); // leak!
            return HPy_Dup(ctx, ctx->h_None);
        }
        @EXPORT(leak)
        @INIT
    """)


def test_debug_ctx_name(compiler):
    # this is very similar to the one in test_00_basic, but:
    #   1. by doing the same here, we ensure that we are actually using
    #      the debug ctx in these tests
    #   2. in pypy we run HPyTest with only hpy_abi==universal, so this
    #      tests something which is NOT tested by test_00_basic
    mod = compiler.make_module("""
        HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
        static HPy f_impl(HPyContext *ctx, HPy self)
        {
            return HPyUnicode_FromString(ctx, ctx->name);
        }

        @EXPORT(f)
        @INIT
    """)
    ctx_name = mod.f()
    assert ctx_name.startswith('HPy Debug Mode ABI')

def test_get_open_handles(compiler):
    from hpy.universal import _debug
    mod = make_leak_module(compiler)
    gen1 = _debug.new_generation()
    mod.leak('hello')
    mod.leak('world')
    gen2 = _debug.new_generation()
    mod.leak('a younger leak')
    leaks1 = _debug.get_open_handles(gen1)
    leaks2 = _debug.get_open_handles(gen2)
    leaks1 = [dh.obj for dh in leaks1]
    leaks2 = [dh.obj for dh in leaks2]
    assert leaks1 == ['hello', 'world', 'a younger leak']
    assert leaks2 == ['a younger leak']

def test_leak_from_method(compiler):
    from hpy.universal import _debug
    mod = compiler.make_module("""
        HPyDef_METH(Dummy_leak, "leak", Dummy_leak_impl, HPyFunc_O)
        static HPy Dummy_leak_impl(HPyContext *ctx, HPy self, HPy arg) {
            HPy_Dup(ctx, arg); // leak!
            return HPy_Dup(ctx, ctx->h_None);
        }
        static HPyDef *Dummy_defines[] = {
            &Dummy_leak,
            NULL
        };
        static HPyType_Spec Dummy_spec = {
            .name = "mytest.Dummy",
            .defines = Dummy_defines,
        };
        @EXPORT_TYPE("Dummy", Dummy_spec)
        @INIT
   """)
    gen = _debug.new_generation()
    obj = mod.Dummy()
    obj.leak("a")
    leaks = [dh.obj for dh in _debug.get_open_handles(gen)]
    assert leaks == ["a"]

def test_DebugHandle_id(compiler):
    from hpy.universal import _debug
    mod = make_leak_module(compiler)
    gen = _debug.new_generation()
    mod.leak('a')
    mod.leak('b')
    a1, b1 = _debug.get_open_handles(gen)
    a2, b2 = _debug.get_open_handles(gen)
    assert a1.obj == a2.obj == 'a'
    assert b1.obj == b2.obj == 'b'
    #
    assert a1 is not a2
    assert b1 is not b2
    #
    assert a1.id == a2.id
    assert b1.id == b2.id
    assert a1.id != b1.id

def test_DebugHandle_compare(compiler):
    import pytest
    from hpy.universal import _debug
    mod = make_leak_module(compiler)
    gen = _debug.new_generation()
    mod.leak('a')
    mod.leak('a')
    a2, a1 = _debug.get_open_handles(gen)
    assert a1 != a2 # same underlying object, but different DebugHandle
    #
    a2_new, a1_new = _debug.get_open_handles(gen)
    assert a1 is not a1_new  # different objects...
    assert a2 is not a2_new
    assert a1 == a1_new      # ...but same DebugHandle
    assert a2 == a2_new
    #
    with pytest.raises(TypeError):
        a1 < a2
    with pytest.raises(TypeError):
        a1 <= a2
    with pytest.raises(TypeError):
        a1 > a2
    with pytest.raises(TypeError):
        a1 >= a2

    assert not a1 == 'hello'
    assert a1 != 'hello'
    with pytest.raises(TypeError):
        a1 < 'hello'

def test_DebugHandle_repr(compiler):
    from hpy.universal import _debug
    mod = make_leak_module(compiler)
    gen = _debug.new_generation()
    mod.leak('hello')
    h_hello, = _debug.get_open_handles(gen)
    assert repr(h_hello) == "<DebugHandle 0x%x for 'hello'>" % h_hello.id

def test_LeakDetector(compiler):
    import pytest
    from hpy.debug import LeakDetector, HPyLeakError
    mod = make_leak_module(compiler)
    ld = LeakDetector()
    ld.start()
    mod.leak('hello')
    with pytest.raises(HPyLeakError) as exc:
        ld.stop()
    assert str(exc.value).startswith('1 unclosed handle:')
    #
    with pytest.raises(HPyLeakError) as exc:
        with LeakDetector():
            mod.leak('foo')
            mod.leak('bar')
            mod.leak('baz')
    msg = str(exc.value)
    assert msg.startswith('3 unclosed handles:')
    assert 'foo' in msg
    assert 'bar' in msg
    assert 'baz' in msg
    assert 'hello' not in msg
    assert 'world' not in msg

def test_closed_handles(compiler):
    from hpy.universal import _debug
    mod = make_leak_module(compiler)
    gen = _debug.new_generation()
    mod.leak('hello')
    h_hello, = _debug.get_open_handles(gen)
    assert not h_hello.is_closed
    h_hello._force_close()
    assert h_hello.is_closed
    assert _debug.get_open_handles(gen) == []
    assert h_hello in _debug.get_closed_handles()
    assert repr(h_hello) == "<DebugHandle 0x%x CLOSED>" % h_hello.id

def test_closed_handles_queue_max_size(compiler):
    from hpy.universal import _debug
    mod = compiler.make_module("""
        HPyDef_METH(f, "f", f_impl, HPyFunc_O)
        static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
        {
            return HPy_Dup(ctx, ctx->h_None);
        }
        @EXPORT(f)
        @INIT
    """)
    old_size = _debug.get_closed_handles_queue_max_size()
    try:
        # by calling "f" we open and close 3 handles: 1 for self, 1 for arg
        # and 1 for the result. So, every call to f() increases the size of
        # closed_handles() by 3
        n1 = len(_debug.get_closed_handles())
        _debug.set_closed_handles_queue_max_size(n1+7)
        assert _debug.get_closed_handles_queue_max_size() == n1+7
        #
        mod.f('aaa')
        n2 = len(_debug.get_closed_handles())
        assert n2 == n1+3
        #
        mod.f('bbb')
        n3 = len(_debug.get_closed_handles())
        assert n3 == n2+3
        # with the next call we reach the maximum size of the queue
        mod.f('ccc')
        n4 = len(_debug.get_closed_handles())
        assert n4 == n1+7
        #
        # same as before
        mod.f('ddd')
        n5 = len(_debug.get_closed_handles())
        assert n5 == n1+7
    finally:
        _debug.set_closed_handles_queue_max_size(old_size)

def test_reuse_closed_handles(compiler):
    from hpy.universal import _debug
    mod = compiler.make_module("""
        HPyDef_METH(f, "f", f_impl, HPyFunc_O)
        static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
        {
            return HPy_Dup(ctx, ctx->h_None);
        }
        HPyDef_METH(leak, "leak", leak_impl, HPyFunc_O)
        static HPy leak_impl(HPyContext *ctx, HPy self, HPy arg)
        {
            HPy_Dup(ctx, arg); // leak!
            return HPy_Dup(ctx, ctx->h_None);
        }
        @EXPORT(f)
        @EXPORT(leak)
        @INIT
    """)

    old_size = _debug.get_closed_handles_queue_max_size()
    try:
        gen = _debug.new_generation()
        # call f twice to open/closes a bunch of handles
        mod.f('hello')
        mod.f('world')
        #
        # make sure that the closed_handles queue is considered full: this
        # will force the reuse of existing closed handles
        _debug.set_closed_handles_queue_max_size(1)
        # during the call to leak, we create handles for:
        #   1. self
        #   2. arg
        #   3. HPy_Dup(arg) (leaking)
        #   4. result
        # So the leaked handle will be 3rd in the old closed_handles queue
        closed_handles = _debug.get_closed_handles()
        mod.leak('foo')
        assert not closed_handles[2].is_closed
        assert closed_handles[2].obj == 'foo'

        closed_handles = _debug.get_closed_handles()
        mod.leak('bar')
        assert not closed_handles[2].is_closed
        assert closed_handles[2].obj == 'bar'

        leaks = _debug.get_open_handles(gen)
        for h in leaks:
            h._force_close()
    finally:
        _debug.set_closed_handles_queue_max_size(old_size)

@pytest.mark.skip("Cannot recover from use-after-close on pypy")
def test_cant_use_closed_handle(compiler):
    from hpy.universal import _debug
    mod = compiler.make_module("""
        HPyDef_METH(f, "f", f_impl, HPyFunc_O, .doc="double close")
        static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
        {
            HPy h = HPy_Dup(ctx, arg);
            HPy_Close(ctx, h);
            HPy_Close(ctx, h); // double close
            return HPy_Dup(ctx, ctx->h_None);
        }

        HPyDef_METH(g, "g", g_impl, HPyFunc_O, .doc="use after close")
        static HPy g_impl(HPyContext *ctx, HPy self, HPy arg)
        {
            HPy h = HPy_Dup(ctx, arg);
            HPy_Close(ctx, h);
            return HPy_Repr(ctx, h);
        }

        @EXPORT(f)
        @EXPORT(g)
        @INIT
    """)
    n = 0
    def callback():
        nonlocal n
        n += 1
    _debug.set_on_invalid_handle(callback)
    mod.f('foo')   # double close
    assert n == 1
    mod.g('bar')   # use-after-close
    assert n == 2

