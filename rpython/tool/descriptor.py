class InstanceMethod(object):
    "Like types.InstanceMethod, but with a reasonable (structural) equality."

    def __init__(self, im_func, im_self, im_class):
        self.im_func = im_func
        self.im_self = im_self
        self.im_class = im_class

    def __call__(self, *args, **kwds):
        firstarg = self.im_self
        if firstarg is None:
            if not args or not isinstance(args[0], self.im_class):
                raise TypeError(
                    "must be called with %r instance as first argument" % (
                    self.im_class,))
            firstarg = args[0]
            args = args[1:]
        return self.im_func(firstarg, *args, **kwds)

    def __eq__(self, other):
        return isinstance(other, InstanceMethod) and (
            self.im_func == other.im_func and
            self.im_self == other.im_self)

    def __ne__(self, other):
        return not self.__eq__(other)

    def __hash__(self):
        return hash((self.im_func, self.im_self))
