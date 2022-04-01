
class BrainInterpreter(object):
    def __init__(self):
        self.table = [0] * 30000
        self.pointer = 0

    def interp_char(self, code, code_pointer, input, output):
        char_code = code[code_pointer]
        if char_code == '>':
            self.pointer += 1
        elif char_code == '<':
            self.pointer -= 1
        elif char_code == '+':
            self.table[self.pointer] += 1
        elif char_code == '-':
            self.table[self.pointer] -= 1
        elif char_code == '.':
            output.write(chr(self.table[self.pointer]))
        elif char_code == ',':
            self.table[self.pointer] = ord(input.read(1))
        elif char_code == '[':
            # find corresponding ]
            if self.table[self.pointer] == 0:
                need = 1
                p = code_pointer + 1
                while need > 0:
                    if code[p] == ']':
                        need -= 1
                    elif code[p] == '[':
                        need += 1
                    p += 1
                return p
        elif char_code == ']':
            if self.table[self.pointer] != 0:
                need = 1
                p = code_pointer - 1
                while need > 0:
                    if code[p] == ']':
                        need += 1
                    elif code[p] == '[':
                        need -= 1
                    p -= 1
                return p + 2
        return code_pointer + 1

    def interpret(self, code, input_string, output_io):
        code_pointer = 0
        while code_pointer < len(code):
            code_pointer = self.interp_char(code, code_pointer,
                input_string, output_io)
            #print code_pointer, self.table[:5]
        return output_io
