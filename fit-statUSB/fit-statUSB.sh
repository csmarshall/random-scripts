#!/bin/bash 

COMMAND_STRING=""
SPEED=1000

function ts() {
  echo -n "$(date +'%F %H:%M:%S') ${FUNCNAME[1]}: " >&2
  echo $* >&2;
}

function getDir() {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    echo $DIR
}

SCRIPT_DIR="$(getDir)"

function speed () {
    SPEED=0500
    case ${1} in
        slow)
            SPEED=3000
            ;;
        medium)
            SPEED=1000
            ;;
        fast)
            SPEED=0500
            ;;
        ultra)
            SPEED=0100
            ;;
        * )
            re='^[0-9]+$'
            if [[ ${1} =~ $re ]] ; then
                SPEED=$(printf -v j "%04d" ${1})
            fi
            ;;
    esac
    echo  -n "${SPEED}"
}

function color () {
    source ${SCRIPT_DIR}/color_pallete.include
    ts "Setting color: ${COLOR}"
    echo -n "${COLOR}"
}

function send_command () {
    ts "Sending command: ${1}"
    echo ${1} > /dev/ttyACM0
} 

# Call getopt to validate the provided input. 
while getopts "a:b:c:d:s:o:lhp" opt; do
  case $opt in
    a|c)
      COMMAND_STRING="${COMMAND_STRING}B"
      for COLOR in $(echo ${OPTARG} | sed -e 's/:/ /g'); do
          ts "Adding color ${COLOR}"
          COMMAND_STRING="${COMMAND_STRING}$(color ${COLOR})-SPEED"
      done
      ;;
    b)
      ts "Blinking: ${COLOR}"
      COMMAND_STRING="${COMMAND_STRING}B$(color ${OPTARG})-SPEED#000000-SPEED"
      ;;
    d)
      ts "Duration of ${OPTARG} seconds"
      DURATION="${OPTARG}"
      ;;
    s)
      ts "Setting speed: ${OPTARG}"
      SPEED="$(speed ${OPTARG})"
      ;;
    o)
      ts "Setting solid light: ${OPTARG}"
      send_command "$(color ${OPTARG})"
      exit
      ;;
    p)
      ts "Color will \"pulse\""
      PULSE=true
      ;;
    l)
      ts "Available Colors"
      cat color_pallete.include | grep -A1 COLOROPTION | less 
      exit 0
      ;;
    h)
      echo "Help:"
      echo -e "-a COLOR1:COLOR2 - Alternating\n-b COLOR - Blink\n-c COLOR1:COLOR2:COLOR3 - Several Colors\n-d <seconds> - Duration in seconds\n-s (slow|medium|fast|ultra) - Speed\n-o COLOR - Solid Color\n-p - Pulse colors\n-l - List Colors"
      exit 0
      ;;
  esac
done

shift "$((OPTIND - 1))"

if [ -z "${COMMAND_STRING}" ]; then
    ts "No commands, turning off"
    send_command "$(color off)"
    exit 0
fi

COMMAND_STRING="$(echo ${COMMAND_STRING} | sed -e "s/SPEED/${SPEED}/g")"

if [[ ${PULSE} ]] ; then
    ts "Pulsing" > /dev/stderr
    PULSE_SPEED=$((${SPEED}*2))
    COMMAND_STRING="$(echo ${COMMAND_STRING} | sed -e "s/${SPEED}$/${PULSE_SPEED}/g")"
fi

send_command ${COMMAND_STRING}

if [ ! -z "${DURATION}" ] ;then
    ts "Running for ${DURATION} sec(s)"
    nohup sh -c "sleep ${DURATION} ; echo '#000000' > /dev/ttyACM0" &> /dev/null &
fi

