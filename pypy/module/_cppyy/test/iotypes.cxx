#include "iotypes.h"

const IO::Floats_t& IO::SomeDataObject::get_floats() { return m_floats; }
const IO::Tuples_t& IO::SomeDataObject::get_tuples() { return m_tuples; }

void IO::SomeDataObject::add_float(float f) { m_floats.push_back(f); }
void IO::SomeDataObject::add_tuple(const std::vector<float>& t) { m_tuples.push_back(t); }
