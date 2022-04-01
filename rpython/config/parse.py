

def parse_info(text):
    """See test_parse.py."""
    text = text.lstrip()
    result = {}
    if (text+':').index(':') > (text+'=').index('='):
        # found a '=' before a ':' means that we have the new format
        current = {0: ''}
        indentation_prefix = None
        for line in text.splitlines():
            line = line.rstrip()
            if not line:
                continue
            realline = line.lstrip()
            indent = len(line) - len(realline)
            #
            # 'indentation_prefix' is set when the previous line was a [group]
            if indentation_prefix is not None:
                assert indent > max(current)     # missing indent?
                current[indent] = indentation_prefix
                indentation_prefix = None
                #
            else:
                # in case of dedent, must kill the extra items from 'current'
                for n in current.keys():
                    if n > indent:
                        del current[n]
            #
            prefix = current[indent]      # KeyError if bad dedent
            #
            if realline.startswith('[') and realline.endswith(']'):
                indentation_prefix = prefix + realline[1:-1] + '.'
            else:
                # build the whole dotted key and evaluate the value
                i = realline.index(' = ')
                key = prefix + realline[:i]
                value = realline[i+3:]
                value = eval(value, {})
                result[key] = value
        #
    else:
        # old format
        for line in text.splitlines():
            i = line.index(':')
            key = line[:i].strip()
            value = line[i+1:].strip()
            try:
                value = int(value)
            except ValueError:
                if value in ('True', 'False', 'None'):
                    value = eval(value, {})
            result[key] = value
        #
    return result
