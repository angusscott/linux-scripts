# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

#######################################################
# Automatic setting of $DISPLAY (if not set already).
#######################################################
function _update_ps1() {
    eval "$($GOPATH/bin/powerline-go -error $? -shell bash -eval -modules venv,user,host,ssh,cwd,perms,git,hg,jobs,exit,root,kube)"
}

if [ "$TERM" != "linux" ] && [ -f "$GOPATH/bin/powerline-go" ]; then
    PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
fi

#######################################################
# Automatic setting of $DISPLAY (if not set already).
#######################################################

function get_xserver ()
{
    case $TERM in
        xterm )
            XSERVER=$(who am i | awk '{print $NF}' | tr -d ')''(' )
            XSERVER=${XSERVER%%:*}
            ;;
            aterm | rxvt)
            ;;
    esac
}

if [ -z ${DISPLAY:=""} ]; then
    get_xserver
    if [[ -z ${XSERVER}  || ${XSERVER} == $(hostname) ||
       ${XSERVER} == "unix" ]]; then
          DISPLAY=":0.0"          # Display on local host.
    else
       DISPLAY=${XSERVER}:0.0     # Display on remote host.
    fi
fi



#######################################################
# EXPORTS
#######################################################

export HISTIGNORE="ls:ll:cd:pwd:bg:fg:history"
export HISTCONTROL=ignoredups
export HOSTFILE=$HOME/.hosts    # Put a list of remote hosts in ~/.hosts
export HISTSIZE=100000
export HISTFILESIZE=10000000

export HTTP_PROXY=
export HTTPS_PROXY=
export NO_PROXY=

export LIGHTSAIL_IP=

#######################################################
# ALIASES
#######################################################

alias bashrc='vim ~/.bashrc'
alias loadbash='source ~/.bashrc'
alias o=xdg-open
alias hist='history'
alias q='exit'
alias kc='kubectl'
alias lightsail='ssh ec2-user@${LIGHTSAIL_IP}'

#######################################################
# FUNCTIONS
#######################################################

# Provide a hardware and kernel summary
function hw {
    echo -e "-------------------------------System Information-----------------------------"
    echo -e "Hostname:\t\t"`hostname`
    echo -e "uptime:\t\t\t"`uptime | awk '{print $3,$4}' | sed 's/,//'`
    echo -e "Manufacturer:\t\t"`cat /sys/class/dmi/id/chassis_vendor`
    echo -e "Product Name:\t\t"`cat /sys/class/dmi/id/product_name`
    echo -e "Version:\t\t"`cat /sys/class/dmi/id/product_version`
    echo -e "Machine Type:\t\t"`vserver=$(lscpu | grep Hypervisor | wc -l); if [ $vserver -gt 0 ]; then echo "VM"; else echo "Physical"; fi`
    echo -e "Operating System:\t"`hostnamectl | grep "Operating System" | cut -d ' ' -f5-`
    echo -e "Kernel:\t\t\t"`uname -r`
    echo -e "Architecture:\t\t"`arch`
    echo -e "Active User:\t\t"`w | cut -d ' ' -f1 | grep -v USER | xargs -n1`
    echo -e "System Main IP:\t\t"`hostname -I`
    echo ""
    echo -e "-------------------------------CPU/Memory Usage------------------------------"
    echo -e "Processor Name:\t\t"`awk -F':' '/^model name/ {print $2}' /proc/cpuinfo | uniq | sed -e 's/^[ \t]*//'`
    echo -e "Socket(s):\t\t"`lscpu | grep 'Socket(s)' | awk '{print $2}'`
    echo -e "Core(s) Per Socket:\t"`lscpu | grep 'Core(s) per socket' | awk '{print $4}'`
    echo -e "Thread(s) Per Core:\t"`lscpu | grep 'Thread(s) per core' | awk '{print $4}'`
    echo -e "NUMA node(s):\t\t`lscpu | grep 'NUMA node(s)' | awk '{print $3}'`"
    echo -e "`lscpu | grep 'NUMA node[0-9]\+ CPU(s)'| awk '{print $1,$2,$3,"\011"$4}'`"
    echo -e "CPU Usage:\t\t"`cat /proc/stat | awk '/cpu/{printf("%.2f%\n"), ($2+$4)*100/($2+$4+$5)}' |  awk '{print $0}' | head -1`
    echo ""
    echo -e "Total Memory:\t\t"`lsmem | grep 'Total online memory:'  | awk '{print $4}'`
    echo -e "Memory Usage:\t\t"`free | awk '/Mem/{printf("%.2f%"), $3/$2*100}'`
    echo -e "Swap Usage:\t\t"`free | awk '/Swap/{printf("%.2f%"), $3/$2*100}'`
    echo ""
    echo -e "-------------------------------Kernel Tweaks------------------------------"
    echo -e "Transparent Huge Pages:\t"`cat /sys/kernel/mm/transparent_hugepage/enabled | grep -Po '\[\K[^]]*'`
    echo -e "Swappiness:\t\t"`sysctl vm.swappiness | awk '{print $3}'`
    echo -e "Min Free Kilobytes:\t"`sysctl vm.min_free_kbytes | awk '{print $3}'`
    echo -e "Zone Memory Reclaim:\t"`sysctl vm.zone_reclaim_mode | awk '{print $3}'`
    echo -e "Max Memory Mappings:\t"`sysctl vm.max_map_count | awk '{print $3}'`
    echo ""
    echo -e "-------------------------------Disk Usage >80%-------------------------------"
    df -Ph | sed s/%//g | awk '{ if($5 > 80) print $0;}'
    echo ""
}

