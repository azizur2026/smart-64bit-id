USE s64_test;

CREATE TABLE IF NOT EXISTS physical_engine (
    engine_id INT UNSIGNED NOT NULL,
    class_id TINYINT UNSIGNED NOT NULL,
    status ENUM('ACTIVE','QUARANTINED') NOT NULL DEFAULT 'ACTIVE',
    PRIMARY KEY (engine_id),
    UNIQUE KEY uq_engine_class (engine_id, class_id),
    CHECK (engine_id <= 2097151),
    CHECK (class_id BETWEEN 1 AND 8)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS virtual_engine (
    virtual_engine_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_id TINYINT UNSIGNED NOT NULL,
    status ENUM('ACTIVE','INACTIVE') NOT NULL DEFAULT 'ACTIVE',
    PRIMARY KEY (virtual_engine_id),
    UNIQUE KEY uq_virtual_class (virtual_engine_id, class_id),
    CHECK (class_id BETWEEN 1 AND 8)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS allocation (
    engine_id INT UNSIGNED NOT NULL,
    local_id INT UNSIGNED NOT NULL,
    s64_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (engine_id, local_id),
    UNIQUE KEY uq_s64_id (s64_id),
    FOREIGN KEY (engine_id) REFERENCES physical_engine(engine_id),
    CHECK (local_id <= 536870911)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS attachment_request (
    request_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    engine_id INT UNSIGNED NOT NULL,
    virtual_engine_id BIGINT UNSIGNED NOT NULL,
    requested_by VARCHAR(64) NOT NULL,
    request_status ENUM('PENDING','ATTACHED','REJECTED') NOT NULL DEFAULT 'PENDING',
    PRIMARY KEY (request_id),
    FOREIGN KEY (engine_id) REFERENCES physical_engine(engine_id),
    FOREIGN KEY (virtual_engine_id) REFERENCES virtual_engine(virtual_engine_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS engine_attachment (
    engine_id INT UNSIGNED NOT NULL,
    virtual_engine_id BIGINT UNSIGNED NOT NULL,
    class_id TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (engine_id),
    FOREIGN KEY (engine_id, class_id)
        REFERENCES physical_engine(engine_id, class_id),
    FOREIGN KEY (virtual_engine_id, class_id)
        REFERENCES virtual_engine(virtual_engine_id, class_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS engine_counter (
    engine_id INT UNSIGNED NOT NULL,
    next_local_id INT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (engine_id),
    FOREIGN KEY (engine_id)
        REFERENCES physical_engine(engine_id),
    CHECK (next_local_id BETWEEN 1 AND 536870912)
) ENGINE=InnoDB;
