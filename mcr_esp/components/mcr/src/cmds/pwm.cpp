
#include "cmds/pwm.hpp"
#include "cmds/queues.hpp"

namespace mcr {

cmdPWM::cmdPWM(JsonDocument &doc, elapsedMicros &e)
    : mcrCmd(mcrCmdType::pwm, doc, e) {
  // json format of states command:
  // {"device":"pwm/mcr.xxx.pin:n",
  //   "duty":2048,
  //   "refid":"0fc4417c-f1bb-11e7-86bd-6cf049e7139f",
  //   "mtime":1515117138,
  //   "cmd":"pwm"}
  _create_elapsed.reset();

  _external_dev_id = doc["device"].as<std::string>();
  _internal_dev_id = _external_dev_id; // default to external name
  _refid = doc["refid"].as<std::string>();
  _duty = doc["duty"].as<uint32_t>();
  const JsonVariant ack_flag = doc["ack"];

  // set the ack flag if it's in the json
  if (ack_flag.isNull() == false) {
    _ack = ack_flag.as<bool>();
  }

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
