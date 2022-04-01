
"""
Mixed-module definition for pypy own testing purposes
"""

from pypy.interpreter.mixedmodule import MixedModule


class Module(MixedModule):
    """PyPy own testing"""

    interpleveldefs = {
        }

    appleveldefs = {
        'Hidden': 'app_notrpython.Hidden',
        }
