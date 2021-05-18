function hex2int(str,   i) {
  str = tolower(str)

  for (i = 1; i <= 16; i++) {
    char = substr("0123456789abcdef", i, 1)
    lookup[char] = i-1
  }

  result = 0
  for (i = 1; i <= length(str); i++) {
    result = result * 16
    char   = substr(str, i, 1)
    result = result + lookup[char]
  }
  return result
}

function parse_const(str) {
  sign = sub(/^-/, "", str)
  hex  = sub(/^0x/, "", str)
  if (hex)
    n = hex2int(str)
  else
    n = str+0
  return sign ? -n : n
}
