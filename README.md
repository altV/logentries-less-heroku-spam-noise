# logentries-less-heroku-spam-noise
Decrease the number of useless Logentries notifications across Heroku applications

Hi.

This script works like this: you select your heroku applications that have Logentries addon with default alert settings.

If you think that these applications should send less emails, that is when you have other monitoring means and only want to know when application is actually went down, then run:

./go.rb app-name-1 app-name-2 app-name-3

It will open browser, wait for you to login to Heroku console, then walk over all apps and will try to visit Logentries page to grab API token.
Then it will try to update Alert mail settings for each Logentries token.

Regards,
Leo
