
#include "cmds/cmd_switch.hpp"
#include "cmds/cmd_queues.hpp"

// const static char *TAG = "mcrCmdSwitch";

mcrCmdSwitch::mcrCmdSwitch(JsonDocument &doc)
    : mcrCmd(mcrCmdType::setswitch, doc) {
  // json format of states command:
  // {"switch":"ds/29463408000000",
  //   "states":[{"state":false,"pio":3}],
  //   "refid":"0fc4417c-f1bb-11e7-86bd-6cf049e7139f",
  //   "mtime":1515117138,
  //   "cmd":"set.switch"}
  elapsedMicros create_elapsed;

  _dev_id = doc["switch"].as<std::string>();
  _refid = doc["refid"].as<std::string>();
  const JsonArray states = doc["states"].as<JsonArray>();
  const JsonVariant ack_flag = doc["ack"];
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
    if (ack_flag.isNull() == false) {
      _ack = ack_flag.as<bool>();
    }
  }

  _mask = mask;
  _state = tobe_state;

  int64_t create_us = create_elapsed;
  recordCreateMetric(create_us);
}

bool mcrCmdSwitch::matchDevID(const string_t &match) {
  _match_pos = _dev_id.find(match);

  return (_match_pos == std::string::npos) ? false : true;
}

bool mcrCmdSwitch::matchPrefix(const char *prefix) {
  return ((_dev_id.substr(0, strlen(prefix))) == prefix);
}

bool mcrCmdSwitch::process() {
  for (auto cmd_q : mcrCmdQueues::all()) {
    sendToQueue(cmd_q);
  }

  return true;
}

bool mcrCmdSwitch::sendToQueue(cmdQueue_t &cmd_q) {
  auto rc = false;
  auto q_rc = pdTRUE;

  if (matchPrefix(cmd_q.prefix)) {
    // make a fresh copy of the cmd before pushing to the queue to ensure:
    //   a. each queue receives it's own copy
    //   b. we're certain each cmd is in a clean state
    mcrCmdSwitch_t *fresh_cmd = new mcrCmdSwitch(this);

    // pop the oldest cmd (at the front) to make space when the queue is full
    if (uxQueueSpacesAvailable(cmd_q.q) == 0) {
      mcrCmdSwitch_t *old_cmd = nullptr;

      q_rc = xQueueReceive(cmd_q.q, &old_cmd, pdMS_TO_TICKS(10));

      if ((q_rc == pdTRUE) && (old_cmd != nullptr)) {
        textReading_t *rlog(new textReading_t);
        textReading_ptr_t rlog_ptr(rlog);
        rlog->printf("[%s] queue FULL, removing oldest cmd (%s)", cmd_q.id,
                     old_cmd->devID().c_str());
        rlog->publish();
        delete old_cmd;
      }
    }

    if (q_rc == pdTRUE) {
      q_rc = xQueueSendToBack(cmd_q.q, (void *)&fresh_cmd, pdMS_TO_TICKS(10));

      if (q_rc == pdTRUE) {
        rc = true;
      } else {
        textReading_t *rlog(new textReading_t);
        textReading_ptr_t rlog_ptr(rlog);
        rlog->printf("[%s] queue FAILURE for %s", cmd_q.id, _dev_id.c_str());
        rlog->publish();

        delete fresh_cmd; // delete the fresh cmd since it wasn't queued
      }
    }
  }

  return rc;
}

void mcrCmdSwitch::translateDevID(const string_t &str, const char *with_str) {
  // make a copy of the cmd dev name so we can change it
  string_t _internal_dev_id = _dev_id;
  _internal_dev_id.replace(_match_pos, str.length(), with_str);
}

const unique_ptr<char[]> mcrCmdSwitch::debug() {
  const auto max_len = 127;
  unique_ptr<char[]> debug_str(new char[max_len + 1]);

  snprintf(debug_str.get(), max_len, " mcrCmdSwitch(%s mask=0b%s state=0b%s %s",
           _dev_id.c_str(), _mask.to_string().c_str(),
           _state.to_string().c_str(), ((_ack) ? "ACK" : ""));

  return move(debug_str);
}
