#include <string.h>

#include "cmds/cmd_queues.hpp"

namespace mcr {

static const char *TAG = "mcrCmdQueues";
static mcrCmdQueues_t *__singleton = nullptr;

mcrCmdQueues *mcrCmdQueues::instance() {
  if (__singleton == nullptr) {
    __singleton = new mcrCmdQueues();
  }

  return __singleton;
}

void mcrCmdQueues::registerQ(cmdQueue_t &cmd_q) {
  ESP_LOGI(TAG, "registering cmd_q id=%s prefix=%s q=%p", cmd_q.id,
           cmd_q.prefix, (void *)cmd_q.q);

  instance()->add(cmd_q);
}

const unique_ptr<char[]> mcrCmdQueues::debug() {
  unique_ptr<char[]> debug_str(new char[strlen(TAG) + 1]);

  strcpy(debug_str.get(), TAG);

  return move(debug_str);
}
} // namespace mcr
