#!/bin/bash

# Fri May 12 15:03:43 CEST 2017
# spd@daphne.cps.unizar.es

# Script to set permissions for a workspace/SpacesStore node
# Status: working against alfresco-5.1.e with CSRF protection enabled (default)

# Note: By now this script won't duplicate an existing permission, but
# also won't replace or delete existing ones.
# TODO: add options to edit/delete permissions.

# Mon Mar 31 14:50:42 CEST 2025
# slingshot/doclib/permissions fails when there are more than 5k users

# Requires alfToolsLib.sh
# Requires jshon

# param section

# source function library

ALFTOOLS_BIN=`dirname "$0"`
. $ALFTOOLS_BIN/alfToolsLib.sh

# intended to be replaced in command script by a command specific output
function __show_command_options() {
  echo "  command options:"
  echo "    -s SHORT_NAME , the sites short name"
  echo "    -n path       , file/folder full name"
  echo "    -i id         , node id"
  echo
}

# intended to be replaced in command script
function __show_command_arguments() {
  echo "  command arguments:"
  echo "    user:role [user:role]..."
  echo
}

# intended to be replaced in command script
function __show_command_explanation() {
  echo "  command explanation:"
  echo "    the alfSetPermissions.sh command set permisions for a node."
  echo
  echo "  usage examples:"
  echo
  echo "  ./alfSetPermissions.sh -i \"d79695df-d5fe-4a43-853d-9d92de1290fd\" user1:SiteConsumer user2:SiteManager"
  echo "  ./alfSetPermissions.sh -s My_Site -n Foo/Bar user1:SiteConsumer user2:SiteManager"
  echo
  
}


# command local options
ALF_CMD_OPTIONS="${ALF_GLOBAL_OPTIONS}s:i:n:"
ALF_SITE_SHORT_NAME=""
ALF_FILE_NAME=""
ALF_NODE_ID=""


function __process_cmd_option() {
  local OPTNAME=$1
  local OPTARG=$2

  case $OPTNAME
  in
    s)
      ALF_SITE_SHORT_NAME=$OPTARG;;
    i)
      ALF_NODE_ID="$OPTARG";;
    n)
      ALF_FILE_NAME="$OPTARG";;
  esac
}

__process_options "$@"

# shift away parsed args
shift $((OPTIND-1))

# command arguments,

if $ALF_VERBOSE
then
  ALF_CURL_OPTS="$ALF_CURL_OPTS -v"
  cat >&2 <<-EOF
  connection params:
    user:            $ALF_UID
    endpoint:        $ALF_EP
    curl opts:       $ALF_CURL_OPTS
    site short name: $ALF_SITE_SHORT_NAME
    path name:       $ALF_FILE_NAME
EOF
fi

ALF_SERVER=`echo "$ALF_SHARE_EP" | sed -e 's,/share,,'`

if [ "_$ALF_SITE_SHORT_NAME" != "_" ]
then

	URL=$ALF_SERVER/alfresco/api/-default-/public/cmis/versions
	URL=${URL}/1.1/browser/root/Sites/${ALF_SITE_SHORT_NAME}
	URL=${URL}/documentLibrary/${ALF_FILE_NAME}?cmisSelector=object

	ALF_NODE_ID=`curl $ALF_CURL_OPTS \
	-u"$ALFTOOLS_USER:$ALFTOOLS_PASSWORD" \
	"${URL}" 2>/dev/null |\
	$ALF_JSHON -e properties -e cmis:objectId -e value -u 2>/dev/null`

	if [ "_$ALF_NODE_ID" = "_" ]
	then
		echo "#### ERROR: Non-existing path" >&2
		exit 2
	fi
	ALF_NODE_ID="${ALF_NODE_ID}"

else
	ALF_NODE_ID="workspace/SpacesStore/${ALF_NODE_ID}"
fi

if $ALF_VERBOSE
then
  echo "  node id: $ALF_NODE_ID" >&2
fi

API="api/-default-/public/alfresco/versions/1/nodes/${ALF_NODE_ID}"

CURRENTPERMS=`curl $ALF_CURL_OPTS \
-u"$ALFTOOLS_USER:$ALFTOOLS_PASSWORD" \
-H 'accept:application/json' \
-X GET \
$ALF_EP/${API}?include=permissions`

inherited=`echo "$CURRENTPERMS" |\
$ALF_JSHON -e entry \
-e permissions \
-e isInheritanceEnabled`

if [ "_$inherited" = "_true" ]
then
	#
	# disable inherited permissions
	#
	NEWPERMS=`echo "$CURRENTPERMS" |\
	$ALF_JSHON -e entry \
	-e permissions \
	-d inherited \
	-d isInheritanceEnabled \
	-n false -i isInheritanceEnabled \
	-n "[]" -i locallySet`
	echo "$NEWPERMS"
else
	NEWPERMS=`echo "$CURRENTPERMS" |\
	$ALF_JSHON -e entry \
	-e permissions`
fi

ALF_JSON="$NEWPERMS"

if $ALF_VERBOSE
then
	echo "$ALF_JSON"
fi

for arg in $@
do
	user=`echo $arg | sed -e 's/:.*//'`
	role=`echo $arg | sed -e 's/.*://'`

	if echo "$ALF_JSON" | fgrep '"authorityId": "'"${user}"'"' > /dev/null
	then
		if $ALF_VERBOSE
		then
			echo "# ${user} already present"
		fi
		:
	else
		ALF_JSON=`echo "$ALF_JSON" |\
		$ALF_JSHON \
		-e locallySet \
		-n "{}" \
		-s "$user" -i "authorityId" \
		-s "SiteConsumer" -i "name" \
		-s "ALLOWED" -i "accessStatus" -i append -p`
	fi
done

ALF_JSON='{ "permissions": '"${ALF_JSON}"'}'


curl $ALF_CURL_OPTS \
-u"$ALFTOOLS_USER:$ALFTOOLS_PASSWORD" \
-H 'Content-Type:application/json' \
-X PUT \
$ALF_EP/${API}?fields=permissions \
-d "$ALF_JSON"

# on success the server returns json describing permissions
exit $?

