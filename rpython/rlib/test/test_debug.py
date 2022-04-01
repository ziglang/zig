import py
import pytest
from rpython.rlib.debug import (check_annotation, make_sure_not_resized,
                             debug_print, debug_start, debug_stop,
                             have_debug_prints, debug_offset, debug_flush,
                             check_nonneg, IntegerCanBeNegative,
                             mark_dict_non_null,
                             check_list_of_chars,
                             NotAListOfChars)
from rpython.rlib import debug
from rpython.rtyper.test.test_llinterp import interpret, gengraph

@pytest.fixture
def debuglog(monkeypatch):
    dlog = debug.DebugLog()
    monkeypatch.setattr(debug, '_log', dlog)
    return dlog

def test_check_annotation():
    class Error(Exception):
        pass

    def checker(ann, bk):
        from rpython.annotator.model import SomeList, SomeInteger
        if not isinstance(ann, SomeList):
            raise Error()
        if not isinstance(ann.listdef.listitem.s_value, SomeInteger):
            raise Error()

    def f(x):
        result = [x]
        check_annotation(result, checker)
        return result

    interpret(f, [3])

    def g(x):
        check_annotation(x, checker)
        return x

    py.test.raises(Error, "interpret(g, [3])")

def test_check_nonneg():
    def f(x):
        assert x >= 5
        check_nonneg(x)
    interpret(f, [9])

    def g(x):
        check_nonneg(x-1)
    py.test.raises(IntegerCanBeNegative, interpret, g, [9])

def test_make_sure_not_resized():
    from rpython.annotator.listdef import ListChangeUnallowed
    def f():
        result = [1,2,3]
        make_sure_not_resized(result)
        result.append(4)
        return len(result)

    py.test.raises(ListChangeUnallowed, interpret, f, [],
                   list_comprehension_operations=True)

def test_make_sure_not_resized_annorder():
    def f(n):
        if n > 5:
            result = None
        else:
            result = [1,2,3]
        make_sure_not_resized(result)
    interpret(f, [10])

def test_mark_dict_non_null():
    def f():
        d = {"ac": "bx"}
        mark_dict_non_null(d)
        return d

    t, typer, graph = gengraph(f, [])
    assert sorted(graph.returnblock.inputargs[0].concretetype.TO.entries.TO.OF._flds.keys()) == ['key', 'value']


def test_check_list_of_chars():
    def f(x):
        result = []
        check_list_of_chars(result)
        result = [chr(x), 'a']
        check_list_of_chars(result)
        result = [unichr(x)]
        check_list_of_chars(result)
        return result

    interpret(f, [3])

    def g(x):
        result = ['a', 'b', 'c', '']
        check_list_of_chars(result)
        return x

    py.test.raises(NotAListOfChars, "interpret(g, [3])")


def test_debug_print_start_stop(debuglog):
    def f(x):
        debug_start("mycat")
        debug_print("foo", 2, "bar", x)
        debug_stop("mycat")
        debug_flush()  # does nothing
        debug_offset()  # should not explode at least
        return have_debug_prints()

    res = f(3)
    assert res is True
    assert debuglog == [("mycat", [('debug_print', 'foo', 2, 'bar', 3)])]
    debuglog.reset()

    res = interpret(f, [3])
    assert res is True
    assert debuglog == [("mycat", [('debug_print', 'foo', 2, 'bar', 3)])]

def test_debuglog_summary(debuglog):
    debug_start('foo')
    debug_start('bar') # this is nested, so not counted in the summary by default
    debug_stop('bar')
    debug_stop('foo')
    debug_start('foo')
    debug_stop('foo')
    debug_start('bar')
    debug_stop('bar')
    #
    assert debuglog.summary() == {'foo': 2, 'bar': 1}
    assert debuglog.summary(flatten=True) == {'foo': 2, 'bar': 2}

def test_debug_start_stop_timestamp():
    import time
    def f(timestamp):
        ts_a = debug_start('foo', timestamp=timestamp)
        # simulate some CPU time
        t = time.time()
        while time.time()-t < 0.02:
            pass
        ts_b = debug_stop('foo', timestamp=timestamp)
        return ts_b - ts_a

    assert f(False) == 0
    assert f(True) > 0
    #
    res = interpret(f, [False])
    assert res == 0
    res = interpret(f, [True])
    assert res > 0


def test_debug_print_traceback():
    from rpython.translator.c.test.test_genc import compile
    from rpython.rtyper.lltypesystem import lltype
    from rpython.rtyper.lltypesystem.lloperation import llop

    def ggg(n):
        if n < 10:
            ggg(n + 1)
        else:
            raise ValueError
    def recovery():
        llop.debug_print_traceback(lltype.Void)
    recovery._dont_inline_ = True
    def fff():
        try:
            ggg(0)
        except:
            recovery()

    fn = compile(fff, [], return_stderr=True)
    stderr = fn()
    assert 'RPython traceback:\n' in stderr
    assert stderr.count('entry_point') == 1
    assert stderr.count('ggg') == 11
    assert stderr.count('recovery') == 0
