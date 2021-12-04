#!/usr/bin/env bash

# (C) Sergey Tyurin 2021-11-30 19:00:00

# Disclaimer
##################################################################################################################
# You running this script/function means you will not blame the author(s)
# if this breaks your stuff. This script/function is provided AS IS without warranty of any kind. 
# Author(s) disclaim all implied warranties including, without limitation, 
# any implied warranties of merchantability or of fitness for a particular purpose. 
# The entire risk arising out of the use or performance of the sample scripts and documentation remains with you.
# In no event shall author(s) be held liable for any damages whatsoever 
# (including, without limitation, damages for loss of business profits, business interruption, 
# loss of business information, or other pecuniary loss) arising out of the use of or inability 
# to use the script or documentation. Neither this script/function, 
# nor any part of it other than those parts that are explicitly copied from others, 
# may be republished without author(s) express written permission. 
# Author(s) retain the right to alter this disclaimer at any time.
##################################################################################################################
#
set -eE

echo
echo "################################## Deploy wallet script ########################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

#==================================================
# Set environment
SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
export NODE_TOP_DIR=$(cd "${SCRIPT_DIR}/../" && pwd -P)

NODE_BIN_DIR="$HOME/bin"
KEYS_DIR="${NODE_TOP_DIR}/ton-keys"
Contr_path="${NODE_TOP_DIR}/contracts"

SEND_ATTEMPTS=3
LC_Send_MSG_Timeout=20

#=================================================
# Binaries
export CALL_CA="${NODE_BIN_DIR}/convert_address"
export CALL_TC="${NODE_BIN_DIR}/tonos-cli"
export CALL_LC="${NODE_BIN_DIR}/lite-client --global-config ${NODE_TOP_DIR}/configs/global.config.json"
# LITESERVER_IP="127.0.0.1"
# LITESERVER_PORT="3031"
# export CALL_LC="${NODE_BIN_DIR}/lite-client -p ${KEYS_DIR}/liteserver.pub -a ${LITESERVER_IP}:${LITESERVER_PORT} -t 5"

##################################################################################################################
if [[ "$OS_SYSTEM" == "Linux" ]];then
    export CALL_BC="bc"
else
    export CALL_BC="bc -l"
fi

