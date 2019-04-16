#include "cmds/cmd_factory.hpp"

// {"switch":"ds/12328621000000",
// "states":[{"state":false,"pio":1}],
// "refid":"0eb82430-0320-11e8-94b6-6cf049e7139f",
// "mtime":1517029685,"cmd":"set.switch"}

static const char *TAG = "mcrCmdFactory";
static const int _jsonBufferCapacity =
    JSON_OBJECT_SIZE(10) + JSON_ARRAY_SIZE(8) + JSON_OBJECT_SIZE(2) * 8;

// static const int _jsonBufferCapacity = 1024;

mcrCmd_t *mcrCmdFactory::fromRaw(mcrRawMsg_t *raw) {
  mcrCmd_t *cmd = nullptr;

  if (raw->size() == 0) {
    ESP_LOGW(TAG, "zero length msg");
    return cmd;
  }

  if (raw->at(0) == '{') {
    cmd = fromJSON(raw);
  } else {
    cmd = fromOTA(raw);
  }

  return cmd;
}

mcrCmd_t *mcrCmdFactory::fromJSON(mcrRawMsg_t *raw) {
  StaticJsonBuffer<_jsonBufferCapacity> jsonBuffer;
  mcrCmd_t *cmd = nullptr;
  mcrCmdType_t cmd_type = mcrCmdType::unknown;

  // ensure the raw data is null terminated
  raw->push_back(0x00);

  int64_t start = esp_timer_get_time();
  JsonObject &root = jsonBuffer.parseObject((const char *)raw->data());
  int64_t parse_us = esp_timer_get_time() - start;

  if (!root.success()) { // bail if json parse failed
    ESP_LOGW(TAG, "parse of JSON failed");
    return cmd;
  }

  auto cmd_str = root["cmd"].as<std::string>();
  cmd_type = mcrCmdTypeMap::fromString(cmd_str);

  switch (cmd_type) {
  case mcrCmdType::unknown:
  case mcrCmdType::none:
  case mcrCmdType::heartbeat:
  case mcrCmdType::timesync:
    cmd = new mcrCmd(root);
    break;

  case mcrCmdType::setswitch:
    cmd = new mcrCmdSwitch(root);
    break;

  case mcrCmdType::setname:
    cmd = new mcrCmdNetwork(root);
    break;

  case mcrCmdType::otabegin:
  case mcrCmdType::otacontinue:
  case mcrCmdType::otaend:
  case mcrCmdType::restart:
  case mcrCmdType::bootPartitionNext:
    cmd = new mcrCmdOTA(cmd_type, root);
    break;

  case mcrCmdType::stopEngines:
    break;
  }

  if (cmd) {
    cmd->recordParseMetric(parse_us);
  }
  return cmd;
}

mcrCmd_t *mcrCmdFactory::fromOTA(mcrRawMsg_t *raw) {
  mcrCmd_t *cmd = nullptr;
  mcrCmdType_t cmd_type = mcrCmdType::unknown;

  cmd_type = mcrCmdTypeMap::fromByte(raw->at(0));

  switch (cmd_type) {
  case mcrCmdType::otabegin:
  case mcrCmdType::otacontinue:
  case mcrCmdType::otaend:
    cmd = new mcrCmdOTA(cmd_type, raw);

  default:
    break;
  }

  return cmd;
}
