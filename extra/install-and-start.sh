#!/bin/zsh

	save_cwd=`pwd`

	function run_cmd {
			"$@"
			local rc=$?
			if [ $rc -ne 0 ]; then
					echo "error with $1" >&2
					cd $save_cwd
					exit 1
			fi
			return $rc
	}

	if [[ $1 == "--clean" ]]; then
		clean=1
	fi


	setopt local_options rm_star_silent

	# configuration variables
	mcp_base=${HOME}/devel/janice/mcp
	mcr_esp_base=${HOME}/devel/janice/mcr_esp
	mcr_esp_bin_src=${mcr_esp_base}/build/mcr_esp.bin
	mcr_esp_elf_src=${mcr_esp_base}/build/mcr_esp.elf
	mcr_esp_prefix=$(git describe)
	jan_base=/usr/local/janice
	jan_base_new=${jan_base}.new
	jan_base_old=${jan_base}.old
	jan_bin=$jan_base/bin
	www_root=/dar/www/wisslanding/htdocs
	mcr_esp_fw_loc=${www_root}/janice/mcr_esp/firmware
	mcr_esp_bin=${mcr_esp_prefix}-mcr_esp.bin
	mcr_esp_bin_deploy=${mcr_esp_fw_loc}/${mcr_esp_bin}
	mcr_esp_elf=${mcr_esp_prefix}-mcr_esp.elf
	mcr_esp_elf_deploy=${mcr_esp_fw_loc}/${mcr_esp_elf}

	release=/run/janice/mcp.tar.gz

	if [[ ! -f $release ]]; then
		print "deploy tar $release doesn't exist, doing nothing."
		return 1
	fi

	print -n "untarring $release into $jan_base_new"

	run_cmd sudo rm -rf $jan_base_new
	run_cmd sudo mkdir --mode 0775 $jan_base_new
	run_cmd sudo chown janice:janice $jan_base_new
	run_cmd sudo -u janice tar -C $jan_base_new -xf $release && print " done."

	$jan_bin/mcp ping 1> /dev/null 2>&1
	if [[ $? -eq 0 ]]; then
		print -n "stopping janice... "
		# HACK - to solve issue with /run permissions
		# sudo chmod go+w /run ; sleep 5
		run_cmd $jan_base/bin/mcp stop 1> /dev/null 2>&1

		# check mcp really shutdown
		$jan_bin/mcp ping 1> /dev/null 2>&1
		if [[ $? -ne 0 ]]; then
		  print "FAILED, aborting install."
		  return 1
		else
			print "done."
		fi
	fi

	print "executing mix ecto.migrate:"
	cd $mcp_base
	run_cmd env MIX_ENV=prod mix ecto.migrate
	cd $save_cwd

	print -n "swapping in new release..."
	run_cmd sudo rm -rf $jan_base_old 1> /dev/null 2>&1
	run_cmd sudo mv $jan_base $jan_base_old 1> /dev/null 2>&1
	run_cmd sudo mv $jan_base_new $jan_base 1> /dev/null 2>&1 && print " done."

	print -n "starting janice..."

	# sudo chmod go+w /run
	sudo -u janice --set-home --preserve-env env PORT=4009 $jan_bin/mcp start && print " done."
	# sudo -u janice env PORT=4009 $jan_bin/mcp start && print " done."
	# sleep 5 ; sudo chmod go+w /run

	print -n "removing deploy tar..." && rm -f $release && print " done."

	if [[ $clean -eq 1 ]]; then
		print -n "removing $jan_base_old..." && run_cmd sudo rm -rf $jan_base_old && print " done."
	else
		print "won't remove ${jan_base_old}, use --clean to do so"
	fi

	print "tailing janice log file. (use CTRL+C to stop)"
	exec tail --lines=100 -f $jan_base/var/log/erlang.*(om[1])
