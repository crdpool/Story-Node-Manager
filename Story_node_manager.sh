#!/bin/bash

function colors {
  GREEN="\e[32m"
  RED="\e[39m"
  YELLOW="\e[33m"
  NORMAL="\e[0m"
}

function logo {
  curl -s https://raw.githubusercontent.com/crdpool/volatility/refs/heads/main/story-logo.sh | bash
}

logo

# Function to display the menu
function show_menu {
  echo "============================================="
  echo "          Story Node Manager - Crd           "
  echo "============================================="
  echo "1. Install Story Node"
  echo "2. Install Snapshot"
  echo "3. Create Validator"
  echo "4. Update Node"
  echo "5. Delete Node"
  echo "6. View Logs"
  echo "7. Exit"
  echo "============================================="
  echo -n "Enter your choice [1-7]: "
}

# Function to install the node
function install_node {
  echo "🛠️ Proceeding to installing node..."
  sleep 4

  # Updating the VPS
  echo "🛠️ Updating and upgrading the VPS..."
  sudo apt update && sudo apt-get update
  sudo apt install -y curl git wget htop tmux build-essential jq make lz4 tree gcc unzip
  echo "✅ Updating and upgrading the VPS completed."
  sleep 4

  # Creating directories for binaries if they don't already exist
  mkdir -p "$HOME/.story/geth/bin" "$HOME/.story/story/bin"

  # Downloading and installing Story-Geth binary
  echo "🛠️ Downloading and setting up Story-Geth..."
  wget -q https://storage.crouton.digital/testnet/story/bin/geth -O "$HOME/.story/geth/bin/geth"
  chmod +x "$HOME/.story/geth/bin/geth"
  "$HOME/.story/geth/bin/geth" version
  echo "✅ Downloading and setting up Story-Geth completed."
  sleep 4

  # Downloading and installing Story binary
  echo "🛠️ Downloading and setting up Story..."
  wget -q https://storage.crouton.digital/testnet/story/bin/story -O "$HOME/.story/story/bin/story"
  chmod +x "$HOME/.story/story/bin/story"
  "$HOME/.story/story/bin/story" version
  echo "✅ Downloading and setting up Story completed."
  sleep 4

  # Adding binaries to PATH
  echo 'export PATH="$HOME/.story/geth/bin:$HOME/.story/story/bin:$PATH"' >> ~/.bashrc
  source ~/.bashrc

  # Initializing the Iliad Network Node
  echo "🛠️ Initializing the Iliad network node..."
  $HOME/.story/story/bin/story init --network iliad
  echo "✅ Initializing the Iliad network node completed."
  sleep 4

  # Prompt for moniker input
  read -rp "Enter a moniker for your node: " moniker

  # Creating systemd service for Story-Geth
  echo "🛠️ reating systemd service for Story-Geth..."
  sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story-Geth Node
After=network.target

[Service]
User=$USER
Type=simple
WorkingDirectory=$HOME/.story/geth
ExecStart=$(which geth) --iliad --syncmode full
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
  
  echo "✅ Creating systemd service for Story-Geth completed."
  sleep 4

  # Initializing the Story node
  echo "🛠️ Initializing the Story node..."
  $HOME/.story/story/bin/story init --network iliad --moniker "${moniker}"
  echo "✅ Initializing the Story node completed."
  sleep 4

  # Downloading the address book
  echo "🛠️ Downloading address book..."
  wget -O "$HOME/.story/story/config/addrbook.json" https://storage.crouton.digital/testnet/story/files/addrbook.json
  echo "✅ Downloading address book completed."
  sleep 4

  # Creating and configuring systemd service for Story
  echo "🛠️ Creating systemd service for Story..."
  sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Protocol Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/.story/story
Type=simple
ExecStart=$(which story) run
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

  echo "🛠️ Creating systemd service for Story completed."
  sleep 4

  # Updating config.toml with the provided moniker
  config_path="$HOME/.story/story/config/config.toml"
  sed -i "s|moniker = \"[^\"]*\"|moniker = \"$moniker\"|g" "$config_path"
  echo "✅ Configuration updated successfully in config.toml with moniker: $moniker"

  # Reloading systemd and enabling services
  echo "🛠️ Reloading systemd, enabling, and starting Story-Geth and Story services..."
  sleep 2
  sudo systemctl daemon-reload
  sleep 2
  sudo systemctl enable story-geth story
  sleep 2
  sudo systemctl start story-geth story
  sleep 2

  echo "✅ Reloading systemd, enabling, and starting Story-Geth and Story services completed."
  echo "❗ Before creating a validator, ensure your node is 100% synchronized with the Story Protocol. To speed up this process, consider installing a snapshot."

}

# Function to install snapshot
function install_snapshot {
  echo "🛠️ Proceeding to installing snapshot..."

  echo "🛠️ Stopping Story and Story-Geth..."
  sudo systemctl stop story story-geth
  echo "✅ Stopping Story and Story-Geth completed."
  sleep 4

  echo "🛠️ Backing up current validator state..."
  cp "$HOME/.story/story/data/priv_validator_state.json" "$HOME/.story/story/priv_validator_state.json.backup"
  echo "✅ Backing up current validator state completed."
  sleep 4

  echo "🛠️ Removing current Story blockchain data..."
  rm -rf "$HOME/.story/story/data"
  echo "✅ Removing current Story blockchain data completed."
  sleep 4

  echo "🛠️ Removing current Story-Geth blockchain data..."
  rm -rf "$HOME/.story/geth/iliad/geth/chaindata"
  echo "✅ Removing current Story-Geth blockchain data completed."
  sleep 4

  echo "🛠️ Downloading and extracting the latest snapshot..."
  curl https://storage.crouton.digital/testnet/story/snapshots/story_latest.tar.lz4 | lz4 -dc - | tar -xf - -C "$HOME/.story"
  echo "✅ Downloading and extracting the latest snapshot completed."
  sleep 4

  echo "🛠️ Restoring the backed-up validator state..."
  mv "$HOME/.story/story/priv_validator_state.json.backup" "$HOME/.story/story/data/priv_validator_state.json"
  echo "✅ Restoring the backed-up validator state completed."
  sleep 4

  echo "🛠️ Starting the Story-Geth..."
  sudo systemctl start story-geth
  echo "✅ Starting the Story-Geth completed."
  sleep 4

  echo "🛠️ Starting the Story..."
  sudo systemctl start story
  echo "✅ Starting the Story completed."
  sleep 4

  echo "🛠️ Displaying Story service logs..."
  sudo journalctl -u story -f
}

