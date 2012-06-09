package Mojolicious::Command::secret;

use Mojo::Base 'Mojo::Command';

use File::Spec;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case no_auto_abbrev);   # Match Mojo's commands

our $VERSION = '0.01';

has description => "Create an application secret() consisting of random bytes\n";
has usage => <<USAGE;
usage $0 secret [OPTIONS]

OPTIONS:
  -f, --force                    Overwrite an existing secret. Defaults to 0.
  -g, --generator MODULE=method  Use module & method to generate the secret. The method
                                 must accept an integer argument.
  -p, --print                    Just print the secret, do not add it to your application.
  -s, --size      SIZE           Number of bytes to use. Defaults to 32.

Default options can be added to the MOJO_SECRET_OPTIONS environment variable.
USAGE

sub run
{
    my ($self, @argv) = @_;
    unshift @argv, split /\s+/, $ENV{MOJO_SECRET_OPTIONS} if $ENV{MOJO_SECRET_OPTIONS};

    my ($force, $size, $module, $print);
    my $ok = GetOptionsFromArray(\@argv,
                                 'f|force'       => \$force,
                                 's|size=i'      => \$size,
                                 'p|print'       => \$print,
                                 'g|generator=s' => \$module);

    say "PKPKOK $ok\n";
    return unless $ok;

    my $secret   = _create_secret($module, $size);
    my $code     = sprintf q|->secret('%s');|, $secret;
    my $filename = $self->class_to_path(ref($self->app));
    my $path     = $filename eq 'Mojolicious/Lite.pm' ? $0 : File::Spec->catdir('lib', $filename);

    # If we're called as `mojo` just print the secret
    my $base = join '/', (File::Spec->splitdir($path))[-2,-1];
    if($print || $base eq 'bin/mojo') {
        print "$secret\n";
        return;
    }

    open my $in, '<:encoding(utf8)', $path or die "Error opening $path: $!\n";
    my $data = do { local $/; <$in> };

    my $created = 0;
    if($data =~ m|\w->secret\((["'].*["'])\)|) { # '
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
        die "Can't figure out where to insert the call to secret()\n";
    }

    my $out;
    open $out, '>:encoding(utf8)', $path 
	and print $out $data 
	and close $out
	or die "Error writing secret to $path: $!\n";

    print "Secret created!\n";
}

sub _create_secret
{
    my $module = shift;
    my $size   = shift || 32;
    my @lookup = $module ? $module : qw|Crypt::URandom=urandom Crypt::OpenSSL::Random=random_bytes|;

    my ($class, $method);
    while(defined(my $mod = shift @lookup)) {
	($class, $method) = split /=/, $mod, 2;
	eval "require $class; 1" 
	    and last 
	    or @lookup
	    or die "Module '$class' not found\n";
    }

    my $secret;
    {
        no strict 'refs';
	no warnings; 

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

Mojolicious::Command::secret - Create an application secret() consisting of random bytes

=head1 DESCRIPTION

Tired of manually creating and adding secrets? Me too! Use this command to create a secret
and add it to your C<Mojolicous> or C<Mojolicious::Lite> application:

 ./script/your_app secret
 ./lite_app secret

B<This will modify the appropriate application file>, though an existing secret will not be overridden unless the C<-f> option is used.
If you do not want to automatically add the secret to your application use the C<mojo> command or
the C<-p> option and the secret will be printed to C<STDOUT> instead:

 mojo secret
 ./script/your_app secret -p

It is assumed that your file contains UTF-8 data.

=head1 OPTIONS

 -f, --force                    Overwrite an existing secret. Defaults to 0.
 -g, --generator MODULE=method  Use module & method to generate the secret. The method
                                must accept an integer argument.
 -p, --print                    Print the secret, do not add it to your application.
 -s, --size      SIZE           Number of bytes to use. Defaults to 32.

 Default options can be added to the MOJO_SECRET_OPTIONS environment variable.

=head1 AUTHOR

Skye Shaw

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
