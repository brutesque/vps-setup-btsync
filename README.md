# Install script for installing BTSync server
Install script for installing BTSync server on an ubuntu vps

Before using this script make sure you've setup your ufw firewall. Use https://github.com/brutesque/vps-setup-basics if neccessary.

Open up a command line on the remote host and enter the following command:
```sh
$ bash -c "$(curl -fsSL https://raw.githubusercontent.com/brutesque/btsync=server/master/install.sh)"
```

# What does it do
- Installs btsync
- Installs nginx and generates self-signed ssl/tls certificate
- Updates firewall rules
- Generate random username and password; printed at the end of the script
