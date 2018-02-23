#include "cmds/cmd_network.hpp"
#include "net/mcr_net.hpp"

static const char *TAG = "mcrCmdNetwork";
static const char *k_host = "host";
static const char *k_name = "name";

mcrCmdNetwork::mcrCmdNetwork(JsonObject &root)
    : mcrCmd(mcrCmdType::setname, root) {

  if (root.success()) {
    _host = root[k_host] | "no_host";
    _name = root[k_name] | "no_name";
  }
}

bool mcrCmdNetwork::process() {
  if (_host == mcrUtil::hostID()) {
    mcrNetwork::setName(_name);
    return true;
  }

  return false;
}

const std::string mcrCmdNetwork::debug() { return std::string(TAG); }
