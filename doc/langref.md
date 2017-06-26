# Language Reference

## Grammar

```
Root = many(TopLevelItem) "EOF"

TopLevelItem = ErrorValueDecl | CompTimeExpression(Block) | TopLevelDecl | TestDecl

TestDecl = "test" String Block

TopLevelDecl = option(VisibleMod) (FnDef | ExternDecl | GlobalVarDecl | UseDecl)

ErrorValueDecl = "error" Symbol ";"

GlobalVarDecl = VariableDeclaration ";"

VariableDeclaration = option("comptime") ("var" | "const") Symbol option(":" TypeExpr) "=" Expression

ContainerMember = (ContainerField | FnDef | GlobalVarDecl)

ContainerField = Symbol option(":" Expression) ","

UseDecl = "use" Expression ";"

ExternDecl = "extern" option(String) (FnProto | VariableDeclaration) ";"

FnProto = option("coldcc" | "nakedcc" | "stdcallcc") "fn" option(Symbol) ParamDeclList option("->" TypeExpr)

VisibleMod = "pub" | "export"

FnDef = option("inline" | "extern") FnProto Block

ParamDeclList = "(" list(ParamDecl, ",") ")"

ParamDecl = option("noalias" | "comptime") option(Symbol ":") (TypeExpr | "...")

Block = "{" many(Statement) option(Expression) "}"

Statement = Label | VariableDeclaration ";" | Defer(Block) | Defer(Expression) ";" | BlockExpression(Block) | Expression ";" | ";"

Label = Symbol ":"

TypeExpr = PrefixOpExpression | "var"

BlockOrExpression = Block | Expression

Expression = ReturnExpression | BreakExpression | AssignmentExpression

AsmExpression = "asm" option("volatile") "(" String option(AsmOutput) ")"

AsmOutput = ":" list(AsmOutputItem, ",") option(AsmInput)

AsmInput = ":" list(AsmInputItem, ",") option(AsmClobbers)

AsmOutputItem = "[" Symbol "]" String "(" (Symbol | "->" TypeExpr) ")"

AsmInputItem = "[" Symbol "]" String "(" Expression ")"

AsmClobbers= ":" list(String, ",")

UnwrapExpression = BoolOrExpression (UnwrapMaybe | UnwrapError) | BoolOrExpression

UnwrapMaybe = "??" Expression

UnwrapError = "%%" option("|" Symbol "|") Expression

AssignmentExpression = UnwrapExpression AssignmentOperator UnwrapExpression | UnwrapExpression

AssignmentOperator = "=" | "*=" | "/=" | "%=" | "+=" | "-=" | "<<=" | ">>=" | "&=" | "^=" | "|=" | "*%=" | "+%=" | "-%=" | "<<%="

BlockExpression(body) = Block | IfExpression(body) | TryExpression(body) | TestExpression(body) | WhileExpression(body) | ForExpression(body) | SwitchExpression | CompTimeExpression(body)

CompTimeExpression(body) = "comptime" body

SwitchExpression = "switch" "(" Expression ")" "{" many(SwitchProng) "}"

SwitchProng = (list(SwitchItem, ",") | "else") "=>" option("|" option("*") Symbol "|") Expression ","

SwitchItem = Expression | (Expression "..." Expression)

ForExpression(body) = option("inline") "for" "(" Expression ")" option("|" option("*") Symbol option("," Symbol) "|") body option("else" BlockExpression(body))

BoolOrExpression = BoolAndExpression "or" BoolOrExpression | BoolAndExpression

ReturnExpression = option("%") "return" option(Expression)

BreakExpression = "break" option(Expression)

Defer(body) = option("%") "defer" body

IfExpression(body) = "if" "(" Expression ")" body option("else" BlockExpression(body))

TryExpression(body) = "if" "(" Expression ")" option("|" option("*") Symbol "|") body "else" "|" Symbol "|" BlockExpression(body)

TestExpression(body) = "if" "(" Expression ")" option("|" option("*") Symbol "|") body option("else" BlockExpression(body))

WhileExpression(body) = option("inline") "while" "(" Expression ")" option("|" option("*") Symbol "|") option(":" "(" Expression ")") body option("else" option("|" Symbol "|") BlockExpression(body))

BoolAndExpression = ComparisonExpression "and" BoolAndExpression | ComparisonExpression

ComparisonExpression = BinaryOrExpression ComparisonOperator BinaryOrExpression | BinaryOrExpression

ComparisonOperator = "==" | "!=" | "<" | ">" | "<=" | ">="

BinaryOrExpression = BinaryXorExpression "|" BinaryOrExpression | BinaryXorExpression

BinaryXorExpression = BinaryAndExpression "^" BinaryXorExpression | BinaryAndExpression

BinaryAndExpression = BitShiftExpression "&" BinaryAndExpression | BitShiftExpression

BitShiftExpression = AdditionExpression BitShiftOperator BitShiftExpression | AdditionExpression

BitShiftOperator = "<<" | ">>" | "<<%"

AdditionExpression = MultiplyExpression AdditionOperator AdditionExpression | MultiplyExpression

AdditionOperator = "+" | "-" | "++" | "+%" | "-%"

MultiplyExpression = CurlySuffixExpression MultiplyOperator MultiplyExpression | CurlySuffixExpression

CurlySuffixExpression = TypeExpr option(ContainerInitExpression)

MultiplyOperator = "*" | "/" | "%" | "**" | "*%"

PrefixOpExpression = PrefixOp PrefixOpExpression | SuffixOpExpression

SuffixOpExpression = PrimaryExpression option(FnCallExpression | ArrayAccessExpression | FieldAccessExpression | SliceExpression)

FieldAccessExpression = "." Symbol

FnCallExpression = "(" list(Expression, ",") ")"

ArrayAccessExpression = "[" Expression "]"

SliceExpression = "[" Expression ".." option(Expression) "]"

ContainerInitExpression = "{" ContainerInitBody "}"

ContainerInitBody = list(StructLiteralField, ",") | list(Expression, ",")

StructLiteralField = "." Symbol "=" Expression

PrefixOp = "!" | "-" | "~" | "*" | ("&" option("const") option("volatile")) | "?" | "%" | "%%" | "??" | "-%"

PrimaryExpression = Integer | Float | String | CharLiteral | KeywordLiteral | GroupedExpression | GotoExpression | BlockExpression(BlockOrExpression) | Symbol | ("@" Symbol FnCallExpression) | ArrayType | (option("extern") FnProto) | AsmExpression | ("error" "." Symbol) | ContainerDecl

ArrayType = "[" option(Expression) "]" option("const") TypeExpr

GotoExpression = "goto" Symbol

GroupedExpression = "(" Expression ")"

KeywordLiteral = "true" | "false" | "null" | "continue" | "undefined" | "error" | "this" | "unreachable"

ContainerDecl = option("extern" | "packed") ("struct" | "enum" | "union") "{" many(ContainerMember) "}"
```

## Operator Precedence

```
x() x[] x.y
!x -x -%x ~x *x &x ?x %x %%x ??x
x{}
* / % ** *%
+ - ++ +% -%
<< >>
&
^
|
== != < > <= >=
and
or
?? %%
= *= /= %= += -= <<= >>= &= ^= |=
```
