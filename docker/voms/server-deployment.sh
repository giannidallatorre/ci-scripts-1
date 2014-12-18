#!/bin/bash
set -x

sh clean.sh

MODE=${MODE:-clean}
PLATFORM=${PLATFORM:-EL6}

VOMSREPO=${VOMSREPO:-http://radiohead.cnaf.infn.it:9999/view/REPOS/job/repo_voms_develop_SL6/lastSuccessfulBuild/artifact/voms-develop_sl6.repo}

VO1=${VO1:-vo.0}
VO1_HOST=${VO1_HOST:-voms-server}
VO1_PORT=${VO1_PORT:-15000}
VO1_ISSUER=${VO1_ISSUER:-/C=IT/O=IGI/CN=voms-server}

VO2=${VO2:-vo.1}
VO2_HOST=${VO2_HOST:-voms-server}
VO2_PORT=${VO2_PORT:-15001}
VO2_ISSUER=${VO2_ISSUER:-/C=IT/O=IGI/CN=voms-server}

MYPROXY_SERVER=${MYPROXY_SERVER:-myproxy-server}
MYPROXY_PASSWORD=${MYPROXY_PASSWORD:-123456}

INCLUDE_TESTS=${INCLUDE_TESTS:-""}
EXCLUDE_TESTS=${EXCLUDE_TESTS:-""}

# Start myproxy server
if [ -z "${SKIP_MYPROXY}" ]; then
  docker run -d \
    -h myproxy-server \
    --name myproxy-server \
    italiangrid:myproxy-server
fi

# run VOMS deployment
if [ -z "${SKIP_SERVER}" ]; then
  docker run -d \
    -e "MODE=${MODE}" \
    -e "PLATFORM=${PLATFORM}" \
    -v /sync \
    -h voms-server \
    --name voms-server \
    italiangrid:voms-deployment-test
fi

# run VOMS testsuite when deployment is over
docker run \
  -e "VOMSREPO=${VOMSREPO}" \
  -e "VO1=${VO1}" \
  -e "VO1_HOST=${VO1_HOST}" \
  -e "VO1_PORT=${VO1_PORT}" \
  -e "VO1_ISSUER=${VO1_ISSUER}" \
  -e "VO2=${VO2}" \
  -e "VO2_HOST=${VO2_HOST}" \
  -e "VO2_PORT=${VO2_PORT}" \
  -e "VO2_ISSUER=${VO2_ISSUER}" \
  -e "MYPROXY_SERVER=${MYPROXY_SERVER}" \
  -e "MYPROXY_PASSWORD=${MYPROXY_PASSWORD}" \
  -e "INCLUDE_TESTS=${INCLUDE_TESTS}" \
  -e "EXCLUDE_TESTS=${EXCLUDE_TESTS}" \
  -h voms-ts \
  --name voms-ts \
  --volumes-from voms-server \
  --link voms-server:voms-server \
  --link myproxy-server:myproxy-server \
  italiangrid:voms-ts

testsuite_retval=$?

# Get server logs and shutdown container
if [ -z "${SKIP_SERVER}" ]; then
  # copy VOMS server logs
  mkdir logs
  docker cp voms-server:/var/log/voms logs
  docker cp voms-server:/var/log/voms-admin logs
  docker logs --tail="all" voms-server &> deployment.log
  docker rm -f voms-server
fi

# Get testsuite logs & shutdown container
docker cp voms-ts:/home/voms/voms-testsuite/reports .
docker logs --tail="all" voms-ts &> testsuite.log
docker rm -f voms-ts
docker rm -f myproxy-server

exit ${testsuite_retval}
