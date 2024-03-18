#!/bin/bash

#
# Run this script from the base SignifyPy directory, like
# signifypy% ./integration/app/delegate.sh
#

#print commands
#set -x

#save this current directory, this is where the integration_clienting file also is
ORIG_CUR_DIR=$( pwd )

#run a clean witness network
echo "Launching a clean witness network"
KERI_PRIMARY_STORAGE="/usr/local/var/keri"
KERI_FALLBACK_STORAGE="${HOME}/.keri"

KERI_DEV_BRANCH="development"
VLEI_DEV_BRANCH="dev"
KERIA_DEV_BRANCH="main"
SIGNIFY_DEV_BRANCH="main"

declare -A PID_MAP
delPid="delegator"
keriaPid="keria"
vleiPid="vLEI"
witPid="witness"

vleiPort=7723
keriaPortStart=3901
keriaPortEnd=3903
witPortStart=5632
witPortEnd=5647

function checkPorts() {
    # Get the output from lsof command
    output=$(sudo lsof -i -P -n | grep LISTEN)

    # Set the process name and port range you want to check and kill
    if [ "$#" -lt 1 ]; then
        echo "Cant check ports without a process name and port"
        return 1
    else
        sPort="$1"
        echo "start port is: $sPort"
        ePort=$sPort
        if [ -z "$2" ]; then
            echo "Using only start port"
        else
            ePort="$2"
            echo "end port is: $ePort"
        fi

        # Get the output from lsof command
        output=$(sudo lsof -i -P -n | grep LISTEN)

        # Loop through the range of ports
        for port in $(seq $sPort $ePort); do
            # Parse the output and get the PIDs of the target process for the specific port
            pids=$(echo "$output" | grep ":$port" | awk '{print $2}')

            # Identify each found PID
            for pid in $pids; do
                if [ ! -z "$pid" ]; then
                    echo "Found PID $pid on port $port"
                    killInput="n"
                    read -p "Kill PID $pid on port $port? (y/n): " killInput
                    if [ ${killInput} == "y" ]; then
                        kill $pid
                    else
                        return 1
                    fi
                fi
            done
        done
    fi

    return 0
}

function getKeripyDir() {
    # Check if the environment variable is set
    if [ -z "$KERIPY_DIR" ]; then
        default_value="../keripy"
        # Prompt the user for input with a default value
        read -p "Set keripy dir [${default_value}]: " input
        # Set the value to the user input or the default value
        KERIPY_DIR=${input:-$default_value}
    fi
    # Use the value of the environment variable
    echo "$KERIPY_DIR"
}

function getVleiDir() {
    # Check if the environment variable is set
    if [ -z "$VLEI_DIR" ]; then
        default_value="../vLEI"
        # Prompt the user for input with a default value
        read -p "Set vlei dir [${default_value}]: " input
        # Set the value to the user input or the default value
        VLEI_DIR=${input:-$default_value}
    fi
    # Use the value of the environment variable
    echo "$VLEI_DIR"
}

function getKeriaDir() {
    # Check if the environment variable is set
    if [ -z "$KERIA_DIR" ]; then
        default_value="../keria"
        # Prompt the user for input with a default value
        read -p "Set keria dir [${default_value}]: " input
        # Set the value to the user input or the default value
        KERIA_DIR=${input:-$default_value}
    fi
    # Use the value of the environment variable
    echo "$KERIA_DIR"
}

function runDelegator() {
    #create the delegator from keripy
    keriDir=$1
    echo "Creating delegator"
    KERIPY_SCRIPTS_DIR="${keriDir}/scripts"
    if [ -d "${KERIPY_SCRIPTS_DIR}" ]; then
        kli init --name delegator --nopasscode --config-dir "${KERIPY_SCRIPTS_DIR}" --config-file demo-witness-oobis --salt 0ACDEyMzQ1Njc4OWdoaWpsaw
        KERIPY_DELEGATOR_CONF="${KERIPY_SCRIPTS_DIR}/demo/data/delegator.json"
        if [ -f "${KERIPY_DELEGATOR_CONF}" ]; then
            kli incept --name delegator --alias delegator --file "${KERIPY_DELEGATOR_CONF}"
            # kli incept --name delegator --alias delegator --file /Users/meenyleeny/VSCode/keripy/scripts/demo/data/delegator.json
            echo "Delegator created"
            # delgator auto-accepts the delegation request
            kli delegate confirm --name delegator --alias delegator -Y &
            PID_MAP[$delPid]=$!
            echo "Delegator waiting to auto-accept delegation request"
        else
            echo "Delegator configuration missing ${KERIPY_DELEGATOR_CONF}"
        fi
    else
        echo "KERIPY directory ${KERIPY_SCRIPTS_DIR} does not exist."
    fi
}

