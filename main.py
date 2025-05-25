import time
from multiprocessing import Pool, Value, Lock
import json

GLY_RANDOM = False 
PYTHON_DEFAULT = True 
RAND_INT = False 
RAND_BIT = True 

def init_pool_processes(the_lock, the_finished_iterations):
    import numpy as np
    import random
    global lock
    global finished_iterations
    global rng
    global get_rand



    if GLY_RANDOM:
        def get_rand(rand_range):
            return 1
    else:
        if PYTHON_DEFAULT:
            if RAND_INT:
                def get_rand(rand_range):
                    return random.randint(1, rand_range + 1)
            elif RAND_BIT:
                def get_rand(rand_range):
                    num = rand_range 
                    while num > rand_range - 1:
                        num = random.getrandbits(5)
                    return int(num + 1) 
                    return int(random.random() * rand_range) + 1
            else:
                def get_rand(rand_range):
                    return int(random.random() * rand_range) + 1
        else:
            np.random.seed()
            rng = np.random.default_rng()

            if RAND_INT:
                def get_rand(rand_range):
                    random_number = rng.integers(low=1, high=rand_range + 1)
                    return random_number
            else:
                def get_rand(rand_range):
                    random_number = int(rng.random() * rand_range) + 1
                    return random_number
        

    lock = the_lock 
    finished_iterations = the_finished_iterations 

CORES = 6
BITE_SIZE_ITERATIONS = 10**6
CHECKPOINT_ITERATIONS = 10**2

RANGE = 20
DICE_COUNT = 11
#ITERATIONS = 10**6
ITERATIONS = 10**7

MIN_SUM = 1 * DICE_COUNT
ARRAY_SIZE = RANGE * DICE_COUNT - MIN_SUM + 1

BIGGEST_NUMBER = ARRAY_SIZE 
MAX_PROB_LENGTH = 120

MAX_PROB = 0

def format_number(number):
    return f"{str(number).rjust(len(str(BIGGEST_NUMBER)), ' ')}"

def format_probabilities(prob, prev, next, max_prob):
    prev_count = int(prev*MAX_PROB_LENGTH/max_prob)
    count = int(prob*MAX_PROB_LENGTH/max_prob)
    next_count = int(next*MAX_PROB_LENGTH/max_prob)
    string = f"|" + ("").rjust(count, "⠿")

    big_up_symbol = "⠍"
    big_down_symbol = "⠥"
    big_both_symbol = "⠅"
    up_symbol = "⠁"
    down_symbol = "."
    both_symbol = "⠅"
    
    if prev_count > count and next_count > count:
        string += big_both_symbol
    elif prev_count > count:
        string += big_up_symbol
    elif next_count > count:
        string += big_down_symbol

    elif count == 0:
        if prev < prob and next < prob:
            string += both_symbol
        elif prev < prob:
            string += up_symbol
        elif next < prob:
            string += down_symbol



    # 6 characters after decimal
    # 2 characters before decimal
    formatted_number = f"{round(prob,6):.6f}"

    tmp = formatted_number.split(".")
    before_decimal = tmp[0].rjust(2, " ")
    after_decimal = tmp[1].ljust(6, "0")
    string = f"{before_decimal}.{after_decimal}% {string}"
    # string += f"   {str(round(prob,6)).ljust(8, "0")}%"
    return string

def seconds_to_hms(seconds):

    s = seconds
    h = s // 3600
    s = s - h * 3600
    m = s // 60
    s = s - m * 60
    return h, m, s

def get_sum_rand(rand_range, iterations):
    sum = 0
    for i in range(iterations):
        sum += get_rand(rand_range)
    return sum

# print(get_sum_rand(20, 1))
# print(get_sum_rand(20, 1))
# print(get_sum_rand(20, 1))
# print(get_sum_rand(20, 1))
# print(get_sum_rand(20, 1))
# print(get_sum_rand(20, 1))
# exit()

def process(iterations):
    counter = [0] * ARRAY_SIZE
    
    for i in range(1, iterations + 1):
        number = get_sum_rand(RANGE, DICE_COUNT)
        counter[number - 1] += 1
        if i % CHECKPOINT_ITERATIONS == 0:
            with lock:
                finished_iterations.value += CHECKPOINT_ITERATIONS
    return counter




        



    

