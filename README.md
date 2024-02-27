# slurm
Instructions for setting up a Slurm gpu cluster using Ubuntu 22.04.
Sync GID/UIDs
LDAP
https://computingforgeeks.com/install-and-configure-openldap-server-ubuntu/
https://computingforgeeks.com/install-and-configure-ldap-account-manager-on-ubuntu/
Sync time
NTP
https://knowm.org/how-to-synchronize-time-across-a-linux-cluster/
munge and slurm users and groups
on both machines
sudo adduser -u 1111 munge --disabled-password --gecos ""
sudo adduser -u 1121 slurm --disabled-password --gecos ""
nfs
https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nfs-mount-on-ubuntu-16-04
main machine
sudo apt-get update
sudo apt-get install nfs-kernel-server
sudo mkdir /storage -p
sudo chown lopenpc:lopenpc /storage/
sudo vim /etc/exports
/storage	192.168.1.3(rw,sync,no_root_squash,no_subtree_check)
sudo systemctl restart nfs-kernel-server
sudo ufw allow from 192.168.1.3 to any port nfs
ls -ld /storage/
worker
sudo mkdir -p /storage
sudo apt-get update
sudo apt-get install nfs-common
sudo mount 192.168.1.8:/storage /storage
echo 192.168.1.8:/storage /storage nfs auto,timeo=14,intr 0 0 | sudo tee -a /etc/fstab
sudo chown lopenlaptop:lopenlaptop /storage/
ls -ld /storage/
paswordless ssh
ssh-keygen
ssh-copy-id lopenlaptop@192.168.1.3
install munge
master
sudo apt-get install libmunge-dev libmunge2 munge -y
sudo systemctl enable munge
sudo systemctl start munge
munge -n | unmunge | grep STATUS
sudo cp /etc/munge/munge.key /storage/
sudo chown munge /storage/munge.key
sudo chmod 400 /storage/munge.key
worker
sudo apt-get install libmunge-dev libmunge2 munge
sudo cp /storage/munge.key /etc/munge/munge.key
sudo systemctl enable munge
sudo systemctl start munge
munge -n | unmunge | grep STATUS
db for slurm
copy my files
some git clone slurm_configs
sudo apt-get install python3 gcc make openssl ruby ruby-dev libpam0g-dev libmariadb-dev mariadb-server build-essential libssl-dev numactl hwloc libmunge-dev man2html lua5.3 -y
sudo gem install fpm
sudo systemctl enable mysql
sudo systemctl start mysql
sudo mysql -u root
create database slurm_acct_db;
create user 'slurm'@'localhost';
set password for 'slurm'@'localhost' = password('slurmdbpass');
grant usage on *.* to 'slurm'@'localhost';
grant all privileges on slurm_acct_db.* to 'slurm'@'localhost';
flush privileges;
exit
install slurm
build slurm
cd /storage
wget https://download.schedmd.com/slurm/slurm-23.11.4.tar.bz2
tar xvjf slurm-23.11.4.tar.bz2
cd slurm-23.11.4/
./configure --prefix=/tmp/slurm-build --sysconfdir=/etc/slurm --enable-pam --with-pam_dir=/lib/x86_64-linux-gnu/security/ --without-shared-libslurm
make
make contrib
make install
cd ..
install slurm
sudo fpm -s dir -t deb -v 1.0 -n slurm-23.11.4 --prefix=/usr -C /tmp/slurm-build/ .
sudo dpkg -i slurm-23.11.4_1.0_amd64.deb
sudo mkdir -p /etc/slurm /etc/slurm/prolog.d /etc/slurm/epilog.d /var/spool/slurm/ctld /var/spool/slurm/d /var/log/slurm
sudo chown slurm /var/spool/slurm/ctld /var/spool/slurm/d /var/log/slurm
cp from git:
! sudo cp /storage/ubuntu-slurm/slurmdbd.service /etc/systemd/system/
! sudo cp /storage/ubuntu-slurm/slurmctld.service /etc/systemd/system/
sudo cp /storage/slurmdbd.conf /etc/slurm/
sudo chmod 600 /etc/slurm/slurmdbd.conf
sudo chown slurm /etc/slurm/slurmdbd.conf
sudo systemctl daemon-reload
sudo systemctl enable slurmdbd
sudo systemctl start slurmdbd
sudo systemctl enable slurmctld
sudo systemctl start slurmctld
if main is node
sudo cp /storage/ubuntu-slurm/slurmd.service /etc/systemd/system/
sudo systemctl enable slurmd
sudo systemctl start slurmd
worker:
cd /storage
sudo dpkg -i slurm-23.11.4_1.0_amd64.deb
sudo cp /storage/slurm_configs/slurmd.service /etc/systemd/system
sudo systemctl enable slurmd
sudo systemctl start slurmd
sudo cp /storage/slurm_configs/slurm.conf /storage/
sudo slurmd -C
and change the specs
edit gres
main:
sudo cp slurm_configs/cgroup* /etc/slurm/
sudo cp slurm_configs/slurm.conf /etc/slurm/
sudo cp slurm_configs/gres.conf /etc/slurm/
worker:
sudo mkdir /etc/slurm/
sudo cp slurm_configs/cgroup* /etc/slurm/
sudo cp slurm_configs/slurm.conf /etc/slurm/
sudo cp slurm_configs/gres.conf /etc/slurm/
main:
sudo mkdir -p /var/spool/slurm/d
sudo chown slurm /var/spool/slurm/d
worker:
sudo mkdir -p /var/spool/slurm/d
sudo chown slurm /var/spool/slurm/d
main:
sudo systemctl restart slurmctld
sudo systemctl restart slurmdbd
sudo vim /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="cgroup_enable=memory systemd.unified_cgroup_hierarchy=0"
sudo update-grub
reboot
sudo systemctl restart slurmd
dont need gres file on the worker, do same with grub on worker
main:
sudo ufw allow from any to any port 6817
if drain nodes:
sudo scontrol update NodeName=lopenpc State=RESUME
sudo scontrol update NodeName=lopenlaptop State=RESUME
added gres back
added master node /etc/hosts
on worker:
sudo ufw allow from any to any port 6817
AND 6818

srun -w lopenlaptop hostname
