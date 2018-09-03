# c (color)
# a (action)
# h (help)
# p (print stdout)
# e (print stderr)
# l (log to file)
# u (util)

LIB_DIR=${LIB_DIR:-"./lib"}
_LOADED_LIBS=()

# log levels:
# 0 - debug
# 1 - info
# 2 - warning
# 3 - error
LOG_LEVEL=1

l:() {
  local level="$1"
  local msg="$2"

  local color=""
  local current_level="${LOG_LEVEL:-"1"}"
  local level_name=""

  if [[ ! "$level" =~ /^\d/ ]]; then
    case "$level" in
      d*|debug)
        level='0'
        color="purple"
        level_name="debug"
        ;;
      #info) <-- handled by default
      w*|warn)
        level='2'
        color="yellow"
        level_name="warn"
        ;;
      e*|error)
        level='3'
        color="red"
        level_name="error"
        ;;
      *)
        level='1'
        color="cyan"
        level_name="info"
        ;;
    esac
  fi

  if [[ "$level" -ge "$current_level" ]]; then
    l::handler "$level" "$level_name" "$color" "$msg"
  fi
}

l::handler() {
  local level="$1"
  local level_name="$2"
  local color="$3"
  local msg="$4"

  local datestamp="$( gdate --utc --rfc-3339=ns )"
  color="$(c: $color)"

  printf "[%s] |%-5s| $color%s$(c::reset)\n" "$datestamp" "$level_name" "$msg"
}

_::cols() {
  echo "${COLS:-"$(tput cols)"}"
}

u::die() {
  echo "$@"
  exit 1
}

u::import() {
  local libs=("$@")
  local lib_path

  if [[ "${#libs[@]}" -eq 0 ]]; then
    u::die "Oh no."
  fi

  for lib_name in "${libs[@]}"; do
    lib_path="${LIB_DIR}/${lib_name}.bash"
    if [[ -f "$lib_path" ]]; then
      . "$lib_path" \
        || u::die "Error loading lib: $lib_name"
    else
      u::die "Lib does not exist: $lib_name"
    fi
  done
}



p:() {
  local color="$1"; shift
  local indent=""
  local cols="$(_::cols)"

  local OPTIND OPTARG

  while getopts ":i:I:" arg "$@"; do
    case "$arg" in
      i)
        cols="$(( cols- OPTARG * 2 ))"
        indent="$( printf "  %.0s" $(seq 1 "$OPTARG" ) )"
        ;;
      I)
        if [[ "$OPTARG" -gt 0 ]]; then
          cols="$(( cols - OPTARG ))"
          indent="$( printf " %.0s" $(seq 1 "$OPTARG" ) )"
        fi
        ;;

      :)
        e::err "Option requires argument: -$OPTARG"
        return 1
        ;;

      \?)
        e::err "Invalid option: -$OPTARG"
        return 1
        ;;
    esac
  done

  shift $((OPTIND-1))

  local oldifs="$IFS"
  IFS=$'\n'

  lines=("$@")
  lines=( $(echo "${lines[@]}" | fold -s -w "$cols") )
  
  printf "${indent}$(c: "$color")%s$(c::reset)\n" "${lines[@]}"
  IFS="$oldifs"
}

p::list() {
  local bullet=" * "
  local bullet_color="bcyan"
  local color="white"
  local indent=""
  local indent_size=0
  local cols="$(_::cols)"

  local OPTIND OPTARG

  while getopts ":i:c:b:C:" arg "$@"; do
    case "$arg" in
      i)
        cols="$(( cols - OPTARG * 2 ))"
        indent="$( printf "  %.0s" $(seq 1 "$OPTARG" ) )"
        indent_size="$(( OPTARG * 2 ))"
        ;;
      c)
        color="$OPTARG"
        ;;
      C)
        bullet_color="$OPTARG"
        ;;
      b)
        bullet="$OPTARG"
        ;;

      :)
        e::err "Option requires argument: -$OPTARG"
        return 1
        ;;

      \?)
        e::err "Invalid option: -$OPTARG"
        return 1
        ;;
    esac
  done

  shift $((OPTIND-1))

  for item in "$@"; do
    item="$( p: "$color" -I "$((indent_size + ${#bullet} ))" "$item" | sed -E '1 s@^[[:space:]]+@@' )"
    printf "${indent}$(c: "$bullet_color")${bullet}${item}\n"
  done
}

p::2columns() {
  local left_color='bwhite'
  local right_color='white'
  local indent=""
  local indent_size=0
  local cols="$(_::cols)"

  local OPTIND OPTARG

  while getopts ":i:l:r:" arg "$@"; do
    case "$arg" in
      i)
        cols="$(( cols - OPTARG * 2 ))"
        indent="$( printf "  %.0s" $(seq 1 "$OPTARG" ) )"
        indent_size="$(( OPTARG * 2 ))"
        ;;
      l)
        left_color="$OPTARG"
        ;;
      r)
        right_color="$OPTARG"
        ;;
      
      :)
        e::err "Option requires argument: -$OPTARG"
        return 1
        ;;

      \?)
        e::err "Invalid option: -$OPTARG"
        return 1
        ;;
    esac
  done

  shift $((OPTIND-1))

  local args=("$@")
  local last_index="$(( ${#args[@]} - 1 ))"
  local gutter="  "
  local max_length=0
  local dt
  local dd

  # first figure out max size of left column
  for i in $( seq 0 2 "$last_index" ); do
    dt="${args[$i]}"

    if [[ "${#dt}" -gt "$max_length" ]]; then
      max_length="${#dt}"
    fi
  done

  # now iterate through and print everything
  for i in $( seq 0 2 "$last_index" ); do
    dt="${args[$i]}"
    dd="${args[$((i + 1))]}"

    gutter="$( printf " %0.s" $( seq 1 $(( max_length - ${#dt} + 2 )) ) )"

    dd="$(p: "$right_color" -I "$((indent_size + max_length + 2))" "$dd" | sed -E '1 s@^[[:space:]]+@@' )"

    printf "${indent}$(c: "$left_color")${dt}${gutter}${dd}\n"
  done
}

