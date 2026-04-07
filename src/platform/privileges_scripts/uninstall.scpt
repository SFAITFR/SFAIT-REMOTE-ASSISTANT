set sh1 to "launchctl unload -w /Library/LaunchDaemons/fr.sfait.remoteassistant_service.plist;"
set sh2 to "/bin/rm /Library/LaunchDaemons/fr.sfait.remoteassistant_service.plist;"
set sh3 to "/bin/rm /Library/LaunchAgents/fr.sfait.remoteassistant_server.plist;"

set sh to sh1 & sh2 & sh3
do shell script sh with prompt "SFAIT Remote Assistant wants to unload daemon" with administrator privileges
