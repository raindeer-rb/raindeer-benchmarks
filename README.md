# Raindeer Benchmarks

Benchmarking CPU-bound routes and IO-bound simulated delays. Load-tested locally with Apache Bench (`ab`) on the same machine, sequentially (not concurrently, to avoid CPU contention skewing results).

## Apps

- Roda

## Routes
- `/` - Short plain-text body to benchmark CPU
- `/slow` - `sleep(0.05)` then a short body to simulate I/O
- `/route<number>` - Simulate multiple routes to benchmark CPU

## Method

```
ab -n 2000  -c 25 -k <url>   # warm-up, discarded
ab -n 20000 -c 50 -k <url>   # measured run
```

`-k` enables HTTP keep-alive.

## Results

Raw `ab` output for both passes is in this folder as `*_result.log` / `*_result2.log`
(not committed to git — regenerate via the commands above if needed).

### Falcon for async apples-to-applies comparison

[Falcon](https://github.com/socketry/falcon) is a Rack-compatible
server built on the same `async`/fiber-reactor foundation as Raindeer's
`LowLoop` (it shares the `async`, `async-http`, `async-container` gems) —
running Roda on it should get Roda the same "no thread pool to size" property
Raindeer has, without changing a line of Roda application code. Added `falcon`
to `roda_app`'s Gemfile and ran it two ways: `falcon serve -b http://... -n 1`
(single instance — the fair one-reactor-vs-one-reactor comparison) and
`falcon serve -b http://...` (Falcon's actual out-of-the-box default: forked,
10 instances).

### Giving Raindeer the same multi-core parallelism

Fair follow-up: Falcon got credit for 10-process parallelism above, so does
`LowLoop` have anything comparable? Checked — no. `rain server`/`bin/server` is
just `Providers['low.loop'].start`; there's no forking, no `SO_REUSEPORT`, no
process-count option anywhere in `low_loop`, `raindeer`, or `lowload`. To test
Raindeer under the same kind of multi-core parallelism Falcon gets by default,
I launched 10 independent `bin/server` processes (this machine has 10 cores —
same count Falcon's default picked), each on its own port via `RAIN_PORT`, and
split the total load across them: 10 concurrent `ab` processes running at once,
each hitting one port, with the *total* concurrency/request-count across all
10 matching the single-endpoint tests above (e.g. c=200 total → c=20 × 10
processes). Summed the resulting req/s across all 10 — mathematically
equivalent to what a real load balancer distributing across 10 independent,
non-communicating processes would achieve, since there's no shared state or
coordination between them either way.
