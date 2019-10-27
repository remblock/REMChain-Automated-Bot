#!/bin/bash

#****************************************************************************************************#
#                                             AUTOBOT.SH                                             #
#****************************************************************************************************#

#-----------------------------------------------------------------------------------------------------
# IF THE USER HAS NO ROOT PERMISSIONS THE SCRIPT WILL EXIT  
#-----------------------------------------------------------------------------------------------------

if (($EUID!=0))
then
  echo "You must be root to run this script" 2>&1
  exit 1
fi

#****************************************************************************************************#
#                                       CONFIGURATION VARIABLES                                      #
#****************************************************************************************************#

#-----------------------------------------------------------------------------------------------------
# CREATE AUTOBOT DIRECTORY  
#-----------------------------------------------------------------------------------------------------

create_dir="/root/remblock/autobot"

#-----------------------------------------------------------------------------------------------------
# CREATE AUTOBOT CONFIG FILE
#-----------------------------------------------------------------------------------------------------

config_file="/root/remblock/autobot/config"

#-----------------------------------------------------------------------------------------------------
# BP MONITOR SCRIPT AND CONFIG PATHS
#-----------------------------------------------------------------------------------------------------

bp_monitor_script_path="/root/remblock/autobot/bpmonitor.sh"
bp_monitor_config_path="$config_file"

#-----------------------------------------------------------------------------------------------------
# MINUTES TO WAIT BETWEEN EACH EXECUTIONS OF THE SCRIPT
#-----------------------------------------------------------------------------------------------------

minutes_to_wait=1442

#-----------------------------------------------------------------------------------------------------
# CRON LINE WILL BE CREATED FOR THE BP MONITORING SCRIPT
#-----------------------------------------------------------------------------------------------------

bp_mon_cron_line="* * * * * /root/remblock/autobot/bpmonitor.sh"

#-----------------------------------------------------------------------------------------------------
# START AND STOP SERVER COMMANDS FILES PATH
#-----------------------------------------------------------------------------------------------------

start_server_commands_path="/root/remblock/autobot/start_server_commands.sh"
stop_server_commands_path="/root/remblock/autobot/stop_server_commands.sh"
service_definition_path="/etc/systemd/system/autobot.service"

#-----------------------------------------------------------------------------------------------------
# INITIATE BOOLEAN VARIABLES FOR THE AUTOBOT SCRIPT
#-----------------------------------------------------------------------------------------------------

auto_vote=false
auto_reward=false
auto_restaking=false
auto_vote_alert=false
auto_reward_alert=false
auto_restaking_alert=false
bp_monitoring=false
vote_failed=false
reward_failed=false
restaking_failed=false
send_message=false

#-----------------------------------------------------------------------------------------------------
# CHECK IF THE REQUIRED PACKAGES WERE INSTALLED, IF NOT INSTALL THEM
#-----------------------------------------------------------------------------------------------------

if ! dpkg -l | awk '{print $2}' | grep -w at &>/dev/null
then
  echo "at package was not installed, installing it now..."
  apt-get install at -y
fi

if ! dpkg -l | awk '{print $2}' | grep -w bc &>/dev/null
then
  echo "bc package was not installed, installing it now..."
  apt-get install bc -y
fi

#-----------------------------------------------------------------------------------------------------
# CHECK IF THE AT CONDITION IS ENABLE TO AVOID PRINTING ANY OUTPUT
#-----------------------------------------------------------------------------------------------------

at=false
if [[ "$1" == "--at" ]]
then
  at=true
  at now + $minutes_to_wait minutes << DOC &>/dev/null
  /root/autobot.sh --at
DOC
fi

#-----------------------------------------------------------------------------------------------------
# CREATE THE DIRECTORY IF IT DOES NOT EXIST
#-----------------------------------------------------------------------------------------------------

if [ ! -d "$create_dir" ]
then
  mkdir -p "$create_dir"
fi

#-----------------------------------------------------------------------------------------------------
# CREATE THE CONFIG FILE IF IT DOES NOT EXIST
#-----------------------------------------------------------------------------------------------------

