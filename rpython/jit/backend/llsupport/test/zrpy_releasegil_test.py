from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rlib.jit import dont_look_inside
from rpython.jit.metainterp.optimizeopt import ALL_OPTS_NAMES
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rlib import rposix
from rpython.rlib import rgil
from rpython.rlib.debug import debug_print

from rpython.rtyper.annlowlevel import llhelper

from rpython.jit.backend.llsupport.test.zrpy_gc_test import BaseFrameworkTests
from rpython.jit.backend.llsupport.test.zrpy_gc_test import check
from rpython.tool.udir import udir


class ReleaseGILTests(BaseFrameworkTests):
    compile_kwds = dict(enable_opts=ALL_OPTS_NAMES, thread=True)

    def define_simple(self):
        c_strchr = rffi.llexternal('strchr', [rffi.CCHARP, lltype.Signed],
                                   rffi.CCHARP)

        def before(n, x):
            return (n, None, None, None, None, None,
                    None, None, None, None, None, None)
        #

        @dont_look_inside
        def check_gil(name):
            # we may not have the GIL here, don't use "print"
            debug_print(name)
            if not rgil.am_I_holding_the_GIL():
                debug_print('assert failed at point', name)
                debug_print('rgil.gil_get_holder() ==', rgil.gil_get_holder())
                assert False

        def f(n, x, *args):
            a = rffi.str2charp(str(n))
            check_gil('before c_strchr')
            c_strchr(a, ord('0'))
            check_gil('after c_strchr')
            lltype.free(a, flavor='raw')
            n -= 1
            return (n, x) + args
        return before, f, None

    def test_simple(self):
        self.run('simple')
        assert 'call_release_gil' in udir.join('TestCompileFramework.log').read()

    def define_close_stack(self):
        #
        class Glob(object):
            pass
        glob = Glob()
        class X(object):
            pass
        #
        def callback(p1, p2):
            for i in range(100):
                glob.lst.append(X())
            return rffi.cast(rffi.INT, 1)
        CALLBACK = lltype.Ptr(lltype.FuncType([lltype.Signed,
                                               lltype.Signed], rffi.INT))
        #
        @dont_look_inside
        def alloc1():
            return llmemory.raw_malloc(16)
        @dont_look_inside
        def free1(p):
            llmemory.raw_free(p)

        c_qsort = rffi.llexternal('qsort', [rffi.VOIDP, rffi.SIZE_T,
                                            rffi.SIZE_T, CALLBACK], lltype.Void)
        #
        def f42(n):
            length = len(glob.lst)
            raw = alloc1()
            wrapper = rffi._make_wrapper_for(CALLBACK, callback, None, True)
            fn = llhelper(CALLBACK, wrapper)
            if n & 1:    # to create a loop and a bridge, and also
                pass     # to run the qsort() call in the blackhole interp
            c_qsort(rffi.cast(rffi.VOIDP, raw), rffi.cast(rffi.SIZE_T, 2),
                    rffi.cast(rffi.SIZE_T, 8), fn)
            free1(raw)
            check(len(glob.lst) > length)
            del glob.lst[:]
        #
        def before(n, x):
            glob.lst = []

            return (n, None, None, None, None, None,
                    None, None, None, None, None, None)
        #
        def f(n, x, *args):
            f42(n)
            n -= 1
            return (n, x) + args
        return before, f, None

    def test_close_stack(self):
        self.run('close_stack')
        assert 'call_release_gil' in udir.join('TestCompileFramework.log').read()

    # XXX this should also test get/set_alterrno ?
    def define_get_set_errno(self):
        eci = ExternalCompilationInfo(
            post_include_bits=[r'''
                #include <errno.h>
                static int test_get_set_errno(void) {
                    int r = errno;
                    //fprintf(stderr, "read saved errno: %d\n", r);
                    errno = 42;
                    return r;
                }
            '''])

        c_test = rffi.llexternal('test_get_set_errno', [], rffi.INT,
                                 compilation_info=eci,
                                 save_err=rffi.RFFI_FULL_ERRNO)

        def before(n, x):
            return (n, None, None, None, None, None,
                    None, None, None, None, None, None)
        #
        def f(n, x, *args):
            rposix.set_saved_errno(24)
            result1 = c_test()
            result2 = rposix.get_saved_errno()
            assert result1 == 24
            assert result2 == 42
            n -= 1
            return (n, x) + args
        return before, f, None

    def test_get_set_errno(self):
        self.run('get_set_errno')
        assert 'call_release_gil' in udir.join('TestCompileFramework.log').read()
