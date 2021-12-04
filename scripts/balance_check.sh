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
# export CALL_LC="$LC_BIN -p ${KEYS_DIR}/liteserver.pub -a ${LITESERVER_IP}:${LITESERVER_PORT} -t 5"

##################################################################################################################
if [[ "$OS_SYSTEM" == "Linux" ]];then
    export CALL_BC="bc"
else
    export CALL_BC="bc -l"
fi
#=================================================
# Text modifiers & signs
export NormText="\e[0m"
export RedBlink="\e[5;101m"
export GreeBack="\e[42m"
export BlueBack="\e[44m"
export RedBack="\e[41m"
export YellowBack="\e[43m"
export BoldText="\e[1m"

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
##################################################################################################################

#=================================================
echo
echo "Time Now: $(date  +'%F %T %Z')"

UnkWAL_Addr=$1
ACCOUNT="$("${CALL_CA}" "${UnkWAL_Addr}" hex | tr '[:upper:]' '[:lower:]')"
acc_wc=${ACCOUNT%%:*}
acc_hex=${ACCOUNT##*:}
if [[ ${#acc_hex} -ne 64 ]];then
    echo "###-ERROR(${FUNCNAME[0]} line $LINENO): Wrong source address!"
    exit 1
fi
echo "Account: $ACCOUNT"

ACCOUNT_INFO="$(Get_Account_Info $ACCOUNT)"
ACC_STATUS=`echo $ACCOUNT_INFO |awk '{print $1}'`
if [[ "$ACC_STATUS" == "None" ]];then
    echo -e "${BoldText}${RedBack}Account does not exist! (no tokens, no code, nothing)${NormText}"
    echo "=================================================================================================="
    exit 0
fi
[[ "$ACC_STATUS" == "Uninit" ]] && ACC_STATUS="${BoldText}${YellowBack}Uninit${NormText}" || ACC_STATUS="${BoldText}${GreeBack}Deployed and Active${NormText}"

AMOUNT=`echo "$ACCOUNT_INFO" |awk '{print $2}'`
ACC_LAST_OP_TIME=`echo "$ACCOUNT_INFO" | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $3)}'`

echo -e "Status: $ACC_STATUS"
echo "Has balance : $(echo "scale=3; $((AMOUNT)) / 1000000000" | $CALL_BC) tokens"
echo "Last operation time: $ACC_LAST_OP_TIME"

echo "=================================================================================================="
exit 0
