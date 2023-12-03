<?php
namespace EverISay\Prilo\Bundle\Console;

use Dotenv\Dotenv;
use Symfony\Component\Console\Application;
use Symfony\Component\Console\CommandLoader\FactoryCommandLoader;

require_once __DIR__.'/vendor/autoload.php';

if (class_exists(Dotenv::class)) {
    // .env file is used in dev env only.
    $dotenv = Dotenv::createImmutable(__DIR__);
    $dotenv->safeLoad();
}

$cmdLoader = new FactoryCommandLoader([
    'verify:lua' => fn() => new Command\VerifyLuaCommand,
    'batch:lua' => fn() => new Command\BatchLuaCommand,
]);

$app = new Application;
$app->setCommandLoader($cmdLoader);
$app->run();
