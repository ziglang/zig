#include "operators.h"

// for testing the case of virtual operator==
v_opeq_base::v_opeq_base(int val) : m_val(val) {}
v_opeq_base::~v_opeq_base() {}

bool v_opeq_base::operator==(const v_opeq_base& other) {
   return m_val == other.m_val;
}

v_opeq_derived::v_opeq_derived(int val) : v_opeq_base(val) {}
v_opeq_derived::~v_opeq_derived() {}

bool v_opeq_derived::operator==(const v_opeq_derived& other) {
   return m_val != other.m_val;
}
