import weakref
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rlib.rarithmetic import LONG_BIT


class GroupType(lltype.ContainerType):
    """A 'group' that stores static structs together in memory.

    On 32-bit platforms, the point is that they can be referenced by a
    GroupMemberOffset which only takes 2 bytes (a USHORT), so the total
    size of a group is limited to 18 (= the 16 bits in a USHORT, plus 2
    bits at the end that are zero and so don't need to be stored).

    On 64-bit platforms, we check that the address they end up at is
    within the first 32 bits, so that we can store that address in half
    a long (i.e. in a UINT).
    """
    _gckind = 'raw'

Group = GroupType()


class group(lltype._container):
    _TYPE = Group
    outdated = None

    def __init__(self, name):
        self.name = name
        self.members = []

    def add_member(self, structptr):
        TYPE = lltype.typeOf(structptr)
        assert isinstance(TYPE.TO, lltype.Struct)
        assert TYPE.TO._gckind == 'raw'
        struct = structptr._as_obj()
        prevgroup = _membership.get(struct)
        if prevgroup is not None:
            prevgroup.outdated = (
                "structure %s was inserted into another group" % (struct,))
        assert struct._parentstructure() is None
        index = len(self.members)
        self.members.append(struct)
        _membership[struct] = self
        return GroupMemberOffset(self, index)

def member_of_group(structptr):
    return _membership.get(structptr._as_obj(), None)

_membership = weakref.WeakValueDictionary()


if LONG_BIT == 32:
    HALFSHIFT = 16
    HALFWORD = rffi.USHORT
    r_halfword = rffi.r_ushort
else:
    HALFSHIFT = 32
    HALFWORD = rffi.UINT
    r_halfword = rffi.r_uint


class GroupMemberOffset(llmemory.Symbolic):
    """The offset of a struct inside a group, stored compactly in a HALFWORD
    (a USHORT or UINT). Can only be used by the lloperation 'get_group_member'.
    """
    def annotation(self):
        from rpython.annotator import model
        return model.SomeInteger(knowntype=r_halfword)

    def lltype(self):
        return HALFWORD

    def __init__(self, grp, memberindex):
        assert lltype.typeOf(grp) == Group
        self.grpptr = grp._as_ptr()
        self.index = memberindex
        self.member = grp.members[memberindex]._as_ptr()

    def __repr__(self):
        return '%s(%s, %s)' % (self.__class__.__name__,
                               self.grpptr, self.index)

    def __nonzero__(self):
        return True

    def _get_group_member(self, grpptr):
        assert grpptr == self.grpptr, "get_group_member: wrong group!"
        return self.member

    def _get_next_group_member(self, grpptr, skipoffset):
        # ad-hoc: returns a pointer to the group member that follows this one,
        # given information in 'skipoffset' about how much to skip -- which
        # is the size of the current member.
        assert grpptr == self.grpptr, "get_next_group_member: wrong group!"
        assert isinstance(skipoffset, llmemory.ItemOffset)
        assert skipoffset.TYPE == lltype.typeOf(self.member).TO
        assert skipoffset.repeat == 1
        return self.grpptr._as_obj().members[self.index + 1]._as_ptr()


class CombinedSymbolic(llmemory.Symbolic):
    """A general-purpose Signed symbolic that combines an unsigned half-word
    (USHORT on 32-bit platforms, UINT on 64-bit platforms) and the rest
    of the word (typically flags).  Only supports extracting the half-word
    with 'llop.extract_ushort', and extracting the rest of the word with
    '&~0xFFFF' or with a direct masking like '&0x10000' (resp. on 64-bit
    platform, with '&~0xFFFFFFFF' or '&0x100000000').
    """
    __slots__ = ['lowpart', 'rest']
    MASK = (1<<HALFSHIFT)-1     # 0xFFFF or 0xFFFFFFFF

    def annotation(self):
        from rpython.annotator import model
        return model.SomeInteger()

    def lltype(self):
        return lltype.Signed

    def __init__(self, lowpart, rest):
        assert (rest & CombinedSymbolic.MASK) == 0
        self.lowpart = lowpart
        self.rest = rest

    def __repr__(self):
        return '<CombinedSymbolic %r|%s>' % (self.lowpart, self.rest)

    def __nonzero__(self):
        return True

    def __and__(self, other):
        if (other & CombinedSymbolic.MASK) == 0:
            return self.rest & other
        if (other & CombinedSymbolic.MASK) == CombinedSymbolic.MASK:
            return CombinedSymbolic(self.lowpart, self.rest & other)
        raise Exception("other=0x%x" % other)

    def __or__(self, other):
        assert (other & CombinedSymbolic.MASK) == 0
        return CombinedSymbolic(self.lowpart, self.rest | other)

    def __add__(self, other):
        assert (other & CombinedSymbolic.MASK) == 0
        return CombinedSymbolic(self.lowpart, self.rest + other)

    def __sub__(self, other):
        assert (other & CombinedSymbolic.MASK) == 0
        return CombinedSymbolic(self.lowpart, self.rest - other)

    def __rshift__(self, other):
        assert other >= HALFSHIFT
        return self.rest >> other

    def __eq__(self, other):
        if (isinstance(other, CombinedSymbolic) and
            self.lowpart is other.lowpart):
            return self.rest == other.rest
        else:
            return NotImplemented

    def __ne__(self, other):
        if (isinstance(other, CombinedSymbolic) and
            self.lowpart is other.lowpart):
            return self.rest != other.rest
        else:
            return NotImplemented
