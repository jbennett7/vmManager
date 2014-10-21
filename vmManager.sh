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

  #TODO: The disk size ${3} parameter needs to have a suffix (G,M...).
  #      Need to check for this.
  vmbuild)
    vm_name=${1} && number_of_disks=${2} && size_of_disk=${3}
    if [ "$#" -ne 3 ]; then
      echo "Usage: vmbuild vm_name number_of_disks size_of_disk"
      exit
    elif vm_exist ${vm_name};then
      echo "vm ${vm_name} already exists, destroy it first"
      exit
    fi
    if ! primary_network_exist;then
      define_primary_network
    elif ! primary_network_running || ! primary_network_in_use;then
      undefine_primary_network
      define_primary_network
    fi
    if ! kickstart_file_exist ${vm_name};then
      generate_kickstart_file ${vm_name} ${SM}
    fi
    define_vm ${vm_name} ${number_of_disks} ${size_of_disk}
    host_register_vm ${vm_name}
  ;;

  vmdestroy)
    vm_name=${1}
    if [ "$#" -ne 1 ];then
      echo "Usage vmdestroy vm_name"
    elif ! vm_exist ${vm_name};then
      exit
    fi
    if vm_running ${vm_name};then
      stop_vm ${vm_name}
    fi
    undefine_vm ${vm_name}
    host_unregister_vm ${vm_name}
  ;;

  vmlist)
    scan_for_vms
  ;;

  vmrlist)
    scan_for_running_vms
  ;;

  vmstart)
    vm_name=${1}
    if ! primary_network_exist;then
      define_primary_network
    elif ! primary_network_running || ! primary_network_in_use;then
      undefine_primary_network
      define_primary_network
    fi
    start_vm ${vm_name}
  ;;

  vmstop)
    vm_name=${1}
    stop_vm ${vm_name}
  ;;

  vmnetstop)
    undefine_primary_network
  ;;

  vmnetstart)
    define_primary_network
  ;;

  *)
    echo "Error: ${subcommand} is not a command"
    usage
    exit -1
  ;;
esac
