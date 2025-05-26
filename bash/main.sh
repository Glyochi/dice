#!/usr/bin/env bash
set -Eeu pipefail

REGISTER_0=""
REGISTER_1=""
REGISTER_2=""
REGISTER_3=""
REGISTER_4=""
reset_register(){
  REGISTER_0=""
  REGISTER_1=""
  REGISTER_2=""
  REGISTER_3=""
  REGISTER_4=""
}

DICE_FACE=20
DICE_COUNT=11

MIN_SUM=$((DICE_COUNT * 1))
MAX_SUM=$((DICE_COUNT * DICE_FACE))
ARRAY_SIZE=$((DICE_COUNT * DICE_FACE - MIN_SUM + 1))

ITERATIONS=100000
ITERATIONS_PER_PROGRESS_ANNOUNCEMENT=100000
# Make sure there are at least 10 announcements
if [[ $((ITERATIONS / ITERATIONS_PER_PROGRESS_ANNOUNCEMENT)) -lt 10 ]]; then
  ITERATIONS_PER_PROGRESS_ANNOUNCEMENT=$((ITERATIONS / 10))
fi
MAX_PROB_LENGTH=80

# Initialize count array
count_array=()
i=$MIN_SUM
while [[ i -lt $((ARRAY_SIZE + MIN_SUM)) ]]; do
  count_array[$i]=0
  i=$((i + 1))
done


# Function defined
seconds_to_hms(){
  reset_register
  local total_seconds="$1"
  local hours="$((total_seconds / 3600))"
  local minutes="$((($total_seconds - hours * 3600) / 60))"
  local seconds="$(($total_seconds - hours * 3600 - minutes * 60))"


  REGISTER_0="$hours"
  REGISTER_1="$minutes"
  REGISTER_2="$seconds"
}

