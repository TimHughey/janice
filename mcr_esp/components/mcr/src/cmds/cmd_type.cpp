
#include "cmds/cmd_types.hpp"

static const char *TAG = "mcrCmdTypeMap";

static const std::map<std::string, mcrCmdType> _cmd_map = {
    {std::string("unknown"), mcrCmdType::unknown},
    {std::string("none"), mcrCmdType::none},
    {std::string("time.sync"), mcrCmdType::timesync},
    {std::string("set.switch"), mcrCmdType::setswitch},
    {std::string("set.name"), mcrCmdType::setname},
    {std::string("heartbeat"), mcrCmdType::heartbeat},
    {std::string("restart"), mcrCmdType::restart},
    {std::string("engines.suspend"), mcrCmdType::enginesSuspend},
    {std::string("ota.https"), mcrCmdType::otaHTTPS},
    {std::string("pwm"), mcrCmdType::pwm}};

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

mcrCmdType_t mcrCmdTypeMap::find(const std::string &cmd) {
  auto search = _cmd_map.find(cmd);

  if (search != _cmd_map.end()) {
    return search->second;
  }

  ESP_LOGD(TAG, "unknown cmd=%s", cmd.c_str());

  return mcrCmdType::unknown;
}
