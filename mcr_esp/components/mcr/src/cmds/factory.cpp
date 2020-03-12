#include "cmds/factory.hpp"

namespace mcr {

// {"switch":"ds/12328621000000",
// "states":[{"state":false,"pio":1}],
// "refid":"0eb82430-0320-11e8-94b6-6cf049e7139f",
// "mtime":1517029685,"cmd":"set.switch"}

static const char *TAG = "mcrCmdFactory";

static const int _jsonBufferCapacity =
    JSON_OBJECT_SIZE(10) + JSON_ARRAY_SIZE(8) + JSON_OBJECT_SIZE(2) * 8;

mcrCmdFactory::mcrCmdFactory() {
  // ESP_LOGI(TAG, "JSON static buffer capacity: %d", _jsonBufferCapacity);
}

mcrCmd_t *mcrCmdFactory::fromRaw(JsonDocument &doc, rawMsg_t *raw) {
  mcrCmd_t *cmd = nullptr;
  elapsedMicros parse_elapsed;

  // if the payload is empty there's nothing to do, return a nullptr
  if (raw->empty()) {
    ESP_LOGW(TAG, "payload is zero length, ignoring");
    return cmd;
  }

  DeserializationError err;

  if (raw->at(0) == '{') {
    // this looks like a JSON payload, let's deseralize it
    raw->push_back(0x00); // ensure payload is null terminated
    err = deserializeJson(doc, (const char *)raw->data());

  } else if (raw->at(0) > 0) {
    // this might be a MsgPack payload, let's deseralize it
    err = deserializeMsgPack(doc, (const char *)raw->data());

  } else {
    ESP_LOGW(TAG, "payload is not MsgPack or JSON, ignoring");
  }

  // parsing complete, freeze the elapsed timer
  parse_elapsed.freeze();

  // did the deserailization succeed?
  // if so, manufacture the derived cmd
  if (err) {
    ESP_LOGW(TAG, "[%s] JSON parse failure", err.c_str());
  } else {
    // deserialization success, manufacture the derived cmd
    cmd = manufacture(doc, parse_elapsed);
  }

  return cmd;
}

mcrCmd_t *mcrCmdFactory::manufacture(JsonDocument &doc,
                                     elapsedMicros &parse_elapsed) {
  mcrCmd_t *cmd = nullptr;
  mcrCmdType_t cmd_type = mcrCmdType::unknown;

  auto cmd_str = doc["cmd"].as<string_t>();
  cmd_type = mcrCmdTypeMap::fromString(cmd_str);

  switch (cmd_type) {
  case mcrCmdType::unknown:
    ESP_LOGW(TAG, "unknown command [%s]", cmd_str.c_str());
    cmd = new mcrCmd(doc, parse_elapsed);
    break;

  case mcrCmdType::none:
  case mcrCmdType::heartbeat:
  case mcrCmdType::timesync:
    cmd = new mcrCmd(doc, parse_elapsed);
    break;

  case mcrCmdType::setswitch:
    cmd = new cmdSwitch(doc, parse_elapsed);
    break;

  case mcrCmdType::setname:
    cmd = new mcrCmdNetwork(doc, parse_elapsed);
    break;

  case mcrCmdType::otaHTTPS:
  case mcrCmdType::restart:
    cmd = new mcrCmdOTA(doc, parse_elapsed);
    break;

  case mcrCmdType::enginesSuspend:
    break;

  case mcrCmdType::pwm:
    cmd = new cmdPWM(doc, parse_elapsed);
    break;
  }

  return cmd;
}
} // namespace mcr
