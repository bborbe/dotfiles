if [[ "$OSTYPE" == "darwin"* ]]; then
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
fi
