<?php
declare(strict_types=1);
require_once __DIR__ . '/SmartId.php';
require_once __DIR__ . '/AllocationJournal.php';

/** Local SQLite allocator guarded by a separate durable reservation journal. */
final class Allocator
{
    private PDO $db;
    private AllocationJournal $journal;
    private bool $needsRecovery = false;

    public function __construct(string $path, ?string $journalPath = null, bool $initialize = true)
    {
        $dir = dirname($path);
        if (!is_dir($dir) && !mkdir($dir, 0770, true) && !is_dir($dir)) {
            throw new RuntimeException('Cannot create database directory.');
        }
        $this->db = new PDO('sqlite:' . $path, null, null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]);
        $this->db->exec('PRAGMA foreign_keys = ON');
        $this->db->exec('PRAGMA busy_timeout = 60000');
        if ($initialize) {
            $this->db->exec('PRAGMA journal_mode = WAL');
            $this->db->exec('PRAGMA synchronous = FULL');
            $this->db->exec('CREATE TABLE IF NOT EXISTS engines (engine_no INTEGER PRIMARY KEY CHECK(engine_no BETWEEN 0 AND 2097151), next_local INTEGER NOT NULL DEFAULT 0 CHECK(next_local BETWEEN 0 AND 536870912), created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
            $this->db->exec('CREATE TABLE IF NOT EXISTS allocations (engine_no INTEGER NOT NULL, local_id INTEGER NOT NULL CHECK(local_id BETWEEN 0 AND 536870911), class_id INTEGER NOT NULL CHECK(class_id BETWEEN 1 AND 8), role_id INTEGER NOT NULL CHECK(role_id IN (0,1)), id_blob BLOB NOT NULL UNIQUE CHECK(length(id_blob)=8), created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(engine_no, local_id), FOREIGN KEY(engine_no) REFERENCES engines(engine_no)) WITHOUT ROWID');
        }

        $this->journal = new AllocationJournal($journalPath ?? ($path . '.journal'));
        if ($initialize) {
            $this->reconcileJournal();
        }
    }

    /** Reconcile SQLite from the durable journal, or fail closed on contradictions. */
    private function reconcileJournal(): void
    {
        $this->db->exec('BEGIN IMMEDIATE');
        try {
            // Keep lock order consistent with allocate(): database, then journal.
            $state = $this->journal->state();
            $dbEngines = [];
            foreach ($this->db->query('SELECT engine_no, next_local FROM engines')->fetchAll() as $row) {
                $e = (int)$row['engine_no'];
                $dbEngines[$e] = (int)$row['next_local'];
                if ($dbEngines[$e] > ($state['next'][$e] ?? 0)) {
                    throw new RuntimeException("Database counter is ahead of journal for Engine {$e}; allocation blocked.");
                }
            }

            $rows = $this->db->query('SELECT engine_no, local_id, class_id, role_id, id_blob FROM allocations')->fetchAll();
            $dbRecords = [];
            foreach ($rows as $row) {
                $key = (int)$row['engine_no'] . ':' . (int)$row['local_id'];
                $hex = strtoupper(bin2hex($row['id_blob']));
                try {
                    $fields = SmartId::decode($row['id_blob']);
                } catch (Throwable $e) {
                    throw new RuntimeException("Database contains invalid SMART ID bytes ({$key}); allocation blocked.");
                }
                if ($fields['engine'] !== (int)$row['engine_no'] ||
                    $fields['local'] !== (int)$row['local_id'] ||
                    $fields['class'] !== (int)$row['class_id'] ||
                    $fields['role'] !== (int)$row['role_id'] ||
                    ($state['records'][$key] ?? null) !== $hex) {
                    throw new RuntimeException("Database allocation missing from or conflicting with journal ({$key}); allocation blocked.");
                }
                $dbRecords[$key] = true;
            }

            foreach ($state['records'] as $key => $hex) {
                [$engine, $local] = array_map('intval', explode(':', $key, 2));
                $blob = hex2bin($hex);
                if ($blob === false) throw new RuntimeException('Invalid journal ID bytes; allocation blocked.');
                $fields = SmartId::decode($blob);
                if ($fields['engine'] !== $engine || $fields['local'] !== $local) {
                    throw new RuntimeException('Journal key and ID bytes disagree; allocation blocked.');
                }

                if (!isset($dbEngines[$engine])) {
                    $q = $this->db->prepare('INSERT INTO engines(engine_no, next_local) VALUES(:e, 0)');
                    $q->execute([':e' => $engine]);
                    $dbEngines[$engine] = 0;
                }
                if (!isset($dbRecords[$key])) {
                    $q = $this->db->prepare('INSERT INTO allocations(engine_no, local_id, class_id, role_id, id_blob) VALUES(:e,:l,:c,:r,:b)');
                    $q->bindValue(':e', $engine, PDO::PARAM_INT);
                    $q->bindValue(':l', $local, PDO::PARAM_INT);
                    $q->bindValue(':c', $fields['class'], PDO::PARAM_INT);
                    $q->bindValue(':r', $fields['role'], PDO::PARAM_INT);
                    $q->bindValue(':b', $blob, PDO::PARAM_LOB);
                    $q->execute();
                }
            }

            foreach ($state['next'] as $engine => $next) {
                $q = $this->db->prepare('UPDATE engines SET next_local = :n WHERE engine_no = :e');
                $q->execute([':n' => $next, ':e' => $engine]);
            }
            $this->db->exec('COMMIT');
        } catch (Throwable $e) {
            try { $this->db->exec('ROLLBACK'); } catch (Throwable $ignored) {}
            throw $e;
        }
    }

