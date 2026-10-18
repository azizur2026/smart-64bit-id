<?php
declare(strict_types=1);

$configPath = __DIR__ . '/../config.php';
$worker = __DIR__ . '/idempotency-concurrency-worker.php';
$barrier = __DIR__ . '/.idempotency-concurrency-start';

$caller = 'idempotency-concurrency-lab';
$requestKey = hash('sha256', 'smart64-idempotency-concurrent-test-001');
$engine = 2000018;

if (!is_file($configPath) || !is_file($worker)) {
    fwrite(STDERR, "Missing config.php or worker script.\n");
    exit(2);
}

$config = require $configPath;

if (
    !isset($config['dsn'], $config['user'], $config['password']) ||
    !is_string($config['dsn']) ||
    !preg_match('/(?:^|;)dbname=([^;]+)/', $config['dsn'], $m) ||
    $m[1] !== 'smart64_test'
) {
    fwrite(STDERR, "Refusing to run outside smart64_test.\n");
    exit(2);
}

if (is_file($barrier)) {
    fwrite(STDERR, "Refusing to run: stale start-barrier file exists.\n");
    exit(2);
}

$pdo = new PDO(
    $config['dsn'],
    $config['user'],
    $config['password'],
    $config['options'] ?? []
);
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

// Refuse to reuse a request key from an earlier run.
$stmt = $pdo->prepare(
    'SELECT COUNT(*) FROM smart64_fencing_lab_requests
     WHERE caller_id = ? AND request_key = ?'
);
$stmt->execute([$caller, $requestKey]);

if ((int)$stmt->fetchColumn() !== 0) {
    fwrite(STDERR, "Refusing to run: test request key already exists.\n");
    exit(2);
}

// Confirm the lab Engine has the expected authority.
$stmt = $pdo->prepare(
    'SELECT fencing_token, owner_label, next_local
     FROM smart64_fencing_lab
     WHERE engine_id = ?'
);
$stmt->execute([$engine]);
$owner = $stmt->fetch(PDO::FETCH_ASSOC);

if (
    !$owner ||
    (int)$owner['fencing_token'] !== 2 ||
    $owner['owner_label'] !== 'worker_B'
) {
    fwrite(STDERR, "Refusing to run: unexpected lab owner/token.\n");
    exit(2);
}

$startingLocal = (int)$owner['next_local'];
echo "Starting next_local: $startingLocal\n";

$processes = [];
$barrierCreated = false;
$passed = 0;
$failed = 0;

