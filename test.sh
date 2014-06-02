#!/bin/bash
DEBUG=1
source /root/virsh-devel/functions.sh
SM="/root/subscription_manager.sed"

function generateKickstartFileTest1 {
  generateKickstartFile test1 ${SM}
  less /var/www/html/test1.cfg
  cp /var/www/html/test1.cfg /tmp
  generateKickstartFile test1 ${SM}
  generateKickstartFile test1 ${SM}

  diff /tmp/test1.cfg /var/www/html/test1.cfg
  [ "$?" == "0" ] && echo "PASSED" || echo "NOT PASSED"
  rm -f /tmp/test1.cfg
  rm -f /var/www/html/test1.cfg
}
generateKickstartFileTest1

function generateKickstartFileTest2 {
  generateKickstartFile test1 ${SM}
  deleteKickstartFile test1
  [ -f /var/www/html/test1.cfg ] && echo "NOT PASSED" || echo "PASSED"
}

function generateKickstartFileTest3 {
  generateKickstartFile test1 ${SM}
  deleteKickstartFile test1
  generateKickstartFile test1 ${SM}
  echo "HELLO" >> /var/www/html/test1.cfg
  grep "HELLO" /var/www/html/test1.cfg
  generateKickstartFile test1 ${SM}
  grep "HELLO" /var/www/html/test1.cfg
  deleteKickstartFile test1
}

function generateKickstartFileTest4 {
  if ! kickstartFileExist test1;then
    echo "Kickstart does not exist generating it"
    generateKickstartFile test1 ${SM}
  fi
  if kickstartFileExist test1;then
    echo "Kickstart exists deleting it"
    deleteKickstartFile test1
  fi
}

function definePrimaryNetworkTest1 {
  primaryNetworkExist || definePrimaryNetwork
  primaryNetworkExist && undefinePrimaryNetwork

  ! primaryNetworkExist && definePrimaryNetwork
  ! primaryNetworkExist || undefinePrimaryNetwork
}

function definePrimaryNetworkTest2 {
  primaryNetworkRunning || definePrimaryNetwork
  primaryNetworkRunning && undefinePrimaryNetwork

  ! primaryNetworkRunning && definePrimaryNetwork
  ! primaryNetworkRunning || undefinePrimaryNetwork
}

function buildVMTest1 {
  definePrimaryNetwork
  generateKickstartFile test1 ${SM}
  defineVM test1 1 20G
  virt-viewer test1 &
  sleep 40
  kill -SIGHUP "$!"
  poweroffVM test1
  undefineVM test1
  undefinePrimaryNetwork
  deleteKickstartFile test1
}

function VMTestProcedure1 {
  if primaryNetworkInUse;then
    echo "RESULT:  primaryNetworkInUse"
  elif primaryNetworkRunning;then
    echo "RESULT:  PrimaryNetworkRunning"
  elif primaryNetworkExist;then
    echo "RESULT:  PrimaryNetworkExist"
  else
    echo "RESULT:  PrimaryNetwork DNE"
  fi
}

function VMTestProcedure2 {
  if ! primaryNetworkExist;then
    echo "RESULT:  NOT primaryNetworkExist"
  elif ! primaryNetworkRunning;then
    echo "RESULT:  NOT PrimaryNetworkRunning"
  elif ! primaryNetworkInUse;then
    echo "RESULT:  NOT PrimaryNetworkInUse"
  else
    echo "RESULT:  PrimaryNetwork is in use"
  fi
}

function VMTestProcedure3 {
  if ! primaryNetworkExist || ! primaryNetworkRunning;then
    echo "RESULT:  NOT Exist or NOT Running"
  elif ! primaryNetworkInUse;then
    echo "RESULT:  NOT InUse"
  else
    echo "RESULT:  Primary in use"
  fi
}

function VMTest1ExistsPrimaryInUse {
  primaryNetworkExist || definePrimaryNetwork
  generateKickstartFile test1 ${SM}
  defineVM test1 1 20G
  sleep 5
  echo "TEST:  Test1ExistsPrimaryInUse"
  echo
  echo
  VMTestProcedure1
  VMTestProcedure2
  VMTestProcedure3
  poweroffVM test1; undefineVM test1
}

function VMTest1DNEPrimaryRunning {
  primaryNetworkExist || definePrimaryNetwork
  sleep 5
  echo "TEST:  Test1DNEPrimaryRunning"
  echo
  echo
  VMTestProcedure1
  VMTestProcedure2
  VMTestProcedure3
}

function VMTest1DNEPrimaryExitsNotRunning {
  primaryNetworkExist || definePrimaryNetwork
  virsh net-destroy primary
  sleep 5
  echo "TEST:  Test1DNEPrimaryExistsNotRunning"
  echo
  echo
  VMTestProcedure1
  VMTestProcedure2
  VMTestProcedure3
}

function VMTest1DNEPrimaryDNE {
  primaryNetworkExist && undefinePrimaryNetwork
  sleep 5
  echo "TEST:  Test1DNEPrimaryDNE"
  echo
  echo
  VMTestProcedure1
  VMTestProcedure2
  VMTestProcedure3
}

function defineVMTest1 {
  if primaryNetworkExist;then
    undefinePrimaryNetwork
  fi
  definePrimaryNetwork
  generateKickstartFile test1 ${SM}
  defineVM test1 1 20G
  sleep 5
  while vMRunning test1;do
    sleep 5
  done
  startVM test1
  sleep 20
  generateKickstartFile test2 ${SM}
  defineVM test2 1 20G
  sleep 5
  while vMRunning test2;do
    sleep 5
    clear
    cat /var/lib/libvirt/dnsmasq/primary.leases
  done
  startVM test2
  sleep 2
  scanForRunningVMs
  cat /var/lib/libvirt/dnsmasq/primary.leases
  deleteKickstartFile test1
  deleteKickstartFile test2
}
