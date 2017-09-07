#!/bin/bash

# nrfprog - a loose shell port of nrfjprog.exe for bash

#### CONSTANTS



read -d '' USAGE <<- EOF
nrfprog.sh

This is a loose shell port of the nrfjprog.exe program distributed by Nordic,
which relies on JLinkExe to interface with the JLink hardware.

usage:

nrfjprog <action> [hexfile]

where action is one of
  --reset
  --pinreset
  --erase-all
  --gdb-server
  --program
  --programs
  --recover
  --rtt
EOF

GREEN="\033[32m"
RESET="\033[0m"
SCRIPT="/tmp/$(basename $0).$$.jlink"

JLINK="JLinkExe $JLINK_OPTIONS -if swd -speed 1000 -device nrf51"
JLINKGDBSERVER="JLinkGDBServer $JLINK_OPTIONS -if swd -speed 1000 -port 2331"
GDB="arm-none-eabi-gdb"
GDB_INIT="/tmp/$(basename $0).$$.gdbinit"

#### FUNCTIONS

execute ()
{
    echo "$1" > "$SCRIPT"
    $JLINK "$SCRIPT"
    rm "$SCRIPT"
}

reset ()
{
    echo ""
    echo -e "${GREEN}resetting...${RESET}"
    echo ""
    echo "r"     > "$SCRIPT"
    echo "g"    >> "$SCRIPT"
    echo "exit" >> "$SCRIPT"
    $JLINK "$SCRIPT"
    rm "$SCRIPT"
}

pinreset ()
{
    # Magic incantations from
    # https://devzone.nordicsemi.com/question/18449/pin-reset-nrfjprog-p-equivalent-using-jlinkexe/
    echo ""
    echo -e "${GREEN}resetting with pin...${RESET}"
    echo ""
    echo "w4 40000544 1" > "$SCRIPT"
    echo "si 0"         >> "$SCRIPT"
    echo "tck0"         >> "$SCRIPT"
    echo "t0"           >> "$SCRIPT"
    echo "sleep 10"     >> "$SCRIPT"
    echo "t1"           >> "$SCRIPT"
    echo "exit"         >> "$SCRIPT"
    $JLINK "$SCRIPT"
    rm "$SCRIPT"
}

erase-all ()
{
    echo ""
    echo -e "${GREEN}perfoming full erase...${RESET}"
    echo ""
    echo "w4 4001e504 2"  > "$SCRIPT"
    echo "w4 4001e50c 1" >> "$SCRIPT"
    echo "sleep 100"     >> "$SCRIPT"
    echo "r"             >> "$SCRIPT"
    echo "exit"          >> "$SCRIPT"
    $JLINK "$SCRIPT"
    rm "$SCRIPT"
}

flash ()
{
    echo ""
    echo -e "${GREEN}flashing ${1}...${RESET}"
    echo ""
    echo "r"            > "$SCRIPT"
    echo "loadfile $1" >> "$SCRIPT"
    echo "r"           >> "$SCRIPT"
    echo "g"           >> "$SCRIPT"
    echo "exit"        >> "$SCRIPT"
    $JLINK "$SCRIPT"
    rm "$SCRIPT"
    exit 0
}

flash-softdevice ()
{
    echo ""
    echo -e "${GREEN}flashing softdevice ${HEX}...${RESET}"
    echo ""

    # Write to NVMC to enable erase, do erase all, wait for completion. reset
    echo "w4 4001e504 2"  > "$SCRIPT"
    echo "w4 4001e50c 1" >> "$SCRIPT"
    echo "sleep 100"     >> "$SCRIPT"
    echo "r"             >> "$SCRIPT"

    # Write to NVMC to enable write. Write mainpart, write UICR. Assumes device is erased.
    echo "w4 4001e504 1" >> "$SCRIPT"
    echo "loadfile $1"   >> "$SCRIPT"
    echo "r"             >> "$SCRIPT"
    echo "g"             >> "$SCRIPT"
    echo "exit"          >> "$SCRIPT"
    $JLINK "$SCRIPT"
    rm "$SCRIPT"
}

gdb ()
{
    # trap the SIGINT signal so we can clean up if the user CTRL-C's out of the
    # GDB server
    trap ctrl_c INT
    echo -e "${GREEN}Starting GDB Server...${RESET}"
    $JLINKGDBSERVER &
    JLINK_PID=$!
    sleep 2
    echo -e "\n${GREEN}Connecting to GDB Server...${RESET}"
#    echo "target remote localhost:2331"               > "${GDB_INIT}"
#    echo "break main"                                >> "${GDB_INIT}"
#    echo "monitor speed auto"                        >> "${GDB_INIT}"
#    echo "set remote memory-write-packet-size 1024"  >> "${GDB_INIT}"
#    echo "set remote memory-write-packet-size fixed" >> "${GDB_INIT}"
    $GDB "$1" -readnow -ex 'target extended-remote :2331' "$1"
    echo -e "\n${GREEN}Killing GDB Server ($JLINK_PID)...${RESET}"
    kill $JLINK_PID
}

