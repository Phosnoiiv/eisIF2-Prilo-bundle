<?php
namespace EverISay\Prilo\Bundle\Console\Validator;

use EverISay\Prilo\Bundle\Console\ConsoleHelper;
use Spatie\TemporaryDirectory\TemporaryDirectory;
use Symfony\Component\Filesystem\Path;
use Symfony\Component\Process\Process;

class LuaValidator {
    public function __construct(
        private readonly string $unzipRoot,
        private readonly string $recoverRoot,
    ) {
        $this->luacPath = ConsoleHelper::getRequiredEnv('PRILO_LUAC_PATH');
        $this->honokamikuPath = ConsoleHelper::getRequiredEnv('PRILO_HONOKAMIKU_PATH');
        $this->tmp = (new TemporaryDirectory)->name('prilo-bundle-lua')->force()->create();
    }

    function __destruct() {
        $this->tmp->delete();
    }

    private readonly string $luacPath;
    private readonly string $honokamikuPath;
    private TemporaryDirectory $tmp;

    public function validate(string $filename): bool {
        $basename = basename($filename);
        $honokamiku = new Process([
            $this->honokamikuPath,
            Path::join($this->unzipRoot, $filename),
            $unzipPath = $this->tmp->path($basename),
        ]);
        $honokamiku->mustRun();
        $luac = new Process([
            $this->luacPath,
            '-s',
            '-o', $recoverPath = $this->tmp->path('luac.out'),
            Path::join($this->recoverRoot, $filename),
        ]);
        $luac->run();
        if (!$luac->isSuccessful()) return false;
        $result = md5_file($unzipPath) == md5_file($recoverPath);
        unlink($unzipPath);
        unlink($recoverPath);
        return $result;
    }
}
