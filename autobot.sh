#!/bin/bash

#If not root, exit the script
if (($EUID!=0))
then
  echo "You must be root to run this script" 2>&1
  exit 1
fi

#CONFIGURATION VARIABLES
#directory to create
create_dir="/root/remblock/autobot"
#config file
config_file="/root/remblock/autobot/config"
bp_monitor_script_path="/root/remblock/autobot/bpmonitor.sh"
bp_monitor_config_path="/root/remblock/autobot/bp-monitor-config.conf"
#telegram message to send
#check at the end of the script to change the messages
#minutes to wait between executions of the script, 1440 min is 24 hours. recommended 2 mins to avoid possible round up errors
minutes_to_wait=1442
#BP monitoring cron line
bp_mon_cron_line="* * * * * /root/remblock/autobot/bpmonitor.sh"

#Initiate boolean variables
auto_vote=false
auto_reward=false
auto_restaking=false
auto_vote_noti=false
auto_reward_noti=false
auto_restaking_noti=false
bp_monitoring=false

#Verify if the required packages are isntalled, if not install them
if ! dpkg -l | awk '{print $2}' | grep -w at &>/dev/null
then
  echo "at package not installed, installing it..."
  apt-get install at -y
fi

if ! dpkg -l | awk '{print $2}' | grep -w bc &>/dev/null
then
  echo "bc package not installed, installing it..."
  apt-get install bc -y
fi

#check if at mode must be enabled (in order to not print any output)
at=false
if [[ "$1" == "--at" ]]
then
  at=true
  #Setup next execution
at now + $minutes_to_wait minutes << DOC &>/dev/null
/root/remblock/autobot/autobot.sh --at
DOC
fi

#Create the directory if it does not exist
if [ ! -d "$create_dir" ]
then
  mkdir -p "$create_dir"
fi

#Create the config file if it does not exists
if [ ! -f "$config_file" ]
then
  echo "#Configuration file for the autobot.sh script" > "$config_file"
  echo "#Make the entries as variable=value" >> "$config_file"
  echo  >> "$config_file"
fi

#FUNCTION DEFINITIONS
function get_user_answer_yn(){
  while :
  do
    read -p "$1 (y/n): " answer
    answer="$(echo $answer | tr '[:upper:]' '[:lower:]')"  
    case "$answer" in
      yes|y) return 0 ;;
      no|n) return 1 ;;
      *) echo  "  Invalid answer, (yes/y/no/n expected)";continue;;
    esac
  done
}

function get_config_value(){
  #global value is used as an global variable to return the result
  global_value=$(grep -v '^#' "$config_file" | grep "^$1=" | awk -F '=' '{print $2}')
  if [ -z "$global_value" ]
  then
    return 1
  else
    return 0
  fi
}

