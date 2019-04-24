#include "cmds/cmd_network.hpp"
#include "net/mcr_net.hpp"

static const char *TAG = "mcrCmdNetwork";
static const char *k_host = "host";
static const char *k_name = "name";

mcrCmdNetwork::mcrCmdNetwork(JsonDocument &doc)
    : mcrCmd(mcrCmdType::setname, doc) {

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

const std::string mcrCmdNetwork::debug() { return std::string(TAG); }