try {
    // Start both processes; each waits for the barrier file.
    for ($i = 0; $i < 2; $i++) {
        $descriptors = [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ];

        $proc = proc_open(
            [PHP_BINARY, $worker],
            $descriptors,
            $pipes
        );

        if (!is_resource($proc)) {
            throw new RuntimeException(
                'Could not start worker ' . ($i + 1) . '.'
            );
        }

        fclose($pipes[0]);

        stream_set_blocking($pipes[1], false);
        stream_set_blocking($pipes[2], false);

        $processes[] = [
            'proc' => $proc,
            'stdout' => $pipes[1],
            'stderr' => $pipes[2],
            'out' => '',
            'err' => '',
            'exit' => null,
        ];
    }

    // Give both workers time to enter their wait loops.
    usleep(250000);

    if (file_put_contents($barrier, "go\n", LOCK_EX) === false) {
        throw new RuntimeException('Could not create start signal.');
    }
    $barrierCreated = true;

    // Drain output while workers run, avoiding pipe-buffer deadlocks.
    $deadline = microtime(true) + 30.0;
    $running = [0 => true, 1 => true];

    while ($running[0] || $running[1]) {
        foreach ([0, 1] as $i) {
            if (!$running[$i]) {
                continue;
            }

            $out = stream_get_contents($processes[$i]['stdout']);
            $err = stream_get_contents($processes[$i]['stderr']);

            if ($out !== false) {
                $processes[$i]['out'] .= $out;
            }
            if ($err !== false) {
                $processes[$i]['err'] .= $err;
            }

            $status = proc_get_status($processes[$i]['proc']);
            if (!$status['running']) {
                $running[$i] = false;
                $processes[$i]['exit'] = $status['exitcode'];
            }
        }

        if (microtime(true) >= $deadline) {
            throw new RuntimeException('Timed out waiting for workers.');
        }

        if ($running[0] || $running[1]) {
            usleep(10000);
        }
    }

    // Capture any remaining output, then close the streams and processes.
    foreach ([0, 1] as $i) {
        $out = stream_get_contents($processes[$i]['stdout']);
        $err = stream_get_contents($processes[$i]['stderr']);

        if ($out !== false) {
            $processes[$i]['out'] .= $out;
        }
        if ($err !== false) {
            $processes[$i]['err'] .= $err;
        }

        fclose($processes[$i]['stdout']);
        fclose($processes[$i]['stderr']);

        $closeCode = proc_close($processes[$i]['proc']);
        if ($processes[$i]['exit'] === -1 || $processes[$i]['exit'] === null) {
            $processes[$i]['exit'] = $closeCode;
        }

        echo 'Worker ' . ($i + 1) . ' stdout: '
            . trim($processes[$i]['out']) . "\n";

        if (trim($processes[$i]['err']) !== '') {
            echo 'Worker ' . ($i + 1) . ' stderr: '
                . trim($processes[$i]['err']) . "\n";
        }
    }

    $results = [];
    foreach ($processes as $p) {
        $decoded = json_decode(trim($p['out']), true);
        $results[] = is_array($decoded) ? $decoded : null;
    }

    $workersOk = count($results) === 2;
    foreach ([0, 1] as $i) {
        $workersOk = $workersOk
            && $processes[$i]['exit'] === 0
            && is_array($results[$i])
            && ($results[$i]['ok'] ?? false) === true;
    }

    if (!$workersOk) {
        throw new RuntimeException(
            'One or more workers failed; inspect output before retrying.'
        );
    }

    $sameId = $results[0]['id_hex'] === $results[1]['id_hex'];
    $sameLocal = $results[0]['local'] === $results[1]['local'];
    $oneFresh = (int)!$results[0]['replayed']
        + (int)!$results[1]['replayed'] === 1;
    $oneReplay = (int)$results[0]['replayed']
        + (int)$results[1]['replayed'] === 1;

    $stmt = $pdo->prepare(
        'SELECT COUNT(*), MIN(local_id), MAX(local_id),
                MIN(id_hex), MAX(id_hex)
         FROM smart64_fencing_lab_requests
         WHERE caller_id = ? AND request_key = ?'
    );
    $stmt->execute([$caller, $requestKey]);
    $request = $stmt->fetch(PDO::FETCH_NUM);

    $stmt = $pdo->prepare(
        'SELECT COUNT(*), MIN(local_id), MAX(local_id),
                MIN(fencing_token), MAX(fencing_token)
         FROM smart64_fencing_lab_allocations
         WHERE engine_id = ? AND local_id = ?'
    );
    $stmt->execute([$engine, $results[0]['local']]);
    $allocation = $stmt->fetch(PDO::FETCH_NUM);

    $stmt = $pdo->prepare(
        'SELECT next_local FROM smart64_fencing_lab WHERE engine_id = ?'
    );
    $stmt->execute([$engine]);
    $endingLocal = (int)$stmt->fetchColumn();

    $checks = [
        'Both workers returned successfully' => $workersOk,
        'Both workers returned the same SMART ID and Local' =>
            $sameId && $sameLocal,
        'One request allocated and the other replayed' =>
            $oneFresh && $oneReplay,
        'Exactly one matching request row exists' =>
            (int)$request[0] === 1
            && (int)$request[1] === $results[0]['local']
            && (int)$request[2] === $results[0]['local']
            && $request[3] === $results[0]['id_hex']
            && $request[4] === $results[0]['id_hex'],
        'Exactly one matching allocation exists with token 2' =>
            (int)$allocation[0] === 1
            && (int)$allocation[1] === $results[0]['local']
            && (int)$allocation[2] === $results[0]['local']
            && (int)$allocation[3] === 2
            && (int)$allocation[4] === 2,
        'Counter advanced exactly once' =>
            $endingLocal === $startingLocal + 1,
    ];

    foreach ($checks as $label => $ok) {
        echo ($ok ? 'PASS: ' : 'FAIL: ') . $label . "\n";
        $ok ? $passed++ : $failed++;
    }

    echo "Starting Local: $startingLocal\n";
    echo "Ending Local: $endingLocal\n";
    echo "Returned SMART ID: " . $results[0]['id_hex'] . "\n";
    echo "RESULT: $passed passed, $failed failed\n";
} catch (Throwable $e) {
    fwrite(STDERR, "ERROR: " . $e->getMessage() . "\n");
    $failed++;
} finally {
    // Remove the barrier regardless of success or failure.
    if ($barrierCreated && is_file($barrier) && !unlink($barrier)) {
        fwrite(STDERR, "WARNING: could not remove barrier file.\n");
        $failed++;
    }

    // Terminate any processes still running after an error.
    foreach ($processes as $p) {
        if (is_resource($p['proc'])) {
            $status = proc_get_status($p['proc']);
            if ($status['running']) {
                proc_terminate($p['proc']);
            }
        }
    }

    foreach ($processes as $p) {
        foreach (['stdout', 'stderr'] as $stream) {
            if (isset($p[$stream]) && is_resource($p[$stream])) {
                fclose($p[$stream]);
            }
        }
        if (isset($p['proc']) && is_resource($p['proc'])) {
            proc_close($p['proc']);
        }
    }
}

exit($failed === 0 ? 0 : 1);
