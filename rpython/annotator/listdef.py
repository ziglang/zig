from rpython.annotator.model import s_ImpossibleValue
from rpython.annotator.model import SomeList, SomeString
from rpython.annotator.model import unionof, TLS, UnionError, AnnotatorError


class TooLateForChange(AnnotatorError):
    pass

class ListChangeUnallowed(AnnotatorError):
    pass

class ListItem(object):
    mutated = False    # True for lists mutated after creation
    resized = False    # True for lists resized after creation
    range_step = None  # the step -- only for lists only created by a range()
    dont_change_any_more = False   # set to True when too late for changes
    immutable = False  # for getattr out of _immutable_fields_ = ['attr[*]']
    must_not_resize = False   # make_sure_not_resized()

    # what to do if range_step is different in merge.
    # - if one is a list (range_step is None), unify to a list.
    # - if both have a step, unify to use a variable step (indicated by 0)
    _step_map = {
        (type(None), int): None,
        (int, type(None)): None,
        (int, int)       : 0,
        }

    def __init__(self, bookkeeper, s_value):
        self.s_value = s_value
        self.bookkeeper = bookkeeper
        self.itemof = {}  # set of all ListDefs using this ListItem
        self.read_locations = set()
        if bookkeeper is None:
            self.dont_change_any_more = True

    def mutate(self):
        if not self.mutated:
            if self.dont_change_any_more:
                raise TooLateForChange
            self.immutable = False
            self.mutated = True

    def resize(self):
        if not self.resized:
            if self.dont_change_any_more:
                raise TooLateForChange
            if self.must_not_resize:
                raise ListChangeUnallowed("resizing list")
            self.resized = True

    def setrangestep(self, step):
        if step != self.range_step:
            if self.dont_change_any_more:
                raise TooLateForChange
            self.range_step = step

    def merge(self, other):
        if self is not other:
            if getattr(TLS, 'no_side_effects_in_union', 0):
                raise UnionError(self, other)

            if other.dont_change_any_more:
                if self.dont_change_any_more:
                    raise TooLateForChange
                else:
                    # lists using 'other' don't expect it to change any more,
                    # so we try merging into 'other', which will give
                    # TooLateForChange if it actually tries to make
                    # things more general
                    self, other = other, self

            self.immutable &= other.immutable
            if other.must_not_resize:
                if self.resized:
                    raise ListChangeUnallowed("list merge with a resized")
                self.must_not_resize = True
            if other.mutated:
                self.mutate()
            if other.resized:
                self.resize()
            if other.range_step != self.range_step:
                self.setrangestep(self._step_map[type(self.range_step),
                                                 type(other.range_step)])
            self.itemof.update(other.itemof)
            s_value = self.s_value
            s_other_value = other.s_value
            s_new_value = unionof(s_value, s_other_value)
            if s_new_value != s_value:
                if self.dont_change_any_more:
                    raise TooLateForChange
            self.patch()    # which should patch all refs to 'other'
            if s_new_value != s_value:
                self.s_value = s_new_value
                self.notify_update()
            if s_new_value != s_other_value:
                other.notify_update()
            self.read_locations |= other.read_locations

    def patch(self):
        for listdef in self.itemof:
            listdef.listitem = self

    def notify_update(self):
        '''Reflow from all reading points'''
        for position_key in self.read_locations:
            self.bookkeeper.annotator.reflowfromposition(position_key)

    def generalize(self, s_other_value):
        s_new_value = unionof(self.s_value, s_other_value)
        updated = s_new_value != self.s_value
        if updated:
            if self.dont_change_any_more:
                raise TooLateForChange
            self.s_value = s_new_value
            self.notify_update()
        return updated


class ListDef(object):
    """A list definition remembers how general the items in that particular
    list have to be.  Every list creation makes a new ListDef, and the union
    of two lists merges the ListItems that each ListDef stores."""

    def __init__(self, bookkeeper, s_item=s_ImpossibleValue,
                 mutated=False, resized=False):
        self.listitem = ListItem(bookkeeper, s_item)
        self.listitem.mutated = mutated | resized
        self.listitem.resized = resized
        self.listitem.itemof[self] = True

    def read_item(self, position_key):
        self.listitem.read_locations.add(position_key)
        return self.listitem.s_value

    def same_as(self, other):
        return self.listitem is other.listitem

    def union(self, other):
        self.listitem.merge(other.listitem)
        return self

    def agree(self, bookkeeper, other):
        position = bookkeeper.position_key
        s_self_value = self.read_item(position)
        s_other_value = other.read_item(position)
        self.generalize(s_other_value)
        other.generalize(s_self_value)
        if self.listitem.range_step is not None:
            self.generalize_range_step(other.listitem.range_step)
        if other.listitem.range_step is not None:
            other.generalize_range_step(self.listitem.range_step)

    def offspring(self, bookkeeper, *others):
        position = bookkeeper.position_key
        s_self_value = self.read_item(position)
        s_other_values = []
        for other in others:
            s_other_values.append(other.read_item(position))
        s_newlst = bookkeeper.newlist(s_self_value, *s_other_values)
        s_newvalue = s_newlst.listdef.read_item(position)
        self.generalize(s_newvalue)
        for other in others:
            other.generalize(s_newvalue)
        return s_newlst

    def generalize(self, s_value):
        self.listitem.generalize(s_value)

    def generalize_range_step(self, range_step):
        newlistitem = ListItem(self.listitem.bookkeeper, s_ImpossibleValue)
        newlistitem.range_step = range_step
        self.listitem.merge(newlistitem)

    def __repr__(self):
        return '<[%r]%s%s%s%s>' % (self.listitem.s_value,
                               self.listitem.mutated and 'm' or '',
                               self.listitem.resized and 'r' or '',
                               self.listitem.immutable and 'I' or '',
                               self.listitem.must_not_resize and '!R' or '')

    def mutate(self):
        self.listitem.mutate()

    def resize(self):
        self.listitem.mutate()
        self.listitem.resize()

    def never_resize(self):
        if self.listitem.resized:
            raise ListChangeUnallowed("list already resized")
        self.listitem.must_not_resize = True

    def mark_as_immutable(self):
        # Sets the 'immutable' flag.  Note that unlike "never resized",
        # the immutable flag is only a hint.  It is cleared again e.g.
        # when we merge with a "normal" list that doesn't have it.  It
        # is thus expected to live only shortly, mostly for the case
        # of writing 'x.list[n]'.
        self.never_resize()
        if not self.listitem.mutated:
            self.listitem.immutable = True
        #else: it's fine, don't set immutable=True at all (see
        #      test_can_merge_immutable_list_with_regular_list)

s_list_of_strings = SomeList(ListDef(None, SomeString(no_nul=True),
                                     resized = True))
