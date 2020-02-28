
#include "misc/status_led.hpp"

namespace mcr {
static const char *TAG = "statusLED";
static StatusLED_t *__singleton__ = nullptr;

StatusLED::StatusLED() {
  esp_err_t timer_rc, config_rc;

  timer_rc = ledc_timer_config(&ledc_timer_);

  if (timer_rc == ESP_OK) {
    config_rc = ledc_channel_config(&ledc_channel_);
    ESP_LOGI(TAG, "timer_rc: [%s] config_rc: [%s]", esp_err_to_name(timer_rc),
             esp_err_to_name(config_rc));

    if (config_rc == ESP_OK) {
      ledc_fade_func_install(0);
    }
  } else {
    ESP_LOGI(TAG, "timer_rc: [%s]", esp_err_to_name(timer_rc));
  }
}

void StatusLED::bright() {
  duty_ = 4095;
  activate_duty();
}

void StatusLED::brighter() {
  duty_ += 512;

  if (duty_ > 4095) {
    duty_ = 4095;
  }

  activate_duty();
}

void StatusLED::dim() {
  duty_ = 128;
  activate_duty();
}

void StatusLED::dimmer() {
  duty_ -= 0;

  if (duty_ < 128) {
    duty_ = 128;
  }

  activate_duty();
}

void StatusLED::off() {
  duty_ = 0;
  activate_duty();
}

void StatusLED::activate_duty() {
  ledc_set_duty_and_update(ledc_channel_.speed_mode, ledc_channel_.channel,
                           duty_, 0);
}

// STATIC
void StatusLED::duty(uint32_t new_duty) {

  if ((new_duty > 0) && (new_duty < 4096)) {
    instance()->duty_ = new_duty;

    instance()->activate_duty();
  }
}

// STATIC
StatusLED_t *StatusLED::instance() {
  if (__singleton__ == nullptr) {
    __singleton__ = new StatusLED();
  }

  return __singleton__;
}
} // namespace mcr
