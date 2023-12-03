<?php
namespace EverISay\Prilo\Bundle\Console\Command;

use EverISay\Prilo\Bundle\Console\ConsoleHelper;
use EverISay\Prilo\Bundle\Console\Validator\LuaValidator;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Filesystem\Path;

#[AsCommand('verify:lua')]
final class VerifyLuaCommand extends Command {
    #[\Override]
    protected function configure(): void {
        $this->addArgument('filename', InputArgument::REQUIRED);
    }

    #[\Override]
    protected function execute(InputInterface $input, OutputInterface $output): int {
        $validator = new LuaValidator(
            ConsoleHelper::getRequiredEnv('PRILO_APK_ASSETS_PATH'),
            Path::join(__DIR__, '../../lua/original')
        );
        if ($validator->validate($input->getArgument('filename'))) {
            $output->writeln('PASSED');
        } else {
            $output->writeln('FAILED');
        }
        return self::SUCCESS;
    }
}
