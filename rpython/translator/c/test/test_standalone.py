import py
import sys, os, re
import textwrap

from rpython.config.translationoption import get_combined_translation_config
from rpython.config.translationoption import SUPPORT__THREAD
from rpython.rlib.objectmodel import keepalive_until_here
from rpython.rlib.rarithmetic import r_longlong
from rpython.rlib.debug import ll_assert, have_debug_prints, debug_flush
from rpython.rlib.debug import debug_print, debug_start, debug_stop
from rpython.rlib.debug import debug_offset, have_debug_prints_for
from rpython.rlib.entrypoint import entrypoint_highlevel, secondary_entrypoints
from rpython.rtyper.lltypesystem import lltype
from rpython.translator.translator import TranslationContext
from rpython.translator.backendopt import all
from rpython.translator.c.genc import CStandaloneBuilder, ExternalCompilationInfo
from rpython.annotator.listdef import s_list_of_strings
from rpython.tool.udir import udir
from rpython.translator import cdir
from rpython.conftest import option
from rpython.rlib.jit import JitDriver

def setup_module(module):
    if os.name == 'nt':
        # Do not open dreaded dialog box on segfault
        import ctypes
        SEM_NOGPFAULTERRORBOX = 0x0002 # From MSDN
        if hasattr(ctypes.windll.kernel32, 'GetErrorMode'):
            old_err_mode = ctypes.windll.kernel32.GetErrorMode()
            new_err_mode = old_err_mode | SEM_NOGPFAULTERRORBOX
            ctypes.windll.kernel32.SetErrorMode(new_err_mode)
            module.old_err_mode = old_err_mode

def teardown_module(module):
    if os.name == 'nt' and hasattr(module, 'old_err_mode'):
        import ctypes
        ctypes.windll.kernel32.SetErrorMode(module.old_err_mode)

class StandaloneTests(object):
    config = None

    def compile(self, entry_point, debug=True, shared=False,
                stackcheck=False, entrypoints=None, local_icon=None,
                exe_name=None):
        t = TranslationContext(self.config)
        ann = t.buildannotator()
        ann.build_types(entry_point, [s_list_of_strings])
        if entrypoints is not None:
            anns = {}
            for func, annotation in secondary_entrypoints['test']:
                anns[func] = annotation
            for item in entrypoints:
                ann.build_types(item, anns[item])
        t.buildrtyper().specialize()

        if stackcheck:
            from rpython.translator.transform import insert_ll_stackcheck
            insert_ll_stackcheck(t)

        t.config.translation.shared = shared
        if local_icon:
            t.config.translation.icon = os.path.join(os.path.dirname(__file__),
                                                     local_icon)

        if entrypoints is not None:
            kwds = {'secondary_entrypoints': [(i, None) for i in entrypoints]}
        else:
            kwds = {}
        cbuilder = CStandaloneBuilder(t, entry_point, t.config, **kwds)
        if debug:
            cbuilder.generate_source(defines=cbuilder.DEBUG_DEFINES,
                                     exe_name=exe_name)
        else:
            cbuilder.generate_source()
        cbuilder.compile()
        if option is not None and option.view:
            t.view()
        return t, cbuilder


