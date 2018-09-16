#!/bin/bash

PARAM=$(echo $*)
CONFIG_DIR="/home/vpsop/vm"
USR=vpsop

HOST_RAM=$(free -m|grep "Mem:"|awk '{print $2}')
HOST_SWP=$(free -m|grep "Mem:"|awk '{print $2}')

ACTION=$(echo $PARAM|awk '{print $1}')
VM=$(echo $PARAM|awk '{print $2}')

MEM=$(echo $PARAM|awk '{print $3}')
DISK=$(echo $PARAM|awk '{print $4}')
MAC=$(echo $PARAM|awk '{print $5}')
VNC_PORT=$(echo $PARAM|awk '{print $6}')
SWITCH=$(echo $PARAM|awk '{print $7}')

UUID=$(/scripts/uuidgen)


HOST_TOTAL_MEM=$(echo ${HOST_RAM}+${HOST_SWP}|bc)

vm_test ()
{
	if [ "$VM" == "" ]
	then
		VM_PID=""
	else
		VM_PID=$(ps ax 2>/dev/null|grep -w qemu|grep -w $VM|grep -v grep|awk '{print $1}')
		VM_UUID=$(ps ax 2>/dev/null|grep -w qemu|grep -w $VM|awk '{print $8}')
	fi
}

MON_PATH=/var/run


LIST_COLUMN="VM:        STATUS:        PID:        UUID:\n"
START_VM_OK="Starting VM is OK\n"
START_VM_FAILED="Starting VM is FAILED\n"
STOP_VM_OK="Stop VM is OK\n"
STOP_VM_FAILED="Stop VM is FAILED\n"
VM_IS_RUN="VM is RUNNING\n"
VM_CONFIG_NOT_FOUND="ERROR: Config not found\n"
VM_CONFIG_NOT_FOUND_SWITCH="ERROR: Switch сonfig not found\n"
NAME_NO_SET="ERROR: name is not set.\n"
SEND_REQUEST_OK="Send request is OK\n"
SEND_REQUEST_FAILED="Send request is FAILED\n"
ENTER_VM_NAME="ERROR: enter VM name\n"

TEST_HYP_MSG="Testing the hypervisor...\n"
TEST_HYP_MSG_TUN="TUN/TAP..."
TEST_HYP_MSG_KVM="KVM..."
TEST_HYP_MSG_VHOST_NET="Vhost-net..."
TEST_HYP_MSG_VHOST_SOCK="Vhost-socket..."
TEST_IS_OK="OK\n"
TEST_IS_FAILED="FAILED\n"
TEST_IS_SCORE="The hypervisor score:"

CREATE_VM_MSG="Creating..."
CREATE_VM_OK="[OK]\n"
CREATE_VM_FAILED="[FAILED]\n"
VM_EXIST="ERROR: VM is exist."

ERROR_NOT_SET_MEM="ERROR: memory is not set.\n"
ERROR_NOT_SET_VNC="ERROR: vnc port is not set.\n"
ERROR_NOT_SET_DSK="ERROR: disk is not set.\n"
ERROR_NOT_SET_MAC="ERROR: mac address is not set.\n"
ERROR_NOT_SET_SWITCH="ERROR: switch is not set.\n"
ERROR_NOT_SWITCH_FOUND="ERROR: switch is not found.\n"
ERROR_NOT_MEMORY_AVAIBLE="ERROR: Not memory avaible.\n"





# Config example

config_example () {
-name test \
-drive file=test.qcow2,if=virtio \
-netdev tap,ifname=test,id=net0 \
-device virtio-net-pci,netdev=net0,id=vionet.0 \
-vnc 127.0.0.1:1 \
-enable-kvm \
-m 128M

}


