
#include "cmds/cmd_base.hpp"

// static const char *TAG = "mcrCmd";
static const char *k_vsn = "vsn";
static const char *k_mtime = "mtime";
static const char *k_cmd = "cmd";

mcrCmdBase::mcrCmdBase(JsonObject &root) { populate(root); }

mcrCmdBase::mcrCmdBase(mcrCmdType_t type) {
  _vsn = mcrVersion::git();
  _mtime = time(nullptr);
  _type = type;
}

mcrCmdBase::mcrCmdBase(mcrCmdType_t type, JsonObject &root) : _type(type) {
  populate(root);
}

time_t mcrCmdBase::latency() {
  int64_t latency = esp_timer_get_time() - _latency;
  return latency;
}

void mcrCmdBase::populate(JsonObject &root) {
  if (root.success()) {
    _vsn = root[k_vsn] | "0000000";

    _mtime = root[k_mtime] | time(nullptr);
    _type = mcrCmdTypeMap::fromString(root[k_cmd] | "unknown");
  }
}

const std::string mcrCmdBase::debug() {
  std::ostringstream debug_str;
  float latency_ms = (float)latency() / 1000.0;
  float parse_ms = (float)_parse_us / 1000.0;
  float create_ms = (float)_create_us / 1000.0;

  debug_str << "mcrCmdBase(latency=" << latency_ms << "ms parse=" << parse_ms
            << "ms create=" << create_ms << "ms)";
  return debug_str.str();
}
