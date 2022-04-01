import re
from rpython.rlib.rsre.test.test_match import get_code
from rpython.rlib.rsre.test import support


def test_external_match():
    from rpython.rlib.rsre.test.re_tests import tests
    for t in tests:
        yield run_external, t, False

def test_external_search():
    from rpython.rlib.rsre.test.re_tests import tests
    for t in tests:
        yield run_external, t, True

def run_external(t, use_search):
    from rpython.rlib.rsre.test.re_tests import SUCCEED, FAIL, SYNTAX_ERROR
    pattern, s, outcome = t[:3]
    if len(t) == 5:
        repl, expected = t[3:5]
    else:
        assert len(t) == 3
    print 'trying:', t
    try:
        obj = get_code(pattern)
    except re.error:
        if outcome == SYNTAX_ERROR:
            return  # Expected a syntax error
        raise
    if outcome == SYNTAX_ERROR:
        raise Exception("this should have been a syntax error")
    #
    if use_search:
        result = support.search(obj, s)
    else:
        # Emulate a poor man's search() with repeated match()s
        for i in range(len(s)+1):
            result = support.match(obj, s, start=i)
            if result:
                break
    #
    if outcome == FAIL:
        if result is not None:
            raise Exception("succeeded incorrectly")
    elif outcome == SUCCEED:
        if result is None:
            raise Exception("failed incorrectly")
        # Matched, as expected, so now we compute the
        # result string and compare it to our expected result.
        start, end = result.span(0)
        vardict={'found': result.group(0),
                 'groups': result.group(),
                 }#'flags': result.re.flags}
        for i in range(1, 100):
            try:
                gi = result.group(i)
                # Special hack because else the string concat fails:
                if gi is None:
                    gi = "None"
            except IndexError:
                gi = "Error"
            vardict['g%d' % i] = gi
        #for i in result.re.groupindex.keys():
        #    try:
        #        gi = result.group(i)
        #        if gi is None:
        #            gi = "None"
        #    except IndexError:
        #        gi = "Error"
        #    vardict[i] = gi
        repl = eval(repl, vardict)
        if repl != expected:
            raise Exception("grouping error: %r should be %r" % (repl,
                                                                 expected))