da_lock = Lock()
finished_iterations = Value('i', 0)


bite_size_tasks = [(BITE_SIZE_ITERATIONS,)] * int(ITERATIONS / BITE_SIZE_ITERATIONS)
if ITERATIONS % BITE_SIZE_ITERATIONS != 0:
    bite_size_tasks.append((ITERATIONS % BITE_SIZE_ITERATIONS,))

counter = [0] * ARRAY_SIZE



start_time = time.time_ns()
with Pool(processes=CORES, initializer=init_pool_processes, initargs=(da_lock, finished_iterations)) as p:
    result = p.starmap_async(process, bite_size_tasks)

    while not result.ready():
        current_time = time.time_ns()

        eta_s = 0
        eta_m = 0
        eta_h = 0

        e_h, e_m, e_s = seconds_to_hms(int((current_time - start_time) / 1000000000))
        if finished_iterations.value != 0:
            
            eta_h, eta_m, eta_s = seconds_to_hms(int(((current_time - start_time) * ITERATIONS / finished_iterations.value) / 1000000000))

        e_s = str(e_s).rjust(2, "0")
        e_m = str(e_m).rjust(2, "0")
        eta_s = str(eta_s).rjust(2, "0")
        eta_m = str(eta_m).rjust(2, "0")

        progress = str(round(finished_iterations.value * 100.0 / ITERATIONS, 2))
        tmp = progress.split(".") 
        before_decimal = tmp[0].rjust(3, " ")
        after_decimal = tmp[1].ljust(2, "0")

        finished_iterations_str = f"{finished_iterations.value:,}"
        finished_iterations_str = finished_iterations_str.rjust(len(f"{ITERATIONS:,}"), " ")

        print(f"Progress: {before_decimal}.{after_decimal}%  {finished_iterations_str}/{ITERATIONS:,}  Elapsed {e_h}:{e_m}:{e_s}  ETA {eta_h}:{eta_m}:{eta_s}")
        time.sleep(0.5)
        
    sub_counters = result.get()
    for sub_counter in sub_counters:

        for i in range(len(sub_counter)):
            counter[i] += sub_counter[i]

processing_duration_ms = round((time.time_ns() - start_time) / 1000000.0, 2)
p_h, p_m, p_s = seconds_to_hms(int(processing_duration_ms / 1000))



probabilities = [0.0] * ARRAY_SIZE
for number in range(MIN_SUM, ARRAY_SIZE + 1):
    i = number - 1
    probabilities[i] = counter[i] * 100.0 / ITERATIONS
    if probabilities[i] > MAX_PROB:
        MAX_PROB = probabilities[i]


print()
print()
print()
print()
print(f"Rolling and summing 11 20-face-dice {ITERATIONS:,} times over {CORES} processes")
string = f"Simulating with Python "
if PYTHON_DEFAULT:
    string += f"using python random implementation "
    if RAND_INT:
        string += f"(random.randint)."
    elif RAND_BIT:
        string += f"(random.getrandbits)."
    else:
        string += f"(random.random)."
else:
    string += f"using numpy random implementation "
    if RAND_INT:
        string += f"(rng.integers)."
    else:
        string += f"(rng.random)."

print(string)
print(f"Total processing time is {round(processing_duration_ms):,} miliseconds or {p_h} hour(s) {p_m} minute(s) {p_s} second(s)")

for number in range(MIN_SUM, ARRAY_SIZE + 1):
    i = number - 1
    prob = probabilities[i]
    prev = probabilities[i - 1] if i > 0 else prob
    next = probabilities[i + 1] if i < ARRAY_SIZE - 1 else prob
    print(f"{format_number(number)} {str(counter[i]).rjust(len(str(ITERATIONS)), ' ')} {format_probabilities(prob, prev, next, MAX_PROB)}")

with open(f"{DICE_COUNT}_{RANGE}-face-dice_{ITERATIONS:,}.json", "w") as f:
    json.dump({"iterations": ITERATIONS, "cores": CORES, "processing_duration_ms": processing_duration_ms, "counter": counter, "probabilities": probabilities}, f)