    public function registerEngine(int $engine): void
    {
        if ($engine < 0 || $engine > SmartId::MAX_ENGINE) throw new InvalidArgumentException('Engine must be 0..2097151.');
        $stmt = $this->db->prepare('INSERT OR IGNORE INTO engines(engine_no, next_local) VALUES(:e, 0)');
        $stmt->execute([':e' => $engine]);
    }

    public function listEngines(): array
    {
        return $this->db->query('SELECT engine_no, next_local, created_at FROM engines ORDER BY engine_no')->fetchAll();
    }

    /** Reserve durably before returning an ID. A failed post-reservation write is reconciled before retry. */
    public function allocate(int $engine, int $class, int $role): array
    {
        if ($this->needsRecovery) {
            $this->reconcileJournal();
            $this->needsRecovery = false;
        }
        SmartId::className($class);
        if ($role !== 0 && $role !== 1) throw new InvalidArgumentException('Role must be 0 or 1.');

        $reserved = false;
        $this->db->exec('BEGIN IMMEDIATE');
        try {
            $q = $this->db->prepare('SELECT next_local FROM engines WHERE engine_no = :e');
            $q->execute([':e' => $engine]);
            $row = $q->fetch();
            if (!$row) throw new RuntimeException('Engine is not registered. Register it before allocating.');
            $local = (int)$row['next_local'];
            if ($local > SmartId::MAX_LOCAL) throw new RuntimeException('Local namespace exhausted; allocation refused.');

            $blob = SmartId::encode($class, $engine, $local, $role);
            $this->journal->reserve($engine, $local, $class, $role, strtoupper(bin2hex($blob)));
            $reserved = true;

            $ins = $this->db->prepare('INSERT INTO allocations(engine_no, local_id, class_id, role_id, id_blob) VALUES(:e,:l,:c,:r,:b)');
            $ins->bindValue(':e', $engine, PDO::PARAM_INT);
            $ins->bindValue(':l', $local, PDO::PARAM_INT);
            $ins->bindValue(':c', $class, PDO::PARAM_INT);
            $ins->bindValue(':r', $role, PDO::PARAM_INT);
            $ins->bindValue(':b', $blob, PDO::PARAM_LOB);
            $ins->execute();

            $up = $this->db->prepare('UPDATE engines SET next_local = :n WHERE engine_no = :e');
            $up->execute([':n' => $local + 1, ':e' => $engine]);
            $this->db->exec('COMMIT');

            $fields = SmartId::decode($blob);
            return $fields + ['id_hex' => strtoupper(bin2hex($blob)), 'id_decimal' => SmartId::toDecimal($blob)];
        } catch (Throwable $e) {
            try { $this->db->exec('ROLLBACK'); } catch (Throwable $ignored) {}
            if ($reserved) $this->needsRecovery = true;
            throw $e;
        }
    }

    public function benchmark(int $engines, int $count, int $class, int $role): array
    {
        if ($engines < 1 || $engines > 100) throw new InvalidArgumentException('Choose 1..100 engines.');
        if ($count < 1 || $count > 1000) throw new InvalidArgumentException('Choose 1..1000 IDs per engine (web demo safety limit).');
        $start = hrtime(true);
        $made = 0;
        for ($i = 0; $i < $engines; $i++) {
            $this->registerEngine($i);
            for ($j = 0; $j < $count; $j++) { $this->allocate($i, $class, $role); $made++; }
        }
        $elapsed = (hrtime(true) - $start) / 1e9;
        return ['engines' => $engines, 'ids_per_engine' => $count, 'generated' => $made, 'elapsed_seconds' => $elapsed, 'ids_per_second' => $elapsed > 0 ? $made / $elapsed : 0.0, 'mode' => 'journal reservation + SQLite persistence; includes engine registration and per-ID transactions'];
    }

    public function recent(int $limit = 50): array
    {
        $limit = max(1, min(200, $limit));
        $stmt = $this->db->query('SELECT engine_no, local_id, class_id, role_id, id_blob, created_at FROM allocations ORDER BY created_at DESC, engine_no DESC, local_id DESC LIMIT ' . $limit);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$r) { $r['id_hex'] = strtoupper(bin2hex($r['id_blob'])); $r['id_decimal'] = SmartId::toDecimal($r['id_blob']); $r['class_name'] = SmartId::className((int)$r['class_id']); unset($r['id_blob']); }
        return $rows;
    }
}
