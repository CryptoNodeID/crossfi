#!/bin/bash
DAEMON_NAME=crossfid
DAEMON_HOME=$HOME/.mineplex-chain
SERVICE_NAME=crossfi-testnet
INSTALLATION_DIR=$(dirname "$(realpath "$0")")
SNAP_RPC="https://crossfi-testnet-rpc.cryptonode.id:443"

cd ${INSTALLATION_DIR}

mkdir -p ${INSTALLATION_DIR}/bin
read -p "Enter 'testnet' or 'mainnet': " network
network=$(echo "$network" | tr '[:upper:]' '[:lower:]')
if [ "$network" == "testnet" ]; then
  DAEMON_NAME=crossfid-testnet
  DAEMON_HOME=$HOME/.crossfi-testnet
  wget https://github.com/crossfichain/crossfi-node/releases/download/v0.3.0-prebuild3/crossfi-node_0.3.0-prebuild3_linux_amd64.tar.gz && tar -xf crossfi-node_0.3.0-prebuild3_linux_amd64.tar.gz
  mv bin/crossfid bin/${DAEMON_NAME}
  git clone https://github.com/crossfichain/testnet.git
  SERVICE_NAME=crossfi-testnet
  CHAIN_ID='crossfi-evm-testnet-1'
  SNAP_RPC="https://crossfi-testnet-rpc.cryptonode.id:443"
  mv testnet ${DAEMON_HOME}
  if ! grep -q "export DAEMON_NAME_TESTNET=${DAEMON_NAME}" ~/.profile; then
    echo "export DAEMON_NAME_TESTNET=${DAEMON_NAME}" >> ~/.profile
  fi
  if ! grep -q "export DAEMON_HOME_TESTNET=${DAEMON_HOME}" ~/.profile; then
      echo "export DAEMON_HOME_TESTNET=${DAEMON_HOME}" >> ~/.profile
  fi
  if ! grep -q "export DAEMON_ALLOW_DOWNLOAD_BINARIES_TESTNET=true" ~/.profile; then
      echo "export DAEMON_ALLOW_DOWNLOAD_BINARIES_TESTNET=true" >> ~/.profile
  fi
  if ! grep -q "export DAEMON_RESTART_AFTER_UPGRADE_TESTNET=true" ~/.profile; then
      echo "export DAEMON_RESTART_AFTER_UPGRADE_TESTNET=true" >> ~/.profile
  fi
  if ! grep -q "export DAEMON_LOG_BUFFER_SIZE_TESTNET=512" ~/.profile; then
      echo "export DAEMON_LOG_BUFFER_SIZE_TESTNET=512" >> ~/.profile
  fi
else
  wget https://github.com/crossfichain/crossfi-node/releases/download/v0.1.1/mineplex-2-node._v0.1.1_linux_amd64.tar.gz && tar -xf mineplex-2-node._v0.1.1_linux_amd64.tar.gz
  mv mineplex-chaind bin/${DAEMON_NAME}
  git clone https://github.com/crossfichain/mainnet.git
  SERVICE_NAME=crossfi-mainnet
  CHAIN_ID='mineplex-mainnet-1'
  SNAP_RPC="https://crossfi-mainnet-rpc.cryptonode.id:443"
  if ! grep -q "export DAEMON_NAME=${DAEMON_NAME}" ~/.profile; then
    echo "export DAEMON_NAME=${DAEMON_NAME}" >> ~/.profile
  fi
  if ! grep -q "export DAEMON_HOME=${DAEMON_HOME}" ~/.profile; then
      echo "export DAEMON_HOME=${DAEMON_HOME}" >> ~/.profile
  fi
  if ! grep -q "export DAEMON_ALLOW_DOWNLOAD_BINARIES=true" ~/.profile; then
      echo "export DAEMON_ALLOW_DOWNLOAD_BINARIES=true" >> ~/.profile
  fi
  if ! grep -q "export DAEMON_RESTART_AFTER_UPGRADE=true" ~/.profile; then
      echo "export DAEMON_RESTART_AFTER_UPGRADE=true" >> ~/.profile
  fi
  if ! grep -q "export DAEMON_LOG_BUFFER_SIZE=512" ~/.profile; then
      echo "export DAEMON_LOG_BUFFER_SIZE=512" >> ~/.profile
  fi
  source ~/.profile
fi

