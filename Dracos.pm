package Dracos;
use Modern::Perl;
use File::Slurp;

my $postboxes_data_file = 'postboxes.tsv';

sub get_data {
    if (not -e $postboxes_data_file) {
	my $uri = 'http://www.dracos.co.uk/play/locating-postboxes/export.php';
	die "$postboxes_data_file not there, fetch it from:\n$uri\n";
    }

    # Read the Dracos file.  The fields are the same as in the header.
    my @postbox_data;
    foreach (read_file $postboxes_data_file) {
	my %h;
	@h{qw(ref postcode loc1 loc2 lat lon)} = split /\t/;
	foreach (keys %h) {
	    delete $h{$_} if $h{$_} !~ /\S/;
	}
	push @postbox_data, \%h;
    }

    # Process the Dracos entries breaking up the information a bit.
    foreach (@postbox_data) {
	$_->{operator} = 'Royal Mail'; # might as well assume this
	my ($housenumber, $street, $postcode);
	if (defined (my $loc1 = delete($_->{loc1}))) {
	    if ($loc1 =~ /\A(\d+) (.+) ([A-Z]+\d+)\z/) {
		($housenumber, $street, $postcode) = ($1, $2, $3);
	    }
	    elsif ($loc1 =~ /\A(\d+) (.+)\z/) {
		($housenumber, $street) = ($1, $2);
	    }
	    else {
		$street = $loc1;
	    }
	}
	$_->{'addr:housenumber'} = $housenumber if defined $housenumber;
	$_->{'addr:street'} = $street if defined $housenumber;
	if (defined $postcode and exists $_->{postcode}
	    and $_->{postcode} !~ /\A$postcode /) {
	    if ($_->{postcode} =~ /\A${postcode}(\d)\z/) {
		# A simple missing space, most likely.
		$_->{postcode} = "$postcode $1";
	    }
	    else {
		warn "inconsistency in Dracos data: box with $_->{postcode} has $postcode in loc1\n";
	    }
	}

	# loc2, if present, gives the intersection street.  We don't do
	# anything with this yet, since addr:street holds just the main one.
	#
	delete $_->{loc2};

	# Rename this to the standard OSM name.
	if (exists $_->{postcode}) {
	    $_->{postal_code} = delete $_->{postcode};
	}
    }
    return @postbox_data;
}

1;
