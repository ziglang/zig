# coding: utf-8
# Used by genpytokenize.py to generate the parser in pytokenize.py
from pypy.interpreter.pyparser.automata import DFA, DEFAULT

class EMPTY: pass

def newArcPair (states, transitionLabel):
    s1Index = len(states)
    s2Index = s1Index + 1
    states.append([(transitionLabel, s2Index)])
    states.append([])
    return s1Index, s2Index

# ______________________________________________________________________

def chain (states, *stateIndexPairs):
    if len(stateIndexPairs) > 1:
        start, lastFinish = stateIndexPairs[0]
        for nStart, nFinish in stateIndexPairs[1:]:
            states[lastFinish].append((EMPTY, nStart))
            lastFinish = nFinish
        return start, nFinish
    else:
        return stateIndexPairs[0]


# ______________________________________________________________________

def chainStr (states, str):
    return chain(states, *map(lambda x : newArcPair(states, x), str))

# ______________________________________________________________________

def notChainStr (states, str):
    """XXX I'm not sure this is how it should be done, but I'm going to
    try it anyway.  Note that for this case, I require only single character
    arcs, since I would have to basically invert all accepting states and
    non-accepting states of any sub-NFA's.
    """
    assert len(str) > 0
    arcs = map(lambda x : newArcPair(states, x), str)
    finish = len(states)
    states.append([])
    start, lastFinish = arcs[0]
    states[start].append((EMPTY, finish))
    for crntStart, crntFinish in arcs[1:]:
        states[lastFinish].append((EMPTY, crntStart))
        states[crntStart].append((EMPTY, finish))
    return start, finish

# ______________________________________________________________________

def group (states, *stateIndexPairs):
    if len(stateIndexPairs) > 1:
        start = len(states)
        finish = start + 1
        startList = []
        states.append(startList)
        states.append([])
        for eStart, eFinish in stateIndexPairs:
            startList.append((EMPTY, eStart))
            states[eFinish].append((EMPTY, finish))
        return start, finish
    else:
        return stateIndexPairs[0]

# ______________________________________________________________________

def groupStr (states, str):
    return group(states, *map(lambda x : newArcPair(states, x), str))

# ______________________________________________________________________

def notGroup (states, *stateIndexPairs):
    """Like group, but will add a DEFAULT transition to a new end state,
    causing anything in the group to not match by going to a dead state.
    XXX I think this is right...
    """
    start, dead = group(states, *stateIndexPairs)
    finish = len(states)
    states.append([])
    states[start].append((DEFAULT, finish))
    return start, finish

# ______________________________________________________________________

def notGroupStr (states, str):
    return notGroup(states, *map(lambda x : newArcPair(states, x), str))
# ______________________________________________________________________

def any (states, *stateIndexPairs):
    start, finish = group(states, *stateIndexPairs)
    states[finish].append((EMPTY, start))
    return start, start

# ______________________________________________________________________

def maybe (states, *stateIndexPairs):
    start, finish = group(states, *stateIndexPairs)
    states[start].append((EMPTY, finish))
    return start, finish

# ______________________________________________________________________

def atleastonce (states, *stateIndexPairs):
    start, finish = group(states, *stateIndexPairs)
    states[finish].append((EMPTY, start))
    return start, finish

# ______________________________________________________________________

def closure(states, start, result = frozenset()):
    if result is None:
        result = frozenset()
    if frozenset() == (result & {start}):
        result |= {start}
        for label, arrow in states[start]:
            if label == EMPTY:
                result |= closure(states, arrow, result)
    return result

# ______________________________________________________________________

