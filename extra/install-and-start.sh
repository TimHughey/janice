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
	jan_base=/usr/local/janice
	jan_base_new=${jan_base}.new
	jan_base_old=${jan_base}.old
	jan_bin=$jan_base/bin
	release=/run/janice/mcp.tar.gz


	if [[ ! -f $release ]]; then
		print "deploy tar $release doesn't exist, doing nothing."
		return 1
	fi

	print -n "untarring $release into $jan_base_new"

	run_cmd sudo rm -rf $jan_base_new
	run_cmd sudo mkdir --mode 0775 $jan_base_new
	run_cmd sudo chown janice:janice $jan_base_new
	run_cmd tar -C $jan_base_new -xf $release && print " done."


	$jan_bin/mcp ping 1> /dev/null 2>&1
	if [[ $? -eq 0 ]]; then
		print -n "stopping janice before swapping old and new..."
		run_cmd $jan_base/bin/mcp stop 1> /dev/null 2>&1 && print " done."
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

	env PORT=4009 mcp start && print " done."

	print -n "removing deploy tar..." && rm -f $release && print " done."

	if [[ $clean -eq 1 ]]; then
		print -n "removing $jan_base_old..." && run_cmd sudo rm -rf $jan_base_old && print " done."
	else
		print "won't remove ${jan_base_old}, use --clean to do so"
	fi

	print "tailing janice log file. (use CTRL+C to stop)"
	exec tail --lines=100 -f $jan_base/var/log/erlang.*(om[1])
