package Mojolicious::Command::secret;

use Mojo::Base 'Mojo::Command';

use File::Spec;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case no_auto_abbrev);   # Match Mojo's commands

our $VERSION = '0.01';

has description => "Generate a secret() consisting of random bytes and add it to your application\n";
has usage => <<USAGE;
usage $0 secret [OPTIONS]

OPTIONS:
  -f, --force                    Overwrite an existing secret. Defaults to 0.
  -g, --generator MODULE=method  Module & method used to generate the secret. Defaults to Crypt::URandom=urandom. 
    				 Set the MOJO_GEN_SECRET environment variable to override this.
  -s, --size      SIZE           Number of bytes to use. Defaults to 32.
USAGE

sub run
{
    my ($self, @argv) = @_;
    my ($force, $size, $module);
    my $ok = GetOptionsFromArray(\@argv,
                                 'f|force'       => \$force,
                                 's|size=i'      => \$size,
                                 'g|generator=s' => \$module);

    return unless $ok;

    my $secret   = _create_secret($module, $size);
    my $code     = sprintf q|->secret('%s');|, $secret;
    my $filename = $self->class_to_path(ref($self->app));
    my $path     = $filename eq 'Mojolicious/Lite.pm' ? $0 : File::Spec->catdir('lib', $filename);

    open my $io, '+<:encoding(utf8)', $path or die "Error opening $path: $!\n";
    my $data = do { local $/; <$io> };

    my $created = 0;
    if($data =~ m|\w->secret\((["'].+["'])\)|) {
        if(!$force) {
            die "Your application already has a secret (use -f to overwrite it)\n";
        }

        my ($i, $j) = ($-[1], $+[1] - $-[1]);
        substr($data, $i, $j) = "'$secret'";
        $created = 1;
    }
    # Preserve indentation and prepend method target to $code.
    elsif($data =~ s/(sub\s+startup\s*\{(\s*).+(\$self).+)$/$1$2$3$code/m ||
          $data =~ s/^((\s*)\b(app)->\w+)/$2$3$code$1/m) {
        $created = 1;
    }

    if(!$created) {
        die "Can't figure out where to insert the call to secret()\n"
    }
    
    seek  $io, 0, 0 or die "Can't seek: $!\n";
    print $io $data and close $io or die "Error writing secret to $path: $!\n";

    say 'Secret created!';
}

sub _create_secret
{
    my $module = shift || $ENV{'MOJO_GEN_SECRET'} || 'Crypt::URandom=urandom';
    my $size   = shift || 32;

    my ($class, $method) = split /=/, $module, 2;
    eval "require $class; 1" or die "Module '$class' not found\n";

    my $secret;
    {
        no strict 'refs';
        if(!exists ${"${class}::"}{$method}) {
            die "$class has no method named '$method'\n";
        }

        eval { $secret = unpack "H*", "${class}::$method"->($size) };
        die "Can't create secret: $@\n" if $@;
    }

    $secret;
}

1;

=pod

=head1 NAME

Mojolicious::Command::secret - Generate a secret() using random bytes and add it to your application

=head1 DESCRIPTION

Tired of manually adding secrets? Me too!

  ./script/your_app secret
  perl ./lite_app.pl secret

B<This will modify your file>. An existing secret will not be overridden unless the C<-f> option is used. 

=head1 OPTIONS

  -f, --force                    Overwrite an existing secret. Defaults to 0.
  -g, --generator MODULE=method  Module & method used to generate the secret. Defaults to Crypt::URandom=urandom. 
    				 Set the MOJO_GEN_SECRET environment variable to override this.
  -s, --size      SIZE           Number of bytes to use. Defaults to 32.

=head1 AUTHOR

Skye Shaw

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

