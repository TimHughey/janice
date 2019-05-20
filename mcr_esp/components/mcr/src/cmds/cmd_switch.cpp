
#include "cmds/cmd_switch.hpp"
#include "cmds/cmd_queues.hpp"

namespace mcr {

CmdSwitch::CmdSwitch(JsonDocument &doc) : mcrCmd(mcrCmdType::setswitch, doc) {
  // json format of states command:
  // {"switch":"ds/29463408000000",
  //   "states":[{"state":false,"pio":3}],
  //   "refid":"0fc4417c-f1bb-11e7-86bd-6cf049e7139f",
  //   "mtime":1515117138,
  //   "cmd":"set.switch"}
  elapsedMicros create_elapsed;

  _external_dev_id = doc["switch"].as<std::string>();
  _internal_dev_id = _external_dev_id; // default to external name
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

  recordCreateMetric(create_elapsed);
}

bool CmdSwitch::matchExternalDevID(const string_t &match) {
  auto match_pos = _external_dev_id.find(match);

  return (match_pos == std::string::npos) ? false : true;
}

bool CmdSwitch::matchPrefix(const char *prefix) {
  return ((_external_dev_id.substr(0, strlen(prefix))) == prefix);
}

bool CmdSwitch::process() {
  for (auto cmd_q : mcrCmdQueues::all()) {
    sendToQueue(cmd_q);
  }

  return true;
}

bool CmdSwitch::sendToQueue(cmdQueue_t &cmd_q) {
  auto rc = false;
  auto q_rc = pdTRUE;

  if (matchPrefix(cmd_q.prefix)) {
    // make a fresh copy of the cmd before pushing to the queue to ensure:
    //   a. each queue receives it's own copy
    //   b. we're certain each cmd is in a clean state
    CmdSwitch_t *fresh_cmd = new CmdSwitch(this);

    // pop the oldest cmd (at the front) to make space when the queue is full
    if (uxQueueSpacesAvailable(cmd_q.q) == 0) {
      CmdSwitch_t *old_cmd = nullptr;

      q_rc = xQueueReceive(cmd_q.q, &old_cmd, pdMS_TO_TICKS(10));

      if ((q_rc == pdTRUE) && (old_cmd != nullptr)) {
        textReading_t *rlog(new textReading_t);
        textReading_ptr_t rlog_ptr(rlog);
        rlog->printf("[%s] queue FULL, removing oldest cmd (%s)", cmd_q.id,
                     old_cmd->externalDevID().c_str());
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
        rlog->printf("[%s] queue FAILURE for %s", cmd_q.id,
                     _external_dev_id.c_str());
        rlog->publish();

        delete fresh_cmd; // delete the fresh cmd since it wasn't queued
      }
    }
  }

  return rc;
}

void CmdSwitch::translateDevID(const string_t &str, const char *with_str) {

  // update the internal dev ID (originally external ID)
  auto pos = _internal_dev_id.find(str);
  _internal_dev_id.replace(pos, str.length(), with_str);
}

const unique_ptr<char[]> CmdSwitch::debug() {
  const auto max_len = 127;
  unique_ptr<char[]> debug_str(new char[max_len + 1]);

  snprintf(debug_str.get(), max_len, "CmdSwitch(%s m(0b%s) s(0b%s) %s)",
           _external_dev_id.c_str(), _mask.to_string().c_str(),
           _state.to_string().c_str(), ((_ack) ? "ACK" : ""));

  return move(debug_str);
}
} // namespace mcr
