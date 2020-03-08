
#include "cmds/switch.hpp"
#include "cmds/queues.hpp"

namespace mcr {

cmdSwitch::cmdSwitch(JsonDocument &doc, elapsedMicros &e)
    : mcrCmd(doc, e, "switch") {
  // json format of states command:
  // {"switch":"ds/29463408000000",
  //   "states":[{"state":false,"pio":3}],
  //   "refid":"0fc4417c-f1bb-11e7-86bd-6cf049e7139f",
  //   "mtime":1515117138,
  //   "cmd":"set.switch"}

  // switch cmds for i2c devices require the internal device id
  // to be translated
  auto i2c_str = _internal_dev_id.find("i2c");
  if (i2c_str != std::string::npos) {
    translateExternalDeviceID("self");
  }

  const JsonArray states = doc["states"].as<JsonArray>();
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
  }

  _mask = mask;
  _state = tobe_state;

  _create_elapsed.freeze();
}

bool cmdSwitch::process() {
  for (auto cmd_q : mcrCmdQueues::all()) {
    auto fresh_cmd = new cmdSwitch(this);
    sendToQueue(cmd_q, fresh_cmd);
  }

  return true;
}

const unique_ptr<char[]> cmdSwitch::debug() {
  const auto max_len = 127;
  unique_ptr<char[]> debug_str(new char[max_len + 1]);

  snprintf(debug_str.get(), max_len, "cmdSwitch(%s m(0b%s) s(0b%s) %s)",
           _external_dev_id.c_str(), _mask.to_string().c_str(),
           _state.to_string().c_str(), ((_ack) ? "ACK" : ""));

  return move(debug_str);
}

} // namespace mcr
