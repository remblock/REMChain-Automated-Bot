# REMChain-Automated-Bot

REMChain-Automated-Bot is a fully customisable script that manages and monitors your REMChain node. It allows Guardians and Producers the flexibility to choose whether to have their votes, claims and even a percentage of their claimed rewards restaked or transfered out automatically every 24 hours. Furthermore it also has a built in monitor that monitors and warns your by telegram is your REMChain node problems within the set interval period.<br>
<br>

***
<br>

# Step 1: Create Telegram Bot Using Botfather
<br>

**The following steps describe how to create a new bot:**

* Contact [**@BotFather**](https://telegram.me/BotFather) in your Telegram messenger.
* To get a token, send BotFather a message that says **`/newbot`**.
* When asked for a name for your new bot choose something that ends with the word bot, so for example my_test_bot.
* If your chosen name is available, BotFather will then send you a token.
* Save this token as you will be asked for it once you execute the script.

Once your bot is created, you can set a custom name, profile photo and description for it. The description is basically a message that explains what the bot can do.

**To set the Bot name in BotFather do the following:**

* Send **`/setname`** to BotFather.
* Select the bot which you want to change.
* Send the new name to BotFather.

**To set a Profile photo for your bot in BotFather do the following:**

* Send **`/setuserpic`** to BotFather.
* Select the bot that you want the profile photo changed on.
* Send the photo to BotFather.

**To set Description for your bot in BotFather do the following:**

* Send **`/setdescription`** to BotFather.
* Select the bot for which you are writing a description.
* Change the description and send it to BotFather.

There are some other useful methods in BotFather which we won't cover in this tutorial like **`/setcommands`**.
<br>
<br>

***
<br>

# Step 2: Obtain Your Chat Idenification Number
<br>
Theres two ways to retrieve your Chat ID, the first is by opening the following URL in your web-browser: 

[**https://api.telegram.org/botTOKEN/getUpdates**](https://api.telegram.org/botTOKEN/getUpdates) then replace the **`TOKEN`** with your actual bot token.

Your Chat ID will be shown in this format **`"id":7041782343`**, based on this example your Chat ID would of been **`7041782343`**. The second way that this can be done is through a third party telegram bot called [**@get_id_bot**](https://telegram.me/get_id_bot).
<br>
<br>

***
<br>

# Step 3: Download The Scripts Required For Monitoring and Managing Your Guardian Or Producer.
<br>

**`AUTOBOT 1: MONITORING AND MANAGING PRODUCER`**

```
sudo wget https://github.com/SooSDExZ/REMChain-Automated-Bot/raw/master/autobot1 && sudo chmod u+x autobot1 && sudo ./autobot1 --at
```
```
sudo ./autobot1
```
<br>

**Please Note: You will need to change the default key permissions in remblock/autobot1/config file.**
<br>

***

<br>

**`AUTOBOT 2: MANAGING GUARDIAN 1`**

```
sudo wget https://github.com/SooSDExZ/REMChain-Automated-Bot/raw/master/autobot2 && sudo chmod u+x autobot2 && sudo ./autobot2 --at
```
```
sudo ./autobot2
```
<br>

**Please Note: You will need to change the default key permissions in remblock/autobot2/config file.**
<br>

***

<br>

**`AUTOBOT 3: MANAGING GUARDIAN 2`**

```
sudo wget https://github.com/SooSDExZ/REMChain-Automated-Bot/raw/master/autobot3 && sudo chmod u+x autobot3 && sudo ./autobot3 --at
```
```
sudo ./autobot3
```
<br>

**Please Note: You will need to change the default key permissions in remblock/autobot3/config file.**
<br>

***

<br>

**`AUTOBOT 4: MANAGING GUARDIAN 3`**

```
sudo wget https://github.com/SooSDExZ/REMChain-Automated-Bot/raw/master/autobot4 && sudo chmod u+x autobot4 && sudo ./autobot4 --at
```
```
sudo ./autobot4
```
<br>

**Please Note: You will need to change the default key permissions in remblock/autobot4/config file.**
<br>

***

<br>

**`AUTOBOT 5: MANAGING GUARDIAN 4`**

```
sudo wget https://github.com/SooSDExZ/REMChain-Automated-Bot/raw/master/autobot5 && sudo chmod u+x autobot5 && sudo ./autobot5 --at
```
```
sudo ./autobot5
```
<br>

**Please Note: You will need to change the default key permissions in remblock/autobot5/config file.**
<br>

***

<br>

**`AUTOBOT 6: MANAGING GUARDIAN 5`**

```
sudo wget https://github.com/SooSDExZ/REMChain-Automated-Bot/raw/master/autobot6 && sudo chmod u+x autobot6 && sudo ./autobot6 --at
```
```
sudo ./autobot6
```
<br>

**Please Note: You will need to change the default key permissions in remblock/autobot6/config file.**
<br>

***

<br>

**`AUTOBOT 7: MANAGING GUARDIAN 6`**

```
sudo wget https://github.com/SooSDExZ/REMChain-Automated-Bot/raw/master/autobot7 && sudo chmod u+x autobot7 && sudo ./autobot7 --at
```
```
sudo ./autobot7
```
<br>

**Please Note: You will need to change the default key permissions in remblock/autobot7/config file.**
<br>

***

<br>

**`AUTOBOT 8: MANAGING GUARDIAN 7`**

```
sudo wget https://github.com/SooSDExZ/REMChain-Automated-Bot/raw/master/autobot8 && sudo chmod u+x autobot8 && sudo ./autobot8 --at
```
```
sudo ./autobot8
```
<br>

**Please Note: You will need to change the default key permissions in remblock/autobot8/config file.**
<br>

***

<br>

**`AUTOBOT 9: MANAGING GUARDIAN 8`**

```
sudo wget https://github.com/SooSDExZ/REMChain-Automated-Bot/raw/master/autobot9 && sudo chmod u+x autobot9 && sudo ./autobot9 --at
```
```
sudo ./autobot9
```
<br>

**Please Note: You will need to change the default key permissions in remblock/autobot9/config file.**
<br>

***

<br>

**`AUTOBOT 10: MANAGING GUARDIAN 9`**

```
sudo wget https://github.com/SooSDExZ/REMChain-Automated-Bot/raw/master/autobot10 && sudo chmod u+x autobot10 && sudo ./autobot10 --at
```
```
sudo ./autobot10
```
<br>

**Please Note: You will need to change the default key permissions in remblock/autobot10/config file.**
<br>

***

<br>

**`AUTOBOT 11: MANAGING GUARDIAN 10`**

```
sudo wget https://github.com/SooSDExZ/REMChain-Automated-Bot/raw/master/autobot8 && sudo chmod u+x autobot11 && sudo ./autobot11 --at
```
```
sudo ./autobot11
```
<br>

**Please Note: You will need to change the default key permissions in remblock/autobot11/config file.**
