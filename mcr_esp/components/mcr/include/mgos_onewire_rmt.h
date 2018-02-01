#pragma once
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif
    struct mgos_onewire;

    struct mgos_onewire* mgos_onewire_rmt_create(int pin);
    void mgos_onewire_rmt_close(struct mgos_onewire *ow);

    bool mgos_onewire_rmt_reset(struct mgos_onewire *ow);
    uint8_t mgos_onewire_rmt_crc8(const uint8_t *rom, int len);
    void mgos_onewire_rmt_target_setup(struct mgos_onewire *ow, const uint8_t family_code);

    bool mgos_onewire_rmt_next(struct mgos_onewire *ow, uint8_t *rom, int mode);
    void mgos_onewire_rmt_select(struct mgos_onewire *ow, const uint8_t *rom);
    void mgos_onewire_rmt_skip(struct mgos_onewire *ow);
    void mgos_onewire_rmt_search_clean(struct mgos_onewire *ow);

    bool mgos_onewire_rmt_read_bit(struct mgos_onewire *ow);
    uint8_t mgos_onewire_rmt_read(struct mgos_onewire *ow);
    void mgos_onewire_rmt_read_bytes(struct mgos_onewire *ow, uint8_t *buf, int len);

    void mgos_onewire_rmt_write_bit(struct mgos_onewire *ow, int bit);
    void mgos_onewire_rmt_write(struct mgos_onewire *ow, const uint8_t data);
    void mgos_onewire_rmt_write_bytes(struct mgos_onewire *ow, const uint8_t *buf, int len);

#ifdef __cplusplus
}
#endif
