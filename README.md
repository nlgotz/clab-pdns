# clab-pdns

The clab-pdns.sh script will create DNS records for containerlab nodes. It can do this by either manually executing the script or setting up incron to watch the /etc/hosts file for updates

This assumes that the webserver and API are enabled on the PowerDNS server. The other option is to run [PowerDNS-Admin](https://github.com/ngoduykhanh/PowerDNS-Admin) and use that API. The API works the same between the 2 for this use case.

## Setup

This should be setup on the containerlab server

### Config File

Copy the config.cfg.defaults file to config.cfg and update with your information.

#### Sample

```bash
SERVER=dns1.mysite.internal:8081
DNS_SERVER=localhost
APIKEY=changeme
DOMAIN=lab.mysite.internal
ADD_IPV6=false
```

### Manual Running

```bash
sudo clab-pdns.sh
```

### Automatic DNS record updates - wrapper script

It should be possible to create a wrapper script for containerlab that also runs this script to create DNS records.

### Automatic DNS record updates - watching /etc/hosts

This version requires that incron is installed on the containerlab server.

To install on Debian based systems use:

```bash
sudo apt install incron
```

Then you need to allow users to run incron

```bash
echo 'root' | sudo tee -a /etc/incron.allow
```

Then you need to setup the incron to watch the /etc/hosts file

```bash
sudo incrontab -e
```

Add the following to the file and save. Make sure to put in the full path to the file

```bash
/etc/hosts      IN_MODIFY       <path>/clab-pdns.sh
```
