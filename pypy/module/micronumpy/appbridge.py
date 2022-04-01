from rpython.rlib.objectmodel import specialize


class AppBridgeCache(object):
    w__mean = None
    w__var = None
    w__std = None
    w__commastring = None
    w_array_repr = None
    w_array_str = None
    w__usefields = None
    w_partition = None

    def __init__(self, space):
        pass

    @specialize.arg(3)
    def call_method(self, space, path, name, args):
        w_method = getattr(self, 'w_' + name)
        if w_method is None:
            w_method = space.appexec([space.newtext(path), space.newtext(name)],
                "(path, name): return getattr(__import__(path, fromlist=[name]), name)")
            setattr(self, 'w_' + name, w_method)
        return space.call_args(w_method, args)


def set_string_function(space, w_f, w_repr):
    cache = get_appbridge_cache(space)
    if space.is_true(w_repr):
        cache.w_array_repr = w_f
    else:
        cache.w_array_str = w_f


def get_appbridge_cache(space):
    return space.fromcache(AppBridgeCache)
