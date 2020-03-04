#!/bin/bash

usage() { echo "Usage: $0 [-a <string>] [-b <string>]" 1>&2; exit 1; }
while getopts ":a:b:" opt; do
	case ${opt} in
		a )
			A_VAR=$OPTARG
			;;
		b )
			B_VAR=$OPTARG
			;;
		* )
			usage
			;;
	esac
done
shift $((OPTIND -1))

if [ -z "${A_VAR}" ] || [ -z "${B_VAR}" ]; then
	usage
fi

echo "The \"a\" parameter is ${A_VAR} and the \"b\" parameter is ${B_VAR}"
