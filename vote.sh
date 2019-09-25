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
#path to automated vote file
automated_reward_f="$create_dir/automatedreward.txt"
#telegram message to send
#check at the end of the script to change the messages
#line to add to the crontab
cron_line="1 0 * * * /root/vote.sh --cron"

#Check if line is on cron already, if not add it
if ! crontab -l | grep -v '^#' | grep vote.sh &>/dev/null
then
  echo "Crontab line added"
  (crontab -l; echo "$cron_line" ) | crontab -
fi

#check if cron mode must be enabled
cron=false
if [[ "$1" == "--cron" ]]
then
  cron=true
fi

#Create the directory if it does not exist
if [ ! -d "$create_dir" ]
then
  mkdir "$create_dir"
fi

#unused function
function pause(){
      read -p "$*"
}

#get variable values from files or user
if [ -f "$owner_f" ]
then
  owneraccountname=$(cat "$owner_f")
else
  if $cron
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
  if $cron
  then
    exit 2
  fi
  read -p "YOUR WALLET PASSWORD: " -e walletpassword
  echo $walletpassword > "$wallet_f"
  echo 
fi

if [ -f "$bpaccountnames_f" ]
then
  bpaccountnames=$(cat "$bpaccountnames_f")
else
  if $cron
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

if [ -f "$tel_token_f" ]
then
  tel_token=$(cat "$tel_token_f")
else
  if $cron
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
  if $cron
  then
    exit 2
  fi
  read -p "COPY AND PASTE YOUR TELEGRAM CHAT ID: " -e tel_id
  echo $tel_id > "$tel_id_f"
  echo 
fi


if [ -f "$automated_vote_f" ]
then
  automated_vote=$(cat "$automated_vote_f")
else
  if $cron
  then
    exit 2
  fi
  read -p "DO YOU WANT AUTOMATED VOTING (y/n): " -e automated_vote
  automated_vote=$(echo $automated_vote | tr '[:upper:]' '[:lower:]')
  echo $automated_vote > "$automated_vote_f"
  echo 
fi

if [ -f "$automated_reward_f" ]
then
  automated_reward=$(cat "$automated_reward_f")
else
  if $cron
  then
    exit 2
  fi
  read -p "DO YOU WANT AUTOMATED REWARDS (y/n): " -e automated_reward
  automated_reward=$(echo $automated_reward | tr '[:upper:]' '[:lower:]')
  echo $automated_reward > "$automated_reward_f"
  echo 
fi

auto_vote=false
auto_reward=false

if $cron
then
  remcli wallet unlock --password $walletpassword &>/dev/null
  if [[ "$automated_vote" == "y" || "$automated_vote" == "yes" ]] 
  then
    auto_vote=true
    remcli system voteproducer prods $owneraccountname $bpaccountnames -p $owneraccountname@vote &>/dev/null
  fi
  if [[ "$automated_reward" == "y" || "$automated_reward" == "yes" ]] 
  then
    auto_reward=true
    remcli system claimrewards $owneraccountname -p $owneraccountname@claim &>/dev/null
  fi
else
  remcli wallet unlock --password $walletpassword
  if [[ "$automated_vote" == "y" || "$automated_vote" == "yes" ]] 
  then
    auto_vote=true
    remcli system voteproducer prods $owneraccountname $bpaccountnames -p $owneraccountname@vote
  fi
  if [[ "$automated_reward" == "y" || "$automated_reward" == "yes" ]] 
  then
    auto_reward=true
    remcli system claimrewards $owneraccountname -p $owneraccountname@claim
  fi
fi

#Telegram messages configuration
tel_message_1="Your vote was executed for $bpaccountnames on $HOSTNAME at $(date)r"
tel_message_2="Your claim was executed for $owneraccountname on $HOSTNAME at $(date)"
tel_message_3="Your vote was casted for $bpaccountnames and your rewards were claimed for $owneraccountname on $HOSTNAME at $(date)"

#Send notification to telegram
if $auto_vote && $auto_reward
then
  curl -s -X POST https://api.telegram.org/bot$tel_token/sendMessage -d chat_id=$tel_id -d text="$tel_message_3" &>/dev/null
elif $auto_vote
then
  curl -s -X POST https://api.telegram.org/bot$tel_token/sendMessage -d chat_id=$tel_id -d text="$tel_message_1" &>/dev/null
elif $auto_reward
then
  curl -s -X POST https://api.telegram.org/bot$tel_token/sendMessage -d chat_id=$tel_id -d text="$tel_message_2" &>/dev/null
fi
