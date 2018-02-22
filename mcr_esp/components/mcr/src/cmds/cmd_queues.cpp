
#include "cmds/cmd_queues.hpp"

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