add_comma_to_number(){
  reset_register
  local number="$1"
  local breaking_point=3
  local result_str=""
  while [[ ${#number} -gt 3 ]]; do
    result_str=",${number:$((${#number} - 3)):${#number}}${result_str}"
    number="${number:0:$((${#number} - 3))}"
  done
  result_str="${number}${result_str}"
  REGISTER_0="${result_str}"
}

roll_dice(){
  reset_register
  REGISTER_0=$((RANDOM % (DICE_FACE) + 1))
}

sum_roll_dice(){
  reset_register
  local sum=0
  local counter=0
  while [[ $counter -lt $DICE_COUNT ]]; do
    roll_dice
    sum=$((sum + REGISTER_0))
    counter=$((counter + 1))
  done

  REGISTER_0=$sum
}

create_string(){
  reset_register
  local pad_char="$1"
  local length="$2"
  local new_str=""
  local i=0
  while [[ $i -lt $length ]]; do
    new_str="${1}${new_str}"
    i=$((i + 1))
  done
  REGISTER_0="$new_str"
}

format_number(){
  reset_register
  local number=$1 
  local max_number=$2 
  local max_length=${#max_number}
  local cur_length=${#1}

  local new_str="$1"
  while [[ $cur_length -lt $max_length ]]; do
    new_str=" ${new_str}"
    cur_length=$((cur_length + 1))
  done
  REGISTER_0="$new_str"
}




format_probabilities(){
  reset_register
  local prob=$1
  local prev=$2
  local next=$3
  local max_prob=$4
    

  # We want to round up to integer for displaying graph
  local prev_count=$(bc <<< "scale=0; ${prev} * ${MAX_PROB_LENGTH} / ${max_prob}")
  local count=$(bc <<< "scale=0; ${prob} * ${MAX_PROB_LENGTH} / ${max_prob}")
  local next_count=$(bc <<< "scale=0; ${next} * ${MAX_PROB_LENGTH} / ${max_prob}")

  local i=0
  local string="|"
  while [[ $i -lt $count ]]; do
    string="${string}⠿"
    i=$((i + 1))
  done

  local big_up_symbol="⠍"
  local big_down_symbol="⠥"
  local big_both_symbol="⠅"
  local up_symbol="⠁"
  local down_symbol="."
  local both_symbol="⠅"
  
  if [[ $prev_count -gt $count && $next_count -gt $count ]]; then
      string="${string}${big_both_symbol}"
  elif [[ $prev_count -gt $count ]]; then
      string="${string}${big_up_symbol}"
  elif [[ $next_count -gt $count ]]; then
      string="${string}${big_down_symbol}"
      
  elif [[ $count -eq 0 ]]; then
    if [[ $(bc <<< "$prev < $prob") -eq 1 && $(bc <<< "$next < $prob") -eq 1 ]]; then
          string="${string}${both_symbol}"
      elif [[ $(bc <<< "$prev < $prob") -eq 1 ]]; then
          string="${string}${up_symbol}"
      elif [[ $(bc <<< "$next < $prob") -eq 1 ]]; then
          string="${string}${down_symbol}"
      fi
  fi


  # Round it up
  local round_after_decimal=6
  local formatted_prob=$(bc -l <<< "scale=$round_after_decimal; ${prob}")

  # Format it if less than 1%
  local before_decimal_str="${formatted_prob%%.*}" 

  local formatted_length=0
  # If its in '.123' => make it '0.123'
  if [[ ${#before_decimal_str} -eq 0 ]]; then
    before_decimal_str="0"
    formatted_prob="${before_decimal_str}${formatted_prob}"
  fi

  # If it does not have a decimal point => before = full string
  if [[ "${before_decimal_str}" == "${formatted_prob}" ]]; then
    create_string 0 "$round_after_decimal"
    formatted_prob="${before_decimal_str}.${REGISTER_0}"
  fi

  # before decimal + the '.' + after decimal
  target_formatted_length=$(( ${#before_decimal_str} + 1 + ${round_after_decimal} ))

  # Remove the trailing
  formatted_prob="${formatted_prob:0:${target_formatted_length}}"
  if [[ ${#formatted_prob} -lt $target_formatted_length ]]; then
    create_string 0 $((target_formatted_length - ${#formatted_prob}))
    formatted_prob="${formatted_prob}${REGISTER_0}"
  fi


  string="${formatted_prob}% ${string}"
  REGISTER_0="$string"
}

report_progress(){
  reset_register
  local current_iter="$1"
  local total_iter="$2"
  local elapsed_total_seconds="$3"
  
  # We want percentage to be in format of ' x.xx' or 'xx.xx'. 
  # Never '100.xx'. Maybe if you want to thats fine too whatever your heart desires
  local percentage="$(bc <<< "scale=2; ${current_iter} * 100 / ${total_iter}")"
  local before_decimal_str="${percentage%%.*}" 
  # In case you get '.123' not ' 0.123'
  if [[ "${before_decimal_str}" == "" ]]; then
    before_decimal_str=" 0"
    percentage="${before_decimal_str}${percentage}"
  fi

  # In case you get '1.123' not ' 1.123'
  if [[ "${#before_decimal_str}" -eq 1 ]]; then
    before_decimal_str=" ${before_decimal_str}"
    percentage=" ${percentage}"
  fi

  # Add the %
  percentage="${percentage}%"

  seconds_to_hms "$elapsed_total_seconds"
  local elapsed_h="$REGISTER_0"
  local elapsed_m="$REGISTER_1"
  local elapsed_s="$REGISTER_2"
  if [[ "${#elapsed_m}" -lt 2 ]]; then 
    elapsed_m="0${elapsed_m}"
  fi
  if [[ "${#elapsed_s}" -lt 2 ]]; then 
    elapsed_s="0${elapsed_s}"
  fi

  local eta_total_seconds=$(bc <<< "scale=0; ${elapsed_total_seconds} * (${total_iter} - ${current_iter}) / ${current_iter}")
  seconds_to_hms "$eta_total_seconds"
  local eta_h="$REGISTER_0"
  local eta_m="$REGISTER_1"
  local eta_s="$REGISTER_2"
  if [[ "${#eta_m}" -lt 2 ]]; then 
    eta_m="0${eta_m}"
  fi
  if [[ "${#eta_s}" -lt 2 ]]; then 
    eta_s="0${eta_s}"
  fi

  add_comma_to_number "$current_iter"
  local formatted_current_iter="$REGISTER_0"
  add_comma_to_number "$total_iter"
  local formatted_total_iter="$REGISTER_0"

  create_string " " $((${#formatted_total_iter} - ${#formatted_current_iter}))
  formatted_current_iter="${REGISTER_0}${formatted_current_iter}"

  local final_str="Progress: ${percentage}  ${formatted_current_iter}/${formatted_total_iter}  Elapsed ${elapsed_h}:${elapsed_m}:${elapsed_s}  ETA ${eta_h}:${eta_m}:${eta_s}"
  
  REGISTER_0="$final_str"
}






# Roll the dices

START_SECONDS=$SECONDS
iter=0
while [[ $iter -lt $ITERATIONS ]]; do
  sum_roll_dice
  sum=$REGISTER_0
  count_array[$sum]="$((count_array[sum] + 1))"

  iter=$((iter + 1))

  # Report progress
  if [[ $((iter % ITERATIONS_PER_PROGRESS_ANNOUNCEMENT)) -eq 0 ]]; then
    report_progress $iter $ITERATIONS $((SECONDS - START_SECONDS))
    echo "$REGISTER_0"
  fi

done

# Get speed stats
DURATION=$((SECONDS - START_SECONDS))
seconds_to_hms "$DURATION"
DURATION_HOUR="$REGISTER_0"
DURATION_MINUTE="$REGISTER_1"
DURATION_SECOND="$REGISTER_2"


iter=0

# Get stats (probabilities and occurance count)
i=$MIN_SUM
max_prob=0
max_count=0
probabilities=()
while [[ $i -lt $((ARRAY_SIZE + MIN_SUM)) ]]; do

  tmp_count=${count_array[$i]}
  probabilities[$i]="$(bc -l <<< "${tmp_count} * 100.0 / ${ITERATIONS}")"

  if [[ ${count_array[$i]} -gt $max_count ]]; then
    max_count=${count_array[$i]}
    max_prob="${probabilities[$i]}"
  fi

  i=$((i + 1))
done



# Runtime stats
echo ""
echo ""
echo ""
echo ""
add_comma_to_number "${ITERATIONS}"
echo "Rolling and summing 11 20-face-dice ${REGISTER_0} times"
echo "Simulating with Bash"
echo "Total processing time is ${DURATION} seconds or ${DURATION_HOUR} hour(s) ${DURATION_MINUTE} minute(s) ${DURATION_SECOND} second(s)"
#print(f"Total processing time is {round(processing_duration_ms):,} miliseconds or {p_h} hour(s) {p_m} minute(s) {p_s} second(s)")


# Print out the distribution
i=$MIN_SUM
while [[ i -lt $((ARRAY_SIZE + MIN_SUM)) ]]; do
  prob=${probabilities[$i]}

  prev=$prob
  next=$prob

  if [[ $i -gt MIN_SUM ]]; then
    prev=${probabilities[$((i - 1))]}
  fi

  if [[ $i -lt $((ARRAY_SIZE - 1)) ]]; then
    next=${probabilities[$((i + 1))]}
  fi

  string=""
  format_number $i $MAX_SUM
  string="${REGISTER_0}"
  format_number ${count_array[$i]} $max_count
  string="${string}  ${REGISTER_0}"
  format_probabilities $prob $prev $next $max_prob
  string="${string}  ${REGISTER_0}"
  echo "$string"
  i=$((i + 1))
done

