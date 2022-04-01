from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    """provides basic warning filtering support.
    It is a helper module to speed up interpreter start-up."""

    interpleveldefs = {
        'warn'         : 'interp_warnings.warn',
        'warn_explicit': 'interp_warnings.warn_explicit',
        '_filters_mutated': 'interp_warnings.filters_mutated',
    }

    appleveldefs = {
        '_warn_unawaited_coroutine' : 'app_warnings._warn_unawaited_coroutine',
    }

    def setup_after_space_initialization(self):
        from pypy.module._warnings.interp_warnings import State
        state = self.space.fromcache(State)
        self.setdictvalue(self.space, "filters", state.w_filters)
        self.setdictvalue(self.space, "_onceregistry", state.w_once_registry)
        self.setdictvalue(self.space, "_defaultaction", state.w_default_action)

