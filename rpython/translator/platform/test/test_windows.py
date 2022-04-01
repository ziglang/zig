import pytest
import os
import re
from rpython.tool.udir import udir
from rpython.translator.platform import CompilationError, Platform
from rpython.translator.platform import host
from rpython.translator.tool.cbuild import ExternalCompilationInfo

import py, sys, platform
if sys.platform != 'win32':
    pytest.skip("Windows only")


def get_manifest(executable, allow_missing=False):
    # This is a regex since the xmlns value is a ' or " delimited string
    manifest_start = '<assembly xmlns=.urn:schemas-microsoft-com:asm.v1. manifestVersion='
    manifest_end = '</assembly>'
    with open(str(executable), 'rb') as fid:
        exe = fid.read()
    match = re.search(manifest_start, exe)
    if not match:
        if allow_missing:
            return None
        raise ValueError("could not find manifest in %s" % executable)
    start = match.start()
    end = exe.find(manifest_end, start) + len(manifest_end)
    # sanity check
    assert end > len(manifest_end)
    # only one manifest
    assert exe.find(manifest_start, end) == -1
    return exe[start:end]

class TestWindows(object):
    platform = host

    def test_manifest_exe(self):
        cfile = udir.join('test_simple.c')
        cfile.write('''
        #include <stdio.h>
        int main()
        {
            printf("42\\n");
            return 0;
        }
        ''')
        executable = self.platform.compile([cfile], ExternalCompilationInfo())
        manifest = get_manifest(executable)
        assert "asInvoker" in manifest
        assert "longPathAware" not in manifest

    def test_manifest_dll(self):
        cfile = udir.join('test_simple.c')
        cfile.write('''
        __declspec(dllexport) int times2(int x)
        {
            return x * 2;
        }
        ''')
        executable = self.platform.compile([cfile],
                                           ExternalCompilationInfo(),
                                           standalone=False)
        manifest = get_manifest(executable)
        assert "asInvoker" in manifest
        assert "longPathAware" not in manifest

class TestMakefile(object):
    platform = host

    def check_res(self, res, expected):
        assert res.out == expected
        assert res.returncode == 0

    def test_manifest(self):

        class Translation():
            icon = None
            manifest = os.path.join(os.path.dirname(__file__),
                                    'data', 'python.manifest')

        class Config():
            translation = Translation()

        tmpdir = udir.join('test_manifest').ensure(dir=1)
        cfile = tmpdir.join('pypy_main.c')
        cfile.write('''
        #include <stdio.h>
        __declspec(dllexport) int pypy_main_startup(int argc, char* argv[])
        {
            int x = 10;
            int y = x * 2;
            printf("%d\\n", y);
            return 0;
        }
        ''')
        mk = self.platform.gen_makefile([cfile],
                                        ExternalCompilationInfo(),
                                        path=tmpdir,
                                        shared=True,
                                        config = Config(),
                                       )
        mk.write()
        self.platform.execute_makefile(mk)

        # Make sure compilation succeeded for the target, targetw,
        # and debug_target
        target = mk.exe_name
        basename = target.purebasename
        res = self.platform.execute(target)
        self.check_res(res, '20\n')
        targetw = target.parts()[-2] / basename + 'w.exe'
        res = self.platform.execute(targetw)
        self.check_res(res, '20\n')
        self.platform.execute_makefile(mk, ['debugmode_' + basename + '.exe'])
        debug_target = target.parts()[-2] / 'debugmode_' + basename + '.exe'
        res = self.platform.execute(debug_target)
        self.check_res(res, '20\n')

        # Check the manifests
        for v in [target, targetw, debug_target]:
            manifest = get_manifest(v)        
            assert "asInvoker" in manifest
            assert "longPathAware" in manifest
