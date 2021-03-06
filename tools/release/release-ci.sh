#!/bin/bash

set -x

apt-get update
apt-get -y install jq git file p7zip-full

function getattr() {
  curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/$2/attributes/$1
}

GITHUB_TOKEN=$(getattr "github_token" "project")
RELEASE_TAG=$(getattr "release_tag" "instance")
PRERELEASE=$(getattr "prerelease" "instance")
DOCKER_HUB_KEY=$(getattr "docker_hub_key" "project")
SIGN_KEY_PATH=$(getattr "sign_key_path" "project")
SIGN_KEY_PASS=$(getattr "sign_key_pass" "project")
VUSER=$(getattr "b_user" "project")

mkdir -p /v2ray/build

gsutil cp ${SIGN_KEY_PATH} /v2ray/build/sign_key.asc
echo ${SIGN_KEY_PASS} | gpg --passphrase-fd 0 --batch --import /v2ray/build/sign_key.asc

curl -L -o /v2ray/build/releases https://api.github.com/repos/v2ray/v2ray-core/releases

GO_INSTALL=golang.tar.gz
curl -L -o ${GO_INSTALL} https://storage.googleapis.com/golang/go1.9.linux-amd64.tar.gz
tar -C /usr/local -xzf ${GO_INSTALL}
export PATH=$PATH:/usr/local/go/bin

mkdir -p /v2ray/src
export GOPATH=/v2ray

go get -u v2ray.com/core/...
go get -u v2ray.com/ext/...

pushd $GOPATH/src/v2ray.com/core/
git checkout tags/${RELEASE_TAG}
popd

go install v2ray.com/ext/tools/build/vbuild

export TRAVIS_TAG=${RELEASE_TAG}
export GPG_SIGN_PASS=${SIGN_KEY_PASS}
export V_USER=${VUSER}

$GOPATH/bin/vbuild --os=windows --arch=x86 --zip --sign --encrypt
$GOPATH/bin/vbuild --os=windows --arch=x64 --zip --sign --encrypt
$GOPATH/bin/vbuild --os=macos --arch=x64 --zip --sign --encrypt
$GOPATH/bin/vbuild --os=linux --arch=x86 --zip --sign --encrypt
$GOPATH/bin/vbuild --os=linux --arch=x64 --zip --sign --encrypt
$GOPATH/bin/vbuild --os=linux --arch=arm --zip --sign --encrypt
$GOPATH/bin/vbuild --os=linux --arch=arm64 --zip --sign --encrypt
$GOPATH/bin/vbuild --os=linux --arch=mips64 --zip --sign --encrypt
$GOPATH/bin/vbuild --os=linux --arch=mips64le --zip --sign --encrypt
$GOPATH/bin/vbuild --os=linux --arch=mips --zip --sign --encrypt
$GOPATH/bin/vbuild --os=linux --arch=mipsle --zip --sign --encrypt
$GOPATH/bin/vbuild --os=freebsd --arch=x86 --zip --sign --encrypt
$GOPATH/bin/vbuild --os=freebsd --arch=amd64 --zip --sign --encrypt
$GOPATH/bin/vbuild --os=openbsd --arch=x86 --zip --sign --encrypt
$GOPATH/bin/vbuild --os=openbsd --arch=amd64 --zip --sign --encrypt

RELBODY=$(cat $GOPATH/bin/metadata.txt | jq -R -s -c .)
JSON_DATA=$(echo "{}" | jq -c ".tag_name=\"${RELEASE_TAG}\"")
JSON_DATA=$(echo ${JSON_DATA} | jq -c ".prerelease=${PRERELEASE}")
JSON_DATA=$(echo ${JSON_DATA} | jq -c ".body=${RELBODY}")
RELEASE_ID=$(curl --data "${JSON_DATA}" -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/v2ray/v2ray-core/releases | jq ".id")

function upload() {
  FILE=$1
  CTYPE=$(file -b --mime-type $FILE)
  curl -H "Authorization: token ${GITHUB_TOKEN}" -H "Content-Type: ${CTYPE}" --data-binary @$FILE "https://uploads.github.com/repos/v2ray/v2ray-core/releases/${RELEASE_ID}/assets?name=$(basename $FILE)"
}

upload $GOPATH/bin/v2ray-macos.zip
upload $GOPATH/bin/v2ray-windows-64.zip
upload $GOPATH/bin/v2ray-windows-32.zip
upload $GOPATH/bin/v2ray-linux-64.zip
upload $GOPATH/bin/v2ray-linux-32.zip
upload $GOPATH/bin/v2ray-linux-arm.zip
upload $GOPATH/bin/v2ray-linux-arm64.zip
upload $GOPATH/bin/v2ray-linux-mips64.zip
upload $GOPATH/bin/v2ray-linux-mips64le.zip
upload $GOPATH/bin/v2ray-linux-mips.zip
upload $GOPATH/bin/v2ray-linux-mipsle.zip
upload $GOPATH/bin/v2ray-freebsd-64.zip
upload $GOPATH/bin/v2ray-freebsd-32.zip
upload $GOPATH/bin/v2ray-openbsd-64.zip
upload $GOPATH/bin/v2ray-openbsd-32.zip
upload $GOPATH/bin/metadata.txt
upload $GOPATH/bin/vencrypted-macos.7z
upload $GOPATH/bin/vencrypted-windows-64.7z
upload $GOPATH/bin/vencrypted-windows-32.7z
upload $GOPATH/bin/vencrypted-linux-64.7z
upload $GOPATH/bin/vencrypted-linux-32.7z
upload $GOPATH/bin/vencrypted-linux-arm.7z
upload $GOPATH/bin/vencrypted-linux-arm64.7z
upload $GOPATH/bin/vencrypted-linux-mips64.7z
upload $GOPATH/bin/vencrypted-linux-mips64le.7z
upload $GOPATH/bin/vencrypted-linux-mips.7z
upload $GOPATH/bin/vencrypted-linux-mipsle.7z
upload $GOPATH/bin/vencrypted-freebsd-64.7z
upload $GOPATH/bin/vencrypted-freebsd-32.7z
upload $GOPATH/bin/vencrypted-openbsd-64.7z
upload $GOPATH/bin/vencrypted-openbsd-32.7z

if [[ "${PRERELEASE}" == "false" ]]; then

INSTALL_DIR=/v2ray/src/github.com/v2ray/install

git clone "https://github.com/v2ray/install.git" ${INSTALL_DIR}

#RELEASE_DIR=${INSTALL_DIR}/releases/${RELEASE_TAG}
#mkdir -p ${RELEASE_DIR}/
#cp $GOPATH/bin/metadata.txt ${RELEASE_DIR}/
#cp $GOPATH/bin/v2ray-*.zip ${RELEASE_DIR}/
#echo ${RELEASE_TAG} > ${INSTALL_DIR}/releases/latest.txt

cp $GOPATH/bin/v2ray-${RELEASE_TAG}-linux-64/v2ray ${INSTALL_DIR}/docker/official/

pushd ${INSTALL_DIR}
git config user.name "V2Ray Auto Build"
git config user.email "admin@v2ray.com"
git add -A
git commit -m "Update for ${RELEASE_TAG}"
git push "https://${GITHUB_TOKEN}@github.com/v2ray/install.git" master
popd

DOCKER_HUB_API=https://registry.hub.docker.com/u/v2ray/official/trigger/${DOCKER_HUB_KEY}/
curl -H "Content-Type: application/json" --data '{"build": true}' -X POST "${DOCKER_HUB_API}"

fi

shutdown -h +5
