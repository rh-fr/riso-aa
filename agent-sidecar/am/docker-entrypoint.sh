#!/bin/bash
#
# Copyright (c) 2019 ForgeRock AS. Use of this source code is subject to the
# Common Development and Distribution License (CDDL) that can be found in the LICENSE file
#

echo "$(date +%d/%b/%Y:%T) Entering docker-entrypoint"

# AM configs
AM_URL="http://am-agent.apps-crc.testing:8080/am"
HOSTNAME=$(hostname)
HOSTNAME="http://${HOSTNAME}:8080/am"

# Config page. This comes up if OpenAM is not configured.
CONFIG_URL="${HOSTNAME}/config/options.htm"

# Start tomcat
start_tomcat() {
  echo "$(date +%d/%b/%Y:%T) Starting tomcat..."
  catalina.sh start
}

# Restarting tomcat with shutdown can be flaky - if there is not enough
# wait between the shutdown.sh and the startup.sh, a zombie tomcat will
# be left and everything will collapse, so we kill it instead
restart_tomcat ()
{
  echo "$(date +%d/%b/%Y:%T) Restarting tomcat..."
  ps -ef | grep tomcat | grep -v grep | awk '{ print $2 }' | xargs kill -9
  /usr/local/tomcat/bin/startup.sh
}

installAm ()
{
  if [ ! -f "/opt/amInstalled" ]; then
    echo "$(date +%d/%b/%Y:%T) Installing AM..."
    curl -X POST -s \
"$HOSTNAME/config/configurator\
?DS_DIRMGRPASSWD=password\
&ADMIN_CONFIRM_PWD=password\
&DATA_STORE=embedded\
&AM_ENC_KEY=FederatedAccessManagerEncryptionKey\
&DIRECTORY_PORT=50389\
&SERVER_HOST=am\
&SERVER_URI=%2Fam\
&ROOT_SUFFIX=dc%3Dopenam%2Cdc%3Dforgerock%2Cdc%3Dorg\
&DS_DIRMGRDN=cn%3DDirectory%20Manager\
&DIRECTORY_SSL=SIMPLE\
&acceptLicense=true\
&PLATFORM_LOCALE=en_US\
&DIRECTORY_SERVER=localhost\
&AMLDAPUSERPASSWD_CONFIRM=cangetinua\
&DIRECTORY_JMX_PORT=1689\
&AMLDAPUSERPASSWD=cangetinua\
&COOKIE_DOMAIN=apps-crc.testing\
&ADMIN_PWD=password\
&DIRECTORY_ADMIN_PORT=4444\
&SERVER_URL=http%3A%2F%2am-agent.apps-crc.testing%3A8080\
&AUDIT_CONFIG_LOCATION=%2Froot%2Fam%2Fam%2Flog\
&locale=en_US\
&BASE_DIR=%2Froot%2Fam"
    echo ""
    touch /opt/amInstalled
  fi
}

getAdminToken ()
{
  echo "$(date +%d/%b/%Y:%T) Obtaining admin token..."
  ADMIN_TOKEN=`curl --request POST -s \
  --header "Content-Type: application/json" \
  --header "Accept-API-Version: protocol=1.0,resource=1.0" \
  --header "X-OpenAM-Username: amadmin" \
  --header "X-OpenAM-Password: password" \
  --data "{}" "$AM_URL/json/authenticate" \
  | grep -o '"tokenId":"[^"]*"' | sed -e 's/"tokenId" *: *"//' -e 's/"$//'`
}

