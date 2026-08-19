#include "llama-q38f-shared-galloc.h"

#include <cstdlib>
#include <cstring>

bool llama_q38f_shared_galloc_enabled() {
    const char * v = std::getenv("LLAMA_Q38F_SHARED_GALLOC");

    if (v == nullptr) {
        return false;
    }

    return std::strcmp(v, "1") == 0 ||
           std::strcmp(v, "true") == 0 ||
           std::strcmp(v, "TRUE") == 0 ||
           std::strcmp(v, "on") == 0 ||
           std::strcmp(v, "ON") == 0;
}