# Quick and easy Python webserver, handy for quickly sharing files between machines
function webserver(){
    port=${1:-8080}
    version=$(python -V 2>&1 | grep -Po '(?<=Python )(.+)')
    parsedVersion=$(echo "${version//./}")
    if [[ "$parsedVersion" -gt "300" ]]
    then
        python -m http.server $port
    elif [[ "$parsedVersion" -gt "270" ]]
    then
        python -m SimpleHTTPServer $port
    else
        echo "Python not installed"
    fi
}

# View and switch kubectl configs
function kubectx(){
    if [ $# -eq 0 ]
        then
            kubectl config get-contexts
        else
            kubectl config use-context $1
    fi
}

#Print Affinity for a process by pattern
function affinity(){
	pid=$(pgrep -f "$1")
	taskset -pc $pid
}



# Awesome London tube status script (https://github.com/smallwat3r/tubestatus)
function tubestatus {

    set -e

    if ! command -v jq &>/dev/null; then
      printf "Error: You need to install jq to run this script
    https://stedolan.github.io/jq/download/\n"
      exit 1
    fi

    LINE_SEARCH=$1
    DELIMITER="¬"
    RED="\033[38;5;161m"
    GREEN="\033[38;5;082m"
    YELLOW="\033[38;5;226m"
    NONE="\033[0m"
    URL="https://api.tfl.gov.uk/line/mode/tube,overground,dlr,tflrail/status"

    curl -s $URL |
      jq --arg delim $DELIMITER -j '.[] |
        (.name) + $delim,
        (.lineStatuses[0] | (.statusSeverity),
        $delim + (.statusSeverityDescription),
        $delim + (.reason) + "\n")' |
      awk -F $DELIMITER -v delim=$DELIMITER -v r=$RED \
        -v y=$YELLOW -v g=$GREEN -v n=$NONE -v line=$LINE_SEARCH '{
          if ( $4 ) reason=$4;
          else reason="";
          if ( $2 == 10 ) color=g;
          else if ( $2 == 20 ) color=r;
          else if ( $2 >= 8 ) color=y;
          else color=r;
          if ( index(tolower($1), tolower(line)) )
            print color "●" n, $1 delim $3 delim reason;
        }' | column -t -s $DELIMITER

}
