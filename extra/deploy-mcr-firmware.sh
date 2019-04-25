#!/bin/zsh

save_cwd=$(pwd)
host=$(hostname)

[[ $host -ne "jophiel" ]] && echo "please run jophiel" && exit 255

function sudo_cmd {
    sudo -u janice "$@"
    local rc=$?
    if [ $rc -ne 0 ]; then
        echo "error with $1" >&2
				exit 1
    fi
    return $rc
}

base=${HOME}/devel/janice
mcr_build=${base}/mcr_esp/build
fw_suffixes=(bin elf)
vsn=$(git describe)
htdocs=/dar/www/wisslanding/htdocs/janice/mcr_esp/firmware

cd $htdocs
# echo "deploying mcr_esp.{bin,elf} to $htdocs"
for suffix in $fw_suffixes; do
  src=${mcr_build}/mcr_esp.${suffix}
  dest=${vsn}-mcr_esp.${suffix}
  latest=latest-mcr_esp.${suffix}

  # copy the firmware file (bin or elf)
#  echo -n "copying ${src} to ${dest}..."
  sudo_cmd cp $src $dest
#  echo " done."

  # point the well known name latest-mcr_esp.* to the new file
  sudo_cmd rm -f $latest
#  echo -n "linking $latest to $dest..."
  sudo_cmd ln -s ./${dest} $latest
#  echo " done."
done

cd ${save_pwd}