createAgentProfile () {
  if [[ ! -f "/opt/profileCreated" ]]; then
    echo "$(date +%d/%b/%Y:%T) Creating Agent Profile..."
    curl --request PUT -s \
    --header "iPlanetDirectoryPro: $ADMIN_TOKEN" \
    --header "Content-Type: application/json" \
    --header "Accept-API-Version: protocol=2.0,resource=1.0" \
    --data '{
    "userpassword":"password",
    "agentUrl":"https://agent.localtest.me:443",
    "serverUrl":"https://openam.localtest.me:8443/am",
    "agentNotificationUrl":{"value":"","inherited":false}
    }' \
    "$AM_URL/json/realms/realm-config/agents/WebAgent/wpa-agent"
    echo ""
    touch /opt/profileCreated  
 fi
}

# Wait for AM to come up. It can wait for AM to be ready to configured,
# already configured, or either. The timeout is also configurable.
# Parameters:
# $1: AM desited state. Optional. Can be:
#     "configured" : if we want to wait until AM is configured
#     "ready" : if we want to wait until AM is ready to be configured
# $2: Timeout. Optional. Default is 3 minutes (TODO - hardcoded to 3 mins)
wait_for_openam()
{
    timeout=180
    wait_time=5
    # Parse arguments
    if (( $# == 0 )); then
        expected="any"
    elif (( $# == 1 )); then
        if [[ $1 == "configured" || $1 == "ready" ]]; then
            expected=$1
        fi
        echo "$(date +%d/%b/%Y:%T) Waiting until AM is $expected"
    else
        echo "$(date +%d/%b/%Y:%T) Too many parameters"
        exit 1
    fi

    # Initial sleep. We know that it won't be ready yet, so give it some time.
    sleep 5
    response=0

    # Loop until AM gets to the desired state or timesout.
    while true
    do
        echo "$(date +%d/%b/%Y:%T) Waiting for AM server at ${CONFIG_URL} to be $expected "

        response=$(curl --write-out %{http_code} --silent --connect-timeout 30 --output /dev/null ${CONFIG_URL} )
        echo "$(date +%d/%b/%Y:%T) Got Response code $response"

        # If we get a "FOUND" response from AM, we check whether it is...
        if (( response == 302 )); then
            echo "$(date +%d/%b/%Y:%T) AM is up."
            if [[ ${expected} == "any" ]]; then
                break
            fi
            # ... Ready to be configured
            # (if we are waiting for "ready" we are done, so we break)
            if curl  ${CONFIG_URL} -s | grep -q "Configuration"; then
                if [[ ${expected} == "ready" ]]; then
                    break
                fi
            fi
            echo "$(date +%d/%b/%Y:%T) It looks like AM is configured already."

            # ... Or already configured - meaning we are done in any case,
            # so we always break
            # But if we were waiting for ready, we exit the script, as we do not
            # want to reconfigure - TOOD maybe extract this logic out of the
            # function? (a return 1 instead of an exit and check the return
            # value?)
            if [[ ${expected} == "ready" ]]; then
                echo "$(date +%d/%b/%Y:%T) AM already configured. Won't reconfigure again"
                break
            fi
            break
        fi
        # If we get an "OK", AM is ready to be configured
        if (( response == 200 )); then
            # If that is what we were looking for, we are done so we break.
            echo "$(date +%d/%b/%Y:%T) AM app is up and ready to be configured"
            if [[ ${expected} == "ready" || ${expected} == "any" ]]; then
                break
            fi
        fi
        echo "$(date +%d/%b/%Y:%T) Response code ${response}. Will continue to wait"
        sleep ${wait_time}
        (( timeout = timeout - wait_time ))
        if (( timeout <= 0 )); then
            echo "$(date +%d/%b/%Y:%T) Timed out. Exiting"
            exit 1
        fi
    done
    echo "$(date +%d/%b/%Y:%T) Server is ready"
}

# Start Tomcat
start_tomcat

#echo "$(date +%d/%b/%Y:%T) Waiting for AM to be ready to be configured ..."
#wait_for_openam ready

# Installing AM
#installAm
#wait_for_openam configured

# Create Agent Profile
#getAdminToken
#createAgentProfile

echo "$(date +%d/%b/%Y:%T) AM is ready to use"
sleep infinity