class TestStandalone(StandaloneTests):

    def compile(self, *args, **kwds):
        t, builder = StandaloneTests.compile(self, *args, **kwds)
        #
        # verify that the executable re-export symbols, but not too many
        if sys.platform.startswith('linux') and not kwds.get('shared', False):
            seen = set()
            g = os.popen("objdump -T '%s'" % builder.executable_name, 'r')
            for line in g:
                if not line.strip():
                    continue
                if '*UND*' in line:
                    continue
                name = line.split()[-1]
                if name.startswith('__'):
                    continue
                seen.add(name)
                if name == 'main':
                    continue
                if name == 'pypy_debug_file':     # ok to export this one
                    continue
                if name == 'rpython_startup_code':  # ok for this one too
                    continue
                if 'pypy' in name.lower() or 'rpy' in name.lower():
                    raise Exception("Unexpected exported name %r.  "
                        "What is likely missing is RPY_EXTERN before the "
                        "declaration of this C function or global variable"
                        % (name,))
            g.close()
            # list of symbols that we *want* to be exported:
            for name in ['main', 'pypy_debug_file', 'rpython_startup_code']:
                assert name in seen, "did not see '%r' exported" % name
        #
        return t, builder

    def test_hello_world(self):
        def entry_point(argv):
            os.write(1, "hello world\n")
            argv = argv[1:]
            os.write(1, "argument count: " + str(len(argv)) + "\n")
            for s in argv:
                os.write(1, "   '" + str(s) + "'\n")
            return 0

        t, cbuilder = self.compile(entry_point, local_icon='red.ico')
        data = cbuilder.cmdexec('hi there')
        assert data.startswith('''hello world\nargument count: 2\n   'hi'\n   'there'\n''')

        # Verify that the generated C files have sane names:
        gen_c_files = [str(f) for f in cbuilder.extrafiles]
        for expfile in ('rpython_rlib.c',
                        'rpython_rtyper_lltypesystem.c',
                        'rpython_translator_c_test.c'):
            assert cbuilder.targetdir.join(expfile) in gen_c_files

    def test_print(self):
        def entry_point(argv):
            print "hello simpler world"
            argv = argv[1:]
            print "argument count:", len(argv)
            print "arguments:", argv
            print "argument lengths:",
            print [len(s) for s in argv]
            return 0

        t, cbuilder = self.compile(entry_point)
        data = cbuilder.cmdexec('hi there')
        assert data.startswith('''hello simpler world\n'''
                               '''argument count: 2\n'''
                               '''arguments: [hi, there]\n'''
                               '''argument lengths: [2, 5]\n''')
        # NB. RPython has only str, not repr, so str() on a list of strings
        # gives the strings unquoted in the list

    def test_counters(self):
        from rpython.rtyper.lltypesystem import lltype
        from rpython.rtyper.lltypesystem.lloperation import llop
        def entry_point(argv):
            llop.instrument_count(lltype.Void, 'test', 2)
            llop.instrument_count(lltype.Void, 'test', 1)
            llop.instrument_count(lltype.Void, 'test', 1)
            llop.instrument_count(lltype.Void, 'test', 2)
            llop.instrument_count(lltype.Void, 'test', 1)
            return 0
        t = TranslationContext(self.config)
        t.config.translation.instrument = True
        t.buildannotator().build_types(entry_point, [s_list_of_strings])
        t.buildrtyper().specialize()

        cbuilder = CStandaloneBuilder(t, entry_point, config=t.config) # xxx
        cbuilder.generate_source()
        cbuilder.compile()

        counters_fname = udir.join("_counters_")
        os.environ['PYPY_INSTRUMENT_COUNTERS'] = str(counters_fname)
        try:
            data = cbuilder.cmdexec()
        finally:
            del os.environ['PYPY_INSTRUMENT_COUNTERS']

        f = counters_fname.open('rb')
        counters_data = f.read()
        f.close()

        import struct
        fmt = "LLL"
        if sys.platform == 'win32' and sys.maxint > 2**31:
            fmt = "QQQ"
        counters = struct.unpack(fmt, counters_data)

        assert counters == (0,3,2)

    def test_prof_inline(self):
        py.test.skip("broken by 5b0e029514d4, but we don't use it any more")
        if sys.platform == 'win32':
            py.test.skip("instrumentation support is unix only for now")
        def add(a,b):
            return a + b - b + b - b + b - b + b - b + b - b + b - b + b
        def entry_point(argv):
            tot =  0
            x = int(argv[1])
            while x > 0:
                tot = add(tot, x)
                x -= 1
            os.write(1, str(tot))
            return 0
        from rpython.translator.interactive import Translation
        t = Translation(entry_point, backend='c')
        # no counters
        t.backendopt(inline_threshold=100, profile_based_inline="500")
        exe = t.compile()
        out = py.process.cmdexec("%s 500" % exe)
        assert int(out) == 500*501/2

        t = Translation(entry_point, backend='c')
        # counters
        t.backendopt(inline_threshold=all.INLINE_THRESHOLD_FOR_TEST*0.5,
                     profile_based_inline="500")
        exe = t.compile()
        out = py.process.cmdexec("%s 500" % exe)
        assert int(out) == 500*501/2

    def test_frexp(self):
        import math
        def entry_point(argv):
            m, e = math.frexp(0)
            x, y = math.frexp(0)
            print m, x
            return 0

        t, cbuilder = self.compile(entry_point)
        data = cbuilder.cmdexec('hi there')
        assert map(float, data.split()) == [0.0, 0.0]

    def test_profopt(self):
        if sys.platform == 'win32':
            py.test.skip("no profopt on win32")
        def add(a,b):
            return a + b - b + b - b + b - b + b - b + b - b + b - b + b
        def entry_point(argv):
            tot =  0
            x = int(argv[1])
            while x > 0:
                tot = add(tot, x)
                x -= 1
            os.write(1, str(tot))
            return 0
        from rpython.translator.interactive import Translation
        t = Translation(entry_point, backend='c', profopt=True, profoptargs="10", shared=True)
        t.backendopt()
        exe = t.compile()
        assert (os.path.isfile("%s" % exe))

        t = Translation(entry_point, backend='c', profopt=True, profoptargs="10", shared=False)
        t.backendopt()
        exe = t.compile()
        assert (os.path.isfile("%s" % exe))

        import rpython.translator.goal.targetrpystonedalone as rpy
        t = Translation(rpy.entry_point, backend='c', profopt=True, profoptargs='1000', shared=False)
        t.backendopt()
        exe = t.compile()
        assert (os.path.isfile("%s" % exe))


    if hasattr(os, 'setpgrp'):
        def test_os_setpgrp(self):
            def entry_point(argv):
                os.setpgrp()
                return 0

            t, cbuilder = self.compile(entry_point)
            cbuilder.cmdexec("")


    def test_profopt_mac_osx_bug(self):
        if sys.platform == 'win32':
            py.test.skip("no profopt on win32")
        def entry_point(argv):
            import os
            pid = os.fork()
            if pid:
                os.waitpid(pid, 0)
            else:
                os._exit(0)
            return 0
        from rpython.translator.interactive import Translation
        # XXX this is mostly a "does not crash option"
        t = Translation(entry_point, backend='c', profopt=True, profoptargs='10', shared=True)
        # no counters
        t.backendopt()
        exe = t.compile()
        #py.process.cmdexec(exe)
        t = Translation(entry_point, backend='c', profopt=True, profoptargs='10', shared=True)
        # no counters
        t.backendopt()
        exe = t.compile()
        #py.process.cmdexec(exe)

    def test_standalone_large_files(self):
        filename = str(udir.join('test_standalone_largefile'))
        r4800000000 = r_longlong(4800000000L)
        def entry_point(argv):
            assert str(r4800000000 + r_longlong(len(argv))) == '4800000003'
            fd = os.open(filename, os.O_RDWR | os.O_CREAT, 0644)
            os.lseek(fd, r4800000000, 0)
            newpos = os.lseek(fd, 0, 1)
            if newpos == r4800000000:
                print "OK"
            else:
                print "BAD POS"
            os.close(fd)
            return 0
        t, cbuilder = self.compile(entry_point)
        data = cbuilder.cmdexec('hi there')
        assert data.strip() == "OK"

    def test_separate_files(self):
        # One file in translator/c/src
        fname = py.path.local(cdir).join('src', 'll_strtod.c')

        # One file in (another) subdir of the temp directory
        dirname = udir.join("test_dir").ensure(dir=1)
        fname2 = dirname.join("test_genc.c")
        fname2.write("""
        void f() {
            LL_strtod_formatd(12.3, 'f', 5);
        }""")

        files = [fname, fname2]

        def entry_point(argv):
            return 0

        t = TranslationContext(self.config)
        t.buildannotator().build_types(entry_point, [s_list_of_strings])
        t.buildrtyper().specialize()

        cbuilder = CStandaloneBuilder(t, entry_point, t.config)
        cbuilder.eci = cbuilder.eci.merge(
            ExternalCompilationInfo(separate_module_files=files))
        cbuilder.generate_source()

        makefile = udir.join(cbuilder.modulename, 'Makefile').read()

        # generated files are compiled in the same directory
        assert "  ../test_dir/test_genc.c" in makefile
        assert "  ../test_dir/test_genc.o" in makefile

        # but files from pypy source dir must be copied
        assert "translator/c/src" not in makefile
        assert "  ll_strtod.c" in makefile
        assert "  ll_strtod.o" in makefile

    def test_debug_print_start_stop(self):
        import sys
        from rpython.rtyper.lltypesystem import rffi
        if sys.platform == 'win32':
            # ftell(stderr) is a bit different under subprocess.Popen
            tell = 0
        else:
            tell = -1
        def entry_point(argv):
            x = "got:"
            if have_debug_prints_for("my"): x += "M"
            if have_debug_prints_for("myc"): x += "m"
            debug_start  ("mycat")
            if have_debug_prints(): x += "b"
            debug_print    ("foo", r_longlong(2), "bar", 3)
            debug_start      ("cat2")
            if have_debug_prints(): x += "c"
            debug_print        ("baz")
            debug_stop       ("cat2")
            if have_debug_prints(): x += "d"
            debug_print    ("bok")
            debug_stop   ("mycat")
            if have_debug_prints(): x += "a"
            debug_print("toplevel")
            debug_print("some int", rffi.cast(rffi.INT, 3))
            debug_flush()
            os.write(1, x + "." + str(debug_offset()) + '.\n')
            return 0
        t, cbuilder = self.compile(entry_point)
        # check with PYPYLOG undefined
        out, err = cbuilder.cmdexec("", err=True, env={})
        assert out.strip() == 'got:a.%d.' % tell
        assert 'toplevel' in err
        assert 'mycat' not in err
        assert 'foo 2 bar 3' not in err
        assert 'cat2' not in err
        assert 'baz' not in err
        assert 'bok' not in err
        # check with PYPYLOG defined to an empty string (same as undefined)
        out, err = cbuilder.cmdexec("", err=True, env={'PYPYLOG': ''})
        assert out.strip() == 'got:a.%d.' % tell
        assert 'toplevel' in err
        assert 'mycat' not in err
        assert 'foo 2 bar 3' not in err
        assert 'cat2' not in err
        assert 'baz' not in err
        assert 'bok' not in err
        # check with PYPYLOG=:- (means print to stderr)
        out, err = cbuilder.cmdexec("", err=True, env={'PYPYLOG': ':-'})
        assert out.strip() == 'got:Mmbcda.%d.' % tell
        assert 'toplevel' in err
        assert '{mycat' in err
        assert 'mycat}' in err
        assert 'foo 2 bar 3' in err
        assert '{cat2' in err
        assert 'cat2}' in err
        assert 'baz' in err
        assert 'bok' in err
        assert 'some int 3' in err
        # check with PYPYLOG=:somefilename
        path = udir.join('test_debug_xxx.log')
        out, err = cbuilder.cmdexec("", err=True,
                                    env={'PYPYLOG': ':%s' % path})
        size = os.stat(str(path)).st_size
        assert out.strip() == 'got:Mmbcda.' + str(size) + '.'
        assert not err
        assert path.check(file=1)
        data = path.read()
        assert 'toplevel' in data
        assert '{mycat' in data
        assert 'mycat}' in data
        assert 'foo 2 bar 3' in data
        assert '{cat2' in data
        assert 'cat2}' in data
        assert 'baz' in data
        assert 'bok' in data
        # check with PYPYLOG=somefilename
        path = udir.join('test_debug_xxx_prof.log')
        if str(path).find(':')>=0:
            # bad choice of udir, there is a ':' in it which messes up the test
            pass
        else:
            out, err = cbuilder.cmdexec("", err=True, env={'PYPYLOG': str(path)})
            size = os.stat(str(path)).st_size
            assert out.strip() == 'got:a.' + str(size) + '.'
            assert not err
            assert path.check(file=1)
            data = path.read()
            assert 'toplevel' in data
            assert '{mycat' in data
            assert 'mycat}' in data
            assert 'foo 2 bar 3' not in data
            assert '{cat2' in data
            assert 'cat2}' in data
            assert 'baz' not in data
            assert 'bok' not in data
        # check with PYPYLOG=+somefilename
        path = udir.join('test_debug_xxx_prof_2.log')
        out, err = cbuilder.cmdexec("", err=True, env={'PYPYLOG': '+%s' % path})
        size = os.stat(str(path)).st_size
        assert out.strip() == 'got:a.' + str(size) + '.'
        assert not err
        assert path.check(file=1)
        data = path.read()
        assert 'toplevel' in data
        assert '{mycat' in data
        assert 'mycat}' in data
        assert 'foo 2 bar 3' not in data
        assert '{cat2' in data
        assert 'cat2}' in data
        assert 'baz' not in data
        assert 'bok' not in data
        # check with PYPYLOG=myc:somefilename   (includes mycat but not cat2)
        path = udir.join('test_debug_xxx_myc.log')
        out, err = cbuilder.cmdexec("", err=True,
                                    env={'PYPYLOG': 'myc:%s' % path})
        size = os.stat(str(path)).st_size
        assert out.strip() == 'got:Mmbda.' + str(size) + '.'
        assert not err
        assert path.check(file=1)
        data = path.read()
        assert 'toplevel' in data
        assert '{mycat' in data
        assert 'mycat}' in data
        assert 'foo 2 bar 3' in data
        assert 'cat2' not in data
        assert 'baz' not in data
        assert 'bok' in data
        # check with PYPYLOG=cat:somefilename   (includes cat2 but not mycat)
        path = udir.join('test_debug_xxx_cat.log')
        out, err = cbuilder.cmdexec("", err=True,
                                    env={'PYPYLOG': 'cat:%s' % path})
        size = os.stat(str(path)).st_size
        assert out.strip() == 'got:ca.' + str(size) + '.'
        assert not err
        assert path.check(file=1)
        data = path.read()
        assert 'toplevel' in data
        assert 'mycat' not in data
        assert 'foo 2 bar 3' not in data
        assert 'cat2' in data
        assert 'baz' in data
        assert 'bok' not in data
        # check with PYPYLOG=myc,cat2:somefilename   (includes mycat and cat2)
        path = udir.join('test_debug_xxx_myc_cat2.log')
        out, err = cbuilder.cmdexec("", err=True,
                                    env={'PYPYLOG': 'myc,cat2:%s' % path})
        size = os.stat(str(path)).st_size
        assert out.strip() == 'got:Mmbcda.' + str(size) + '.'
        assert not err
        assert path.check(file=1)
        data = path.read()
        assert 'toplevel' in data
        assert '{mycat' in data
        assert 'mycat}' in data
        assert 'foo 2 bar 3' in data
        assert 'cat2' in data
        assert 'baz' in data
        assert 'bok' in data
        #
        # finally, check compiling with logging disabled
        config = get_combined_translation_config(translating=True)
        config.translation.log = False
        self.config = config
        t, cbuilder = self.compile(entry_point)
        path = udir.join('test_debug_does_not_show_up.log')
        out, err = cbuilder.cmdexec("", err=True,
                                    env={'PYPYLOG': ':%s' % path})
        assert out.strip() == 'got:.-1.'
        assert not err
        assert path.check(file=0)

    def test_debug_start_stop_timestamp(self):
        from rpython.rlib.rtimer import read_timestamp
        def entry_point(argv):
            timestamp = bool(int(argv[1]))
            ts1 = debug_start("foo", timestamp=timestamp)
            ts2 = read_timestamp()
            ts3 = debug_stop("foo", timestamp=timestamp)
            print ts1
            print ts2
            print ts3
            return 0
        t, cbuilder = self.compile(entry_point)

        def parse_out(out):
            lines = out.strip().splitlines()
            ts1, ts2, ts3 = lines
            return int(ts1), int(ts2), int(ts3)

        # check with PYPYLOG :-
        out, err = cbuilder.cmdexec("1", err=True, env={'PYPYLOG': ':-'})
        ts1, ts2, ts3 = parse_out(out)
        assert ts3 > ts2 > ts1
        expected = ('[%x] {foo\n' % ts1 +
                    '[%x] foo}\n' % ts3)
        assert err == expected

        # check with PYPYLOG profiling only
        out, err = cbuilder.cmdexec("1", err=True, env={'PYPYLOG': '-'})
        ts1, ts2, ts3 = parse_out(out)
        assert ts3 > ts2 > ts1
        expected = ('[%x] {foo\n' % ts1 +
                    '[%x] foo}\n' % ts3)
        assert err == expected

        # check with PYPYLOG undefined
        out, err = cbuilder.cmdexec("1", err=True, env={})
        ts1, ts2, ts3 = parse_out(out)
        assert ts3 > ts2 > ts1

        # check with PYPYLOG undefined and timestamp=False
        out, err = cbuilder.cmdexec("0", err=True, env={})
        ts1, ts2, ts3 = parse_out(out)
        assert ts1 == ts3 == 42;

    def test_debug_print_start_stop_nonconst(self):
        def entry_point(argv):
            debug_start(argv[1])
            debug_print(argv[2])
            debug_stop(argv[1])
            return 0
        t, cbuilder = self.compile(entry_point)
        out, err = cbuilder.cmdexec("foo bar", err=True, env={'PYPYLOG': ':-'})
        lines = err.splitlines()
        assert '{foo' in lines[0]
        assert 'bar' == lines[1]
        assert 'foo}' in lines[2]

    def test_debug_print_fork(self):
        if not hasattr(os, 'fork'):
            py.test.skip("requires fork()")

        def entry_point(argv):
            print "parentpid =", os.getpid()
            debug_start("foo")
            debug_print("test line")
            childpid = os.fork()
            debug_print("childpid =", childpid)
            if childpid == 0:
                childpid2 = os.fork()   # double-fork
                debug_print("childpid2 =", childpid2)
            debug_stop("foo")
            return 0
        t, cbuilder = self.compile(entry_point)
        path = udir.join('test_debug_print_fork.log')
        out, err = cbuilder.cmdexec("", err=True,
                                    env={'PYPYLOG': ':%s.%%d' % path})
        assert not err
        import time
        time.sleep(0.5)    # time for the forked children to finish
        #
        lines = out.splitlines()
        assert lines[-1].startswith('parentpid = ')
        parentpid = int(lines[-1][12:])
        #
        f = open('%s.%d' % (path, parentpid), 'r')
        lines = f.readlines()
        f.close()
        assert '{foo' in lines[0]
        assert lines[1] == "test line\n"
        #offset1 = len(lines[0]) + len(lines[1])
        assert lines[2].startswith('childpid = ')
        childpid = int(lines[2][11:])
        assert childpid != 0
        assert 'foo}' in lines[3]
        assert len(lines) == 4
        #
        f = open('%s.%d' % (path, childpid), 'r')
        lines = f.readlines()
        f.close()
        #assert lines[0] == 'FORKED: %d %s\n' % (offset1, path)
        assert lines[0] == 'childpid = 0\n'
        #offset2 = len(lines[0]) + len(lines[1])
        assert lines[1].startswith('childpid2 = ')
        childpid2 = int(lines[1][11:])
        assert childpid2 != 0
        assert 'foo}' in lines[2]
        assert len(lines) == 3
        #
        f = open('%s.%d' % (path, childpid2), 'r')
        lines = f.readlines()
        f.close()
        #assert lines[0] == 'FORKED: %d %s.fork%d\n' % (offset2, path, childpid)
        assert lines[0] == 'childpid2 = 0\n'
        assert 'foo}' in lines[1]
        assert len(lines) == 2

    def test_debug_flush_at_exit(self):
        def entry_point(argv):
            debug_start("mycat")
            os._exit(0)
            return 0

        t, cbuilder = self.compile(entry_point)
        path = udir.join('test_debug_flush_at_exit.log')
        cbuilder.cmdexec("", env={'PYPYLOG': ':%s' % path})
        #
        f = open(str(path), 'r')
        lines = f.readlines()
        f.close()
        assert lines[0].endswith('{mycat\n')

    def test_fatal_error(self):
        def g(x):
            if x == 1:
                raise ValueError
            else:
                raise KeyError
        def entry_point(argv):
            if len(argv) < 3:
                g(len(argv))
            return 0
        t, cbuilder = self.compile(entry_point)
        #
        out, err = cbuilder.cmdexec("", expect_crash=True)
        assert out.strip() == ''
        lines = err.strip().splitlines()
        idx = lines.index('Fatal RPython error: ValueError')   # assert found
        lines = lines[:idx+1]
        assert len(lines) >= 5
        l0, lx, l1, l2 = lines[-5:-1]
        assert l0 == 'RPython traceback:'
        # lx is a bit strange with reference counting, ignoring it
        assert re.match(r'  File "\w+.c", line \d+, in entry_point', l1)
        assert re.match(r'  File "\w+.c", line \d+, in g', l2)
        #
        out2, err2 = cbuilder.cmdexec("x", expect_crash=True)
        assert out2.strip() == ''
        lines2 = err2.strip().splitlines()
        idx = lines2.index('Fatal RPython error: KeyError')    # assert found
        lines2 = lines2[:idx+1]
        l0, lx, l1, l2 = lines2[-5:-1]
        assert l0 == 'RPython traceback:'
        # lx is a bit strange with reference counting, ignoring it
        assert re.match(r'  File "\w+.c", line \d+, in entry_point', l1)
        assert re.match(r'  File "\w+.c", line \d+, in g', l2)
        assert lines2[-2] != lines[-2]    # different line number
        assert lines2[-3] == lines[-3]    # same line number

    def test_fatal_error_finally_1(self):
        # a simple case of try:finally:
        def g(x):
            if x == 1:
                raise KeyError
        def h(x):
            try:
                g(x)
            finally:
                os.write(1, 'done.\n')
        def entry_point(argv):
            if len(argv) < 3:
                h(len(argv))
            return 0
        t, cbuilder = self.compile(entry_point)
        #
        out, err = cbuilder.cmdexec("", expect_crash=True)
        assert out.strip() == 'done.'
        lines = err.strip().splitlines()
        idx = lines.index('Fatal RPython error: KeyError')    # assert found
        lines = lines[:idx+1]
        assert len(lines) >= 6
        l0, lx, l1, l2, l3 = lines[-6:-1]
        assert l0 == 'RPython traceback:'
        # lx is a bit strange with reference counting, ignoring it
        assert re.match(r'  File "\w+.c", line \d+, in entry_point', l1)
        assert re.match(r'  File "\w+.c", line \d+, in h', l2)
        assert re.match(r'  File "\w+.c", line \d+, in g', l3)

    def test_fatal_error_finally_2(self):
        # a try:finally: in which we raise and catch another exception
        def raiseme(x):
            if x == 1:
                raise ValueError
        def raise_and_catch(x):
            try:
                raiseme(x)
            except ValueError:
                pass
        def g(x):
            if x == 1:
                raise KeyError
        def h(x):
            try:
                g(x)
            finally:
                raise_and_catch(x)
                os.write(1, 'done.\n')
        def entry_point(argv):
            if len(argv) < 3:
                h(len(argv))
            return 0
        t, cbuilder = self.compile(entry_point)
        #
        out, err = cbuilder.cmdexec("", expect_crash=True)
        assert out.strip() == 'done.'
        lines = err.strip().splitlines()
        idx = lines.index('Fatal RPython error: KeyError')     # assert found
        lines = lines[:idx+1]
        assert len(lines) >= 6
        l0, lx, l1, l2, l3 = lines[-6:-1]
        assert l0 == 'RPython traceback:'
        # lx is a bit strange with reference counting, ignoring it
        assert re.match(r'  File "\w+.c", line \d+, in entry_point', l1)
        assert re.match(r'  File "\w+.c", line \d+, in h', l2)
        assert re.match(r'  File "\w+.c", line \d+, in g', l3)

    def test_fatal_error_finally_3(self):
        py.test.skip("not implemented: "
                     "a try:finally: in which we raise the *same* exception")

    def test_fatal_error_finally_4(self):
        # a try:finally: in which we raise (and don't catch) an exception
        def raiseme(x):
            if x == 1:
                raise ValueError
        def g(x):
            if x == 1:
                raise KeyError
        def h(x):
            try:
                g(x)
            finally:
                raiseme(x)
                os.write(1, 'done.\n')
        def entry_point(argv):
            if len(argv) < 3:
                h(len(argv))
            return 0
        t, cbuilder = self.compile(entry_point)
        #
        out, err = cbuilder.cmdexec("", expect_crash=True)
        assert out.strip() == ''
        lines = err.strip().splitlines()
        idx = lines.index('Fatal RPython error: ValueError')    # assert found
        lines = lines[:idx+1]
        assert len(lines) >= 6
        l0, lx, l1, l2, l3 = lines[-6:-1]
        assert l0 == 'RPython traceback:'
        # lx is a bit strange with reference counting, ignoring it
        assert re.match(r'  File "\w+.c", line \d+, in entry_point', l1)
        assert re.match(r'  File "\w+.c", line \d+, in h', l2)
        assert re.match(r'  File "\w+.c", line \d+, in raiseme', l3)

    def test_assertion_error_debug(self):
        def entry_point(argv):
            assert len(argv) != 1
            return 0
        t, cbuilder = self.compile(entry_point, debug=True)
        out, err = cbuilder.cmdexec("", expect_crash=True)
        assert out.strip() == ''
        lines = err.strip().splitlines()
        assert 'in pypy_g_RPyRaiseException: AssertionError' in lines

    def test_assertion_error_nondebug(self):
        def g(x):
            assert x != 1
        def f(argv):
            try:
                g(len(argv))
            finally:
                print 'done'
        def entry_point(argv):
            f(argv)
            return 0
        t, cbuilder = self.compile(entry_point, debug=False)
        out, err = cbuilder.cmdexec("", expect_crash=True)
        assert out.strip() == ''
        lines = err.strip().splitlines()
        idx = lines.index('Fatal RPython error: AssertionError') # assert found
        lines = lines[:idx+1]
        assert len(lines) >= 4
        l0, l1, l2 = lines[-4:-1]
        assert l0 == 'RPython traceback:'
        assert re.match(r'  File "\w+.c", line \d+, in f', l1)
        assert re.match(r'  File "\w+.c", line \d+, in g', l2)
        # The traceback stops at f() because it's the first function that
        # captures the AssertionError, which makes the program abort.

    def test_int_lshift_too_large(self):
        from rpython.rlib.rarithmetic import LONG_BIT, LONGLONG_BIT
        def entry_point(argv):
            a = int(argv[1])
            b = int(argv[2])
            print a << b
            return 0

        t, cbuilder = self.compile(entry_point, debug=True)
        out = cbuilder.cmdexec("10 2", expect_crash=False)
        assert out.strip() == str(10 << 2)
        cases = [-4, LONG_BIT, LONGLONG_BIT]
        for x in cases:
            out, err = cbuilder.cmdexec("%s %s" % (1, x), expect_crash=True)
            lines = err.strip()
            assert 'The shift count is outside of the supported range' in lines

    def test_llong_rshift_too_large(self):
        from rpython.rlib.rarithmetic import LONG_BIT, LONGLONG_BIT
        def entry_point(argv):
            a = r_longlong(int(argv[1]))
            b = r_longlong(int(argv[2]))
            print a >> b
            return 0

        t, cbuilder = self.compile(entry_point, debug=True)
        out = cbuilder.cmdexec("10 2", expect_crash=False)
        assert out.strip() == str(10 >> 2)
        out = cbuilder.cmdexec("%s %s" % (-42, LONGLONG_BIT - 1), expect_crash=False)
        assert out.strip() == '-1'
        cases = [-4, LONGLONG_BIT]
        for x in cases:
            out, err = cbuilder.cmdexec("%s %s" % (1, x), expect_crash=True)
            lines = err.strip()
            assert 'The shift count is outside of the supported range' in lines

    def test_ll_assert_error_debug(self):
        def entry_point(argv):
            ll_assert(len(argv) != 1, "foobar")
            return 0
        t, cbuilder = self.compile(entry_point, debug=True)
        out, err = cbuilder.cmdexec("", expect_crash=True)
        assert out.strip() == ''
        lines = err.strip().splitlines()
        assert 'in pypy_g_entry_point: foobar' in lines

    def test_ll_assert_error_nondebug(self):
        py.test.skip("implement later, maybe: tracebacks even with ll_assert")
        def g(x):
            ll_assert(x != 1, "foobar")
        def f(argv):
            try:
                g(len(argv))
            finally:
                print 'done'
        def entry_point(argv):
            f(argv)
            return 0
        t, cbuilder = self.compile(entry_point)
        out, err = cbuilder.cmdexec("", expect_crash=True)
        assert out.strip() == ''
        lines = err.strip().splitlines()
        idx = lines.index('PyPy assertion failed: foobar')    # assert found
        lines = lines[:idx+1]
        assert len(lines) >= 4
        l0, l1, l2 = lines[-4:-1]
        assert l0 == 'RPython traceback:'
        assert re.match(r'  File "\w+.c", line \d+, in f', l1)
        assert re.match(r'  File "\w+.c", line \d+, in g', l2)
        # The traceback stops at f() because it's the first function that
        # captures the AssertionError, which makes the program abort.

    def test_shared1(self, monkeypatch):
        def f(argv):
            print len(argv)
        def entry_point(argv):
            f(argv)
            return 0
        # Make sure the '.' in exe_name is propagated
        t, cbuilder = self.compile(entry_point, shared=True, exe_name='pypy3.9')
        assert 'pypy3.9' in str(cbuilder.executable_name)
        assert cbuilder.shared_library_name is not None
        assert cbuilder.shared_library_name != cbuilder.executable_name
        assert 'exe' not in str(cbuilder.shared_library_name)
        # it must be something with a '.basename' to make the driver.py happy
        assert not isinstance(cbuilder.shared_library_name, str)
        assert 'pypy3.9' in str(cbuilder.shared_library_name)
        #Do not set LD_LIBRARY_PATH, make sure $ORIGIN flag is working
        out, err = cbuilder.cmdexec("a b")
        assert out == "3"
        if sys.platform == 'win32':
            assert 'pypy3.9.exe' not in str(cbuilder.shared_library_name)
            assert 'pypy3.9.exe' in str(cbuilder.executable_name)
            # Make sure we have a pypy3.9w.exe
            # Since stdout, stderr are piped, we will get output
            exe = cbuilder.executable_name
            wexe = exe.new(purebasename=exe.purebasename + 'w')
            out, err = cbuilder.cmdexec("a b", exe = wexe)
            assert out == "3"

    def test_shared2(self, monkeypatch):
        def f(argv):
            print len(argv)
        def entry_point(argv):
            f(argv)
            return 0
        # Make sure the '.exe' in exe_name is not propagated
        t, cbuilder = self.compile(entry_point, shared=True, exe_name='pypy')
        assert 'pypy' == cbuilder.executable_name.purebasename
        assert 'libpypy' == cbuilder.shared_library_name.purebasename

    def test_gcc_options(self):
        # check that the env var CC is correctly interpreted, even if
        # it contains the compiler name followed by some options.
        if sys.platform == 'win32':
            py.test.skip("only for gcc")

        from rpython.rtyper.lltypesystem import lltype, rffi
        dir = udir.ensure('test_gcc_options', dir=1)
        dir.join('someextraheader.h').write('#define someextrafunc() 42\n')
        eci = ExternalCompilationInfo(includes=['someextraheader.h'])
        someextrafunc = rffi.llexternal('someextrafunc', [], lltype.Signed,
                                        compilation_info=eci)

        def entry_point(argv):
            return someextrafunc()

        old_cc = os.environ.get('CC')
        try:
            os.environ['CC'] = 'gcc -I%s' % dir
            t, cbuilder = self.compile(entry_point)
        finally:
            if old_cc is None:
                del os.environ['CC']
            else:
                os.environ['CC'] = old_cc

    def test_inhibit_tail_call(self):
        # the point is to check that the f()->f() recursion stops
        from rpython.rlib.rstackovf import StackOverflow
        class Glob:
            pass
        glob = Glob()
        def f(n):
            glob.n = n
            if n <= 0:
                return 42
            return f(n+1)
        def entry_point(argv):
            try:
                return f(1)
            except StackOverflow:
                print 'hi!', glob.n
                return 0
        t, cbuilder = self.compile(entry_point, stackcheck=True)
        out = cbuilder.cmdexec("")
        text = out.strip()
        assert text.startswith("hi! ")
        n = int(text[4:])
        assert n > 500 and n < 5000000

    def test_set_length_fraction(self):
        # check for rpython.rlib.rstack._stack_set_length_fraction()
        from rpython.rlib.rstack import _stack_set_length_fraction
        from rpython.rlib.rstackovf import StackOverflow
        class A:
            n = 0
        glob = A()
        def f(n):
            glob.n += 1
            if n <= 0:
                return 42
            return f(n+1)
        def entry_point(argv):
            _stack_set_length_fraction(0.1)
            try:
                return f(1)
            except StackOverflow:
                glob.n = 0
            _stack_set_length_fraction(float(argv[1]))
            try:
                return f(1)
            except StackOverflow:
                print glob.n
                return 0
        t, cbuilder = self.compile(entry_point, stackcheck=True)
        counts = {}
        for fraction in [0.1, 0.4, 1.0]:
            out = cbuilder.cmdexec(str(fraction))
            print 'counts[%s]: %r' % (fraction, out)
            counts[fraction] = int(out.strip())
        #
        assert counts[1.0] >= 1000
        # ^^^ should actually be much more than 1000 for this small test
        assert counts[0.1] < counts[0.4] / 3
        assert counts[0.4] < counts[1.0] / 2
        assert counts[0.1] > counts[0.4] / 7
        assert counts[0.4] > counts[1.0] / 4

    def test_stack_criticalcode(self):
        # check for rpython.rlib.rstack._stack_criticalcode_start/stop()
        from rpython.rlib.rstack import _stack_criticalcode_start
        from rpython.rlib.rstack import _stack_criticalcode_stop
        from rpython.rlib.rstackovf import StackOverflow
        class A:
            pass
        glob = A()
        def f(n):
            if n <= 0:
                return 42
            try:
                return f(n+1)
            except StackOverflow:
                if glob.caught:
                    print 'Oups! already caught!'
                glob.caught = True
                _stack_criticalcode_start()
                critical(100)   # recurse another 100 times here
                _stack_criticalcode_stop()
                return 789
        def critical(n):
            if n > 0:
                n = critical(n - 1)
            return n - 42
        def entry_point(argv):
            glob.caught = False
            print f(1)
            return 0
        t, cbuilder = self.compile(entry_point, stackcheck=True)
        out = cbuilder.cmdexec('')
        assert out.strip() == '789'

    def test_llhelper_stored_in_struct(self):
        from rpython.rtyper.annlowlevel import llhelper

        def f(x):
            return x + 3

        FUNC_TP = lltype.Ptr(lltype.FuncType([lltype.Signed], lltype.Signed))

        S = lltype.GcStruct('s', ('f', FUNC_TP))

        class Glob(object):
            pass

        glob = Glob()

        def entry_point(argv):
            x = llhelper(FUNC_TP, f)
            s = lltype.malloc(S)
            s.f = x
            glob.s = s # escape
            return 0

        self.compile(entry_point)
        # assert did not explode

    def test_unicode_builder(self):
        import random
        from rpython.rlib.rstring import UnicodeBuilder

        to_do = []
        for i in range(15000):
            to_do.append(random.randrange(0, 100000))
        to_do.append(0)

        expected = []
        s = ''
        for x in to_do:
            if x < 1500:
                expected.append("``%s''" % (s,))
                if x < 1000:
                    s = ''
            elif x < 20000:
                s += chr(32 + (x & 63))
            elif x < 30000:
                s += chr(32 + (x & 63)) * (x % 93)
            else:
                s += str(x)
        expected = '\n'.join(expected)

        def entry_point(argv):
            b = UnicodeBuilder(32)
            for x in to_do:
                if x < 1500:
                    print "``%s''" % str(b.build())
                    if x < 1000:
                        b = UnicodeBuilder(32)
                elif x < 20000:
                    b.append(unichr(32 + (x & 63)))
                elif x < 30000:
                    b.append_multiple_char(unichr(32 + (x & 63)), x % 93)
                else:
                    b.append(unicode(str(x)))
            return 0

        t, cbuilder = self.compile(entry_point)
        out = cbuilder.cmdexec('')
        assert out.strip() == expected

    def test_call_at_startup(self):
        from rpython.rtyper.extregistry import ExtRegistryEntry

        class State:
            seen = 0
        state = State()
        def startup():
            state.seen += 1
        def enablestartup():
            "NOT_RPYTHON"
        def entry_point(argv):
            state.seen += 100
            assert state.seen == 101
            print 'ok'
            enablestartup()
            return 0

        class Entry(ExtRegistryEntry):
            _about_ = enablestartup

            def compute_result_annotation(self):
                bk = self.bookkeeper
                s_callable = bk.immutablevalue(startup)
                key = (enablestartup,)
                bk.emulate_pbc_call(key, s_callable, [])

            def specialize_call(self, hop):
                hop.exception_cannot_occur()
                bk = hop.rtyper.annotator.bookkeeper
                s_callable = bk.immutablevalue(startup)
                r_callable = hop.rtyper.getrepr(s_callable)
                ll_init = r_callable.get_unique_llfn().value
                bk.annotator.translator._call_at_startup.append(ll_init)

        t, cbuilder = self.compile(entry_point)
        out = cbuilder.cmdexec('')
        assert out.strip() == 'ok'

    def test_gcc_precompiled_header(self):
        if sys.platform == 'win32':
            py.test.skip("no win")
        def entry_point(argv):
            os.write(1, "hello world\n")
            argv = argv[1:]
            os.write(1, "argument count: " + str(len(argv)) + "\n")
            for s in argv:
                os.write(1, "   '" + str(s) + "'\n")
            return 0

        t, cbuilder = self.compile(entry_point)
        if "gcc" not in t.platform.cc:
            py.test.skip("gcc only")
        data = cbuilder.cmdexec('hi there')
        assert data.startswith('''hello world\nargument count: 2\n   'hi'\n   'there'\n''')

        # check that the precompiled header was generated
        assert cbuilder.targetdir.join("singleheader.h.gch").check()


