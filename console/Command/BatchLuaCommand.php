<?php
namespace EverISay\Prilo\Bundle\Console\Command;

use EverISay\Prilo\Bundle\Console\ConsoleHelper;
use EverISay\Prilo\Bundle\Console\Validator\LuaValidator;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Filesystem\Path;
use Symfony\Component\Finder\Finder;

#[AsCommand('batch:lua')]
class BatchLuaCommand extends Command {
    #[\Override]
    protected function execute(InputInterface $input, OutputInterface $output): int {
        $validator = new LuaValidator(
            $unzipRoot = ConsoleHelper::getRequiredEnv('PRILO_APK_ASSETS_PATH'),
            $recoverRoot = Path::join(__DIR__, '../../lua/original')
        );
        $totalCount = $totalSize = $coveredCount = $coveredSize = $failedCount = 0;
        $finder = (new Finder())->in($unzipRoot)->files()->name('*.lua');
        foreach ($finder as $file) {
            $size = $file->getSize() - 16;
            if (file_exists(Path::join($recoverRoot, $filename = $file->getRelativePathname()))) {
                if ($validator->validate($filename)) {
                    echo sprintf("PASSED %s\n", $filename);
                    $coveredCount++;
                    $coveredSize += $size;
                } else {
                    echo sprintf("::error::FAILED %s\n", $filename);
                    $failedCount++;
                }
            }
            $totalCount++;
            $totalSize += $size;
        }
        $isGitHub = isset($_SERVER['GITHUB_STEP_SUMMARY']);
        $summaryOut = $isGitHub ? fopen($_SERVER['GITHUB_STEP_SUMMARY'], 'w') : STDOUT;
        fprintf(
            $summaryOut,
            "%d failures\nCoverage by file count: %.2f%% (%d/%d)\nCoverage by file size: %.2f%% (%.1f/%.1f KB)",
            $failedCount,
            floor($coveredCount / $totalCount * 10000) / 100, $coveredCount, $totalCount,
            floor($coveredSize / $totalSize * 10000) / 100,
            floor($coveredSize / 102.4) / 10,
            ceil($totalSize / 102.4) / 10,
        );
        if ($isGitHub) {
            fclose($summaryOut);
        }
        return $failedCount ? self::FAILURE : self::SUCCESS;
    }
}
