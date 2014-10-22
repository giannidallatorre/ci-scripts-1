#!/bin/bash
set -x
trap "exit 1" TERM
export TOP_PID=$$

terminate() {
      echo $1 && kill -s TERM $TOP_PID
}

[ -n "${JENKINS_SLAVE_PRIVATE_KEY}" ] || terminate "JENKINS_SLAVE_PRIVATE_KEY not set."
[ -n "${MACHINE_HOSTNAME}" ] || terminate "MACHINE_HOSTNAME not set."
[ -n "${EC2_USER}" ] || terminate "EC2_USER not set."

[ -n "${REPO_URL}" ] || terminate "REPO_URL not set."
[ -n "${PLATFORM}" ] || terminate "PLATFORM not set."
[ -n "${MODE}" ] || terminate "MODE not set."
[ -n "${COMPONENT}" ] || terminate "COMPONENT not set."
[ -n "${PERFORM_DATABASE_UPGRADE}" ] || terminate "PERFORM_DATABASE_UPGRADE not set."

[ "${PERFORM_DATABASE_UPGRADE}" == "true" ] && DB_UPGRADE=yes || DB_UPGRADE=no

VOMS_DEPLOYMENT_TEST_SCRIPT=${VOMS_DEPLOYMENT_TEST_SCRIPT:-https://raw.githubusercontent.com/italiangrid/voms-deployment-test/master/voms-deployment-test.sh}
SSH_OPTIONS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=false -i $JENKINS_SLAVE_PRIVATE_KEY"
VOMS_REPO="${REPO_URL}_$(echo $PLATFORM | tr '[:upper:]' '[:lower:]').repo"

chmod 400 ${JENKINS_SLAVE_PRIVATE_KEY}

cat << EOF > deploy_voms.sh
#!/bin/bash
set -x
dir=$(mktemp -d voms-deployment.XXXX)
cd $dir
wget --no-check-certificate ${VOMS_DEPLOYMENT_TEST_SCRIPT} -O voms-deployment-test.sh
export PATH=$PATH:/sbin:/usr/sbin
sh voms-deployment-test.sh -c ${COMPONENT} -m ${MODE} -p ${PLATFORM} -r ${VOMS_REPO} -u ${DB_UPGRADE}
EOF

scp ${SSH_OPTIONS} deploy_voms.sh ${EC2_USER}@${MACHINE_HOSTNAME}:
[ $? -ne 0 ] && terminate "Error sending deployment script to ${MACHINE_HOSTNAME}"

ssh -tt ${SSH_OPTIONS} ${EC2_USER}@${MACHINE_HOSTNAME} "sudo sh deploy_voms.sh"
[ $? -ne 0 ] && terminate "Deployment test ERROR"

echo "Deployment test success."
