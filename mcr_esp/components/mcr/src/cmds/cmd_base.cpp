
#include "cmds/cmd_base.hpp"

using std::move;
using std::unique_ptr;

// static const char *TAG = "mcrCmd";
static const char *k_mtime = "mtime";
static const char *k_cmd = "cmd";

mcrCmd::mcrCmd(JsonDocument &doc) { populate(doc); }

mcrCmd::mcrCmd(mcrCmdType_t type) {
  _mtime = time(nullptr);
  _type = type;
}

mcrCmd::mcrCmd(mcrCmdType_t type, JsonDocument &doc) : _type(type) {
  populate(doc);
}

time_t mcrCmd::latency() {
  int64_t latency = esp_timer_get_time() - _latency;
  return latency;
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
           "mcrCmd(latency=%02fms parse=%02fms create=%02fms",
           ((float)latency() / 1000.0), ((float)_parse_us / 1000.0),
           ((float)_create_us / 1000.0));

  return move(debug_str);
}
