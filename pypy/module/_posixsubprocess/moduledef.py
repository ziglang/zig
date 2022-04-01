from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    applevel_name = '_posixsubprocess'

    appleveldefs = {
        }

    interpleveldefs = {
        'fork_exec': 'interp_subprocess.fork_exec',
        }

    def startup(self, space):
        from interp_subprocess import c_init
        c_init()
