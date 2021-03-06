#!/bin/sh

MTU=9000

N=$0
NAME=$(find $N -type l|tr '/' ' '|awk '{print $NF}')
PARAM=$(echo $*)
ANTISPOOF="/scripts/antispoof.txt"
ALLOW_IF="eth0"
EBT_ANTISPOOF_TABLE="ANTISPOOF_VPS"
APPS="qemu-ifup qemu-ifdown shaper antispoof"
eth_to_ipv6 () {
	IFS=':'; set $1; unset IFS
	printf "fe80::%x:%x:%x:%x\n" $(( 0x${1}${2} ^ 0x200 )) 0x${3}ff 0xfe${4} 0x${5}${6}
}

case $NAME in
	qemu-ifup)
		IF=$(echo $PARAM|awk '{print $1}')

		if [ "$IF" == "" ]
		then
			echo "Please enter interface name."
			exit 1
		else
			true
		fi

		;;
        qemu-ifdown)

                if [ "$IF" == "" ]
                then
                        echo "Please enter interface name."
                        exit 1
                else
                        true
                fi

                IF=$(echo $PARAM|awk '{print $1}')
                ;;
        shaper)
		ACTION=$(echo $PARAM|awk '{print $1}')
                IF=$(echo $PARAM|awk '{print $2}')
                speedUp=$(echo $PARAM|awk '{print $3}')
                speedDown=$(echo $PARAM|awk '{print $4}')
                NETEM_ACT=$(echo $PARAM|awk '{print $5}')
                NETEM_PARAM=$(echo $PARAM|awk '{print $6}')
                ;;
	antispoof)
                ACTION=$(echo $PARAM|awk '{print $1}')
		;;
esac

antispoof () {
                        for a in $(cat $ANTISPOOF|tr ' ' '~')
                        do
                                if=$(echo $a|tr '~' ' '|awk '{print $1}')
                                mac=$(echo $a|tr '~' ' '|awk '{print $2}')
                                ipv4=$(echo $a|tr '~' ' '|awk '{print $3}')
                                ipv6=$(echo $a|tr '~' ' '|awk '{print $4}')
                                ll_ipv6=$(eth_to_ipv6 $mac)
				if [ "$mac" == "none" ] || [ "$mac" == "NONE" ]
				then
					echo "Antispoofing the host disabled."
					return 0
				else
					true
				fi

                                ebtables -D $EBT_ANTISPOOF_TABLE -i $if -s $mac -p ARP --arp-ip-src $ipv4 -j RETURN
                                ebtables -D $EBT_ANTISPOOF_TABLE -i $if -s $mac -p IPv4 --ip-src $ipv4 -j RETURN

                                ebtables -D $EBT_ANTISPOOF_TABLE -i $if -s $mac -p IPv6 --ip6-src $ipv6 -j RETURN
                                ebtables -D $EBT_ANTISPOOF_TABLE -i $if -s $mac -p IPv6 --ip6-src $ll_ipv6 -j RETURN

                                ebtables -D $EBT_ANTISPOOF_TABLE -o $if -j RETURN

                                ebtables -A $EBT_ANTISPOOF_TABLE -i $if -s $mac -p ARP --arp-ip-src $ipv4 -j RETURN
                                ebtables -A $EBT_ANTISPOOF_TABLE -i $if -s $mac -p IPv4 --ip-src $ipv4 -j RETURN

                                ebtables -A $EBT_ANTISPOOF_TABLE -i $if -s $mac -p IPv6 --ip6-src $ipv6 -j RETURN
                                ebtables -A $EBT_ANTISPOOF_TABLE -i $if -s $mac -p IPv6 --ip6-src $ll_ipv6 -j RETURN

                                ebtables -A $EBT_ANTISPOOF_TABLE -o $if -j RETURN
                        done
			return 0
}

