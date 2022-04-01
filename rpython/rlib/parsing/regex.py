import py
import string
from rpython.rlib.parsing.deterministic import NFA

set = py.builtin.set

class RegularExpression(object):
    def __init__(self):
        raise NotImplementedError("abstract base class")

    def make_automaton(self):
        raise NotImplementedError("abstract base class")
        
    def __add__(self, other):
        return AddExpression(self, other)
    
    def __or__(self, other):
        return OrExpression(self, other)

    def __pos__(self):
        return AddExpression(self, self.kleene())

    def __mul__(self, i):
        result = StringExpression("")
        for x in range(i):
            result += self
        return result

    def __invert__(self):
        return NotExpression(self)

    def kleene(self):
        return KleeneClosure(self)

class StringExpression(RegularExpression):
    def __init__(self, s):
        self.string = s

    def __add__(self, other):
        if not isinstance(other, StringExpression):
            return super(StringExpression, self).__add__(other)
        return StringExpression(self.string + other.string)

    def make_automaton(self):
        nfa = NFA()
        firstfinal = not self.string
        state = nfa.add_state(start=True, final=firstfinal)
        for i, char in enumerate(self.string):
            final = i == len(self.string) - 1
            next_state = nfa.add_state(final=final)
            nfa.add_transition(state, next_state, char)
            state = next_state
        return nfa

    def __repr__(self):
        return "StringExpression(%r)" % (self.string, )

class RangeExpression(RegularExpression):
    def __init__(self, fromchar, tochar):
        self.fromchar = fromchar
        self.tochar = tochar

    def make_automaton(self):
        nfa = NFA()
        startstate = nfa.add_state(start=True)
        finalstate = nfa.add_state(final=True)
        for i in range(ord(self.fromchar), ord(self.tochar) + 1):
            char = chr(i)
            nfa.add_transition(startstate, finalstate, char)
        return nfa

    def __repr__(self):
        return "RangeExpression(%r, %r)" % (self.fromchar, self.tochar)

class AddExpression(RegularExpression):
    def __init__(self, rega, regb):
        self.rega = rega
        self.regb = regb

    def make_automaton(self):
        nfa1 = self.rega.make_automaton()
        nfa2 = self.regb.make_automaton()
        finalstates1 = nfa1.final_states
        nfa1.final_states = set()
        real_final = nfa1.add_state("final*", final=True)
        orig_to_copy = nfa1.update(nfa2)
        for final_state in finalstates1:
            for start_state in nfa2.start_states:
                start_state = orig_to_copy[start_state]
                nfa1.add_transition(final_state, start_state)
        for final_state in nfa2.final_states:
            final_state = orig_to_copy[final_state]
            nfa1.add_transition(final_state, real_final)
        return nfa1

    def __repr__(self):
        return "AddExpression(%r, %r)" % (self.rega, self.regb)
 
class ExpressionTag(RegularExpression):
    def __init__(self, reg, tag):
        self.reg = reg
        self.tag = tag

    def make_automaton(self):
        nfa = self.reg.make_automaton()
        finalstates = nfa.final_states
        nfa.final_states = set()
        real_final = nfa.add_state(self.tag, final=True, unmergeable=True)
        for final_state in finalstates:
            nfa.add_transition(final_state, real_final)
        return nfa

    def __repr__(self):
        return "ExpressionTag(%r, %r)" % (self.reg, self.tag)

class KleeneClosure(RegularExpression):
    def __init__(self, regex):
        self.regex = regex

    def make_automaton(self):
        nfa = self.regex.make_automaton()
        oldfinal = nfa.final_states
        nfa.final_states = set()
        oldstart = nfa.start_states
        nfa.start_states = set()
        real_final = nfa.add_state("final*", final=True)
        real_start = nfa.add_state("start*", start=True)
        for start in oldstart:
            nfa.add_transition(real_start, start)
        for final in oldfinal:
            nfa.add_transition(final, real_final)
        nfa.add_transition(real_start, real_final)
        nfa.add_transition(real_final, real_start)
        return nfa

    def __repr__(self):
        return "KleeneClosure(%r)" % (self.regex, )

class OrExpression(RegularExpression):
    def __init__(self, rega, regb):
        self.rega = rega
        self.regb = regb

    def make_automaton(self):
        nfa1 = self.rega.make_automaton()
        nfa2 = self.regb.make_automaton()
        oldfinal1 = nfa1.final_states
        nfa1.final_states = set()
        oldstart1 = nfa1.start_states
        nfa1.start_states = set()
        real_final = nfa1.add_state("final|", final=True)
        real_start = nfa1.add_state("start|", start=True)
        orig_to_copy = nfa1.update(nfa2)
        for start in oldstart1:
            nfa1.add_transition(real_start, start)
        for final in oldfinal1:
            nfa1.add_transition(final, real_final)
        for start in nfa2.start_states:
            start = orig_to_copy[start]
            nfa1.add_transition(real_start, start)
        for final in nfa2.final_states:
            final = orig_to_copy[final]
            nfa1.add_transition(final, real_final)
        return nfa1

    def __repr__(self):
        return "OrExpression(%r, %r)" % (self.rega, self.regb)

class NotExpression(RegularExpression):
    def __init__(self, reg):
        self.reg = reg

    def make_automaton(self):
        nfa = self.reg.make_automaton()
        # add error state
        error = nfa.add_state("error")
        for state in range(nfa.num_states):
            occurring = set(nfa.transitions.get(state, {}).keys())
            toerror = set([chr(i) for i in range(256)]) - occurring
            for input in toerror:
                nfa.add_transition(state, error, input)
        nfa.final_states = set(range(nfa.num_states)) - nfa.final_states
        return nfa

    def __invert__(self):
        return self.reg


class LexingOrExpression(RegularExpression):
    def __init__(self, regs, names):
        self.regs = regs
        self.names = names

    def make_automaton(self):
        dfas = [reg.make_automaton().make_deterministic() for reg in self.regs]
        [dfa.optimize() for dfa in dfas]
        nfas = [dfa.make_nondeterministic() for dfa in dfas]
        result_nfa = NFA()
        start_state = result_nfa.add_state(start=True)
        for i, nfa in enumerate(nfas):
            final_state = result_nfa.add_state(self.names[i], final=True,
                                               unmergeable=True)
            state_map = {}
            for j, name in enumerate(nfa.names):
                start = j in nfa.start_states
                final = j in nfa.final_states
                newstate = result_nfa.add_state(name)
                state_map[j] = newstate
                if start:
                    result_nfa.add_transition(start_state, newstate)
                if final:
                    result_nfa.add_transition(newstate, final_state)
            for state, subtransitions in nfa.transitions.iteritems():
                for input, states in subtransitions.iteritems():
                    newstate = state_map[state]
                    newstates = [state_map[s] for s in states]
                    for newtargetstate in newstates:
                        result_nfa.add_transition(
                            newstate, newtargetstate, input)
        return result_nfa

    def __repr__(self):
        return "LexingOrExpression(%r, %r)" % (self.regs, self.names)


