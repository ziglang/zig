#include "fragile.h"

fragile::H::HH* fragile::H::HH::copy() {
    return (HH*)0;
}

fragile::I fragile::gI;

void fragile::fglobal(int, double, char) {
    /* empty; only used for doc-string testing */
}

namespace fragile {

    class Kderived : public K {
    public:
        virtual ~Kderived();
    };

} // namespace fragile

fragile::Kderived::~Kderived() {}

fragile::K::~K() {}

fragile::K* fragile::K::GimeK(bool derived) {
    if (!derived) return this;
    else {
        static Kderived kd;
        return &kd;
    }
};

fragile::K* fragile::K::GimeL() {
    static L l;
    return &l;
}

fragile::L::~L() {}
