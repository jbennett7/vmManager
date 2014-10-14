#!/bin/bash

imageDirectory="/var/lib/libvirt/images"
kickstartDirectory="/var/www/html"

if [ ${DEBUG} ];then
  OUTPUT=/dev/tty
else
  OUTPUT=/dev/null
fi

function vMTestFunction {
  echo "This is the test function1" > ${OUTPUT}
}

function usage {
cat <<USAGE
This is the usage message

Joseph Bennett
USAGE
}

function scanForRunningVMs {
  for vm in $(virsh list | grep -vE "Name|^-|^$" | awk '{print $2}');do
    echo ${vm}
  done
}

function scanForVMs {
  for vm in $(virsh list --all | grep -vE "Name|^-|^$" | awk '{print $2}');do
    echo ${vm}
  done
}

function vMExist {
  vmname=${1}
  if virsh list --all | grep " ${vmname} " > /dev/null;then
    return 0
  else
    return 1
  fi
}

function vMRunning {
  vmname=${1}
  if virsh list | grep " ${vmname} " > /dev/null;then
    return 0
  else
    return 1
  fi
}

function startVM {
  vmname=${1}
  if [ ! $(vMExist ${vmname}) ];then
    virsh start ${vmname} > ${OUTPUT}
  fi
}

function stopVM {
  vmname=${1}
  if [ $(vMExist ${vmname}) -a $(vMRunning ${vmname}) ];then
    virsh shutdown ${vmname} > ${OUTPUT}
  fi
}

function poweroffVM {
  vmname=${1}
  if [ $(vMExist ${vmname}) -a $(vMRunning ${vmname}) ];then
    virsh destroy ${vmname} > ${OUTPUT}
  fi
}

function pxeMenu {
cat <<PXE
default one
prompt 1
timeout 1
 
LABEL one
  MENU LABEL RHEL6
    kernel vmlinuz
    append initrd=initrd.img ks=http://192.168.122.1/_VMNAME_.cfg ksdevice=eth0 noipv6
PXE
}

#TODO: Clean this up
#TODO: Define a mechanism to define the number of cpus and memory
function defineVM {
  vmname=${1} && numberOfDisks=${2} && sizeOfDisk=${3}
  bstr="virt-install --noautoconsole --name ${vmname} --memory 2048 --vcpus 2"
  bstr=${bstr}" --network network:primary"
  bstr=${bstr}" --pxe"
  for ((diskNumber=1;diskNumber<=${numberOfDisks};diskNumber++));do
    qemu-img create -f qcow2 -o size=${sizeOfDisk} \
      ${imageDirectory}/${vmname}-${diskNumber}.qcow2
    bstr=${bstr}" --disk ${imageDirectory}/${vmname}-${diskNumber}.qcow2,bus=virtio"
  done
  eval ${bstr}
  pxeMenu | sed -e 's/_VMNAME_/'${vmname}'/' \
    > /var/lib/tftpboot/pxelinux.cfg/default
}

#TODO: The vm needs to be shutdown before calling this
function undefineVM {
  vmname=${1}
  if vMExist ${vmname};then
    virsh undefine ${vmname} &> ${OUTPUT}
    rm -v -f ${imageDirectory}/${vmname}-*.qcow2 > ${OUTPUT}
  fi
}

function kshead {
cat <<KSHEAD
install
keyboard 'us'
reboot
rootpw fog87sit
timezone America/New_York
url --url="http://192.168.122.1/rhel6"
lang en_US
firewall --enabled --service=ssh
network --onboot=yes --bootproto=dhcp --device=eth0 --hostname=_VMNAME_.example.com
auth  --useshadow  --passalgo=sha512
text
selinux --permissive
skipx
ignoredisk --only-use=vda
bootloader --location=mbr
zerombr
clearpart --all
part /boot --asprimary --fstype="ext4" --size=1000
part swap --fstype="swap" --size=4096
part / --fstype="ext4" --grow --size=1
KSHEAD
}

function kspackages {
cat <<KSPACKAGES
%packages
@ Core
@ Base
@ Development tools
nfs-utils
%end
KSPACKAGES
}

function ksend {
cat <<KSEND
%pre
%end
%post
subscription-manager register --user='_USERID_' --password='_PASS_'
subscription-manager attach --pool=_POOLID_
yum-config-manager --disable "*"
yum-config-manager --enable rhel-6-server-rpms 
yum-config-manager --enable rhel-6-server-optional-rpms 
yum-config-manager --enable rhel-server-rhscl-6-rpms
yum -y update
sed -i -e '/DEVICE/aDHCP_HOSTNAME="_VMNAME_.example.com"' /etc/sysconfig/network-scripts/ifcfg-eth0
service network restart
sed -i -e '/:${OUTPUT} ACCEPT/a-A INPUT -j ACCEPT' /etc/sysconfig/iptables
%end
KSEND
}

