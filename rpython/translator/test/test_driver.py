import pytest
import os
from rpython.translator.driver import TranslationDriver, shutil_copy
from rpython.tool.udir import udir
from rpython.translator.platform import windows, darwin, linux

def test_ctr():
    td = TranslationDriver()
    expected = ['annotate', 'backendopt', 'llinterpret', 'rtype', 'source',
                'compile', 'pyjitpl']
    assert set(td.exposed) == set(expected)

    assert td.backend_select_goals(['compile_c']) == ['compile_c']
    assert td.backend_select_goals(['compile']) == ['compile_c']
    assert td.backend_select_goals(['rtype']) == ['rtype_lltype']
    assert td.backend_select_goals(['rtype_lltype']) == ['rtype_lltype']
    assert td.backend_select_goals(['backendopt']) == ['backendopt_lltype']
    assert td.backend_select_goals(['backendopt_lltype']) == [
        'backendopt_lltype']

    td = TranslationDriver({'backend': None, 'type_system': None})

    assert td.backend_select_goals(['compile_c']) == ['compile_c']
    pytest.raises(Exception, td.backend_select_goals, ['compile'])
    pytest.raises(Exception, td.backend_select_goals, ['rtype'])
    assert td.backend_select_goals(['rtype_lltype']) == ['rtype_lltype']
    pytest.raises(Exception, td.backend_select_goals, ['backendopt'])
    assert td.backend_select_goals(['backendopt_lltype']) == [
        'backendopt_lltype']

    expected = ['annotate', 'backendopt_lltype', 'llinterpret_lltype',
                'rtype_lltype', 'source_c', 'compile_c', 'pyjitpl_lltype', ]
    assert set(td.exposed) == set(expected)

    td = TranslationDriver({'backend': None, 'type_system': 'lltype'})

    assert td.backend_select_goals(['compile_c']) == ['compile_c']
    pytest.raises(Exception, td.backend_select_goals, ['compile'])
    assert td.backend_select_goals(['rtype_lltype']) == ['rtype_lltype']
    assert td.backend_select_goals(['rtype']) == ['rtype_lltype']
    assert td.backend_select_goals(['backendopt']) == ['backendopt_lltype']
    assert td.backend_select_goals(['backendopt_lltype']) == [
        'backendopt_lltype']

    expected = ['annotate', 'backendopt', 'llinterpret', 'rtype', 'source_c',
                'compile_c', 'pyjitpl']

    assert set(td.exposed) == set(expected)


@pytest.mark.parametrize("host, suffix", (
            (windows.MsvcPlatform, '.exe'),
            (darwin.Darwin, ''),
            (linux.BaseLinux, '')),
            ids=('windows', 'macOS', 'linux'))
def test_compile_c(host, suffix):

    exe_name = 'pypy-%(backend)s'
    # Created by the fake "compile" function
    # Create the dst directory to be tested
    dst_name = udir.join('dst/pypy-c' + suffix)
    dst_name.ensure()

    class CBuilder(object):
        def compile(self, exe_name):
            from rpython.translator.tool.cbuild import ExternalCompilationInfo

            # CBuilder.gen_makefile is called via CBuilder.generate_source
            # in driver.task_source_c. We are faking parts of it here
            targetdir = udir.join('src')
            exe_name = targetdir.join(exe_name)
            platform = host(cc='not_really_going_to_compile')
            mk = platform.gen_makefile([], ExternalCompilationInfo(),
                                       exe_name=exe_name,
                                       path=targetdir,
                                       shared=True,
                                      )
            # "compile" the needed outputs
            src_name = udir.join('src/pypy-c' + suffix)
            src_name.ensure()
            src_name.write('exe')
            dll_name = udir.join('src/pypy-c.dll')
            dll_name.ensure()
            dll_name.write('dll')
            self.shared_library_name = dll_name

            # mock the additional windows artifacts as well
            wsrc_name = udir.join('src/pypy-cw.exe')
            wsrc_name.ensure()
            wsrc_name.write('wexe')
            self.executable_name_w = wsrc_name
            lib_name = udir.join('src/pypy-c.lib')
            lib_name.ensure()
            lib_name.write('lib')
            pdb_name = udir.join('src/pypy-c.pdb')
            pdb_name.ensure()
            pdb_name.write('pdb')
            self.executable_name = mk.exe_name

    td = TranslationDriver(exe_name=str(exe_name))
    # Normally done in the database_c task
    td.cbuilder = CBuilder()
    # Normally done when creating the driver via from_targetspec
    td.standalone = True

    cwd = os.getcwd()

    # This calls compile(), sets td.c_entryp to CBuilder.executable_name,
    # and calls create_exe(). We must cd into the target directory since
    # create_exe() copies back to the current directory

    try:
        os.chdir(dst_name.dirname)
        td.task_compile_c()
    finally:
        os.chdir(cwd)

    assert dst_name.read() == 'exe'
    assert dst_name.new(ext='dll').read() == 'dll'
    if host is windows.MsvcPlatform:
        assert dst_name.new(ext='lib').read() == 'lib'
        assert dst_name.new(purebasename=dst_name.purebasename + 'w').read() == 'wexe'

def test_shutil_copy():
    if os.name == 'nt':
        pytest.skip('Windows cannot copy or rename to an in-use file')
    a = udir.join('file_a')
    b = udir.join('file_a')
    a.write('hello')
    shutil_copy(str(a), str(b))
    assert b.read() == 'hello'
