#include <vector>

namespace IO {

typedef std::vector<float>                Floats_t;
typedef std::vector<std::vector<float> >  Tuples_t;

class SomeDataObject {
public:
   const Floats_t& get_floats();
   const Tuples_t& get_tuples();

public:
   void add_float(float f);
   void add_tuple(const std::vector<float>& t);

private:
   Floats_t m_floats;
   Tuples_t m_tuples;
};

struct SomeDataStruct {
   Floats_t Floats;
   char     Label[3];
   int      NLabel;
};

} // namespace IO
