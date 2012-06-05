package Mojolicious::Command::secret;

use Mojo::Base 'Mojo::Command';
use Getopt::Long 'GetOptionsFromArray';

our $VERSION = '0.01';

has description => "Generate a secret() using random bytes and add it to your app\n";
has usage => <<USAGE;
usage $0 secret [OPTIONS]

OPTIONS:
  -f, --force                 Overwrite an existing secret. Defaults to 0.
  -m, --module MODULE=method  Module & method used to generate the secret. Defaults to Crypt::URandom=urandom.
  -s, --size   SIZE           Number of bytes to use. Defaults to 32.
USAGE

sub run 
{
    my ($self, @argv) = @_;
    my ($force, $size, $module);
    my $ok = GetOptionsFromArray(\@argv, 
				 'f|force'    => \$force,
				 's|size=i'   => \$size,
				 'm|module=s' => \$module);    
    return unless $ok;
    
    my $secret   = _create_secret($module, $size);
    my $code     = sprintf qq|->secret('%s');|, $secret;
    my $filename = $self->class_to_path(ref($self->app));
    my $path     = $filename eq 'Mojolicious/Lite.pm' ? $0 : File::Spec->catdir('lib', $filename);

    open my $io, '<', $path or die "Error opening $path: $!\n";
    my $data = do { local $/; <$io> };    

    my $created = 0;
    if($data =~ m|\w->secret\((["'].+["'])\)|) {
	if(!$force) {
	    die "Your app already has a secret (use -f to overwrite it)\n";
	}

    	my ($i, $j) = ($-[1], $+[1] - $-[1]);	
    	substr($data, $i, $j) = "'$secret'";
	$created = 1;
    }
    # Preserve indentation and prepend target object to $code.
    elsif($data =~ s/(sub\s+startup\s*\{(\s*).+(\$self).+)$/$1$2$3$code/m ||
	  $data =~ s/^((\s*)\b(app)->\w+)/$2$3$code$1/m) {
	$created = 1;
    }

    if(!$created) {
	die "Can't figure out where to insert the call to secret\n"
    }

    open my $out, '>', $path or die "Error writing secret to $path: $!\n";
    print $out $data;
    close $out or die "Error writing secret to $path: $!\n";
    say 'Secret created!';
}

sub _create_secret
{
    my $module = shift || 'Crypt::URandom=urandom';
    my $size   = shift || 32;

    my ($class, $method) = split /=/, $module, 2;   
    eval "require $class; 1" or die "Module not found: $class\n";
    
    my $secret;
    { 
	no strict 'refs';
	eval { 
	    $secret = unpack "H*", "${class}::$method"->($size);
	};
	die "Can't create secret: $@" if $@;
    }

    $secret;
}

1;

=pod

=head1 NAME

Mojolicious::Command::secret - Generate a secret() using random bytes and add it you your app

=head1 DESCRIPTION

  ./script/your_app secret
  perl ./lite_app.pl secret

=head1 OPTIONS

  -f, --force                 Overwrite an existing secret. Defaults to 0.
  -m, --module MODULE=method  Module & method used to generate the secret. Defaults to Crypt::URandom=urandom.
  -s, --size   SIZE           Number of bytes to use. Defaults to 32.