#TODO: This needs to be able to work to individualize the subscription-manager stuff.
function generateKickstartFile {
  vmname=${1} && SM=${2}
  tmp=$(uuidgen)
  for ksPart in kshead kspackages ksend;do
    ${ksPart} | sed -e 's/_VMNAME_/'${vmname}'/g' -f ${SM} >> /tmp/${vmname}-${tmp}.cfg
  done
  cp -v -f /tmp/${vmname}-${tmp}.cfg ${kickstartDirectory}/${vmname}.cfg > ${OUTPUT}
  rm -v -f /tmp/${vmname}-${tmp}.cfg > ${OUTPUT}
}

function deleteKickstartFile {
  vmname=${1}
  rm -v -f ${kickstartDirectory}/${vmname}.cfg > ${OUTPUT}
}

function kickstartFileExist {
  vmname=${1}
  if [ -f ${kickstartDirectory}/${vmname}.cfg ];then
    return 0
  else
    return 1
  fi
}

#TODO: Define this function to add the vm to the host's /etc/hosts file
function hostRegisterVM {
  vmname=${1}
}

#TODO: Define this function to delete the vm from the host's /etc/hosts file
function hostUnRegisterVM {
  vmname=${1}
}

function networkExist {
  netname=${1}
  if virsh net-list --all | grep ${netname} > /dev/null;then
    return 0
  else
    return 1
  fi
}

function primaryNetworkExist {
  if virsh net-list --all | grep primary > /dev/null;then
    return 0
  else
    return 1
  fi
}

function primaryNetworkRunning {
  if virsh net-list | grep primary > /dev/null;then
    return 0
  else
    return 1
  fi
}

function primaryNetworkInUse {
  for vm in $(scanForRunningVMs);do
    if virsh dumpxml ${vm} | grep primary > /dev/null;then
      return 0
    fi
  done
  return 1
}

function pnetstart {
cat <<PNETSTART
<network>
  <name>primary</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
PNETSTART
}

function pnetend {
cat <<PNETEND
  <domain name='example.com'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <tftp root='/var/lib/tftpboot'/>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
      <bootp file='/var/lib/tftpboot/pxelinux.0'/>
    </dhcp>
  </ip>
</network>
PNETEND
}

function undefinePrimaryNetwork {
  if primaryNetworkRunning; then
    virsh net-destroy primary > ${OUTPUT}
  fi
  virsh net-undefine primary > ${OUTPUT}
}

#TODO: This needs to be cleaned up
#TODO: Maybe use net-create instead of net-define?
function definePrimaryNetwork {
  if primaryNetworkExist; then
    undefinePrimaryNetwork
  fi 
  pnetstart > /tmp/primary.xml
  echo "  <dns>" >> /tmp/primary.xml
  for i in $(cat /etc/resolv.conf | \
    sed -ne 's/^nameserver \(\([0-9][0-9]*\.\)\{3\}\)/\1/p');do
      echo "    <forwarder addr='${i}'/>" \
        >> /tmp/primary.xml
  done
  echo "    <txt name='example' value='example value'/>" \
    >> /tmp/primary.xml
  echo "    <host ip='192.168.122.1' netmask='255.255.255.0'>" \
    >> /tmp/primary.xml
  echo "      <hostname>host</hostname>" \
    >> /tmp/primary.xml
  echo "      <hostname>host.example.com</hostname>" \
    >> /tmp/primary.xml
  echo "    </host>"  \
    >> /tmp/primary.xml
  echo "  </dns>" \
    >> /tmp/primary.xml
  pnetend >> /tmp/primary.xml
  virsh net-define /tmp/primary.xml > ${OUTPUT}
  virsh net-start primary > ${OUTPUT}
  rm -f /tmp/primary.xml
}

function snet {
thirdOctet=${1}
cat <<SNET
<network>
  <name>secondary</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr1' stp='on' delay='0'/>
  <ip address='192.168.${thirdOctet}.1' netmask='255.255.255.0'/>
</network>
SNET
}

function defineSecondaryNetwork {
  thirdOctet=${1}
  snet ${thirdOctet} > /tmp/secondary.xml
  virsh net-define /tmp/secondary.xml
  virsh net-start secondary
  rm -f /tmp/secondary.xml
}
