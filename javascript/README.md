### PREREQUISITE
To run this project, please install Node.js (v10.5.0 and above should work)

* For runing single threaded, do `npm run single`
* For running multi threaded with best case scenario chunking, do `npm run multiB`
* For running multi threaded with smaller chunking, do `npm run multiS`

### Optional settings (Things to change in code to play around with)
* `DICE_FACE` : Number of dice face. Affects the distribution of the graph.
* `NUM_DICE` : Number of dice. Affects the distribution of the graph.
* `ITERATIONS` : Number of iteration. Higher = smoother graph, slower; Lower = less smooth, faster.