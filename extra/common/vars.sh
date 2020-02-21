#!/usr/bin/env zsh

autoload colors
if [[ "$terminfo[colors]" -gt 8 ]]; then
    colors
fi

# save current working directory
save_cwd=`pwd`

# source (devel) paths
janice_base=${HOME}/devel/janice
janice_extra=${janice_base}/extra
mcp_base=${janice_base}/mcp
mcp_build_prod=${mcp_base}/_build/prod
mcr_esp_base=${janice_base}/mcr_esp

# mcr build location and prefix
mcr_esp_bin_src=${mcr_esp_base}/build/mcr_esp.bin
mcr_esp_elf_src=${mcr_esp_base}/build/mcr_esp.elf
mcr_esp_prefix=$(git describe)

# prod install path and filenames
jan_base=/usr/local/janice
jan_base_new=${jan_base}.new
jan_base_old=${jan_base}.old
jan_bin=$jan_base/bin

# mcr firmware install path and filenames
www_root=/dar/www/wisslanding/htdocs
mcr_esp_fw_loc=${www_root}/janice/mcr_esp/firmware
mcr_esp_bin=${mcr_esp_prefix}-mcr_esp.bin
mcr_esp_bin_deploy=${mcr_esp_fw_loc}/${mcr_esp_bin}
mcr_esp_elf=${mcr_esp_prefix}-mcr_esp.elf
mcr_esp_elf_deploy=${mcr_esp_fw_loc}/${mcr_esp_elf}

# mcp prod release tar ball
mcp_tarball=${mcp_build_prod}/mcp.tar.gz