create() {
	cd ${CONFIG_DIR}

	if [ -f ${VM}.conf ]
	then
		printf "$VM_EXIST"
		exit 1
	else
		true
	fi

	if [ "$MEM" == "" ] ||  [ "$MEM" == "$(echo $MEM|sed -e 's/[0-9]//g')" ]
	then
		printf "$ERROR_NOT_SET_MEM"
		exit 1
	else
		true
	fi

        if [ "$VNC_PORT" == "" ] || [ "$VNC_PORT" == "$(echo $VNC_PORT|sed -e 's/[0-9]//g')" ] || [ "$VNC_PORT" -ge "1000" ]
        then
                printf "$ERROR_NOT_SET_VNC"
                exit 1
        else
                true
        fi

	if [ "$DISK" == "" ] || [ "$DISK" == "$(echo $DISK|sed -e 's/[0-9]//g')" ] 
	then
		printf "$ERROR_NOT_SET_DSK"
		exit 1
	else
		true
	fi
	
	if [ "$MEM" -ge "$HOST_TOTAL_MEM" ]
	then
		printf "$ERROR_NOT_MEMORY_AVAIBLE"
		exit 1
	else
		true
	fi


        if [ "$MAC" == "" ]
        then
                printf "$ERROR_NOT_SET_MAC"
                exit 1
        else
                true
        fi

        if [ "$SWITCH" == "" ]
        then
                printf "$ERROR_NOT_SET_SWITCH"
                exit 1
        else
                true
        fi

	ip link show dev $SWITCH >/dev/null 2>&1
	if [ "$?" == "0" ]
	then
		true
	else
		printf "$ERROR_NOT_SWITCH_FOUND"
		exit 1
	fi



	echo "-name ${VM}" '\' >>${VM}.conf
        echo "-drive file=${VM}.qcow2,if=virtio" '\' >>${VM}.conf
        echo "-netdev tap,ifname=${VM},id=net0" '\' >>${VM}.conf
        echo "-device virtio-net-pci,netdev=net0,id=vionet.0,mac=${MAC}" '\' >>${VM}.conf
        echo "-vnc 127.0.0.1:${VNC_PORT}" '\' >>${VM}.conf
        echo "-enable-kvm" '\' >>${VM}.conf
        echo "-m ${MEM}M" >>${VM}.conf

	qemu-img create -f qcow2 ${VM}.qcow2 ${DISK}M

	echo "$VM $SWITCH" >>${VM}.switch

	chown ${USR}:${USR} ${VM}.conf
        chown ${USR}:${USR} ${VM}.qcow2
        chown ${USR}:${USR} ${VM}.switch


}

remove () {
        cd ${CONFIG_DIR}

	local CCODE=$(cat /dev/urandom|tr -dc '0-9'|head -c 8)

	vm_test
	if [ "$VM_PID" == "" ]
	then
		true
	else
		printf "$VM_IS_RUN"
		exit 1
	fi

        if [ -f ${VM}.conf ]
        then
              	true
        else
                printf "$VM_EXIST"
                exit 1
        fi

	echo "Please confirn operatiom."
	echo "Please enter [ $CCODE ] to confirm."

	read CONF

	if [ "$CONF" == "$CCODE" ]
	then
		echo "Removing..."
		rm "${VM}.conf"
                rm "${VM}.qcow2"
                rm "${VM}.switch"
	else
		echo "Confirm code failed. Exiting..."
		exit 1
	fi

}

list () {

	local COLLUMN="$(printf "$LIST_COLUMN"|wc -c)"
	local CONT=0
	printf "$LIST_COLUMN"

	for a in $(seq $CONT $COLLUMN)
	do
		echo -ne "="
		CONT=$(echo ${CONT}+1|bc)
	done
	echo -ne "\n"
	cd $CONFIG_DIR
	for a in $(ls $CONFIG_DIR)
	do
		if [ "$a" ==  "$(echo $a|grep conf)" ]
		then
			name=$(cat $a|grep -w "name"|awk '{print $2}')
			VM=$name
			vm_test
			status=$(
			if [ "$VM_PID" == "" ]
			then
				echo "STOPPED"
			else
				echo "RUNNING"
			fi
			)
			echo "$name	$status	$VM_PID $VM_UUID"		
		else
			true
		fi
	done		
}