function runMultisig() {
    #create the delegator from keripy
    keriDir=$1
    echo "Creating multisig"
    KERIPY_SCRIPTS_DIR="${keriDir}/scripts"
    if [ -d "${KERIPY_SCRIPTS_DIR}" ]; then

        # Follow commands run in parallel
        kli multisig incept --name multisig1 --alias multisig1 --group multisig --file ${KERI_DEMO_SCRIPT_DIR}/data/multisig-triple-sample.json &
        kli multisig incept --name multisig2 --alias multisig2 --group multisig --file ${KERI_SCRIPTS_DIR}/data/multisig-triple-sample.json &

        kli init --name multisig1 --salt 0ACDEyMzQ1Njc4OWxtbm9aBc --nopasscode --config-dir "${KERIPY_SCRIPTS_DIR}" --config-file demo-witness-oobis
        kli init --name multisig2 --salt 0ACDEyMzQ1Njc4OWdoaWpsaw --nopasscode --config-dir "${KERIPY_SCRIPTS_DIR}" --config-file demo-witness-oobis
        KERIPY_MULTISIG_CONF_1="${KERIPY_SCRIPTS_DIR}/demo/data/multisig-1-sample.json"
        KERIPY_MULTISIG_CONF_2="${KERIPY_SCRIPTS_DIR}/demo/data/multisig-2-sample.json"
        if [ -f "${KERIPY_MULTISIG_CONF_2}" ]; then
            kli incept --name multisig1 --alias multisig1 --file "${KERIPY_MULTISIG_CONF_1}"
            kli incept --name multisig2 --alias multisig2 --file "${KERIPY_MULTISIG_CONF_2}"

            echo "Multisig 1 and 2 created"
            kli oobi resolve --name multisig1 --oobi-alias multisig2 --oobi http://127.0.0.1:5642/oobi/EJccSRTfXYF6wrUVuenAIHzwcx3hJugeiJsEKmndi5q1/witness/BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha &
            kli oobi resolve --name multisig1 --oobi-alias multisig3 --oobi http://127.0.0.1:5642/oobi/EKzS2BGQ7qkmEfsjGdx2w5KwmpWKf7lEXAMfB4AKqvUe/witness/BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha &
            kli oobi resolve --name multisig2 --oobi-alias multisig1 --oobi http://127.0.0.1:5642/oobi/EKYLUMmNPZeEs77Zvclf0bSN5IN-mLfLpx2ySb-HDlk4/witness/BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha &
            kli oobi resolve --name multisig2 --oobi-alias multisig3 --oobi http://127.0.0.1:5642/oobi/EKzS2BGQ7qkmEfsjGdx2w5KwmpWKf7lEXAMfB4AKqvUe/witness/BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha &
            echo "All participants of multisig looking for each other"
        else
            echo "Multisig configuration missing ${KERIPY_MULTISIG_CONF_2}"
        fi
    else
        echo "KERIPY directory ${KERIPY_SCRIPTS_DIR} does not exist."
    fi
}

function runIssueEcr() {
    cd "${ORIG_CUR_DIR}" || exit
    read -p "Run vLEI issue ECR script (n to skip)?, [y]: " input
    runIssueEcr=${input:-"y"}
    if [ "${runIssueEcr}" == "n" ]; then
        echo "Skipping Issue ECR script"
    else
        echo "Running issue ECR script"
        scriptsDir="scripts"
        if [ -d "${scriptsDir}" ]; then
            echo "Launching Issue ECR script"
            cd ${scriptsDir} || exit
            source env.sh
            source issue-ecr.sh
            echo "Completed issue ECR script"
            python list_person_credentials.py
            echo "Listed person credentials"
        fi
    fi
    cd "${ORIG_CUR_DIR}" || exit
}

