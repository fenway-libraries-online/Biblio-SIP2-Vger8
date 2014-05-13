use strict;
use warnings;

use Module::Build;

my %module_build_args = (
    'build_requires' => {
        'Module::Build' => 0,
        'Test::More' => 0
    },
    'configure_requires' => {
        'Module::Build' => 0,
    },
    'dist_abstract' => 'SIP2 back-end for Voyager 8 ILS',
    'dist_author' => [ 'Paul Hoffman <paul@flo.org>' ],
    'dist_name' => 'Biblio-SIP2-Vger8',
    #'dist_version' => '0.03',
    'license' => 'perl',
    'module_name' => 'Biblio::SIP2::Vger8',
    'recommends' => {},
    'recursive_test_files' => 1,
    'requires' => {
        'Biblio-SIP2' => 0,
    },
    'script_files' => [],
);

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