start () {
		cd $CONFIG_DIR
		VM_CFG=$(cat ${VM}.conf 2>/dev/null)
		sw=$(cat ${VM}.switch 2>/dev/null|xxd -ps -c 1)

		if [ -f ${VM}.conf ]
		then
			true
		else
			echo "$VM_CONFIG_NOT_FOUND"
			exit 1
		fi

                if [ -f ${VM}.switch ]
                then
                        true
                else
                        printf "$VM_CONFIG_NOT_FOUND_SWITCH"
                        exit 1
                fi



		vm_test
		if [ "$VM_PID" == "" ]
		then
			true
		else
			printf "$VM_IS_RUN"
			exit 1
		fi
		count=0

		for a in $(echo $VM_CFG|tr ' ' '~'|tr '\' ' ')
		do
			NAME=$(echo $a|tr '~' ' '|grep -w "name"|awk '{print $2}')
			if [ "$NAME" == "" ]
			then
				printf "$NAME_NO_SET"
				exit 1
			else
				break
			fi
		done

		export switch=$sw
                if  qemu-system-x86_64 -monitor unix:${MON_PATH}/${VM}.ctl,server,nowait  \
		-uuid $UUID -daemonize -runas $USR \
		$(echo $VM_CFG|tr '\' ' '|sed "s/MAC_RND/$MAC_RANDOM/")
		then
			printf "$START_VM_OK"
			exit 0
		else
			printf "$START_VM_FAILED"
			exit 1
		fi

}

stop () {
		vm_test
                if [ "$VM_PID" != "" ]
                then
                        true
                else
                        echo "ERROR: vm not is running."
                        exit 1
                fi

		if kill $VM_PID 2>/dev/null
		then
			printf "$STOP_VM_OK"
			exit 0
		else
                        printf "$STOP_VM_FAILED"
			exit 1
		fi
}

pause () {
	printf "stop\n"|socat - UNIX-CONNECT:${MON_PATH}/${VM}.ctl >/dev/null 2>/dev/null
	if [ "$?" == "0" ]
	then
		printf "$SEND_REQUEST_OK"
		exit 0
	else
		printf "$SEND_REQUEST_FAILED"
		exit 1
	fi
}

cont () {
        printf "cont\n"|socat - UNIX-CONNECT:${MON_PATH}/${VM}.ctl >/dev/null 2>/dev/null
        if [ "$?" == "0" ]
        then
                printf "$SEND_REQUEST_OK"
                exit 0
        else
                printf "$SEND_REQUEST_FAILED"
                exit 1
        fi
}

test () {
	local SCORE_C=4
	local SCORE=0
	printf "$TEST_HYP_MSG"
	printf "$TEST_HYP_MSG_TUN"
	if [ -c /dev/net/tun ]
	then
		printf "$TEST_IS_OK"
                SCORE=$(echo ${SCORE}+1|bc)

	else
		printf "$TEST_IS_FAILED"
	fi

        printf "$TEST_HYP_MSG_KVM"
        if [ -c /dev/kvm ]
        then
                printf "$TEST_IS_OK"
                SCORE=$(echo ${SCORE}+1|bc)
        else
                printf "$TEST_IS_FAILED"
        fi
        printf "$TEST_HYP_MSG_VHOST_NET"
        if [ -c /dev/vhost-net ]
        then
                printf "$TEST_IS_OK"
                SCORE=$(echo ${SCORE}+1|bc)
        else
                printf "$TEST_IS_FAILED"
        fi

        printf "$TEST_HYP_MSG_VHOST_SOCK"
        if [ -c /dev/vhost-vsock ]
        then
                printf "$TEST_IS_OK"
                SCORE=$(echo ${SCORE}+1|bc)
        else
                printf "$TEST_IS_FAILED"
        fi
	printf "$TEST_IS_SCORE ${SCORE}/${SCORE_C}\n"
	
}

help () {
		echo "The script command:"
		echo "start [vm] - start the virtual machine."
		echo "stop [vm] - stop the virtual machine."
		echo "create [vm] [ramsize] [disksize] [mac address] [vncport] [switch] - create new virtual machine"
		echo "remove [vm] - remove the virtual machine"
		echo "pause [vm] - suspend the virtual machine."
		echo "cont [vm] - continue the virtual machine."
		echo "help - the help."
		echo "list - list all virtual machines."
		exit 0
}

case $ACTION in
	start)
		if [ "$VM" == "" ]
		then
			printf "$ENTER_VM_NAME"
			exit 1
		else
			true
		fi
		start
		;;
	stop)
                if [ "$VM" == "" ]
                then
                        printf "$ENTER_VM_NAME"
                        exit 1
                else
                        true
                fi

		stop
		;;
        pause)
                if [ "$VM" == "" ]
                then
                        printf "$ENTER_VM_NAME"
                        exit 1
                else
                        true
                fi

                pause
                ;;
        cont)
                if [ "$VM" == "" ]
                then
                        printf "$ENTER_VM_NAME"
                        exit 1
                else
                        true
                fi

                cont
                ;;
	create)
               if [ "$VM" == "" ]
                then
                        printf "$ENTER_VM_NAME"
                        exit 1
		else
			true
		fi
		create
		;;
	remove)
               if [ "$VM" == "" ]
                then
                        printf "$ENTER_VM_NAME"
                        exit 1
                else
                        true
                fi
		remove
		;;
	help)
		help
		;;
	test)
		test
		;;

	list)
		list
		;;
	* )
		help
		;;
esac
