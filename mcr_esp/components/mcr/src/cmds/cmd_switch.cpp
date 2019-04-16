
#include "cmds/cmd_switch.hpp"
#include "cmds/cmd_queues.hpp"

const static char *TAG = "mcrCmdSwitch";

mcrCmdSwitch::mcrCmdSwitch(JsonObject &root)
    : mcrCmd(mcrCmdType::setswitch, root) {
  // json format of states command:
  // {"switch":"ds/29463408000000",
  //   "states":[{"state":false,"pio":3}],
  //   "refid":"0fc4417c-f1bb-11e7-86bd-6cf049e7139f",
  //   "mtime":1515117138,
  //   "cmd":"set.switch"}
  int64_t create_start = esp_timer_get_time();
  _dev_id = root["switch"].as<std::string>();
  _refid = root["refid"].as<std::string>();
  const JsonVariant &variant = root.get<JsonVariant>("states");
  const JsonArray &states = variant.as<JsonArray>();
  const JsonVariant &ack_flag = root["ack"];
  uint32_t mask = 0x00;
  uint32_t tobe_state = 0x00;

  // iterate through the array of new states
  for (auto element : states) {
    // get a reference to the object from the array
    const JsonObject &requested_state = element.as<JsonObject>();

    const uint32_t bit = requested_state["pio"].as<uint32_t>();
    const bool state = requested_state["state"].as<bool>();

    // set the mask with each bit that should be adjusted
    mask |= (0x01 << bit);

    // set the tobe state with the values those bits should be
    // if the new_state is true (on) then set the bit,
    // otherwise leave it unset
    if (state) {
      tobe_state |= (0x01 << bit);
    }

    // set the ack flag if it's in the json
    if (ack_flag.success()) {
      _ack = ack_flag.as<bool>();
    }
  }

  _mask = mask;
  _state = tobe_state;

  int64_t create_us = esp_timer_get_time() - create_start;
  recordCreateMetric(create_us);
}

bool mcrCmdSwitch::matchPrefix(const char *prefix) {
  const std::string prefix_str(prefix);

  return _dev_id.matchPrefix(prefix);
}

bool mcrCmdSwitch::process() {
  for (auto cmd_q : mcrCmdQueues::all()) {
    sendToQueue(cmd_q);
  }

  return true;
}

bool mcrCmdSwitch::sendToQueue(cmdQueue_t &cmd_q) {
  if (matchPrefix(cmd_q.prefix)) {
    // make a fresh copy of the cmd before pusing to the queue to ensure:
    //   a. each queue receives it's own copy
    //   b. we're certain each cmd is in a clean state
    mcrCmdSwitch_t *fresh_cmd = new mcrCmdSwitch(this);

    if (xQueueSendToBack(cmd_q.q, (void *)&fresh_cmd, pdMS_TO_TICKS(10)) ==
        pdTRUE) {
      ESP_LOGD(TAG, "%s queued %s", cmd_q.id, debug().c_str());
    } else
      ESP_LOGW(TAG, "queue to %s FAILED", cmd_q.id);
  }

  return true;
}

const std::string mcrCmdSwitch::debug() {
  std::ostringstream debug_str;

  debug_str << mcrCmd::debug() << " mcrCmdSwitch(" << _dev_id << " mask=0b"
            << _mask << " state=0b" << _state << ((_ack) ? " ACK" : "NOACK")
            << ")";

  return debug_str.str();
}