p::debug() {
  p: 'purple' "$@"
}

p::info() {
  p: 'cyan' "$@"
}

p::warn() {
  p: 'yellow' "$@"
}

p::err() {
  p: 'red' "$@"
}

e::debug() {
  p::debug "$@" >&2
}
e::info() {
  p::info "$@" >&2
}
e::warn() {
  p::warn "$@" >&2
}
e::err() {
  p::err "$@" >&2
}

c:() {
  local color="$1"

  case "$color" in
    off)           printf "\033[0m" ;;
    reset)         printf "\033[0m" ;;

    bold)          printf "\033[1m" ;;
    unbold)        printf "\033[22m" ;;

    # Colors
    black)         printf "\033[0;30m" ;;
    red)           printf "\033[0;31m" ;;
    green)         printf "\033[0;32m" ;;
    yellow)        printf "\033[0;33m" ;;
    blue)          printf "\033[0;34m" ;;
    purple)        printf "\033[0;35m" ;;
    cyan)          printf "\033[0;36m" ;;
    white)         printf "\033[0;37m" ;;

    # bold
    bblack)        printf "\033[1;30m" ;;
    bred)          printf "\033[1;31m" ;;
    bgreen)        printf "\033[1;32m" ;;
    byellow)       printf "\033[1;33m" ;;
    bblue)         printf "\033[1;34m" ;;
    bpurple)       printf "\033[1;35m" ;;
    bcyan)         printf "\033[1;36m" ;;
    bwhite)        printf "\033[1;37m" ;;

    # underline
    ublack)        printf "\033[4;30m" ;;
    ured)          printf "\033[4;31m" ;;
    ugreen)        printf "\033[4;32m" ;;
    uyellow)       printf "\033[4;33m" ;;
    ublue)         printf "\033[4;34m" ;;
    upurple)       printf "\033[4;35m" ;;
    ucyan)         printf "\033[4;36m" ;;
    uwhite)        printf "\033[4;37m" ;;

    # background
    on_black)      printf "\033[40m" ;;
    on_red)        printf "\033[41m" ;;
    on_green)      printf "\033[42m" ;;
    on_yellow)     printf "\033[43m" ;;
    on_blue)       printf "\033[44m" ;;
    on_purple)     printf "\033[45m" ;;
    on_cyan)       printf "\033[46m" ;;
    on_white)      printf "\033[47m" ;;

    # intense
    iblack)        printf "\033[0;90m" ;;
    ired)          printf "\033[0;91m" ;;
    igreen)        printf "\033[0;92m" ;;
    iyellow)       printf "\033[0;93m" ;;
    iblue)         printf "\033[0;94m" ;;
    ipurple)       printf "\033[0;95m" ;;
    icyan)         printf "\033[0;96m" ;;
    iwhite)        printf "\033[0;97m" ;;

    # bold intense
    biblack)       printf "\033[1;90m" ;;
    bired)         printf "\033[1;91m" ;;
    bigreen)       printf "\033[1;92m" ;;
    biyellow)      printf "\033[1;93m" ;;
    biblue)        printf "\033[1;94m" ;;
    bipurple)      printf "\033[1;95m" ;;
    bicyan)        printf "\033[1;96m" ;;
    biwhite)       printf "\033[1;97m" ;;

    # intense bg
    on_iblack)     printf "\033[0;100m" ;;
    on_ired)       printf "\033[0;101m" ;;
    on_igreen)     printf "\033[0;102m" ;;
    on_iyellow)    printf "\033[0;103m" ;;
    on_iblue)      printf "\033[0;104m" ;;
    on_ipurple)    printf "\033[10;95m" ;;
    on_icyan)      printf "\033[0;106m" ;;
    on_iwhite)     printf "\033[0;107m" ;;
  esac
}

c::reset() {
  c: reset
}

h::section() {
  local header="$1"; shift

}

