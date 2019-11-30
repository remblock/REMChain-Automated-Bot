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
transfer_failed=false
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

progress-bar() {

  local duration=${1}
  already_done() { for ((done=0; done<$elapsed; done++)); do printf "▇"; done }
  remaining() { for ((remain=$elapsed; remain<$duration; remain++)); do printf " "; done }
  percentage() { printf "| %s%%" $(( (($elapsed)*100)/($duration)*100/100 )); }
  clean_line() { printf "\r"; }

  for (( elapsed=1; elapsed<=$duration; elapsed++ )); do
      already_done; remaining; percentage
      sleep 1
      clean_line

  done
  clean_line

}


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
# CREATE START AND STOP SERVICES
#-----------------------------------------------------------------------------------------------------

function create_start_stop_service {
  if [ ! -f "$start_server_commands_path" ]
  then
cat << 'DOC' > "$start_server_commands_path"
#!/bin/sh
/usr/bin/nohup /usr/bin/remnode --config-dir /root/config/ --data-dir /root/data/ >>/root/remnode.log 2>>/root/remnode.log &
sleep 30
if ! tail -n1 /root/remnode.log | grep 'on_incoming_block' &>/dev/null
then
   /usr/bin/nohup /usr/bin/remnode --config-dir  /root/config/ --data-dir /root/data/ --replay-blockchain --hard-replay-blockchain --genesis-json genesis.json &
fi
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
Description=RUN AUTOBOT REMCLI COMMANDS AT START AND STOP
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
#This script need to be called via cron every minute

#PATH to used commands
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
#Load configuration variables and values
source "/root/remblock/autobot/config" &>/dev/null
now_epoch="$(date +%s)"
now_date="$(date +%d-%m-%Y)"
owneraccountname="$owner"

#Install crontab line if it does not exists
if [ ! -z "$bpm_cron_cmd" ] && ! crontab -u root -l | grep -v '^ *#' | grep "$bpm_cron_cmd" &>/dev/null
then
  (crontab -u root -l ; echo "*/1 * * * * $bpm_cron_cmd") | crontab -u root -
fi

#Create bpmonitor folder for temporal information
if [ ! -z "$bpm_temp_dir" ] && [ ! -d "$bpm_temp_dir" ]
then
  mkdir "$bpm_temp_dir"
fi

#Function definitions

#Add a message to be sent later, if there are more lines than permited in the queue, delete the older ones
function add_message_to_queue(){
  #If the log is at maximum capacity, delete exceding lines
  if [ -f "$bpm_temp_dir/msg_queue.txt" ] && (( $(wc -l "$bpm_temp_dir/msg_queue.txt" | awk '{print $1}') >= bpm_max_queued_msg_lines ))
  then
    echo "$(tail -$((bpm_max_queued_msg_lines -1)) $bpm_temp_dir/msg_queue.txt)" > $bpm_temp_dir/msg_queue.txt
  fi
  if ! line_repeated "$1"
  then
    echo -e "$1\n" >> "$bpm_temp_dir/msg_queue.txt"
  fi
}

#Check if the last line is repeated
function line_repeated(){
  if grep "$1" "$bpm_temp_dir/msg_queue.txt" &>/dev/null
  then
    return 0
  else
    return 1
  fi
}

#Remove old lines that only change in minutes displayed
#It receives only the base of the line befores the numbers curresponding to time
function remove_lines_repeated_time(){
  sed -i "/^$1/d" "$bpm_temp_dir/msg_queue.txt"
}

#Remove 2 consecutive empty lines before sending the message
function remove_empty_lines(){
  sed -i '/^$/{N;/^\n$/d;}' "$bpm_temp_dir/msg_queue.txt"
}

#Send the queued messages to telegram and empty the queue
function send_telegram_messages(){
  if [ ! -z "$telegram_token" ] && [ ! -z "$telegram_chatid" ]
  then
    remove_empty_lines
    curl -s -X POST https://api.telegram.org/bot$telegram_token/sendMessage -d chat_id=$telegram_chatid -d text="$(echo -e "BP Warning Alert\n--------------------------------------";cat $bpm_temp_dir/msg_queue.txt)" &>/dev/null
    #clean the msg queue file
    > $bpm_temp_dir/msg_queue.txt
    echo $now_epoch > "$bpm_temp_dir/last_send_message_epoch.txt"
  fi
}

#Check warning threshold and send message
function send_warnings(){
  if [ ! -f "$bpm_temp_dir/last_send_message_epoch.txt" ] 
  then
    echo $now_epoch > "$bpm_temp_dir/last_send_message_epoch.txt"
  else
    config_minutes_in_seconds="$((bpm_warning_alert_threshold * 60))"
    last_msg_epoch=$(cat "$bpm_temp_dir/last_send_message_epoch.txt")
    if (( (now_epoch - last_msg_epoch) >= config_minutes_in_seconds )) && (( $(wc -l "$bpm_temp_dir/msg_queue.txt" | awk '{print $1}') > 1 ))
    then
      send_telegram_messages
    fi
  fi
}

#Translate the time format from the remnode log to epoch time
function remnodelogtime_to_epoch(){
  temp_date="$( echo $1 | awk -F '.' '{ print $1}' | tr '-' '/' | tr 'T' ' ')"
  echo $(date "+%s" -d "$temp_date")
}

#Function that checks if whether the node has actual produced a block within the past configured max minutes.
function check_produce_minutes(){
  last_block_date=$(grep -i "produce_block" $bpm_remnode_log | sed -n '$p' | awk '{print $2}')
  last_block_epoch=$(remnodelogtime_to_epoch "$last_block_date")
  config_minutes_in_seconds="$((bpm_check_produce_minutes * 60))"
  if (( (now_epoch - last_block_epoch) >= config_minutes_in_seconds ))
  then
    remove_lines_repeated_time "$owneraccountname last produced a block"
    add_message_to_queue "$owneraccountname last produced a block "$(((now_epoch - last_block_epoch)/60))" minutes ago."
  fi
}

#Function that checks whether the remnode.log file has been modified within the past configured max minutes
function check_log_minutes(){
  last_write_epoch=$(date +%s -r "$bpm_remnode_log")
  config_minutes_in_seconds="$(( bpm_check_log_minutes * 60))"
  if (( (now_epoch - last_write_epoch) >= config_minutes_in_seconds ))
  then
    remove_lines_repeated_time "$owneraccountname log file was last modified"
    add_message_to_queue "$owneraccountname log file was last modified "$(((now_epoch - last_write_epoch)/60))" minutes ago"
  fi
}


#Function that checks the condition of the remnode chain
function check_remnode_chain(){
  if ! timeout 10s remcli get info 2>&1 | grep server_version &>/dev/null
  then
    add_message_to_queue "$owneraccountname failed to receive a response from \"remcli get info\""
  fi
}

#Function that checks gap between head block (head_block_num) and last irreversible block (last_irreversible_block_num) to see if it has been more than the configured minutes
function check_block_minutes(){
  if ! timeout 10s remcli get info 2>&1 | grep server_version &>/dev/null
  then
    add_message_to_queue "$owneraccountname failed to receive a response from \"remcli get info\""
    return
  fi
  last_block_id="$(remcli get info | grep -w 'head_block_num' | awk '{print $2}' | tr -d ',')"
  last_irr_block_id="$(remcli get info | grep -w 'last_irreversible_block_num' | awk '{print $2}' | tr -d ',')"
  last_block_date=$(grep -i "#$last_block_id" $bpm_remnode_log | sed -n '$p' | awk '{print $2}')
  last_irr_block_date=$(grep -i "#$last_irr_block_id" $bpm_remnode_log | sed -n '$p' | awk '{print $2}')
  last_block_epoch=$(remnodelogtime_to_epoch "$last_block_date")
  last_irr_block_epoch=$(remnodelogtime_to_epoch "$last_irr_block_date")
  config_minutes_in_seconds="$((bpm_check_block_minutes * 60))"
  if (( ( last_block_epoch - last_irr_block_epoch ) >= config_minutes_in_seconds ))
  then
    remove_lines_repeated_time "$owneraccountname current block is"
    add_message_to_queue "$owneraccountname current block is $(((last_block_epoch - last_irr_block_epoch)/60)) ahead of last irreversible."
  fi
}

#Function that checks if the last irreversible block has not advanced.
function check_last_iblock(){
  if ! timeout 10s remcli get info 2>&1 | grep server_version &>/dev/null
  then
    add_message_to_queue "$owneraccountname failed to receive a response from \"remcli get info\""
    return
  fi
  if [ ! -f "$bpm_temp_dir/last_iblock.txt" ]
  then
    last_irr_block_id="$(remcli get info | grep -w 'last_irreversible_block_num' | awk '{print $2}' | tr -d ',')"
    echo "$last_irr_block_id" > "$bpm_temp_dir/last_iblock.txt"
  else
    last_block_id=$(cat "$bpm_temp_dir/last_iblock.txt")
    last_irr_block_id="$(remcli get info | grep -w 'last_irreversible_block_num' | awk '{print $2}' | tr -d ',')"
    if [ "$last_block_id" == "$last_irr_block_id" ]
    then
      remove_lines_repeated_time "$owneraccountname last irreversible block is stuck on"
      add_message_to_queue "$owneraccountname last irreversible block is stuck on ${last_irr_block_id}."
    else
      echo "$last_irr_block_id" > "$bpm_temp_dir/last_iblock.txt"
    fi
  fi
}

#Function that tests the "remcli net peers" command for the last handshake time, if the peer time is older than the configured minutes
function check_net_peers(){
  if ! timeout 10 remcli net peers | grep head_id &>/dev/null
  then
    add_message_to_queue "$owneraccountname failed to receive a response from \"remcli net peers\""
    return
  fi
  last_hand_shake_time_ns="$(remcli net peers | grep time | sed -n '1p' | awk '{print $2}' | tr -d '",')"
  #removing nanoseconds for calculations
  last_hand_shake_epoch="${last_hand_shake_time_ns:-9}"
  config_minutes_in_seconds="$((bpm_check_peers_minutes * 60))"
  if (( ( now_epoch - last_hand_shake_epoch ) >= config_minutes_in_seconds ))
  then
    add_message_to_queue "$owneraccountname peer handshake never took place."
  fi
}

#Send alerts if disk or ram exceeds the threshold
function check_disk_and_ram(){
  ram_used_perc="$(free | grep Mem | awk '{print $3/$2 * 100.0}' | awk -F '.' '{print $1}')"
  max_ram="$(echo $bpm_ram_usage_threshold | tr -d '%' )"
  disk_used_perc="$(df -h | grep -w '/' | awk '{print $5}' | tr -d '%')"
  max_disk="$(echo $bpm_disk_space_threshold | tr -d '%' )"
  if (( ram_used_perc >= max_ram ))
  then
    add_message_to_queue "$owneraccountname ram usage is over the specified threshold amount."
  fi
  if (( disk_used_perc >= max_disk ))
  then
    add_message_to_queue "$owneraccountname disk usage is over the specified threshold amount."
  fi
}

#MAIN SCRIPT

if [ "$(echo $bpm_check_producer | tr '[:upper:]' '[:lower:]' )" == "true" ]
then 
  check_produce_minutes
fi

if [ "$(echo $bpm_check_log | tr '[:upper:]' '[:lower:]' )" == "true" ]
then 
  check_log_minutes
fi

if [ "$(echo $bpm_check_info | tr '[:upper:]' '[:lower:]' )" == "true" ]
then 
  check_remnode_chain
fi

if [ "$(echo $bpm_check_blocks | tr '[:upper:]' '[:lower:]' )" == "true" ]
then 
  check_block_minutes
fi

if [ "$(echo $bpm_check_irr_blocks | tr '[:upper:]' '[:lower:]' )" == "true" ]
then 
  check_last_iblock
fi

if [ "$(echo $bpm_check_peers | tr '[:upper:]' '[:lower:]' )" == "true" ]
then 
  check_net_peers
fi

if [ "$(echo $bpm_check_server | tr '[:upper:]' '[:lower:]' )" == "true" ]
then 
  check_disk_and_ram
fi

send_warnings
DOC

chmod u+x $bp_monitor_script_path

#-----------------------------------------------------------------------------------------------------
# CREATE BP MONITOR CONFIG FILE
#-----------------------------------------------------------------------------------------------------

if ! grep 'bpm_temp_dir' "$bp_monitor_config_path" &>/dev/null
then
cat << 'DOC' >> "$bp_monitor_config_path"
bpm_cron_cmd="/root/remblock/autobot/bpmonitor.sh"
bpm_temp_dir="/root/remblock/autobot/bpmonitor_temp"
bpm_remnode_log="/root/remnode.log"
bpm_warning_alert_threshold=3
bpm_check_produce_minutes=3
bpm_max_queued_msg_lines=50
bpm_check_log_minutes=3
bpm_check_block_minutes=3
bpm_check_peers_minutes=3
bpm_ram_usage_threshold=80
bpm_disk_space_threshold=80
bpm_check_producer=True
bpm_check_log=False
bpm_check_info=False
bpm_check_blocks=False
bpm_check_irr_blocks=False
bpm_check_peers=False
bpm_check_server=True
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


#Fill possible missing config variables

if get_config_value vote_permission 
then
  vote_permission="$global_value"
else
  vote_permission="producer"
  echo "vote_permission=$vote_permission" >> "$config_file"
fi

if get_config_value claim_permission
then
  claim_permission="$global_value"
else
  claim_permission="producer"
  echo "claim_permission=$claim_permission" >> "$config_file"
fi

if get_config_value stake_permission
then
  stake_permission="$global_value"
else
  stake_permission="producer"
  echo "stake_permission=$stake_permission" >> "$config_file"
fi

if get_config_value transfer_permission
then
  transfer_permission="$global_value"
else
  transfer_permission="transfer"
  echo "transfer_permission=$transfer_permission" >> "$config_file"
fi

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
# GET VOTING NOTIFCATION ANSWER FROM THE USER OR TAKE IT FROM THE CONFIG FILE
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
# GET REWARD NOTIFCATION ANSWER FROM THE USER OR TAKE IT FROM THE CONFIG FILE
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
    restakingpercentage=$(echo $restakingpercentage | tr -d '%' )
    
#-----------------------------------------------------------------------------------------------------
# GET RESTAKING NOTIFCATION ANSWER FROM THE USER OR TAKE IT FROM THE CONFIG FILE
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

  if get_config_value auto_transfer
  then
    if [ "$global_value" = "true" ]
    then
      auto_transfer=true
      if get_config_value auto_transfer_acct
      then
        auto_transfer_acct="$global_value"
      else
        echo "ERROR: auto_transfer_acct must be set when using auto_transfer"
	exit 1
      fi
      if get_config_value auto_transfer_perc
      then
        auto_transfer_perc="$global_value"
      else
        echo "ERROR: auto_transfer_perc must be set when using auto_transfer"
	exit 1
      fi
    fi
  else
    if $at
    then
      exit 2
    fi
    if get_user_answer_yn "DO YOU WANT AUTOBOT TO AUTO TRANSFER YOUR REWARDS"
    then
      auto_transfer=true
      echo "auto_transfer=true" >> "$config_file"
      echo
      read -p "PLEASE SET YOUR TRANSFER ACCOUNT NAME: " auto_transfer_acct
      echo "auto_transfer_acct=$auto_transfer_acct" >> "$config_file"
      echo
      read -p "PLEASE SET YOUR TRANSFER PERCENTAGE: " auto_transfer_perc
      echo "auto_transfer_perc=$auto_transfer_perc" >> "$config_file"
    else
      echo "auto_restaking=false" >> "$config_file"
    fi
    echo 
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
#Uncomment if you want the output of the command printed
#if ! $at; then echo $output; fi

#-----------------------------------------------------------------------------------------------------
# REMCLI COMMAND FOR CASTING YOUR VOTES
#-----------------------------------------------------------------------------------------------------

if $auto_vote
then
  output=$(remcli system voteproducer prods $owneraccountname $bpaccountnames -p $owneraccountname@$vote_permission -f 2>&1)
  #Uncomment if you want the output of the command printed
  #if ! $at; then echo $output; fi
  if [[ ! "$output" =~ "executed transaction" ]]; then vote_failed=true; fi
fi
  
#-----------------------------------------------------------------------------------------------------
# REMCLI COMMAND FOR CLAIMING YOUR REWARDS
#-----------------------------------------------------------------------------------------------------

if $auto_reward
then
  previous=$(remcli get currency balance rem.token $owneraccountname | awk '{print $1}')
  output=$(remcli system claimrewards $owneraccountname -x 120 -p $owneraccountname@$claim_permission -f 2>&1)
  #Uncomment if you want the output of the command printed
  #if ! $at; then echo $output; fi
  if [[ "$output" =~ "already claimed rewards" ]]; then reward_failed=true; fi
  after=$(remcli get currency balance rem.token $owneraccountname  | awk '{print $1}')
  total_reward=$(echo "$after - $previous"|bc)
fi

if $auto_transfer
then
  output=$(remcli transfer $owneraccountname $auto_transfer_acct "$(( (total_reward*100)/auto_transfer_perc )) REM" -x 120 -p $owneraccountname@$transfer_permission -f 2>&1)
  #Uncomment if you want the output of the command printed
  #if ! $at; then echo $output; fi
  if [[ ! "$output" =~ "executed transaction" ]]; then transfer_failed=true; fi
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
  output=$(remcli system delegatebw $owneraccountname $owneraccountname "$restake_reward REM" -x 120 -p $owneraccountname@$stake_permission -f 2>&1)
  #Uncomment if you want the output of the command printed
  #if ! $at; then echo $output; fi
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

  if $transfer_failed
  then
    telegram_message="$telegram_message
Transfer Rewards: Failed"
    send_message=true
  else
    telegram_message="$telegram_message
Transfer Rewards: $total_reward REM"
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
Voted Block Producers: Failed"
    send_message=true
  elif $auto_vote_alert
  then
    telegram_message="$telegram_message
Voted Block Producers: $bpaccountnames"
    send_message=true
  fi
  
#-----------------------------------------------------------------------------------------------------
# SEND ALERT NOTIFCATIONS TO TELEGRAM BOT (IF THERE'S SOMETHING TO SEND)
#-----------------------------------------------------------------------------------------------------
 
  if $send_message
  then
    #If at option is active, wait without printing the progress bar
    if $at
    then
      sleep 120
    else
      printf  "\n\nWAIT 2 MINUTES FOR THE CONFIRMATION OF THE TRANSACTIONS\n\n"
      progress-bar 112
      printf "\n\n\n"
    fi
    curl -s -X POST https://api.telegram.org/bot$telegram_token/sendMessage -d chat_id=$telegram_chatid -d text="$telegram_message" &>/dev/null
  fi
fi
