# clab-pdns

The clab-pdns.sh script will create DNS records for containerlab nodes. It can do this by either manually executing the script or setting up incron to watch the /etc/hosts file for updates

This assumes that the webserver and API are enabled on the PowerDNS server.

## Setup

This should be setup on the containerlab server

### Updates needed

Right now, all the variables are hardcoded into the script. You'll need to update the SERVER, DNS_SERVER, APIKEY, DOMAIN, and ADD_IPV6 variables to match your environment. The server and APIKEY should match what is in PowerDNS. Assuming you are running the PowerDNS webserver on the default port in the config (8081), that will be needed as part of the SERVER

#### Sample

```bash
SERVER='dns1.mysite.internal:8081'
DNS_SERVER='localhost'
APIKEY='changeme'
DOMAIN='lab.mysite.internal'
ADD_IPV6=false
```

### Manual Running

```bash
sudo clab-pdns.sh
```

### Automatic DNS record updates

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