qemu_ifup () {

		ifc="$(printf $IF|wc -c)"
		if [ "$ifc" -le "7" ]
		then
			true
		else
			echo "THE interface maximam 7 chapters. Exiting..."
			exit 10
		fi

		swp=$(echo $switch|xxd -r -p|grep $IF|awk '{print $2}')

		if [ "$swp" == "" ]
		then
			echo "ERROR: switch is no set."
			exit 1
		else
			true
		fi

		case $swp in
		
			other)
				echo "Network running from other L2 forwarding agent"
				ip link set dev $IF up
				ip link set dev $IF mtu $MTU
				;;
			* )
				echo "Attaching from bridge $swp"
		       	        ip link set dev $IF up
				MTU=$(ip link show dev $swp|grep mtu|awk '{print $5}')
		                ip link set dev $IF mtu $MTU
				ip link set dev $IF master $swp
				antispoof
				;;
		esac	
}

shaper () {
		  if [ "$IF" == "" ] || [ "$speedUp" == "" ] ||  [ "$speedDown" == "" ]
		  then
			echo "ERROR: Cmdline is incomplete."
			exit 1
		  else
			true
		  fi

                  ip link del dev ${IF}-ingress
		  ip link add dev ${IF}-ingress type ifb
                  MTU=$(ip link show dev ${IF}|grep mtu|awk '{print $5}')
		   ip link set dev ${IF}-ingress up
                   ip link set dev ${IF}-ingress mtu $MTU
                  /sbin/tc qdisc del dev ${IF} ingress
                  /sbin/tc qdisc add dev ${IF} ingress
		  /sbin/tc filter add dev ${IF} parent ffff: protocol all prio 10 u32 \
  		  match u32 0 0 flowid 1:1 \
  		  action mirred egress redirect dev ${IF}-ingress
		  /sbin/tc qdisc del dev ${IF} root handle 1:
		  /sbin/tc qdisc add dev ${IF} root handle 1: htb default 10 r2q 1

		  /sbin/tc class add dev ${IF} parent 1: classid 1:10 htb rate ${speedUp}kbit quantum 8000 burst 8k


		  if [ "$NETEM_ACT" == "del" ] || \
		     [ "$NETEM_ACT" == "lo" ] || \
                     [ "$NETEM_ACT" == "cor" ] || \
                     [ "$NETEM_ACT" == "reo" ] || \
                     [ "$NETEM_ACT" == "dup" ] 

		  then
			case $NETEM_ACT in
			del)
				ne=delay
				;;
			lo)
				ne=loss
				;;
			cor)
				ne=corrupt
				;;
			reo)
				ne=reorder
				;;
                        dup)
                                ne=duplicate
                                ;;

			esac
			tc qdisc add dev ${IF} parent 1:10 handle 10 netem $ne $NETEM_PARAM
		    else
			true
		    fi	


                  /sbin/tc qdisc add dev ${IF}-ingress root handle 1: htb default 10 r2q 1
                  /sbin/tc class add dev ${IF}-ingress parent 1: classid 1:10 htb rate ${speedDown}kbit quantum 8000 burst 8k

}

shaper_remove () {
                  ip link del dev ${IF}-ingress
                  /sbin/tc qdisc del dev ${IF} ingress
                  /sbin/tc qdisc del dev ${IF} root handle 1:
}

case $NAME in
	qemu-ifup)
		qemu_ifup
		;;	
	qemu-ifdown)
		true
		;;
	shaper)
		case $ACTION in
		add)
			shaper
			;;
		remove)
			shaper_remove
			;;
		*)
			echo "/scripts/shaper add test0 512 512"
			;;
		esac
		;;
	antispoof)
		case $ACTION in
		reload)
			antispoof
			;;
		clean)
			ebtables -F $EBT_ANTISPOOF_TABLE 
			ebtables -A $EBT_ANTISPOOF_TABLE -i $ALLOW_IF -j RETURN
                        #ebtables -A $EBT_ANTISPOOF_TABLE -o $ALLOW_IF -j RETURN
			;;
		*)
			echo "/scripts/antispoof reload|clean"
			;;
		esac
		;;
	*)
			echo "Invalid application."
			echo "Application is availed: $APPS"
			;;
esac
