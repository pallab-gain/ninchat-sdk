#!/bin/bash

set -e -u


THIS_DIR=$(cd -P "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")" && pwd)
DEFAULT_MVN_REPO="${THIS_DIR}/../../../jitsi-maven-repository/releases"
THE_MVN_REPO=${MVN_REPO:-${1:-$DEFAULT_MVN_REPO}}
MVN_HTTP=0
DEFAULT_SDK_VERSION=$(grep sdkVersion ${THIS_DIR}/../gradle.properties | cut -d"=" -f2)
SDK_VERSION=${OVERRIDE_SDK_VERSION:-${DEFAULT_SDK_VERSION}}
RN_VERSION=$(jq -r '.version' ${THIS_DIR}/../../node_modules/react-native/package.json)
JSC_VERSION="r"$(jq -r '.dependencies."jsc-android"' ${THIS_DIR}/../../node_modules/react-native/package.json | cut -d . -f 1 | cut -c 2-)
DO_GIT_TAG=${GIT_TAG:-0}


MVN_REPO_PATH=$(realpath $THE_MVN_REPO)
THE_MVN_REPO="file:${MVN_REPO_PATH}"



export MVN_REPO=$THE_MVN_REPO

echo "Releasing SDK ${SDK_VERSION}"
echo "Using ${MVN_REPO} as the Maven repo"


# Push React Native, if necessary
if [[ ! -d ${MVN_REPO}/com/facebook/react/react-native/${RN_VERSION} ]]; then
    echo "Pushing React Native ${RN_VERSION} to the Maven repo"
    pushd ${THIS_DIR}/../../node_modules/react-native/android/com/facebook/react/react-native/${RN_VERSION}
    mvn \
        deploy:deploy-file \
        -Durl=${MVN_REPO} \
        -Dfile=react-native-${RN_VERSION}.aar \
        -Dpackaging=aar \
        -DgeneratePom=false \
        -DpomFile=react-native-${RN_VERSION}.pom
    popd
fi

# Push JSC, if necessary
if [[ ! -d ${MVN_REPO}/org/webkit/android-jsc/${JSC_VERSION} ]]; then
    echo "Pushing JSC ${JSC_VERSION} to the Maven repo"
    pushd ${THIS_DIR}/../../node_modules/jsc-android/dist/org/webkit/android-jsc/${JSC_VERSION}
    mvn \
        deploy:deploy-file \
        -Durl=${MVN_REPO} \
        -Dfile=android-jsc-${JSC_VERSION}.aar \
        -Dpackaging=aar \
        -DgeneratePom=false \
        -DpomFile=android-jsc-${JSC_VERSION}.pom
    popd
fi


# Now build and publish the SDK and its dependencies
echo "Building and publishing the SDK"
pushd ${THIS_DIR}/../
./gradlew clean 
./gradlew assembleRelease 
./gradlew publish
popd

# Done!
echo "Finished! Don't forget to push the tag and the Maven repo artifacts."
