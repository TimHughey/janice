
#include "cmds/cmd_types.hpp"

static const char *TAG = "mcrCmdTypeMap";

static const std::map<std::string, mcrCmdType> _cmd_map = {
    {std::string("unknown"), mcrCmdType::unknown},
    {std::string("none"), mcrCmdType::none},
    {std::string("time.sync"), mcrCmdType::timesync},
    {std::string("set.switch"), mcrCmdType::setswitch},
    {std::string("set.name"), mcrCmdType::setname},
    {std::string("heartbeat"), mcrCmdType::heartbeat},
    {std::string("ota.begin"), mcrCmdType::otabegin},
    {std::string("ota.continue"), mcrCmdType::otacontinue},
    {std::string("ota.end"), mcrCmdType::otaend},
    {std::string("boot.part.next"), mcrCmdType::bootPartitionNext},
    {std::string("restart"), mcrCmdType::restart}};

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

mcrCmdType_t mcrCmdTypeMap::decodeByte(char byte) {
  switch (byte) {
  case 0xd1:
    return mcrCmdType::otabegin;
    break;

  case 0xd2:
    return mcrCmdType::otacontinue;
    break;

  case 0xd4:
    return mcrCmdType::otaend;
    break;
  }

  return mcrCmdType::unknown;
}

mcrCmdType_t mcrCmdTypeMap::find(const std::string &cmd) {
  auto search = _cmd_map.find(cmd);

  if (search != _cmd_map.end()) {
    return search->second;
  }

  ESP_LOGW(TAG, "unknown cmd=%s", cmd.c_str());

  return mcrCmdType::unknown;
}
