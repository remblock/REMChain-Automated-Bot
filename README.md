# REMChain-Automated-Voting-Script

**Step 1: Create a bot using BotFather**

The following steps describe how to create a new bot:

* Contact `@BotFather` in your Telegram messenger
* To get a token, send BotFather a message that says `/newbot`
* When asked for a name for your new bot choose something that ends with the word bot. For example, my_test_bot
* If your chosen name is available, BotFather will send you a token
* Save the token

Once your bot is created, you can set a name profile photo and description for it. Description is a message which shown in middle of the profile page usually describing what the bot can do.

**To set the Bot name in BotFather do the following:**

* Send `/setname` to BotFather
* Select the bot which you want to change.
* Send the new name to BotFather.

**To set a Profile photo for your bot in BotFather do the following:**

* Send `/setuserpic` to BotFather
* Select the bot for which you are writing a Description
* Send the photo to BotFather

**To set Description for your bot in BotFather do the following:**

* Send `/setdescription` to BotFather
* Select the bot for which you are writing a Description
* Change the description and send it to BotFather

There are some other useful methods in BotFather which we won't cover in this tutorial like `/setcommands` and other.

**Step 2: Obtain your Chat Identification Number**

To get the chat ID, open the following URL in your web-browser: 

`https://api.telegram.org/bot<TOKEN>/getUpdates` > replace `<TOKEN>` with your bot token

Your chat ID will be shown in this format `"id":7041782343`

**Step 3: Download and install the voting script**

```
sudo wget https://github.com/SooSDExZ/REMChain-Voting-Script/raw/master/vote.sh && sudo chmod u+x vote.sh && sudo ./vote.sh
```
