#!/bin/zsh

host=$(hostname)

[[ $host -ne "jophiel" ]] && echo "please run on jophiel" && exit 255

function run_cmd {
    "$@"
    local rc=$?
    if [ $rc -ne 0 ]; then
        echo "error with $1" >&2
				exit 1
    fi
    return $rc
}

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
mcr=${base}/mcr_esp
mcr_build=${mcr}/build
fw_suffixes=(bin elf)
vsn=$(git describe)
htdocs=/dar/www/wisslanding/htdocs/janice/mcr_esp/firmware

if ! type "portageq" > /dev/null; then
	MAKEOPTS=$(portageq envvar MAKEOPTS)
else
	MAKEOPTS="-j9"
fi

pushd $mcr
print -n "make ${MAKEOPTS} 1> /dev/null"
# run_cmd make app-clean 1> /dev/null
run_cmd make ${MAKEOPTS} 1> /dev/null && print " done"

popd

pushd $htdocs
# echo "deploying mcr_esp.{bin,elf} to $htdocs"
for suffix in $fw_suffixes; do
  src=${mcr_build}/mcr_esp.${suffix}
  dest=${vsn}-mcr_esp.${suffix}
  latest=latest-mcr_esp.${suffix}

  sudo_cmd cp $src $dest

  # point the well known name latest-mcr_esp.* to the new file
  sudo_cmd rm -f $latest
  sudo_cmd ln -s ./${dest} $latest
done

popd
