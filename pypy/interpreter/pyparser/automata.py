# ______________________________________________________________________
"""Module automata

THIS FILE WAS COPIED FROM pypy/module/parser/pytokenize.py AND ADAPTED
TO BE ANNOTABLE (Mainly made the DFA's __init__ accept two lists
instead of a unique nested one)

$Id: automata.py,v 1.2 2003/10/02 17:37:17 jriehl Exp $
"""
# ______________________________________________________________________
# Module level definitions

# PYPY Modification: removed the EMPTY class as it's not needed here


# PYPY Modification: DEFAULT is a singleton, used only in the pre-RPython
# dicts (see pytokenize.py).  Then DFA.__init__() turns these dicts into
# more compact strings.
DEFAULT = object()

# PYPY Modification : removed all automata functions (any, maybe,
#                     newArcPair, etc.)

ERROR_STATE = chr(255)

# NB: all non-ascii bytes (>= 128) will be turned into 128
NON_ASCII = chr(128)


class DFA:
    # ____________________________________________________________
    def __init__(self, states, accepts, start = 0):
        """ NOT_RPYTHON """
        assert len(states) < 255 # no support for huge amounts of states
        # construct string for looking up state transitions
        string_states = [] * len(states)
        # compute maximum
        maximum = 0
        for state in states:
            for key in state:
                if key == DEFAULT:
                    continue
                ordkey = ord(key)
                if ordkey > 128:
                    raise ValueError("DFA does not support matching of specific non-ASCII character %r. Use NON_ASCII instead" % key)
                maximum = max(ordkey, maximum)
        self.max_char = maximum + 1

        defaults = []
        for i, state in enumerate(states):
            default = ERROR_STATE
            if DEFAULT in state:
                default = chr(state[DEFAULT])
            defaults.append(default)
            string_state = [default] * self.max_char
            for key, value in state.iteritems():
                if key == DEFAULT:
                    continue
                assert len(key) == 1
                assert ord(key) < self.max_char
                string_state[ord(key)] = chr(value)
            string_states.extend(string_state)
        self.states = "".join(string_states)
        self.defaults = "".join(defaults)
        self.accepts = accepts
        self.start = start

    # ____________________________________________________________

    def _next_state(self, item, crntState):
        if ord(item) >= self.max_char:
            return self.defaults[crntState]
        else:
            return self.states[crntState * self.max_char + ord(item)]

    def recognize(self, inVec, pos = 0):
        crntState = self.start
        lastAccept = False
        i = pos
        for i in range(pos, len(inVec)):
            item = inVec[i]
            if ord(item) > 0x80:
                item = NON_ASCII
            accept = self.accepts[crntState]
            crntState = self._next_state(item, crntState)
            if crntState != ERROR_STATE:
                pass
            elif accept:
                return i
            elif lastAccept:
                # This is now needed b/c of exception cases where there are
                # transitions to dead states
                return i - 1
            else:
                return -1
            crntState = ord(crntState)
            lastAccept = accept
        # if self.states[crntState][1]:
        if self.accepts[crntState]:
            return i + 1
        elif lastAccept:
            return i
        else:
            return -1

# ______________________________________________________________________

class NonGreedyDFA (DFA):

    def recognize(self, inVec, pos = 0):
        crntState = self.start
        i = pos
        for i in range(pos, len(inVec)):
            item = inVec[i]
            if ord(item) > 0x80:
                item = NON_ASCII
            accept = self.accepts[crntState]
            if accept:
                return i
            crntState = self._next_state(item, crntState)
            if crntState == ERROR_STATE:
                return -1
            crntState = ord(crntState)
            i += 1
        if self.accepts[crntState]:
            return i
        else:
            return -1

# ______________________________________________________________________
# End of automata.py