function echoerr() { printf "\e[31;1m%s\e[0m\n" "$*" >&2; }
#=================================================
# Get account INFO
# Input: AccountHEX
# Return: Active/Uninit/None nanoTokens LastOperTime
function Get_Account_Info() {
    local ACCOUNT=`echo "$1"| tr '[:upper:]' '[:lower:]'`
    local acc_wc=${ACCOUNT%%:*}
    local acc_hex=${ACCOUNT##*:}
    if [[ ${#acc_hex} -ne 64 ]];then
        echoerr "###-ERROR(${FUNCNAME[0]} line $LINENO): Wrong account address!"
        echo "None 0 0" 
        return
    fi
    local ACCOUNT_INFO=`$CALL_LC -rc "getaccount ${ACCOUNT}" -rc "quit" 2>/dev/null`
    if [[ ! -z "$(echo ${ACCOUNT_INFO} | grep -i 'account state is empty')" ]];then
        echo "None 0 0"
        return
    fi
    local AMOUNT_nt=`echo "$ACCOUNT_INFO" |grep "account balance" | tr -d "ng"|awk '{print $4}'`
    local LASTOP=`echo "$ACCOUNT_INFO" | grep "last_paid" | gawk -F ":" '{print $5}'`
    local STATUS=`echo "$ACCOUNT_INFO" | grep 'state:'|tr -d ')'|tr -d '('|cut -d ':' -f 2`
    [[ "${STATUS}" == "account_uninit" ]] && STATUS="Uninit"
    [[ "${STATUS}" == "account_active" ]] && STATUS="Active"
    [[ ! -z "$(echo ${ACCOUNT_INFO} | grep -i 'account_frozen')" ]] && STATUS="Frozen"
    echo "${STATUS} ${AMOUNT_nt} ${LASTOP}"
}
#=================================================
# Send File - send external message serialized as bag of cells and stored in specified msg_file
# Input: boc file
# Output: result
function Send_File_To_BC() {
    local Result="failed"
    local BOC_File="$1"
    [[ ! -f $BOC_File ]] && echoerr "###-ERROR(${FUNCNAME[0]} line $LINENO): File to send not found!!!"
    local LC_OUT="$($CALL_LC -rc "sendfile $BOC_File" -rc 'quit' 2>&1 | grep 'external message status is 1')"
    [[ -n "$(echo "$LC_OUT" | grep -i 'external message status is 1')" ]] && Result="success"
    sleep $LC_Send_MSG_Timeout
    echo "${Result}"
}
##################################################################################################################


function show_usage(){
    echo
    echo " Use: Resc-wallet_deploy.sh 'Source Address' 'seed phrase' 'Target Address'"
    echo " All fields required!"
    echo
    exit 0
}
[[ $# -lt 3 ]] && show_usage

#============================================
echo "Deploy wallet to '${NETWORK_TYPE}' network"

#==================================================
# Check input parametrs
UnkWAL_Addr="$1"
SeedPhrase="$2"
Target_Addr="$3"
ForceDeploy="$4"

#==================================================
# Check validity of Seed phrese 
TC_OUT=$($CALL_TC genpubkey "${SeedPhrase}")
if [[ -z $(echo "${TC_OUT}" | grep -i 'Invalid bip39 phrase') ]];then
    UnkPubKey="$(echo "${TC_OUT}" | grep -i 'Public key:'|awk '{print $3}')"
    echo "Pubkey from seed: ${UnkPubKey}"
else
    echo
    echo "###-ERROR(line $LINENO): Your seed phrase is not bip39 phrase"
    echo
    exit 1
fi

#==================================================
# Check addresses
DST_Addr="$("${CALL_CA}" "${Target_Addr}" hex | tr '[:upper:]' '[:lower:]')"
acc_wc=${DST_Addr%%:*}
acc_hex=${DST_Addr##*:}
if [[ ${#acc_hex} -ne 64 ]];then
    echo "###-ERROR(${FUNCNAME[0]} line $LINENO): Wrong target address!"
    exit 1
fi
SRC_Addr="$("${CALL_CA}" "${UnkWAL_Addr}" hex | tr '[:upper:]' '[:lower:]')"
acc_wc=${SRC_Addr%%:*}
acc_hex=${SRC_Addr##*:}
if [[ ${#acc_hex} -ne 64 ]];then
    echo "###-ERROR(${FUNCNAME[0]} line $LINENO): Wrong source address!"
    exit 1
fi
echo "Source address:      ${SRC_Addr}"
echo "Destination address: ${DST_Addr}"
echo

#==================================================
# Save address & keypair
echo ${acc_hex} > "${KEYS_DIR}/${acc_hex}.addr"
"${CALL_TC}" getkeypair "${KEYS_DIR}/${acc_hex}.keys.json" "$SeedPhrase" &>/dev/null
SRC_KEY_FILE="${KEYS_DIR}/${acc_hex}.keys.json"

#==================================================
# Fing correct contract from list
Contr_List_file="Contracts_List.json"
Contr_JSON=$(cat "${Contr_path}/${Contr_List_file}")
Contracts_List=$(echo "${Contr_JSON}" | jq -rc 'keys[]' | tr '\n' ' ')
TVC_Found=false
for CurrContr in ${Contracts_List}
do
    echo "Try ${CurrContr} contract code..."
    Wallet_ABI="${Contr_path}/$(echo ${Contr_JSON}  | jq -r ".${CurrContr}.abi")"
    Wallet_Code="${Contr_path}/$(echo ${Contr_JSON} | jq -r ".${CurrContr}.tvc")"
    if [[ ! -f $Wallet_Code ]] || [[ ! -f $Wallet_ABI ]];then
        echo "###-ERROR(line $LINENO): Can not find Wallet code or ABI for ${CurrContr}. Check contracts folder '${Contr_path}'"  
        exit 1
    fi
    WalletAddress=$("${CALL_TC}" genaddr $Wallet_Code $Wallet_ABI --setkey "${SRC_KEY_FILE}" --wc ${acc_wc} | tee ${KEYS_DIR}/${acc_hex}_addr-card.txt | grep "Raw address:" | awk '{print $3}')
    if [[ "${WalletAddress}" == "${SRC_Addr}" ]];then
        echo "SUCCESS!!! Contract found! It is: ${CurrContr}"
        TVC_Found=true
        break
    fi
done
if ! $TVC_Found;then
    echo "###-ERROR(line $LINENO): Cannot find contract code for given SRC address. Check address and seedphrase!" 
    exit 1
fi
echo
echo "Wallet Code file: ${Wallet_Code}"
echo "Wallet ABI  file: ${Wallet_ABI}"

#=================================================
# Check deployed already
ACCOUNT_INFO="$(Get_Account_Info "${SRC_Addr}")"
AMOUNT=`echo "$ACCOUNT_INFO" |awk '{print $2}'`
ACTUAL_BALANCE=$(echo "scale=3; $((AMOUNT)) / 1000000000" | $CALL_BC)
ACC_STATUS=`echo "$ACCOUNT_INFO" | awk '{print $1}'`
if [[ "$ACC_STATUS" == "Active" ]];then
    echo
    echo -e "###-ERROR(line $LINENO): ${YellowBack}${BoldText}Wallet deployed already.${NormText} Status: \"$ACC_STATUS\"; Balance: $ACTUAL_BALANCE"
    echo
    [[ "${ForceDeploy}" != "force" ]] && exit 1
fi
echo "Wallet status : \"$ACC_STATUS\""

#=================================================
# Check wallet balance
if [[ $((AMOUNT / 100000000)) -lt 9 ]];then
    echo "###-ERROR(line $LINENO): You haven't enough tokens to deploy wallet. Current balance: $ACTUAL_BALANCE tokens. You need 0.9 at least. Exit."
    exit 1
fi
echo "Wallet balance: $ACTUAL_BALANCE"

#=================================================
# Read keys and make a string
Custodians_PubKeys=""
PubKey="0x$(cat ${SRC_KEY_FILE} | jq '.public'| tr -d '\"')"
SecKey="0x$(cat ${SRC_KEY_FILE} | jq '.secret'| tr -d '\"')"
if [[ "$PubKey" == "0x" ]] || [[ "$SecKey" == "0x" ]];then
    echo
    echo "###-ERROR(line $LINENO): Can't find wallet public and/or secret key!"
    echo
    exit 1
fi
Custodians_PubKeys+="\"${PubKey}\","
Custodians_PubKeys=${Custodians_PubKeys::-1}
echo "Custodians_PubKeys: '$Custodians_PubKeys'"
echo

#===========================================================
# Check Wallet Address once more
ADDR_from_Keys=$($CALL_TC genaddr $Wallet_Code $Wallet_ABI --setkey "${SRC_KEY_FILE}" --wc ${acc_wc} | grep "Raw address:" | awk '{print $3}')
if [[ "$SRC_Addr" != "$ADDR_from_Keys" ]];then
    echo "###-ERROR(line $LINENO): Given Wallet Address and calculated address is different. Possible you prepared it for another contract type or keys. "
    echo "Given addr: $SRC_Addr"
    echo "Calc  addr: $ADDR_from_Keys"
    echo 
    [[ "${ForceDeploy}" != "force" ]] && exit 1
fi
SRC_ACCOUNT="$SRC_Addr"
#=================================================
read -p "### CHECK INFO TWICE!!! Is this a right deploy info?  (y/n)? " answer </dev/tty
case ${answer:0:1} in
    y|Y )
        echo "Processing....."
    ;;
    * )
        echo "Cancelled."
        exit 1
    ;;
esac

###################################################################################################################################
# Deploy wallet
ReqConfirms=1
#=================================================
# make boc file 
function Make_BOC_File(){
    rm -f deploy.boc
    TC_OUTPUT=$($CALL_TC deploy_message \
        $Wallet_Code \
        "{\"owners\":[$Custodians_PubKeys],\"reqConfirms\":${ReqConfirms}}" \
        --abi $Wallet_ABI \
        --sign "${SRC_KEY_FILE}" \
        --wc ${acc_wc} \
        --raw \
        --output deploy.boc \
        | tee ${KEYS_DIR}/${acc_hex}_deploy_wallet_msg.log)
    echo "${TC_OUTPUT}"
}

echo -n "---INFO(line $LINENO): Make deploy message BOC file..."

MBF_Output="$(Make_BOC_File)"

if [[ ! -f "deploy.boc" ]];then 
    echo "###-ERROR(line $LINENO): Failed to make deploying message file!!!"
    echo "$MBF_Output"
    exit 1
fi

MBF_addr="$(echo "$MBF_Output"|grep "Contract's address:"|awk '{print $3}')"

if [[ "${MBF_addr}" != "${SRC_Addr}" ]];then
    echo "###-ERROR(line $LINENO): Address from BOC ($MBF_addr) is not equal calc address ($SRC_Addr) !"
    [[ "${ForceDeploy}" != "force" ]] && exit 1
else
    echo "DONE"
fi

#=================================================
# Send deploy message to BlockChain
echo -n "---INFO(line $LINENO): Send deploy message to blockchain..."
Attempts_to_send=$SEND_ATTEMPTS
while [[ $Attempts_to_send -gt 0 ]]; do
    result=`Send_File_To_BC "deploy.boc"`
    if [[ "$result" == "failed" ]]; then
        echo "###-ERROR(line $LINENO): Send deploy message FAILED!!!"
    else
        echo "DONE"
        break
    fi
done

###################################################################################################################################
# Transfer tokens 
echo
echo "================================================="
echo "============= Transfer tokens ==================="
echo

#================================================================
echo "Check SRC $SRC_NAME account.."
ACCOUNT_INFO="$(Get_Account_Info $SRC_ACCOUNT)"
SRC_STATUS=`echo $ACCOUNT_INFO |awk '{print $1}'`
SRC_AMOUNT=`echo "$ACCOUNT_INFO" |awk '{print $2}'`
SRC_TIME=`echo "$ACCOUNT_INFO" | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $3)}'`
SRC_Time_Unix=`echo $ACCOUNT_INFO |awk '{print $3}'`

if [[ "$SRC_STATUS" == "None" ]];then
    echo -e "###-ERROR(line $LINENO): ${BoldText}${RedBack}SRC account does not exist! (no tokens, no code, nothing)${NormText}"
    echo "=================================================================================================="
    echo 
    exit 0
fi
if [[ "$SRC_STATUS" == "Uninit" ]];then
    echo -e "###-ERROR(line $LINENO): ${BoldText}${RedBack}SRC account uninitialized!${NormText} Deploy contract code first!"
    echo "=================================================================================================="
    echo 
    exit 0
fi

# Check SRC acc Keys
Calc_Addr=$($CALL_TC genaddr $Wallet_Code $Wallet_ABI --setkey $SRC_KEY_FILE --wc "${acc_wc}" | grep "Raw address:" | awk '{print $3}')
if [[ ! "$SRC_ACCOUNT" == "$Calc_Addr" ]];then
    echo "###-ERROR(line $LINENO): Given SRC account address and calculated address is different. Wrong keys. Can't continue. "
    echo "Given addr: $SRC_ACCOUNT"
    echo "Calc  addr: $Calc_Addr"
    echo 
    exit 1
fi

#================================================================
BOUNCE="true"
DST_ACCOUNT="${DST_Addr}"
echo "Check DST account: $DST_ACCOUNT"
ACCOUNT_INFO="$(Get_Account_Info $DST_ACCOUNT)"
DST_AMOUNT=`echo "$ACCOUNT_INFO" |awk '{print $2}'`
DST_TIME=`echo "$ACCOUNT_INFO" | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $3)}'`
DST_STATUS=`echo $ACCOUNT_INFO |awk '{print $1}'`
if [[ "$DST_STATUS" != "Active" ]] && [[ "$ForceDeploy" != "force" ]];then
    echo
    echo "###-ERROR(line $LINENO): DST account is not deployed. To transfer to undeployed account use 'new' parameter"
    tr_usage
    exit 1
fi
[[ "$ForceDeploy" != "force" ]] && BOUNCE="false"

NANO_AMOUNT=$((SRC_AMOUNT - 50000000))      # 0.05 - for transfer fee
TRANSF_AMOUNT=$(echo "scale=3; $((NANO_AMOUNT)) / 1000000000" | $CALL_BC)

#================================================================
echo
echo "TRANFER FROM :"
echo "SRC Account: $SRC_ACCOUNT"
echo "Has balance : $(echo "scale=3; $((SRC_AMOUNT)) / 1000000000" | $CALL_BC) tokens"
echo "Last operation time: $SRC_TIME"
echo
echo "TRANFER TO :"
echo "DST Account: $DST_ACCOUNT"
echo "Has balance : $(echo "scale=3; $((DST_AMOUNT)) / 1000000000" | $CALL_BC) tokens"
echo "Last operation time: $DST_TIME"
echo
echo "Transferring $TRANSF_AMOUNT ($NANO_AMOUNT) ..." 

read -p "### CHECK INFO TWICE!!! Is this a right tranfer?  (y/n)? " </dev/tty answer
case ${answer:0:1} in
    y|Y )
        echo "Processing....."
    ;;
    * )
        echo "Cancelled."
        exit 1
    ;;
esac

#================================================================
# Make BOC file to send
TA_BOC_File="${KEYS_DIR}/Transfer_Amount.boc"
rm -f "${TA_BOC_File}" &>/dev/null
TC_OUTPUT="$($CALL_TC message --raw --output ${TA_BOC_File} \
--sign "${SRC_KEY_FILE}" \
--abi "${Wallet_ABI}" \
${SRC_ACCOUNT} submitTransaction \
"{\"dest\":\"${DST_ACCOUNT}\",\"value\":${NANO_AMOUNT},\"bounce\":$BOUNCE,\"allBalance\":false,\"payload\":\"\"}" \
--lifetime 600 | grep -i 'Message saved to file')"

if [[ -z $TC_OUTPUT ]] || [[ ! -f "${TA_BOC_File}" ]];then
    echo "###-ERROR(line $LINENO): Failed to make BOC file ${TA_BOC_File}. Can't continue."
    exit 1
fi
echo "INFO: Message BOC file created: ${TA_BOC_File}"

#==========================================================================
# Send transaction to BC 
for (( i=1; i<=${SEND_ATTEMPTS}; i++ )); do
    echo -n "INFO: submitTransaction attempt #${i}..."
    result=`Send_File_To_BC "${TA_BOC_File}"`
    if [[ "$result" == "failed" ]]; then
        echo " FAIL"
        echo "Now sleep $LC_Send_MSG_Timeout secs and will try again.."
        echo "--------------"
        sleep $LC_Send_MSG_Timeout
        continue
    else
        echo " PASS"
    fi
    
    echo "Now sleep $LC_Send_MSG_Timeout secs and check transactions..."
    sleep $LC_Send_MSG_Timeout

    ACCOUNT_INFO="$(Get_Account_Info $SRC_ACCOUNT)"
    Time_Unix=`echo $ACCOUNT_INFO |awk '{print $3}'`
    if [[ $Time_Unix -gt $SRC_Time_Unix ]];then
        echo -e "INFO: successfully sent $TRANSF_AMOUNT tokens."
        break
    fi
done

#==========================================================================
# Check accounts
echo "Check SRC account.."
ACCOUNT_INFO="$(Get_Account_Info $SRC_ACCOUNT)"
SRC_AMOUNT=`echo "$ACCOUNT_INFO" |awk '{print $2}'`
SRC_TIME=`echo "$ACCOUNT_INFO" | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $3)}'`

echo "Check DST account.."
ACCOUNT_INFO="$(Get_Account_Info $DST_ACCOUNT)"
DST_AMOUNT=`echo "$ACCOUNT_INFO" |awk '{print $2}'`
DST_TIME=`echo "$ACCOUNT_INFO" | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $3)}'`

echo
echo "${SRC_NAME} Account: $SRC_ACCOUNT"
echo "Has balance : $(echo "scale=3; $((SRC_AMOUNT)) / 1000000000" | $CALL_BC) tokens"
echo "Last operation time: $SRC_TIME"

echo
echo "${DST_NAME} Account: $DST_ACCOUNT"
echo "Has balance : $(echo "scale=3; $((DST_AMOUNT)) / 1000000000" | $CALL_BC) tokens"
echo "Last operation time: $DST_TIME"
echo


echo
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"
echo

exit 0
