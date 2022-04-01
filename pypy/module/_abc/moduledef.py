from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):

    appleveldefs = {
        "get_cache_token": "app_abc.get_cache_token",
        "_abc_init": "app_abc._abc_init",
        "_abc_register": "app_abc._abc_register",
        "_abc_instancecheck": "app_abc._abc_instancecheck",
        "_abc_subclasscheck": "app_abc._abc_subclasscheck",
        "_get_dump": "app_abc._get_dump",
        "_reset_registry": "app_abc._reset_registry",
        "_reset_caches": "app_abc._reset_caches",
    }

    interpleveldefs = {
    }
