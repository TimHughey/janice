
#include "cmds/pwm.hpp"
#include "cmds/queues.hpp"

namespace mcr {

cmdPWM::cmdPWM(JsonDocument &doc, elapsedMicros &e) : mcrCmd(doc, e, "device") {
  // json format of states command:
  // {"device":"pwm/mcr.xxx.pin:n",
  //   "duty":2048,
  //   "refid":"0fc4417c-f1bb-11e7-86bd-6cf049e7139f",
  //   "mtime":1515117138,
  //   "cmd":"pwm"}

  // overrides the default of internal name == external name
  translateExternalDeviceID("self");

  _duty = doc["duty"].as<uint32_t>();

  _create_elapsed.freeze();
}

bool cmdPWM::process() {
  for (auto cmd_q : mcrCmdQueues::all()) {
    auto *fresh_cmd = new cmdPWM(this);
    sendToQueue(cmd_q, fresh_cmd);
  }

  return true;
}

const unique_ptr<char[]> cmdPWM::debug() {
  const auto max_len = 127;
  unique_ptr<char[]> debug_str(new char[max_len + 1]);

  snprintf(debug_str.get(), max_len, "cmdPWM(%s duty(%d) %s)",
           _external_dev_id.c_str(), _duty, ((_ack) ? "ACK" : ""));

  return move(debug_str);
}
} // namespace mcr
