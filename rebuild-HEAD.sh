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
mvn_rebuild_latest="${command} -V -e artifact:buildinfo  -Dreference.repo=central -Dreference.compare.save -Dbuildinfo.reproducible"
# the effective rebuild commands for master HEAD, adding buildinfo plugin and install on first run to compare on second
mvn_rebuild_1="${command} -V -e install:install"
mvn_rebuild_2="${command} -V -e artifact:buildinfo  -Dreference.repo=central -Dreference.compare.save -Dbuildinfo.reproducible"

mvnBuildDocker() {
  local mvnCommand mvnImage
  mvnCommand="$1"
  # select Docker image to match required JDK version
  case ${jdk} in
    6)
      mvnImage=maven:3-jdk-${jdk}
      ;;
    7)
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
    mvnCommand="$(echo "${mvnCommand}" | sed "s_^mvn _/var/maven/.m2/mvncrlf _")"
  fi
  ${docker_command} ${mvnImage} ${mvnCommand} ${mvn_docker_params}
}

# TODO not tested
mvnBuildLocal() {
  local mvnCommand="$1"

  echo "Rebuilding using local JDK ${jdk}"
  # TODO need to define settings with ${base}/repository local repository to avoid mixing reproducible-central dependencies with day to day builds
  if [ "${newline}" == "crlf" ]
  then
    mvnCommand="$(echo "${mvnCommand}" | sed "s_^mvn _/var/maven/.m2/mvncrlf _")"
  fi
  ${mvnCommand}
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

  dos2unix ${buildinfo}* || fatal "failed to convert buildinfo newlines"
  sed -i 's/\(reference_[^=]*\)=\([^"].*\)/\1="\2"/' ${buildinfo}*.compare # waiting for MARTIFACT-19

  cp ${buildinfo}* ../.. || fatal "failed to copy buildinfo artifacts latest ${version}"
  echo
  echo -e "rebuild from \033[1m${buildspec}\033[0m"
  compare=""
  for f in ${buildinfo}*.compare
  do
    compare=$f
    echo -e "  results in \033[1m$(dirname ${buildspec})/$(basename $f .buildinfo.compare).buildinfo\033[0m"
    echo -e "compared to Central Repository \033[1m$(dirname ${buildspec})/$(basename $f)\033[0m:"
  done
  . ${buildinfo}*.compare
  if [[ ${ko} > 0 ]]
  then
    echo -e "    ok=${ok}"
    echo -e "    okFiles=\"${okFiles}\""
    echo -e "    \033[31;1mko=${ko}\033[0m"
    echo -e "    koFiles=\"${koFiles}\""
    if [ -n "${reference_java_version}" ]
    then
      echo -e "    check .buildspec \033[1mjdk=${jdk}\033[0m vs reference \033[1mjava.version=${reference_java_version}\033[0m"
    fi
    if [ -n "${reference_os_name}" ]
    then
      echo -e "    check .buildspec \033[1mnewline=${newline}\033[0m vs reference \033[1mos.name=${reference_os_name}\033[0m (newline should be crlf if os.name is Windows, lf instead)"
    fi
    echo -e "build available in \033[1m$(dirname ${buildspec})/buildcache/${artifactId}\033[0m, where you can execute \033[36mdiffoscope\033[0m"
    grep '# diffoscope ' ${buildinfo}*.compare
    echo -e "run \033[36mdiffoscope\033[0m as container with \033[1mdocker run --rm -t -w /mnt -v $(pwd):/mnt:ro registry.salsa.debian.org/reproducible-builds/diffoscope\033[0m"
#    echo -e "To see every differences between current rebuild and reference, run:"
#    echo -e "    \033[1m./build_diffoscope.sh $(dirname ${buildspec})/$(basename ${compare}) buildcache/${artifactId}\033[0m"
  else
    echo -e "    \033[32;1mok=${ok}\033[0m"
    echo -e "    okFiles=\"${okFiles}\""
  fi
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

  dos2unix ${buildinfo}* || fatal "failed to convert buildinfo newlines"
  sed -i 's/^\(reference_[^=]*\)=\([^"].*\)/\1="\2"/' ${buildinfo}*.compare # waiting for MARTIFACT-19
  cp ${buildinfo}* ../.. || fatal "failed to copy buildinfo artifacts HEAD"
  # TODO detect if buildinfo.commit has changed: if not, restore previous buildinfo since update is mostly noise

  echo -n "${currentCommit}" > ${prevCommitFile}
fi

echo

popd > /dev/null
