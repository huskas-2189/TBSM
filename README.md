# TBSM

A lightweight script to manage SSH targets. It stores server hostnames and associated user accounts, and streamlines the connection process. Select a server, choose a user, and the script launches a standard ssh session using the chosen credentials.

## Features
- Manage SSH hosts
- Manage users for each hosts
- Create SSH key when adding users

## Requirements
- **jq**: manage json configuration
- **dialog**: display

To install these packages:

```bash
sudo apt update && sudo apt install jq dialog
```

## Installation

1. `curl -o ~/.tbsm/tbsm.sh https://github.com/huskas-2189/TBSM/tbsm.sh`
2. `chmod +x ~/.tbsm/tbsm.sh`
3. `ln -s ~/tbsm/tbsm.sh ~/.local/bin/tbsm`

if *~/.local/bin* doesn't exist : `mkdir ~/.local/bin`


Then, you can use it with `tbsm`

## Configuration

You can configure the script with thoses variables : 

| Variables | Description | Default Value |
| --- | --- | --- |
| TBSM_CUSTOM_DIR | Specify the config directory | ~/.tbsm |
| TBSM_CUSTOM_SSHKEY_DIR | SSH Key Directory | ~/.ssh |

Example:
```bash
# ~/.bashrc

export TBSM_CUSTOM_DIR="/my/custom/dir"
```

## Contributions

KISS it!! *(Keep it Simple, Stupid)*

I wrote this bash script years ago in one evening, and I still use it every day. But because it just works, I haven’t touched it in years – it’s basically been left to gather dust in some hidden folder, and I almost forgot where it was. It was simple and did exactly what was asked of it, nothing more, nothing less.

Keep it alive: fork it, modify it, but preserve this spirit of simplicity.


