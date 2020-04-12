#!/bin/bash

cat <(echo "| groupId | artifactId (buildspec, Git)  | latest release | master HEAD SNAPSHOT |"
echo "| ------- | ------------------------------ | ----------------- | ----------------- |"

count=0
countHEADOk=0
sumHEADOk=0
sumHEADKo=0
countLatest=0
countLatestOk=0
sumLatestOk=0
sumLatestKo=0
prevDist=""
for buildspec in `find mojo -name *.buildspec -print | sort`
do
  count=$(($count+1))
  . $buildspec

  groupDir=$(echo ${groupId} | tr '.' '/')

  echo -n "| [`echo ${groupId} | sed s/org.apache.maven/m/`](https://repo.maven.apache.org/maven2/${groupDir}) "
  echo -n "| [${artifactId}](https://repo.maven.apache.org/maven2/${groupDir}/${artifactId}) "
  echo -n "([spec](https://github.com/mojohaus/reproducible-mojohaus/tree/master/${buildspec}), "
  echo -n "[Git](${gitRepo})) "

  buildinfo="`dirname ${buildspec}`/`basename ${buildinfo}`"
  b=`echo "${buildinfo}" | sed s/-SNAPSHOT//`
  buildinfoLatestFilename="`ls ${b} | grep -v SNAPSHOT`"
  buildinfoHEADFilename="`ls ${buildinfo} | grep SNAPSHOT`"

  if [ "${buildinfoLatestFilename}" == "" ]
  then
    echo -n "| "
  else
    countLatest=$(($countLatest+1))
    buildinfoLatest="`dirname ${buildspec}`/`basename ${buildinfoLatestFilename}`"
    . ${buildinfoLatest}.compare
    echo -n "| [${version}](https://github.com/mojohaus/reproducible-mojohaus/tree/master/${buildinfoLatest}): "
    [ ${ok} -gt 0 ] && echo -n "${ok} :heavy_check_mark: "
    [ ${ko} -gt 0 ] && echo -n " ${ko} [:warning:](https://github.com/mojohaus/reproducible-mojohaus/tree/master/${buildinfoLatest}.compare) "

    [ ${ko} -eq 0 ] && countLatestOk=$(($countLatestOk + 1))
    sumLatestOk=$(($sumLatestOk + ${ok}))
    sumLatestKo=$(($sumLatestKo + ${ko}))
  fi

  buildinfoHEAD="`dirname ${buildspec}`/`basename ${buildinfoHEADFilename}`"
  . ${buildinfoHEAD}.compare
  echo -n "| [${version}](https://github.com/mojohaus/reproducible-mojohaus/tree/master/${buildinfoHEAD}): "
  [ ${ok} -gt 0 ] && echo -n "${ok} :heavy_check_mark: "
  [ ${ko} -gt 0 ] && echo -n " ${ko} [:warning:](https://github.com/mojohaus/reproducible-mojohaus/tree/master/${buildinfoHEAD}.compare) "
  echo "|"

  [ ${ko} -eq 0 ] && countHEADOk=$(($countHEADOk + 1))
  sumHEADOk=$(($sumHEADOk + ${ok}))
  sumHEADKo=$(($sumHEADKo + ${ko}))
done

echo -n "| | **${count}** "

echo -n "| **${countLatest}: ${countLatestOk} :heavy_check_mark: + $((${countLatest}-${countLatestOk})) :warning: = "
echo -n "$((${countLatestOk}*100/${countLatest}))% :heavy_check_mark:: "
echo -n "${sumLatestOk} :heavy_check_mark: ${sumLatestKo} :warning:** "

echo -n "| **${count}: ${countHEADOk} :heavy_check_mark: + $((${count}-${countHEADOk})) :warning: = "
echo -n "$((${countHEADOk}*100/${count}))% :heavy_check_mark:: "
echo "${sumHEADOk} :heavy_check_mark: ${sumHEADKo} :warning:** |"
echo "MojoHaus consists in ${count} sub-projects:

- **Latest release: on ${countLatest} releases, reproducibility status is ${countLatestOk} :heavy_check_mark: + $((${countLatest}-${countLatestOk})) :warning:
   = $((${countLatestOk}*100/${countLatest}))% :heavy_check_mark:**

- **master HEAD SNAPSHOT: on ${count} SNAPSHOTs, reproducibility status is ${countHEADOk} :heavy_check_mark: + $((${count}-${countHEADOk})) :warning:
   = $((${countHEADOk}*100/${count}))% :heavy_check_mark:**

sub-projects details:
   " > summary.md
) > summary-table.md

lead='^<!-- BEGIN GENERATED CONTENT -->$'
tail='^<!-- END GENERATED CONTENT -->$'
sed -e "/$lead/,/$tail/{ /$lead/{p; r summary.md
        r summary-table.md
        }; /$tail/p; d }" README.md > README.md.tmp

mv README.md.tmp README.md

rm summary.md
rm summary-table.md
