from rpython.translator.platform.linux import Linux
from rpython.translator.platform.posix import _run_subprocess, GnuMakefile
from rpython.translator.platform import ExecutionResult, log
from os import getenv

SB2 = getenv('SB2')
if SB2 is None:
    log.error('SB2: Provide a path to the sb2 rootfs for the target in env variable SB2')
    assert 0

sb2_params = getenv('SB2OPT')
if sb2_params is None:
    log.info('Pass additional options to sb2 in SB2OPT')
    SB2ARGS = []
else:
    SB2ARGS = sb2_params.split(' ')

class ARM(Linux):
    name = "arm"
    shared_only = ('-fPIC',)

    available_librarydirs = [SB2 + '/lib/arm-linux-gnueabi/',
                             SB2 + '/lib/arm-linux-gnueabihf/',
                             SB2 + '/lib/aarch64-linux-gnu/',
                             SB2 + '/usr/lib/arm-linux-gnueabi/',
                             SB2 + '/usr/lib/arm-linux-gnueabihf/',
                             SB2 + '/usr/lib/aarch64-linux-gnu/']

    available_includedirs = [SB2 + '/usr/include/arm-linux-gnueabi/',
                             SB2 + '/usr/include/arm-linux-gnueabihf/',
                             SB2 + '/usr/include/aarch64-linux-gnu/']
    copied_cache = {}


    def _invent_new_name(self, basepath, base):
        pth = basepath.join(base)
        num = 0
        while pth.check():
            pth = basepath.join('%s_%d' % (base,num))
            num += 1
        return pth.ensure(dir=1)

    def _execute_c_compiler(self, cc, args, outname, cwd=None):
        log.execute('sb2 ' + ' '.join(SB2ARGS) + ' ' + cc + ' ' + ' '.join(args))
        args = SB2ARGS + [cc] + args
        returncode, stdout, stderr = _run_subprocess('sb2', args)
        self._handle_error(returncode, stderr, stdout, outname)

    def execute(self, executable, args=[], env=None):
        if isinstance(args, str):
            args = ' '.join(SB2ARGS) + ' ' + str(executable) + ' ' + args
            log.message('executing sb2 ' + args)
        else:
            args = SB2ARGS + [str(executable)] + args
            log.message('executing sb2 ' + ' '.join(args))
        returncode, stdout, stderr = _run_subprocess('sb2', args,
                                                     env)
        return ExecutionResult(returncode, stdout, stderr)

    def include_dirs_for_libffi(self):
        return self.available_includedirs

    def library_dirs_for_libffi(self):
        return self.available_librarydirs

    def _preprocess_library_dirs(self, library_dirs):
        return list(library_dirs) + self.available_librarydirs

    def execute_makefile(self, path_to_makefile, extra_opts=[]):
        if isinstance(path_to_makefile, GnuMakefile):
            path = path_to_makefile.makefile_dir
        else:
            path = path_to_makefile
        log.execute('sb2 %s make %s in %s' % (' '.join(SB2ARGS), " ".join(extra_opts), path))
        returncode, stdout, stderr = _run_subprocess(
            'sb2', SB2ARGS + ['make', '-C', str(path)] + extra_opts)
        self._handle_error(returncode, stdout, stderr, path.join('make'))
