package OSM;
use Modern::Perl;
use Carp qw(croak);
use Math::Trig;
use LWP::Simple;
use XML::Twig;
my $BASE_URI = 'http://api.openstreetmap.org/api/0.6/';

sub get_area_bbox {
    my ($left, $bottom, $right, $top) = @_;
    croak 'bad bbox: left > right' if $left > $right;
    croak 'bad bbox: bottom > top' if $bottom >= $top;
    my $uri = $BASE_URI . "map?bbox=$left,$bottom,$right,$top";
    my $got = get($uri) //  die "could not get $uri";
    return $got;
}

# Given a position return the size in metres of one degree of
# longitude / latitude centred at that position.
#
sub one_degree_lat {
    my ($lat, $lon) = @_;
    return 111_000;
}
sub one_degree_lon {
    my ($lat, $lon) = @_;
    my $cosine = cos(deg2rad($lat));
    my $one_degree_lon_at_equator = 111_000;
    return $one_degree_lon_at_equator * $cosine;
}

# Distance in metres between two points.
sub distance {
    my ($lat1, $lon1, $lat2, $lon2) = @_;
    my $lat_diff = abs($lat1 - $lat2);
    my $lon_diff = abs($lon1 - $lon2);
    my $average_lat = ($lat1 + $lat2) / 2;
    my $average_lon = ($lon1 + $lon2) / 2;
    my $height = $lat_diff * one_degree_lat($average_lat, $average_lon);
    my $width = $lon_diff * one_degree_lon($average_lat, $average_lon);
    return sqrt($height ** 2 + $width ** 2);
}

# Utility functions to convert width and height to degrees of
# longitude and latitude respectively.  Pass the the lat,lon of the
# position you're interested in.
#
sub width_to_lon_degrees {
    my ($lat, $lon, $width) = @_;
    return $width / one_degree_lon($lat, $lon);
}
sub height_to_lat_degrees {
    my ($lat, $lon, $width) = @_;
    return $width / one_degree_lat($lat, $lon);
}

sub get_area_centre {
    my ($centre_lat, $centre_lon, $width, $height) = @_;
    my $cosine = cos(deg2rad($centre_lat));
    my $lat_degrees_high
	= height_to_lat_degrees $centre_lat, $centre_lon, $height;
    my $lon_degrees_wide
	= width_to_lon_degrees $centre_lat, $centre_lon, $width;
    return get_area_bbox
	$centre_lon - ($lon_degrees_wide / 2),
	$centre_lat - ($lat_degrees_high / 2),
	$centre_lon + ($lon_degrees_wide / 2),
	$centre_lat + ($lat_degrees_high / 2);
}

sub get_area_zoom {
    my ($centre_lat, $centre_lon, $zoom, $screen_width, $screen_height) = @_;
    $screen_width //= 1000;
    $screen_height //= 1000;

    my %metres_per_pixel_at_equator = (
	18 => 0.597164,
	17 => 1.194329,
	16 => 2.388657,
	15 => 4.777314,
	14 => 9.554629,
	13 => 19.109257,
	12 => 38.218514,
	11 => 76.437028,
	10 => 152.874057,
	9 => 305.748113,
	8 => 611.496226,
	7 => 1222.992453,
	6 => 2445.984905,
	5 => 4891.969810,
	4 => 9783.939621,
	3 => 19567.879241,
	2 => 39135.758482,
    );
    die "bad zoom $zoom" if not exists $metres_per_pixel_at_equator{$zoom};
    my $cosine = cos(deg2rad($centre_lat));
    my $metres_per_pixel
	= $metres_per_pixel_at_equator{$zoom} / $cosine;
    my $metres_wide = $screen_width * $metres_per_pixel;
    my $metres_high = $screen_height * $metres_per_pixel;
    return get_area_centre $centre_lat, $centre_lon, $metres_wide, $metres_high;
}

# Simplistic interface to parse the XML data and return the nodes.
# Each one is returned as a hashref with id, lat, lon, and tags.
# If a given tag appears twice then the values are concatenated with ;.
# If for some reason 'id', 'lat' or 'lon' appear as tags they are ignored.
# Certain tags such as 'created_by' are ignored.
#
my @boring_tags = qw(created_by randomjunk_bot ele time);
my @wanted_attrs = qw(id lat lon);
sub parse_nodes {
    my $data = shift;
    my $t = new XML::Twig;
    $t->parse($data);
    my @nodes = $t->root->children('node');
    my @r;
    foreach my $node (@nodes) {
	my %h;

	# First get the tags.
	foreach ($node->children('tag')) {
	    my $k = $_->att('k') // die "no 'k' in tag";
	    next if @boring_tags ~~ $k;
	    my $v = $_->att('v') // die "no 'v' in tag";
	    if (exists $h{$k}) {
		$h{$k} .= "; $v";
	    }
	    else {
		$h{$k} = $v;
	    }
	}
	next if not %h; # no tags

	# Then the standard attributes.
	foreach my $a (@wanted_attrs) {
	    my $v = $node->att($a) // die "no $a attr in node";
	    $h{$a} = $v;
	}
	push @r, \%h;
    }
    return @r;
}

1;
