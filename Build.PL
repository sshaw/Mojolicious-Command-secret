use Module::Build;
use strict;
use warnings;

my $found;
my @modz = qw|Crypt::OpenSSL::Random Crypt::URandom|;
for(@modz) {
  if(eval "require $_; 1") {
    $found = 1;
    last;
  }
}

unless($found) {
  warn<<END;

Neither $modz[0] or $modz[1] are installed. In order to generate a secret
you must install one of these modules or, when running the command, specify an alternate
generator via the `-g` option.

See `mojo secret --help` for more info.

END
}

my $class = Module::Build->subclass
  (
   class => 'My::Builder',
   code => q{
     sub ACTION_docs {
       system('perldoc -uT "lib/Mojolicious/Command/secret.pm" > README.pod');
     }
   },
  );

my $build = $class->new (
  module_name => 'Mojolicious::Command::secret',
  license     => 'perl',
  dist_author => 'Skye Shaw <skye.shaw AT gmail.com>',
  requires    => { 'Mojolicious' => '4.63' },
  dist_version_from  => 'lib/Mojolicious/Command/secret.pm',
  (eval { Module::Build->VERSION(0.28) } ?
     (meta_merge => {
       resources => {
         homepage   => 'http://github.com/sshaw/Mojolicious-Command-secret',
         bugtracker => 'http://github.com/sshaw/Mojolicious-Command-secret/issues',
         repository => 'http://github.com/sshaw/Mojolicious-Command-secret'
        }
      }
     ) : ()
    )
 );

$build->create_build_script;