if [ ! -f "$config_file" ]
then
  echo "#Configuration file for the autobot.sh script" > "$config_file"
  echo "#Make the entries as variable=value" >> "$config_file"
  echo  >> "$config_file"
fi

#****************************************************************************************************#
#                                        FUNCTION DEFINITIONS                                        #
#****************************************************************************************************#

function get_user_answer_yn(){
  while :
  do
    read -p "$1 [y/n]: " answer
    answer="$(echo $answer | tr '[:upper:]' '[:lower:]')"  
    case "$answer" in
      yes|y) return 0 ;;
      no|n) return 1 ;;
      *) echo  "Invalid Answer [yes/y/no/n expected]";continue;;
    esac
  done
}

#-----------------------------------------------------------------------------------------------------
# GLOBAL VALUE IS USED AS A GLOBAL VARIABLE TO RETURN THE RESULT
#-----------------------------------------------------------------------------------------------------

function get_config_value(){
  global_value=$(grep -v '^#' "$config_file" | grep "^$1=" | awk -F '=' '{print $2}')
  if [ -z "$global_value" ]
  then
    return 1
  else
    return 0
  fi
}

#-----------------------------------------------------------------------------------------------------
# CREATE START STOP SERVICES
#-----------------------------------------------------------------------------------------------------

