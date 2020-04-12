#!/usr/bin/env bash

fatal()
{
  echo "fatal: $1" 1>&2
  exit 1
}

usage()
{
  echo "usage: $0 [-r] <file.buildspec>
  -r: rebuild also latest release" 1>&2
  exit 1
}

rebuildLatest='false'
while getopts ":r" option; do
  case "${option}" in
    r)
      rebuildLatest='true'
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

buildspec=$1
[ -z "${buildspec}" ] && usage

echo "Rebuilding from spec ${buildspec}"

. ${buildspec} || fatal "could not source ${buildspec}"

echo "- ${groupId}:${artifactId}"
echo "- gitRepo: ${gitRepo}"
echo "- jdk: ${jdk}"
echo "- command: ${command}"
echo "- buildinfo: ${buildinfo}"

base="$PWD"

pushd `dirname ${buildspec}` >/dev/null || fatal "could not move into ${buildspec}"

# prepare source, using provided Git repository
[ -d buildcache ] || mkdir buildcache
cd buildcache
[ -d ${artifactId} ] || git clone ${gitRepo} ${artifactId} || fatal "failed to clone ${artifactId}"
cd ${artifactId}
git checkout master || fatal "failed to git checkout master"
git pull || fatal "failed to git pull"

pwd

# the effective rebuild command for latest, adding buildinfo plugin to compare with central content
mvn_rebuild_latest="${command} -V -e buildinfo:buildinfo -Dreference.repo=central -Dreference.compare.save"
# the effective rebuild commands for master HEAD, adding buildinfo plugin and install on first run to compare on second
mvn_rebuild_1="${command} -V -e install:install buildinfo:buildinfo"
mvn_rebuild_2="${command} -V -e buildinfo:buildinfo -Dreference.repo=file:./stage -Dreference.compare.save"

mvnBuildDocker() {
  local mvnCommand mvnImage
  mvnCommand="$1"
  # select Docker image to match required JDK version
  case ${jdk} in
    6 | 7)
      mvnImage=maven:3.6.1-jdk-${jdk}-alpine
      ;;
    9)
      mvnImage=maven:3-jdk-${jdk}-slim
      ;;
    *)
      mvnImage=maven:3.6.3-jdk-${jdk}-slim
  esac

  echo "Rebuilding using Docker image ${mvnImage}"
  local docker_command="docker run -it --rm --name rebuild-maven -v $PWD:/var/maven/app -v $base:/var/maven/.m2 -u $(id -u ${USER}):$(id -g ${USER}) -e MAVEN_CONFIG=/var/maven/.m2 -w /var/maven/app"
  local mvn_docker_params="-Duser.home=/var/maven"
  if [ "${newline}" == "crlf" ]
  then
    ${docker_command} ${mvnImage} ${mvnCommand} ${mvn_docker_params} -Dline.separator=$'\r\n'
  else
    ${docker_command} ${mvnImage} ${mvnCommand} ${mvn_docker_params}
  fi
}

# TODO not tested
mvnBuildLocal() {
  local mvnCommand="$1"

  echo "Rebuilding using local JDK ${jdk}"
  # TODO need to define settings with ${base}/repository local repository to avoid mixing reproducible-central dependencies with day to day builds
  if [ "${newline}" == "crlf" ]
  then
    ${mvnCommand} -Dline.separator=$'\r\n'
  else
    ${mvnCommand}
  fi
}

# by default, build with Docker
# TODO: on parameter, use instead mvnBuildLocal after selecting JDK
#   jenv shell ${jdk}
#   sdk use java ${jdk}

if ${rebuildLatest}
then
  echo "******************************************************"
  echo "* rebuilding latest release and comparing to central *"
  echo "******************************************************"
  # git checkout latest tag then rebuild latest release
  if [ -z "${latest}" ]
  then
    # auto-detect last Git tag
    gitTag="`git describe --abbrev=0`"
    version="${gitTag}"
  else
    version="${latest}"
  fi
  git checkout ${gitTag} || fatal "failed to git checkout latest ${version}"
  mvnBuildDocker "${mvn_rebuild_latest}" || fatal "failed to build latest"

  cp ${buildinfo}* ../.. || fatal "failed to copy buildinfo artifacts latest ${version}"
fi

git checkout master || fatal "failed to git checkout master"
currentCommit="`git rev-parse HEAD`"
prevCommitFile="../`basename $(pwd)`.HEAD"
if [ "${currentCommit}" == "`cat ${prevCommitFile}`" ]
then
  echo "*******************************************"
  echo "* no new commit on HEAD, skipping rebuild *"
  echo "*******************************************"
else
  echo "*******************************************************"
  echo "* rebuilding master HEAD SNAPSHOT twice and comparing *"
  echo "*******************************************************"
  # git checkout master then rebuild HEAD SNAPSHOT twice
  mvnBuildDocker "${mvn_rebuild_1}" || fatal "failed to build first time"
  mvnBuildDocker "${mvn_rebuild_2}" || fatal "failed to build second time"

  cp ${buildinfo}* ../.. || fatal "failed to copy buildinfo artifacts HEAD"
  # TODO detect if buildinfo.commit has changed: if not, restore previous buildinfo since update is mostly noise

  echo -n "${currentCommit}" > ${prevCommitFile}
fi

echo

popd > /dev/null
