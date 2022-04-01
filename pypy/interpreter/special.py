from pypy.interpreter.baseobjspace import W_Root


class Ellipsis(W_Root):

    @staticmethod
    def descr_new_ellipsis(space, w_type):
        return space.w_Ellipsis

    def descr__repr__(self, space):
        return space.newtext('Ellipsis')

    descr__reduce__ = descr__repr__


class NotImplemented(W_Root):

    @staticmethod
    def descr_new_notimplemented(space, w_type):
        return space.w_NotImplemented

    def descr__repr__(self, space):
        return space.newtext('NotImplemented')

    descr__reduce__ = descr__repr__

    def descr_bool(self, space):
        space.warn(
            space.newtext("NotImplemented should not be used in a boolean context"),
            space.w_DeprecationWarning
        )
        return space.w_True