function create_start_stop_service {
  if [ ! -f "$start_server_commands_path" ]
  then
cat << 'DOC' > "$start_server_commands_path"
#!/bin/sh
. /root/.profile
remnode --config-dir ./config/ --data-dir ./data/ >> remnode.log 2>&1 &
/root/autobot.sh
DOC
chmod u+x "$start_server_commands_path"
fi
if [ ! -f "$stop_server_commands_path" ]
then
cat << 'DOC' > "$stop_server_commands_path"
#!/bin/sh
/usr/bin/killall remcli
sleep 15
DOC
chmod u+x $stop_server_commands_path
fi
if [ ! -f "$service_definition_path" ]
then
cat << DOC > "$service_definition_path"
[Unit]
Description=Run Autobot REMCLI Commands At Start And Stop
[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=$start_server_commands_path
ExecStop=$stop_server_commands_path
[Install]
WantedBy=multi-user.target
DOC
systemctl enable autobot &> /dev/null
fi
}

#-----------------------------------------------------------------------------------------------------
# CREATE BP MONITOR SCRIPT FILE
#-----------------------------------------------------------------------------------------------------

function create_bp_monitor_files(){
cat << 'DOC' > $bp_monitor_script_path
#!/bin/bash

#-----------------------------------------------------------------------------------------------------
# GET VARIABLES FROM THE CONFIG SOURCE
#-----------------------------------------------------------------------------------------------------

source "/root/remblock/autobot/config"

#Install and update crontab line
if [ ! -z "$ALERT_THRESHOLD" ]
then
  #Fix crontab to match time in ALERT_THRESHOLD
  CRON_CMD="/root/remblock/autobot/bpmonitor.sh"
  #Remove previous line of cron
  crontab -u root -l | grep -v 'bpmonitor.sh'  | crontab -u root -
  #Add new line that matches desired interval time
 (crontab -u root -l ; echo "*/$ALERT_THRESHOLD * * * * $CRON_CMD") | crontab -u root -
fi

#-----------------------------------------------------------------------------------------------------
# GET TELEGRAM API DETAILS FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

alerts=()
messages=()
now_s=$(date -d $now +%s)
now_n=$(date -d $now +%s%N)
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
telegram_config_file="/root/remblock/autobot/config"

#-----------------------------------------------------------------------------------------------------
# GET TELEGRAM CONFIGURATION FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

telegram_token="$(grep -v '^#' "$telegram_config_file" | grep '^telegram_token=' | awk -F '=' '{print $2}')"
telegram_chatid="$(grep -v '^#' "$telegram_config_file" | grep '^telegram_chatid=' | awk -F '=' '{print $2}')"

#-----------------------------------------------------------------------------------------------------
# SCHEDULE CRON FOR THE BP MONITOR SCRIPT
#-----------------------------------------------------------------------------------------------------

if ! crontab -l | grep -q "$SCRIPT_FILE"
then
  (crontab -l ; echo "* * * * * ${SCRIPT_DIR}/${SCRIPT_FILE} >> ${SCRIPT_DIR}/${SCRIPT_LOG_FILE} 2>&1") | crontab -
fi

#-----------------------------------------------------------------------------------------------------
# LOG FILE STATE TEST & MAINTENANCE
#-----------------------------------------------------------------------------------------------------

log_last_modified_s=$(date -r $NODE_LOG_FILE +%s)
modified_diff=$(( $now_s - $log_last_modified_s ))
log_byte_size=$(stat -c%s $NODE_LOG_FILE)

#-----------------------------------------------------------------------------------------------------
# IF THE LOG FILE HAS NOT BEEN MODIFIED WITHIN THE LAST 5 MINUTES
#-----------------------------------------------------------------------------------------------------

if [ $modified_diff -ge 300 ]; then
    alerts+=( "Node log was last modified $(( modified_diff / 60 )) minutes ago." )
fi

#-----------------------------------------------------------------------------------------------------
# IF THE LOG FILE IS LARGER THAN THE SPECIFIED THRESHOLD
#-----------------------------------------------------------------------------------------------------

if [ $(( $log_byte_size / 1000000)) -gt $MAX_LOG_SIZE ]; then
    sudo truncate -s 0 $NODE_LOG_FILE
fi

#-----------------------------------------------------------------------------------------------------
# TEST FOR REMCLI GET INFO RESPONCE
#-----------------------------------------------------------------------------------------------------

get_info_response="$(remcli get info)"

#-----------------------------------------------------------------------------------------------------
# IF THE RESPONSE WAS EMPTY OR THAT OF A FAILED CONNECTION 
#-----------------------------------------------------------------------------------------------------

if [[ -z "${get_info_response// }" ]] || [[ "Failed" =~ ^$get_info_response ]]; then
    alerts+=( "Failed to receive a response from remcli get info." )
else
    head_block_num="$(jq '.head_block_num | tonumber' <<< ${get_info_response})"
    li_block_num="$(jq '.last_irreversible_block_num | tonumber' <<< ${get_info_response})"
    block_diff=$(( head_block_num - li_block_num ))
   
#-----------------------------------------------------------------------------------------------------
# ALERT IF THE GAP BETWEEN THE HEAD AND LAST BLOCK IS MORE THAN 3 MINUTES
#-----------------------------------------------------------------------------------------------------

    if (( block_diff / 2 / 60 > 3 )); then
        alerts+=( "Current block is ${block_diff} ahead of last irreversible block." )
    fi

#-----------------------------------------------------------------------------------------------------
# ALERT IF THE LAST IRREVERSIBLE BLOCK HAS NOT ADVANCED
#-----------------------------------------------------------------------------------------------------
    
    if [ $LAST_IRREVERSIBLE_BLOCK_NUM -eq $li_block_num ]; then
        alerts+=( "Last irreversible block is stuck on ${li_block_num}." )
    fi

#-----------------------------------------------------------------------------------------------------
# UPDATE THE LAST IRREVERSIBLE BLOCK NUMBER
#-----------------------------------------------------------------------------------------------------

    sed -i "s/last_irreversible_block_num=.*/last_irreversible_block_num=$li_block_num/" $SCRIPT_DIR/$CONFIG_FILE
fi

#-----------------------------------------------------------------------------------------------------
# TEST REMCLI NET PEERS LAST HANDSHAKE TIME
#-----------------------------------------------------------------------------------------------------

net_peers_response="$(remcli net peers)"

#-----------------------------------------------------------------------------------------------------
# IF THE RESPONCE IS EMPTY OR THAT OF A FAILED CONNECTION
#-----------------------------------------------------------------------------------------------------

if [[ -z "${net_peers_response// }" ]] || [[ "Failed" =~ ^$net_peers_response ]]; then
    alerts+=( "Failed to receive a response from remcli net peers." )
else
    last_handshake=$(jq '.[0].last_handshake.time | tonumber' <<< ${net_peers_response})

#-----------------------------------------------------------------------------------------------------
# IF THE PEER TIME IS OLDER THAN 3 MINUTES IN NANOSECONDS
#-----------------------------------------------------------------------------------------------------
    
    if [ $last_handshake -eq 0 ] ; then
        alerts+=( "Peer handshake never took place" )
    fi
fi

#-----------------------------------------------------------------------------------------------------
# SEND ALERTS IF PROBLEMS WERE FOUND
#-----------------------------------------------------------------------------------------------------

if [ ${#alerts[@]} -gt 0 ]; then
    alert="BP Monitor Alert (${ALERT_THRESHOLD} minute frequency) 
-----------------------------------------------"
    for i in "${alerts[@]}"
    do
            alert="${alert} 
${i}"
    done
    alert="${alert} 
-----------------------------------------------"

#-----------------------------------------------------------------------------------------------------
# SEND ALERTS TO YOUR TELEGRAM BOT 
#-----------------------------------------------------------------------------------------------------
     
    curl -s -X POST https://api.telegram.org/bot$telegram_token/sendMessage -d chat_id=$telegram_chatid -d text="$alert" &>/dev/null

#-----------------------------------------------------------------------------------------------------
# UPDATE THE TIMESTAMP IN THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------
    
    sed -i "s/LAST_ALERT=.*/LAST_ALERT=$now/" $SCRIPT_DIR/$CONFIG_FILE
fi

#-----------------------------------------------------------------------------------------------------
# SEND MONITORING DAILY SUMMARY NOTIFICATIONS
#-----------------------------------------------------------------------------------------------------

if [ $(date +%H:%M) == $DAILY_STATUS_AT ] && [ "$DAILY_SUM_ENABLED" == "true" ]; then
    summary="Daily Summary 
-------------------------------------------" 
    summary="${summary}
Cron job is still running, scheduled to check in at ${DAILY_STATUS_AT} UTC every day."
    for i in "${messages[@]}"
    do
        summary="${summary}
${i}"
    done
    summary="${summary} 
-------------------------------------------"

#-----------------------------------------------------------------------------------------------------
# SEND MONITORING DAILY SUMMARY TO TELEGRAM BOT
#-----------------------------------------------------------------------------------------------------
    
    curl -s -X POST https://api.telegram.org/bot$telegram_token/sendMessage -d chat_id=$telegram_chatid -d text="$summary" &>/dev/null

#-----------------------------------------------------------------------------------------------------
# UPDATE THE TIMESTAMP IN THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------
    
    sed -i "s/LAST_STATUS=.*/LAST_STATUS=$now/" $SCRIPT_DIR/$CONFIG_FILE
fi
DOC

chmod u+x $bp_monitor_script_path

#-----------------------------------------------------------------------------------------------------
# CREATE BP MONITOR CONFIG FILE
#-----------------------------------------------------------------------------------------------------

if ! grep '^SCRIPT_FILE=' "$bp_monitor_config_path" &>/dev/null
then
cat << 'DOC' >> "$bp_monitor_config_path"
#-----------------------------------------------------------------------------------------------------
# START OF BPMONITOR CONFIGURATION
#-----------------------------------------------------------------------------------------------------

NODE_NAME=""
SCRIPT_DIR="/root/remblock/autobot"
SCRIPT_FILE="/root/remblock/autobot/bpmonitor.sh"
SCRIPT_LOG_FILE="log.txt"
CONFIG_FILE="config.conf"
NODE_LOG_FILE="/root/remnode.log"

#-----------------------------------------------------------------------------------------------------
# IF THE LOG FILE EXCEEDS THE SPECFIED MB, IT WILL BE EMPTIED
#-----------------------------------------------------------------------------------------------------

MAX_LOG_SIZE=100

#-----------------------------------------------------------------------------------------------------
# CRON WILL RUN IN EVERY ALERT_THRESHOLD MINUTE SPECIFIED
#-----------------------------------------------------------------------------------------------------

ALERT_THRESHOLD=30
CRON_CMD="/root/remblock/autobot/bpmonitor.sh"

#-----------------------------------------------------------------------------------------------------
# MONITOR SCRIPT CHECKS IN ONCE A DAY TO CONFIRM THAT ITS STILL ACTIVE
#-----------------------------------------------------------------------------------------------------

DAILY_SUM_ENABLED="false"
DAILY_STATUS_AT="11:30"
LAST_ALERT="2006-09-04"
LAST_STATUS="2006-09-04"
LAST_IRREVERSIBLE_BLOCK_NUM=0

#Time is defined in UTC military time, -4 for eastern
DOC

#Run the script a first time so it create the crontab line
bash $bp_monitor_script_path &>/dev/null
fi
}

#****************************************************************************************************#
#                                       MAIN PROGRAM FUNCTIONS                                       #
#****************************************************************************************************#

#Every time the script runs it will check if the service is installed, if not it will install it
create_start_stop_service

#-----------------------------------------------------------------------------------------------------
# ASK USER FOR THEIR OWNER ACCOUNT NAME OR TAKE IT FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

if get_config_value owner
then
  owneraccountname="$global_value"
else
  if $at
  then
    exit 2
  fi
  echo
  read -p "YOUR ACCOUNT NAME: " -e owneraccountname
  echo "owner=$owneraccountname" >> "$config_file"
  echo 
fi

#-----------------------------------------------------------------------------------------------------
# ASK USER FOR THEIR WALLET PASSWORD OR TAKE IT FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

if get_config_value walletpassword
then
  walletpassword="$global_value"
else
  if $at
  then
    exit 2
  fi
  read -p "YOUR WALLET PASSWORD: " -e walletpassword
  echo "walletpassword=$walletpassword" >> "$config_file"
  echo 
fi

#-----------------------------------------------------------------------------------------------------
# GET AUTOMATED VOTING ANSWER FROM THE USER OR TAKE IT FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

if get_config_value auto_vote
then
  if [ "$global_value" = "true" ]
  then
    auto_vote=true
  fi
else
  if $at
  then
    exit 2
  fi
  if get_user_answer_yn "DO YOU WANT AUTOBOT TO AUTOMATE YOUR VOTING"
  then
    auto_vote=true
    echo "auto_vote=true" >> "$config_file"
  else
    echo "auto_vote=false" >> "$config_file"
  fi
  echo 
fi

#-----------------------------------------------------------------------------------------------------
# IF AUTOMATED VOTING IS ENABLED, ASK THE USER FOR ACCOUNT NAMES OR TAKE IT FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

if $auto_vote
then
 if get_config_value bpaccountnames
 then
   bpaccountnames="$global_value"
else
   if $at
   then
     exit 2
   fi
   read -p "THE BLOCK PRODUCERS THAT YOU WANT TO VOTE FOR: " -e bpaccountnames
   if [ -z "$bpaccountnames" ]
   then
     bpaccountnames="$owneraccountname"
   fi
   echo "bpaccountnames=$bpaccountnames" >> "$config_file"
  echo 
fi
    
#-----------------------------------------------------------------------------------------------------
# GET VOTING NOTIFCATIONS ANSWER FROM THE USER OR TAKE IT FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------
      
if get_config_value auto_vote_alert
then
  if [ "$global_value" = "true" ]
  then
    auto_vote_alert=true
  fi
  else
    if $at
    then
      exit 2
    fi
    if get_user_answer_yn "DO YOU WANT TO RECEIVE VOTING NOTIFICATIONS"
    then
      auto_vote_alert=true
      echo "auto_vote_alert=true" >> "$config_file"
    else
      echo "auto_vote_alert=false" >> "$config_file"
    fi
    echo 
  fi
fi

#-----------------------------------------------------------------------------------------------------
# GET AUTOMATED REWARDS ANSWER FROM THE USER OR TAKE IT FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

if get_config_value auto_reward
then
  if [ "$global_value" = "true" ]
  then
    auto_reward=true
  fi
else
  if $at
  then
    exit 2
  fi
  if get_user_answer_yn "DO YOU WANT AUTOBOT TO AUTO CLAIM YOUR REWARDS"
  then
    auto_reward=true
    echo "auto_reward=true" >> "$config_file"
  else
    echo "auto_reward=false" >> "$config_file"
  fi
  echo 
fi

#-----------------------------------------------------------------------------------------------------
# GET REWARD NOTIFCATIONS ANSWER FROM THE USER OR TAKE IT FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

if $auto_reward
then
  if get_config_value auto_reward_alert
  then
    if [ "$global_value" = "true" ]
    then
      auto_reward_alert=true
    fi
  else
    if $at
    then
      exit 2
    fi
    if get_user_answer_yn "DO YOU WANT TO RECEIVE REWARD NOTIFICATIONS"
    then
      auto_reward_alert=true
      echo "auto_reward_alert=true" >> "$config_file"
    else
      echo "auto_reward_alert=false" >> "$config_file"
    fi
    echo 
  fi

#-----------------------------------------------------------------------------------------------------
# GET AUTOMATED RESTAKING ANSWER FROM THE USER OR TAKE IT FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

  if get_config_value auto_restaking
  then
    if [ "$global_value" = "true" ]
    then
      auto_restaking=true
    fi
  else
    if $at
    then
      exit 2
    fi
    if get_user_answer_yn "DO YOU WANT AUTOBOT TO AUTO RESTAKE YOUR REWARDS"
    then
      auto_restaking=true
      echo "auto_restaking=true" >> "$config_file"
    else
      echo "auto_restaking=false" >> "$config_file"
    fi
    echo 
  fi

#-----------------------------------------------------------------------------------------------------
# GET THE RESTAKING PERCENTAGE FROM THE USER OR TAKE IT FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

  if $auto_restaking
  then
    if get_config_value restakingpercentage
    then
      restakingpercentage="$global_value"
    else
      if $at
      then
        exit 2
      fi
      read -p "PLEASE SET YOUR RESTAKING PERCENTAGE: " -e restakingpercentage
      echo "restakingpercentage=$restakingpercentage" >> "$config_file"
      echo 
    fi

#-----------------------------------------------------------------------------------------------------
# GET RESTAKING NOTIFCATIONS ANSWER FROM THE USER OR TAKE IT FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

    if get_config_value auto_restaking_alert
    then
      if [ "$global_value" = "true" ]
      then
        auto_restaking_alert=true
      fi
    else
      if $at
      then
        exit 2
      fi
      if get_user_answer_yn "DO YOU WANT TO RECEIVE RESTAKING NOTIFICATIONS"
      then
        auto_restaking_alert=true
        echo "auto_restaking_alert=true" >> "$config_file"
      else
        echo "auto_restaking_alert=false" >> "$config_file"
      fi
      echo 
    fi
  fi
fi

#-----------------------------------------------------------------------------------------------------
# GET BP MONITORING ANSWER FROM THE USER OR TAKE IT FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

if get_config_value bp_monitoring
then
  if [ "$global_value" = "true" ]
  then
    bp_monitoring=true
  fi
else
  if $at
  then
    exit 2
  fi
  if get_user_answer_yn "DO YOU WANT AUTOBOT TO ACTIVATE BP MONITORING"
  then
    bp_monitoring=true
    echo "bp_monitoring=true" >> "$config_file"
  else
    echo "bp_monitoring=false" >> "$config_file"
  fi
  echo 
fi

#-----------------------------------------------------------------------------------------------------
# CHECK IF THE LINE IS ALREADY ON CRON, IF NOT ADD IT INSIDE
#-----------------------------------------------------------------------------------------------------

if $bp_monitoring
then
  if [ ! -f "$bp_monitor_script_path" ]
  then
    create_bp_monitor_files
  fi
fi
    
#-----------------------------------------------------------------------------------------------------
# GET TELEGRAM TOKEN FROM THE USER OR TAKE IT FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

if $auto_vote_alert || $auto_reward_alert || $auto_restaking_alert || $bp_monitoring
then
  if get_config_value telegram_token
  then
    telegram_token="$global_value"
  else
    if $at
    then
      exit 2
    fi
    read -p "COPY AND PASTE YOUR TELEGRAM TOKEN: " -e telegram_token
    echo "telegram_token=$telegram_token" >> "$config_file"
    echo 
  fi

#-----------------------------------------------------------------------------------------------------
# GET TELEGRAM CHAT ID FROM THE USER OR TAKE IT FROM THE CONFIG FILE
#-----------------------------------------------------------------------------------------------------

if get_config_value telegram_chatid
  then
    telegram_chatid="$global_value"
  else
    if $at
    then
      exit 2
    fi
    read -p "COPY AND PASTE YOUR TELEGRAM CHAT ID: " -e telegram_chatid
    echo "telegram_chatid=$telegram_chatid" >> "$config_file"
    echo 
  fi
fi

#-----------------------------------------------------------------------------------------------------
# REMCLI COMMANDS FOR UNLOCKING YOUR WALLET
#-----------------------------------------------------------------------------------------------------

output=$(remcli wallet unlock --password $walletpassword 2>&1)
if ! $at; then echo $output; fi

#-----------------------------------------------------------------------------------------------------
# REMCLI COMMAND FOR CASTING YOUR VOTES
#-----------------------------------------------------------------------------------------------------

if $auto_vote
then
  output=$(remcli system voteproducer prods $owneraccountname $bpaccountnames -p $owneraccountname@vote -f 2>&1)
  if ! $at; then echo $output; fi
  if [[ ! "$output" =~ "executed transaction" ]]; then vote_failed=true; fi
fi
  
#-----------------------------------------------------------------------------------------------------
# REMCLI COMMAND FOR CLAIMING YOUR REWARDS
#-----------------------------------------------------------------------------------------------------

if $auto_reward
then
  previous=$(remcli get currency balance rem.token $owneraccountname | awk '{print $1}')
  output=$(remcli system claimrewards $owneraccountname -x 120 -p $owneraccountname@claim -f 2>&1)
  if ! $at; then echo $output; fi
  if [[ "$output" =~ "already claimed rewards" ]]; then reward_failed=true; fi
  after=$(remcli get currency balance rem.token $owneraccountname  | awk '{print $1}')
  total_reward=$(echo "$after - $previous"|bc)
fi
  
#-----------------------------------------------------------------------------------------------------
# REMCLI COMMAND FOR RESTAKING YOUR REWARDS
#-----------------------------------------------------------------------------------------------------

if $auto_restaking
then
  if (( restakingpercentage == 100 ))
  then
    restake_reward="$total_reward"
  else
    restake_reward=$(echo "scale=4; ( $total_reward / 100 ) * $restakingpercentage" | bc )
  fi
  output=$(remcli system delegatebw $owneraccountname $owneraccountname "$restake_reward REM" -x 120 -p $owneraccountname@stake -f 2>&1)
  if ! $at; then echo $output; fi
  if [[ ! "$output" =~ "executed transaction" ]]; then restaking_failed=true; fi
fi

#-----------------------------------------------------------------------------------------------------
# PREPARE NOTIFCATIONS TO SEND TO TELEGRAM
#-----------------------------------------------------------------------------------------------------

if [ ! -z "$telegram_chatid" ]
then
  telegram_message="
"${owneraccountname^}" Daily Summary
--------------------------------------
Date: $(date +"%d-%m-%Y")"
  if $reward_failed
  then
    telegram_message="$telegram_message
Claimed Rewards: Failed"
    send_message=true
  elif $auto_reward_alert
  then
    telegram_message="$telegram_message
Claimed Rewards: $total_reward REM"
    send_message=true
  fi
  if $restaking_failed
  then
    telegram_message="$telegram_message
Restaked Rewards: Failed"
    send_message=true
  elif $auto_restaking_alert
  then
    telegram_message="$telegram_message
Restaked Rewards: $restake_reward REM"
    send_message=true
  fi
  if $vote_failed
  then
    telegram_message="$telegram_message
Block Producer Votes: Failed"
    send_message=true
  elif $auto_vote_alert
  then
    telegram_message="$telegram_message
Block Producer Votes: $bpaccountnames"
    send_message=true
  fi
  
#-----------------------------------------------------------------------------------------------------
# SEND ALERT NOTIFCATIONS TO TELEGRAM BOT (IF THERE'S SOMETHING TO SEND)
#-----------------------------------------------------------------------------------------------------
 
  if $send_message
  then
    sleep 120 #Wait to mins before sending the notification
    curl -s -X POST https://api.telegram.org/bot$telegram_token/sendMessage -d chat_id=$telegram_chatid -d text="$telegram_message" &>/dev/null
  fi
fi
