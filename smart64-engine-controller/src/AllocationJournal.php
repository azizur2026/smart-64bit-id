<?php
declare(strict_types=1);

/**
 * Local append-only reservation journal.
 * Hash chaining detects alteration/truncation, not whole-file rollback.
 */
final class AllocationJournal
{
    private string $path;

    public function __construct(?string $path = null)
    {
        $configured = getenv('SMART64_JOURNAL_PATH');
        $this->path = $path ?? (($configured !== false && $configured !== '')
            ? $configured
            : dirname(__DIR__, 2) . '/smart64-journal/allocations.jsonl');

        $dir = dirname($this->path);
        if (!is_dir($dir) && !mkdir($dir, 0700, true) && !is_dir($dir)) {
            throw new RuntimeException('Cannot create journal directory.');
        }
        if (!is_file($this->path)) {
            $f = @fopen($this->path, 'x+b');
            if ($f !== false) {
                chmod($this->path, 0600);
                fclose($f);
            }
        }
        if (!is_file($this->path) || !is_readable($this->path) || !is_writable($this->path)) {
            throw new RuntimeException('Journal unavailable; allocation refused.');
        }
    }

    private function locked(callable $callback): mixed
    {
        $f = @fopen($this->path, 'c+b');
        if ($f === false || !flock($f, LOCK_EX)) {
            if (is_resource($f)) fclose($f);
            throw new RuntimeException('Cannot lock journal; allocation refused.');
        }

        try {
            rewind($f);
            $raw = stream_get_contents($f);
            if ($raw === false) throw new RuntimeException('Cannot read journal.');
            $state = $this->scan($raw);
            return $callback($f, $state);
        } finally {
            flock($f, LOCK_UN);
            fclose($f);
        }
    }

    private function scan(string $raw): array
    {
        $state = ['next' => [], 'records' => [], 'last' => str_repeat('0', 64)];
        $seenIds = [];
        if ($raw === '') return $state;
        if (!str_ends_with($raw, "\n")) {
            throw new RuntimeException('Journal has an incomplete final record; allocation refused.');
        }

        foreach (explode("\n", rtrim($raw, "\n")) as $line) {
            try {
                $r = json_decode($line, true, 16, JSON_THROW_ON_ERROR);
            } catch (Throwable $e) {
                throw new RuntimeException('Journal record is corrupt; allocation refused.');
            }
            if (!is_array($r)) throw new RuntimeException('Invalid journal record.');

            $p = [
                'engine' => $r['engine'] ?? null,
                'local' => $r['local'] ?? null,
                'class' => $r['class'] ?? null,
                'role' => $r['role'] ?? null,
                'id_hex' => $r['id_hex'] ?? null,
                'prev' => $r['prev'] ?? null,
            ];
            if (!is_int($p['engine']) || $p['engine'] < 0 || $p['engine'] > 2097151 ||
                !is_int($p['local']) || $p['local'] < 0 || $p['local'] > 536870911 ||
                !is_int($p['class']) || $p['class'] < 1 || $p['class'] > 8 ||
                !is_int($p['role']) || !in_array($p['role'], [0, 1], true) ||
                !is_string($p['id_hex']) || !preg_match('/\A[0-9A-F]{16}\z/', $p['id_hex']) ||
                !is_string($p['prev']) || !hash_equals($state['last'], $p['prev'])) {
                throw new RuntimeException('Journal chain or fields invalid; allocation refused.');
            }

            $key = $p['engine'] . ':' . $p['local'];
            if ($p['local'] !== ($state['next'][$p['engine']] ?? 0) ||
                isset($state['records'][$key]) ||
                isset($seenIds[$p['id_hex']])) {
                throw new RuntimeException('Journal sequence or uniqueness failure; allocation refused.');
            }
            try {
                $decoded = SmartId::decode(hex2bin($p['id_hex']));
            } catch (Throwable $e) {
                throw new RuntimeException('Journal contains an invalid SMART ID; allocation refused.');
            }
            if ($decoded['engine'] !== $p['engine'] ||
                $decoded['local'] !== $p['local'] ||
                $decoded['class'] !== $p['class'] ||
                $decoded['role'] !== $p['role']) {
                throw new RuntimeException('Journal fields do not match ID bytes; allocation refused.');
            }
            $expected = hash('sha256', json_encode($p, JSON_THROW_ON_ERROR));
            if (!isset($r['hash']) || !is_string($r['hash']) ||
                !hash_equals($expected, $r['hash'])) {
                throw new RuntimeException('Journal hash mismatch; allocation refused.');
            }

            $state['records'][$key] = $p['id_hex'];
            $seenIds[$p['id_hex']] = true;
            $state['next'][$p['engine']] = max(
                $state['next'][$p['engine']] ?? 0,
                $p['local'] + 1
            );
            $state['last'] = $r['hash'];
        }
        return $state;
    }

    /** Return validated high-water marks and recorded IDs. */
    public function state(): array
    {
        return $this->locked(static fn($f, $state) => $state);
    }

    /** Durably reserve an exact ID before SQLite commits it. */
    public function reserve(int $engine, int $local, int $class, int $role, string $idHex): void
    {
        $this->locked(function ($f, $state) use ($engine, $local, $class, $role, $idHex): void {
            if (($state['next'][$engine] ?? 0) !== $local) {
                throw new RuntimeException('Journal counter mismatch; allocation refused.');
            }
            if (!preg_match('/\A[0-9A-F]{16}\z/', $idHex)) {
                throw new RuntimeException('Invalid ID bytes for journal.');
            }

            $blob = hex2bin($idHex);
            if ($blob === false) {
                throw new RuntimeException('Invalid ID encoding for journal.');
            }

            $decoded = SmartId::decode($blob);
            if ($decoded['engine'] !== $engine ||
                $decoded['local'] !== $local ||
                $decoded['class'] !== $class ||
                $decoded['role'] !== $role) {
                throw new RuntimeException('Journal reservation fields do not match ID bytes.');
            }

            $p = [
                'engine' => $engine, 'local' => $local,
                'class' => $class, 'role' => $role,
                'id_hex' => $idHex, 'prev' => $state['last'],
            ];
            $record = $p + ['hash' => hash('sha256', json_encode($p, JSON_THROW_ON_ERROR))];

            fseek($f, 0, SEEK_END);
            $line = json_encode($record, JSON_THROW_ON_ERROR) . "\n";
            if (fwrite($f, $line) !== strlen($line) || !fflush($f) || !fsync($f)) {
                throw new RuntimeException('Journal durability uncertain; allocation refused.');
            }
        });
    }
}
