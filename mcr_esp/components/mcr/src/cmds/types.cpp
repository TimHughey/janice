
#include "cmds/types.hpp"

namespace mcr {

static const char *TAG = "mcrCmdTypeMap";

static const std::map<string_t, mcrCmdType> _cmd_map = {
    {string_t("unknown"), mcrCmdType::unknown},
    {string_t("none"), mcrCmdType::none},
    {string_t("time.sync"), mcrCmdType::timesync},
    {string_t("set.switch"), mcrCmdType::setswitch},
    {string_t("set.name"), mcrCmdType::setname},
    {string_t("heartbeat"), mcrCmdType::heartbeat},
    {string_t("restart"), mcrCmdType::restart},
    {string_t("engines.suspend"), mcrCmdType::enginesSuspend},
    {string_t("ota.https"), mcrCmdType::otaHTTPS},
    {string_t("pwm"), mcrCmdType::pwm}};

static mcrCmdTypeMap_t *__singleton;

mcrCmdTypeMap::mcrCmdTypeMap() {
  ESP_LOGD(TAG, "_cmd_set sizeof=%u", sizeof(_cmd_map));
}

// STATIC!
mcrCmdTypeMap_t *mcrCmdTypeMap::instance() {
  if (__singleton == nullptr) {
    __singleton = new mcrCmdTypeMap();
  }

  return __singleton;
}

mcrCmdType_t mcrCmdTypeMap::find(const string_t &cmd) {
  auto search = _cmd_map.find(cmd);

  if (search != _cmd_map.end()) {
    return search->second;
  }

  ESP_LOGD(TAG, "unknown cmd=%s", cmd.c_str());

  return mcrCmdType::unknown;
}
} // namespace mcr
