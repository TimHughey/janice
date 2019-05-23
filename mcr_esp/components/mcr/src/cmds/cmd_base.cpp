
#include "cmds/cmd_base.hpp"

using std::move;
using std::unique_ptr;

// static const char *TAG = "mcrCmd";
static const char *k_mtime = "mtime";
static const char *k_cmd = "cmd";

mcrCmd::mcrCmd(JsonDocument &doc, elapsedMicros &e) : _parse_elapsed(e) {
  populate(doc);
}

mcrCmd::mcrCmd(mcrCmdType_t type) {
  _mtime = time(nullptr);
  _type = type;
}

mcrCmd::mcrCmd(mcrCmdType_t type, JsonDocument &doc, elapsedMicros &e)
    : _type(type), _parse_elapsed(e) {
  populate(doc);
}

void mcrCmd::populate(JsonDocument &doc) {
  if (doc.isNull()) {
    // there should be some warning here OR determine this check isn't
    // required and remove it!
  } else {
    _mtime = doc[k_mtime] | time(nullptr);
    _type = mcrCmdTypeMap::fromString(doc[k_cmd] | "unknown");
  }
}

const unique_ptr<char[]> mcrCmd::debug() {

  const auto max_buf = 128;
  unique_ptr<char[]> debug_str(new char[max_buf]);

  snprintf(debug_str.get(), max_buf,
           "mcrCmd(latency(%0.3fs) parse(%0.3fs) create(%0.3fs)",
           latency().asSeconds(), _parse_elapsed.asSeconds(),
           _create_elapsed.asSeconds());

  return move(debug_str);
}
