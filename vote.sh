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
#telegram message to send
tel_message="$0 executed on $HOSTNAME at $(date)"
#line to add to the crontab
cron_line="*/15 * * * * /root/vote.sh --cron"

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
  read -p "VOTE FOR ANOTHER BLOCK PRODUCER: " -e bpaccountnames
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

if $cron
then
  remcli wallet unlock --password $walletpassword &>/dev/null
  remcli system voteproducer prods $owneraccountname $bpaccountnames -p $owneraccountname@vote &>/dev/null
else
  remcli wallet unlock --password $walletpassword
  remcli system voteproducer prods $owneraccountname $bpaccountnames -p $owneraccountname@vote
fi

#Send notification to telegram
curl -s -X POST https://api.telegram.org/bot$tel_token/sendMessage -d chat_id=$tel_id -d text="$tel_message" &>/dev/null
