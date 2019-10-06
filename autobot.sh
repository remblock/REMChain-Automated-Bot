#!/bin/bash

#If not root, exit the script
if (($EUID!=0))
then
  echo "You must be root to run this script" 2>&1
  exit 3
fi

#CONFIGURATION VARIABLES
#directory to create
create_dir="/root/info"
#path to owner file
owner_f="$create_dir/owneraccountname.txt"
#path to wallet file
wallet_f="$create_dir/walletpassword.txt"
#path to block producers to voy
bpaccountnames_f="$create_dir/bpaccountnames.txt"
#path to telegram token
tel_token_f="$create_dir/telegramtoken.txt"
#path to telegram id
tel_id_f="$create_dir/telegramid.txt"
#path to automated vote file
automated_vote_f="$create_dir/automatedvote.txt"
#path to automated reward file
automated_reward_f="$create_dir/automatedreward.txt"
#path to automated vote notification file
automated_vote_notifications_f="$create_dir/automatedvotenotifications.txt"
#path to automated reward notification file
automated_reward_notifications_f="$create_dir/automatedrewardnotifications.txt"
#path to automated restaking file
automated_restaking_f="$create_dir/automatedrestaking.txt"
#path to automated restaking notification file
automated_restaking_notifications_f="$create_dir/automatedrestakingnotifications.txt"
#path to restaking percentage file
restakingpercentage_f="$create_dir/restakingpercentage.txt"
#telegram message to send
#check at the end of the script to change the messages
#minutes to wait between executions of the script, 1440 min is 24 hours. recommended 2 mins to avoid possible round up errors
minutes_to_wait=1442

#Initiate boolean variables
auto_vote=false
auto_reward=false
auto_restaking=false
auto_vote_noti=false
auto_reward_noti=false
auto_restaking_noti=false

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
/root/autobot.sh --at
DOC
fi

#Create the directory if it does not exist
if [ ! -d "$create_dir" ]
then
  mkdir "$create_dir"
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

#MAIN PROGRAM

#get variable values from files or user
if [ -f "$owner_f" ]
then
  owneraccountname=$(cat "$owner_f")
else
  if $at
  then
    exit 1
  fi
  echo
  read -p "YOUR ACCOUNT NAME: " -e owneraccountname
  echo $owneraccountname > "$owner_f"
  echo 
fi

if [ -f "$wallet_f" ]
then
  walletpassword=$(cat "$wallet_f")
else
  if $at
  then
    exit 2
  fi
  read -p "YOUR WALLET PASSWORD: " -e walletpassword
  echo $walletpassword > "$wallet_f"
  echo 
fi

if [ -f "$automated_vote_f" ]
then
  if [ "$(cat $automated_vote_f)" = "true" ]
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
    echo "true" > "$automated_vote_f"
  else
    echo "false" > "$automated_vote_f"
  fi
  echo 
fi

if $auto_vote
then

  if [ -f "$bpaccountnames_f" ]
  then
    bpaccountnames=$(cat "$bpaccountnames_f")
  else
    if $at
    then
      exit 2
    fi
    read -p "BLOCK PRODUCERS TO VOTE FOR: " -e bpaccountnames
    if [ -z "$bpaccountnames" ]
    then
      echo $owneraccountname > "$bpaccountnames_f"
      bpaccountnames="$owneraccountname"
    else
      echo $bpaccountnames > "$bpaccountnames_f"
    fi
    echo 
  fi

  if [ -f "$automated_vote_notifications_f" ]
  then
    if [ "$(cat $automated_vote_notifications_f)" = "true" ]
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
      echo "true" > "$automated_vote_notifications_f"
    else
      echo "false" > "$automated_vote_notifications_f"
    fi
    echo 
  fi

fi

if [ -f "$automated_reward_f" ]
then
  if [ "$(cat $automated_reward_f)" = "true" ]
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
    echo "true" > "$automated_reward_f"
  else
    echo "false" > "$automated_reward_f"
  fi
  echo 
fi

if $auto_reward
then

  if [ -f "$automated_reward_notifications_f" ]
  then
    if [ "$(cat $automated_reward_notifications_f)" = "true" ]
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
      echo "true" > "$automated_reward_notifications_f"
    else
      echo "false" > "$automated_reward_notifications_f"
    fi
    echo 
  fi

  if [ -f "$automated_restaking_f" ]
  then
    if [ "$(cat $automated_restaking_f)" = "true" ]
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
      echo "true" > "$automated_restaking_f"
    else
      echo "false" > "$automated_restaking_f"
    fi
    echo 
  fi

  if $auto_restaking
  then
    if [ -f "$restakingpercentage_f" ]
    then
      restakingpercentage=$(cat "$restakingpercentage_f")
    else
      if $at
      then
        exit 2
      fi
      read -p "SET YOUR RESTAKING PERCENTAGE: " -e restakingpercentage
      echo $restakingpercentage > "$restakingpercentage_f"
      echo 
    fi

    if [ -f "$automated_restaking_notifications_f" ]
    then
      if [ "$(cat $automated_restaking_notifications_f)" = "true" ]
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
        echo "true" > "$automated_restaking_notifications_f"
      else
        echo "false" > "$automated_restaking_notifications_f"
      fi
      echo 
    fi
  fi

fi

if $auto_vote_noti || $auto_reward_noti || $auto_restaking_noti
then
  if [ -f "$tel_token_f" ]
  then
    tel_token=$(cat "$tel_token_f")
  else
    if $at
    then
      exit 2
    fi
    read -p "COPY AND PASTE YOUR TELEGRAM TOKEN: " -e tel_token
    echo $tel_token > "$tel_token_f"
    echo 
  fi

  if [ -f "$tel_id_f" ]
  then
    tel_id=$(cat "$tel_id_f")
  else
    if $at
    then
      exit 2
    fi
    read -p "COPY AND PASTE YOUR TELEGRAM CHAT ID: " -e tel_id
    echo $tel_id > "$tel_id_f"
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
    restake_reward=$(echo "( $total_reward / 100 ) * $restakingpercentage" | bc )
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
    restake_reward=$(echo "( $total_reward / 100 ) * $restakingpercentage" | bc )
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
