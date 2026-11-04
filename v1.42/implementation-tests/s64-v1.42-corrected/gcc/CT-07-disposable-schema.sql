CREATE DATABASE IF NOT EXISTS s64_ct07_disposable;
USE s64_ct07_disposable;
CREATE TABLE IF NOT EXISTS physical_engine (
 engine_id INT UNSIGNED NOT NULL,
 class_id TINYINT UNSIGNED NOT NULL,
 status ENUM('ACTIVE','QUARANTINED') NOT NULL DEFAULT 'ACTIVE',
 PRIMARY KEY(engine_id),
 UNIQUE KEY uq_engine_class(engine_id,class_id),
 CHECK(engine_id <= 2097151),
 CHECK(class_id BETWEEN 1 AND 8)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS allocation (
 engine_id INT UNSIGNED NOT NULL,
 local_id INT UNSIGNED NOT NULL,
 s64_id BIGINT UNSIGNED NOT NULL,
 PRIMARY KEY(engine_id,local_id),
 UNIQUE KEY uq_s64_id(s64_id),
 FOREIGN KEY(engine_id) REFERENCES physical_engine(engine_id),
 CHECK(local_id <= 536870911)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS engine_counter (
 engine_id INT UNSIGNED NOT NULL,
 next_local_id INT UNSIGNED NOT NULL DEFAULT 1,
 PRIMARY KEY(engine_id),
 FOREIGN KEY(engine_id) REFERENCES physical_engine(engine_id),
 CHECK(next_local_id BETWEEN 1 AND 536870912)
) ENGINE=InnoDB;