class TestThread(object):
    gcrootfinder = 'shadowstack'
    config = None

    def compile(self, entry_point, no__thread=True):
        t = TranslationContext(self.config)
        t.config.translation.gc = "incminimark"
        t.config.translation.gcrootfinder = self.gcrootfinder
        t.config.translation.thread = True
        t.config.translation.no__thread = no__thread
        t.buildannotator().build_types(entry_point, [s_list_of_strings])
        t.buildrtyper().specialize()
        #
        cbuilder = CStandaloneBuilder(t, entry_point, t.config)
        cbuilder.generate_source(defines=cbuilder.DEBUG_DEFINES)
        cbuilder.compile()
        #
        return t, cbuilder


    def test_stack_size(self):
        import time
        from rpython.rlib import rthread
        from rpython.rtyper.lltypesystem import lltype

        class State:
            pass
        state = State()

        def recurse(n):
            if n > 0:
                return recurse(n-1)+1
            else:
                time.sleep(0.2)      # invokes before/after
                return 0

        # recurse a lot
        RECURSION = 19500
        if sys.platform == 'win32':
            # If I understand it correctly:
            # - The stack size "reserved" for a new thread is a compile-time
            #   option (by default: 1Mb).  This is a minimum that user code
            #   cannot control.
            # - set_stacksize() only sets the initially "committed" size,
            #   which eventually requires a larger "reserved" size.
            # - The limit below is large enough to exceed the "reserved" size,
            #   for small values of set_stacksize().
            RECURSION = 150 * 1000

        def bootstrap():
            recurse(RECURSION)
            state.count += 1

        def entry_point(argv):
            os.write(1, "hello world\n")
            error = rthread.set_stacksize(int(argv[1]))
            if error != 0:
                os.write(2, "set_stacksize(%d) returned %d\n" % (
                    int(argv[1]), error))
                raise AssertionError
            # malloc a bit
            s1 = State(); s2 = State(); s3 = State()
            s1.x = 0x11111111; s2.x = 0x22222222; s3.x = 0x33333333
            # start 3 new threads
            state.count = 0
            ident1 = rthread.start_new_thread(bootstrap, ())
            ident2 = rthread.start_new_thread(bootstrap, ())
            ident3 = rthread.start_new_thread(bootstrap, ())
            # wait for the 3 threads to finish
            while True:
                if state.count == 3:
                    break
                time.sleep(0.1)      # invokes before/after
            # check that the malloced structures were not overwritten
            assert s1.x == 0x11111111
            assert s2.x == 0x22222222
            assert s3.x == 0x33333333
            os.write(1, "done\n")
            return 0

        t, cbuilder = self.compile(entry_point)

        # recursing should crash with only 32 KB of stack,
        # and it should eventually work with more stack
        for test_kb in [32, 128, 512, 1024, 2048, 4096, 8192, 16384,
                        32768, 65536]:
            print >> sys.stderr, 'Trying with %d KB of stack...' % (test_kb,),
            try:
                data = cbuilder.cmdexec(str(test_kb * 1024))
            except Exception as e:
                if e.__class__ is not Exception:
                    raise
                print >> sys.stderr, 'segfault'
                # got a segfault! try with the next stack size...
            else:
                # it worked
                print >> sys.stderr, 'ok'
                assert data == 'hello world\ndone\n'
                assert test_kb > 32   # it cannot work with just 32 KB of stack
                break    # finish
        else:
            py.test.fail("none of the stack sizes worked")


    def test_thread_and_gc(self):
        import time, gc
        from rpython.rlib import rthread, rposix
        from rpython.rtyper.lltypesystem import lltype

        class State:
            pass
        state = State()

        class Cons:
            def __init__(self, head, tail):
                self.head = head
                self.tail = tail

        def check_errno(value):
            rposix.set_saved_errno(value)
            for i in range(10000000):
                pass
            assert rposix.get_saved_errno() == value

        def bootstrap():
            rthread.gc_thread_start()
            check_errno(42)
            state.xlist.append(Cons(123, Cons(456, None)))
            gc.collect()
            rthread.gc_thread_die()

        def new_thread():
            ident = rthread.start_new_thread(bootstrap, ())
            check_errno(41)
            time.sleep(0.5)    # enough time to start, hopefully
            return ident

        def entry_point(argv):
            os.write(1, "hello world\n")
            state.xlist = []
            x2 = Cons(51, Cons(62, Cons(74, None)))
            # start 5 new threads
            ident1 = new_thread()
            ident2 = new_thread()
            #
            gc.collect()
            #
            ident3 = new_thread()
            ident4 = new_thread()
            ident5 = new_thread()
            # wait for the 5 threads to finish
            while True:
                gc.collect()
                if len(state.xlist) == 5:
                    break
                time.sleep(0.1)      # invokes before/after
            # check that the malloced structures were not overwritten
            assert x2.head == 51
            assert x2.tail.head == 62
            assert x2.tail.tail.head == 74
            assert x2.tail.tail.tail is None
            # check the structures produced by the threads
            for i in range(5):
                assert state.xlist[i].head == 123
                assert state.xlist[i].tail.head == 456
                assert state.xlist[i].tail.tail is None
                os.write(1, "%d ok\n" % (i+1))
            return 0

        def runme(no__thread):
            t, cbuilder = self.compile(entry_point, no__thread=no__thread)
            data = cbuilder.cmdexec('')
            assert data.splitlines() == ['hello world',
                                         '1 ok',
                                         '2 ok',
                                         '3 ok',
                                         '4 ok',
                                         '5 ok']

        if SUPPORT__THREAD:
            runme(no__thread=False)
        runme(no__thread=True)


    def test_gc_with_fork_without_threads(self):
        if not hasattr(os, 'fork'):
            py.test.skip("requires fork()")

        def entry_point(argv):
            childpid = os.fork()
            if childpid == 0:
                print "Testing..."
            else:
                pid, status = os.waitpid(childpid, 0)
                assert pid == childpid
                assert status == 0
                print "OK."
            return 0

        t, cbuilder = self.compile(entry_point)
        data = cbuilder.cmdexec('')
        print repr(data)
        assert data.startswith('Testing...\nOK.')

    def test_thread_and_gc_with_fork(self):
        # This checks that memory allocated for the shadow stacks of the
        # other threads is really released when doing a fork() -- or at
        # least that the object referenced from stacks that are no longer
        # alive are really freed.
        import time, gc, os
        from rpython.rlib import rthread
        if not hasattr(os, 'fork'):
            py.test.skip("requires fork()")

        from rpython.rtyper.lltypesystem import rffi, lltype
        direct_write = rffi.llexternal(
            "write", [rffi.INT, rffi.CCHARP, rffi.SIZE_T], lltype.Void,
            _nowrapper=True)

        class State:
            pass
        state = State()

        class Cons:
            def __init__(self, head, tail):
                self.head = head
                self.tail = tail

        class Stuff:
            def __del__(self):
                p = rffi.str2charp('d')
                one = rffi.cast(rffi.SIZE_T, 1)
                direct_write(rffi.cast(rffi.INT, state.write_end), p, one)
                rffi.free_charp(p)

        def allocate_stuff():
            s = Stuff()
            os.write(state.write_end, 'a')
            return s

        def run_in_thread():
            for i in range(10):
                state.xlist.append(Cons(123, Cons(456, None)))
                time.sleep(0.01)
            childpid = os.fork()
            return childpid

        def bootstrap():
            rthread.gc_thread_start()
            childpid = run_in_thread()
            gc.collect()        # collect both in the child and in the parent
            gc.collect()
            gc.collect()
            if childpid == 0:
                os.write(state.write_end, 'c')   # "I did not die!" from child
            else:
                os.write(state.write_end, 'p')   # "I did not die!" from parent
            rthread.gc_thread_die()

        def new_thread():
            ident = rthread.start_new_thread(bootstrap, ())
            time.sleep(0.5)    # enough time to start, hopefully
            return ident

        def start_arthreads():
            s = allocate_stuff()
            ident1 = new_thread()
            ident2 = new_thread()
            ident3 = new_thread()
            ident4 = new_thread()
            ident5 = new_thread()
            # wait for 4 more seconds, which should be plenty of time
            time.sleep(4)
            keepalive_until_here(s)

        def entry_point(argv):
            os.write(1, "hello world\n")
            state.xlist = []
            state.deleted = 0
            state.read_end, state.write_end = os.pipe()
            x2 = Cons(51, Cons(62, Cons(74, None)))
            # start 5 new threads
            start_arthreads()
            # force freeing
            gc.collect()
            gc.collect()
            gc.collect()
            # return everything that was written to the pipe so far,
            # followed by the final dot.
            os.write(state.write_end, '.')
            result = os.read(state.read_end, 256)
            os.write(1, "got: %s\n" % result)
            return 0

        t, cbuilder = self.compile(entry_point)
        data = cbuilder.cmdexec('')
        print repr(data)
        header, footer = data.splitlines()
        assert header == 'hello world'
        assert footer.startswith('got: ')
        result = footer[5:]
        # check that all 5 threads and 5 forked processes
        # finished successfully, that we did 1 allocation,
        # and that it was freed 6 times -- once in the parent
        # process and once in every child process.
        assert (result[-1] == '.'
                and result.count('c') == result.count('p') == 5
                and result.count('a') == 1
                and result.count('d') == 6)


class TestShared(StandaloneTests):

    def test_entrypoint(self):
        import ctypes

        config = get_combined_translation_config(translating=True)
        self.config = config

        @entrypoint_highlevel('test', [lltype.Signed], c_name='foo')
        def f(a):
            return a + 3

        def entry_point(argv):
            return 0

        t, cbuilder = self.compile(entry_point, shared=True,
                                   entrypoints=[f.exported_wrapper],
                                   local_icon='red.ico')
        ext_suffix = '.so'
        if cbuilder.eci.platform.name == 'msvc':
            ext_suffix = '.dll'
        elif cbuilder.eci.platform.name.startswith('darwin'):
            ext_suffix = '.dylib'
        libname = cbuilder.executable_name.join('..', 'lib' +
                                      cbuilder.modulename + ext_suffix)
        lib = ctypes.CDLL(str(libname))
        assert lib.foo(13) == 16
