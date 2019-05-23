#include "cmds/cmd_network.hpp"
#include "net/mcr_net.hpp"

static const char *TAG = "mcrCmdNetwork";
static const char *k_host = "host";
static const char *k_name = "name";

mcrCmdNetwork::mcrCmdNetwork(JsonDocument &doc, elapsedMicros &e)
    : mcrCmd(mcrCmdType::setname, doc, e) {

  if (doc.isNull() == false) {
    _host = doc[k_host] | "no_host";
    _name = doc[k_name] | "no_name";
  }
}

bool mcrCmdNetwork::process() {
  if (_host == mcr::Net::hostID()) {
    mcr::Net::setName(_name);
    return true;
  }

  return false;
}

const unique_ptr<char[]> mcrCmdNetwork::debug() {
  unique_ptr<char[]> debug_str(new char[strlen(TAG) + 1]);

  strcpy(debug_str.get(), TAG);

  return move(debug_str);
}