def nfaToDfa(states, start, finish):
    tempStates = []
    startClosure = closure(states, start)
    crntTempState = [startClosure, [], frozenset() != (startClosure & {finish})]
    tempStates.append(crntTempState)
    index = 0
    while index < len(tempStates):
        crntTempState = tempStates[index]
        crntClosure, crntArcs, crntAccept = crntTempState
        for index2 in range(0, len(states)):
            if frozenset() != (crntClosure & {index2}):
                for label, nfaArrow in states[index2]:
                    if label == EMPTY:
                        continue
                    foundTempArc = False
                    for tempArc in crntArcs:
                        if tempArc[0] == label:
                            foundTempArc = True
                            break
                    if not foundTempArc:
                        tempArc = [label, -1, frozenset()]
                        crntArcs.append(tempArc)
                    tempArc[2] = closure(states, nfaArrow, tempArc[2])
        for arcIndex in range(0, len(crntArcs)):
            label, arrow, targetStates = crntArcs[arcIndex]
            targetFound = False
            arrow = 0
            for destTempState in tempStates:
                if destTempState[0] == targetStates:
                    targetFound = True
                    break
                arrow += 1
            if not targetFound:
                assert arrow == len(tempStates)
                newState = [targetStates, [], frozenset() != (targetStates & {finish})]
                tempStates.append(newState)
            crntArcs[arcIndex][1] = arrow
        index += 1
    tempStates = simplifyTempDfa(tempStates)
    states = finalizeTempDfa(tempStates)
    return states

# ______________________________________________________________________

def sameState (s1, s2):
    """sameState(s1, s2)
    Note:
    state := [ nfaclosure : Long, [ arc ], accept : Boolean ]
    arc := [ label, arrow : Int, nfaClosure : Long ]
    """
    if (len(s1[1]) != len(s2[1])) or (s1[2] != s2[2]):
        return False
    for arcIndex in range(0, len(s1[1])):
        arc1 = s1[1][arcIndex]
        arc2 = s2[1][arcIndex]
        if arc1[:-1] != arc2[:-1]:
            return False
    return True

# ______________________________________________________________________

def simplifyTempDfa (tempStates):
    """simplifyTempDfa (tempStates)
    """
    changes = True
    deletedStates = []
    while changes:
        changes = False
        for i in range(1, len(tempStates)):
            if i in deletedStates:
                continue
            for j in range(0, i):
                if j in deletedStates:
                    continue
                if sameState(tempStates[i], tempStates[j]):
                    deletedStates.append(i)
                    for k in range(0, len(tempStates)):
                        if k in deletedStates:
                            continue
                        for arc in tempStates[k][1]:
                            if arc[1] == i:
                                arc[1] = j
                    changes = True
                    break
    for stateIndex in deletedStates:
        tempStates[stateIndex] = None
    return tempStates
# ______________________________________________________________________

def finalizeTempDfa (tempStates):
    """finalizeTempDfa (tempStates)
    
    Input domain:
    tempState := [ nfaClosure : Long, [ tempArc ], accept : Boolean ]
    tempArc := [ label, arrow, nfaClosure ]

    Output domain:
    state := [ arcMap, accept : Boolean ]
    """
    states = []
    accepts = []
    stateMap = {}
    tempIndex = 0
    for tempIndex in range(0, len(tempStates)):
        tempState = tempStates[tempIndex]
        if None != tempState:
            stateMap[tempIndex] = len(states)
            states.append({})
            accepts.append(tempState[2])
    for tempIndex in stateMap.keys():
        stateBitset, tempArcs, accepting = tempStates[tempIndex]
        newIndex = stateMap[tempIndex]
        arcMap = states[newIndex]
        for tempArc in tempArcs:
            arcMap[tempArc[0]] = stateMap[tempArc[1]]
    return states, accepts

def _dot(states, final, r):
    for i, state in enumerate(states):
        shape = "circle"
        color = ""
        if final[i]:
            shape = "doublecircle"
            color = ", fillcolor=green"
        r.append('s%s [label="", shape="%s"%s];' % (i, shape, color))
        if isinstance(state, dict):
            stateiter = state.iteritems()
        else:
            stateiter = state
        for char, target in stateiter:
            if char is EMPTY:
                char = "ε"
            elif char is DEFAULT:
                char = "default"
            elif type(char) is str and len(char) == 1 and ord(char) < 32:
                char = ord(char)
            elif char == "\\":
                char = "\\\\"
            elif char == '"':
                char = '\\"'
            r.append('s%s -> s%s [label="%s"];' % (i, target, char))

def view(states, final):
    from dotviewer import graphclient
    import tempfile
    r = ["digraph G {"]
    _dot(states, final, r)
    r.append("}")
    with tempfile.NamedTemporaryFile() as f:
        fn = f.name
        print fn
        with open(fn, "w") as f:
            f.write("\n".join(r))
        graphclient.display_dot_file(fn)

