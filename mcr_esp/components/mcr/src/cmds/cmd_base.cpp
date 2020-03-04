#include "cmds/cmd_base.hpp"

using std::move;
using std::unique_ptr;

// static const char *TAG = "mcrCmd";
static const char *k_mtime = "mtime";
static const char *k_cmd = "cmd";

mcrCmd::mcrCmd(JsonDocument &doc, elapsedMicros &e) : _parse_elapsed(e) {
  populate(doc);
}

mcrCmd::mcrCmd(mcrCmdType_t type) {
  _mtime = time(nullptr);
  _type = type;
}

mcrCmd::mcrCmd(mcrCmdType_t type, JsonDocument &doc, elapsedMicros &e)
    : _type(type), _parse_elapsed(e) {
  populate(doc);
}

bool mcrCmd::matchExternalDevID(const string_t &match) {
  auto match_pos = _external_dev_id.find(match);

  return (match_pos == std::string::npos) ? false : true;
}

bool mcrCmd::matchPrefix(const char *prefix) {
  return ((_external_dev_id.substr(0, strlen(prefix))) == prefix);
}

void mcrCmd::populate(JsonDocument &doc) {
  if (doc.isNull()) {
    // there should be some warning here OR determine this check isn't
    // required and remove it!
  } else {
    _mtime = doc[k_mtime] | time(nullptr);
    _type = mcrCmdTypeMap::fromString(doc[k_cmd] | "unknown");
  }
}

bool mcrCmd::sendToQueue(cmdQueue_t &cmd_q, mcrCmd_t *cmd) {
  auto rc = false;
  auto q_rc = pdTRUE;

  if (matchPrefix(cmd_q.prefix)) {
    // make a fresh copy of the cmd before pushing to the queue to ensure:
    //   a. each queue receives it's own copy
    //   b. we're certain each cmd is in a clean state

    // pop the oldest cmd (at the front) to make space when the queue is full
    if (uxQueueSpacesAvailable(cmd_q.q) == 0) {
      mcrCmd_t *old_cmd = nullptr;

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
      q_rc = xQueueSendToBack(cmd_q.q, (void *)&cmd, pdMS_TO_TICKS(10));

      if (q_rc == pdTRUE) {
        rc = true;
      } else {
        textReading_t *rlog(new textReading_t);
        textReading_ptr_t rlog_ptr(rlog);
        rlog->printf("[%s] queue FAILURE for %s", cmd_q.id,
                     _external_dev_id.c_str());
        rlog->publish();

        delete cmd; // delete the cmd passed in since it was never used
      }
    }

  } else {
    delete cmd; // delete the cmd passed in since it was never used
  }

  return rc;
}

void mcrCmd::translateDevID(const string_t &str, const char *with_str) {

  // update the internal dev ID (originally external ID)
  auto pos = _internal_dev_id.find(str);
  _internal_dev_id.replace(pos, str.length(), with_str);
}

const unique_ptr<char[]> mcrCmd::debug() {

  const auto max_buf = 128;
  unique_ptr<char[]> debug_str(new char[max_buf]);

  snprintf(debug_str.get(), max_buf,
           "mcrCmd(latency_us(%0.3fs) parse(%0.3fs) create(%0.3fs)",
           latency_us().asSeconds(), _parse_elapsed.asSeconds(),
           _create_elapsed.asSeconds());

  return move(debug_str);
}
