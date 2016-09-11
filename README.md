# Convenience script for setting up a Bittorrent Sync server
Install script for installing BTSync server on an ubuntu vps

Before using this script make sure you've setup your ufw firewall. Use https://github.com/brutesque/vps-setup-basics if neccessary.

Open up a command line on the remote host and enter the following command:
```sh
$ bash -c "$(curl -fsSL raw.githubusercontent.com/brutesque/vps-setup-btsync/master/install.sh)"
```
Be sure to write down the username and password. It will not be shown again.

# What does it do
- Installs btsync
- Installs nginx and generates self-signed ssl/tls certificate
- Updates firewall rules
- Generate random username and password; printed at the end of the script
