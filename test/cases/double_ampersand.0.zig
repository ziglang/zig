pub const a = if (true && false) 1 else 2;

// error
// output_mode=Exe
//
// :1:24: error: ambiguous use of '&&'; use 'and' for logical AND, or change whitespace to ' & &' for bitwise AND
