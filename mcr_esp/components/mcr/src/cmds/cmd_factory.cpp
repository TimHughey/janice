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
  StaticJsonDocument<_jsonBufferCapacity> doc;
  mcrCmd_t *cmd = nullptr;
  mcrCmdType_t cmd_type = mcrCmdType::unknown;

  // ensure the raw data is null terminated
  raw->push_back(0x00);

  int64_t start = esp_timer_get_time();
  auto err = deserializeJson(doc, (const char *)raw->data());
  int64_t parse_us = esp_timer_get_time() - start;

  if (err) { // bail if json parse failed
    ESP_LOGW(TAG, "parse of JSON failed (%s)", err.c_str());
    return cmd;
  }

  auto cmd_str = doc["cmd"].as<std::string>();
  cmd_type = mcrCmdTypeMap::fromString(cmd_str);

  switch (cmd_type) {
  case mcrCmdType::unknown:
    ESP_LOGW(TAG, "unknown command [%s]", cmd_str.c_str());
    cmd = new mcrCmd(doc);
    break;

  case mcrCmdType::none:
  case mcrCmdType::heartbeat:
  case mcrCmdType::timesync:
    cmd = new mcrCmd(doc);
    break;

  case mcrCmdType::setswitch:
    cmd = new mcrCmdSwitch(doc);
    break;

  case mcrCmdType::setname:
    cmd = new mcrCmdNetwork(doc);
    break;

  case mcrCmdType::otabegin:
  case mcrCmdType::otacontinue:
  case mcrCmdType::otaend:
  case mcrCmdType::restart:
  case mcrCmdType::bootPartitionNext:
  case mcrCmdType::otaHTTPS:
    cmd = new mcrCmdOTA(cmd_type, doc);
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
