#! /bin/ksh -p
#
# Provide the date "$1" days ago
#

    t=`date +%j`
    ago=$1
    ago=${ago:=1} # in days
    y=`date +%Y`

    function build_year {
            set -A j X $( for m in 01 02 03 04 05 06 07 08 09 10 11 12
                    {
                            cal $m $y | sed -e '1,2d' -e 's/^/ /' -e "s/ \([0-9]\)/ $m\1/g"
                    } )
            yeardays=$(( ${#j[*]} - 1 ))
    }

    build_year

    until [ $ago -lt $t ]
    do
            (( y=y-1 ))
            build_year
            (( ago = ago - t ))
            t=$yeardays
    done

    print ${j[$(( t - ago ))]}....$y
