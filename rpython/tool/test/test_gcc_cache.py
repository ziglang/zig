import sys
import cStringIO
import py
from rpython.tool.udir import udir
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.translator.platform import CompilationError
from rpython.tool.gcc_cache import (
    cache_file_path, build_executable_cache, try_compile_cache)

localudir = udir.join('test_gcc_cache').ensure(dir=1)

def test_gcc_exec():
    f = localudir.join("x.c")
    f.write("""
    #include <stdio.h>
    #include <test_gcc_exec.h>
    int main()
    {
       printf("%d\\n", ANSWER);
       return 0;
    }
    """)
    dir1 = localudir.join('test_gcc_exec_dir1').ensure(dir=1)
    dir2 = localudir.join('test_gcc_exec_dir2').ensure(dir=1)
    dir1.join('test_gcc_exec.h').write('#define ANSWER 3\n')
    dir2.join('test_gcc_exec.h').write('#define ANSWER 42\n')
    eci = ExternalCompilationInfo(include_dirs=[str(dir1)])
    # remove cache
    path = cache_file_path([f], eci, 'build_executable_cache')
    if path.check():
        path.remove()
    res = build_executable_cache([f], eci)
    assert res == "3\n"
    assert build_executable_cache([f], eci) == "3\n"
    eci2 = ExternalCompilationInfo(include_dirs=[str(dir2)])
    assert build_executable_cache([f], eci2) == "42\n"
    f.write("#error BOOM\n")
    err = py.test.raises(CompilationError, build_executable_cache, [f], eci2)
    print '<<<'
    print err
    print '>>>'

def test_gcc_ask():
    f = localudir.join("y.c")
    f.write("""
    #include <stdio.h>
    #include <test_gcc_ask.h>
    int main()
    {
       printf("hello\\n");
       return 0;
    }
    """)
    dir1 = localudir.join('test_gcc_ask_dir1').ensure(dir=1)
    dir2 = localudir.join('test_gcc_ask_dir2').ensure(dir=1)
    dir1.join('test_gcc_ask.h').write('/* hello world */\n')
    dir2.join('test_gcc_ask.h').write('#error boom\n')
    eci = ExternalCompilationInfo(include_dirs=[str(dir1)])
    # remove cache
    path = cache_file_path([f], eci, 'try_compile_cache')
    if path.check():
        path.remove()
    assert try_compile_cache([f], eci)
    assert try_compile_cache([f], eci)
    assert build_executable_cache([f], eci) == "hello\n"
    eci2 = ExternalCompilationInfo(include_dirs=[str(dir2)])
    path = cache_file_path([f], eci, 'try_compile_cache')
    if path.check():
        path.remove()
    err = py.test.raises(CompilationError, try_compile_cache, [f], eci2)
    assert path.check
    py.test.raises(CompilationError, try_compile_cache, [f], eci2)

def test_gcc_ask_doesnt_log_errors():
    f = localudir.join('z.c')
    f.write("""this file is not valid C code\n""")
    eci = ExternalCompilationInfo()
    oldstderr = sys.stderr
    try:
        sys.stderr = capture = cStringIO.StringIO()
        py.test.raises(CompilationError, try_compile_cache, [f], eci)
    finally:
        sys.stderr = oldstderr
    assert 'ERROR' not in capture.getvalue().upper()

def test_execute_code_ignore_errors():
    f = localudir.join('z.c')
    f.write("""this file is not valid C code\n""")
    eci = ExternalCompilationInfo()
    oldstderr = sys.stderr
    try:
        sys.stderr = capture = cStringIO.StringIO()
        py.test.raises(CompilationError, build_executable_cache,
                       [f], eci, True)
    finally:
        sys.stderr = oldstderr
    assert 'ERROR' not in capture.getvalue().upper()

def test_execute_code_show_runtime_error():
    f = localudir.join('z.c')
    f.write("""
    #include <stdio.h>
    int main()
    {
       fprintf(stderr, "hello\\n");
       return 0;
    }
    """)
    for i in range(2):
        eci = ExternalCompilationInfo()
        oldstderr = sys.stderr
        try:
            sys.stderr = capture = cStringIO.StringIO()
            output = build_executable_cache([f], eci, True)
        finally:
            sys.stderr = oldstderr
        assert 'hello' in capture.getvalue()
        assert output == ''
