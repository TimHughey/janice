#include "cmds/network.hpp"

namespace mcr {

// static const char *TAG = "mcrCmdNetwork";
static const char *k_name = "name";

mcrCmdNetwork::mcrCmdNetwork(JsonDocument &doc, elapsedMicros &e)
    : mcrCmd{doc, e} {
  _name = doc[k_name] | "";
}

bool mcrCmdNetwork::process() {
  if (forThisHost() && (_name.empty() == false)) {
    Net::setName(_name);
    return true;
  }

  return false;
}

const unique_ptr<char[]> mcrCmdNetwork::debug() {
  const auto max_buf = 128;
  unique_ptr<char[]> debug_str(new char[max_buf]);

  snprintf(debug_str.get(), max_buf,
           "mcrCmdNetwork(host(%s) name(%s)) parse(%lldus)", host().c_str(),
           _name.c_str(), (uint64_t)_parse_elapsed);

  return move(debug_str);
}
} // namespace mcr
