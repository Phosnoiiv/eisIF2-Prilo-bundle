<?php
namespace EverISay\Prilo\Bundle\Console;

final class ConsoleHelper {
    public static function getRequiredEnv(string $name): string {
        return $_SERVER[$name] ?? throw new \Exception("Undefined environment variable " . $name);
    }
}
