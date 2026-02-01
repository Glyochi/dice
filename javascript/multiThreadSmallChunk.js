const { Worker, isMainThread, parentPort } = require('worker_threads');
const os = require('os');
const TOTAL_NUM_WORKERS = os.cpus().length;

const DICE_FACE = 20;
const NUM_DICE = 11;
const ITERATIONS = 10 ** 8;

const CHUNK_SIZE = Math.round(ITERATIONS / TOTAL_NUM_WORKERS) < 10 ** 5 ? Math.round(ITERATIONS / TOTAL_NUM_WORKERS) : 10 ** 5;
const MIN_VALUE = NUM_DICE;
const MAX_VALUE = NUM_DICE * DICE_FACE;

const MAX_PROB_LENGTH = 120;
const WORKER_PROGRESS_UPDATE_FREQUENCY = .5; //seconds
const ACTUAL_PROGRESS_UPDATE_FREQUENCY = 1; //seconds

function getDiffSeconds(latest, previous) {
  return ((latest.getTime() - previous.getTime()) / 1000).toFixed(2);
}

function getHourMinSecBySec(seconds) {
  const correctedSeconds = seconds < 0 ? 0 : seconds;

  return {
    h: Math.floor(correctedSeconds / 3600),
    m: Math.floor(correctedSeconds / 60),
    s: Math.floor(correctedSeconds) % 60,
    deci: (correctedSeconds % 1).toFixed(2).toLocaleString().padEnd(4, '0').substring(1)
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

function printProgress(startTime, progress, isCompleted = false) {
  const currentTime = new Date();
  const diffInSec = getDiffSeconds(currentTime, startTime);
  const { h, m, s, deci } = getHourMinSecBySec(diffInSec);
  const { h: eta_h, m: eta_m, s: eta_s, deci: eta_deci } = getHourMinSecBySec((diffInSec * (ITERATIONS - progress) / progress));

  console.log(
    `Progess: ${(progress * 100 / ITERATIONS).toFixed(1).padStart(5)}%  ` +
    `${progress.toLocaleString().padStart(ITERATIONS.toLocaleString().length)}/${ITERATIONS.toLocaleString()}  ` +
    `Elapsed: ${h}:${m.toLocaleString().padStart(2, '0')}:${s.toLocaleString().padStart(2, '0')}${deci}  ` +
    `ETA: ${eta_h}:${eta_m.toLocaleString().padStart(2, '0')}:${eta_s.toLocaleString().padStart(2, '0')}${eta_deci}`
  );

  if (isCompleted) {
    console.log(`\n\n\n\n`);
    console.log(`Rolling and summing ${NUM_DICE.toLocaleString()} ${DICE_FACE.toLocaleString()}-face-dice ${ITERATIONS.toLocaleString()} times over ${TOTAL_NUM_WORKERS} processes`);
    console.log(`Simulating with Javascript - Multi-thread`);
    console.log(`Total processing time is ${s} seconds or ${h} hour(s) ${m} minute(s) ${s + deci} second(s)`);
  }

  return currentTime;
}

function rollDice() {
  return Math.floor(Math.random() * DICE_FACE) + 1;
}

function rollDices() {
  let sum = 0;
  for (let i = 0; i < NUM_DICE; i++) {
    sum += rollDice();
  }

  return sum;
}

function simulate(givenIterations, parentPort) {
  const map = new Array(MAX_VALUE + 1).fill(0);
  let lastUpdated = new Date(),
    progressSinceUpdate = 0,
    currentProcessed = 0;

  // simulation
  while (currentProcessed < givenIterations) {
    const sumVal = rollDices();

    map[sumVal]++;
    progressSinceUpdate++;
    currentProcessed++;

    const currentTime = new Date();
    if (getDiffSeconds(currentTime, lastUpdated) > ACTUAL_PROGRESS_UPDATE_FREQUENCY) {
      parentPort.postMessage({ progressSinceUpdate });
      progressSinceUpdate = 0;
      lastUpdated = currentTime;
    }
  }

  parentPort.postMessage({ progressSinceUpdate, unprocessed: givenIterations - currentProcessed });
  return map;
}

const main = () => {
  console.log('Starting thread');
  const startTime = new Date();

  // initialize
  const totalCalculatedMap = new Array(MAX_VALUE + 1).fill(0);
  let remainingIterations = ITERATIONS,
    progress = 0,
    largestCount = 0,
    lastUpdated = startTime,
    currentWorkers = 0;

    
  // create workers
  while (currentWorkers <= TOTAL_NUM_WORKERS) {
      const worker = new Worker(__filename);
      currentWorkers++;

      if (remainingIterations - CHUNK_SIZE > 0) {
        worker.postMessage({ chunkSize: CHUNK_SIZE });
        remainingIterations -= CHUNK_SIZE;
      } else if (remainingIterations > 0) {
        worker.postMessage({ chunkSize: remainingIterations });
        remainingIterations = 0;
      }

      // listening for worker 
    worker.on('message', ({ map, progressSinceUpdate, unprocessed, isDone }) => {
        if (unprocessed > 0) {
          console.log(unprocessed)
          remainingIterations += unprocessed;
        }

        if (isDone) {
          //pick up new job
          if (remainingIterations - CHUNK_SIZE > 0) {
            worker.postMessage({ chunkSize: CHUNK_SIZE });
            remainingIterations -= CHUNK_SIZE;
          } else if (remainingIterations > 0) {
            worker.postMessage({ chunkSize: remainingIterations });
            remainingIterations = 0;
          }
        }

        progress += progressSinceUpdate ?? 0;

        if (getDiffSeconds(new Date(), lastUpdated) > WORKER_PROGRESS_UPDATE_FREQUENCY) {
          printProgress(startTime, progress, progress >= ITERATIONS);
          lastUpdated = new Date();
        }

        if (map) {
          for (let i = MIN_VALUE; i <= MAX_VALUE; i++) {
            totalCalculatedMap[i] += map[i];

            if (totalCalculatedMap[i] > largestCount) {
              largestCount = totalCalculatedMap[i];
            }
          }
        }

        // printing result if done
        if (progress >= ITERATIONS) {
          if (lastUpdated < new Date()) {
            printProgress(startTime, progress, true);
          }

          for (let i = MIN_VALUE; i <= MAX_VALUE; i++) {
            const currentValue = totalCalculatedMap[i];
            const previousValue = totalCalculatedMap[i - 1] ?? 0;
            const nextValue = totalCalculatedMap[i + 1] ?? 0;


            let res = `${i.toLocaleString().padStart(MAX_VALUE.toLocaleString().length)}  ` +
              `${currentValue.toLocaleString().padStart(largestCount.toLocaleString().length)}  ` +
              `${(currentValue / ITERATIONS * 100).toFixed(6)}% | ${getBar(previousValue, currentValue, nextValue, largestCount)}`;

            console.log(res);
          }

          process.exit(0);
        }
      });

      // error handling
      worker.on('error', (error) => {
        console.error('Worker error:', error);
      });

      worker.on('exit', (exitCode) => {
        console.log('Worker exited with code:', exitCode);
      });
  }
};

if (isMainThread) {
  main();
} else {
  // workers listening and returning message when it is done
  parentPort.on('message', ({ chunkSize }) => {
    const calculatedMap = simulate(chunkSize, parentPort);

    parentPort.postMessage({ map: calculatedMap, isDone: true });
  });
}
