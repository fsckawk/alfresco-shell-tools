#!/bin/bash
# set -x

#
# Mon Mar 31 13:12:21 CEST 2025
# Changed to use the new API version which supports "skipCount"
# Necessary when there is more than 5000 users
# param section

#

# source function library

ALFTOOLS_BIN=`dirname "$0"`
. $ALFTOOLS_BIN/alfToolsLib.sh

function __show_command_options() {
  echo "  command options:"
  echo "    -j    optional, switch to enable raw json output"
  echo "    -p    optional, dump also firstName/firstName"
  echo
}



# intended to be replaced in command script
function __show_command_explanation() {
  echo "  command explanation:"
  echo "    the alfListUsers.sh command lists all user names of alfresco one in a row"
  echo
}

# command local options
ALF_CMD_OPTIONS="${ALF_GLOBAL_OPTIONS}jp"
ALF_JSON_OUTPUT=false
ALF_PW_OUTPUT=false

function __process_cmd_option() {
  local OPTNAME=$1
  local OPTARG=$2

  case $OPTNAME
  in
    j)
      ALF_JSON_OUTPUT=true;;
    p)
      ALF_PW_OUTPUT=true;;
  esac
}


__process_options $@

# shift away parsed args
shift $((OPTIND-1))

if $ALF_VERBOSE
then
  ALF_CURL_OPTS="$ALF_CURL_OPTS -v"
  echo "connection params:"
  echo "  user: $ALF_UID"
  echo "  endpoint: $ALF_EP"
  echo "  curl opts: $ALF_CURL_OPTS"
fi



# API=service/api/people
#  	$ALF_JSHON -Q -e people -a -e userName -u \
#	-p -e firstName -u -p -e lastName

API=api/-default-/public/alfresco/versions/1/people

NOTDONE=:

(
MAXITEMS=1000
SKIP=0
while $NOTDONE
do
	OUTPUT=`curl $ALF_CURL_OPTS -u $ALF_UID:$ALF_PW \
	"$ALF_EP/${API}?maxItems=${MAXITEMS}&skipCount=${SKIP}"`

	MORE=`echo ${OUTPUT} |\
		jshon -Q -e list -e pagination -e hasMoreItems`
	

	echo "${OUTPUT}" |\
	(
	if $ALF_JSON_OUTPUT
	then
		cat
	else
	  if $ALF_PW_OUTPUT
	  then
		$ALF_JSHON \
		-Q -e list -e entries \
		-a -e entry \
		-e id -u -p -e firstName -u -p -e lastName -u
	  else
		$ALF_JSHON \
		-Q -e list -e entries \
		-a -e entry \
		-e id -u 
	  fi
	fi
	)
	SKIP=`expr $SKIP + $MAXITEMS`

	if [ "_$MORE" = "_false" ]
	then
		NOTDONE=false
	fi
done
) | sort | (

if $ALF_PW_OUTPUT
then
	while read uname
	do
		read first
		read last
		echo "$uname:$first:$last" | tr -d \"
	done
else
	cat
fi

)

