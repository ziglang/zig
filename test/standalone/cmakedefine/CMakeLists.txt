cmake_minimum_required(VERSION 3.15)

project(cmakdefine LANGUAGES)

# config.h.in
set(noval)
set(nullval)
set(trueval 1)
set(falseval 0)
set(zeroval 0)
set(oneval 1)
set(tenval 10)
set(stringval "test")


set(boolnoval)
set(boolnullval)
set(booltrueval 1)
set(boolfalseval 0)
set(boolzeroval 0)
set(booloneval 1)
set(booltenval 10)
set(boolstringval "test")

configure_file(config.h.in ${PROJECT_SOURCE_DIR}/expected_config.h)

# pwd.sh.in
set(DIR "\${PWD}")

configure_file(pwd.sh.in ${PROJECT_SOURCE_DIR}/expected_pwd.sh)

# sigil.h.in
configure_file(sigil.h.in ${PROJECT_SOURCE_DIR}/expected_sigil.h)

# stack.h.in
set(AT "@")
set(UNDERSCORE "_")
set(NEST_UNDERSCORE_PROXY "UNDERSCORE")
set(NEST_PROXY "NEST_UNDERSCORE_PROXY")

configure_file(stack.h.in ${PROJECT_SOURCE_DIR}/expected_stack.h)

# wrapper.h.in
set(DOLLAR "$")
set(TEXT "TRAP")

set(STRING "TEXT")
set(STRING_AT "@STRING@")
set(STRING_CURLY "{STRING}")
set(STRING_VAR "\${STRING}")

configure_file(wrapper.h.in ${PROJECT_SOURCE_DIR}/expected_wrapper.h)