# Function to create a validator
function create_validator {
  echo "🛠️ Proceeding to creating validator..."
  
  echo "🛠️ Exporting public keys..."
  story validator export
  echo "✅ Exporting public keys completed."
  sleep 4

  echo "🛠️ Exporting private key..."
  story validator export --export-evm-key
  echo "✅ Exporting private key completed."
  sleep 4

  # Extract private key from the file
  private_key_file="$HOME/.story/story/config/private_key.txt"
  if [ -f "$private_key_file" ]; then
    private_key=$(grep "PRIVATE_KEY=" "$private_key_file" | cut -d'=' -f2 | cut -d'r' -f1)
    if [ -n "$private_key" ]; then
      echo "✅ Private key extracted successfully."
    fi
  fi

  echo "🛠️ Request testnet IP token on https://faucet.story.foundation/. Press Enter when you are done."
  read -p "Press Enter to continue..."

  echo "🛠️ Creating a validator..."
  story validator create --stake 1000000000000000000 --private-key "$private_key"
  echo "✅ Creating a validator completed."
  sleep 4

  echo "🛠️ Fetching validator info..."
  curl -s localhost:26657/status | jq -r '.result.validator_info'
  echo "✅ Fetching validator info completed."
}

# Function to update the node
function update_node {
  echo "🛠️ Proceeding to updating story..."

  cd "$HOME"
  rm -rf story
  git clone https://github.com/piplabs/story
  cd "$HOME/story"
  git checkout v0.10.1
  go build -o story ./client
  sudo mv "$HOME/story/story" "$HOME/.story/story/bin/"
  echo "✅ Updating story completed."
  sleep 4

  echo "🛠️ Restarting Story service..."
  sudo systemctl restart story && sudo journalctl -u story -f
  echo "✅ Restarting Story service completed."
  sleep 4

  echo "🛠️ Updating story-geth..."

  cd "$HOME"
  wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.3-b224fdf.tar.gz
  tar -xvzf geth-linux-amd64-0.9.3-b224fdf.tar.gz
  mv geth-linux-amd64-0.9.3-b224fdf/geth "$HOME/.story/geth/bin/"
  rm -rf geth-linux-amd64-0.9.3-b224fdf geth-linux-amd64-0.9.3-b224fdf.tar.gz
  sudo systemctl restart story-geth
  echo "✅ Updating story-geth completed."
}

# Function to delete the node
function delete_node {
  echo "🛠️ Proceeding to uninstalling node..."
  echo 2

  echo "🛠️ Stopping services..."
  sudo systemctl stop story-geth
  sudo systemctl stop story
  echo "✅ Stopping services completed."
  sleep 5

  echo "🛠️ Disabling services..."
  sudo systemctl disable story-geth
  sudo systemctl disable story
  echo "✅ Disabling services completed."
  sleep 5

  echo "🛠️ Removing service files..."
  sudo rm /etc/systemd/system/story-geth.service
  sudo rm /etc/systemd/system/story.service
  sudo systemctl daemon-reload
  echo "✅ Removing service files completed."
  sleep 5

  echo "🛠️ Removing node data..."
  sudo rm -rf "$HOME/.story"
  sudo rm -f "$HOME/go/bin/story-geth"
  sudo rm -f "$HOME/go/bin/story"
  echo "✅ Removing node data completed."
}

# Function to view logs
function view_logs {
  echo "🛠️ Viewing logs..."

  echo "🛠️ Fetching synchronization status..."
  local_height=$(curl -s localhost:26657/status | jq -r '.result.sync_info.latest_block_height')
  network_height=$(curl -s https://rpc-story.josephtran.xyz/status | jq -r '.result.sync_info.latest_block_height')
  blocks_left=$((network_height - local_height))
  echo "✅ Fetching synchronization status completed."

  # Output the information
  echo -e "\033[1;38mYour node height:\033[0m \033[1;34m$local_height\033[0m | \033[1;35mNetwork height:\033[0m \033[1;36m$network_height\033[0m | \033[1;29mBlocks left:\033[0m \033[1;31m$blocks_left\033[0m"
  
  read -p "Press Enter to view further logs. Then press Ctrl + C if you want to leave"
  echo "🛠️ Viewing logs for both story-geth and story..."

  # Run both journalctl commands in the background
  sudo journalctl -u story-geth -f -o cat &
  sudo journalctl -u story -f -o cat &
  echo "✅ Viewing logs completed."

  # Wait for the user to exit
  wait
}

# Main menu loop
while true; do
  show_menu
  read -r choice
  case $choice in
    1)
      install_node
      ;;
    2)
      install_snapshot
      ;;
    3)
      create_validator
      ;;
    4)
      update_node
      ;;    
    5)
      delete_node
      ;;
    6)
      view_logs
      ;;
    7)
      echo "Exiting the program..."
      exit 0
      ;;
    *)
      echo "Invalid choice. Please select between 1 and 7."
      ;;
  esac
done
