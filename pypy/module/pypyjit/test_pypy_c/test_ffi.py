import sys, py
from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC

class Test__ffi(BaseTestPyPyC):

    def test__ffi_call(self):
        from rpython.rlib.test.test_clibffi import get_libm_name
        def main(libm_name):
            try:
                from _rawffi.alt import CDLL, types
            except ImportError:
                sys.stderr.write('SKIP: cannot import _rawffi.alt\n')
                return 0

            libm = CDLL(libm_name)
            pow = libm.getfunc('pow', [types.double, types.double],
                               types.double)
            i = 0
            res = 0
            while i < 300:
                tmp = pow(2, 3)   # ID: fficall
                res += tmp
                i += 1
            return pow.getaddr(), res
        #
        libm_name = get_libm_name(sys.platform)
        log = self.run(main, [libm_name])
        pow_addr, res = log.result
        assert res == 8.0 * 300
        py.test.skip("XXX re-optimize _ffi for the JIT?")
        loop, = log.loops_by_filename(self.filepath)
        if 'ConstClass(pow)' in repr(loop):   # e.g. OS/X
            pow_addr = 'ConstClass(pow)'
        assert loop.match_by_id('fficall', """
            guard_not_invalidated(descr=...)
            i17 = force_token()
            setfield_gc(p0, i17, descr=<.* .*PyFrame.vable_token .*>)
            f21 = call_release_gil(%s, 2.000000, 3.000000, descr=<Callf 8 ff EF=7>)
            guard_not_forced(descr=...)
            guard_no_exception(descr=...)
        """ % pow_addr)


    def test__ffi_call_frame_does_not_escape(self):
        from rpython.rlib.test.test_clibffi import get_libm_name
        def main(libm_name):
            try:
                from _rawffi.alt import CDLL, types
            except ImportError:
                sys.stderr.write('SKIP: cannot import _rawffi.alt\n')
                return 0

            libm = CDLL(libm_name)
            pow = libm.getfunc('pow', [types.double, types.double],
                               types.double)

            def mypow(a, b):
                return pow(a, b)

            i = 0
            res = 0
            while i < 300:
                tmp = mypow(2, 3)
                res += tmp
                i += 1
            return pow.getaddr(), res
        #
        libm_name = get_libm_name(sys.platform)
        log = self.run(main, [libm_name])
        pow_addr, res = log.result
        assert res == 8.0 * 300
        loop, = log.loops_by_filename(self.filepath)
        opnames = log.opnames(loop.allops())
        # we only force the virtualref, not its content
        assert opnames.count('new_with_vtable') == 1

    def test__ffi_call_releases_gil(self):
        from rpython.rlib.clibffi import get_libc_name
        def main(libc_name, n):
            import time
            import os
            from threading import Thread
            #
            if os.name == 'nt':
                from _rawffi.alt import WinDLL, types
                libc = WinDLL('Kernel32.dll')
                sleep = libc.getfunc('Sleep', [types.uint], types.uint)
                delays = [0]*n + [1000]
            else:
                from _rawffi.alt import CDLL, types
                libc = CDLL(libc_name)
                sleep = libc.getfunc('sleep', [types.uint], types.uint)
                delays = [0]*n + [1]
            #
            def loop_of_sleeps(i, delays):
                for delay in delays:
                    sleep(delay)    # ID: sleep
            #
            threads = [Thread(target=loop_of_sleeps, args=[i, delays]) for i in range(5)]
            start = time.time()
            for i, thread in enumerate(threads):
                thread.start()
            for thread in threads:
                thread.join()
            end = time.time()
            return end - start
        log = self.run(main, [get_libc_name(), 200], threshold=150,
                       import_site=True)
        assert 1 <= log.result <= 1.5 # at most 0.5 seconds of overhead
        loops = log.loops_by_id('sleep')
        assert len(loops) == 1 # make sure that we actually JITted the loop

    def test__ffi_struct(self):
        def main():
            from _rawffi.alt import _StructDescr, Field, types
            fields = [
                Field('x', types.slong),
                ]
            descr = _StructDescr('foo', fields)
            struct = descr.allocate()
            i = 0
            while i < 300:
                x = struct.getfield('x')   # ID: getfield
                x = x+1
                struct.setfield('x', x)    # ID: setfield
                i += 1
            return struct.getfield('x')
        #
        log = self.run(main, [])
        py.test.skip("XXX re-optimize _ffi for the JIT?")
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id('getfield', """
            guard_not_invalidated(descr=...)
            i57 = getfield_raw_i(i46, descr=<FieldS dynamic 0>)
        """)
        assert loop.match_by_id('setfield', """
            setfield_raw(i44, i57, descr=<FieldS dynamic 0>)
        """)


    def test__cffi_call(self):
        from rpython.rlib.test.test_clibffi import get_libm_name
        def main(libm_name):
            try:
                import _cffi_backend
            except ImportError:
                sys.stderr.write('SKIP: cannot import _cffi_backend\n')
                return 0

            libm = _cffi_backend.load_library(libm_name)
            BDouble = _cffi_backend.new_primitive_type("double")
            BInt = _cffi_backend.new_primitive_type("int")
            BPow = _cffi_backend.new_function_type([BDouble, BInt], BDouble)
            ldexp = libm.load_function(BPow, 'ldexp')
            i = 0
            res = 0
            while i < 300:
                tmp = ldexp(1, 3)   # ID: cfficall
                res += tmp
                i += 1
            BLong = _cffi_backend.new_primitive_type("long")
            ldexp_addr = int(_cffi_backend.cast(BLong, ldexp))
            return ldexp_addr, res
        #
        libm_name = get_libm_name(sys.platform)
        log = self.run(main, [libm_name])
        ldexp_addr, res = log.result
        assert res == 8.0 * 300
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id('cfficall', """
            p96 = force_token()
            setfield_gc(p0, p96, descr=<FieldP pypy.interpreter.pyframe.PyFrame.vable_token .>)
            f97 = call_release_gil_f(91, i59, 1.0, 3, descr=<Callf 8 fi EF=7 OS=62>)
            guard_not_forced(descr=...)
            guard_no_exception(descr=...)
        """, ignore_ops=['guard_not_invalidated'])

    def test__cffi_call_c_int(self):
        if sys.platform == 'win32':
            py.test.skip("not tested on Windows (this test must pass on "
                         "other platforms, and it should work the same way)")
        def main():
            import os
            try:
                import _cffi_backend
            except ImportError:
                sys.stderr.write('SKIP: cannot import _cffi_backend\n')
                return 0

            libc = _cffi_backend.load_library(None)
            BInt = _cffi_backend.new_primitive_type("int")
            BClose = _cffi_backend.new_function_type([BInt], BInt)
            _dup = libc.load_function(BClose, 'dup')
            i = 0
            fd0, fd1 = os.pipe()
            while i < 300:
                tmp = _dup(fd0)   # ID: cfficall
                os.close(tmp)
                i += 1
            os.close(fd0)
            os.close(fd1)
            BLong = _cffi_backend.new_primitive_type("long")
            return 42
        #
        log = self.run(main, [])
        assert log.result == 42
        loop, = log.loops_by_filename(self.filepath)
        if sys.maxint > 2**32:
            extra = "i98 = int_signext(i97, 4)"
        else:
            extra = ""
        assert loop.match_by_id('cfficall', """
            p96 = force_token()
            setfield_gc(p0, p96, descr=<FieldP pypy.interpreter.pyframe.PyFrame.vable_token .>)
            i97 = call_release_gil_i(91, i59, i50, descr=<Calli 4 i EF=7 OS=62>)
            guard_not_forced(descr=...)
            guard_no_exception(descr=...)
            %s
        """ % extra, ignore_ops=['guard_not_invalidated'])

    def test__cffi_call_size_t(self):
        if sys.platform == 'win32':
            py.test.skip("not tested on Windows (this test must pass on "
                         "other platforms, and it should work the same way)")
        def main():
            import os
            try:
                import _cffi_backend
            except ImportError:
                sys.stderr.write('SKIP: cannot import _cffi_backend\n')
                return 0

            libc = _cffi_backend.load_library(None)
            BInt = _cffi_backend.new_primitive_type("int")
            BSizeT = _cffi_backend.new_primitive_type("size_t")
            BChar = _cffi_backend.new_primitive_type("char")
            BCharP = _cffi_backend.new_pointer_type(BChar)
            BWrite = _cffi_backend.new_function_type([BInt, BCharP, BSizeT],
                                                     BSizeT)  # not signed here!
            _write = libc.load_function(BWrite, 'write')
            i = 0
            fd0, fd1 = os.pipe()
            buffer = _cffi_backend.newp(BCharP, b'A')
            while i < 300:
                tmp = _write(fd1, buffer, 1)   # ID: cfficall
                assert tmp == 1
                assert os.read(fd0, 2) == b'A'
                i += 1
            os.close(fd0)
            os.close(fd1)
            return 42
        #
        log = self.run(main, [])
        assert log.result == 42
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id('cfficall', """
            p96 = force_token()
            setfield_gc(p0, p96, descr=<FieldP pypy.interpreter.pyframe.PyFrame.vable_token .>)
            i97 = call_release_gil_i(91, i59, i10, i12, 1, descr=<Calli . iii EF=7 OS=62>)
            guard_not_forced(descr=...)
            guard_no_exception(descr=...)
            p98 = call_r(ConstClass(fromrarith_int__r_uint), i97, descr=<Callr . i EF=4>)
            guard_no_exception(descr=...)
        """, ignore_ops=['guard_not_invalidated'])

    def test_cffi_call_guard_not_forced_fails(self):
        # this is the test_pypy_c equivalent of
        # rpython/jit/metainterp/test/test_fficall::test_guard_not_forced_fails
        #
        # it requires cffi to be installed for pypy in order to run
        def main():
            import sys
            try:
                import cffi
            except ImportError:
                sys.stderr.write('SKIP: cannot import cffi\n')
                return 0

            ffi = cffi.FFI()

            ffi.cdef("""
            typedef void (*functype)(int);
            int foo(int n, functype func);
            """)

            lib = ffi.verify("""
            #include <signal.h>
            typedef void (*functype)(int);

            int foo(int n, functype func) {
                if (n >= 2000) {
                    func(n);
                }
                return n*2;
            }
            """)

            @ffi.callback("functype")
            def mycallback(n):
                if n < 5000:
                    return
                # make sure that guard_not_forced fails
                d = {}
                f = sys._getframe()
                while f:
                    d.update(f.f_locals)
                    f = f.f_back

            n = 0
            while n < 10000:
                res = lib.foo(n, mycallback)  # ID: cfficall
                # this is the real point of the test: before the
                # refactor-call_release_gil branch, the assert failed when
                # res == 5000
                assert res == n*2
                n += 1
            return n

        log = self.run(main, [], import_site=True,
                       discard_stdout_before_last_line=True)  # <- for Win32
        assert log.result == 10000
        loop, = log.loops_by_id('cfficall')
        assert loop.match_by_id('cfficall', """
            ...
            i1 = call_release_gil_i(..., descr=<Calli 4 ii EF=7 OS=62>)
            ...
        """)

    def test__cffi_bug1(self):
        from rpython.rlib.test.test_clibffi import get_libm_name
        def main(libm_name):
            try:
                import _cffi_backend
            except ImportError:
                sys.stderr.write('SKIP: cannot import _cffi_backend\n')
                return 0

            libm = _cffi_backend.load_library(libm_name)
            BDouble = _cffi_backend.new_primitive_type("double")
            BSin = _cffi_backend.new_function_type([BDouble], BDouble)
            sin = libm.load_function(BSin, 'sin')

            def f(*args):
                for i in range(300):
                    sin(*args)

            f(1.0)
            f(1)
        #
        libm_name = get_libm_name(sys.platform)
        self.run(main, [libm_name])
        # assert did not crash

    def test_cffi_init_struct_with_list(self):
        def main(n):
            import sys
            try:
                import cffi
            except ImportError:
                sys.stderr.write('SKIP: cannot import cffi\n')
                return 0

            ffi = cffi.FFI()
            ffi.cdef("""
            struct s {
                short x;
                short y;
                short z;
            };
            """)

            for i in range(n):
                ffi.new("struct s *", [i, i, i])

        log = self.run(main, [300])
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
        i106 = getfield_gc_i(p20, descr=...)
        i161 = int_lt(i106, i43)
        guard_true(i161, descr=...)
        i162 = int_add(i106, 1)
        p110 = getfield_gc_r(p16, descr=...)
        setfield_gc(p20, i162, descr=...)
        guard_value(p110, ConstPtr(ptr111), descr=...)
        guard_not_invalidated(descr=...)
        p163 = force_token()
        p164 = force_token()
        p118 = getfield_gc_r(p16, descr=...)
        p120 = getarrayitem_gc_r(p118, 0, descr=...)
        guard_value(p120, ConstPtr(ptr121), descr=...)
        p122 = getfield_gc_r(p120, descr=...)
        guard_value(p122, ConstPtr(ptr123), descr=...)
        p125 = getfield_gc_r(p16, descr=...)
        guard_nonnull_class(p125, ..., descr=...)
        p999 = getfield_gc_r(p125, descr=...)
        guard_isnull(p999, descr=...)
        p127 = getfield_gc_r(p125, descr=...)
        guard_value(p127, ConstPtr(ptr128), descr=...)
        p129 = getfield_gc_r(p127, descr=...)
        guard_value(p129, ConstPtr(ptr130), descr=...)
        p132 = call_r(ConstClass(_ll_0_alloc_with_del___), descr=...)
        guard_no_exception(descr=...)
        p133 = force_token()
        p134 = new_with_vtable(descr=...)
        setfield_gc(p134, ..., descr=...)
        setfield_gc(p134, ConstPtr(null), descr=...)
        setfield_gc(p48, p134, descr=...)
        setfield_gc(p132, ..., descr=...)
        i138 = call_i(ConstClass(_ll_1_raw_malloc_varsize_zero__Signed), 6, descr=...)
        check_memory_error(i138)
        setfield_gc(p132, i138, descr=...)
        setfield_gc(p132, 0, descr=...)
        setfield_gc(p132, ConstPtr(ptr139), descr=...)
        setfield_gc(p132, -1, descr=...)
        setfield_gc(p0, p133, descr=...)
        call_may_force_n(ConstClass(_ll_2_gc_add_memory_pressure__Signed_pypy_module__cffi_backend_cdataobj_W_CDataNewStdPtr), 6, p132, descr=...)
        guard_not_forced(descr=...)
        guard_no_exception(descr=...)
        i144 = int_add(i138, 0)
        i146 = int_signext(i106, 2)
        i147 = int_ne(i106, i146)
        guard_false(i147, descr=...)
        setarrayitem_raw(i144, 0, i106, descr=...)
        i150 = int_add(i138, 2)
        setarrayitem_raw(i150, 0, i106, descr=...)
        i153 = int_add(i138, 4)
        setarrayitem_raw(i153, 0, i106, descr=...)
        p156 = getfield_gc_r(p48, descr=...)
        i158 = getfield_raw_i(..., descr=...)
        setfield_gc(p48, p49, descr=...)
        setfield_gc(p134, ConstPtr(null), descr=...)
        i159 = int_lt(i158, 0)
        guard_false(i159, descr=...)
        jump(..., descr=...)
        """)
