### Prerequisite :
#### Ensure 'git' already installed
    apt-get update -y && apt-get install git -y
### Steps
#### Clone this repository :
    git clone https://github.com/CryptoNodeID/crossfi.git
#### run setup command : 
    cd crossfi && chmod ug+x *.sh && ./setup.sh
#### follow the instruction and then run below command to start the node :
    ./start_crossfi.sh && ./check_log.sh
