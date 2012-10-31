#!/bin/sh

set -e

CAT=cat
CURL="curl -s -X POST -k"
GREP=grep
SED=sed

ENDPOINT=https://ws.audioscrobbler.com/2.0/
API_KEY=cacc7818012940129d6969e158e88e98
API_SECRET=c7b73e244113d6b891bcea65bc879631
GETTOKEN_SIG=68ae4512777cc9eaf4cbc089303d7314

AQUALUNG_DIR=$HOME/.aqualung
TOKEN_FILE="$AQUALUNG_DIR"/scrobbler.token
SESSION_KEY_FILE="$AQUALUNG_DIR"/scrobbler.session_key_response
CONFIG_FILE="$AQUALUNG_DIR"/scrobbler_config.lua
LIB_FILE=scrobbler.lua

function setup_complete {
  echo "Setup complete!"
  echo "Enable aqualung-scobbler by adding the following to your aqualung lua"
  echo "extension file:"
  echo 
  echo 'dofile(os.getenv("HOME") .. "/.aqualung/scrobbler.lua")'
}

if [ ! -d "$AQUALUNG_DIR" ]; then
  echo "~/.aqualung not present, exiting"
  exit
fi

$CURL --help >/dev/null || true
if [ 0 -ne $? ]; then
  echo "curl not found, please install first, exiting"
  exit 1
fi

for MD5 in \
"md5 -qs" \
"md5 -n -d" \
"ruby -rdigest/md5 -e 'puts Digest::MD5.new.update(ARGV.first).hexdigest'" \
"perl -e 'use Digest::MD5 qw(md5_hex); print md5_hex(@ARGV[0])'" \
"python -c 'import sys, md5; m = md5.new(); m.update(sys.argv[1]); print m.hexdigest()'" \
"false"; do
  if [ X`sh -c "$MD5 foo"` = Xacbd18db4cc2f85cedef654fccc4a4d8 ]; then
   break;
  fi
done

if [ X"MD5" = Xfalse ]; then
  echo "compatible MD5 generator not found, please install md5, python, perl, or ruby, exiting"
  exit 1
fi

if [ -f "$CONFIG_FILE" ]; then
  setup_complete
  exit
fi

if [ ! -f "$SESSION_KEY_FILE" ]; then
  if [ ! -f "$TOKEN_FILE" ]; then
    $CURL -d "api_key=${API_KEY}&api_sig=${GETTOKEN_SIG}&method=auth.getToken" $ENDPOINT |
      $GREP token | $SED 's,^.*<token>,,' | $SED 's,</token>.*$,,' > "$TOKEN_FILE"
  fi
  TOKEN=`$CAT "$TOKEN_FILE"`

  echo "If you have not already authorized aqualung-scrobbler in your"
  echo "Last.FM account, please go to:"
  echo "  http://www.last.fm/api/auth/?api_key=${API_KEY}&token=${TOKEN}"
  echo "and authorize the token."
  echo

  authorized=No
  until [ X"$authorized" = X"Yes" ]; do
    echo "Have you authorized the token?"
    select authorized in Yes No; do
      break;
    done
  done

  GETSESSION_SIG=`$MD5 api_key${API_KEY}methodauth.getSessiontoken${TOKEN}${API_SECRET}`
  $CURL -d "api_key=${API_KEY}&api_sig=${GETSESSION_SIG}&token=${TOKEN}&method=auth.getSession" $ENDPOINT > "$SESSION_KEY_FILE"
fi

USERNAME=`$GREP name < $SESSION_KEY_FILE | $SED 's,^.*<name>,,' | $SED 's,</name>.*$,,'`
SESSION_KEY=`$GREP key < $SESSION_KEY_FILE | $SED 's,^.*<key>,,' | $SED 's,</key>.*$,,'`

echo "Aqualung.scrobbler = {}" > "$CONFIG_FILE"
echo "Aqualung.scrobbler.username = \"${USERNAME}\"" >> "$CONFIG_FILE"
echo "Aqualung.scrobbler.session_key = \"${SESSION_KEY}\"" >> "$CONFIG_FILE"
echo "Aqualung.scrobbler.api_key = \"${API_KEY}\"" >> "$CONFIG_FILE"
echo "Aqualung.scrobbler.api_secret = \"${API_SECRET}\"" >> "$CONFIG_FILE"
echo "Aqualung.scrobbler.md5 = \"${MD5}\"" >> "$CONFIG_FILE"
echo "Aqualung.scrobbler.curl = \"${CURL}\"" >> "$CONFIG_FILE"
echo "Aqualung.scrobbler.endpoint = \"${ENDPOINT}\"" >> "$CONFIG_FILE"

echo "aqualung-scrobbler config file created: ${CONFIG_FILE}"

cp "${LIB_FILE}" "${AQUALUNG_DIR}"/
echo "aqualung-scrobbler library file installed: ${AQUALUNG_DIR}/${LIB_FILE}"

setup_complete
rm "${TOKEN_FILE}" "${SESSION_KEY_FILE}"
