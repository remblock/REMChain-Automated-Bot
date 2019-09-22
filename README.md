# REMChain-Automated-Voting-Bot
<br>

**Step 1: Create a bot using BotFather**

The following steps describe how to create a new bot:

* Contact **`@BotFather`** in your Telegram messenger.
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

***

**Step 2: Obtain your Chat Identification Number**

To get your Chat ID, open the following URL in your web-browser: 

[https://api.telegram.org/bot"TOKEN"/getUpdates](https://api.telegram.org/bot"TOKEN"/getUpdates) > replace **`"TOKEN"`** with your bot token.

Your Chat ID will be shown in this format **`"id":7041782343`**

***

**Step 3: Download and install the voting script in root**
<br>
<br>
```
sudo wget https://github.com/SooSDExZ/REMChain-Automated-Voting-Script/raw/master/vote.sh && sudo chmod u+x vote.sh && sudo ./vote.sh
```
_NOTE: This will only work if you have either setup your key permissions through my Setup-Your-Key-Management scripts or recently used my latest REMChain-Testnet-Guide scripts._
