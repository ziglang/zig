from rpython.jit.codewriter.policy import JitPolicy

class PyPyJitPolicy(JitPolicy):

    def look_inside_pypy_module(self, modname):
        if (modname == '__builtin__.operation' or
                modname == '__builtin__.abstractinst' or
                modname == '__builtin__.interp_classobj' or
                modname == '__builtin__.functional' or
                modname == '__builtin__.descriptor' or
                modname == 'thread.os_local' or
                modname == 'thread.os_thread' or
                modname.startswith('_rawffi.alt')):
            return True
        if '.' in modname:
            modname, rest = modname.split('.', 1)
            if modname in ['unicodedata', 'gc', '_minimal_curses']:
                return False
        else:
            rest = ''
        if modname == 'pypyjit' and 'interp_resop' in rest:
            return False
        return True

    def look_inside_function(self, func):
        mod = func.__module__ or '?'

        if mod == 'rpython.rlib.rlocale' or mod == 'rpython.rlib.rsocket':
            return False
        if mod.startswith('pypy.interpreter.astcompiler.'):
            return False
        if mod.startswith('pypy.interpreter.pyparser.'):
            return False
        if mod.startswith('pypy.module.'):
            modname = mod[len('pypy.module.'):]
            if not self.look_inside_pypy_module(modname):
                return False

        return True
