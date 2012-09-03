use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Devel::Kit',
    license             => 'perl',
    dist_author         => 'Daniel Muey <http://drmuey.com/cpan_contact.pl>',
    dist_version_from   => 'lib/Devel/Kit.pm',
    requires => {
        'Test::More' => 0, # for testing, I know I know: Test::XT
        'File::Temp' => 0, # for testing, I know I know: Test::XT
        
        'Module::Want' => 0,
        
        # lazy loaded (via Module::Want) only when needed
        'Import::Into' => 0,
        'Data::Dumper' => 0,
        'File::Slurp' => 0,
        'YAML::Syck' => 0,,
        'JSON::Syck' => 0,,
        'XML::Parser' => 0,
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
    add_to_cleanup      => [ 'Devel-Kit-*' ],
);

$builder->create_build_script();
