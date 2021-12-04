# Rescue system 

#### If you accidentally sent coins from the The Open Network (ton.org (http://ton.org/)) to the wallet address created in Everscale network, or in the opposite direction, then this rescue system will allow you to recover coins.

### NB! You must have seed phrase for the address from which you want to get tokens!  

#### How it works  

Example: If you sent tokens from exchange to "Surf" address (which cannot be managed in the ton.org blockchain) and you have seed phrase for this address, you can use script **`Resc_wallet_deploy.sh`** to find right contract code, deploy this code to address and trasfer tokens to your address, which you can manage.

## Installation
To install the system install **`git`** package, and then do the follow:
```bash
cd $HOME
git clone https://github.com/Custler/tc_Rescue.git
cd tc_Rescue/scripts
./Utils_Build.sh
```

**Utils_Build.sh** will update you system, install all neccessary packages and build utilites for `Resc_wallet_deploy.sh`

## Using
To success using the script, you have to know:
 - SRC address - from which you want to save tokens
 - "seed phrase" of SRC address
 - DST address - address to tranfer tokens. Be absolutele shure that you have control on this address.

To start procedure do:

```bash
cd $HOME/tc_Rescue/scripts
./Resc_wallet_deploy.sh "SRC address" "seed phrase" "DST address"  
```
SRC and DST addresses can be in HEX or in Base64 formats

##### Exapmle

```bash
cd $HOME/tc_Rescue/scripts
./Resc_wallet_deploy.sh "0:fe6aac00f877b8a270b56492028f1238555a17e670009042d7d53bd26d273234" "hurt  envelope inflict trip truth latin prosper coffee spy chair legend finger" "0:905D4D712F0EF0EAE11CAF89678D2F2CE1A533E080E8D33A1BC6CA4F750846E9"  
```
or 
```bash
cd $HOME/tc_Rescue/scripts
./Resc_wallet_deploy.sh "EQD-aqwA-He1onC1ZJICj7M4VVoX6nAAkELX1TvSbScyNOzZ" "hurt envelope inflict trip truth latin prosper coffee spy chair legend finger" "EQCQXU1xLw9w6uEcr4pK_S1s4aUz4IDo0zobxspPdQhG3eYZ"  
```
P.S. Addresses and seeds are fake in this example

The script has additional last parametr **`force`** If you place it at the end of command, the script will ignore checking SRC for already deployed and that DST is not deployed. It's dangerous. Be carefully!


## How it works

The script takes seedphrase and generate addresses from it for each contract from list in file  
```bash
tc_Rescue/contracts/Contracts_List.json  
```
If calculated address is equal to given SRC address, the script deploy contract code to SRC address and than transfer tokens to DST address.
Keys and logs files will be placed to `tc_Rescue/ton-keys` folder

Contracts codes placed in `tc_Rescue/contracts/` folder  
You can place new contract (tvc and abi files) to this folder and add it to the list. 

## Check account state

You can check account state by run script

```bash
./balance_check.sh "address"
```

where **`address`** can be hex or base64 address format

##### Example

```bash
$ ./balance_check.sh "Ef8zMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzM0vF"

Time Now: 2021-11-30 22:35:20 MSK
Account: -1:3333333333333333333333333333333333333333333333333333333333333333
Status: Deployed and Active
Has balance : 198827312.140 tokens
Last operation time: 1970-01-01 03:00:00
==================================================================================================
```

P.S. The script is open and free - but, if you need human help - then write a request in issues - but the work will cost % of the amount.
