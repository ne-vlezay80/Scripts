#!/bin/bash

LIST=0

exit0 () {
	exit 0
}

play () {
        PLAY=$(cat ./radio.txt|grep -w $LIST|awk '{print $2}')
        if [[ "" != $PLAY ]]
        then
                mplayer $PLAY
        else
                exit0
        fi
}

play_ch () {
        PLAY=$(cat ./radio.txt|grep -w $LIST_CH|awk '{print $2}')
        if [[ "" != $PLAY ]]
        then
                mplayer $PLAY
        else
                exit0
        fi
}


while true
do
	LIST=$(($LIST+1))
	case $CH in
	false)
		;;
	* )
		play
		;;
	esac
	read -n 1 INPUT 
	case $INPUT in
		q|Q)
			exit0
			;;
		1)
			unset LIST
			LIST_CH=1
			CH=false
			play_ch
			;;
                2)
                        unset LIST
                        LIST_CH=2
			CH=false
                        play_ch
                        ;;
                3)
                        unset LIST
                        LIST_CH=3
                        CH=false
                        play_ch
                        ;;
                4)
                        unset LIST
                        LIST_CH=4
                        CH=false
                        play_ch
                        ;;
		0)
			unset CH
			;;

		* )
			;;
	esac
	#mplayer $PLAY
	if [[ "" != $PLAY ]]
	then
		true
	else
		exit0
	fi

done