recover ()
{
    echo ""
    echo -e "${GREEN}recovering device. This can take about 3 minutes.${RESET}"
    echo ""
    echo "si 0"           > "$SCRIPT"
    echo "t0"            >> "$SCRIPT"
    echo "sleep 1"       >> "$SCRIPT"
    echo "tck1"          >> "$SCRIPT"
    echo "sleep 1"       >> "$SCRIPT"
    echo "t1"            >> "$SCRIPT"
    echo "sleep 2"       >> "$SCRIPT"
    echo "t0"            >> "$SCRIPT"
    echo "sleep 2"       >> "$SCRIPT"
    echo "t1"            >> "$SCRIPT"
    echo "sleep 2"       >> "$SCRIPT"
    echo "t0"            >> "$SCRIPT"
    echo "sleep 2"       >> "$SCRIPT"
    echo "t1"            >> "$SCRIPT"
    echo "sleep 2"       >> "$SCRIPT"
    echo "t0"            >> "$SCRIPT"
    echo "sleep 2"       >> "$SCRIPT"
    echo "t1"            >> "$SCRIPT"
    echo "sleep 2"       >> "$SCRIPT"
    echo "t0"            >> "$SCRIPT"
    echo "sleep 2"       >> "$SCRIPT"
    echo "t1"            >> "$SCRIPT"
    echo "sleep 2"       >> "$SCRIPT"
    echo "t0"            >> "$SCRIPT"
    echo "sleep 2"       >> "$SCRIPT"
    echo "t1"            >> "$SCRIPT"
    echo "sleep 2"       >> "$SCRIPT"
    echo "t0"            >> "$SCRIPT"
    echo "sleep 2"       >> "$SCRIPT"
    echo "t1"            >> "$SCRIPT"
    echo "sleep 2"       >> "$SCRIPT"
    echo "tck0"          >> "$SCRIPT"
    echo "sleep 100"     >> "$SCRIPT"
    echo "si 1"          >> "$SCRIPT"
    echo "r"             >> "$SCRIPT"
    echo "exit"          >> "$SCRIPT"
    $JLINK "$SCRIPT"
    rm "$SCRIPT"
}

rtt ()
{
    # trap the SIGINT signal so we can clean up if the user CTRL-C's out of the
    # RTT client
    trap ctrl_c INT
    echo -e "${GREEN}Starting RTT Server...${RESET}"
    $JLINK &
    JLINK_PID=$!
    sleep 1
    echo -e "\n${GREEN}Connecting to RTT Server...${RESET}"
    JLinkRTTClient
    echo -e "\n${GREEN}Killing RTT Server ($JLINK_PID)...${RESET}"
    kill $JLINK_PID
}

memrd ()
{

	printf -v HEX_ADD "0x%08x" "$1"
    echo "mem8 $HEX_ADD, $2" > "$SCRIPT"
    echo "exit" >> "$SCRIPT"
    VALUE=$($JLINK "$SCRIPT" | grep -o -E ".{8} =( .{2})+" | grep -o -E "( [0123456789ABCDEF]{2})+")
    rm "$SCRIPT"
    printf "0x%08x:%s\n\n" "$1" "$VALUE"
	exit 0
}

ctrl_c ()
{
    return
}

#### MAIN

if [ $# -eq 0 ]; then
    echo "$USAGE" >&2
    exit 1
else
	for i in "$@"
	do
	#echo "$i"
       case "$i" in
            -r | --reset)   reset
                            ;;
            --pinreset)     pinreset
                            ;;
            --erase-all)    erase-all
                            ;;
            -x | --execute) shift
                            execute "$i"
                            ;;
            --gdb)          shift
                            gdb "$i"
                            ;;
            --program)      shift
                            flash "$1"
                            ;;
            --programs)     shift
                            flash-softdevice "$i"
                            ;;
            --recover)      recover
                            ;;
            --rtt)          rtt
                            ;;
            --memrd)		shift
							memrd "$1" "$5"
							;;
            *)              #echo "unexpected option '$i'" >&2
                            i=$((i + 1));
          esac
        shift
    done
fi
