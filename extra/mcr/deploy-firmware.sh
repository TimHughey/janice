#!/usr/bin/env zsh

host=$(hostname -s)

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

if [[ -x /usr/bin/portageq ]]; then
	MAKEOPTS=$(portageq envvar MAKEOPTS)
else
	MAKEOPTS="-j9"
fi

pushd -q $mcr

if [[ "${host}" = "jophiel" ]]; then
  git pull || exit 1
fi

run_cmd make ${MAKEOPTS}

# echo "deploying mcr_esp.{bin,elf} to $htdocs"
for suffix in "${fw_suffixes[@]}"; do
  src=${mcr_build}/mcr_esp.${suffix}
  dest=${vsn}-mcr_esp.${suffix}
  latest=latest-mcr_esp.${suffix}

  if [[ "${host}" != "jophiel" ]]; then
    run_cmd scp ${src} jophiel:${htdocs}/${dest}
    ssh jophiel "pushd -q ${htdocs} ; rm -f ${latest}"
    ssh jophiel "pushd -q ${htdocs} ; ln -s ./${dest} ${latest}"
  else
    pushd -q $htdocs
    run_cmd cp $src $dest || exit 1

    # point the well known name latest-mcr_esp.* to the new file
    sudo_cmd rm -f $latest
    sudo_cmd ln -s ./${dest} $latest

		ls -l $latest
		popd -q
  fi
done

popd -q
