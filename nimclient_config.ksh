#!/bin/ksh
#
        LINE=
        RING_SPEED=
        CABLE_TYPE=
        PIF_NAME=
        SPEED=
        DUPLEX=
        NIM_SERVICE=
        while getopts n:P:i:m:p:c:R:k:s:d:S: c
        do
                case $c in
                        n) LINE="$LINE -aname=$OPTARG";;
                        P) LINE="$LINE -aplatform=$OPTARG";;
                        i) PIF_NAME=$OPTARG
                           LINE="$LINE -apif_name=$PIF_NAME";;
                        m) LINE="$LINE -amaster=$OPTARG";;
                        p) LINE="$LINE -amaster_port=$OPTARG";;
                        R) LINE="$LINE -aregistration_port=$OPTARG";;
                        k) LINE="$LINE -anetboot_kernel=$OPTARG";;
                        c) COMMENTS="$OPTARG";;
                        s) SPEED="$OPTARG";;
                        d) DUPLEX="$OPTARG";;
                        S) NIM_SERVICE="$OPTARG";;
                esac
        done

        if [[ $PIF_NAME = tr* ]]
        then
          RING_SPEED=`mktcpip -S ${PIF_NAME} 2>&1 | awk 'BEGIN { RS="\n"; FS=":" } { for (i=1;i<=NF;i++) { if ( match ($i,/speed/) ) (j=i) }if (NR==2){print $j} }'`
          LINE="$LINE -aring_speed1=$RING_SPEED";
        else
          if [[ $PIF_NAME = e[nt]* ]]
          then
            CABLE_TYPE=`mktcpip -S ${PIF_NAME} 2>&1 | awk 'BEGIN { RS="\n"; FS=":" } { for (i=1;i<=NF;i++) { if ( match ($i,/type/) ) (j=i) } if (NR==2){print $j} }'`
            LINE="$LINE -acable_type1=$CABLE_TYPE";
          fi
        fi

        if [[ -n $SPEED || -n $DUPLEX ]]
        then
          NET_SETTINGS="$SPEED $DUPLEX";
        fi

        niminit $LINE ${COMMENTS:+-a comments="${COMMENTS}"} ${NET_SETTINGS:+-a net_settings="${NET_SETTINGS}"} ${NIM_SERVICE:+-a connect="${NIM_SERVICE}"}
        exit $?
