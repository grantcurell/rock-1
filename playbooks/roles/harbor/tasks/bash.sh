export CLR='\e[0m' RED='\e[31m' GRN='\e[32m' YEL='\e[33m' MAG='\e[35m' CYN='\e[36m'

# Wrappers for log_msg to log contextual messages
stub_msg(){ log_msg ${MAG} "\n__________________________  ${1}" "\n"; }
head_msg(){ log_msg ${MAG} "\n[ ==== ] ${1}" " "; }
info_msg(){ log_msg ${CYN}   "[ INFO ]" "${1}"; }
attn_msg(){ log_msg ${GRN}   ">>>>>>>>" "${1}" no-eol no-log-file; }
warn_msg(){ log_msg ${YEL}   "[ WARN ]" "${1}"; }
fail_msg(){ log_msg ${RED} "\n[ FAIL ]" "${1}"; }
err_msg(){  log_msg ${RED}   "[ ERR  ]" "${1}"; }
ok_msg(){   log_msg ${GRN}   "[  OK  ]" "${1}"; }

# Presents a prompt w/ standardized formatting to a user, requesting input
#  - ARG 1: The message to print
#  - ARG 2: The default value if an empty value is supplied by the user
#  - return: The returned value is in the global `REPLY` variable
#  - if no default is specified, the prompt loops until the user supplies input
export REPLY=""
prompt(){
  local msg=${1} default=${2}
  REPLY=""

  case ${default} in
    '')
      while [ ! ${REPLY} ]; do
        attn_msg "${msg}: [${default}] "
        read REPLY
      done
    ;;
    *)
      attn_msg "${msg}: [${default}] "
      read REPLY
      [ ${REPLY} ] || REPLY=${default}
    ;;
  esac
}

# Formats a message for logging to both the terminal and a logfile
#  Allows for pretty colors in the terminal
#  Ensures ANSI escapes stay out of the log file
# [ WARN ] Not meant to be used directly, use the supplied wrappers defined after
log_msg(){
  local color=${1} prefix=${2} msg=${3}; shift 3
  local echo_args='-e'
  local stdout='y'
  local log_file='y'

  while [ ${1} ]; do
    case ${1} in
      'no-eol') echo_args=${echo_args}n ;;
      'no-stdout') stdout='' ;;
      'no-log-file') log_file='' ;;
    esac
    shift
  done

  [ ${stdout} ] && echo ${echo_args} "${color}${prefix}${CLR} ${msg}"
  [ ${log_file} ] && echo ${echo_args} "${prefix} ${msg}" >> ${LOG_FILE}
}


#################################################################################################################
# This function grabs the first interface on the computer which is in the up state
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   active_interface: Returns the first interface encountered
#################################################################################################################

get_active_interface() {
  active_interface=$(ip link show up | cut -d ' ' -f 2 | grep -e "^e" | sed -n 1p | sed s/://g)
}

#################################################################################################################
# Ask a user for what interface they would like to assign something
# Globals:
#   None
# Arguments:
#   The prompt you would like displayed
# Returns:
#   interface_name: The name of the interface the user selected
#################################################################################################################

prompt_for_interface() {

  get_active_interface

  set +e
  prompt "${1}" "${active_interface}"
  set -e

  interface_name=${REPLY}

}

#################################################################################################################
# Performs a wget and verifies the file is there and the download was successful
# Globals:
#   None
# Arguments:
#   The URL
#   The directory you would like to download to
# Returns:
#   None
#################################################################################################################
wget_plus() {

  local url="${1}"
  local filename="${url##*/}"

  # Check to see if we already have the tar file first, if not, download it.
  if [ ! -f "${2}${filename}" ]; then

    wget -P "${2}" "${url}"

    # Make sure wget was successful
    if [[ $? -ne 0 ]]; then
      err_msg "WGET failed. Could not download ${filename}."
      break
    fi
  else
    warn_msg "${filename} file already downloaded. Skipping."
  fi

}

#################################################################################################################
# Forcefully, throws an error in the framework. It works by attempting to make a directory root, which will
# always already exist.
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#################################################################################################################
throw_error() {
  mkdir /
}

#################################################################################################################
# Checks to make sure a service is enabled and starts it. If it isn't enabled, this function enables it.
# Globals:
#   None
# Arguments:
#   The name of the service that you would like to start and enable
# Returns:
#   None
#################################################################################################################
enable_service() {

  service_name=$1

  if [[ ! $(systemctl list-unit-files | grep "${service_name}.service" | awk -F ' ' '{ print $2 }') == "enabled" ]]; then
    info_msg "${service_name} not enabled, enabling."
    systemctl enable "${service_name}"
  fi

  if [[ ! $(systemctl status "${service_name}" | grep Active: | awk -F ' ' '{ print $2 }') == "active" ]]; then
    info_msg "${service_name} not started, starting."
    systemctl start "${service_name}"
  fi

  if [[ ! $(systemctl status "${service_name}" | grep Active: | awk -F ' ' '{ print $2 }') == "active" ]]; then
    echo "${service_name} still not running, quitting."
    throw_error
  fi

}

#################################################################################################################
# Checks to see if a package is already installed. If it is, returns true, else, false
# Globals:
#   None
# Arguments:
#   The name of the package you would like to check for
# Returns:
#   echos - If the package is installed, T is echoed. If the package is not installed, F is echoed
#################################################################################################################
check_for_package() {

  package_name="${1}"

  info_msg "Checking for package ${package_name}"
  if [[ ! $(rpm -q "${package_name}" | grep 'is not installed') ]]; then
    info_msg "${package_name} is already installed."
    echo 'T'
  else
    info_msg "${package_name} is not installed"
	echo 'F'
  fi

}

#################################################################################################################
# Checks to see if a package is already installed. If it is, it skips it, otherwise it installs it
# Globals:
#   None
# Arguments:
#   The name of the package you would like to check for
#   Optionally, you may provide the location of the RPM package
# Returns:
#   None
#################################################################################################################
install_package() {

  package_name="${1}"

  # This removes the rpm extension from the end of the package name if it is provided. rpm -q will not find the package
  # if it is terminated with rpm
  package_name_sans_rpm=$(echo "${package_name}" | sed s/.rpm//g)

  info_msg "Checking for package ${package_name}"
  if [[ ! $(rpm -q "${package_name_sans_rpm}" | grep 'is not installed') ]]; then
    warn_msg "${package_name} is already installed, skipping."
  else

    # Check to see if the user provided a path to the RPM. If they didn't it just runs a yum without a path
    if [[ -z "${2}" ]]; then
	  info_msg "Installing ${package_name}"
      yum install -y "${package_name}"
	else
	  info_msg "Installing ${2}${package_name}"
	  yum install -y "${2}${package_name}"
	fi
  fi

}

export -f install_package
export -f enable_service
export -f get_active_interface
export -f prompt_for_interface
export -f wget_plus
export -f throw_error
export -f prompt
export -f log_msg
export -f head_msg
export -f info_msg
export -f attn_msg
export -f warn_msg
export -f fail_msg
export -f err_msg
export -f ok_msg
