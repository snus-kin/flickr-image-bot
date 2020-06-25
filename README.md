# Flickr Twitter Bot (in Nim)
Takes a set of tags and posts a random photo to twitter, without duplicates

Example bot: https://twitter.com/BotBiodiversity

## How to install
```bash
$ nimble install flickr_image_bot
$ flickr_image_bot
Config file created
$ vim ~/.config/flickr_image_bot/twitter_bot.cfg
```
Now run `flickr_image_bot` and a post will be made.

## Service files
The files in directory `example-units` outline systemd user timer and service
file pair that runs every 3 hours.

