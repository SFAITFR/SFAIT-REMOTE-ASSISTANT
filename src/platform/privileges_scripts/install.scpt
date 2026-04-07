on run {daemon_file, agent_file, user}

  set sh1 to "echo " & quoted form of daemon_file & " > /Library/LaunchDaemons/fr.sfait.remoteassistant_service.plist && chown root:wheel /Library/LaunchDaemons/fr.sfait.remoteassistant_service.plist;"

  set sh2 to "echo " & quoted form of agent_file & " > /Library/LaunchAgents/fr.sfait.remoteassistant_server.plist && chown root:wheel /Library/LaunchAgents/fr.sfait.remoteassistant_server.plist;"

  set user_pref_dir to "/Users/" & user & "/Library/Preferences/fr.sfait.remoteassistant"
  set root_pref_dir to "/var/root/Library/Preferences/fr.sfait.remoteassistant"

  set sh3 to "mkdir -p " & quoted form of root_pref_dir & " && cp -rf " & quoted form of (user_pref_dir & "/SFAIT Remote Assistant.toml") & " " & quoted form of root_pref_dir & ";"

  set sh4 to "mkdir -p " & quoted form of root_pref_dir & " && cp -rf " & quoted form of (user_pref_dir & "/SFAIT Remote Assistant2.toml") & " " & quoted form of root_pref_dir & ";"

  set sh5 to "launchctl load -w /Library/LaunchDaemons/fr.sfait.remoteassistant_service.plist;"

  set sh to sh1 & sh2 & sh3 & sh4 & sh5

  do shell script sh with prompt "SFAIT Remote Assistant wants to install daemon and agent" with administrator privileges
end run
