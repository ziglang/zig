from pypy.interpreter.gateway import unwrap_spec

def saferepr(space, w_obj):
    """Get a safe repr of an object for assertion error messages.

    The assertion formatting (util.format_explanation()) requires
    newlines to be escaped since they are a special character for it.
    Normally assertion.util.format_explanation() does this but for a
    custom repr it is possible to contain one of the special escape
    sequences, especially '\n{' and '\n}' are likely to be present in
    JSON reprs.

    """
    return space.newtext(space.text_w(space.repr(w_obj)).replace('\n', '\\n'))

def format_assertmsg(space, __args__):
    """Format the custom assertion message given.

    For strings this simply replaces newlines with '\n~' so that
    util.format_explanation() will preserve them instead of escaping
    newlines.  For other objects py.io.saferepr() is used first.

    """
    # XXX
    return obj.replace("\n", "\n~").replace("%", "%%")


def _split_explanation(explanation):
    """Return a list of individual lines in the explanation

    This will return a list of lines split on '\n{', '\n}' and '\n~'.
    Any other newlines will be escaped and appear in the line as the
    literal '\n' characters.
    """
    raw_lines = (explanation or '').split('\n')
    lines = [raw_lines[0]]
    for values in raw_lines[1:]:
        if values and values[0] in ['{', '}', '~', '>']:
            lines.append(values)
        else:
            lines[-1] += '\\n' + values
    return lines

def _format_lines(lines):
    """Format the individual lines

    This will replace the '{', '}' and '~' characters of our mini
    formatting language with the proper 'where ...', 'and ...' and ' +
    ...' text, taking care of indentation along the way.

    Return a list of formatted lines.
    """
    result = lines[:1]
    stack = [0]
    stackcnt = [0]
    for line in lines[1:]:
        if line.startswith('{'):
            if stackcnt[-1]:
                s = 'and   '
            else:
                s = 'where '
            stack.append(len(result))
            stackcnt[-1] += 1
            stackcnt.append(0)
            result.append(' +' + '  ' * (len(stack) - 1) + s + line[1:])
        elif line.startswith('}'):
            stack.pop()
            stackcnt.pop()
            result[stack[-1]] += line[1:]
        else:
            assert line[0] in ['~', '>']
            stack[-1] += 1
            indent = len(stack) if line.startswith('~') else len(stack) - 1
            result.append('  ' * indent + line[1:])
    assert len(stack) == 1
    return result

@unwrap_spec(explanation="text")
def format_explanation(space, explanation):
    """This formats an explanation

    Normally all embedded newlines are escaped, however there are
    three exceptions: \n{, \n} and \n~.  The first two are intended
    cover nested explanations, see function and attribute explanations
    for examples (.visit_Call(), visit_Attribute()).  The last one is
    for when one explanation needs to span multiple lines, e.g. when
    displaying diffs.
    """
    lines = _split_explanation(explanation)
    result = _format_lines(lines)
    return space.newtext('\n'.join(result))

def should_repr_global_name(space, w_obj):
    return space.newbool(
            space.findattr(w_obj, space.newtext("__name__")) is None and
            not space.callable_w(w_obj))


@unwrap_spec(is_or=bool)
def format_boolop(space, w_explanations, is_or):
    explanations_w = space.unpackiterable(w_explanations)
    explanation = "(" + (is_or and " or " or " and ").join([space.text_w(w_e) for w_e in explanations_w]) + ")"
    return space.newtext(explanation.replace('%', '%%'))


def call_reprcompare(space, w_ops, w_results, w_expls, w_each_obj):
    ops_w = space.unpackiterable(w_ops)
    results_w = space.unpackiterable(w_results)
    expls_w = space.unpackiterable(w_expls)
    each_obj_w = space.unpackiterable(w_each_obj)
    for i, w_res, w_expl in zip(range(len(ops_w)), results_w, expls_w):
        try:
            done = space.is_true(space.not_(w_res))
        except Exception:
            done = True
        if done:
            break
    # XXX disabled for now
    #w_custom = callbinrepr(ops_w[i], each_obj_w[i], each_obj_w[i + 1])
    #if w_custom is not None:
    #    return w_custom
    return w_expl

