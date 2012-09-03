use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Devel::Kit',
    AUTHOR              => 'Daniel Muey <http://drmuey.com/cpan_contact.pl>',
    VERSION_FROM        => 'lib/Devel/Kit.pm',
    ABSTRACT_FROM       => 'lib/Devel/Kit.pm',
    PL_FILES            => {},
    LICENSE             => 'perl',
    PREREQ_PM => {
        'Test::More' => 0, # for testing, I know I know: Test::XT
        'File::Temp' => 0, # for testing, I know I know: Test::XT
         
        'Module::Want' => 0,
        
        # lazy loaded (via Module::Want) only when needed
        'Import::Into' => 0,
        
        'Data::Dumper' => 0,
        'File::Slurp' => 0,
        'YAML::Syck' => 0,,
        'JSON::Syck' => 0,,
        'XML::Parser' => 0,,
        'Storable' => 0,
        'Config::INI::Reader' => 0,
        'Data::MessagePack' => 0,
         
        'Digest::MD5' => 0,
        'Digest::SHA' => 0,
        
        'MIME::QuotedPrint' => 0,
        'Net::IDN::Encode' => 0,
        'HTML::Entities' => 0,
        'URI::Escape' => 0,
        'MIME::Base64' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Devel-Kit-*' },
);
