# slurm_ubuntu_gpu_cluster
Guide on how to set up gpu cluster on Ubuntu 22.04 using slurm (with cgroups).
### Acknowledgements
Thanks to nateGeorge for the [guide](https://github.com/nateGeorge/slurm_gpu_ubuntu?tab=readme-ov-file) he wrote. I would highly recommend checking it out first as it is very descriptive.
# Assumptions:
- masternode 111.xx.111.xx
- workernode 222.xx.222.xx
- masternode FQDN = masternode.master.local
- workernode FQDN = workernode.worker.local
# Steps:
- [Install nvidia drivers](https://github.com/lopentusska/slurm_ubuntu_gpu_cluster?tab=readme-ov-file#install-nvidia-drivers)
- [Set up passwordless ssh](https://github.com/lopentusska/slurm_ubuntu_gpu_cluster?tab=readme-ov-file#set-up-passwordless-ssh)
- [SYNC GID/UIDs](https://github.com/lopentusska/slurm_ubuntu_gpu_cluster?tab=readme-ov-file#sync-giduids)
- [Synchronize time](https://github.com/lopentusska/slurm_ubuntu_gpu_cluster?tab=readme-ov-file#synchronize-time)
- [Set up NFS](https://github.com/lopentusska/slurm_ubuntu_gpu_cluster?tab=readme-ov-file#set-up-nfs)
- [Set up MUNGE](https://github.com/lopentusska/slurm_ubuntu_gpu_cluster?tab=readme-ov-file#set-up-munge)
- [Set up DB for Slurm](https://github.com/lopentusska/slurm_ubuntu_gpu_cluster?tab=readme-ov-file#set-up-db-for-slurm)
- [Set up Slurm](https://github.com/lopentusska/slurm_ubuntu_gpu_cluster?tab=readme-ov-file#set-up-slurm)
- [Logs](https://github.com/lopentusska/slurm_ubuntu_gpu_cluster?tab=readme-ov-file#Logs)
# Install nvidia drivers
If you need to install nvidia drivers, use this [guide](https://gist.github.com/denguir/b21aa66ae7fb1089655dd9de8351a202#install-nvidia-drivers).
# Set up passwordless ssh
on master and worker nodes:
```
sudo apt install openssh-server
sudo ufw enable
sudo ufw allow ssh
```
on master node:
```
ssh-keygen
ssh-copy-id worker_node@222.xx.222.xx
```
# Sync GID/UIDs
### LDAP Account Manager
You can follow this [guide](https://computingforgeeks.com/install-and-configure-openldap-server-ubuntu/) to install and configure LDAP Account Manager.  

Additionally, after step one (Set hostname on the server) of the guide in ```/etc/hosts``` after ```<IP> <FQDN>``` add ```<name>``` of the node so it would look like ```111.xx.111.xx masternode.master.local masternode```.  

Also, on worker_node do the following:
- set FQDN for the worker_node:
```sudo hostnamectl set-hostname workernode.worker.local```
- add IP, FQDN and name of the workernode ```222.xx.222.xx workernode.worker.local workernode``` and add IP, FQDN and name of the masternode ```111.xx.111.xx masternode.master.local masternode``` in ```etc/hosts```. So in worker_node ```etc/hosts``` you would have both master and worker nodes IPs, FQDNs and names.
### Create munge and slurm users:
Master and Worker nodes:
```
sudo adduser -u 1111 munge --disabled-password --gecos ""
sudo adduser -u 1121 slurm --disabled-password --gecos ""
```
# Synchronize time
Synchronize time with NTP using this [guide](https://knowm.org/how-to-synchronize-time-across-a-linux-cluster/).  
The guide won't tell you to allow ntp ports but you should do that to make it work.
```
sudo ufw allow ntp
```
# Set up NFS
I will show my steps below but you could use this [guide](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nfs-mount-on-ubuntu-16-04) as well

Master node:
```
sudo apt-get update
sudo apt-get install nfs-kernel-server
sudo mkdir /storage -p
sudo chown master_node:master_node /storage/
sudo vim /etc/exports
/storage 222.xx.222.xx(rw,sync,no_root_squash,no_subtree_check)
sudo systemctl restart nfs-kernel-server
sudo ufw allow from 222.xx.222.xx to any port nfs
```
Worker node:
```
sudo apt-get update
sudo apt-get install nfs-common
sudo mkdir -p /storage
sudo mount 111.xx.111.xx:/storage /storage
echo 111.xx.111.xx:/storage /storage nfs auto,timeo=14,intr 0 0 | sudo tee -a /etc/fstab
sudo chown worker_node:worker_node /storage/
```
# Set up MUNGE
Master node:
```
sudo apt-get install libmunge-dev libmunge2 munge -y
sudo systemctl enable munge
sudo systemctl start munge
munge -n | unmunge | grep STATUS
sudo cp /etc/munge/munge.key /storage/
sudo chown munge /storage/munge.key
sudo chmod 400 /storage/munge.key
```
Worker node:
```
sudo apt-get install libmunge-dev libmunge2 munge
sudo cp /storage/munge.key /etc/munge/munge.key
sudo systemctl enable munge
sudo systemctl start munge
munge -n | unmunge | grep STATUS
```
# Set up DB for Slurm
### Clone this repo with config and service files:
```
cd /storage
git clone https://github.com/lopentusska/slurm_ubuntu_gpu_cluster
```
### Install prerequisites for DB:
```
sudo apt-get install python3 gcc make openssl ruby ruby-dev libpam0g-dev libmariadb-dev mariadb-server build-essential libssl-dev numactl hwloc libmunge-dev man2html lua5.3 -y
sudo gem install fpm
sudo systemctl enable mysql
sudo systemctl start mysql
```
```
sudo mysql -u root
create database slurm_acct_db;
create user 'slurm'@'localhost';
set password for 'slurm'@'localhost' = password('slurmdbpass');
grant usage on *.* to 'slurm'@'localhost';
grant all privileges on slurm_acct_db.* to 'slurm'@'localhost';
flush privileges;
exit
```
Copy db config: ```cp /storage/slurm_ubuntu_gpu_cluster/configs_services/slurmdbd.conf /storage```
# Set up Slurm:
## Download and install Slurm on master node
### Build installation file
You should check slurm [download](https://download.schedmd.com/slurm/) page and install the latest version.
```
cd /storage
wget https://download.schedmd.com/slurm/slurm-23.11.4.tar.bz2
tar xvjf slurm-23.11.4.tar.bz2
cd slurm-23.11.4/
./configure --prefix=/tmp/slurm-build --sysconfdir=/etc/slurm --enable-pam --with-pam_dir=/lib/x86_64-linux-gnu/security/ --without-shared-libslurm
make
make contrib
make install
cd ..
```
### Install Slurm
```
sudo fpm -s dir -t deb -v 1.0 -n slurm-23.11.4 --prefix=/usr -C /tmp/slurm-build/ .
sudo dpkg -i slurm-23.11.4_1.0_amd64.deb
```
Make directories:
```
sudo mkdir -p /etc/slurm /etc/slurm/prolog.d /etc/slurm/epilog.d /var/spool/slurm/ctld /var/spool/slurm/d /var/log/slurm
sudo chown slurm /var/spool/slurm/ctld /var/spool/slurm/d /var/log/slurm
```
Copy slurm services:
```
sudo cp /storage/slurm_ubuntu_gpu_cluster/configs_services/slurmdbd.service /etc/systemd/system/
sudo cp /storage/slurm_ubuntu_gpu_cluster/configs_services/slurmctld.service /etc/systemd/system/
```
Copy slurm DB config:
```
sudo cp /storage/slurmdbd.conf /etc/slurm/
sudo chmod 600 /etc/slurm/slurmdbd.conf
sudo chown slurm /etc/slurm/slurmdbd.conf
```
Open ports for slurm communcation:
```
sudo ufw allow from any to any port 6817
sudo ufw allow from any to any port 6818
```
Start slurm services:
```
sudo systemctl daemon-reload
sudo systemctl enable slurmdbd
sudo systemctl start slurmdbd
sudo systemctl enable slurmctld
sudo systemctl start slurmctld
```
If master is a compute (worker) node:
```
sudo cp /storage/slurm_ubuntu_gpu_cluster/configs_services/slurmd.service /etc/systemd/system/
sudo systemctl enable slurmd
sudo systemctl start slurmd
```
## Install Slurm on worker node:
```
cd /storage
sudo dpkg -i slurm-23.11.4_1.0_amd64.deb
sudo cp /storage/slurm_ubuntu_gpu_cluster/configs_services/slurmd.service /etc/systemd/system
```
Open ports for slurm communcation:
```
sudo ufw allow from any to any port 6817
sudo ufw allow from any to any port 6818
```
```
sudo systemctl enable slurmd
sudo systemctl start slurmd
```
### Configure Slurm
In ```/storage/slurm_ubuntu_gpu_cluster/configs_services/slurm.conf``` change:

```ControlMachine=masternode.master.local``` - use your FQDN

```ControlAddr=111.xx.111.xx``` - use IP of your masternode

Use ```sudo slurmd -C``` to print out machine specs. You should copy specs of all machines in slurm.conf file and modify it.  
example of how it should look in your config file:
```
NodeName=masternode NodeAddr=111.xx.111.xx Gres=gpu:1 CPUs=16 Boards=1 SocketsPerBoard=1 CoresPerSocket=8 ThreadsPerCore=2 RealMemory=63502
```
After you are done with ```slurm.conf``` editing:
```
sudo cp /storage/slurm_ubuntu_gpu_cluster/configs_services/slurm.conf /storage/
```

Edit ```/storage/slurm_ubuntu_gpu_cluster/configs_services/gres.conf``` file.
```
NodeName=masternode Name=gpu File=/dev/nvidia0
NodeName=workernode Name=gpu File=/dev/nvidia0
```
You can use ```nvidia-smi``` to find out the number you should use instead of ```0``` in ```nvidia0```. You will find it to the left of the GPU name.  

Copy .conf files (except slurmdbd.conf) on all machines:  
on worker_node create slurm directory: ```sudo mkdir /etc/slurm/```
```
sudo cp /storage/slurm_ubuntu_gpu_cluster/configs_services/cgroup* /etc/slurm/
sudo cp /storage/slurm_ubuntu_gpu_cluster/configs_services/slurm.conf /etc/slurm/
sudo cp /storage/slurm_ubuntu_gpu_cluster/configs_services/gres.conf /etc/slurm/
```
```
sudo mkdir -p /var/spool/slurm/d
sudo chown slurm /var/spool/slurm/d
```
### Configure cgroups
```
sudo vim /etc/default/grub
```
add:
```
GRUB_CMDLINE_LINUX_DEFAULT="cgroup_enable=memory systemd.unified_cgroup_hierarchy=0"
```
then:
```
sudo update-grub
```
### Start Slurm
Reboot machines and:  
on master_node:
```
sudo systemctl restart slurmctld
sudo systemctl restart slurmdbd
sudo systemctl restart slurmd
```
on worker_node:
```
sudo systemctl restart slurmd
```
Create cluster: ```sudo sacctmgr add cluster compute-cluster```

Finally:
```
sudo apt update
sudo apt upgrade
sudo apt autoremove
```
# Logs
### If something doesn't work, you can find logs for ```slurmctld```, ```slurmdbd``` and ```slurmd``` in ```/var/log/slurm/```.
# Script
I've also added a simple script to check if slurm works that would run ```srun hostname```, which basically will print out the node on which the job was started.
You will need to move the file in the ```/storage```.
Inside the script change:
```partition```, 
```nodelist``` (choose on which node to run),
Then you can run script with:
```sbatch script_slurm_hostname.sh```