function create_bp_monitor_files(){
cat << 'DOC' > $bp_monitor_script_path
#!/bin/bash

#---------------------------------
# SETUP
#---------------------------------

# load variables from config
source "/root/remblock/autobot/bp-monitor-config.conf"

# config file where the telegram details are loaded from
tel_config_file="/root/remblock/autobot/config"

alerts=()
messages=()
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
now_s=$(date -d $now +%s)
now_n=$(date -d $now +%s%N)

#---------------------------------
# GET TELEGRAM CONFIGURATION
#---------------------------------

tel_token="$(grep -v '^#' "$tel_config_file" | grep '^tel_token=' | awk -F '=' '{print $2}')"
tel_id="$(grep -v '^#' "$tel_config_file" | grep '^tel_id=' | awk -F '=' '{print $2}')"

#---------------------------------
# SCHEDULE THIS SCRIPT AS CRON
#---------------------------------

if ! crontab -l | grep -q "$SCRIPT_FILE"
then
  (crontab -l ; echo "* * * * * ${SCRIPT_DIR}/${SCRIPT_FILE} >> ${SCRIPT_DIR}/${SCRIPT_LOG_FILE} 2>&1") | crontab -
fi

#---------------------------------
# LOG FILE STATE TEST & MAINTENANCE
#---------------------------------

log_last_modified_s=$(date -r $NODE_LOG_FILE +%s)
modified_diff=$(( $now_s - $log_last_modified_s ))
log_byte_size=$(stat -c%s $NODE_LOG_FILE)

# if log has not been modified
# within the last 5 minutes
if [ $modified_diff -ge 300 ]; then
    alerts+=( "Node log was last modified $(( modified_diff / 60 )) minutes ago." )
fi

# if log is larger than specified threshold
if [ $(( $log_byte_size / 1000000)) -gt $MAX_LOG_SIZE ]; then
    sudo truncate -s 0 $NODE_LOG_FILE
fi

#---------------------------------
# TEST CHAIN STATE
#---------------------------------

# test "remcli get info" response
get_info_response="$(remcli get info)"

# if response is empty or that of failed connection
if [[ -z "${get_info_response// }" ]] || [[ "Failed" =~ ^$get_info_response ]]; then
    alerts+=( "Failed to receive a response from remcli get info." )
else
    head_block_num="$(jq '.head_block_num | tonumber' <<< ${get_info_response})"
    li_block_num="$(jq '.last_irreversible_block_num | tonumber' <<< ${get_info_response})"
    block_diff=$(( head_block_num - li_block_num ))

    # if the gap between head block and last irreversible
    # is more than 3 minutes, send an alert
    if (( block_diff / 2 / 60 > 3 )); then
        alerts+=( "Current block is ${block_diff} ahead of last irreversible." )
    fi

    # if last irreversible block has not advanced
    if [ $LAST_IRREVERSIBLE_BLOCK_NUM -eq $li_block_num ]; then
        alerts+=( "Last irreversible block is stuck on ${li_block_num}." )
    fi

    # update last irreversible block number
    sed -i "s/last_irreversible_block_num=.*/last_irreversible_block_num=$li_block_num/" $SCRIPT_DIR/$CONFIG_FILE
fi

#---------------------------------
# TEST NET PEER STATE
#---------------------------------

# test "remcli net peers" last handshake time
net_peers_response="$(remcli net peers)"

# if response is empty or that of failed connection
if [[ -z "${net_peers_response// }" ]] || [[ "Failed" =~ ^$net_peers_response ]]; then
    alerts+=( "Failed to receive a response from remcli net peers." )
else
    last_handshake=$(jq '.[0].last_handshake.time | tonumber' <<< ${net_peers_response})

    # if peer time is older than 3 minutes, in nanoseconds
    if [ $last_handshake -eq 0 ] ; then
        alerts+=( "Peer handshake never took place" )
    fi
fi

#---------------------------------
# SEND ALERTS IF PROBLEMS WERE FOUND
#---------------------------------

# if there are alerts
if [ ${#alerts[@]} -gt 0 ]; then

    # if we haven't sent a message recently
    last_alert_s=$(date -d $LAST_ALERT +%s)
    diff_s=$(( $now_s - $last_alert_s ))

    # time difference is in seconds, alert threshold is in minutes
    if [ $diff_s -ge $(( $ALERT_THRESHOLD * 60 )) ]; then

        alert="Alert (${ALERT_THRESHOLD} minute frequency) ---------------------------------------"

        for i in "${alerts[@]}"
        do
            alert="${alert} ${i}"
        done

        alert="${alert} ---------------------------------------"

        #send alert to telegram
        curl -s -X POST https://api.telegram.org/bot$tel_token/sendMessage -d chat_id=$tel_id -d text="$alert" &>/dev/null

        # update the timestamp
        sed -i "s/LAST_ALERT=.*/LAST_ALERT=$now/" $SCRIPT_DIR/$CONFIG_FILE

    fi
fi

#---------------------------------
# SEND DAILY SUMMARY
#---------------------------------

if [ $(date +%H:%M) == $DAILY_STATUS_AT ]; then
    summary="Daily Summary ---------------------------------------"
    summary="${summary} Cron job is still running, scheduled to check in at ${DAILY_STATUS_AT} UTC every day."

    for i in "${messages[@]}"
    do
        summary="${summary} ${i}"
    done

    summary="${summary} ---------------------------------------"

    # send summary to telegram
    curl -s -X POST https://api.telegram.org/bot$tel_token/sendMessage -d chat_id=$tel_id -d text="$summary" &>/dev/null

    # update the timestamp
    sed -i "s/LAST_STATUS=.*/LAST_STATUS=$now/" $SCRIPT_DIR/$CONFIG_FILE
fi
DOC
chmod u+x $bp_monitor_script_path

cat << 'DOC' > $bp_monitor_config_path
NODE_NAME=""
SCRIPT_DIR="/root/remblock/autobot"
SCRIPT_FILE="/root/remblock/autobot/bpmonitor.sh"
SCRIPT_LOG_FILE="log.txt"
CONFIG_FILE="config.conf"
NODE_LOG_FILE="/root/remnode.log"

# log will be emptied
# if size exceeds this definition
# defined in MB
MAX_LOG_SIZE=100

# this cron will run every minute
# but we don't want to receive alerts that often
# defined in minutes
ALERT_THRESHOLD=30

# this script will check in once a day
# to confirm that it is still active
# defined in UTC military time, -4 for eastern
DAILY_STATUS_AT="11:30"

LAST_ALERT="2006-09-04"
LAST_STATUS="2006-09-04"
LAST_IRREVERSIBLE_BLOCK_NUM=0
DOC
}

#MAIN PROGRAM

#get variable values from files or user
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
  if get_user_answer_yn "DO YOU WANT AUTOMATED VOTING"
  then
    auto_vote=true
    echo "auto_vote=true" >> "$config_file"
  else
    echo "auto_vote=false" >> "$config_file"
  fi
  echo 
fi

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
    read -p "BLOCK PRODUCERS TO VOTE FOR: " -e bpaccountnames
    if [ -z "$bpaccountnames" ]
    then
      bpaccountnames="$owneraccountname"
    fi
    echo "bpaccountnames=$bpaccountnames" >> "$config_file"
    echo 
  fi

  if get_config_value auto_vote_noti
  then
    if [ "$global_value" = "true" ]
    then
      auto_vote_noti=true
    fi
  else
    if $at
    then
      exit 2
    fi
    if get_user_answer_yn "DO YOU WANT AUTOMATED VOTING NOTIFICATIONS"
    then
      auto_vote_noti=true
      echo "auto_vote_noti=true" >> "$config_file"
    else
      echo "auto_vote_noti=false" >> "$config_file"
    fi
    echo 
  fi

fi

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
  if get_user_answer_yn "DO YOU WANT AUTOMATED REWARDS"
  then
    auto_reward=true
    echo "auto_reward=true" >> "$config_file"
  else
    echo "auto_reward=false" >> "$config_file"
  fi
  echo 
fi

if $auto_reward
then

  if get_config_value auto_reward_noti
  then
    if [ "$global_value" = "true" ]
    then
      auto_reward_noti=true
    fi
  else
    if $at
    then
      exit 2
    fi
    if get_user_answer_yn "DO YOU WANT AUTOMATED REWARDS NOTIFICATIONS"
    then
      auto_reward_noti=true
      echo "auto_reward_noti=true" >> "$config_file"
    else
      echo "auto_reward_noti=false" >> "$config_file"
    fi
    echo 
  fi

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
    if get_user_answer_yn "DO YOU WANT TO ENABLE AUTOMATED RESTAKING"
    then
      auto_restaking=true
      echo "auto_restaking=true" >> "$config_file"
    else
      echo "auto_restaking=false" >> "$config_file"
    fi
    echo 
  fi

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
      read -p "SET YOUR RESTAKING PERCENTAGE: " -e restakingpercentage
      echo "restakingpercentage=$restakingpercentage" >> "$config_file"
      echo 
    fi

    if get_config_value auto_restaking_noti
    then
      if [ "$global_value" = "true" ]
      then
        auto_restaking_noti=true
      fi
    else
      if $at
      then
        exit 2
      fi
      if get_user_answer_yn "DO YOU WANT AUTOMATED RESTAKING NOTIFICATIONS"
      then
        auto_restaking_noti=true
        echo "auto_restaking_noti=true" >> "$config_file"
      else
        echo "auto_restaking_noti=false" >> "$config_file"
      fi
      echo 
    fi
  fi

fi

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
  if get_user_answer_yn "DO YOU WANT TO ACTIVATE BP MONITORING"
  then
    bp_monitoring=true
    echo "bp_monitoring=true" >> "$config_file"
    create_bp_monitor_files
  else
    echo "bp_monitoring=false" >> "$config_file"
  fi
  echo 
fi

if $bp_monitoring
then
  #Check if line is on cron already, if not add it
  if ! crontab -l | grep -v '^#' | grep bpmonitor.sh &>/dev/null
  then
    (crontab -l; echo "$bp_mon_cron_line" ) | crontab -
  fi
fi

if $auto_vote_noti || $auto_reward_noti || $auto_restaking_noti || $bp_monitoring
then
  if get_config_value tel_token
  then
    tel_token="$global_value"
  else
    if $at
    then
      exit 2
    fi
    read -p "COPY AND PASTE YOUR TELEGRAM TOKEN: " -e tel_token
    echo "tel_token=$tel_token" >> "$config_file"
    echo 
  fi

  if get_config_value tel_id
  then
    tel_id="$global_value"
  else
    if $at
    then
      exit 2
    fi
    read -p "COPY AND PASTE YOUR TELEGRAM CHAT ID: " -e tel_id
    echo "tel_id=$tel_id" >> "$config_file"
    echo 
  fi
fi

if $at
then
  remcli wallet unlock --password $walletpassword &>/dev/null
  if $auto_vote
  then
    remcli system voteproducer prods $owneraccountname $bpaccountnames -p $owneraccountname@vote -f &>/dev/null
  fi
  if $auto_reward
  then
    previous=$(remcli get currency balance rem.token $owneraccountname | awk '{print $1}')
    remcli system claimrewards $owneraccountname -p $owneraccountname@claim -f &>/dev/null
    after=$(remcli get currency balance rem.token $owneraccountname  | awk '{print $1}')
    total_reward=$(echo "$after - $previous"|bc)
  fi
  if $auto_restaking
  then
    if (( restakingpercentage == 100 ))
    then
      restake_reward="$total_reward"
    else
      restake_reward=$(echo "scale=4; ( $total_reward / 100 ) * $restakingpercentage" | bc )
    fi
    remcli system delegatebw $owneraccountname $owneraccountname "$restake_reward REM" -x 120 -p $owneraccountname@stake -f &>/dev/null
  fi
else
  remcli wallet unlock --password $walletpassword
  if $auto_vote
  then
    remcli system voteproducer prods $owneraccountname $bpaccountnames -p $owneraccountname@vote -f
  fi
  if $auto_reward
  then
    previous=$(remcli get currency balance rem.token $owneraccountname | awk '{print $1}')
    remcli system claimrewards $owneraccountname -p $owneraccountname@claim -f
    after=$(remcli get currency balance rem.token $owneraccountname  | awk '{print $1}')
    total_reward=$(echo "$after - $previous"|bc)
  fi
  if $auto_restaking
  then
    if (( restakingpercentage == 100 ))
    then
      restake_reward="$total_reward"
    else
      restake_reward=$(echo "scale=4; ( $total_reward / 100 ) * $restakingpercentage" | bc )
    fi
    remcli system delegatebw $owneraccountname $owneraccountname "$restake_reward REM" -x 120 -p $owneraccountname@stake -f
  fi
fi


if $auto_vote_noti || $auto_reward_noti || $auto_restaking_noti
then
  #Telegram messages configuration
  tel_message_1="Your vote was casted for $bpaccountnames on $(date)"
  tel_message_2="$total_reward REM was received for $owneraccountname on $(date)"
  tel_message_3="$restake_reward REM was restaked for $owneraccountname on $(date)"
  tel_message_4="$total_reward REM was received for $owneraccountname and your vote was casted for $bpaccountnames on $(date)"
  tel_message_5="$total_reward REM was received and $restake_reward REM was restaked for $owneraccountname on $(date)"
  tel_message_6="$restake_reward REM was restaked for $owneraccountname and your vote was casted for $bpaccountnames on $(date)"
  tel_message_7="$total_reward REM was received and $restake_reward REM was restaked for $owneraccountname and your vote was casted for $bpaccountnames on $(date)"

  #Transform notification options into binary
  #first bit is vote, second claim, third restake
  if $auto_vote_noti; then option_bin="1"; else option_bin="0"; fi
  if $auto_reward_noti; then option_bin="${option_bin}1"; else option_bin="${option_bin}0"; fi
  if $auto_restaking_noti; then option_bin="${option_bin}1"; else option_bin="${option_bin}0"; fi

  case "$option_bin" in
    100) tel_message="$tel_message_1";;
    010) tel_message="$tel_message_2";;
    001) tel_message="$tel_message_3";;
    110) tel_message="$tel_message_4";;
    011) tel_message="$tel_message_5";;
    101) tel_message="$tel_message_6";;
    111) tel_message="$tel_message_7";;
      *) tel_message="Error in case stament";;
  esac
  
  #Send notification to telegram
  curl -s -X POST https://api.telegram.org/bot$tel_token/sendMessage -d chat_id=$tel_id -d text="$tel_message" &>/dev/null
fi