if ! command -v cosmovisor &> /dev/null; then
    wget https://github.com/cosmos/cosmos-sdk/releases/download/cosmovisor%2Fv1.5.0/cosmovisor-v1.5.0-linux-amd64.tar.gz
    tar -xvzf cosmovisor-v1.5.0-linux-amd64.tar.gz
    rm cosmovisor-v1.5.0-linux-amd64.tar.gz
    mv cosmovisor bin/cosmovisor
    cp ${INSTALLATION_DIR}/bin/cosmovisor /usr/local/bin/cosmovisor -f
fi

echo "DAEMON_NAME=$DAEMON_NAME"
echo "DAEMON_HOME=$DAEMON_HOME"
echo "DAEMON_ALLOW_DOWNLOAD_BINARIES=$DAEMON_ALLOW_DOWNLOAD_BINARIES"
echo "DAEMON_RESTART_AFTER_UPGRADE=$DAEMON_RESTART_AFTER_UPGRADE"
echo "DAEMON_LOG_BUFFER_SIZE=$DAEMON_LOG_BUFFER_SIZE"
echo "Crossfid version: "$(${INSTALLATION_DIR}/bin/${DAEMON_NAME} --home ${DAEMON_HOME} version)
echo "Chain id: "${CHAIN_ID}
echo "RPC: "${SNAP_RPC}
echo "Service name: "${SERVICE_NAME}

LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height);
BLOCK_HEIGHT=$((LATEST_HEIGHT - 1000));
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash) 
echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH && sleep 2

read -p "Press enter to continue or Ctrl+C to cancel"

if [ $network == "mainnet" ]; then
    rm -rf ${DAEMON_HOME}
    mv mainnet ${DAEMON_HOME}
fi

mkdir -p ${DAEMON_HOME}/cosmovisor/genesis/bin
mkdir -p ${DAEMON_HOME}/cosmovisor/upgrades

sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "10"|' \
  ${DAEMON_HOME}/config/app.toml

cp ${INSTALLATION_DIR}/bin/${DAEMON_NAME} ${DAEMON_HOME}/cosmovisor/genesis/bin
sudo ln -s ${DAEMON_HOME}/cosmovisor/genesis ${DAEMON_HOME}/cosmovisor/current -f
sudo ln -s ${DAEMON_HOME}/cosmovisor/current/bin/${DAEMON_NAME} /usr/local/bin/${DAEMON_NAME} -f

# Init Crossfi
${DAEMON_NAME} --home ${DAEMON_HOME} version
read -p "Enter validator key name: " VALIDATOR_KEY_NAME
if [ -z "$VALIDATOR_KEY_NAME" ]; then
    echo "Error: No validator key name provided."
    exit 1
fi
read -p "Do you want to recover wallet? [y/N]: " RECOVER
if [[ "$RECOVER" =~ ^[Yy](es)?$ ]]; then
    ${DAEMON_NAME} --home ${DAEMON_HOME} keys add $VALIDATOR_KEY_NAME --recover
else
    ${DAEMON_NAME} --home ${DAEMON_HOME} keys add $VALIDATOR_KEY_NAME
fi
${DAEMON_NAME} --home ${DAEMON_HOME} keys list

# Helper scripts
mkdir ${INSTALLATION_DIR}/scripts
cd ${INSTALLATION_DIR}/scripts
rm -rf list_keys_${network}.sh check_balance_${network}.sh create_validator_${network}.sh unjail_validator_${network}.sh check_validator_${network}.sh start_crossfi_${network}.sh check_log_${network}.sh

