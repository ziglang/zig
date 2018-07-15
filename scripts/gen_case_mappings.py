#!/usr/bin/env python3


def switch_cases(values):
    result = []
    i = 0
    while i < len(values):
        start = values[i]
        case = (start, start)
        j = i + 1
        while j < len(values):
            end = values[j]
            if (end - start) != (j - i):
                i = j
                break
            case = (start, end)
            j += 1
        if i != j:
            i += 1
        result.append(case)
    return result


def write_testing_func(output, func_name, char_set):
    output.write('pub fn {0}(value: u8) bool {{\n'.format(func_name))
    output.write('    return switch (value) {\n')
    cases = switch_cases(sorted(char_set))
    for case in cases:
        if case != cases[0]:
            output.write(',\n')
        start, end = hex(case[0]), hex(case[1])
        if start == end:
            output.write('        {0}'.format(start))
        else:
            output.write('        {0} ... {1}'.format(start, end))
    output.write(' => true,\n')
    output.write('        else => false,\n')
    output.write('    };\n')
    output.write('}\n')


def write_conversion_func(output, func_name, mapping):
    output.write('pub fn {0}(value: u8) u8 {{\n'.format(func_name))
    output.write('    return switch (value) {\n')
    for key in sorted(mapping.keys()):
        output.write('        {0} => {1},\n'.format(hex(key), hex(mapping[key])))
    output.write('        else => value,\n')
    output.write('    };\n')
    output.write('}\n')


def main():
    uppercase = set()
    lowercase = set()
    to_upper = {}
    to_lower = {}
    with open('UnicodeData.txt') as input, \
         open('case_mapping.zig', 'w') as output:
        output.write(
            '// This code is generated from UnicodeData.txt using ' +
            __file__ + '\n\n')
        for line in input:
            fields = line.split(';')
            code_point = int(fields[0].strip(), 16)
            uppercase_mapping = fields[12].strip()
            lowercase_mapping = fields[13].strip()
            if uppercase_mapping:
                upper_code_point = int(uppercase_mapping, 16)
                uppercase.add(upper_code_point)
                to_upper[code_point] = upper_code_point
            if lowercase_mapping:
                lower_code_point = int(lowercase_mapping, 16)
                lowercase.add(lower_code_point)
                to_lower[code_point] = lower_code_point

        write_testing_func(output, 'isLower', lowercase)
        output.write('\n')
        write_testing_func(output, 'isUpper', uppercase)
        output.write('\n')
        write_conversion_func(output, 'toLower', to_lower)
        output.write('\n')
        write_conversion_func(output, 'toUpper', to_upper)


if __name__ == '__main__':
    main()
