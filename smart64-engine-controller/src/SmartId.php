<?php
declare(strict_types=1);

/** SMART 64-Bit ID v1.41 bit layout and unsigned-safe binary helpers. */
final class SmartId
{
    public const MAX_ENGINE = 2097151;       // 2^21 - 1
    public const MAX_LOCAL = 536870911;       // 2^29 - 1
    public const VERSION = 0;
    public const REVISION = 1;                // v1.41 profile

    public static function className(int $class): string
    {
        return match ($class) {
            1 => 'Human', 2 => 'Other Living Being', 3 => 'IoT / Device',
            4 => 'AI', 5 => 'Organization', 6 => 'Artifact / Object',
            7 => 'Android / Humanoid Artificial Entity', 8 => 'Natural / Celestial Object',
            default => throw new InvalidArgumentException('Class must be 1..8 for this v1.41 controller.'),
        };
    }

    /** Build the canonical 8-byte unsigned big-endian representation without PHP unsigned-int assumptions. */
    public static function encode(int $class, int $engine, int $local, int $role): string
    {
        self::className($class); // rejects 0 and reserved future classes in this initial implementation
        if ($engine < 0 || $engine > self::MAX_ENGINE) throw new InvalidArgumentException('Engine must be 0..2097151.');
        if ($local < 0 || $local > self::MAX_LOCAL) throw new InvalidArgumentException('Local must be 0..536870911.');
        if ($role !== 0 && $role !== 1) throw new InvalidArgumentException('Role must be 0 or 1.');

        $bytes = array_fill(0, 8, 0);
        self::putBits($bytes, 0, 29, $local);
        self::putBits($bytes, 29, 21, $engine);
        self::putBits($bytes, 50, 4, $class);
        // Reserved bits 54..57 remain zero.
        self::putBits($bytes, 58, 1, $role);
        self::putBits($bytes, 59, 4, self::REVISION);
        self::putBits($bytes, 63, 1, self::VERSION);
        return pack('C*', ...$bytes);
    }

    /** Extract fields from exactly 8 canonical bytes, rejecting invalid v1.41 representations. */
    public static function decode(string $blob): array
    {
        if (strlen($blob) !== 8) throw new InvalidArgumentException('A SMART binary ID must be exactly 8 bytes.');
        $bytes = array_values(unpack('C*', $blob));
        $fields = [
            'local' => self::getBits($bytes, 0, 29),
            'engine' => self::getBits($bytes, 29, 21),
            'class' => self::getBits($bytes, 50, 4),
            'reserved' => self::getBits($bytes, 54, 4),
            'role' => self::getBits($bytes, 58, 1),
            'revision' => self::getBits($bytes, 59, 4),
            'version' => self::getBits($bytes, 63, 1),
        ];
        if ($fields['version'] !== 0 || $fields['revision'] !== 1) throw new InvalidArgumentException('Unsupported SMART profile; expected Version 0, Revision 0001 (v1.41).');
        if ($fields['reserved'] !== 0) throw new InvalidArgumentException('Non-conforming v1.41 ID: Reserved bits must be zero.');
        self::className($fields['class']);
        $fields['binary_hex'] = strtoupper(bin2hex($blob));
        $fields['decimal'] = self::toDecimal($blob);
        $fields['class_name'] = self::className($fields['class']);
        return $fields;
    }

    private static function putBits(array &$bytes, int $start, int $width, int $value): void
    {
        for ($i = 0; $i < $width; $i++) {
            if (($value & (1 << $i)) !== 0) {
                $bit = $start + $i;
                $byteIndex = 7 - intdiv($bit, 8);
                $bytes[$byteIndex] |= (1 << ($bit % 8));
            }
        }
    }

    private static function getBits(array $bytes, int $start, int $width): int
    {
        $value = 0;
        for ($i = 0; $i < $width; $i++) {
            $bit = $start + $i;
            $byteIndex = 7 - intdiv($bit, 8);
            if (($bytes[$byteIndex] & (1 << ($bit % 8))) !== 0) $value |= (1 << $i);
        }
        return $value;
    }

    /** Convert 8-byte unsigned integer to decimal text using decimal-string arithmetic. */
    public static function toDecimal(string $blob): string
    {
        if (strlen($blob) !== 8) throw new InvalidArgumentException('Expected exactly 8 bytes.');
        $decimal = '0';
        foreach (array_values(unpack('C*', $blob)) as $byte) {
            $carry = $byte;
            $out = '';
            for ($i = strlen($decimal) - 1; $i >= 0; $i--) {
                $n = ((int)$decimal[$i]) * 256 + $carry;
                $out = (string)($n % 10) . $out;
                $carry = intdiv($n, 10);
            }
            while ($carry > 0) {
                $out = (string)($carry % 10) . $out;
                $carry = intdiv($carry, 10);
            }
            $decimal = ltrim($out, '0');
            if ($decimal === '') $decimal = '0';
        }
        return $decimal;
    }
}
