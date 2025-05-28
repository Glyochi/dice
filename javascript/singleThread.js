const DICE_FACE = 20;
const NUM_DICE = 11;
const ITERATIONS = 10 ** 7;

const MIN_VALUE = NUM_DICE;
const MAX_VALUE = NUM_DICE * DICE_FACE;

const CALCULATED_MAP = new Array(MAX_VALUE + 1).fill(0);

const MAX_PROB_LENGTH = 120;
const PROGRESS_UPDATE_FREQUENCY = 5; //seconds

function getDiffSeconds(latest, previous) {
  return ((latest.getTime() - previous.getTime()) / 1000).toFixed(2);
}

function getHourMinSecBySec(seconds) {
  return {
    h: Math.floor(seconds / 3600),
    m: Math.floor(seconds / 60),
    s: Math.floor(seconds) % 60,
    deci: (seconds % 1).toFixed(2).toLocaleString().padEnd(4, '0').substring(1)
  };
}

function getBar(previousValue, currentValue, nextValue, largestCount) {
  const [prevCount, count, nextCount] = [
    Math.round(previousValue * MAX_PROB_LENGTH / largestCount),
    Math.round(currentValue * MAX_PROB_LENGTH / largestCount),
    Math.round(nextValue * MAX_PROB_LENGTH / largestCount),
  ];

  const big_up_symbol = "⠍",
    big_down_symbol = "⠥",
    big_both_symbol = "⠅",
    up_symbol = "⠁",
    down_symbol = ".",
    both_symbol = "⠅";

  let string = "⠿".repeat(count);
  if (prevCount > count && nextCount > count) {
    string += big_both_symbol;
  } else if (prevCount > count) {
    string += big_up_symbol;
  } else if (nextCount > count) {
    string += big_down_symbol;
  } else if (count === 0) {
    if (previousValue < currentValue && nextValue < currentValue) {
      string += both_symbol;
    } else if (previousValue < currentValue) {
      string += up_symbol;
    } else if (nextValue < currentValue) {
      string += down_symbol;
    }
  }

  return string;
}

function rollDice() {
  return Math.floor(Math.random() * DICE_FACE) + 1;
}

function rollDices() {
  let sum = 0;
  for(let i = 0; i < NUM_DICE; i++) {
    sum += rollDice();
  }

  return sum;
}

const main = () => {
  const startTime = new Date();
  let progress = 0,
    largestCount = 0,
    lastUpdated = startTime;;

  for(let i = 0; i < ITERATIONS; i++) {
    const sumVal = rollDices();

    CALCULATED_MAP[sumVal]++;
    progress++;

    if (CALCULATED_MAP[sumVal] > largestCount) {
      largestCount = CALCULATED_MAP[sumVal];
    }

    const currentTime = new Date();
    if (getDiffSeconds(currentTime, lastUpdated) > PROGRESS_UPDATE_FREQUENCY || 
        (progress * 100 / ITERATIONS) % 100 === 0) {
      const { h, m, s, deci } = getHourMinSecBySec(getDiffSeconds(currentTime, startTime));

      console.log(`Progess: ${(progress * 100 / ITERATIONS).toFixed(1).padStart(5)}%  ` +
        `${progress.toLocaleString().padStart(ITERATIONS.toLocaleString().length)}/${ITERATIONS}  ` +
        `Elapsed: ${h}:${m.toLocaleString().padStart(2, '0')}:${s.toLocaleString().padStart(2, '0')}${deci}`);

      lastUpdated = currentTime;
    }
  }

  for (let i = MIN_VALUE; i <= MAX_VALUE; i++) {
    const currentValue = CALCULATED_MAP[i];
    const previousValue = CALCULATED_MAP[i - 1] ?? 0;
    const nextValue = CALCULATED_MAP[i + 1] ?? 0;

    let res = `${i.toLocaleString().padStart(MAX_VALUE.toLocaleString().length)}  ` +
      `${currentValue.toLocaleString().padStart(largestCount.toLocaleString().length)}  ` +
      `${(currentValue / ITERATIONS * 100).toFixed(6)}% | ${getBar(previousValue, currentValue, nextValue, largestCount)}`;

    console.log(res);
  }

  const { h, m, s, deci } = getHourMinSecBySec(getDiffSeconds(new Date(), startTime));
  console.log(`Rolling and summing ${NUM_DICE.toLocaleString()} ${DICE_FACE.toLocaleString()}-face-dice ${ITERATIONS.toLocaleString()} times`);
  console.log(`Simulating with Javascript - Single-thread`);
  console.log(`Total processing time is ${s} seconds or ${h} hour(s) ${m} minute(s) ${s + deci} second(s)`);
}

main();