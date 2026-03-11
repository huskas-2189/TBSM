#!/bin/bash

function tbsm() {
	TBSM_APP_NAME="Tiny Bash SSH Manager"

	# Generics vars
	TBSM_HOST=""
	TBSM_USER=""
	TBSM_DIR="${TBSM_CUSTOM_DIR:-$HOME/.tbsm}"
	TBSM_SSHKEY_DIR="${TBSM_CUSTOM_SSHKEY_DIR:-$HOME/.ssh}"
	TBSM_HOSTS_FILENAME="$TBSM_DIR/ssh_hosts.json"

	# Dépendances à vérifier et message générique d'installation
	deps=(jq dialog ssh-keygen)

	####################################
	## Function declaration
	init() {
		__deps_check

		# Create directory if not exists
		[ ! -d "$TBSM_DIR" ] && mkdir "$TBSM_DIR"
	
		if [ ! -f "${TBSM_HOSTS_FILENAME}" ]; then
			echo "{}" > "$TBSM_HOSTS_FILENAME"
		fi
	}

	cleanup() {
		# Doing some cleanup
		unset select_host_exitcode
		unset new_host
		unset TBSM_HOST
		unset TBSM_USER
		unset TBSM_HOSTS_FILENAME
		unset TBSM_APP_NAME
		unset TBSM_DIR
	}

	__deps_check() {
		for dep in "${deps[@]}"; do
			if ! command -v $dep >/dev/null 2>&1; then
				echo "Error : $dep is not installed or is not in PATH." >&2
				echo "Please install $dep (ex. 'sudo apt install $dep' or 'brew install $dep') then relaunch." >&2
				return 1
			fi
		done
	}

	__tbsm_select_host() {
		local i=0

		local hosts
		hosts=($(__tbsm_read_hosts))
		
		if [ ${#hosts[@]} -eq 0 ]; then 
			__tbsm_add_host

			# vérifie le succès
			if [ $? -ne 0 ]; then
				return 1
			fi

			hosts=($(__tbsm_read_hosts))
		fi

		local i=1
		local dialoghosts=()
		for host in "${hosts[@]}"; do
			dialoghosts+=("$i" "$host")
			((i++))
		done
		
		local title="Choose your host"
		local menu="Please select the host you want to connect to"
		local cancellabel="Exit"

		# Promp Serveur name and select it
		exec 3>&1
		local key=0

		key=$(dialog --extra-button --extra-label "Add Host" --cancel-label "$cancellabel" --clear --backtitle "$TBSM_APP_NAME" --title "$title" --menu "$menu" 20 50 5 "${dialoghosts[@]}" 2>&1 1>&3)
		exitcode=$?
		exec 3>&-;
		clear

		# vérifie le succès
		if [ $? -ne 0 ]; then
		  return 1
		fi

		((key--))

		if [ ${#hosts[@]} -ge $key ]; then
			TBSM_HOST=${hosts[@]:$key:1}
		fi

		return $exitcode
	}

	__tbsm_read_hosts() {
		local tbsm_read_hosts=()
		while IFS='' read -r line; do
			tbsm_read_hosts+=("$line")
		done < <(jq -r 'keys[]' "${TBSM_HOSTS_FILENAME}")

		echo "${tbsm_read_hosts[@]}"
	}

	__tbsm_select_user() {
		if [ $# -eq 0 ]; then
			echo "No host given"
			return 1
		fi

		local host=$1

		local i=0
		local users=()
		local dialogusers=()
		while IFS='' read -r user; do
			((i++))
			users+=("$user")
			dialogusers+=("$i" "$user")
		done < <(jq -r ".\"$host\"[]" "${TBSM_HOSTS_FILENAME}")

		local title="Choose your user"
		local menu="Please select the user to connect to $host"
		local opt="Add user"

		exec 3>&1
		local key=0
		key=$(dialog --clear --extra-button --extra-label "$opt" --backtitle "$TBSM_APP_NAME" --title "$title" --menu "$menu" 20 50 5 "${dialogusers[@]}" 2>&1 1>&3)

		exitcode=$?

		exec 3>&-;
		
		clear
		
		((key--))
		if [ ${#users[@]} -ge $key ]; then
			TBSM_USER=${users[@]:$key:1}
		fi

		return $exitcode
	}

	__tbsm_add_host() {
		local title="Add host"
		local inputtext="Please enter IP or hostname"

		exec 3>&1
		new_host=$(dialog --clear --backtitle "$TBSM_APP_NAME" --title "$title" --inputbox "$inputtext" 20 50 "${1-}" 2>&1 1>&3)
		
		local newhost_exitcode=$?
		exec 3>&-;
		clear
		if [ $newhost_exitcode -gt 0 ]; then
			return $newhost_exitcode
		fi
		__tbsm_add_user $new_host
		adduser_exitcode=$?
		local new_user
		new_user=$__tbsm_add_user
		unset __tbsm_add_user

		return 1

		if [ $adduser_exitcode -gt 0 ]; then
			__tbsm_add_host $new_host
		else
			jq ". |= . + {\"$new_host\": [\"$new_user\"]}" "${TBSM_HOSTS_FILENAME}" > "$TBSM_DIR/.tbsm_tmp_hosts" && mv "$TBSM_DIR/.tbsm_tmp_hosts" "${TBSM_HOSTS_FILENAME}"
		fi
	}

	__tbsm_add_user() {
		if [ $# -eq 0 ]; then
			echo "Missing params"
			exit 1
		fi

		local host=$1
		local newuser
		__tbsm_ask_for_new_user $host
		local exitcode=$?
		__tbsm_add_user="$__tbsm_ask_for_new_user"

		if [ $exitcode -eq 0 ]; then
			local newuser=$__tbsm_ask_for_new_user
			unset __tbsm_ask_for_new_user
			
			jq ".\"$host\" |= . + [\"$newuser\"]" "${TBSM_HOSTS_FILENAME}" > "$TBSM_DIR/.tbsm_tmp_hosts" && mv "$TBSM_DIR/.tbsm_tmp_hosts" "${TBSM_HOSTS_FILENAME}"
			
			__tbsm_ask_for_ssh_key $newuser $host
			if [ $? -eq 0 ]; then
				__tbsm_add_ssh_key $newuser $host
			fi
		fi
	
		return 0
	}

	__tbsm_ask_for_new_user() {
		local title="Add user for $1"
		local inputtext="Enter the name of the user"
		exec 3>&1
		__tbsm_ask_for_new_user=$(dialog --clear --backtitle "$TBSM_APP_NAME" --title "$title" --inputbox "$inputtext" 20 50 2>&1 1>&3)
		local newuser_exitcode=$?
		exec 3>&-;
		clear

		return $newuser_exitcode
	}


	__tbsm_ask_for_ssh_key() {
		local title="SSH Key"
		local question="Do you want to add a custom SSH Key for $1 on $2 ?"
		exec 3>&1
		dialog --clear --backtitle "$TBSM_APP_NAME" --title "$title" --yesno "$question" 20 50 2>&1 1>&3
		local exitcode=$?
		exec 3>&-;
		clear

		return $exitcode
	}

	__tbsm_add_ssh_key() {
		local user=$1
		local host=$2

		local filename=$(__tbsm_get_ssh_file $newuser $host)
		local key_path="$TBSM_SSHKEY_DIR/$filename"

		local title="SSH Key password"
		local inputtext="Please enter a password for the SSH Key or leave empty"
		exec 3>&1
		password=$(dialog --clear --backtitle "$TBSM_APP_NAME" --title "$title" --passwordbox "$inputtext" 20 50 2>&1 1>&3)
		exec 3>&-;
		clear

		ssh-keygen -t rsa -b 4096 -f "$key_path" -N "$password" -C "Generated by TBSM for ${newuser} on ${host}" >/dev/null 2>&1

		# vérifie le succès
		if [ $? -ne 0 ]; then
		  echo "Échec de la génération de la clé SSH." >&2
		  exit 1
		fi
		title="SSH Key generated"
		msg="The SSH Key has been generated at $key_path\n\nPublic Key:\n$(cat ${key_path}.pub)"
		dialog --clear --backtitle "$TBSM_APP_NAME" --title "$title" --msgbox $msg 30 80
	}

	__tbsm_get_ssh_file() {
		local user=$(__tbsm_sanitize $1)
		local host=$(__tbsm_sanitize $2)

		printf '%s' "tbsm__${host}__${user}"
	}

	__tbsm_sanitize() {
	  local s="$1"
	  # Remplacements successifs
	  s="${s// /_}"   # espace -> _
	  s="${s//./_}"   # . -> _
	  s="${s//\//_}"  # / -> _
	  s="${s//\\/ _}" # \ -> _  (attention à l'escape)
	  s="${s//:/_}"   # : -> _
	  s="${s//,/ _}"  # , -> _

	  printf '%s' "$s"
	}

	#########################
	## Begin real script
	init

	__tbsm_select_host
	select_host_exitcode=$?

	while [ $select_host_exitcode -ne 1 ]; do
		while [ $select_host_exitcode -eq 3 ]; do
			__tbsm_add_host
			__tbsm_select_host
			select_host_exitcode=$?
		done

		if [ $select_host_exitcode -eq 0 ]; then

			__tbsm_select_user $TBSM_HOST
			select_user_exitcode=$?
			while [ $select_user_exitcode -eq 3 ]; do
				__tbsm_add_user $TBSM_HOST
				__tbsm_select_user $TBSM_HOST
				select_user_exitcode=$?
			done

			if [ $select_user_exitcode -eq 0 ]; then
				select_host_exitcode=1
				local params=()

				local ssh_key_filename="$TBSM_SSHKEY_DIR/$(__tbsm_get_ssh_file $TBSM_USER $TBSM_HOST)"
				[ -f "$ssh_key_filename" ] && params+=(-i "$ssh_key_filename")
				command ssh $params $TBSM_USER@$TBSM_HOST
			else 
				__tbsm_select_host
				select_host_exitcode=$?
			fi
			unset select_user_exitcode
		fi
	done

	cleanup
	echo "Au revoir"
	return 0
}

tbsm

