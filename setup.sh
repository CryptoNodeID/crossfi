#!/bin/bash
DAEMON_NAME=crossfid
DAEMON_HOME=$HOME/appl/testnet
SERVICE_NAME=crossfi-testnet
INSTALLATION_DIR=$(dirname "$(realpath "$0")")

cd ${INSTALLATION_DIR}

wget https://github.com/crossfichain/crossfi-node/releases/download/v0.3.0-prebuild3/crossfi-node_0.3.0-prebuild3_linux_amd64.tar.gz && tar -xf crossfi-node_0.3.0-prebuild3_linux_amd64.tar.gz
git clone https://github.com/crossfichain/testnet.git

mkdir -p ${DAEMON_HOME}/cosmovisor/genesis/bin
mkdir -p ${DAEMON_HOME}/cosmovisor/upgrades

if ! command -v cosmovisor &> /dev/null; then
    wget https://github.com/cosmos/cosmos-sdk/releases/download/cosmovisor%2Fv1.5.0/cosmovisor-v1.5.0-linux-amd64.tar.gz
    tar -xvzf cosmovisor-v1.5.0-linux-amd64.tar.gz
    rm cosmovisor-v1.5.0-linux-amd64.tar.gz
    sudo cp cosmovisor /usr/local/bin
fi
if ! grep -q 'export DAEMON_NAME=${DAEMON_NAME}' ~/.profile; then
    echo 'export DAEMON_NAME=${DAEMON_NAME}' >> ~/.profile
fi
if ! grep -q 'export DAEMON_HOME=${DAEMON_HOME}' ~/.profile; then
    echo 'export DAEMON_HOME=${DAEMON_HOME}' >> ~/.profile
fi
if ! grep -q 'export DAEMON_ALLOW_DOWNLOAD_BINARIES=true' ~/.profile; then
    echo 'export DAEMON_ALLOW_DOWNLOAD_BINARIES=true' >> ~/.profile
fi
if ! grep -q 'export DAEMON_RESTART_AFTER_UPGRADE=true' ~/.profile; then
    echo 'export DAEMON_RESTART_AFTER_UPGRADE=true' >> ~/.profile
fi
if ! grep -q 'export DAEMON_LOG_BUFFER_SIZE=512' ~/.profile; then
    echo 'export DAEMON_LOG_BUFFER_SIZE=512' >> ~/.profile
fi
source ~/.profile

sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "10"|' \
  ${DAEMON_HOME}/config/app.toml

mkdir -p ${DAEMON_HOME}/cosmovisor/genesis/bin && mkdir -p ${DAEMON_HOME}/cosmovisor/upgrades
cp ${INSTALLATION_DIR}/${DAEMON_NAME} ${DAEMON_HOME}/cosmovisor/genesis/bin
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
${DAEMON_NAME} --home ${DAEMON_HOME} init $VALIDATOR_KEY_NAME --chain-id crossfi-evm-testnet-1

# Helper scripts
cd ${INSTALLATION_DIR}
rm -rf list_keys.sh check_balance.sh create_validator.sh unjail_validator.sh check_validator.sh start_crossfi.sh check_log.sh
echo "${DAEMON_NAME} --home ${DAEMON_HOME} keys list" > list_keys.sh && chmod +x list_keys.sh
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
rm -rf crossfid check_balance.sh create_validator.sh unjail_validator.sh check_validator.sh start_crossfid.sh check_log.sh list_keys.sh
echo "${DAEMON_NAME} keys list" > list_keys.sh && chmod +x list_keys.sh
if [[ "$use_custom_port" =~ ^[Yy](es)?$ ]]; then
    echo "${DAEMON_NAME} q bank balances --node=tcp://localhost:${port_prefix}657 \$(${DAEMON_NAME} keys show $VALIDATOR_KEY_NAME -a)" > check_balance.sh && chmod +x check_balance.sh
else
    echo "${DAEMON_NAME} q bank balances \$(${DAEMON_NAME} keys show $VALIDATOR_KEY_NAME -a)" > check_balance.sh && chmod +x check_balance.sh
fi
tee create_validator.sh > /dev/null <<EOF
#!/bin/bash
${DAEMON_NAME} --home ${DAEMON_HOME} tx staking create-validator \\
  --amount=9900000000000000000000mpx \\
  --pubkey=\$(${DAEMON_NAME} --home ${DAEMON_HOME} tendermint show-validator) \\
  --moniker="$VALIDATOR_KEY_NAME" \\
  --details="CryptoNodeID. Crypto Validator Node Education Channel" \\
  --website="https://t.me/CryptoNodeID" \\
  --chain-id="crossfi-evm-testnet-1" \\
  --commission-rate="0.05" \\
  --commission-max-rate="0.20" \\
  --commission-max-change-rate="0.01" \\
  --min-self-delegation="1000000" \\
  --gas="auto" \\
  --gas-prices="10000000000000mpx" \\
  --gas-adjustment=1.5 \\
  --from=$VALIDATOR_KEY_NAME
EOF
chmod +x create_validator.sh
tee unjail_validator.sh > /dev/null <<EOF
#!/bin/bash
${DAEMON_NAME} --home ${DAEMON_HOME} tx slashing unjail \\
  --from=$VALIDATOR_KEY_NAME
EOF
chmod +x unjail_validator.sh
tee check_validator.sh > /dev/null <<EOF
#!/bin/bash
${DAEMON_NAME} --home ${DAEMON_HOME} query tendermint-validator-set
EOF
chmod +x check_validator.sh
tee start_crossfi.sh > /dev/null <<EOF
#!/bin/bash
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl restart ${SERVICE_NAME}
EOF
chmod +x start_crossfi.sh
tee check_log.sh > /dev/null <<EOF
#!/bin/bash
journalctl -u ${SERVICE_NAME} -f
EOF
chmod +x check_log.sh

sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF  
[Unit]
Description=CrossFi Testnet Daemon (cosmovisor)
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
rm -f crossfi-node_0.3.0-prebuild3_linux_amd64.tar.gz
rm -f README.md CHANGELOG.md LICENSE readme.md