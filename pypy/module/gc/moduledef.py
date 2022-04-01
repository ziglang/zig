from pypy.interpreter.mixedmodule import MixedModule


class Module(MixedModule):
    interpleveldefs = {
        'collect': 'interp_gc.collect',
        'enable': 'interp_gc.enable',
        'disable': 'interp_gc.disable',
        'isenabled': 'interp_gc.isenabled',
        'enable_finalizers': 'interp_gc.enable_finalizers',
        'disable_finalizers': 'interp_gc.disable_finalizers',
        'garbage': 'space.newlist([])',
        #'dump_heap_stats': 'interp_gc.dump_heap_stats',
    }
    appleveldefs = {}

    def __init__(self, space, w_name):
        if (not space.config.translating or
                space.config.translation.gctransformer == "framework"):
            self.appleveldefs.update({
                'dump_rpy_heap': 'app_referents.dump_rpy_heap',
                'get_stats': 'app_referents.get_stats',
                })
            self.interpleveldefs.update({
                'collect_step': 'interp_gc.collect_step',
                'get_rpy_roots': 'referents.get_rpy_roots',
                'get_rpy_referents': 'referents.get_rpy_referents',
                'get_rpy_memory_usage': 'referents.get_rpy_memory_usage',
                'get_rpy_type_index': 'referents.get_rpy_type_index',
                'get_objects': 'referents.get_objects',
                'get_referents': 'referents.get_referents',
                'get_referrers': 'referents.get_referrers',
                '_get_stats': 'referents.get_stats',
                '_dump_rpy_heap': 'referents._dump_rpy_heap',
                'get_typeids_z': 'referents.get_typeids_z',
                'get_typeids_list': 'referents.get_typeids_list',
                'GcRef': 'referents.W_GcRef',
                'hooks': 'space.fromcache(hook.W_AppLevelHooks)',
                'GcCollectStepStats': 'hook.W_GcCollectStepStats',
                })
        MixedModule.__init__(self, space, w_name)
