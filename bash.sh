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
ARRAY_SIZE=$((DICE_COUNT * DICE_FACE - MIN_SUM + 1))

ITERATIONS=10000
MAX_PROB_LENGTH=80

# Initialize count array
count_array=()
i=$MIN_SUM
while [[ i -lt $((ARRAY_SIZE + 1)) ]]; do
  count_array[$i]=0
  i=$((i + 1))
done


# Function defined
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
    new_str=" ${new_str}"
    i=$((i + 1))
  done
  REGISTER_0="$new_str"
}

format_number(){
  reset_register
  local number=$1 
  local max_sum=$((DICE_FACE * DICE_COUNT))
  local max_length=${#max_sum}
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



  local formatted_prob=$(bc -l <<< "scale=2; ${prob}")

  local formatted_prob_length=${#formatted_prob}
  #local pad_length=$((12 - formatted_prob_length))
  local pad_length=0
  create_string 0 "$pad_length"
  formatted_prob="${formatted_prob}${REGISTER_0}"

  string="${formatted_prob}   ${string}"
  # string = f"{str(round(prob,10)).ljust(12, "0")}%  {string}"
  #
  # string="${string}${f"   {str(round(prob,6)).ljust(8, "0")}%"
  REGISTER_0="$string"
}






# Roll the dices
START_SECONDS=$SECONDS
iter=0
max_prob=0
while [[ $iter -lt $ITERATIONS ]]; do
  sum_roll_dice
  sum=$REGISTER_0
  count_array[$sum]=$((count_array[sum] + sum))

  if [[ $sum -gt $max_prob ]]; then
    max_prob=$sum
  fi

  iter=$((iter + 1))
done
DURATION=$((SECONDS - START_SECONDS))

# Calculate probabilities
i=$MIN_SUM
probabilities=()
while [[ $i -lt $((ARRAY_SIZE + 1)) ]]; do
  tmp_count=${count_array[$i]}
  probabilities[$i]=$(bc -l <<< "${tmp_count} * 100.0 / ${ITERATIONS}")
  #probabilities[$i]=$((tmp_count * 100.0 / ITERATIONS))

  i=$((i + 1))
done

i=$MIN_SUM
while [[ i -lt $((ARRAY_SIZE + 1)) ]]; do
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
  format_number $i
  string="${REGISTER_0}"
  format_probabilities $prob $prev $next $max_prob
  string="${string}  ${REGISTER_0}"
  echo "$string"
  i=$((i + 1))
done

echo "This took $DURATION seconds"