read -p "Do you want to use custom port number prefix (y/N)? " use_custom_port
if [[ "$use_custom_port" =~ ^[Yy](es)?$ ]]; then
    read -p "Enter port number prefix (max 2 digits, not exceeding 50): " port_prefix
    while [[ "$port_prefix" =~ [^0-9] || ${#port_prefix} -gt 2 || $port_prefix -gt 50 ]]; do
        read -p "Invalid input, enter port number prefix (max 2 digits, not exceeding 50): " port_prefix
    done
    ${DAEMON_NAME} config node tcp://localhost:${port_prefix}657
    sed -i.bak -e "s%:1317%:${port_prefix}317%g; s%:8080%:${port_prefix}080%g; s%:9090%:${port_prefix}090%g; s%:9091%:${port_prefix}091%g; s%:8545%:${port_prefix}545%g; s%:8546%:${port_prefix}546%g; s%:6065%:${port_prefix}065%g" ${DAEMON_HOME}/config/app.toml
    sed -i.bak -e "s%:26658%:${port_prefix}658%g; s%:26657%:${port_prefix}657%g; s%:6060%:${port_prefix}060%g; s%:26656%:${port_prefix}656%g; s%:26660%:${port_prefix}660%g" ${DAEMON_HOME}/config/config.toml
fi
echo "${DAEMON_NAME} keys list" > list_keys_${network}.sh && chmod ug+x list_keys_${network}.sh
if [[ "$use_custom_port" =~ ^[Yy](es)?$ ]]; then
    echo "${DAEMON_NAME} q bank balances --node=tcp://localhost:${port_prefix}657 \$(${DAEMON_NAME} keys show $VALIDATOR_KEY_NAME -a)" > check_balance_${network}.sh && chmod +x check_balance_${network}.sh
else
    echo "${DAEMON_NAME} q bank balances \$(${DAEMON_NAME} keys show $VALIDATOR_KEY_NAME -a)" > check_balance_${network}.sh && chmod +x check_balance_${network}.sh
fi

tee create_validator_${network}.sh > /dev/null <<EOF
#!/bin/bash
${DAEMON_NAME} --home ${DAEMON_HOME} tx staking create-validator \\
  --amount=9900000000000000000000mpx \\
  --pubkey=\$(${DAEMON_NAME} --home ${DAEMON_HOME} tendermint show-validator) \\
  --moniker="$VALIDATOR_KEY_NAME" \\
  --identity="4a8bc33cee42de0b23bbccbc84aee10fd0cdfc07" \\
  --details="CryptoNode.ID Crypto Validator Node Education Channel" \\
  --website="https://cryptonode.id" \\
  --security-contact="admin@cryptonode.id" \\
  --chain-id="$CHAIN_ID" \\
  --commission-rate="0.05" \\
  --commission-max-rate="0.20" \\
  --commission-max-change-rate="0.01" \\
  --min-self-delegation="1000000" \\
  --gas="auto" \\
  --gas-prices="10000000000000mpx" \\
  --gas-adjustment=1.5 \\
  --from=$VALIDATOR_KEY_NAME
EOF
chmod ug+x create_validator_${network}.sh
tee unjail_validator_${network}.sh > /dev/null <<EOF
#!/bin/bash
${DAEMON_NAME} --home ${DAEMON_HOME} tx slashing unjail \\
  --from=$VALIDATOR_KEY_NAME \\
  --chain-id="$CHAIN_ID" \\
  --gas auto --gas-adjustment 1.5 --gas-prices 5000000000000mpx
EOF
chmod ug+x unjail_validator_${network}.sh
tee check_validator_${network}.sh > /dev/null <<EOF
#!/bin/bash
${DAEMON_NAME} --home ${DAEMON_HOME} query tendermint-validator-set
EOF
chmod ug+x check_validator_${network}.sh
tee start_crossfi_${network}.sh > /dev/null <<EOF
#!/bin/bash
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl restart ${SERVICE_NAME}
EOF
chmod ug+x start_crossfi_${network}.sh
tee check_log_${network}.sh > /dev/null <<EOF
#!/bin/bash
sudo journalctl -u ${SERVICE_NAME} -f
EOF
chmod ug+x check_log_${network}.sh

sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF  
[Unit]
Description=CrossFi ${network} Daemon (cosmovisor)
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) run start --home ${DAEMON_HOME}
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment="DAEMON_NAME=${DAEMON_NAME}"
Environment="DAEMON_HOME=${DAEMON_HOME}"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="DAEMON_LOG_BUFFER_SIZE=512"

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
read -p "Do you want to enable the ${SERVICE_NAME} service? (y/N): " ENABLE_SERVICE
if [[ "$ENABLE_SERVICE" =~ ^[Yy](es)?$ ]]; then
    sudo systemctl enable ${SERVICE_NAME}.service
else
    echo "Skipping enabling ${SERVICE_NAME} service."
fi

#Cleanup
cd ${INSTALLATION_DIR}
rm -f crossfi-node_0.3.0-prebuild3_linux_amd64.tar.gz mineplex-2-node._v0.1.1_linux_amd64.tar.gz
rm -f README.md CHANGELOG.md LICENSE readme.md