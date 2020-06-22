# openMenuIfCancelled
openMenuIfCancelled() {
pressed=$1
case $pressed in
  1)
    echo "Cancelled"
    echo "Returning to the menu..."
    sleep 1
    /home/joinmarket/menu.sh
    exit 1;;
  255)
    echo "ESC pressed."
    echo "Returning to the menu..."
    sleep 1
    /home/joinmarket/menu.sh
    exit 1;;
esac
}

# chooseWallet
chooseWallet() {
wallet=$(tempfile 2>/dev/null)
dialog --backtitle "Choose a wallet" \
--title "Choose a wallet by typing the full name of the file" \
--fselect "/home/joinmarket/.joinmarket/wallets/" 10 60 2> $wallet
openMenuIfCancelled $?
}
