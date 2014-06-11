#!/bin/bash
source ~/virsh-devel/functions.sh
SM="/root/subscription_manager.sed"
if [ "${0}" != "vmManager.sh" ];then
  subcommand=$(basename ${0})
elif [ -n ${1} ];then
  subcommand=${1}
  shift
fi

case "${subcommand}" in

  vmbuild)
    vmname=${1} && numberOfDisks=${2} && sizeOfDisk=${3}
    if vMExist ${vmname};then
      echo "vm ${vmname} already exists, destroy it first"
      exit
    fi
    if ! primaryNetworkExist;then
      definePrimaryNetwork
    elif ! primaryNetworkRunning || ! primaryNetworkInUse;then
      undefinePrimaryNetwork
      definePrimaryNetwork
    fi
    if ! kickstartFileExist ${vmname};then
      generateKickstartFile ${vmname} ${SM}
    fi
    defineVM ${vmname} ${numberOfDisks} ${sizeOfDisk}
    hostRegisterVM ${vmname}
  ;;

  vmdestroy)
    vmname=${1}
    if ! vMExist ${vmname};then
      exit
    fi
    if vMRunning ${vmname};then
      stopVM ${vmname}
    fi
    undefineVM ${vmname}
    hostUnRegisterVM ${vmname}
  ;;

  vmlist)
    scanForVMs
  ;;

  vmrlist)
    scanForRunningVMs
  ;;

  vmstart)
    vmname=${1}
    if ! primaryNetworkExist;then
      definePrimaryNetwork
    elif ! primaryNetworkRunning || ! primaryNetworkInUse;then
      undefinePrimaryNetwork
      definePrimaryNetwork
    fi
    startVM ${vmname}
  ;;

  vmstop)
    vmname=${1}
    stopVM ${vmname}
  ;;

  vmnetstop)
    undefinePrimaryNetwork
  ;;

  vmnetstart)
    definePrimaryNetwork
  ;;

  *)
    echo "Error: ${subcommand} is not a command"
    usage
    exit -1
  ;;
esac