function runKeri() {
    cd ${ORIG_CUR_DIR} || exit
    keriDir=$(getKeripyDir)
    echo "Keripy dir set to: ${keriDir}"
    read -p "Run witness network (y/n)? [y]: " input
    runWit=${input:-"y"}
    if [ "${runWit}" == "y" ]; then
        if [ -d  "${keriDir}" ]; then
            cd "${keriDir}" || exit
            updateFromGit ${KERI_DEV_BRANCH}
            installPythonUpdates
            rm -rf ${KERI_PRIMARY_STORAGE}/*;rm -Rf ${KERI_FALLBACK_STORAGE}/*;kli witness demo &
            PID_MAP[$witPid]=$!
            sleep 5
            echo "Clean witness network launched"
        else
            echo "KERIPY dir missing ${keriDir}"
            exit 1
        fi
    else
        echo "Skipping witness network"
    fi
    echo ""
}

function runKeria() {
        # run keria cloud agent
    read -p "Run Keria (y/n)? [y]: " input
    runKeria=${input:-"y"}
    if [ "${runKeria}" == "y" ]; then
        echo "Running keria cloud agent"
        keriaDir=$(getKeriaDir)
        if [ -d "${keriaDir}" ]; then
            cd "${keriaDir}" || exit
            updateFromGit ${KERIA_DEV_BRANCH}
            installPythonUpdates
            export KERI_AGENT_CORS=true
            keria start --config-file demo-witness-oobis.json --config-dir "${keriaDir}/scripts" &
            PID_MAP[$keriaPid]=$!
            sleep 5
            echo "Keria cloud agent running"
        else
            echo "Keria dir missing ${keriaDir}"
        fi
    fi
    echo ""
}

function runSignifyIntegrationTests() {
    # Assumes you are running from the base signify dir (see hints at the top)
    cd "${ORIG_CUR_DIR}" || exit
    integrationTestModule="integration.app.integration_clienting"
    echo "Available functions in ${integrationTestModule}"
    python -c "import ${integrationTestModule}; print('\n'.join(x for x in dir(${integrationTestModule}) if x.startswith('test_')))"

    read -p "What signify test to run (n to skip)?, [${runSignify}]: " input
    runSignify=${input:-$runSignify}
    if [ "${runSignify}" == "n" ]; then
        echo "Skipping signify test"
    else
        echo "Launching Signifypy test ${runSignify}"
        updateFromGit ${SIGNIFY_DEV_BRANCH}
        installPythonUpdates
        iClient="./integration/app/integration_clienting.py"
        if [ -f "${iClient}" ]; then
            if [ "${runSignify}" == "test_delegation" ]; then
                runDelegator ${keriDir}
            fi
            if [ "${runSignify}" == "test_multisig" ]; then
                runMultisig ${keriDir}
            fi
            python -c "from ${integrationTestModule} import ${runSignify}; ${runSignify}()" &
            PID_MAP[$signifyPid]=$!
            sleep 10
            echo "Completed signify ${runSignify}"
        else
            echo "${iClient} module missing"
            exit 1
        fi
    fi
}

function runVlei() {
    # run vLEI cloud agent
    cd ${ORIG_CUR_DIR} || exit
    read -p "Run vLEI (y/n)? [y]: " input
    runVlei=${input:-"y"}
    if [ "${runVlei}" == "y" ]; then
        echo "Running vLEI server"
        vleiDir=$(getVleiDir)
        if [ -d "${vleiDir}" ]; then
            cd "${vleiDir}" || exit
            updateFromGit ${VLEI_DEV_BRANCH}
            installPythonUpdates
            vLEI-server -s ./schema/acdc -c ./samples/acdc/ -o ./samples/oobis/ &
            PID_MAP[$vleiPid]=$!
            sleep 5
            echo "vLEI server is running"
        else
            echo "vLEI dir missing ${vleiDir}"
        fi
    fi
    echo ""
}

function installPythonUpdates() {
    echo "Installing python module updates..."
    python -m pip install -e .
}

function updateFromGit() {
    branch=$1
    read -p "Update git repo ${branch}?, [n]: " input
    update=${input:-"n"}
    if [ "${update}" == "y" ]; then
        echo "Updating git branch ${branch}"
        fetch=$(git fetch)
        echo "git fetch status ${fetch}"
        switch=$(git switch "${branch}")
        echo "git switch status ${switch}"
        pull=$(git pull)
        echo "git pull status ${pull}"
    else
        echo "Skipping git update ${branch}"
    fi
}

function killProcesses() {
    echo "Tearing down any leftover processes"
    for task_name in "${!PID_MAP[@]}"; do
        echo "Killing $task_name with PID ${PID_MAP["$task_name"]}"
        kill "${PID_MAP["$task_name"]}" >/dev/null 2>&1
    done
}

function printProcesses() {
    echo "Processes running:"
    for task_name in "${!PID_MAP[@]}"; do
        echo "Process running $task_name with PID ${PID_MAP["$task_name"]}"
    done
}

echo "Welcome to the integration test setup/run/teardown script"

runSignify="test_salty"
while [ "${runSignify}" != "n" ]
do
    # echo "Setting up..."
    # if checkPorts ${witPortStart} ${witPortEnd}; then
    #     runKeri
    # else
    #     echo "Witness network already running"
    # fi

    # printProcesses

    # if checkPorts ${vleiPort}; then
    #     runVlei
    # else
    #     echo "vLEI server already running"
    # fi

    # printProcesses

    # if checkPorts ${keriaPortStart} ${keriaPortEnd}; then
    #     runKeria
    # else
    #     echo "Keria cloud agent already running"
    # fi

    # printProcesses

    runSignifyIntegrationTests
    
    printProcesses
    
    runIssueEcr
    
    printProcesses
    echo ""

    read -p "Your servers still running, hit enter to tear down: " input
    killProcesses
    printProcesses

    read -p "Run another test [n]?: " input
    runSignify=${input:-"n"}
done

echo "Done"