#!/bin/bash

if [ $# -lt 4 ]; then
  >&2 echo Script requires 4 parameters in the following order: username, hostname, src_file, dest_file
  exit 1
fi

# Parse arguments
USER=$1
shift
HOST=$1
shift
SRC_FILE=$1
shift
DEST_FILE=$1
KERB_KEYTAB=$RD_CONFIG_KERBEROS_KEYTAB

# openshift workaround for anonymous user
export NSS_WRAPPER_PASSWD=/tmp/nss_passwd
export NSS_WRAPPER_GROUP=/tmp/nss_group
export LD_PRELOAD=libnss_wrapper.so

if [ ! -f $KERB_KEYTAB ]; then
  >&2 echo Keytab $KERB_KEYTAB not found
  exit 2
fi

# random delay (0..0.5s) to make it work with parallel exec
sleep $(bc <<< "scale=2; $(printf '0.%02d' $(( $RANDOM % 100))) / 2")

# status 1 if the credentials cache cannot be read or is expired, and with status 0 otherwise
klist -s
if [ $? -ne 0 ]; then
  kinit -kt $KERB_KEYTAB $RD_CONFIG_KERBEROS_USER

  # verify ticket has been successfuly created
  klist -s
  if [ $? -ne 0 ]; then
    >&2 echo Kinit failure when calling kinit -kt $KERB_KEYTAB $RD_CONFIG_KERBEROS_USER
    exit 2
  fi
fi

SSHOPTS=" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet"
RUNSSH="scp $SSHOPTS $SRC_FILE $USER@$HOST:$DEST_FILE"

#finally, execute scp but don't print to STDOUT
$RUNSSH 1>&2 || exit $? # exit if not successful
echo $DEST_FILE # echo remote filepath

if [[ ${RD_CONFIG_DO_KDESTROY} == 'true' ]]; then
  kdestroy
fi
