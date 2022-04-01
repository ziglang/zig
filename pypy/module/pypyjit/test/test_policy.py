from pypy.module.pypyjit import policy

pypypolicy = policy.PyPyJitPolicy()

def test_id_any():
    from pypy.objspace.std.intobject import W_IntObject
    assert pypypolicy.look_inside_function(W_IntObject.descr_add)

def test_rlocale():
    from rpython.rlib.rlocale import setlocale
    assert not pypypolicy.look_inside_function(setlocale)

def test_astcompiler():
    from pypy.interpreter.astcompiler import ast
    assert not pypypolicy.look_inside_function(ast.AST.walkabout)

def test_pyparser():
    from pypy.interpreter.pyparser import parser
    assert not pypypolicy.look_inside_function(parser.Grammar.__init__.im_func)

def test_property():
    from pypy.module.__builtin__.descriptor import W_Property
    assert pypypolicy.look_inside_function(W_Property.get.im_func)

def test_thread_local():
    from pypy.module.thread.os_local import Local
    from pypy.module.thread.os_thread import get_ident
    assert pypypolicy.look_inside_function(Local.getdict.im_func)
    assert pypypolicy.look_inside_function(get_ident)

def test_time():
    from pypy.module.time.interp_time import time
    assert pypypolicy.look_inside_function(time)

def test_io():
    from pypy.module._io.interp_bytesio import W_BytesIO
    assert pypypolicy.look_inside_function(W_BytesIO.seek_w.im_func)

def test_thread():
    from pypy.module.thread.os_lock import Lock
    assert pypypolicy.look_inside_function(Lock.descr_lock_acquire.im_func)

def test_select():
    from pypy.module.select.interp_select import poll
    assert pypypolicy.look_inside_function(poll)

def test_pypy_module():
    from pypy.module._collections.interp_deque import W_Deque
    from pypy.module._random.interp_random import W_Random
    assert pypypolicy.look_inside_function(W_Random.random)
    assert pypypolicy.look_inside_function(W_Deque.length)
    assert pypypolicy.look_inside_pypy_module('__builtin__.operation')
    assert pypypolicy.look_inside_pypy_module('__builtin__.abstractinst')
    assert pypypolicy.look_inside_pypy_module('__builtin__.functional')
    assert pypypolicy.look_inside_pypy_module('__builtin__.descriptor')
    assert pypypolicy.look_inside_pypy_module('exceptions.interp_exceptions')
    for modname in 'pypyjit', 'signal', 'micronumpy', 'math', 'imp':
        assert pypypolicy.look_inside_pypy_module(modname)
        assert pypypolicy.look_inside_pypy_module(modname + '.foo')
    assert not pypypolicy.look_inside_pypy_module('pypyjit.interp_resop')

def test_see_jit_module():
    assert pypypolicy.look_inside_pypy_module('pypyjit.interp_jit')
