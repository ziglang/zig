from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    """
    (Extremely) low-level import machinery bits as used by importlib and imp.
    """
    applevel_name = '_imp'

    interpleveldefs = {
        'extension_suffixes': 'interp_imp.extension_suffixes',

        'get_magic':       'interp_imp.get_magic',
        'get_tag':         'interp_imp.get_tag',
        'create_dynamic':  'interp_imp.create_dynamic',
        'create_builtin':  'interp_imp.create_builtin',
        'init_frozen':     'interp_imp.init_frozen',
        'is_builtin':      'interp_imp.is_builtin',
        'is_frozen':       'interp_imp.is_frozen',
        'exec_dynamic':    'interp_imp.exec_dynamic',
        'exec_builtin':    'interp_imp.exec_builtin',
        'get_frozen_object': 'interp_imp.get_frozen_object',
        'is_frozen_package': 'interp_imp.is_frozen_package',

        'lock_held':       'interp_imp.lock_held',
        'acquire_lock':    'interp_imp.acquire_lock',
        'release_lock':    'interp_imp.release_lock',

        '_fix_co_filename': 'interp_imp.fix_co_filename',

        'source_hash':     'interp_imp.source_hash',
        'check_hash_based_pycs': 'space.newtext("default")',
        }

    appleveldefs = {
        }

    def __init__(self, space, *args):
        "NOT_RPYTHON"
        MixedModule.__init__(self, space, *args)
        from pypy.module.posix.interp_posix import add_fork_hook
        from pypy.module.imp import interp_imp
        add_fork_hook('before', interp_imp.acquire_lock)
        add_fork_hook('parent', interp_imp.release_lock)
        add_fork_hook('child', interp_imp.reinit_lock)
